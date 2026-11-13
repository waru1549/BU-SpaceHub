import { useState } from 'react';
import DataTable from '../Tables/DataTable.jsx';
import StatusBadge from '../Badge/StatusBadge.jsx';
import Notice from '../Feedback/Notice.jsx';
import EquipmentActionModal from './EquipmentActionModal.jsx';
import { usePagedData } from '../../hooks/usePagedData.js';
import { getAllEquipmentBookings } from '../../services/equipment.service.js';
import { EQUIPMENT_STATUS_OPTIONS } from '../../utils/booking.js';
import { EQUIPMENT_ACTIONS, formatDay, formatDayTime } from '../../utils/equipment.js';

const focusRing =
  'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-amber-600';
const fieldClass = `rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-800 ${focusRing}`;

export default function EquipmentRequestsPanel() {
  // คิวเริ่มต้น: รออนุมัติ (เปลี่ยนตัวกรองเป็น "อนุมัติแล้ว" เพื่อส่งมอบ, "กำลังยืม"/"เกินกำหนดคืน" เพื่อรับคืน)
  const table = usePagedData(getAllEquipmentBookings, {
    sort: 'borrow_date',
    order: 'asc',
    filters: { booking_status: 'PENDING' },
  });

  const [notice, setNotice] = useState(null);
  const [target, setTarget] = useState(null);
  const statusFilter = table.params.filters.booking_status ?? '';

  const columns = [
    { key: 'booking_code', label: 'เลขที่การยืม', sortable: true },
    {
      key: 'user_name',
      label: 'ผู้ยืม',
      render: (r) => <span className="font-medium text-slate-900">{r.user_name}</span>,
    },
    {
      key: 'equipment_name',
      label: 'อุปกรณ์',
      sortable: true,
      render: (r) => (
        <>
          <span className="block font-medium text-slate-900">{r.equipment_name}</span>
          <span className="block text-xs text-slate-600">{r.equipment_code}</span>
        </>
      ),
    },
    {
      key: 'borrow_date',
      label: 'วันที่ยืม',
      sortable: true,
      render: (r) => <span className="whitespace-nowrap">{formatDay(r.borrow_date)}</span>,
    },
    {
      key: 'expected_return_date',
      label: 'กำหนดคืน',
      sortable: true,
      render: (r) => <span className="whitespace-nowrap">{formatDayTime(r.expected_return_date)}</span>,
    },
    {
      key: 'booking_status',
      label: 'สถานะ',
      sortable: true,
      render: (r) => (
        <>
          <StatusBadge status={r.booking_status} variant="equipment" />
          {r.overdue_days > 0 && (
            <span className="mt-1 block text-xs font-medium text-red-800">เกิน {r.overdue_days} วัน</span>
          )}
        </>
      ),
    },
    {
      key: 'borrow_purpose',
      label: 'วัตถุประสงค์',
      render: (r) => <span className="line-clamp-2 max-w-[16rem]">{r.borrow_purpose ?? '-'}</span>,
    },
    {
      key: 'actions',
      label: 'การดำเนินการ',
      render: (r) =>
        r.actions.length === 0 ? (
          '-'
        ) : (
          <div className="flex flex-wrap gap-2">
            {r.actions.map((a) => (
              <button
                key={a}
                type="button"
                onClick={() => setTarget({ row: r, action: a })}
                aria-label={`${EQUIPMENT_ACTIONS[a].button} ${r.booking_code}`}
                className={`whitespace-nowrap rounded-lg border bg-white px-3 py-1 text-sm font-medium ${EQUIPMENT_ACTIONS[a].trigger} ${focusRing}`}
              >
                {EQUIPMENT_ACTIONS[a].button}
              </button>
            ))}
          </div>
        ),
    },
  ];

  return (
    <section aria-labelledby="equipment-requests-title" className="space-y-3">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h2 id="equipment-requests-title" className="text-lg font-semibold text-slate-800">
            ยืม-คืนอุปกรณ์
          </h2>
          <p className="text-sm text-slate-600" aria-live="polite">
            {statusFilter === 'PENDING' && table.meta
              ? `รออนุมัติ ${table.meta.total} รายการ`
              : 'รายการยืมอุปกรณ์'}
          </p>
        </div>
        <label className="flex items-center gap-2 text-sm text-slate-700">
          <span>สถานะ</span>
          <select
            name="booking_status"
            value={statusFilter}
            onChange={(e) => table.setFilter('booking_status', e.target.value)}
            className={fieldClass}
          >
            {EQUIPMENT_STATUS_OPTIONS.map(([value, label]) => (
              <option key={value} value={value}>
                {label}
              </option>
            ))}
          </select>
        </label>
      </div>

      {notice && (
        <Notice type={notice.type} onDismiss={() => setNotice(null)}>
          {notice.text}
        </Notice>
      )}

      <DataTable
        caption="ตารางคำขอยืมอุปกรณ์"
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
        emptyText={statusFilter === 'PENDING' ? 'ไม่มีคำขอที่รออนุมัติ' : 'ไม่พบรายการ'}
      />

      <EquipmentActionModal
        target={target}
        onClose={() => setTarget(null)}
        onDone={(message) => {
          setTarget(null);
          setNotice({ type: 'success', text: message });
          table.reload();
        }}
        onStale={table.reload}
      />
    </section>
  );
}
