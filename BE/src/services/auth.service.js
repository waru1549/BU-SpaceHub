import { supabase } from '../config/supabase.js';
import { AppError } from '../middleware/error.middleware.js';
import * as usersRepo from '../repositories/users.repository.js';

const ALLOWED_DOMAIN = (process.env.ALLOWED_EMAIL_DOMAIN || 'bumail.net').toLowerCase();

const toSessionUser = (u) => ({
  userId: u.user_id,
  authUserId: u.auth_user_id,
  userCode: u.user_code,
  fullName: u.full_name,
  email: u.email,
  role: u.role.role_name,
  status: u.user_status,
});

export const resolveUserFromToken = async (token) => {
  // ให้ Supabase ตรวจว่า token จริงและยังไม่หมดอายุ
  const { data, error } = await supabase.auth.getUser(token);
  if (error || !data?.user) throw new AppError('Invalid or expired token', 401);

  const authUser = data.user;
  const email = authUser.email?.toLowerCase();
  if (!email || !authUser.email_confirmed_at) throw new AppError('Email is not verified', 403);

  // 1) เคยผูกบัญชีแล้ว
  let user = await usersRepo.findByAuthId(authUser.id);

  // 2) Staff/Admin ที่ถูกสร้างไว้ล่วงหน้า: จับคู่ด้วยอีเมลแล้วผูกบัญชี
  if (!user) {
    const byEmail = await usersRepo.findByEmail(email);
    if (byEmail) {
      if (byEmail.auth_user_id) throw new AppError('Email is linked to another account', 403);
      await usersRepo.linkAuthId(byEmail.user_id, authUser.id);
      user = await usersRepo.findByAuthId(authUser.id);
    }
  }

  // 3) นักศึกษาใหม่: ต้องมาจาก Google และเป็น @bumail.net เท่านั้น
  if (!user) {
    const viaGoogle = authUser.app_metadata?.providers?.includes('google');
    if (!viaGoogle || !email.endsWith(`@${ALLOWED_DOMAIN}`)) {
      throw new AppError(`Only @${ALLOWED_DOMAIN} Google accounts or registered staff are allowed`, 403);
    }
    const fullName =
      authUser.user_metadata?.full_name || authUser.user_metadata?.name || email.split('@')[0];
    user = await usersRepo.createStudent({ authUserId: authUser.id, email, fullName });
  }

  if (!user) throw new AppError('Unable to resolve user', 403);
  if (user.user_status !== 'ACTIVE') throw new AppError(`Account is ${user.user_status}`, 403);

  return toSessionUser(user);
};

export const recordLogin = (userId) => usersRepo.touchLastLogin(userId);