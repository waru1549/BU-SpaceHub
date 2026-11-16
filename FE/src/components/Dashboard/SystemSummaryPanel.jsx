import { BOOKING_STATUS, STATUS_LABEL_BY_VARIANT } from '../../utils/booking.js';
import { formatMonth } from '../../utils/dashboard.js';
import BarList from './BarList.jsx';
import ColumnChart from './ColumnChart.jsx';

const MAX_MONTHS = 12;

// ภาพรวมของระบบ: แนวโน้มรายเดือนของระบบนี้ + สัดส่วนสถานะ
export default function SystemSummaryPanel({ system, summary, trendRows, trendLoading }) {
  const months = (trendRows ?? [])
    .filter((r) => r.module === system.api)
    .map((r) => ({ key: r.month_label, label: formatMonth(r.month_label), value: Number(r.total_bookings), sort: r.month_label }))
    .sort((a, b) => a.sort.localeCompare(b.sort))
    .slice(-MAX_MONTHS);

  const statusItems = (summary?.status_distribution ?? [])
    .map((s) => ({
      key: s.status,
      label: STATUS_LABEL_BY_VARIANT[system.variant]?.[s.status] ?? BOOKING_STATUS[s.status]?.label ?? s.status,
      value: s.total,
    }))
    .sort((a, b) => b.value - a.value);
  const total = statusItems.reduce((sum, i) => sum + i.value, 0);

  return (
    <div className="grid gap-6 lg:grid-cols-2">
      <section aria-labelledby="sys-trend-title" className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
        <h2 id="sys-trend-title" className="text-lg font-semibold text-slate-800">
          แนวโน้มรายเดือน
        </h2>
        <p className="mb-4 text-sm text-slate-600">จำนวนรายการของ{system.label} ย้อนหลังสูงสุด {MAX_MONTHS} เดือน</p>
        {trendLoading ? (
          <div aria-hidden="true" className="h-48 animate-pulse rounded-xl bg-slate-100 motion-reduce:animate-none" />
        ) : (
          <ColumnChart items={months} color={system.color} />
        )}
      </section>

      <section aria-labelledby="sys-status-title" className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
        <h2 id="sys-status-title" className="text-lg font-semibold text-slate-800">
          สัดส่วนตามสถานะ
        </h2>
        <p className="mb-4 text-sm text-slate-600">ทั้งหมด {total.toLocaleString('th-TH')} รายการ</p>
        <BarList items={statusItems} color={system.color} />
      </section>
    </div>
  );
}
