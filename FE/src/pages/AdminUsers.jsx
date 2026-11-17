import { useEffect, useRef, useState } from 'react';
import { Search, ShieldCheck, UserCheck, UserX } from 'lucide-react';
import DataTable from '../components/Tables/DataTable.jsx';
import Notice from '../components/Feedback/Notice.jsx';
import { RoleBadge, UserStatusBadge } from '../components/Admin/UserBadges.jsx';
import UserRoleModal from '../components/Admin/UserRoleModal.jsx';
import UserStatusModal from '../components/Admin/UserStatusModal.jsx';
import { usePagedData } from '../hooks/usePagedData.js';
import { listUsers } from '../services/adminUsers.service.js';
import { ROLE_FILTER, STATUS_FILTER, formatDateTime } from '../utils/adminUsers.js';

const focusRing = 'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600';
const fieldClass = `rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 ${focusRing}`;
const actionBtn = `inline-flex items-center gap-1 whitespace-nowrap rounded-lg border bg-white px-3 py-1 text-sm font-medium ${focusRing}`;

export default function AdminUsers() {
  const table = usePagedData(listUsers, { sort: 'created_at', order: 'desc', filters: {} });
  const [notice, setNotice] = useState(null);
  const [roleTarget, setRoleTarget] = useState(null);
  const [statusTarget, setStatusTarget] = useState(null);
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
    {
      key: 'full_name',
      label: 'ผู้ใช้',
      sortable: true,
      render: (r) => (
        <>
          <span className="block font-medium text-slate-900">{r.full_name}</span>
          <span className="block break-all text-xs text-slate-600">{r.email}</span>
        </>
      ),
    },
    { key: 'role', label: 'บทบาท', sortable: true, render: (r) => <RoleBadge role={r.role} /> },
    { key: 'user_status', label: 'สถานะ', sortable: true, render: (r) => <UserStatusBadge status={r.user_status} /> },
    {
      key: 'booking_count',
      label: 'รายการทั้งหมด',
      sortable: true,
      render: (r) => (
        <>
          {r.booking_count.toLocaleString('th-TH')}
          {r.active_count > 0 && <span className="block text-xs text-amber-800">กำลังดำเนินการ {r.active_count}</span>}
        </>
      ),
    },
    {
      key: 'last_login',
      label: 'เข้าสู่ระบบล่าสุด',
      sortable: true,
      render: (r) => <span className="whitespace-nowrap text-xs text-slate-700">{formatDateTime(r.last_login)}</span>,
    },
    {
      key: 'actions',
      label: 'การดำเนินการ',
      render: (r) => (
        <div className="flex flex-wrap gap-2">
          <button
            type="button"
            onClick={() => setRoleTarget(r)}
            aria-label={`เปลี่ยนบทบาท ${r.full_name}`}
            className={`${actionBtn} border-indigo-300 text-indigo-800 hover:bg-indigo-50`}
          >
            <ShieldCheck className="h-3.5 w-3.5" aria-hidden="true" />
            บทบาท
          </button>
          {r.user_status === 'ACTIVE' ? (
            <button
              type="button"
              onClick={() => setStatusTarget({ row: r, next: 'SUSPENDED' })}
              aria-label={`ระงับบัญชี ${r.full_name}`}
              className={`${actionBtn} border-red-300 text-red-800 hover:bg-red-50`}
            >
              <UserX className="h-3.5 w-3.5" aria-hidden="true" />
              ระงับ
            </button>
          ) : (
            <button
              type="button"
              onClick={() => setStatusTarget({ row: r, next: 'ACTIVE' })}
              aria-label={`เปิดใช้งานบัญชี ${r.full_name}`}
              className={`${actionBtn} border-emerald-300 text-emerald-900 hover:bg-emerald-50`}
            >
              <UserCheck className="h-3.5 w-3.5" aria-hidden="true" />
              เปิดใช้งาน
            </button>
          )}
        </div>
      ),
    },
  ];

  const done = (text) => {
    setRoleTarget(null);
    setStatusTarget(null);
    setNotice(text);
    table.reload();
  };

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-2xl font-bold text-slate-800">จัดการผู้ใช้</h1>
        <p className="text-sm text-slate-600">
          ค้นหาผู้ใช้ เปลี่ยนบทบาท และระงับ/เปิดใช้งานบัญชี (เปลี่ยนบัญชีของตัวเองไม่ได้ และต้องเหลือผู้ดูแลระบบอย่างน้อย 1 คน)
        </p>
      </header>

      {notice && (
        <Notice type="success" onDismiss={() => setNotice(null)}>
          {notice}
        </Notice>
      )}

      <section aria-labelledby="usr-list-title" className="space-y-3">
        <h2 id="usr-list-title" className="sr-only">รายการผู้ใช้</h2>
        <div className="flex flex-wrap items-end gap-3">
          <div className="min-w-56 flex-1">
            <label htmlFor="usr-search" className="mb-1 block text-xs font-semibold text-slate-700">ค้นหา</label>
            <div className="relative">
              <Search className="pointer-events-none absolute top-1/2 left-3 h-4 w-4 -translate-y-1/2 text-slate-500" aria-hidden="true" />
              <input
                id="usr-search"
                type="search"
                name="q"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="ชื่อ อีเมล หรือรหัสนักศึกษา"
                autoComplete="off"
                className={`${fieldClass} w-full pl-9`}
              />
            </div>
          </div>
          <label className="text-sm text-slate-700">
            <span className="mb-1 block text-xs font-semibold">บทบาท</span>
            <select name="role" value={table.params.filters.role ?? ''} onChange={(e) => table.setFilter('role', e.target.value)} className={fieldClass}>
              {ROLE_FILTER.map(([value, label]) => (
                <option key={value} value={value}>{label}</option>
              ))}
            </select>
          </label>
          <label className="text-sm text-slate-700">
            <span className="mb-1 block text-xs font-semibold">สถานะ</span>
            <select
              name="user_status"
              value={table.params.filters.user_status ?? ''}
              onChange={(e) => table.setFilter('user_status', e.target.value)}
              className={fieldClass}
            >
              {STATUS_FILTER.map(([value, label]) => (
                <option key={value} value={value}>{label}</option>
              ))}
            </select>
          </label>
        </div>
        <p className="text-sm text-slate-600" aria-live="polite">{table.meta ? `พบ ${table.meta.total} รายการ` : 'กำลังโหลด…'}</p>

        <DataTable
          caption="ตารางผู้ใช้"
          columns={columns}
          rows={table.rows}
          rowKey="user_id"
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
          emptyText="ไม่พบผู้ใช้ตามเงื่อนไขที่เลือก"
        />
      </section>

      <UserRoleModal target={roleTarget} onClose={() => setRoleTarget(null)} onDone={done} onStale={table.reload} />
      <UserStatusModal target={statusTarget} onClose={() => setStatusTarget(null)} onDone={done} onStale={table.reload} />
    </div>
  );
}
