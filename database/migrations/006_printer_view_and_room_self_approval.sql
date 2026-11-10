-- =====================================================
-- 006_printer_view_and_room_self_approval.sql
-- 1) เพิ่ม material, est_weight_g ท้าย v_printer_booking_summary (ไม่กระทบคอลัมน์เดิม)
-- 2) ห้ามอนุมัติการจองห้องของตัวเอง (SELF_APPROVAL) -- แก้จาก fn_room_change_status เดิมบรรทัดเดียว
-- รันซ้ำได้
-- =====================================================

CREATE OR REPLACE VIEW v_printer_booking_summary WITH (security_invoker = true) AS
SELECT pb.booking_id,
       pb.booking_code,
       u.user_id,
       u.full_name                                   AS user_name,
       r.resource_id,
       r.resource_code                               AS printer_code,
       r.resource_name                               AS printer_name,
       r.location,
       ps.work_date,
       ps.start_time,
       ps.end_time,
       EXTRACT(EPOCH FROM (ps.end_time - ps.start_time)) / 3600.0 AS booked_hours,
       bs.booking_status_name                        AS booking_status,
       pb.print_purpose,
       pb.booking_time,
       pb.material,
       pb.est_weight_g
FROM printer_bookings  AS pb
JOIN users             AS u  ON u.user_id            = pb.user_id
JOIN printer_schedules AS ps ON ps.schedule_id       = pb.schedule_id
JOIN resources         AS r  ON r.resource_id        = ps.resource_id
JOIN booking_status    AS bs ON bs.booking_status_id = pb.booking_status_id;

CREATE OR REPLACE FUNCTION public.fn_room_change_status(p_booking_id bigint, p_action text, p_actor_id bigint, p_actor_is_staff boolean)
 RETURNS TABLE(changed_booking_id bigint, changed_status character varying)
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
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

    IF p_action = 'APPROVE' AND v_owner = p_actor_id THEN
        RAISE EXCEPTION 'SELF_APPROVAL';
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
$function$;

REVOKE ALL ON FUNCTION fn_room_change_status(BIGINT,TEXT,BIGINT,BOOLEAN) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_room_change_status(BIGINT,TEXT,BIGINT,BOOLEAN) TO service_role;
