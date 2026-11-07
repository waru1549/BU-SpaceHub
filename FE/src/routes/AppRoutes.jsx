import { Routes, Route } from 'react-router';
import ProtectedRoute from './ProtectedRoute.jsx';
import AuthLayout from '../layouts/AuthLayout.jsx';
import MainLayout from '../layouts/MainLayout.jsx';
import Login from '../pages/Login.jsx';
import RoleLogin from '../pages/RoleLogin.jsx';
import Dashboard from '../pages/Dashboard.jsx';
import Profile from '../pages/Profile.jsx';
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

          {/* ชั่วคราว: ไว้ทดสอบการกั้นตาม role (จะลบใน Step 7B) */}
          <Route element={<ProtectedRoute roles={[ROLES.STAFF, ROLES.ADMIN]} />}>
            <Route
              path="/staff-only"
              element={
                <div className="rounded-xl bg-white p-6 shadow-sm">หน้านี้เฉพาะ Staff/Admin (ชั่วคราว)</div>
              }
            />
          </Route>
        </Route>
      </Route>

      <Route path="*" element={<NotFound />} />
    </Routes>
  );
}