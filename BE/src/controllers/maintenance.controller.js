import { sendSuccess } from '../utils/response.js';
import * as service from '../services/maintenance.service.js';

const STATUS_MESSAGE = {
  START: 'เริ่มดำเนินการซ่อมแล้ว',
  COMPLETE: 'ปิดงานซ่อมแล้ว',
  REJECT: 'ปฏิเสธงานแจ้งซ่อมแล้ว',
  CANCEL: 'ยกเลิกงานแจ้งซ่อมแล้ว',
};

export const listResources = async (_req, res) => sendSuccess(res, await service.listResources());
export const listStaff = async (_req, res) => sendSuccess(res, await service.listAssignableStaff());

export const createRequest = async (req, res) =>
  sendSuccess(res, await service.createRequest(req.user, req.body), 'ส่งเรื่องแจ้งซ่อมสำเร็จ รอรับเรื่อง', 201);

export const getMyRequests = async (req, res) => {
  const { rows, meta } = await service.getMyRequests(req.user, req.query);
  return sendSuccess(res, rows, 'OK', 200, meta);
};

export const getAllRequests = async (req, res) => {
  const { rows, meta } = await service.getAllRequests(req.user, req.query);
  return sendSuccess(res, rows, 'OK', 200, meta);
};

export const getRequest = async (req, res) => sendSuccess(res, await service.getRequest(req.user, req.params.id));

export const assign = async (req, res) =>
  sendSuccess(res, await service.assign(req.user, req.params.id, req.body), 'มอบหมายงานแล้ว');

export const changeStatus = (action) => async (req, res) =>
  sendSuccess(res, await service.changeStatus(req.user, req.params.id, action, req.body), STATUS_MESSAGE[action]);

export const signUploads = async (req, res) =>
  sendSuccess(res, await service.signUploads(req.user, req.params.id, req.body));

export const confirmUploads = async (req, res) =>
  sendSuccess(res, await service.confirmUploads(req.user, req.params.id, req.body), 'บันทึกรูปแนบแล้ว', 201);

export const deleteAttachment = async (req, res) =>
  sendSuccess(res, await service.deleteAttachment(req.user, req.params.id, req.params.attachmentId), 'ลบรูปแล้ว');
