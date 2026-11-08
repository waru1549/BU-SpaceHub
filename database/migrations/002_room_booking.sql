-- =====================================================================
-- Migration 002 : โมดูลจองห้อง (Step 8A)
--   1) เพิ่มสถานะ CANCELLED
--   2) View v_room_slot_availability  (ช่วงเวลา + จำนวนที่เหลือ + จองได้หรือไม่)
--   3) fn_room_create_booking        (จองแบบ atomic กันจองซ้อน/เกินจำนวน)
--   4) fn_room_change_status         (อนุมัติ/ปฏิเสธ/ยกเลิก/เสร็จสิ้น + บันทึกประวัติ)
--   5) สิทธิ์: เรียกได้เฉพาะ service_role (BE) เท่านั้น
-- รันซ้ำได้อย่างปลอดภัย (idempotent)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) สถานะ CANCELLED (เดิมมีแค่ action CANCEL แต่ไม่มีสถานะปลายทาง)
-- ---------------------------------------------------------------------
INSERT INTO booking_status (booking_status_id, booking_status_name)
SELECT (SELECT MAX(booking_status_id) + 1 FROM booking_status), 'CANCELLED'
WHERE NOT EXISTS (SELECT 1 FROM booking_status WHERE booking_status_name = 'CANCELLED');

-- กัน sequence ล้าหลังข้อมูลที่ seed ด้วย id ตรง ๆ
SELECT setval(pg_get_serial_sequence('booking_status', 'booking_status_id'),
              (SELECT MAX(booking_status_id) FROM booking_status));
SELECT setval(pg_get_serial_sequence('room_bookings', 'booking_id'),
              (SELECT COALESCE(MAX(booking_id), 1) FROM room_bookings));
SELECT setval(pg_get_serial_sequence('room_booking_history', 'history_id'),
              (SELECT COALESCE(MAX(history_id), 1) FROM room_booking_history));
SELECT setval(pg_get_serial_sequence('room_schedules', 'schedule_id'),
              (SELECT COALESCE(MAX(schedule_id), 1) FROM room_schedules));

-- ---------------------------------------------------------------------
-- 2) View ช่วงเวลาห้อง + ความจุที่เหลือ
--    นับที่นั่งที่ถูกถือไว้จากการจองสถานะ PENDING / APPROVED / COMPLETED
--    is_bookable = ช่วงเวลาไม่ถูกบล็อก + ห้องใช้งานได้ + ยังไม่เริ่ม + ยังเหลือที่
--    เวลาเทียบตามเขตเวลา Asia/Bangkok
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_room_slot_availability WITH (security_invoker = true) AS
SELECT rs.schedule_id,
       r.resource_id,
       rs.work_date,
       rs.start_time,
       rs.end_time,
       rs.max_slots,
       COALESCE(h.held, 0)::int                                   AS booked_slots,
       GREATEST(rs.max_slots - COALESCE(h.held, 0), 0)::int       AS remaining_slots,
       (    sst.schedule_status_name <> 'BLOCKED'
        AND rst.resource_status_name NOT IN ('BROKEN', 'UNDER_MAINTENANCE', 'OUT_OF_SERVICE')
        AND (rs.work_date + rs.start_time) > (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Bangkok')
        AND rs.max_slots > COALESCE(h.held, 0)
       )                                                          AS is_bookable
FROM room_schedules      AS rs
JOIN resources           AS r   ON r.resource_id         = rs.resource_id
JOIN resource_categories AS rc  ON rc.type_id            = r.type_id AND rc.type_name = 'ROOM'
JOIN resource_status     AS rst ON rst.resource_status_id = r.resource_status_id
JOIN schedule_status     AS sst ON sst.schedule_status_id = rs.schedule_status_id
LEFT JOIN (SELECT rb.schedule_id, COUNT(*) AS held
           FROM room_bookings rb
           JOIN booking_status bs ON bs.booking_status_id = rb.booking_status_id
           WHERE bs.booking_status_name IN ('PENDING', 'APPROVED', 'COMPLETED')
           GROUP BY rb.schedule_id) AS h ON h.schedule_id = rs.schedule_id;

-- ---------------------------------------------------------------------
-- 3) จองห้อง (atomic)
--    ล็อกแถวช่วงเวลา (FOR UPDATE) ทำให้การจองพร้อมกันของช่วงเดียวกันเรียงทีละคำขอ
--    ข้อผิดพลาดส่งเป็นรหัสข้อความ ให้ BE แปลงเป็น HTTP status
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_room_create_booking(
    p_user_id     BIGINT,
    p_schedule_id BIGINT,
    p_purpose     TEXT
)
RETURNS TABLE (new_booking_id BIGINT, new_booking_code VARCHAR, new_status VARCHAR)
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
    v_sched      room_schedules%ROWTYPE;
    v_sched_stat TEXT;
    v_res_stat   TEXT;
    v_held       INT;
    v_id         BIGINT;
    v_code       TEXT;
    v_pending    SMALLINT;
    v_now        TIMESTAMP := (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Bangkok');
BEGIN
    SELECT * INTO v_sched FROM room_schedules WHERE schedule_id = p_schedule_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'SCHEDULE_NOT_FOUND';
    END IF;

    SELECT schedule_status_name INTO v_sched_stat
    FROM schedule_status WHERE schedule_status_id = v_sched.schedule_status_id;
    IF v_sched_stat = 'BLOCKED' THEN
        RAISE EXCEPTION 'SLOT_UNAVAILABLE';
    END IF;

    SELECT rst.resource_status_name INTO v_res_stat
    FROM resources r
    JOIN resource_status rst ON rst.resource_status_id = r.resource_status_id
    WHERE r.resource_id = v_sched.resource_id;
    IF v_res_stat IN ('BROKEN', 'UNDER_MAINTENANCE', 'OUT_OF_SERVICE') THEN
        RAISE EXCEPTION 'ROOM_UNAVAILABLE';
    END IF;

    IF (v_sched.work_date + v_sched.start_time) <= v_now THEN
        RAISE EXCEPTION 'SLOT_IN_PAST';
    END IF;

    SELECT COUNT(*) INTO v_held
    FROM room_bookings rb
    JOIN booking_status bs ON bs.booking_status_id = rb.booking_status_id
    WHERE rb.schedule_id = p_schedule_id
      AND bs.booking_status_name IN ('PENDING', 'APPROVED', 'COMPLETED');
    IF v_held >= v_sched.max_slots THEN
        RAISE EXCEPTION 'SLOT_FULL';
    END IF;

    -- ผู้ใช้คนเดียวกันห้ามมีการจองที่เวลาทับกัน (ทุกห้อง) ในวันเดียวกัน
    IF EXISTS (
        SELECT 1
        FROM room_bookings rb
        JOIN booking_status bs ON bs.booking_status_id = rb.booking_status_id
        JOIN room_schedules s  ON s.schedule_id = rb.schedule_id
        WHERE rb.user_id = p_user_id
          AND bs.booking_status_name IN ('PENDING', 'APPROVED')
          AND s.work_date  = v_sched.work_date
          AND s.start_time < v_sched.end_time
          AND s.end_time   > v_sched.start_time
    ) THEN
        RAISE EXCEPTION 'USER_TIME_CONFLICT';
    END IF;

    v_id   := nextval(pg_get_serial_sequence('room_bookings', 'booking_id'));
    v_code := 'RB-' || to_char(v_now, 'YYYY') || '-' || lpad(v_id::text, 4, '0');
    SELECT booking_status_id INTO v_pending FROM booking_status WHERE booking_status_name = 'PENDING';

    INSERT INTO room_bookings (booking_id, booking_code, user_id, schedule_id, booking_status_id, booking_purpose)
    VALUES (v_id, v_code, p_user_id, p_schedule_id, v_pending, p_purpose);

    INSERT INTO room_booking_history (booking_id, action_id)
    SELECT v_id, action_id FROM booking_actions WHERE action_name = 'CREATE';

    RETURN QUERY SELECT v_id, v_code::varchar, 'PENDING'::varchar;
END;
$$;

-- ---------------------------------------------------------------------
-- 4) เปลี่ยนสถานะการจอง (atomic)
--    APPROVE / REJECT : STAFF,ADMIN เท่านั้น จาก PENDING (APPROVE ต้องยังไม่เริ่ม)
--    CANCEL           : เจ้าของ หรือ STAFF,ADMIN จาก PENDING/APPROVED ที่ยังไม่เริ่ม
--    COMPLETE         : STAFF,ADMIN จาก APPROVED ที่เริ่มแล้ว
--    คนอื่นที่ไม่ใช่เจ้าของพยายาม CANCEL จะได้ BOOKING_NOT_FOUND (ไม่เผยว่ามีรายการนี้)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_room_change_status(
    p_booking_id     BIGINT,
    p_action         TEXT,
    p_actor_id       BIGINT,
    p_actor_is_staff BOOLEAN
)
RETURNS TABLE (changed_booking_id BIGINT, changed_status VARCHAR)
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
    v_owner     BIGINT;
    v_current   TEXT;
    v_start     TIMESTAMP;
    v_target    TEXT;
    v_target_id SMALLINT;
    v_now       TIMESTAMP := (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Bangkok');
BEGIN
    IF p_action NOT IN ('APPROVE', 'REJECT', 'CANCEL', 'COMPLETE') THEN
        RAISE EXCEPTION 'INVALID_ACTION';
    END IF;

    SELECT rb.user_id, bs.booking_status_name, (rs.work_date + rs.start_time)
      INTO v_owner, v_current, v_start
    FROM room_bookings rb
    JOIN booking_status bs ON bs.booking_status_id = rb.booking_status_id
    JOIN room_schedules rs ON rs.schedule_id = rb.schedule_id
    WHERE rb.booking_id = p_booking_id
    FOR UPDATE OF rb;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'BOOKING_NOT_FOUND';
    END IF;

    IF p_action IN ('APPROVE', 'REJECT', 'COMPLETE') AND NOT p_actor_is_staff THEN
        RAISE EXCEPTION 'FORBIDDEN';
    END IF;
    IF p_action = 'CANCEL' AND NOT p_actor_is_staff AND v_owner <> p_actor_id THEN
        RAISE EXCEPTION 'BOOKING_NOT_FOUND';
    END IF;

    CASE p_action
        WHEN 'APPROVE' THEN
            IF v_current <> 'PENDING' THEN RAISE EXCEPTION 'INVALID_TRANSITION'; END IF;
            IF v_start <= v_now THEN RAISE EXCEPTION 'SLOT_IN_PAST'; END IF;
            v_target := 'APPROVED';
        WHEN 'REJECT' THEN
            IF v_current <> 'PENDING' THEN RAISE EXCEPTION 'INVALID_TRANSITION'; END IF;
            v_target := 'REJECTED';
        WHEN 'CANCEL' THEN
            IF v_current NOT IN ('PENDING', 'APPROVED') THEN RAISE EXCEPTION 'INVALID_TRANSITION'; END IF;
            IF v_start <= v_now THEN RAISE EXCEPTION 'ALREADY_STARTED'; END IF;
            v_target := 'CANCELLED';
        WHEN 'COMPLETE' THEN
            IF v_current <> 'APPROVED' THEN RAISE EXCEPTION 'INVALID_TRANSITION'; END IF;
            IF v_start > v_now THEN RAISE EXCEPTION 'NOT_STARTED'; END IF;
            v_target := 'COMPLETED';
    END CASE;

    SELECT booking_status_id INTO v_target_id FROM booking_status WHERE booking_status_name = v_target;

    UPDATE room_bookings SET booking_status_id = v_target_id WHERE booking_id = p_booking_id;

    INSERT INTO room_booking_history (booking_id, action_id)
    SELECT p_booking_id, action_id FROM booking_actions WHERE action_name = p_action;

    RETURN QUERY SELECT p_booking_id, v_target::varchar;
END;
$$;

-- ---------------------------------------------------------------------
-- 5) สิทธิ์: ฟังก์ชันและ view ใช้ได้เฉพาะ service_role (BE) ไม่เปิดให้ anon/authenticated
-- ---------------------------------------------------------------------
REVOKE ALL ON FUNCTION fn_room_create_booking(BIGINT, BIGINT, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_room_create_booking(BIGINT, BIGINT, TEXT) TO service_role;

REVOKE ALL ON FUNCTION fn_room_change_status(BIGINT, TEXT, BIGINT, BOOLEAN) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_room_change_status(BIGINT, TEXT, BIGINT, BOOLEAN) TO service_role;

REVOKE ALL ON v_room_slot_availability FROM PUBLIC, anon, authenticated;
GRANT SELECT ON v_room_slot_availability TO service_role;