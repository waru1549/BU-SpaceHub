import { createClient } from '@supabase/supabase-js';

const url = import.meta.env.VITE_SUPABASE_URL;
const key = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY;

if (!url || !key) {
  throw new Error('Missing VITE_SUPABASE_URL or VITE_SUPABASE_PUBLISHABLE_KEY in FE/.env');
}

export const supabase = createClient(url, key, {
  auth: {
    flowType: 'pkce', // ปลอดภัยกว่าการส่ง token ผ่าน URL
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
  },
});