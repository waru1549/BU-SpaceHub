import { BOOKING_STATUS, STATUS_LABEL_BY_VARIANT } from '../../utils/booking.js';

// variant="printer" | "equipment" ใช้ข้อความเฉพาะของโมดูล (เช่น RECEIVED = กำลังยืม)
export default function StatusBadge({ status, variant }) {
  const base = BOOKING_STATUS[status] ?? { label: status, tone: 'bg-slate-100 text-slate-700' };
  const label = STATUS_LABEL_BY_VARIANT[variant]?.[status] ?? base.label;
  return (
    <span className={`inline-block whitespace-nowrap rounded-full px-2.5 py-0.5 text-xs font-semibold ${base.tone}`}>
      {label}
    </span>
  );
}