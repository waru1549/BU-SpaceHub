import { sendSuccess } from '../utils/response.js';
import * as service from '../services/adminResources.service.js';

export const options = async (_req, res) => sendSuccess(res, await service.getOptions());

export const list = async (req, res) => {
  const { rows, meta } = await service.list(req.query);
  return sendSuccess(res, rows, 'OK', 200, meta);
};

export const get = async (req, res) => sendSuccess(res, await service.get(req.params.id));

export const create = async (req, res) => sendSuccess(res, await service.create(req.body), 'เพิ่มทรัพยากรสำเร็จ', 201);

export const update = async (req, res) => sendSuccess(res, await service.update(req.params.id, req.body), 'บันทึกการแก้ไขแล้ว');

export const remove = async (req, res) => {
  const data = await service.remove(req.params.id);
  const message = data.result === 'DELETED'
    ? 'ลบทรัพยากรแล้ว'
    : 'ทรัพยากรนี้มีประวัติการใช้งาน จึงปิดเป็น "งดให้บริการ" แทนการลบ';
  return sendSuccess(res, data, message);
};

export const listSchedules = async (req, res) => {
  const { rows, meta } = await service.listSchedules(req.params.id, req.query);
  return sendSuccess(res, rows, 'OK', 200, meta);
};

export const generate = async (req, res) => {
  const data = await service.generate(req.params.id, req.body);
  return sendSuccess(res, data, `สร้างช่วงเวลา ${data.inserted} ช่วง (ข้ามที่ซ้ำ/ซ้อนทับ ${data.skipped} ช่วง)`, 201);
};

export const setBlock = async (req, res) => {
  const { id, kind, scheduleId } = req.params;
  const data = await service.setBlock(id, kind, scheduleId, req.body);
  return sendSuccess(res, data, data.schedule_status === 'BLOCKED' ? 'บล็อกช่วงเวลาแล้ว' : 'ปลดบล็อกแล้ว');
};

export const removeSchedule = async (req, res) => {
  const { id, kind, scheduleId } = req.params;
  return sendSuccess(res, await service.removeSchedule(id, kind, scheduleId), 'ลบช่วงเวลาแล้ว');
};
