import { api } from './api.js';
import { buildListQuery } from '../utils/query.js';

export const getAvailability = async ({ date, onlyBookable, minCapacity }) => {
  const qs = new URLSearchParams({ date });
  if (onlyBookable) qs.set('only_bookable', 'true');
  if (minCapacity) qs.set('min_capacity', String(minCapacity));
  return (await api.get(`/rooms/availability?${qs}`)).data;
};

export const createBooking = async ({ scheduleId, purpose }) =>
  (await api.post('/rooms/bookings', { schedule_id: scheduleId, purpose })).data;

export const getMyBookings = async (params) => {
  const json = await api.get(`/rooms/bookings/mine?${buildListQuery(params)}`);
  return { rows: json.data, meta: json.meta };
};

// action: 'cancel' | 'approve' | 'reject' | 'complete'
export const changeBookingStatus = async (bookingId, action) =>
  (await api.post(`/rooms/bookings/${bookingId}/${action}`)).data;