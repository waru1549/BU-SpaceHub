// ป้ายสถานะการจอง (ใช้ร่วมกันทุกโมดูล) ต้องมีข้อความกำกับเสมอ ไม่พึ่งสีอย่างเดียว
export const BOOKING_STATUS = {
  PENDING: { label: 'รออนุมัติ', tone: 'bg-amber-50 text-amber-900' },
  APPROVED: { label: 'อนุมัติแล้ว', tone: 'bg-emerald-50 text-emerald-800' },
  REJECTED: { label: 'ไม่อนุมัติ', tone: 'bg-red-50 text-red-800' },
  COMPLETED: { label: 'เสร็จสิ้น', tone: 'bg-indigo-50 text-indigo-800' },
  CANCELLED: { label: 'ยกเลิกแล้ว', tone: 'bg-slate-100 text-slate-700' },
};

export const BOOKING_STATUS_OPTIONS = [
  ['', 'ทุกสถานะ'],
  ...Object.entries(BOOKING_STATUS).map(([value, { label }]) => [value, label]),
];

// สถานะของห้องที่ไม่พร้อมใช้งาน
export const ROOM_UNAVAILABLE_LABEL = {
  BROKEN: 'ชำรุด',
  UNDER_MAINTENANCE: 'ปิดซ่อมบำรุง',
  OUT_OF_SERVICE: 'งดให้บริการ',
};