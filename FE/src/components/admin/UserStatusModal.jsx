import { useEffect, useState } from 'react';
import Modal from '../Modals/Modal.jsx';
import { UserStatusBadge } from './UserBadges.jsx';
import { changeUserStatus } from '../../services/adminUsers.service.js';

const focusRing = 'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600';
const btnSecondary = `rounded-lg border border-slate-300 px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-100 disabled:opacity-50 ${focusRing}`;

// target = { row, next: 'SUSPENDED' | 'ACTIVE' } | null
export default function UserStatusModal({ target, onClose, onDone, onStale }) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (target) setError(null);
  }, [target]);

  const row = target?.row;
  const suspending = target?.next === 'SUSPENDED';
  const hasActive = (row?.active_count ?? 0) > 0;

  const close = () => {
    if (!busy) onClose();
  };

  const confirm = async () => {
    setBusy(true);
    setError(null);
    try {
      const updated = await changeUserStatus(row.user_id, target.next);
      onDone(updated.user_status === 'ACTIVE' ? `เปิดใช้งานบัญชี ${updated.full_name} แล้ว` : `ระงับบัญชี ${updated.full_name} แล้ว`);
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
      title={suspending ? 'ระงับบัญชีผู้ใช้' : 'เปิดใช้งานบัญชีผู้ใช้'}
      onClose={close}
      busy={busy}
      footer={
        <>
          <button type="button" onClick={close} disabled={busy} className={btnSecondary} data-autofocus>
            ยกเลิก
          </button>
          {!(suspending && hasActive) && (
            <button
              type="button"
              onClick={confirm}
              disabled={busy}
              className={`rounded-lg px-4 py-2 text-sm font-medium text-white disabled:opacity-60 ${
                suspending ? 'bg-red-700 hover:bg-red-800' : 'bg-emerald-700 hover:bg-emerald-800'
              } ${focusRing}`}
            >
              {busy ? 'กำลังดำเนินการ…' : suspending ? 'ยืนยันระงับบัญชี' : 'ยืนยันเปิดใช้งาน'}
            </button>
          )}
        </>
      }
    >
      {row && (
        <div className="space-y-4 text-sm">
          <dl className="grid grid-cols-[6rem_1fr] gap-x-3 gap-y-1">
            <dt className="text-slate-600">ชื่อ</dt>
            <dd className="font-medium text-slate-900">{row.full_name}</dd>
            <dt className="text-slate-600">อีเมล</dt>
            <dd className="break-all text-slate-900">{row.email}</dd>
            <dt className="text-slate-600">สถานะ</dt>
            <dd><UserStatusBadge status={row.user_status} /></dd>
          </dl>

          {suspending && hasActive ? (
            <p className="rounded-lg border border-amber-300 bg-amber-50 px-3 py-2 text-amber-900">
              ผู้ใช้นี้ยังมี {row.active_count} รายการที่รอดำเนินการหรือกำลังใช้งานอยู่ จึงระงับบัญชีไม่ได้
              กรุณาให้รายการเหล่านั้นเสร็จสิ้นหรือยกเลิกก่อน
            </p>
          ) : suspending ? (
            <p className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-red-900">
              ผู้ใช้จะเข้าสู่ระบบและเรียกใช้งานไม่ได้ทันที ข้อมูลและประวัติทั้งหมดยังอยู่ครบ และเปิดใช้งานกลับได้ภายหลัง
            </p>
          ) : (
            <p className="rounded-lg border border-emerald-200 bg-emerald-50 px-3 py-2 text-emerald-900">
              ผู้ใช้จะกลับมาเข้าสู่ระบบและใช้งานได้ตามบทบาทเดิม
            </p>
          )}
          {error && (
            <p role="alert" className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-800">
              {error}
            </p>
          )}
        </div>
      )}
    </Modal>
  );
}
