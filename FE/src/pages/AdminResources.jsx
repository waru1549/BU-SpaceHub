import { useEffect, useRef, useState } from 'react';
import { Link } from 'react-router';
import { CalendarClock, Pencil, Plus, Search, Trash2 } from 'lucide-react';
import DataTable from '../components/Tables/DataTable.jsx';
import Notice from '../components/Feedback/Notice.jsx';
import ResourceStatusBadge from '../components/Admin/ResourceStatusBadge.jsx';
import ResourceFormModal from '../components/Admin/ResourceFormModal.jsx';
import DeleteResourceModal from '../components/Admin/DeleteResourceModal.jsx';
import { useAsync } from '../hooks/useAsync.js';
import { usePagedData } from '../hooks/usePagedData.js';
import { getOptions, listResources } from '../services/adminResources.service.js';
import { CATEGORY_LABEL, RESOURCE_STATUS_FILTER, hasSchedule } from '../utils/adminResources.js';

const focusRing = 'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600';
const fieldClass = `rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 ${focusRing}`;
const actionBtn = `inline-flex items-center gap-1 whitespace-nowrap rounded-lg border bg-white px-3 py-1 text-sm font-medium ${focusRing}`;

export default function AdminResources() {
  const options = useAsync(getOptions);
  const table = usePagedData(listResources, { sort: 'resource_code', order: 'asc', filters: {} });
  const [notice, setNotice] = useState(null);
  const [form, setForm] = useState(null);
  const [toDelete, setToDelete] = useState(null);
  const [search, setSearch] = useState('');
  const setFilterRef = useRef(table.setFilter);
  setFilterRef.current = table.setFilter;
  const currentQ = table.params.filters.q ?? '';

  // ค้นหาแบบหน่วงเวลา 400ms เพื่อไม่ยิง API ทุกตัวอักษร
  useEffect(() => {
    const value = search.trim();
    if (value === currentQ) return undefined;
    const t = setTimeout(() => setFilterRef.current('q', value), 400);
    return () => clearTimeout(t);
  }, [search, currentQ]);

  const columns = [
    { key: 'resource_code', label: 'รหัส', sortable: true },
    {
      key: 'resource_name',
      label: 'ชื่อ',
      sortable: true,
      render: (r) => (
        <>
          <span className="block font-medium text-slate-900">{r.resource_name}</span>
          {r.location && <span className="block text-xs text-slate-600">{r.location}</span>}
        </>
      ),
    },
    { key: 'category', label: 'หมวดหมู่', sortable: true, render: (r) => CATEGORY_LABEL[r.category] ?? r.category },
    {
      key: 'capacity',
      label: 'ความจุ/จำนวน',
      sortable: true,
      render: (r) => (r.capacity != null ? `${r.capacity} ที่นั่ง` : r.quantity != null ? `${r.quantity} ชิ้น` : '-'),
    },
    { key: 'resource_status', label: 'สถานะ', sortable: true, render: (r) => <ResourceStatusBadge status={r.resource_status} /> },
    {
      key: 'upcoming_slots',
      label: 'ช่วงเวลาที่เปิด',
      sortable: true,
      render: (r) => (hasSchedule(r.category) ? r.upcoming_slots : <span className="text-slate-600">-</span>),
    },
    {
      key: 'actions',
      label: 'การดำเนินการ',
      render: (r) => (
        <div className="flex flex-wrap gap-2">
          <button
            type="button"
            onClick={() => setForm({ mode: 'edit', row: r })}
            aria-label={`แก้ไข ${r.resource_code}`}
            className={`${actionBtn} border-slate-300 text-slate-700 hover:bg-slate-100`}
          >
            <Pencil className="h-3.5 w-3.5" aria-hidden="true" />
            แก้ไข
          </button>
          {hasSchedule(r.category) && (
            <Link
              to={`/admin/resources/${r.resource_id}/schedules`}
              aria-label={`จัดการตารางเวลา ${r.resource_code}`}
              className={`${actionBtn} border-indigo-300 text-indigo-800 hover:bg-indigo-50`}
            >
              <CalendarClock className="h-3.5 w-3.5" aria-hidden="true" />
              ตารางเวลา
            </Link>
          )}
          <button
            type="button"
            onClick={() => setToDelete(r)}
            aria-label={`ลบ ${r.resource_code}`}
            className={`${actionBtn} border-red-300 text-red-800 hover:bg-red-50`}
          >
            <Trash2 className="h-3.5 w-3.5" aria-hidden="true" />
            ลบ
          </button>
        </div>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <header className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold text-slate-800">จัดการทรัพยากร</h1>
          <p className="text-sm text-slate-600">เพิ่ม แก้ไข ลบ ทรัพยากร และตั้งตารางเวลาของห้อง/เครื่องพิมพ์ 3D</p>
        </div>
        <button
          type="button"
          onClick={() => setForm({ mode: 'create' })}
          disabled={options.loading || Boolean(options.error)}
          className={`inline-flex items-center gap-2 rounded-lg bg-indigo-700 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-800 disabled:opacity-60 ${focusRing}`}
        >
          <Plus className="h-4 w-4" aria-hidden="true" />
          เพิ่มทรัพยากร
        </button>
      </header>

      {options.error && (
        <p role="alert" className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800">
          โหลดตัวเลือกฟอร์มไม่สำเร็จ: {options.error}{' '}
          <button type="button" onClick={options.reload} className="font-medium underline">ลองอีกครั้ง</button>
        </p>
      )}
      {notice && (
        <Notice type="success" onDismiss={() => setNotice(null)}>
          {notice.text}
          {notice.scheduleLink && (
            <>
              {' '}
              <Link to={notice.scheduleLink} className="font-semibold underline">ไปตั้งตารางเวลา</Link>
            </>
          )}
        </Notice>
      )}

      <section aria-labelledby="res-list-title" className="space-y-3">
        <h2 id="res-list-title" className="sr-only">รายการทรัพยากร</h2>
        <div className="flex flex-wrap items-end gap-3">
          <div className="min-w-56 flex-1">
            <label htmlFor="res-search" className="mb-1 block text-xs font-semibold text-slate-700">ค้นหา</label>
            <div className="relative">
              <Search className="pointer-events-none absolute top-1/2 left-3 h-4 w-4 -translate-y-1/2 text-slate-500" aria-hidden="true" />
              <input
                id="res-search"
                type="search"
                name="q"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="ชื่อ รหัส หรือสถานที่"
                autoComplete="off"
                className={`${fieldClass} w-full pl-9`}
              />
            </div>
          </div>
          <label className="text-sm text-slate-700">
            <span className="mb-1 block text-xs font-semibold">หมวดหมู่</span>
            <select
              name="category"
              value={table.params.filters.category ?? ''}
              onChange={(e) => table.setFilter('category', e.target.value)}
              className={fieldClass}
            >
              <option value="">ทุกหมวดหมู่</option>
              {Object.entries(CATEGORY_LABEL).map(([value, label]) => (
                <option key={value} value={value}>{label}</option>
              ))}
            </select>
          </label>
          <label className="text-sm text-slate-700">
            <span className="mb-1 block text-xs font-semibold">สถานะ</span>
            <select
              name="resource_status"
              value={table.params.filters.resource_status ?? ''}
              onChange={(e) => table.setFilter('resource_status', e.target.value)}
              className={fieldClass}
            >
              {RESOURCE_STATUS_FILTER.map(([value, label]) => (
                <option key={value} value={value}>{label}</option>
              ))}
            </select>
          </label>
        </div>
        <p className="text-sm text-slate-600" aria-live="polite">{table.meta ? `พบ ${table.meta.total} รายการ` : 'กำลังโหลด…'}</p>

        <DataTable
          caption="ตารางทรัพยากร"
          columns={columns}
          rows={table.rows}
          rowKey="resource_id"
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
          emptyText="ไม่พบทรัพยากรตามเงื่อนไขที่เลือก"
        />
      </section>

      <ResourceFormModal
        target={form}
        options={options.data}
        onClose={() => setForm(null)}
        onSaved={(text, saved) => {
          const created = form?.mode === 'create';
          setForm(null);
          setNotice({
            text,
            scheduleLink: created && hasSchedule(saved.category) ? `/admin/resources/${saved.resource_id}/schedules` : null,
          });
          table.reload();
        }}
      />
      <DeleteResourceModal
        target={toDelete}
        onClose={() => setToDelete(null)}
        onDone={(text) => {
          setToDelete(null);
          setNotice({ text });
          table.reload();
        }}
        onStale={table.reload}
      />
    </div>
  );
}
