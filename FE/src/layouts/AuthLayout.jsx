import { Outlet } from 'react-router';
import campusBg from '../assets/campus-bg.webp';

// โครงพื้นหลังที่ใช้ร่วมกันทั้ง 3 หน้า Login
export default function AuthLayout() {
  return (
    <div className="relative min-h-screen overflow-hidden bg-slate-50">
      <div aria-hidden="true" className="auth-bg" style={{ backgroundImage: `url(${campusBg})` }} />
      <div aria-hidden="true" className="auth-overlay" />
      <div aria-hidden="true" className="auth-blob auth-blob--indigo" />
      <div aria-hidden="true" className="auth-blob auth-blob--emerald" />
      <div className="relative z-10 min-h-screen">
        <Outlet />
      </div>
    </div>
  );
}