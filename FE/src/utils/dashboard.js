import { AlertTriangle, Banknote, Calendar, Check, ClipboardCheck, Clock, Package, Printer, Wrench } from 'lucide-react';

// สีทุกคลาสต้องเขียนเต็ม (Tailwind สแกนจากข้อความ) | สีกราฟตรงกับ MODULES ใน MonthlyTrendChart
export const SYSTEMS = [
  {
    key: 'overview', label: 'ภาพรวม', api: null, variant: undefined, color: '#475569',
    active: 'bg-slate-800 text-white', ring: 'focus-visible:outline-slate-700',
    tabActive: 'border-slate-700 text-slate-900',
  },
  {
    key: 'room', label: 'จองห้อง', api: 'ROOM', variant: undefined, color: '#4f46e5',
    active: 'bg-indigo-700 text-white', ring: 'focus-visible:outline-indigo-600',
    tabActive: 'border-indigo-600 text-indigo-900',
  },
  {
    key: 'printer', label: 'เครื่องพิมพ์ 3D', api: 'PRINTER', variant: 'printer', color: '#059669',
    active: 'bg-emerald-700 text-white', ring: 'focus-visible:outline-emerald-600',
    tabActive: 'border-emerald-600 text-emerald-900',
  },
  {
    key: 'equipment', label: 'ยืม-คืนอุปกรณ์', api: 'EQUIPMENT', variant: 'equipment', color: '#b45309',
    active: 'bg-amber-700 text-white', ring: 'focus-visible:outline-amber-600',
    tabActive: 'border-amber-600 text-amber-900',
  },
  {
    key: 'maintenance', label: 'แจ้งซ่อม', api: 'MAINTENANCE', variant: 'maintenance', color: '#0284c7',
    active: 'bg-sky-700 text-white', ring: 'focus-visible:outline-sky-600',
    tabActive: 'border-sky-600 text-sky-900',
  },
];

export const SYSTEM_KEYS = SYSTEMS.map((s) => s.key);
export const getSystemConfig = (key) => SYSTEMS.find((s) => s.key === key) ?? SYSTEMS[0];

// แท็บเนื้อหาภายในแต่ละระบบ (ยกเว้นภาพรวม)
export const CONTENT_TABS = [
  { key: 'summary', label: 'ภาพรวม' },
  { key: 'recent', label: 'รายการล่าสุด / ต้องดำเนินการ' },
  { key: 'usage', label: 'การใช้งานทรัพยากร' },
  { key: 'stats', label: 'สถิติเฉพาะระบบ' },
];
export const CONTENT_TAB_KEYS = CONTENT_TABS.map((t) => t.key);

// KPI รายระบบ: key ตรงกับ kpi_key จาก /api/dashboard/system/:module
// format: number | baht | percent | days
const TONE = {
  indigo: 'bg-indigo-50 text-indigo-700',
  emerald: 'bg-emerald-50 text-emerald-800',
  amber: 'bg-amber-50 text-amber-800',
  sky: 'bg-sky-50 text-sky-800',
  red: 'bg-red-50 text-red-700',
  slate: 'bg-slate-100 text-slate-700',
};

export const SYSTEM_KPIS = {
  room: [
    { key: 'total', label: 'การจองทั้งหมด', format: 'number', icon: Calendar, tone: TONE.indigo },
    { key: 'pending', label: 'รออนุมัติ', format: 'number', icon: ClipboardCheck, tone: TONE.amber },
    { key: 'upcoming', label: 'จองล่วงหน้า (อนุมัติแล้ว)', format: 'number', icon: Clock, tone: TONE.slate },
    { key: 'avg_utilization_pct', label: 'การใช้ห้องเฉลี่ย', format: 'percent', icon: Check, tone: TONE.indigo },
  ],
  printer: [
    { key: 'total', label: 'งานพิมพ์ทั้งหมด', format: 'number', icon: Printer, tone: TONE.emerald },
    { key: 'pending', label: 'รออนุมัติ', format: 'number', icon: ClipboardCheck, tone: TONE.amber },
    { key: 'in_progress', label: 'กำลังพิมพ์', format: 'number', icon: Clock, tone: TONE.slate },
    { key: 'awaiting_pickup', label: 'พิมพ์เสร็จ รอรับงาน', format: 'number', icon: Check, tone: TONE.emerald },
  ],
  equipment: [
    { key: 'on_loan', label: 'กำลังยืม', format: 'number', icon: Package, tone: TONE.amber },
    { key: 'overdue', label: 'เกินกำหนดคืน', format: 'number', icon: AlertTriangle, tone: TONE.red },
    { key: 'pending', label: 'รออนุมัติ', format: 'number', icon: ClipboardCheck, tone: TONE.slate },
    { key: 'unpaid_fines', label: 'ค่าปรับค้างชำระ', format: 'baht', icon: Banknote, tone: TONE.red },
  ],
  maintenance: [
    { key: 'pending', label: 'รอรับเรื่อง', format: 'number', icon: ClipboardCheck, tone: TONE.amber },
    { key: 'in_progress', label: 'กำลังซ่อม', format: 'number', icon: Wrench, tone: TONE.sky },
    { key: 'completed_30d', label: 'ซ่อมเสร็จใน 30 วัน', format: 'number', icon: Check, tone: TONE.slate },
    { key: 'avg_repair_days', label: 'ใช้เวลาซ่อมเฉลี่ย (วัน)', format: 'days', icon: Clock, tone: TONE.sky },
  ],
};

export const formatDecimal = (value, digits = 1) =>
  value === null || value === undefined || Number.isNaN(Number(value))
    ? '-'
    : Number(value).toLocaleString('th-TH', { maximumFractionDigits: digits });

export const formatPercent = (value) => (value === null || value === undefined ? '-' : `${formatDecimal(value, 1)}%`);

// ข้อความไทยของค่ากลุ่มในสถิติเฉพาะระบบ
export const FINE_STATUS_TEXT = { UNPAID: 'ค้างชำระ', PAID: 'ชำระแล้ว', WAIVED: 'ยกเว้น' };
export const REPAIR_CATEGORY_TEXT = {
  ROOM: 'ห้อง',
  PRINTER: 'เครื่องพิมพ์ 3D',
  EQUIPMENT: 'อุปกรณ์',
  MAINTENANCE: 'สิ่งอำนวยความสะดวก',
  OTHER: 'สถานที่อื่น (พิมพ์เอง)',
};
export const RESOURCE_STATUS_TEXT = {
  AVAILABLE: 'พร้อมใช้งาน',
  RESERVED: 'จองแล้ว',
  BROKEN: 'ชำรุด',
  UNDER_MAINTENANCE: 'ปิดซ่อมบำรุง',
  OUT_OF_SERVICE: 'งดให้บริการ',
};
export const RECENT_DATE_LABEL = {
  ROOM: 'วันที่ใช้ห้อง',
  PRINTER: 'วันที่พิมพ์',
  EQUIPMENT: 'วันที่ยืม',
  MAINTENANCE: 'วันที่แจ้ง',
};

export const formatNumber = (value) =>
  value === null || value === undefined || Number.isNaN(Number(value)) ? '-' : Number(value).toLocaleString('th-TH');

// '2026-11' -> 'พ.ย. 69' (ใช้ปีพุทธศักราช 2 หลัก)
const MONTHS_TH = ['ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'];
export const formatMonth = (label) => {
  const [y, m] = String(label ?? '').split('-').map(Number);
  if (!y || !m) return String(label ?? '-');
  return `${MONTHS_TH[m - 1]} ${String(y + 543).slice(-2)}`;
};
