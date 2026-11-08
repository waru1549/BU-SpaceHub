-- =====================================================================
-- 003 : สร้างช่วงเวลาจองห้องล่วงหน้า 14 วัน (ข้อมูลสำหรับทดสอบ/สาธิต)
--   * ห้องทุกห้องที่ใช้งานได้ วันจันทร์-ศุกร์ วันละ 3 ช่วง
--   * รันซ้ำได้ ไม่สร้างซ้ำ (ใช้ unique ของตารางกัน)
--   * ควรรันอีกครั้งก่อนวันสาธิต เพื่อให้มีช่วงเวลาในอนาคตเสมอ
-- =====================================================================
INSERT INTO room_schedules (resource_id, work_date, start_time, end_time, max_slots, schedule_status_id)
SELECT r.resource_id,
       d::date,
       s.start_time,
       s.end_time,
       1,
       (SELECT schedule_status_id FROM schedule_status WHERE schedule_status_name = 'AVAILABLE')
FROM resources r
JOIN resource_categories rc ON rc.type_id = r.type_id AND rc.type_name = 'ROOM'
JOIN resource_status rst    ON rst.resource_status_id = r.resource_status_id
CROSS JOIN generate_series(CURRENT_DATE + 1, CURRENT_DATE + 14, INTERVAL '1 day') AS d
CROSS JOIN (VALUES (TIME '09:00', TIME '11:00'),
                   (TIME '13:00', TIME '15:00'),
                   (TIME '15:00', TIME '17:00')) AS s(start_time, end_time)
WHERE rst.resource_status_name NOT IN ('BROKEN', 'UNDER_MAINTENANCE', 'OUT_OF_SERVICE')
  AND EXTRACT(ISODOW FROM d) BETWEEN 1 AND 5
ON CONFLICT (resource_id, work_date, start_time, end_time) DO NOTHING;