import { AppError } from './error.middleware.js';
import { logRateLimited } from '../services/chat.service.js';
import { hashIp } from '../utils/chatGuard.js';

// Rate limit แบบ sliding window ในหน่วยความจำ: จำกัดต่อ IP (hash) | ค่าเริ่มต้น 10 ข้อความ/นาที
// หมายเหตุ: ต้องตั้ง TRUST_PROXY=1 เมื่อ deploy หลัง proxy (Render/Railway) ไม่งั้น req.ip จะเป็น IP ของ proxy
const hits = new Map();

const limit = () => Number(process.env.CHAT_RATE_LIMIT) || 10;
const windowMs = () => Number(process.env.CHAT_RATE_WINDOW_MS) || 60_000;

const sweep = setInterval(() => {
  const cutoff = Date.now() - windowMs();
  for (const [key, list] of hits) {
    const fresh = list.filter((t) => t > cutoff);
    if (fresh.length) hits.set(key, fresh);
    else hits.delete(key);
  }
}, 60_000);
sweep.unref();

export const resetChatRateLimit = () => hits.clear();

export const chatRateLimit = (req, res, next) => {
  const ipHash = hashIp(req.ip);
  const now = Date.now();
  const list = (hits.get(ipHash) ?? []).filter((t) => t > now - windowMs());

  res.setHeader('X-RateLimit-Limit', String(limit()));
  if (list.length >= limit()) {
    const retryAfter = Math.max(1, Math.ceil((list[0] + windowMs() - now) / 1000));
    hits.set(ipHash, list);
    res.setHeader('Retry-After', String(retryAfter));
    res.setHeader('X-RateLimit-Remaining', '0');
    logRateLimited(req.body?.message, { ipHash, userId: req.user?.userId, sessionId: req.body?.sessionId }).catch(() => {});
    return next(new AppError(`ส่งข้อความถี่เกินไป กรุณารอ ${retryAfter} วินาทีแล้วลองใหม่`, 429));
  }
  list.push(now);
  hits.set(ipHash, list);
  res.setHeader('X-RateLimit-Remaining', String(limit() - list.length));
  return next();
};
