import { supabase } from './supabase.js';
import { API_URL } from '../utils/constants.js';

export class ApiError extends Error {
  constructor(message, status, details) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.details = details;
  }
}

async function request(path, { method = 'GET', body } = {}) {
  const headers = { 'Content-Type': 'application/json' };

  // แนบ token ของผู้ใช้ปัจจุบัน (ถ้ามี) ไปให้ BE ตรวจ
  const { data } = await supabase.auth.getSession();
  if (data.session) headers.Authorization = `Bearer ${data.session.access_token}`;

  let res;
  try {
    res = await fetch(`${API_URL}${path}`, {
      method,
      headers,
      body: body ? JSON.stringify(body) : undefined,
    });
  } catch {
    throw new ApiError('ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้', 0);
  }

  const json = await res.json().catch(() => null);
  if (!res.ok || !json?.success) {
    throw new ApiError(json?.message || `Request failed (${res.status})`, res.status, json?.details);
  }
  return json; // { success, message, data, meta }
}

export const api = {
  get: (path) => request(path),
  post: (path, body) => request(path, { method: 'POST', body }),
  put: (path, body) => request(path, { method: 'PUT', body }),
  delete: (path) => request(path, { method: 'DELETE' }),
};