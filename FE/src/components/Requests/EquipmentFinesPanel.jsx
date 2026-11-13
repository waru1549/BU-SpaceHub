import { useState } from 'react';
import DataTable from '../Tables/DataTable.jsx';
import Modal from '../Modals/Modal.jsx';
import Notice from '../Feedback/Notice.jsx';
import FineBadge, { FINE_STATUS_OPTIONS } from '../Badge/FineBadge.jsx';
import { usePagedData } from '../../hooks/usePagedData.js';
import { getAllFines, settleFine } from '../../services/equipment.service.js';
import { formatBaht } from '../../utils/equipment.js';

const focusRing =
  'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-amber-600';
const fieldClass = `rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-800 ${focusRing}`;
const btnSecondary = `rounded-lg border border-slate-300 px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-100 disabled:opacity-50 ${focusRing}`;

const FINE_ACTIONS = {
  pay: {
    button: 'บันทึกชำระ',
    title: 'บันทึกการชำระค่าปรับ',
    question: 'ยืนยันว่าได้รับชำระค่าปรับนี้แล้วใช่หรือไม่',
    confirm: 'ยืนยันการชำระ',
    busy: 'กำลังบันทึก…',
    done: 'บันทึกการชำระค่าปรับ',
    trigger: 'border-emerald-300 text-emerald-800 hover:bg-emerald-50',
    solid: 'bg-emerald-700 hover:bg-emerald-800',
  },
  waive: {
    button: 'ยกเว้น',
    title: 'ยกเว้นค่าปรับ',
    question: 'ต้องการยกเว้นค่าปรับนี้ใช่หรือไม่ การยกเว้นไม่สามารถย้อนกลับได้',
    confirm: 'ยืนยันการยกเว้น',
    busy: 'กำลังบันทึก…',
    done: 'ยกเว้นค่าปรับ',
    trigger: 'border-slate-300 text-slate-700 hover:bg-slate-100',
    solid: 'bg-slate-700 hover:bg-slate-800',
  },
};

// จัดการค่าปรับของเจ้าหน้าที่: UNPAID -> ชำระแล้ว / ยกเว้น (ผู้ยืมจะยืมใหม่ได้เมื่อไม่มีค่าปรับค้างและไม่มีของเกินกำหนด)
export default function EquipmentFinesPanel() {
  const table = usePagedData(getAllFines, {
    sort: 'fine_id',
    order: 'desc',
    filters: { fine_status: 'UNPAID' },
  });

  const [notice, setNotice] = useState(null);
  const [target, setTarget] = useState(null); // { row, action: 'pay' | 'waive' }
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);

  const statusFilter = table.params.filters.fine_status ?? '';
  const cfg = target ? FINE_ACTIONS[target.action] : null;

  const close = () => {
    setTarget(null);
    setError(null);
  };

  const confirm = async () => {
    setBusy(true);
    setError(null);
    try {
      await settleFine(target.row.fine_id, target.action);
      setNotice({ type: 'success', text: `${cfg.done} ${target.row.booking_code} แล้ว` });
      close();
      table.reload();
    } catch (err) {
      setError(err.message);
      if (err.status === 404 || err.status === 409) table.reload();
    } finally {
      setBusy(false);
    }
  };

  const columns = [
    { key: 'booking_code', label: 'เลขที่การยืม', sortable: true },
    {
      key: 'user_name',
      label: 'ผู้ยืม',
      render: (r) => <span className="font-medium text-slate-900">{r.user_name}</span>,
    },
    { key: 'equipment_name', label: 'อุปกรณ์' },
    {
      key: 'fine_amount',
      label: 'ยอดค่าปรับ',
      sortable: true,
      render: (r) => <span className="whitespace-nowrap font-medium text-slate-900">{formatBaht(r.fine_amount)}</span>,
    },
    {
      key: 'fine_reason',
      label: 'เหตุผล',
      render: (r) => <span className="line-clamp-2 max-w-[16rem]">{r.fine_reason ?? '-'}</span>,
    },
    {
      key: 'fine_status',
      label: 'สถานะ',
      sortable: true,
      render: (r) => <FineBadge status={r.fine_status} />,
    },
    {
      key: 'actions',
      label: 'การดำเนินการ',
      render: (r) =>
        r.fine_status === 'UNPAID' ? (
          <div className="flex flex-wrap gap-2">
            {Object.entries(FINE_ACTIONS).map(([action, a]) => (
              <button
                key={action}
                type="button"
                onClick={() => {
                  setTarget({ row: r, action });
                  setError(null);
                }}
                aria-label={`${a.button} ${r.booking_code}`}
                className={`whitespace-nowrap rounded-lg border bg-white px-3 py-1 text-sm font-medium ${a.trigger} ${focusRing}`}
              >
                {a.button}
              </button>
            ))}
          </div>
        ) : (
          '-'
        ),
    },
  ];

  return (
    <section aria-labelledby="fines-title" className="space-y-3">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h2 id="fines-title" className="text-lg font-semibold text-slate-800">
            ค่าปรับอุปกรณ์
          </h2>
          <p className="text-sm text-slate-600" aria-live="polite">
            {statusFilter === 'UNPAID' && table.meta ? `ค้างชำระ ${table.meta.total} รายการ` : 'รายการค่าปรับทั้งหมด'}
          </p>
        </div>
        <label className="flex items-center gap-2 text-sm text-slate-700">
          <span>สถานะ</span>
          <select
            name="fine_status"
            value={statusFilter}
            onChange={(e) => table.setFilter('fine_status', e.target.value)}
            className={fieldClass}
          >
            {FINE_STATUS_OPTIONS.map(([value, label]) => (
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
        caption="ตารางค่าปรับอุปกรณ์"
        columns={columns}
        rows={table.rows}
        rowKey="fine_id"
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
        emptyText={statusFilter === 'UNPAID' ? 'ไม่มีค่าปรับค้างชำระ' : 'ไม่พบรายการ'}
      />

      <Modal
        open={target !== null}
        title={cfg?.title ?? ''}
        onClose={close}
        busy={busy}
        footer={
          cfg && (
            <>
              <button type="button" onClick={close} disabled={busy} className={btnSecondary} data-autofocus>
                ย้อนกลับ
              </button>
              <button
                type="button"
                onClick={confirm}
                disabled={busy}
                className={`rounded-lg px-4 py-2 text-sm font-medium text-white disabled:opacity-60 ${cfg.solid} ${focusRing}`}
              >
                {busy ? cfg.busy : cfg.confirm}
              </button>
            </>
          )
        }
      >
        {target && (
          <div className="space-y-4 text-sm">
            <p className="text-slate-800">{cfg.question}</p>
            <dl className="grid grid-cols-[6rem_1fr] gap-x-3 gap-y-1">
              <dt className="text-slate-600">เลขที่การยืม</dt>
              <dd className="font-medium text-slate-900">{target.row.booking_code}</dd>
              <dt className="text-slate-600">ผู้ยืม</dt>
              <dd className="font-medium text-slate-900">{target.row.user_name}</dd>
              <dt className="text-slate-600">อุปกรณ์</dt>
              <dd className="font-medium text-slate-900">{target.row.equipment_name}</dd>
              <dt className="text-slate-600">ยอดค่าปรับ</dt>
              <dd className="font-medium text-slate-900">{formatBaht(target.row.fine_amount)}</dd>
              <dt className="text-slate-600">เหตุผล</dt>
              <dd className="text-slate-900">{target.row.fine_reason ?? '-'}</dd>
            </dl>
            {error && (
              <p role="alert" className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-red-900">
                {error}
              </p>
            )}
          </div>
        )}
      </Modal>
    </section>
  );
}
