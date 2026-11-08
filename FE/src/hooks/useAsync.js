import { useCallback, useEffect, useState } from 'react';

// fn ต้องเป็นฟังก์ชันที่ identity คงที่ (ประกาศนอก component)
export function useAsync(fn) {
  const [state, setState] = useState({ data: null, loading: true, error: null });
  const [nonce, setNonce] = useState(0);

  useEffect(() => {
    let cancelled = false; // กันผลลัพธ์ของคำขอเก่ามาทับ
    fn()
      .then((data) => {
        if (!cancelled) setState({ data, loading: false, error: null });
      })
      .catch((err) => {
        if (!cancelled) {
          setState({ data: null, loading: false, error: err.message || 'เกิดข้อผิดพลาด' });
        }
      });
    return () => {
      cancelled = true;
    };
  }, [fn, nonce]);

  const reload = useCallback(() => {
    setState((s) => ({ ...s, loading: true, error: null }));
    setNonce((n) => n + 1);
  }, []);

  return { ...state, reload };
}