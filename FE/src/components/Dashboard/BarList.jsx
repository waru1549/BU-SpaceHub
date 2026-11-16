import { formatNumber } from '../../utils/dashboard.js';

// แท่งแนวนอน: ข้อความและตัวเลขแสดงเสมอ (แท่งเป็นแค่ภาพประกอบ) | items = [{ key, label, value, note }]
export default function BarList({ items, color, emptyText = 'ยังไม่มีข้อมูล', formatValue = formatNumber }) {
  if (!items || items.length === 0) {
    return <p className="py-6 text-center text-sm text-slate-600">{emptyText}</p>;
  }
  const max = Math.max(...items.map((i) => i.value), 1);
  return (
    <ul className="space-y-3">
      {items.map((item) => (
        <li key={item.key}>
          <div className="mb-1 flex items-baseline justify-between gap-3 text-sm">
            <span className="min-w-0 truncate font-medium text-slate-800">{item.label}</span>
            <span className="shrink-0 font-semibold text-slate-900">{formatValue(item.value)}</span>
          </div>
          <div aria-hidden="true" className="h-2.5 overflow-hidden rounded-full bg-slate-100">
            <div
              className="h-full rounded-full"
              style={{ width: `${item.value > 0 ? Math.max(2, (item.value / max) * 100) : 0}%`, background: color }}
            />
          </div>
          {item.note && <p className="mt-1 text-xs text-slate-600">{item.note}</p>}
        </li>
      ))}
    </ul>
  );
}
