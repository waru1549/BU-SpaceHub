import { AppError } from '../middleware/error.middleware.js';
import { ROLES } from '../middleware/role.middleware.js';
import * as repo from '../repositories/equipment.repository.js';
import { buildMeta, parseFilters, parsePagination } from '../utils/pagination.js';
import { toIsoDate, toPositiveInt, toText } from '../utils/validate.js';

const CREATE_ERRORS = {
  RESOURCE_NOT_FOUND: [404, 'ไม่พบอุปกรณ์ที่เลือก'],
  EQUIPMENT_UNAVAILABLE: [409, 'อุปกรณ์นี้ไม่พร้อมให้ยืมในขณะนี้'],
  INVALID_DATES: [400, 'วันที่คืนต้องไม่ก่อนวันที่ยืม'],
  BORROW_IN_PAST: [400, 'ไม่สามารถเลือกวันยืมย้อนหลังได้'],
  BORROW_TOO_FAR: [400, 'จองล่วงหน้าได้ไม่เกิน 14 วัน'],
  LOAN_TOO_LONG: [400, 'ยืมได้ไม่เกิน 7 วัน'],
  DUE_IN_PAST: [409, 'กำหนดคืนผ่านไปแล้ว'],
  USER_HAS_OVERDUE: [409, 'คุณมีอุปกรณ์เกินกำหนดคืน กรุณาคืนก่อนยืมใหม่'],
  USER_HAS_UNPAID_FINE: [409, 'คุณมีค่าปรับค้างชำระ กรุณาชำระหรือติดต่อเจ้าหน้าที่ก่อนยืมใหม่'],
  USER_LIMIT_REACHED: [409, 'ยืมพร้อมกันได้ไม่เกิน 2 รายการ'],
  ALREADY_BORROWING: [409, 'คุณมีคำขอหรือการยืมอุปกรณ์ชิ้นนี้อยู่แล้ว'],
  OUT_OF_STOCK: [409, 'อุปกรณ์ในช่วงวันที่เลือกถูกจองเต็มแล้ว'],
};

const CHANGE_ERRORS = {
  BOOKING_NOT_FOUND: [404, 'ไม่พบการยืมนี้'],
  FORBIDDEN: [403, 'คุณไม่มีสิทธิ์ทำรายการนี้'],
  SELF_APPROVAL: [403, 'ไม่สามารถอนุมัติคำขอของตัวเองได้'],
  INVALID_TRANSITION: [409, 'สถานะปัจจุบันไม่รองรับการทำรายการนี้'],
  DUE_IN_PAST: [409, 'กำหนดคืนผ่านไปแล้ว ไม่สามารถดำเนินการได้'],
  NOT_BORROW_DAY: [409, 'ยังไม่ถึงวันยืม ไม่สามารถส่งมอบได้'],
  FINE_INVALID: [400, 'ยอดค่าปรับไม่ถูกต้อง'],
  FINE_REASON_REQUIRED: [400, 'กรุณาระบุเหตุผลของค่าปรับ (ชำรุด/สูญหาย)'],
  INVALID_ACTION: [400, 'การดำเนินการไม่ถูกต้อง'],
};

const translate = (error, map) => {
  const hit = map[error?.message];
  if (hit) throw new AppError(hit[1], hit[0]);
  throw new AppError('Database operation failed', 500, error);
};

const BOOKING_STATUSES = ['PENDING', 'APPROVED', 'REJECTED', 'RECEIVED', 'OVERDUE', 'RETURNED', 'CANCELLED'];
const FINE_STATUSES = ['UNPAID', 'PAID', 'WAIVED'];
const UNAVAILABLE = ['BROKEN', 'UNDER_MAINTENANCE', 'OUT_OF_SERVICE'];

const BOOKING_LIST = {
  view: 'v_equipment_booking_summary',
  tieBreaker: 'booking_id',
  defaultSort: 'borrow_date',
  defaultOrder: 'desc',
  sortable: ['borrow_date', 'expected_return_date', 'equipment_name', 'booking_code', 'booking_status', 'overdue_days'],
  filters: ['booking_status'],
};

const FINE_LIST = {
  view: 'v_equipment_fines',
  tieBreaker: 'fine_id',
  defaultSort: 'fine_id',
  defaultOrder: 'desc',
  sortable: ['fine_id', 'fine_amount', 'booking_code', 'fine_status'],
  filters: ['fine_status'],
};

const isStaff = (user) => user.role === ROLES.STAFF || user.role === ROLES.ADMIN;

const actorId = (user) => {
  const id = Number(user?.userId);
  if (!Number.isInteger(id) || id < 1) throw new AppError('Invalid session user', 500);
  return id;
};

export const allowedActions = (row, { staff, owner }, now = new Date()) => {
  const status = row.booking_status;
  const actions = [];
  if (status === 'PENDING') {
    if (staff && !owner) actions.push('APPROVE');
    if (staff) actions.push('REJECT');
    if (staff || owner) actions.push('CANCEL');
  }
  if (status === 'APPROVED') {
    if (staff || owner) actions.push('CANCEL');
    const borrowDay = new Date(row.borrow_date) <= now;
    const notDue = new Date(row.expected_return_date) > now;
    if (staff && borrowDay && notDue) actions.push('RECEIVE');
  }
  if (staff && (status === 'RECEIVED' || status === 'OVERDUE')) actions.push('RETURN');
  return actions;
};

const withActions = (row, ctx) => ({ ...row, actions: allowedActions(row, ctx) });

// ยอดค่าปรับชำรุด/สูญหาย (ไม่ส่ง/0 = ไม่คิดค่าปรับ) ต้องมีเหตุผลเมื่อมียอด
export const parseFine = (body) => {
  const raw = body?.fine_amount;
  if (raw === undefined || raw === null || raw === '' || Number(raw) === 0) return { amount: null, reason: null };
  const amount = Number(raw);
  if (!Number.isFinite(amount) || amount < 0 || amount > 100000) {
    throw new AppError('fine_amount must be between 0 and 100000', 400);
  }
  const reason = typeof body?.fine_reason === 'string' ? body.fine_reason.trim() : '';
  if (reason.length < 3 || reason.length > 255) {
    throw new AppError('กรุณาระบุเหตุผลของค่าปรับ (3-255 ตัวอักษร)', 400);
  }
  return { amount: Math.round(amount * 100) / 100, reason };
};

export const getAvailability = async (query) => {
  const borrow = toIsoDate(query.borrow_date);
  const ret = toIsoDate(query.return_date);
  if (ret < borrow) throw new AppError('return_date must not be before borrow_date', 400);
  await repo.syncOverdue();
  const [items, stock] = await Promise.all([repo.listEquipment(), repo.getStock(borrow, ret)]);
  const byId = new Map(stock.map((s) => [s.resource_id, s]));
  const onlyBorrowable = query.only_borrowable === 'true';
  return items
    .map((item) => {
      const s = byId.get(item.resource_id);
      const remaining = s?.remaining ?? 0;
      return {
        ...item,
        reserved: s?.reserved ?? 0,
        remaining,
        is_borrowable: remaining > 0 && !UNAVAILABLE.includes(item.resource_status),
      };
    })
    .filter((item) => !onlyBorrowable || item.is_borrowable);
};

export const createBooking = async (user, body) => {
  const resourceId = toPositiveInt(body?.resource_id, 'resource_id');
  const borrow = toIsoDate(body?.borrow_date);
  const ret = toIsoDate(body?.return_date);
  const purpose = toText(body?.purpose, 'purpose', { min: 3, max: 500 });
  const { data, error } = await repo.createBooking(actorId(user), resourceId, borrow, ret, purpose);
  if (error) translate(error, CREATE_ERRORS);
  const booking = await repo.getBookingById(data[0].new_booking_id);
  return withActions(booking, { staff: isStaff(user), owner: true });
};

const listBookings = async (query, extraFilters) => {
  await repo.syncOverdue();
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

export const changeStatus = async (user, rawId, action, body) => {
  const bookingId = toPositiveInt(rawId, 'id');
  const fine = action === 'RETURN' ? parseFine(body) : { amount: null, reason: null };
  const { data, error } = await repo.changeStatus(
    bookingId, action, actorId(user), isStaff(user), fine.amount, fine.reason,
  );
  if (error) translate(error, CHANGE_ERRORS);
  return { booking_id: data[0].out_booking_id, status: data[0].out_status, fine_amount: fine.amount };
};

const listFines = async (query, extraFilters) => {
  const paging = parsePagination(query, FINE_LIST);
  const filters = parseFilters(query, FINE_LIST.filters);
  if (filters.fine_status && !FINE_STATUSES.includes(filters.fine_status)) {
    throw new AppError('Invalid fine_status', 400, { allowed: FINE_STATUSES });
  }
  const { rows, total } = await repo.fetchPage(FINE_LIST, {
    ...paging,
    filters: { ...filters, ...extraFilters },
  });
  return { rows, meta: buildMeta({ total, ...paging }) };
};

export const getMyFines = (user, query) => listFines(query, { user_id: actorId(user) });
export const getAllFines = (query) => listFines(query, {});

// staff: UNPAID -> PAID | WAIVED
export const settleFine = async (rawId, status) => {
  const fineId = toPositiveInt(rawId, 'id');
  const rows = await repo.settleFine(fineId, status);
  if (rows.length === 0) {
    if (await repo.fineExists(fineId)) throw new AppError('ค่าปรับนี้ถูกดำเนินการไปแล้ว', 409);
    throw new AppError('ไม่พบค่าปรับนี้', 404);
  }
  return rows[0];
};
