import { Link } from 'react-router';

export default function NotFound() {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center gap-3 bg-slate-50">
      <h1 className="text-4xl font-bold">404</h1>
      <p className="text-slate-600">ไม่พบหน้าที่ต้องการ</p>
      <Link to="/" className="text-indigo-600 hover:underline">
        กลับหน้าแรก
      </Link>
    </div>
  );
}