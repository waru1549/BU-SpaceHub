-- =====================================================
-- 011_ai_chat.sql  (Step 11-1: AI Chat — DB)
-- 1) chat_logs (มีอยู่แล้วจาก schema หลัก: ปรับให้รองรับผู้ใช้สาธารณะ)
--    user_id เป็น NULL ได้ | เพิ่ม session_id, ip_hash, model, tools_used | เพิ่มสถานะ RATE_LIMITED
ALTER TABLE chat_logs ALTER COLUMN user_id DROP NOT NULL;
ALTER TABLE chat_logs ADD COLUMN IF NOT EXISTS session_id TEXT;
ALTER TABLE chat_logs ADD COLUMN IF NOT EXISTS ip_hash    TEXT;
ALTER TABLE chat_logs ADD COLUMN IF NOT EXISTS model      TEXT;
ALTER TABLE chat_logs ADD COLUMN IF NOT EXISTS tools_used JSONB NOT NULL DEFAULT '[]'::jsonb;

ALTER TABLE chat_logs DROP CONSTRAINT IF EXISTS chat_logs_chat_status_check;
ALTER TABLE chat_logs ADD CONSTRAINT chat_logs_chat_status_check
  CHECK (chat_status IN ('SUCCESS','ERROR','REFUSED','RATE_LIMITED'));

ALTER TABLE chat_logs DROP CONSTRAINT IF EXISTS chk_chat_question;
ALTER TABLE chat_logs ADD CONSTRAINT chk_chat_question
  CHECK (length(btrim(question)) BETWEEN 1 AND 1000);
ALTER TABLE chat_logs DROP CONSTRAINT IF EXISTS chk_chat_tools;
ALTER TABLE chat_logs ADD CONSTRAINT chk_chat_tools
  CHECK (jsonb_typeof(tools_used) = 'array');

CREATE INDEX IF NOT EXISTS idx_chat_logs_session ON chat_logs (session_id, created_at);
CREATE INDEX IF NOT EXISTS idx_chat_logs_ip      ON chat_logs (ip_hash, created_at DESC);

-- 2) ai_knowledge     : กฎและวิธีใช้งานระบบ (ให้ AI ค้นหาผ่าน tool)
-- 3) v_ai_*           : view ปลอดข้อมูลส่วนบุคคล (PII-free) สำหรับ Tool Calling
-- ทุกอย่างเข้าถึงผ่าน service_role (BE) เท่านั้น | รันซ้ำได้ (idempotent)
-- =====================================================

-- 1) chat_logs
CREATE TABLE IF NOT EXISTS chat_logs (
  log_id       BIGSERIAL PRIMARY KEY,
  session_id   TEXT        NOT NULL,
  user_id      BIGINT      REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE SET NULL,
  ip_hash      TEXT,
  question     TEXT        NOT NULL,
  answer       TEXT,
  tools_used   JSONB       NOT NULL DEFAULT '[]'::jsonb,
  model        TEXT,
  status       TEXT        NOT NULL DEFAULT 'OK',
  latency_ms   INTEGER,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_chat_status   CHECK (status IN ('OK','ERROR','RATE_LIMITED','REFUSED')),
  CONSTRAINT chk_chat_question CHECK (length(btrim(question)) BETWEEN 1 AND 1000),
  CONSTRAINT chk_chat_tools    CHECK (jsonb_typeof(tools_used) = 'array')
);
CREATE INDEX IF NOT EXISTS idx_chat_logs_session ON chat_logs (session_id, created_at);
CREATE INDEX IF NOT EXISTS idx_chat_logs_created ON chat_logs (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_logs_ip      ON chat_logs (ip_hash, created_at DESC);

-- 2) ai_knowledge
CREATE TABLE IF NOT EXISTS ai_knowledge (
  topic_id   SMALLSERIAL PRIMARY KEY,
  topic_key  TEXT   NOT NULL UNIQUE,
  category   TEXT   NOT NULL,
  title      TEXT   NOT NULL,
  content    TEXT   NOT NULL,
  keywords   TEXT[] NOT NULL DEFAULT '{}',
  CONSTRAINT chk_knowledge_category CHECK (category IN ('GENERAL','ROOM','PRINTER','EQUIPMENT','MAINTENANCE'))
);

INSERT INTO ai_knowledge (topic_key, category, title, content, keywords) VALUES
('general_login','GENERAL','การเข้าสู่ระบบและบทบาท',
 'นักศึกษา (USER) เข้าสู่ระบบด้วยบัญชี Google ส่วนเจ้าหน้าที่ (STAFF) และผู้ดูแลระบบ (ADMIN) ใช้อีเมลและรหัสผ่าน | USER จอง/ยืม/แจ้งซ่อมและดูรายการของตัวเอง | STAFF อนุมัติ ปฏิเสธ และดำเนินการคำขอ | ADMIN ทำได้ทุกอย่างของ STAFF และมอบหมายงานแจ้งซ่อมให้ STAFF',
 ARRAY['เข้าสู่ระบบ','login','google','บทบาท','role','สิทธิ์','staff','admin']),
('general_status','GENERAL','ความหมายของสถานะคำขอ',
 'PENDING = รออนุมัติ/รอรับเรื่อง | APPROVED = อนุมัติแล้ว | REJECTED = ถูกปฏิเสธ | IN_PROGRESS = กำลังดำเนินการ | COMPLETED = เสร็จสิ้น | RECEIVED = รับของแล้ว/กำลังยืม | RETURNED = คืนแล้ว | OVERDUE = เกินกำหนดคืน | CANCELLED = ยกเลิก',
 ARRAY['สถานะ','status','pending','approved','overdue','รออนุมัติ']),
('room_rules','ROOM','กติกาการจองห้อง',
 'เลือกห้องและช่วงเวลาที่ว่างตามตารางที่เปิดให้จอง ระบุวัตถุประสงค์ แล้วรอ Staff อนุมัติ | ห้องที่ชำรุด ปิดซ่อม หรืองดให้บริการจะจองไม่ได้ | Staff อนุมัติการจองของตัวเองไม่ได้ | ผู้จองยกเลิกได้ก่อนเริ่มใช้งาน',
 ARRAY['จองห้อง','ห้อง','room','ประชุม','ยกเลิก']),
('printer_rules','PRINTER','กติกาการใช้เครื่องพิมพ์ 3D',
 'เลือกเครื่องและช่วงเวลาที่ว่าง ระบุวัสดุและน้ำหนักโดยประมาณ (ไม่เกิน 5,000 กรัม) | จองเวลาซ้อนกับรายการอื่นของตัวเองไม่ได้ | ขั้นตอน: รออนุมัติ > อนุมัติ > กำลังพิมพ์ > พิมพ์เสร็จ > ผู้ใช้กดรับงาน | ผู้จองยกเลิกได้ก่อนถึงเวลาเริ่ม | Staff อนุมัติรายการของตัวเองไม่ได้',
 ARRAY['เครื่องพิมพ์','3d','พิมพ์','printer','วัสดุ','น้ำหนัก','pla']),
('equipment_rules','EQUIPMENT','กติกาการยืม-คืนอุปกรณ์',
 'ยืมได้ไม่เกิน 7 วัน | จองล่วงหน้าไม่เกิน 14 วัน | ยืมพร้อมกันไม่เกิน 2 รายการ | กำหนดคืนเวลา 16:00 | คืนช้าไม่คิดค่าปรับ แต่ถ้ามีของเกินกำหนดคืนหรือมีค่าปรับค้างชำระ จะยืมใหม่ไม่ได้ | ถ้าอุปกรณ์ชำรุดหรือสูญหาย Staff กรอกค่าปรับตอนรับคืน',
 ARRAY['ยืม','คืน','อุปกรณ์','equipment','ค่าปรับ','fine','เกินกำหนด','overdue','7 วัน']),
('maintenance_rules','MAINTENANCE','กติกาการแจ้งซ่อม',
 'แจ้งซ่อมได้ทั้งทรัพยากรในระบบหรือพิมพ์สถานที่เอง แนบรูปได้ไม่เกิน 3 รูป (JPG/PNG/WebP ไม่เกิน 5 MB) | แจ้งค้างพร้อมกันได้ไม่เกิน 5 งาน และแจ้งซ้ำทรัพยากรเดียวกันขณะยังไม่ปิดงานไม่ได้ | ขั้นตอน: รอรับเรื่อง > ADMIN มอบหมาย STAFF > กำลังซ่อม > ซ่อมเสร็จ | ผู้แจ้งยกเลิกได้ก่อนเริ่มซ่อม | STAFF/ADMIN ปฏิเสธได้พร้อมเหตุผล | เมื่อเริ่มซ่อม ทรัพยากรจะเป็นสถานะปิดซ่อมบำรุง และกลับเป็นพร้อมใช้งานเมื่อซ่อมเสร็จ',
 ARRAY['แจ้งซ่อม','ซ่อม','maintenance','รูป','แนบ','มอบหมาย'])
ON CONFLICT (topic_key) DO UPDATE
  SET category = EXCLUDED.category, title = EXCLUDED.title,
      content = EXCLUDED.content, keywords = EXCLUDED.keywords;

-- 3) Views ปลอดข้อมูลส่วนบุคคล (ห้ามมี user_id / ชื่อ / อีเมล / เลขที่การจอง)

-- 3.1 ทรัพยากรและสถานะปัจจุบัน
CREATE OR REPLACE VIEW v_ai_resources WITH (security_invoker = true) AS
SELECT r.resource_code,
       r.resource_name,
       rc.type_name  AS category,
       r.location,
       r.capacity,
       r.quantity,
       rs.resource_status_name AS resource_status,
       (rs.resource_status_name = 'AVAILABLE') AS is_available
FROM resources r
JOIN resource_categories rc ON rc.type_id = r.type_id
JOIN resource_status rs     ON rs.resource_status_id = r.resource_status_id;

-- 3.2 ช่วงเวลาห้องที่ว่าง
CREATE OR REPLACE VIEW v_ai_room_slots WITH (security_invoker = true) AS
SELECT r.resource_code,
       r.resource_name,
       r.location,
       r.capacity,
       s.work_date,
       s.start_time,
       s.end_time,
       s.max_slots,
       GREATEST(s.max_slots - COALESCE(h.cnt, 0), 0)::int AS remaining_slots,
       (ss.schedule_status_name <> 'BLOCKED'
        AND rs.resource_status_name NOT IN ('BROKEN','UNDER_MAINTENANCE','OUT_OF_SERVICE')
        AND ((s.work_date + s.start_time) AT TIME ZONE 'Asia/Bangkok') > now()
        AND COALESCE(h.cnt, 0) < s.max_slots) AS is_bookable
FROM room_schedules s
JOIN schedule_status ss ON ss.schedule_status_id = s.schedule_status_id
JOIN resources r        ON r.resource_id = s.resource_id
JOIN resource_status rs ON rs.resource_status_id = r.resource_status_id
LEFT JOIN LATERAL (
  SELECT COUNT(*) AS cnt
  FROM room_bookings b
  JOIN booking_status bs ON bs.booking_status_id = b.booking_status_id
  WHERE b.schedule_id = s.schedule_id
    AND bs.booking_status_name IN ('PENDING','APPROVED','IN_PROGRESS','COMPLETED','RECEIVED')
) h ON true;

-- 3.3 ช่วงเวลาเครื่องพิมพ์ที่ว่าง
CREATE OR REPLACE VIEW v_ai_printer_slots WITH (security_invoker = true) AS
SELECT r.resource_code,
       r.resource_name,
       r.location,
       a.work_date,
       a.start_time,
       a.end_time,
       a.max_slots,
       a.remaining_slots,
       a.is_bookable
FROM v_printer_slot_availability a
JOIN resources r ON r.resource_id = a.resource_id;

-- 3.4 สต็อกอุปกรณ์ที่ยืมได้ตอนนี้
CREATE OR REPLACE VIEW v_ai_equipment_stock WITH (security_invoker = true) AS
SELECT r.resource_code,
       r.resource_name,
       r.location,
       COALESCE(r.quantity, 1)                   AS total_quantity,
       COALESCE(l.on_loan, 0)::int               AS on_loan,
       CASE WHEN rs.resource_status_name = 'AVAILABLE'
            THEN GREATEST(COALESCE(r.quantity, 1) - COALESCE(l.on_loan, 0), 0)
            ELSE 0 END::int                      AS available_quantity,
       rs.resource_status_name                   AS resource_status
FROM resources r
JOIN resource_categories rc ON rc.type_id = r.type_id AND rc.type_name = 'EQUIPMENT'
JOIN resource_status rs     ON rs.resource_status_id = r.resource_status_id
LEFT JOIN LATERAL (
  SELECT COUNT(*) AS on_loan
  FROM equipment_bookings eb
  JOIN booking_status bs ON bs.booking_status_id = eb.booking_status_id
  WHERE eb.resource_id = r.resource_id
    AND bs.booking_status_name IN ('RECEIVED','OVERDUE')
) l ON true;

-- 3.5 สถิติการใช้งานทรัพยากร (ไม่มีข้อมูลผู้ใช้)
CREATE OR REPLACE VIEW v_ai_usage_stats WITH (security_invoker = true) AS
SELECT resource_code, resource_name, resource_category, resource_status,
       location, total_bookings, completed_bookings,
       scheduled_hours, used_hours, utilization_pct
FROM v_resource_utilization;

-- 3.6 แนวโน้มรายเดือน (รวมทุกระบบ ไม่มีข้อมูลผู้ใช้รายคน)
CREATE OR REPLACE VIEW v_ai_monthly_trend WITH (security_invoker = true) AS
SELECT month_label, module, total_bookings
FROM v_monthly_booking_trend;

-- 3.7 สรุปงานแจ้งซ่อมแยกสถานะและประเภท (ไม่มีชื่อผู้แจ้ง/ผู้ซ่อม)
CREATE OR REPLACE VIEW v_ai_maintenance_summary WITH (security_invoker = true) AS
SELECT COALESCE(rc.type_name, 'OTHER') AS resource_category,
       bs.booking_status_name          AS status,
       COUNT(*)::int                   AS total
FROM maintenance_bookings mb
JOIN booking_status bs        ON bs.booking_status_id = mb.booking_status_id
LEFT JOIN resources r         ON r.resource_id = mb.resource_id
LEFT JOIN resource_categories rc ON rc.type_id = r.type_id
GROUP BY 1, 2;

-- 4) สิทธิ์: เฉพาะ service_role (BE) | RLS เปิด ไม่มี policy = anon/authenticated อ่านไม่ได้
ALTER TABLE chat_logs    ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_knowledge ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON chat_logs, ai_knowledge FROM PUBLIC, anon, authenticated;
REVOKE ALL ON v_ai_resources, v_ai_room_slots, v_ai_printer_slots, v_ai_equipment_stock,
              v_ai_usage_stats, v_ai_monthly_trend, v_ai_maintenance_summary
  FROM PUBLIC, anon, authenticated;

GRANT SELECT, INSERT ON chat_logs TO service_role;
GRANT SELECT ON ai_knowledge TO service_role;
GRANT SELECT ON v_ai_resources, v_ai_room_slots, v_ai_printer_slots, v_ai_equipment_stock,
                v_ai_usage_stats, v_ai_monthly_trend, v_ai_maintenance_summary TO service_role;
GRANT USAGE, SELECT ON SEQUENCE chat_logs_chat_id_seq TO service_role;
