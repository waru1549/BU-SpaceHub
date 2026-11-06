import { AppError } from './error.middleware.js';
import { resolveUserFromToken } from '../services/auth.service.js';

const extractToken = (req) => {
  const [scheme, token] = (req.headers.authorization || '').split(' ');
  return scheme === 'Bearer' && token ? token : null;
};

// ต้องล็อกอิน
export const authenticate = async (req, res, next) => {
  const token = extractToken(req);
  if (!token) throw new AppError('Authentication required', 401);
  req.user = await resolveUserFromToken(token);
  next();
};

// route สาธารณะ (เช่น Chat): ถ้ามี token ที่ถูกต้องจะผูก req.user ให้ ถ้าไม่มีก็ผ่านไปเฉย ๆ
export const optionalAuth = async (req, res, next) => {
  const token = extractToken(req);
  if (token) {
    try {
      req.user = await resolveUserFromToken(token);
    } catch {
      // token ใช้ไม่ได้ = ถือว่าเป็นผู้เยี่ยมชม
    }
  }
  next();
};