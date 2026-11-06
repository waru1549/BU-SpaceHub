import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { supabase } from './src/config/supabase.js';
import { sendSuccess } from './src/utils/response.js';
import { logger } from './src/utils/logger.js';
import { AppError, notFound, errorHandler } from './src/middleware/error.middleware.js';

const app = express();
const PORT = process.env.PORT || 5000;
const allowedOrigins = (process.env.FRONTEND_URL || 'http://localhost:5173')
  .split(',')
  .map((s) => s.trim());

app.use(helmet());
app.use(
  cors({
    origin: (origin, cb) => {
      // origin ว่าง = เรียกจาก curl/Postman/เซิร์ฟเวอร์ จึงอนุญาต
      if (!origin || allowedOrigins.includes(origin)) return cb(null, true);
      return cb(new AppError('Not allowed by CORS', 403));
    },
    credentials: true,
  })
);
app.use(express.json({ limit: '1mb' }));

// --- Health checks ---
app.get('/api/health', (req, res) =>
  sendSuccess(res, { uptime: process.uptime(), time: new Date().toISOString() }, 'API is running')
);

app.get('/api/health/db', async (req, res) => {
  const { count, error } = await supabase
    .from('user_roles')
    .select('role_id', { count: 'exact', head: true });
  if (error) throw new AppError('Database connection failed', 503, error.message);
  return sendSuccess(res, { user_roles: count }, 'Database connected');
});

// --- ต้องอยู่ท้ายสุดเสมอ ---
app.use(notFound);
app.use(errorHandler);

process.on('unhandledRejection', (reason) => logger.error('Unhandled rejection:', reason));

app.listen(PORT, () => logger.info(`CRMS API listening on http://localhost:${PORT}`));