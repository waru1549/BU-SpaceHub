import rateLimit from 'express-rate-limit';
import { sendError } from '../utils/response.js';

export const createLimiter = ({
  windowMs,
  limit,
  message = 'Too many requests, please try again later',
}) =>
  rateLimit({
    windowMs,
    limit,
    standardHeaders: true,
    legacyHeaders: false,
    handler: (req, res) => sendError(res, message, 429),
  });

// ทั้ง API: 300 ครั้ง / 15 นาที / IP
export const apiLimiter = createLimiter({ windowMs: 15 * 60 * 1000, limit: 300 });