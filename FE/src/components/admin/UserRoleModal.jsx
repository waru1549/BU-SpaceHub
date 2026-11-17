import { useEffect, useState } from 'react';
import Modal from '../Modals/Modal.jsx';
import { RoleBadge } from './UserBadges.jsx';
import { changeUserRole } from '../../services/adminUsers.service.js';
import { ROLE_HINT, ROLE_LABEL } from '../../utils/adminUsers.js';

const focusRing = 'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600';
const btnSecondary = `rounded-lg border border-slate-300 px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-100 disabled:opacity-50 ${focusRing}`;
const btnPrimary = `rounded-lg bg-indigo-700 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-800 disabled:opacity-60 ${focusRing}`;

// target = แถวจาก v_admin_users | null
export default function UserRoleModal({ target, onClose, onDone, onStale }) {
  const [role, setRole] = useState('USER');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (target) {
      setRole(target.role);
      setError(null);
    }
  }, [target]);

  const close = () => {
    if (!busy) onClose();
  };

  const confirm = async () => {
    setBusy(true);
    setError(null);
    try {
      const updated = await changeUserRole(target.user_id, role);
      onDone(`เปลี่ยนบทบาทของ ${updated.full_name} เป็น ${ROLE_LABEL[updated.role] ?? updated.role} แล้ว`);
    } catch (err) {
      setError(err.message);
      if (err.status === 404 || err.status === 409) onStale?.();
    } finally {
      setBusy(false);
    }
  };

  const unchanged = target && role === target.role;
  const demoteAdmin = target?.role === 'ADMIN' && role !== 'ADMIN';

  return (
    <Modal
      open={target !== null}
      title="เปลี่ยนบทบาทผู้ใช้"
      onClose={close}
      busy={busy}
      footer={
        <>
          <button type="button" onClick={close} disabled={busy} className={btnSecondary} data-autofocus>
            ยกเลิก
          </button>
          <button type="button" onClick={confirm} disabled={busy || unchanged} className={btnPrimary}>
            {busy ? 'กำลังบันทึก…' : 'ยืนยันการเปลี่ยน'}
          </button>
        </>
      }
    >
      {target && (
        <div className="space-y-4 text-sm">
          <dl className="grid grid-cols-[6rem_1fr] gap-x-3 gap-y-1">
            <dt className="text-slate-600">ชื่อ</dt>
            <dd className="font-medium text-slate-900">{target.full_name}</dd>
            <dt className="text-slate-600">อีเมล</dt>
            <dd className="break-all text-slate-900">{target.email}</dd>
            <dt className="text-slate-600">บทบาทปัจจุบัน</dt>
            <dd><RoleBadge role={target.role} /></dd>
          </dl>

          <fieldset>
            <legend className="mb-2 text-xs font-semibold text-slate-700">บทบาทใหม่</legend>
            <div className="space-y-2">
              {['USER', 'STAFF', 'ADMIN'].map((r) => (
                <label
                  key={r}
                  className={`flex cursor-pointer items-start gap-3 rounded-lg border px-3 py-2 ${
                    role === r ? 'border-indigo-600 bg-indigo-50' : 'border-slate-300 bg-white'
                  }`}
                >
                  <input
                    type="radio"
                    name="role"
                    value={r}
                    checked={role === r}
                    onChange={() => setRole(r)}
                    className={`mt-1 h-4 w-4 text-indigo-700 ${focusRing}`}
                  />
                  <span>
                    <span className="block font-medium text-slate-900">{ROLE_LABEL[r]}</span>
                    <span className="block text-xs text-slate-600">{ROLE_HINT[r]}</span>
                  </span>
                </label>
              ))}
            </div>
          </fieldset>

          {role === 'ADMIN' && target.role !== 'ADMIN' && (
            <p className="rounded-lg border border-amber-300 bg-amber-50 px-3 py-2 text-amber-900">
              ผู้ดูแลระบบมีสิทธิ์เต็ม รวมถึงเปลี่ยนบทบาทของผู้อื่น โปรดตรวจสอบให้แน่ใจก่อนยืนยัน
            </p>
          )}
          {demoteAdmin && (
            <p className="rounded-lg border border-amber-300 bg-amber-50 px-3 py-2 text-amber-900">
              ผู้ใช้นี้จะสูญเสียสิทธิ์ผู้ดูแลระบบทันที (ระบบต้องเหลือผู้ดูแลที่ใช้งานอยู่อย่างน้อย 1 คน)
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
