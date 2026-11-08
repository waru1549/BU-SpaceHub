import { AppError } from '../middleware/error.middleware.js';
import { ROLES } from '../middleware/role.middleware.js';
import * as repo from '../repositories/rooms.repository.js';
import { buildMeta, parseFilters, parsePagination } from '../utils/pagination.js';
import { toIsoDate, toPositiveInt, toText } from '../utils/validate.js';

// รหัสข้อผิดพลาดจากฟังก์ชันใน DB -> [HTTP status, ข้อความสำหรับผู้ใช้]
const CREATE_ERRORS = {
  SCHEDULE_NOT_FOUND: [404, 'ไม่พบช่วงเวลาที่เลือก'],
  SLOT_UNAVAILABLE: [409, 'ช่วงเวลานี้ไม่เปิดให้จอง'],
  ROOM_UNAVAILABLE: [409, 'ห้องนี้ไม่พร้อมใช้งานในขณะนี้'],
  SLOT_IN_PAST: [409, 'ช่วงเวลานี้เริ่มไปแล้ว'],
  SLOT_FULL: [409, 'ช่วงเวลานี้ถูกจองเต็มแล้ว'],
  USER_TIME_CONFLICT: [409, 'คุณมีการจองที่เวลาทับกับช่วงนี้อยู่แล้ว'],
};

const CHANGE_ERRORS = {
  BOOKING_NOT_FOUND: [404, 'ไม่พบการจองนี้'],
  FORBIDDEN: [403, 'คุณไม่มีสิทธิ์ทำรายการนี้'],
  INVALID_TRANSITION: [409, 'สถานะปัจจุบันของการจองไม่รองรับการทำรายการนี้'],
  SLOT_IN_PAST: [409, 'ช่วงเวลานี้เริ่มไปแล้ว ไม่สามารถอนุมัติได้'],
  ALREADY_STARTED: [409, 'การจองนี้เริ่มไปแล้ว ไม่สามารถยกเลิกได้'],
  NOT_STARTED: [409, 'การจองนี้ยังไม่ถึงเวลาเริ่ม'],
  INVALID_ACTION: [400, 'การดำเนินการไม่ถูกต้อง'],
};

const translate = (error, map) => {
  const hit = map[error?.message];
  if (hit) throw new AppError(hit[1], hit[0]);
  throw new AppError('Database operation failed', 500, error);
};

const BOOKING_STATUSES = ['PENDING', 'APPROVED', 'REJECTED', 'COMPLETED', 'CANCELLED'];

const BOOKING_LIST = {
  view: 'v_room_booking_summary',
  tieBreaker: 'booking_id',
  defaultSort: 'work_date',
  defaultOrder: 'desc',
  sortable: ['work_date', 'start_time', 'booking_time', 'room_name', 'booking_code', 'booking_status'],
  filters: ['booking_status'],
};

const isStaff = (user) => user.role === ROLES.STAFF || user.role === ROLES.ADMIN;

// ป้องกันบันทึกการจองผิดคนถ้ารูปแบบ req.user ไม่ตรงที่คาด
const actorId = (user) => {
  const id = Number(user?.userId);
  if (!Number.isInteger(id) || id < 1) throw new AppError('Invalid session user', 500);
  return id;
};

// เวลาปัจจุบันตามเขตเวลาไทย รูปแบบ 'YYYY-MM-DD HH:mm:ss' (เทียบเป็นข้อความได้ตรง ๆ)
const bangkokNow = () => new Date().toLocaleString('sv-SE', { timeZone: 'Asia/Bangkok' });

// รายการที่ผู้เรียกทำได้กับการจองนี้ (สะท้อนกติกาเดียวกับฟังก์ชันใน DB เพื่อให้ FE แสดงปุ่มถูกต้อง
// แต่การบังคับใช้จริงอยู่ที่ DB เสมอ)
export const allowedActions = (row, { staff, owner }) => {
  const started = `${row.work_date} ${row.start_time}` <= bangkokNow();
  const status = row.booking_status;
  const actions = [];
  if (staff && status === 'PENDING' && !started) actions.push('APPROVE');
  if (staff && status === 'PENDING') actions.push('REJECT');
  if ((staff || owner) && (status === 'PENDING' || status === 'APPROVED') && !started) {
    actions.push('CANCEL');
  }
  if (staff && status === 'APPROVED' && started) actions.push('COMPLETE');
  return actions;
};

const withActions = (row, ctx) => ({ ...row, actions: allowedActions(row, ctx) });

// ---------------------------------------------------------------------
// ห้อง + ช่วงเวลาว่างของวันที่เลือก
// ---------------------------------------------------------------------
export const getAvailability = async (query) => {
  const date = toIsoDate(query.date);
  const minCapacity =
    query.min_capacity === undefined ? null : toPositiveInt(query.min_capacity, 'min_capacity');
  const onlyBookable = query.only_bookable === 'true';

  const [rooms, slots] = await Promise.all([repo.listRooms(), repo.listSlots(date)]);

  const byRoom = new Map();
  for (const slot of slots) {
    if (!byRoom.has(slot.resource_id)) byRoom.set(slot.resource_id, []);
    byRoom.get(slot.resource_id).push(slot);
  }

  return rooms
    .filter((room) => minCapacity === null || (room.capacity ?? 0) >= minCapacity)
    .map((room) => ({
      ...room,
      slots: (byRoom.get(room.resource_id) ?? []).filter((s) => !onlyBookable || s.is_bookable),
    }));
};

// ---------------------------------------------------------------------
// สร้างการจอง (สถานะเริ่มต้น PENDING)
// ---------------------------------------------------------------------
export const createBooking = async (user, body) => {
  const scheduleId = toPositiveInt(body?.schedule_id, 'schedule_id');
  const purpose = toText(body?.purpose, 'purpose', { min: 3, max: 500 });

  const { data, error } = await repo.createBooking(actorId(user), scheduleId, purpose);
  if (error) translate(error, CREATE_ERRORS);

  const booking = await repo.getBookingById(data[0].new_booking_id);
  return withActions(booking, { staff: isStaff(user), owner: true });
};

// ---------------------------------------------------------------------
// รายการจอง: ของฉัน / ทั้งหมด (STAFF, ADMIN)
// ---------------------------------------------------------------------
const listBookings = async (query, extraFilters) => {
  const paging = parsePagination(query, BOOKING_LIST);
  const filters = parseFilters(query, BOOKING_LIST.filters);
  if (filters.booking_status && !BOOKING_STATUSES.includes(filters.booking_status)) {
    throw new AppError('Invalid booking_status', 400, { allowed: BOOKING_STATUSES });
  }
  // extraFilters กำหนดโดยเซิร์ฟเวอร์เท่านั้น (เช่น user_id ของผู้เรียก) ไม่รับจาก query
  const { rows, total } = await repo.fetchPage(BOOKING_LIST, {
    ...paging,
    filters: { ...filters, ...extraFilters },
  });
  return { rows, meta: buildMeta({ total, ...paging }) };
};

export const getMyBookings = async (user, query) => {
  const { rows, meta } = await listBookings(query, { user_id: actorId(user) });
  const ctx = { staff: isStaff(user), owner: true };
  return { rows: rows.map((r) => withActions(r, ctx)), meta };
};

export const getAllBookings = async (user, query) => {
  const me = actorId(user);
  const { rows, meta } = await listBookings(query, {});
  return { rows: rows.map((r) => withActions(r, { staff: true, owner: r.user_id === me })), meta };
};

// ---------------------------------------------------------------------
// เปลี่ยนสถานะ: APPROVE / REJECT / CANCEL / COMPLETE
// ---------------------------------------------------------------------
export const changeStatus = async (user, rawId, action) => {
  const bookingId = toPositiveInt(rawId, 'id');
  const { data, error } = await repo.changeStatus(bookingId, action, actorId(user), isStaff(user));
  if (error) translate(error, CHANGE_ERRORS);
  return { booking_id: data[0].changed_booking_id, status: data[0].changed_status };
};