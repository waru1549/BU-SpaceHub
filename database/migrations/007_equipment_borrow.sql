-- =====================================================
-- 007_equipment_borrow.sql  (Step 9-1: Equipment borrow/return)
-- สถานะ: PENDING -> APPROVED -> RECEIVED(กำลังยืม) -> RETURNED
--        RECEIVED -> OVERDUE (ตั้งอัตโนมัติเมื่อเลยกำหนดคืน) -> RETURNED
--        PENDING -> REJECTED | PENDING/APPROVED -> CANCELLED
-- ผู้กด: STAFF = APPROVE/REJECT/RECEIVE(ส่งมอบ)/RETURN(รับคืน), OWNER = CANCEL
-- กติกา: ยืมไม่เกิน 7 วัน | พร้อมกันไม่เกิน 2 รายการ | จองล่วงหน้าไม่เกิน 14 วัน | กำหนดคืน 16:00
--        คืนล่าช้าไม่คิดค่าปรับ | ชำรุด/สูญหาย Staff กรอกยอดตอนรับคืน (fines)
--        มีของเกินกำหนด หรือค่าปรับ UNPAID = ยืมใหม่ไม่ได้ | Staff อนุมัติของตัวเองไม่ได้
-- รันซ้ำได้ (idempotent)
-- =====================================================

INSERT INTO booking_status (booking_status_id, booking_status_name)
SELECT 9, 'CANCELLED'
WHERE NOT EXISTS (SELECT 1 FROM booking_status WHERE booking_status_name = 'CANCELLED');

-- 1) ตั้ง OVERDUE อัตโนมัติ (BE เรียกก่อนอ่าน/จอง/รับคืนทุกครั้ง) คืนจำนวนแถวที่เปลี่ยน
CREATE OR REPLACE FUNCTION fn_equipment_sync_overdue()
RETURNS INT LANGUAGE plpgsql AS $$
DECLARE v_n INT;
BEGIN
  UPDATE equipment_bookings
     SET booking_status_id = (SELECT booking_status_id FROM booking_status WHERE booking_status_name = 'OVERDUE')
   WHERE actual_return_date IS NULL
     AND expected_return_date < now()
     AND booking_status_id = (SELECT booking_status_id FROM booking_status WHERE booking_status_name = 'RECEIVED');
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END $$;

-- 2) จำนวนที่ถูกกันไว้ในช่วงเวลาที่ถามถึง (ใช้ร่วมกันทั้งหน้าแสดงสต็อกและตอนจอง)
--    ของที่ยังไม่คืน (RECEIVED/OVERDUE) ถือว่าอยู่ข้างนอกจนกว่าจะคืน
CREATE OR REPLACE FUNCTION fn_equipment_reserved(p_resource_id BIGINT, p_from TIMESTAMPTZ, p_to TIMESTAMPTZ)
RETURNS INT LANGUAGE sql STABLE AS $$
  SELECT COUNT(*)::int
  FROM equipment_bookings eb
  JOIN booking_status bs ON bs.booking_status_id = eb.booking_status_id
  WHERE eb.resource_id = p_resource_id
    AND bs.booking_status_name IN ('PENDING','APPROVED','RECEIVED','OVERDUE')
    AND eb.borrow_date < p_to
    AND CASE WHEN bs.booking_status_name IN ('RECEIVED','OVERDUE')
             THEN GREATEST(eb.expected_return_date, now())
             ELSE eb.expected_return_date END > p_from;
$$;

-- 3) สต็อกคงเหลือของอุปกรณ์ทุกชิ้นในช่วงวันที่ที่เลือก (ตามเวลา Asia/Bangkok)
CREATE OR REPLACE FUNCTION fn_equipment_availability(p_borrow DATE, p_return DATE)
RETURNS TABLE (resource_id BIGINT, quantity INT, reserved INT, remaining INT)
LANGUAGE sql STABLE AS $$
  SELECT r.resource_id,
         COALESCE(r.quantity, 0),
         fn_equipment_reserved(r.resource_id,
                               p_borrow::timestamp AT TIME ZONE 'Asia/Bangkok',
                               (p_return::timestamp + interval '16 hours') AT TIME ZONE 'Asia/Bangkok'),
         GREATEST(COALESCE(r.quantity, 0) - fn_equipment_reserved(r.resource_id,
                               p_borrow::timestamp AT TIME ZONE 'Asia/Bangkok',
                               (p_return::timestamp + interval '16 hours') AT TIME ZONE 'Asia/Bangkok'), 0)
  FROM resources r
  JOIN resource_categories rc ON rc.type_id = r.type_id
  WHERE rc.type_name = 'EQUIPMENT';
$$;

-- 4) View สรุปการยืม (สำหรับตารางหน้าผู้ใช้/Staff)
CREATE OR REPLACE VIEW v_equipment_booking_summary WITH (security_invoker = true) AS
SELECT eb.booking_id,
       eb.booking_code,
       u.user_id,
       u.full_name                       AS user_name,
       r.resource_id,
       r.resource_code                   AS equipment_code,
       r.resource_name                   AS equipment_name,
       r.location,
       eb.borrow_date,
       eb.expected_return_date,
       eb.actual_return_date,
       bs.booking_status_name            AS booking_status,
       eb.borrow_purpose,
       CASE
         WHEN eb.actual_return_date IS NULL AND bs.booking_status_name IN ('RECEIVED','OVERDUE')
              THEN GREATEST(((now() AT TIME ZONE 'Asia/Bangkok')::date
                             - (eb.expected_return_date AT TIME ZONE 'Asia/Bangkok')::date), 0)
         WHEN eb.actual_return_date IS NOT NULL
              THEN GREATEST(((eb.actual_return_date AT TIME ZONE 'Asia/Bangkok')::date
                             - (eb.expected_return_date AT TIME ZONE 'Asia/Bangkok')::date), 0)
         ELSE 0 END                      AS overdue_days,
       COALESCE(f.total_fine, 0)         AS total_fine,
       COALESCE(f.unpaid_fine, 0)        AS unpaid_fine
FROM equipment_bookings eb
JOIN users          u  ON u.user_id            = eb.user_id
JOIN resources      r  ON r.resource_id        = eb.resource_id
JOIN booking_status bs ON bs.booking_status_id = eb.booking_status_id
LEFT JOIN (SELECT booking_id,
                  SUM(fine_amount)                                       AS total_fine,
                  SUM(fine_amount) FILTER (WHERE fine_status = 'UNPAID') AS unpaid_fine
           FROM fines GROUP BY booking_id) f ON f.booking_id = eb.booking_id;

-- 5) View รายการค่าปรับ (หน้าค่าปรับของ Staff และของผู้ใช้)
CREATE OR REPLACE VIEW v_equipment_fines WITH (security_invoker = true) AS
SELECT f.fine_id,
       f.booking_id,
       eb.booking_code,
       eb.user_id,
       u.full_name      AS user_name,
       r.resource_name  AS equipment_name,
       f.fine_amount,
       f.fine_reason,
       f.fine_status,
       eb.actual_return_date
FROM fines f
JOIN equipment_bookings eb ON eb.booking_id = f.booking_id
JOIN users              u  ON u.user_id     = eb.user_id
JOIN resources          r  ON r.resource_id = eb.resource_id;

-- 6) สร้างคำขอยืม (atomic)
CREATE OR REPLACE FUNCTION fn_equipment_create_booking(
  p_user_id BIGINT, p_resource_id BIGINT, p_borrow DATE, p_return DATE, p_purpose TEXT
) RETURNS TABLE (new_booking_id BIGINT, new_booking_code TEXT, new_status TEXT)
LANGUAGE plpgsql AS $$
DECLARE
  v_qty INT;
  v_is_equipment BOOLEAN;
  v_res_status TEXT;
  v_today DATE := (now() AT TIME ZONE 'Asia/Bangkok')::date;
  v_from TIMESTAMPTZ;
  v_to TIMESTAMPTZ;
  v_active INT;
  v_year TEXT;
  v_seq INT;
  v_id BIGINT;
  v_code TEXT;
BEGIN
  PERFORM fn_equipment_sync_overdue();
  PERFORM pg_advisory_xact_lock(hashtext('eq_user_' || p_user_id));

  SELECT r.quantity, (rc.type_name = 'EQUIPMENT'), rs.resource_status_name
    INTO v_qty, v_is_equipment, v_res_status
    FROM resources r
    JOIN resource_categories rc ON rc.type_id = r.type_id
    JOIN resource_status rs ON rs.resource_status_id = r.resource_status_id
   WHERE r.resource_id = p_resource_id
   FOR UPDATE OF r;
  IF NOT FOUND OR NOT COALESCE(v_is_equipment, false) THEN RAISE EXCEPTION 'RESOURCE_NOT_FOUND'; END IF;
  IF v_res_status IN ('BROKEN','UNDER_MAINTENANCE','OUT_OF_SERVICE') THEN RAISE EXCEPTION 'EQUIPMENT_UNAVAILABLE'; END IF;

  IF p_return < p_borrow THEN RAISE EXCEPTION 'INVALID_DATES'; END IF;
  IF p_borrow < v_today THEN RAISE EXCEPTION 'BORROW_IN_PAST'; END IF;
  IF p_borrow > v_today + 14 THEN RAISE EXCEPTION 'BORROW_TOO_FAR'; END IF;
  IF p_return - p_borrow > 7 THEN RAISE EXCEPTION 'LOAN_TOO_LONG'; END IF;

  v_from := p_borrow::timestamp AT TIME ZONE 'Asia/Bangkok';
  v_to   := (p_return::timestamp + interval '16 hours') AT TIME ZONE 'Asia/Bangkok';
  IF v_to <= now() THEN RAISE EXCEPTION 'DUE_IN_PAST'; END IF;

  -- ผู้ใช้ถูกบล็อก: มีของเกินกำหนด หรือค่าปรับ UNPAID
  IF EXISTS (SELECT 1 FROM equipment_bookings eb
             JOIN booking_status bs USING (booking_status_id)
             WHERE eb.user_id = p_user_id AND bs.booking_status_name = 'OVERDUE') THEN
    RAISE EXCEPTION 'USER_HAS_OVERDUE';
  END IF;
  IF EXISTS (SELECT 1 FROM fines f JOIN equipment_bookings eb USING (booking_id)
             WHERE eb.user_id = p_user_id AND f.fine_status = 'UNPAID') THEN
    RAISE EXCEPTION 'USER_HAS_UNPAID_FINE';
  END IF;

  SELECT COUNT(*) INTO v_active
    FROM equipment_bookings eb JOIN booking_status bs USING (booking_status_id)
   WHERE eb.user_id = p_user_id AND bs.booking_status_name IN ('PENDING','APPROVED','RECEIVED');
  IF v_active >= 2 THEN RAISE EXCEPTION 'USER_LIMIT_REACHED'; END IF;

  IF EXISTS (SELECT 1 FROM equipment_bookings eb JOIN booking_status bs USING (booking_status_id)
             WHERE eb.user_id = p_user_id AND eb.resource_id = p_resource_id
               AND bs.booking_status_name IN ('PENDING','APPROVED','RECEIVED')) THEN
    RAISE EXCEPTION 'ALREADY_BORROWING';
  END IF;

  IF fn_equipment_reserved(p_resource_id, v_from, v_to) >= COALESCE(v_qty, 0) THEN
    RAISE EXCEPTION 'OUT_OF_STOCK';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('equipment_booking_code'));
  v_year := to_char(now() AT TIME ZONE 'Asia/Bangkok', 'YYYY');
  SELECT COALESCE(MAX(substring(booking_code FROM '[0-9]+$')::int), 0) + 1 INTO v_seq
    FROM equipment_bookings WHERE booking_code LIKE 'EB-' || v_year || '-%';
  v_code := 'EB-' || v_year || '-' || lpad(v_seq::text, 4, '0');

  INSERT INTO equipment_bookings
    (booking_code, user_id, resource_id, borrow_date, expected_return_date, booking_status_id, borrow_purpose)
  VALUES
    (v_code, p_user_id, p_resource_id, v_from, v_to,
     (SELECT booking_status_id FROM booking_status WHERE booking_status_name = 'PENDING'), p_purpose)
  RETURNING booking_id INTO v_id;

  INSERT INTO equipment_booking_history (booking_id, action_id)
  VALUES (v_id, (SELECT action_id FROM booking_actions WHERE action_name = 'CREATE'));

  RETURN QUERY SELECT v_id, v_code, 'PENDING'::text;
END $$;

-- 7) เปลี่ยนสถานะ (atomic) | RETURN รับยอดค่าปรับชำรุด/สูญหายได้ (p_fine_amount > 0 ต้องมีเหตุผล)
CREATE OR REPLACE FUNCTION fn_equipment_change_status(
  p_booking_id BIGINT, p_action TEXT, p_actor_id BIGINT, p_actor_is_staff BOOLEAN,
  p_fine_amount NUMERIC DEFAULT NULL, p_fine_reason TEXT DEFAULT NULL
) RETURNS TABLE (out_booking_id BIGINT, out_status TEXT)
LANGUAGE plpgsql AS $$
DECLARE
  v_b equipment_bookings%ROWTYPE;
  v_cur TEXT;
  v_new TEXT;
  v_act TEXT := upper(p_action);
  v_owner BOOLEAN;
BEGIN
  PERFORM fn_equipment_sync_overdue();

  SELECT * INTO v_b FROM equipment_bookings WHERE booking_id = p_booking_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'BOOKING_NOT_FOUND'; END IF;
  SELECT booking_status_name INTO v_cur FROM booking_status WHERE booking_status_id = v_b.booking_status_id;
  v_owner := (v_b.user_id = p_actor_id);

  IF v_act = 'APPROVE' THEN
    IF NOT p_actor_is_staff THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
    IF v_owner THEN RAISE EXCEPTION 'SELF_APPROVAL'; END IF;
    IF v_cur <> 'PENDING' THEN RAISE EXCEPTION 'INVALID_TRANSITION'; END IF;
    IF v_b.expected_return_date <= now() THEN RAISE EXCEPTION 'DUE_IN_PAST'; END IF;
    v_new := 'APPROVED';
  ELSIF v_act = 'REJECT' THEN
    IF NOT p_actor_is_staff THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
    IF v_cur <> 'PENDING' THEN RAISE EXCEPTION 'INVALID_TRANSITION'; END IF;
    v_new := 'REJECTED';
  ELSIF v_act = 'CANCEL' THEN
    IF NOT (v_owner OR p_actor_is_staff) THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
    IF v_cur NOT IN ('PENDING','APPROVED') THEN RAISE EXCEPTION 'INVALID_TRANSITION'; END IF;
    v_new := 'CANCELLED';
  ELSIF v_act = 'RECEIVE' THEN            -- ส่งมอบอุปกรณ์ให้ผู้ยืม
    IF NOT p_actor_is_staff THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
    IF v_cur <> 'APPROVED' THEN RAISE EXCEPTION 'INVALID_TRANSITION'; END IF;
    IF v_b.borrow_date > now() THEN RAISE EXCEPTION 'NOT_BORROW_DAY'; END IF;
    IF v_b.expected_return_date <= now() THEN RAISE EXCEPTION 'DUE_IN_PAST'; END IF;
    UPDATE equipment_bookings SET borrow_date = now() WHERE booking_id = p_booking_id;
    v_new := 'RECEIVED';
  ELSIF v_act = 'RETURN' THEN             -- รับคืน
    IF NOT p_actor_is_staff THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
    IF v_cur NOT IN ('RECEIVED','OVERDUE') THEN RAISE EXCEPTION 'INVALID_TRANSITION'; END IF;
    IF p_fine_amount IS NOT NULL AND p_fine_amount <> 0 THEN
      IF p_fine_amount < 0 OR p_fine_amount > 100000 THEN RAISE EXCEPTION 'FINE_INVALID'; END IF;
      IF p_fine_reason IS NULL OR length(btrim(p_fine_reason)) < 3 THEN RAISE EXCEPTION 'FINE_REASON_REQUIRED'; END IF;
    END IF;
    UPDATE equipment_bookings SET actual_return_date = now() WHERE booking_id = p_booking_id;
    IF p_fine_amount IS NOT NULL AND p_fine_amount > 0 THEN
      INSERT INTO fines (booking_id, fine_amount, fine_reason, fine_status)
      VALUES (p_booking_id, round(p_fine_amount, 2), btrim(p_fine_reason), 'UNPAID');
    END IF;
    v_new := 'RETURNED';
  ELSE
    RAISE EXCEPTION 'INVALID_ACTION';
  END IF;

  UPDATE equipment_bookings
     SET booking_status_id = (SELECT booking_status_id FROM booking_status WHERE booking_status_name = v_new)
   WHERE booking_id = p_booking_id;

  INSERT INTO equipment_booking_history (booking_id, action_id)
  VALUES (p_booking_id, (SELECT action_id FROM booking_actions WHERE action_name = v_act));

  RETURN QUERY SELECT p_booking_id, v_new;
END $$;

-- 8) สิทธิ์: เฉพาะ service_role (BE)
REVOKE ALL ON FUNCTION fn_equipment_sync_overdue()                                   FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION fn_equipment_reserved(BIGINT,TIMESTAMPTZ,TIMESTAMPTZ)          FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION fn_equipment_availability(DATE,DATE)                           FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION fn_equipment_create_booking(BIGINT,BIGINT,DATE,DATE,TEXT)      FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION fn_equipment_change_status(BIGINT,TEXT,BIGINT,BOOLEAN,NUMERIC,TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_equipment_sync_overdue()                                   TO service_role;
GRANT EXECUTE ON FUNCTION fn_equipment_reserved(BIGINT,TIMESTAMPTZ,TIMESTAMPTZ)          TO service_role;
GRANT EXECUTE ON FUNCTION fn_equipment_availability(DATE,DATE)                           TO service_role;
GRANT EXECUTE ON FUNCTION fn_equipment_create_booking(BIGINT,BIGINT,DATE,DATE,TEXT)      TO service_role;
GRANT EXECUTE ON FUNCTION fn_equipment_change_status(BIGINT,TEXT,BIGINT,BOOLEAN,NUMERIC,TEXT) TO service_role;
REVOKE ALL ON v_equipment_booking_summary, v_equipment_fines FROM PUBLIC, anon, authenticated;
GRANT SELECT ON v_equipment_booking_summary, v_equipment_fines TO service_role;

-- 9) sequence ให้ตรงกับ seed
SELECT setval(pg_get_serial_sequence('equipment_bookings','booking_id'),
              (SELECT COALESCE(MAX(booking_id),1) FROM equipment_bookings));
SELECT setval(pg_get_serial_sequence('equipment_booking_history','history_id'),
              (SELECT COALESCE(MAX(history_id),1) FROM equipment_booking_history));
SELECT setval(pg_get_serial_sequence('fines','fine_id'),
              (SELECT COALESCE(MAX(fine_id),1) FROM fines));
