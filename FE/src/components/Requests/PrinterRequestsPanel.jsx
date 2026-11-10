import { useState } from 'react';
import DataTable from '../Tables/DataTable.jsx';
import StatusBadge from '../Badge/StatusBadge.jsx';
import Notice from '../Feedback/Notice.jsx';
import PrinterActionModal from './PrinterActionModal.jsx';
import { usePagedData } from '../../hooks/usePagedData.js';
import { getAllPrinterBookings } from '../../services/printers.service.js';
import { PRINTER_STATUS_OPTIONS } from '../../utils/booking.js';
import { MATERIAL_LABEL, PRINTER_ACTIONS, formatWeight } from '../../utils/printerActions.js';
import { formatDate, formatDateTime, formatTimeRange } from '../../utils/format.js';

const focusRing =
  'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-600';
const fieldClass = `rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-800 ${focusRing}`;

export default function PrinterRequestsPanel() {
  // คิวเริ่มต้น: รออนุมัติ เรียงตามวันที่ใช้เครื่องใกล้ที่สุดก่อน
  // (เปลี่ยนตัวกรองเป็น "อนุมัติแล้ว"/"กำลังพิมพ์" เพื่อกดเริ่มพิมพ์/พิมพ์เสร็จ)
  const table = usePagedData(getAllPrinterBookings, {
    sort: 'work_date',
    order: 'asc',
    filters: { booking_status: 'PENDING' },
  });

  const [notice, setNotice] = useState(null);
  const [target, setTarget] = useState(null);

  const statusFilter = table.params.filters.booking_status ?? '';

  const columns = [
    { key: 'booking_code', label: 'เลขที่การจอง', sortable: true },
    {
      key: 'user_name',
      label: 'ผู้จอง',
      render: (r) => <span className="font-medium text-slate-900">{r.user_name}</span>,
    },
    {
      key: 'printer_name',
      label: 'เครื่องพิมพ์',
      sortable: true,
      render: (r) => (
        <>
          <span className="block font-medium text-slate-900">{r.printer_name}</span>
          <span className="block text-xs text-slate-600">{r.printer_code}</span>
        </>
      ),
    },
    { key: 'work_date', label: 'วันที่ใช้เครื่อง', sortable: true, render: (r) => formatDate(r.work_date) },
    {
      key: 'start_time',
      label: 'เวลา',
      sortable: true,
      render: (r) => formatTimeRange(r.start_time, r.end_time),
    },
    {
      key: 'material',
      label: 'วัสดุ / น้ำหนัก',
      render: (r) => (
        <>
          <span className="block">{MATERIAL_LABEL[r.material] ?? r.material ?? '-'}</span>
          <span className="block text-xs text-slate-600">{formatWeight(r.est_weight_g)}</span>
        </>
      ),
    },
    {
      key: 'booking_status',
      label: 'สถานะ',
      sortable: true,
      render: (r) => <StatusBadge status={r.booking_status} variant="printer" />,
    },
    {
      key: 'print_purpose',
      label: 'วัตถุประสงค์',
      render: (r) => <span className="line-clamp-2 max-w-[16rem]">{r.print_purpose ?? '-'}</span>,
    },
    {
      key: 'booking_time',
      label: 'ส่งคำขอเมื่อ',
      sortable: true,
      render: (r) => <span className="whitespace-nowrap">{formatDateTime(r.booking_time)}</span>,
    },
    {
      key: 'actions',
      label: 'การดำเนินการ',
      render: (r) => {
        // staff ไม่ทำ RECEIVE แทนผู้ใช้ (ปุ่มนี้เป็นของเจ้าของการจอง)
        const staffActions = r.actions.filter((a) => a !== 'RECEIVE');
        if (staffActions.length === 0) return '-';
        return (
          <div className="flex flex-wrap gap-2">
            {staffActions.map((a) => (
              <button
                key={a}
                type="button"
                onClick={() => setTarget({ row: r, action: a })}
                aria-label={`${PRINTER_ACTIONS[a].button} ${r.booking_code}`}
                className={`whitespace-nowrap rounded-lg border bg-white px-3 py-1 text-sm font-medium ${PRINTER_ACTIONS[a].trigger} ${focusRing}`}
              >
                {PRINTER_ACTIONS[a].button}
              </button>
            ))}
          </div>
        );
      },
    },
  ];

  return (
    <section aria-labelledby="printer-requests-title" className="space-y-3">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h2 id="printer-requests-title" className="text-lg font-semibold text-slate-800">
            เครื่องพิมพ์ 3D
          </h2>
          <p className="text-sm text-slate-600" aria-live="polite">
            {statusFilter === 'PENDING' && table.meta
              ? `รออนุมัติ ${table.meta.total} รายการ`
              : 'รายการจองเครื่องพิมพ์'}
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
            {PRINTER_STATUS_OPTIONS.map(([value, label]) => (
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
        caption="ตารางคำขอจองเครื่องพิมพ์ 3D"
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

      <PrinterActionModal
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
