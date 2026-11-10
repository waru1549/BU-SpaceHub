import { useCallback, useState } from 'react';
import { AlertCircle, CalendarDays, ChevronLeft, ChevronRight } from 'lucide-react';
import DataTable from '../components/Tables/DataTable.jsx';
import Modal from '../components/Modals/Modal.jsx';
import PrinterCard from '../components/Cards/PrinterCard.jsx';
import PrinterActionModal from '../components/Requests/PrinterActionModal.jsx';
import StatusBadge from '../components/Badge/StatusBadge.jsx';
import Notice from '../components/Feedback/Notice.jsx';
import { useAsync } from '../hooks/useAsync.js';
import { usePagedData } from '../hooks/usePagedData.js';
import { createBooking, getAvailability, getMyBookings } from '../services/printers.service.js';
import { PRINTER_STATUS_OPTIONS } from '../utils/booking.js';
import {
  MATERIAL_LABEL,
  MATERIAL_OPTIONS,
  PRINTER_ACTIONS,
  WEIGHT_MAX,
  formatWeight,
} from '../utils/printerActions.js';
import { addDaysIso, formatDate, formatDateLong, formatTimeRange, todayIso } from '../utils/format.js';

const focusRing =
  'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-600';
const fieldClass = `rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-800 ${focusRing}`;
const btnSecondary = `rounded-lg border border-slate-300 px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-100 disabled:opacity-50 ${focusRing}`;
const btnPrimary = `rounded-lg bg-emerald-700 px-4 py-2 text-sm font-medium text-white hover:bg-emerald-800 disabled:opacity-60 ${focusRing}`;

const PURPOSE_MAX = 500;
// ผู้ใช้ทำได้เฉพาะยกเลิกและยืนยันรับงาน (ปุ่มของเจ้าหน้าที่อยู่ที่หน้าคำขอรออนุมัติ)
const OWNER_ACTIONS = ['CANCEL', 'RECEIVE'];

export default function Printers() {
  const today = todayIso();
  const [date, setDate] = useState(today);
  const [onlyBookable, setOnlyBookable] = useState(false);
  const [notice, setNotice] = useState(null);

  const fetchAvailability = useCallback(() => getAvailability({ date, onlyBookable }), [date, onlyBookable]);
  const avail = useAsync(fetchAvailability);
  const printers = avail.data ?? [];

  const table = usePagedData(getMyBookings, { sort: 'work_date', order: 'desc' });

  // ฟอร์มจอง
  const [selected, setSelected] = useState(null); // { printer, slot }
  const [purpose, setPurpose] = useState('');
  const [material, setMaterial] = useState('PLA');
  const [weight, setWeight] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [formError, setFormError] = useState(null);

  // ยกเลิก / รับงาน
  const [actionTarget, setActionTarget] = useState(null);

  const openBooking = (printer, slot) => {
    setSelected({ printer, slot });
    setPurpose('');
    setMaterial('PLA');
    setWeight('');
    setFormError(null);
  };
  const closeBooking = () => setSelected(null);

  const submitBooking = async (e) => {
    e.preventDefault();
    const text = purpose.trim();
    if (text.length < 3) {
      setFormError('กรุณาระบุวัตถุประสงค์การพิมพ์อย่างน้อย 3 ตัวอักษร');
      return;
    }
    let estWeightG = null;
    if (weight.trim() !== '') {
      estWeightG = Number(weight);
      if (!Number.isFinite(estWeightG) || estWeightG <= 0 || estWeightG > WEIGHT_MAX) {
        setFormError(`น้ำหนักโดยประมาณต้องมากกว่า 0 และไม่เกิน ${WEIGHT_MAX} กรัม`);
        return;
      }
    }
    setSubmitting(true);
    setFormError(null);
    try {
      const booking = await createBooking({
        scheduleId: selected.slot.schedule_id,
        purpose: text,
        material,
        estWeightG,
      });
      closeBooking();
      setNotice({ type: 'success', text: `จองสำเร็จ เลขที่ ${booking.booking_code} สถานะรออนุมัติ` });
      avail.reload();
      table.reload();
    } catch (err) {
      setFormError(err.message);
      if (err.status === 404 || err.status === 409) avail.reload();
    } finally {
      setSubmitting(false);
    }
  };

  const handleActionDone = (message) => {
    setActionTarget(null);
    setNotice({ type: 'success', text: message });
    avail.reload();
    table.reload();
  };

  const columns = [
    { key: 'booking_code', label: 'เลขที่การจอง', sortable: true },
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
    { key: 'work_date', label: 'วันที่', sortable: true, render: (r) => formatDate(r.work_date) },
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
      key: 'actions',
      label: 'การดำเนินการ',
      render: (r) => {
        const mine = r.actions.filter((a) => OWNER_ACTIONS.includes(a));
        if (mine.length === 0) return '-';
        return (
          <div className="flex flex-wrap gap-2">
            {mine.map((a) => (
              <button
                key={a}
                type="button"
                onClick={() => setActionTarget({ row: r, action: a })}
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
    <div className="space-y-6">
      <header>
        <h1 className="text-2xl font-bold text-slate-800">เครื่องพิมพ์ 3D</h1>
        <p className="text-sm text-slate-600">
          เลือกวันที่ แล้วเลือกช่วงเวลาที่ว่างของเครื่องพิมพ์ (ช่วงละ 4 ชั่วโมง) เมื่อพิมพ์เสร็จให้มารับงานแล้วกดยืนยันในหน้านี้
        </p>
      </header>

      {notice && (
        <Notice type={notice.type} onDismiss={() => setNotice(null)}>
          {notice.text}
        </Notice>
      )}

      <section aria-label="เลือกวันที่และตัวกรอง" className="flex flex-wrap items-end gap-x-4 gap-y-3">
        <div>
          <label htmlFor="printer-date" className="mb-1 block text-xs font-semibold text-slate-600">
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
              id="printer-date"
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

        <label className="flex h-10 items-center gap-2 text-sm text-slate-700">
          <input
            type="checkbox"
            name="only_bookable"
            checked={onlyBookable}
            onChange={(e) => setOnlyBookable(e.target.checked)}
            className={`h-4 w-4 rounded border-slate-300 text-emerald-700 ${focusRing}`}
          />
          แสดงเฉพาะช่วงที่จองได้
        </label>
      </section>

      <section aria-labelledby="printers-title" className="space-y-3">
        <div className="flex flex-wrap items-baseline justify-between gap-2">
          <h2 id="printers-title" className="flex items-center gap-2 text-lg font-semibold text-slate-800">
            <CalendarDays className="h-5 w-5 text-emerald-700" aria-hidden="true" />
            {formatDateLong(date)}
          </h2>
          <p className="text-sm text-slate-600" aria-live="polite">
            {avail.loading ? 'กำลังโหลด…' : avail.error ? '' : `พบ ${printers.length} เครื่อง`}
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
        ) : avail.loading && printers.length === 0 ? (
          <div aria-hidden="true" className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
            {Array.from({ length: 6 }, (_, i) => (
              <div key={i} className="h-56 animate-pulse rounded-2xl bg-slate-200 motion-reduce:animate-none" />
            ))}
          </div>
        ) : printers.length === 0 ? (
          <p className="rounded-2xl border border-slate-200 bg-white py-12 text-center text-slate-600">
            ไม่พบเครื่องพิมพ์ตามเงื่อนไขที่เลือก
          </p>
        ) : (
          <div
            className={`grid gap-4 sm:grid-cols-2 xl:grid-cols-3 ${avail.loading ? 'opacity-60 transition-opacity' : ''}`}
            aria-busy={avail.loading}
          >
            {printers.map((printer) => (
              <PrinterCard key={printer.resource_id} printer={printer} onSelectSlot={openBooking} />
            ))}
          </div>
        )}
      </section>

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
              {PRINTER_STATUS_OPTIONS.map(([value, label]) => (
                <option key={value} value={value}>
                  {label}
                </option>
              ))}
            </select>
          </label>
        </div>

        <DataTable
          caption="ตารางการจองเครื่องพิมพ์ 3D ของฉัน"
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
          emptyText="คุณยังไม่มีการจองเครื่องพิมพ์"
        />
      </section>

      <Modal
        open={selected !== null}
        title="ยืนยันการจองเครื่องพิมพ์"
        onClose={closeBooking}
        busy={submitting}
        footer={
          <>
            <button type="button" onClick={closeBooking} disabled={submitting} className={btnSecondary}>
              ยกเลิก
            </button>
            <button type="submit" form="printer-booking-form" disabled={submitting} className={btnPrimary}>
              {submitting ? 'กำลังจอง…' : 'ยืนยันการจอง'}
            </button>
          </>
        }
      >
        {selected && (
          <form id="printer-booking-form" onSubmit={submitBooking} noValidate className="space-y-4">
            <dl className="grid grid-cols-[5rem_1fr] gap-x-3 gap-y-1 text-sm">
              <dt className="text-slate-600">เครื่อง</dt>
              <dd className="font-medium text-slate-900">
                {selected.printer.resource_name}
                <span className="ml-1 text-xs font-normal text-slate-600">({selected.printer.resource_code})</span>
              </dd>
              <dt className="text-slate-600">วันที่</dt>
              <dd className="font-medium text-slate-900">{formatDateLong(selected.slot.work_date)}</dd>
              <dt className="text-slate-600">เวลา</dt>
              <dd className="font-medium text-slate-900">
                {formatTimeRange(selected.slot.start_time, selected.slot.end_time)}
              </dd>
            </dl>

            <div>
              <label htmlFor="printer-purpose" className="mb-1 block text-sm font-medium text-slate-800">
                วัตถุประสงค์การพิมพ์
              </label>
              <textarea
                id="printer-purpose"
                name="purpose"
                data-autofocus
                rows={3}
                maxLength={PURPOSE_MAX}
                value={purpose}
                onChange={(e) => setPurpose(e.target.value)}
                aria-describedby={formError ? 'printer-booking-error' : 'printer-booking-hint'}
                aria-invalid={formError ? 'true' : undefined}
                className={`w-full ${fieldClass}`}
                placeholder="เช่น ชิ้นส่วนต้นแบบโปรเจกต์วิชาออกแบบ"
              />
              <p id="printer-booking-hint" className="mt-1 text-right text-xs text-slate-600">
                {purpose.length}/{PURPOSE_MAX}
              </p>
            </div>

            <div className="grid gap-4 sm:grid-cols-2">
              <div>
                <label htmlFor="printer-material" className="mb-1 block text-sm font-medium text-slate-800">
                  วัสดุ
                </label>
                <select
                  id="printer-material"
                  name="material"
                  value={material}
                  onChange={(e) => setMaterial(e.target.value)}
                  className={`w-full ${fieldClass}`}
                >
                  {MATERIAL_OPTIONS.map(([value, label]) => (
                    <option key={value} value={value}>
                      {label}
                    </option>
                  ))}
                </select>
              </div>
              <div>
                <label htmlFor="printer-weight" className="mb-1 block text-sm font-medium text-slate-800">
                  น้ำหนักโดยประมาณ (กรัม)
                </label>
                <input
                  id="printer-weight"
                  name="est_weight_g"
                  type="number"
                  inputMode="decimal"
                  min="1"
                  max={WEIGHT_MAX}
                  step="0.1"
                  value={weight}
                  onChange={(e) => setWeight(e.target.value)}
                  placeholder="ไม่บังคับ"
                  className={`w-full ${fieldClass}`}
                />
              </div>
            </div>

            {formError && (
              <p id="printer-booking-error" role="alert" className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-900">
                {formError}
              </p>
            )}
            <p className="text-xs text-slate-600">การจองจะอยู่ในสถานะ "รออนุมัติ" จนกว่าเจ้าหน้าที่จะตอบรับ</p>
          </form>
        )}
      </Modal>

      <PrinterActionModal
        target={actionTarget}
        onClose={() => setActionTarget(null)}
        onDone={handleActionDone}
        onStale={() => {
          table.reload();
          avail.reload();
        }}
      />
    </div>
  );
}
