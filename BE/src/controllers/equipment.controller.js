import { sendSuccess } from '../utils/response.js';
import * as service from '../services/equipment.service.js';

const STATUS_MESSAGE = {
  APPROVE: 'อนุมัติคำขอยืมแล้ว',
  REJECT: 'ปฏิเสธคำขอยืมแล้ว',
  CANCEL: 'ยกเลิกคำขอยืมแล้ว',
  RECEIVE: 'ส่งมอบอุปกรณ์แล้ว',
  RETURN: 'รับคืนอุปกรณ์แล้ว',
};

export const getAvailability = async (req, res) =>
  sendSuccess(res, await service.getAvailability(req.query));

export const createBooking = async (req, res) =>
  sendSuccess(res, await service.createBooking(req.user, req.body), 'สร้างคำขอยืมสำเร็จ รออนุมัติ', 201);

export const getMyBookings = async (req, res) => {
  const { rows, meta } = await service.getMyBookings(req.user, req.query);
  return sendSuccess(res, rows, 'OK', 200, meta);
};

export const getAllBookings = async (req, res) => {
  const { rows, meta } = await service.getAllBookings(req.user, req.query);
  return sendSuccess(res, rows, 'OK', 200, meta);
};

export const changeStatus = (action) => async (req, res) =>
  sendSuccess(res, await service.changeStatus(req.user, req.params.id, action, req.body), STATUS_MESSAGE[action]);

export const getMyFines = async (req, res) => {
  const { rows, meta } = await service.getMyFines(req.user, req.query);
  return sendSuccess(res, rows, 'OK', 200, meta);
};

export const getAllFines = async (req, res) => {
  const { rows, meta } = await service.getAllFines(req.query);
  return sendSuccess(res, rows, 'OK', 200, meta);
};

export const settleFine = (status, message) => async (req, res) =>
  sendSuccess(res, await service.settleFine(req.params.id, status), message);
