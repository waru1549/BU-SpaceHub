import { AlertCircle, CheckCircle2, X } from 'lucide-react';

const STYLE = {
  success: { box: 'border-emerald-200 bg-emerald-50 text-emerald-900', Icon: CheckCircle2 },
  error: { box: 'border-red-200 bg-red-50 text-red-900', Icon: AlertCircle },
};

// แถบแจ้งผลการทำรายการ: success ใช้ role=status (อ่านแบบสุภาพ), error ใช้ role=alert
export default function Notice({ type = 'success', children, onDismiss }) {
  const { box, Icon } = STYLE[type];
  return (
    <div
      role={type === 'error' ? 'alert' : 'status'}
      className={`flex items-start gap-3 rounded-xl border px-4 py-3 text-sm ${box}`}
    >
      <Icon className="mt-0.5 h-5 w-5 shrink-0" aria-hidden="true" />
      <p className="flex-1">{children}</p>
      {onDismiss && (
        <button
          type="button"
          onClick={onDismiss}
          aria-label="ปิดข้อความ"
          className="rounded p-0.5 hover:bg-black/5 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-500"
        >
          <X className="h-4 w-4" aria-hidden="true" />
        </button>
      )}
    </div>
  );
}