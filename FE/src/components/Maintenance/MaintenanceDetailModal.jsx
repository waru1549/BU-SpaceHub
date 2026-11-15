import { useCallback, useState } from 'react';
import { Trash2 } from 'lucide-react';
import Modal from '../Modals/Modal.jsx';
import StatusBadge from '../Badge/StatusBadge.jsx';
import ImagePicker from './ImagePicker.jsx';
import { useAsync } from '../../hooks/useAsync.js';
import { deleteAttachment, getRequest, uploadImages } from '../../services/maintenance.service.js';
import { MAX_IMAGES } from '../../utils/maintenance.js';
import { formatDayTime } from '../../utils/equipment.js';

const focusRing =
  'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-sky-600';
const btnSecondary = `rounded-lg border border-slate-300 px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-100 disabled:opacity-50 ${focusRing}`;
const btnPrimary = `rounded-lg bg-sky-700 px-4 py-2 text-sm font-medium text-white hover:bg-sky-800 disabled:opacity-60 ${focusRing}`;

// รายละเอียดงานแจ้งซ่อม + รูปแนบ | requestId = null จะปิดหน้าต่าง
// เจ้าของงานเพิ่ม/ลบรูปได้ก่อนเริ่มซ่อม (BE ส่ง actions มี CANCEL เฉพาะกรณีนี้)
export default function MaintenanceDetailModal({ requestId, onClose, onChanged }) {
  const fetchDetail = useCallback(
    () => (requestId ? getRequest(requestId) : Promise.resolve(null)),
    [requestId],
  );
  const detail = useAsync(fetchDetail);
  const row = detail.data;

  const [files, setFiles] = useState([]);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);

  const canEditImages = Boolean(row?.actions?.includes('CANCEL'));
  const remaining = MAX_IMAGES - (row?.attachments?.length ?? 0);

  const close = () => {
    setFiles([]);
    setError(null);
    onClose();
  };

  const upload = async () => {
    setBusy(true);
    setError(null);
    try {
      await uploadImages(row.booking_id, files);
      setFiles([]);
      detail.reload();
      onChanged?.();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  const remove = async (attachmentId) => {
    setBusy(true);
    setError(null);
    try {
      await deleteAttachment(row.booking_id, attachmentId);
      detail.reload();
      onChanged?.();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <Modal
      open={requestId !== null && requestId !== undefined}
      title="รายละเอียดงานแจ้งซ่อม"
      onClose={close}
      busy={busy}
      footer={
        <>
          {canEditImages && files.length > 0 && (
            <button type="button" onClick={upload} disabled={busy} className={btnPrimary}>
              {busy ? 'กำลังอัปโหลด…' : `อัปโหลด ${files.length} รูป`}
            </button>
          )}
          <button type="button" onClick={close} disabled={busy} className={btnSecondary} data-autofocus>
            ปิด
          </button>
        </>
      }
    >
      {detail.loading && !row && <p className="text-sm text-slate-600">กำลังโหลด…</p>}
      {detail.error && (
        <p role="alert" className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-900">
          {detail.error}
        </p>
      )}
      {row && (
        <div className="space-y-4 text-sm">
          <div className="flex flex-wrap items-center gap-2">
            <span className="font-semibold text-slate-900">{row.booking_code}</span>
            <StatusBadge status={row.booking_status} variant="maintenance" />
          </div>

          <dl className="grid grid-cols-[7rem_1fr] gap-x-3 gap-y-1">
            <dt className="text-slate-600">เรื่อง</dt>
            <dd className="font-medium text-slate-900">{row.repair_title}</dd>
            <dt className="text-slate-600">ทรัพยากร</dt>
            <dd className="text-slate-900">
              {row.resource_name ? `${row.resource_name} (${row.resource_code})` : 'ไม่ผูกทรัพยากร'}
            </dd>
            <dt className="text-slate-600">สถานที่</dt>
            <dd className="text-slate-900">{row.location ?? '-'}</dd>
            <dt className="text-slate-600">ผู้แจ้ง</dt>
            <dd className="text-slate-900">{row.reporter_name}</dd>
            <dt className="text-slate-600">แจ้งเมื่อ</dt>
            <dd className="text-slate-900">{formatDayTime(row.reported_date)}</dd>
            <dt className="text-slate-600">ผู้รับผิดชอบ</dt>
            <dd className="text-slate-900">{row.assignee_name ?? 'ยังไม่มอบหมาย'}</dd>
            {row.started_at && (
              <>
                <dt className="text-slate-600">เริ่มซ่อม</dt>
                <dd className="text-slate-900">{formatDayTime(row.started_at)}</dd>
              </>
            )}
            {row.completed_at && (
              <>
                <dt className="text-slate-600">ปิดงาน</dt>
                <dd className="text-slate-900">{formatDayTime(row.completed_at)}</dd>
              </>
            )}
          </dl>

          <div>
            <h3 className="mb-1 font-semibold text-slate-800">อาการ/รายละเอียด</h3>
            <p className="whitespace-pre-wrap rounded-lg bg-slate-50 px-3 py-2 text-slate-900">
              {row.repair_description ?? '-'}
            </p>
          </div>

          {row.staff_note && (
            <div>
              <h3 className="mb-1 font-semibold text-slate-800">
                {row.booking_status === 'REJECTED' ? 'เหตุผลที่ไม่รับเรื่อง' : 'บันทึกผลการซ่อม'}
              </h3>
              <p className="whitespace-pre-wrap rounded-lg border border-sky-200 bg-sky-50 px-3 py-2 text-sky-900">
                {row.staff_note}
              </p>
            </div>
          )}

          <div>
            <h3 className="mb-1 font-semibold text-slate-800">
              รูปแนบ ({row.attachments.length}/{MAX_IMAGES})
            </h3>
            {row.attachments.length === 0 ? (
              <p className="text-slate-600">ไม่มีรูปแนบ</p>
            ) : (
              <ul className="grid grid-cols-3 gap-2">
                {row.attachments.map((a) => (
                  <li key={a.attachment_id} className="relative overflow-hidden rounded-lg border border-slate-200">
                    {a.url ? (
                      <a href={a.url} target="_blank" rel="noreferrer" aria-label={`เปิดรูป ${a.file_name} ในแท็บใหม่`}>
                        <img src={a.url} alt={a.file_name ?? 'รูปแนบ'} className="h-24 w-full object-cover" />
                      </a>
                    ) : (
                      <p className="flex h-24 items-center justify-center text-xs text-slate-600">โหลดรูปไม่สำเร็จ</p>
                    )}
                    {canEditImages && (
                      <button
                        type="button"
                        onClick={() => remove(a.attachment_id)}
                        disabled={busy}
                        aria-label={`ลบรูป ${a.file_name}`}
                        className={`absolute right-1 top-1 rounded-full bg-white/90 p-1 text-red-800 shadow hover:bg-white ${focusRing}`}
                      >
                        <Trash2 className="h-3.5 w-3.5" aria-hidden="true" />
                      </button>
                    )}
                  </li>
                ))}
              </ul>
            )}
          </div>

          {canEditImages && remaining > 0 && (
            <div>
              <h3 className="mb-1 font-semibold text-slate-800">เพิ่มรูป (แนบได้อีก {remaining} รูป)</h3>
              <ImagePicker files={files} onChange={setFiles} max={remaining} disabled={busy} id="detail-images" />
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
