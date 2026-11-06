import { Link, Outlet } from 'react-router';
import { APP_NAME } from '../utils/constants.js';

export default function MainLayout() {
  return (
    <div className="min-h-screen bg-slate-50 text-slate-800">
      <header className="border-b border-slate-200 bg-white">
        <div className="mx-auto flex max-w-6xl items-center justify-between px-4 py-3">
          <Link to="/" className="text-lg font-bold">
            {APP_NAME}
          </Link>
          <nav className="flex gap-4 text-sm">
            <Link to="/" className="hover:text-indigo-600">
              Dashboard
            </Link>
            <Link to="/login" className="hover:text-indigo-600">
              Login
            </Link>
          </nav>
        </div>
      </header>
      <main className="mx-auto max-w-6xl px-4 py-6">
        <Outlet />
      </main>
    </div>
  );
}