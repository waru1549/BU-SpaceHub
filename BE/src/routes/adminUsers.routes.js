import { Router } from 'express';
import { authenticate } from '../middleware/auth.middleware.js';
import { ROLES, requireRole } from '../middleware/role.middleware.js';
import * as controller from '../controllers/adminUsers.controller.js';

const router = Router();

// ทุก endpoint ใช้ได้เฉพาะ ADMIN
router.use(authenticate, requireRole(ROLES.ADMIN));

router.get('/options', controller.options);
router.get('/', controller.list);
router.get('/:id', controller.get);
router.put('/:id/role', controller.changeRole);
router.put('/:id/status', controller.changeStatus);

export default router;
