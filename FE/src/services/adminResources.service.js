import { api } from './api.js';
import { buildListQuery } from '../utils/query.js';

const BASE = '/admin/resources';

export const getOptions = async () => (await api.get(`${BASE}/options`)).data;

export const listResources = async (params) => {
  const json = await api.get(`${BASE}?${buildListQuery(params)}`);
  return { rows: json.data, meta: json.meta };
};

export const getResource = async (id) => (await api.get(`${BASE}/${id}`)).data;

export const createResource = async (body) => (await api.post(BASE, body)).data;

// PUT แทนที่ทั้งแถว: ต้องส่งทุกฟิลด์ (ฟิลด์ที่ไม่ส่งจะกลายเป็นค่าว่าง)
export const updateResource = async (id, body) => (await api.put(`${BASE}/${id}`, body)).data;

// คืน { message, data: { result: 'DELETED' | 'DEACTIVATED', resource } }
export const deleteResource = async (id) => {
  const json = await api.delete(`${BASE}/${id}`);
  return { message: json.message, ...json.data };
};

export const listSchedules = async (id, params) => {
  const json = await api.get(`${BASE}/${id}/schedules?${buildListQuery(params)}`);
  return { rows: json.data, meta: json.meta };
};

// คืน { message, inserted, skipped }
export const generateSchedules = async (id, body) => {
  const json = await api.post(`${BASE}/${id}/schedules/generate`, body);
  return { message: json.message, ...json.data };
};

export const setScheduleBlock = async (id, kind, scheduleId, blocked) =>
  (await api.post(`${BASE}/${id}/schedules/${kind}/${scheduleId}/block`, { blocked })).data;

export const deleteSchedule = async (id, kind, scheduleId) =>
  (await api.delete(`${BASE}/${id}/schedules/${kind}/${scheduleId}`)).data;
