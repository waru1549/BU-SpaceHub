import { useState } from 'react';
import Modal from '../Modals/Modal.jsx';
import { changeBookingStatus } from '../../services/equipment.service.js';
import {
  EQUIPMENT_ACTIONS,
  FINE_AMOUNT_MAX,
  formatBaht,
  formatDay,
  formatDayTime,
} from '../../utils/equipment.js';

const focusRing =
  'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-amber-600';
const fieldClass = `w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-800 ${focusRing}`;
const btnSecondary = `rounded-lg border border-slate-300 px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-100 disabled:opacity-50 ${focusRing}`;

// กล่องยืนยันการดำเนินการกับการยืมอุปกรณ์ (ใช้ร่วมกันในหน้าผู้ใช้และคิวเจ้าหน้าที่)
// target = { row, action } | null ; onDone(ข้อความ) ; onStale() เมื่อสถานะเปลี่ยนไปแล้ว
export default function EquipmentActionModal({ target, onClose, onDone, onStale }) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const [hasFine, setHasFine] = useState(false);
  const [amount, setAmount] = useState('');
  const [reason, setReason] = useState('');

  const cfg = target ? EQUIPMENT_ACTIONS[target.action] : null;
  const row = target?.row;
  const isReturn = target?.action === 'RETURN';

  const reset = () => {
    setError(null);
    setHasFine(false);
    setAmount('');
    setReason('');
  };
  const close = () => {
    reset();
    onClose();
  };

  const confirm = async () => {
    let body;
    if (isReturn && hasFine) {
      const n = Number(amount);
      if (!Number.isFinite(n) || n <= 0 || n > FINE_AMOUNT_MAX) {
        setError(`ยอดค่าปรับต้องมากกว่า 0 และไม่เกิน ${FINE_AMOUNT_MAX.toLocaleString('th-TH')} บาท`);
        return;
      }
      if (reason.trim().length < 3) {
        setError('กรุณาระบุเหตุผลของค่าปรับ (ชำรุด/สูญหาย) อย่างน้อย 3 ตัวอักษร');
        return;
      }
      body = { fine_amount: n, fine_reason: reason.trim() };
    }
    setBusy(true);
    setError(null);
    try {
      await changeBookingStatus(row.booking_id, cfg.path, body);
      const fineNote = body ? ` พร้อมบันทึกค่าปรับ ${formatBaht(body.fine_amount)}` : '';
      const message = `${cfg.done} ${row.booking_code} แล้ว${fineNote}`;
      reset();
      onDone(message);
    } catch (err) {
      setError(err.message);
      if (err.status === 404 || err.status === 409) onStale?.();
    } finally {
      setBusy(false);
    }
  };

  return (
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
      {row && (
        <div className="space-y-4 text-sm">
          <p className="text-slate-800">{cfg.question}</p>
          <dl className="grid grid-cols-[6rem_1fr] gap-x-3 gap-y-1">
            <dt className="text-slate-600">เลขที่</dt>
            <dd className="font-medium text-slate-900">{row.booking_code}</dd>
            <dt className="text-slate-600">ผู้ยืม</dt>
            <dd className="font-medium text-slate-900">{row.user_name}</dd>
            <dt className="text-slate-600">อุปกรณ์</dt>
            <dd className="font-medium text-slate-900">{row.equipment_name}</dd>
            <dt className="text-slate-600">วันที่ยืม</dt>
            <dd className="font-medium text-slate-900">{formatDay(row.borrow_date)}</dd>
            <dt className="text-slate-600">กำหนดคืน</dt>
            <dd className="font-medium text-slate-900">{formatDayTime(row.expected_return_date)}</dd>
            <dt className="text-slate-600">วัตถุประสงค์</dt>
            <dd className="text-slate-900">{row.borrow_purpose ?? '-'}</dd>
          </dl>

          {isReturn && row.overdue_days > 0 && (
            <p className="rounded-lg border border-amber-200 bg-amber-50 px-3 py-2 text-amber-900">
              คืนล่าช้า {row.overdue_days} วัน (ไม่คิดค่าปรับล่าช้า)
            </p>
          )}

          {isReturn && (
            <fieldset className="space-y-3 rounded-lg border border-slate-200 p-3">
              <legend className="px-1 text-xs font-semibold text-slate-600">ค่าปรับชำรุด/สูญหาย</legend>
              <label className="flex items-center gap-2 text-slate-800">
                <input
                  type="checkbox"
                  name="has_fine"
                  checked={hasFine}
                  onChange={(e) => setHasFine(e.target.checked)}
                  className={`h-4 w-4 rounded border-slate-300 text-amber-700 ${focusRing}`}
                />
                อุปกรณ์ชำรุดหรือสูญหาย (มีค่าปรับ)
              </label>
              {hasFine && (
                <div className="grid gap-3 sm:grid-cols-[10rem_1fr]">
                  <div>
                    <label htmlFor="fine-amount" className="mb-1 block text-xs font-semibold text-slate-600">
                      ยอดค่าปรับ (บาท)
                    </label>
                    <input
                      id="fine-amount"
                      name="fine_amount"
                      type="number"
                      inputMode="decimal"
                      min="1"
                      max={FINE_AMOUNT_MAX}
                      step="0.01"
                      value={amount}
                      onChange={(e) => setAmount(e.target.value)}
                      className={fieldClass}
                    />
                  </div>
                  <div>
                    <label htmlFor="fine-reason" className="mb-1 block text-xs font-semibold text-slate-600">
                      เหตุผล
                    </label>
                    <input
                      id="fine-reason"
                      name="fine_reason"
                      type="text"
                      maxLength={255}
                      value={reason}
                      onChange={(e) => setReason(e.target.value)}
                      placeholder="เช่น หน้าจอร้าว / สายชาร์จสูญหาย"
                      className={fieldClass}
                    />
                  </div>
                </div>
              )}
            </fieldset>
          )}

          {error && (
            <p role="alert" className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-red-900">
              {error}
            </p>
          )}
        </div>
      )}
    </Modal>
  );
}
