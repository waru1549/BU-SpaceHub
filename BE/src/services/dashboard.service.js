import { AppError } from '../middleware/error.middleware.js';
import { ROLES } from '../middleware/role.middleware.js';
import * as repo from '../repositories/dashboard.repository.js';
import { buildMeta, parseFilters, parsePagination } from '../utils/pagination.js';

const ALL = [ROLES.USER, ROLES.STAFF, ROLES.ADMIN];
const STAFF_UP = [ROLES.STAFF, ROLES.ADMIN];

export const MODULES = ['ROOM', 'PRINTER', 'EQUIPMENT', 'MAINTENANCE'];

// ตารางที่เปิดให้ดึงได้ ทุกค่า (view, คอลัมน์ที่เรียง/กรองได้, role) กำหนดที่นี่ที่เดียว
// view ที่มีชื่อบุคคลถูกจำกัดเฉพาะ STAFF/ADMIN หรือ ADMIN
// filterAllowed (ถ้ามี) = ค่าที่อนุญาตของตัวกรองนั้น ค่าอื่นตอบ 400
const TABLES = {
  utilization: {
    view: 'v_resource_utilization',
    roles: ALL,
    tieBreaker: 'resource_id',
    defaultSort: 'resource_code',
    defaultOrder: 'asc',
    sortable: [
      'resource_code', 'resource_name', 'resource_category', 'resource_status',
      'total_bookings', 'completed_bookings', 'used_hours', 'utilization_pct',
    ],
    filters: ['resource_category', 'resource_status'],
  },
  overdue: {
    view: 'v_equipment_overdue_summary',
    roles: STAFF_UP,
    tieBreaker: 'booking_id',
    defaultSort: 'overdue_days',
    defaultOrder: 'desc',
    sortable: [
      'booking_code', 'borrower_name', 'equipment_name', 'expected_return_date',
      'overdue_days', 'total_fine', 'unpaid_fine', 'booking_status',
    ],
    filters: ['overdue_type', 'booking_status'],
  },
  maintenance: {
    view: 'v_maintenance_tracking_summary',
    roles: STAFF_UP,
    tieBreaker: 'booking_id',
    defaultSort: 'reported_date',
    defaultOrder: 'desc',
    sortable: [
      'booking_code', 'resource_name', 'reported_date', 'days_elapsed',
      'repair_status', 'tracking_state', 'attachment_count',
    ],
    filters: ['tracking_state', 'repair_status', 'resource_category'],
  },
  users: {
    view: 'v_user_activity_summary',
    roles: [ROLES.ADMIN],
    tieBreaker: 'user_id',
    defaultSort: 'total_activities',
    defaultOrder: 'desc',
    sortable: [
      'user_code', 'full_name', 'role_name', 'user_status',
      'total_activities', 'unpaid_fines',
    ],
    filters: ['role_name', 'user_status'],
  },
  // Dashboard v2: ทุกบทบาทเห็นได้ (ข้อมูลสรุป ไม่มีข้อมูลส่วนบุคคล)
  recent: {
    view: 'v_dashboard_recent_items',
    roles: ALL,
    tieBreaker: 'booking_code', // รหัสไม่ซ้ำข้ามระบบ (RB/PB/EB/MT)
    defaultSort: 'event_at',
    defaultOrder: 'desc',
    sortable: ['event_at', 'event_date', 'booking_code', 'item_name', 'status'],
    filters: ['module', 'needs_action', 'status'],
    filterAllowed: { module: MODULES, needs_action: ['true', 'false'] },
  },
  repair_ranking: {
    view: 'v_dashboard_repair_ranking',
    roles: ALL,
    tieBreaker: 'resource_id',
    defaultSort: 'repair_count',
    defaultOrder: 'desc',
    sortable: ['repair_count', 'open_count', 'resource_code', 'resource_name', 'resource_category'],
    filters: ['resource_category'],
  },
};

export const getKpi = () => repo.fetchKpi();
export const getTrend = () => repo.fetchTrend();

// สรุปรายระบบ: KPI (ออบเจ็กต์ key -> ค่า) + สัดส่วนสถานะ + สถิติเฉพาะระบบ
export const getSystem = async (rawModule) => {
  const module = String(rawModule ?? '').toUpperCase();
  if (!MODULES.includes(module)) {
    throw new AppError('Module not found', 404, { allowed: MODULES });
  }
  const [kpiRows, statusRows, breakdown] = await Promise.all([
    repo.fetchModuleKpi(module),
    repo.fetchStatusDistribution(module),
    repo.fetchBreakdown(module),
  ]);
  return {
    module,
    kpis: Object.fromEntries(kpiRows.map((r) => [r.kpi_key, Number(r.kpi_value)])),
    status_distribution: statusRows.map((r) => ({ status: r.status, total: Number(r.total) })),
    breakdown: breakdown.map((r) => ({
      type: r.breakdown_type,
      key: r.group_key,
      total: Number(r.total),
      value2: r.value2 === null ? null : Number(r.value2),
    })),
  };
};

export const getTable = async (name, role, query) => {
  // Object.hasOwn กัน name อย่าง "constructor" หรือ "__proto__"
  if (!Object.hasOwn(TABLES, name)) throw new AppError('Table not found', 404);
  const cfg = TABLES[name];
  if (!cfg.roles.includes(role)) {
    throw new AppError('You do not have permission to access this resource', 403);
  }

  const paging = parsePagination(query, cfg);
  const filters = parseFilters(query, cfg.filters);
  for (const [key, value] of Object.entries(filters)) {
    const allowed = cfg.filterAllowed?.[key];
    if (allowed && !allowed.includes(value)) {
      throw new AppError(`Invalid ${key}`, 400, { allowed });
    }
  }
  const { rows, total } = await repo.fetchPage(cfg, { ...paging, filters });

  return { rows, meta: buildMeta({ total, ...paging }) };
};