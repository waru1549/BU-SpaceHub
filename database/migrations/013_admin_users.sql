-- =====================================================================
-- 013_admin_users.sql  |  Admin จัดการผู้ใช้ (Step U1: DB)
-- ทำซ้ำได้ | รันใน Supabase SQL Editor | เรียกผ่าน BE (service_role) เท่านั้น
--   v_admin_users              : รายชื่อผู้ใช้ + role + สถานะ + จำนวนรายการ + ล็อกอินล่าสุด
--   fn_admin_user_set_role     : เปลี่ยน role (USER/STAFF/ADMIN)
--   fn_admin_user_set_status   : เปลี่ยนสถานะบัญชี (ACTIVE/INACTIVE/SUSPENDED)
-- กติกา: ผู้ทำรายการต้องเป็น ADMIN ที่ ACTIVE | แก้บัญชีตัวเองไม่ได้
--        ต้องเหลือ ADMIN ที่ ACTIVE อย่างน้อย 1 คน (ล็อกกันสองคนลดสิทธิ์พร้อมกัน)
--        ระงับ/ปิดบัญชีไม่ได้ถ้ายังมีรายการ active (รออนุมัติ/อนุมัติแล้ว/กำลังดำเนินการ/รับแล้ว/เกินกำหนด)
--        การบล็อกผู้ถูกระงับทำที่ resolveUserFromToken อยู่แล้ว (403 ถ้าไม่ ACTIVE) ไม่ต้องแก้ BE ส่วนนั้น
-- =====================================================================

-- 1) View ------------------------------------------------------------------
CREATE OR REPLACE VIEW v_admin_users WITH (security_invoker = true) AS
SELECT u.user_id,
       u.user_code,
       u.university_id,
       u.full_name,
       u.email,
       u.phone,
       u.role_id,
       ur.role_name        AS role,
       u.user_status,
       u.created_at,
       u.last_login,
       COALESCE(h.total_count, 0)  AS booking_count,
       COALESCE(h.active_count, 0) AS active_count
FROM users u
JOIN user_roles ur ON ur.role_id = u.role_id
LEFT JOIN LATERAL (
  SELECT COUNT(*)::int AS total_count,
         COUNT(*) FILTER (WHERE st IN ('PENDING','APPROVED','IN_PROGRESS','RECEIVED','OVERDUE'))::int AS active_count
  FROM (
    SELECT bs.booking_status_name AS st FROM room_bookings b
      JOIN booking_status bs ON bs.booking_status_id = b.booking_status_id WHERE b.user_id = u.user_id
    UNION ALL
    SELECT bs.booking_status_name FROM printer_bookings b
      JOIN booking_status bs ON bs.booking_status_id = b.booking_status_id WHERE b.user_id = u.user_id
    UNION ALL
    SELECT bs.booking_status_name FROM equipment_bookings b
      JOIN booking_status bs ON bs.booking_status_id = b.booking_status_id WHERE b.user_id = u.user_id
    UNION ALL
    SELECT bs.booking_status_name FROM maintenance_bookings b
      JOIN booking_status bs ON bs.booking_status_id = b.booking_status_id WHERE b.user_id = u.user_id
  ) x
) h ON TRUE;

-- 2) ตรวจผู้ทำรายการ + ล็อก (ใช้ร่วมกัน) -----------------------------------
CREATE OR REPLACE FUNCTION fn_admin_user_guard(p_actor BIGINT, p_user BIGINT)
RETURNS TABLE (cur_role TEXT, cur_status TEXT)
LANGUAGE plpgsql AS $$
BEGIN
  IF p_actor IS NULL OR p_user IS NULL THEN RAISE EXCEPTION 'USER_NOT_FOUND'; END IF;
  IF p_actor = p_user THEN RAISE EXCEPTION 'SELF_CHANGE'; END IF;

  -- เรียงคิวทุกการเปลี่ยน role/สถานะ: กัน Admin สองคนลดสิทธิ์กันเองพร้อมกันจนเหลือ 0
  PERFORM pg_advisory_xact_lock(hashtext('fn_admin_user_change'));

  IF NOT EXISTS (
    SELECT 1 FROM users a JOIN user_roles r ON r.role_id = a.role_id
     WHERE a.user_id = p_actor AND r.role_name = 'ADMIN' AND a.user_status = 'ACTIVE'
  ) THEN RAISE EXCEPTION 'ACTOR_NOT_ADMIN'; END IF;

  RETURN QUERY
    SELECT r.role_name::text, u.user_status::text
      FROM users u JOIN user_roles r ON r.role_id = u.role_id
     WHERE u.user_id = p_user FOR UPDATE OF u;
  IF NOT FOUND THEN RAISE EXCEPTION 'USER_NOT_FOUND'; END IF;
END $$;

-- 3) เปลี่ยน role -------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_admin_user_set_role(p_actor BIGINT, p_user BIGINT, p_role TEXT)
RETURNS BIGINT
LANGUAGE plpgsql AS $$
DECLARE v_role_id SMALLINT; v_cur_role TEXT; v_cur_status TEXT;
BEGIN
  SELECT role_id INTO v_role_id FROM user_roles WHERE role_name = p_role;
  IF v_role_id IS NULL THEN RAISE EXCEPTION 'ROLE_INVALID'; END IF;

  SELECT g.cur_role, g.cur_status INTO v_cur_role, v_cur_status FROM fn_admin_user_guard(p_actor, p_user) g;

  IF v_cur_role = p_role THEN RETURN p_user; END IF;  -- ไม่เปลี่ยน = สำเร็จเฉย ๆ

  IF v_cur_role = 'ADMIN' AND v_cur_status = 'ACTIVE' AND NOT EXISTS (
    SELECT 1 FROM users u JOIN user_roles r ON r.role_id = u.role_id
     WHERE r.role_name = 'ADMIN' AND u.user_status = 'ACTIVE' AND u.user_id <> p_user
  ) THEN RAISE EXCEPTION 'LAST_ADMIN'; END IF;

  UPDATE users SET role_id = v_role_id WHERE user_id = p_user;
  RETURN p_user;
END $$;

-- 4) เปลี่ยนสถานะบัญชี ------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_admin_user_set_status(p_actor BIGINT, p_user BIGINT, p_status TEXT)
RETURNS BIGINT
LANGUAGE plpgsql AS $$
DECLARE v_cur_role TEXT; v_cur_status TEXT; v_active INT;
BEGIN
  IF p_status IS NULL OR p_status NOT IN ('ACTIVE','INACTIVE','SUSPENDED') THEN RAISE EXCEPTION 'STATUS_INVALID'; END IF;

  SELECT g.cur_role, g.cur_status INTO v_cur_role, v_cur_status FROM fn_admin_user_guard(p_actor, p_user) g;

  IF v_cur_status = p_status THEN RETURN p_user; END IF;

  IF p_status <> 'ACTIVE' THEN
    IF v_cur_role = 'ADMIN' AND v_cur_status = 'ACTIVE' AND NOT EXISTS (
      SELECT 1 FROM users u JOIN user_roles r ON r.role_id = u.role_id
       WHERE r.role_name = 'ADMIN' AND u.user_status = 'ACTIVE' AND u.user_id <> p_user
    ) THEN RAISE EXCEPTION 'LAST_ADMIN'; END IF;

    SELECT active_count INTO v_active FROM v_admin_users WHERE user_id = p_user;
    IF v_active > 0 THEN RAISE EXCEPTION 'HAS_ACTIVE_BOOKINGS'; END IF;
  END IF;

  UPDATE users SET user_status = p_status WHERE user_id = p_user;
  RETURN p_user;
END $$;

-- 5) สิทธิ์: เรียกได้เฉพาะ service_role (BE) ------------------------------
REVOKE ALL ON v_admin_users FROM PUBLIC, anon, authenticated;
GRANT SELECT ON v_admin_users TO service_role;
REVOKE ALL ON FUNCTION fn_admin_user_guard(BIGINT, BIGINT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION fn_admin_user_set_role(BIGINT, BIGINT, TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION fn_admin_user_set_status(BIGINT, BIGINT, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_admin_user_guard(BIGINT, BIGINT) TO service_role;
GRANT EXECUTE ON FUNCTION fn_admin_user_set_role(BIGINT, BIGINT, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION fn_admin_user_set_status(BIGINT, BIGINT, TEXT) TO service_role;
