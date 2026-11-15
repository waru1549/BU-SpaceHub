import { useState } from 'react';
import DataTable from '../Tables/DataTable.jsx';
import StatusBadge from '../Badge/StatusBadge.jsx';
import Notice from '../Feedback/Notice.jsx';
import MaintenanceActionModal from './MaintenanceActionModal.jsx';
import MaintenanceDetailModal from '../Maintenance/MaintenanceDetailModal.jsx';
import { usePagedData } from '../../hooks/usePagedData.js';
import { getAllRequests } from '../../services/maintenance.service.js';
import { MAINTENANCE_STATUS_OPTIONS } from '../../utils/booking.js';
import { MAINTENANCE_ACTIONS } from '../../utils/maintenance.js';
import { formatDayTime } from '../../utils/equipment.js';

const focusRing =
  'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-sky-600';
const fieldClass = `rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-800 ${focusRing}`;

export default function MaintenanceRequestsPanel() {
  // คิวเริ่มต้น: รอรับเรื่อง (Admin มอบหมาย -> Staff เริ่มซ่อม -> ปิดงาน)
  const table = usePagedData(getAllRequests, {
    sort: 'reported_date',
    order: 'asc',
    filters: { booking_status: 'PENDING' },
  });

  const [notice, setNotice] = useState(null);
  const [target, setTarget] = useState(null);
  const [detailId, setDetailId] = useState(null);
  const statusFilter = table.params.filters.booking_status ?? '';
  const mineOnly = table.params.filters.assigned_to === 'me';

  const columns = [
    { key: 'booking_code', label: 'เลขที่งาน', sortable: true },
    {
      key: 'repair_title',
      label: 'เรื่อง',
      sortable: true,
      render: (r) => (
        <>
          <span className="block font-medium text-slate-900">{r.repair_title}</span>
          <span className="block text-xs text-slate-600">{r.resource_name ?? r.location ?? '-'}</span>
          {r.attachment_count > 0 && (
            <span className="block text-xs text-sky-800">รูปแนบ {r.attachment_count} รูป</span>
          )}
        </>
      ),
    },
    { key: 'reporter_name', label: 'ผู้แจ้ง' },
    {
      key: 'assignee_name',
      label: 'ผู้รับผิดชอบ',
      sortable: true,
      render: (r) => r.assignee_name ?? <span className="text-slate-600">ยังไม่มอบหมาย</span>,
    },
    {
      key: 'booking_status',
      label: 'สถานะ',
      sortable: true,
      render: (r) => <StatusBadge status={r.booking_status} variant="maintenance" />,
    },
    {
      key: 'reported_date',
      label: 'แจ้งเมื่อ',
      sortable: true,
      render: (r) => <span className="whitespace-nowrap">{formatDayTime(r.reported_date)}</span>,
    },
    {
      key: 'actions',
      label: 'การดำเนินการ',
      render: (r) => (
        <div className="flex flex-wrap gap-2">
          <button
            type="button"
            onClick={() => setDetailId(r.booking_id)}
            aria-label={`ดูรายละเอียด ${r.booking_code}`}
            className={`whitespace-nowrap rounded-lg border border-slate-300 bg-white px-3 py-1 text-sm font-medium text-slate-700 hover:bg-slate-100 ${focusRing}`}
          >
            รายละเอียด
          </button>
          {r.actions
            .filter((a) => a !== 'CANCEL')
            .map((a) => (
              <button
                key={a}
                type="button"
                onClick={() => setTarget({ row: r, action: a })}
                aria-label={`${MAINTENANCE_ACTIONS[a].button} ${r.booking_code}`}
                className={`whitespace-nowrap rounded-lg border bg-white px-3 py-1 text-sm font-medium ${MAINTENANCE_ACTIONS[a].trigger} ${focusRing}`}
              >
                {r.assigned_to && a === 'ASSIGN' ? 'เปลี่ยนผู้รับผิดชอบ' : MAINTENANCE_ACTIONS[a].button}
              </button>
            ))}
        </div>
      ),
    },
  ];

  return (
    <section aria-labelledby="maintenance-requests-title" className="space-y-3">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h2 id="maintenance-requests-title" className="text-lg font-semibold text-slate-800">
            แจ้งซ่อม
          </h2>
          <p className="text-sm text-slate-600" aria-live="polite">
            {statusFilter === 'PENDING' && table.meta ? `รอรับเรื่อง ${table.meta.total} รายการ` : 'รายการแจ้งซ่อม'}
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-x-4 gap-y-2">
          <label className="flex items-center gap-2 text-sm text-slate-700">
            <input
              type="checkbox"
              name="mine_only"
              checked={mineOnly}
              onChange={(e) => table.setFilter('assigned_to', e.target.checked ? 'me' : '')}
              className={`h-4 w-4 rounded border-slate-300 text-sky-700 ${focusRing}`}
            />
            เฉพาะงานของฉัน
          </label>
          <label className="flex items-center gap-2 text-sm text-slate-700">
            <span>สถานะ</span>
            <select
              name="booking_status"
              value={statusFilter}
              onChange={(e) => table.setFilter('booking_status', e.target.value)}
              className={fieldClass}
            >
              {MAINTENANCE_STATUS_OPTIONS.map(([value, label]) => (
                <option key={value} value={value}>
                  {label}
                </option>
              ))}
            </select>
          </label>
        </div>
      </div>

      {notice && (
        <Notice type={notice.type} onDismiss={() => setNotice(null)}>
          {notice.text}
        </Notice>
      )}

      <DataTable
        caption="ตารางงานแจ้งซ่อม"
        columns={columns}
        rows={table.rows}
        rowKey="booking_id"
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
        emptyText={statusFilter === 'PENDING' ? 'ไม่มีงานที่รอรับเรื่อง' : 'ไม่พบรายการ'}
      />

      <MaintenanceActionModal
        target={target}
        onClose={() => setTarget(null)}
        onDone={(message) => {
          setTarget(null);
          setNotice({ type: 'success', text: message });
          table.reload();
        }}
        onStale={table.reload}
      />
      <MaintenanceDetailModal requestId={detailId} onClose={() => setDetailId(null)} onChanged={table.reload} />
    </section>
  );
}
