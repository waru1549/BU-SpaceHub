import { formatNumber } from '../../utils/dashboard.js';

// แท่งแนวตั้งรายเดือนของระบบเดียว | items = [{ key, label, value }] | ตัวเลขอยู่เหนือแท่งเสมอ
const PLOT = 160;

export default function ColumnChart({ items, color, unit = 'รายการ', emptyText = 'ยังไม่มีข้อมูลรายเดือน' }) {
  if (!items || items.length === 0) {
    return <p className="py-10 text-center text-sm text-slate-600">{emptyText}</p>;
  }
  const max = Math.max(...items.map((i) => i.value), 1);
  return (
    <div className="overflow-x-auto" role="region" aria-label="กราฟแท่งรายเดือน เลื่อนแนวนอนได้" tabIndex={0}>
      <ul className="flex min-w-full items-end gap-2" style={{ minWidth: items.length * 56 }}>
        {items.map((item) => (
          <li
            key={item.key}
            aria-label={`${item.label}: ${formatNumber(item.value)} ${unit}`}
            className="flex min-w-12 flex-1 flex-col items-center justify-end"
          >
            <span className="mb-1 text-xs font-semibold text-slate-900">{formatNumber(item.value)}</span>
            <div
              aria-hidden="true"
              className="w-full max-w-10 rounded-t-md"
              style={{ height: Math.max(item.value > 0 ? 4 : 0, (item.value / max) * PLOT), background: color }}
            />
            <span className="mt-1 whitespace-nowrap border-t border-slate-300 pt-1 text-xs text-slate-600">{item.label}</span>
          </li>
        ))}
      </ul>
    </div>
  );
}
