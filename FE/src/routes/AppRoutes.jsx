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
import StaffRequests from '../pages/StaffRequests.jsx';
import NotFound from '../pages/NotFound.jsx';
import { ROLES } from '../utils/constants.js';

export default function AppRoutes() {
  return (
    <Routes>
      <Route element={<AuthLayout />}>
        <Route path="/login" element={<Login />} />
        <Route path="/login/admin" element={<RoleLogin variant="admin" />} />
        <Route path="/login/staff" element={<RoleLogin variant="staff" />} />
      </Route>

      <Route element={<ProtectedRoute />}>
        <Route element={<MainLayout />}>
          <Route path="/" element={<Dashboard />} />
          <Route path="/profile" element={<Profile />} />

          {/* โมดูลบริการ: หน้าชั่วคราว จะแทนที่ด้วยโมดูลจริงใน Step 8-10 */}
          <Route path="/rooms" element={<Rooms />} />
          <Route path="/printers" element={<Printers />} />
          <Route path="/equipment" element={<Equipment />} />
          <Route path="/maintenance" element={<ComingSoon title="แจ้งซ่อม" step="Step 10" />} />

          <Route element={<ProtectedRoute roles={[ROLES.STAFF, ROLES.ADMIN]} />}>
            <Route path="/staff/requests" element={<StaffRequests />} />
          </Route>

          <Route element={<ProtectedRoute roles={[ROLES.ADMIN]} />}>
            <Route path="/admin/users" element={<ComingSoon title="จัดการผู้ใช้" step="Step 8-10" />} />
            <Route path="/admin/resources" element={<ComingSoon title="จัดการทรัพยากร" step="Step 8-10" />} />
            <Route path="/admin/reports" element={<ComingSoon title="รายงานระบบ" step="Step 7B-2" />} />
          </Route>
        </Route>
      </Route>

      <Route path="*" element={<NotFound />} />
    </Routes>
  );
}