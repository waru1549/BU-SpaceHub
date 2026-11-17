import { AppError } from '../middleware/error.middleware.js';
import * as repo from '../repositories/adminResources.repository.js';
import { buildMeta, parseFilters, parsePagination } from '../utils/pagination.js';

const CATEGORIES = ['ROOM', 'PRINTER', 'EQUIPMENT', 'MAINTENANCE'];
const STATUSES = ['AVAILABLE', 'RESERVED', 'BORROWED', 'BROKEN', 'UNDER_MAINTENANCE', 'OUT_OF_SERVICE'];
const KINDS = ['ROOM', 'PRINTER'];

const LIST = {
  tieBreaker: 'resource_id',
  defaultSort: 'resource_code',
  defaultOrder: 'asc',
  sortable: [
    'resource_code', 'resource_name', 'category', 'location', 'capacity', 'quantity',
    'resource_status', 'upcoming_slots', 'history_count', 'created_at',
  ],
  filters: ['category', 'resource_status'],
};

const ERRORS = {
  CODE_INVALID: [400, 'รหัสต้องเป็นตัวอักษร A-Z ตัวเลข _ หรือ - ยาว 2-50 ตัวอักษร (ห้ามมีช่องว่าง)'],
  NAME_INVALID: [400, 'ชื่อต้องยาว 2-255 ตัวอักษร'],
  CAPACITY_INVALID: [400, 'ความจุต้องเป็นจำนวนเต็ม 1-1000'],
  QUANTITY_INVALID: [400, 'จำนวนต้องเป็นจำนวนเต็ม 1-10000'],
  CAPACITY_REQUIRED: [400, 'ห้องต้องระบุความจุ'],
  QUANTITY_REQUIRED: [400, 'อุปกรณ์ต้องระบุจำนวน'],
  CATEGORY_INVALID: [400, 'หมวดหมู่ไม่ถูกต้อง'],
  STATUS_NOT_ALLOWED: [400, 'ตั้งสถานะได้เฉพาะ พร้อมใช้งาน / ชำรุด / ปิดซ่อมบำรุง / งดให้บริการ'],
  CODE_EXISTS: [409, 'รหัสนี้ถูกใช้แล้ว'],
  RESOURCE_NOT_FOUND: [404, 'ไม่พบทรัพยากรนี้'],
  HAS_ACTIVE_BOOKINGS: [409, 'ยังมีรายการที่รอดำเนินการ/กำลังใช้งานอยู่ จึงลบหรือปิดทรัพยากรนี้ไม่ได้'],
  NO_SCHEDULE_FOR_CATEGORY: [400, 'ทรัพยากรหมวดนี้ไม่มีตารางเวลา (ใช้เฉพาะห้องและเครื่องพิมพ์ 3D)'],
  DATE_RANGE_INVALID: [400, 'ช่วงวันที่ไม่ถูกต้อง'],
  DATE_IN_PAST: [400, 'วันที่เริ่มต้องไม่ย้อนหลัง'],
  RANGE_TOO_LONG: [400, 'สร้างได้ครั้งละไม่เกิน 92 วัน'],
  WEEKDAYS_INVALID: [400, 'กรุณาเลือกวันในสัปดาห์อย่างน้อย 1 วัน'],
  MAX_SLOTS_INVALID: [400, 'จำนวนที่รับต่อช่วงต้องเป็น 1-20'],
  SLOTS_INVALID: [400, 'ช่วงเวลาไม่ถูกต้อง (ต้องมี 1-12 ช่วง รูปแบบ HH:MM และเวลาสิ้นสุดหลังเวลาเริ่ม)'],
  SLOTS_OVERLAP: [400, 'ช่วงเวลาที่ระบุซ้อนทับกัน'],
  KIND_INVALID: [400, 'ชนิดตารางเวลาไม่ถูกต้อง'],
  SCHEDULE_NOT_FOUND: [404, 'ไม่พบช่วงเวลานี้'],
  SLOT_HAS_BOOKINGS: [409, 'ช่วงเวลานี้มีการจองอยู่ จึงทำรายการนี้ไม่ได้'],
};

const run = async (promise) => {
  const { data, error } = await promise;
  if (error) {
    const hit = ERRORS[error.message];
    if (hit) throw new AppError(hit[1], hit[0]);
    throw new AppError('Database operation failed', 500, error);
  }
  return Array.isArray(data) ? data[0] : data;
};

// ---------- ตรวจข้อมูลรับเข้า ----------
const toId = (raw, name = 'id') => {
  const n = Number(raw);
  if (!Number.isInteger(n) || n < 1) throw new AppError(`${name} ไม่ถูกต้อง`, 400);
  return n;
};
const toStr = (v, name, { required = false, max = 500 } = {}) => {
  if (v === undefined || v === null || v === '') {
    if (required) throw new AppError(`กรุณาระบุ ${name}`, 400);
    return null;
  }
  if (typeof v !== 'string') throw new AppError(`${name} ต้องเป็นข้อความ`, 400);
  const t = v.trim();
  if (t.length > max) throw new AppError(`${name} ยาวเกินกำหนด (ไม่เกิน ${max} ตัวอักษร)`, 400);
  if (required && !t) throw new AppError(`กรุณาระบุ ${name}`, 400);
  return t || null;
};
const toOptInt = (v, name) => {
  if (v === undefined || v === null || v === '') return null;
  const n = Number(v);
  if (!Number.isInteger(n)) throw new AppError(`${name} ต้องเป็นจำนวนเต็ม`, 400);
  return n;
};
const isRealDate = (s) => {
  if (typeof s !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(s)) return false;
  const d = new Date(`${s}T00:00:00Z`);
  return !Number.isNaN(d.getTime()) && d.toISOString().slice(0, 10) === s;
};
const bangkokToday = () => new Date().toLocaleDateString('en-CA', { timeZone: 'Asia/Bangkok' });
const cleanSearch = (v) =>
  typeof v === 'string' ? v.replace(/[^\p{L}\p{N}\p{M}\s_-]/gu, '').trim().slice(0, 50) : '';

const resourceArgs = (body, { create }) => {
  const b = body ?? {};
  const status = toStr(b.status ?? b.resource_status, 'สถานะ', { max: 30 });
  return {
    code: toStr(b.resource_code, 'รหัส', { required: true, max: 50 }),
    name: toStr(b.resource_name, 'ชื่อ', { required: true, max: 255 }),
    location: toStr(b.location, 'สถานที่', { max: 255 }),
    capacity: toOptInt(b.capacity, 'ความจุ'),
    quantity: toOptInt(b.quantity, 'จำนวน'),
    description: toStr(b.description, 'คำอธิบาย', { max: 2000 }),
    status: status ? status.toUpperCase() : create ? 'AVAILABLE' : null,
  };
};

// ---------- ทรัพยากร ----------
export const getOptions = async () => {
  const { categories, statuses } = await repo.fetchOptions();
  return {
    categories,
    statuses,
    // สถานะที่ Admin ตั้งเองได้ (RESERVED/BORROWED ระบบจัดการเอง)
    settable_statuses: ['AVAILABLE', 'BROKEN', 'UNDER_MAINTENANCE', 'OUT_OF_SERVICE'],
  };
};

export const list = async (query) => {
  const paging = parsePagination(query, LIST);
  const filters = parseFilters(query, LIST.filters);
  if (filters.category && !CATEGORIES.includes(filters.category)) {
    throw new AppError('Invalid category', 400, { allowed: CATEGORIES });
  }
  if (filters.resource_status && !STATUSES.includes(filters.resource_status)) {
    throw new AppError('Invalid resource_status', 400, { allowed: STATUSES });
  }
  const { rows, total } = await repo.fetchResourcesPage({ ...paging, filters, search: cleanSearch(query?.q) });
  return { rows, meta: buildMeta({ total, ...paging }) };
};

export const get = async (rawId) => {
  const row = await repo.findResource(toId(rawId));
  if (!row) throw new AppError('ไม่พบทรัพยากรนี้', 404);
  return row;
};

export const create = async (body) => {
  const typeId = toId(body?.type_id, 'หมวดหมู่');
  const args = { ...resourceArgs(body, { create: true }), typeId };
  const created = await run(repo.createResource(args));
  return repo.findResource(created.new_resource_id);
};

// หมวดหมู่เปลี่ยนไม่ได้: ถ้าส่ง type_id มาและไม่ตรงกับของเดิม ปฏิเสธ
export const update = async (rawId, body) => {
  const id = toId(rawId);
  const current = await repo.findResource(id);
  if (!current) throw new AppError('ไม่พบทรัพยากรนี้', 404);
  if (body?.type_id !== undefined && Number(body.type_id) !== current.type_id) {
    throw new AppError('ไม่สามารถเปลี่ยนหมวดหมู่ของทรัพยากรได้', 400);
  }
  await run(repo.updateResource(id, resourceArgs(body, { create: false })));
  return repo.findResource(id);
};

export const remove = async (rawId) => {
  const id = toId(rawId);
  const out = await run(repo.deleteResource(id));
  const result = out?.result;
  const resource = result === 'DEACTIVATED' ? await repo.findResource(id) : null;
  return { result, resource };
};

// ---------- ตารางเวลา ----------
export const listSchedules = async (rawId, query) => {
  const id = toId(rawId);
  if (!(await repo.findResource(id))) throw new AppError('ไม่พบทรัพยากรนี้', 404);
  const paging = parsePagination(query, {
    tieBreaker: 'schedule_id', defaultSort: 'work_date', defaultOrder: 'asc', sortable: ['work_date'],
  });
  const dateFrom = query?.date_from ?? bangkokToday();
  const dateTo = query?.date_to || null;
  if (!isRealDate(dateFrom) || (dateTo && !isRealDate(dateTo))) throw new AppError('รูปแบบวันที่ต้องเป็น YYYY-MM-DD', 400);
  const { rows, total } = await repo.fetchSchedulesPage({ resourceId: id, dateFrom, dateTo, from: paging.from, to: paging.to });
  return { rows, meta: buildMeta({ total, ...paging }) };
};

export const generate = async (rawId, body) => {
  const id = toId(rawId);
  const b = body ?? {};
  if (!isRealDate(b.date_from) || !isRealDate(b.date_to)) throw new AppError('รูปแบบวันที่ต้องเป็น YYYY-MM-DD', 400);
  if (!Array.isArray(b.weekdays) || !b.weekdays.every((w) => Number.isInteger(w))) throw new AppError('weekdays ต้องเป็นอาร์เรย์ของเลข 1-7', 400);
  if (!Array.isArray(b.slots) || !b.slots.every((s) => s && typeof s.start === 'string' && typeof s.end === 'string')) {
    throw new AppError('slots ต้องเป็นอาร์เรย์ของ { start, end }', 400);
  }
  const out = await run(repo.generateSchedules(id, {
    dateFrom: b.date_from,
    dateTo: b.date_to,
    weekdays: [...new Set(b.weekdays)],
    slots: b.slots.map((s) => ({ start: s.start, end: s.end })),
    maxSlots: b.max_slots === undefined ? 1 : toOptInt(b.max_slots, 'max_slots'),
  }));
  return { inserted: out.inserted, skipped: out.skipped };
};

const ownSchedule = async (rawId, rawKind, rawScheduleId) => {
  const id = toId(rawId);
  const kind = String(rawKind ?? '').toUpperCase();
  if (!KINDS.includes(kind)) throw new AppError('ชนิดตารางเวลาต้องเป็น ROOM หรือ PRINTER', 400);
  const scheduleId = toId(rawScheduleId, 'scheduleId');
  const row = await repo.findSchedule(kind, scheduleId);
  if (!row || row.resource_id !== id) throw new AppError('ไม่พบช่วงเวลานี้ในทรัพยากรที่ระบุ', 404);
  return { kind, scheduleId };
};

export const setBlock = async (rawId, rawKind, rawScheduleId, body) => {
  if (typeof body?.blocked !== 'boolean') throw new AppError('blocked ต้องเป็น true หรือ false', 400);
  const { kind, scheduleId } = await ownSchedule(rawId, rawKind, rawScheduleId);
  const out = await run(repo.setScheduleBlock(kind, scheduleId, body.blocked));
  return { schedule_id: scheduleId, kind, schedule_status: out.out_status };
};

export const removeSchedule = async (rawId, rawKind, rawScheduleId) => {
  const { kind, scheduleId } = await ownSchedule(rawId, rawKind, rawScheduleId);
  await run(repo.deleteSchedule(kind, scheduleId));
  return { schedule_id: scheduleId, kind };
};
