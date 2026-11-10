import { api } from './api.js';
import { buildListQuery } from '../utils/query.js';

export const getAvailability = async ({ date, onlyBookable }) => {
  const qs = new URLSearchParams({ date });
  if (onlyBookable) qs.set('only_bookable', 'true');
  return (await api.get(`/printers/availability?${qs}`)).data;
};

export const createBooking = async ({ scheduleId, purpose, material, estWeightG }) => {
  const body = { schedule_id: scheduleId, purpose, material };
  if (estWeightG !== null && estWeightG !== undefined) body.est_weight_g = estWeightG;
  return (await api.post('/printers/bookings', body)).data;
};

export const getMyBookings = async (params) => {
  const json = await api.get(`/printers/bookings/mine?${buildListQuery(params)}`);
  return { rows: json.data, meta: json.meta };
};

export const getAllPrinterBookings = async (params) => {
  const json = await api.get(`/printers/bookings?${buildListQuery(params)}`);
  return { rows: json.data, meta: json.meta };
};

// action: 'cancel' | 'approve' | 'reject' | 'start' | 'complete' | 'receive'
export const changeBookingStatus = async (bookingId, action) =>
  (await api.post(`/printers/bookings/${bookingId}/${action}`)).data;
