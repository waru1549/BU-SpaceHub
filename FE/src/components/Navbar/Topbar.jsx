import { LogOut, Menu } from 'lucide-react';
import { ROLE_BADGE, ROLE_LABEL } from '../../utils/navigation.js';

const focusRing =
  'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-500';

export default function Topbar({ profile, menuOpen, onMenuClick, onLogout }) {
  const initial = profile.fullName?.trim()?.[0] ?? '?';

  return (
    <header className="sticky top-0 z-20 border-b border-slate-200 bg-white/80 backdrop-blur">
      <div className="flex items-center gap-3 px-4 py-3 sm:px-6">
        <button
          type="button"
          onClick={onMenuClick}
          aria-label="เปิดเมนู"
          aria-expanded={menuOpen}
          aria-controls="app-sidebar"
          className={`rounded-lg p-2 text-slate-700 hover:bg-slate-100 lg:hidden ${focusRing}`}
        >
          <Menu className="h-6 w-6" aria-hidden="true" />
        </button>

        <p className="hidden text-sm text-slate-600 sm:block">
          สวัสดี, <span className="font-semibold text-slate-800">{profile.fullName}</span>
        </p>

        <div className="ml-auto flex items-center gap-3">
          <span className={`rounded-full px-3 py-1 text-xs font-semibold ${ROLE_BADGE[profile.role]}`}>
            {ROLE_LABEL[profile.role]}
          </span>
          <span
            aria-hidden="true"
            className="grid h-9 w-9 place-items-center rounded-full bg-indigo-100 text-sm font-semibold text-indigo-800"
          >
            {initial}
          </span>
          <button
            type="button"
            onClick={onLogout}
            aria-label="ออกจากระบบ"
            className={`inline-flex items-center gap-2 rounded-lg border border-slate-300 px-3 py-2 text-sm text-slate-700 hover:bg-slate-100 ${focusRing}`}
          >
            <LogOut className="h-4 w-4" aria-hidden="true" />
            <span className="hidden sm:inline">ออกจากระบบ</span>
          </button>
        </div>
      </div>
    </header>
  );
}