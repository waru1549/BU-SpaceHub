import { Router } from 'express';
import { authenticate } from '../middleware/auth.middleware.js';
import * as authController from '../controllers/auth.controller.js';

const router = Router();

router.get('/me', authenticate, authController.getMe);

export default router;