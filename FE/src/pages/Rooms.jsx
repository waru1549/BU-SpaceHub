import { useCallback, useState } from 'react';
import { AlertCircle, CalendarDays, ChevronLeft, ChevronRight } from 'lucide-react';
import DataTable from '../components/Tables/DataTable.jsx';
import Modal from '../components/Modals/Modal.jsx';
import RoomCard from '../components/Cards/RoomCard.jsx';
import StatusBadge from '../components/Badge/StatusBadge.jsx';
import Notice from '../components/Feedback/Notice.jsx';
import { useAsync } from '../hooks/useAsync.js';
import { usePagedData } from '../hooks/usePagedData.js';
import {
  changeBookingStatus,
  createBooking,
  getAvailability,
  getMyBookings,
} from '../services/rooms.service.js';
import { BOOKING_STATUS_OPTIONS } from '../utils/booking.js';
import { addDaysIso, formatDate, formatDateLong, formatTimeRange, todayIso } from '../utils/format.js';

const focusRing =
  'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-500';
const fieldClass = `rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-800 ${focusRing}`;
const btnSecondary = `rounded-lg border border-slate-300 px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-100 disabled:opacity-50 ${focusRing}`;
const btnPrimary = `rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700 disabled:opacity-60 ${focusRing}`;

const CAPACITY_OPTIONS = [
  ['', 'ทุกขนาด'],
  ['10', 'ตั้งแต่ 10 คน'],
  ['20', 'ตั้งแต่ 20 คน'],
  ['30', 'ตั้งแต่ 30 คน'],
  ['50', 'ตั้งแต่ 50 คน'],
];

const PURPOSE_MAX = 500;

export default function Rooms() {
  const today = todayIso();
  const [date, setDate] = useState(today);
  const [minCapacity, setMinCapacity] = useState('');
  const [onlyBookable, setOnlyBookable] = useState(false);
  const [notice, setNotice] = useState(null);

  // ห้อง + ช่วงเวลา: ดึงใหม่อัตโนมัติเมื่อเงื่อนไขเปลี่ยน
  const fetchAvailability = useCallback(
    () => getAvailability({ date, onlyBookable, minCapacity }),
    [date, onlyBookable, minCapacity],
  );
  const avail = useAsync(fetchAvailability);
  const rooms = avail.data ?? [];

  // การจองของฉัน
  const table = usePagedData(getMyBookings, { sort: 'work_date', order: 'desc' });

  // หน้าต่างยืนยันการจอง
  const [selected, setSelected] = useState(null); // { room, slot }
  const [purpose, setPurpose] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [formError, setFormError] = useState(null);

  // หน้าต่างยืนยันการยกเลิก
  const [cancelTarget, setCancelTarget] = useState(null);
  const [cancelling, setCancelling] = useState(false);
  const [cancelError, setCancelError] = useState(null);

  const openBooking = (room, slot) => {
    setSelected({ room, slot });
    setPurpose('');
    setFormError(null);
  };
  const closeBooking = () => setSelected(null);
  const closeCancel = () => setCancelTarget(null);

  const submitBooking = async (e) => {
    e.preventDefault();
    const text = purpose.trim();
    if (text.length < 3) {
      setFormError('กรุณาระบุวัตถุประสงค์การใช้ห้องอย่างน้อย 3 ตัวอักษร');
      return;
    }
    setSubmitting(true);
    setFormError(null);
    try {
      const booking = await createBooking({ scheduleId: selected.slot.schedule_id, purpose: text });
      closeBooking();
      setNotice({ type: 'success', text: `จองสำเร็จ เลขที่ ${booking.booking_code} สถานะรออนุมัติ` });
      avail.reload();
      table.reload();
    } catch (err) {
      setFormError(err.message);
      // ช่วงเวลาอาจถูกจองไปแล้วหรือเปลี่ยนสถานะ: รีเฟรชรายการหลังหน้าต่าง
      if (err.status === 404 || err.status === 409) avail.reload();
    } finally {
      setSubmitting(false);
    }
  };

  const confirmCancel = async () => {
    setCancelling(true);
    setCancelError(null);
    try {
      await changeBookingStatus(cancelTarget.booking_id, 'cancel');
      setNotice({ type: 'success', text: `ยกเลิกการจอง ${cancelTarget.booking_code} แล้ว` });
      closeCancel();
      avail.reload();
      table.reload();
    } catch (err) {
      setCancelError(err.message);
      if (err.status === 404 || err.status === 409) table.reload();
    } finally {
      setCancelling(false);
    }
  };

  const columns = [
    { key: 'booking_code', label: 'เลขที่การจอง', sortable: true },
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
    { key: 'work_date', label: 'วันที่', sortable: true, render: (r) => formatDate(r.work_date) },
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
      key: 'actions',
      label: 'การดำเนินการ',
      render: (r) =>
        r.actions.includes('CANCEL') ? (
          <button
            type="button"
            onClick={() => {
              setCancelTarget(r);
              setCancelError(null);
            }}
            aria-label={`ยกเลิกการจอง ${r.booking_code}`}
            className={`rounded-lg border border-red-300 px-3 py-1 text-sm font-medium text-red-800 hover:bg-red-50 ${focusRing}`}
          >
            ยกเลิก
          </button>
        ) : (
          '-'
        ),
    },
  ];

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-2xl font-bold text-slate-800">จองห้อง</h1>
        <p className="text-sm text-slate-600">เลือกวันที่ แล้วเลือกช่วงเวลาที่ว่างของห้องที่ต้องการ</p>
      </header>

      {notice && (
        <Notice type={notice.type} onDismiss={() => setNotice(null)}>
          {notice.text}
        </Notice>
      )}

      {/* ตัวเลือกวันที่และตัวกรอง */}
      <section aria-label="เลือกวันที่และตัวกรอง" className="flex flex-wrap items-end gap-x-4 gap-y-3">
        <div>
          <label htmlFor="room-date" className="mb-1 block text-xs font-semibold text-slate-600">
            วันที่
          </label>
          <div className="flex items-center gap-1">
            <button
              type="button"
              onClick={() => setDate(addDaysIso(date, -1))}
              disabled={date <= today}
              aria-label="วันก่อนหน้า"
              className={`grid h-10 w-10 place-items-center rounded-lg border border-slate-300 text-slate-700 hover:bg-slate-100 disabled:opacity-40 ${focusRing}`}
            >
              <ChevronLeft className="h-4 w-4" aria-hidden="true" />
            </button>
            <input
              id="room-date"
              name="date"
              type="date"
              min={today}
              value={date}
              onChange={(e) => {
                const v = e.target.value;
                if (v) setDate(v < today ? today : v);
              }}
              className={`h-10 ${fieldClass}`}
            />
            <button
              type="button"
              onClick={() => setDate(addDaysIso(date, 1))}
              aria-label="วันถัดไป"
              className={`grid h-10 w-10 place-items-center rounded-lg border border-slate-300 text-slate-700 hover:bg-slate-100 ${focusRing}`}
            >
              <ChevronRight className="h-4 w-4" aria-hidden="true" />
            </button>
            <button type="button" onClick={() => setDate(today)} disabled={date === today} className={`h-10 ${btnSecondary}`}>
              วันนี้
            </button>
          </div>
        </div>

        <div>
          <label htmlFor="room-capacity" className="mb-1 block text-xs font-semibold text-slate-600">
            ความจุ
          </label>
          <select
            id="room-capacity"
            name="min_capacity"
            value={minCapacity}
            onChange={(e) => setMinCapacity(e.target.value)}
            className={`h-10 ${fieldClass}`}
          >
            {CAPACITY_OPTIONS.map(([value, label]) => (
              <option key={value} value={value}>
                {label}
              </option>
            ))}
          </select>
        </div>

        <label className="flex h-10 items-center gap-2 text-sm text-slate-700">
          <input
            type="checkbox"
            name="only_bookable"
            checked={onlyBookable}
            onChange={(e) => setOnlyBookable(e.target.checked)}
            className={`h-4 w-4 rounded border-slate-300 text-indigo-600 ${focusRing}`}
          />
          แสดงเฉพาะช่วงที่จองได้
        </label>
      </section>

      {/* รายการห้อง */}
      <section aria-labelledby="rooms-title" className="space-y-3">
        <div className="flex flex-wrap items-baseline justify-between gap-2">
          <h2 id="rooms-title" className="flex items-center gap-2 text-lg font-semibold text-slate-800">
            <CalendarDays className="h-5 w-5 text-indigo-600" aria-hidden="true" />
            {formatDateLong(date)}
          </h2>
          <p className="text-sm text-slate-600" aria-live="polite">
            {avail.loading ? 'กำลังโหลด…' : avail.error ? '' : `พบ ${rooms.length} ห้อง`}
          </p>
        </div>

        {avail.error ? (
          <div role="alert" className="flex flex-col items-center gap-3 rounded-2xl border border-slate-200 bg-white py-12 text-slate-700">
            <AlertCircle className="h-8 w-8 text-red-700" aria-hidden="true" />
            <p>{avail.error}</p>
            <button type="button" onClick={avail.reload} className={btnPrimary}>
              ลองอีกครั้ง
            </button>
          </div>
        ) : avail.loading && rooms.length === 0 ? (
          <div aria-hidden="true" className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
            {Array.from({ length: 6 }, (_, i) => (
              <div key={i} className="h-56 animate-pulse rounded-2xl bg-slate-200 motion-reduce:animate-none" />
            ))}
          </div>
        ) : rooms.length === 0 ? (
          <p className="rounded-2xl border border-slate-200 bg-white py-12 text-center text-slate-600">
            ไม่พบห้องตามเงื่อนไขที่เลือก
          </p>
        ) : (
          <div
            className={`grid gap-4 sm:grid-cols-2 xl:grid-cols-3 ${avail.loading ? 'opacity-60 transition-opacity' : ''}`}
            aria-busy={avail.loading}
          >
            {rooms.map((room) => (
              <RoomCard key={room.resource_id} room={room} onSelectSlot={openBooking} />
            ))}
          </div>
        )}
      </section>

      {/* การจองของฉัน */}
      <section aria-labelledby="mine-title" className="space-y-3">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <h2 id="mine-title" className="text-lg font-semibold text-slate-800">
            การจองของฉัน
          </h2>
          <label className="flex items-center gap-2 text-sm text-slate-700">
            <span>สถานะ</span>
            <select
              name="booking_status"
              value={table.params.filters.booking_status ?? ''}
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

        <DataTable
          caption="ตารางการจองห้องของฉัน"
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
          emptyText="คุณยังไม่มีการจองห้อง"
        />
      </section>

      {/* ยืนยันการจอง */}
      <Modal
        open={selected !== null}
        title="ยืนยันการจองห้อง"
        onClose={closeBooking}
        busy={submitting}
        footer={
          <>
            <button type="button" onClick={closeBooking} disabled={submitting} className={btnSecondary}>
              ยกเลิก
            </button>
            <button type="submit" form="booking-form" disabled={submitting} className={btnPrimary}>
              {submitting ? 'กำลังจอง…' : 'ยืนยันการจอง'}
            </button>
          </>
        }
      >
        {selected && (
          <form id="booking-form" onSubmit={submitBooking} noValidate className="space-y-4">
            <dl className="grid grid-cols-[5rem_1fr] gap-x-3 gap-y-1 text-sm">
              <dt className="text-slate-600">ห้อง</dt>
              <dd className="font-medium text-slate-900">
                {selected.room.resource_name}
                <span className="ml-1 text-xs font-normal text-slate-600">({selected.room.resource_code})</span>
              </dd>
              <dt className="text-slate-600">วันที่</dt>
              <dd className="font-medium text-slate-900">{formatDateLong(selected.slot.work_date)}</dd>
              <dt className="text-slate-600">เวลา</dt>
              <dd className="font-medium text-slate-900">
                {formatTimeRange(selected.slot.start_time, selected.slot.end_time)}
              </dd>
            </dl>

            <div>
              <label htmlFor="booking-purpose" className="mb-1 block text-sm font-medium text-slate-800">
                วัตถุประสงค์การใช้ห้อง
              </label>
              <textarea
                id="booking-purpose"
                name="purpose"
                data-autofocus
                rows={3}
                maxLength={PURPOSE_MAX}
                value={purpose}
                onChange={(e) => setPurpose(e.target.value)}
                aria-describedby={formError ? 'booking-error' : 'booking-hint'}
                aria-invalid={formError ? 'true' : undefined}
                className={`w-full ${fieldClass}`}
                placeholder="เช่น ติวสอบวิชาฐานข้อมูลกับเพื่อน"
              />
              <p id="booking-hint" className="mt-1 text-right text-xs text-slate-600">
                {purpose.length}/{PURPOSE_MAX}
              </p>
            </div>

            {formError && (
              <p id="booking-error" role="alert" className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-900">
                {formError}
              </p>
            )}
            <p className="text-xs text-slate-600">การจองจะอยู่ในสถานะ "รออนุมัติ" จนกว่าเจ้าหน้าที่จะตอบรับ</p>
          </form>
        )}
      </Modal>

      {/* ยืนยันการยกเลิก */}
      <Modal
        open={cancelTarget !== null}
        title="ยกเลิกการจอง"
        onClose={closeCancel}
        busy={cancelling}
        footer={
          <>
            <button type="button" onClick={closeCancel} disabled={cancelling} className={btnSecondary} data-autofocus>
              ไม่ยกเลิก
            </button>
            <button
              type="button"
              onClick={confirmCancel}
              disabled={cancelling}
              className={`rounded-lg bg-red-700 px-4 py-2 text-sm font-medium text-white hover:bg-red-800 disabled:opacity-60 ${focusRing}`}
            >
              {cancelling ? 'กำลังยกเลิก…' : 'ยืนยันการยกเลิก'}
            </button>
          </>
        }
      >
        {cancelTarget && (
          <div className="space-y-3 text-sm text-slate-700">
            <p>
              ต้องการยกเลิกการจอง <strong className="text-slate-900">{cancelTarget.booking_code}</strong> ใช่หรือไม่
            </p>
            <p>
              {cancelTarget.room_name} วันที่ {formatDate(cancelTarget.work_date)} เวลา{' '}
              {formatTimeRange(cancelTarget.start_time, cancelTarget.end_time)}
            </p>
            {cancelError && (
              <p role="alert" className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-red-900">
                {cancelError}
              </p>
            )}
          </div>
        )}
      </Modal>
    </div>
  );
}