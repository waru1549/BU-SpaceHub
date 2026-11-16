const TOOL_LABEL = {
  search_knowledge: 'ค้นหากฎและวิธีใช้งาน',
  list_resources: 'รายชื่อทรัพยากร',
  get_free_slots: 'ช่วงเวลาที่ว่าง',
  get_equipment_stock: 'สต็อกอุปกรณ์',
  get_usage_stats: 'สถิติการใช้งาน',
  get_system_summary: 'สรุปตัวเลขของระบบ',
  get_maintenance_overview: 'ภาพรวมงานแจ้งซ่อม',
  get_monthly_trend: 'แนวโน้มรายเดือน',
};

// หลักฐานที่มาของคำตอบ: เครื่องมือที่ AI เรียก, view ที่อ่าน, SQL ที่รันจริง, จำนวนแถว
export default function EvidencePanel({ evidence }) {
  if (!evidence || evidence.length === 0) return null;
  return (
    <details className="group mt-2 rounded-lg border border-slate-200 bg-slate-50 text-xs text-slate-700">
      <summary className="cursor-pointer select-none rounded-lg px-3 py-2 font-medium text-slate-800 hover:bg-slate-100 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600">
        ดูหลักฐานข้อมูล ({evidence.length} คิวรี)
      </summary>
      <ol className="space-y-3 border-t border-slate-200 p-3">
        {evidence.map((e, i) => (
          <li key={`${e.view}-${i}`}>
            <p className="font-semibold text-slate-900">
              {TOOL_LABEL[e.tool] ?? e.tool} <span className="font-normal text-slate-600">· {e.row_count} แถว</span>
            </p>
            <p className="text-slate-600">
              เครื่องมือ <code className="rounded bg-white px-1 py-0.5">{e.tool}</code> · อ่านจาก{' '}
              <code className="rounded bg-white px-1 py-0.5">{e.view}</code>
            </p>
            <pre
              tabIndex={0}
              aria-label={`SQL ที่ใช้ ${e.view}`}
              className="mt-1 overflow-x-auto rounded-md bg-slate-900 p-2 text-[11px] leading-relaxed whitespace-pre-wrap text-slate-100 focus-visible:outline-2 focus-visible:outline-indigo-400"
            >
              {e.sql}
            </pre>
          </li>
        ))}
      </ol>
    </details>
  );
}
