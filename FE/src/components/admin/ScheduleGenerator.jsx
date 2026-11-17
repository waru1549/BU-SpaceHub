import { useState } from 'react';
import { Plus, Trash2 } from 'lucide-react';
import ErrorBanner from './ErrorBanner.jsx';
import { generateSchedules } from '../../services/adminResources.service.js';
import {
  DEFAULT_SLOTS, MAX_SLOTS_PER_DAY, WEEKDAYS, addDays, countPlanned, todayBangkok, validateGenerator,
} from '../../utils/adminResources.js';

const focusRing = 'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600';
const fieldClass = `rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 ${focusRing}`;

// ฟอร์มสร้างช่วงเวลาเป็นชุด | onDone(ข้อความ) หลังสร้างสำเร็จ
export default function ScheduleGenerator({ resourceId, onDone }) {
  const [dateFrom, setDateFrom] = useState(addDays(todayBangkok(), 1));
  const [dateTo, setDateTo] = useState(addDays(todayBangkok(), 14));
  const [weekdays, setWeekdays] = useState([1, 2, 3, 4, 5]);
  const [slots, setSlots] = useState(DEFAULT_SLOTS.map((s) => ({ ...s })));
  const [maxSlots, setMaxSlots] = useState('1');
  const [errors, setErrors] = useState([]);
  const [serverError, setServerError] = useState(null);
  const [busy, setBusy] = useState(false);

  const planned = countPlanned({ dateFrom, dateTo, weekdays, slots });

  const toggleDay = (iso) =>
    setWeekdays((w) => (w.includes(iso) ? w.filter((d) => d !== iso) : [...w, iso].sort((a, b) => a - b)));
  const setSlot = (i, key, value) => setSlots((s) => s.map((x, idx) => (idx === i ? { ...x, [key]: value } : x)));

  const submit = async (e) => {
    e.preventDefault();
    const found = validateGenerator({ dateFrom, dateTo, weekdays, slots, maxSlots });
    setErrors(found);
    setServerError(null);
    if (found.length > 0) return;
    setBusy(true);
    try {
      const out = await generateSchedules(resourceId, {
        date_from: dateFrom,
        date_to: dateTo,
        weekdays,
        slots: slots.map((s) => ({ start: s.start, end: s.end })),
        max_slots: Number(maxSlots),
      });
      onDone(out.message);
    } catch (err) {
      setServerError(err.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <form onSubmit={submit} noValidate className="space-y-4 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm" aria-labelledby="gen-title">
      <div>
        <h2 id="gen-title" className="text-lg font-semibold text-slate-800">สร้างช่วงเวลาเป็นชุด</h2>
        <p className="text-sm text-slate-600">เลือกช่วงวันที่ วันในสัปดาห์ และช่วงเวลา ระบบจะสร้างให้ทุกวันที่ตรงเงื่อนไข (ข้ามช่วงที่ซ้ำหรือซ้อนทับของเดิม)</p>
      </div>

      <div className="grid gap-4 sm:grid-cols-3">
        <div>
          <label htmlFor="gen-from" className="mb-1 block text-xs font-semibold text-slate-700">ตั้งแต่วันที่</label>
          <input id="gen-from" type="date" value={dateFrom} min={todayBangkok()} onChange={(e) => setDateFrom(e.target.value)} className={`${fieldClass} w-full`} />
        </div>
        <div>
          <label htmlFor="gen-to" className="mb-1 block text-xs font-semibold text-slate-700">ถึงวันที่</label>
          <input id="gen-to" type="date" value={dateTo} min={dateFrom || todayBangkok()} onChange={(e) => setDateTo(e.target.value)} className={`${fieldClass} w-full`} />
        </div>
        <div>
          <label htmlFor="gen-max" className="mb-1 block text-xs font-semibold text-slate-700">รับจองได้ต่อช่วง (ครั้ง)</label>
          <input id="gen-max" type="number" inputMode="numeric" min={1} max={20} value={maxSlots} onChange={(e) => setMaxSlots(e.target.value)} className={`${fieldClass} w-full`} />
        </div>
      </div>

      <fieldset>
        <legend className="mb-1 text-xs font-semibold text-slate-700">วันในสัปดาห์</legend>
        <div className="flex flex-wrap gap-2">
          {WEEKDAYS.map((d) => (
            <label
              key={d.iso}
              className={`flex cursor-pointer items-center gap-2 rounded-full border px-3 py-1.5 text-sm ${
                weekdays.includes(d.iso) ? 'border-indigo-600 bg-indigo-50 font-medium text-indigo-900' : 'border-slate-300 bg-white text-slate-700'
              }`}
            >
              <input type="checkbox" checked={weekdays.includes(d.iso)} onChange={() => toggleDay(d.iso)} className={`h-4 w-4 rounded border-slate-300 text-indigo-700 ${focusRing}`} />
              {d.label}
            </label>
          ))}
        </div>
      </fieldset>

      <fieldset>
        <legend className="mb-1 text-xs font-semibold text-slate-700">ช่วงเวลาในแต่ละวัน ({slots.length}/{MAX_SLOTS_PER_DAY})</legend>
        <ul className="space-y-2">
          {slots.map((s, i) => (
            <li key={i} className="flex flex-wrap items-center gap-2">
              <label className="sr-only" htmlFor={`gen-s-${i}`}>เวลาเริ่ม ช่วงที่ {i + 1}</label>
              <input id={`gen-s-${i}`} type="time" value={s.start} onChange={(e) => setSlot(i, 'start', e.target.value)} className={fieldClass} />
              <span aria-hidden="true" className="text-slate-600">ถึง</span>
              <label className="sr-only" htmlFor={`gen-e-${i}`}>เวลาสิ้นสุด ช่วงที่ {i + 1}</label>
              <input id={`gen-e-${i}`} type="time" value={s.end} onChange={(e) => setSlot(i, 'end', e.target.value)} className={fieldClass} />
              <button
                type="button"
                onClick={() => setSlots((arr) => arr.filter((_, idx) => idx !== i))}
                aria-label={`ลบช่วงที่ ${i + 1}`}
                className={`rounded-lg border border-slate-300 p-2 text-slate-700 hover:bg-slate-100 ${focusRing}`}
              >
                <Trash2 className="h-4 w-4" aria-hidden="true" />
              </button>
            </li>
          ))}
        </ul>
        <div className="mt-2 flex flex-wrap gap-2">
          <button
            type="button"
            disabled={slots.length >= MAX_SLOTS_PER_DAY}
            onClick={() => setSlots((arr) => [...arr, { start: '', end: '' }])}
            className={`inline-flex items-center gap-1 rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-sm font-medium text-slate-700 hover:bg-slate-100 disabled:opacity-50 ${focusRing}`}
          >
            <Plus className="h-4 w-4" aria-hidden="true" />
            เพิ่มช่วงเวลา
          </button>
          <button
            type="button"
            onClick={() => setSlots(DEFAULT_SLOTS.map((s) => ({ ...s })))}
            className={`rounded-lg px-3 py-1.5 text-sm font-medium text-indigo-800 hover:bg-indigo-50 ${focusRing}`}
          >
            ใช้ช่วงมาตรฐาน (09-11, 13-15, 15-17)
          </button>
        </div>
      </fieldset>

      {errors.length > 0 && (
        <ErrorBanner>
          <ul className="list-disc space-y-0.5 pl-4">{errors.map((m) => <li key={m}>{m}</li>)}</ul>
        </ErrorBanner>
      )}
      {serverError && <ErrorBanner onDismiss={() => setServerError(null)}>{serverError}</ErrorBanner>}

      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="text-sm text-slate-700" aria-live="polite">จะสร้างสูงสุด <strong>{planned.toLocaleString('th-TH')}</strong> ช่วง</p>
        <button type="submit" disabled={busy} className={`rounded-lg bg-indigo-700 px-5 py-2 text-sm font-medium text-white hover:bg-indigo-800 disabled:opacity-60 ${focusRing}`}>
          {busy ? 'กำลังสร้าง…' : 'สร้างช่วงเวลา'}
        </button>
      </div>
    </form>
  );
}
