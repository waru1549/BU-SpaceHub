import { useAuth } from '../hooks/useAuth.js';

export default function Profile() {
  const { profile } = useAuth();

  const rows = [
    ['ชื่อ', profile.fullName],
    ['อีเมล', profile.email],
    ['รหัสผู้ใช้', profile.userCode],
    ['บทบาท', profile.role],
    ['สถานะ', profile.status],
  ];

  return (
    <section className="max-w-xl rounded-xl border border-slate-200 bg-white p-6 shadow-sm">
      <h1 className="text-2xl font-bold">โปรไฟล์</h1>
      <dl className="mt-4 divide-y divide-slate-100">
        {rows.map(([label, value]) => (
          <div key={label} className="flex justify-between gap-4 py-2 text-sm">
            <dt className="text-slate-500">{label}</dt>
            <dd className="font-medium">{value}</dd>
          </div>
        ))}
      </dl>
    </section>
  );
}