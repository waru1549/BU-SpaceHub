import { useCallback, useEffect, useState } from 'react';
import { getTable } from '../services/dashboard.service.js';

export function useTableData(name, { sort, order }) {
  const [params, setParams] = useState({ page: 1, limit: 10, sort, order, filters: {} });
  const [state, setState] = useState({ rows: [], meta: null, loading: true, error: null });
  const [nonce, setNonce] = useState(0);

  useEffect(() => {
    let cancelled = false;
    getTable(name, params)
      .then(({ rows, meta }) => {
        if (!cancelled) setState({ rows, meta, loading: false, error: null });
      })
      .catch((err) => {
        if (!cancelled) {
          setState({ rows: [], meta: null, loading: false, error: err.message || 'โหลดข้อมูลไม่สำเร็จ' });
        }
      });
    return () => {
      cancelled = true;
    };
  }, [name, params, nonce]);

  // เปลี่ยนเงื่อนไขทุกครั้งให้เข้าสถานะ loading ทันที (ทำใน event handler ไม่ใช่ใน effect)
  const update = useCallback((patch) => {
    setState((s) => ({ ...s, loading: true, error: null }));
    setParams((p) => ({ ...p, ...patch }));
  }, []);

  return {
    ...state,
    params,
    setPage: (page) => update({ page }),
    setLimit: (limit) => update({ limit, page: 1 }),
    setSort: ({ sort: s, order: o }) => update({ sort: s, order: o, page: 1 }),
    setFilter: (key, value) =>
      update({ filters: { ...params.filters, [key]: value }, page: 1 }),
    reload: () => {
      setState((s) => ({ ...s, loading: true, error: null }));
      setNonce((n) => n + 1);
    },
  };
}