import { supabase } from './supabase.js';
import { api } from './api.js';
import { GOOGLE_DOMAIN_HINT } from '../utils/constants.js';

export const signInWithGoogle = () =>
  supabase.auth.signInWithOAuth({
    provider: 'google',
    options: {
      redirectTo: `${window.location.origin}/`,
      queryParams: { hd: GOOGLE_DOMAIN_HINT, prompt: 'select_account' },
    },
  });

export async function signInWithPassword(email, password) {
  const { error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) throw error;
}

export const signOut = () => supabase.auth.signOut();

// ขอโปรไฟล์ (รวม role) จาก BE
export const fetchMe = async () => (await api.get('/auth/me')).data;