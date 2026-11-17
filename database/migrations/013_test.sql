-- 013_test.sql : ทดสอบ Admin จัดการผู้ใช้ (ROLLBACK ท้ายไฟล์ ไม่ทิ้งข้อมูล)
-- รันทั้งไฟล์ใน Supabase SQL Editor แล้วดูตารางผลลัพธ์ล่างสุด (ทุกแถวต้องเป็น PASS)
BEGIN;
CREATE TEMP TABLE t_res (n INT, name TEXT, ok BOOLEAN, detail TEXT) ON COMMIT DROP;
CREATE TEMP TABLE t_ctx (k TEXT PRIMARY KEY, v BIGINT) ON COMMIT DROP;

CREATE FUNCTION pg_temp.err(q TEXT) RETURNS TEXT LANGUAGE plpgsql AS $$
BEGIN EXECUTE q; RETURN 'OK'; EXCEPTION WHEN OTHERS THEN RETURN SQLERRM; END $$;

-- ข้อมูลทดสอบ: Admin 2 คน, นักศึกษา 1, Staff 1 (ทำให้ Admin จริงทั้งหมดไม่ปรากฏ เพื่อทดสอบกติกา "เหลือ Admin")
INSERT INTO users (full_name, email, role_id, user_status) VALUES ('TST Admin A','tst-admin-a@example.test',(SELECT role_id FROM user_roles WHERE role_name='ADMIN'),'ACTIVE');
INSERT INTO users (full_name, email, role_id, user_status) VALUES ('TST Admin B','tst-admin-b@example.test',(SELECT role_id FROM user_roles WHERE role_name='ADMIN'),'ACTIVE');
INSERT INTO users (full_name, email, role_id, user_status) VALUES ('TST Student','tst-student@example.test',(SELECT role_id FROM user_roles WHERE role_name='USER'),'ACTIVE');
INSERT INTO users (full_name, email, role_id, user_status) VALUES ('TST Staff','tst-staff@example.test',(SELECT role_id FROM user_roles WHERE role_name='STAFF'),'ACTIVE');
INSERT INTO t_ctx SELECT 'a', user_id FROM users WHERE email='tst-admin-a@example.test';
INSERT INTO t_ctx SELECT 'b', user_id FROM users WHERE email='tst-admin-b@example.test';
INSERT INTO t_ctx SELECT 's', user_id FROM users WHERE email='tst-student@example.test';
INSERT INTO t_ctx SELECT 'f', user_id FROM users WHERE email='tst-staff@example.test';
-- ปิด Admin จริงชั่วคราวภายในทรานแซกชันนี้ (ROLLBACK ท้ายไฟล์)
UPDATE users SET user_status='INACTIVE' WHERE role_id=(SELECT role_id FROM user_roles WHERE role_name='ADMIN') AND user_id NOT IN (SELECT v FROM t_ctx WHERE k IN ('a','b'));

-- T1 view
INSERT INTO t_res SELECT 1,'v_admin_users แสดงผู้ใช้ทดสอบ พร้อม role/สถานะ/จำนวนรายการ = 0',
  (SELECT role='USER' AND user_status='ACTIVE' AND booking_count=0 AND active_count=0 FROM v_admin_users WHERE user_id=(SELECT v FROM t_ctx WHERE k='s')), '';
-- T2 รวมจำนวนรายการตรงกับนับมือ (ผู้ใช้จริงที่มีรายการมากสุด)
DO $$ DECLARE v_u BIGINT; v_exp INT; v_got INT; BEGIN
  SELECT user_id INTO v_u FROM v_admin_users ORDER BY booking_count DESC, user_id LIMIT 1;
  SELECT (SELECT COUNT(*) FROM room_bookings WHERE user_id=v_u)+(SELECT COUNT(*) FROM printer_bookings WHERE user_id=v_u)
        +(SELECT COUNT(*) FROM equipment_bookings WHERE user_id=v_u)+(SELECT COUNT(*) FROM maintenance_bookings WHERE user_id=v_u) INTO v_exp;
  SELECT booking_count INTO v_got FROM v_admin_users WHERE user_id=v_u;
  INSERT INTO t_res VALUES (2,'booking_count ตรงกับนับจาก 4 ตารางการจอง', v_exp = v_got, 'user='||v_u||' นับมือ='||v_exp||' view='||v_got);
END $$;

-- T3-T5 เปลี่ยน role
DO $$ DECLARE v_r TEXT; v_a BIGINT; v_s BIGINT; BEGIN
  SELECT v INTO v_a FROM t_ctx WHERE k='a'; SELECT v INTO v_s FROM t_ctx WHERE k='s';
  v_r := pg_temp.err(format('SELECT fn_admin_user_set_role(%s,%s,%L)', v_a, v_s, 'STAFF'));
  INSERT INTO t_res VALUES (3,'Admin A เลื่อนนักศึกษาเป็น STAFF ได้ และ role เปลี่ยนจริง',
    v_r='OK' AND (SELECT role FROM v_admin_users WHERE user_id=v_s)='STAFF', v_r);
END $$;
INSERT INTO t_res SELECT 4,'role ที่ไม่มีจริง = ROLE_INVALID',
  pg_temp.err(format('SELECT fn_admin_user_set_role(%s,%s,%L)',(SELECT v FROM t_ctx WHERE k='a'),(SELECT v FROM t_ctx WHERE k='s'),'BOSS'))='ROLE_INVALID', '';
INSERT INTO t_res SELECT 5,'role เท่าเดิม = สำเร็จโดยไม่เปลี่ยน (idempotent)',
  pg_temp.err(format('SELECT fn_admin_user_set_role(%s,%s,%L)',(SELECT v FROM t_ctx WHERE k='a'),(SELECT v FROM t_ctx WHERE k='s'),'STAFF'))='OK', '';

-- T6-T8 ป้องกัน
INSERT INTO t_res SELECT 6,'แก้ role ตัวเอง = SELF_CHANGE',
  pg_temp.err(format('SELECT fn_admin_user_set_role(%s,%s,%L)',(SELECT v FROM t_ctx WHERE k='a'),(SELECT v FROM t_ctx WHERE k='a'),'USER'))='SELF_CHANGE', '';
INSERT INTO t_res SELECT 7,'ระงับตัวเอง = SELF_CHANGE',
  pg_temp.err(format('SELECT fn_admin_user_set_status(%s,%s,%L)',(SELECT v FROM t_ctx WHERE k='a'),(SELECT v FROM t_ctx WHERE k='a'),'SUSPENDED'))='SELF_CHANGE', '';
INSERT INTO t_res SELECT 8,'Staff เป็นผู้ทำรายการ = ACTOR_NOT_ADMIN',
  pg_temp.err(format('SELECT fn_admin_user_set_role(%s,%s,%L)',(SELECT v FROM t_ctx WHERE k='f'),(SELECT v FROM t_ctx WHERE k='s'),'USER'))='ACTOR_NOT_ADMIN', '';
INSERT INTO t_res SELECT 9,'ผู้ใช้เป้าหมายไม่มีอยู่ = USER_NOT_FOUND',
  pg_temp.err(format('SELECT fn_admin_user_set_role(%s,%s,%L)',(SELECT v FROM t_ctx WHERE k='a'),-1,'USER'))='USER_NOT_FOUND', '';

-- T10-T12 สถานะ
INSERT INTO t_res SELECT 10,'สถานะที่ไม่มีจริง = STATUS_INVALID',
  pg_temp.err(format('SELECT fn_admin_user_set_status(%s,%s,%L)',(SELECT v FROM t_ctx WHERE k='a'),(SELECT v FROM t_ctx WHERE k='f'),'BANNED'))='STATUS_INVALID', '';
DO $$ DECLARE v_r TEXT; v_a BIGINT; v_f BIGINT; BEGIN
  SELECT v INTO v_a FROM t_ctx WHERE k='a'; SELECT v INTO v_f FROM t_ctx WHERE k='f';
  v_r := pg_temp.err(format('SELECT fn_admin_user_set_status(%s,%s,%L)', v_a, v_f, 'SUSPENDED'));
  INSERT INTO t_res VALUES (11,'ระงับ Staff (ไม่มีรายการ active) ได้ และสถานะเปลี่ยนจริง',
    v_r='OK' AND (SELECT user_status FROM v_admin_users WHERE user_id=v_f)='SUSPENDED', v_r);
  v_r := pg_temp.err(format('SELECT fn_admin_user_set_status(%s,%s,%L)', v_a, v_f, 'ACTIVE'));
  INSERT INTO t_res VALUES (12,'เปิดใช้งานกลับเป็น ACTIVE ได้ และสถานะเปลี่ยนจริง',
    v_r='OK' AND (SELECT user_status FROM v_admin_users WHERE user_id=v_f)='ACTIVE', v_r);
END $$;

-- T13 มีรายการ active = ระงับไม่ได้ (ใช้ผู้ใช้จริงที่มีรายการ active ถ้ามี)
DO $$ DECLARE v_u BIGINT; v_a BIGINT; v_res TEXT; BEGIN
  SELECT v INTO v_a FROM t_ctx WHERE k='a';
  SELECT user_id INTO v_u FROM v_admin_users WHERE active_count > 0 AND user_id <> v_a ORDER BY user_id LIMIT 1;
  IF v_u IS NULL THEN
    INSERT INTO t_res VALUES (13,'ระงับผู้ใช้ที่มีรายการ active = HAS_ACTIVE_BOOKINGS (ไม่มีข้อมูล active ในฐาน: ข้าม)', TRUE, 'ไม่มีข้อมูล');
  ELSE
    v_res := pg_temp.err(format('SELECT fn_admin_user_set_status(%s,%s,%L)', v_a, v_u, 'SUSPENDED'));
    INSERT INTO t_res VALUES (13,'ระงับผู้ใช้ที่มีรายการ active = HAS_ACTIVE_BOOKINGS', v_res='HAS_ACTIVE_BOOKINGS', 'user='||v_u||' ผล='||v_res);
  END IF;
END $$;

-- T14 ลำดับแข่งกัน: A ลดสิทธิ์ B สำเร็จ แล้ว B (ตอนนี้ไม่ใช่ Admin) พยายามลด A = ACTOR_NOT_ADMIN
INSERT INTO t_res SELECT 14,'Admin A ลด Admin B เป็น USER ได้ (A ยังเป็น Admin อยู่)',
  pg_temp.err(format('SELECT fn_admin_user_set_role(%s,%s,%L)',(SELECT v FROM t_ctx WHERE k='a'),(SELECT v FROM t_ctx WHERE k='b'),'USER'))='OK', '';
INSERT INTO t_res SELECT 15,'B ที่ถูกลดสิทธิ์แล้วลด A กลับไม่ได้ = ACTOR_NOT_ADMIN (ไม่เหลือ Admin 0 คน)',
  pg_temp.err(format('SELECT fn_admin_user_set_role(%s,%s,%L)',(SELECT v FROM t_ctx WHERE k='b'),(SELECT v FROM t_ctx WHERE k='a'),'USER'))='ACTOR_NOT_ADMIN'
  AND (SELECT COUNT(*) FROM users u JOIN user_roles r ON r.role_id=u.role_id WHERE r.role_name='ADMIN' AND u.user_status='ACTIVE') >= 1, '';

-- T16 Admin ที่ถูกระงับแล้ว ทำรายการไม่ได้
DO $$ DECLARE v_a BIGINT; v_b BIGINT; v_f BIGINT; BEGIN
  SELECT v INTO v_a FROM t_ctx WHERE k='a'; SELECT v INTO v_b FROM t_ctx WHERE k='b'; SELECT v INTO v_f FROM t_ctx WHERE k='f';
  PERFORM fn_admin_user_set_role(v_a, v_b, 'ADMIN');
  PERFORM fn_admin_user_set_status(v_a, v_b, 'SUSPENDED');
  INSERT INTO t_res VALUES (16,'Admin ที่ถูกระงับ ทำรายการไม่ได้ = ACTOR_NOT_ADMIN',
    pg_temp.err(format('SELECT fn_admin_user_set_status(%s,%s,%L)', v_b, v_f, 'SUSPENDED'))='ACTOR_NOT_ADMIN', '');
END $$;

-- T17 สิทธิ์การเรียก
INSERT INTO t_res SELECT 17,'anon/authenticated เรียกฟังก์ชัน/อ่าน view ไม่ได้ ส่วน service_role ได้',
  NOT has_function_privilege('anon','fn_admin_user_set_role(bigint,bigint,text)','EXECUTE')
  AND NOT has_function_privilege('authenticated','fn_admin_user_set_status(bigint,bigint,text)','EXECUTE')
  AND NOT has_table_privilege('anon','v_admin_users','SELECT')
  AND has_function_privilege('service_role','fn_admin_user_set_role(bigint,bigint,text)','EXECUTE')
  AND has_table_privilege('service_role','v_admin_users','SELECT'), '';

SELECT n, name, CASE WHEN ok THEN 'PASS' ELSE 'FAIL' END AS result, detail FROM t_res ORDER BY n;
ROLLBACK;
