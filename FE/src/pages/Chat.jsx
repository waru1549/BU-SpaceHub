import { Link } from 'react-router';
import { ArrowLeft, LogIn } from 'lucide-react';
import Logo from '../components/Brand/Logo.jsx';
import ChatPanel from '../components/Chat/ChatPanel.jsx';
import { useChat } from '../hooks/useChat.js';
import { useAuth } from '../hooks/useAuth.js';

const linkClass =
  'inline-flex items-center gap-2 rounded-full border border-slate-300 bg-white px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-100 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600';

// หน้าแชตเต็มจอ: เปิดได้โดยไม่ต้องล็อกอิน
export default function Chat() {
  const chat = useChat();
  const { isAuthenticated } = useAuth();

  return (
    <div className="flex h-dvh flex-col bg-slate-50">
      <header className="flex items-center justify-between gap-3 border-b border-slate-200 bg-white px-4 py-3 sm:px-6">
        <Logo />
        {isAuthenticated ? (
          <Link to="/" className={linkClass}>
            <ArrowLeft className="h-4 w-4" aria-hidden="true" />
            กลับหน้าหลัก
          </Link>
        ) : (
          <Link to="/login" className={linkClass}>
            <LogIn className="h-4 w-4" aria-hidden="true" />
            เข้าสู่ระบบ
          </Link>
        )}
      </header>
      <main className="mx-auto flex min-h-0 w-full max-w-3xl flex-1 flex-col px-0 sm:px-4 sm:py-4">
        <h1 className="sr-only">ผู้ช่วย AI น้องสเปซ</h1>
        <div className="flex min-h-0 flex-1 flex-col overflow-hidden border-slate-200 bg-slate-50 sm:rounded-2xl sm:border sm:shadow-sm">
          <ChatPanel chat={chat} autoFocus />
        </div>
      </main>
    </div>
  );
}
