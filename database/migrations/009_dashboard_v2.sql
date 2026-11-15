-- =====================================================================
-- 009_dashboard_v2.sql  |  Dashboard v2-1: view สรุปรายระบบ (ไม่มีข้อมูลส่วนบุคคล)
-- ทำซ้ำได้ (CREATE OR REPLACE) | รันใน Supabase SQL Editor | ไม่แก้ view/ตารางเดิม
--   v_dashboard_module_kpi          : KPI รายระบบ (1 แถวต่อ KPI)
--   v_dashboard_status_distribution : สัดส่วนสถานะรายระบบ
--   v_dashboard_recent_items        : รายการล่าสุด / ที่ต้องดำเนินการ (ไม่มีชื่อผู้ใช้/วัตถุประสงค์)
--   v_dashboard_repair_ranking      : ทรัพยากรที่ถูกแจ้งซ่อมมากที่สุด
--   v_dashboard_module_breakdown    : สถิติเฉพาะระบบ (ช่วงเวลา/วัสดุ/ค่าปรับ/ประเภทงานซ่อม)
-- =====================================================================

-- 1) KPI รายระบบ -------------------------------------------------------
CREATE OR REPLACE VIEW v_dashboard_module_kpi WITH (security_invoker = true) AS
WITH today AS (SELECT (now() AT TIME ZONE 'Asia/Bangkok')::date AS d),
rb AS (
  SELECT bs.booking_status_name AS s, rs.work_date
  FROM room_bookings b
  JOIN booking_status bs ON bs.booking_status_id = b.booking_status_id
  JOIN room_schedules rs ON rs.schedule_id = b.schedule_id
),
pb AS (
  SELECT bs.booking_status_name AS s
  FROM printer_bookings b
  JOIN booking_status bs ON bs.booking_status_id = b.booking_status_id
),
eb AS (
  SELECT bs.booking_status_name AS s
  FROM equipment_bookings b
  JOIN booking_status bs ON bs.booking_status_id = b.booking_status_id
),
mb AS (
  SELECT bs.booking_status_name AS s,
         COALESCE(m.completed_at, h.completed_date) AS completed_at,
         m.reported_date
  FROM maintenance_bookings m
  JOIN booking_status bs ON bs.booking_status_id = m.booking_status_id
  LEFT JOIN (
    SELECT mh.booking_id, max(mh.action_date) AS completed_date
    FROM maintenance_booking_history mh
    JOIN booking_actions ba ON ba.action_id = mh.action_id AND ba.action_name = 'COMPLETE'
    GROUP BY mh.booking_id
  ) h ON h.booking_id = m.booking_id
)
SELECT 'ROOM'::text AS module, 'total'::text AS kpi_key, count(*)::numeric AS kpi_value FROM rb
UNION ALL SELECT 'ROOM', 'pending',  count(*) FILTER (WHERE s = 'PENDING')::numeric FROM rb
UNION ALL SELECT 'ROOM', 'upcoming', count(*) FILTER (WHERE s = 'APPROVED' AND work_date >= (SELECT d FROM today))::numeric FROM rb
UNION ALL SELECT 'ROOM', 'avg_utilization_pct',
       COALESCE(round(avg(utilization_pct), 1), 0)
  FROM v_resource_utilization WHERE resource_category = 'ROOM'
UNION ALL SELECT 'PRINTER', 'total',           count(*)::numeric FROM pb
UNION ALL SELECT 'PRINTER', 'pending',         count(*) FILTER (WHERE s = 'PENDING')::numeric FROM pb
UNION ALL SELECT 'PRINTER', 'in_progress',     count(*) FILTER (WHERE s = 'IN_PROGRESS')::numeric FROM pb
UNION ALL SELECT 'PRINTER', 'awaiting_pickup', count(*) FILTER (WHERE s = 'COMPLETED')::numeric FROM pb
UNION ALL SELECT 'EQUIPMENT', 'on_loan', count(*) FILTER (WHERE s = 'RECEIVED')::numeric FROM eb
UNION ALL SELECT 'EQUIPMENT', 'overdue', count(*) FILTER (WHERE s = 'OVERDUE')::numeric FROM eb
UNION ALL SELECT 'EQUIPMENT', 'pending', count(*) FILTER (WHERE s = 'PENDING')::numeric FROM eb
UNION ALL SELECT 'EQUIPMENT', 'unpaid_fines',
       COALESCE((SELECT sum(fine_amount) FROM fines WHERE fine_status = 'UNPAID'), 0)
UNION ALL SELECT 'MAINTENANCE', 'pending',     count(*) FILTER (WHERE s IN ('PENDING','APPROVED'))::numeric FROM mb
UNION ALL SELECT 'MAINTENANCE', 'in_progress', count(*) FILTER (WHERE s = 'IN_PROGRESS')::numeric FROM mb
UNION ALL SELECT 'MAINTENANCE', 'completed_30d',
       count(*) FILTER (WHERE s = 'COMPLETED' AND completed_at >= now() - interval '30 days')::numeric FROM mb
UNION ALL SELECT 'MAINTENANCE', 'avg_repair_days',
       COALESCE(round(avg(EXTRACT(epoch FROM (completed_at - reported_date)) / 86400.0)
                      FILTER (WHERE s = 'COMPLETED' AND completed_at IS NOT NULL), 1), 0)
  FROM mb;

-- 2) สัดส่วนสถานะรายระบบ ----------------------------------------------
CREATE OR REPLACE VIEW v_dashboard_status_distribution WITH (security_invoker = true) AS
SELECT 'ROOM'::text AS module, bs.booking_status_name AS status, count(*) AS total
  FROM room_bookings b JOIN booking_status bs ON bs.booking_status_id = b.booking_status_id GROUP BY 2
UNION ALL
SELECT 'PRINTER', bs.booking_status_name, count(*)
  FROM printer_bookings b JOIN booking_status bs ON bs.booking_status_id = b.booking_status_id GROUP BY 2
UNION ALL
SELECT 'EQUIPMENT', bs.booking_status_name, count(*)
  FROM equipment_bookings b JOIN booking_status bs ON bs.booking_status_id = b.booking_status_id GROUP BY 2
UNION ALL
SELECT 'MAINTENANCE', bs.booking_status_name, count(*)
  FROM maintenance_bookings b JOIN booking_status bs ON bs.booking_status_id = b.booking_status_id GROUP BY 2;

-- 3) รายการล่าสุด/ที่ต้องดำเนินการ (ไม่มีชื่อผู้ใช้ ไม่มีวัตถุประสงค์) -----------
-- needs_action = รอเจ้าหน้าที่ตัดสินใจ (PENDING, แจ้งซ่อมที่ APPROVED เดิม) หรืออุปกรณ์เกินกำหนดคืน
CREATE OR REPLACE VIEW v_dashboard_recent_items WITH (security_invoker = true) AS
SELECT 'ROOM'::text AS module, b.booking_id, b.booking_code,
       r.resource_name AS item_name,
       bs.booking_status_name AS status,
       b.booking_time AS event_at,
       rs.work_date AS event_date,
       (bs.booking_status_name = 'PENDING') AS needs_action
FROM room_bookings b
JOIN booking_status bs ON bs.booking_status_id = b.booking_status_id
JOIN room_schedules rs ON rs.schedule_id = b.schedule_id
JOIN resources r ON r.resource_id = rs.resource_id
UNION ALL
SELECT 'PRINTER', b.booking_id, b.booking_code, r.resource_name, bs.booking_status_name,
       b.booking_time, ps.work_date,
       (bs.booking_status_name = 'PENDING')
FROM printer_bookings b
JOIN booking_status bs ON bs.booking_status_id = b.booking_status_id
JOIN printer_schedules ps ON ps.schedule_id = b.schedule_id
JOIN resources r ON r.resource_id = ps.resource_id
UNION ALL
SELECT 'EQUIPMENT', b.booking_id, b.booking_code, r.resource_name, bs.booking_status_name,
       b.borrow_date, (b.borrow_date AT TIME ZONE 'Asia/Bangkok')::date,
       (bs.booking_status_name IN ('PENDING','OVERDUE'))
FROM equipment_bookings b
JOIN booking_status bs ON bs.booking_status_id = b.booking_status_id
JOIN resources r ON r.resource_id = b.resource_id
UNION ALL
SELECT 'MAINTENANCE', m.booking_id, m.booking_code,
       COALESCE(r.resource_name, NULLIF(btrim(m.location_text), ''), '-'),
       bs.booking_status_name,
       m.reported_date, (m.reported_date AT TIME ZONE 'Asia/Bangkok')::date,
       (bs.booking_status_name IN ('PENDING','APPROVED'))
FROM maintenance_bookings m
JOIN booking_status bs ON bs.booking_status_id = m.booking_status_id
LEFT JOIN resources r ON r.resource_id = m.resource_id;

-- 4) ทรัพยากรที่ถูกแจ้งซ่อมมากที่สุด --------------------------------------
CREATE OR REPLACE VIEW v_dashboard_repair_ranking WITH (security_invoker = true) AS
SELECT r.resource_id, r.resource_code, r.resource_name, rc.type_name AS resource_category,
       count(*) AS repair_count,
       count(*) FILTER (WHERE bs.booking_status_name IN ('PENDING','APPROVED','IN_PROGRESS')) AS open_count
FROM maintenance_bookings m
JOIN resources r ON r.resource_id = m.resource_id
JOIN resource_categories rc ON rc.type_id = r.type_id
JOIN booking_status bs ON bs.booking_status_id = m.booking_status_id
WHERE bs.booking_status_name NOT IN ('REJECTED','CANCELLED')
GROUP BY r.resource_id, r.resource_code, r.resource_name, rc.type_name;

-- 5) สถิติเฉพาะระบบ ---------------------------------------------------
-- breakdown_type: SLOT (ห้อง: ช่วงเวลา) | MATERIAL (เครื่องพิมพ์: วัสดุ, value2 = น้ำหนักรวม g)
--                 FINE_STATUS (อุปกรณ์: ค่าปรับ, value2 = ยอดเงิน) | REPAIR_CATEGORY (แจ้งซ่อม: ประเภท, value2 = วันซ่อมเฉลี่ย)
CREATE OR REPLACE VIEW v_dashboard_module_breakdown WITH (security_invoker = true) AS
SELECT 'ROOM'::text AS module, 'SLOT'::text AS breakdown_type,
       to_char(rs.start_time, 'HH24:MI') || '-' || to_char(rs.end_time, 'HH24:MI') AS group_key,
       count(*) AS total, NULL::numeric AS value2
FROM room_bookings b
JOIN booking_status bs ON bs.booking_status_id = b.booking_status_id
JOIN room_schedules rs ON rs.schedule_id = b.schedule_id
WHERE bs.booking_status_name NOT IN ('REJECTED','CANCELLED')
GROUP BY rs.start_time, rs.end_time
UNION ALL
SELECT 'PRINTER', 'MATERIAL', COALESCE(NULLIF(btrim(b.material), ''), 'ไม่ระบุ'),
       count(*), round(COALESCE(sum(b.est_weight_g), 0), 1)
FROM printer_bookings b
JOIN booking_status bs ON bs.booking_status_id = b.booking_status_id
WHERE bs.booking_status_name NOT IN ('REJECTED','CANCELLED')
GROUP BY 3
UNION ALL
SELECT 'EQUIPMENT', 'FINE_STATUS', f.fine_status, count(*), COALESCE(sum(f.fine_amount), 0)
FROM fines f GROUP BY f.fine_status
UNION ALL
SELECT 'MAINTENANCE', 'REPAIR_CATEGORY', COALESCE(rc.type_name, 'OTHER'), count(*),
       round(avg(EXTRACT(epoch FROM (h.completed_date - m.reported_date)) / 86400.0)
             FILTER (WHERE bs.booking_status_name = 'COMPLETED' AND h.completed_date IS NOT NULL), 1)
FROM maintenance_bookings m
JOIN booking_status bs ON bs.booking_status_id = m.booking_status_id
LEFT JOIN resources r ON r.resource_id = m.resource_id
LEFT JOIN resource_categories rc ON rc.type_id = r.type_id
LEFT JOIN (
  SELECT mh.booking_id, max(mh.action_date) AS completed_date
  FROM maintenance_booking_history mh
  JOIN booking_actions ba ON ba.action_id = mh.action_id AND ba.action_name = 'COMPLETE'
  GROUP BY mh.booking_id
) h ON h.booking_id = m.booking_id
WHERE bs.booking_status_name NOT IN ('REJECTED','CANCELLED')
GROUP BY COALESCE(rc.type_name, 'OTHER');

-- 6) สิทธิ์: เฉพาะ service_role (BE) -----------------------------------
REVOKE ALL ON v_dashboard_module_kpi, v_dashboard_status_distribution, v_dashboard_recent_items,
              v_dashboard_repair_ranking, v_dashboard_module_breakdown
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON v_dashboard_module_kpi, v_dashboard_status_distribution, v_dashboard_recent_items,
                v_dashboard_repair_ranking, v_dashboard_module_breakdown
  TO service_role;
