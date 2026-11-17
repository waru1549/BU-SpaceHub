import { api } from './api.js';
import { buildListQuery } from '../utils/query.js';

const BASE = '/admin/users';

export const listUsers = async (params) => {
  const json = await api.get(`${BASE}?${buildListQuery(params)}`);
  return { rows: json.data, meta: json.meta };
};

export const getUserOptions = async () => (await api.get(`${BASE}/options`)).data;

// คืนแถวผู้ใช้หลังเปลี่ยน
export const changeUserRole = async (id, role) => (await api.put(`${BASE}/${id}/role`, { role })).data;
export const changeUserStatus = async (id, status) => (await api.put(`${BASE}/${id}/status`, { status })).data;
