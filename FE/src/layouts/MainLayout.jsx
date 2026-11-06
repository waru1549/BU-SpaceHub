import { Link, Outlet } from 'react-router';
import { APP_NAME } from '../utils/constants.js';
import { useAuth } from '../hooks/useAuth.js';

export default function MainLayout() {
  const { profile, logout } = useAuth();

  return (
    <div className="min-h-screen bg-slate-50 text-slate-800">
      <header className="border-b border-slate-200 bg-white">
        <div className="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-3 px-4 py-3">
          <Link to="/" className="text-lg font-bold">
            {APP_NAME}
          </Link>
          <nav className="flex flex-wrap items-center gap-4 text-sm">
            <Link to="/" className="hover:text-indigo-600">
              Dashboard
            </Link>
            <Link to="/profile" className="hover:text-indigo-600">
              Profile
            </Link>
            {profile && (
              <span className="rounded-full bg-indigo-50 px-3 py-1 text-indigo-700">
                {profile.fullName} · {profile.role}
              </span>
            )}
            <button
              type="button"
              onClick={logout}
              className="rounded-lg border border-slate-300 px-3 py-1 hover:bg-slate-100"
            >
              Logout
            </button>
          </nav>
        </div>
      </header>
      <main className="mx-auto max-w-6xl px-4 py-6">
        <Outlet />
      </main>
    </div>
  );
}