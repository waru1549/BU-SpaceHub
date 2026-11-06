// รูปแบบ response เดียวกันทั้งระบบ
export const sendSuccess = (res, data = null, message = 'OK', status = 200, meta) => {
  const body = { success: true, message, data };
  if (meta) body.meta = meta; // ใช้กับ pagination ใน Step ถัดไป
  return res.status(status).json(body);
};

export const sendError = (res, message = 'Internal Server Error', status = 500, details) => {
  const body = { success: false, message };
  if (details) body.details = details;
  return res.status(status).json(body);
};