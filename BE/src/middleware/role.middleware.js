import { AppError } from './error.middleware.js';

export const ROLES = Object.freeze({ USER: 'USER', STAFF: 'STAFF', ADMIN: 'ADMIN' });

// ใช้หลัง authenticate เสมอ เช่น requireRole(ROLES.STAFF, ROLES.ADMIN)
export const requireRole = (...allowed) => (req, res, next) => {
  if (!req.user) throw new AppError('Authentication required', 401);
  if (!allowed.includes(req.user.role)) {
    throw new AppError('You do not have permission to access this resource', 403);
  }
  next();
};