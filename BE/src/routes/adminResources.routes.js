import { Router } from 'express';
import { authenticate } from '../middleware/auth.middleware.js';
import { ROLES, requireRole } from '../middleware/role.middleware.js';
import * as controller from '../controllers/adminResources.controller.js';

const router = Router();

// ทุก endpoint ใช้ได้เฉพาะ ADMIN
router.use(authenticate, requireRole(ROLES.ADMIN));

router.get('/options', controller.options);
router.get('/', controller.list);
router.post('/', controller.create);
router.get('/:id', controller.get);
router.put('/:id', controller.update);
router.delete('/:id', controller.remove);

router.get('/:id/schedules', controller.listSchedules);
router.post('/:id/schedules/generate', controller.generate);
router.post('/:id/schedules/:kind/:scheduleId/block', controller.setBlock);
router.delete('/:id/schedules/:kind/:scheduleId', controller.removeSchedule);

export default router;
