-- =====================================================================
-- 012_admin_resources.sql  |  Admin CRUD ทรัพยากร (Step A1: DB)
-- ทำซ้ำได้ | รันใน Supabase SQL Editor | เรียกผ่าน BE (service_role) เท่านั้น
--   v_admin_resources / v_admin_schedules : ข้อมูลสำหรับหน้าจัดการ
--   fn_admin_resource_create / _update / _delete
--   fn_admin_generate_schedules / fn_admin_schedule_set_block / fn_admin_schedule_delete
-- กติกา: หมวดหมู่เปลี่ยนไม่ได้ | ลบจริงเฉพาะที่ไม่มีประวัติ ถ้ามีประวัติจะปิดเป็น OUT_OF_SERVICE
--        มีงานค้าง (รออนุมัติ/อนุมัติแล้ว/กำลังดำเนินการ/กำลังยืม/เกินกำหนด) = ลบ/ปิดไม่ได้
--        สถานะที่ Admin ตั้งเองได้: AVAILABLE, BROKEN, UNDER_MAINTENANCE, OUT_OF_SERVICE
-- =====================================================================

-- 1) View รายการทรัพยากรสำหรับ Admin --------------------------------------
CREATE OR REPLACE VIEW v_admin_resources WITH (security_invoker = true) AS
SELECT r.resource_id,
       r.resource_code,
       r.resource_name,
       r.type_id,
       rc.type_name            AS category,
       r.location,
       r.capacity,
       r.quantity,
       r.description,
       r.resource_status_id,
       rs.resource_status_name AS resource_status,
       r.created_at,
       (SELECT COUNT(*) FROM room_schedules s WHERE s.resource_id = r.resource_id AND s.work_date >= (now() AT TIME ZONE 'Asia/Bangkok')::date)::int
     + (SELECT COUNT(*) FROM printer_schedules s WHERE s.resource_id = r.resource_id AND s.work_date >= (now() AT TIME ZONE 'Asia/Bangkok')::date)::int
                                AS upcoming_slots,
       h.history_count,
       h.active_count
FROM resources r
JOIN resource_categories rc ON rc.type_id = r.type_id
JOIN resource_status rs     ON rs.resource_status_id = r.resource_status_id
CROSS JOIN LATERAL (
  SELECT COUNT(*)::int AS history_count,
         COUNT(*) FILTER (WHERE st IN ('PENDING','APPROVED','IN_PROGRESS','RECEIVED','OVERDUE'))::int AS active_count
  FROM (
    SELECT bs.booking_status_name AS st FROM room_bookings b
      JOIN room_schedules s ON s.schedule_id = b.schedule_id
      JOIN booking_status bs ON bs.booking_status_id = b.booking_status_id WHERE s.resource_id = r.resource_id
    UNION ALL
    SELECT bs.booking_status_name FROM printer_bookings b
      JOIN printer_schedules s ON s.schedule_id = b.schedule_id
      JOIN booking_status bs ON bs.booking_status_id = b.booking_status_id WHERE s.resource_id = r.resource_id
    UNION ALL
    SELECT bs.booking_status_name FROM equipment_bookings b
      JOIN booking_status bs ON bs.booking_status_id = b.booking_status_id WHERE b.resource_id = r.resource_id
    UNION ALL
    SELECT bs.booking_status_name FROM maintenance_bookings b
      JOIN booking_status bs ON bs.booking_status_id = b.booking_status_id WHERE b.resource_id = r.resource_id
  ) x
) h;

-- 2) View ตารางเวลา (ห้อง + เครื่องพิมพ์) ---------------------------------
CREATE OR REPLACE VIEW v_admin_schedules WITH (security_invoker = true) AS
SELECT 'ROOM'::text AS kind, s.schedule_id, s.resource_id, r.resource_code, r.resource_name,
       s.work_date, s.start_time, s.end_time, s.max_slots,
       ss.schedule_status_name AS schedule_status,
       COALESCE(h.cnt, 0)::int AS booked_slots,
       GREATEST(s.max_slots - COALESCE(h.cnt, 0), 0)::int AS remaining_slots
FROM room_schedules s
JOIN resources r ON r.resource_id = s.resource_id
JOIN schedule_status ss ON ss.schedule_status_id = s.schedule_status_id
LEFT JOIN LATERAL (
  SELECT COUNT(*) AS cnt FROM room_bookings b JOIN booking_status bs ON bs.booking_status_id = b.booking_status_id
  WHERE b.schedule_id = s.schedule_id AND bs.booking_status_name IN ('PENDING','APPROVED','IN_PROGRESS','COMPLETED','RECEIVED')
) h ON true
UNION ALL
SELECT 'PRINTER'::text, s.schedule_id, s.resource_id, r.resource_code, r.resource_name,
       s.work_date, s.start_time, s.end_time, s.max_slots,
       ss.schedule_status_name,
       COALESCE(h.cnt, 0)::int,
       GREATEST(s.max_slots - COALESCE(h.cnt, 0), 0)::int
FROM printer_schedules s
JOIN resources r ON r.resource_id = s.resource_id
JOIN schedule_status ss ON ss.schedule_status_id = s.schedule_status_id
LEFT JOIN LATERAL (
  SELECT COUNT(*) AS cnt FROM printer_bookings b JOIN booking_status bs ON bs.booking_status_id = b.booking_status_id
  WHERE b.schedule_id = s.schedule_id AND bs.booking_status_name IN ('PENDING','APPROVED','IN_PROGRESS','COMPLETED','RECEIVED')
) h ON true;

-- 3) ตัวช่วยภายใน: ตรวจ/ปรับค่ารับเข้า ------------------------------------
CREATE OR REPLACE FUNCTION fn_admin_validate_resource(
  p_code TEXT, p_name TEXT, p_category TEXT, p_capacity INT, p_quantity INT
) RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
  IF p_code IS NULL OR btrim(p_code) !~ '^[A-Za-z0-9_-]{2,50}$' THEN RAISE EXCEPTION 'CODE_INVALID'; END IF;
  IF p_name IS NULL OR length(btrim(p_name)) < 2 OR length(btrim(p_name)) > 255 THEN RAISE EXCEPTION 'NAME_INVALID'; END IF;
  IF p_capacity IS NOT NULL AND (p_capacity < 1 OR p_capacity > 1000) THEN RAISE EXCEPTION 'CAPACITY_INVALID'; END IF;
  IF p_quantity IS NOT NULL AND (p_quantity < 1 OR p_quantity > 10000) THEN RAISE EXCEPTION 'QUANTITY_INVALID'; END IF;
  IF p_category = 'ROOM' AND p_capacity IS NULL THEN RAISE EXCEPTION 'CAPACITY_REQUIRED'; END IF;
  IF p_category = 'EQUIPMENT' AND p_quantity IS NULL THEN RAISE EXCEPTION 'QUANTITY_REQUIRED'; END IF;
END $$;

-- 4) เพิ่มทรัพยากร ----------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_admin_resource_create(
  p_code TEXT, p_name TEXT, p_type_id SMALLINT, p_location TEXT,
  p_capacity INT, p_quantity INT, p_description TEXT, p_status TEXT DEFAULT 'AVAILABLE'
) RETURNS TABLE (new_resource_id BIGINT)
LANGUAGE plpgsql AS $$
DECLARE v_cat TEXT; v_status_id SMALLINT; v_id BIGINT;
BEGIN
  SELECT type_name INTO v_cat FROM resource_categories WHERE type_id = p_type_id;
  IF v_cat IS NULL THEN RAISE EXCEPTION 'CATEGORY_INVALID'; END IF;
  PERFORM fn_admin_validate_resource(p_code, p_name, v_cat, p_capacity, p_quantity);
  IF p_status NOT IN ('AVAILABLE','BROKEN','UNDER_MAINTENANCE','OUT_OF_SERVICE') THEN RAISE EXCEPTION 'STATUS_NOT_ALLOWED'; END IF;
  SELECT resource_status_id INTO v_status_id FROM resource_status WHERE resource_status_name = p_status;
  IF EXISTS (SELECT 1 FROM resources WHERE lower(resource_code) = lower(btrim(p_code))) THEN RAISE EXCEPTION 'CODE_EXISTS'; END IF;

  INSERT INTO resources (resource_code, resource_name, type_id, location, resource_status_id, capacity, quantity, description)
  VALUES (btrim(p_code), btrim(p_name), p_type_id, NULLIF(btrim(COALESCE(p_location, '')), ''), v_status_id,
          p_capacity, p_quantity, NULLIF(btrim(COALESCE(p_description, '')), ''))
  RETURNING resource_id INTO v_id;
  RETURN QUERY SELECT v_id;
END $$;

-- 5) แก้ไขทรัพยากร (หมวดหมู่เปลี่ยนไม่ได้) --------------------------------
CREATE OR REPLACE FUNCTION fn_admin_resource_update(
  p_resource_id BIGINT, p_code TEXT, p_name TEXT, p_location TEXT,
  p_capacity INT, p_quantity INT, p_description TEXT, p_status TEXT
) RETURNS TABLE (out_resource_id BIGINT)
LANGUAGE plpgsql AS $$
DECLARE v_r resources%ROWTYPE; v_cat TEXT; v_cur TEXT; v_status_id SMALLINT;
BEGIN
  SELECT * INTO v_r FROM resources WHERE resource_id = p_resource_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'RESOURCE_NOT_FOUND'; END IF;
  SELECT type_name INTO v_cat FROM resource_categories WHERE type_id = v_r.type_id;
  SELECT resource_status_name INTO v_cur FROM resource_status WHERE resource_status_id = v_r.resource_status_id;
  PERFORM fn_admin_validate_resource(p_code, p_name, v_cat, p_capacity, p_quantity);

  IF p_status IS DISTINCT FROM v_cur THEN
    IF p_status NOT IN ('AVAILABLE','BROKEN','UNDER_MAINTENANCE','OUT_OF_SERVICE') THEN RAISE EXCEPTION 'STATUS_NOT_ALLOWED'; END IF;
  END IF;
  SELECT resource_status_id INTO v_status_id FROM resource_status WHERE resource_status_name = COALESCE(p_status, v_cur);
  IF v_status_id IS NULL THEN RAISE EXCEPTION 'STATUS_NOT_ALLOWED'; END IF;

  IF EXISTS (SELECT 1 FROM resources WHERE lower(resource_code) = lower(btrim(p_code)) AND resource_id <> p_resource_id) THEN
    RAISE EXCEPTION 'CODE_EXISTS';
  END IF;

  UPDATE resources
     SET resource_code = btrim(p_code),
         resource_name = btrim(p_name),
         location = NULLIF(btrim(COALESCE(p_location, '')), ''),
         capacity = p_capacity,
         quantity = p_quantity,
         description = NULLIF(btrim(COALESCE(p_description, '')), ''),
         resource_status_id = v_status_id
   WHERE resource_id = p_resource_id;
  RETURN QUERY SELECT p_resource_id;
END $$;

-- 6) ลบทรัพยากร: ไม่มีประวัติ = ลบจริง | มีประวัติ = ปิดเป็น OUT_OF_SERVICE | มีงานค้าง = ปฏิเสธ
CREATE OR REPLACE FUNCTION fn_admin_resource_delete(p_resource_id BIGINT)
RETURNS TABLE (result TEXT)
LANGUAGE plpgsql AS $$
DECLARE v_hist INT; v_active INT;
BEGIN
  PERFORM 1 FROM resources WHERE resource_id = p_resource_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'RESOURCE_NOT_FOUND'; END IF;
  SELECT history_count, active_count INTO v_hist, v_active FROM v_admin_resources WHERE resource_id = p_resource_id;
  IF v_active > 0 THEN RAISE EXCEPTION 'HAS_ACTIVE_BOOKINGS'; END IF;

  IF v_hist = 0 THEN
    DELETE FROM resources WHERE resource_id = p_resource_id;   -- ตารางเวลาที่ว่างจะถูกลบตาม (CASCADE)
    RETURN QUERY SELECT 'DELETED'::text;
  ELSE
    UPDATE resources SET resource_status_id = (SELECT resource_status_id FROM resource_status WHERE resource_status_name = 'OUT_OF_SERVICE')
     WHERE resource_id = p_resource_id;
    RETURN QUERY SELECT 'DEACTIVATED'::text;
  END IF;
END $$;

-- 7) สร้างตารางเวลาเป็นชุด (ห้อง/เครื่องพิมพ์) -------------------------------
--    p_weekdays: ISO 1=จันทร์ ... 7=อาทิตย์ | p_slots: [{"start":"09:00","end":"11:00"}, ...]
--    ข้ามช่วงที่ซ้อนทับกับช่วงเดิมของทรัพยากรเดียวกัน
CREATE OR REPLACE FUNCTION fn_admin_generate_schedules(
  p_resource_id BIGINT, p_date_from DATE, p_date_to DATE,
  p_weekdays INT[], p_slots JSONB, p_max_slots INT DEFAULT 1
) RETURNS TABLE (inserted INT, skipped INT)
LANGUAGE plpgsql AS $$
DECLARE
  v_cat TEXT; v_today DATE := (now() AT TIME ZONE 'Asia/Bangkok')::date;
  v_avail SMALLINT; v_total INT; v_ins INT;
BEGIN
  SELECT rc.type_name INTO v_cat FROM resources r JOIN resource_categories rc ON rc.type_id = r.type_id
   WHERE r.resource_id = p_resource_id;
  IF v_cat IS NULL THEN RAISE EXCEPTION 'RESOURCE_NOT_FOUND'; END IF;
  IF v_cat NOT IN ('ROOM','PRINTER') THEN RAISE EXCEPTION 'NO_SCHEDULE_FOR_CATEGORY'; END IF;
  IF p_date_from IS NULL OR p_date_to IS NULL OR p_date_to < p_date_from THEN RAISE EXCEPTION 'DATE_RANGE_INVALID'; END IF;
  IF p_date_from < v_today THEN RAISE EXCEPTION 'DATE_IN_PAST'; END IF;
  IF p_date_to - p_date_from > 92 THEN RAISE EXCEPTION 'RANGE_TOO_LONG'; END IF;
  IF p_weekdays IS NULL OR cardinality(p_weekdays) = 0 OR EXISTS (SELECT 1 FROM unnest(p_weekdays) w WHERE w NOT BETWEEN 1 AND 7) THEN
    RAISE EXCEPTION 'WEEKDAYS_INVALID';
  END IF;
  IF p_max_slots IS NULL OR p_max_slots < 1 OR p_max_slots > 20 THEN RAISE EXCEPTION 'MAX_SLOTS_INVALID'; END IF;
  IF p_slots IS NULL OR jsonb_typeof(p_slots) <> 'array' OR jsonb_array_length(p_slots) NOT BETWEEN 1 AND 12 THEN
    RAISE EXCEPTION 'SLOTS_INVALID';
  END IF;

  -- ตรวจรูปแบบเวลา (ไม่ใช้ temp table เพื่อไม่ต้องพึ่งสิทธิ์ TEMP ของ service_role)
  BEGIN
    PERFORM 1 FROM jsonb_array_elements(p_slots) e
     WHERE (e->>'start')::time IS NULL OR (e->>'end')::time IS NULL OR (e->>'end')::time <= (e->>'start')::time;
    IF FOUND THEN RAISE EXCEPTION 'SLOTS_INVALID'; END IF;
  EXCEPTION WHEN invalid_text_representation OR invalid_datetime_format OR datetime_field_overflow THEN
    RAISE EXCEPTION 'SLOTS_INVALID';
  END;
  IF EXISTS (
    WITH g AS (SELECT (e->>'start')::time AS st, (e->>'end')::time AS en FROM jsonb_array_elements(p_slots) e)
    SELECT 1 FROM g a JOIN g b ON a.st < b.en AND a.en > b.st AND (a.st, a.en) <> (b.st, b.en)
  ) THEN RAISE EXCEPTION 'SLOTS_OVERLAP'; END IF;
  IF (SELECT COUNT(DISTINCT (e->>'start', e->>'end')) FROM jsonb_array_elements(p_slots) e) <> jsonb_array_length(p_slots) THEN
    RAISE EXCEPTION 'SLOTS_OVERLAP';
  END IF;

  SELECT schedule_status_id INTO v_avail FROM schedule_status WHERE schedule_status_name = 'AVAILABLE';
  SELECT COUNT(*)::int INTO v_total
    FROM generate_series(p_date_from, p_date_to, interval '1 day') d
    CROSS JOIN jsonb_array_elements(p_slots) e
   WHERE extract(isodow FROM d)::int = ANY (p_weekdays);

  IF v_cat = 'ROOM' THEN
    INSERT INTO room_schedules (resource_id, work_date, start_time, end_time, max_slots, schedule_status_id)
    SELECT p_resource_id, d::date, g.st, g.en, p_max_slots, v_avail
      FROM generate_series(p_date_from, p_date_to, interval '1 day') d
      CROSS JOIN (SELECT (e->>'start')::time AS st, (e->>'end')::time AS en FROM jsonb_array_elements(p_slots) e) g
     WHERE extract(isodow FROM d)::int = ANY (p_weekdays)
       AND NOT EXISTS (SELECT 1 FROM room_schedules s WHERE s.resource_id = p_resource_id AND s.work_date = d::date
                         AND s.start_time < g.en AND s.end_time > g.st);
  ELSE
    INSERT INTO printer_schedules (resource_id, work_date, start_time, end_time, max_slots, schedule_status_id)
    SELECT p_resource_id, d::date, g.st, g.en, p_max_slots, v_avail
      FROM generate_series(p_date_from, p_date_to, interval '1 day') d
      CROSS JOIN (SELECT (e->>'start')::time AS st, (e->>'end')::time AS en FROM jsonb_array_elements(p_slots) e) g
     WHERE extract(isodow FROM d)::int = ANY (p_weekdays)
       AND NOT EXISTS (SELECT 1 FROM printer_schedules s WHERE s.resource_id = p_resource_id AND s.work_date = d::date
                         AND s.start_time < g.en AND s.end_time > g.st);
  END IF;
  GET DIAGNOSTICS v_ins = ROW_COUNT;
  RETURN QUERY SELECT v_ins, GREATEST(v_total - v_ins, 0);
END $$;

-- 8) บล็อก/ปลดบล็อกช่วงเวลา ---------------------------------------------------
CREATE OR REPLACE FUNCTION fn_admin_schedule_set_block(p_kind TEXT, p_schedule_id BIGINT, p_blocked BOOLEAN)
RETURNS TABLE (out_status TEXT)
LANGUAGE plpgsql AS $$
DECLARE v_active INT; v_status_id SMALLINT; v_name TEXT := CASE WHEN p_blocked THEN 'BLOCKED' ELSE 'AVAILABLE' END; v_found BOOLEAN;
BEGIN
  IF p_kind NOT IN ('ROOM','PRINTER') THEN RAISE EXCEPTION 'KIND_INVALID'; END IF;
  SELECT schedule_status_id INTO v_status_id FROM schedule_status WHERE schedule_status_name = v_name;

  IF p_kind = 'ROOM' THEN
    SELECT EXISTS (SELECT 1 FROM room_schedules WHERE schedule_id = p_schedule_id) INTO v_found;
    IF NOT v_found THEN RAISE EXCEPTION 'SCHEDULE_NOT_FOUND'; END IF;
    SELECT COUNT(*) INTO v_active FROM room_bookings b JOIN booking_status bs ON bs.booking_status_id = b.booking_status_id
     WHERE b.schedule_id = p_schedule_id AND bs.booking_status_name IN ('PENDING','APPROVED','IN_PROGRESS');
    IF p_blocked AND v_active > 0 THEN RAISE EXCEPTION 'SLOT_HAS_BOOKINGS'; END IF;
    UPDATE room_schedules SET schedule_status_id = v_status_id WHERE schedule_id = p_schedule_id;
  ELSE
    SELECT EXISTS (SELECT 1 FROM printer_schedules WHERE schedule_id = p_schedule_id) INTO v_found;
    IF NOT v_found THEN RAISE EXCEPTION 'SCHEDULE_NOT_FOUND'; END IF;
    SELECT COUNT(*) INTO v_active FROM printer_bookings b JOIN booking_status bs ON bs.booking_status_id = b.booking_status_id
     WHERE b.schedule_id = p_schedule_id AND bs.booking_status_name IN ('PENDING','APPROVED','IN_PROGRESS');
    IF p_blocked AND v_active > 0 THEN RAISE EXCEPTION 'SLOT_HAS_BOOKINGS'; END IF;
    UPDATE printer_schedules SET schedule_status_id = v_status_id WHERE schedule_id = p_schedule_id;
  END IF;
  RETURN QUERY SELECT v_name;
END $$;

-- 9) ลบช่วงเวลา: ลบได้เฉพาะช่วงที่ไม่เคยมีการจอง ---------------------------------
CREATE OR REPLACE FUNCTION fn_admin_schedule_delete(p_kind TEXT, p_schedule_id BIGINT)
RETURNS TABLE (deleted_id BIGINT)
LANGUAGE plpgsql AS $$
DECLARE v_cnt INT;
BEGIN
  IF p_kind NOT IN ('ROOM','PRINTER') THEN RAISE EXCEPTION 'KIND_INVALID'; END IF;
  IF p_kind = 'ROOM' THEN
    IF NOT EXISTS (SELECT 1 FROM room_schedules WHERE schedule_id = p_schedule_id) THEN RAISE EXCEPTION 'SCHEDULE_NOT_FOUND'; END IF;
    SELECT COUNT(*) INTO v_cnt FROM room_bookings WHERE schedule_id = p_schedule_id;
    IF v_cnt > 0 THEN RAISE EXCEPTION 'SLOT_HAS_BOOKINGS'; END IF;
    DELETE FROM room_schedules WHERE schedule_id = p_schedule_id;
  ELSE
    IF NOT EXISTS (SELECT 1 FROM printer_schedules WHERE schedule_id = p_schedule_id) THEN RAISE EXCEPTION 'SCHEDULE_NOT_FOUND'; END IF;
    SELECT COUNT(*) INTO v_cnt FROM printer_bookings WHERE schedule_id = p_schedule_id;
    IF v_cnt > 0 THEN RAISE EXCEPTION 'SLOT_HAS_BOOKINGS'; END IF;
    DELETE FROM printer_schedules WHERE schedule_id = p_schedule_id;
  END IF;
  RETURN QUERY SELECT p_schedule_id;
END $$;

-- 10) สิทธิ์: เฉพาะ service_role (BE) -----------------------------------------
REVOKE ALL ON v_admin_resources, v_admin_schedules FROM PUBLIC, anon, authenticated;
GRANT SELECT ON v_admin_resources, v_admin_schedules TO service_role;

REVOKE ALL ON FUNCTION fn_admin_validate_resource(TEXT, TEXT, TEXT, INT, INT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION fn_admin_resource_create(TEXT, TEXT, SMALLINT, TEXT, INT, INT, TEXT, TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION fn_admin_resource_update(BIGINT, TEXT, TEXT, TEXT, INT, INT, TEXT, TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION fn_admin_resource_delete(BIGINT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION fn_admin_generate_schedules(BIGINT, DATE, DATE, INT[], JSONB, INT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION fn_admin_schedule_set_block(TEXT, BIGINT, BOOLEAN) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION fn_admin_schedule_delete(TEXT, BIGINT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_admin_validate_resource(TEXT, TEXT, TEXT, INT, INT) TO service_role;
GRANT EXECUTE ON FUNCTION fn_admin_resource_create(TEXT, TEXT, SMALLINT, TEXT, INT, INT, TEXT, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION fn_admin_resource_update(BIGINT, TEXT, TEXT, TEXT, INT, INT, TEXT, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION fn_admin_resource_delete(BIGINT) TO service_role;
GRANT EXECUTE ON FUNCTION fn_admin_generate_schedules(BIGINT, DATE, DATE, INT[], JSONB, INT) TO service_role;
GRANT EXECUTE ON FUNCTION fn_admin_schedule_set_block(TEXT, BIGINT, BOOLEAN) TO service_role;
GRANT EXECUTE ON FUNCTION fn_admin_schedule_delete(TEXT, BIGINT) TO service_role;
