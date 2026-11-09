import { useState } from 'react';
import DataTable from '../Tables/DataTable.jsx';
import Modal from '../Modals/Modal.jsx';
import StatusBadge from '../Badge/StatusBadge.jsx';
import Notice from '../Feedback/Notice.jsx';
import { usePagedData } from '../../hooks/usePagedData.js';
import { changeBookingStatus, getAllRoomBookings } from '../../services/rooms.service.js';
import { BOOKING_STATUS_OPTIONS } from '../../utils/booking.js';
import { ROLE_LABEL } from '../../utils/navigation.js';
import { formatDate, formatDateTime, formatTimeRange } from '../../utils/format.js';

const focusRing =
  'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-500';
const fieldClass = `rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-800 ${focusRing}`;
const btnSecondary = `rounded-lg border border-slate-300 px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-100 disabled:opacity-50 ${focusRing}`;

// ปุ่มและข้อความของแต่ละการดำเนินการ (รหัสตรงกับฟิลด์ actions ที่ BE ส่งมา)
const ACTIONS = {
  APPROVE: {
    path: 'approve',
    button: 'อนุมัติ',
    title: 'อนุมัติการจอง',
    question: 'ต้องการอนุมัติการจองนี้ใช่หรือไม่',
    confirm: 'ยืนยันการอนุมัติ',
    busy: 'กำลังอนุมัติ…',
    done: 'อนุมัติการจอง',
    trigger: 'border-emerald-300 text-emerald-800 hover:bg-emerald-50',
    solid: 'bg-emerald-700 hover:bg-emerald-800',
  },
  REJECT: {
    path: 'reject',
    button: 'ปฏิเสธ',
    title: 'ปฏิเสธการจอง',
    question: 'ต้องการปฏิเสธการจองนี้ใช่หรือไม่ ผู้จองต้องจองใหม่หากยังต้องการใช้ห้อง',
    confirm: 'ยืนยันการปฏิเสธ',
    busy: 'กำลังปฏิเสธ…',
    done: 'ปฏิเสธการจอง',
    trigger: 'border-red-300 text-red-800 hover:bg-red-50',
    solid: 'bg-red-700 hover:bg-red-800',
  },
  CANCEL: {
    path: 'cancel',
    button: 'ยกเลิก',
    title: 'ยกเลิกการจอง',
    question: 'ต้องการยกเลิกการจองนี้ใช่หรือไม่ ช่วงเวลานี้จะกลับมาเปิดให้จองอีกครั้ง',
    confirm: 'ยืนยันการยกเลิก',
    busy: 'กำลังยกเลิก…',
    done: 'ยกเลิกการจอง',
    trigger: 'border-red-300 text-red-800 hover:bg-red-50',
    solid: 'bg-red-700 hover:bg-red-800',
  },
  COMPLETE: {
    path: 'complete',
    button: 'เสร็จสิ้น',
    title: 'บันทึกว่าใช้งานเสร็จสิ้น',
    question: 'ยืนยันว่าการใช้ห้องนี้เสร็จสิ้นแล้วใช่หรือไม่',
    confirm: 'ยืนยันเสร็จสิ้น',
    busy: 'กำลังบันทึก…',
    done: 'บันทึกเสร็จสิ้นการจอง',
    trigger: 'border-indigo-300 text-indigo-800 hover:bg-indigo-50',
    solid: 'bg-indigo-600 hover:bg-indigo-700',
  },
};

export default function RoomRequestsPanel() {
  // คิวเริ่มต้น: รออนุมัติ เรียงตามวันที่ใช้ห้องใกล้ที่สุดก่อน
  const table = usePagedData(getAllRoomBookings, {
    sort: 'work_date',
    order: 'asc',
    filters: { booking_status: 'PENDING' },
  });

  const [notice, setNotice] = useState(null);
  const [target, setTarget] = useState(null); // { row, action }
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);

  const statusFilter = table.params.filters.booking_status ?? '';
  const cfg = target ? ACTIONS[target.action] : null;

  const openAction = (row, action) => {
    setTarget({ row, action });
    setError(null);
  };
  const closeAction = () => setTarget(null);

  const confirm = async () => {
    setBusy(true);
    setError(null);
    try {
      await changeBookingStatus(target.row.booking_id, cfg.path);
      setNotice({ type: 'success', text: `${cfg.done} ${target.row.booking_code} แล้ว` });
      closeAction();
      table.reload();
    } catch (err) {
      setError(err.message);
      // สถานะอาจเปลี่ยนไปแล้วโดยผู้อื่น: โหลดรายการใหม่เพื่อให้ปุ่มตรงความจริง
      if (err.status === 404 || err.status === 409) table.reload();
    } finally {
      setBusy(false);
    }
  };

  const columns = [
    { key: 'booking_code', label: 'เลขที่การจอง', sortable: true },
    {
      key: 'user_name',
      label: 'ผู้จอง',
      render: (r) => (
        <>
          <span className="block font-medium text-slate-900">{r.user_name}</span>
          <span className="block text-xs text-slate-600">{ROLE_LABEL[r.user_role] ?? r.user_role}</span>
        </>
      ),
    },
    {
      key: 'room_name',
      label: 'ห้อง',
      sortable: true,
      render: (r) => (
        <>
          <span className="block font-medium text-slate-900">{r.room_name}</span>
          <span className="block text-xs text-slate-600">{r.room_code}</span>
        </>
      ),
    },
    { key: 'work_date', label: 'วันที่ใช้ห้อง', sortable: true, render: (r) => formatDate(r.work_date) },
    {
      key: 'start_time',
      label: 'เวลา',
      sortable: true,
      render: (r) => formatTimeRange(r.start_time, r.end_time),
    },
    {
      key: 'booking_status',
      label: 'สถานะ',
      sortable: true,
      render: (r) => <StatusBadge status={r.booking_status} />,
    },
    {
      key: 'booking_purpose',
      label: 'วัตถุประสงค์',
      render: (r) => <span className="line-clamp-2 max-w-[16rem]">{r.booking_purpose ?? '-'}</span>,
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
      render: (r) =>
        r.actions.length === 0 ? (
          '-'
        ) : (
          <div className="flex flex-wrap gap-2">
            {r.actions.map((a) => (
              <button
                key={a}
                type="button"
                onClick={() => openAction(r, a)}
                aria-label={`${ACTIONS[a].button} ${r.booking_code}`}
                className={`whitespace-nowrap rounded-lg border bg-white px-3 py-1 text-sm font-medium ${ACTIONS[a].trigger} ${focusRing}`}
              >
                {ACTIONS[a].button}
              </button>
            ))}
          </div>
        ),
    },
  ];

  return (
    <section aria-labelledby="room-requests-title" className="space-y-3">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h2 id="room-requests-title" className="text-lg font-semibold text-slate-800">
            จองห้อง
          </h2>
          <p className="text-sm text-slate-600" aria-live="polite">
            {statusFilter === 'PENDING' && table.meta
              ? `รออนุมัติ ${table.meta.total} รายการ`
              : 'รายการจองห้องทั้งหมด'}
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
            {BOOKING_STATUS_OPTIONS.map(([value, label]) => (
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
        caption="ตารางคำขอจองห้อง"
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

      <Modal
        open={target !== null}
        title={cfg?.title ?? ''}
        onClose={closeAction}
        busy={busy}
        footer={
          cfg && (
            <>
              <button type="button" onClick={closeAction} disabled={busy} className={btnSecondary} data-autofocus>
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
              <dt className="text-slate-600">เลขที่</dt>
              <dd className="font-medium text-slate-900">{target.row.booking_code}</dd>
              <dt className="text-slate-600">ผู้จอง</dt>
              <dd className="font-medium text-slate-900">{target.row.user_name}</dd>
              <dt className="text-slate-600">ห้อง</dt>
              <dd className="font-medium text-slate-900">{target.row.room_name}</dd>
              <dt className="text-slate-600">วันที่</dt>
              <dd className="font-medium text-slate-900">{formatDate(target.row.work_date)}</dd>
              <dt className="text-slate-600">เวลา</dt>
              <dd className="font-medium text-slate-900">
                {formatTimeRange(target.row.start_time, target.row.end_time)}
              </dd>
              <dt className="text-slate-600">วัตถุประสงค์</dt>
              <dd className="text-slate-900">{target.row.booking_purpose ?? '-'}</dd>
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