import { useMemo } from 'react';
import DataTable from '../Tables/DataTable.jsx';
import StatusBadge from '../Badge/StatusBadge.jsx';
import { usePagedData } from '../../hooks/usePagedData.js';
import { getTable } from '../../services/dashboard.service.js';
import { RECENT_DATE_LABEL } from '../../utils/dashboard.js';
import { formatDay } from '../../utils/equipment.js';

const focusRing = 'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-slate-700';

// ใช้ key={system.key} ที่ตัวเรียก เพื่อให้ตารางเริ่มใหม่ทุกครั้งที่เปลี่ยนระบบ
export default function SystemRecentPanel({ system }) {
  const fetcher = useMemo(
    () => (p) => getTable('recent', { ...p, filters: { ...p.filters, module: system.api } }),
    [system.api],
  );
  const table = usePagedData(fetcher, {
    sort: 'event_at',
    order: 'desc',
    filters: { needs_action: 'true' },
  });
  const needsAction = table.params.filters.needs_action ?? '';

  const columns = [
    { key: 'booking_code', label: 'เลขที่', sortable: true },
    { key: 'item_name', label: 'ทรัพยากร/สถานที่', sortable: true },
    {
      key: 'status',
      label: 'สถานะ',
      sortable: true,
      render: (r) => (
        <span className="flex flex-wrap items-center gap-2">
          <StatusBadge status={r.status} variant={system.variant} />
          {r.needs_action && <span className="text-xs font-semibold text-red-800">ต้องดำเนินการ</span>}
        </span>
      ),
    },
    {
      key: 'event_date',
      label: RECENT_DATE_LABEL[system.api],
      sortable: true,
      render: (r) => <span className="whitespace-nowrap">{formatDay(r.event_date)}</span>,
    },
  ];

  return (
    <section aria-labelledby="sys-recent-title" className="space-y-3">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h2 id="sys-recent-title" className="text-lg font-semibold text-slate-800">
            รายการล่าสุด
          </h2>
          <p className="text-sm text-slate-600" aria-live="polite">
            {table.meta ? `${needsAction === 'true' ? 'ที่ต้องดำเนินการ' : 'ทั้งหมด'} ${table.meta.total} รายการ` : 'กำลังโหลด…'} · ไม่แสดงข้อมูลผู้ใช้
          </p>
        </div>
        <label className="flex items-center gap-2 text-sm text-slate-700">
          <span>แสดง</span>
          <select
            name="needs_action"
            value={needsAction}
            onChange={(e) => table.setFilter('needs_action', e.target.value)}
            className={`rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-800 ${focusRing}`}
          >
            <option value="true">เฉพาะที่ต้องดำเนินการ</option>
            <option value="">ทั้งหมด</option>
          </select>
        </label>
      </div>
      <DataTable
        caption={`รายการล่าสุดของ${system.label}`}
        columns={columns}
        rows={table.rows}
        rowKey="booking_code"
        loading={table.loading}
        error={table.error}
        onRetry={table.reload}
        page={table.params.page}
        limit={table.params.limit}
        total={table.meta?.total ?? 0}
        totalPages={table.meta?.totalPages ?? 1}
        sort={table.params.sort}
        order={table.params.order}
        onPageChange={table.setPage}
        onLimitChange={table.setLimit}
        onSortChange={table.setSort}
        emptyText={needsAction === 'true' ? 'ไม่มีรายการที่ต้องดำเนินการ' : 'ไม่พบรายการ'}
      />
    </section>
  );
}
