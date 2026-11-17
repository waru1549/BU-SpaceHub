import { useState } from 'react';
import Modal from '../Modals/Modal.jsx';
import ResourceStatusBadge from './ResourceStatusBadge.jsx';
import { deleteResource } from '../../services/adminResources.service.js';
import { CATEGORY_LABEL } from '../../utils/adminResources.js';

const focusRing = 'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600';
const btnSecondary = `rounded-lg border border-slate-300 px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-100 disabled:opacity-50 ${focusRing}`;

// target = แถวจาก v_admin_resources | null
export default function DeleteResourceModal({ target, onClose, onDone, onStale }) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);

  const hasActive = (target?.active_count ?? 0) > 0;
  const hasHistory = (target?.history_count ?? 0) > 0;
  const alreadyOff = target?.resource_status === 'OUT_OF_SERVICE';

  const close = () => {
    if (busy) return;
    setError(null);
    onClose();
  };

  const confirm = async () => {
    setBusy(true);
    setError(null);
    try {
      const out = await deleteResource(target.resource_id);
      setError(null);
      onDone(out.message);
    } catch (err) {
      setError(err.message);
      if (err.status === 404 || err.status === 409) onStale?.();
    } finally {
      setBusy(false);
    }
  };

  const verb = hasHistory ? 'ปิดเป็นงดให้บริการ' : 'ลบถาวร';

  return (
    <Modal
      open={target !== null}
      title={hasHistory ? 'ปิดการให้บริการทรัพยากร' : 'ลบทรัพยากร'}
      onClose={close}
      busy={busy}
      footer={
        <>
          <button type="button" onClick={close} disabled={busy} className={btnSecondary} data-autofocus>
            ย้อนกลับ
          </button>
          {!hasActive && !(hasHistory && alreadyOff) && (
            <button
              type="button"
              onClick={confirm}
              disabled={busy}
              className={`rounded-lg px-4 py-2 text-sm font-medium text-white disabled:opacity-60 ${hasHistory ? 'bg-slate-700 hover:bg-slate-800' : 'bg-red-700 hover:bg-red-800'} ${focusRing}`}
            >
              {busy ? 'กำลังดำเนินการ…' : `ยืนยัน${verb}`}
            </button>
          )}
        </>
      }
    >
      {target && (
        <div className="space-y-4 text-sm">
          <dl className="grid grid-cols-[6rem_1fr] gap-x-3 gap-y-1">
            <dt className="text-slate-600">รหัส</dt>
            <dd className="font-medium text-slate-900">{target.resource_code}</dd>
            <dt className="text-slate-600">ชื่อ</dt>
            <dd className="text-slate-900">{target.resource_name}</dd>
            <dt className="text-slate-600">หมวดหมู่</dt>
            <dd className="text-slate-900">{CATEGORY_LABEL[target.category] ?? target.category}</dd>
            <dt className="text-slate-600">สถานะ</dt>
            <dd><ResourceStatusBadge status={target.resource_status} /></dd>
          </dl>

          {hasActive ? (
            <p className="rounded-lg border border-amber-300 bg-amber-50 px-3 py-2 text-amber-900">
              ยังมี {target.active_count} รายการที่รอดำเนินการหรือกำลังใช้งานอยู่ จึงลบหรือปิดทรัพยากรนี้ไม่ได้
              กรุณาให้รายการเหล่านั้นเสร็จสิ้นหรือยกเลิกก่อน
            </p>
          ) : hasHistory ? (
            <p className="rounded-lg border border-slate-300 bg-slate-50 px-3 py-2 text-slate-800">
              ทรัพยากรนี้มีประวัติการใช้งาน {target.history_count} รายการ จึง<strong>ลบถาวรไม่ได้</strong>
              {alreadyOff
                ? ' และปิดเป็น "งดให้บริการ" อยู่แล้ว'
                : ' ระบบจะปิดเป็น "งดให้บริการ" แทน (ประวัติและสถิติยังอยู่ครบ และเปิดกลับได้โดยแก้ไขสถานะ)'}
            </p>
          ) : (
            <p className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-red-900">
              ทรัพยากรนี้ไม่เคยมีการใช้งาน การลบจะ<strong>ลบถาวร</strong>
              {target.upcoming_slots > 0 ? ` พร้อมตารางเวลาที่เปิดไว้ ${target.upcoming_slots} ช่วง` : ''} และกู้คืนไม่ได้
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
