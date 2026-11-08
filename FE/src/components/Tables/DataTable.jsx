import {
  AlertCircle,
  ArrowDown,
  ArrowUp,
  ChevronLeft,
  ChevronRight,
  ChevronsLeft,
  ChevronsRight,
  ChevronsUpDown,
  Inbox,
} from 'lucide-react';

const focusRing =
  'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-500';

const ALIGN = {
  left: { text: 'text-left', flex: 'justify-start' },
  right: { text: 'text-right', flex: 'justify-end' },
  center: { text: 'text-center', flex: 'justify-center' },
};

function SortIcon({ active, order }) {
  if (!active) return <ChevronsUpDown className="h-4 w-4 text-slate-500" aria-hidden="true" />;
  const Icon = order === 'asc' ? ArrowUp : ArrowDown;
  return <Icon className="h-4 w-4 text-indigo-700" aria-hidden="true" />;
}

function PagerButton({ label, disabled, onClick, children }) {
  return (
    <button
      type="button"
      aria-label={label}
      disabled={disabled}
      onClick={onClick}
      className={`grid h-9 w-9 place-items-center rounded-lg border border-slate-300 text-slate-700 hover:bg-slate-100 disabled:cursor-not-allowed disabled:opacity-40 disabled:hover:bg-transparent ${focusRing}`}
    >
      {children}
    </button>
  );
}

/**
 * ตารางแบบ controlled: ไม่ดึงข้อมูลเอง
 * columns: [{ key, label, sortable?, align?, render?(row), className? }]
 * sort/order/page/limit/total/totalPages มาจากผู้ใช้ component (state หรือ meta ของ API)
 */
export default function DataTable({
  caption,
  columns,
  rows,
  rowKey,
  loading = false,
  error = null,
  onRetry,
  page,
  limit,
  total,
  totalPages,
  sort,
  order,
  limitOptions = [10, 25, 50],
  onPageChange,
  onLimitChange,
  onSortChange,
  emptyText = 'ไม่พบข้อมูล',
  maxHeightClass = 'max-h-[28rem]',
}) {
  const initialLoading = loading && rows.length === 0;
  const refreshing = loading && rows.length > 0;
  const from = total === 0 ? 0 : (page - 1) * limit + 1;
  const to = Math.min(page * limit, total);
  const getKey = (row) => (typeof rowKey === 'function' ? rowKey(row) : row[rowKey]);

  const handleSort = (key) => {
    const nextOrder = sort === key && order === 'asc' ? 'desc' : 'asc';
    onSortChange?.({ sort: key, order: nextOrder });
  };

  return (
    <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm">
      {/* พื้นที่เลื่อน: แนวตั้งเมื่อสูงเกิน, แนวนอนบนจอแคบ; focus ได้เพื่อเลื่อนด้วยคีย์บอร์ด */}
      <div
        className={`${maxHeightClass} overflow-auto`}
        role="region"
        aria-label={caption}
        tabIndex={0}
        aria-busy={loading}
      >
        <table className="w-full min-w-[40rem] border-separate border-spacing-0 text-sm">
          <caption className="sr-only">{caption}</caption>
          <thead>
            <tr>
              {columns.map((col) => {
                const align = ALIGN[col.align ?? 'left'];
                const active = sort === col.key;
                return (
                  <th
                    key={col.key}
                    scope="col"
                    aria-sort={
                      col.sortable ? (active ? (order === 'asc' ? 'ascending' : 'descending') : 'none') : undefined
                    }
                    className={`sticky top-0 z-10 whitespace-nowrap border-b border-slate-200 bg-slate-50 px-4 py-3 text-xs font-semibold text-slate-600 ${align.text}`}
                  >
                    {col.sortable ? (
                      <button
                        type="button"
                        onClick={() => handleSort(col.key)}
                        className={`flex w-full items-center gap-1 rounded ${align.flex} hover:text-slate-900 ${focusRing}`}
                      >
                        {col.label}
                        <SortIcon active={active} order={order} />
                      </button>
                    ) : (
                      col.label
                    )}
                  </th>
                );
              })}
            </tr>
          </thead>

          <tbody className={refreshing ? 'opacity-60 transition-opacity' : 'transition-opacity'}>
            {initialLoading &&
              Array.from({ length: 6 }, (_, i) => (
                <tr key={`sk-${i}`} aria-hidden="true">
                  {columns.map((col) => (
                    <td key={col.key} className="border-b border-slate-100 px-4 py-3">
                      <div className="h-4 w-full max-w-[8rem] animate-pulse rounded bg-slate-200 motion-reduce:animate-none" />
                    </td>
                  ))}
                </tr>
              ))}

            {error && !loading && (
              <tr>
                <td colSpan={columns.length} className="px-4 py-12 text-center">
                  <div role="alert" className="flex flex-col items-center gap-3 text-slate-700">
                    <AlertCircle className="h-8 w-8 text-red-700" aria-hidden="true" />
                    <p>{error}</p>
                    {onRetry && (
                      <button
                        type="button"
                        onClick={onRetry}
                        className={`rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700 ${focusRing}`}
                      >
                        ลองอีกครั้ง
                      </button>
                    )}
                  </div>
                </td>
              </tr>
            )}

            {!error && !loading && rows.length === 0 && (
              <tr>
                <td colSpan={columns.length} className="px-4 py-12 text-center text-slate-600">
                  <Inbox className="mx-auto mb-2 h-8 w-8 text-slate-500" aria-hidden="true" />
                  {emptyText}
                </td>
              </tr>
            )}

            {!error &&
              rows.map((row) => (
                <tr key={getKey(row)} className="hover:bg-slate-50">
                  {columns.map((col) => (
                    <td
                      key={col.key}
                      className={`border-b border-slate-100 px-4 py-3 text-slate-800 ${
                        ALIGN[col.align ?? 'left'].text
                      } ${col.className ?? ''}`}
                    >
                      {col.render ? col.render(row) : (row[col.key] ?? '-')}
                    </td>
                  ))}
                </tr>
              ))}
          </tbody>
        </table>
      </div>

      <div className="flex flex-col gap-3 border-t border-slate-200 px-4 py-3 text-sm text-slate-700 sm:flex-row sm:items-center sm:justify-between">
        <p aria-live="polite">
          {total === 0 ? 'ไม่มีรายการ' : `แสดง ${from}-${to} จาก ${total} รายการ`}
        </p>

        <div className="flex flex-wrap items-center gap-x-4 gap-y-2">
          <label className="flex items-center gap-2">
            <span>แถวต่อหน้า</span>
            <select
              value={limit}
              onChange={(e) => onLimitChange?.(Number(e.target.value))}
              className={`rounded-lg border border-slate-300 bg-white px-2 py-1.5 ${focusRing}`}
            >
              {limitOptions.map((n) => (
                <option key={n} value={n}>
                  {n}
                </option>
              ))}
            </select>
          </label>

          <div className="flex items-center gap-1">
            <PagerButton label="หน้าแรก" disabled={page <= 1} onClick={() => onPageChange?.(1)}>
              <ChevronsLeft className="h-4 w-4" aria-hidden="true" />
            </PagerButton>
            <PagerButton label="หน้าก่อนหน้า" disabled={page <= 1} onClick={() => onPageChange?.(page - 1)}>
              <ChevronLeft className="h-4 w-4" aria-hidden="true" />
            </PagerButton>
            <span className="min-w-[5.5rem] px-2 text-center">
              หน้า {page} / {totalPages}
            </span>
            <PagerButton
              label="หน้าถัดไป"
              disabled={page >= totalPages}
              onClick={() => onPageChange?.(page + 1)}
            >
              <ChevronRight className="h-4 w-4" aria-hidden="true" />
            </PagerButton>
            <PagerButton
              label="หน้าสุดท้าย"
              disabled={page >= totalPages}
              onClick={() => onPageChange?.(totalPages)}
            >
              <ChevronsRight className="h-4 w-4" aria-hidden="true" />
            </PagerButton>
          </div>
        </div>
      </div>
    </div>
  );
}