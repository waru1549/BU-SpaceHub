import { MapPin, Users } from 'lucide-react';
import { formatTimeRange } from '../../utils/format.js';
import { ROOM_UNAVAILABLE_LABEL } from '../../utils/booking.js';

const focusRing =
  'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-500';

function slotLabel(slot) {
  if (slot.is_bookable) return slot.max_slots > 1 ? `เหลือ ${slot.remaining_slots}` : 'ว่าง';
  return slot.remaining_slots === 0 ? 'เต็ม' : 'ปิดรับจอง';
}

export default function RoomCard({ room, onSelectSlot }) {
  const unavailable = ROOM_UNAVAILABLE_LABEL[room.resource_status];

  return (
    <article className="flex flex-col rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
      <header className="flex items-start justify-between gap-3">
        <div>
          <h3 className="font-semibold text-slate-900">{room.resource_name}</h3>
          <p className="text-xs text-slate-600">{room.resource_code}</p>
        </div>
        {unavailable && (
          <span className="whitespace-nowrap rounded-full bg-red-50 px-2.5 py-0.5 text-xs font-semibold text-red-800">
            {unavailable}
          </span>
        )}
      </header>

      <ul className="mt-3 space-y-1 text-sm text-slate-700">
        {room.location && (
          <li className="flex items-center gap-2">
            <MapPin className="h-4 w-4 shrink-0 text-indigo-600" aria-hidden="true" />
            <span>{room.location}</span>
          </li>
        )}
        {room.capacity && (
          <li className="flex items-center gap-2">
            <Users className="h-4 w-4 shrink-0 text-indigo-600" aria-hidden="true" />
            <span>รองรับ {room.capacity} คน</span>
          </li>
        )}
      </ul>

      {room.description && <p className="mt-2 line-clamp-2 text-sm text-slate-600">{room.description}</p>}

      <div className="mt-4">
        <p className="mb-2 text-xs font-semibold text-slate-600">ช่วงเวลา</p>
        {room.slots.length === 0 ? (
          <p className="text-sm text-slate-600">ไม่มีช่วงเวลาเปิดจองในวันนี้</p>
        ) : (
          <ul className="grid grid-cols-1 gap-2 min-[420px]:grid-cols-2">
            {room.slots.map((slot) => {
              const time = formatTimeRange(slot.start_time, slot.end_time);
              const label = slotLabel(slot);
              return (
                <li key={slot.schedule_id}>
                  <button
                    type="button"
                    disabled={!slot.is_bookable}
                    onClick={() => onSelectSlot(room, slot)}
                    aria-label={`${room.resource_name} เวลา ${time} ${label}`}
                    className={`w-full rounded-xl border px-3 py-2 text-left text-sm transition ${focusRing} ${
                      slot.is_bookable
                        ? 'border-indigo-300 bg-white text-indigo-900 hover:bg-indigo-50'
                        : 'cursor-not-allowed border-slate-200 bg-slate-100 text-slate-600'
                    }`}
                  >
                    <span className="block font-medium">{time}</span>
                    <span className="block text-xs">{label}</span>
                  </button>
                </li>
              );
            })}
          </ul>
        )}
      </div>
    </article>
  );
}