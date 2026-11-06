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