import { supabase } from '../config/supabase.js';
import { AppError } from '../middleware/error.middleware.js';

const fail = (error) => {
  throw new AppError('Database query failed', 500, error);
};

const SEARCH_COLS = ['full_name', 'email', 'user_code', 'university_id'];

const applyFilters = (q, { filters, search }) => {
  Object.entries(filters).forEach(([col, val]) => {
    q = q.eq(col, val);
  });
  if (search) q = q.or(SEARCH_COLS.map((c) => `${c}.ilike.%${search}%`).join(','));
  return q;
};

export const fetchUsersPage = async ({ from, to, sort, ascending, filters, search }) => {
  let q = applyFilters(supabase.from('v_admin_users').select('*', { count: 'exact' }), { filters, search });
  q = q.order(sort, { ascending, nullsFirst: false });
  if (sort !== 'user_id') q = q.order('user_id', { ascending: true });

  const { data, count, error } = await q.range(from, to);
  if (error?.code === 'PGRST103') {
    // หน้าที่ขอเกินจำนวนจริง: คืนแถวว่างพร้อมยอดรวมที่ถูกต้อง
    const h = await applyFilters(supabase.from('v_admin_users').select('*', { count: 'exact', head: true }), { filters, search });
    if (h.error) fail(h.error);
    return { rows: [], total: h.count ?? 0 };
  }
  if (error) fail(error);
  return { rows: data, total: count ?? 0 };
};

export const findUser = async (id) => {
  const { data, error } = await supabase.from('v_admin_users').select('*').eq('user_id', id).maybeSingle();
  if (error) fail(error);
  return data;
};

export const fetchRoles = async () => {
  const { data, error } = await supabase.from('user_roles').select('role_id, role_name').order('role_id');
  if (error) fail(error);
  return data;
};

// ฟังก์ชันใน DB ทำงานแบบ atomic พร้อมตรวจกติกา | ผลลัพธ์ { data, error } ให้ service แปลง error
export const setRole = (actorId, userId, role) =>
  supabase.rpc('fn_admin_user_set_role', { p_actor: actorId, p_user: userId, p_role: role });

export const setStatus = (actorId, userId, status) =>
  supabase.rpc('fn_admin_user_set_status', { p_actor: actorId, p_user: userId, p_status: status });
