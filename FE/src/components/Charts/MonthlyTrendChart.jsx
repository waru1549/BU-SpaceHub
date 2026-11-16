import { useEffect, useMemo, useRef, useState } from 'react';
import { AlertCircle } from 'lucide-react';
import { formatMonth, formatNumber } from '../../utils/format.js';

// สีผ่าน validator แล้ว (แยกสีสำหรับตาบอดสีและ contrast >= 3:1 บนพื้นขาว)
export const MODULES = [
  { key: 'ROOM', label: 'จองห้อง', color: '#4f46e5' },
  { key: 'PRINTER', label: 'เครื่องพิมพ์ 3D', color: '#059669' },
  { key: 'EQUIPMENT', label: 'ยืม-คืนอุปกรณ์', color: '#b45309' },
  { key: 'MAINTENANCE', label: 'แจ้งซ่อม', color: '#0284c7' },
];

const HEIGHT = 280;
const M = { top: 12, right: 12, bottom: 34, left: 40 };
const PLOT_H = HEIGHT - M.top - M.bottom;
const BAR_GAP = 2; // ช่องว่าง 2px ระหว่างแท่งในกลุ่ม
const MIN_GROUP_W = 72; // ความกว้างต่อเดือนขั้นต่ำ ถ้าน้อยกว่านี้ให้เลื่อนแนวนอน
const MAX_MONTHS = 12;

const focusRing =
  'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-500';

const niceStep = (max) => {
  if (max <= 0) return 1;
  const rough = max / 4;
  const pow = 10 ** Math.floor(Math.log10(rough));
  const n = rough / pow;
  return (n <= 1 ? 1 : n <= 2 ? 2 : n <= 5 ? 5 : 10) * pow;
};

// แท่งมุมบนมน 4px ปลายล่างเรียบติดเส้นฐาน
const barPath = (x, yBase, w, h) => {
  const r = Math.min(4, w / 2, h);
  return `M${x},${yBase}V${yBase - h + r}a${r},${r} 0 0 1 ${r},${-r}H${x + w - r}a${r},${r} 0 0 1 ${r},${r}V${yBase}Z`;
};

export default function MonthlyTrendChart({ rows, loading, error, onRetry }) {
  const [active, setActive] = useState(null);
  const [asTable, setAsTable] = useState(false);
  const [boxW, setBoxW] = useState(0);
  const wrapRef = useRef(null);

  // วัดความกว้างจริงของการ์ด เพื่อวาดกราฟขนาด 1:1 (ตัวอักษรไม่ถูกขยาย)
  useEffect(() => {
    const el = wrapRef.current;
    if (!el) return undefined;
    const ro = new ResizeObserver(([entry]) => setBoxW(Math.floor(entry.contentRect.width)));
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  const months = useMemo(() => {
    const map = new Map();
    for (const r of rows ?? []) {
      if (!map.has(r.month_label)) map.set(r.month_label, { label: r.month_label });
      map.get(r.month_label)[r.module] = Number(r.total_bookings);
    }
    return [...map.values()].sort((a, b) => a.label.localeCompare(b.label)).slice(-MAX_MONTHS);
  }, [rows]);

  const n = months.length;
  const width = Math.max(boxW, M.left + M.right + n * MIN_GROUP_W);
  const groupW = n > 0 ? (width - M.left - M.right) / n : MIN_GROUP_W;
  const barW = Math.max(10, Math.min(24, Math.floor((groupW * 0.6 - BAR_GAP * (MODULES.length - 1)) / MODULES.length)));
  const clusterW = MODULES.length * barW + (MODULES.length - 1) * BAR_GAP;

  const maxValue = Math.max(0, ...months.flatMap((m) => MODULES.map((mod) => m[mod.key] ?? 0)));
  const step = niceStep(maxValue);
  const yMax = Math.max(step * 4, step * Math.ceil(maxValue / step));
  const ticks = Array.from({ length: Math.round(yMax / step) + 1 }, (_, i) => i * step);
  const yBase = HEIGHT - M.bottom;
  const y = (v) => yBase - (v / yMax) * PLOT_H;

  const summary = (m) =>
    `${formatMonth(m.label)}: ${MODULES.map((mod) => `${mod.label} ${m[mod.key] ?? 0}`).join(', ')}`;

  const activeMonth = active === null ? null : months[active];

  let body;
  if (loading) {
    body = (
      <div
        aria-hidden="true"
        className="h-70 animate-pulse rounded-xl bg-slate-100 motion-reduce:animate-none"
      />
    );
  } else if (error) {
    body = (
      <div role="alert" className="flex flex-col items-center gap-3 py-12 text-slate-700">
        <AlertCircle className="h-8 w-8 text-red-700" aria-hidden="true" />
        <p>{error}</p>
        <button
          type="button"
          onClick={onRetry}
          className={`rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700 ${focusRing}`}
        >
          ลองอีกครั้ง
        </button>
      </div>
    );
  } else if (n === 0) {
    body = <p className="py-12 text-center text-slate-600">ยังไม่มีข้อมูลรายเดือน</p>;
  } else if (asTable) {
    body = (
      <div className="max-h-88 overflow-auto" role="region" aria-label="ตารางข้อมูลแนวโน้มรายเดือน" tabIndex={0}>
        <table className="w-full min-w-lg border-separate border-spacing-0 text-sm">
          <caption className="sr-only">จำนวนรายการรายเดือนแยกตามโมดูล</caption>
          <thead>
            <tr>
              <th scope="col" className="sticky top-0 border-b border-slate-200 bg-slate-50 px-4 py-3 text-left text-xs font-semibold text-slate-600">
                เดือน
              </th>
              {MODULES.map((mod) => (
                <th key={mod.key} scope="col" className="sticky top-0 whitespace-nowrap border-b border-slate-200 bg-slate-50 px-4 py-3 text-right text-xs font-semibold text-slate-600">
                  {mod.label}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {months.map((m) => (
              <tr key={m.label} className="hover:bg-slate-50">
                <th scope="row" className="border-b border-slate-100 px-4 py-3 text-left font-medium text-slate-800">
                  {formatMonth(m.label)}
                </th>
                {MODULES.map((mod) => (
                  <td key={mod.key} className="border-b border-slate-100 px-4 py-3 text-right text-slate-800">
                    {formatNumber(m[mod.key] ?? 0)}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    );
  } else {
    const tipCenter = M.left + active * groupW + groupW / 2;
    const tipShift = active === 0 ? '0%' : active === n - 1 ? '-100%' : '-50%';
    const tipLeft = active === 0 ? M.left + 8 : active === n - 1 ? width - M.right - 8 : tipCenter;

    body = (
      <div className="overflow-x-auto" role="region" aria-label="กราฟแนวโน้มรายเดือน เลื่อนแนวนอนได้" tabIndex={0}>
        <div className="relative" style={{ width }}>
          <svg
            viewBox={`0 0 ${width} ${HEIGHT}`}
            width={width}
            height={HEIGHT}
            role="img"
            aria-label="กราฟแท่งกลุ่มแสดงจำนวนรายการรายเดือนแยกตาม 4 โมดูล ดูตัวเลขได้จากปุ่มดูเป็นตาราง"
            className="block"
          >
            {ticks.map((t) => (
              <g key={t}>
                <line x1={M.left} x2={width - M.right} y1={y(t)} y2={y(t)} stroke="#e2e8f0" strokeWidth="1" />
                <text x={M.left - 8} y={y(t)} textAnchor="end" dominantBaseline="middle" fontSize="12" fill="#475569">
                  {formatNumber(t)}
                </text>
              </g>
            ))}

            {months.map((m, i) => {
              const gx = M.left + i * groupW;
              const cx = gx + (groupW - clusterW) / 2;
              return (
                <g key={m.label}>
                  {active === i && (
                    <rect x={gx} y={M.top} width={groupW} height={PLOT_H} fill="#f1f5f9" />
                  )}
                  {MODULES.map((mod, j) => {
                    const v = m[mod.key] ?? 0;
                    if (v <= 0) return null;
                    const h = (v / yMax) * PLOT_H;
                    return (
                      <path
                        key={mod.key}
                        d={barPath(cx + j * (barW + BAR_GAP), yBase, barW, h)}
                        fill={mod.color}
                      />
                    );
                  })}
                  <text x={gx + groupW / 2} y={yBase + 20} textAnchor="middle" fontSize="12" fill="#475569">
                    {formatMonth(m.label)}
                  </text>
                  {/* พื้นที่ hover/โฟกัสใหญ่กว่าแท่ง และเข้าถึงด้วยคีย์บอร์ดได้ */}
                  <rect
                    x={gx}
                    y={M.top}
                    width={groupW}
                    height={PLOT_H}
                    fill="transparent"
                    tabIndex={0}
                    aria-label={summary(m)}
                    className="focus:outline-none focus-visible:stroke-indigo-600 focus-visible:stroke-2"
                    onMouseEnter={() => setActive(i)}
                    onMouseLeave={() => setActive(null)}
                    onFocus={() => setActive(i)}
                    onBlur={() => setActive(null)}
                  />
                </g>
              );
            })}

            <line x1={M.left} x2={width - M.right} y1={yBase} y2={yBase} stroke="#94a3b8" strokeWidth="1" />
          </svg>

          {activeMonth && (
            <div
              className="pointer-events-none absolute top-2 z-10 min-w-44 rounded-xl border border-slate-200 bg-white p-3 text-sm shadow-lg"
              style={{ left: tipLeft, transform: `translateX(${tipShift})` }}
            >
              <p className="mb-1 font-semibold text-slate-900">{formatMonth(activeMonth.label)}</p>
              <ul className="space-y-1">
                {MODULES.map((mod) => (
                  <li key={mod.key} className="flex items-center justify-between gap-4 text-slate-700">
                    <span className="flex items-center gap-2">
                      <span aria-hidden="true" className="h-2.5 w-2.5 rounded-sm" style={{ background: mod.color }} />
                      {mod.label}
                    </span>
                    <span className="font-semibold text-slate-900">{formatNumber(activeMonth[mod.key] ?? 0)}</span>
                  </li>
                ))}
              </ul>
            </div>
          )}
        </div>
      </div>
    );
  }

  return (
    <section aria-labelledby="trend-title" className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
      <div className="mb-4 flex flex-wrap items-start justify-between gap-3">
        <div>
          <h2 id="trend-title" className="text-lg font-semibold text-slate-800">
            แนวโน้มรายเดือนแยกตามโมดูล
          </h2>
          <p className="text-sm text-slate-600">จำนวนรายการ ย้อนหลังสูงสุด {MAX_MONTHS} เดือน</p>
        </div>
        <button
          type="button"
          aria-pressed={asTable}
          onClick={() => setAsTable((v) => !v)}
          className={`rounded-lg border border-slate-300 px-3 py-1.5 text-sm text-slate-700 hover:bg-slate-100 ${focusRing}`}
        >
          {asTable ? 'ดูเป็นกราฟ' : 'ดูเป็นตาราง'}
        </button>
      </div>

      <ul className="mb-3 flex flex-wrap gap-x-5 gap-y-2" aria-label="คำอธิบายสี">
        {MODULES.map((mod) => (
          <li key={mod.key} className="flex items-center gap-2 text-sm text-slate-700">
            <span aria-hidden="true" className="h-3 w-3 rounded-sm" style={{ background: mod.color }} />
            {mod.label}
          </li>
        ))}
      </ul>

      {/* ref อยู่ที่ตัวห่อเสมอ เพื่อวัดความกว้างได้ทุกสถานะ (loading/error/ตาราง/กราฟ) */}
      <div ref={wrapRef}>{body}</div>
    </section>
  );
}