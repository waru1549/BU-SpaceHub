import { supabase } from '../config/supabase.js';
import { AppError } from '../middleware/error.middleware.js';

// error ของ Supabase เป็น object ธรรมดา: ห่อเป็น AppError (รายละเอียดจะไม่ออกบน production)
const fail = (error) => {
  throw new AppError('Database query failed', 500, error);
};

const applyFilters = (query, filters) =>
  Object.entries(filters).reduce((q, [col, val]) => q.eq(col, val), query);

export const fetchKpi = async () => {
  const { data, error } = await supabase.from('v_dashboard_kpi').select('*').single();
  if (error) fail(error);
  return data;
};

export const fetchTrend = async () => {
  const { data, error } = await supabase
    .from('v_monthly_booking_trend')
    .select('month_start, month_label, module, total_bookings, distinct_users')
    .order('month_start', { ascending: true })
    .order('module', { ascending: true })
    .limit(1000);
  if (error) fail(error);
  return data;
};

// ดึงข้อมูลจาก view ทีละหน้า (เรียงลำดับ + กรอง + นับจำนวนทั้งหมด)
export const fetchPage = async (cfg, { from, to, sort, ascending, filters }) => {
  let query = applyFilters(
    supabase.from(cfg.view).select('*', { count: 'exact' }),
    filters,
  ).order(sort, { ascending, nullsFirst: false });

  // คอลัมน์ตัดสินลำดับเมื่อค่าซ้ำ ทำให้การแบ่งหน้าไม่สลับแถวไปมา
  if (cfg.tieBreaker !== sort) query = query.order(cfg.tieBreaker, { ascending: true });

  const { data, count, error } = await query.range(from, to);

  // ขอหน้าเกินหน้าสุดท้าย: คืนแถวว่าง แต่ยังบอกจำนวนทั้งหมดให้ถูกต้อง
  if (error?.code === 'PGRST103') {
    const head = await applyFilters(
      supabase.from(cfg.view).select('*', { count: 'exact', head: true }),
      filters,
    );
    if (head.error) fail(head.error);
    return { rows: [], total: head.count ?? 0 };
  }
  if (error) fail(error);
  return { rows: data, total: count ?? 0 };
};