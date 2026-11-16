import { useEffect, useRef, useState } from 'react';
import { useLocation } from 'react-router';
import { Bot, MessageCircle, X } from 'lucide-react';
import ChatPanel from './ChatPanel.jsx';
import { useChat } from '../../hooks/useChat.js';

// ปุ่มลอยมุมขวาล่างทุกหน้า (ซ่อนในหน้า /chat) | บทสนทนายังอยู่เมื่อปิด/เปิดหรือเปลี่ยนหน้า
export default function ChatWidget() {
  const { pathname } = useLocation();
  const chat = useChat();
  const [open, setOpen] = useState(false);
  const buttonRef = useRef(null);

  useEffect(() => {
    if (!open) return undefined;
    const onKey = (e) => {
      if (e.key === 'Escape') {
        setOpen(false);
        buttonRef.current?.focus();
      }
    };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [open]);

  if (pathname === '/chat') return null;

  return (
    <>
      {open && (
        <section
          role="dialog"
          aria-label="ผู้ช่วย AI น้องสเปซ"
          className="fixed inset-x-3 top-16 bottom-20 z-50 flex flex-col overflow-hidden rounded-2xl border border-slate-200 bg-slate-50 shadow-2xl sm:inset-x-auto sm:top-auto sm:right-4 sm:h-[min(36rem,calc(100dvh-7rem))] sm:w-96"
        >
          <header className="flex items-center justify-between bg-indigo-700 px-4 py-3 text-white">
            <h2 className="flex items-center gap-2 text-sm font-semibold">
              <Bot className="h-5 w-5" aria-hidden="true" />
              น้องสเปซ ผู้ช่วย AI
            </h2>
            <button
              type="button"
              onClick={() => {
                setOpen(false);
                buttonRef.current?.focus();
              }}
              aria-label="ปิดแผงแชต"
              className="rounded-md p-1 hover:bg-indigo-800 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-white"
            >
              <X className="h-5 w-5" aria-hidden="true" />
            </button>
          </header>
          <div className="min-h-0 flex-1">
            <ChatPanel chat={chat} autoFocus />
          </div>
        </section>
      )}

      <button
        ref={buttonRef}
        type="button"
        onClick={() => setOpen((v) => !v)}
        aria-expanded={open}
        aria-label={open ? 'ปิดผู้ช่วย AI' : 'เปิดผู้ช่วย AI'}
        className="fixed right-4 bottom-4 z-50 grid h-14 w-14 place-items-center rounded-full bg-indigo-700 text-white shadow-lg hover:bg-indigo-800 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
      >
        {open ? <X className="h-6 w-6" aria-hidden="true" /> : <MessageCircle className="h-6 w-6" aria-hidden="true" />}
      </button>
    </>
  );
}
