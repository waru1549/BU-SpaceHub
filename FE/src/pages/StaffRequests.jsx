import { useState } from 'react';
import RoomRequestsPanel from '../components/Requests/RoomRequestsPanel.jsx';
import PrinterRequestsPanel from '../components/Requests/PrinterRequestsPanel.jsx';
import EquipmentRequestsPanel from '../components/Requests/EquipmentRequestsPanel.jsx';
import EquipmentFinesPanel from '../components/Requests/EquipmentFinesPanel.jsx';
import MaintenanceRequestsPanel from '../components/Requests/MaintenanceRequestsPanel.jsx';

// แต่ละแท็บใช้สีของโมดูลตัวเอง (ห้อง = Indigo, เครื่องพิมพ์ = Emerald, อุปกรณ์/ค่าปรับ = Amber, แจ้งซ่อม = Sky)
const INDIGO = { active: 'border-indigo-600 text-indigo-800', ring: 'focus-visible:outline-indigo-500' };
const EMERALD = { active: 'border-emerald-600 text-emerald-800', ring: 'focus-visible:outline-emerald-600' };
const SKY = { active: 'border-sky-600 text-sky-900', ring: 'focus-visible:outline-sky-600' };
const AMBER = { active: 'border-amber-600 text-amber-900', ring: 'focus-visible:outline-amber-600' };

const TABS = [
  { id: 'rooms', label: 'จองห้อง', Panel: RoomRequestsPanel, ...INDIGO },
  { id: 'printers', label: 'เครื่องพิมพ์ 3D', Panel: PrinterRequestsPanel, ...EMERALD },
  { id: 'equipment', label: 'ยืม-คืนอุปกรณ์', Panel: EquipmentRequestsPanel, ...AMBER },
  { id: 'fines', label: 'ค่าปรับอุปกรณ์', Panel: EquipmentFinesPanel, ...AMBER },
  { id: 'maintenance', label: 'แจ้งซ่อม', Panel: MaintenanceRequestsPanel, ...SKY },
];

// หน้าคิวคำขอของเจ้าหน้าที่: ห้อง เครื่องพิมพ์ อุปกรณ์ ค่าปรับ และแจ้งซ่อม
export default function StaffRequests() {
  const [tab, setTab] = useState('rooms');
  const current = TABS.find((t) => t.id === tab) ?? TABS[0];

  const onKeyDown = (e) => {
    const i = TABS.findIndex((t) => t.id === tab);
    if (e.key === 'ArrowRight') setTab(TABS[(i + 1) % TABS.length].id);
    else if (e.key === 'ArrowLeft') setTab(TABS[(i - 1 + TABS.length) % TABS.length].id);
    else return;
    e.preventDefault();
  };

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-2xl font-bold text-slate-800">คำขอรออนุมัติ</h1>
        <p className="text-sm text-slate-600">ตรวจสอบและดำเนินการกับคำขอของผู้ใช้</p>
      </header>

      <div role="tablist" aria-label="ประเภทคำขอ" onKeyDown={onKeyDown} className="flex gap-1 overflow-x-auto border-b border-slate-200">
        {TABS.map((t) => {
          const selected = t.id === tab;
          return (
            <button
              key={t.id}
              type="button"
              role="tab"
              id={`tab-${t.id}`}
              aria-selected={selected}
              aria-controls={`panel-${t.id}`}
              tabIndex={selected ? 0 : -1}
              onClick={() => setTab(t.id)}
              className={`-mb-px whitespace-nowrap border-b-2 px-4 py-2 text-sm font-semibold focus-visible:outline-2 focus-visible:outline-offset-2 ${t.ring} ${
                selected ? t.active : 'border-transparent text-slate-600 hover:text-slate-900'
              }`}
            >
              {t.label}
            </button>
          );
        })}
      </div>

      <div role="tabpanel" id={`panel-${current.id}`} aria-labelledby={`tab-${current.id}`}>
        <current.Panel />
      </div>
    </div>
  );
}