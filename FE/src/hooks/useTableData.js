import { useCallback } from 'react';
import { getTable } from '../services/dashboard.service.js';
import { usePagedData } from './usePagedData.js';

// ตารางของ Dashboard: ห่อ usePagedData ด้วยตัวดึงข้อมูลตามชื่อตาราง
export function useTableData(name, initial) {
  const fetcher = useCallback((params) => getTable(name, params), [name]);
  return usePagedData(fetcher, initial);
}