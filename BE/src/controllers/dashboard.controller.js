import { sendSuccess } from '../utils/response.js';
import * as service from '../services/dashboard.service.js';

export const getKpi = async (req, res) => sendSuccess(res, await service.getKpi());

export const getTrend = async (req, res) => sendSuccess(res, await service.getTrend());

export const getSystem = async (req, res) => sendSuccess(res, await service.getSystem(req.params.module));

export const getTable = async (req, res) => {
  const { rows, meta } = await service.getTable(req.params.name, req.user.role, req.query);
  return sendSuccess(res, rows, 'OK', 200, meta);
};