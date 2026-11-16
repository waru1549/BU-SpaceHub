import { SYSTEMS } from '../../utils/dashboard.js';

// ตัวเลือกระบบ (tablist) ใช้ปุ่มลูกศรซ้าย/ขวาเลื่อนได้ | เลื่อนแนวนอนบนจอแคบ
export default function SystemSelector({ value, onChange }) {
  const onKeyDown = (e) => {
    const index = SYSTEMS.findIndex((s) => s.key === value);
    let next = null;
    if (e.key === 'ArrowRight') next = (index + 1) % SYSTEMS.length;
    if (e.key === 'ArrowLeft') next = (index - 1 + SYSTEMS.length) % SYSTEMS.length;
    if (e.key === 'Home') next = 0;
    if (e.key === 'End') next = SYSTEMS.length - 1;
    if (next === null) return;
    e.preventDefault();
    onChange(SYSTEMS[next].key);
    document.getElementById(`system-tab-${SYSTEMS[next].key}`)?.focus();
  };

  return (
    <div className="-mx-1 overflow-x-auto px-1 py-1">
      <div role="tablist" aria-label="เลือกระบบ" onKeyDown={onKeyDown} className="flex w-max gap-2">
        {SYSTEMS.map((s) => {
          const selected = s.key === value;
          return (
            <button
              key={s.key}
              id={`system-tab-${s.key}`}
              type="button"
              role="tab"
              aria-selected={selected}
              aria-controls="system-panel"
              tabIndex={selected ? 0 : -1}
              onClick={() => onChange(s.key)}
              className={`whitespace-nowrap rounded-full px-4 py-2 text-sm font-semibold focus-visible:outline-2 focus-visible:outline-offset-2 ${s.ring} ${
                selected ? s.active : 'border border-slate-300 bg-white text-slate-700 hover:bg-slate-100'
              }`}
            >
              {s.label}
            </button>
          );
        })}
      </div>
    </div>
  );
}
