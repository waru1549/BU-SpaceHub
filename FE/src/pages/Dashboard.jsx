import { AlertCircle, AlertTriangle, Banknote, ClipboardCheck, Users } from 'lucide-react';
import KpiCard from '../components/Cards/KpiCard.jsx';
import MonthlyTrendChart from '../components/Charts/MonthlyTrendChart.jsx';
import DashboardTables from '../components/Tables/DashboardTables.jsx';
import { useAsync } from '../hooks/useAsync.js';
import { useAuth } from '../hooks/useAuth.js';
import { getKpi, getTrend } from '../services/dashboard.service.js';
import { formatBaht, formatNumber } from '../utils/format.js';

export default function Dashboard() {
  const { profile } = useAuth();
  const kpi = useAsync(getKpi);
  const trend = useAsync(getTrend);
  const k = kpi.data;

  const cards = [
    { label: 'ผู้ใช้ที่ใช้งานอยู่', value: formatNumber(k?.active_users), icon: Users, tone: 'bg-indigo-50 text-indigo-700' },
    { label: 'รายการรออนุมัติ', value: formatNumber(k?.pending_approvals), icon: ClipboardCheck, tone: 'bg-amber-50 text-amber-800' },
    { label: 'อุปกรณ์เกินกำหนดคืน', value: formatNumber(k?.overdue_equipment), icon: AlertTriangle, tone: 'bg-red-50 text-red-700' },
    { label: 'ค่าปรับค้างชำระ', value: formatBaht(k?.unpaid_fines), icon: Banknote, tone: 'bg-slate-100 text-slate-700' },
  ];

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-2xl font-bold text-slate-800">แดชบอร์ด</h1>
        <p className="text-sm text-slate-600">ภาพรวมการใช้งานระบบ BU SpaceHub</p>
      </header>

      {kpi.error && (
        <div role="alert" className="flex flex-wrap items-center gap-3 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800">
          <AlertCircle className="h-5 w-5 shrink-0" aria-hidden="true" />
          <span>โหลดตัวชี้วัดไม่สำเร็จ: {kpi.error}</span>
          <button
            type="button"
            onClick={kpi.reload}
            className="ml-auto rounded-lg border border-red-300 bg-white px-3 py-1 font-medium hover:bg-red-100 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-500"
          >
            ลองอีกครั้ง
          </button>
        </div>
      )}

      <section aria-label="ตัวชี้วัดหลัก" className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {cards.map((c) => (
          <KpiCard key={c.label} {...c} loading={kpi.loading} />
        ))}
      </section>

      <MonthlyTrendChart rows={trend.data} loading={trend.loading} error={trend.error} onRetry={trend.reload} />

      <DashboardTables role={profile.role} />
    </div>
  );
}