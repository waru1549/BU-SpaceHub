import { AppError } from '../middleware/error.middleware.js';
import * as repo from '../repositories/adminUsers.repository.js';
import { buildMeta, parseFilters, parsePagination } from '../utils/pagination.js';

const ROLES = ['USER', 'STAFF', 'ADMIN'];
const STATUSES = ['ACTIVE', 'INACTIVE', 'SUSPENDED'];

const LIST = {
  tieBreaker: 'user_id',
  defaultSort: 'created_at',
  defaultOrder: 'desc',
  sortable: ['full_name', 'email', 'role', 'user_status', 'booking_count', 'last_login', 'created_at'],
  filters: ['role', 'user_status'],
};

const ERRORS = {
  ROLE_INVALID: [400, 'บทบาทไม่ถูกต้อง'],
  STATUS_INVALID: [400, 'สถานะไม่ถูกต้อง'],
  SELF_CHANGE: [400, 'ไม่สามารถเปลี่ยนบทบาทหรือสถานะของบัญชีตัวเองได้'],
  USER_NOT_FOUND: [404, 'ไม่พบผู้ใช้นี้'],
  ACTOR_NOT_ADMIN: [403, 'บัญชีของคุณไม่มีสิทธิ์ผู้ดูแลระบบที่ใช้งานอยู่แล้ว'],
  LAST_ADMIN: [409, 'ต้องมีผู้ดูแลระบบที่ใช้งานอยู่อย่างน้อย 1 คน จึงทำรายการนี้ไม่ได้'],
  HAS_ACTIVE_BOOKINGS: [409, 'ผู้ใช้นี้ยังมีรายการที่รอดำเนินการหรือกำลังใช้งานอยู่ จึงระงับหรือปิดบัญชีไม่ได้ กรุณาให้รายการเหล่านั้นเสร็จสิ้นหรือยกเลิกก่อน'],
};

const run = async (promise) => {
  const { error } = await promise;
  if (error) {
    const hit = ERRORS[error.message];
    if (hit) throw new AppError(hit[1], hit[0]);
    throw new AppError('Database operation failed', 500, error);
  }
};

const toId = (raw, name = 'id') => {
  const n = Number(raw);
  if (!Number.isInteger(n) || n < 1) throw new AppError(`${name} ไม่ถูกต้อง`, 400);
  return n;
};

// เก็บตัวอักษร/ตัวเลข/ช่องว่าง และ _ - @ . (สำหรับค้นอีเมล) ตัดอักขระพิเศษที่อาจทำให้ตัวกรอง PostgREST เพี้ยน
const cleanSearch = (v) =>
  typeof v === 'string' ? v.replace(/[^\p{L}\p{N}\p{M}\s_@.-]/gu, '').trim().slice(0, 60) : '';

const upper = (v) => (typeof v === 'string' ? v.trim().toUpperCase() : '');

export const getOptions = async () => ({
  roles: await repo.fetchRoles(),
  statuses: STATUSES,
});

export const list = async (query) => {
  const paging = parsePagination(query, LIST);
  const filters = parseFilters(query, LIST.filters);
  if (filters.role && !ROLES.includes(filters.role)) throw new AppError('Invalid role', 400, { allowed: ROLES });
  if (filters.user_status && !STATUSES.includes(filters.user_status)) {
    throw new AppError('Invalid user_status', 400, { allowed: STATUSES });
  }
  const { rows, total } = await repo.fetchUsersPage({ ...paging, filters, search: cleanSearch(query?.q) });
  return { rows, meta: buildMeta({ total, ...paging }) };
};

export const get = async (rawId) => {
  const row = await repo.findUser(toId(rawId));
  if (!row) throw new AppError('ไม่พบผู้ใช้นี้', 404);
  return row;
};

export const changeRole = async (actor, rawId, body) => {
  const id = toId(rawId);
  const role = upper(body?.role);
  if (!ROLES.includes(role)) throw new AppError('บทบาทไม่ถูกต้อง (USER, STAFF หรือ ADMIN)', 400);
  await run(repo.setRole(actor.userId, id, role));
  return repo.findUser(id);
};

export const changeStatus = async (actor, rawId, body) => {
  const id = toId(rawId);
  const status = upper(body?.status);
  if (!STATUSES.includes(status)) throw new AppError('สถานะไม่ถูกต้อง (ACTIVE, INACTIVE หรือ SUSPENDED)', 400);
  await run(repo.setStatus(actor.userId, id, status));
  return repo.findUser(id);
};
