-- =====================================================
-- 004_printer_booking.sql  (Step 8C-1: 3D Printer module)
-- สถานะ: PENDING -> APPROVED -> IN_PROGRESS -> COMPLETED -> RECEIVED
--        PENDING -> REJECTED | PENDING/APPROVED -> CANCELLED
-- ผู้กด: STAFF = APPROVE/REJECT/START/COMPLETE, OWNER = CANCEL/RECEIVE
-- กติกา: Staff อนุมัติคำขอของตัวเองไม่ได้
-- รันซ้ำได้ (idempotent)
-- =====================================================

-- 1) ตรวจให้มีสถานะ CANCELLED (เผื่อยังไม่ได้รัน 002)
INSERT INTO booking_status (booking_status_id, booking_status_name)
SELECT 9, 'CANCELLED'
WHERE NOT EXISTS (SELECT 1 FROM booking_status WHERE booking_status_name = 'CANCELLED');

-- 2) ข้อมูลงานพิมพ์ (nullable เพื่อไม่กระทบข้อมูลเดิม)
ALTER TABLE printer_bookings ADD COLUMN IF NOT EXISTS material VARCHAR(50);
ALTER TABLE printer_bookings ADD COLUMN IF NOT EXISTS est_weight_g NUMERIC(8,1);

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_printer_est_weight') THEN
    ALTER TABLE printer_bookings
      ADD CONSTRAINT ck_printer_est_weight
      CHECK (est_weight_g IS NULL OR (est_weight_g > 0 AND est_weight_g <= 5000));
  END IF;
END $$;

-- 3) View ช่องว่างของเครื่องพิมพ์ (นับสถานะที่ยึดช่อง)
CREATE OR REPLACE VIEW v_printer_slot_availability
WITH (security_invoker = true) AS
SELECT
  s.schedule_id,
  s.resource_id,
  s.work_date,
  s.start_time,
  s.end_time,
  s.max_slots,
  COALESCE(h.cnt, 0)::int                          AS booked_slots,
  GREATEST(s.max_slots - COALESCE(h.cnt, 0), 0)::int AS remaining_slots,
  (
    ss.schedule_status_name <> 'BLOCKED'
    AND rs.resource_status_name NOT IN ('BROKEN','UNDER_MAINTENANCE','OUT_OF_SERVICE')
    AND ((s.work_date + s.start_time) AT TIME ZONE 'Asia/Bangkok') > now()
    AND COALESCE(h.cnt, 0) < s.max_slots
  ) AS is_bookable
FROM printer_schedules s
JOIN schedule_status ss ON ss.schedule_status_id = s.schedule_status_id
JOIN resources r        ON r.resource_id = s.resource_id
JOIN resource_status rs ON rs.resource_status_id = r.resource_status_id
LEFT JOIN LATERAL (
  SELECT COUNT(*) AS cnt
  FROM printer_bookings b
  JOIN booking_status bs ON bs.booking_status_id = b.booking_status_id
  WHERE b.schedule_id = s.schedule_id
    AND bs.booking_status_name IN ('PENDING','APPROVED','IN_PROGRESS','COMPLETED','RECEIVED')
) h ON true;

-- 4) สร้างการจอง (atomic)
CREATE OR REPLACE FUNCTION fn_printer_create_booking(
  p_user_id BIGINT, p_schedule_id BIGINT, p_purpose TEXT,
  p_material TEXT DEFAULT NULL, p_est_weight NUMERIC DEFAULT NULL
) RETURNS TABLE (new_booking_id BIGINT, new_booking_code TEXT, new_status TEXT)
LANGUAGE plpgsql AS $$
DECLARE
  v_s printer_schedules%ROWTYPE;
  v_sched_status TEXT;
  v_res_status TEXT;
  v_is_printer BOOLEAN;
  v_held INT;
  v_year TEXT;
  v_seq INT;
  v_id BIGINT;
  v_code TEXT;
BEGIN
  SELECT * INTO v_s FROM printer_schedules WHERE schedule_id = p_schedule_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'SCHEDULE_NOT_FOUND'; END IF;

  SELECT ss.schedule_status_name INTO v_sched_status
    FROM schedule_status ss WHERE ss.schedule_status_id = v_s.schedule_status_id;
  SELECT rs.resource_status_name, (rc.type_name = 'PRINTER') INTO v_res_status, v_is_printer
    FROM resources r
    JOIN resource_status rs ON rs.resource_status_id = r.resource_status_id
    JOIN resource_categories rc ON rc.type_id = r.type_id
    WHERE r.resource_id = v_s.resource_id;

  IF NOT COALESCE(v_is_printer, false) THEN RAISE EXCEPTION 'SCHEDULE_NOT_FOUND'; END IF;
  IF v_sched_status = 'BLOCKED' THEN RAISE EXCEPTION 'SLOT_UNAVAILABLE'; END IF;
  IF v_res_status IN ('BROKEN','UNDER_MAINTENANCE','OUT_OF_SERVICE') THEN RAISE EXCEPTION 'PRINTER_UNAVAILABLE'; END IF;
  IF ((v_s.work_date + v_s.start_time) AT TIME ZONE 'Asia/Bangkok') <= now() THEN RAISE EXCEPTION 'SLOT_IN_PAST'; END IF;

  SELECT COUNT(*) INTO v_held
    FROM printer_bookings b JOIN booking_status bs USING (booking_status_id)
    WHERE b.schedule_id = p_schedule_id
      AND bs.booking_status_name IN ('PENDING','APPROVED','IN_PROGRESS','COMPLETED','RECEIVED');
  IF v_held >= v_s.max_slots THEN RAISE EXCEPTION 'SLOT_FULL'; END IF;

  -- ผู้ใช้จองเวลาซ้อนกัน (ทุกเครื่อง)
  IF EXISTS (
    SELECT 1
    FROM printer_bookings b
    JOIN booking_status bs USING (booking_status_id)
    JOIN printer_schedules s2 ON s2.schedule_id = b.schedule_id
    WHERE b.user_id = p_user_id
      AND bs.booking_status_name IN ('PENDING','APPROVED','IN_PROGRESS','COMPLETED')
      AND s2.work_date = v_s.work_date
      AND s2.start_time < v_s.end_time
      AND s2.end_time   > v_s.start_time
  ) THEN RAISE EXCEPTION 'USER_TIME_CONFLICT'; END IF;

  -- ออกเลขรหัสแบบไม่ซ้ำแม้จองพร้อมกันคนละช่อง
  PERFORM pg_advisory_xact_lock(hashtext('printer_booking_code'));
  v_year := to_char(now() AT TIME ZONE 'Asia/Bangkok', 'YYYY');
  SELECT COALESCE(MAX(substring(booking_code FROM '[0-9]+$')::int), 0) + 1 INTO v_seq
    FROM printer_bookings WHERE booking_code LIKE 'PB-' || v_year || '-%';
  v_code := 'PB-' || v_year || '-' || lpad(v_seq::text, 4, '0');

  INSERT INTO printer_bookings
    (booking_code, user_id, schedule_id, booking_status_id, print_purpose, material, est_weight_g)
  VALUES
    (v_code, p_user_id, p_schedule_id,
     (SELECT booking_status_id FROM booking_status WHERE booking_status_name = 'PENDING'),
     p_purpose, p_material, p_est_weight)
  RETURNING booking_id INTO v_id;

  INSERT INTO printer_booking_history (booking_id, action_id)
  VALUES (v_id, (SELECT action_id FROM booking_actions WHERE action_name = 'CREATE'));

  RETURN QUERY SELECT v_id, v_code, 'PENDING'::text;
END $$;

-- 5) เปลี่ยนสถานะ (atomic)
CREATE OR REPLACE FUNCTION fn_printer_change_status(
  p_booking_id BIGINT, p_action TEXT, p_actor_id BIGINT, p_actor_is_staff BOOLEAN
) RETURNS TABLE (out_booking_id BIGINT, out_status TEXT)
LANGUAGE plpgsql AS $$
DECLARE
  v_b printer_bookings%ROWTYPE;
  v_cur TEXT;
  v_start TIMESTAMPTZ;
  v_new TEXT;
  v_act TEXT;
  v_owner BOOLEAN;
BEGIN
  SELECT * INTO v_b FROM printer_bookings WHERE booking_id = p_booking_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'BOOKING_NOT_FOUND'; END IF;

  SELECT booking_status_name INTO v_cur FROM booking_status WHERE booking_status_id = v_b.booking_status_id;
  SELECT (s.work_date + s.start_time) AT TIME ZONE 'Asia/Bangkok' INTO v_start
    FROM printer_schedules s WHERE s.schedule_id = v_b.schedule_id;
  v_owner := (v_b.user_id = p_actor_id);
  v_act := upper(p_action);

  IF v_act = 'APPROVE' THEN
    IF NOT p_actor_is_staff THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
    IF v_owner THEN RAISE EXCEPTION 'SELF_APPROVAL'; END IF;
    IF v_cur <> 'PENDING' THEN RAISE EXCEPTION 'INVALID_TRANSITION'; END IF;
    IF v_start <= now() THEN RAISE EXCEPTION 'SLOT_IN_PAST'; END IF;
    v_new := 'APPROVED';
  ELSIF v_act = 'REJECT' THEN
    IF NOT p_actor_is_staff THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
    IF v_cur <> 'PENDING' THEN RAISE EXCEPTION 'INVALID_TRANSITION'; END IF;
    v_new := 'REJECTED';
  ELSIF v_act = 'CANCEL' THEN
    IF NOT (v_owner OR p_actor_is_staff) THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
    IF v_cur NOT IN ('PENDING','APPROVED') THEN RAISE EXCEPTION 'INVALID_TRANSITION'; END IF;
    IF v_start <= now() THEN RAISE EXCEPTION 'ALREADY_STARTED'; END IF;
    v_new := 'CANCELLED';
  ELSIF v_act = 'START' THEN
    IF NOT p_actor_is_staff THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
    IF v_cur <> 'APPROVED' THEN RAISE EXCEPTION 'INVALID_TRANSITION'; END IF;
    v_new := 'IN_PROGRESS';
  ELSIF v_act = 'COMPLETE' THEN
    IF NOT p_actor_is_staff THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
    IF v_cur <> 'IN_PROGRESS' THEN RAISE EXCEPTION 'INVALID_TRANSITION'; END IF;
    v_new := 'COMPLETED';
  ELSIF v_act = 'RECEIVE' THEN
    IF NOT v_owner THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
    IF v_cur <> 'COMPLETED' THEN RAISE EXCEPTION 'INVALID_TRANSITION'; END IF;
    v_new := 'RECEIVED';
  ELSE
    RAISE EXCEPTION 'INVALID_ACTION';
  END IF;

  UPDATE printer_bookings
     SET booking_status_id = (SELECT booking_status_id FROM booking_status WHERE booking_status_name = v_new)
   WHERE booking_id = p_booking_id;

  INSERT INTO printer_booking_history (booking_id, action_id)
  VALUES (p_booking_id, (SELECT action_id FROM booking_actions WHERE action_name = v_act));

  RETURN QUERY SELECT p_booking_id, v_new;
END $$;

-- 6) สิทธิ์: เฉพาะ service_role (BE) เท่านั้น
REVOKE ALL ON FUNCTION fn_printer_create_booking(BIGINT,BIGINT,TEXT,TEXT,NUMERIC) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION fn_printer_change_status(BIGINT,TEXT,BIGINT,BOOLEAN)       FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_printer_create_booking(BIGINT,BIGINT,TEXT,TEXT,NUMERIC) TO service_role;
GRANT EXECUTE ON FUNCTION fn_printer_change_status(BIGINT,TEXT,BIGINT,BOOLEAN)       TO service_role;
REVOKE ALL ON v_printer_slot_availability FROM PUBLIC, anon, authenticated;
GRANT SELECT ON v_printer_slot_availability TO service_role;

-- 7) sequence ให้ตรงกับ seed
SELECT setval(pg_get_serial_sequence('printer_bookings','booking_id'),
              (SELECT COALESCE(MAX(booking_id),1) FROM printer_bookings));
SELECT setval(pg_get_serial_sequence('printer_schedules','schedule_id'),
              (SELECT COALESCE(MAX(schedule_id),1) FROM printer_schedules));
SELECT setval(pg_get_serial_sequence('printer_booking_history','history_id'),
              (SELECT COALESCE(MAX(history_id),1) FROM printer_booking_history));
