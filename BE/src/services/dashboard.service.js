import { AppError } from '../middleware/error.middleware.js';
import { ROLES } from '../middleware/role.middleware.js';
import * as repo from '../repositories/dashboard.repository.js';
import { buildMeta, parseFilters, parsePagination } from '../utils/pagination.js';

const ALL = [ROLES.USER, ROLES.STAFF, ROLES.ADMIN];
const STAFF_UP = [ROLES.STAFF, ROLES.ADMIN];

// ตารางที่เปิดให้ดึงได้ ทุกค่า (view, คอลัมน์ที่เรียง/กรองได้, role) กำหนดที่นี่ที่เดียว
// view ที่มีชื่อบุคคลถูกจำกัดเฉพาะ STAFF/ADMIN หรือ ADMIN
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
};

export const getKpi = () => repo.fetchKpi();
export const getTrend = () => repo.fetchTrend();

export const getTable = async (name, role, query) => {
  // Object.hasOwn กัน name อย่าง "constructor" หรือ "__proto__"
  if (!Object.hasOwn(TABLES, name)) throw new AppError('Table not found', 404);
  const cfg = TABLES[name];
  if (!cfg.roles.includes(role)) {
    throw new AppError('You do not have permission to access this resource', 403);
  }

  const paging = parsePagination(query, cfg);
  const filters = parseFilters(query, cfg.filters);
  const { rows, total } = await repo.fetchPage(cfg, { ...paging, filters });

  return { rows, meta: buildMeta({ total, ...paging }) };
};