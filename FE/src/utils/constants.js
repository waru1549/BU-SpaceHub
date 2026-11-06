export const APP_NAME = 'BU SpaceHub';
export const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:5000/api';
export const ROLES = Object.freeze({ USER: 'USER', STAFF: 'STAFF', ADMIN: 'ADMIN' });

// ตัวช่วยให้ Google แสดงเฉพาะบัญชีโดเมนนี้ก่อน (เป็นแค่ hint ตัวบังคับจริงอยู่ที่ BE)
export const GOOGLE_DOMAIN_HINT = 'bumail.net';