-- =====================================================================
-- ส่วนที่ 1 : VIEWS (8 วิว)  ทุกวิวใช้ WITH (security_invoker = true)
--   ให้วิวเคารพนโยบาย RLS ของผู้เรียกใช้ (ไม่ข้ามสิทธิ์แบบ owner)
-- =====================================================================
DROP VIEW IF EXISTS v_dashboard_kpi, v_monthly_booking_trend, v_user_activity_summary,
                    v_resource_utilization, v_maintenance_tracking_summary,
                    v_equipment_overdue_summary, v_printer_booking_summary,
                    v_room_booking_summary CASCADE;

-- ---------------------------------------------------------------------
-- View 1 : สรุปการจองห้อง (JOIN 6 ตาราง) -> ใช้กับหน้าตารางการจองห้องและ Chat
-- ---------------------------------------------------------------------
CREATE VIEW v_room_booking_summary WITH (security_invoker = true) AS
SELECT rb.booking_id,
       rb.booking_code,
       u.user_id,
       u.full_name                                   AS user_name,
       ur.role_name                                  AS user_role,
       r.resource_id,
       r.resource_code                               AS room_code,
       r.resource_name                               AS room_name,
       r.location,
       r.capacity,
       rs.work_date,
       rs.start_time,
       rs.end_time,
       EXTRACT(EPOCH FROM (rs.end_time - rs.start_time)) / 3600.0 AS booked_hours,
       bs.booking_status_name                        AS booking_status,
       rb.booking_purpose,
       rb.booking_time
FROM room_bookings     AS rb
JOIN users             AS u  ON u.user_id            = rb.user_id
JOIN user_roles        AS ur ON ur.role_id           = u.role_id
JOIN room_schedules    AS rs ON rs.schedule_id       = rb.schedule_id
JOIN resources         AS r  ON r.resource_id        = rs.resource_id
JOIN booking_status    AS bs ON bs.booking_status_id = rb.booking_status_id;

-- ---------------------------------------------------------------------
-- View 2 : สรุปการจองเครื่องพิมพ์ 3 มิติ
-- ---------------------------------------------------------------------
CREATE VIEW v_printer_booking_summary WITH (security_invoker = true) AS
SELECT pb.booking_id,
       pb.booking_code,
       u.user_id,
       u.full_name                                   AS user_name,
       r.resource_id,
       r.resource_code                               AS printer_code,
       r.resource_name                               AS printer_name,
       r.location,
       ps.work_date,
       ps.start_time,
       ps.end_time,
       EXTRACT(EPOCH FROM (ps.end_time - ps.start_time)) / 3600.0 AS booked_hours,
       bs.booking_status_name                        AS booking_status,
       pb.print_purpose,
       pb.booking_time
FROM printer_bookings  AS pb
JOIN users             AS u  ON u.user_id            = pb.user_id
JOIN printer_schedules AS ps ON ps.schedule_id       = pb.schedule_id
JOIN resources         AS r  ON r.resource_id        = ps.resource_id
JOIN booking_status    AS bs ON bs.booking_status_id = pb.booking_status_id;

-- ---------------------------------------------------------------------
-- View 3 : สรุปอุปกรณ์เกินกำหนดคืน (ค้างคืนอยู่ + คืนล่าช้า) พร้อมค่าปรับ
--   overdue_days = วันที่คืนจริง (หรือวันนี้ ถ้ายังไม่คืน) - วันครบกำหนด
-- ---------------------------------------------------------------------
CREATE VIEW v_equipment_overdue_summary WITH (security_invoker = true) AS
SELECT eb.booking_id,
       eb.booking_code,
       u.user_id,
       u.full_name                                   AS borrower_name,
       u.user_status,
       r.resource_code                               AS equipment_code,
       r.resource_name                               AS equipment_name,
       eb.borrow_date,
       eb.expected_return_date,
       eb.actual_return_date,
       (COALESCE(eb.actual_return_date::date, CURRENT_DATE)
          - eb.expected_return_date::date)           AS overdue_days,
       CASE WHEN eb.actual_return_date IS NULL
            THEN 'ยังไม่คืน (ค้างอยู่)' ELSE 'คืนแล้วแต่ล่าช้า' END AS overdue_type,
       bs.booking_status_name                        AS booking_status,
       COALESCE(f.total_fine, 0)                     AS total_fine,
       COALESCE(f.unpaid_fine, 0)                    AS unpaid_fine
FROM equipment_bookings AS eb
JOIN users              AS u  ON u.user_id            = eb.user_id
JOIN resources          AS r  ON r.resource_id        = eb.resource_id
JOIN booking_status     AS bs ON bs.booking_status_id = eb.booking_status_id
LEFT JOIN (SELECT booking_id,
                  SUM(fine_amount)                                           AS total_fine,
                  SUM(fine_amount) FILTER (WHERE fine_status = 'UNPAID')     AS unpaid_fine
           FROM fines GROUP BY booking_id) AS f ON f.booking_id = eb.booking_id
WHERE eb.booking_status_id IN (SELECT booking_status_id FROM booking_status
                               WHERE booking_status_name IN ('RECEIVED', 'OVERDUE', 'RETURNED'))
  AND COALESCE(eb.actual_return_date::date, CURRENT_DATE) > eb.expected_return_date::date;

-- ---------------------------------------------------------------------
-- View 4 : ติดตามงานแจ้งซ่อม (ระยะเวลาที่ค้าง / ใช้ซ่อมจริง + จำนวนไฟล์แนบ)
-- ---------------------------------------------------------------------
CREATE VIEW v_maintenance_tracking_summary WITH (security_invoker = true) AS
SELECT mb.booking_id,
       mb.booking_code,
       mb.repair_title,
       r.resource_code,
       r.resource_name,
       rc.type_name                                  AS resource_category,
       r.location,
       u.full_name                                   AS reporter_name,
       bs.booking_status_name                        AS repair_status,
       mb.reported_date,
       h.completed_date,
       ROUND(EXTRACT(EPOCH FROM (COALESCE(h.completed_date, CURRENT_TIMESTAMP)
                                 - mb.reported_date)) / 86400.0, 1) AS days_elapsed,
       CASE WHEN h.completed_date IS NOT NULL THEN 'ปิดงานแล้ว'
            WHEN bs.booking_status_name = 'REJECTED' THEN 'ปฏิเสธ'
            ELSE 'ค้างดำเนินการ' END                  AS tracking_state,
       COALESCE(a.attachment_count, 0)               AS attachment_count
FROM maintenance_bookings AS mb
JOIN users                AS u  ON u.user_id            = mb.user_id
JOIN resources            AS r  ON r.resource_id        = mb.resource_id
JOIN resource_categories  AS rc ON rc.type_id           = r.type_id
JOIN booking_status       AS bs ON bs.booking_status_id = mb.booking_status_id
LEFT JOIN (SELECT mh.booking_id, MAX(mh.action_date) AS completed_date
           FROM maintenance_booking_history mh
           JOIN booking_actions ba ON ba.action_id = mh.action_id
           WHERE ba.action_name = 'COMPLETE'
           GROUP BY mh.booking_id) AS h ON h.booking_id = mb.booking_id
LEFT JOIN (SELECT booking_id, COUNT(booking_id) AS attachment_count
           FROM attachments GROUP BY booking_id) AS a ON a.booking_id = mb.booking_id;

-- ---------------------------------------------------------------------
-- View 5 : การใช้ประโยชน์ทรัพยากร (ห้อง / เครื่องพิมพ์ / อุปกรณ์) รายชิ้น
--   ห้อง/เครื่องพิมพ์ : utilization_pct = ชั่วโมงที่ถูกจอง / ชั่วโมงที่เปิดให้จองทั้งหมด
--   อุปกรณ์            : usage_hours = ชั่วโมงที่ถูกยืมจริง, ไม่มีชั่วโมงเปิดให้จอง (NULL)
-- ---------------------------------------------------------------------
CREATE VIEW v_resource_utilization WITH (security_invoker = true) AS
WITH room_capacity AS (
    SELECT rs.resource_id,
           SUM(EXTRACT(EPOCH FROM (rs.end_time - rs.start_time)) / 3600.0
               * rs.max_slots) AS scheduled_hours
    FROM room_schedules rs
    GROUP BY rs.resource_id
), room_activity AS (
    SELECT rs.resource_id,
           SUM(EXTRACT(EPOCH FROM (rs.end_time - rs.start_time)) / 3600.0)
               FILTER (WHERE bs.booking_status_name IN ('APPROVED', 'COMPLETED')) AS used_hours,
           COUNT(rb.booking_id) AS total_bookings,
           COUNT(rb.booking_id)
               FILTER (WHERE bs.booking_status_name = 'COMPLETED') AS completed_bookings
    FROM room_schedules rs
    LEFT JOIN room_bookings rb ON rb.schedule_id = rs.schedule_id
    LEFT JOIN booking_status bs ON bs.booking_status_id = rb.booking_status_id
    GROUP BY rs.resource_id
), room_use AS (
    SELECT c.resource_id, c.scheduled_hours,
           COALESCE(a.used_hours, 0) AS used_hours,
           COALESCE(a.total_bookings, 0) AS total_bookings,
           COALESCE(a.completed_bookings, 0) AS completed_bookings
    FROM room_capacity c
    LEFT JOIN room_activity a ON a.resource_id = c.resource_id
), printer_capacity AS (
    SELECT ps.resource_id,
           SUM(EXTRACT(EPOCH FROM (ps.end_time - ps.start_time)) / 3600.0
               * ps.max_slots) AS scheduled_hours
    FROM printer_schedules ps
    GROUP BY ps.resource_id
), printer_activity AS (
    SELECT ps.resource_id,
           SUM(EXTRACT(EPOCH FROM (ps.end_time - ps.start_time)) / 3600.0)
               FILTER (WHERE bs.booking_status_name IN ('APPROVED', 'IN_PROGRESS', 'COMPLETED', 'RECEIVED')) AS used_hours,
           COUNT(pb.booking_id) AS total_bookings,
           COUNT(pb.booking_id)
               FILTER (WHERE bs.booking_status_name IN ('COMPLETED', 'RECEIVED')) AS completed_bookings
    FROM printer_schedules ps
    LEFT JOIN printer_bookings pb ON pb.schedule_id = ps.schedule_id
    LEFT JOIN booking_status bs ON bs.booking_status_id = pb.booking_status_id
    GROUP BY ps.resource_id
), printer_use AS (
    SELECT c.resource_id, c.scheduled_hours,
           COALESCE(a.used_hours, 0) AS used_hours,
           COALESCE(a.total_bookings, 0) AS total_bookings,
           COALESCE(a.completed_bookings, 0) AS completed_bookings
    FROM printer_capacity c
    LEFT JOIN printer_activity a ON a.resource_id = c.resource_id
), equip_use AS (
    SELECT eb.resource_id,
           CAST(NULL AS NUMERIC) AS scheduled_hours,
           SUM(EXTRACT(EPOCH FROM (
                   COALESCE(eb.actual_return_date, LEAST(eb.expected_return_date, CURRENT_TIMESTAMP))
                   - eb.borrow_date
               )) / 3600.0)
               FILTER (WHERE bs.booking_status_name IN ('RECEIVED', 'RETURNED', 'OVERDUE')) AS used_hours,
           COUNT(eb.booking_id) AS total_bookings,
           COUNT(eb.booking_id) FILTER (WHERE bs.booking_status_name = 'RETURNED') AS completed_bookings
    FROM equipment_bookings eb
    JOIN booking_status bs ON bs.booking_status_id = eb.booking_status_id
    GROUP BY eb.resource_id
)
SELECT r.resource_id,
       r.resource_code,
       r.resource_name,
       rc.type_name AS resource_category,
       rst.resource_status_name AS resource_status,
       r.location,
       COALESCE(u.total_bookings, 0) AS total_bookings,
       COALESCE(u.completed_bookings, 0) AS completed_bookings,
       ROUND(u.scheduled_hours::numeric, 1) AS scheduled_hours,
       ROUND(COALESCE(u.used_hours, 0)::numeric, 1) AS used_hours,
       ROUND(u.used_hours::numeric * 100.0
             / NULLIF(u.scheduled_hours::numeric, 0), 2) AS utilization_pct
FROM resources r
JOIN resource_categories rc ON rc.type_id = r.type_id
JOIN resource_status rst ON rst.resource_status_id = r.resource_status_id
LEFT JOIN (
    SELECT * FROM room_use
    UNION ALL SELECT * FROM printer_use
    UNION ALL SELECT * FROM equip_use
) AS u ON u.resource_id = r.resource_id
WHERE rc.type_name IN ('ROOM', 'PRINTER', 'EQUIPMENT');

-- ---------------------------------------------------------------------
-- View 6 : ผู้ใช้แต่ละคนใช้บริการกี่ครั้งในแต่ละโมดูล (User 360)
-- ---------------------------------------------------------------------
CREATE VIEW v_user_activity_summary WITH (security_invoker = true) AS
SELECT u.user_id,
       u.user_code,
       u.full_name,
       ur.role_name,
       u.user_status,
       COALESCE(rb.cnt, 0)  AS room_bookings,
       COALESCE(pb.cnt, 0)  AS printer_bookings,
       COALESCE(eb.cnt, 0)  AS equipment_bookings,
       COALESCE(mb.cnt, 0)  AS maintenance_reports,
       COALESCE(rb.cnt, 0) + COALESCE(pb.cnt, 0) + COALESCE(eb.cnt, 0) + COALESCE(mb.cnt, 0) AS total_activities,
       COALESCE(fn.unpaid, 0) AS unpaid_fines
FROM users u
JOIN user_roles ur ON ur.role_id = u.role_id
LEFT JOIN (SELECT user_id, COUNT(booking_id) cnt FROM room_bookings        GROUP BY user_id) rb ON rb.user_id = u.user_id
LEFT JOIN (SELECT user_id, COUNT(booking_id) cnt FROM printer_bookings     GROUP BY user_id) pb ON pb.user_id = u.user_id
LEFT JOIN (SELECT user_id, COUNT(booking_id) cnt FROM equipment_bookings   GROUP BY user_id) eb ON eb.user_id = u.user_id
LEFT JOIN (SELECT user_id, COUNT(booking_id) cnt FROM maintenance_bookings GROUP BY user_id) mb ON mb.user_id = u.user_id
LEFT JOIN (SELECT e.user_id, SUM(f.fine_amount) AS unpaid
           FROM fines f JOIN equipment_bookings e ON e.booking_id = f.booking_id
           WHERE f.fine_status = 'UNPAID' GROUP BY e.user_id) fn ON fn.user_id = u.user_id;

-- ---------------------------------------------------------------------
-- View 7 : แนวโน้มจำนวนรายการรายเดือน แยกโมดูล (ใช้ทำกราฟเส้น/แท่ง)
-- ---------------------------------------------------------------------
CREATE VIEW v_monthly_booking_trend WITH (security_invoker = true) AS
SELECT DATE_TRUNC('month', t.event_date)::date AS month_start,
       TO_CHAR(t.event_date, 'YYYY-MM')        AS month_label,
       t.module,
       COUNT(t.user_id)                       AS total_bookings,
       COUNT(DISTINCT t.user_id)               AS distinct_users
FROM (
    SELECT rs.work_date::timestamp AS event_date, rb.user_id, 'ROOM'::text AS module
      FROM room_bookings rb JOIN room_schedules rs ON rs.schedule_id = rb.schedule_id
    UNION ALL
    SELECT ps.work_date::timestamp, pb.user_id, 'PRINTER'
      FROM printer_bookings pb JOIN printer_schedules ps ON ps.schedule_id = pb.schedule_id
    UNION ALL
    SELECT eb.borrow_date, eb.user_id, 'EQUIPMENT' FROM equipment_bookings eb
    UNION ALL
    SELECT mb.reported_date, mb.user_id, 'MAINTENANCE' FROM maintenance_bookings mb
) AS t
GROUP BY DATE_TRUNC('month', t.event_date), TO_CHAR(t.event_date, 'YYYY-MM'), t.module;

-- ---------------------------------------------------------------------
-- View 8 : ตัวชี้วัดภาพรวมระบบ (1 แถว) สำหรับการ์ด KPI บน Dashboard
-- ---------------------------------------------------------------------
CREATE VIEW v_dashboard_kpi WITH (security_invoker = true) AS
SELECT (SELECT COUNT(user_id) FROM users WHERE user_status = 'ACTIVE')                          AS active_users,
       (SELECT COUNT(resource_id) FROM resources)                                                   AS total_resources,
       (SELECT COUNT(booking_id) FROM room_bookings)                                               AS room_bookings,
       (SELECT COUNT(booking_id) FROM printer_bookings)                                            AS printer_bookings,
       (SELECT COUNT(booking_id) FROM equipment_bookings)                                          AS equipment_bookings,
       (SELECT COUNT(booking_id) FROM maintenance_bookings)                                        AS maintenance_requests,
       (SELECT COUNT(rb.booking_id) FROM room_bookings rb JOIN booking_status bs ON bs.booking_status_id = rb.booking_status_id
         WHERE bs.booking_status_name = 'PENDING')
     + (SELECT COUNT(pb.booking_id) FROM printer_bookings pb JOIN booking_status bs ON bs.booking_status_id = pb.booking_status_id
         WHERE bs.booking_status_name = 'PENDING')
     + (SELECT COUNT(eb.booking_id) FROM equipment_bookings eb JOIN booking_status bs ON bs.booking_status_id = eb.booking_status_id
         WHERE bs.booking_status_name = 'PENDING')                                        AS pending_approvals,
       (SELECT COUNT(eb.booking_id) FROM equipment_bookings eb JOIN booking_status bs ON bs.booking_status_id = eb.booking_status_id
         WHERE bs.booking_status_name = 'OVERDUE')                                        AS overdue_equipment,
       (SELECT COALESCE(SUM(fine_amount), 0) FROM fines)                                  AS total_fines,
       (SELECT COALESCE(SUM(fine_amount), 0) FROM fines WHERE fine_status = 'UNPAID')     AS unpaid_fines,
       (SELECT COUNT(mb.booking_id) FROM maintenance_bookings mb JOIN booking_status bs ON bs.booking_status_id = mb.booking_status_id
         WHERE bs.booking_status_name IN ('PENDING', 'APPROVED', 'IN_PROGRESS'))          AS open_maintenance,
       (SELECT ROUND(AVG(utilization_pct), 2) FROM v_resource_utilization
         WHERE resource_category = 'ROOM')                                                AS avg_room_utilization_pct;


