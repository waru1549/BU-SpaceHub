import { sendSuccess } from '../utils/response.js';
import * as service from '../services/adminUsers.service.js';

export const options = async (_req, res) => sendSuccess(res, await service.getOptions());

export const list = async (req, res) => {
  const { rows, meta } = await service.list(req.query);
  return sendSuccess(res, rows, 'OK', 200, meta);
};

export const get = async (req, res) => sendSuccess(res, await service.get(req.params.id));

export const changeRole = async (req, res) =>
  sendSuccess(res, await service.changeRole(req.user, req.params.id, req.body), 'เปลี่ยนบทบาทแล้ว');

export const changeStatus = async (req, res) => {
  const data = await service.changeStatus(req.user, req.params.id, req.body);
  return sendSuccess(res, data, data.user_status === 'ACTIVE' ? 'เปิดใช้งานบัญชีแล้ว' : 'ระงับ/ปิดบัญชีแล้ว');
};
