import { useMemo, useState } from 'react';
import DataTable from '../components/Tables/DataTable.jsx';
import { formatNumber } from '../utils/format.js';

const CATEGORY_STYLE = {
  ROOM: 'bg-indigo-50 text-indigo-800',
  PRINTER: 'bg-emerald-50 text-emerald-800',
  EQUIPMENT: 'bg-amber-50 text-amber-900',
};

const MOCK = Array.from({ length: 57 }, (_, i) => {
  const category = ['ROOM', 'PRINTER', 'EQUIPMENT'][i % 3];
  return {
    id: i + 1,
    code: `RES-${String(i + 1).padStart(3, '0')}`,
    name: `ทรัพยากรตัวอย่าง ${i + 1}`,
    category,
    hours: (i * 7) % 90,
    pct: category === 'EQUIPMENT' ? null : (i * 13) % 100,
  };
});

const columns = [
  { key: 'code', label: 'รหัส', sortable: true },
  { key: 'name', label: 'ชื่อ', sortable: true },
  {
    key: 'category',
    label: 'ประเภท',
    sortable: true,
    render: (r) => (
      <span className={`rounded-full px-2.5 py-0.5 text-xs font-semibold ${CATEGORY_STYLE[r.category]}`}>
        {r.category}
      </span>
    ),
  },
  { key: 'hours', label: 'ชั่วโมงใช้งาน', sortable: true, align: 'right', render: (r) => formatNumber(r.hours, 1) },
  {
    key: 'pct',
    label: 'อัตราการใช้ (%)',
    sortable: true,
    align: 'right',
    render: (r) => (r.pct === null ? '-' : formatNumber(r.pct, 2)),
  },
];

const MODES = [
  ['normal', 'ปกติ'],
  ['loading', 'จำลอง loading'],
  ['error', 'จำลอง error'],
  ['empty', 'ข้อมูลว่าง'],
];

export default function DevTablePreview() {
  const [page, setPage] = useState(1);
  const [limit, setLimit] = useState(10);
  const [sort, setSort] = useState('code');
  const [order, setOrder] = useState('asc');
  const [mode, setMode] = useState('normal');

  const source = mode === 'empty' ? [] : MOCK;

  const sorted = useMemo(() => {
    const dir = order === 'asc' ? 1 : -1;
    return [...source].sort((a, b) => {
      const x = a[sort];
      const y = b[sort];
      if (x === y) return a.id - b.id;
      if (x === null) return 1; // NULL ไปท้ายเสมอ เหมือนฝั่ง BE
      if (y === null) return -1;
      return (x > y ? 1 : -1) * dir;
    });
  }, [source, sort, order]);

  const total = sorted.length;
  const totalPages = Math.max(1, Math.ceil(total / limit));
  const rows = sorted.slice((page - 1) * limit, page * limit);

  return (
    <section className="space-y-4">
      <h1 className="text-2xl font-bold text-slate-800">ทดสอบ DataTable (ชั่วคราว)</h1>

      <div className="flex flex-wrap gap-2">
        {MODES.map(([value, label]) => (
          <button
            key={value}
            type="button"
            onClick={() => setMode(value)}
            aria-pressed={mode === value}
            className={`rounded-lg border px-3 py-1.5 text-sm ${
              mode === value
                ? 'border-indigo-600 bg-indigo-600 text-white'
                : 'border-slate-300 bg-white text-slate-700 hover:bg-slate-100'
            }`}
          >
            {label}
          </button>
        ))}
      </div>

      <DataTable
        caption="ตารางทดสอบทรัพยากร"
        columns={columns}
        rows={mode === 'loading' || mode === 'error' ? [] : rows}
        rowKey="id"
        loading={mode === 'loading'}
        error={mode === 'error' ? 'โหลดข้อมูลไม่สำเร็จ' : null}
        onRetry={() => setMode('normal')}
        page={page}
        limit={limit}
        total={total}
        totalPages={totalPages}
        sort={sort}
        order={order}
        onPageChange={setPage}
        onLimitChange={(n) => {
          setLimit(n);
          setPage(1);
        }}
        onSortChange={({ sort: s, order: o }) => {
          setSort(s);
          setOrder(o);
          setPage(1);
        }}
      />
    </section>
  );
}