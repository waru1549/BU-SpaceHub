import { useEffect, useRef, useState } from 'react';
import DataTable from '../Tables/DataTable.jsx';
import ErrorBanner from './ErrorBanner.jsx';
import { usePagedData } from '../../hooks/usePagedData.js';
import { deleteSchedule, listSchedules, setScheduleBlock } from '../../services/adminResources.service.js';
import { SCHEDULE_STATUS_LABEL, formatDay, timeText } from '../../utils/adminResources.js';

const focusRing = 'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600';
const fieldClass = `rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 ${focusRing}`;
const btn = `whitespace-nowrap rounded-lg border bg-white px-3 py-1 text-sm font-medium disabled:opacity-50 ${focusRing}`;

// ใช้ key={resourceId} ที่ตัวเรียก | version เพิ่มขึ้น = โหลดตารางใหม่ | onNotice(ข้อความสำเร็จ)
export default function ScheduleList({ resourceId, kind, version, onNotice }) {
  const table = usePagedData((p) => listSchedules(resourceId, p), { sort: 'work_date', order: 'asc', filters: {} });
  const [busyId, setBusyId] = useState(null);
  const [error, setError] = useState(null);
  const reloadRef = useRef(table.reload);
  reloadRef.current = table.reload;

  useEffect(() => {
    if (version > 0) reloadRef.current();
  }, [version]);

  const act = async (row, fn, message) => {
    setBusyId(row.schedule_id);
    setError(null);
    try {
      await fn();
      onNotice(message);
      table.reload();
    } catch (err) {
      setError(err.message);
      if (err.status === 404 || err.status === 409) table.reload();
    } finally {
      setBusyId(null);
    }
  };

  const columns = [
    { key: 'work_date', label: 'วันที่', render: (r) => <span className="whitespace-nowrap">{formatDay(r.work_date)}</span> },
    { key: 'time', label: 'เวลา', render: (r) => <span className="whitespace-nowrap">{timeText(r.start_time)}–{timeText(r.end_time)}</span> },
    { key: 'booked', label: 'จองแล้ว / รับได้', render: (r) => `${r.booked_slots} / ${r.max_slots}` },
    {
      key: 'schedule_status',
      label: 'สถานะ',
      render: (r) => (
        <span
          className={`inline-block whitespace-nowrap rounded-full px-2.5 py-1 text-xs font-semibold ${
            r.schedule_status === 'BLOCKED' ? 'bg-slate-200 text-slate-800' : r.remaining_slots === 0 ? 'bg-amber-100 text-amber-900' : 'bg-emerald-100 text-emerald-900'
          }`}
        >
          {r.schedule_status === 'AVAILABLE' && r.remaining_slots === 0 ? 'เต็ม' : SCHEDULE_STATUS_LABEL[r.schedule_status] ?? r.schedule_status}
        </span>
      ),
    },
    {
      key: 'actions',
      label: 'การดำเนินการ',
      render: (r) => {
        const blocked = r.schedule_status === 'BLOCKED';
        const label = `${formatDay(r.work_date)} ${timeText(r.start_time)}`;
        return (
          <div className="flex flex-wrap gap-2">
            <button
              type="button"
              disabled={busyId === r.schedule_id}
              onClick={() =>
                act(r, () => setScheduleBlock(resourceId, kind, r.schedule_id, !blocked), blocked ? 'ปลดบล็อกช่วงเวลาแล้ว' : 'บล็อกช่วงเวลาแล้ว')
              }
              aria-label={`${blocked ? 'ปลดบล็อก' : 'บล็อก'} ${label}`}
              className={`${btn} border-slate-300 text-slate-700 hover:bg-slate-100`}
            >
              {blocked ? 'ปลดบล็อก' : 'บล็อก'}
            </button>
            <button
              type="button"
              disabled={busyId === r.schedule_id}
              onClick={() => act(r, () => deleteSchedule(resourceId, kind, r.schedule_id), 'ลบช่วงเวลาแล้ว')}
              aria-label={`ลบ ${label}`}
              className={`${btn} border-red-300 text-red-800 hover:bg-red-50`}
            >
              ลบ
            </button>
          </div>
        );
      },
    },
  ];

  return (
    <section aria-labelledby="sch-title" className="space-y-3">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h2 id="sch-title" className="text-lg font-semibold text-slate-800">ช่วงเวลาที่เปิดไว้</h2>
          <p className="text-sm text-slate-600" aria-live="polite">{table.meta ? `ทั้งหมด ${table.meta.total} ช่วง` : 'กำลังโหลด…'} · ลบได้เฉพาะช่วงที่ไม่เคยมีการจอง</p>
        </div>
        <div className="flex flex-wrap items-center gap-3 text-sm text-slate-700">
          <label className="flex items-center gap-2">
            <span>ตั้งแต่</span>
            <input type="date" name="date_from" value={table.params.filters.date_from ?? ''} onChange={(e) => table.setFilter('date_from', e.target.value)} className={fieldClass} />
          </label>
          <label className="flex items-center gap-2">
            <span>ถึง</span>
            <input type="date" name="date_to" value={table.params.filters.date_to ?? ''} onChange={(e) => table.setFilter('date_to', e.target.value)} className={fieldClass} />
          </label>
        </div>
      </div>
      <ErrorBanner onDismiss={() => setError(null)}>{error}</ErrorBanner>
      <DataTable
        caption="ตารางช่วงเวลาที่เปิดให้จอง"
        columns={columns}
        rows={table.rows}
        rowKey="schedule_id"
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
        emptyText="ยังไม่มีช่วงเวลาที่เปิดไว้ในช่วงวันที่นี้"
      />
    </section>
  );
}
