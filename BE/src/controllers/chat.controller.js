import { sendSuccess } from '../utils/response.js';
import * as service from '../services/chat.service.js';
import { hashIp } from '../utils/chatGuard.js';

export const ask = async (req, res) => {
  const { message, history, sessionId } = req.body ?? {};
  const data = await service.ask(
    { message, history, sessionId },
    { ipHash: hashIp(req.ip), userId: req.user?.userId ?? null },
  );
  return sendSuccess(res, data);
};

export const suggestions = async (req, res) => sendSuccess(res, service.SUGGESTIONS);

// ใช้ตรวจว่า token ที่แนบมา BE มองว่าเป็นใคร (ไม่คืนข้อมูลส่วนบุคคล)
export const whoami = async (req, res) =>
  sendSuccess(res, { authenticated: Boolean(req.user), role: req.user?.role ?? null, hasUserId: req.user?.userId != null });