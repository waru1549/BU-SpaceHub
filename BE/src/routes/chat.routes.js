import { Router } from 'express';
import { optionalAuth } from '../middleware/auth.middleware.js';
import { chatRateLimit } from '../middleware/chatRateLimit.middleware.js';
import * as controller from '../controllers/chat.controller.js';

const router = Router();

// สาธารณะ: ไม่ต้องล็อกอิน (ถ้าแนบ token ที่ถูกต้องจะบันทึก user_id ด้วย) | จำกัด 10 ข้อความ/นาที/IP
router.get('/suggestions', controller.suggestions);
router.get('/whoami', optionalAuth, controller.whoami);
router.post('/', optionalAuth, chatRateLimit, controller.ask);

export default router;