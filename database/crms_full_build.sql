-- =====================================================================
-- crms_full_build.sql : สร้างฐานข้อมูล BU SpaceHub (CRMS) ทั้งหมดในไฟล์เดียว
-- วิธีใช้ : รันทั้งไฟล์ใน Supabase SQL Editor (หรือ psql -f) บนโปรเจกต์/ฐานข้อมูลที่ "ว่างหรือยอมให้ล้าง"
-- คำเตือน : ไฟล์นี้ DROP ตารางทุกตาราง และ TRUNCATE ข้อมูลเดิมก่อนใส่ข้อมูลจำลอง (ห้ามรันบนฐานข้อมูลที่มีข้อมูลจริง)
-- ต้องมีตาราง auth.users (มีอยู่แล้วใน Supabase) และ role anon / authenticated / service_role
-- เนื้อหา = ไฟล์ตามลำดับด้านล่าง ต่อกันโดยไม่แก้ไข (ลำดับเดียวกับที่ใช้พัฒนาจริง)
-- ไฟล์ทดสอบ (008_test ... 013_test) ไม่รวมในนี้ ให้รันแยกหลังสร้างเสร็จ (ดู README.md)
-- ตรวจแล้ว : รันบนฐานข้อมูลว่างได้ครบโดยไม่มี error และผ่านชุดทดสอบทั้งหมด
-- =====================================================================

-- #####################################################################
-- 1) โครงสร้างตาราง (DROP แล้วสร้างใหม่ทั้งหมด) : crms_complete_schema.sql
-- #####################################################################
-- =====================================================
-- CRMS COMPLETE SCHEMA
-- Campus Resource Management System
-- PostgreSQL / Supabase
-- =====================================================

-- =====================================================
-- DROP TABLES
-- =====================================================

DROP TABLE IF EXISTS attachments CASCADE;

DROP TABLE IF EXISTS maintenance_booking_history CASCADE;
DROP TABLE IF EXISTS maintenance_bookings CASCADE;

DROP TABLE IF EXISTS fines CASCADE;
DROP TABLE IF EXISTS equipment_booking_history CASCADE;
DROP TABLE IF EXISTS equipment_bookings CASCADE;

DROP TABLE IF EXISTS printer_booking_history CASCADE;
DROP TABLE IF EXISTS printer_bookings CASCADE;
DROP TABLE IF EXISTS printer_schedules CASCADE;

DROP TABLE IF EXISTS room_booking_history CASCADE;
DROP TABLE IF EXISTS room_bookings CASCADE;
DROP TABLE IF EXISTS room_schedules CASCADE;

DROP TABLE IF EXISTS booking_actions CASCADE;
DROP TABLE IF EXISTS booking_status CASCADE;

DROP TABLE IF EXISTS schedule_status CASCADE;

DROP TABLE IF EXISTS resources CASCADE;
DROP TABLE IF EXISTS resource_status CASCADE;
DROP TABLE IF EXISTS resource_categories CASCADE;

DROP TABLE IF EXISTS chat_logs CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS user_roles CASCADE;

-- =====================================================
-- SHARED CORE TABLES
-- =====================================================

CREATE TABLE user_roles (
    role_id SMALLSERIAL PRIMARY KEY,
    role_name VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE users (
    user_id BIGSERIAL PRIMARY KEY,
    auth_user_id UUID UNIQUE,
    user_code VARCHAR(50) UNIQUE,
    google_id VARCHAR(255) UNIQUE,
    university_id VARCHAR(50),
    full_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    phone VARCHAR(50),
    role_id SMALLINT NOT NULL,
    user_status VARCHAR(20)
        DEFAULT 'ACTIVE'
        CHECK (
            user_status IN
            (
                'ACTIVE',
                'INACTIVE',
                'SUSPENDED'
            )
        ),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMPTZ,

    CONSTRAINT fk_users_role
    FOREIGN KEY(role_id)
    REFERENCES user_roles(role_id)
    ON UPDATE CASCADE,

    CONSTRAINT fk_users_auth
    FOREIGN KEY(auth_user_id)
    REFERENCES auth.users(id)
    ON DELETE SET NULL
);

CREATE TABLE resource_categories (
    type_id SMALLSERIAL PRIMARY KEY,
    type_name VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE resource_status (
    resource_status_id SMALLSERIAL PRIMARY KEY,
    resource_status_name VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE resources (
    resource_id BIGSERIAL PRIMARY KEY,

    resource_code VARCHAR(100)
        NOT NULL UNIQUE,

    resource_name VARCHAR(255)
        NOT NULL,

    type_id SMALLINT NOT NULL,

    location VARCHAR(255),

    resource_status_id SMALLINT NOT NULL,

    capacity INTEGER
        CHECK (
            capacity IS NULL
            OR capacity > 0
        ),

    quantity INTEGER
        CHECK (
            quantity IS NULL
            OR quantity > 0
        ),

    description TEXT,

    created_at TIMESTAMPTZ
        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_resource_category
    FOREIGN KEY(type_id)
    REFERENCES resource_categories(type_id)
    ON UPDATE CASCADE,

    CONSTRAINT fk_resource_status
    FOREIGN KEY(resource_status_id)
    REFERENCES resource_status(resource_status_id)
    ON UPDATE CASCADE
);

CREATE TABLE schedule_status (
    schedule_status_id SMALLSERIAL PRIMARY KEY,
    schedule_status_name VARCHAR(50)
        NOT NULL UNIQUE
);

CREATE TABLE booking_status (
    booking_status_id SMALLSERIAL PRIMARY KEY,
    booking_status_name VARCHAR(50)
        NOT NULL UNIQUE
);

CREATE TABLE booking_actions (
    action_id SMALLSERIAL PRIMARY KEY,
    action_name VARCHAR(100)
        NOT NULL UNIQUE
);

-- =====================================================
-- ROOM BOOKING MODULE
-- =====================================================

CREATE TABLE room_schedules (

    schedule_id BIGSERIAL PRIMARY KEY,

    resource_id BIGINT NOT NULL,

    work_date DATE NOT NULL,

    start_time TIME NOT NULL,

    end_time TIME NOT NULL,

    max_slots INTEGER NOT NULL
        DEFAULT 1,

    schedule_status_id SMALLINT NOT NULL,

    created_at TIMESTAMPTZ
        DEFAULT CURRENT_TIMESTAMP,

    CHECK(max_slots > 0),

    CHECK(end_time > start_time),

    CONSTRAINT fk_room_schedule_resource
    FOREIGN KEY(resource_id)
    REFERENCES resources(resource_id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,

    CONSTRAINT fk_room_schedule_status
    FOREIGN KEY(schedule_status_id)
    REFERENCES schedule_status(schedule_status_id)
    ON UPDATE CASCADE,

    CONSTRAINT uq_room_schedule
    UNIQUE
    (
        resource_id,
        work_date,
        start_time,
        end_time
    )
);

CREATE TABLE room_bookings (

    booking_id BIGSERIAL PRIMARY KEY,

    booking_code VARCHAR(50)
        NOT NULL UNIQUE,

    user_id BIGINT NOT NULL,

    schedule_id BIGINT NOT NULL,

    booking_time TIMESTAMPTZ
        DEFAULT CURRENT_TIMESTAMP,

    booking_status_id SMALLINT NOT NULL,

    booking_purpose TEXT,

    CONSTRAINT fk_room_booking_user
    FOREIGN KEY(user_id)
    REFERENCES users(user_id)
    ON UPDATE CASCADE,

    CONSTRAINT fk_room_booking_schedule
    FOREIGN KEY(schedule_id)
    REFERENCES room_schedules(schedule_id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,

    CONSTRAINT fk_room_booking_status
    FOREIGN KEY(booking_status_id)
    REFERENCES booking_status(booking_status_id)
    ON UPDATE CASCADE
);

CREATE TABLE room_booking_history (

    history_id BIGSERIAL PRIMARY KEY,

    booking_id BIGINT NOT NULL,

    action_id SMALLINT NOT NULL,

    action_date TIMESTAMPTZ
        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_room_history_booking
    FOREIGN KEY(booking_id)
    REFERENCES room_bookings(booking_id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,

    CONSTRAINT fk_room_history_action
    FOREIGN KEY(action_id)
    REFERENCES booking_actions(action_id)
    ON UPDATE CASCADE
);

-- =====================================================
-- 3D PRINTER MODULE
-- =====================================================

CREATE TABLE printer_schedules (

    schedule_id BIGSERIAL PRIMARY KEY,

    resource_id BIGINT NOT NULL,

    work_date DATE NOT NULL,

    start_time TIME NOT NULL,

    end_time TIME NOT NULL,

    max_slots INTEGER NOT NULL
        DEFAULT 1,

    schedule_status_id SMALLINT NOT NULL,

    created_at TIMESTAMPTZ
        DEFAULT CURRENT_TIMESTAMP,

    CHECK(max_slots > 0),

    CHECK(end_time > start_time),

    CONSTRAINT fk_printer_schedule_resource
    FOREIGN KEY(resource_id)
    REFERENCES resources(resource_id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,

    CONSTRAINT fk_printer_schedule_status
    FOREIGN KEY(schedule_status_id)
    REFERENCES schedule_status(schedule_status_id)
    ON UPDATE CASCADE,

    CONSTRAINT uq_printer_schedule
    UNIQUE
    (
        resource_id,
        work_date,
        start_time,
        end_time
    )
);

CREATE TABLE printer_bookings (

    booking_id BIGSERIAL PRIMARY KEY,

    booking_code VARCHAR(50)
        NOT NULL UNIQUE,

    user_id BIGINT NOT NULL,

    schedule_id BIGINT NOT NULL,

    booking_time TIMESTAMPTZ
        DEFAULT CURRENT_TIMESTAMP,

    booking_status_id SMALLINT NOT NULL,

    print_purpose TEXT,

    CONSTRAINT fk_printer_booking_user
    FOREIGN KEY(user_id)
    REFERENCES users(user_id)
    ON UPDATE CASCADE,

    CONSTRAINT fk_printer_booking_schedule
    FOREIGN KEY(schedule_id)
    REFERENCES printer_schedules(schedule_id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,

    CONSTRAINT fk_printer_booking_status
    FOREIGN KEY(booking_status_id)
    REFERENCES booking_status(booking_status_id)
    ON UPDATE CASCADE
);

CREATE TABLE printer_booking_history (

    history_id BIGSERIAL PRIMARY KEY,

    booking_id BIGINT NOT NULL,

    action_id SMALLINT NOT NULL,

    action_date TIMESTAMPTZ
        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_printer_history_booking
    FOREIGN KEY(booking_id)
    REFERENCES printer_bookings(booking_id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,

    CONSTRAINT fk_printer_history_action
    FOREIGN KEY(action_id)
    REFERENCES booking_actions(action_id)
    ON UPDATE CASCADE
);

-- =====================================================
-- EQUIPMENT BORROWING MODULE
-- =====================================================

CREATE TABLE equipment_bookings (

    booking_id BIGSERIAL PRIMARY KEY,

    booking_code VARCHAR(50)
        NOT NULL UNIQUE,

    user_id BIGINT NOT NULL,

    resource_id BIGINT NOT NULL,

    borrow_date TIMESTAMPTZ NOT NULL,

    expected_return_date TIMESTAMPTZ NOT NULL,

    actual_return_date TIMESTAMPTZ,

    booking_status_id SMALLINT NOT NULL,

    borrow_purpose TEXT,

    CHECK(expected_return_date >= borrow_date),

    CHECK(
        actual_return_date IS NULL
        OR actual_return_date >= borrow_date
    ),

    CONSTRAINT fk_equipment_booking_user
    FOREIGN KEY(user_id)
    REFERENCES users(user_id)
    ON UPDATE CASCADE,

    CONSTRAINT fk_equipment_booking_resource
    FOREIGN KEY(resource_id)
    REFERENCES resources(resource_id)
    ON UPDATE CASCADE,

    CONSTRAINT fk_equipment_booking_status
    FOREIGN KEY(booking_status_id)
    REFERENCES booking_status(booking_status_id)
    ON UPDATE CASCADE
);

CREATE TABLE equipment_booking_history (

    history_id BIGSERIAL PRIMARY KEY,

    booking_id BIGINT NOT NULL,

    action_id SMALLINT NOT NULL,

    action_date TIMESTAMPTZ
        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_equipment_history_booking
    FOREIGN KEY(booking_id)
    REFERENCES equipment_bookings(booking_id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,

    CONSTRAINT fk_equipment_history_action
    FOREIGN KEY(action_id)
    REFERENCES booking_actions(action_id)
    ON UPDATE CASCADE
);

CREATE TABLE fines (

    fine_id BIGSERIAL PRIMARY KEY,

    booking_id BIGINT NOT NULL,

    fine_amount DECIMAL(10,2)
        NOT NULL
        CHECK(fine_amount >= 0),

    fine_reason VARCHAR(255),

    fine_status VARCHAR(20)
        NOT NULL
        DEFAULT 'UNPAID'
        CHECK (fine_status IN ('UNPAID','PAID','WAIVED')),

    CONSTRAINT fk_fine_booking
    FOREIGN KEY(booking_id)
    REFERENCES equipment_bookings(booking_id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);

-- =====================================================
-- MAINTENANCE MODULE
-- =====================================================

CREATE TABLE maintenance_bookings (

    booking_id BIGSERIAL PRIMARY KEY,

    booking_code VARCHAR(50)
        NOT NULL UNIQUE,

    user_id BIGINT NOT NULL,

    resource_id BIGINT NOT NULL,

    booking_time TIMESTAMPTZ
        DEFAULT CURRENT_TIMESTAMP,

    booking_status_id SMALLINT NOT NULL,

    repair_title VARCHAR(255)
        NOT NULL,

    repair_description TEXT,

    reported_date TIMESTAMPTZ
        DEFAULT CURRENT_TIMESTAMP,

    staff_note TEXT,

    CONSTRAINT fk_maintenance_booking_user
    FOREIGN KEY(user_id)
    REFERENCES users(user_id)
    ON UPDATE CASCADE,

    CONSTRAINT fk_maintenance_booking_resource
    FOREIGN KEY(resource_id)
    REFERENCES resources(resource_id)
    ON UPDATE CASCADE,

    CONSTRAINT fk_maintenance_booking_status
    FOREIGN KEY(booking_status_id)
    REFERENCES booking_status(booking_status_id)
    ON UPDATE CASCADE
);

CREATE TABLE maintenance_booking_history (

    history_id BIGSERIAL PRIMARY KEY,

    booking_id BIGINT NOT NULL,

    action_id SMALLINT NOT NULL,

    action_date TIMESTAMPTZ
        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_maintenance_history_booking
    FOREIGN KEY(booking_id)
    REFERENCES maintenance_bookings(booking_id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,

    CONSTRAINT fk_maintenance_history_action
    FOREIGN KEY(action_id)
    REFERENCES booking_actions(action_id)
    ON UPDATE CASCADE
);

CREATE TABLE attachments (

    attachment_id BIGSERIAL PRIMARY KEY,

    booking_id BIGINT NOT NULL,

    file_name VARCHAR(255),

    file_path TEXT NOT NULL,

    upload_date TIMESTAMPTZ
        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_attachment_booking
    FOREIGN KEY(booking_id)
    REFERENCES maintenance_bookings(booking_id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);

-- =====================================================
-- AI CHAT LOGS (ประวัติการถามตอบของระบบ Chat)
-- =====================================================

CREATE TABLE chat_logs (
    chat_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    question TEXT NOT NULL,
    answer TEXT,
    tool_name VARCHAR(100),
    sql_used TEXT,
    result_rows INTEGER CHECK (result_rows IS NULL OR result_rows >= 0),
    chat_status VARCHAR(20) NOT NULL DEFAULT 'SUCCESS'
        CHECK (chat_status IN ('SUCCESS','ERROR','REFUSED')),
    error_message TEXT,
    response_ms INTEGER CHECK (response_ms IS NULL OR response_ms >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_chat_user
    FOREIGN KEY(user_id)
    REFERENCES users(user_id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);

CREATE INDEX idx_chat_logs_user_time
ON chat_logs(user_id, created_at DESC);

-- =====================================================
-- INDEXING STRATEGY
-- =====================================================

CREATE INDEX idx_users_role
ON users(role_id);

CREATE INDEX idx_resources_category
ON resources(type_id);

CREATE INDEX idx_resources_status
ON resources(resource_status_id);

CREATE INDEX idx_room_schedule_resource
ON room_schedules(resource_id);

CREATE INDEX idx_room_schedule_date
ON room_schedules(work_date);

CREATE INDEX idx_room_schedule_conflict
ON room_schedules
(
    resource_id,
    work_date,
    start_time,
    end_time
);

CREATE INDEX idx_printer_schedule_resource
ON printer_schedules(resource_id);

CREATE INDEX idx_printer_schedule_date
ON printer_schedules(work_date);

CREATE INDEX idx_printer_schedule_conflict
ON printer_schedules
(
    resource_id,
    work_date,
    start_time,
    end_time
);

CREATE INDEX idx_room_booking_user
ON room_bookings(user_id);

CREATE INDEX idx_printer_booking_user
ON printer_bookings(user_id);

CREATE INDEX idx_equipment_booking_user
ON equipment_bookings(user_id);

CREATE INDEX idx_maintenance_booking_user
ON maintenance_bookings(user_id);

CREATE INDEX idx_equipment_due_date
ON equipment_bookings
(
    resource_id,
    expected_return_date
);

CREATE INDEX idx_maintenance_reported_date
ON maintenance_bookings
(
    resource_id,
    reported_date
);

-- =====================================================
-- SEED DATA
-- =====================================================

INSERT INTO user_roles(role_name)
VALUES
('USER'),
('STAFF'),
('ADMIN');

INSERT INTO resource_categories(type_name)
VALUES
('ROOM'),
('PRINTER'),
('EQUIPMENT'),
('MAINTENANCE');

INSERT INTO resource_status(resource_status_name)
VALUES
('AVAILABLE'),
('RESERVED'),
('BORROWED'),
('BROKEN'),
('UNDER_MAINTENANCE'),
('OUT_OF_SERVICE');

INSERT INTO schedule_status(schedule_status_name)
VALUES
('AVAILABLE'),
('RESERVED'),
('BLOCKED');

INSERT INTO booking_status(booking_status_name)
VALUES
('PENDING'),
('APPROVED'),
('REJECTED'),
('COMPLETED'),
('RECEIVED'),
('IN_PROGRESS'),
('RETURNED'),
('OVERDUE');

INSERT INTO booking_actions(action_name)
VALUES
('CREATE'),
('APPROVE'),
('REJECT'),
('RECEIVE'),
('START'),
('COMPLETE'),
('RETURN'),
('CANCEL');

-- #####################################################################
-- 2) ข้อมูลจำลอง (TRUNCATE แล้วใส่ใหม่) : seed_data.sql
-- #####################################################################
-- =====================================================================
-- ส่วนที่ 2 : ข้อมูลจำลอง (SEED DATA)
--   - ตารางหลักทุกตารางมีไม่น้อยกว่า 30 แถว (ดูสรุปจำนวนแถวในส่วนที่ 4)
--   - ตารางสนับสนุน fines มี 30 แถว (22 แถวเดิม + 8 แถวจากการคืนช้าที่เพิ่มใน 2.12b) คิดค่าปรับวันละ 20 บาท
--   - ช่วงเวลาของข้อมูล : 7 ก.ย. - 20 พ.ย. 2569 (มีทั้งรายการที่ผ่านมาแล้วและรายการล่วงหน้า)
--   - ระบุค่าคีย์หลักเองเพื่อให้ตารางประวัติอ้างอิงถูกต้อง แล้วปรับ sequence ให้ต่อท้ายในตอนท้าย
-- =====================================================================
BEGIN;
SET LOCAL TIME ZONE 'Asia/Bangkok';  -- เวลาในข้อมูลจำลองเป็นเวลาไทย (ใช้กับ TIMESTAMPTZ)

-- ล้างข้อมูลเดิมทุกตาราง (เรียงตามลำดับ FK ด้วย CASCADE) และเริ่มนับเลขลำดับใหม่
TRUNCATE TABLE attachments, maintenance_booking_history, maintenance_bookings,
               fines, equipment_booking_history, equipment_bookings,
               printer_booking_history, printer_bookings, printer_schedules,
               room_booking_history, room_bookings, room_schedules,
               booking_actions, booking_status, schedule_status,
               resources, resource_status, resource_categories,
               users, user_roles
RESTART IDENTITY CASCADE;

-- 2.1 ตารางอ้างอิง (Lookup tables)
INSERT INTO user_roles (role_id, role_name) VALUES
(1, 'USER'),
(2, 'STAFF'),
(3, 'ADMIN');

INSERT INTO resource_categories (type_id, type_name) VALUES
(1, 'ROOM'),
(2, 'PRINTER'),
(3, 'EQUIPMENT'),
(4, 'MAINTENANCE');

INSERT INTO resource_status (resource_status_id, resource_status_name) VALUES
(1, 'AVAILABLE'),
(2, 'RESERVED'),
(3, 'BORROWED'),
(4, 'BROKEN'),
(5, 'UNDER_MAINTENANCE'),
(6, 'OUT_OF_SERVICE');

INSERT INTO schedule_status (schedule_status_id, schedule_status_name) VALUES
(1, 'AVAILABLE'),
(2, 'RESERVED'),
(3, 'BLOCKED');

INSERT INTO booking_status (booking_status_id, booking_status_name) VALUES
(1, 'PENDING'),
(2, 'APPROVED'),
(3, 'REJECTED'),
(4, 'COMPLETED'),
(5, 'RECEIVED'),
(6, 'IN_PROGRESS'),
(7, 'RETURNED'),
(8, 'OVERDUE');

INSERT INTO booking_actions (action_id, action_name) VALUES
(1, 'CREATE'),
(2, 'APPROVE'),
(3, 'REJECT'),
(4, 'RECEIVE'),
(5, 'START'),
(6, 'COMPLETE'),
(7, 'RETURN'),
(8, 'CANCEL');

-- 2.2 ผู้ใช้งาน users (35 แถว: ADMIN 2, STAFF 4, USER 29)
INSERT INTO users (user_id, user_code, google_id, university_id, full_name, email, phone, role_id, user_status, created_at, last_login) VALUES
(1, 'U0001', NULL, 'STF001', 'อรุณี ศรีสุวรรณ', 'arunee.s@bu-spacehub.test', '081-107-5292', 3, 'ACTIVE', '2026-08-14 10:00:00', '2026-11-02 14:00:00'),
(2, 'U0002', NULL, 'STF002', 'ประเสริฐ วงศ์พิทักษ์', 'prasert.w@bu-spacehub.test', '082-918-1886', 3, 'ACTIVE', '2026-08-18 16:40:00', '2026-10-29 13:05:00'),
(3, 'U0003', NULL, 'STF003', 'กมลชนก ทองดี', 'kamonchanok.t@bu-spacehub.test', '089-196-9940', 2, 'ACTIVE', '2026-08-12 09:40:00', '2026-10-30 14:50:00'),
(4, 'U0004', NULL, 'STF004', 'ธนากร สุขเจริญ', 'thanakorn.s@bu-spacehub.test', '086-432-1947', 2, 'ACTIVE', '2026-08-19 13:40:00', '2026-10-24 18:25:00'),
(5, 'U0005', NULL, 'STF005', 'พิมพ์ชนก แก้วมณี', 'pimchanok.k@bu-spacehub.test', '082-234-4477', 2, 'ACTIVE', '2026-08-09 08:20:00', '2026-10-30 09:50:00'),
(6, 'U0006', NULL, 'STF006', 'วิชัย บุญมา', 'wichai.b@bu-spacehub.test', '082-741-1389', 2, 'ACTIVE', '2026-08-02 08:00:00', '2026-10-21 17:25:00'),
(7, 'U0007', NULL, '66100259', 'สมชาย ใจดี', 'somchai.j@bu-spacehub.test', '089-951-9084', 1, 'ACTIVE', '2026-08-16 12:00:00', '2026-10-28 08:05:00'),
(8, 'U0008', NULL, '66100296', 'สุภาพร รัตนะ', 'supaporn.r@bu-spacehub.test', '082-565-7000', 1, 'SUSPENDED', '2026-08-10 15:40:00', '2026-10-22 20:25:00'),
(9, 'U0009', NULL, '66100333', 'ณัฐวุฒิ พงษ์ศิริ', 'nattawut.p@bu-spacehub.test', '081-254-2822', 1, 'ACTIVE', '2026-08-05 17:00:00', '2026-10-28 20:50:00'),
(10, 'U0010', NULL, '66100370', 'กัญญารัตน์ มีสุข', 'kanyarat.m@bu-spacehub.test', '081-182-9927', 1, 'ACTIVE', '2026-08-20 16:00:00', '2026-10-20 14:25:00'),
(11, 'U0011', NULL, '66100407', 'ภาณุพงศ์ จันทร์เพ็ญ', 'phanupong.j@bu-spacehub.test', '082-878-2088', 1, 'ACTIVE', '2026-08-11 12:10:00', '2026-10-24 12:50:00'),
(12, 'U0012', NULL, '66100444', 'ปวีณา สายสุวรรณ', 'paweena.s@bu-spacehub.test', '086-135-5361', 1, 'ACTIVE', '2026-08-05 12:00:00', '2026-10-26 09:05:00'),
(13, 'U0013', NULL, '66100481', 'อนุชา ทวีสุข', 'anucha.t@bu-spacehub.test', '082-690-5509', 1, 'ACTIVE', '2026-08-15 08:40:00', '2026-10-30 20:50:00'),
(14, 'U0014', NULL, '66100518', 'ชลธิชา เพชรรัตน์', 'chonthicha.p@bu-spacehub.test', '089-766-3953', 1, 'ACTIVE', '2026-08-06 12:10:00', '2026-10-31 20:05:00'),
(15, 'U0015', NULL, '66100555', 'รัฐภูมิ แสงทอง', 'rattaphum.s@bu-spacehub.test', '086-825-4956', 1, 'SUSPENDED', '2026-08-09 14:00:00', '2026-10-30 17:25:00'),
(16, 'U0016', NULL, '66100592', 'นภัสสร อินทรวงศ์', 'napatsorn.i@bu-spacehub.test', '081-532-2143', 1, 'ACTIVE', '2026-08-15 17:00:00', '2026-10-23 09:25:00'),
(17, 'U0017', NULL, '66100629', 'วรากร ศิริพงษ์', 'warakorn.s@bu-spacehub.test', '082-635-7326', 1, 'ACTIVE', '2026-08-09 17:10:00', '2026-10-25 15:05:00'),
(18, 'U0018', NULL, '66100666', 'ศิริพร กลิ่นหอม', 'siriporn.k@bu-spacehub.test', '089-874-9426', 1, 'ACTIVE', '2026-08-15 15:20:00', '2026-10-22 17:50:00'),
(19, 'U0019', NULL, '66100703', 'เจษฎา ปัญญาดี', 'jetsada.p@bu-spacehub.test', '082-436-6630', 1, 'ACTIVE', '2026-08-17 10:00:00', '2026-10-28 11:50:00'),
(20, 'U0020', NULL, '66100740', 'อัญชลี ขจรเกียรติ', 'anchalee.k@bu-spacehub.test', '082-495-9790', 1, 'ACTIVE', '2026-08-15 15:20:00', '2026-10-20 19:50:00'),
(21, 'U0021', NULL, '66100777', 'ธีรภัทร นิลวงศ์', 'teerapat.n@bu-spacehub.test', '081-341-1385', 1, 'ACTIVE', '2026-08-16 17:40:00', '2026-10-24 14:50:00'),
(22, 'U0022', NULL, '66100814', 'มณีรัตน์ สุวรรณชาติ', 'maneerat.s@bu-spacehub.test', '081-322-4258', 1, 'ACTIVE', '2026-08-19 12:20:00', '2026-10-23 11:05:00'),
(23, 'U0023', NULL, '66100851', 'กิตติพงษ์ ยอดสุวรรณ', 'kittipong.y@bu-spacehub.test', '082-342-1516', 1, 'ACTIVE', '2026-08-01 11:00:00', '2026-10-30 17:25:00'),
(24, 'U0024', NULL, '66100888', 'ปานชีวา รุ่งเรือง', 'panchiwa.r@bu-spacehub.test', '089-603-7647', 1, 'ACTIVE', '2026-08-04 10:10:00', '2026-10-22 09:05:00'),
(25, 'U0025', NULL, '66100925', 'สิรวิชญ์ ภู่ทอง', 'sirawit.p@bu-spacehub.test', '081-371-3140', 1, 'ACTIVE', '2026-08-07 13:00:00', '2026-10-21 13:25:00'),
(26, 'U0026', NULL, '66100962', 'ลลิตา เจริญผล', 'lalita.c@bu-spacehub.test', '081-818-5215', 1, 'ACTIVE', '2026-08-13 15:40:00', '2026-10-20 11:50:00'),
(27, 'U0027', NULL, '66100999', 'พีรพัฒน์ ชัยมงคล', 'peeraphat.c@bu-spacehub.test', '089-856-3191', 1, 'ACTIVE', '2026-08-10 13:10:00', '2026-10-21 18:05:00'),
(28, 'U0028', NULL, '66101036', 'วริศรา ทองคำ', 'warisara.t@bu-spacehub.test', '089-764-1000', 1, 'ACTIVE', '2026-08-17 10:40:00', '2026-10-25 08:25:00'),
(29, 'U0029', NULL, '66101073', 'ชัยวัฒน์ สมบูรณ์', 'chaiwat.s@bu-spacehub.test', '081-533-7190', 1, 'ACTIVE', '2026-08-17 12:00:00', '2026-10-25 17:50:00'),
(30, 'U0030', NULL, '66101110', 'กุลธิดา พึ่งบุญ', 'kunthida.p@bu-spacehub.test', '082-634-1684', 1, 'ACTIVE', '2026-08-15 16:40:00', '2026-10-31 12:25:00'),
(31, 'U0031', NULL, '66101147', 'ธนพล เรืองศรี', 'thanaphon.r@bu-spacehub.test', '082-260-6391', 1, 'ACTIVE', '2026-08-02 12:40:00', '2026-10-23 19:50:00'),
(32, 'U0032', NULL, '66101184', 'อรวรรณ มั่นคง', 'orawan.m@bu-spacehub.test', '089-491-1919', 1, 'ACTIVE', '2026-08-07 16:00:00', '2026-10-28 10:05:00'),
(33, 'U0033', NULL, '66101221', 'ศุภกิจ วิริยะ', 'suppakit.w@bu-spacehub.test', '086-277-8866', 1, 'INACTIVE', '2026-08-14 09:40:00', NULL),
(34, 'U0034', NULL, '66101258', 'ณัฐธิดา บัวทอง', 'nutthida.b@bu-spacehub.test', '086-780-4592', 1, 'INACTIVE', '2026-08-12 14:20:00', '2026-10-18 17:25:00'),
(35, 'U0035', NULL, '66101295', 'สรวิศ เพชรสว่าง', 'sorawit.p@bu-spacehub.test', '089-327-8544', 1, 'ACTIVE', '2026-08-10 08:10:00', '2026-10-27 08:05:00');

-- 2.3 ทรัพยากร resources (38 แถว: ห้อง 12, เครื่องพิมพ์ 8, อุปกรณ์ 14, สิ่งอำนวยความสะดวก 4)
INSERT INTO resources (resource_id, resource_code, resource_name, type_id, location, resource_status_id, capacity, quantity, description, created_at) VALUES
(1, 'RM-A101', 'Classroom A101', 1, 'Building A Floor 1', 1, 40, NULL, 'ห้องเรียนมาตรฐาน โปรเจกเตอร์ + ระบบเสียง', '2026-08-01 09:00:00'),
(2, 'RM-A102', 'Classroom A102', 1, 'Building A Floor 1', 1, 40, NULL, 'ห้องเรียนมาตรฐาน', '2026-08-01 09:00:00'),
(3, 'RM-A201', 'Lecture Hall A201', 1, 'Building A Floor 2', 1, 120, NULL, 'ห้องบรรยายขนาดใหญ่ รองรับ 120 ที่นั่ง', '2026-08-01 09:00:00'),
(4, 'RM-B101', 'Meeting Room B101', 1, 'Building B Floor 1', 1, 12, NULL, 'ห้องประชุมกลุ่มเล็ก จอ LED 65 นิ้ว', '2026-08-01 09:00:00'),
(5, 'RM-B102', 'Meeting Room B102', 1, 'Building B Floor 1', 1, 12, NULL, 'ห้องประชุมกลุ่มเล็ก', '2026-08-01 09:00:00'),
(6, 'RM-B201', 'Seminar Room B201', 1, 'Building B Floor 2', 1, 30, NULL, 'ห้องสัมมนา พร้อม Smart Board', '2026-08-01 09:00:00'),
(7, 'RM-B202', 'Study Room B202', 1, 'Building B Floor 2', 1, 8, NULL, 'ห้องติวหนังสือ กระดานไวท์บอร์ด', '2026-08-01 09:00:00'),
(8, 'RM-C101', 'Computer Lab C101', 1, 'Building C Floor 1', 1, 50, NULL, 'ห้องปฏิบัติการคอมพิวเตอร์ 50 เครื่อง', '2026-08-01 09:00:00'),
(9, 'RM-C102', 'Computer Lab C102', 1, 'Building C Floor 1', 5, 50, NULL, 'ห้องปฏิบัติการคอมพิวเตอร์ (กำลังซ่อมระบบไฟ)', '2026-08-01 09:00:00'),
(10, 'RM-C301', 'Studio Room C301', 1, 'Building C Floor 3', 1, 20, NULL, 'ห้องสตูดิโอถ่ายทำ/บันทึกเสียง', '2026-08-01 09:00:00'),
(11, 'RM-D101', 'Library Study Room D101', 1, 'Library Floor 1', 1, 6, NULL, 'ห้องอ่านหนังสือเดี่ยว/กลุ่มเล็ก', '2026-08-01 09:00:00'),
(12, 'RM-D102', 'Library Group Room D102', 1, 'Library Floor 1', 6, 10, NULL, 'ห้องกลุ่มห้องสมุด (ปิดปรับปรุง)', '2026-08-01 09:00:00'),
(13, '3DP001', '3D Printer Prusa MK4 #1', 2, 'Engineering Lab A', 1, 1, NULL, 'FDM Printer - Prusa Research', '2026-08-01 09:05:00'),
(14, '3DP002', '3D Printer Bambu X1E', 2, 'Engineering Lab A', 1, 1, NULL, 'FDM Printer - Bambu Lab (หลายสี)', '2026-08-01 09:05:00'),
(15, '3DP003', '3D Printer Formlabs Form 3', 2, 'Maker Space', 1, 1, NULL, 'SLA Resin Printer - Formlabs', '2026-08-01 09:05:00'),
(16, '3DP004', '3D Printer Prusa MK4 #2', 2, 'Engineering Lab A', 1, 1, NULL, 'FDM Printer - Prusa Research', '2026-08-01 09:05:00'),
(17, '3DP005', '3D Printer Creality K1 Max', 2, 'Maker Space', 1, 1, NULL, 'FDM Printer - ความเร็วสูง', '2026-08-01 09:05:00'),
(18, '3DP006', '3D Printer Ultimaker S5', 2, 'Engineering Lab B', 1, 1, NULL, 'FDM Printer - Dual Extruder', '2026-08-01 09:05:00'),
(19, '3DP007', '3D Printer Bambu P1S', 2, 'Maker Space', 1, 1, NULL, 'FDM Printer - Bambu Lab', '2026-08-01 09:05:00'),
(20, '3DP008', '3D Printer Formlabs Form 3+', 2, 'Engineering Lab B', 4, 1, NULL, 'SLA Resin Printer (รอเปลี่ยนชิ้นส่วน)', '2026-08-01 09:05:00'),
(21, 'LP001', 'Dell Latitude 5430 Laptop', 3, 'Equipment Room', 1, NULL, 10, 'Laptop Core i7 RAM 16GB', '2026-08-01 09:10:00'),
(22, 'LP002', 'MacBook Air M2', 3, 'Equipment Room', 1, NULL, 6, 'Laptop Apple M2 RAM 16GB', '2026-08-01 09:10:00'),
(23, 'CM001', 'Canon EOS R10', 3, 'Media Lab', 1, NULL, 5, 'กล้อง Mirrorless พร้อมเลนส์ kit', '2026-08-01 09:10:00'),
(24, 'CM002', 'Sony A7 III', 3, 'Media Lab', 1, NULL, 3, 'กล้อง Full-frame Mirrorless', '2026-08-01 09:10:00'),
(25, 'AD001', 'Arduino Uno R4', 3, 'IoT Laboratory', 1, NULL, 20, 'บอร์ดไมโครคอนโทรลเลอร์', '2026-08-01 09:10:00'),
(26, 'RP001', 'Raspberry Pi 5 Kit', 3, 'IoT Laboratory', 1, NULL, 15, 'ชุด Raspberry Pi 5 8GB + อุปกรณ์เสริม', '2026-08-01 09:10:00'),
(27, 'PJ001', 'Portable Projector Epson', 3, 'Equipment Room', 1, NULL, 6, 'โปรเจกเตอร์พกพา 3,600 lumens', '2026-08-01 09:10:00'),
(28, 'TB001', 'iPad Pro 11 inch', 3, 'Equipment Room', 1, NULL, 8, 'แท็บเล็ต พร้อม Apple Pencil', '2026-08-01 09:10:00'),
(29, 'VR001', 'Meta Quest 3', 3, 'Media Lab', 1, NULL, 4, 'ชุดแว่น VR', '2026-08-01 09:10:00'),
(30, 'MC001', 'Rode Wireless GO II', 3, 'Media Lab', 1, NULL, 6, 'ไมโครโฟนไร้สาย', '2026-08-01 09:10:00'),
(31, 'TR001', 'Tripod Manfrotto Set', 3, 'Media Lab', 1, NULL, 10, 'ขาตั้งกล้อง', '2026-08-01 09:10:00'),
(32, 'DR001', 'DJI Mini 3 Drone', 3, 'Media Lab', 1, NULL, 2, 'โดรนถ่ายภาพ', '2026-08-01 09:10:00'),
(33, 'OS001', 'Digital Oscilloscope', 3, 'Electronics Lab', 1, NULL, 5, 'ออสซิลโลสโคป 100 MHz', '2026-08-01 09:10:00'),
(34, 'SM001', 'Smart Display 55 inch (Mobile)', 3, 'Equipment Room', 2, NULL, 3, 'จอสัมผัสเคลื่อนที่', '2026-08-01 09:10:00'),
(35, 'AC001', 'Air Conditioner Room A101', 4, 'Building A Floor 1', 1, NULL, NULL, 'เครื่องปรับอากาศห้อง A101', '2026-08-01 09:15:00'),
(36, 'NET001', 'Network Switch Room B201', 4, 'Building B Floor 2', 1, NULL, NULL, 'สวิตช์เครือข่ายห้อง B201', '2026-08-01 09:15:00'),
(37, 'PJ-C301', 'Ceiling Projector Room C301', 4, 'Building C Floor 3', 1, NULL, NULL, 'โปรเจกเตอร์ติดเพดานห้อง C301', '2026-08-01 09:15:00'),
(38, 'AC002', 'Air Conditioner Library D101', 4, 'Library Floor 1', 1, NULL, NULL, 'เครื่องปรับอากาศห้องสมุด', '2026-08-01 09:15:00');

-- 2.4 ตารางเวลาห้อง room_schedules (50 แถว)
INSERT INTO room_schedules (schedule_id, resource_id, work_date, start_time, end_time, max_slots, schedule_status_id, created_at) VALUES
(1, 4, '2026-09-07', '15:00:00', '17:00:00', 1, 2, '2026-09-01 08:00:00'),
(2, 10, '2026-09-07', '18:00:00', '20:00:00', 1, 2, '2026-09-01 08:00:00'),
(3, 6, '2026-09-08', '10:00:00', '12:00:00', 1, 3, '2026-09-01 08:00:00'),
(4, 8, '2026-09-08', '13:00:00', '15:00:00', 1, 2, '2026-09-01 08:00:00'),
(5, 4, '2026-09-09', '13:00:00', '16:00:00', 1, 2, '2026-09-01 08:00:00'),
(6, 5, '2026-09-09', '13:00:00', '16:00:00', 1, 1, '2026-09-01 08:00:00'),
(7, 1, '2026-09-10', '17:00:00', '19:00:00', 1, 2, '2026-09-01 08:00:00'),
(8, 3, '2026-09-10', '15:00:00', '17:00:00', 1, 2, '2026-09-01 08:00:00'),
(9, 1, '2026-09-14', '13:00:00', '16:00:00', 1, 2, '2026-09-01 08:00:00'),
(10, 7, '2026-09-14', '15:00:00', '17:00:00', 1, 2, '2026-09-01 08:00:00'),
(11, 10, '2026-09-16', '09:00:00', '12:00:00', 1, 2, '2026-09-01 08:00:00'),
(12, 5, '2026-09-18', '15:00:00', '17:00:00', 1, 2, '2026-09-01 08:00:00'),
(13, 11, '2026-09-21', '16:00:00', '18:00:00', 1, 1, '2026-09-01 08:00:00'),
(14, 1, '2026-09-22', '09:00:00', '12:00:00', 1, 2, '2026-09-01 08:00:00'),
(15, 1, '2026-09-22', '16:00:00', '18:00:00', 1, 2, '2026-09-01 08:00:00'),
(16, 7, '2026-09-23', '13:00:00', '15:00:00', 1, 2, '2026-09-01 08:00:00'),
(17, 8, '2026-09-23', '09:00:00', '12:00:00', 1, 2, '2026-09-01 08:00:00'),
(18, 6, '2026-09-25', '09:00:00', '11:00:00', 1, 1, '2026-09-01 08:00:00'),
(19, 7, '2026-09-25', '15:00:00', '17:00:00', 1, 2, '2026-09-01 08:00:00'),
(20, 2, '2026-09-30', '09:00:00', '10:00:00', 1, 2, '2026-09-01 08:00:00'),
(21, 2, '2026-09-30', '10:00:00', '12:00:00', 1, 2, '2026-09-01 08:00:00'),
(22, 8, '2026-10-01', '09:00:00', '12:00:00', 1, 2, '2026-09-01 08:00:00'),
(23, 2, '2026-10-06', '09:00:00', '10:00:00', 1, 1, '2026-09-01 08:00:00'),
(24, 5, '2026-10-07', '18:00:00', '20:00:00', 1, 3, '2026-09-01 08:00:00'),
(25, 1, '2026-10-08', '16:00:00', '18:00:00', 1, 2, '2026-09-01 08:00:00'),
(26, 8, '2026-10-12', '17:00:00', '19:00:00', 1, 1, '2026-09-01 08:00:00'),
(27, 11, '2026-10-12', '10:00:00', '12:00:00', 1, 2, '2026-09-01 08:00:00'),
(28, 1, '2026-10-16', '13:00:00', '16:00:00', 1, 3, '2026-09-01 08:00:00'),
(29, 8, '2026-10-19', '18:00:00', '20:00:00', 1, 2, '2026-09-01 08:00:00'),
(30, 5, '2026-10-20', '13:00:00', '15:00:00', 1, 2, '2026-09-01 08:00:00'),
(31, 8, '2026-10-20', '09:00:00', '11:00:00', 1, 2, '2026-09-01 08:00:00'),
(32, 3, '2026-10-21', '13:00:00', '15:00:00', 1, 2, '2026-09-01 08:00:00'),
(33, 3, '2026-10-23', '17:00:00', '19:00:00', 1, 2, '2026-09-01 08:00:00'),
(34, 6, '2026-10-23', '09:00:00', '12:00:00', 1, 2, '2026-09-01 08:00:00'),
(35, 5, '2026-10-26', '16:00:00', '18:00:00', 1, 1, '2026-09-01 08:00:00'),
(36, 2, '2026-10-27', '09:00:00', '11:00:00', 1, 1, '2026-09-01 08:00:00'),
(37, 10, '2026-10-27', '09:00:00', '12:00:00', 1, 2, '2026-09-01 08:00:00'),
(38, 3, '2026-10-28', '17:00:00', '19:00:00', 1, 1, '2026-09-01 08:00:00'),
(39, 5, '2026-10-29', '10:00:00', '12:00:00', 1, 2, '2026-09-01 08:00:00'),
(40, 7, '2026-10-29', '09:00:00', '12:00:00', 1, 1, '2026-09-01 08:00:00'),
(41, 1, '2026-10-30', '09:00:00', '11:00:00', 1, 1, '2026-09-01 08:00:00'),
(42, 10, '2026-11-02', '09:00:00', '12:00:00', 1, 2, '2026-09-01 08:00:00'),
(43, 2, '2026-11-04', '13:00:00', '15:00:00', 1, 2, '2026-09-01 08:00:00'),
(44, 8, '2026-11-06', '10:00:00', '12:00:00', 1, 2, '2026-09-01 08:00:00'),
(45, 3, '2026-11-12', '16:00:00', '18:00:00', 1, 2, '2026-09-01 08:00:00'),
(46, 10, '2026-11-13', '13:00:00', '16:00:00', 1, 2, '2026-09-01 08:00:00'),
(47, 1, '2026-11-17', '09:00:00', '12:00:00', 1, 2, '2026-09-01 08:00:00'),
(48, 4, '2026-11-17', '18:00:00', '20:00:00', 1, 2, '2026-09-01 08:00:00'),
(49, 4, '2026-11-19', '17:00:00', '19:00:00', 1, 2, '2026-09-01 08:00:00'),
(50, 8, '2026-11-19', '16:00:00', '18:00:00', 1, 2, '2026-09-01 08:00:00');

-- 2.5 การจองห้อง room_bookings (41 แถว)
INSERT INTO room_bookings (booking_id, booking_code, user_id, schedule_id, booking_time, booking_status_id, booking_purpose) VALUES
(1, 'RB-2026-0001', 20, 1, '2026-09-06 16:30:00', 4, 'อบรม Git และ GitHub'),
(2, 'RB-2026-0002', 18, 2, '2026-09-03 12:00:00', 4, 'Workshop IoT เบื้องต้น'),
(3, 'RB-2026-0003', 19, 4, '2026-08-30 13:15:00', 4, 'อบรม Git และ GitHub'),
(4, 'RB-2026-0004', 8, 5, '2026-08-31 12:00:00', 4, 'อบรม Git และ GitHub'),
(5, 'RB-2026-0005', 19, 6, '2026-09-01 15:15:00', 3, 'ประชุมคณะกรรมการนักศึกษา'),
(6, 'RB-2026-0006', 20, 7, '2026-09-05 10:00:00', 4, 'กิจกรรมชมรมคอมพิวเตอร์'),
(7, 'RB-2026-0007', 15, 8, '2026-09-01 13:30:00', 4, 'สอบ Midterm ชดเชย'),
(8, 'RB-2026-0008', 11, 9, '2026-09-10 11:15:00', 4, 'Workshop IoT เบื้องต้น'),
(9, 'RB-2026-0009', 12, 10, '2026-09-08 12:30:00', 4, 'ประชุมกลุ่มโปรเจกต์ฐานข้อมูล'),
(10, 'RB-2026-0010', 20, 11, '2026-09-15 17:30:00', 4, 'กิจกรรมชมรมคอมพิวเตอร์'),
(11, 'RB-2026-0011', 12, 12, '2026-09-11 12:00:00', 4, 'Workshop IoT เบื้องต้น'),
(12, 'RB-2026-0012', 3, 13, '2026-09-16 10:30:00', 3, 'กิจกรรมปฐมนิเทศนักศึกษาใหม่'),
(13, 'RB-2026-0013', 12, 14, '2026-09-14 16:15:00', 4, 'ฝึกซ้อมพรีเซนเทชัน'),
(14, 'RB-2026-0014', 12, 15, '2026-09-18 10:45:00', 4, 'สอบ Midterm ชดเชย'),
(15, 'RB-2026-0015', 12, 16, '2026-09-15 09:15:00', 4, 'สัมมนาวิชาการ'),
(16, 'RB-2026-0016', 7, 17, '2026-09-15 14:15:00', 4, 'กิจกรรมชมรมคอมพิวเตอร์'),
(17, 'RB-2026-0017', 20, 19, '2026-09-16 12:00:00', 4, 'สอนเสริมวิชาแคลคูลัส'),
(18, 'RB-2026-0018', 20, 20, '2026-09-24 09:30:00', 4, 'ประชุมทีมพัฒนาเว็บแอปพลิเคชัน'),
(19, 'RB-2026-0019', 12, 21, '2026-09-25 08:45:00', 4, 'Workshop IoT เบื้องต้น'),
(20, 'RB-2026-0020', 28, 22, '2026-09-27 17:00:00', 4, 'สัมมนาวิชาการ'),
(21, 'RB-2026-0021', 26, 23, '2026-10-02 15:45:00', 3, 'สอนเสริมวิชาแคลคูลัส'),
(22, 'RB-2026-0022', 15, 25, '2026-10-01 17:00:00', 4, 'ประชุมทีมพัฒนาเว็บแอปพลิเคชัน'),
(23, 'RB-2026-0023', 15, 27, '2026-10-03 17:30:00', 4, 'ซ้อมนำเสนอโครงงาน'),
(24, 'RB-2026-0024', 22, 29, '2026-10-11 11:30:00', 4, 'กิจกรรมปฐมนิเทศนักศึกษาใหม่'),
(25, 'RB-2026-0025', 8, 30, '2026-10-14 09:15:00', 4, 'สอนเสริมวิชาแคลคูลัส'),
(26, 'RB-2026-0026', 29, 31, '2026-10-19 17:30:00', 4, 'ประชุมกลุ่มโปรเจกต์ฐานข้อมูล'),
(27, 'RB-2026-0027', 15, 32, '2026-10-13 16:45:00', 4, 'ประชุมกลุ่มโปรเจกต์ฐานข้อมูล'),
(28, 'RB-2026-0028', 16, 33, '2026-10-15 17:00:00', 4, 'สัมมนาวิชาการ'),
(29, 'RB-2026-0029', 33, 34, '2026-10-18 11:45:00', 4, 'ซ้อมนำเสนอโครงงาน'),
(30, 'RB-2026-0030', 34, 37, '2026-10-23 11:30:00', 4, 'ติวสอบกลางภาควิชา AIE313'),
(31, 'RB-2026-0031', 32, 39, '2026-10-21 12:00:00', 4, 'ประชุมคณะกรรมการนักศึกษา'),
(32, 'RB-2026-0032', 14, 40, '2026-10-26 17:00:00', 3, 'ซ้อมนำเสนอโครงงาน'),
(33, 'RB-2026-0033', 22, 42, '2026-10-24 08:00:00', 2, 'ติวสอบกลางภาควิชา AIE313'),
(34, 'RB-2026-0034', 34, 43, '2026-10-28 11:45:00', 2, 'สอบ Midterm ชดเชย'),
(35, 'RB-2026-0035', 21, 44, '2026-11-02 11:15:00', 2, 'ติวสอบกลางภาควิชา AIE313'),
(36, 'RB-2026-0036', 18, 45, '2026-11-02 05:00:00', 2, 'ติวสอบปลายภาค'),
(37, 'RB-2026-0037', 20, 46, '2026-11-01 21:00:00', 1, 'ติวสอบกลางภาควิชา AIE313'),
(38, 'RB-2026-0038', 17, 47, '2026-11-01 03:00:00', 2, 'Workshop IoT เบื้องต้น'),
(39, 'RB-2026-0039', 12, 48, '2026-11-02 08:00:00', 2, 'ถ่ายทำสื่อการเรียนการสอน'),
(40, 'RB-2026-0040', 32, 49, '2026-11-01 00:00:00', 1, 'ติวสอบปลายภาค'),
(41, 'RB-2026-0041', 33, 50, '2026-11-02 06:00:00', 1, 'ติวสอบปลายภาค');

-- 2.6 ประวัติการจองห้อง room_booking_history (107 แถว)
INSERT INTO room_booking_history (booking_id, action_id, action_date) VALUES
(1, 1, '2026-09-06 16:30:00'),
(1, 2, '2026-09-07 19:13:00'),
(1, 6, '2026-09-07 17:00:00'),
(2, 1, '2026-09-03 12:00:00'),
(2, 2, '2026-09-04 11:33:00'),
(2, 6, '2026-09-07 20:00:00'),
(3, 1, '2026-08-30 13:15:00'),
(3, 2, '2026-08-31 03:45:00'),
(3, 6, '2026-09-08 15:00:00'),
(4, 1, '2026-08-31 12:00:00'),
(4, 2, '2026-09-01 09:51:00'),
(4, 6, '2026-09-09 16:00:00'),
(5, 1, '2026-09-01 15:15:00'),
(5, 8, '2026-09-02 01:55:00'),
(6, 1, '2026-09-05 10:00:00'),
(6, 2, '2026-09-05 21:25:00'),
(6, 6, '2026-09-10 19:00:00'),
(7, 1, '2026-09-01 13:30:00'),
(7, 2, '2026-09-02 00:09:00'),
(7, 6, '2026-09-10 17:00:00'),
(8, 1, '2026-09-10 11:15:00'),
(8, 2, '2026-09-10 16:07:00'),
(8, 6, '2026-09-14 16:00:00'),
(9, 1, '2026-09-08 12:30:00'),
(9, 2, '2026-09-09 01:06:00'),
(9, 6, '2026-09-14 17:00:00'),
(10, 1, '2026-09-15 17:30:00'),
(10, 2, '2026-09-16 04:50:00'),
(10, 6, '2026-09-16 12:00:00'),
(11, 1, '2026-09-11 12:00:00'),
(11, 2, '2026-09-12 13:36:00'),
(11, 6, '2026-09-18 17:00:00'),
(12, 1, '2026-09-16 10:30:00'),
(12, 3, '2026-09-16 22:12:00'),
(13, 1, '2026-09-14 16:15:00'),
(13, 2, '2026-09-15 01:00:00'),
(13, 6, '2026-09-22 12:00:00'),
(14, 1, '2026-09-18 10:45:00'),
(14, 2, '2026-09-18 21:28:00'),
(14, 6, '2026-09-22 18:00:00'),
(15, 1, '2026-09-15 09:15:00'),
(15, 2, '2026-09-16 07:33:00'),
(15, 6, '2026-09-23 15:00:00'),
(16, 1, '2026-09-15 14:15:00'),
(16, 2, '2026-09-16 20:54:00'),
(16, 6, '2026-09-23 12:00:00'),
(17, 1, '2026-09-16 12:00:00'),
(17, 2, '2026-09-17 15:37:00'),
(17, 6, '2026-09-25 17:00:00'),
(18, 1, '2026-09-24 09:30:00'),
(18, 2, '2026-09-25 01:05:00'),
(18, 6, '2026-09-30 10:00:00'),
(19, 1, '2026-09-25 08:45:00'),
(19, 2, '2026-09-25 23:36:00'),
(19, 6, '2026-09-30 12:00:00'),
(20, 1, '2026-09-27 17:00:00'),
(20, 2, '2026-09-28 12:46:00'),
(20, 6, '2026-10-01 12:00:00'),
(21, 1, '2026-10-02 15:45:00'),
(21, 8, '2026-10-03 00:16:00'),
(22, 1, '2026-10-01 17:00:00'),
(22, 2, '2026-10-02 02:45:00'),
(22, 6, '2026-10-08 18:00:00'),
(23, 1, '2026-10-03 17:30:00'),
(23, 2, '2026-10-04 04:49:00'),
(23, 6, '2026-10-12 12:00:00'),
(24, 1, '2026-10-11 11:30:00'),
(24, 2, '2026-10-12 06:54:00'),
(24, 6, '2026-10-19 20:00:00'),
(25, 1, '2026-10-14 09:15:00'),
(25, 2, '2026-10-14 16:41:00'),
(25, 6, '2026-10-20 15:00:00'),
(26, 1, '2026-10-19 17:30:00'),
(26, 2, '2026-10-20 01:02:00'),
(26, 6, '2026-10-20 11:00:00'),
(27, 1, '2026-10-13 16:45:00'),
(27, 2, '2026-10-13 21:18:00'),
(27, 6, '2026-10-21 15:00:00'),
(28, 1, '2026-10-15 17:00:00'),
(28, 2, '2026-10-16 03:55:00'),
(28, 6, '2026-10-23 19:00:00'),
(29, 1, '2026-10-18 11:45:00'),
(29, 2, '2026-10-19 01:58:00'),
(29, 6, '2026-10-23 12:00:00'),
(30, 1, '2026-10-23 11:30:00'),
(30, 2, '2026-10-23 19:39:00'),
(30, 6, '2026-10-27 12:00:00'),
(31, 1, '2026-10-21 12:00:00'),
(31, 2, '2026-10-21 17:01:00'),
(31, 6, '2026-10-29 12:00:00'),
(32, 1, '2026-10-26 17:00:00'),
(32, 8, '2026-10-27 17:55:00'),
(33, 1, '2026-10-24 08:00:00'),
(33, 2, '2026-10-24 13:04:00'),
(34, 1, '2026-10-28 11:45:00'),
(34, 2, '2026-10-28 20:45:00'),
(35, 1, '2026-11-02 11:15:00'),
(35, 2, '2026-11-02 14:30:00'),
(36, 1, '2026-11-02 05:00:00'),
(36, 2, '2026-11-02 14:30:00'),
(37, 1, '2026-11-01 21:00:00'),
(38, 1, '2026-11-01 03:00:00'),
(38, 2, '2026-11-02 07:36:00'),
(39, 1, '2026-11-02 08:00:00'),
(39, 2, '2026-11-02 14:30:00'),
(40, 1, '2026-11-01 00:00:00'),
(41, 1, '2026-11-02 06:00:00');

-- 2.7 ตารางเวลาเครื่องพิมพ์ printer_schedules (38 แถว)
INSERT INTO printer_schedules (schedule_id, resource_id, work_date, start_time, end_time, max_slots, schedule_status_id, created_at) VALUES
(1, 18, '2026-09-07', '09:00:00', '13:00:00', 1, 1, '2026-09-01 08:30:00'),
(2, 16, '2026-09-14', '08:00:00', '12:00:00', 1, 2, '2026-09-01 08:30:00'),
(3, 15, '2026-09-16', '13:00:00', '15:00:00', 1, 3, '2026-09-01 08:30:00'),
(4, 19, '2026-09-18', '10:00:00', '12:00:00', 1, 2, '2026-09-01 08:30:00'),
(5, 15, '2026-09-21', '08:00:00', '12:00:00', 1, 1, '2026-09-01 08:30:00'),
(6, 17, '2026-09-22', '09:00:00', '13:00:00', 1, 2, '2026-09-01 08:30:00'),
(7, 18, '2026-09-22', '13:00:00', '18:00:00', 1, 2, '2026-09-01 08:30:00'),
(8, 16, '2026-09-24', '08:00:00', '12:00:00', 1, 3, '2026-09-01 08:30:00'),
(9, 19, '2026-09-24', '08:00:00', '12:00:00', 1, 2, '2026-09-01 08:30:00'),
(10, 15, '2026-09-30', '09:00:00', '13:00:00', 1, 2, '2026-09-01 08:30:00'),
(11, 18, '2026-10-01', '13:00:00', '18:00:00', 1, 2, '2026-09-01 08:30:00'),
(12, 13, '2026-10-02', '13:00:00', '18:00:00', 1, 2, '2026-09-01 08:30:00'),
(13, 15, '2026-10-02', '08:00:00', '12:00:00', 1, 2, '2026-09-01 08:30:00'),
(14, 16, '2026-10-02', '13:00:00', '15:00:00', 1, 2, '2026-09-01 08:30:00'),
(15, 16, '2026-10-05', '13:00:00', '15:00:00', 1, 2, '2026-09-01 08:30:00'),
(16, 17, '2026-10-13', '09:00:00', '12:00:00', 1, 2, '2026-09-01 08:30:00'),
(17, 13, '2026-10-14', '10:00:00', '12:00:00', 1, 2, '2026-09-01 08:30:00'),
(18, 14, '2026-10-15', '10:00:00', '12:00:00', 1, 2, '2026-09-01 08:30:00'),
(19, 16, '2026-10-20', '13:00:00', '17:00:00', 1, 2, '2026-09-01 08:30:00'),
(20, 17, '2026-10-20', '10:00:00', '12:00:00', 1, 2, '2026-09-01 08:30:00'),
(21, 19, '2026-10-20', '10:00:00', '12:00:00', 1, 2, '2026-09-01 08:30:00'),
(22, 19, '2026-10-21', '08:00:00', '12:00:00', 1, 1, '2026-09-01 08:30:00'),
(23, 19, '2026-10-22', '15:00:00', '19:00:00', 1, 2, '2026-09-01 08:30:00'),
(24, 16, '2026-10-27', '10:00:00', '12:00:00', 1, 2, '2026-09-01 08:30:00'),
(25, 16, '2026-11-02', '09:00:00', '13:00:00', 1, 2, '2026-09-01 08:30:00'),
(26, 19, '2026-11-02', '13:00:00', '17:00:00', 1, 2, '2026-09-01 08:30:00'),
(27, 17, '2026-11-06', '13:00:00', '17:00:00', 1, 3, '2026-09-01 08:30:00'),
(28, 15, '2026-11-09', '13:00:00', '17:00:00', 1, 2, '2026-09-01 08:30:00'),
(29, 19, '2026-11-10', '13:00:00', '15:00:00', 1, 2, '2026-09-01 08:30:00'),
(30, 16, '2026-11-11', '13:00:00', '17:00:00', 1, 2, '2026-09-01 08:30:00'),
(31, 14, '2026-11-13', '15:00:00', '19:00:00', 1, 2, '2026-09-01 08:30:00'),
(32, 16, '2026-11-13', '09:00:00', '13:00:00', 1, 2, '2026-09-01 08:30:00'),
(33, 17, '2026-11-16', '09:00:00', '12:00:00', 1, 2, '2026-09-01 08:30:00'),
(34, 19, '2026-11-16', '09:00:00', '12:00:00', 1, 2, '2026-09-01 08:30:00'),
(35, 14, '2026-11-17', '13:00:00', '15:00:00', 1, 2, '2026-09-01 08:30:00'),
(36, 16, '2026-11-17', '13:00:00', '18:00:00', 1, 2, '2026-09-01 08:30:00'),
(37, 18, '2026-11-18', '15:00:00', '19:00:00', 1, 2, '2026-09-01 08:30:00'),
(38, 17, '2026-11-20', '13:00:00', '17:00:00', 1, 2, '2026-09-01 08:30:00');

-- 2.8 การจองเครื่องพิมพ์ 3 มิติ printer_bookings (34 แถว)
INSERT INTO printer_bookings (booking_id, booking_code, user_id, schedule_id, booking_time, booking_status_id, print_purpose) VALUES
(1, 'PB-2026-0001', 16, 1, '2026-09-06 12:45:00', 3, 'พิมพ์ชิ้นส่วนหุ่นยนต์โปรเจกต์จบ'),
(2, 'PB-2026-0002', 24, 2, '2026-09-10 16:45:00', 4, 'เฟืองและตัวยึดสำหรับงานวิจัย'),
(3, 'PB-2026-0003', 7, 4, '2026-09-16 11:45:00', 5, 'ต้นแบบเคสอุปกรณ์ IoT'),
(4, 'PB-2026-0004', 31, 5, '2026-09-15 17:30:00', 3, 'โมเดลของที่ระลึกคณะ'),
(5, 'PB-2026-0005', 7, 6, '2026-09-14 12:00:00', 4, 'โมเดลสถาปัตยกรรมวิชาออกแบบ'),
(6, 'PB-2026-0006', 15, 7, '2026-09-16 17:45:00', 5, 'พิมพ์ชิ้นส่วนหุ่นยนต์โปรเจกต์จบ'),
(7, 'PB-2026-0007', 21, 9, '2026-09-20 15:15:00', 5, 'โมเดลสถาปัตยกรรมวิชาออกแบบ'),
(8, 'PB-2026-0008', 18, 10, '2026-09-25 13:15:00', 4, 'โมเดลของที่ระลึกคณะ'),
(9, 'PB-2026-0009', 34, 11, '2026-09-30 13:15:00', 4, 'ต้นแบบขาตั้งโทรศัพท์'),
(10, 'PB-2026-0010', 23, 12, '2026-09-26 16:00:00', 5, 'พิมพ์เคสบอร์ด Arduino'),
(11, 'PB-2026-0011', 7, 13, '2026-09-28 12:30:00', 4, 'ชิ้นส่วนโดรนสำหรับโครงงาน'),
(12, 'PB-2026-0012', 32, 14, '2026-09-25 10:30:00', 4, 'ต้นแบบเคสอุปกรณ์ IoT'),
(13, 'PB-2026-0013', 19, 15, '2026-10-02 15:30:00', 5, 'ต้นแบบฟิกเกอร์งานนิทรรศการ'),
(14, 'PB-2026-0014', 20, 16, '2026-10-12 09:15:00', 5, 'ต้นแบบฟิกเกอร์งานนิทรรศการ'),
(15, 'PB-2026-0015', 22, 17, '2026-10-13 08:45:00', 5, 'โมเดลของที่ระลึกคณะ'),
(16, 'PB-2026-0016', 12, 18, '2026-10-13 11:15:00', 5, 'พิมพ์ที่ยึดกล้อง/ขาตั้ง'),
(17, 'PB-2026-0017', 8, 19, '2026-10-18 14:15:00', 4, 'โมเดลฟันจำลองวิชาทันตกรรม (Resin)'),
(18, 'PB-2026-0018', 20, 20, '2026-10-13 09:00:00', 5, 'โมเดลฟันจำลองวิชาทันตกรรม (Resin)'),
(19, 'PB-2026-0019', 18, 21, '2026-10-16 17:45:00', 4, 'เฟืองและตัวยึดสำหรับงานวิจัย'),
(20, 'PB-2026-0020', 16, 23, '2026-10-21 10:30:00', 5, 'ต้นแบบเคสอุปกรณ์ IoT'),
(21, 'PB-2026-0021', 33, 24, '2026-10-24 12:45:00', 4, 'พิมพ์เคสบอร์ด Arduino'),
(22, 'PB-2026-0022', 16, 25, '2026-10-31 17:15:00', 6, 'โมเดลฟันจำลองวิชาทันตกรรม (Resin)'),
(23, 'PB-2026-0023', 8, 26, '2026-10-31 11:45:00', 6, 'โมเดลของที่ระลึกคณะ'),
(24, 'PB-2026-0024', 24, 28, '2026-11-01 09:15:00', 2, 'ชิ้นงานวิชา Product Design'),
(25, 'PB-2026-0025', 35, 29, '2026-11-01 12:00:00', 1, 'โมเดลฟันจำลองวิชาทันตกรรม (Resin)'),
(26, 'PB-2026-0026', 11, 30, '2026-11-01 03:00:00', 2, 'ต้นแบบเคสอุปกรณ์ IoT'),
(27, 'PB-2026-0027', 13, 31, '2026-11-01 02:00:00', 2, 'พิมพ์เคสบอร์ด Arduino'),
(28, 'PB-2026-0028', 17, 32, '2026-11-01 14:00:00', 1, 'ชิ้นงานวิชา Product Design'),
(29, 'PB-2026-0029', 31, 33, '2026-11-02 03:00:00', 2, 'โมเดลของที่ระลึกคณะ'),
(30, 'PB-2026-0030', 8, 34, '2026-11-01 21:00:00', 2, 'โมเดลสถาปัตยกรรมวิชาออกแบบ'),
(31, 'PB-2026-0031', 15, 35, '2026-11-01 20:00:00', 2, 'พิมพ์เคสบอร์ด Arduino'),
(32, 'PB-2026-0032', 34, 36, '2026-10-31 23:00:00', 2, 'โมเดลของที่ระลึกคณะ'),
(33, 'PB-2026-0033', 19, 37, '2026-10-31 23:00:00', 1, 'เฟืองและตัวยึดสำหรับงานวิจัย'),
(34, 'PB-2026-0034', 9, 38, '2026-11-01 04:00:00', 1, 'พิมพ์เคสบอร์ด Arduino');

-- 2.9 ประวัติการจองเครื่องพิมพ์ printer_booking_history (114 แถว)
INSERT INTO printer_booking_history (booking_id, action_id, action_date) VALUES
(1, 1, '2026-09-06 12:45:00'),
(1, 8, '2026-09-07 01:34:00'),
(2, 1, '2026-09-10 16:45:00'),
(2, 2, '2026-09-11 06:01:00'),
(2, 5, '2026-09-14 08:04:00'),
(2, 6, '2026-09-14 12:00:00'),
(3, 1, '2026-09-16 11:45:00'),
(3, 2, '2026-09-17 11:42:00'),
(3, 5, '2026-09-18 10:17:00'),
(3, 6, '2026-09-18 12:00:00'),
(3, 4, '2026-09-18 16:00:00'),
(4, 1, '2026-09-15 17:30:00'),
(4, 3, '2026-09-16 21:58:00'),
(5, 1, '2026-09-14 12:00:00'),
(5, 2, '2026-09-15 13:05:00'),
(5, 5, '2026-09-22 09:07:00'),
(5, 6, '2026-09-22 13:00:00'),
(6, 1, '2026-09-16 17:45:00'),
(6, 2, '2026-09-16 22:40:00'),
(6, 5, '2026-09-22 13:19:00'),
(6, 6, '2026-09-22 18:00:00'),
(6, 4, '2026-09-22 19:00:00'),
(7, 1, '2026-09-20 15:15:00'),
(7, 2, '2026-09-21 00:26:00'),
(7, 5, '2026-09-24 08:11:00'),
(7, 6, '2026-09-24 12:00:00'),
(7, 4, '2026-09-25 02:00:00'),
(8, 1, '2026-09-25 13:15:00'),
(8, 2, '2026-09-26 05:21:00'),
(8, 5, '2026-09-30 09:14:00'),
(8, 6, '2026-09-30 13:00:00'),
(9, 1, '2026-09-30 13:15:00'),
(9, 2, '2026-10-01 15:13:00'),
(9, 5, '2026-10-01 13:19:00'),
(9, 6, '2026-10-01 18:00:00'),
(10, 1, '2026-09-26 16:00:00'),
(10, 2, '2026-09-27 12:19:00'),
(10, 5, '2026-10-02 13:12:00'),
(10, 6, '2026-10-02 18:00:00'),
(10, 4, '2026-10-03 19:00:00'),
(11, 1, '2026-09-28 12:30:00'),
(11, 2, '2026-09-29 11:16:00'),
(11, 5, '2026-10-02 08:13:00'),
(11, 6, '2026-10-02 12:00:00'),
(12, 1, '2026-09-25 10:30:00'),
(12, 2, '2026-09-26 13:46:00'),
(12, 5, '2026-10-02 13:17:00'),
(12, 6, '2026-10-02 15:00:00'),
(13, 1, '2026-10-02 15:30:00'),
(13, 2, '2026-10-03 17:40:00'),
(13, 5, '2026-10-05 13:13:00'),
(13, 6, '2026-10-05 15:00:00'),
(13, 4, '2026-10-06 13:00:00'),
(14, 1, '2026-10-12 09:15:00'),
(14, 2, '2026-10-13 00:25:00'),
(14, 5, '2026-10-13 09:04:00'),
(14, 6, '2026-10-13 12:00:00'),
(14, 4, '2026-10-13 21:00:00'),
(15, 1, '2026-10-13 08:45:00'),
(15, 2, '2026-10-14 01:45:00'),
(15, 5, '2026-10-14 10:08:00'),
(15, 6, '2026-10-14 12:00:00'),
(15, 4, '2026-10-14 22:00:00'),
(16, 1, '2026-10-13 11:15:00'),
(16, 2, '2026-10-13 20:33:00'),
(16, 5, '2026-10-15 10:19:00'),
(16, 6, '2026-10-15 12:00:00'),
(16, 4, '2026-10-16 00:00:00'),
(17, 1, '2026-10-18 14:15:00'),
(17, 2, '2026-10-19 14:25:00'),
(17, 5, '2026-10-20 13:15:00'),
(17, 6, '2026-10-20 17:00:00'),
(18, 1, '2026-10-13 09:00:00'),
(18, 2, '2026-10-13 20:31:00'),
(18, 5, '2026-10-20 10:06:00'),
(18, 6, '2026-10-20 12:00:00'),
(18, 4, '2026-10-20 23:00:00'),
(19, 1, '2026-10-16 17:45:00'),
(19, 2, '2026-10-17 19:46:00'),
(19, 5, '2026-10-20 10:16:00'),
(19, 6, '2026-10-20 12:00:00'),
(20, 1, '2026-10-21 10:30:00'),
(20, 2, '2026-10-22 10:54:00'),
(20, 5, '2026-10-22 15:08:00'),
(20, 6, '2026-10-22 19:00:00'),
(20, 4, '2026-10-23 10:00:00'),
(21, 1, '2026-10-24 12:45:00'),
(21, 2, '2026-10-25 16:31:00'),
(21, 5, '2026-10-27 10:03:00'),
(21, 6, '2026-10-27 12:00:00'),
(22, 1, '2026-10-31 17:15:00'),
(22, 2, '2026-11-01 12:51:00'),
(22, 5, '2026-11-02 09:02:00'),
(23, 1, '2026-10-31 11:45:00'),
(23, 2, '2026-11-01 14:12:00'),
(23, 5, '2026-11-02 13:03:00'),
(24, 1, '2026-11-01 09:15:00'),
(24, 2, '2026-11-02 12:10:00'),
(25, 1, '2026-11-01 12:00:00'),
(26, 1, '2026-11-01 03:00:00'),
(26, 2, '2026-11-01 09:41:00'),
(27, 1, '2026-11-01 02:00:00'),
(27, 2, '2026-11-01 20:41:00'),
(28, 1, '2026-11-01 14:00:00'),
(29, 1, '2026-11-02 03:00:00'),
(29, 2, '2026-11-02 14:30:00'),
(30, 1, '2026-11-01 21:00:00'),
(30, 2, '2026-11-02 12:39:00'),
(31, 1, '2026-11-01 20:00:00'),
(31, 2, '2026-11-02 14:30:00'),
(32, 1, '2026-10-31 23:00:00'),
(32, 2, '2026-11-01 13:31:00'),
(33, 1, '2026-10-31 23:00:00'),
(34, 1, '2026-11-01 04:00:00');

-- 2.10 การยืมอุปกรณ์ equipment_bookings (45 แถว)
INSERT INTO equipment_bookings (booking_id, booking_code, user_id, resource_id, borrow_date, expected_return_date, actual_return_date, booking_status_id, borrow_purpose) VALUES
(1, 'EB-2026-0001', 13, 21, '2026-09-03 14:45:00', '2026-09-06 16:00:00', '2026-09-14 19:00:00', 7, 'บันทึกเสียงพอดแคสต์'),
(2, 'EB-2026-0002', 20, 21, '2026-09-05 11:15:00', '2026-09-12 16:00:00', '2026-09-21 17:00:00', 7, 'นำเสนองานนอกสถานที่'),
(3, 'EB-2026-0003', 8, 28, '2026-09-05 13:45:00', '2026-09-19 16:00:00', '2026-09-24 17:00:00', 7, 'ทดลองในรายวิชาอิเล็กทรอนิกส์'),
(4, 'EB-2026-0004', 25, 27, '2026-09-06 10:45:00', '2026-09-09 16:00:00', '2026-09-12 17:00:00', 7, 'สาธิตเทคโนโลยี VR ในงานเปิดบ้าน'),
(5, 'EB-2026-0005', 15, 26, '2026-09-06 12:30:00', '2026-09-11 16:00:00', '2026-09-14 21:00:00', 7, 'ใช้ประกอบการเรียนการสอน'),
(6, 'EB-2026-0006', 12, 28, '2026-09-06 15:45:00', '2026-09-11 16:00:00', '2026-09-11 13:00:00', 7, 'ถ่ายภาพงานรับปริญญา'),
(7, 'EB-2026-0007', 8, 27, '2026-09-08 12:30:00', '2026-09-11 16:00:00', '2026-09-18 21:00:00', 7, 'ทดลองในรายวิชาอิเล็กทรอนิกส์'),
(8, 'EB-2026-0008', 21, 28, '2026-09-09 10:30:00', '2026-09-16 16:00:00', '2026-09-25 21:00:00', 7, 'บันทึกเสียงพอดแคสต์'),
(9, 'EB-2026-0009', 19, 30, '2026-09-10 10:45:00', '2026-09-17 16:00:00', '2026-09-16 07:00:00', 7, 'นำเสนองานนอกสถานที่'),
(10, 'EB-2026-0010', 8, 24, '2026-09-14 09:15:00', '2026-09-21 16:00:00', '2026-09-20 22:00:00', 7, 'บันทึกเสียงพอดแคสต์'),
(11, 'EB-2026-0011', 10, 23, '2026-09-21 09:45:00', '2026-09-28 16:00:00', '2026-09-29 19:00:00', 7, 'ทดลองในรายวิชาอิเล็กทรอนิกส์'),
(12, 'EB-2026-0012', 15, 30, '2026-09-21 12:00:00', '2026-10-05 16:00:00', '2026-10-05 10:00:00', 7, 'ใช้พัฒนาแอปพลิเคชัน'),
(13, 'EB-2026-0013', 32, 30, '2026-09-21 14:30:00', '2026-09-26 16:00:00', NULL, 3, 'นำเสนองานนอกสถานที่'),
(14, 'EB-2026-0014', 13, 25, '2026-09-23 09:30:00', '2026-09-28 16:00:00', '2026-09-27 15:00:00', 7, 'ใช้พัฒนาแอปพลิเคชัน'),
(15, 'EB-2026-0015', 20, 27, '2026-09-23 14:00:00', '2026-09-28 16:00:00', '2026-09-27 23:00:00', 7, 'ใช้พัฒนาแอปพลิเคชัน'),
(16, 'EB-2026-0016', 12, 29, '2026-09-24 10:00:00', '2026-10-01 16:00:00', NULL, 3, 'สาธิตเทคโนโลยี VR ในงานเปิดบ้าน'),
(17, 'EB-2026-0017', 31, 23, '2026-10-04 13:15:00', '2026-10-11 16:00:00', '2026-10-14 16:00:00', 7, 'บันทึกเสียงพอดแคสต์'),
(18, 'EB-2026-0018', 13, 30, '2026-10-06 13:30:00', '2026-10-11 16:00:00', '2026-10-11 00:00:00', 7, 'ถ่ายภาพงานรับปริญญา'),
(19, 'EB-2026-0019', 24, 27, '2026-10-06 15:00:00', '2026-10-13 16:00:00', '2026-10-16 21:00:00', 7, 'ทดลองในรายวิชาอิเล็กทรอนิกส์'),
(20, 'EB-2026-0020', 20, 22, '2026-10-08 11:30:00', '2026-10-22 16:00:00', '2026-10-28 19:00:00', 7, 'ใช้ประกอบการเรียนการสอน'),
(21, 'EB-2026-0021', 27, 23, '2026-10-09 12:45:00', '2026-10-16 16:00:00', '2026-10-15 12:00:00', 7, 'สาธิตเทคโนโลยี VR ในงานเปิดบ้าน'),
(22, 'EB-2026-0022', 23, 25, '2026-10-10 10:30:00', '2026-10-24 16:00:00', '2026-10-27 16:00:00', 7, 'บันทึกเสียงพอดแคสต์'),
(23, 'EB-2026-0023', 20, 24, '2026-10-10 15:15:00', '2026-10-24 16:00:00', '2026-10-23 07:00:00', 7, 'ถ่ายทำสารคดีวิชา Media'),
(24, 'EB-2026-0024', 23, 25, '2026-10-12 13:00:00', '2026-10-17 16:00:00', NULL, 8, 'ทดลองในรายวิชาอิเล็กทรอนิกส์'),
(25, 'EB-2026-0025', 15, 23, '2026-10-12 15:15:00', '2026-10-19 16:00:00', '2026-10-27 21:00:00', 7, 'ใช้ทำโปรเจกต์วิชา IoT'),
(26, 'EB-2026-0026', 14, 30, '2026-10-12 15:30:00', '2026-10-26 16:00:00', '2026-10-25 01:00:00', 7, 'ใช้ทำโปรเจกต์วิชา IoT'),
(27, 'EB-2026-0027', 12, 25, '2026-10-14 12:00:00', '2026-10-19 16:00:00', NULL, 8, 'ใช้พัฒนาแอปพลิเคชัน'),
(28, 'EB-2026-0028', 19, 28, '2026-10-15 15:15:00', '2026-10-18 16:00:00', NULL, 3, 'ใช้ประกอบการเรียนการสอน'),
(29, 'EB-2026-0029', 23, 21, '2026-10-15 15:15:00', '2026-10-29 16:00:00', '2026-10-29 10:00:00', 7, 'ใช้ทำโปรเจกต์วิชา IoT'),
(30, 'EB-2026-0030', 12, 26, '2026-10-16 13:45:00', '2026-10-21 16:00:00', '2026-10-21 05:00:00', 7, 'นำเสนองานนอกสถานที่'),
(31, 'EB-2026-0031', 8, 28, '2026-10-16 14:00:00', '2026-10-21 16:00:00', NULL, 8, 'ใช้พัฒนาแอปพลิเคชัน'),
(32, 'EB-2026-0032', 30, 25, '2026-10-16 15:00:00', '2026-10-19 16:00:00', NULL, 8, 'นำเสนองานนอกสถานที่'),
(33, 'EB-2026-0033', 23, 26, '2026-10-18 14:00:00', '2026-10-25 16:00:00', NULL, 8, 'ใช้ในกิจกรรมชมรม'),
(34, 'EB-2026-0034', 15, 26, '2026-10-20 14:00:00', '2026-10-23 16:00:00', NULL, 8, 'ถ่ายภาพงานรับปริญญา'),
(35, 'EB-2026-0035', 15, 27, '2026-10-28 12:45:00', '2026-11-04 16:00:00', NULL, 5, 'ใช้ทำโปรเจกต์วิชา IoT'),
(36, 'EB-2026-0036', 20, 24, '2026-10-28 13:45:00', '2026-11-04 16:00:00', NULL, 5, 'ใช้ในกิจกรรมชมรม'),
(37, 'EB-2026-0037', 13, 24, '2026-10-28 14:30:00', '2026-11-04 16:00:00', NULL, 5, 'สาธิตเทคโนโลยี VR ในงานเปิดบ้าน'),
(38, 'EB-2026-0038', 28, 24, '2026-11-01 10:30:00', '2026-11-08 16:00:00', NULL, 5, 'ถ่ายทำสารคดีวิชา Media'),
(39, 'EB-2026-0039', 25, 28, '2026-11-01 12:45:00', '2026-11-15 16:00:00', NULL, 5, 'ใช้ในกิจกรรมชมรม'),
(40, 'EB-2026-0040', 13, 23, '2026-11-04 15:30:00', '2026-11-09 16:00:00', NULL, 2, 'ถ่ายภาพงานรับปริญญา'),
(41, 'EB-2026-0041', 8, 25, '2026-11-06 09:00:00', '2026-11-13 16:00:00', NULL, 2, 'ใช้ประกอบการเรียนการสอน'),
(42, 'EB-2026-0042', 30, 25, '2026-11-06 11:30:00', '2026-11-11 16:00:00', NULL, 1, 'นำเสนองานนอกสถานที่'),
(43, 'EB-2026-0043', 19, 21, '2026-11-06 15:15:00', '2026-11-20 16:00:00', NULL, 2, 'บันทึกเสียงพอดแคสต์'),
(44, 'EB-2026-0044', 8, 22, '2026-11-09 10:30:00', '2026-11-14 16:00:00', NULL, 1, 'ถ่ายทำสารคดีวิชา Media'),
(45, 'EB-2026-0045', 20, 25, '2026-11-11 09:30:00', '2026-11-14 16:00:00', NULL, 1, 'ใช้พัฒนาแอปพลิเคชัน');

-- 2.11 ประวัติการยืมอุปกรณ์ equipment_booking_history (148 แถว)
INSERT INTO equipment_booking_history (booking_id, action_id, action_date) VALUES
(1, 1, '2026-09-01 11:45:00'),
(1, 2, '2026-09-01 21:45:00'),
(1, 4, '2026-09-03 14:45:00'),
(1, 7, '2026-09-14 19:00:00'),
(2, 1, '2026-08-31 10:15:00'),
(2, 2, '2026-09-01 04:15:00'),
(2, 4, '2026-09-05 11:15:00'),
(2, 7, '2026-09-21 17:00:00'),
(3, 1, '2026-09-02 12:45:00'),
(3, 2, '2026-09-03 07:45:00'),
(3, 4, '2026-09-05 13:45:00'),
(3, 7, '2026-09-24 17:00:00'),
(4, 1, '2026-09-01 09:45:00'),
(4, 2, '2026-09-01 16:45:00'),
(4, 4, '2026-09-06 10:45:00'),
(4, 7, '2026-09-12 17:00:00'),
(5, 1, '2026-09-02 10:30:00'),
(5, 2, '2026-09-02 20:30:00'),
(5, 4, '2026-09-06 12:30:00'),
(5, 7, '2026-09-14 21:00:00'),
(6, 1, '2026-09-02 12:45:00'),
(6, 2, '2026-09-02 17:45:00'),
(6, 4, '2026-09-06 15:45:00'),
(6, 7, '2026-09-11 13:00:00'),
(7, 1, '2026-09-07 11:30:00'),
(7, 2, '2026-09-07 14:30:00'),
(7, 4, '2026-09-08 12:30:00'),
(7, 7, '2026-09-18 21:00:00'),
(8, 1, '2026-09-05 09:30:00'),
(8, 2, '2026-09-05 22:30:00'),
(8, 4, '2026-09-09 10:30:00'),
(8, 7, '2026-09-25 21:00:00'),
(9, 1, '2026-09-06 07:45:00'),
(9, 2, '2026-09-06 09:45:00'),
(9, 4, '2026-09-10 10:45:00'),
(9, 7, '2026-09-16 07:00:00'),
(10, 1, '2026-09-13 09:15:00'),
(10, 2, '2026-09-13 14:15:00'),
(10, 4, '2026-09-14 09:15:00'),
(10, 7, '2026-09-20 22:00:00'),
(11, 1, '2026-09-20 09:45:00'),
(11, 2, '2026-09-20 20:45:00'),
(11, 4, '2026-09-21 09:45:00'),
(11, 7, '2026-09-29 19:00:00'),
(12, 1, '2026-09-18 09:00:00'),
(12, 2, '2026-09-18 17:00:00'),
(12, 4, '2026-09-21 12:00:00'),
(12, 7, '2026-10-05 10:00:00'),
(13, 1, '2026-09-19 14:30:00'),
(13, 3, '2026-09-19 23:30:00'),
(14, 1, '2026-09-20 09:30:00'),
(14, 2, '2026-09-21 01:30:00'),
(14, 4, '2026-09-23 09:30:00'),
(14, 7, '2026-09-27 15:00:00'),
(15, 1, '2026-09-20 14:00:00'),
(15, 2, '2026-09-21 09:00:00'),
(15, 4, '2026-09-23 14:00:00'),
(15, 7, '2026-09-27 23:00:00'),
(16, 1, '2026-09-20 07:00:00'),
(16, 3, '2026-09-20 21:00:00'),
(17, 1, '2026-09-29 12:15:00'),
(17, 2, '2026-09-30 00:15:00'),
(17, 4, '2026-10-04 13:15:00'),
(17, 7, '2026-10-14 16:00:00'),
(18, 1, '2026-10-05 11:30:00'),
(18, 2, '2026-10-05 19:30:00'),
(18, 4, '2026-10-06 13:30:00'),
(18, 7, '2026-10-11 00:00:00'),
(19, 1, '2026-10-04 14:00:00'),
(19, 2, '2026-10-05 02:00:00'),
(19, 4, '2026-10-06 15:00:00'),
(19, 7, '2026-10-16 21:00:00'),
(20, 1, '2026-10-03 09:30:00'),
(20, 2, '2026-10-03 13:30:00'),
(20, 4, '2026-10-08 11:30:00'),
(20, 7, '2026-10-28 19:00:00'),
(21, 1, '2026-10-05 09:45:00'),
(21, 2, '2026-10-06 01:45:00'),
(21, 4, '2026-10-09 12:45:00'),
(21, 7, '2026-10-15 12:00:00'),
(22, 1, '2026-10-05 07:30:00'),
(22, 2, '2026-10-05 17:30:00'),
(22, 4, '2026-10-10 10:30:00'),
(22, 7, '2026-10-27 16:00:00'),
(23, 1, '2026-10-07 15:15:00'),
(23, 2, '2026-10-08 07:15:00'),
(23, 4, '2026-10-10 15:15:00'),
(23, 7, '2026-10-23 07:00:00'),
(24, 1, '2026-10-11 13:00:00'),
(24, 2, '2026-10-12 01:00:00'),
(24, 4, '2026-10-12 13:00:00'),
(25, 1, '2026-10-07 12:15:00'),
(25, 2, '2026-10-08 06:15:00'),
(25, 4, '2026-10-12 15:15:00'),
(25, 7, '2026-10-27 21:00:00'),
(26, 1, '2026-10-08 14:30:00'),
(26, 2, '2026-10-08 16:30:00'),
(26, 4, '2026-10-12 15:30:00'),
(26, 7, '2026-10-25 01:00:00'),
(27, 1, '2026-10-12 11:00:00'),
(27, 2, '2026-10-12 22:00:00'),
(27, 4, '2026-10-14 12:00:00'),
(28, 1, '2026-10-10 14:15:00'),
(28, 3, '2026-10-10 20:15:00'),
(29, 1, '2026-10-12 14:15:00'),
(29, 2, '2026-10-13 03:15:00'),
(29, 4, '2026-10-15 15:15:00'),
(29, 7, '2026-10-29 10:00:00'),
(30, 1, '2026-10-11 13:45:00'),
(30, 2, '2026-10-12 01:45:00'),
(30, 4, '2026-10-16 13:45:00'),
(30, 7, '2026-10-21 05:00:00'),
(31, 1, '2026-10-15 12:00:00'),
(31, 2, '2026-10-15 23:00:00'),
(31, 4, '2026-10-16 14:00:00'),
(32, 1, '2026-10-13 13:00:00'),
(32, 2, '2026-10-13 18:00:00'),
(32, 4, '2026-10-16 15:00:00'),
(33, 1, '2026-10-13 11:00:00'),
(33, 2, '2026-10-13 17:00:00'),
(33, 4, '2026-10-18 14:00:00'),
(34, 1, '2026-10-19 11:00:00'),
(34, 2, '2026-10-20 02:00:00'),
(34, 4, '2026-10-20 14:00:00'),
(35, 1, '2026-10-27 10:45:00'),
(35, 2, '2026-10-27 16:45:00'),
(35, 4, '2026-10-28 12:45:00'),
(36, 1, '2026-10-27 13:45:00'),
(36, 2, '2026-10-27 18:45:00'),
(36, 4, '2026-10-28 13:45:00'),
(37, 1, '2026-10-25 14:30:00'),
(37, 2, '2026-10-25 21:30:00'),
(37, 4, '2026-10-28 14:30:00'),
(38, 1, '2026-10-29 10:30:00'),
(38, 2, '2026-10-29 21:30:00'),
(38, 4, '2026-11-01 10:30:00'),
(39, 1, '2026-10-29 09:45:00'),
(39, 2, '2026-10-30 02:45:00'),
(39, 4, '2026-11-01 12:45:00'),
(40, 1, '2026-10-30 13:30:00'),
(40, 2, '2026-10-31 01:30:00'),
(41, 1, '2026-11-02 09:00:00'),
(41, 2, '2026-11-02 14:00:00'),
(42, 1, '2026-11-02 08:30:00'),
(43, 1, '2026-11-02 09:00:00'),
(43, 2, '2026-11-02 12:00:00'),
(44, 1, '2026-11-02 09:00:00'),
(45, 1, '2026-11-02 09:00:00');

-- 2.12 ค่าปรับ fines (22 แถว + 8 แถวใน 2.12b = 30 แถว)
INSERT INTO fines (booking_id, fine_amount, fine_reason, fine_status) VALUES
(1, 180.00, 'คืนอุปกรณ์ล่าช้า 9 วัน (วันละ 20 บาท)', 'PAID'),
(2, 200.00, 'คืนอุปกรณ์ล่าช้า 10 วัน (วันละ 20 บาท)', 'PAID'),
(3, 120.00, 'คืนอุปกรณ์ล่าช้า 6 วัน (วันละ 20 บาท)', 'PAID'),
(4, 80.00, 'คืนอุปกรณ์ล่าช้า 4 วัน (วันละ 20 บาท)', 'WAIVED'),
(5, 80.00, 'คืนอุปกรณ์ล่าช้า 4 วัน (วันละ 20 บาท)', 'PAID'),
(6, 800.00, 'อุปกรณ์เสริมสูญหาย', 'UNPAID'),
(7, 160.00, 'คืนอุปกรณ์ล่าช้า 8 วัน (วันละ 20 บาท)', 'PAID'),
(8, 200.00, 'คืนอุปกรณ์ล่าช้า 10 วัน (วันละ 20 บาท)', 'UNPAID'),
(9, 500.00, 'อุปกรณ์เสริมสูญหาย', 'UNPAID'),
(10, 300.00, 'อุปกรณ์ชำรุดจากการใช้งาน', 'UNPAID'),
(11, 40.00, 'คืนอุปกรณ์ล่าช้า 2 วัน (วันละ 20 บาท)', 'WAIVED'),
(17, 60.00, 'คืนอุปกรณ์ล่าช้า 3 วัน (วันละ 20 บาท)', 'PAID'),
(19, 80.00, 'คืนอุปกรณ์ล่าช้า 4 วัน (วันละ 20 บาท)', 'PAID'),
(20, 140.00, 'คืนอุปกรณ์ล่าช้า 7 วัน (วันละ 20 บาท)', 'PAID'),
(22, 60.00, 'คืนอุปกรณ์ล่าช้า 3 วัน (วันละ 20 บาท)', 'PAID'),
(24, 320.00, 'ค้างคืนอุปกรณ์เกินกำหนด 16 วัน (วันละ 20 บาท)', 'UNPAID'),
(25, 180.00, 'คืนอุปกรณ์ล่าช้า 9 วัน (วันละ 20 บาท)', 'UNPAID'),
(27, 280.00, 'ค้างคืนอุปกรณ์เกินกำหนด 14 วัน (วันละ 20 บาท)', 'UNPAID'),
(31, 240.00, 'ค้างคืนอุปกรณ์เกินกำหนด 12 วัน (วันละ 20 บาท)', 'UNPAID'),
(32, 280.00, 'ค้างคืนอุปกรณ์เกินกำหนด 14 วัน (วันละ 20 บาท)', 'UNPAID'),
(33, 160.00, 'ค้างคืนอุปกรณ์เกินกำหนด 8 วัน (วันละ 20 บาท)', 'UNPAID'),
(34, 200.00, 'ค้างคืนอุปกรณ์เกินกำหนด 10 วัน (วันละ 20 บาท)', 'UNPAID');

-- 2.12b เพิ่มการยืมที่คืนช้า 8 รายการ (booking 46-53) พร้อมประวัติและค่าปรับ เพื่อให้ fines ครบ 30 แถว
INSERT INTO equipment_bookings (booking_id, booking_code, user_id, resource_id, borrow_date, expected_return_date, actual_return_date, booking_status_id, borrow_purpose) VALUES
(46, 'EB-2026-0046', 9,  22, '2026-09-12 10:00:00', '2026-09-15 16:00:00', '2026-09-19 12:00:00', 7, 'ใช้ประกอบการเรียนการสอน'),
(47, 'EB-2026-0047', 10, 26, '2026-09-17 13:30:00', '2026-09-24 16:00:00', '2026-09-27 10:00:00', 7, 'ใช้ทำโปรเจกต์วิชา IoT'),
(48, 'EB-2026-0048', 14, 29, '2026-09-25 11:00:00', '2026-09-30 16:00:00', '2026-10-06 09:00:00', 7, 'ถ่ายภาพงานรับปริญญา'),
(49, 'EB-2026-0049', 19, 24, '2026-10-02 14:15:00', '2026-10-09 16:00:00', '2026-10-10 18:00:00', 7, 'ถ่ายทำสารคดีวิชา Media'),
(50, 'EB-2026-0050', 21, 30, '2026-10-05 09:45:00', '2026-10-08 16:00:00', '2026-10-15 15:00:00', 7, 'นำเสนองานนอกสถานที่'),
(51, 'EB-2026-0051', 24, 27, '2026-10-13 10:15:00', '2026-10-20 16:00:00', '2026-10-24 11:00:00', 7, 'สาธิตเทคโนโลยี VR ในงานเปิดบ้าน'),
(52, 'EB-2026-0052', 27, 23, '2026-10-19 13:00:00', '2026-10-23 16:00:00', '2026-10-30 20:00:00', 7, 'ใช้พัฒนาแอปพลิเคชัน'),
(53, 'EB-2026-0053', 28, 21, '2026-10-21 15:30:00', '2026-10-28 16:00:00', '2026-11-02 14:00:00', 7, 'บันทึกเสียงพอดแคสต์');

INSERT INTO equipment_booking_history (booking_id, action_id, action_date) VALUES
(46, 1, '2026-09-10 09:30:00'), (46, 2, '2026-09-10 21:30:00'), (46, 4, '2026-09-12 10:00:00'), (46, 7, '2026-09-19 12:00:00'),
(47, 1, '2026-09-15 14:00:00'), (47, 2, '2026-09-16 02:00:00'), (47, 4, '2026-09-17 13:30:00'), (47, 7, '2026-09-27 10:00:00'),
(48, 1, '2026-09-23 10:15:00'), (48, 2, '2026-09-23 22:15:00'), (48, 4, '2026-09-25 11:00:00'), (48, 7, '2026-10-06 09:00:00'),
(49, 1, '2026-09-30 16:20:00'), (49, 2, '2026-10-01 04:20:00'), (49, 4, '2026-10-02 14:15:00'), (49, 7, '2026-10-10 18:00:00'),
(50, 1, '2026-10-03 11:00:00'), (50, 2, '2026-10-03 23:00:00'), (50, 4, '2026-10-05 09:45:00'), (50, 7, '2026-10-15 15:00:00'),
(51, 1, '2026-10-11 15:30:00'), (51, 2, '2026-10-12 03:30:00'), (51, 4, '2026-10-13 10:15:00'), (51, 7, '2026-10-24 11:00:00'),
(52, 1, '2026-10-17 09:00:00'), (52, 2, '2026-10-17 21:00:00'), (52, 4, '2026-10-19 13:00:00'), (52, 7, '2026-10-30 20:00:00'),
(53, 1, '2026-10-19 10:45:00'), (53, 2, '2026-10-19 22:45:00'), (53, 4, '2026-10-21 15:30:00'), (53, 7, '2026-11-02 14:00:00');

INSERT INTO fines (booking_id, fine_amount, fine_reason, fine_status) VALUES
(46,  80.00, 'คืนอุปกรณ์ล่าช้า 4 วัน (วันละ 20 บาท)', 'PAID'),
(47,  60.00, 'คืนอุปกรณ์ล่าช้า 3 วัน (วันละ 20 บาท)', 'PAID'),
(48, 120.00, 'คืนอุปกรณ์ล่าช้า 6 วัน (วันละ 20 บาท)', 'PAID'),
(49,  40.00, 'คืนอุปกรณ์ล่าช้า 2 วัน (วันละ 20 บาท)', 'WAIVED'),
(50, 140.00, 'คืนอุปกรณ์ล่าช้า 7 วัน (วันละ 20 บาท)', 'UNPAID'),
(51,  80.00, 'คืนอุปกรณ์ล่าช้า 4 วัน (วันละ 20 บาท)', 'UNPAID'),
(52, 160.00, 'คืนอุปกรณ์ล่าช้า 8 วัน (วันละ 20 บาท)', 'UNPAID'),
(53, 100.00, 'คืนอุปกรณ์ล่าช้า 5 วัน (วันละ 20 บาท)', 'UNPAID');

-- 2.13 การแจ้งซ่อม maintenance_bookings (34 แถว)
INSERT INTO maintenance_bookings (booking_id, booking_code, user_id, resource_id, booking_time, booking_status_id, repair_title, repair_description, reported_date, staff_note) VALUES
(1, 'MT-2026-0001', 9, 19, '2026-09-01 11:00:00', 4, 'แผ่นฐานพิมพ์เสื่อมสภาพ', 'พื้นผิวฐานพิมพ์เป็นรอย ชิ้นงานติดแน่น', '2026-09-01 11:00:00', 'เปลี่ยนอะไหล่ใหม่และทดสอบแล้ว'),
(2, 'MT-2026-0002', 11, 7, '2026-09-03 09:15:00', 4, 'ไฟห้องกะพริบ', 'หลอดไฟกะพริบรบกวนการเรียน', '2026-09-03 09:15:00', 'ตรวจสอบและแก้ไขเรียบร้อย ทดสอบใช้งานปกติ'),
(3, 'MT-2026-0003', 15, 11, '2026-09-05 14:00:00', 4, 'เก้าอี้ชำรุด', 'เก้าอี้หัก 3 ตัว ไม่ปลอดภัยต่อการใช้งาน', '2026-09-05 14:00:00', 'ทำความสะอาดและปรับตั้งค่าใหม่ใช้งานได้ปกติ'),
(4, 'MT-2026-0004', 25, 31, '2026-09-08 14:45:00', 4, 'เลนส์มีฝ้า/เชื้อรา', 'พบฝ้าด้านในเลนส์ ภาพไม่คมชัด', '2026-09-08 14:45:00', 'เปลี่ยนอะไหล่ใหม่และทดสอบแล้ว'),
(5, 'MT-2026-0005', 12, 18, '2026-09-11 16:15:00', 4, 'เรซินรั่วซึม', 'ถาดเรซินมีรอยรั่ว ต้องเปลี่ยนถาด', '2026-09-11 16:15:00', 'ช่างภายนอกเข้าซ่อมและส่งมอบเรียบร้อย'),
(6, 'MT-2026-0006', 33, 15, '2026-09-12 16:15:00', 4, 'หัวฉีดอุดตัน', 'พิมพ์แล้วเส้นพลาสติกไม่ออก ต้องทำความสะอาดหัวฉีด', '2026-09-12 16:15:00', 'เปลี่ยนอะไหล่ใหม่และทดสอบแล้ว'),
(7, 'MT-2026-0007', 33, 15, '2026-09-15 12:00:00', 4, 'แผ่นฐานพิมพ์เสื่อมสภาพ', 'พื้นผิวฐานพิมพ์เป็นรอย ชิ้นงานติดแน่น', '2026-09-15 12:00:00', 'ตรวจสอบและแก้ไขเรียบร้อย ทดสอบใช้งานปกติ'),
(8, 'MT-2026-0008', 9, 22, '2026-09-15 16:00:00', 4, 'พอร์ตชาร์จเสีย', 'เสียบสายชาร์จแล้วไม่เข้าเครื่อง', '2026-09-15 16:00:00', 'เปลี่ยนอะไหล่ใหม่และทดสอบแล้ว'),
(9, 'MT-2026-0009', 32, 37, '2026-09-18 12:45:00', 4, 'พอร์ตสวิตช์เสีย', 'พอร์ตเครือข่ายบางพอร์ตไม่จ่ายสัญญาณ', '2026-09-18 12:45:00', 'เปลี่ยนอะไหล่ใหม่และทดสอบแล้ว'),
(10, 'MT-2026-0010', 12, 35, '2026-09-22 08:30:00', 4, 'พอร์ตสวิตช์เสีย', 'พอร์ตเครือข่ายบางพอร์ตไม่จ่ายสัญญาณ', '2026-09-22 08:30:00', 'เปลี่ยนอะไหล่ใหม่และทดสอบแล้ว'),
(11, 'MT-2026-0011', 3, 36, '2026-09-23 15:15:00', 3, 'น้ำหยดจากเครื่องปรับอากาศ', 'มีน้ำหยดลงพื้นห้องจากคอยล์เย็น', '2026-09-23 15:15:00', 'เป็นรายการซ้ำกับใบแจ้งซ่อมก่อนหน้า'),
(12, 'MT-2026-0012', 35, 38, '2026-09-27 12:45:00', 4, 'น้ำหยดจากเครื่องปรับอากาศ', 'มีน้ำหยดลงพื้นห้องจากคอยล์เย็น', '2026-09-27 12:45:00', 'ทำความสะอาดและปรับตั้งค่าใหม่ใช้งานได้ปกติ'),
(13, 'MT-2026-0013', 20, 36, '2026-09-28 16:00:00', 4, 'อินเทอร์เน็ตหลุดบ่อย', 'เครือข่ายขาดหายเป็นช่วงๆ ระหว่างเรียนออนไลน์', '2026-09-28 16:00:00', 'ทำความสะอาดและปรับตั้งค่าใหม่ใช้งานได้ปกติ'),
(14, 'MT-2026-0014', 13, 38, '2026-09-29 12:00:00', 4, 'พอร์ตสวิตช์เสีย', 'พอร์ตเครือข่ายบางพอร์ตไม่จ่ายสัญญาณ', '2026-09-29 12:00:00', 'ช่างภายนอกเข้าซ่อมและส่งมอบเรียบร้อย'),
(15, 'MT-2026-0015', 19, 27, '2026-10-05 15:15:00', 4, 'แบตเตอรี่เสื่อม', 'ใช้งานได้ไม่ถึง 1 ชั่วโมง ต้องเปลี่ยนแบตเตอรี่', '2026-10-05 15:15:00', 'เปลี่ยนอะไหล่ใหม่และทดสอบแล้ว'),
(16, 'MT-2026-0016', 7, 36, '2026-10-06 11:15:00', 4, 'อินเทอร์เน็ตหลุดบ่อย', 'เครือข่ายขาดหายเป็นช่วงๆ ระหว่างเรียนออนไลน์', '2026-10-06 11:15:00', 'เปลี่ยนอะไหล่ใหม่และทดสอบแล้ว'),
(17, 'MT-2026-0017', 28, 19, '2026-10-08 14:15:00', 4, 'หัวฉีดอุดตัน', 'พิมพ์แล้วเส้นพลาสติกไม่ออก ต้องทำความสะอาดหัวฉีด', '2026-10-08 14:15:00', 'ตรวจสอบและแก้ไขเรียบร้อย ทดสอบใช้งานปกติ'),
(18, 'MT-2026-0018', 8, 22, '2026-10-11 08:00:00', 4, 'เลนส์มีฝ้า/เชื้อรา', 'พบฝ้าด้านในเลนส์ ภาพไม่คมชัด', '2026-10-11 08:00:00', 'ช่างภายนอกเข้าซ่อมและส่งมอบเรียบร้อย'),
(19, 'MT-2026-0019', 15, 5, '2026-10-11 12:45:00', 4, 'เก้าอี้ชำรุด', 'เก้าอี้หัก 3 ตัว ไม่ปลอดภัยต่อการใช้งาน', '2026-10-11 12:45:00', 'ทำความสะอาดและปรับตั้งค่าใหม่ใช้งานได้ปกติ'),
(20, 'MT-2026-0020', 12, 34, '2026-10-12 13:45:00', 3, 'เลนส์มีฝ้า/เชื้อรา', 'พบฝ้าด้านในเลนส์ ภาพไม่คมชัด', '2026-10-12 13:45:00', 'เป็นรายการซ้ำกับใบแจ้งซ่อมก่อนหน้า'),
(21, 'MT-2026-0021', 15, 38, '2026-10-14 12:45:00', 3, 'ภาพโปรเจกเตอร์เบลอ', 'ภาพไม่คมชัด สีเพี้ยน อาจต้องเปลี่ยนหลอดภาพ', '2026-10-14 12:45:00', 'ตรวจสอบแล้วไม่พบความผิดปกติ'),
(22, 'MT-2026-0022', 35, 21, '2026-10-16 11:45:00', 6, 'พอร์ตชาร์จเสีย', 'เสียบสายชาร์จแล้วไม่เข้าเครื่อง', '2026-10-16 11:45:00', 'อยู่ระหว่างรออะไหล่จากผู้จำหน่าย'),
(23, 'MT-2026-0023', 26, 37, '2026-10-19 11:00:00', 3, 'เครื่องปรับอากาศไม่เย็น', 'เปิดแอร์แล้วลมไม่เย็น อุณหภูมิห้องสูงกว่า 30 องศา', '2026-10-19 11:00:00', 'ตรวจสอบแล้วไม่พบความผิดปกติ'),
(24, 'MT-2026-0024', 8, 35, '2026-10-19 13:30:00', 6, 'น้ำหยดจากเครื่องปรับอากาศ', 'มีน้ำหยดลงพื้นห้องจากคอยล์เย็น', '2026-10-19 13:30:00', 'รอช่างภายนอกเข้าซ่อม'),
(25, 'MT-2026-0025', 15, 12, '2026-10-22 09:30:00', 6, 'ไฟห้องกะพริบ', 'หลอดไฟกะพริบรบกวนการเรียน', '2026-10-22 09:30:00', 'อยู่ระหว่างรออะไหล่จากผู้จำหน่าย'),
(26, 'MT-2026-0026', 12, 37, '2026-10-22 15:30:00', 6, 'อินเทอร์เน็ตหลุดบ่อย', 'เครือข่ายขาดหายเป็นช่วงๆ ระหว่างเรียนออนไลน์', '2026-10-22 15:30:00', 'อยู่ระหว่างรออะไหล่จากผู้จำหน่าย'),
(27, 'MT-2026-0027', 20, 18, '2026-10-25 16:15:00', 2, 'แผ่นฐานพิมพ์เสื่อมสภาพ', 'พื้นผิวฐานพิมพ์เป็นรอย ชิ้นงานติดแน่น', '2026-10-25 16:15:00', 'รับเรื่องแล้ว อยู่ในคิวซ่อม'),
(28, 'MT-2026-0028', 32, 35, '2026-10-26 16:45:00', 6, 'เครื่องปรับอากาศไม่เย็น', 'เปิดแอร์แล้วลมไม่เย็น อุณหภูมิห้องสูงกว่า 30 องศา', '2026-10-26 16:45:00', 'อยู่ระหว่างรออะไหล่จากผู้จำหน่าย'),
(29, 'MT-2026-0029', 8, 22, '2026-10-29 12:15:00', 2, 'แบตเตอรี่เสื่อม', 'ใช้งานได้ไม่ถึง 1 ชั่วโมง ต้องเปลี่ยนแบตเตอรี่', '2026-10-29 12:15:00', 'รับเรื่องแล้ว อยู่ในคิวซ่อม'),
(30, 'MT-2026-0030', 7, 2, '2026-10-29 13:30:00', 2, 'ประตูล็อกไม่สนิท', 'ล็อกประตูฝืด ปิดไม่สนิท', '2026-10-29 13:30:00', 'รับเรื่องแล้ว อยู่ในคิวซ่อม'),
(31, 'MT-2026-0031', 7, 20, '2026-10-30 09:30:00', 1, 'หัวฉีดอุดตัน', 'พิมพ์แล้วเส้นพลาสติกไม่ออก ต้องทำความสะอาดหัวฉีด', '2026-10-30 09:30:00', NULL),
(32, 'MT-2026-0032', 15, 15, '2026-10-31 11:30:00', 1, 'เตียงพิมพ์ไม่เรียบ', 'ชิ้นงานหลุดจากฐานระหว่างพิมพ์ ต้องปรับระดับเตียง', '2026-10-31 11:30:00', NULL),
(33, 'MT-2026-0033', 33, 5, '2026-10-31 12:00:00', 1, 'ไฟห้องกะพริบ', 'หลอดไฟกะพริบรบกวนการเรียน', '2026-10-31 12:00:00', NULL),
(34, 'MT-2026-0034', 21, 18, '2026-11-01 13:45:00', 1, 'เรซินรั่วซึม', 'ถาดเรซินมีรอยรั่ว ต้องเปลี่ยนถาด', '2026-11-01 13:45:00', NULL);

-- 2.14 ประวัติการแจ้งซ่อม maintenance_booking_history (105 แถว)
INSERT INTO maintenance_booking_history (booking_id, action_id, action_date) VALUES
(1, 1, '2026-09-01 11:00:00'),
(1, 2, '2026-09-02 13:00:00'),
(1, 5, '2026-09-04 03:00:00'),
(1, 6, '2026-09-06 14:00:00'),
(2, 1, '2026-09-03 09:15:00'),
(2, 2, '2026-09-04 09:15:00'),
(2, 5, '2026-09-06 03:15:00'),
(2, 6, '2026-09-06 11:15:00'),
(3, 1, '2026-09-05 14:00:00'),
(3, 2, '2026-09-06 10:00:00'),
(3, 5, '2026-09-07 04:00:00'),
(3, 6, '2026-09-15 15:00:00'),
(4, 1, '2026-09-08 14:45:00'),
(4, 2, '2026-09-08 22:45:00'),
(4, 5, '2026-09-09 11:45:00'),
(4, 6, '2026-09-13 15:45:00'),
(5, 1, '2026-09-11 16:15:00'),
(5, 2, '2026-09-12 14:15:00'),
(5, 5, '2026-09-14 13:15:00'),
(5, 6, '2026-09-22 17:15:00'),
(6, 1, '2026-09-12 16:15:00'),
(6, 2, '2026-09-13 17:15:00'),
(6, 5, '2026-09-15 07:15:00'),
(6, 6, '2026-09-24 16:15:00'),
(7, 1, '2026-09-15 12:00:00'),
(7, 2, '2026-09-16 17:00:00'),
(7, 5, '2026-09-17 20:00:00'),
(7, 6, '2026-09-24 18:00:00'),
(8, 1, '2026-09-15 16:00:00'),
(8, 2, '2026-09-15 22:00:00'),
(8, 5, '2026-09-16 04:00:00'),
(8, 6, '2026-09-21 18:00:00'),
(9, 1, '2026-09-18 12:45:00'),
(9, 2, '2026-09-18 17:45:00'),
(9, 5, '2026-09-20 06:45:00'),
(9, 6, '2026-09-26 18:45:00'),
(10, 1, '2026-09-22 08:30:00'),
(10, 2, '2026-09-22 22:30:00'),
(10, 5, '2026-09-24 04:30:00'),
(10, 6, '2026-09-24 09:30:00'),
(11, 1, '2026-09-23 15:15:00'),
(11, 3, '2026-09-24 00:15:00'),
(12, 1, '2026-09-27 12:45:00'),
(12, 2, '2026-09-28 04:45:00'),
(12, 5, '2026-09-28 22:45:00'),
(12, 6, '2026-10-07 18:45:00'),
(13, 1, '2026-09-28 16:00:00'),
(13, 2, '2026-09-29 02:00:00'),
(13, 5, '2026-09-29 18:00:00'),
(13, 6, '2026-10-11 22:00:00'),
(14, 1, '2026-09-29 12:00:00'),
(14, 2, '2026-09-29 17:00:00'),
(14, 5, '2026-10-01 11:00:00'),
(14, 6, '2026-10-05 15:00:00'),
(15, 1, '2026-10-05 15:15:00'),
(15, 2, '2026-10-06 19:15:00'),
(15, 5, '2026-10-08 01:15:00'),
(15, 6, '2026-10-18 18:15:00'),
(16, 1, '2026-10-06 11:15:00'),
(16, 2, '2026-10-06 23:15:00'),
(16, 5, '2026-10-08 22:15:00'),
(16, 6, '2026-10-11 17:15:00'),
(17, 1, '2026-10-08 14:15:00'),
(17, 2, '2026-10-09 09:15:00'),
(17, 5, '2026-10-10 23:15:00'),
(17, 6, '2026-10-13 16:15:00'),
(18, 1, '2026-10-11 08:00:00'),
(18, 2, '2026-10-12 08:00:00'),
(18, 5, '2026-10-13 23:00:00'),
(18, 6, '2026-10-25 12:00:00'),
(19, 1, '2026-10-11 12:45:00'),
(19, 2, '2026-10-12 01:45:00'),
(19, 5, '2026-10-13 13:45:00'),
(19, 6, '2026-10-21 12:45:00'),
(20, 1, '2026-10-12 13:45:00'),
(20, 3, '2026-10-13 00:45:00'),
(21, 1, '2026-10-14 12:45:00'),
(21, 3, '2026-10-14 23:45:00'),
(22, 1, '2026-10-16 11:45:00'),
(22, 2, '2026-10-17 06:45:00'),
(22, 5, '2026-10-18 13:45:00'),
(23, 1, '2026-10-19 11:00:00'),
(23, 3, '2026-10-20 09:00:00'),
(24, 1, '2026-10-19 13:30:00'),
(24, 2, '2026-10-19 18:30:00'),
(24, 5, '2026-10-21 05:30:00'),
(25, 1, '2026-10-22 09:30:00'),
(25, 2, '2026-10-22 12:30:00'),
(25, 5, '2026-10-24 12:30:00'),
(26, 1, '2026-10-22 15:30:00'),
(26, 2, '2026-10-23 09:30:00'),
(26, 5, '2026-10-23 22:30:00'),
(27, 1, '2026-10-25 16:15:00'),
(27, 2, '2026-10-26 13:15:00'),
(28, 1, '2026-10-26 16:45:00'),
(28, 2, '2026-10-27 22:45:00'),
(28, 5, '2026-10-29 00:45:00'),
(29, 1, '2026-10-29 12:15:00'),
(29, 2, '2026-10-30 04:15:00'),
(30, 1, '2026-10-29 13:30:00'),
(30, 2, '2026-10-30 05:30:00'),
(31, 1, '2026-10-30 09:30:00'),
(32, 1, '2026-10-31 11:30:00'),
(33, 1, '2026-10-31 12:00:00'),
(34, 1, '2026-11-01 13:45:00');

-- 2.15 ไฟล์แนบการแจ้งซ่อม attachments (30 แถว)
INSERT INTO attachments (booking_id, file_name, file_path, upload_date) VALUES
(2, 'MT-2026-0002_photo1.jpg', 'maintenance/MT-2026-0002/photo1.jpg', '2026-09-03 09:26:00'),
(6, 'MT-2026-0006_photo1.jpg', 'maintenance/MT-2026-0006/photo1.jpg', '2026-09-12 16:21:00'),
(7, 'MT-2026-0007_photo1.jpg', 'maintenance/MT-2026-0007/photo1.jpg', '2026-09-15 12:01:00'),
(7, 'MT-2026-0007_photo2.jpg', 'maintenance/MT-2026-0007/photo2.jpg', '2026-09-15 12:05:00'),
(8, 'MT-2026-0008_photo1.jpg', 'maintenance/MT-2026-0008/photo1.jpg', '2026-09-15 16:14:00'),
(9, 'MT-2026-0009_photo1.jpg', 'maintenance/MT-2026-0009/photo1.jpg', '2026-09-18 12:57:00'),
(9, 'MT-2026-0009_photo2.jpg', 'maintenance/MT-2026-0009/photo2.jpg', '2026-09-18 13:00:00'),
(12, 'MT-2026-0012_photo1.jpg', 'maintenance/MT-2026-0012/photo1.jpg', '2026-09-27 13:03:00'),
(13, 'MT-2026-0013_photo1.jpg', 'maintenance/MT-2026-0013/photo1.jpg', '2026-09-28 16:19:00'),
(13, 'MT-2026-0013_photo2.jpg', 'maintenance/MT-2026-0013/photo2.jpg', '2026-09-28 16:10:00'),
(14, 'MT-2026-0014_photo1.jpg', 'maintenance/MT-2026-0014/photo1.jpg', '2026-09-29 12:07:00'),
(16, 'MT-2026-0016_photo1.jpg', 'maintenance/MT-2026-0016/photo1.jpg', '2026-10-06 11:26:00'),
(16, 'MT-2026-0016_photo2.jpg', 'maintenance/MT-2026-0016/photo2.jpg', '2026-10-06 11:20:00'),
(17, 'MT-2026-0017_photo1.jpg', 'maintenance/MT-2026-0017/photo1.jpg', '2026-10-08 14:21:00'),
(18, 'MT-2026-0018_photo1.jpg', 'maintenance/MT-2026-0018/photo1.jpg', '2026-10-11 08:11:00'),
(19, 'MT-2026-0019_photo1.jpg', 'maintenance/MT-2026-0019/photo1.jpg', '2026-10-11 13:04:00'),
(20, 'MT-2026-0020_photo1.jpg', 'maintenance/MT-2026-0020/photo1.jpg', '2026-10-12 13:47:00'),
(21, 'MT-2026-0021_photo1.jpg', 'maintenance/MT-2026-0021/photo1.jpg', '2026-10-14 12:49:00'),
(21, 'MT-2026-0021_photo2.jpg', 'maintenance/MT-2026-0021/photo2.jpg', '2026-10-14 13:02:00'),
(23, 'MT-2026-0023_photo1.jpg', 'maintenance/MT-2026-0023/photo1.jpg', '2026-10-19 11:06:00'),
(25, 'MT-2026-0025_photo1.jpg', 'maintenance/MT-2026-0025/photo1.jpg', '2026-10-22 09:35:00'),
(26, 'MT-2026-0026_photo1.jpg', 'maintenance/MT-2026-0026/photo1.jpg', '2026-10-22 15:50:00'),
(28, 'MT-2026-0028_photo1.jpg', 'maintenance/MT-2026-0028/photo1.jpg', '2026-10-26 17:00:00'),
(30, 'MT-2026-0030_photo1.jpg', 'maintenance/MT-2026-0030/photo1.jpg', '2026-10-29 13:33:00'),
(31, 'MT-2026-0031_photo1.jpg', 'maintenance/MT-2026-0031/photo1.jpg', '2026-10-30 09:33:00'),
(31, 'MT-2026-0031_photo2.jpg', 'maintenance/MT-2026-0031/photo2.jpg', '2026-10-30 09:41:00'),
(32, 'MT-2026-0032_photo1.jpg', 'maintenance/MT-2026-0032/photo1.jpg', '2026-10-31 11:38:00'),
(33, 'MT-2026-0033_photo1.jpg', 'maintenance/MT-2026-0033/photo1.jpg', '2026-10-31 12:11:00'),
(34, 'MT-2026-0034_photo1.jpg', 'maintenance/MT-2026-0034/photo1.jpg', '2026-11-01 13:58:00'),
(34, 'MT-2026-0034_photo2.jpg', 'maintenance/MT-2026-0034/photo2.jpg', '2026-11-01 13:53:00');

-- ปรับ sequence ของตารางที่ระบุคีย์หลักเองให้ค่าถัดไปต่อจากค่าสูงสุดที่มีอยู่
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT * FROM (VALUES
    ('user_roles','role_id'),
    ('resource_categories','type_id'),
    ('resource_status','resource_status_id'),
    ('schedule_status','schedule_status_id'),
    ('booking_status','booking_status_id'),
    ('booking_actions','action_id'),
    ('users','user_id'),
    ('resources','resource_id'),
    ('room_schedules','schedule_id'),
    ('room_bookings','booking_id'),
    ('printer_schedules','schedule_id'),
    ('printer_bookings','booking_id'),
    ('equipment_bookings','booking_id'),
    ('maintenance_bookings','booking_id')
  ) AS v(tbl, col)
  LOOP
    EXECUTE format('SELECT setval(pg_get_serial_sequence(%L, %L), (SELECT MAX(%I) FROM %I))', r.tbl, r.col, r.col, r.tbl);
  END LOOP;
END $$;

COMMIT;
-- =====================================================================
-- ส่วนที่ 4 : ตรวจสอบจำนวนแถวหลังใส่ข้อมูล (ตารางหลักต้อง >= 30 แถว)
-- =====================================================================
SELECT table_name, row_count,
       CASE WHEN row_count >= 30 THEN 'OK (>= 30)' ELSE 'ตารางอ้างอิง/สนับสนุน' END AS check_result
FROM (
    SELECT 'users'                        AS table_name, COUNT(*) AS row_count FROM users
    UNION ALL SELECT 'resources',                    COUNT(*) FROM resources
    UNION ALL SELECT 'room_schedules',               COUNT(*) FROM room_schedules
    UNION ALL SELECT 'room_bookings',                COUNT(*) FROM room_bookings
    UNION ALL SELECT 'room_booking_history',         COUNT(*) FROM room_booking_history
    UNION ALL SELECT 'printer_schedules',            COUNT(*) FROM printer_schedules
    UNION ALL SELECT 'printer_bookings',             COUNT(*) FROM printer_bookings
    UNION ALL SELECT 'printer_booking_history',      COUNT(*) FROM printer_booking_history
    UNION ALL SELECT 'equipment_bookings',           COUNT(*) FROM equipment_bookings
    UNION ALL SELECT 'equipment_booking_history',    COUNT(*) FROM equipment_booking_history
    UNION ALL SELECT 'fines',                        COUNT(*) FROM fines
    UNION ALL SELECT 'maintenance_bookings',         COUNT(*) FROM maintenance_bookings
    UNION ALL SELECT 'maintenance_booking_history',  COUNT(*) FROM maintenance_booking_history
    UNION ALL SELECT 'attachments',                  COUNT(*) FROM attachments
    UNION ALL SELECT 'user_roles',                   COUNT(*) FROM user_roles
    UNION ALL SELECT 'resource_categories',          COUNT(*) FROM resource_categories
    UNION ALL SELECT 'resource_status',              COUNT(*) FROM resource_status
    UNION ALL SELECT 'schedule_status',              COUNT(*) FROM schedule_status
    UNION ALL SELECT 'booking_status',               COUNT(*) FROM booking_status
    UNION ALL SELECT 'booking_actions',              COUNT(*) FROM booking_actions
) AS c
ORDER BY row_count DESC, table_name;

-- #####################################################################
-- 3) วิวพื้นฐาน 8 วิว : views.sql
-- #####################################################################
-- =====================================================================
-- ส่วนที่ 1 : VIEWS (8 วิว)  ทุกวิวใช้ WITH (security_invoker = true)
--   ให้วิวเคารพนโยบาย RLS ของผู้เรียกใช้ (ไม่ข้ามสิทธิ์แบบ owner)
-- =====================================================================
DROP VIEW IF EXISTS v_dashboard_kpi, v_monthly_booking_trend, v_user_activity_summary,
                    v_resource_utilization, v_maintenance_tracking_summary,
                    v_equipment_overdue_summary, v_printer_booking_summary,
                    v_room_booking_summary CASCADE;

-- ---------------------------------------------------------------------
-- View 1 : สรุปการจองห้อง (JOIN 6 ตาราง) -> ใช้กับหน้าตารางการจองห้องและ Chat
-- ---------------------------------------------------------------------
CREATE VIEW v_room_booking_summary WITH (security_invoker = true) AS
SELECT rb.booking_id,
       rb.booking_code,
       u.user_id,
       u.full_name                                   AS user_name,
       ur.role_name                                  AS user_role,
       r.resource_id,
       r.resource_code                               AS room_code,
       r.resource_name                               AS room_name,
       r.location,
       r.capacity,
       rs.work_date,
       rs.start_time,
       rs.end_time,
       EXTRACT(EPOCH FROM (rs.end_time - rs.start_time)) / 3600.0 AS booked_hours,
       bs.booking_status_name                        AS booking_status,
       rb.booking_purpose,
       rb.booking_time
FROM room_bookings     AS rb
JOIN users             AS u  ON u.user_id            = rb.user_id
JOIN user_roles        AS ur ON ur.role_id           = u.role_id
JOIN room_schedules    AS rs ON rs.schedule_id       = rb.schedule_id
JOIN resources         AS r  ON r.resource_id        = rs.resource_id
JOIN booking_status    AS bs ON bs.booking_status_id = rb.booking_status_id;

-- ---------------------------------------------------------------------
-- View 2 : สรุปการจองเครื่องพิมพ์ 3 มิติ
-- ---------------------------------------------------------------------
CREATE VIEW v_printer_booking_summary WITH (security_invoker = true) AS
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
       pb.booking_time
FROM printer_bookings  AS pb
JOIN users             AS u  ON u.user_id            = pb.user_id
JOIN printer_schedules AS ps ON ps.schedule_id       = pb.schedule_id
JOIN resources         AS r  ON r.resource_id        = ps.resource_id
JOIN booking_status    AS bs ON bs.booking_status_id = pb.booking_status_id;

-- ---------------------------------------------------------------------
-- View 3 : สรุปอุปกรณ์เกินกำหนดคืน (ค้างคืนอยู่ + คืนล่าช้า) พร้อมค่าปรับ
--   overdue_days = วันที่คืนจริง (หรือวันนี้ ถ้ายังไม่คืน) - วันครบกำหนด
-- ---------------------------------------------------------------------
CREATE VIEW v_equipment_overdue_summary WITH (security_invoker = true) AS
SELECT eb.booking_id,
       eb.booking_code,
       u.user_id,
       u.full_name                                   AS borrower_name,
       u.user_status,
       r.resource_code                               AS equipment_code,
       r.resource_name                               AS equipment_name,
       eb.borrow_date,
       eb.expected_return_date,
       eb.actual_return_date,
       (COALESCE(eb.actual_return_date::date, CURRENT_DATE)
          - eb.expected_return_date::date)           AS overdue_days,
       CASE WHEN eb.actual_return_date IS NULL
            THEN 'ยังไม่คืน (ค้างอยู่)' ELSE 'คืนแล้วแต่ล่าช้า' END AS overdue_type,
       bs.booking_status_name                        AS booking_status,
       COALESCE(f.total_fine, 0)                     AS total_fine,
       COALESCE(f.unpaid_fine, 0)                    AS unpaid_fine
FROM equipment_bookings AS eb
JOIN users              AS u  ON u.user_id            = eb.user_id
JOIN resources          AS r  ON r.resource_id        = eb.resource_id
JOIN booking_status     AS bs ON bs.booking_status_id = eb.booking_status_id
LEFT JOIN (SELECT booking_id,
                  SUM(fine_amount)                                           AS total_fine,
                  SUM(fine_amount) FILTER (WHERE fine_status = 'UNPAID')     AS unpaid_fine
           FROM fines GROUP BY booking_id) AS f ON f.booking_id = eb.booking_id
WHERE eb.booking_status_id IN (SELECT booking_status_id FROM booking_status
                               WHERE booking_status_name IN ('RECEIVED', 'OVERDUE', 'RETURNED'))
  AND COALESCE(eb.actual_return_date::date, CURRENT_DATE) > eb.expected_return_date::date;

-- ---------------------------------------------------------------------
-- View 4 : ติดตามงานแจ้งซ่อม (ระยะเวลาที่ค้าง / ใช้ซ่อมจริง + จำนวนไฟล์แนบ)
-- ---------------------------------------------------------------------
CREATE VIEW v_maintenance_tracking_summary WITH (security_invoker = true) AS
SELECT mb.booking_id,
       mb.booking_code,
       mb.repair_title,
       r.resource_code,
       r.resource_name,
       rc.type_name                                  AS resource_category,
       r.location,
       u.full_name                                   AS reporter_name,
       bs.booking_status_name                        AS repair_status,
       mb.reported_date,
       h.completed_date,
       ROUND(EXTRACT(EPOCH FROM (COALESCE(h.completed_date, CURRENT_TIMESTAMP)
                                 - mb.reported_date)) / 86400.0, 1) AS days_elapsed,
       CASE WHEN h.completed_date IS NOT NULL THEN 'ปิดงานแล้ว'
            WHEN bs.booking_status_name = 'REJECTED' THEN 'ปฏิเสธ'
            ELSE 'ค้างดำเนินการ' END                  AS tracking_state,
       COALESCE(a.attachment_count, 0)               AS attachment_count
FROM maintenance_bookings AS mb
JOIN users                AS u  ON u.user_id            = mb.user_id
JOIN resources            AS r  ON r.resource_id        = mb.resource_id
JOIN resource_categories  AS rc ON rc.type_id           = r.type_id
JOIN booking_status       AS bs ON bs.booking_status_id = mb.booking_status_id
LEFT JOIN (SELECT mh.booking_id, MAX(mh.action_date) AS completed_date
           FROM maintenance_booking_history mh
           JOIN booking_actions ba ON ba.action_id = mh.action_id
           WHERE ba.action_name = 'COMPLETE'
           GROUP BY mh.booking_id) AS h ON h.booking_id = mb.booking_id
LEFT JOIN (SELECT booking_id, COUNT(booking_id) AS attachment_count
           FROM attachments GROUP BY booking_id) AS a ON a.booking_id = mb.booking_id;

-- ---------------------------------------------------------------------
-- View 5 : การใช้ประโยชน์ทรัพยากร (ห้อง / เครื่องพิมพ์ / อุปกรณ์) รายชิ้น
--   ห้อง/เครื่องพิมพ์ : utilization_pct = ชั่วโมงที่ถูกจอง / ชั่วโมงที่เปิดให้จองทั้งหมด
--   อุปกรณ์            : usage_hours = ชั่วโมงที่ถูกยืมจริง, ไม่มีชั่วโมงเปิดให้จอง (NULL)
-- ---------------------------------------------------------------------
CREATE VIEW v_resource_utilization WITH (security_invoker = true) AS
WITH room_capacity AS (
    SELECT rs.resource_id,
           SUM(EXTRACT(EPOCH FROM (rs.end_time - rs.start_time)) / 3600.0
               * rs.max_slots) AS scheduled_hours
    FROM room_schedules rs
    GROUP BY rs.resource_id
), room_activity AS (
    SELECT rs.resource_id,
           SUM(EXTRACT(EPOCH FROM (rs.end_time - rs.start_time)) / 3600.0)
               FILTER (WHERE bs.booking_status_name IN ('APPROVED', 'COMPLETED')) AS used_hours,
           COUNT(rb.booking_id) AS total_bookings,
           COUNT(rb.booking_id)
               FILTER (WHERE bs.booking_status_name = 'COMPLETED') AS completed_bookings
    FROM room_schedules rs
    LEFT JOIN room_bookings rb ON rb.schedule_id = rs.schedule_id
    LEFT JOIN booking_status bs ON bs.booking_status_id = rb.booking_status_id
    GROUP BY rs.resource_id
), room_use AS (
    SELECT c.resource_id, c.scheduled_hours,
           COALESCE(a.used_hours, 0) AS used_hours,
           COALESCE(a.total_bookings, 0) AS total_bookings,
           COALESCE(a.completed_bookings, 0) AS completed_bookings
    FROM room_capacity c
    LEFT JOIN room_activity a ON a.resource_id = c.resource_id
), printer_capacity AS (
    SELECT ps.resource_id,
           SUM(EXTRACT(EPOCH FROM (ps.end_time - ps.start_time)) / 3600.0
               * ps.max_slots) AS scheduled_hours
    FROM printer_schedules ps
    GROUP BY ps.resource_id
), printer_activity AS (
    SELECT ps.resource_id,
           SUM(EXTRACT(EPOCH FROM (ps.end_time - ps.start_time)) / 3600.0)
               FILTER (WHERE bs.booking_status_name IN ('APPROVED', 'IN_PROGRESS', 'COMPLETED', 'RECEIVED')) AS used_hours,
           COUNT(pb.booking_id) AS total_bookings,
           COUNT(pb.booking_id)
               FILTER (WHERE bs.booking_status_name IN ('COMPLETED', 'RECEIVED')) AS completed_bookings
    FROM printer_schedules ps
    LEFT JOIN printer_bookings pb ON pb.schedule_id = ps.schedule_id
    LEFT JOIN booking_status bs ON bs.booking_status_id = pb.booking_status_id
    GROUP BY ps.resource_id
), printer_use AS (
    SELECT c.resource_id, c.scheduled_hours,
           COALESCE(a.used_hours, 0) AS used_hours,
           COALESCE(a.total_bookings, 0) AS total_bookings,
           COALESCE(a.completed_bookings, 0) AS completed_bookings
    FROM printer_capacity c
    LEFT JOIN printer_activity a ON a.resource_id = c.resource_id
), equip_use AS (
    SELECT eb.resource_id,
           CAST(NULL AS NUMERIC) AS scheduled_hours,
           SUM(EXTRACT(EPOCH FROM (
                   COALESCE(eb.actual_return_date, LEAST(eb.expected_return_date, CURRENT_TIMESTAMP))
                   - eb.borrow_date
               )) / 3600.0)
               FILTER (WHERE bs.booking_status_name IN ('RECEIVED', 'RETURNED', 'OVERDUE')) AS used_hours,
           COUNT(eb.booking_id) AS total_bookings,
           COUNT(eb.booking_id) FILTER (WHERE bs.booking_status_name = 'RETURNED') AS completed_bookings
    FROM equipment_bookings eb
    JOIN booking_status bs ON bs.booking_status_id = eb.booking_status_id
    GROUP BY eb.resource_id
)
SELECT r.resource_id,
       r.resource_code,
       r.resource_name,
       rc.type_name AS resource_category,
       rst.resource_status_name AS resource_status,
       r.location,
       COALESCE(u.total_bookings, 0) AS total_bookings,
       COALESCE(u.completed_bookings, 0) AS completed_bookings,
       ROUND(u.scheduled_hours::numeric, 1) AS scheduled_hours,
       ROUND(COALESCE(u.used_hours, 0)::numeric, 1) AS used_hours,
       ROUND(u.used_hours::numeric * 100.0
             / NULLIF(u.scheduled_hours::numeric, 0), 2) AS utilization_pct
FROM resources r
JOIN resource_categories rc ON rc.type_id = r.type_id
JOIN resource_status rst ON rst.resource_status_id = r.resource_status_id
LEFT JOIN (
    SELECT * FROM room_use
    UNION ALL SELECT * FROM printer_use
    UNION ALL SELECT * FROM equip_use
) AS u ON u.resource_id = r.resource_id
WHERE rc.type_name IN ('ROOM', 'PRINTER', 'EQUIPMENT');

-- ---------------------------------------------------------------------
-- View 6 : ผู้ใช้แต่ละคนใช้บริการกี่ครั้งในแต่ละโมดูล (User 360)
-- ---------------------------------------------------------------------
CREATE VIEW v_user_activity_summary WITH (security_invoker = true) AS
SELECT u.user_id,
       u.user_code,
       u.full_name,
       ur.role_name,
       u.user_status,
       COALESCE(rb.cnt, 0)  AS room_bookings,
       COALESCE(pb.cnt, 0)  AS printer_bookings,
       COALESCE(eb.cnt, 0)  AS equipment_bookings,
       COALESCE(mb.cnt, 0)  AS maintenance_reports,
       COALESCE(rb.cnt, 0) + COALESCE(pb.cnt, 0) + COALESCE(eb.cnt, 0) + COALESCE(mb.cnt, 0) AS total_activities,
       COALESCE(fn.unpaid, 0) AS unpaid_fines
FROM users u
JOIN user_roles ur ON ur.role_id = u.role_id
LEFT JOIN (SELECT user_id, COUNT(booking_id) cnt FROM room_bookings        GROUP BY user_id) rb ON rb.user_id = u.user_id
LEFT JOIN (SELECT user_id, COUNT(booking_id) cnt FROM printer_bookings     GROUP BY user_id) pb ON pb.user_id = u.user_id
LEFT JOIN (SELECT user_id, COUNT(booking_id) cnt FROM equipment_bookings   GROUP BY user_id) eb ON eb.user_id = u.user_id
LEFT JOIN (SELECT user_id, COUNT(booking_id) cnt FROM maintenance_bookings GROUP BY user_id) mb ON mb.user_id = u.user_id
LEFT JOIN (SELECT e.user_id, SUM(f.fine_amount) AS unpaid
           FROM fines f JOIN equipment_bookings e ON e.booking_id = f.booking_id
           WHERE f.fine_status = 'UNPAID' GROUP BY e.user_id) fn ON fn.user_id = u.user_id;

-- ---------------------------------------------------------------------
-- View 7 : แนวโน้มจำนวนรายการรายเดือน แยกโมดูล (ใช้ทำกราฟเส้น/แท่ง)
-- ---------------------------------------------------------------------
CREATE VIEW v_monthly_booking_trend WITH (security_invoker = true) AS
SELECT DATE_TRUNC('month', t.event_date)::date AS month_start,
       TO_CHAR(t.event_date, 'YYYY-MM')        AS month_label,
       t.module,
       COUNT(t.user_id)                       AS total_bookings,
       COUNT(DISTINCT t.user_id)               AS distinct_users
FROM (
    SELECT rs.work_date::timestamp AS event_date, rb.user_id, 'ROOM'::text AS module
      FROM room_bookings rb JOIN room_schedules rs ON rs.schedule_id = rb.schedule_id
    UNION ALL
    SELECT ps.work_date::timestamp, pb.user_id, 'PRINTER'
      FROM printer_bookings pb JOIN printer_schedules ps ON ps.schedule_id = pb.schedule_id
    UNION ALL
    SELECT eb.borrow_date, eb.user_id, 'EQUIPMENT' FROM equipment_bookings eb
    UNION ALL
    SELECT mb.reported_date, mb.user_id, 'MAINTENANCE' FROM maintenance_bookings mb
) AS t
GROUP BY DATE_TRUNC('month', t.event_date), TO_CHAR(t.event_date, 'YYYY-MM'), t.module;

-- ---------------------------------------------------------------------
-- View 8 : ตัวชี้วัดภาพรวมระบบ (1 แถว) สำหรับการ์ด KPI บน Dashboard
-- ---------------------------------------------------------------------
CREATE VIEW v_dashboard_kpi WITH (security_invoker = true) AS
SELECT (SELECT COUNT(user_id) FROM users WHERE user_status = 'ACTIVE')                          AS active_users,
       (SELECT COUNT(resource_id) FROM resources)                                                   AS total_resources,
       (SELECT COUNT(booking_id) FROM room_bookings)                                               AS room_bookings,
       (SELECT COUNT(booking_id) FROM printer_bookings)                                            AS printer_bookings,
       (SELECT COUNT(booking_id) FROM equipment_bookings)                                          AS equipment_bookings,
       (SELECT COUNT(booking_id) FROM maintenance_bookings)                                        AS maintenance_requests,
       (SELECT COUNT(rb.booking_id) FROM room_bookings rb JOIN booking_status bs ON bs.booking_status_id = rb.booking_status_id
         WHERE bs.booking_status_name = 'PENDING')
     + (SELECT COUNT(pb.booking_id) FROM printer_bookings pb JOIN booking_status bs ON bs.booking_status_id = pb.booking_status_id
         WHERE bs.booking_status_name = 'PENDING')
     + (SELECT COUNT(eb.booking_id) FROM equipment_bookings eb JOIN booking_status bs ON bs.booking_status_id = eb.booking_status_id
         WHERE bs.booking_status_name = 'PENDING')                                        AS pending_approvals,
       (SELECT COUNT(eb.booking_id) FROM equipment_bookings eb JOIN booking_status bs ON bs.booking_status_id = eb.booking_status_id
         WHERE bs.booking_status_name = 'OVERDUE')                                        AS overdue_equipment,
       (SELECT COALESCE(SUM(fine_amount), 0) FROM fines)                                  AS total_fines,
       (SELECT COALESCE(SUM(fine_amount), 0) FROM fines WHERE fine_status = 'UNPAID')     AS unpaid_fines,
       (SELECT COUNT(mb.booking_id) FROM maintenance_bookings mb JOIN booking_status bs ON bs.booking_status_id = mb.booking_status_id
         WHERE bs.booking_status_name IN ('PENDING', 'APPROVED', 'IN_PROGRESS'))          AS open_maintenance,
       (SELECT ROUND(AVG(utilization_pct), 2) FROM v_resource_utilization
         WHERE resource_category = 'ROOM')                                                AS avg_room_utilization_pct;

-- #####################################################################
-- 4) 002 โมดูลจองห้อง
-- #####################################################################
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

-- #####################################################################
-- 5) 003 ช่วงเวลาห้องสาธิต (นับจากวันที่รัน)
-- #####################################################################
-- =====================================================================
-- 003 : สร้างช่วงเวลาจองห้องล่วงหน้า 14 วัน (ข้อมูลสำหรับทดสอบ/สาธิต)
--   * ห้องทุกห้องที่ใช้งานได้ วันจันทร์-ศุกร์ วันละ 3 ช่วง
--   * รันซ้ำได้ ไม่สร้างซ้ำ (ใช้ unique ของตารางกัน)
--   * ควรรันอีกครั้งก่อนวันสาธิต เพื่อให้มีช่วงเวลาในอนาคตเสมอ
-- =====================================================================
INSERT INTO room_schedules (resource_id, work_date, start_time, end_time, max_slots, schedule_status_id)
SELECT r.resource_id,
       d::date,
       s.start_time,
       s.end_time,
       1,
       (SELECT schedule_status_id FROM schedule_status WHERE schedule_status_name = 'AVAILABLE')
FROM resources r
JOIN resource_categories rc ON rc.type_id = r.type_id AND rc.type_name = 'ROOM'
JOIN resource_status rst    ON rst.resource_status_id = r.resource_status_id
CROSS JOIN generate_series(CURRENT_DATE + 1, CURRENT_DATE + 14, INTERVAL '1 day') AS d
CROSS JOIN (VALUES (TIME '09:00', TIME '11:00'),
                   (TIME '13:00', TIME '15:00'),
                   (TIME '15:00', TIME '17:00')) AS s(start_time, end_time)
WHERE rst.resource_status_name NOT IN ('BROKEN', 'UNDER_MAINTENANCE', 'OUT_OF_SERVICE')
  AND EXTRACT(ISODOW FROM d) BETWEEN 1 AND 5
ON CONFLICT (resource_id, work_date, start_time, end_time) DO NOTHING;

-- #####################################################################
-- 6) 004 จองเครื่องพิมพ์ 3 มิติ
-- #####################################################################
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

-- #####################################################################
-- 7) 005 ช่วงเวลาเครื่องพิมพ์สาธิต (นับจากวันที่รัน)
-- #####################################################################
-- 005_demo_printer_schedules.sql : สล็อตเครื่องพิมพ์ 4 ชม. 2 ช่วง/วัน (09-13, 13-17)
-- วันทำการถัดไป 14 วัน เฉพาะเครื่อง AVAILABLE | รันซ้ำได้ก่อนวันสาธิต
INSERT INTO printer_schedules (resource_id, work_date, start_time, end_time, max_slots, schedule_status_id)
SELECT r.resource_id, d::date, t.s, t.e, 1,
       (SELECT schedule_status_id FROM schedule_status WHERE schedule_status_name = 'AVAILABLE')
FROM resources r
JOIN resource_categories rc ON rc.type_id = r.type_id AND rc.type_name = 'PRINTER'
JOIN resource_status rs ON rs.resource_status_id = r.resource_status_id AND rs.resource_status_name = 'AVAILABLE'
CROSS JOIN generate_series(
  (now() AT TIME ZONE 'Asia/Bangkok')::date + 1,
  (now() AT TIME ZONE 'Asia/Bangkok')::date + 20, interval '1 day') AS d
CROSS JOIN (VALUES ('09:00'::time,'13:00'::time), ('13:00'::time,'17:00'::time)) AS t(s,e)
WHERE extract(isodow FROM d) < 6
  AND d::date <= (now() AT TIME ZONE 'Asia/Bangkok')::date + 20
ON CONFLICT (resource_id, work_date, start_time, end_time) DO NOTHING;

-- #####################################################################
-- 8) 006 วิวเครื่องพิมพ์ + ห้องอนุมัติตนเอง
-- #####################################################################
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

-- #####################################################################
-- 9) 007 ยืม-คืนอุปกรณ์
-- #####################################################################
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

-- #####################################################################
-- 10) 008 แจ้งซ่อม
-- #####################################################################
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

-- #####################################################################
-- 11) 009 Dashboard v2
-- #####################################################################
-- =====================================================================
-- 009_dashboard_v2.sql  |  Dashboard v2-1: view สรุปรายระบบ (ไม่มีข้อมูลส่วนบุคคล)
-- ทำซ้ำได้ (CREATE OR REPLACE) | รันใน Supabase SQL Editor | ไม่แก้ view/ตารางเดิม
--   v_dashboard_module_kpi          : KPI รายระบบ (1 แถวต่อ KPI)
--   v_dashboard_status_distribution : สัดส่วนสถานะรายระบบ
--   v_dashboard_recent_items        : รายการล่าสุด / ที่ต้องดำเนินการ (ไม่มีชื่อผู้ใช้/วัตถุประสงค์)
--   v_dashboard_repair_ranking      : ทรัพยากรที่ถูกแจ้งซ่อมมากที่สุด
--   v_dashboard_module_breakdown    : สถิติเฉพาะระบบ (ช่วงเวลา/วัสดุ/ค่าปรับ/ประเภทงานซ่อม)
-- =====================================================================

-- 1) KPI รายระบบ -------------------------------------------------------
CREATE OR REPLACE VIEW v_dashboard_module_kpi WITH (security_invoker = true) AS
WITH today AS (SELECT (now() AT TIME ZONE 'Asia/Bangkok')::date AS d),
rb AS (
  SELECT bs.booking_status_name AS s, rs.work_date
  FROM room_bookings b
  JOIN booking_status bs ON bs.booking_status_id = b.booking_status_id
  JOIN room_schedules rs ON rs.schedule_id = b.schedule_id
),
pb AS (
  SELECT bs.booking_status_name AS s
  FROM printer_bookings b
  JOIN booking_status bs ON bs.booking_status_id = b.booking_status_id
),
eb AS (
  SELECT bs.booking_status_name AS s
  FROM equipment_bookings b
  JOIN booking_status bs ON bs.booking_status_id = b.booking_status_id
),
mb AS (
  SELECT bs.booking_status_name AS s,
         COALESCE(m.completed_at, h.completed_date) AS completed_at,
         m.reported_date
  FROM maintenance_bookings m
  JOIN booking_status bs ON bs.booking_status_id = m.booking_status_id
  LEFT JOIN (
    SELECT mh.booking_id, max(mh.action_date) AS completed_date
    FROM maintenance_booking_history mh
    JOIN booking_actions ba ON ba.action_id = mh.action_id AND ba.action_name = 'COMPLETE'
    GROUP BY mh.booking_id
  ) h ON h.booking_id = m.booking_id
)
SELECT 'ROOM'::text AS module, 'total'::text AS kpi_key, count(*)::numeric AS kpi_value FROM rb
UNION ALL SELECT 'ROOM', 'pending',  count(*) FILTER (WHERE s = 'PENDING')::numeric FROM rb
UNION ALL SELECT 'ROOM', 'upcoming', count(*) FILTER (WHERE s = 'APPROVED' AND work_date >= (SELECT d FROM today))::numeric FROM rb
UNION ALL SELECT 'ROOM', 'avg_utilization_pct',
       COALESCE(round(avg(utilization_pct), 1), 0)
  FROM v_resource_utilization WHERE resource_category = 'ROOM'
UNION ALL SELECT 'PRINTER', 'total',           count(*)::numeric FROM pb
UNION ALL SELECT 'PRINTER', 'pending',         count(*) FILTER (WHERE s = 'PENDING')::numeric FROM pb
UNION ALL SELECT 'PRINTER', 'in_progress',     count(*) FILTER (WHERE s = 'IN_PROGRESS')::numeric FROM pb
UNION ALL SELECT 'PRINTER', 'awaiting_pickup', count(*) FILTER (WHERE s = 'COMPLETED')::numeric FROM pb
UNION ALL SELECT 'EQUIPMENT', 'on_loan', count(*) FILTER (WHERE s = 'RECEIVED')::numeric FROM eb
UNION ALL SELECT 'EQUIPMENT', 'overdue', count(*) FILTER (WHERE s = 'OVERDUE')::numeric FROM eb
UNION ALL SELECT 'EQUIPMENT', 'pending', count(*) FILTER (WHERE s = 'PENDING')::numeric FROM eb
UNION ALL SELECT 'EQUIPMENT', 'unpaid_fines',
       COALESCE((SELECT sum(fine_amount) FROM fines WHERE fine_status = 'UNPAID'), 0)
UNION ALL SELECT 'MAINTENANCE', 'pending',     count(*) FILTER (WHERE s IN ('PENDING','APPROVED'))::numeric FROM mb
UNION ALL SELECT 'MAINTENANCE', 'in_progress', count(*) FILTER (WHERE s = 'IN_PROGRESS')::numeric FROM mb
UNION ALL SELECT 'MAINTENANCE', 'completed_30d',
       count(*) FILTER (WHERE s = 'COMPLETED' AND completed_at >= now() - interval '30 days')::numeric FROM mb
UNION ALL SELECT 'MAINTENANCE', 'avg_repair_days',
       COALESCE(round(avg(EXTRACT(epoch FROM (completed_at - reported_date)) / 86400.0)
                      FILTER (WHERE s = 'COMPLETED' AND completed_at IS NOT NULL), 1), 0)
  FROM mb;

-- 2) สัดส่วนสถานะรายระบบ ----------------------------------------------
CREATE OR REPLACE VIEW v_dashboard_status_distribution WITH (security_invoker = true) AS
SELECT 'ROOM'::text AS module, bs.booking_status_name AS status, count(*) AS total
  FROM room_bookings b JOIN booking_status bs ON bs.booking_status_id = b.booking_status_id GROUP BY 2
UNION ALL
SELECT 'PRINTER', bs.booking_status_name, count(*)
  FROM printer_bookings b JOIN booking_status bs ON bs.booking_status_id = b.booking_status_id GROUP BY 2
UNION ALL
SELECT 'EQUIPMENT', bs.booking_status_name, count(*)
  FROM equipment_bookings b JOIN booking_status bs ON bs.booking_status_id = b.booking_status_id GROUP BY 2
UNION ALL
SELECT 'MAINTENANCE', bs.booking_status_name, count(*)
  FROM maintenance_bookings b JOIN booking_status bs ON bs.booking_status_id = b.booking_status_id GROUP BY 2;

-- 3) รายการล่าสุด/ที่ต้องดำเนินการ (ไม่มีชื่อผู้ใช้ ไม่มีวัตถุประสงค์) -----------
-- needs_action = รอเจ้าหน้าที่ตัดสินใจ (PENDING, แจ้งซ่อมที่ APPROVED เดิม) หรืออุปกรณ์เกินกำหนดคืน
CREATE OR REPLACE VIEW v_dashboard_recent_items WITH (security_invoker = true) AS
SELECT 'ROOM'::text AS module, b.booking_id, b.booking_code,
       r.resource_name AS item_name,
       bs.booking_status_name AS status,
       b.booking_time AS event_at,
       rs.work_date AS event_date,
       (bs.booking_status_name = 'PENDING') AS needs_action
FROM room_bookings b
JOIN booking_status bs ON bs.booking_status_id = b.booking_status_id
JOIN room_schedules rs ON rs.schedule_id = b.schedule_id
JOIN resources r ON r.resource_id = rs.resource_id
UNION ALL
SELECT 'PRINTER', b.booking_id, b.booking_code, r.resource_name, bs.booking_status_name,
       b.booking_time, ps.work_date,
       (bs.booking_status_name = 'PENDING')
FROM printer_bookings b
JOIN booking_status bs ON bs.booking_status_id = b.booking_status_id
JOIN printer_schedules ps ON ps.schedule_id = b.schedule_id
JOIN resources r ON r.resource_id = ps.resource_id
UNION ALL
SELECT 'EQUIPMENT', b.booking_id, b.booking_code, r.resource_name, bs.booking_status_name,
       b.borrow_date, (b.borrow_date AT TIME ZONE 'Asia/Bangkok')::date,
       (bs.booking_status_name IN ('PENDING','OVERDUE'))
FROM equipment_bookings b
JOIN booking_status bs ON bs.booking_status_id = b.booking_status_id
JOIN resources r ON r.resource_id = b.resource_id
UNION ALL
SELECT 'MAINTENANCE', m.booking_id, m.booking_code,
       COALESCE(r.resource_name, NULLIF(btrim(m.location_text), ''), '-'),
       bs.booking_status_name,
       m.reported_date, (m.reported_date AT TIME ZONE 'Asia/Bangkok')::date,
       (bs.booking_status_name IN ('PENDING','APPROVED'))
FROM maintenance_bookings m
JOIN booking_status bs ON bs.booking_status_id = m.booking_status_id
LEFT JOIN resources r ON r.resource_id = m.resource_id;

-- 4) ทรัพยากรที่ถูกแจ้งซ่อมมากที่สุด --------------------------------------
CREATE OR REPLACE VIEW v_dashboard_repair_ranking WITH (security_invoker = true) AS
SELECT r.resource_id, r.resource_code, r.resource_name, rc.type_name AS resource_category,
       count(*) AS repair_count,
       count(*) FILTER (WHERE bs.booking_status_name IN ('PENDING','APPROVED','IN_PROGRESS')) AS open_count
FROM maintenance_bookings m
JOIN resources r ON r.resource_id = m.resource_id
JOIN resource_categories rc ON rc.type_id = r.type_id
JOIN booking_status bs ON bs.booking_status_id = m.booking_status_id
WHERE bs.booking_status_name NOT IN ('REJECTED','CANCELLED')
GROUP BY r.resource_id, r.resource_code, r.resource_name, rc.type_name;

-- 5) สถิติเฉพาะระบบ ---------------------------------------------------
-- breakdown_type: SLOT (ห้อง: ช่วงเวลา) | MATERIAL (เครื่องพิมพ์: วัสดุ, value2 = น้ำหนักรวม g)
--                 FINE_STATUS (อุปกรณ์: ค่าปรับ, value2 = ยอดเงิน) | REPAIR_CATEGORY (แจ้งซ่อม: ประเภท, value2 = วันซ่อมเฉลี่ย)
CREATE OR REPLACE VIEW v_dashboard_module_breakdown WITH (security_invoker = true) AS
SELECT 'ROOM'::text AS module, 'SLOT'::text AS breakdown_type,
       to_char(rs.start_time, 'HH24:MI') || '-' || to_char(rs.end_time, 'HH24:MI') AS group_key,
       count(*) AS total, NULL::numeric AS value2
FROM room_bookings b
JOIN booking_status bs ON bs.booking_status_id = b.booking_status_id
JOIN room_schedules rs ON rs.schedule_id = b.schedule_id
WHERE bs.booking_status_name NOT IN ('REJECTED','CANCELLED')
GROUP BY rs.start_time, rs.end_time
UNION ALL
SELECT 'PRINTER', 'MATERIAL', COALESCE(NULLIF(btrim(b.material), ''), 'ไม่ระบุ'),
       count(*), round(COALESCE(sum(b.est_weight_g), 0), 1)
FROM printer_bookings b
JOIN booking_status bs ON bs.booking_status_id = b.booking_status_id
WHERE bs.booking_status_name NOT IN ('REJECTED','CANCELLED')
GROUP BY 3
UNION ALL
SELECT 'EQUIPMENT', 'FINE_STATUS', f.fine_status, count(*), COALESCE(sum(f.fine_amount), 0)
FROM fines f GROUP BY f.fine_status
UNION ALL
SELECT 'MAINTENANCE', 'REPAIR_CATEGORY', COALESCE(rc.type_name, 'OTHER'), count(*),
       round(avg(EXTRACT(epoch FROM (h.completed_date - m.reported_date)) / 86400.0)
             FILTER (WHERE bs.booking_status_name = 'COMPLETED' AND h.completed_date IS NOT NULL), 1)
FROM maintenance_bookings m
JOIN booking_status bs ON bs.booking_status_id = m.booking_status_id
LEFT JOIN resources r ON r.resource_id = m.resource_id
LEFT JOIN resource_categories rc ON rc.type_id = r.type_id
LEFT JOIN (
  SELECT mh.booking_id, max(mh.action_date) AS completed_date
  FROM maintenance_booking_history mh
  JOIN booking_actions ba ON ba.action_id = mh.action_id AND ba.action_name = 'COMPLETE'
  GROUP BY mh.booking_id
) h ON h.booking_id = m.booking_id
WHERE bs.booking_status_name NOT IN ('REJECTED','CANCELLED')
GROUP BY COALESCE(rc.type_name, 'OTHER');

-- 6) สิทธิ์: เฉพาะ service_role (BE) -----------------------------------
REVOKE ALL ON v_dashboard_module_kpi, v_dashboard_status_distribution, v_dashboard_recent_items,
              v_dashboard_repair_ranking, v_dashboard_module_breakdown
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON v_dashboard_module_kpi, v_dashboard_status_distribution, v_dashboard_recent_items,
                v_dashboard_repair_ranking, v_dashboard_module_breakdown
  TO service_role;

-- #####################################################################
-- 12) 010 แก้วิวติดตามงานซ่อม
-- #####################################################################
-- =====================================================================
-- 010_maintenance_tracking_view_fix.sql  |  Dashboard v2-2
-- แก้ v_maintenance_tracking_summary ให้รองรับระบบแจ้งซ่อมใหม่ (migration 008)
--   1) งานที่ผู้ใช้พิมพ์สถานที่เอง (ไม่ผูกทรัพยากร) ต้องไม่หายจากตาราง (LEFT JOIN)
--   2) สถานะ CANCELLED ต้องไม่ถูกนับเป็น "ค้างดำเนินการ" (แสดงเป็น "ยกเลิก")
-- คอลัมน์เดิมครบทุกตัว ชื่อ/ชนิดเดิม จึงไม่กระทบ FE และ analysis_queries | ทำซ้ำได้
-- =====================================================================
CREATE OR REPLACE VIEW v_maintenance_tracking_summary WITH (security_invoker = true) AS
SELECT mb.booking_id,
       mb.booking_code,
       mb.repair_title,
       r.resource_code,
       COALESCE(r.resource_name, NULLIF(btrim(mb.location_text), ''))::varchar(255) AS resource_name,
       COALESCE(rc.type_name, 'OTHER')::varchar(100)                               AS resource_category,
       COALESCE(r.location, NULLIF(btrim(mb.location_text), ''))::varchar(255)      AS location,
       u.full_name AS reporter_name,
       bs.booking_status_name AS repair_status,
       mb.reported_date,
       h.completed_date,
       round((EXTRACT(epoch FROM (COALESCE(h.completed_date, CURRENT_TIMESTAMP) - mb.reported_date)) / 86400.0), 1) AS days_elapsed,
       CASE
         WHEN h.completed_date IS NOT NULL                 THEN 'ปิดงานแล้ว'
         WHEN bs.booking_status_name = 'REJECTED'          THEN 'ปฏิเสธ'
         WHEN bs.booking_status_name = 'CANCELLED'         THEN 'ยกเลิก'
         ELSE 'ค้างดำเนินการ'
       END::text AS tracking_state,
       COALESCE(a.attachment_count, 0::bigint) AS attachment_count
FROM maintenance_bookings mb
JOIN users u            ON u.user_id = mb.user_id
JOIN booking_status bs  ON bs.booking_status_id = mb.booking_status_id
LEFT JOIN resources r             ON r.resource_id = mb.resource_id
LEFT JOIN resource_categories rc  ON rc.type_id = r.type_id
LEFT JOIN (
  SELECT mh.booking_id, max(mh.action_date) AS completed_date
  FROM maintenance_booking_history mh
  JOIN booking_actions ba ON ba.action_id = mh.action_id
  WHERE ba.action_name = 'COMPLETE'
  GROUP BY mh.booking_id
) h ON h.booking_id = mb.booking_id
LEFT JOIN (
  SELECT booking_id, count(booking_id) AS attachment_count FROM attachments GROUP BY booking_id
) a ON a.booking_id = mb.booking_id;

-- #####################################################################
-- 13) 011 AI Chat
-- #####################################################################
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

-- #####################################################################
-- 14) 012 Admin จัดการทรัพยากร
-- #####################################################################
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

-- #####################################################################
-- 15) 013 Admin จัดการผู้ใช้
-- #####################################################################
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
