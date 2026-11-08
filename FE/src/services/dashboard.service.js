import { api } from './api.js';

export const getKpi = async () => (await api.get('/dashboard/kpi')).data;

export const getTrend = async () => (await api.get('/dashboard/trend')).data;

export const getTable = async (name, { page, limit, sort, order, filters = {} }) => {
  const qs = new URLSearchParams({ page, limit, sort, order });
  Object.entries(filters).forEach(([key, value]) => {
    if (value) qs.set(key, value);
  });
  const json = await api.get(`/dashboard/tables/${name}?${qs}`);
  return { rows: json.data, meta: json.meta };
};