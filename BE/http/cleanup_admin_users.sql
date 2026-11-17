-- ใช้กับการทดสอบ Step U2 (รันใน Supabase SQL Editor ทีละข้อ) ---------------------------------

-- (0) สร้างผู้ใช้ทดสอบ 1 คน (นักศึกษา) แล้วจดค่า user_id เป็น @tstId
INSERT INTO users (full_name, email, role_id, user_status)
SELECT 'TST ผู้ใช้ทดสอบ', 'tst-u2@example.test', role_id, 'ACTIVE' FROM user_roles WHERE role_name = 'USER'
ON CONFLICT (email) DO NOTHING;
SELECT 'tstId' AS use_as, user_id, email FROM users WHERE email = 'tst-u2@example.test';

-- (1) หา @activeUserId = ผู้ใช้ (ไม่ใช่ Admin) ที่มีรายการ active สำหรับข้อ U23
SELECT 'activeUserId' AS use_as, user_id, full_name, role, active_count
FROM v_admin_users WHERE active_count > 0 AND role <> 'ADMIN' ORDER BY user_id LIMIT 3;

-- (2) ค่า @selfId = user_id ของ Admin ที่ใช้ tokenA (ดูจากรายชื่อ)
SELECT 'selfId?' AS use_as, user_id, full_name, email FROM v_admin_users WHERE role = 'ADMIN' AND user_status = 'ACTIVE';

-- (3) หลังทดสอบ: ตรวจว่าไม่เหลือผู้ใช้ทดสอบ แล้วลบ (ผลตรวจต้องเป็น 0 แถว)
DELETE FROM users WHERE email = 'tst-u2@example.test';
SELECT user_id, email FROM users WHERE email LIKE 'tst-%@example.test';

-- (4) ตรวจว่า role/สถานะของบัญชีจริงกลับมาปกติ (ทุกคนที่ใช้ทดสอบต้องเป็น ACTIVE และ role เดิม)
SELECT user_id, full_name, role, user_status FROM v_admin_users WHERE role <> 'USER' OR user_status <> 'ACTIVE' ORDER BY user_id;
