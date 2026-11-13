import { api } from './api.js';
import { buildListQuery } from '../utils/query.js';

export const getAvailability = async ({ borrowDate, returnDate, onlyBorrowable }) => {
  const qs = new URLSearchParams({ borrow_date: borrowDate, return_date: returnDate });
  if (onlyBorrowable) qs.set('only_borrowable', 'true');
  return (await api.get(`/equipment/availability?${qs}`)).data;
};

export const createBooking = async ({ resourceId, borrowDate, returnDate, purpose }) =>
  (
    await api.post('/equipment/bookings', {
      resource_id: resourceId,
      borrow_date: borrowDate,
      return_date: returnDate,
      purpose,
    })
  ).data;

export const getMyBookings = async (params) => {
  const json = await api.get(`/equipment/bookings/mine?${buildListQuery(params)}`);
  return { rows: json.data, meta: json.meta };
};

export const getAllEquipmentBookings = async (params) => {
  const json = await api.get(`/equipment/bookings?${buildListQuery(params)}`);
  return { rows: json.data, meta: json.meta };
};

// action: 'cancel' | 'approve' | 'reject' | 'receive' | 'return' ; body ใช้เฉพาะ return { fine_amount, fine_reason }
export const changeBookingStatus = async (bookingId, action, body) =>
  (await api.post(`/equipment/bookings/${bookingId}/${action}`, body)).data;

export const getMyFines = async (params) => {
  const json = await api.get(`/equipment/fines/mine?${buildListQuery(params)}`);
  return { rows: json.data, meta: json.meta };
};

export const getAllFines = async (params) => {
  const json = await api.get(`/equipment/fines?${buildListQuery(params)}`);
  return { rows: json.data, meta: json.meta };
};

// action: 'pay' | 'waive'
export const settleFine = async (fineId, action) => (await api.post(`/equipment/fines/${fineId}/${action}`)).data;
