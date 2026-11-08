import { Router } from 'express';
import { authenticate } from '../middleware/auth.middleware.js';
import { ROLES, requireRole } from '../middleware/role.middleware.js';
import * as controller from '../controllers/rooms.controller.js';

const router = Router();
const staffOnly = requireRole(ROLES.STAFF, ROLES.ADMIN);

router.use(authenticate);

router.get('/availability', controller.getAvailability);

router.get('/bookings/mine', controller.getMyBookings);
router.get('/bookings', staffOnly, controller.getAllBookings);
router.post('/bookings', controller.createBooking);

// ยกเลิก: เจ้าของหรือเจ้าหน้าที่ (ฟังก์ชันใน DB ตรวจความเป็นเจ้าของ)
router.post('/bookings/:id/cancel', controller.changeStatus('CANCEL'));
router.post('/bookings/:id/approve', staffOnly, controller.changeStatus('APPROVE'));
router.post('/bookings/:id/reject', staffOnly, controller.changeStatus('REJECT'));
router.post('/bookings/:id/complete', staffOnly, controller.changeStatus('COMPLETE'));

export default router;