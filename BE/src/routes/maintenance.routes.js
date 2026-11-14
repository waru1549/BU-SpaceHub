import { Router } from 'express';
import { authenticate } from '../middleware/auth.middleware.js';
import { ROLES, requireRole } from '../middleware/role.middleware.js';
import * as controller from '../controllers/maintenance.controller.js';

const router = Router();
const staffOnly = requireRole(ROLES.STAFF, ROLES.ADMIN);
const adminOnly = requireRole(ROLES.ADMIN);

router.use(authenticate);
router.get('/resources', controller.listResources);
router.get('/staff', adminOnly, controller.listStaff);

router.get('/requests/mine', controller.getMyRequests);
router.get('/requests', staffOnly, controller.getAllRequests);
router.post('/requests', controller.createRequest);
router.get('/requests/:id', controller.getRequest);

router.post('/requests/:id/assign', adminOnly, controller.assign);
router.post('/requests/:id/start', staffOnly, controller.changeStatus('START'));
router.post('/requests/:id/complete', staffOnly, controller.changeStatus('COMPLETE'));
router.post('/requests/:id/reject', staffOnly, controller.changeStatus('REJECT'));
router.post('/requests/:id/cancel', controller.changeStatus('CANCEL'));

router.post('/requests/:id/attachments/sign', controller.signUploads);
router.post('/requests/:id/attachments', controller.confirmUploads);
router.delete('/requests/:id/attachments/:attachmentId', controller.deleteAttachment);

export default router;
