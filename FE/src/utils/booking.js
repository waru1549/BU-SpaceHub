// ป้ายสถานะการจอง (ใช้ร่วมกันทุกโมดูล) ต้องมีข้อความกำกับเสมอ ไม่พึ่งสีอย่างเดียว
export const BOOKING_STATUS = {
  PENDING: { label: 'รออนุมัติ', tone: 'bg-amber-50 text-amber-900' },
  APPROVED: { label: 'อนุมัติแล้ว', tone: 'bg-emerald-50 text-emerald-800' },
  REJECTED: { label: 'ไม่อนุมัติ', tone: 'bg-red-50 text-red-800' },
  IN_PROGRESS: { label: 'กำลังพิมพ์', tone: 'bg-violet-50 text-violet-800' },
  COMPLETED: { label: 'เสร็จสิ้น', tone: 'bg-indigo-50 text-indigo-800' },
  RECEIVED: { label: 'รับงานแล้ว', tone: 'bg-teal-50 text-teal-900' },
  CANCELLED: { label: 'ยกเลิกแล้ว', tone: 'bg-slate-100 text-slate-700' },
};

// เครื่องพิมพ์: COMPLETED หมายถึงพิมพ์เสร็จ รอผู้ใช้มารับงาน
export const PRINTER_STATUS_LABEL = {
  COMPLETED: 'พิมพ์เสร็จ รอรับงาน',
};

const toOptions = (keys, labels = {}) => [
  ['', 'ทุกสถานะ'],
  ...keys.map((key) => [key, labels[key] ?? BOOKING_STATUS[key].label]),
];

export const BOOKING_STATUS_OPTIONS = toOptions([
  'PENDING',
  'APPROVED',
  'REJECTED',
  'COMPLETED',
  'CANCELLED',
]);

export const PRINTER_STATUS_OPTIONS = toOptions(
  ['PENDING', 'APPROVED', 'IN_PROGRESS', 'COMPLETED', 'RECEIVED', 'REJECTED', 'CANCELLED'],
  PRINTER_STATUS_LABEL,
);

// สถานะของทรัพยากร (ห้อง/เครื่อง) ที่ไม่พร้อมใช้งาน
export const ROOM_UNAVAILABLE_LABEL = {
  BROKEN: 'ชำรุด',
  UNDER_MAINTENANCE: 'ปิดซ่อมบำรุง',
  OUT_OF_SERVICE: 'งดให้บริการ',
};