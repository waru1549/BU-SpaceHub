import { sendSuccess } from '../utils/response.js';
import * as authService from '../services/auth.service.js';

export const getMe = async (req, res) => {
  await authService.recordLogin(req.user.userId);
  return sendSuccess(res, req.user, 'Authenticated');
};
