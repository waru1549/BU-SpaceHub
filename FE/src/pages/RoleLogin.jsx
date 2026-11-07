import { useEffect, useRef, useState } from 'react';
import { Link, Navigate, useLocation } from 'react-router';
import { ArrowLeft, ArrowRight, Eye, EyeOff, Lock, Mail, UserCog, Users } from 'lucide-react';
import Logo from '../components/Brand/Logo.jsx';
import { useAuth } from '../hooks/useAuth.js';
import { ROLES } from '../utils/constants.js';

// ต้องเขียนชื่อคลาส Tailwind ให้ครบทุกตัว (ห้ามต่อสตริง) เพื่อให้ Tailwind สร้างสไตล์ให้
const VARIANTS = {
  admin: {
    role: ROLES.ADMIN,
    badge: 'Admin',
    title: 'เข้าสู่ระบบแอดมิน',
    emailLabel: 'อีเมลผู้ดูแลระบบ (Admin)',
    wrongRole: 'บัญชีนี้ไม่ใช่แอดมิน กรุณาใช้ช่องทางเข้าสู่ระบบที่ถูกต้อง',
    Icon: UserCog,
    circle: 'bg-indigo-100 text-indigo-600',
    badgeCls: 'bg-indigo-200 text-indigo-800',
    button: 'bg-indigo-600 hover:bg-indigo-700 focus-visible:outline-indigo-600',
    ring: 'focus-within:ring-indigo-300',
    link: 'text-indigo-700',
  },
  staff: {
    role: ROLES.STAFF,
    badge: 'Staff',
    title: 'เข้าสู่ระบบสตาฟ',
    emailLabel: 'อีเมลเจ้าหน้าที่ (Staff)',
    wrongRole: 'บัญชีนี้ไม่ใช่สตาฟ กรุณาใช้ช่องทางเข้าสู่ระบบที่ถูกต้อง',
    Icon: Users,
    circle: 'bg-emerald-100 text-emerald-600',
    badgeCls: 'bg-emerald-200 text-emerald-800',
    button: 'bg-emerald-700 hover:bg-emerald-800 focus-visible:outline-emerald-700',
    ring: 'focus-within:ring-emerald-300',
    link: 'text-emerald-700',
  },
};

const fieldCls =
  'flex items-center gap-3 rounded-xl border border-slate-200 bg-white/90 px-4 py-3 focus-within:ring-2';

export default function RoleLogin({ variant }) {
  const v = VARIANTS[variant];
  const { isAuthenticated, profile, authError, loginWithPassword, logout } = useAuth();
  const location = useLocation();
  const attempted = useRef(false); // true เฉพาะหลังผู้ใช้กดปุ่มล็อกอินในหน้านี้

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');
  const [showForgot, setShowForgot] = useState(false);

  // ล็อกอินสำเร็จแต่ role ไม่ตรงกับพอร์ทัลนี้ → ออกจากระบบและแจ้งเตือน
  useEffect(() => {
    if (attempted.current && isAuthenticated && profile.role !== v.role) {
      attempted.current = false;
      setSubmitting(false);
      setError(v.wrongRole);
      logout();
    }
  }, [isAuthenticated, profile, v, logout]);

  // BE ปฏิเสธ (เช่น บัญชีถูกระงับ/ไม่ได้ลงทะเบียน)
  useEffect(() => {
    if (attempted.current && authError) {
      attempted.current = false;
      setSubmitting(false);
      setError(authError);
    }
  }, [authError]);

  if (isAuthenticated && profile.role === v.role) {
    return <Navigate to={location.state?.from || '/'} replace />;
  }

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setSubmitting(true);
    attempted.current = true;
    try {
      await loginWithPassword(email.trim().toLowerCase(), password);
      // สำเร็จ: ปล่อยให้ AuthContext โหลดโปรไฟล์แล้วหน้านี้จะ redirect เอง
    } catch (err) {
      attempted.current = false;
      setSubmitting(false);
      setError(
        err.message === 'Invalid login credentials' ? 'อีเมลหรือรหัสผ่านไม่ถูกต้อง' : err.message
      );
    }
  };

  return (
    <div className="mx-auto flex min-h-screen w-full max-w-md flex-col px-5 py-6">
      <div>
        <Link
          to="/login"
          className="inline-flex items-center gap-2 rounded-full bg-white/80 px-4 py-2 text-sm text-slate-600 shadow-sm ring-1 ring-slate-200 transition hover:bg-white focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-slate-500"
        >
          <ArrowLeft className="h-4 w-4" aria-hidden="true" />
          กลับไปหน้าล็อกอิน
        </Link>
      </div>

      <div className="mt-8 flex justify-center">
        <Logo />
      </div>
      <p className="mt-2 text-center text-[11px] uppercase tracking-[0.25em] text-slate-500">
        Book · Print · Borrow · Repair
      </p>

      <section className="glass-card fade-up mt-8 p-6 sm:p-8" aria-labelledby="role-title">
        <div className="flex flex-col items-center text-center">
          <span className={`grid h-16 w-16 place-items-center rounded-full ${v.circle}`}>
            <v.Icon className="h-7 w-7" aria-hidden="true" />
          </span>
          <span className={`-mt-2 rounded-full px-3 py-0.5 text-xs font-semibold ${v.badgeCls}`}>
            {v.badge}
          </span>
          <h1 id="role-title" className="mt-3 text-2xl font-bold text-slate-800">
            {v.title}
          </h1>
          <p className="mt-1 text-sm text-slate-500">กรุณากรอกรหัสผ่านเพื่อยืนยันตัวตน</p>
        </div>

        {error && (
          <p role="alert" className="mt-5 rounded-xl bg-rose-50 px-4 py-3 text-sm text-rose-700">
            {error}
          </p>
        )}

        <form onSubmit={handleSubmit} className="mt-6 space-y-4">
          <label className="block">
            <span className="sr-only">{v.emailLabel}</span>
            <span className={`${fieldCls} ${v.ring}`}>
              <Mail className="h-5 w-5 shrink-0 text-slate-500" aria-hidden="true" />
              <input
                type="email"
                required
                autoComplete="username"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder={v.emailLabel}
                className="w-full bg-transparent outline-none placeholder:text-slate-500"
              />
            </span>
          </label>

          <label className="block">
            <span className="sr-only">รหัสผ่าน</span>
            <span className={`${fieldCls} ${v.ring}`}>
              <Lock className="h-5 w-5 shrink-0 text-slate-500" aria-hidden="true" />
              <input
                type={showPassword ? 'text' : 'password'}
                required
                autoComplete="current-password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="รหัสผ่าน"
                className="w-full bg-transparent outline-none placeholder:text-slate-500"
              />
              <button
                type="button"
                onClick={() => setShowPassword((s) => !s)}
                aria-label={showPassword ? 'ซ่อนรหัสผ่าน' : 'แสดงรหัสผ่าน'}
                aria-pressed={showPassword}
                className="text-slate-500 hover:text-slate-700"
              >
                {showPassword ? (
                  <EyeOff className="h-5 w-5" aria-hidden="true" />
                ) : (
                  <Eye className="h-5 w-5" aria-hidden="true" />
                )}
              </button>
            </span>
          </label>

          <button
            type="submit"
            disabled={submitting}
            className={`flex w-full items-center justify-center gap-2 rounded-xl px-4 py-3 font-semibold text-white transition focus-visible:outline-2 focus-visible:outline-offset-2 disabled:opacity-60 ${v.button}`}
          >
            {submitting ? 'กำลังเข้าสู่ระบบ...' : 'เข้าสู่ระบบ'}
            {!submitting && <ArrowRight className="h-4 w-4" aria-hidden="true" />}
          </button>
        </form>

        <div className="mt-4 text-center">
          <button
            type="button"
            onClick={() => setShowForgot((s) => !s)}
            className={`text-sm underline underline-offset-2 ${v.link}`}
          >
            ลืมรหัสผ่าน?
          </button>
          {showForgot && (
            <p className="mt-2 text-xs text-slate-500">
              กรุณาติดต่อผู้ดูแลระบบของมหาวิทยาลัยเพื่อรีเซ็ตรหัสผ่าน
            </p>
          )}
        </div>
      </section>

      <p className="mt-auto pt-8 text-center text-xs text-slate-500">
        BU SpaceHub
        <br />
        Bangkok University
      </p>
    </div>
  );
}