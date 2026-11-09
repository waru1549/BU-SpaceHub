import { useEffect, useId, useRef } from 'react';
import { X } from 'lucide-react';

const FOCUSABLE =
  'a[href], button:not([disabled]), textarea:not([disabled]), input:not([disabled]), select:not([disabled]), [tabindex]:not([tabindex="-1"])';

const focusRing =
  'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-500';

/**
 * หน้าต่างโต้ตอบที่เข้าถึงได้: โฟกัสเข้าไปข้างใน (หรือองค์ประกอบที่มี data-autofocus),
 * Tab วนอยู่ในหน้าต่าง, Esc ปิด, ล็อก scroll พื้นหลัง และคืนโฟกัสให้ปุ่มที่เปิดเมื่อปิด
 * บนจอเล็กแสดงเป็น bottom sheet
 */
export default function Modal({ open, title, onClose, children, footer, busy = false }) {
  const titleId = useId();
  const panelRef = useRef(null);
  const returnRef = useRef(null);
  const busyRef = useRef(busy);
  const closeRef = useRef(onClose);

  // เก็บค่าล่าสุดไว้ให้ตัวจัดการ keydown โดยไม่ต้องตั้ง effect ใหม่ (ไม่รีเซ็ตโฟกัส)
  useEffect(() => {
    busyRef.current = busy;
    closeRef.current = onClose;
  });

  useEffect(() => {
    if (!open) return undefined;
    const panel = panelRef.current;
    returnRef.current = document.activeElement;

    const initial = panel.querySelector('[data-autofocus]') ?? panel.querySelector(FOCUSABLE);
    initial?.focus();
    document.body.style.overflow = 'hidden';

    const onKey = (e) => {
      if (e.key === 'Escape') {
        if (!busyRef.current) closeRef.current();
        return;
      }
      if (e.key !== 'Tab') return;
      const items = [...panel.querySelectorAll(FOCUSABLE)];
      if (items.length === 0) return;
      const first = items[0];
      const last = items[items.length - 1];
      if (e.shiftKey && document.activeElement === first) {
        e.preventDefault();
        last.focus();
      } else if (!e.shiftKey && document.activeElement === last) {
        e.preventDefault();
        first.focus();
      }
    };

    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('keydown', onKey);
      document.body.style.overflow = '';
      returnRef.current?.focus?.();
    };
  }, [open]);

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-50 grid place-items-end sm:place-items-center">
      <div
        className="absolute inset-0 bg-slate-900/50"
        onClick={() => {
          if (!busy) onClose();
        }}
        aria-hidden="true"
      />
      <div
        ref={panelRef}
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        className="relative z-10 flex max-h-[90vh] w-full flex-col rounded-t-2xl bg-white shadow-xl sm:max-w-lg sm:rounded-2xl"
      >
        <div className="flex items-start justify-between gap-4 border-b border-slate-200 px-5 py-4">
          <h2 id={titleId} className="text-lg font-semibold text-slate-900">
            {title}
          </h2>
          <button
            type="button"
            onClick={onClose}
            disabled={busy}
            aria-label="ปิดหน้าต่าง"
            className={`rounded-lg p-1.5 text-slate-600 hover:bg-slate-100 disabled:opacity-40 ${focusRing}`}
          >
            <X className="h-5 w-5" aria-hidden="true" />
          </button>
        </div>

        <div className="overflow-y-auto px-5 py-4">{children}</div>

        {footer && (
          <div className="flex flex-wrap justify-end gap-2 border-t border-slate-200 px-5 py-4">
            {footer}
          </div>
        )}
      </div>
    </div>
  );
}