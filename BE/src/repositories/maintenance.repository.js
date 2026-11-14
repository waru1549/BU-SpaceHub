import { supabase } from '../config/supabase.js';
import { AppError } from '../middleware/error.middleware.js';
export { fetchPage } from './dashboard.repository.js';

const fail = (error) => { throw new AppError('Database query failed', 500, error); };
export const BUCKET = 'maintenance-images';

// ทรัพยากรทั้งหมดสำหรับเลือกแจ้งซ่อม
export const listResources = async () => {
  const { data, error } = await supabase
    .from('resources')
    .select('resource_id, resource_code, resource_name, location, resource_categories(type_name), resource_status(resource_status_name)')
    .order('resource_code', { ascending: true });
  if (error) fail(error);
  return data.map(({ resource_categories: c, resource_status: s, ...r }) => ({
    ...r,
    category: c?.type_name ?? null,
    resource_status: s?.resource_status_name ?? null,
  }));
};

// Staff/Admin ที่รับมอบหมายงานได้
export const listAssignableStaff = async () => {
  const { data, error } = await supabase
    .from('users')
    .select('user_id, full_name, email, user_roles!inner(role_name)')
    .eq('user_status', 'ACTIVE')
    .in('user_roles.role_name', ['STAFF', 'ADMIN'])
    .order('full_name', { ascending: true });
  if (error) fail(error);
  return data.map(({ user_roles: role, ...u }) => ({ ...u, role: role?.role_name ?? null }));
};

export const getRequestById = async (bookingId) => {
  const { data, error } = await supabase
    .from('v_maintenance_requests')
    .select('*')
    .eq('booking_id', bookingId)
    .maybeSingle();
  if (error) fail(error);
  return data;
};

export const createRequest = (userId, resourceId, location, title, description) =>
  supabase.rpc('fn_maintenance_create_booking', {
    p_user_id: userId,
    p_resource_id: resourceId,
    p_location: location,
    p_title: title,
    p_description: description,
  });

export const assignRequest = (bookingId, assigneeId, actorIsAdmin) =>
  supabase.rpc('fn_maintenance_assign', {
    p_booking_id: bookingId,
    p_assignee_id: assigneeId,
    p_actor_is_admin: actorIsAdmin,
  });

export const changeStatus = (bookingId, action, actorId, isStaff, isAdmin, note) =>
  supabase.rpc('fn_maintenance_change_status', {
    p_booking_id: bookingId,
    p_action: action,
    p_actor_id: actorId,
    p_actor_is_staff: isStaff,
    p_actor_is_admin: isAdmin,
    p_note: note,
  });

// ---------- attachments ----------
export const listAttachments = async (bookingId) => {
  const { data, error } = await supabase
    .from('attachments')
    .select('attachment_id, booking_id, file_name, file_path, upload_date')
    .eq('booking_id', bookingId)
    .order('attachment_id', { ascending: true });
  if (error) fail(error);
  return data;
};

export const getAttachment = async (attachmentId) => {
  const { data, error } = await supabase
    .from('attachments')
    .select('attachment_id, booking_id, file_name, file_path')
    .eq('attachment_id', attachmentId)
    .maybeSingle();
  if (error) fail(error);
  return data;
};

export const insertAttachments = (rows) =>
  supabase.from('attachments').insert(rows).select('attachment_id, file_name, file_path');

export const deleteAttachmentRow = async (attachmentId) => {
  const { error } = await supabase.from('attachments').delete().eq('attachment_id', attachmentId);
  if (error) fail(error);
};

export const createSignedUpload = (path) => supabase.storage.from(BUCKET).createSignedUploadUrl(path);

export const createSignedRead = async (path, seconds = 3600) => {
  const { data, error } = await supabase.storage.from(BUCKET).createSignedUrl(path, seconds);
  if (error) return null;
  return data?.signedUrl ?? null;
};

// ชื่อไฟล์ที่มีอยู่จริงในโฟลเดอร์ของงาน (ตรวจว่า FE อัปโหลดสำเร็จก่อนบันทึก)
export const listStoredNames = async (folder) => {
  const { data, error } = await supabase.storage.from(BUCKET).list(folder, { limit: 100 });
  if (error) fail(error);
  return new Set((data ?? []).map((f) => f.name));
};

export const removeStored = (paths) => supabase.storage.from(BUCKET).remove(paths);
