import * as repo from '../repositories/chat.repository.js';

// ---------------------------------------------------------------------------
// เครื่องมือ (Tool) ที่ AI เรียกได้ — whitelist เท่านั้น: ทุกตัวอ่านจาก view/ตารางที่ไม่มีข้อมูลส่วนบุคคล
// ผลลัพธ์ของทุก tool: { data, queries:[{ view, sql, rows }] }  (queries = หลักฐานที่แสดงให้ผู้ใช้เห็น)
// ---------------------------------------------------------------------------

const CATEGORIES = ['ROOM', 'PRINTER', 'EQUIPMENT', 'MAINTENANCE'];
const KNOWLEDGE_CATEGORIES = ['GENERAL', ...CATEGORIES];
const USAGE_ORDER = ['total_bookings', 'used_hours', 'utilization_pct'];

const bangkokToday = () => new Date().toLocaleDateString('en-CA', { timeZone: 'Asia/Bangkok' });

// เหลือเฉพาะตัวอักษร (รวมไทย) ตัวเลข ช่องว่าง และขีด — กัน injection เข้า filter ของ PostgREST
const cleanKeyword = (v) =>
  typeof v === 'string'
    ? v.replace(/[^\p{L}\p{N}\p{M}\s-]/gu, '').trim().slice(0, 40)
    : '';
const enumOrNull = (v, list) => {
  const up = typeof v === 'string' ? v.toUpperCase() : '';
  return list.includes(up) ? up : null;
};
const intIn = (v, def, min, max) => {
  const n = Number(v);
  return Number.isInteger(n) ? Math.min(Math.max(n, min), max) : def;
};
const lit = (v) => `'${String(v).replace(/'/g, "''")}'`;
const orFilter = (kw, cols) => (kw ? cols.map((c) => `${c}.ilike.%${kw}%`).join(',') : null);
const orSql = (kw, cols) => (kw ? `(${cols.map((c) => `${c} ILIKE ${lit(`%${kw}%`)}`).join(' OR ')})` : null);
const where = (parts) => {
  const p = parts.filter(Boolean);
  return p.length ? ` WHERE ${p.join(' AND ')}` : '';
};

const TOOLS = {
  search_knowledge: {
    description: 'ค้นหากฎและวิธีใช้งานระบบ (เช่น ยืมได้กี่วัน ค่าปรับ จองเครื่องพิมพ์ แจ้งซ่อมต้องทำอย่างไร)',
    parameters: {
      type: 'object',
      properties: {
        keyword: { type: 'string', description: 'คำสำคัญ เช่น ยืม, ค่าปรับ, แจ้งซ่อม' },
        category: { type: 'string', enum: KNOWLEDGE_CATEGORIES, description: 'หมวดของกฎ' },
      },
    },
    async run(args) {
      const category = enumOrNull(args.category, KNOWLEDGE_CATEGORIES);
      const kw = cleanKeyword(args.keyword).toLowerCase();
      let rows = await repo.selectKnowledge();
      if (category) rows = rows.filter((r) => r.category === category);
      if (kw) {
        const hit = rows.filter((r) =>
          [r.title, r.content, ...(r.keywords ?? [])].some((t) => String(t).toLowerCase().includes(kw)));
        if (hit.length) rows = hit;
      }
      rows = rows.slice(0, 4);
      const sql = `SELECT category, title, content FROM ai_knowledge${where([category && `category = ${lit(category)}`, kw && `(title ILIKE ${lit(`%${kw}%`)} OR content ILIKE ${lit(`%${kw}%`)})`])};`;
      return { data: rows.map(({ category: c, title, content }) => ({ category: c, title, content })), queries: [{ view: 'ai_knowledge', sql, rows: rows.length }] };
    },
  },

  list_resources: {
    description: 'ดูรายชื่อห้อง เครื่องพิมพ์ 3D อุปกรณ์ และสิ่งอำนวยความสะดวก พร้อมสถานะปัจจุบัน (พร้อมใช้งาน/ชำรุด/ปิดซ่อม ฯลฯ)',
    parameters: {
      type: 'object',
      properties: {
        category: { type: 'string', enum: CATEGORIES },
        only_available: { type: 'boolean', description: 'true = เฉพาะที่พร้อมใช้งาน' },
        keyword: { type: 'string', description: 'ชื่อหรือรหัสบางส่วน' },
        limit: { type: 'integer', description: 'สูงสุด 30' },
      },
    },
    async run(args) {
      const category = enumOrNull(args.category, CATEGORIES);
      const kw = cleanKeyword(args.keyword);
      const onlyAvailable = args.only_available === true;
      const limit = intIn(args.limit, 20, 1, 30);
      const cols = ['resource_name', 'resource_code'];
      const rows = await repo.selectResources({ category, onlyAvailable, keywordOr: orFilter(kw, cols), limit });
      const sql = `SELECT resource_code, resource_name, category, location, capacity, quantity, resource_status FROM v_ai_resources${where([category && `category = ${lit(category)}`, onlyAvailable && 'is_available = true', orSql(kw, cols)])} ORDER BY category, resource_code LIMIT ${limit};`;
      return { data: rows, queries: [{ view: 'v_ai_resources', sql, rows: rows.length }] };
    },
  },

  get_free_slots: {
    description: 'หาช่วงเวลาที่ว่างและจองได้ของห้อง (ROOM) หรือเครื่องพิมพ์ 3D (PRINTER) ระบุวันที่ได้ (YYYY-MM-DD) ถ้าไม่ระบุจะแสดงตั้งแต่วันนี้เป็นต้นไป',
    parameters: {
      type: 'object',
      properties: {
        type: { type: 'string', enum: ['ROOM', 'PRINTER'] },
        date: { type: 'string', description: 'วันที่ YYYY-MM-DD' },
        keyword: { type: 'string', description: 'ชื่อหรือรหัสห้อง/เครื่อง' },
        min_capacity: { type: 'integer', description: 'จำนวนที่นั่งขั้นต่ำ (เฉพาะห้อง)' },
        limit: { type: 'integer', description: 'สูงสุด 30' },
      },
      required: ['type'],
    },
    async run(args) {
      const type = enumOrNull(args.type, ['ROOM', 'PRINTER']);
      if (!type) return { data: { error: 'type ต้องเป็น ROOM หรือ PRINTER' }, queries: [] };
      const date = /^\d{4}-\d{2}-\d{2}$/.test(args.date ?? '') ? args.date : null;
      const kw = cleanKeyword(args.keyword);
      const minCapacity = type === 'ROOM' ? intIn(args.min_capacity, null, 1, 1000) : null;
      const limit = intIn(args.limit, 20, 1, 30);
      const view = type === 'ROOM' ? 'v_ai_room_slots' : 'v_ai_printer_slots';
      const today = bangkokToday();
      const cols = ['resource_name', 'resource_code'];
      const rows = await repo.selectSlots({ view, date, today, keywordOr: orFilter(kw, cols), minCapacity, limit });
      const sql = `SELECT resource_code, resource_name, location, work_date, start_time, end_time, remaining_slots FROM ${view}${where(['is_bookable = true', date ? `work_date = ${lit(date)}` : `work_date >= ${lit(today)}`, orSql(kw, cols), minCapacity && `capacity >= ${minCapacity}`])} ORDER BY work_date, start_time LIMIT ${limit};`;
      return { data: rows, queries: [{ view, sql, rows: rows.length }] };
    },
  },

  get_equipment_stock: {
    description: 'ตรวจสอบอุปกรณ์ที่ยืมได้ตอนนี้ (จำนวนทั้งหมด กำลังถูกยืม และคงเหลือ)',
    parameters: {
      type: 'object',
      properties: {
        keyword: { type: 'string', description: 'ชื่อหรือรหัสอุปกรณ์ เช่น โน้ตบุ๊ก, โปรเจคเตอร์' },
        only_available: { type: 'boolean', description: 'true = เฉพาะที่ยังเหลือให้ยืม' },
        limit: { type: 'integer', description: 'สูงสุด 30' },
      },
    },
    async run(args) {
      const kw = cleanKeyword(args.keyword);
      const onlyAvailable = args.only_available === true;
      const limit = intIn(args.limit, 20, 1, 30);
      const cols = ['resource_name', 'resource_code'];
      const rows = await repo.selectEquipmentStock({ keywordOr: orFilter(kw, cols), onlyAvailable, limit });
      const sql = `SELECT resource_code, resource_name, location, total_quantity, on_loan, available_quantity, resource_status FROM v_ai_equipment_stock${where([onlyAvailable && 'available_quantity > 0', orSql(kw, cols)])} ORDER BY resource_code LIMIT ${limit};`;
      return { data: rows, queries: [{ view: 'v_ai_equipment_stock', sql, rows: rows.length }] };
    },
  },

  get_usage_stats: {
    description: 'สถิติการใช้งานทรัพยากร จัดอันดับ เช่น ห้องที่ถูกจองมากที่สุด อัตราการใช้งาน ชั่วโมงที่ใช้',
    parameters: {
      type: 'object',
      properties: {
        category: { type: 'string', enum: CATEGORIES },
        order_by: { type: 'string', enum: USAGE_ORDER, description: 'ค่าเริ่มต้น total_bookings' },
        direction: { type: 'string', enum: ['desc', 'asc'] },
        limit: { type: 'integer', description: 'สูงสุด 10 (ค่าเริ่มต้น 5)' },
      },
    },
    async run(args) {
      const category = enumOrNull(args.category, CATEGORIES);
      const orderBy = USAGE_ORDER.includes(args.order_by) ? args.order_by : 'total_bookings';
      const ascending = args.direction === 'asc';
      const limit = intIn(args.limit, 5, 1, 10);
      const rows = await repo.selectUsageStats({ category, orderBy, ascending, limit });
      const sql = `SELECT resource_code, resource_name, resource_category, total_bookings, completed_bookings, used_hours, utilization_pct FROM v_ai_usage_stats${where([category && `resource_category = ${lit(category)}`])} ORDER BY ${orderBy} ${ascending ? 'ASC' : 'DESC'} NULLS LAST LIMIT ${limit};`;
      return { data: rows, queries: [{ view: 'v_ai_usage_stats', sql, rows: rows.length }] };
    },
  },

  get_system_summary: {
    description: 'ตัวเลขสรุป (KPI) และสัดส่วนสถานะของแต่ละระบบ เช่น จำนวนรออนุมัติ จำนวนอุปกรณ์เกินกำหนดคืน ค่าปรับค้างชำระ',
    parameters: {
      type: 'object',
      properties: { module: { type: 'string', enum: CATEGORIES, description: 'ไม่ระบุ = ทุกระบบ' } },
    },
    async run(args) {
      const module = enumOrNull(args.module, CATEGORIES);
      const [kpis, statuses] = await Promise.all([repo.selectModuleKpi(module), repo.selectStatusDistribution(module)]);
      const w = where([module && `module = ${lit(module)}`]);
      return {
        data: { kpis, status_distribution: statuses },
        queries: [
          { view: 'v_dashboard_module_kpi', sql: `SELECT module, kpi_key, kpi_value FROM v_dashboard_module_kpi${w} ORDER BY module, kpi_key;`, rows: kpis.length },
          { view: 'v_dashboard_status_distribution', sql: `SELECT module, status, total FROM v_dashboard_status_distribution${w} ORDER BY module, total DESC;`, rows: statuses.length },
        ],
      };
    },
  },

  get_maintenance_overview: {
    description: 'ภาพรวมงานแจ้งซ่อม: จำนวนแยกตามสถานะและประเภททรัพยากร และอันดับทรัพยากรที่ถูกแจ้งซ่อมบ่อยที่สุด',
    parameters: { type: 'object', properties: { top: { type: 'integer', description: 'จำนวนอันดับ สูงสุด 10 (ค่าเริ่มต้น 5)' } } },
    async run(args) {
      const top = intIn(args.top, 5, 1, 10);
      const [summary, ranking] = await Promise.all([repo.selectMaintenanceSummary(), repo.selectRepairRanking(top)]);
      return {
        data: { by_status_and_category: summary, most_repaired: ranking },
        queries: [
          { view: 'v_ai_maintenance_summary', sql: 'SELECT resource_category, status, total FROM v_ai_maintenance_summary ORDER BY resource_category, status;', rows: summary.length },
          { view: 'v_dashboard_repair_ranking', sql: `SELECT resource_code, resource_name, resource_category, repair_count, open_count FROM v_dashboard_repair_ranking ORDER BY repair_count DESC LIMIT ${top};`, rows: ranking.length },
        ],
      };
    },
  },

  get_monthly_trend: {
    description: 'แนวโน้มจำนวนรายการรายเดือนของแต่ละระบบ (ย้อนหลัง)',
    parameters: {
      type: 'object',
      properties: {
        module: { type: 'string', enum: CATEGORIES },
        months: { type: 'integer', description: 'จำนวนเดือนย้อนหลัง สูงสุด 12' },
      },
    },
    async run(args) {
      const module = enumOrNull(args.module, CATEGORIES);
      const months = intIn(args.months, 6, 1, 12);
      const limit = months * (module ? 1 : CATEGORIES.length);
      const rows = await repo.selectMonthlyTrend({ module, limit });
      const sql = `SELECT month_label, module, total_bookings FROM v_ai_monthly_trend${where([module && `module = ${lit(module)}`])} ORDER BY month_label DESC LIMIT ${limit};`;
      return { data: rows, queries: [{ view: 'v_ai_monthly_trend', sql, rows: rows.length }] };
    },
  },
};

export const TOOL_NAMES = Object.keys(TOOLS);

// รูปแบบที่ส่งให้ Groq (OpenAI-compatible)
// ทุกพารามิเตอร์ยอมรับ null ได้ เพราะบางโมเดลส่ง null แทนการละพารามิเตอร์ที่ไม่ใช้ (Groq ตรวจ schema ฝั่งเซิร์ฟเวอร์)
const nullable = (params) => {
  const required = params.required ?? [];
  const properties = Object.fromEntries(
    Object.entries(params.properties).map(([k, v]) => [
      k,
      required.includes(k) ? v : { ...v, type: [v.type, 'null'], ...(v.enum ? { enum: [...v.enum, null] } : {}) },
    ]),
  );
  return { ...params, properties };
};

export const toolDefinitions = TOOL_NAMES.map((name) => ({
  type: 'function',
  function: { name, description: TOOLS[name].description, parameters: nullable(TOOLS[name].parameters) },
}));

// เรียก tool ตามชื่อ: ชื่อที่ไม่อยู่ใน whitelist จะถูกปฏิเสธ (ใช้ Object.hasOwn กัน __proto__/constructor)
export const executeTool = async (name, args) => {
  if (!Object.hasOwn(TOOLS, name)) {
    return { data: { error: `ไม่มีเครื่องมือชื่อ ${String(name).slice(0, 40)}` }, queries: [] };
  }
  const raw = args && typeof args === 'object' && !Array.isArray(args) ? args : {};
  // ตัด null/undefined ออก: ถือว่าไม่ได้ระบุพารามิเตอร์นั้น
  const safeArgs = Object.fromEntries(Object.entries(raw).filter(([, v]) => v !== null && v !== undefined));
  return TOOLS[name].run(safeArgs);
};