export default function KpiCard({ label, value, icon: Icon, tone, loading }) {
  return (
    <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
      <div className="flex items-start justify-between gap-3">
        <p className="text-sm text-slate-600">{label}</p>
        <span className={`grid h-10 w-10 shrink-0 place-items-center rounded-xl ${tone}`}>
          <Icon className="h-5 w-5" aria-hidden="true" />
        </span>
      </div>
      {loading ? (
        <div
          aria-hidden="true"
          className="mt-3 h-9 w-24 animate-pulse rounded bg-slate-200 motion-reduce:animate-none"
        />
      ) : (
        <p className="mt-3 text-3xl font-bold text-slate-900">{value}</p>
      )}
    </div>
  );
}