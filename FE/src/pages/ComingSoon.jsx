export default function ComingSoon({ title, step, description }) {
  return (
    <section className="rounded-2xl border border-slate-200 bg-white p-8 text-center shadow-sm">
      <h1 className="text-2xl font-bold text-slate-800">{title}</h1>
      <p className="mt-2 text-slate-600">{description ?? 'หน้านี้กำลังพัฒนา'}</p>
      {step && (
        <p className="mt-4 inline-block rounded-full bg-indigo-50 px-4 py-1 text-sm text-indigo-800">
          จะสร้างใน {step}
        </p>
      )}
    </section>
  );
}