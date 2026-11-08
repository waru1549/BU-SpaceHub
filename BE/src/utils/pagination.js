import { AppError } from '../middleware/error.middleware.js';

const parseIntParam = (raw, name, fallback, min, max) => {
  if (raw === undefined) return fallback;
  if (typeof raw !== 'string' || !/^\d+$/.test(raw)) {
    throw new AppError(`${name} must be an integer`, 400);
  }
  const n = Number(raw);
  if (n < min || n > max) throw new AppError(`${name} must be between ${min} and ${max}`, 400);
  return n;
};

// อ่านและตรวจ page / limit / sort / order จาก query string (ค่าไม่ถูกต้อง = 400)
export const parsePagination = (
  query,
  { sortable, defaultSort, defaultOrder = 'asc', defaultLimit = 10, maxLimit = 100 },
) => {
  const page = parseIntParam(query.page, 'page', 1, 1, 1_000_000);
  const limit = parseIntParam(query.limit, 'limit', defaultLimit, 1, maxLimit);

  const sort = query.sort ?? defaultSort;
  if (typeof sort !== 'string' || !sortable.includes(sort)) {
    throw new AppError('Invalid sort column', 400, { allowed: sortable });
  }

  const order = query.order ?? defaultOrder;
  if (order !== 'asc' && order !== 'desc') {
    throw new AppError('order must be asc or desc', 400);
  }

  const from = (page - 1) * limit;
  return { page, limit, from, to: from + limit - 1, sort, order, ascending: order === 'asc' };
};

// รับเฉพาะคอลัมน์ที่อยู่ใน whitelist และต้องเป็นข้อความสั้น ๆ เท่านั้น
export const parseFilters = (query, allowed) => {
  const filters = {};
  for (const col of allowed) {
    const v = query[col];
    if (v === undefined) continue;
    if (typeof v !== 'string' || v.length === 0 || v.length > 50) {
      throw new AppError(`Invalid filter: ${col}`, 400);
    }
    filters[col] = v;
  }
  return filters;
};

export const buildMeta = ({ total, page, limit, sort, order }) => ({
  total,
  page,
  limit,
  totalPages: Math.max(1, Math.ceil(total / limit)),
  sort,
  order,
});