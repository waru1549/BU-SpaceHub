import { sendError } from '../utils/response.js';
import { logger } from '../utils/logger.js';

// ใช้ throw new AppError('ข้อความ', 404) ได้จากทุกที่
export class AppError extends Error {
  constructor(message, status = 500, details) {
    super(message);
    this.name = 'AppError';
    this.status = status;
    this.details = details;
  }
}

export const notFound = (req, res) =>
  sendError(res, `Route not found: ${req.method} ${req.originalUrl}`, 404);

// Express จะรู้ว่าเป็น error handler จากการมี 4 พารามิเตอร์
export const errorHandler = (err, req, res, next) => {
  if (err.type === 'entity.parse.failed') return sendError(res, 'Invalid JSON body', 400);
  if (err.type === 'entity.too.large') return sendError(res, 'Request body too large', 413);

  const status = err.status || 500;
  const isProd = process.env.NODE_ENV === 'production';

  if (status >= 500) logger.error(err);

  const message = status >= 500 && isProd ? 'Internal Server Error' : err.message;
  const details = isProd ? undefined : err.details; // ไม่เปิดรายละเอียดภายในบน production
  return sendError(res, message, status, details);
};