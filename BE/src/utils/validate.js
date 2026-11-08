import { AppError } from '../middleware/error.middleware.js';

// รับเลขจำนวนเต็มบวก (ทั้งแบบตัวเลขและข้อความตัวเลข) ไม่งั้น 400
export const toPositiveInt = (value, name) => {
  const s = typeof value === 'number' ? String(value) : value;
  if (typeof s !== 'string' || !/^\d{1,15}$/.test(s) || Number(s) < 1) {
    throw new AppError(`${name} must be a positive integer`, 400);
  }
  return Number(s);
};

// รับวันที่รูปแบบ YYYY-MM-DD ที่มีอยู่จริงในปฏิทิน (ปฏิเสธ 2026-02-30)
export const toIsoDate = (value, name = 'date') => {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    throw new AppError(`${name} must be in YYYY-MM-DD format`, 400);
  }
  const d = new Date(`${value}T00:00:00Z`);
  if (Number.isNaN(d.getTime()) || d.toISOString().slice(0, 10) !== value) {
    throw new AppError(`${name} is not a valid date`, 400);
  }
  return value;
};

// ข้อความที่ตัดช่องว่างหัวท้ายแล้ว ความยาวอยู่ในช่วง min-max
export const toText = (value, name, { min, max }) => {
  if (typeof value !== 'string') throw new AppError(`${name} is required`, 400);
  const text = value.trim();
  if (text.length < min || text.length > max) {
    throw new AppError(`${name} must be ${min}-${max} characters`, 400);
  }
  return text;
};