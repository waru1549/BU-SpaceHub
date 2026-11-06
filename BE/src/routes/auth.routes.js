import { Router } from 'express';
import { authenticate } from '../middleware/auth.middleware.js';
import { requireRole, ROLES } from '../middleware/role.middleware.js';
import * as authController from '../controllers/auth.controller.js';

const router = Router();

router.get('/me', authenticate, authController.getMe);

// ชั่วคราว: ไว้ทดสอบ role middleware (จะลบตอน Step 8)
router.get('/role-test', authenticate, requireRole(ROLES.STAFF, ROLES.ADMIN), authController.roleTest);

export default router;