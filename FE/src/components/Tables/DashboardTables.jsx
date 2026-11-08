import { useState } from 'react';
import DataTable from './DataTable.jsx';
import { useTableData } from '../../hooks/useTableData.js';
import { ROLES } from '../../utils/constants.js';
import { ROLE_LABEL } from '../../utils/navigation.js';
import { formatBaht, formatDate, formatNumber } from '../../utils/format.js';

const ALL = [ROLES.USER, ROLES.STAFF, ROLES.ADMIN];
const STAFF_UP = [ROLES.STAFF, ROLES.ADMIN];

const BADGE_TONE = {
  indigo: 'bg-indigo-50 text-indigo-800',
  emerald: 'bg-emerald-50 text-emerald-800',
  amber: 'bg-amber-50 text-amber-900',
  red: 'bg-red-50 text-red-800',
  slate: 'bg-slate-100 text-slate-700',
};

function Badge({ tone = 'slate', children }) {
  return (
    <span className={`inline-block whitespace-nowrap rounded-full px-2.5 py-0.5 text-xs font-semibold ${BADGE_TONE[tone]}`}>
      {children}
    </span>
  );
}

const CATEGORY = { ROOM: ['indigo', 'ห้อง'], PRINTER: ['emerald', 'เครื่องพิมพ์'], EQUIPMENT: ['amber', 'อุปกรณ์'] };
const TRACKING_TONE = { 'ปิดงานแล้ว': 'emerald', 'ปฏิเสธ': 'slate', 'ค้างดำเนินการ': 'amber' };
const ROLE_TONE = { ADMIN: 'indigo', STAFF: 'emerald', USER: 'slate' };

const TABS = [
  {
    name: 'utilization',
    label: 'การใช้ทรัพยากร',
    roles: ALL,
    rowKey: 'resource_id',
    sort: 'resource_code',
    order: 'asc',
    filter: {
      key: 'resource_category',
      label: 'ประเภท',
      options: [['', 'ทั้งหมด'], ['ROOM', 'ห้อง'], ['PRINTER', 'เครื่องพิมพ์ 3D'], ['EQUIPMENT', 'อุปกรณ์']],
    },
    columns: [
      { key: 'resource_code', label: 'รหัส', sortable: true },
      { key: 'resource_name', label: 'ชื่อ', sortable: true },
      {
        key: 'resource_category',
        label: 'ประเภท',
        sortable: true,
        render: (r) => <Badge tone={CATEGORY[r.resource_category]?.[0]}>{CATEGORY[r.resource_category]?.[1] ?? r.resource_category}</Badge>,
      },
      { key: 'total_bookings', label: 'จำนวนรายการ', sortable: true, align: 'right', render: (r) => formatNumber(r.total_bookings) },
      { key: 'used_hours', label: 'ชั่วโมงใช้งาน', sortable: true, align: 'right', render: (r) => formatNumber(r.used_hours, 1) },
      { key: 'utilization_pct', label: 'อัตราการใช้ (%)', sortable: true, align: 'right', render: (r) => (r.utilization_pct === null ? '-' : formatNumber(r.utilization_pct, 2)) },
    ],
  },
  {
    name: 'overdue',
    label: 'อุปกรณ์เกินกำหนด',
    roles: STAFF_UP,
    rowKey: 'booking_id',
    sort: 'overdue_days',
    order: 'desc',
    filter: {
      key: 'overdue_type',
      label: 'สถานะ',
      options: [['', 'ทั้งหมด'], ['ยังไม่คืน (ค้างอยู่)', 'ยังไม่คืน (ค้างอยู่)'], ['คืนแล้วแต่ล่าช้า', 'คืนแล้วแต่ล่าช้า']],
    },
    columns: [
      { key: 'booking_code', label: 'รหัสการยืม', sortable: true },
      { key: 'borrower_name', label: 'ผู้ยืม', sortable: true },
      { key: 'equipment_name', label: 'อุปกรณ์', sortable: true },
      { key: 'expected_return_date', label: 'กำหนดคืน', sortable: true, render: (r) => formatDate(r.expected_return_date) },
      { key: 'overdue_days', label: 'เกิน (วัน)', sortable: true, align: 'right', render: (r) => formatNumber(r.overdue_days) },
      { key: 'overdue_type', label: 'สถานะ', render: (r) => <Badge tone={r.actual_return_date ? 'amber' : 'red'}>{r.overdue_type}</Badge> },
      { key: 'total_fine', label: 'ค่าปรับรวม', sortable: true, align: 'right', render: (r) => formatBaht(r.total_fine) },
      { key: 'unpaid_fine', label: 'ค้างชำระ', sortable: true, align: 'right', render: (r) => formatBaht(r.unpaid_fine) },
    ],
  },
  {
    name: 'maintenance',
    label: 'งานแจ้งซ่อม',
    roles: STAFF_UP,
    rowKey: 'booking_id',
    sort: 'reported_date',
    order: 'desc',
    filter: {
      key: 'tracking_state',
      label: 'สถานะ',
      options: [['', 'ทั้งหมด'], ['ค้างดำเนินการ', 'ค้างดำเนินการ'], ['ปิดงานแล้ว', 'ปิดงานแล้ว'], ['ปฏิเสธ', 'ปฏิเสธ']],
    },
    columns: [
      { key: 'booking_code', label: 'รหัส', sortable: true },
      { key: 'repair_title', label: 'เรื่อง' },
      { key: 'resource_name', label: 'ทรัพยากร', sortable: true },
      { key: 'reported_date', label: 'วันที่แจ้ง', sortable: true, render: (r) => formatDate(r.reported_date) },
      { key: 'days_elapsed', label: 'ใช้เวลา (วัน)', sortable: true, align: 'right', render: (r) => formatNumber(r.days_elapsed, 1) },
      { key: 'tracking_state', label: 'สถานะ', sortable: true, render: (r) => <Badge tone={TRACKING_TONE[r.tracking_state]}>{r.tracking_state}</Badge> },
      { key: 'attachment_count', label: 'ไฟล์แนบ', sortable: true, align: 'right', render: (r) => formatNumber(r.attachment_count) },
    ],
  },
  {
    name: 'users',
    label: 'ผู้ใช้งาน',
    roles: [ROLES.ADMIN],
    rowKey: 'user_id',
    sort: 'total_activities',
    order: 'desc',
    filter: {
      key: 'role_name',
      label: 'บทบาท',
      options: [['', 'ทั้งหมด'], ['USER', 'นักศึกษา'], ['STAFF', 'สตาฟ'], ['ADMIN', 'แอดมิน']],
    },
    columns: [
      { key: 'user_code', label: 'รหัส', sortable: true },
      { key: 'full_name', label: 'ชื่อ-นามสกุล', sortable: true },
      { key: 'role_name', label: 'บทบาท', sortable: true, render: (r) => <Badge tone={ROLE_TONE[r.role_name]}>{ROLE_LABEL[r.role_name] ?? r.role_name}</Badge> },
      { key: 'room_bookings', label: 'ห้อง', align: 'right', render: (r) => formatNumber(r.room_bookings) },
      { key: 'printer_bookings', label: 'เครื่องพิมพ์', align: 'right', render: (r) => formatNumber(r.printer_bookings) },
      { key: 'equipment_bookings', label: 'อุปกรณ์', align: 'right', render: (r) => formatNumber(r.equipment_bookings) },
      { key: 'maintenance_reports', label: 'แจ้งซ่อม', align: 'right', render: (r) => formatNumber(r.maintenance_reports) },
      { key: 'total_activities', label: 'รวม', sortable: true, align: 'right', render: (r) => formatNumber(r.total_activities) },
      { key: 'unpaid_fines', label: 'ค่าปรับค้าง', sortable: true, align: 'right', render: (r) => formatBaht(r.unpaid_fines) },
    ],
  },
];

const focusRing =
  'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-500';

function TablePanel({ tab }) {
  const t = useTableData(tab.name, { sort: tab.sort, order: tab.order });

  return (
    <div className="space-y-3">
      {tab.filter && (
        <label className="flex items-center gap-2 text-sm text-slate-700">
          <span>{tab.filter.label}</span>
          <select
            value={t.params.filters[tab.filter.key] ?? ''}
            onChange={(e) => t.setFilter(tab.filter.key, e.target.value)}
            className={`rounded-lg border border-slate-300 bg-white px-2 py-1.5 ${focusRing}`}
          >
            {tab.filter.options.map(([value, label]) => (
              <option key={value} value={value}>
                {label}
              </option>
            ))}
          </select>
        </label>
      )}

      <DataTable
        caption={`ตาราง${tab.label}`}
        columns={tab.columns}
        rows={t.rows}
        rowKey={tab.rowKey}
        loading={t.loading}
        error={t.error}
        onRetry={t.reload}
        page={t.params.page}
        limit={t.params.limit}
        total={t.meta?.total ?? 0}
        totalPages={t.meta?.totalPages ?? 1}
        sort={t.params.sort}
        order={t.params.order}
        onPageChange={t.setPage}
        onLimitChange={t.setLimit}
        onSortChange={t.setSort}
      />
    </div>
  );
}

export default function DashboardTables({ role }) {
  const tabs = TABS.filter((t) => t.roles.includes(role));
  const [activeName, setActiveName] = useState(tabs[0].name);
  const active = tabs.find((t) => t.name === activeName) ?? tabs[0];

  // ลูกศรซ้าย/ขวา, Home, End ตามรูปแบบ tabs มาตรฐาน
  const onKeyDown = (e) => {
    const i = tabs.findIndex((t) => t.name === active.name);
    let next = null;
    if (e.key === 'ArrowRight') next = (i + 1) % tabs.length;
    if (e.key === 'ArrowLeft') next = (i - 1 + tabs.length) % tabs.length;
    if (e.key === 'Home') next = 0;
    if (e.key === 'End') next = tabs.length - 1;
    if (next === null) return;
    e.preventDefault();
    setActiveName(tabs[next].name);
    requestAnimationFrame(() => document.getElementById(`tab-${tabs[next].name}`)?.focus());
  };

  return (
    <section aria-labelledby="tables-title" className="space-y-4">
      <h2 id="tables-title" className="text-lg font-semibold text-slate-800">
        ตารางข้อมูล
      </h2>

      <div role="tablist" aria-label="เลือกตารางข้อมูล" onKeyDown={onKeyDown} className="flex gap-1 overflow-x-auto border-b border-slate-200">
        {tabs.map((tab) => {
          const selected = tab.name === active.name;
          return (
            <button
              key={tab.name}
              id={`tab-${tab.name}`}
              type="button"
              role="tab"
              aria-selected={selected}
              aria-controls={`panel-${tab.name}`}
              tabIndex={selected ? 0 : -1}
              onClick={() => setActiveName(tab.name)}
              className={`-mb-px whitespace-nowrap border-b-2 px-4 py-2.5 text-sm ${focusRing} ${
                selected
                  ? 'border-indigo-600 font-semibold text-indigo-800'
                  : 'border-transparent text-slate-600 hover:text-slate-900'
              }`}
            >
              {tab.label}
            </button>
          );
        })}
      </div>

      <div role="tabpanel" id={`panel-${active.name}`} aria-labelledby={`tab-${active.name}`}>
        <TablePanel key={active.name} tab={active} />
      </div>
    </section>
  );
}