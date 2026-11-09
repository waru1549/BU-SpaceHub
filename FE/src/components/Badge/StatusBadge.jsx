import { BOOKING_STATUS } from '../../utils/booking.js';

export default function StatusBadge({ status }) {
  const { label, tone } = BOOKING_STATUS[status] ?? { label: status, tone: 'bg-slate-100 text-slate-700' };
  return (
    <span className={`inline-block whitespace-nowrap rounded-full px-2.5 py-0.5 text-xs font-semibold ${tone}`}>
      {label}
    </span>
  );
}