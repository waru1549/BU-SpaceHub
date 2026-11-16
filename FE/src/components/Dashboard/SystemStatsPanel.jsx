import { FINE_STATUS_TEXT, REPAIR_CATEGORY_TEXT, formatDecimal } from '../../utils/dashboard.js';
import { formatBaht } from '../../utils/equipment.js';
import BarList from './BarList.jsx';

// สถิติเฉพาะระบบ: หัวข้อและตัวอย่างข้อความกำหนดตามชนิด breakdown ของแต่ละระบบ
const VIEWS = {
  room: {
    type: 'SLOT',
    title: 'ช่วงเวลาที่ถูกจอง',
    desc: 'จำนวนการจองที่ไม่ถูกปฏิเสธ/ยกเลิก แยกตามช่วงเวลา',
    label: (key) => key,
    note: () => null,
    sort: (a, b) => a.key.localeCompare(b.key),
  },
  printer: {
    type: 'MATERIAL',
    title: 'วัสดุที่ใช้พิมพ์',
    desc: 'จำนวนงานและน้ำหนักโดยประมาณ แยกตามวัสดุ (ไม่นับงานที่ถูกปฏิเสธ/ยกเลิก)',
    label: (key) => key,
    note: (i) => (i.value2 > 0 ? `น้ำหนักรวมโดยประมาณ ${formatDecimal(i.value2)} กรัม` : null),
    sort: (a, b) => b.total - a.total,
  },
  equipment: {
    type: 'FINE_STATUS',
    title: 'ค่าปรับอุปกรณ์',
    desc: 'จำนวนรายการและยอดเงิน แยกตามสถานะค่าปรับ',
    label: (key) => FINE_STATUS_TEXT[key] ?? key,
    note: (i) => `ยอดรวม ${formatBaht(i.value2 ?? 0)}`,
    sort: (a, b) => b.total - a.total,
  },
  maintenance: {
    type: 'REPAIR_CATEGORY',
    title: 'ประเภทงานแจ้งซ่อม',
    desc: 'จำนวนงานตามประเภททรัพยากร (ไม่นับงานที่ถูกปฏิเสธ/ยกเลิก)',
    label: (key) => REPAIR_CATEGORY_TEXT[key] ?? key,
    note: (i) => (i.value2 > 0 ? `ใช้เวลาซ่อมเฉลี่ย ${formatDecimal(i.value2)} วัน` : null),
    sort: (a, b) => b.total - a.total,
  },
};

export default function SystemStatsPanel({ system, summary }) {
  const view = VIEWS[system.key];
  const rows = (summary?.breakdown ?? []).filter((b) => b.type === view.type).sort(view.sort);
  const items = rows.map((b) => ({
    key: b.key,
    label: view.label(b.key),
    value: b.total,
    value2: b.value2,
    note: view.note({ value2: b.value2 }),
  }));

  return (
    <section aria-labelledby="sys-stats-title" className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
      <h2 id="sys-stats-title" className="text-lg font-semibold text-slate-800">
        {view.title}
      </h2>
      <p className="mb-4 text-sm text-slate-600">{view.desc}</p>
      <BarList items={items} color={system.color} />
    </section>
  );
}
