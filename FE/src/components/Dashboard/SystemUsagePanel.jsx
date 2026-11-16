import { useMemo } from 'react';
import DataTable from '../Tables/DataTable.jsx';
import { usePagedData } from '../../hooks/usePagedData.js';
import { getTable } from '../../services/dashboard.service.js';
import { REPAIR_CATEGORY_TEXT, RESOURCE_STATUS_TEXT, formatDecimal, formatPercent } from '../../utils/dashboard.js';
import { formatNumber } from '../../utils/dashboard.js';

// ห้อง/เครื่องพิมพ์/อุปกรณ์: ตารางการใช้งานทรัพยากร | แจ้งซ่อม: อันดับทรัพยากรที่ถูกแจ้งซ่อมมากที่สุด
// ใช้ key={system.key} ที่ตัวเรียก เพื่อให้ตารางเริ่มใหม่ทุกครั้งที่เปลี่ยนระบบ
export default function SystemUsagePanel({ system }) {
  const isRepair = system.key === 'maintenance';

  const fetcher = useMemo(
    () => (p) =>
      isRepair
        ? getTable('repair_ranking', p)
        : getTable('utilization', { ...p, filters: { ...p.filters, resource_category: system.api } }),
    [isRepair, system.api],
  );
  const table = usePagedData(fetcher, isRepair
    ? { sort: 'repair_count', order: 'desc' }
    : { sort: 'total_bookings', order: 'desc' });

  const columns = isRepair
    ? [
        { key: 'resource_code', label: 'รหัส', sortable: true },
        { key: 'resource_name', label: 'ทรัพยากร', sortable: true },
        {
          key: 'resource_category',
          label: 'ประเภท',
          sortable: true,
          render: (r) => REPAIR_CATEGORY_TEXT[r.resource_category] ?? r.resource_category,
        },
        { key: 'repair_count', label: 'ครั้งที่ถูกแจ้งซ่อม', sortable: true, render: (r) => formatNumber(r.repair_count) },
        { key: 'open_count', label: 'ยังไม่ปิดงาน', sortable: true, render: (r) => formatNumber(r.open_count) },
      ]
    : [
        { key: 'resource_code', label: 'รหัส', sortable: true },
        { key: 'resource_name', label: 'ทรัพยากร', sortable: true },
        {
          key: 'resource_status',
          label: 'สถานะ',
          sortable: true,
          render: (r) => RESOURCE_STATUS_TEXT[r.resource_status] ?? r.resource_status,
        },
        { key: 'total_bookings', label: 'จำนวนครั้งที่ใช้', sortable: true, render: (r) => formatNumber(r.total_bookings) },
        { key: 'used_hours', label: 'ชั่วโมงที่ใช้', sortable: true, render: (r) => formatDecimal(r.used_hours) },
        {
          key: 'utilization_pct',
          label: 'อัตราการใช้งาน',
          sortable: true,
          render: (r) =>
            r.utilization_pct === null ? (
              <span className="text-slate-600">-</span>
            ) : (
              <span className="flex items-center gap-2">
                <span aria-hidden="true" className="h-2 w-16 overflow-hidden rounded-full bg-slate-100">
                  <span
                    className="block h-full rounded-full"
                    style={{ width: `${Math.min(100, Number(r.utilization_pct))}%`, background: system.color }}
                  />
                </span>
                <span className="font-medium text-slate-900">{formatPercent(r.utilization_pct)}</span>
              </span>
            ),
        },
      ];

  return (
    <section aria-labelledby="sys-usage-title" className="space-y-3">
      <div>
        <h2 id="sys-usage-title" className="text-lg font-semibold text-slate-800">
          {isRepair ? 'ทรัพยากรที่ถูกแจ้งซ่อมมากที่สุด' : 'การใช้งานทรัพยากร'}
        </h2>
        <p className="text-sm text-slate-600">
          {isRepair
            ? 'นับเฉพาะงานที่ไม่ถูกปฏิเสธ/ยกเลิก และผูกกับทรัพยากรในระบบ'
            : system.key === 'equipment'
              ? 'อุปกรณ์ไม่มีตารางเวลาคงที่ จึงไม่แสดงอัตราการใช้งาน (วัดจากจำนวนครั้งและชั่วโมงที่ถูกยืม)'
              : 'อัตราการใช้งาน = ชั่วโมงที่ถูกใช้ ÷ ชั่วโมงที่เปิดให้บริการ'}
        </p>
      </div>
      <DataTable
        caption={isRepair ? 'อันดับทรัพยากรที่ถูกแจ้งซ่อม' : `การใช้งานทรัพยากรของ${system.label}`}
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
        emptyText="ยังไม่มีข้อมูล"
      />
    </section>
  );
}
