-- 012_test.sql : ทดสอบ Admin CRUD ทรัพยากร (ROLLBACK ท้ายไฟล์ ไม่ทิ้งข้อมูล)
-- รันทั้งไฟล์ใน Supabase SQL Editor แล้วดูตารางผลลัพธ์ล่างสุด (ทุกแถวต้องเป็น PASS)
BEGIN;
CREATE TEMP TABLE t_res (n INT, name TEXT, ok BOOLEAN, detail TEXT) ON COMMIT DROP;
CREATE TEMP TABLE t_ctx (k TEXT PRIMARY KEY, v BIGINT) ON COMMIT DROP;

-- ตัวช่วย: รัน SQL แล้วคืน 'OK' หรือข้อความ error
CREATE FUNCTION pg_temp.err(q TEXT) RETURNS TEXT LANGUAGE plpgsql AS $$
BEGIN EXECUTE q; RETURN 'OK'; EXCEPTION WHEN OTHERS THEN RETURN SQLERRM; END $$;

-- T1 สร้างห้อง
DO $$ DECLARE v_id BIGINT; r RECORD; BEGIN
  SELECT new_resource_id INTO v_id FROM fn_admin_resource_create('TST-ROOM-1','ห้องทดสอบ 1',1::smallint,'ตึก T ชั้น 1',12,NULL,'ห้องสำหรับทดสอบ','AVAILABLE');
  INSERT INTO t_ctx VALUES ('room', v_id);
  SELECT * INTO r FROM v_admin_resources WHERE resource_id = v_id;
  INSERT INTO t_res VALUES (1,'สร้างห้องได้และมองเห็นใน v_admin_resources',
    r.category='ROOM' AND r.capacity=12 AND r.resource_status='AVAILABLE' AND r.history_count=0 AND r.active_count=0, 'id='||v_id);
END $$;

-- T2-T7 ตรวจสอบข้อมูลรับเข้า
INSERT INTO t_res SELECT 2,'รหัสซ้ำ (ไม่สนตัวพิมพ์) = CODE_EXISTS', pg_temp.err($q$SELECT * FROM fn_admin_resource_create('tst-room-1','x ซ้ำ',1::smallint,NULL,5,NULL,NULL,'AVAILABLE')$q$)='CODE_EXISTS', '';
INSERT INTO t_res SELECT 3,'รหัสมีช่องว่าง = CODE_INVALID', pg_temp.err($q$SELECT * FROM fn_admin_resource_create('a b','ชื่อ',1::smallint,NULL,5,NULL,NULL,'AVAILABLE')$q$)='CODE_INVALID', '';
INSERT INTO t_res SELECT 4,'ห้องไม่ใส่ความจุ = CAPACITY_REQUIRED', pg_temp.err($q$SELECT * FROM fn_admin_resource_create('TST-R2','ชื่อ',1::smallint,NULL,NULL,NULL,NULL,'AVAILABLE')$q$)='CAPACITY_REQUIRED', '';
INSERT INTO t_res SELECT 5,'อุปกรณ์ไม่ใส่จำนวน = QUANTITY_REQUIRED', pg_temp.err($q$SELECT * FROM fn_admin_resource_create('TST-E1','ชื่อ',3::smallint,NULL,NULL,NULL,NULL,'AVAILABLE')$q$)='QUANTITY_REQUIRED', '';
INSERT INTO t_res SELECT 6,'ตั้งสถานะ RESERVED เอง = STATUS_NOT_ALLOWED', pg_temp.err($q$SELECT * FROM fn_admin_resource_create('TST-R3','ชื่อ',1::smallint,NULL,5,NULL,NULL,'RESERVED')$q$)='STATUS_NOT_ALLOWED', '';
INSERT INTO t_res SELECT 7,'หมวดหมู่ไม่มีจริง = CATEGORY_INVALID', pg_temp.err($q$SELECT * FROM fn_admin_resource_create('TST-R4','ชื่อ',99::smallint,NULL,5,NULL,NULL,'AVAILABLE')$q$)='CATEGORY_INVALID', '';

-- T8 แก้ไข (หมวดหมู่คงเดิม)
DO $$ DECLARE v_id BIGINT; r RECORD; BEGIN
  SELECT v INTO v_id FROM t_ctx WHERE k='room';
  PERFORM * FROM fn_admin_resource_update(v_id,'TST-ROOM-1','ห้องทดสอบ (แก้แล้ว)','ตึก T ชั้น 2',20,NULL,'แก้ไข','BROKEN');
  SELECT * INTO r FROM v_admin_resources WHERE resource_id = v_id;
  INSERT INTO t_res VALUES (8,'แก้ไขชื่อ/ที่ตั้ง/ความจุ/สถานะ ได้ หมวดหมู่ยังเป็น ROOM',
    r.resource_name='ห้องทดสอบ (แก้แล้ว)' AND r.location='ตึก T ชั้น 2' AND r.capacity=20 AND r.resource_status='BROKEN' AND r.category='ROOM', '');
END $$;
DO $$ DECLARE v_id BIGINT; v_other TEXT; BEGIN
  SELECT v INTO v_id FROM t_ctx WHERE k='room';
  SELECT resource_code INTO v_other FROM resources WHERE resource_id <> v_id ORDER BY resource_id LIMIT 1;
  INSERT INTO t_res VALUES (9,'แก้รหัสไปซ้ำกับของอื่น = CODE_EXISTS',
    pg_temp.err(format('SELECT * FROM fn_admin_resource_update(%s,%L,%L,NULL,20,NULL,NULL,%L)', v_id, v_other, 'ชื่อ', 'AVAILABLE'))='CODE_EXISTS', v_other);
  INSERT INTO t_res VALUES (10,'แก้สถานะเป็น BORROWED เอง = STATUS_NOT_ALLOWED',
    pg_temp.err(format('SELECT * FROM fn_admin_resource_update(%s,%L,%L,NULL,20,NULL,NULL,%L)', v_id, 'TST-ROOM-1', 'ชื่อ', 'BORROWED'))='STATUS_NOT_ALLOWED', '');
  INSERT INTO t_res VALUES (11,'แก้ไขทรัพยากรที่ไม่มี = RESOURCE_NOT_FOUND',
    pg_temp.err($q$SELECT * FROM fn_admin_resource_update(999999,'X1','ชื่อ',NULL,5,NULL,NULL,'AVAILABLE')$q$)='RESOURCE_NOT_FOUND', '');
  PERFORM * FROM fn_admin_resource_update(v_id,'TST-ROOM-1','ห้องทดสอบ','ตึก T',20,NULL,NULL,'AVAILABLE');
END $$;

-- T12-T19 สร้างตารางเวลาเป็นชุด
DO $$ DECLARE v_id BIGINT; v_from DATE := (now() AT TIME ZONE 'Asia/Bangkok')::date + 1; v_to DATE := (now() AT TIME ZONE 'Asia/Bangkok')::date + 14;
  v_expect INT; r RECORD; v_cnt INT; BEGIN
  SELECT v INTO v_id FROM t_ctx WHERE k='room';
  SELECT COUNT(*)::int INTO v_expect FROM generate_series(v_from, v_to, interval '1 day') d WHERE extract(isodow FROM d)::int BETWEEN 1 AND 5;
  SELECT * INTO r FROM fn_admin_generate_schedules(v_id, v_from, v_to, ARRAY[1,2,3,4,5], '[{"start":"09:00","end":"11:00"},{"start":"13:00","end":"15:00"}]'::jsonb, 1);
  INSERT INTO t_res VALUES (12,'สร้างตารางเวลาเป็นชุด (จ-ศ, 2 ช่วง/วัน)', r.inserted = v_expect*2 AND r.skipped = 0, 'inserted='||r.inserted||' expect='||v_expect*2);
  SELECT * INTO r FROM fn_admin_generate_schedules(v_id, v_from, v_to, ARRAY[1,2,3,4,5], '[{"start":"09:00","end":"11:00"},{"start":"13:00","end":"15:00"}]'::jsonb, 1);
  INSERT INTO t_res VALUES (13,'สร้างซ้ำ = ข้ามทั้งหมด ไม่ error', r.inserted = 0 AND r.skipped = v_expect*2, 'skipped='||r.skipped);
  SELECT * INTO r FROM fn_admin_generate_schedules(v_id, v_from, v_to, ARRAY[1,2,3,4,5], '[{"start":"09:30","end":"10:30"}]'::jsonb, 1);
  INSERT INTO t_res VALUES (14,'ช่วงที่ซ้อนทับของเดิม ถูกข้าม', r.inserted = 0 AND r.skipped = v_expect, '');
  SELECT COUNT(*)::int INTO v_cnt FROM v_admin_schedules WHERE resource_id = v_id AND kind='ROOM';
  INSERT INTO t_res VALUES (15,'v_admin_schedules แสดงช่วงที่สร้าง', v_cnt = v_expect*2, 'rows='||v_cnt);
END $$;
DO $$ DECLARE v_pr BIGINT; v_from DATE := (now() AT TIME ZONE 'Asia/Bangkok')::date + 1; r RECORD; v_cnt INT; v_max INT; BEGIN
  SELECT new_resource_id INTO v_pr FROM fn_admin_resource_create('TST-PRN-1','เครื่องพิมพ์ทดสอบ',2::smallint,'Lab',NULL,NULL,NULL,'AVAILABLE');
  INSERT INTO t_ctx VALUES ('printer', v_pr);
  SELECT * INTO r FROM fn_admin_generate_schedules(v_pr, v_from, v_from + 6, ARRAY[1,2,3,4,5,6,7], '[{"start":"10:00","end":"12:00"}]'::jsonb, 2);
  SELECT COUNT(*)::int, MAX(max_slots) INTO v_cnt, v_max FROM printer_schedules WHERE resource_id = v_pr;
  INSERT INTO t_res VALUES (16,'เครื่องพิมพ์: สร้าง 7 วัน ลงตาราง printer_schedules + max_slots=2', r.inserted=7 AND v_cnt=7 AND v_max=2, '');
END $$;
INSERT INTO t_res SELECT 17,'หมวดอุปกรณ์สร้างตารางเวลาไม่ได้ = NO_SCHEDULE_FOR_CATEGORY',
  pg_temp.err(format($q$SELECT * FROM fn_admin_generate_schedules(%s, current_date+1, current_date+2, ARRAY[1], '[{"start":"09:00","end":"10:00"}]'::jsonb, 1)$q$, (SELECT resource_id FROM resources WHERE type_id=3 LIMIT 1)))='NO_SCHEDULE_FOR_CATEGORY', '';

DO $$ DECLARE v_id BIGINT; BEGIN
  SELECT v INTO v_id FROM t_ctx WHERE k='room';
  INSERT INTO t_res VALUES (18,'วันที่ย้อนหลัง = DATE_IN_PAST', pg_temp.err(format($q$SELECT * FROM fn_admin_generate_schedules(%s, current_date-30, current_date+1, ARRAY[1], '[{"start":"09:00","end":"10:00"}]'::jsonb, 1)$q$, v_id))='DATE_IN_PAST', '');
  INSERT INTO t_res VALUES (19,'ช่วงวันที่เกิน 92 วัน = RANGE_TOO_LONG', pg_temp.err(format($q$SELECT * FROM fn_admin_generate_schedules(%s, current_date+1, current_date+200, ARRAY[1], '[{"start":"09:00","end":"10:00"}]'::jsonb, 1)$q$, v_id))='RANGE_TOO_LONG', '');
  INSERT INTO t_res VALUES (20,'วันในสัปดาห์ไม่ถูกต้อง = WEEKDAYS_INVALID', pg_temp.err(format($q$SELECT * FROM fn_admin_generate_schedules(%s, current_date+1, current_date+5, ARRAY[8], '[{"start":"09:00","end":"10:00"}]'::jsonb, 1)$q$, v_id))='WEEKDAYS_INVALID', '');
  INSERT INTO t_res VALUES (21,'ช่วงเวลาในคำขอซ้อนกันเอง = SLOTS_OVERLAP', pg_temp.err(format($q$SELECT * FROM fn_admin_generate_schedules(%s, current_date+1, current_date+5, ARRAY[1], '[{"start":"09:00","end":"11:00"},{"start":"10:00","end":"12:00"}]'::jsonb, 1)$q$, v_id))='SLOTS_OVERLAP', '');
  INSERT INTO t_res VALUES (22,'ช่วงเวลาซ้ำกันเป๊ะ = SLOTS_OVERLAP', pg_temp.err(format($q$SELECT * FROM fn_admin_generate_schedules(%s, current_date+1, current_date+5, ARRAY[1], '[{"start":"09:00","end":"11:00"},{"start":"09:00","end":"11:00"}]'::jsonb, 1)$q$, v_id))='SLOTS_OVERLAP', '');
  INSERT INTO t_res VALUES (23,'เวลาไม่ถูกต้อง (25:00) = SLOTS_INVALID', pg_temp.err(format($q$SELECT * FROM fn_admin_generate_schedules(%s, current_date+1, current_date+5, ARRAY[1], '[{"start":"25:00","end":"26:00"}]'::jsonb, 1)$q$, v_id))='SLOTS_INVALID', '');
  INSERT INTO t_res VALUES (24,'เวลาสิ้นสุดก่อนเริ่ม = SLOTS_INVALID', pg_temp.err(format($q$SELECT * FROM fn_admin_generate_schedules(%s, current_date+1, current_date+5, ARRAY[1], '[{"start":"11:00","end":"09:00"}]'::jsonb, 1)$q$, v_id))='SLOTS_INVALID', '');
  INSERT INTO t_res VALUES (25,'slots ไม่ใช่ array = SLOTS_INVALID', pg_temp.err(format($q$SELECT * FROM fn_admin_generate_schedules(%s, current_date+1, current_date+5, ARRAY[1], '{"a":1}'::jsonb, 1)$q$, v_id))='SLOTS_INVALID', '');
  INSERT INTO t_res VALUES (26,'max_slots นอกช่วง = MAX_SLOTS_INVALID', pg_temp.err(format($q$SELECT * FROM fn_admin_generate_schedules(%s, current_date+1, current_date+5, ARRAY[1], '[{"start":"09:00","end":"10:00"}]'::jsonb, 99)$q$, v_id))='MAX_SLOTS_INVALID', '');
END $$;

-- T27-T29 บล็อก/ปลดบล็อก/ลบช่วงเวลา
DO $$ DECLARE v_id BIGINT; v_s BIGINT; r TEXT; v_bookable BOOLEAN; BEGIN
  SELECT v INTO v_id FROM t_ctx WHERE k='room';
  SELECT schedule_id INTO v_s FROM room_schedules WHERE resource_id = v_id ORDER BY work_date, start_time LIMIT 1;
  INSERT INTO t_ctx VALUES ('slot', v_s);
  SELECT out_status INTO r FROM fn_admin_schedule_set_block('ROOM', v_s, true);
  SELECT is_bookable INTO v_bookable FROM v_ai_room_slots a JOIN room_schedules s ON s.work_date=a.work_date AND s.start_time=a.start_time AND s.schedule_id=v_s AND a.resource_code='TST-ROOM-1';
  INSERT INTO t_res VALUES (27,'บล็อกช่วงเวลา → BLOCKED และจองไม่ได้ (is_bookable=false)', r='BLOCKED' AND v_bookable = false, 'status='||r);
  SELECT out_status INTO r FROM fn_admin_schedule_set_block('ROOM', v_s, false);
  INSERT INTO t_res VALUES (28,'ปลดบล็อก → AVAILABLE', r='AVAILABLE', '');
  INSERT INTO t_res VALUES (29,'kind ไม่ถูกต้อง = KIND_INVALID', pg_temp.err(format($q$SELECT * FROM fn_admin_schedule_set_block('HACK',%s,true)$q$, v_s))='KIND_INVALID', '');
END $$;
DO $$ DECLARE v_s BIGINT; v_booked BIGINT; v_res TEXT; BEGIN
  SELECT s.schedule_id INTO v_booked FROM room_schedules s JOIN room_bookings b ON b.schedule_id=s.schedule_id
    JOIN booking_status bs ON bs.booking_status_id=b.booking_status_id WHERE bs.booking_status_name IN ('PENDING','APPROVED') LIMIT 1;
  IF v_booked IS NULL THEN
    INSERT INTO t_res VALUES (30,'บล็อกช่วงที่มีงานค้าง = SLOT_HAS_BOOKINGS (ข้าม: ไม่มีข้อมูลตัวอย่าง)', true, 'skip');
  ELSE
    INSERT INTO t_res VALUES (30,'บล็อกช่วงที่มีงานค้าง = SLOT_HAS_BOOKINGS', pg_temp.err(format($q$SELECT * FROM fn_admin_schedule_set_block('ROOM',%s,true)$q$, v_booked))='SLOT_HAS_BOOKINGS', '');
  END IF;
  SELECT s.schedule_id INTO v_booked FROM room_schedules s JOIN room_bookings b ON b.schedule_id=s.schedule_id LIMIT 1;
  INSERT INTO t_res VALUES (31,'ลบช่วงที่เคยมีการจอง = SLOT_HAS_BOOKINGS', pg_temp.err(format($q$SELECT * FROM fn_admin_schedule_delete('ROOM',%s)$q$, v_booked))='SLOT_HAS_BOOKINGS', '');
  SELECT v INTO v_s FROM t_ctx WHERE k='slot';
  v_res := pg_temp.err(format($q$SELECT * FROM fn_admin_schedule_delete('ROOM',%s)$q$, v_s));
  INSERT INTO t_res VALUES (32,'ลบช่วงที่ไม่มีการจอง สำเร็จ', v_res='OK' AND NOT EXISTS (SELECT 1 FROM room_schedules WHERE schedule_id=v_s), v_res);
  INSERT INTO t_res VALUES (33,'ลบช่วงที่ไม่มีอยู่ = SCHEDULE_NOT_FOUND', pg_temp.err($q$SELECT * FROM fn_admin_schedule_delete('PRINTER',999999999)$q$)='SCHEDULE_NOT_FOUND', '');
END $$;

-- T34-T37 ลบทรัพยากร
DO $$ DECLARE v_room BIGINT; v_prn BIGINT; v_hist BIGINT; v_act BIGINT; r TEXT; v_left INT; BEGIN
  SELECT v INTO v_room FROM t_ctx WHERE k='room';
  SELECT v INTO v_prn  FROM t_ctx WHERE k='printer';
  SELECT result INTO r FROM fn_admin_resource_delete(v_room);
  SELECT COUNT(*)::int INTO v_left FROM room_schedules WHERE resource_id = v_room;
  INSERT INTO t_res VALUES (34,'ลบทรัพยากรที่ไม่มีประวัติ = DELETED และตารางเวลาถูกลบตาม', r='DELETED' AND NOT EXISTS (SELECT 1 FROM resources WHERE resource_id=v_room) AND v_left=0, 'result='||r);
  SELECT result INTO r FROM fn_admin_resource_delete(v_prn);
  INSERT INTO t_res VALUES (35,'ลบเครื่องพิมพ์ที่ไม่มีประวัติ = DELETED', r='DELETED', '');

  SELECT resource_id INTO v_hist FROM v_admin_resources WHERE history_count>0 AND active_count=0 AND resource_status <> 'OUT_OF_SERVICE' ORDER BY resource_id LIMIT 1;
  IF v_hist IS NULL THEN
    INSERT INTO t_res VALUES (36,'ลบทรัพยากรที่มีประวัติ = DEACTIVATED (ข้าม: ไม่มีข้อมูลตัวอย่าง)', true, 'skip');
  ELSE
    SELECT result INTO r FROM fn_admin_resource_delete(v_hist);
    INSERT INTO t_res VALUES (36,'ลบทรัพยากรที่มีประวัติ = DEACTIVATED (ยังอยู่ในระบบ สถานะ OUT_OF_SERVICE)',
      r='DEACTIVATED' AND (SELECT resource_status FROM v_admin_resources WHERE resource_id=v_hist)='OUT_OF_SERVICE', 'resource_id='||v_hist);
  END IF;

  SELECT resource_id INTO v_act FROM v_admin_resources WHERE active_count>0 ORDER BY resource_id LIMIT 1;
  IF v_act IS NULL THEN
    INSERT INTO t_res VALUES (37,'ลบทรัพยากรที่มีงานค้าง = HAS_ACTIVE_BOOKINGS (ข้าม: ไม่มีข้อมูลตัวอย่าง)', true, 'skip');
  ELSE
    INSERT INTO t_res VALUES (37,'ลบทรัพยากรที่มีงานค้าง = HAS_ACTIVE_BOOKINGS', pg_temp.err(format('SELECT * FROM fn_admin_resource_delete(%s)', v_act))='HAS_ACTIVE_BOOKINGS', 'resource_id='||v_act);
  END IF;
  INSERT INTO t_res VALUES (38,'ลบทรัพยากรที่ไม่มี = RESOURCE_NOT_FOUND', pg_temp.err('SELECT * FROM fn_admin_resource_delete(999999999)')='RESOURCE_NOT_FOUND', '');
END $$;

-- T39 จำนวนแถวของ view ตรงกับตารางจริง
INSERT INTO t_res SELECT 39,'v_admin_resources / v_admin_schedules จำนวนตรงกับตาราง',
  (SELECT COUNT(*) FROM v_admin_resources) = (SELECT COUNT(*) FROM resources)
  AND (SELECT COUNT(*) FROM v_admin_schedules) = (SELECT COUNT(*) FROM room_schedules) + (SELECT COUNT(*) FROM printer_schedules), '';

-- T40 สิทธิ์
INSERT INTO t_res SELECT 40,'anon/authenticated เรียกฟังก์ชัน/อ่าน view ไม่ได้ | service_role ได้',
  NOT has_function_privilege('anon','fn_admin_resource_delete(bigint)','EXECUTE')
  AND NOT has_function_privilege('authenticated','fn_admin_resource_create(text,text,smallint,text,integer,integer,text,text)','EXECUTE')
  AND NOT has_function_privilege('authenticated','fn_admin_generate_schedules(bigint,date,date,integer[],jsonb,integer)','EXECUTE')
  AND NOT has_table_privilege('authenticated','public.v_admin_resources','SELECT')
  AND has_function_privilege('service_role','fn_admin_resource_update(bigint,text,text,text,integer,integer,text,text)','EXECUTE')
  AND has_table_privilege('service_role','public.v_admin_schedules','SELECT'), '';

SELECT n AS test_no, name, CASE WHEN ok THEN 'PASS' ELSE 'FAIL' END AS result, detail FROM t_res ORDER BY n;
ROLLBACK;
