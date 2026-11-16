-- =====================================================================
-- 010_maintenance_tracking_view_fix.sql  |  Dashboard v2-2
-- แก้ v_maintenance_tracking_summary ให้รองรับระบบแจ้งซ่อมใหม่ (migration 008)
--   1) งานที่ผู้ใช้พิมพ์สถานที่เอง (ไม่ผูกทรัพยากร) ต้องไม่หายจากตาราง (LEFT JOIN)
--   2) สถานะ CANCELLED ต้องไม่ถูกนับเป็น "ค้างดำเนินการ" (แสดงเป็น "ยกเลิก")
-- คอลัมน์เดิมครบทุกตัว ชื่อ/ชนิดเดิม จึงไม่กระทบ FE และ analysis_queries | ทำซ้ำได้
-- =====================================================================
CREATE OR REPLACE VIEW v_maintenance_tracking_summary WITH (security_invoker = true) AS
SELECT mb.booking_id,
       mb.booking_code,
       mb.repair_title,
       r.resource_code,
       COALESCE(r.resource_name, NULLIF(btrim(mb.location_text), ''))::varchar(255) AS resource_name,
       COALESCE(rc.type_name, 'OTHER')::varchar(100)                               AS resource_category,
       COALESCE(r.location, NULLIF(btrim(mb.location_text), ''))::varchar(255)      AS location,
       u.full_name AS reporter_name,
       bs.booking_status_name AS repair_status,
       mb.reported_date,
       h.completed_date,
       round((EXTRACT(epoch FROM (COALESCE(h.completed_date, CURRENT_TIMESTAMP) - mb.reported_date)) / 86400.0), 1) AS days_elapsed,
       CASE
         WHEN h.completed_date IS NOT NULL                 THEN 'ปิดงานแล้ว'
         WHEN bs.booking_status_name = 'REJECTED'          THEN 'ปฏิเสธ'
         WHEN bs.booking_status_name = 'CANCELLED'         THEN 'ยกเลิก'
         ELSE 'ค้างดำเนินการ'
       END::text AS tracking_state,
       COALESCE(a.attachment_count, 0::bigint) AS attachment_count
FROM maintenance_bookings mb
JOIN users u            ON u.user_id = mb.user_id
JOIN booking_status bs  ON bs.booking_status_id = mb.booking_status_id
LEFT JOIN resources r             ON r.resource_id = mb.resource_id
LEFT JOIN resource_categories rc  ON rc.type_id = r.type_id
LEFT JOIN (
  SELECT mh.booking_id, max(mh.action_date) AS completed_date
  FROM maintenance_booking_history mh
  JOIN booking_actions ba ON ba.action_id = mh.action_id
  WHERE ba.action_name = 'COMPLETE'
  GROUP BY mh.booking_id
) h ON h.booking_id = mb.booking_id
LEFT JOIN (
  SELECT booking_id, count(booking_id) AS attachment_count FROM attachments GROUP BY booking_id
) a ON a.booking_id = mb.booking_id;
