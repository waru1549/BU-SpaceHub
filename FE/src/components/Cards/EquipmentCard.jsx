import { MapPin, Package } from 'lucide-react';
import { ROOM_UNAVAILABLE_LABEL } from '../../utils/booking.js';

const focusRing =
  'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-amber-600';

export default function EquipmentCard({ item, onBorrow }) {
  const unavailable = ROOM_UNAVAILABLE_LABEL[item.resource_status];
  const total = item.quantity ?? 0;
  const out = item.remaining <= 0;
  const label = unavailable ? unavailable : out ? 'หมดช่วงนี้' : 'ขอยืม';

  return (
    <article className="flex flex-col rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
      <header className="flex items-start justify-between gap-3">
        <div>
          <h3 className="font-semibold text-slate-900">{item.resource_name}</h3>
          <p className="text-xs text-slate-600">{item.resource_code}</p>
        </div>
        {unavailable && (
          <span className="whitespace-nowrap rounded-full bg-red-50 px-2.5 py-0.5 text-xs font-semibold text-red-800">
            {unavailable}
          </span>
        )}
      </header>

      <ul className="mt-3 space-y-1 text-sm text-slate-700">
        {item.location && (
          <li className="flex items-center gap-2">
            <MapPin className="h-4 w-4 shrink-0 text-amber-700" aria-hidden="true" />
            <span>{item.location}</span>
          </li>
        )}
        <li className="flex items-center gap-2">
          <Package className="h-4 w-4 shrink-0 text-amber-700" aria-hidden="true" />
          <span>
            คงเหลือ <strong className={out ? 'text-red-800' : 'text-slate-900'}>{item.remaining}</strong> / {total} ชิ้น
          </span>
        </li>
      </ul>

      {item.description && <p className="mt-2 line-clamp-2 text-sm text-slate-600">{item.description}</p>}

      <div className="mt-4">
        <button
          type="button"
          disabled={!item.is_borrowable}
          onClick={() => onBorrow(item)}
          aria-label={`${label} ${item.resource_name}`}
          className={`w-full rounded-xl border px-3 py-2 text-sm font-medium transition ${focusRing} ${
            item.is_borrowable
              ? 'border-amber-700 bg-amber-700 text-white hover:bg-amber-800'
              : 'cursor-not-allowed border-slate-200 bg-slate-100 text-slate-600'
          }`}
        >
          {label}
        </button>
      </div>
    </article>
  );
}
