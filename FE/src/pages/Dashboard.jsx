import { useCallback } from 'react';
import { useSearchParams } from 'react-router';
import { AlertCircle, AlertTriangle, Banknote, ClipboardCheck, Users } from 'lucide-react';
import KpiCard from '../components/Cards/KpiCard.jsx';
import MonthlyTrendChart from '../components/Charts/MonthlyTrendChart.jsx';
import DashboardTables from '../components/Tables/DashboardTables.jsx';
import SystemSelector from '../components/Dashboard/SystemSelector.jsx';
import SystemSummaryPanel from '../components/Dashboard/SystemSummaryPanel.jsx';
import SystemRecentPanel from '../components/Dashboard/SystemRecentPanel.jsx';
import SystemUsagePanel from '../components/Dashboard/SystemUsagePanel.jsx';
import SystemStatsPanel from '../components/Dashboard/SystemStatsPanel.jsx';
import { useAsync } from '../hooks/useAsync.js';
import { useAuth } from '../hooks/useAuth.js';
import { getKpi, getSystem, getTrend } from '../services/dashboard.service.js';
import {
  CONTENT_TABS,
  CONTENT_TAB_KEYS,
  SYSTEM_KEYS,
  SYSTEM_KPIS,
  formatDecimal,
  formatNumber,
  formatPercent,
  getSystemConfig,
} from '../utils/dashboard.js';
import { formatBaht } from '../utils/equipment.js';

const FORMATTERS = {
  number: formatNumber,
  baht: formatBaht,
  percent: formatPercent,
  days: (v) => formatDecimal(v, 1),
};

export default function Dashboard() {
  const { profile } = useAuth();
  const [params, setParams] = useSearchParams();
  const system = getSystemConfig(SYSTEM_KEYS.includes(params.get('system')) ? params.get('system') : 'overview');
  const tab = CONTENT_TAB_KEYS.includes(params.get('tab')) ? params.get('tab') : 'summary';
  const isOverview = system.key === 'overview';

  const kpi = useAsync(getKpi);
  const trend = useAsync(getTrend);
  const fetchSummary = useCallback(
    () => (system.api ? getSystem(system.api) : Promise.resolve(null)),
    [system.api],
  );
  const summary = useAsync(fetchSummary);

  const selectSystem = (key) => setParams(key === 'overview' ? {} : { system: key }, { replace: true });
  const selectTab = (key) => setParams({ system: system.key, tab: key }, { replace: true });

  const k = kpi.data;
  const overviewCards = [
    { label: 'ผู้ใช้ที่ใช้งานอยู่', value: formatNumber(k?.active_users), icon: Users, tone: 'bg-indigo-50 text-indigo-700' },
    { label: 'รายการรออนุมัติ', value: formatNumber(k?.pending_approvals), icon: ClipboardCheck, tone: 'bg-amber-50 text-amber-800' },
    { label: 'อุปกรณ์เกินกำหนดคืน', value: formatNumber(k?.overdue_equipment), icon: AlertTriangle, tone: 'bg-red-50 text-red-700' },
    { label: 'ค่าปรับค้างชำระ', value: formatBaht(k?.unpaid_fines), icon: Banknote, tone: 'bg-slate-100 text-slate-700' },
  ];
  const systemCards = (SYSTEM_KPIS[system.key] ?? []).map((def) => ({
    label: def.label,
    value: FORMATTERS[def.format](summary.data?.kpis?.[def.key]),
    icon: def.icon,
    tone: def.tone,
  }));

  const activeError = isOverview ? kpi.error : summary.error;
  const retry = isOverview ? kpi.reload : summary.reload;
  const cards = isOverview ? overviewCards : systemCards;
  const cardsLoading = isOverview ? kpi.loading : summary.loading;

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-2xl font-bold text-slate-800">แดชบอร์ด</h1>
        <p className="text-sm text-slate-600">ภาพรวมการใช้งานระบบ BU SpaceHub (ข้อมูลสรุป ไม่แสดงข้อมูลส่วนบุคคล)</p>
      </header>

      <SystemSelector value={system.key} onChange={selectSystem} />

      {activeError && (
        <div role="alert" className="flex flex-wrap items-center gap-3 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800">
          <AlertCircle className="h-5 w-5 shrink-0" aria-hidden="true" />
          <span>โหลดตัวชี้วัดไม่สำเร็จ: {activeError}</span>
          <button
            type="button"
            onClick={retry}
            className="ml-auto rounded-lg border border-red-300 bg-white px-3 py-1 font-medium hover:bg-red-100 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-500"
          >
            ลองอีกครั้ง
          </button>
        </div>
      )}

      <section aria-label={`ตัวชี้วัดหลัก ${system.label}`} className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {cards.map((c) => (
          <KpiCard key={`${system.key}-${c.label}`} {...c} loading={cardsLoading} />
        ))}
      </section>

      <div id="system-panel" role="tabpanel" aria-labelledby={`system-tab-${system.key}`} className="space-y-6">
        {isOverview ? (
          <>
            <MonthlyTrendChart rows={trend.data} loading={trend.loading} error={trend.error} onRetry={trend.reload} />
            <DashboardTables role={profile.role} />
          </>
        ) : (
          <>
            <div className="overflow-x-auto border-b border-slate-200">
              <div role="tablist" aria-label={`เนื้อหาของ${system.label}`} className="flex w-max gap-1">
                {CONTENT_TABS.map((t) => {
                  const selected = t.key === tab;
                  return (
                    <button
                      key={t.key}
                      type="button"
                      role="tab"
                      aria-selected={selected}
                      onClick={() => selectTab(t.key)}
                      className={`-mb-px whitespace-nowrap border-b-2 px-4 py-2.5 text-sm font-semibold focus-visible:outline-2 focus-visible:outline-offset-2 ${system.ring} ${
                        selected ? system.tabActive : 'border-transparent text-slate-600 hover:text-slate-900'
                      }`}
                    >
                      {t.label}
                    </button>
                  );
                })}
              </div>
            </div>

            {tab === 'summary' && (
              <SystemSummaryPanel
                system={system}
                summary={summary.data}
                trendRows={trend.data}
                trendLoading={trend.loading}
              />
            )}
            {tab === 'recent' && <SystemRecentPanel key={system.key} system={system} />}
            {tab === 'usage' && <SystemUsagePanel key={system.key} system={system} />}
            {tab === 'stats' && <SystemStatsPanel system={system} summary={summary.data} />}
          </>
        )}
      </div>
    </div>
  );
}
