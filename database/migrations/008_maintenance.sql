-- =====================================================================
-- 008_maintenance.sql  |  Step 10-1: ระบบแจ้งซ่อม (Maintenance)
-- ทำซ้ำได้ (idempotent) | รันใน Supabase SQL Editor
--
-- กติกา: PENDING(รอรับเรื่อง) -> IN_PROGRESS(กำลังซ่อม) -> COMPLETED(เสร็จสิ้น)
--        + REJECTED (Staff/Admin) + CANCELLED (ผู้แจ้ง ก่อนเริ่มซ่อม)
--        Admin มอบหมาย Staff (assigned_to) | START/COMPLETE โดย Staff ที่ได้รับมอบหมายหรือ Admin
--        START -> ทรัพยากรเป็น UNDER_MAINTENANCE | COMPLETE -> กลับเป็น AVAILABLE
--        แนบรูปได้ ≤ 3 รูป (bucket maintenance-images, ≤ 5MB, JPG/PNG/WebP)
--        สถานะ APPROVED เดิมใน seed ถือเป็น "รอรับเรื่อง" (เริ่มซ่อม/ปฏิเสธ/ยกเลิกได้)
-- =====================================================================

-- 1) ปรับตาราง maintenance_bookings
ALTER TABLE maintenance_bookings ALTER COLUMN resource_id DROP NOT NULL;
ALTER TABLE maintenance_bookings ADD COLUMN IF NOT EXISTS location_text VARCHAR(255);
ALTER TABLE maintenance_bookings ADD COLUMN IF NOT EXISTS assigned_to   BIGINT;
ALTER TABLE maintenance_bookings ADD COLUMN IF NOT EXISTS assigned_at   TIMESTAMPTZ;
ALTER TABLE maintenance_bookings ADD COLUMN IF NOT EXISTS started_at    TIMESTAMPTZ;
ALTER TABLE maintenance_bookings ADD COLUMN IF NOT EXISTS completed_at  TIMESTAMPTZ;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_maintenance_assigned_to') THEN
    ALTER TABLE maintenance_bookings
      ADD CONSTRAINT fk_maintenance_assigned_to FOREIGN KEY (assigned_to)
      REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE SET NULL;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_maintenance_target') THEN
    ALTER TABLE maintenance_bookings
      ADD CONSTRAINT chk_maintenance_target
      CHECK (resource_id IS NOT NULL OR length(btrim(COALESCE(location_text, ''))) > 0);
  END IF;
END $$;
CREATE INDEX IF NOT EXISTS idx_maintenance_assigned ON maintenance_bookings (assigned_to);
CREATE INDEX IF NOT EXISTS idx_maintenance_status   ON maintenance_bookings (booking_status_id);
CREATE INDEX IF NOT EXISTS idx_attachments_booking  ON attachments (booking_id);

-- 2) action ใหม่สำหรับบันทึกการมอบหมายงาน
INSERT INTO booking_actions (action_id, action_name)
SELECT (SELECT COALESCE(MAX(action_id), 0) + 1 FROM booking_actions), 'ASSIGN'
WHERE NOT EXISTS (SELECT 1 FROM booking_actions WHERE action_name = 'ASSIGN');

-- 3) จำกัดรูปแนบ ≤ 3 รูปต่องาน (กันซ้ำที่ชั้น DB อีกชั้น)
CREATE OR REPLACE FUNCTION fn_attachments_limit() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF (SELECT count(*) FROM attachments WHERE booking_id = NEW.booking_id) >= 3 THEN
    RAISE EXCEPTION 'TOO_MANY_ATTACHMENTS';
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_attachments_limit ON attachments;
CREATE TRIGGER trg_attachments_limit BEFORE INSERT ON attachments
  FOR EACH ROW EXECUTE FUNCTION fn_attachments_limit();

-- 4) Storage bucket (private, 5MB, JPG/PNG/WebP) — ข้ามอัตโนมัติถ้าไม่มี schema storage
DO $$
BEGIN
  IF to_regclass('storage.buckets') IS NOT NULL THEN
    INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    VALUES ('maintenance-images', 'maintenance-images', false, 5242880,
            ARRAY['image/jpeg','image/png','image/webp'])
    ON CONFLICT (id) DO UPDATE
      SET public = false, file_size_limit = 5242880,
          allowed_mime_types = ARRAY['image/jpeg','image/png','image/webp'];
  END IF;
END $$;

-- 5) View สำหรับ BE (รองรับงานที่ไม่ผูกทรัพยากร + ผู้รับผิดชอบ)
CREATE OR REPLACE VIEW v_maintenance_requests WITH (security_invoker = true) AS
SELECT mb.booking_id, mb.booking_code,
       mb.user_id, u.full_name AS reporter_name,
       mb.resource_id, r.resource_code, r.resource_name,
       COALESCE(NULLIF(btrim(mb.location_text), ''), r.location) AS location,
       mb.repair_title, mb.repair_description,
       bs.booking_status_name AS booking_status,
       mb.reported_date,
       mb.assigned_to, au.full_name AS assignee_name, mb.assigned_at,
       mb.started_at, mb.completed_at, mb.staff_note,
       COALESCE(a.cnt, 0) AS attachment_count
FROM maintenance_bookings mb
JOIN users u            ON u.user_id = mb.user_id
JOIN booking_status bs  ON bs.booking_status_id = mb.booking_status_id
LEFT JOIN resources r   ON r.resource_id = mb.resource_id
LEFT JOIN users au      ON au.user_id = mb.assigned_to
LEFT JOIN (SELECT booking_id, count(*) AS cnt FROM attachments GROUP BY booking_id) a
       ON a.booking_id = mb.booking_id;

-- 6) สร้างใบแจ้งซ่อม (atomic)
CREATE OR REPLACE FUNCTION fn_maintenance_create_booking(
  p_user_id BIGINT, p_resource_id BIGINT, p_location TEXT, p_title TEXT, p_description TEXT
) RETURNS TABLE (new_booking_id BIGINT, new_booking_code TEXT, new_status TEXT)
LANGUAGE plpgsql AS $$
DECLARE
  v_title TEXT := btrim(COALESCE(p_title, ''));
  v_desc  TEXT := btrim(COALESCE(p_description, ''));
  v_loc   TEXT := NULLIF(btrim(COALESCE(p_location, '')), '');
  v_prefix TEXT; v_seq INT; v_code TEXT; v_id BIGINT;
BEGIN
  IF length(v_title) < 3 OR length(v_title) > 255 THEN RAISE EXCEPTION 'INVALID_TITLE'; END IF;
  IF length(v_desc) < 10 THEN RAISE EXCEPTION 'DESCRIPTION_REQUIRED'; END IF;
  IF p_resource_id IS NULL AND v_loc IS NULL THEN RAISE EXCEPTION 'TARGET_REQUIRED'; END IF;
  IF v_loc IS NOT NULL AND length(v_loc) > 255 THEN RAISE EXCEPTION 'INVALID_LOCATION'; END IF;

  IF p_resource_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM resources WHERE resource_id = p_resource_id) THEN
      RAISE EXCEPTION 'RESOURCE_NOT_FOUND';
    END IF;
    IF EXISTS (
      SELECT 1 FROM maintenance_bookings mb JOIN booking_status bs USING (booking_status_id)
      WHERE mb.user_id = p_user_id AND mb.resource_id = p_resource_id
        AND bs.booking_status_name IN ('PENDING','APPROVED','IN_PROGRESS')
    ) THEN RAISE EXCEPTION 'ALREADY_REPORTED'; END IF;
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('maintenance_booking_code'));
  IF (SELECT count(*) FROM maintenance_bookings mb JOIN booking_status bs USING (booking_status_id)
       WHERE mb.user_id = p_user_id AND bs.booking_status_name IN ('PENDING','APPROVED','IN_PROGRESS')) >= 5 THEN
    RAISE EXCEPTION 'USER_LIMIT_REACHED';
  END IF;

  v_prefix := 'MT-' || to_char(now() AT TIME ZONE 'Asia/Bangkok', 'YYYY') || '-';
  SELECT COALESCE(MAX(substring(booking_code FROM '[0-9]+$')::int), 0) + 1 INTO v_seq
    FROM maintenance_bookings WHERE booking_code LIKE v_prefix || '%';
  v_code := v_prefix || lpad(v_seq::text, 4, '0');

  INSERT INTO maintenance_bookings
    (booking_code, user_id, resource_id, location_text, booking_status_id, repair_title, repair_description)
  VALUES
    (v_code, p_user_id, p_resource_id, v_loc,
     (SELECT booking_status_id FROM booking_status WHERE booking_status_name = 'PENDING'),
     v_title, v_desc)
  RETURNING booking_id INTO v_id;

  INSERT INTO maintenance_booking_history (booking_id, action_id)
  VALUES (v_id, (SELECT action_id FROM booking_actions WHERE action_name = 'CREATE'));

  RETURN QUERY SELECT v_id, v_code, 'PENDING'::text;
END $$;

-- 7) มอบหมายงาน (Admin เท่านั้น — BE ส่ง p_actor_is_admin)
CREATE OR REPLACE FUNCTION fn_maintenance_assign(
  p_booking_id BIGINT, p_assignee_id BIGINT, p_actor_is_admin BOOLEAN
) RETURNS TABLE (out_booking_id BIGINT, out_assigned_to BIGINT)
LANGUAGE plpgsql AS $$
DECLARE v_cur TEXT;
BEGIN
  IF NOT COALESCE(p_actor_is_admin, false) THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
  SELECT bs.booking_status_name INTO v_cur
    FROM maintenance_bookings mb JOIN booking_status bs USING (booking_status_id)
   WHERE mb.booking_id = p_booking_id FOR UPDATE OF mb;
  IF NOT FOUND THEN RAISE EXCEPTION 'BOOKING_NOT_FOUND'; END IF;
  IF v_cur NOT IN ('PENDING','APPROVED','IN_PROGRESS') THEN RAISE EXCEPTION 'INVALID_TRANSITION'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM users u JOIN user_roles ur USING (role_id)
     WHERE u.user_id = p_assignee_id AND u.user_status = 'ACTIVE' AND ur.role_name IN ('STAFF','ADMIN')
  ) THEN RAISE EXCEPTION 'ASSIGNEE_INVALID'; END IF;

  UPDATE maintenance_bookings SET assigned_to = p_assignee_id, assigned_at = now()
   WHERE booking_id = p_booking_id;
  INSERT INTO maintenance_booking_history (booking_id, action_id)
  VALUES (p_booking_id, (SELECT action_id FROM booking_actions WHERE action_name = 'ASSIGN'));
  RETURN QUERY SELECT p_booking_id, p_assignee_id;
END $$;

-- 8) เปลี่ยนสถานะ (atomic) START / COMPLETE / REJECT / CANCEL
CREATE OR REPLACE FUNCTION fn_maintenance_change_status(
  p_booking_id BIGINT, p_action TEXT, p_actor_id BIGINT,
  p_actor_is_staff BOOLEAN, p_actor_is_admin BOOLEAN, p_note TEXT DEFAULT NULL
) RETURNS TABLE (out_booking_id BIGINT, out_status TEXT)
LANGUAGE plpgsql AS $$
DECLARE
  v_b maintenance_bookings%ROWTYPE;
  v_cur TEXT; v_new TEXT;
  v_act TEXT := upper(p_action);
  v_note TEXT := NULLIF(btrim(COALESCE(p_note, '')), '');
  v_is_assignee BOOLEAN;
BEGIN
  SELECT * INTO v_b FROM maintenance_bookings WHERE booking_id = p_booking_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'BOOKING_NOT_FOUND'; END IF;
  SELECT booking_status_name INTO v_cur FROM booking_status WHERE booking_status_id = v_b.booking_status_id;
  v_is_assignee := (v_b.assigned_to IS NOT NULL AND v_b.assigned_to = p_actor_id);

  IF v_act = 'START' THEN
    IF NOT p_actor_is_staff THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
    IF v_cur NOT IN ('PENDING','APPROVED') THEN RAISE EXCEPTION 'INVALID_TRANSITION'; END IF;
    IF v_b.assigned_to IS NULL THEN RAISE EXCEPTION 'NOT_ASSIGNED'; END IF;
    IF NOT (p_actor_is_admin OR v_is_assignee) THEN RAISE EXCEPTION 'NOT_ASSIGNEE'; END IF;
    UPDATE maintenance_bookings SET started_at = now() WHERE booking_id = p_booking_id;
    IF v_b.resource_id IS NOT NULL THEN
      UPDATE resources SET resource_status_id =
        (SELECT resource_status_id FROM resource_status WHERE resource_status_name = 'UNDER_MAINTENANCE')
       WHERE resource_id = v_b.resource_id;
    END IF;
    v_new := 'IN_PROGRESS';
  ELSIF v_act = 'COMPLETE' THEN
    IF NOT p_actor_is_staff THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
    IF v_cur <> 'IN_PROGRESS' THEN RAISE EXCEPTION 'INVALID_TRANSITION'; END IF;
    IF NOT (p_actor_is_admin OR v_is_assignee) THEN RAISE EXCEPTION 'NOT_ASSIGNEE'; END IF;
    IF v_note IS NULL OR length(v_note) < 3 THEN RAISE EXCEPTION 'NOTE_REQUIRED'; END IF;
    UPDATE maintenance_bookings SET staff_note = v_note, completed_at = now() WHERE booking_id = p_booking_id;
    v_new := 'COMPLETED';
    -- คืนทรัพยากรเป็น AVAILABLE เมื่อไม่มีงานซ่อมอื่นที่กำลังซ่อมอยู่
    IF v_b.resource_id IS NOT NULL
       AND NOT EXISTS (
         SELECT 1 FROM maintenance_bookings mb JOIN booking_status bs USING (booking_status_id)
          WHERE mb.resource_id = v_b.resource_id AND mb.booking_id <> p_booking_id
            AND bs.booking_status_name = 'IN_PROGRESS')
    THEN
      UPDATE resources SET resource_status_id =
        (SELECT resource_status_id FROM resource_status WHERE resource_status_name = 'AVAILABLE')
       WHERE resource_id = v_b.resource_id
         AND resource_status_id = (SELECT resource_status_id FROM resource_status WHERE resource_status_name = 'UNDER_MAINTENANCE');
    END IF;
  ELSIF v_act = 'REJECT' THEN
    IF NOT p_actor_is_staff THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
    IF v_cur NOT IN ('PENDING','APPROVED') THEN RAISE EXCEPTION 'INVALID_TRANSITION'; END IF;
    IF v_note IS NULL OR length(v_note) < 3 THEN RAISE EXCEPTION 'NOTE_REQUIRED'; END IF;
    UPDATE maintenance_bookings SET staff_note = v_note WHERE booking_id = p_booking_id;
    v_new := 'REJECTED';
  ELSIF v_act = 'CANCEL' THEN
    IF v_b.user_id <> p_actor_id THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
    IF v_cur NOT IN ('PENDING','APPROVED') THEN RAISE EXCEPTION 'INVALID_TRANSITION'; END IF;
    v_new := 'CANCELLED';
  ELSE
    RAISE EXCEPTION 'INVALID_ACTION';
  END IF;

  UPDATE maintenance_bookings
     SET booking_status_id = (SELECT booking_status_id FROM booking_status WHERE booking_status_name = v_new)
   WHERE booking_id = p_booking_id;
  INSERT INTO maintenance_booking_history (booking_id, action_id)
  VALUES (p_booking_id, (SELECT action_id FROM booking_actions WHERE action_name = v_act));

  RETURN QUERY SELECT p_booking_id, v_new;
END $$;

-- 9) สิทธิ์: เฉพาะ service_role (BE)
REVOKE ALL ON FUNCTION fn_maintenance_create_booking(BIGINT,BIGINT,TEXT,TEXT,TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION fn_maintenance_assign(BIGINT,BIGINT,BOOLEAN)                FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION fn_maintenance_change_status(BIGINT,TEXT,BIGINT,BOOLEAN,BOOLEAN,TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_maintenance_create_booking(BIGINT,BIGINT,TEXT,TEXT,TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION fn_maintenance_assign(BIGINT,BIGINT,BOOLEAN)                TO service_role;
GRANT EXECUTE ON FUNCTION fn_maintenance_change_status(BIGINT,TEXT,BIGINT,BOOLEAN,BOOLEAN,TEXT) TO service_role;
REVOKE ALL ON v_maintenance_requests FROM PUBLIC, anon, authenticated;
GRANT SELECT ON v_maintenance_requests TO service_role;

-- 10) sequence ให้ตรงกับ seed
SELECT setval(pg_get_serial_sequence('maintenance_bookings','booking_id'),
              (SELECT COALESCE(MAX(booking_id),1) FROM maintenance_bookings));
SELECT setval(pg_get_serial_sequence('maintenance_booking_history','history_id'),
              (SELECT COALESCE(MAX(history_id),1) FROM maintenance_booking_history));
SELECT setval(pg_get_serial_sequence('attachments','attachment_id'),
              (SELECT COALESCE(MAX(attachment_id),1) FROM attachments));
