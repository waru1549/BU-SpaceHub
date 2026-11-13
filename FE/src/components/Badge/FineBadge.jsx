const FINE_STATUS = {
  UNPAID: { label: 'ค้างชำระ', tone: 'bg-red-50 text-red-800' },
  PAID: { label: 'ชำระแล้ว', tone: 'bg-emerald-50 text-emerald-800' },
  WAIVED: { label: 'ยกเว้น', tone: 'bg-slate-100 text-slate-700' },
};

export const FINE_STATUS_OPTIONS = [
  ['', 'ทุกสถานะ'],
  ...Object.entries(FINE_STATUS).map(([value, { label }]) => [value, label]),
];

export default function FineBadge({ status }) {
  const { label, tone } = FINE_STATUS[status] ?? { label: status, tone: 'bg-slate-100 text-slate-700' };
  return (
    <span className={`inline-block whitespace-nowrap rounded-full px-2.5 py-0.5 text-xs font-semibold ${tone}`}>
      {label}
    </span>
  );
}
