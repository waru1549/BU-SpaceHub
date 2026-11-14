-- ทดสอบ 008 (Step 10-1) | รันทั้งก้อนเดียว | ข้อมูลทดสอบจะถูก ROLLBACK ไม่ค้างในฐานข้อมูล
BEGIN;
CREATE TEMP TABLE t_res (n INT, test TEXT, expected TEXT, actual TEXT) ON COMMIT DROP;
DO $$
DECLARE
  adm BIGINT; stf BIGINT; usr BIGINT; res BIGINT; b BIGINT; b2 BIGINT; r RECORD; n INT := 0; e TEXT;
BEGIN
  SELECT user_id INTO adm FROM users WHERE role_id=3 ORDER BY 1 LIMIT 1;
  SELECT user_id INTO stf FROM users WHERE role_id=2 AND user_status='ACTIVE' ORDER BY 1 LIMIT 1;
  SELECT user_id INTO usr FROM users WHERE role_id=1 AND user_status='ACTIVE' ORDER BY 1 LIMIT 1;
  SELECT resource_id INTO res FROM resources WHERE resource_status_id=1 ORDER BY 1 LIMIT 1;

  -- helper inline: แต่ละเคสจับ error เป็นข้อความ
  n:=1;  SELECT new_booking_id INTO b FROM fn_maintenance_create_booking(usr,res,NULL,'ไฟเสีย','หลอดไฟดับทั้งแถว ใช้งานไม่ได้');
         INSERT INTO t_res VALUES (n,'แจ้งซ่อมผูกทรัพยากร','PENDING',(SELECT booking_status FROM v_maintenance_requests WHERE booking_id=b));
  n:=2;  BEGIN PERFORM fn_maintenance_create_booking(usr,res,NULL,'ไฟเสีย','หลอดไฟดับทั้งแถว ใช้งานไม่ได้'); e:='OK'; EXCEPTION WHEN OTHERS THEN e:=SQLERRM; END;
         INSERT INTO t_res VALUES (n,'แจ้งซ้ำทรัพยากรเดิม','ALREADY_REPORTED',e);
  n:=3;  BEGIN PERFORM fn_maintenance_create_booking(usr,NULL,' ','ไฟเสีย','หลอดไฟดับทั้งแถว ใช้งานไม่ได้'); e:='OK'; EXCEPTION WHEN OTHERS THEN e:=SQLERRM; END;
         INSERT INTO t_res VALUES (n,'ไม่ระบุทรัพยากร/สถานที่','TARGET_REQUIRED',e);
  n:=4;  BEGIN PERFORM fn_maintenance_create_booking(usr,res+0,NULL,'ab','ยาวพอสำหรับรายละเอียด'); e:='OK'; EXCEPTION WHEN OTHERS THEN e:=SQLERRM; END;
         INSERT INTO t_res VALUES (n,'หัวข้อสั้นเกินไป','INVALID_TITLE',e);
  n:=5;  SELECT new_booking_id INTO b2 FROM fn_maintenance_create_booking(usr,NULL,'ลานจอดรถ ตึก 3','ไฟถนนดับ','หลอดไฟริมถนนดับหลายต้น');
         INSERT INTO t_res VALUES (n,'แจ้งซ่อมพิมพ์สถานที่เอง','PENDING',(SELECT booking_status FROM v_maintenance_requests WHERE booking_id=b2));
  n:=6;  BEGIN PERFORM fn_maintenance_change_status(b,'START',stf,true,false); e:='OK'; EXCEPTION WHEN OTHERS THEN e:=SQLERRM; END;
         INSERT INTO t_res VALUES (n,'เริ่มซ่อมก่อนมอบหมาย','NOT_ASSIGNED',e);
  n:=7;  BEGIN PERFORM fn_maintenance_assign(b,stf,false); e:='OK'; EXCEPTION WHEN OTHERS THEN e:=SQLERRM; END;
         INSERT INTO t_res VALUES (n,'ผู้ที่ไม่ใช่ Admin มอบหมายงาน','FORBIDDEN',e);
  n:=8;  BEGIN PERFORM fn_maintenance_assign(b,usr,true); e:='OK'; EXCEPTION WHEN OTHERS THEN e:=SQLERRM; END;
         INSERT INTO t_res VALUES (n,'มอบหมายให้นักศึกษา','ASSIGNEE_INVALID',e);
  n:=9;  PERFORM fn_maintenance_assign(b,stf,true);
         INSERT INTO t_res VALUES (n,'Admin มอบหมาย Staff','assigned_to='||stf,'assigned_to='||(SELECT assigned_to FROM maintenance_bookings WHERE booking_id=b));
  n:=10; BEGIN PERFORM fn_maintenance_change_status(b,'START',stf+100000,true,false); e:='OK'; EXCEPTION WHEN OTHERS THEN e:=SQLERRM; END;
         INSERT INTO t_res VALUES (n,'Staff คนอื่นกดเริ่มซ่อม','NOT_ASSIGNEE',e);
  n:=11; PERFORM fn_maintenance_change_status(b,'START',stf,true,false);
         INSERT INTO t_res VALUES (n,'Staff ผู้รับผิดชอบเริ่มซ่อม','IN_PROGRESS',(SELECT booking_status FROM v_maintenance_requests WHERE booking_id=b));
  n:=12; INSERT INTO t_res VALUES (n,'ทรัพยากรเปลี่ยนเป็น','UNDER_MAINTENANCE',(SELECT rs.resource_status_name FROM resources r JOIN resource_status rs USING(resource_status_id) WHERE resource_id=res));
  n:=13; BEGIN PERFORM fn_maintenance_change_status(b,'CANCEL',usr,false,false); e:='OK'; EXCEPTION WHEN OTHERS THEN e:=SQLERRM; END;
         INSERT INTO t_res VALUES (n,'ยกเลิกหลังเริ่มซ่อม','INVALID_TRANSITION',e);
  n:=14; BEGIN PERFORM fn_maintenance_change_status(b,'COMPLETE',stf,true,false,''); e:='OK'; EXCEPTION WHEN OTHERS THEN e:=SQLERRM; END;
         INSERT INTO t_res VALUES (n,'ปิดงานโดยไม่ใส่บันทึก','NOTE_REQUIRED',e);
  n:=15; PERFORM fn_maintenance_change_status(b,'COMPLETE',stf,true,false,'เปลี่ยนหลอดไฟแล้ว');
         INSERT INTO t_res VALUES (n,'ปิดงานซ่อม','COMPLETED',(SELECT booking_status FROM v_maintenance_requests WHERE booking_id=b));
  n:=16; INSERT INTO t_res VALUES (n,'ทรัพยากรกลับเป็น','AVAILABLE',(SELECT rs.resource_status_name FROM resources r JOIN resource_status rs USING(resource_status_id) WHERE resource_id=res));
  n:=17; BEGIN PERFORM fn_maintenance_change_status(b2,'REJECT',stf,true,false,''); e:='OK'; EXCEPTION WHEN OTHERS THEN e:=SQLERRM; END;
         INSERT INTO t_res VALUES (n,'ปฏิเสธโดยไม่ใส่เหตุผล','NOTE_REQUIRED',e);
  n:=18; BEGIN PERFORM fn_maintenance_change_status(b2,'CANCEL',stf,true,false); e:='OK'; EXCEPTION WHEN OTHERS THEN e:=SQLERRM; END;
         INSERT INTO t_res VALUES (n,'Staff ยกเลิกแทนผู้แจ้ง','FORBIDDEN',e);
  n:=19; PERFORM fn_maintenance_change_status(b2,'CANCEL',usr,false,false);
         INSERT INTO t_res VALUES (n,'ผู้แจ้งยกเลิกก่อนเริ่มซ่อม','CANCELLED',(SELECT booking_status FROM v_maintenance_requests WHERE booking_id=b2));
  n:=20; INSERT INTO attachments(booking_id,file_name,file_path) VALUES (b,'a','x/a'),(b,'b','x/b'),(b,'c','x/c');
         BEGIN INSERT INTO attachments(booking_id,file_name,file_path) VALUES (b,'d','x/d'); e:='OK'; EXCEPTION WHEN OTHERS THEN e:=SQLERRM; END;
         INSERT INTO t_res VALUES (n,'แนบรูปที่ 4','TOO_MANY_ATTACHMENTS',e);
  n:=21; INSERT INTO t_res VALUES (n,'attachment_count ใน view','3',(SELECT attachment_count::text FROM v_maintenance_requests WHERE booking_id=b));
  n:=22; INSERT INTO t_res VALUES (n,'ประวัติของงาน','CREATE>ASSIGN>START>COMPLETE',
         (SELECT string_agg(ba.action_name,'>' ORDER BY h.history_id) FROM maintenance_booking_history h JOIN booking_actions ba USING(action_id) WHERE h.booking_id=b));
  n:=23; INSERT INTO t_res VALUES (n,'view เดิมยังใช้ได้ (>0 แถว)','true',(SELECT (count(*)>0)::text FROM v_maintenance_tracking_summary));
END $$;
SELECT n, test, expected, actual, CASE WHEN expected=actual THEN 'PASS' ELSE 'FAIL' END AS result FROM t_res ORDER BY n;
ROLLBACK;
