import { supabase } from '../config/supabase.js';
import { AppError } from '../middleware/error.middleware.js';
export { fetchPage } from './dashboard.repository.js';

const fail = (error) => { throw new AppError('Database query failed', 500, error); };

// ตั้งสถานะ OVERDUE ให้รายการที่เลยกำหนดคืน (เรียกก่อนอ่านรายการ/สต็อกทุกครั้ง)
export const syncOverdue = async () => {
  const { error } = await supabase.rpc('fn_equipment_sync_overdue');
  if (error) fail(error);
};

export const listEquipment = async () => {
  const { data, error } = await supabase
    .from('resources')
    .select('resource_id, resource_code, resource_name, location, quantity, description, resource_categories!inner(type_name), resource_status(resource_status_name)')
    .eq('resource_categories.type_name', 'EQUIPMENT')
    .order('resource_code', { ascending: true });
  if (error) fail(error);
  return data.map(({ resource_categories: _category, resource_status: status, ...item }) => ({
    ...item,
    resource_status: status?.resource_status_name ?? null,
  }));
};

export const getStock = async (borrow, ret) => {
  const { data, error } = await supabase.rpc('fn_equipment_availability', { p_borrow: borrow, p_return: ret });
  if (error) fail(error);
  return data;
};

export const getBookingById = async (bookingId) => {
  const { data, error } = await supabase
    .from('v_equipment_booking_summary')
    .select('*')
    .eq('booking_id', bookingId)
    .single();
  if (error) fail(error);
  return data;
};

export const createBooking = (userId, resourceId, borrow, ret, purpose) =>
  supabase.rpc('fn_equipment_create_booking', {
    p_user_id: userId,
    p_resource_id: resourceId,
    p_borrow: borrow,
    p_return: ret,
    p_purpose: purpose,
  });

export const changeStatus = (bookingId, action, actorId, actorIsStaff, fineAmount, fineReason) =>
  supabase.rpc('fn_equipment_change_status', {
    p_booking_id: bookingId,
    p_action: action,
    p_actor_id: actorId,
    p_actor_is_staff: actorIsStaff,
    p_fine_amount: fineAmount,
    p_fine_reason: fineReason,
  });

// เปลี่ยนสถานะค่าปรับ UNPAID -> PAID/WAIVED แบบ atomic (ไม่แก้ซ้ำถ้าไม่ใช่ UNPAID)
export const settleFine = async (fineId, status) => {
  const { data, error } = await supabase
    .from('fines')
    .update({ fine_status: status })
    .eq('fine_id', fineId)
    .eq('fine_status', 'UNPAID')
    .select('fine_id, booking_id, fine_amount, fine_status');
  if (error) fail(error);
  return data;
};

export const fineExists = async (fineId) => {
  const { data, error } = await supabase.from('fines').select('fine_id').eq('fine_id', fineId).limit(1);
  if (error) fail(error);
  return data.length > 0;
};
