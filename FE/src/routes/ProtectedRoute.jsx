import { Link, Navigate, Outlet, useLocation } from 'react-router';
import { useAuth } from '../hooks/useAuth.js';

function Forbidden() {
  return (
    <div className="py-16 text-center">
      <h1 className="text-3xl font-bold">403</h1>
      <p className="mt-2 text-slate-600">คุณไม่มีสิทธิ์เข้าถึงหน้านี้</p>
      <Link to="/" className="mt-4 inline-block text-indigo-600 hover:underline">
        กลับหน้าแรก
      </Link>
    </div>
  );
}

// ใช้: <Route element={<ProtectedRoute />}> หรือ <ProtectedRoute roles={['STAFF','ADMIN']} />
export default function ProtectedRoute({ roles }) {
  const { loading, isAuthenticated, profile } = useAuth();
  const location = useLocation();

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center text-slate-500">
        กำลังตรวจสอบสิทธิ์...
      </div>
    );
  }
  if (!isAuthenticated) {
    return <Navigate to="/login" replace state={{ from: location.pathname }} />;
  }
  if (roles && !roles.includes(profile.role)) return <Forbidden />;
  return <Outlet />;
}