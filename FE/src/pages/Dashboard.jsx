import { useEffect, useState } from 'react';
import { API_URL } from '../utils/constants.js';

const STATUS_STYLE = {
  checking: 'bg-slate-100 text-slate-600',
  online: 'bg-emerald-100 text-emerald-700',
  error: 'bg-amber-100 text-amber-700',
  offline: 'bg-rose-100 text-rose-700',
};

export default function Dashboard() {
  const [apiStatus, setApiStatus] = useState('checking');

  useEffect(() => {
    fetch(`${API_URL}/health`)
      .then((res) => res.json())
      .then((body) => setApiStatus(body.success ? 'online' : 'error'))
      .catch(() => setApiStatus('offline'));
  }, []);

  return (
    <section className="rounded-xl border border-slate-200 bg-white p-6 shadow-sm">
      <h1 className="text-2xl font-bold">Dashboard</h1>
      <p className="mt-2 text-slate-600">หน้าชั่วคราวของ Step 6A</p>
      <p className="mt-4 text-sm">
        สถานะ API:{' '}
        <span className={`rounded-full px-3 py-1 font-medium ${STATUS_STYLE[apiStatus]}`}>
          {apiStatus}
        </span>
      </p>
    </section>
  );
}