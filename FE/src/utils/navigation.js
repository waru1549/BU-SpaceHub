import {
  Box,
  Building2,
  CalendarDays,
  ClipboardCheck,
  FileText,
  LayoutDashboard,
  PackageCheck,
  User,
  Users,
  Wrench,
} from 'lucide-react';
import { ROLES } from './constants.js';

const ALL = [ROLES.USER, ROLES.STAFF, ROLES.ADMIN];
const STAFF_UP = [ROLES.STAFF, ROLES.ADMIN];

// ตารางเมนูตัวเดียว: เพิ่ม/ซ่อนเมนูตาม role ที่นี่ที่เดียว
// (การกั้นสิทธิ์จริงอยู่ที่ ProtectedRoute ฝั่ง FE และ requireRole ฝั่ง BE)
export const NAV_SECTIONS = [
  {
    title: 'เมนูหลัก',
    roles: ALL,
    items: [{ to: '/', label: 'แดชบอร์ด', icon: LayoutDashboard, end: true }],
  },
  {
    title: 'บริการ',
    roles: ALL,
    items: [
      { to: '/rooms', label: 'จองห้อง', icon: CalendarDays, tone: 'text-indigo-600' },
      { to: '/printers', label: 'เครื่องพิมพ์ 3D', icon: Box, tone: 'text-emerald-700' },
      { to: '/equipment', label: 'ยืม-คืนอุปกรณ์', icon: PackageCheck, tone: 'text-amber-700' },
      { to: '/maintenance', label: 'แจ้งซ่อม', icon: Wrench, tone: 'text-sky-700' },
    ],
  },
  {
    title: 'สำหรับสตาฟ',
    roles: STAFF_UP,
    items: [{ to: '/staff/requests', label: 'คำขอรออนุมัติ', icon: ClipboardCheck }],
  },
  {
    title: 'ผู้ดูแลระบบ',
    roles: [ROLES.ADMIN],
    items: [
      { to: '/admin/users', label: 'จัดการผู้ใช้', icon: Users },
      { to: '/admin/resources', label: 'จัดการทรัพยากร', icon: Building2 },
      { to: '/admin/reports', label: 'รายงานระบบ', icon: FileText },
    ],
  },
  {
    title: 'บัญชี',
    roles: ALL,
    items: [{ to: '/profile', label: 'โปรไฟล์', icon: User }],
  },
];

export const getNavForRole = (role) => NAV_SECTIONS.filter((s) => s.roles.includes(role));

export const ROLE_LABEL = { USER: 'นักศึกษา', STAFF: 'สตาฟ', ADMIN: 'แอดมิน' };

export const ROLE_BADGE = {
  USER: 'bg-slate-100 text-slate-700',
  STAFF: 'bg-emerald-100 text-emerald-800',
  ADMIN: 'bg-indigo-100 text-indigo-800',
};