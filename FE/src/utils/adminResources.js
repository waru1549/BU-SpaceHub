// ค่าคงที่และตัวช่วยของหน้า Admin จัดการทรัพยากร

export const CATEGORY_LABEL = {
  ROOM: 'ห้อง',
  PRINTER: 'เครื่องพิมพ์ 3D',
  EQUIPMENT: 'อุปกรณ์',
  MAINTENANCE: 'สิ่งอำนวยความสะดวก',
};

export const RESOURCE_STATUS_LABEL = {
  AVAILABLE: 'พร้อมใช้งาน',
  RESERVED: 'จองแล้ว',
  BORROWED: 'ถูกยืม',
  BROKEN: 'ชำรุด',
  UNDER_MAINTENANCE: 'ปิดซ่อมบำรุง',
  OUT_OF_SERVICE: 'งดให้บริการ',
};

// สีต้องเขียนเต็มคลาส | ข้อความสถานะแสดงเสมอ ไม่พึ่งสีอย่างเดียว
export const RESOURCE_STATUS_STYLE = {
  AVAILABLE: 'bg-emerald-100 text-emerald-900',
  RESERVED: 'bg-amber-100 text-amber-900',
  BORROWED: 'bg-amber-100 text-amber-900',
  BROKEN: 'bg-red-100 text-red-900',
  UNDER_MAINTENANCE: 'bg-sky-100 text-sky-900',
  OUT_OF_SERVICE: 'bg-slate-200 text-slate-800',
};

// สถานะที่ระบบจัดการเอง Admin ตั้งเองไม่ได้ (แต่เลือกคงค่าเดิมได้)
export const SYSTEM_STATUSES = ['RESERVED', 'BORROWED'];

export const SCHEDULE_KINDS = ['ROOM', 'PRINTER'];
export const hasSchedule = (category) => SCHEDULE_KINDS.includes(category);

export const RESOURCE_STATUS_FILTER = [
  ['', 'ทุกสถานะ'],
  ['AVAILABLE', 'พร้อมใช้งาน'],
  ['BROKEN', 'ชำรุด'],
  ['UNDER_MAINTENANCE', 'ปิดซ่อมบำรุง'],
  ['OUT_OF_SERVICE', 'งดให้บริการ'],
  ['RESERVED', 'จองแล้ว'],
  ['BORROWED', 'ถูกยืม'],
];

export const WEEKDAYS = [
  { iso: 1, label: 'จันทร์' },
  { iso: 2, label: 'อังคาร' },
  { iso: 3, label: 'พุธ' },
  { iso: 4, label: 'พฤหัสบดี' },
  { iso: 5, label: 'ศุกร์' },
  { iso: 6, label: 'เสาร์' },
  { iso: 7, label: 'อาทิตย์' },
];

export const SCHEDULE_STATUS_LABEL = { AVAILABLE: 'เปิดให้จอง', BLOCKED: 'ปิดกั้น' };
export const MAX_RANGE_DAYS = 92;
export const MAX_SLOTS_PER_DAY = 12;
export const DEFAULT_SLOTS = [
  { start: '09:00', end: '11:00' },
  { start: '13:00', end: '15:00' },
  { start: '15:00', end: '17:00' },
];

// ---------- วันที่ (ใช้เวลาไทย, ไม่พึ่งไลบรารี) ----------
export const todayBangkok = () => new Date().toLocaleDateString('en-CA', { timeZone: 'Asia/Bangkok' });
const toUtc = (iso) => new Date(`${iso}T00:00:00Z`);
export const addDays = (iso, n) => {
  const d = toUtc(iso);
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
};
export const diffDays = (from, to) => Math.round((toUtc(to) - toUtc(from)) / 86400000);
export const isoWeekday = (iso) => ((toUtc(iso).getUTCDay() + 6) % 7) + 1; // 1=จันทร์ ... 7=อาทิตย์
export const timeText = (t) => String(t ?? '').slice(0, 5);

// ---------- ตรวจฟอร์มทรัพยากร (กติกาเดียวกับฐานข้อมูล) ----------
export const validateResource = (v, { category, isEdit, needCapacity, needQuantity }) => {
  const e = {};
  const code = v.resource_code.trim();
  if (!/^[A-Za-z0-9_-]{2,50}$/.test(code)) e.resource_code = 'รหัสใช้ A-Z ตัวเลข _ หรือ - ยาว 2-50 ตัวอักษร (ห้ามเว้นวรรค)';
  const name = v.resource_name.trim();
  if (name.length < 2 || name.length > 255) e.resource_name = 'ชื่อต้องยาว 2-255 ตัวอักษร';
  if (!isEdit && !v.type_id) e.type_id = 'กรุณาเลือกหมวดหมู่';
  if (v.location.trim().length > 255) e.location = 'สถานที่ไม่เกิน 255 ตัวอักษร';
  if (v.description.trim().length > 2000) e.description = 'คำอธิบายไม่เกิน 2,000 ตัวอักษร';

  const intIn = (s, min, max) => /^\d+$/.test(String(s).trim()) && Number(s) >= min && Number(s) <= max;
  if (needCapacity || String(v.capacity).trim()) {
    if (!intIn(v.capacity, 1, 1000)) e.capacity = category === 'ROOM' && !String(v.capacity).trim() ? 'ห้องต้องระบุความจุ' : 'ความจุต้องเป็นจำนวนเต็ม 1-1000';
  }
  if (needQuantity || String(v.quantity).trim()) {
    if (!intIn(v.quantity, 1, 10000)) e.quantity = category === 'EQUIPMENT' && !String(v.quantity).trim() ? 'อุปกรณ์ต้องระบุจำนวน' : 'จำนวนต้องเป็นจำนวนเต็ม 1-10000';
  }
  return e;
};

// ---------- ตรวจฟอร์มสร้างตารางเวลา ----------
export const validateGenerator = ({ dateFrom, dateTo, weekdays, slots, maxSlots }) => {
  const errors = [];
  const today = todayBangkok();
  if (!dateFrom || !dateTo) errors.push('กรุณาเลือกวันที่เริ่มและวันที่สิ้นสุด');
  else {
    if (dateFrom < today) errors.push('วันที่เริ่มต้องไม่ย้อนหลัง');
    if (dateTo < dateFrom) errors.push('วันที่สิ้นสุดต้องไม่ก่อนวันที่เริ่ม');
    else if (diffDays(dateFrom, dateTo) > MAX_RANGE_DAYS) errors.push(`สร้างได้ครั้งละไม่เกิน ${MAX_RANGE_DAYS} วัน`);
  }
  if (weekdays.length === 0) errors.push('กรุณาเลือกวันในสัปดาห์อย่างน้อย 1 วัน');
  if (slots.length === 0) errors.push('กรุณาเพิ่มช่วงเวลาอย่างน้อย 1 ช่วง');
  if (slots.length > MAX_SLOTS_PER_DAY) errors.push(`เพิ่มได้ไม่เกิน ${MAX_SLOTS_PER_DAY} ช่วงต่อวัน`);
  if (slots.some((s) => !s.start || !s.end)) errors.push('กรุณากรอกเวลาเริ่มและสิ้นสุดให้ครบทุกช่วง');
  else {
    if (slots.some((s) => s.end <= s.start)) errors.push('เวลาสิ้นสุดต้องหลังเวลาเริ่มในทุกช่วง');
    const sorted = [...slots].sort((a, b) => a.start.localeCompare(b.start));
    if (sorted.some((s, i) => i > 0 && s.start < sorted[i - 1].end)) errors.push('ช่วงเวลาซ้อนทับกัน');
  }
  if (!/^\d+$/.test(String(maxSlots)) || Number(maxSlots) < 1 || Number(maxSlots) > 20) errors.push('จำนวนที่รับต่อช่วงต้องเป็น 1-20');
  return errors;
};

// จำนวนช่วงสูงสุดที่จะถูกสร้าง (ยังไม่หักช่วงที่ซ้ำ/ซ้อนทับของเดิม)
export const countPlanned = ({ dateFrom, dateTo, weekdays, slots }) => {
  if (!dateFrom || !dateTo || dateTo < dateFrom || diffDays(dateFrom, dateTo) > MAX_RANGE_DAYS) return 0;
  let days = 0;
  for (let i = 0; i <= diffDays(dateFrom, dateTo); i += 1) {
    if (weekdays.includes(isoWeekday(addDays(dateFrom, i)))) days += 1;
  }
  return days * slots.length;
};

export const formatDay = (iso) =>
  new Date(`${String(iso).slice(0, 10)}T00:00:00Z`).toLocaleDateString('th-TH', {
    timeZone: 'UTC', weekday: 'short', day: 'numeric', month: 'short', year: 'numeric',
  });
