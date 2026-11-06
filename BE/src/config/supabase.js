import 'dotenv/config';
import { createClient } from '@supabase/supabase-js';

const { SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY } = process.env;

// หยุดทันทีถ้าตั้งค่าไม่ครบ (ดีกว่าปล่อยให้พังตอนมีคนเรียกใช้)
if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in BE/.env');
}

// service_role ข้าม RLS ได้ จึงใช้ฝั่ง BE เท่านั้น และห้ามส่งไป FE
export const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});