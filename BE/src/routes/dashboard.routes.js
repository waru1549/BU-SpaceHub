import { Router } from 'express';
import { authenticate } from '../middleware/auth.middleware.js';
import * as controller from '../controllers/dashboard.controller.js';

const router = Router();

// ทุก route ต้องล็อกอิน; สิทธิ์ราย role ของแต่ละตารางตรวจใน service
router.use(authenticate);
router.get('/kpi', controller.getKpi);
router.get('/trend', controller.getTrend);
router.get('/system/:module', controller.getSystem);
router.get('/tables/:name', controller.getTable);

export default router;