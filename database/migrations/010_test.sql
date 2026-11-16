-- ทดสอบ 010 | รันทั้งก้อนเดียว | ข้อมูลทดสอบถูก ROLLBACK ไม่ค้างในฐานข้อมูล
BEGIN;
CREATE TEMP TABLE t_res (n INT, test TEXT, expected TEXT, actual TEXT) ON COMMIT DROP;
DO $$
DECLARE usr BIGINT; adm BIGINT; b1 BIGINT; b2 BIGINT; before_n BIGINT; e TEXT;
BEGIN
  SELECT user_id INTO usr FROM users WHERE role_id=1 AND user_status='ACTIVE' ORDER BY 1 LIMIT 1;
  SELECT user_id INTO adm FROM users WHERE role_id=3 ORDER BY 1 LIMIT 1;
  SELECT count(*) INTO before_n FROM v_maintenance_tracking_summary;
  INSERT INTO t_res VALUES (1,'จำนวนแถวก่อนทดสอบ = จำนวนงานแจ้งซ่อมทั้งหมด',
     (SELECT count(*)::text FROM maintenance_bookings), before_n::text);

  SELECT new_booking_id INTO b1 FROM fn_maintenance_create_booking(usr,NULL,'ลานจอดรถ ตึก 3','ไฟถนนดับ','หลอดไฟริมถนนดับหลายต้น');
  INSERT INTO t_res VALUES (2,'งานพิมพ์สถานที่เองปรากฏใน view','1',
     (SELECT count(*)::text FROM v_maintenance_tracking_summary WHERE booking_id=b1));
  INSERT INTO t_res VALUES (3,'ชื่อทรัพยากรของงานสถานที่เอง = ข้อความที่พิมพ์','ลานจอดรถ ตึก 3',
     (SELECT resource_name FROM v_maintenance_tracking_summary WHERE booking_id=b1));
  INSERT INTO t_res VALUES (4,'งานค้าง = ค้างดำเนินการ','ค้างดำเนินการ',
     (SELECT tracking_state FROM v_maintenance_tracking_summary WHERE booking_id=b1));

  PERFORM fn_maintenance_change_status(b1,'CANCEL',usr,false,false);
  INSERT INTO t_res VALUES (5,'งานที่ยกเลิก = ยกเลิก (ไม่ใช่ค้างดำเนินการ)','ยกเลิก',
     (SELECT tracking_state FROM v_maintenance_tracking_summary WHERE booking_id=b1));

  SELECT new_booking_id INTO b2 FROM fn_maintenance_create_booking(usr,NULL,'โรงอาหาร','โต๊ะหัก','โต๊ะตัวที่ 3 ขาหัก นั่งไม่ได้');
  PERFORM fn_maintenance_assign(b2, adm, true);
  PERFORM fn_maintenance_change_status(b2,'START',adm,true,true);
  PERFORM fn_maintenance_change_status(b2,'COMPLETE',adm,true,true,'เปลี่ยนขาโต๊ะแล้ว');
  INSERT INTO t_res VALUES (6,'งานที่ปิดแล้ว = ปิดงานแล้ว','ปิดงานแล้ว',
     (SELECT tracking_state FROM v_maintenance_tracking_summary WHERE booking_id=b2));
  INSERT INTO t_res VALUES (7,'งานที่ปิดแล้วมี completed_date','true',
     (SELECT (completed_date IS NOT NULL)::text FROM v_maintenance_tracking_summary WHERE booking_id=b2));
  INSERT INTO t_res VALUES (8,'งาน seed เดิมที่ปิดแล้วยังเป็น ปิดงานแล้ว (จำนวนเท่าเดิม)',
     (SELECT count(*)::text FROM maintenance_booking_history h JOIN booking_actions ba USING(action_id)
       WHERE ba.action_name='COMPLETE' AND h.booking_id <= 34),
     (SELECT count(*)::text FROM v_maintenance_tracking_summary WHERE tracking_state='ปิดงานแล้ว' AND booking_id <= 34));
  INSERT INTO t_res VALUES (9,'คอลัมน์ครบ 14 ตัวเหมือนเดิม','14',
     (SELECT count(*)::text FROM information_schema.columns WHERE table_name='v_maintenance_tracking_summary'));
END $$;
SELECT n, test, expected, actual, CASE WHEN expected=actual THEN 'PASS' ELSE 'FAIL' END AS result FROM t_res ORDER BY n;
ROLLBACK;
