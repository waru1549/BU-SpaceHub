// โลโก้ BU SpaceHub: กริด 4 ช่อง แทน 4 บริการ (ห้อง, เครื่องพิมพ์, อุปกรณ์, แจ้งซ่อม)
export default function Logo({ className = '' }) {
  return (
    <div className={`flex items-center gap-3 ${className}`}>
      <span
        aria-hidden="true"
        className="grid h-11 w-11 shrink-0 grid-cols-2 gap-1 rounded-2xl bg-slate-800 p-2 shadow-sm"
      >
        <span className="rounded-md bg-indigo-300" />
        <span className="rounded-md bg-emerald-300" />
        <span className="rounded-md bg-amber-200" />
        <span className="rounded-md bg-sky-300" />
      </span>
      <span className="leading-tight">
        <span className="block text-lg font-bold text-slate-800">BU SpaceHub</span>
        <span className="block text-xs text-slate-500">Campus Resource Management</span>
      </span>
    </div>
  );
}