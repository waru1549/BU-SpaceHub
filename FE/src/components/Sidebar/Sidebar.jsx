import { NavLink } from 'react-router';
import { X } from 'lucide-react';
import Logo from '../Brand/Logo.jsx';
import { getNavForRole } from '../../utils/navigation.js';

const focusRing =
  'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-500';

export default function Sidebar({ role, onNavigate, onClose }) {
  const sections = getNavForRole(role);

  return (
    <div className="flex h-full flex-col">
      <div className="flex items-center justify-between px-5 py-5">
        <Logo />
        {/* ปุ่มปิด แสดงเฉพาะตอนเป็น drawer (จอเล็ก) */}
        <button
          type="button"
          onClick={onClose}
          aria-label="ปิดเมนู"
          className={`rounded-lg p-2 text-slate-600 hover:bg-slate-100 lg:hidden ${focusRing}`}
        >
          <X className="h-5 w-5" aria-hidden="true" />
        </button>
      </div>

      <nav aria-label="เมนูหลัก" className="flex-1 space-y-6 overflow-y-auto px-3 pb-6">
        {sections.map((section) => (
          <div key={section.title}>
            <p className="px-3 text-xs font-semibold text-slate-500">{section.title}</p>
            <ul className="mt-2 space-y-1">
              {section.items.map(({ to, label, icon: Icon, end, tone }) => (
                <li key={to}>
                  <NavLink
                    to={to}
                    end={end}
                    onClick={onNavigate}
                    className={({ isActive }) =>
                      `flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm transition ${focusRing} ${
                        isActive
                          ? 'bg-indigo-50 font-semibold text-indigo-800'
                          : 'text-slate-700 hover:bg-slate-100'
                      }`
                    }
                  >
                    <Icon className={`h-5 w-5 shrink-0 ${tone ?? 'text-slate-500'}`} aria-hidden="true" />
                    {label}
                  </NavLink>
                </li>
              ))}
            </ul>
          </div>
        ))}
      </nav>

      <p className="border-t border-slate-200 px-5 py-4 text-xs text-slate-500">Bangkok University</p>
    </div>
  );
}