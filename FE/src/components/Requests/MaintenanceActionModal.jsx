import { useCallback, useEffect, useState } from 'react';
import Modal from '../Modals/Modal.jsx';
import StatusBadge from '../Badge/StatusBadge.jsx';
import { useAsync } from '../../hooks/useAsync.js';
import { assignRequest, changeRequestStatus, getAssignableStaff } from '../../services/maintenance.service.js';
import { MAINTENANCE_ACTIONS, ROLE_LABEL } from '../../utils/maintenance.js';

const focusRing =
  'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-sky-600';
const fieldClass = `w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-800 ${focusRing}`;
const btnSecondary = `rounded-lg border border-slate-300 px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-100 disabled:opacity-50 ${focusRing}`;

// กล่องยืนยันการดำเนินการกับงานแจ้งซ่อม (ใช้ร่วมกันในหน้าผู้ใช้และคิวเจ้าหน้าที่)
// target = { row, action } | null ; onDone(ข้อความ) ; onStale() เมื่อสถานะเปลี่ยนไปแล้ว
export default function MaintenanceActionModal({ target, onClose, onDone, onStale }) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const [note, setNote] = useState('');
  const [assignee, setAssignee] = useState('');

  const cfg = target ? MAINTENANCE_ACTIONS[target.action] : null;
  const row = target?.row;
  const isAssign = target?.action === 'ASSIGN';

  const fetchStaff = useCallback(
    () => (isAssign ? getAssignableStaff() : Promise.resolve([])),
    [isAssign],
  );
  const staff = useAsync(fetchStaff);

  useEffect(() => {
    if (target) setAssignee(target.row.assigned_to ? String(target.row.assigned_to) : '');
  }, [target]);

  const reset = () => {
    setError(null);
    setNote('');
    setAssignee('');
  };
  const close = () => {
    reset();
    onClose();
  };

  const confirm = async () => {
    if (cfg.note === 'required' && note.trim().length < 3) {
      setError(`กรุณาระบุ${cfg.noteLabel} อย่างน้อย 3 ตัวอักษร`);
      return;
    }
    if (isAssign && !assignee) {
      setError('กรุณาเลือกผู้รับผิดชอบ');
      return;
    }
    setBusy(true);
    setError(null);
    try {
      if (isAssign) await assignRequest(row.booking_id, Number(assignee));
      else await changeRequestStatus(row.booking_id, cfg.path, note.trim());
      const message = `${cfg.done} ${row.booking_code} แล้ว`;
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
            <dt className="text-slate-600">เรื่อง</dt>
            <dd className="font-medium text-slate-900">{row.repair_title}</dd>
            <dt className="text-slate-600">สถานที่/ทรัพยากร</dt>
            <dd className="text-slate-900">{row.resource_name ?? row.location ?? '-'}</dd>
            <dt className="text-slate-600">ผู้แจ้ง</dt>
            <dd className="text-slate-900">{row.reporter_name}</dd>
            <dt className="text-slate-600">สถานะ</dt>
            <dd>
              <StatusBadge status={row.booking_status} variant="maintenance" />
            </dd>
          </dl>

          {isAssign && (
            <div>
              <label htmlFor="mt-assignee" className="mb-1 block text-xs font-semibold text-slate-600">
                ผู้รับผิดชอบ
              </label>
              <select
                id="mt-assignee"
                name="assignee_id"
                value={assignee}
                onChange={(e) => setAssignee(e.target.value)}
                disabled={staff.loading}
                className={fieldClass}
              >
                <option value="">{staff.loading ? 'กำลังโหลดรายชื่อ…' : '— เลือกผู้รับผิดชอบ —'}</option>
                {(staff.data ?? []).map((s) => (
                  <option key={s.user_id} value={s.user_id}>
                    {s.full_name} ({ROLE_LABEL[s.role] ?? s.role})
                  </option>
                ))}
              </select>
              {staff.error && <p className="mt-1 text-xs text-red-800">{staff.error}</p>}
            </div>
          )}

          {cfg.note === 'required' && (
            <div>
              <label htmlFor="mt-note" className="mb-1 block text-xs font-semibold text-slate-600">
                {cfg.noteLabel}
              </label>
              <textarea
                id="mt-note"
                name="note"
                rows={3}
                maxLength={1000}
                value={note}
                onChange={(e) => setNote(e.target.value)}
                placeholder={cfg.notePlaceholder}
                className={fieldClass}
              />
            </div>
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
