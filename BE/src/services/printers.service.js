import { AppError } from '../middleware/error.middleware.js';
import { ROLES } from '../middleware/role.middleware.js';
import * as repo from '../repositories/printers.repository.js';
import { buildMeta, parseFilters, parsePagination } from '../utils/pagination.js';
import { toIsoDate, toPositiveInt, toText } from '../utils/validate.js';

const CREATE_ERRORS = {
  SCHEDULE_NOT_FOUND: [404, 'ไม่พบช่วงเวลาที่เลือก'],
  SLOT_UNAVAILABLE: [409, 'ช่วงเวลานี้ไม่เปิดให้จอง'],
  PRINTER_UNAVAILABLE: [409, 'เครื่องพิมพ์นี้ไม่พร้อมใช้งานในขณะนี้'],
  SLOT_IN_PAST: [409, 'ช่วงเวลานี้เริ่มไปแล้ว'],
  SLOT_FULL: [409, 'ช่วงเวลานี้ถูกจองเต็มแล้ว'],
  USER_TIME_CONFLICT: [409, 'คุณมีการจองที่เวลาทับกับช่วงนี้อยู่แล้ว'],
};

const CHANGE_ERRORS = {
  BOOKING_NOT_FOUND: [404, 'ไม่พบการจองนี้'],
  FORBIDDEN: [403, 'คุณไม่มีสิทธิ์ทำรายการนี้'],
  SELF_APPROVAL: [403, 'ไม่สามารถอนุมัติคำขอของตัวเองได้'],
  INVALID_TRANSITION: [409, 'สถานะปัจจุบันของการจองไม่รองรับการทำรายการนี้'],
  SLOT_IN_PAST: [409, 'ช่วงเวลานี้เริ่มไปแล้ว ไม่สามารถอนุมัติได้'],
  ALREADY_STARTED: [409, 'การจองนี้เริ่มไปแล้ว ไม่สามารถยกเลิกได้'],
  INVALID_ACTION: [400, 'การดำเนินการไม่ถูกต้อง'],
};

const translate = (error, map) => {
  const hit = map[error?.message];
  if (hit) throw new AppError(hit[1], hit[0]);
  throw new AppError('Database operation failed', 500, error);
};

export const MATERIALS = ['PLA', 'PETG', 'ABS', 'ASA', 'TPU', 'NYLON', 'RESIN', 'OTHER'];
const BOOKING_STATUSES = ['PENDING', 'APPROVED', 'REJECTED', 'IN_PROGRESS', 'COMPLETED', 'RECEIVED', 'CANCELLED'];

const BOOKING_LIST = {
  view: 'v_printer_booking_summary',
  tieBreaker: 'booking_id',
  defaultSort: 'work_date',
  defaultOrder: 'desc',
  sortable: ['work_date', 'start_time', 'booking_time', 'printer_name', 'booking_code', 'booking_status'],
  filters: ['booking_status'],
};

const isStaff = (user) => user.role === ROLES.STAFF || user.role === ROLES.ADMIN;

const actorId = (user) => {
  const id = Number(user?.userId);
  if (!Number.isInteger(id) || id < 1) throw new AppError('Invalid session user', 500);
  return id;
};

const bangkokNow = () => new Date().toLocaleString('sv-SE', { timeZone: 'Asia/Bangkok' });

export const allowedActions = (row, { staff, owner }) => {
  const started = `${row.work_date} ${row.start_time}` <= bangkokNow();
  const status = row.booking_status;
  const actions = [];
  if (status === 'PENDING') {
    if (staff && !owner && !started) actions.push('APPROVE');
    if (staff) actions.push('REJECT');
  }
  if ((status === 'PENDING' || status === 'APPROVED') && (staff || owner) && !started) actions.push('CANCEL');
  if (staff && status === 'APPROVED') actions.push('START');
  if (staff && status === 'IN_PROGRESS') actions.push('COMPLETE');
  if (owner && status === 'COMPLETED') actions.push('RECEIVE');
  return actions;
};

const withActions = (row, ctx) => ({ ...row, actions: allowedActions(row, ctx) });

const parseMaterial = (value) => {
  const material = String(value ?? '').trim().toUpperCase();
  if (!MATERIALS.includes(material)) throw new AppError('Invalid material', 400, { allowed: MATERIALS });
  return material;
};

const parseWeight = (value) => {
  if (value === undefined || value === null || value === '') return null;
  const n = Number(value);
  if (!Number.isFinite(n) || n <= 0 || n > 5000) {
    throw new AppError('est_weight_g must be between 0 and 5000', 400);
  }
  return Math.round(n * 10) / 10;
};

export const getAvailability = async (query) => {
  const date = toIsoDate(query.date);
  const onlyBookable = query.only_bookable === 'true';
  const [printers, slots] = await Promise.all([repo.listPrinters(), repo.listSlots(date)]);
  const byPrinter = new Map();
  for (const slot of slots) {
    if (!byPrinter.has(slot.resource_id)) byPrinter.set(slot.resource_id, []);
    byPrinter.get(slot.resource_id).push(slot);
  }
  return printers.map((printer) => ({
    ...printer,
    slots: (byPrinter.get(printer.resource_id) ?? []).filter((s) => !onlyBookable || s.is_bookable),
  }));
};

export const createBooking = async (user, body) => {
  const scheduleId = toPositiveInt(body?.schedule_id, 'schedule_id');
  const purpose = toText(body?.purpose, 'purpose', { min: 3, max: 500 });
  const material = parseMaterial(body?.material);
  const weight = parseWeight(body?.est_weight_g);
  const { data, error } = await repo.createBooking(actorId(user), scheduleId, purpose, material, weight);
  if (error) translate(error, CREATE_ERRORS);
  const booking = await repo.getBookingById(data[0].new_booking_id);
  return withActions(booking, { staff: isStaff(user), owner: true });
};

const listBookings = async (query, extraFilters) => {
  const paging = parsePagination(query, BOOKING_LIST);
  const filters = parseFilters(query, BOOKING_LIST.filters);
  if (filters.booking_status && !BOOKING_STATUSES.includes(filters.booking_status)) {
    throw new AppError('Invalid booking_status', 400, { allowed: BOOKING_STATUSES });
  }
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

export const changeStatus = async (user, rawId, action) => {
  const bookingId = toPositiveInt(rawId, 'id');
  const { data, error } = await repo.changeStatus(bookingId, action, actorId(user), isStaff(user));
  if (error) translate(error, CHANGE_ERRORS);
  return { booking_id: data[0].out_booking_id, status: data[0].out_status };
};
