import { createContext, useCallback, useEffect, useMemo, useState } from 'react';
import { supabase } from '../services/supabase.js';
import * as authService from '../services/auth.service.js';

export const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [session, setSession] = useState(null);
  const [profile, setProfile] = useState(null);
  const [initializing, setInitializing] = useState(true);
  const [authError, setAuthError] = useState('');

  // 1) ติดตามสถานะ session ของ Supabase
  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session);
      setInitializing(false);
    });
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, newSession) => setSession(newSession));
    return () => subscription.unsubscribe();
  }, []);

  // 2) มี session แล้ว → ขอโปรไฟล์/role จาก BE (ทำใหม่เฉพาะตอนเปลี่ยนผู้ใช้)
  const userId = session?.user?.id;
  useEffect(() => {
    if (!userId) {
      setProfile(null);
      return;
    }
    let cancelled = false;
    authService
      .fetchMe()
      .then((me) => {
        if (cancelled) return;
        setProfile(me);
        setAuthError('');
      })
      .catch(async (err) => {
        if (cancelled) return;
        setAuthError(err.message); // เช่น ไม่ใช่ @bumail.net / บัญชีถูกระงับ
        setProfile(null);
        try {
          await authService.signOut();
        } finally {
          setSession(null);
        }
      });
    return () => {
      cancelled = true;
    };
  }, [userId]);

  const loginWithGoogle = useCallback(async () => {
    setAuthError('');
    const { error } = await authService.signInWithGoogle();
    if (error) setAuthError(error.message);
  }, []);

  const loginWithPassword = useCallback(async (email, password) => {
    setAuthError('');
    await authService.signInWithPassword(email, password); // throw ถ้าผิด ให้หน้า Login จับเอง
  }, []);

  const logout = useCallback(async () => {
    await authService.signOut();
    setProfile(null);
  }, []);

  const hasRole = useCallback((...roles) => Boolean(profile) && roles.includes(profile.role), [profile]);

  // กำลังโหลด = ยังตรวจ session หรือมี session แต่ยังไม่ได้โปรไฟล์จาก BE
  const loading = initializing || (Boolean(session) && !profile);

  const value = useMemo(
    () => ({
      session,
      profile,
      loading,
      authError,
      isAuthenticated: Boolean(profile),
      loginWithGoogle,
      loginWithPassword,
      logout,
      hasRole,
    }),
    [session, profile, loading, authError, loginWithGoogle, loginWithPassword, logout, hasRole]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}