import { useState } from 'react';
import { Navigate, useLocation } from 'react-router';
import { useAuth } from '../hooks/useAuth.js';
import { APP_NAME } from '../utils/constants.js';

export default function Login() {
  const { isAuthenticated, authError, loginWithGoogle, loginWithPassword } = useAuth();
  const location = useLocation();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [formError, setFormError] = useState('');

  if (isAuthenticated) return <Navigate to={location.state?.from || '/'} replace />;

  const handlePasswordLogin = async (e) => {
    e.preventDefault();
    setSubmitting(true);
    setFormError('');
    try {
      await loginWithPassword(email.trim().toLowerCase(), password);
    } catch (err) {
      setFormError(err.message);
    } finally {
      setSubmitting(false);
    }
  };

  const error = formError || authError;

  return (
    <div className="flex min-h-screen items-center justify-center bg-slate-100 px-4">
      <div className="w-full max-w-sm rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
        <h1 className="text-center text-2xl font-bold">{APP_NAME}</h1>
        <p className="mt-1 text-center text-sm text-slate-500">เข้าสู่ระบบ</p>

        {error && (
          <p className="mt-4 rounded-lg bg-rose-50 px-3 py-2 text-sm text-rose-700">{error}</p>
        )}

        <button
          type="button"
          onClick={loginWithGoogle}
          className="mt-5 w-full rounded-lg bg-indigo-600 px-4 py-2.5 font-medium text-white hover:bg-indigo-700"
        >
          Login with Google (@bumail.net)
        </button>

        <div className="my-5 text-center text-xs text-slate-400">หรือ Staff / Admin</div>

        <form onSubmit={handlePasswordLogin} className="space-y-3">
          <input
            type="email"
            required
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="Email"
            className="w-full rounded-lg border border-slate-300 px-3 py-2"
          />
          <input
            type="password"
            required
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            placeholder="Password"
            className="w-full rounded-lg border border-slate-300 px-3 py-2"
          />
          <button
            type="submit"
            disabled={submitting}
            className="w-full rounded-lg bg-emerald-600 px-4 py-2.5 font-medium text-white hover:bg-emerald-700 disabled:opacity-60"
          >
            {submitting ? 'กำลังเข้าสู่ระบบ...' : 'Login'}
          </button>
        </form>
      </div>
    </div>
  );
}