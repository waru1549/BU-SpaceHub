import { supabase } from '../config/supabase.js';
import { AppError } from '../middleware/error.middleware.js';

const fail = (error) => {
  throw new AppError('Database query failed', 500, error);
};

// ---------- อ่าน ----------
export const fetchResourcesPage = async ({ from, to, sort, ascending, filters, search }) => {
  let q = supabase.from('v_admin_resources').select('*', { count: 'exact' });
  Object.entries(filters).forEach(([col, val]) => {
    q = q.eq(col, val);
  });
  if (search) {
    q = q.or(['resource_code', 'resource_name', 'location'].map((c) => `${c}.ilike.%${search}%`).join(','));
  }
  q = q.order(sort, { ascending, nullsFirst: false });
  if (sort !== 'resource_id') q = q.order('resource_id', { ascending: true });

  const { data, count, error } = await q.range(from, to);
  if (error?.code === 'PGRST103') {
    let head = supabase.from('v_admin_resources').select('*', { count: 'exact', head: true });
    Object.entries(filters).forEach(([col, val]) => {
      head = head.eq(col, val);
    });
    if (search) head = head.or(['resource_code', 'resource_name', 'location'].map((c) => `${c}.ilike.%${search}%`).join(','));
    const h = await head;
    if (h.error) fail(h.error);
    return { rows: [], total: h.count ?? 0 };
  }
  if (error) fail(error);
  return { rows: data, total: count ?? 0 };
};

export const findResource = async (id) => {
  const { data, error } = await supabase.from('v_admin_resources').select('*').eq('resource_id', id).maybeSingle();
  if (error) fail(error);
  return data;
};

export const fetchOptions = async () => {
  const [cats, statuses] = await Promise.all([
    supabase.from('resource_categories').select('type_id, type_name').order('type_id'),
    supabase.from('resource_status').select('resource_status_id, resource_status_name').order('resource_status_id'),
  ]);
  if (cats.error) fail(cats.error);
  if (statuses.error) fail(statuses.error);
  return { categories: cats.data, statuses: statuses.data };
};

export const fetchSchedulesPage = async ({ resourceId, dateFrom, dateTo, from, to }) => {
  let q = supabase.from('v_admin_schedules').select('*', { count: 'exact' }).eq('resource_id', resourceId).gte('work_date', dateFrom);
  if (dateTo) q = q.lte('work_date', dateTo);
  q = q.order('work_date').order('start_time').order('schedule_id');
  const { data, count, error } = await q.range(from, to);
  if (error?.code === 'PGRST103') {
    let head = supabase.from('v_admin_schedules').select('*', { count: 'exact', head: true }).eq('resource_id', resourceId).gte('work_date', dateFrom);
    if (dateTo) head = head.lte('work_date', dateTo);
    const h = await head;
    if (h.error) fail(h.error);
    return { rows: [], total: h.count ?? 0 };
  }
  if (error) fail(error);
  return { rows: data, total: count ?? 0 };
};

export const findSchedule = async (kind, scheduleId) => {
  const { data, error } = await supabase
    .from('v_admin_schedules').select('kind, schedule_id, resource_id')
    .eq('kind', kind).eq('schedule_id', scheduleId).maybeSingle();
  if (error) fail(error);
  return data;
};

// ---------- เขียน (ฟังก์ชันใน DB ทำงานแบบ atomic) ----------
export const createResource = (a) =>
  supabase.rpc('fn_admin_resource_create', {
    p_code: a.code, p_name: a.name, p_type_id: a.typeId, p_location: a.location,
    p_capacity: a.capacity, p_quantity: a.quantity, p_description: a.description, p_status: a.status,
  });

export const updateResource = (id, a) =>
  supabase.rpc('fn_admin_resource_update', {
    p_resource_id: id, p_code: a.code, p_name: a.name, p_location: a.location,
    p_capacity: a.capacity, p_quantity: a.quantity, p_description: a.description, p_status: a.status,
  });

export const deleteResource = (id) => supabase.rpc('fn_admin_resource_delete', { p_resource_id: id });

export const generateSchedules = (id, a) =>
  supabase.rpc('fn_admin_generate_schedules', {
    p_resource_id: id, p_date_from: a.dateFrom, p_date_to: a.dateTo,
    p_weekdays: a.weekdays, p_slots: a.slots, p_max_slots: a.maxSlots,
  });

export const setScheduleBlock = (kind, scheduleId, blocked) =>
  supabase.rpc('fn_admin_schedule_set_block', { p_kind: kind, p_schedule_id: scheduleId, p_blocked: blocked });

export const deleteSchedule = (kind, scheduleId) =>
  supabase.rpc('fn_admin_schedule_delete', { p_kind: kind, p_schedule_id: scheduleId });
