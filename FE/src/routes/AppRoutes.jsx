import { Routes, Route } from 'react-router';
import ProtectedRoute from './ProtectedRoute.jsx';
import AuthLayout from '../layouts/AuthLayout.jsx';
import MainLayout from '../layouts/MainLayout.jsx';
import Login from '../pages/Login.jsx';
import RoleLogin from '../pages/RoleLogin.jsx';
import Dashboard from '../pages/Dashboard.jsx';
import Profile from '../pages/Profile.jsx';
import ComingSoon from '../pages/ComingSoon.jsx';
import Rooms from '../pages/Rooms.jsx';
import Printers from '../pages/Printers.jsx';
import Equipment from '../pages/Equipment.jsx';
import Maintenance from '../pages/Maintenance.jsx';
import StaffRequests from '../pages/StaffRequests.jsx';
import Chat from '../pages/Chat.jsx';
import ChatWidget from '../components/Chat/ChatWidget.jsx';
import NotFound from '../pages/NotFound.jsx';
import { ROLES } from '../utils/constants.js';

export default function AppRoutes() {
  return (
    <>
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
              <Route path="/admin/users" element={<ComingSoon title="จัดการผู้ใช้" step="Admin CRUD" />} />
              <Route path="/admin/resources" element={<ComingSoon title="จัดการทรัพยากร" step="Admin CRUD" />} />
            </Route>
          </Route>
        </Route>

        <Route path="*" element={<NotFound />} />
      </Routes>

      {/* ปุ่มลอยผู้ช่วย AI ทุกหน้า (ซ่อนเองในหน้า /chat) */}
      <ChatWidget />
    </>
  );
}
