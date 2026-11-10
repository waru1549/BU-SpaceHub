import { useState } from 'react';
import Modal from '../Modals/Modal.jsx';
import { changeBookingStatus } from '../../services/printers.service.js';
import { MATERIAL_LABEL, PRINTER_ACTIONS, formatWeight } from '../../utils/printerActions.js';
import { formatDate, formatTimeRange } from '../../utils/format.js';

const focusRing =
  'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-600';
const btnSecondary = `rounded-lg border border-slate-300 px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-100 disabled:opacity-50 ${focusRing}`;

// กล่องยืนยันการดำเนินการกับการจองเครื่องพิมพ์ (ใช้ร่วมกันในหน้าผู้ใช้และคิวเจ้าหน้าที่)
// target = { row, action } | null; onDone(ข้อความสำเร็จ); onStale() เมื่อสถานะเปลี่ยนไปแล้ว
export default function PrinterActionModal({ target, onClose, onDone, onStale }) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const cfg = target ? PRINTER_ACTIONS[target.action] : null;

  const close = () => {
    setError(null);
    onClose();
  };

  const confirm = async () => {
    setBusy(true);
    setError(null);
    try {
      await changeBookingStatus(target.row.booking_id, cfg.path);
      const message = `${cfg.done} ${target.row.booking_code} แล้ว`;
      setError(null);
      onDone(message);
    } catch (err) {
      setError(err.message);
      if (err.status === 404 || err.status === 409) onStale?.();
    } finally {
      setBusy(false);
    }
  };

  const row = target?.row;

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
            <dt className="text-slate-600">ผู้จอง</dt>
            <dd className="font-medium text-slate-900">{row.user_name}</dd>
            <dt className="text-slate-600">เครื่อง</dt>
            <dd className="font-medium text-slate-900">{row.printer_name}</dd>
            <dt className="text-slate-600">วันที่</dt>
            <dd className="font-medium text-slate-900">{formatDate(row.work_date)}</dd>
            <dt className="text-slate-600">เวลา</dt>
            <dd className="font-medium text-slate-900">{formatTimeRange(row.start_time, row.end_time)}</dd>
            <dt className="text-slate-600">วัสดุ</dt>
            <dd className="font-medium text-slate-900">{MATERIAL_LABEL[row.material] ?? row.material ?? '-'}</dd>
            <dt className="text-slate-600">น้ำหนัก</dt>
            <dd className="font-medium text-slate-900">{formatWeight(row.est_weight_g)}</dd>
            <dt className="text-slate-600">วัตถุประสงค์</dt>
            <dd className="text-slate-900">{row.print_purpose ?? '-'}</dd>
          </dl>
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
