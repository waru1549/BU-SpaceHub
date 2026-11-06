import { supabase } from '../config/supabase.js';
import { AppError } from '../middleware/error.middleware.js';

const USER_SELECT =
  'user_id, auth_user_id, user_code, full_name, email, user_status, role:user_roles(role_name)';

const check = (error, message) => {
  if (error) throw new AppError(message, 500, error.message);
};

export const findByAuthId = async (authUserId) => {
  const { data, error } = await supabase
    .from('users').select(USER_SELECT).eq('auth_user_id', authUserId).maybeSingle();
  check(error, 'Failed to query user');
  return data;
};

export const findByEmail = async (email) => {
  const { data, error } = await supabase
    .from('users').select(USER_SELECT).eq('email', email).maybeSingle();
  check(error, 'Failed to query user');
  return data;
};

// ผูกได้เฉพาะแถวที่ยังไม่เคยผูก (กันเขียนทับ)
export const linkAuthId = async (userId, authUserId) => {
  const { error } = await supabase
    .from('users').update({ auth_user_id: authUserId })
    .eq('user_id', userId).is('auth_user_id', null);
  check(error, 'Failed to link account');
};

export const createStudent = async ({ authUserId, email, fullName }) => {
  const { data: role, error: roleError } = await supabase
    .from('user_roles').select('role_id').eq('role_name', 'USER').single();
  check(roleError, 'Role USER not found');

  const { data, error } = await supabase
    .from('users')
    .insert({
      auth_user_id: authUserId,
      email,
      full_name: fullName,
      role_id: role.role_id,
      user_status: 'ACTIVE',
    })
    .select('user_id').single();

  // ล็อกอินครั้งแรกพร้อมกัน 2 คำขอ: ตัวที่สองจะชน unique ให้ใช้แถวที่มีอยู่
  if (error?.code === '23505') return findByAuthId(authUserId);
  check(error, 'Failed to create user');

  const userCode = `U${String(data.user_id).padStart(4, '0')}`;
  const { error: codeError } = await supabase
    .from('users').update({ user_code: userCode }).eq('user_id', data.user_id);
  check(codeError, 'Failed to set user code');

  return findByAuthId(authUserId);
};

export const touchLastLogin = async (userId) => {
  const { error } = await supabase
    .from('users').update({ last_login: new Date().toISOString() }).eq('user_id', userId);
  check(error, 'Failed to update last login');
};