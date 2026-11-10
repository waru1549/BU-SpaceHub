import { BOOKING_STATUS, PRINTER_STATUS_LABEL } from '../../utils/booking.js';

// variant="printer" ใช้ข้อความเฉพาะของเครื่องพิมพ์ (เช่น COMPLETED = พิมพ์เสร็จ รอรับงาน)
export default function StatusBadge({ status, variant }) {
  const base = BOOKING_STATUS[status] ?? { label: status, tone: 'bg-slate-100 text-slate-700' };
  const label = (variant === 'printer' && PRINTER_STATUS_LABEL[status]) || base.label;
  return (
    <span className={`inline-block whitespace-nowrap rounded-full px-2.5 py-0.5 text-xs font-semibold ${base.tone}`}>
      {label}
    </span>
  );
}