-- ทดสอบ 009 (Dashboard v2-1) | รันทั้งก้อนเดียว | อ่านอย่างเดียว ไม่แก้ข้อมูล
-- วิธีตรวจ: เทียบตัวเลขใน view ใหม่กับการนับจากตารางจริงโดยตรง (ผ่านเมื่อ result = PASS ทุกแถว)
WITH checks AS (
  SELECT 1 AS n, 'KPI ห้อง total = จำนวน room_bookings' AS test,
         (SELECT count(*) FROM room_bookings)::text AS expected,
         (SELECT kpi_value::bigint::text FROM v_dashboard_module_kpi WHERE module='ROOM' AND kpi_key='total') AS actual
  UNION ALL SELECT 2, 'KPI เครื่องพิมพ์ total = จำนวน printer_bookings',
         (SELECT count(*) FROM printer_bookings)::text,
         (SELECT kpi_value::bigint::text FROM v_dashboard_module_kpi WHERE module='PRINTER' AND kpi_key='total')
  UNION ALL SELECT 3, 'KPI อุปกรณ์ overdue = สถานะ OVERDUE',
         (SELECT count(*) FROM equipment_bookings eb JOIN booking_status bs USING (booking_status_id) WHERE bs.booking_status_name='OVERDUE')::text,
         (SELECT kpi_value::bigint::text FROM v_dashboard_module_kpi WHERE module='EQUIPMENT' AND kpi_key='overdue')
  UNION ALL SELECT 4, 'KPI อุปกรณ์ unpaid_fines = ผลรวมค่าปรับ UNPAID',
         (SELECT COALESCE(sum(fine_amount),0)::text FROM fines WHERE fine_status='UNPAID'),
         (SELECT kpi_value::text FROM v_dashboard_module_kpi WHERE module='EQUIPMENT' AND kpi_key='unpaid_fines')
  UNION ALL SELECT 5, 'KPI แจ้งซ่อม pending = PENDING + APPROVED',
         (SELECT count(*) FROM maintenance_bookings m JOIN booking_status bs USING (booking_status_id) WHERE bs.booking_status_name IN ('PENDING','APPROVED'))::text,
         (SELECT kpi_value::bigint::text FROM v_dashboard_module_kpi WHERE module='MAINTENANCE' AND kpi_key='pending')
  UNION ALL SELECT 6, 'KPI ครบ 16 แถว (4 ระบบ x 4 ตัวชี้วัด)', '16', (SELECT count(*)::text FROM v_dashboard_module_kpi)
  UNION ALL SELECT 7, 'สถานะ: ผลรวมห้อง = room_bookings',
         (SELECT count(*) FROM room_bookings)::text,
         (SELECT sum(total)::text FROM v_dashboard_status_distribution WHERE module='ROOM')
  UNION ALL SELECT 8, 'สถานะ: ผลรวมเครื่องพิมพ์ = printer_bookings',
         (SELECT count(*) FROM printer_bookings)::text,
         (SELECT sum(total)::text FROM v_dashboard_status_distribution WHERE module='PRINTER')
  UNION ALL SELECT 9, 'สถานะ: ผลรวมอุปกรณ์ = equipment_bookings',
         (SELECT count(*) FROM equipment_bookings)::text,
         (SELECT sum(total)::text FROM v_dashboard_status_distribution WHERE module='EQUIPMENT')
  UNION ALL SELECT 10, 'สถานะ: ผลรวมแจ้งซ่อม = maintenance_bookings',
         (SELECT count(*) FROM maintenance_bookings)::text,
         (SELECT sum(total)::text FROM v_dashboard_status_distribution WHERE module='MAINTENANCE')
  UNION ALL SELECT 11, 'รายการล่าสุด: จำนวนแถวรวมทุกระบบ',
         ((SELECT count(*) FROM room_bookings) + (SELECT count(*) FROM printer_bookings)
          + (SELECT count(*) FROM equipment_bookings) + (SELECT count(*) FROM maintenance_bookings))::text,
         (SELECT count(*)::text FROM v_dashboard_recent_items)
  UNION ALL SELECT 12, 'รายการล่าสุด: ไม่มีคอลัมน์ชื่อผู้ใช้/วัตถุประสงค์/อีเมล',
         '0',
         (SELECT count(*)::text FROM information_schema.columns
           WHERE table_name='v_dashboard_recent_items'
             AND (column_name ILIKE '%user%' OR column_name ILIKE '%purpose%' OR column_name ILIKE '%email%'
                  OR column_name ILIKE '%reporter%' OR column_name ILIKE '%full_name%' OR column_name ILIKE '%title%'))
  UNION ALL SELECT 13, 'needs_action ของแจ้งซ่อม = KPI pending',
         (SELECT kpi_value::bigint::text FROM v_dashboard_module_kpi WHERE module='MAINTENANCE' AND kpi_key='pending'),
         (SELECT count(*)::text FROM v_dashboard_recent_items WHERE module='MAINTENANCE' AND needs_action)
  UNION ALL SELECT 14, 'อันดับแจ้งซ่อม: ผลรวม <= แจ้งซ่อมที่ไม่ใช่ปฏิเสธ/ยกเลิก',
         'true',
         (SELECT ((SELECT COALESCE(sum(repair_count),0) FROM v_dashboard_repair_ranking) <=
                  (SELECT count(*) FROM maintenance_bookings m JOIN booking_status bs USING (booking_status_id)
                    WHERE bs.booking_status_name NOT IN ('REJECTED','CANCELLED')))::text)
  UNION ALL SELECT 15, 'สถิติอุปกรณ์: จำนวนค่าปรับ = ตาราง fines',
         (SELECT count(*) FROM fines)::text,
         (SELECT COALESCE(sum(total),0)::text FROM v_dashboard_module_breakdown WHERE breakdown_type='FINE_STATUS')
  UNION ALL SELECT 16, 'สิทธิ์: anon และ authenticated อ่าน view ใหม่ไม่ได้',
         'false',
         (SELECT (bool_or(has_table_privilege('anon', v, 'SELECT')) OR bool_or(has_table_privilege('authenticated', v, 'SELECT')))::text
            FROM unnest(ARRAY['v_dashboard_module_kpi','v_dashboard_status_distribution','v_dashboard_recent_items',
                              'v_dashboard_repair_ranking','v_dashboard_module_breakdown']) AS v)
  UNION ALL SELECT 17, 'สิทธิ์: service_role อ่านได้',
         'true',
         (SELECT bool_and(has_table_privilege('service_role', v, 'SELECT'))::text
            FROM unnest(ARRAY['v_dashboard_module_kpi','v_dashboard_status_distribution','v_dashboard_recent_items',
                              'v_dashboard_repair_ranking','v_dashboard_module_breakdown']) AS v)
)
SELECT n, test, expected, actual, CASE WHEN expected = actual THEN 'PASS' ELSE 'FAIL' END AS result
FROM checks ORDER BY n;
