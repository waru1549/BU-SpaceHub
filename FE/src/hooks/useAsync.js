import { useCallback, useEffect, useState } from 'react';

// fn ต้องมี identity คงที่ (ประกาศนอก component หรือห่อด้วย useCallback)
// เมื่อ fn เปลี่ยน (พารามิเตอร์เปลี่ยน) จะโหลดใหม่และ loading = true ทันที
export function useAsync(fn) {
  const [state, setState] = useState({ fn: null, data: null, loading: true, error: null });
  const [nonce, setNonce] = useState(0);

  useEffect(() => {
    let cancelled = false; // กันผลลัพธ์ของคำขอเก่ามาทับ
    fn()
      .then((data) => {
        if (!cancelled) setState({ fn, data, loading: false, error: null });
      })
      .catch((err) => {
        if (!cancelled) {
          setState({ fn, data: null, loading: false, error: err.message || 'เกิดข้อผิดพลาด' });
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

  // ผลที่ถืออยู่เป็นของพารามิเตอร์ชุดเก่า: ถือว่ากำลังโหลดและยังไม่มี error
  const stale = state.fn !== fn;
  return {
    data: state.data,
    loading: state.loading || stale,
    error: stale ? null : state.error,
    reload,
  };
}