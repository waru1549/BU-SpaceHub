-- 005_demo_printer_schedules.sql : สล็อตเครื่องพิมพ์ 4 ชม. 2 ช่วง/วัน (09-13, 13-17)
-- วันทำการถัดไป 14 วัน เฉพาะเครื่อง AVAILABLE | รันซ้ำได้ก่อนวันสาธิต
INSERT INTO printer_schedules (resource_id, work_date, start_time, end_time, max_slots, schedule_status_id)
SELECT r.resource_id, d::date, t.s, t.e, 1,
       (SELECT schedule_status_id FROM schedule_status WHERE schedule_status_name = 'AVAILABLE')
FROM resources r
JOIN resource_categories rc ON rc.type_id = r.type_id AND rc.type_name = 'PRINTER'
JOIN resource_status rs ON rs.resource_status_id = r.resource_status_id AND rs.resource_status_name = 'AVAILABLE'
CROSS JOIN generate_series(
  (now() AT TIME ZONE 'Asia/Bangkok')::date + 1,
  (now() AT TIME ZONE 'Asia/Bangkok')::date + 20, interval '1 day') AS d
CROSS JOIN (VALUES ('09:00'::time,'13:00'::time), ('13:00'::time,'17:00'::time)) AS t(s,e)
WHERE extract(isodow FROM d) < 6
  AND d::date <= (now() AT TIME ZONE 'Asia/Bangkok')::date + 20
ON CONFLICT (resource_id, work_date, start_time, end_time) DO NOTHING;
