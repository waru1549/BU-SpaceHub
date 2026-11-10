import { supabase } from '../config/supabase.js';
import { AppError } from '../middleware/error.middleware.js';
export { fetchPage } from './dashboard.repository.js';

const fail = (error) => { throw new AppError('Database query failed', 500, error); };

export const listPrinters = async () => {
  const { data, error } = await supabase
    .from('resources')
    .select('resource_id, resource_code, resource_name, location, description, resource_categories!inner(type_name), resource_status(resource_status_name)')
    .eq('resource_categories.type_name', 'PRINTER')
    .order('resource_code', { ascending: true });
  if (error) fail(error);
  return data.map(({ resource_categories: _category, resource_status: status, ...printer }) => ({
    ...printer,
    resource_status: status?.resource_status_name ?? null,
  }));
};

export const listSlots = async (date) => {
  const { data, error } = await supabase
    .from('v_printer_slot_availability')
    .select('schedule_id, resource_id, work_date, start_time, end_time, max_slots, booked_slots, remaining_slots, is_bookable')
    .eq('work_date', date)
    .order('start_time', { ascending: true })
    .order('schedule_id', { ascending: true })
    .limit(1000);
  if (error) fail(error);
  return data;
};

export const getBookingById = async (bookingId) => {
  const { data, error } = await supabase
    .from('v_printer_booking_summary')
    .select('*')
    .eq('booking_id', bookingId)
    .single();
  if (error) fail(error);
  return data;
};

export const createBooking = (userId, scheduleId, purpose, material, estWeight) =>
  supabase.rpc('fn_printer_create_booking', {
    p_user_id: userId,
    p_schedule_id: scheduleId,
    p_purpose: purpose,
    p_material: material,
    p_est_weight: estWeight,
  });

export const changeStatus = (bookingId, action, actorId, actorIsStaff) =>
  supabase.rpc('fn_printer_change_status', {
    p_booking_id: bookingId,
    p_action: action,
    p_actor_id: actorId,
    p_actor_is_staff: actorIsStaff,
  });
