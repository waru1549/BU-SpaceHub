import { sendSuccess } from '../utils/response.js';
import * as service from '../services/printers.service.js';

const STATUS_MESSAGE = {
  APPROVE: 'อนุมัติการจองแล้ว',
  REJECT: 'ปฏิเสธการจองแล้ว',
  CANCEL: 'ยกเลิกการจองแล้ว',
  START: 'เริ่มพิมพ์งานแล้ว',
  COMPLETE: 'บันทึกว่าพิมพ์เสร็จแล้ว รอผู้ใช้มารับงาน',
  RECEIVE: 'ยืนยันการรับงานแล้ว',
};

export const getAvailability = async (req, res) =>
  sendSuccess(res, await service.getAvailability(req.query));

export const createBooking = async (req, res) =>
  sendSuccess(res, await service.createBooking(req.user, req.body), 'สร้างการจองสำเร็จ รออนุมัติ', 201);

export const getMyBookings = async (req, res) => {
  const { rows, meta } = await service.getMyBookings(req.user, req.query);
  return sendSuccess(res, rows, 'OK', 200, meta);
};

export const getAllBookings = async (req, res) => {
  const { rows, meta } = await service.getAllBookings(req.user, req.query);
  return sendSuccess(res, rows, 'OK', 200, meta);
};

export const changeStatus = (action) => async (req, res) =>
  sendSuccess(res, await service.changeStatus(req.user, req.params.id, action), STATUS_MESSAGE[action]);
