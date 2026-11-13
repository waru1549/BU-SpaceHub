import { useCallback, useMemo, useState } from 'react';
import { AlertCircle, Info } from 'lucide-react';
import DataTable from '../components/Tables/DataTable.jsx';
import Modal from '../components/Modals/Modal.jsx';
import EquipmentCard from '../components/Cards/EquipmentCard.jsx';
import EquipmentActionModal from '../components/Requests/EquipmentActionModal.jsx';
import StatusBadge from '../components/Badge/StatusBadge.jsx';
import FineBadge, { FINE_STATUS_OPTIONS } from '../components/Badge/FineBadge.jsx';
import Notice from '../components/Feedback/Notice.jsx';
import { useAsync } from '../hooks/useAsync.js';
import { usePagedData } from '../hooks/usePagedData.js';
import { createBooking, getAvailability, getMyBookings, getMyFines } from '../services/equipment.service.js';
import { EQUIPMENT_STATUS_OPTIONS } from '../utils/booking.js';
import { EQUIPMENT_ACTIONS, LOAN_RULES, formatBaht, formatDay, formatDayTime } from '../utils/equipment.js';
import { addDaysIso, todayIso } from '../utils/format.js';

const focusRing =
  'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-amber-600';
const fieldClass = `rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-800 ${focusRing}`;
const btnSecondary = `rounded-lg border border-slate-300 px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-100 disabled:opacity-50 ${focusRing}`;
const btnPrimary = `rounded-lg bg-amber-700 px-4 py-2 text-sm font-medium text-white hover:bg-amber-800 disabled:opacity-60 ${focusRing}`;

const PURPOSE_MAX = 500;
const clamp = (value, min, max) => (value < min ? min : value > max ? max : value);

// ใช้ดูว่าผู้ใช้ถูกบล็อกยืมใหม่หรือไม่ (ดึงแค่จำนวน)
const countParams = (filterKey, value) => ({
  page: 1,
  limit: 1,
  sort: filterKey === 'fine_status' ? 'fine_id' : 'borrow_date',
  order: 'desc',
  filters: { [filterKey]: value },
});

export default function Equipment() {
  const today = todayIso();
  const maxBorrow = addDaysIso(today, LOAN_RULES.maxAheadDays);

  const [borrow, setBorrow] = useState(today);
  const [ret, setRet] = useState(addDaysIso(today, 2));
  const [onlyBorrowable, setOnlyBorrowable] = useState(false);
  const [search, setSearch] = useState('');
  const [notice, setNotice] = useState(null);

  const onBorrowChange = (value) => {
    if (!value) return;
    const b = clamp(value, today, maxBorrow);
    setBorrow(b);
    setRet((r) => clamp(r, b, addDaysIso(b, LOAN_RULES.maxDays)));
  };
  const onReturnChange = (value) => {
    if (!value) return;
    setRet(clamp(value, borrow, addDaysIso(borrow, LOAN_RULES.maxDays)));
  };

  const fetchAvailability = useCallback(
    () => getAvailability({ borrowDate: borrow, returnDate: ret, onlyBorrowable }),
    [borrow, ret, onlyBorrowable],
  );
  const avail = useAsync(fetchAvailability);
  const items = useMemo(() => {
    const q = search.trim().toLowerCase();
    const all = avail.data ?? [];
    if (!q) return all;
    return all.filter((i) => `${i.resource_name} ${i.resource_code}`.toLowerCase().includes(q));
  }, [avail.data, search]);

  const bookings = usePagedData(getMyBookings, { sort: 'borrow_date', order: 'desc' });
  const fines = usePagedData(getMyFines, { sort: 'fine_id', order: 'desc' });

  // ผู้ใช้ที่มีของเกินกำหนดหรือค่าปรับค้างจะยืมใหม่ไม่ได้ (บังคับที่ DB) แจ้งไว้ล่วงหน้า
  const fetchUnpaid = useCallback(() => getMyFines(countParams('fine_status', 'UNPAID')), []);
  const fetchOverdue = useCallback(() => getMyBookings(countParams('booking_status', 'OVERDUE')), []);
  const unpaid = useAsync(fetchUnpaid);
  const overdue = useAsync(fetchOverdue);
  const blockedReasons = [];
  if ((overdue.data?.meta?.total ?? 0) > 0) blockedReasons.push('มีอุปกรณ์เกินกำหนดคืน');
  if ((unpaid.data?.meta?.total ?? 0) > 0) blockedReasons.push('มีค่าปรับค้างชำระ');

  const reloadAll = () => {
    avail.reload();
    bookings.reload();
    fines.reload();
    unpaid.reload();
    overdue.reload();
  };

  // ฟอร์มขอยืม
  const [selected, setSelected] = useState(null);
  const [purpose, setPurpose] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [formError, setFormError] = useState(null);
  const [actionTarget, setActionTarget] = useState(null);

  const openBorrow = (item) => {
    setSelected(item);
    setPurpose('');
    setFormError(null);
  };
  const closeBorrow = () => setSelected(null);

  const submitBorrow = async (e) => {
    e.preventDefault();
    const text = purpose.trim();
    if (text.length < 3) {
      setFormError('กรุณาระบุวัตถุประสงค์การยืมอย่างน้อย 3 ตัวอักษร');
      return;
    }
    setSubmitting(true);
    setFormError(null);
    try {
      const booking = await createBooking({
        resourceId: selected.resource_id,
        borrowDate: borrow,
        returnDate: ret,
        purpose: text,
      });
      closeBorrow();
      setNotice({ type: 'success', text: `ส่งคำขอยืมสำเร็จ เลขที่ ${booking.booking_code} สถานะรออนุมัติ` });
      reloadAll();
    } catch (err) {
      setFormError(err.message);
      if (err.status === 404 || err.status === 409) avail.reload();
    } finally {
      setSubmitting(false);
    }
  };

  const bookingColumns = [
    { key: 'booking_code', label: 'เลขที่การยืม', sortable: true },
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
      key: 'total_fine',
      label: 'ค่าปรับ',
      render: (r) =>
        Number(r.total_fine) > 0 ? (
          <span className="whitespace-nowrap">
            {formatBaht(r.total_fine)}
            {Number(r.unpaid_fine) > 0 && <span className="block text-xs text-red-800">ค้างชำระ</span>}
          </span>
        ) : (
          '-'
        ),
    },
    {
      key: 'actions',
      label: 'การดำเนินการ',
      render: (r) =>
        r.actions.includes('CANCEL') ? (
          <button
            type="button"
            onClick={() => setActionTarget({ row: r, action: 'CANCEL' })}
            aria-label={`ยกเลิกคำขอยืม ${r.booking_code}`}
            className={`rounded-lg border bg-white px-3 py-1 text-sm font-medium ${EQUIPMENT_ACTIONS.CANCEL.trigger} ${focusRing}`}
          >
            ยกเลิก
          </button>
        ) : (
          '-'
        ),
    },
  ];

  const fineColumns = [
    { key: 'booking_code', label: 'เลขที่การยืม', sortable: true },
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
  ];

  const pagerProps = (t) => ({
    loading: t.loading,
    error: t.error,
    onRetry: t.reload,
    page: t.params.page,
    limit: t.params.limit,
    total: t.meta?.total ?? 0,
    totalPages: t.meta?.totalPages ?? 1,
    sort: t.params.sort,
    order: t.params.order,
    onPageChange: t.setPage,
    onLimitChange: t.setLimit,
    onSortChange: t.setSort,
  });

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-2xl font-bold text-slate-800">ยืม-คืนอุปกรณ์</h1>
        <p className="text-sm text-slate-600">เลือกช่วงวันที่ยืม แล้วขอยืมอุปกรณ์ที่ยังมีเหลือ รับ-คืนของที่ห้องอุปกรณ์กับเจ้าหน้าที่</p>
      </header>

      <div className="flex gap-3 rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-900">
        <Info className="mt-0.5 h-4 w-4 shrink-0" aria-hidden="true" />
        <p>
          ยืมได้ไม่เกิน {LOAN_RULES.maxDays} วัน, พร้อมกันไม่เกิน {LOAN_RULES.maxActive} รายการ, จองล่วงหน้าไม่เกิน{' '}
          {LOAN_RULES.maxAheadDays} วัน, กำหนดคืนเวลา {LOAN_RULES.dueHour} น. คืนล่าช้าไม่คิดค่าปรับ
          แต่หากอุปกรณ์ชำรุดหรือสูญหายจะมีค่าปรับ
        </p>
      </div>

      {blockedReasons.length > 0 && (
        <div role="alert" className="flex gap-3 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-900">
          <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" aria-hidden="true" />
          <p>
            คุณ{blockedReasons.join(' และ ')} จึงยังขอยืมอุปกรณ์ใหม่ไม่ได้ จนกว่าจะคืนอุปกรณ์และชำระหรือได้รับการยกเว้นค่าปรับ
          </p>
        </div>
      )}

      {notice && (
        <Notice type={notice.type} onDismiss={() => setNotice(null)}>
          {notice.text}
        </Notice>
      )}

      <section aria-label="เลือกช่วงวันที่ยืมและตัวกรอง" className="flex flex-wrap items-end gap-x-4 gap-y-3">
        <div>
          <label htmlFor="eq-borrow" className="mb-1 block text-xs font-semibold text-slate-600">
            วันที่ยืม
          </label>
          <input
            id="eq-borrow"
            name="borrow_date"
            type="date"
            min={today}
            max={maxBorrow}
            value={borrow}
            onChange={(e) => onBorrowChange(e.target.value)}
            className={`h-10 ${fieldClass}`}
          />
        </div>
        <div>
          <label htmlFor="eq-return" className="mb-1 block text-xs font-semibold text-slate-600">
            วันที่คืน
          </label>
          <input
            id="eq-return"
            name="return_date"
            type="date"
            min={borrow}
            max={addDaysIso(borrow, LOAN_RULES.maxDays)}
            value={ret}
            onChange={(e) => onReturnChange(e.target.value)}
            className={`h-10 ${fieldClass}`}
          />
        </div>
        <div>
          <label htmlFor="eq-search" className="mb-1 block text-xs font-semibold text-slate-600">
            ค้นหา
          </label>
          <input
            id="eq-search"
            name="search"
            type="search"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="ชื่อหรือรหัสอุปกรณ์"
            className={`h-10 ${fieldClass}`}
          />
        </div>
        <label className="flex h-10 items-center gap-2 text-sm text-slate-700">
          <input
            type="checkbox"
            name="only_borrowable"
            checked={onlyBorrowable}
            onChange={(e) => setOnlyBorrowable(e.target.checked)}
            className={`h-4 w-4 rounded border-slate-300 text-amber-700 ${focusRing}`}
          />
          แสดงเฉพาะที่ยืมได้
        </label>
      </section>

      <section aria-labelledby="equipment-title" className="space-y-3">
        <div className="flex flex-wrap items-baseline justify-between gap-2">
          <h2 id="equipment-title" className="text-lg font-semibold text-slate-800">
            {formatDay(borrow)} – {formatDay(ret)}
          </h2>
          <p className="text-sm text-slate-600" aria-live="polite">
            {avail.loading ? 'กำลังโหลด…' : avail.error ? '' : `พบ ${items.length} รายการ`}
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
        ) : avail.loading && items.length === 0 ? (
          <div aria-hidden="true" className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
            {Array.from({ length: 6 }, (_, i) => (
              <div key={i} className="h-48 animate-pulse rounded-2xl bg-slate-200 motion-reduce:animate-none" />
            ))}
          </div>
        ) : items.length === 0 ? (
          <p className="rounded-2xl border border-slate-200 bg-white py-12 text-center text-slate-600">
            ไม่พบอุปกรณ์ตามเงื่อนไขที่เลือก
          </p>
        ) : (
          <div
            className={`grid gap-4 sm:grid-cols-2 xl:grid-cols-3 ${avail.loading ? 'opacity-60 transition-opacity' : ''}`}
            aria-busy={avail.loading}
          >
            {items.map((item) => (
              <EquipmentCard key={item.resource_id} item={item} onBorrow={openBorrow} />
            ))}
          </div>
        )}
      </section>

      <section aria-labelledby="my-loans-title" className="space-y-3">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <h2 id="my-loans-title" className="text-lg font-semibold text-slate-800">
            การยืมของฉัน
          </h2>
          <label className="flex items-center gap-2 text-sm text-slate-700">
            <span>สถานะ</span>
            <select
              name="booking_status"
              value={bookings.params.filters.booking_status ?? ''}
              onChange={(e) => bookings.setFilter('booking_status', e.target.value)}
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
        <DataTable
          caption="ตารางการยืมอุปกรณ์ของฉัน"
          columns={bookingColumns}
          rows={bookings.rows}
          rowKey="booking_id"
          emptyText="คุณยังไม่มีการยืมอุปกรณ์"
          {...pagerProps(bookings)}
        />
      </section>

      <section aria-labelledby="my-fines-title" className="space-y-3">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <h2 id="my-fines-title" className="text-lg font-semibold text-slate-800">
            ค่าปรับของฉัน
          </h2>
          <label className="flex items-center gap-2 text-sm text-slate-700">
            <span>สถานะ</span>
            <select
              name="fine_status"
              value={fines.params.filters.fine_status ?? ''}
              onChange={(e) => fines.setFilter('fine_status', e.target.value)}
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
        <DataTable
          caption="ตารางค่าปรับของฉัน"
          columns={fineColumns}
          rows={fines.rows}
          rowKey="fine_id"
          emptyText="คุณไม่มีค่าปรับ"
          {...pagerProps(fines)}
        />
        <p className="text-xs text-slate-600">ชำระค่าปรับหรือขอยกเว้นได้ที่เจ้าหน้าที่ห้องอุปกรณ์</p>
      </section>

      <Modal
        open={selected !== null}
        title="ขอยืมอุปกรณ์"
        onClose={closeBorrow}
        busy={submitting}
        footer={
          <>
            <button type="button" onClick={closeBorrow} disabled={submitting} className={btnSecondary}>
              ยกเลิก
            </button>
            <button type="submit" form="equipment-form" disabled={submitting} className={btnPrimary}>
              {submitting ? 'กำลังส่งคำขอ…' : 'ยืนยันคำขอยืม'}
            </button>
          </>
        }
      >
        {selected && (
          <form id="equipment-form" onSubmit={submitBorrow} noValidate className="space-y-4">
            <dl className="grid grid-cols-[6rem_1fr] gap-x-3 gap-y-1 text-sm">
              <dt className="text-slate-600">อุปกรณ์</dt>
              <dd className="font-medium text-slate-900">
                {selected.resource_name}
                <span className="ml-1 text-xs font-normal text-slate-600">({selected.resource_code})</span>
              </dd>
              <dt className="text-slate-600">วันที่ยืม</dt>
              <dd className="font-medium text-slate-900">{formatDay(borrow)}</dd>
              <dt className="text-slate-600">กำหนดคืน</dt>
              <dd className="font-medium text-slate-900">
                {formatDay(ret)} เวลา {LOAN_RULES.dueHour} น.
              </dd>
            </dl>

            <div>
              <label htmlFor="equipment-purpose" className="mb-1 block text-sm font-medium text-slate-800">
                วัตถุประสงค์การยืม
              </label>
              <textarea
                id="equipment-purpose"
                name="purpose"
                data-autofocus
                rows={3}
                maxLength={PURPOSE_MAX}
                value={purpose}
                onChange={(e) => setPurpose(e.target.value)}
                aria-describedby={formError ? 'equipment-error' : 'equipment-hint'}
                aria-invalid={formError ? 'true' : undefined}
                className={`w-full ${fieldClass}`}
                placeholder="เช่น ถ่ายงานโปรเจกต์วิชาสื่อดิจิทัล"
              />
              <p id="equipment-hint" className="mt-1 text-right text-xs text-slate-600">
                {purpose.length}/{PURPOSE_MAX}
              </p>
            </div>

            {formError && (
              <p id="equipment-error" role="alert" className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-900">
                {formError}
              </p>
            )}
            <p className="text-xs text-slate-600">คำขอจะอยู่ในสถานะ "รออนุมัติ" จนกว่าเจ้าหน้าที่จะตอบรับ แล้วจึงรับของที่ห้องอุปกรณ์</p>
          </form>
        )}
      </Modal>

      <EquipmentActionModal
        target={actionTarget}
        onClose={() => setActionTarget(null)}
        onDone={(message) => {
          setActionTarget(null);
          setNotice({ type: 'success', text: message });
          reloadAll();
        }}
        onStale={reloadAll}
      />
    </div>
  );
}
