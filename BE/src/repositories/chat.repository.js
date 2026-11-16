import { supabase } from '../config/supabase.js';
import { AppError } from '../middleware/error.middleware.js';

const fail = (error) => {
  throw new AppError('Database query failed', 500, error);
};

// ----- ตัวช่วยสร้าง query: ใช้เฉพาะ view/คอลัมน์ที่ whitelist ใน chatTools.service.js -----
const run = async (query) => {
  const { data, error } = await query;
  if (error) fail(error);
  return data ?? [];
};

export const selectKnowledge = () =>
  run(supabase.from('ai_knowledge').select('topic_key, category, title, content, keywords').order('topic_id'));

export const selectResources = ({ category, onlyAvailable, keywordOr, limit }) => {
  let q = supabase
    .from('v_ai_resources')
    .select('resource_code, resource_name, category, location, capacity, quantity, resource_status, is_available');
  if (category) q = q.eq('category', category);
  if (onlyAvailable) q = q.eq('is_available', true);
  if (keywordOr) q = q.or(keywordOr);
  return run(q.order('category').order('resource_code').limit(limit));
};

export const selectSlots = ({ view, date, today, keywordOr, minCapacity, limit }) => {
  const cols = view === 'v_ai_room_slots'
    ? 'resource_code, resource_name, location, capacity, work_date, start_time, end_time, remaining_slots'
    : 'resource_code, resource_name, location, work_date, start_time, end_time, remaining_slots';
  let q = supabase.from(view).select(cols).eq('is_bookable', true);
  q = date ? q.eq('work_date', date) : q.gte('work_date', today);
  if (keywordOr) q = q.or(keywordOr);
  if (minCapacity) q = q.gte('capacity', minCapacity);
  return run(q.order('work_date').order('start_time').order('resource_code').limit(limit));
};

export const selectEquipmentStock = ({ keywordOr, onlyAvailable, limit }) => {
  let q = supabase
    .from('v_ai_equipment_stock')
    .select('resource_code, resource_name, location, total_quantity, on_loan, available_quantity, resource_status');
  if (onlyAvailable) q = q.gt('available_quantity', 0);
  if (keywordOr) q = q.or(keywordOr);
  return run(q.order('resource_code').limit(limit));
};

export const selectUsageStats = ({ category, orderBy, ascending, limit }) => {
  let q = supabase
    .from('v_ai_usage_stats')
    .select('resource_code, resource_name, resource_category, total_bookings, completed_bookings, used_hours, utilization_pct');
  if (category) q = q.eq('resource_category', category);
  return run(q.order(orderBy, { ascending, nullsFirst: false }).order('resource_code').limit(limit));
};

export const selectModuleKpi = (module) => {
  let q = supabase.from('v_dashboard_module_kpi').select('module, kpi_key, kpi_value');
  if (module) q = q.eq('module', module);
  return run(q.order('module').order('kpi_key'));
};

export const selectStatusDistribution = (module) => {
  let q = supabase.from('v_dashboard_status_distribution').select('module, status, total');
  if (module) q = q.eq('module', module);
  return run(q.order('module').order('total', { ascending: false }));
};

export const selectMaintenanceSummary = () =>
  run(supabase.from('v_ai_maintenance_summary').select('resource_category, status, total')
    .order('resource_category').order('status'));

export const selectRepairRanking = (limit) =>
  run(supabase.from('v_dashboard_repair_ranking')
    .select('resource_code, resource_name, resource_category, repair_count, open_count')
    .order('repair_count', { ascending: false }).order('resource_code').limit(limit));

export const selectMonthlyTrend = ({ module, limit }) => {
  let q = supabase.from('v_ai_monthly_trend').select('month_label, module, total_bookings');
  if (module) q = q.eq('module', module);
  return run(q.order('month_label', { ascending: false }).order('module').limit(limit));
};

// บันทึก log (best effort: ไม่ทำให้คำตอบล้มเหลว)
export const insertLog = async (row) => {
  const { error } = await supabase.from('chat_logs').insert(row);
  if (error) console.error('[chat_logs] insert failed:', error.message);
};
