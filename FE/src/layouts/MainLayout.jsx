import { useEffect, useState } from 'react';
import { Outlet, useLocation } from 'react-router';
import Sidebar from '../components/Sidebar/Sidebar.jsx';
import Topbar from '../components/Navbar/Topbar.jsx';
import { useAuth } from '../hooks/useAuth.js';

export default function MainLayout() {
  const { profile, logout } = useAuth();
  const [open, setOpen] = useState(false); // สถานะ drawer บนจอ < 1024px
  const location = useLocation();

  // ปิด drawer เมื่อเปลี่ยนหน้า (รวมถึงกดปุ่มย้อนกลับของเบราว์เซอร์)
  useEffect(() => {
    setOpen(false);
  }, [location.pathname]);

  // ปิด drawer เมื่อขยายจอถึงขนาดเดสก์ท็อป (กัน scroll ถูกล็อกค้าง)
  useEffect(() => {
    const mq = window.matchMedia('(min-width: 1024px)');
    const onChange = (e) => {
      if (e.matches) setOpen(false);
    };
    mq.addEventListener('change', onChange);
    return () => mq.removeEventListener('change', onChange);
  }, []);

  // drawer เปิดอยู่: กด Esc เพื่อปิด และล็อก scroll ของหน้า
  useEffect(() => {
    if (!open) return undefined;
    const onKey = (e) => {
      if (e.key === 'Escape') setOpen(false);
    };
    document.addEventListener('keydown', onKey);
    document.body.style.overflow = 'hidden';
    return () => {
      document.removeEventListener('keydown', onKey);
      document.body.style.overflow = '';
    };
  }, [open]);

  return (
    <div className="min-h-screen bg-slate-50 text-slate-800">
      {open && (
        <div
          className="fixed inset-0 z-30 bg-slate-900/40 lg:hidden"
          onClick={() => setOpen(false)}
          aria-hidden="true"
        />
      )}

      {/* ปิดอยู่บนจอเล็กจะเป็น invisible เพื่อไม่ให้ Tab ไปโฟกัสลิงก์ที่มองไม่เห็น */}
      <aside
        id="app-sidebar"
        className={`fixed inset-y-0 left-0 z-40 w-72 border-r border-slate-200 bg-white transition-[transform,visibility] duration-200 motion-reduce:transition-none lg:visible lg:w-64 lg:translate-x-0 ${
          open ? 'visible translate-x-0' : 'invisible -translate-x-full'
        }`}
      >
        <Sidebar role={profile.role} onNavigate={() => setOpen(false)} onClose={() => setOpen(false)} />
      </aside>

      <div className="lg:pl-64">
        <Topbar
          profile={profile}
          menuOpen={open}
          onMenuClick={() => setOpen(true)}
          onLogout={logout}
        />
        <main className="mx-auto max-w-6xl px-4 py-6 sm:px-6">
          <Outlet />
        </main>
      </div>
    </div>
  );
}