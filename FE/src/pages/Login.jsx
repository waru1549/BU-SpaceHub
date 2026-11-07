import { Link, Navigate, useLocation } from 'react-router';
import { ArrowRight, Box, CalendarDays, PackageCheck, UserCog, Users, Wrench } from 'lucide-react';
import Logo from '../components/Brand/Logo.jsx';
import GoogleIcon from '../components/Brand/GoogleIcon.jsx';
import { useAuth } from '../hooks/useAuth.js';

const FEATURES = [
  { icon: CalendarDays, label: 'จองห้อง' },
  { icon: Box, label: 'เครื่องพิมพ์ 3D' },
  { icon: PackageCheck, label: 'ยืม-คืนอุปกรณ์' },
  { icon: Wrench, label: 'แจ้งซ่อม' },
];

const focusRing =
  'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-500';

function RoleLink({ to, icon: Icon, title, caption, tone }) {
  return (
    <div>
      <Link
        to={to}
        className={`flex items-center gap-3 rounded-full border px-5 py-3.5 font-medium transition ${tone} ${focusRing}`}
      >
        <Icon className="h-5 w-5" aria-hidden="true" />
        <span className="flex-1 text-center">{title}</span>
        <ArrowRight className="h-4 w-4 opacity-60" aria-hidden="true" />
      </Link>
      <p className="mt-1.5 pl-6 text-xs text-slate-500">{caption}</p>
    </div>
  );
}

export default function Login() {
  const { isAuthenticated, authError, loginWithGoogle } = useAuth();
  const location = useLocation();

  if (isAuthenticated) return <Navigate to={location.state?.from || '/'} replace />;

  return (
    <div className="mx-auto flex min-h-screen max-w-6xl flex-col px-5 py-6 sm:px-8">
      <header className="flex items-center justify-between">
        <Logo />
        <span className="text-xs text-slate-500">Bangkok University</span>
      </header>

      <main className="grid flex-1 items-center gap-10 py-10 lg:grid-cols-2 lg:gap-16">
        <section className="fade-up">
          <h1 className="text-3xl font-bold leading-tight text-slate-800 sm:text-4xl lg:text-5xl">
            ทุกบริการของมหาวิทยาลัย
            <span className="block text-indigo-600">ในที่เดียว</span>
          </h1>
          <p className="mt-4 max-w-md text-base text-slate-600">
            จองห้อง จองเครื่องพิมพ์ 3 มิติ ยืมอุปกรณ์ และแจ้งซ่อม
            ได้ง่ายด้วยบัญชีมหาวิทยาลัยของคุณ
          </p>
          {/* ซ่อนบนมือถือเพื่อให้การ์ดล็อกอินอยู่ใกล้หน้าจอแรก */}
          <ul className="mt-8 hidden max-w-md grid-cols-4 gap-4 sm:grid">
            {FEATURES.map(({ icon: Icon, label }) => (
              <li key={label} className="flex flex-col items-center gap-2 text-center text-xs text-slate-600">
                <span className="grid h-12 w-12 place-items-center rounded-full bg-white/80 text-indigo-600 shadow-sm ring-1 ring-slate-200">
                  <Icon className="h-5 w-5" aria-hidden="true" />
                </span>
                {label}
              </li>
            ))}
          </ul>
        </section>

        <section
          className="glass-card fade-up mx-auto w-full max-w-md p-6 sm:p-8"
          aria-labelledby="login-title"
        >
          <h2 id="login-title" className="text-2xl font-bold text-slate-800">
            เข้าสู่ระบบ
          </h2>
          <p className="mt-1 text-sm text-slate-500">เลือกวิธีการเข้าสู่ระบบที่ต้องการ</p>

          {authError && (
            <p role="alert" className="mt-4 rounded-xl bg-rose-50 px-4 py-3 text-sm text-rose-700">
              {authError}
            </p>
          )}

          <button
            type="button"
            onClick={loginWithGoogle}
            className={`mt-6 flex w-full items-center gap-3 rounded-full border border-slate-200 bg-white px-5 py-3.5 font-medium text-slate-700 shadow-sm transition hover:shadow-md ${focusRing}`}
          >
            <GoogleIcon />
            <span className="flex-1 text-center">เข้าสู่ระบบด้วย Google</span>
            <ArrowRight className="h-4 w-4 text-slate-500" aria-hidden="true" />
          </button>
          <p className="mt-2 text-center text-xs text-slate-500">ใช้อีเมล @bumail.net เท่านั้น</p>

          <div className="my-6 flex items-center gap-3 text-xs text-slate-500">
            <span className="h-px flex-1 bg-slate-200" />
            หรือ
            <span className="h-px flex-1 bg-slate-200" />
          </div>

          <div className="space-y-4">
            <RoleLink
              to="/login/admin"
              icon={UserCog}
              title="เข้าสู่ระบบสำหรับแอดมิน"
              caption="สำหรับผู้ดูแลระบบ (Admin)"
              tone="border-indigo-200 bg-indigo-50/80 text-indigo-800 hover:bg-indigo-100"
            />
            <RoleLink
              to="/login/staff"
              icon={Users}
              title="เข้าสู่ระบบสำหรับสตาฟ"
              caption="สำหรับเจ้าหน้าที่ (Staff)"
              tone="border-emerald-200 bg-emerald-50/80 text-emerald-800 hover:bg-emerald-100"
            />
          </div>

          <p className="mt-6 text-center text-xs leading-relaxed text-slate-500">
            หากคุณเป็นนักศึกษาหรือผู้ใช้ทั่วไป สามารถเข้าสู่ระบบด้วย Google เพื่อใช้งานได้ทันที
          </p>
        </section>
      </main>
    </div>
  );
}