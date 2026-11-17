import { Suspense, lazy } from 'react';
import { Routes, Route } from 'react-router';
import ProtectedRoute from './ProtectedRoute.jsx';
import AuthLayout from '../layouts/AuthLayout.jsx';
import MainLayout from '../layouts/MainLayout.jsx';
import ChatWidget from '../components/Chat/ChatWidget.jsx';
import { ROLES } from '../utils/constants.js';

// แยกโค้ดรายหน้า (code splitting): โหลดเมื่อเข้าหน้านั้น ลดขนาดไฟล์แรกที่ต้องโหลด
// เพิ่มหน้าใหม่: สร้างไฟล์หน้า แล้วเพิ่ม lazy() + <Route> อย่างละ 1 บรรทัด
const Login = lazy(() => import('../pages/Login.jsx'));
const RoleLogin = lazy(() => import('../pages/RoleLogin.jsx'));
const Dashboard = lazy(() => import('../pages/Dashboard.jsx'));
const Profile = lazy(() => import('../pages/Profile.jsx'));
const Rooms = lazy(() => import('../pages/Rooms.jsx'));
const Printers = lazy(() => import('../pages/Printers.jsx'));
const Equipment = lazy(() => import('../pages/Equipment.jsx'));
const Maintenance = lazy(() => import('../pages/Maintenance.jsx'));
const StaffRequests = lazy(() => import('../pages/StaffRequests.jsx'));
// const AdminUsers = lazy(() => import('../pages/AdminUsers.jsx'));
const AdminResources = lazy(() => import('../pages/AdminResources.jsx'));
const AdminResourceSchedules = lazy(() => import("../pages/AdminResourceSchedules.jsx"));
const Chat = lazy(() => import('../pages/Chat.jsx'));
const NotFound = lazy(() => import('../pages/NotFound.jsx'));

function PageFallback() {
  return (
    <div role="status" className="grid min-h-[40vh] place-items-center text-sm text-slate-600">
      กำลังโหลด…
    </div>
  );
}

export default function AppRoutes() {
  return (
    <>
      <Suspense fallback={<PageFallback />}>
        <Routes>
          <Route element={<AuthLayout />}>
            <Route path="/login" element={<Login />} />
            <Route path="/login/admin" element={<RoleLogin variant="admin" />} />
            <Route path="/login/staff" element={<RoleLogin variant="staff" />} />
          </Route>

          {/* AI Chat: สาธารณะ ไม่ต้องล็อกอิน */}
          <Route path="/chat" element={<Chat />} />

          <Route element={<ProtectedRoute />}>
            <Route element={<MainLayout />}>
              <Route path="/" element={<Dashboard />} />
              <Route path="/profile" element={<Profile />} />

              <Route path="/rooms" element={<Rooms />} />
              <Route path="/printers" element={<Printers />} />
              <Route path="/equipment" element={<Equipment />} />
              <Route path="/maintenance" element={<Maintenance />} />

              <Route element={<ProtectedRoute roles={[ROLES.STAFF, ROLES.ADMIN]} />}>
                <Route path="/staff/requests" element={<StaffRequests />} />
              </Route>

              <Route element={<ProtectedRoute roles={[ROLES.ADMIN]} />}>
                {/* <Route path="/admin/users" element={<AdminUsers />} /> */}
                <Route path="/admin/resources/:id/schedules" element={<AdminResourceSchedules />} />
                <Route path="/admin/resources" element={<AdminResources />} />
              </Route>
            </Route>
          </Route>

          <Route path="*" element={<NotFound />} />
        </Routes>
      </Suspense>

      {/* ปุ่มลอยผู้ช่วย AI ทุกหน้า (ซ่อนเองในหน้า /chat) */}
      <ChatWidget />
    </>
  );
}
