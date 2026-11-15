import { useMemo, useState } from 'react';
import { Info } from 'lucide-react';
import DataTable from '../components/Tables/DataTable.jsx';
import StatusBadge from '../components/Badge/StatusBadge.jsx';
import Notice from '../components/Feedback/Notice.jsx';
import ImagePicker from '../components/Maintenance/ImagePicker.jsx';
import MaintenanceDetailModal from '../components/Maintenance/MaintenanceDetailModal.jsx';
import MaintenanceActionModal from '../components/Requests/MaintenanceActionModal.jsx';
import { useAsync } from '../hooks/useAsync.js';
import { usePagedData } from '../hooks/usePagedData.js';
import { createRequest, getMyRequests, getResources, uploadImages } from '../services/maintenance.service.js';
import { MAINTENANCE_STATUS_OPTIONS } from '../utils/booking.js';
import {
  DESCRIPTION_MAX,
  DESCRIPTION_MIN,
  MAINTENANCE_ACTIONS,
  MAX_IMAGES,
  TITLE_MAX,
} from '../utils/maintenance.js';
import { formatDayTime } from '../utils/equipment.js';

const focusRing =
  'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-sky-600';
const fieldClass = `w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-800 ${focusRing}`;
const selectClass = `rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-800 ${focusRing}`;
const btnPrimary = `rounded-lg bg-sky-700 px-4 py-2 text-sm font-medium text-white hover:bg-sky-800 disabled:opacity-60 ${focusRing}`;

const CATEGORY_LABEL = { ROOM: 'ห้อง', PRINTER: 'เครื่องพิมพ์ 3D', EQUIPMENT: 'อุปกรณ์' };

export default function Maintenance() {
  const resources = useAsync(getResources);
  const requests = usePagedData(getMyRequests, { sort: 'reported_date', order: 'desc' });

  const [mode, setMode] = useState('resource'); // 'resource' | 'location'
  const [resourceId, setResourceId] = useState('');
  const [location, setLocation] = useState('');
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [files, setFiles] = useState([]);
  const [submitting, setSubmitting] = useState(false);
  const [formError, setFormError] = useState(null);
  const [notice, setNotice] = useState(null);
  const [uploadWarning, setUploadWarning] = useState(null);
  const [detailId, setDetailId] = useState(null);
  const [actionTarget, setActionTarget] = useState(null);

  const grouped = useMemo(() => {
    const groups = new Map();
    for (const r of resources.data ?? []) {
      const key = r.category ?? 'OTHER';
      if (!groups.has(key)) groups.set(key, []);
      groups.get(key).push(r);
    }
    return [...groups.entries()];
  }, [resources.data]);

  const resetForm = () => {
    setResourceId('');
    setLocation('');
    setTitle('');
    setDescription('');
    setFiles([]);
    setFormError(null);
  };

  const submit = async (e) => {
    e.preventDefault();
    if (mode === 'resource' && !resourceId) {
      setFormError('กรุณาเลือกทรัพยากรที่ต้องการแจ้งซ่อม หรือเปลี่ยนเป็น "สถานที่อื่น"');
      return;
    }
    if (mode === 'location' && location.trim().length < 2) {
      setFormError('กรุณาระบุสถานที่ที่ต้องการแจ้งซ่อม');
      return;
    }
    if (title.trim().length < 3) {
      setFormError('กรุณาระบุหัวข้ออย่างน้อย 3 ตัวอักษร');
      return;
    }
    if (description.trim().length < DESCRIPTION_MIN) {
      setFormError(`กรุณาอธิบายอาการอย่างน้อย ${DESCRIPTION_MIN} ตัวอักษร`);
      return;
    }

    setSubmitting(true);
    setFormError(null);
    setUploadWarning(null);
    let created = null;
    try {
      created = await createRequest({
        resourceId: mode === 'resource' ? Number(resourceId) : null,
        location: mode === 'location' ? location.trim() : null,
        title: title.trim(),
        description: description.trim(),
      });
    } catch (err) {
      setFormError(err.message);
      setSubmitting(false);
      return;
    }

    // เรื่องถูกสร้างแล้ว: ถ้าอัปโหลดรูปไม่สำเร็จ ผู้ใช้เพิ่มรูปภายหลังได้จากหน้ารายละเอียด
    if (files.length > 0) {
      try {
        await uploadImages(created.booking_id, files);
      } catch (err) {
        setUploadWarning(
          `ส่งเรื่อง ${created.booking_code} แล้ว แต่แนบรูปไม่สำเร็จ (${err.message}) เปิด "รายละเอียด" ของเรื่องนี้เพื่อเพิ่มรูปอีกครั้ง`,
        );
      }
    }
    setNotice({ type: 'success', text: `ส่งเรื่องแจ้งซ่อมสำเร็จ เลขที่ ${created.booking_code} สถานะรอรับเรื่อง` });
    resetForm();
    requests.reload();
    resources.reload();
    setSubmitting(false);
  };

  const columns = [
    { key: 'booking_code', label: 'เลขที่งาน', sortable: true },
    {
      key: 'repair_title',
      label: 'เรื่อง',
      sortable: true,
      render: (r) => (
        <>
          <span className="block font-medium text-slate-900">{r.repair_title}</span>
          <span className="block text-xs text-slate-600">{r.resource_name ?? r.location ?? '-'}</span>
        </>
      ),
    },
    {
      key: 'booking_status',
      label: 'สถานะ',
      sortable: true,
      render: (r) => <StatusBadge status={r.booking_status} variant="maintenance" />,
    },
    {
      key: 'assignee_name',
      label: 'ผู้รับผิดชอบ',
      render: (r) => r.assignee_name ?? <span className="text-slate-600">ยังไม่มอบหมาย</span>,
    },
    {
      key: 'reported_date',
      label: 'แจ้งเมื่อ',
      sortable: true,
      render: (r) => <span className="whitespace-nowrap">{formatDayTime(r.reported_date)}</span>,
    },
    {
      key: 'actions',
      label: 'การดำเนินการ',
      render: (r) => (
        <div className="flex flex-wrap gap-2">
          <button
            type="button"
            onClick={() => setDetailId(r.booking_id)}
            aria-label={`ดูรายละเอียด ${r.booking_code}`}
            className={`whitespace-nowrap rounded-lg border border-slate-300 bg-white px-3 py-1 text-sm font-medium text-slate-700 hover:bg-slate-100 ${focusRing}`}
          >
            รายละเอียด
          </button>
          {r.actions.includes('CANCEL') && (
            <button
              type="button"
              onClick={() => setActionTarget({ row: r, action: 'CANCEL' })}
              aria-label={`ยกเลิกงานแจ้งซ่อม ${r.booking_code}`}
              className={`rounded-lg border bg-white px-3 py-1 text-sm font-medium ${MAINTENANCE_ACTIONS.CANCEL.trigger} ${focusRing}`}
            >
              ยกเลิก
            </button>
          )}
        </div>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-2xl font-bold text-slate-800">แจ้งซ่อม</h1>
        <p className="text-sm text-slate-600">แจ้งปัญหาห้อง เครื่องพิมพ์ อุปกรณ์ หรือสถานที่ พร้อมแนบรูป แล้วติดตามความคืบหน้าได้ที่นี่</p>
      </header>

      <div className="flex gap-3 rounded-xl border border-sky-200 bg-sky-50 px-4 py-3 text-sm text-sky-900">
        <Info className="mt-0.5 h-4 w-4 shrink-0" aria-hidden="true" />
        <p>
          เรื่องที่ส่งแล้วจะอยู่ในสถานะ "รอรับเรื่อง" จนกว่าเจ้าหน้าที่จะมอบหมายและเริ่มซ่อม ยกเลิกได้ก่อนเริ่มซ่อมเท่านั้น
          แนบรูปได้สูงสุด {MAX_IMAGES} รูป และมีงานที่ยังไม่ปิดได้ไม่เกิน 5 เรื่อง
        </p>
      </div>

      {notice && (
        <Notice type={notice.type} onDismiss={() => setNotice(null)}>
          {notice.text}
        </Notice>
      )}
      {uploadWarning && (
        <p role="alert" className="rounded-xl border border-amber-300 bg-amber-50 px-4 py-3 text-sm text-amber-900">
          {uploadWarning}
        </p>
      )}

      <section aria-labelledby="report-title" className="rounded-2xl border border-slate-200 bg-white p-4 sm:p-6">
        <h2 id="report-title" className="mb-4 text-lg font-semibold text-slate-800">
          แจ้งซ่อมใหม่
        </h2>
        <form onSubmit={submit} noValidate className="space-y-4">
          <fieldset className="space-y-3">
            <legend className="mb-1 text-sm font-medium text-slate-800">สิ่งที่ต้องการแจ้งซ่อม</legend>
            <div className="flex flex-wrap gap-x-6 gap-y-2 text-sm text-slate-800">
              <label className="flex items-center gap-2">
                <input
                  type="radio"
                  name="mode"
                  value="resource"
                  checked={mode === 'resource'}
                  onChange={() => setMode('resource')}
                  className={`h-4 w-4 text-sky-700 ${focusRing}`}
                />
                ทรัพยากรในระบบ (ห้อง/เครื่องพิมพ์/อุปกรณ์)
              </label>
              <label className="flex items-center gap-2">
                <input
                  type="radio"
                  name="mode"
                  value="location"
                  checked={mode === 'location'}
                  onChange={() => setMode('location')}
                  className={`h-4 w-4 text-sky-700 ${focusRing}`}
                />
                สถานที่อื่น (พิมพ์เอง)
              </label>
            </div>

            {mode === 'resource' ? (
              <div>
                <label htmlFor="mt-resource" className="mb-1 block text-xs font-semibold text-slate-600">
                  ทรัพยากร
                </label>
                <select
                  id="mt-resource"
                  name="resource_id"
                  value={resourceId}
                  onChange={(e) => setResourceId(e.target.value)}
                  disabled={resources.loading || submitting}
                  className={`${selectClass} w-full sm:max-w-md`}
                >
                  <option value="">{resources.loading ? 'กำลังโหลดรายการ…' : '— เลือกทรัพยากร —'}</option>
                  {grouped.map(([category, items]) => (
                    <optgroup key={category} label={CATEGORY_LABEL[category] ?? category}>
                      {items.map((r) => (
                        <option key={r.resource_id} value={r.resource_id}>
                          {r.resource_code} · {r.resource_name}
                        </option>
                      ))}
                    </optgroup>
                  ))}
                </select>
                {resources.error && <p className="mt-1 text-xs text-red-800">{resources.error}</p>}
              </div>
            ) : (
              <div>
                <label htmlFor="mt-location" className="mb-1 block text-xs font-semibold text-slate-600">
                  สถานที่
                </label>
                <input
                  id="mt-location"
                  name="location"
                  type="text"
                  maxLength={255}
                  value={location}
                  onChange={(e) => setLocation(e.target.value)}
                  disabled={submitting}
                  placeholder="เช่น ลานจอดรถ ตึก 3 / ห้องน้ำ ชั้น 2"
                  className={`${fieldClass} sm:max-w-md`}
                />
              </div>
            )}
          </fieldset>

          <div>
            <label htmlFor="mt-title" className="mb-1 block text-xs font-semibold text-slate-600">
              หัวข้อ
            </label>
            <input
              id="mt-title"
              name="title"
              type="text"
              maxLength={TITLE_MAX}
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              disabled={submitting}
              placeholder="เช่น ไฟห้องกะพริบ"
              className={fieldClass}
            />
          </div>

          <div>
            <label htmlFor="mt-description" className="mb-1 block text-xs font-semibold text-slate-600">
              อาการ/รายละเอียด
            </label>
            <textarea
              id="mt-description"
              name="description"
              rows={4}
              maxLength={DESCRIPTION_MAX}
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              disabled={submitting}
              placeholder="อธิบายอาการ เกิดขึ้นเมื่อไร และผลกระทบ"
              className={fieldClass}
            />
            <p className="mt-1 text-right text-xs text-slate-600">
              {description.length}/{DESCRIPTION_MAX}
            </p>
          </div>

          <div>
            <p className="mb-1 text-xs font-semibold text-slate-600">รูปประกอบ (ไม่บังคับ)</p>
            <ImagePicker files={files} onChange={setFiles} max={MAX_IMAGES} disabled={submitting} id="mt-images" />
          </div>

          {formError && (
            <p role="alert" className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-900">
              {formError}
            </p>
          )}

          <div className="flex justify-end">
            <button type="submit" disabled={submitting} className={btnPrimary}>
              {submitting ? (files.length > 0 ? 'กำลังส่งเรื่องและอัปโหลดรูป…' : 'กำลังส่งเรื่อง…') : 'ส่งเรื่องแจ้งซ่อม'}
            </button>
          </div>
        </form>
      </section>

      <section aria-labelledby="my-requests-title" className="space-y-3">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <h2 id="my-requests-title" className="text-lg font-semibold text-slate-800">
            งานแจ้งซ่อมของฉัน
          </h2>
          <label className="flex items-center gap-2 text-sm text-slate-700">
            <span>สถานะ</span>
            <select
              name="booking_status"
              value={requests.params.filters.booking_status ?? ''}
              onChange={(e) => requests.setFilter('booking_status', e.target.value)}
              className={selectClass}
            >
              {MAINTENANCE_STATUS_OPTIONS.map(([value, label]) => (
                <option key={value} value={value}>
                  {label}
                </option>
              ))}
            </select>
          </label>
        </div>
        <DataTable
          caption="ตารางงานแจ้งซ่อมของฉัน"
          columns={columns}
          rows={requests.rows}
          rowKey="booking_id"
          loading={requests.loading}
          error={requests.error}
          onRetry={requests.reload}
          page={requests.params.page}
          limit={requests.params.limit}
          total={requests.meta?.total ?? 0}
          totalPages={requests.meta?.totalPages ?? 1}
          sort={requests.params.sort}
          order={requests.params.order}
          onPageChange={requests.setPage}
          onLimitChange={requests.setLimit}
          onSortChange={requests.setSort}
          emptyText="คุณยังไม่มีงานแจ้งซ่อม"
        />
      </section>

      <MaintenanceDetailModal requestId={detailId} onClose={() => setDetailId(null)} onChanged={requests.reload} />
      <MaintenanceActionModal
        target={actionTarget}
        onClose={() => setActionTarget(null)}
        onDone={(message) => {
          setActionTarget(null);
          setNotice({ type: 'success', text: message });
          requests.reload();
        }}
        onStale={requests.reload}
      />
    </div>
  );
}
