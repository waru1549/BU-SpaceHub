# รายงานส่วนบุคคล: โมดูลระบบจัดการห้อง (Room Management System)

**โครงงาน:** BU SpaceHub (CRMS – Campus Resource Management System)
**รายวิชา:** Database System
**ผู้จัดทำ:** ______________________ รหัสนักศึกษา: ______________

---

## บทนำ

รายงานนี้อธิบายการออกแบบฐานข้อมูลของโมดูลระบบจัดการห้อง โดยแบ่งเป็น 2 หัวข้อหลัก ได้แก่ (1) การทำนอร์มัลไลเซชัน (Normalization) จาก UNF ถึง 3NF และ (2) การออกแบบ View ด้วย PostgreSQL ทั้งนี้อ้างอิงตามสคีมาสุดท้ายของโปรเจกต์ ซึ่งตารางของโมดูลห้องใช้ชื่อ `room_schedules` และ `room_bookings`

**ข้อสมมติที่ใช้ในรายงาน:**

- กำหนดให้คีย์ของ UNF เป็นคีย์ผสม (Booking_ID, Schedule_ID) เพื่อให้ขั้นตอน 2NF มีการแยกความสัมพันธ์บางส่วน (Partial Dependency) อย่างชัดเจน
- ER Diagram สุดท้ายของโปรเจกต์ไม่มีตารางอุปกรณ์ของห้อง จึงแสดง `booking_equipment` เป็นผลลัพธ์ของขั้น 1NF และอธิบายการจัดการอุปกรณ์ในสคีมาจริงไว้ในหัวข้อ 1.4

---

## ส่วนที่ 1: การทำนอร์มัลไลเซชัน (Normalization)

### 1.0 รูปแบบที่ยังไม่ผ่านการทำนอร์มัลไลเซชัน (UNF)

```text
ROOM_BOOKING_UNF (
    Booking_ID, User_ID, Full_Name, Role_Name,
    Room_ID, Room_Code, Room_Name, Location, Capacity,
    Schedule_ID, Work_Date, Start_Time, End_Time,
    Status_Name, Booking_Purpose,
    Equipment_List
)
```

ตัวอย่างค่าใน Equipment_List: `Projector, Microphone, Whiteboard`

**ปัญหาที่พบ:**

- Equipment_List เก็บหลายค่าไว้ในเซลล์เดียว
- ข้อมูลผู้ใช้ ห้อง และสถานะ ถูกเก็บซ้ำในทุกแถวการจอง จึงเกิดความผิดปกติในการเพิ่ม แก้ไข และลบข้อมูล (Insert, Update, Delete Anomalies) เช่น การเปลี่ยนชื่อห้องต้องแก้หลายแถว

### 1.1 First Normal Form (1NF): ค่าต้องเป็นอะตอมิก

**กฎ:** ทุกแอตทริบิวต์เก็บค่าเดียว (Atomic) และไม่มีกลุ่มข้อมูลซ้ำ

**การดำเนินการ:** แยก Equipment_List ออกเป็นตารางใหม่ โดยให้อุปกรณ์ 1 ชิ้นต่อ 1 แถว และเชื่อมโยงกับการจอง

```text
BOOKING_1NF (
    PK (Booking_ID, Schedule_ID),
    User_ID, Full_Name, Role_Name,
    Room_ID, Room_Code, Room_Name, Location, Capacity,
    Work_Date, Start_Time, End_Time,
    Status_Name, Booking_Purpose
)

BOOKING_EQUIPMENT (
    PK (Booking_ID, Equipment_Name),
    FK Booking_ID -> BOOKING_1NF
)
```

**เหตุผล:** ทุกเซลล์เก็บค่าเดียว จึงค้นหา นับ และเพิ่มอุปกรณ์ได้โดยไม่ต้องตัดสตริง

### 1.2 Second Normal Form (2NF): กำจัดความสัมพันธ์บางส่วน

**กฎ:** ต้องอยู่ใน 1NF และทุกแอตทริบิวต์ที่ไม่ใช่คีย์ต้องขึ้นกับคีย์หลัก "ทั้งหมด" ไม่ใช่เพียงบางส่วน

**ความสัมพันธ์ที่พบ** ใน `BOOKING_1NF` ซึ่งมีคีย์ผสม (Booking_ID, Schedule_ID):

| ตัวกำหนด (ส่วนหนึ่งของคีย์) | กำหนดค่าของ                                                                          |
|-----------------------------|--------------------------------------------------------------------------------------|
| Booking_ID                  | User_ID, Full_Name, Role_Name, Status_Name, Booking_Purpose                          |
| Schedule_ID                 | Room_ID, Room_Code, Room_Name, Location, Capacity, Work_Date, Start_Time, End_Time   |

ทั้งสองกลุ่มขึ้นกับคีย์เพียงบางส่วน จึงเป็น Partial Dependency

**การดำเนินการ:** แยกตารางดังนี้

```text
ROOM_SCHEDULE_2NF (
    PK Schedule_ID,
    Room_ID, Room_Code, Room_Name, Location, Capacity,
    Work_Date, Start_Time, End_Time
)

BOOKING_2NF (
    PK Booking_ID,
    FK Schedule_ID -> ROOM_SCHEDULE_2NF,
    User_ID, Full_Name, Role_Name,
    Status_Name, Booking_Purpose
)

BOOKING_EQUIPMENT (
    PK (Booking_ID, Equipment_Name),
    FK Booking_ID -> BOOKING_2NF
)
```

**เหตุผล:** รายละเอียดของช่วงเวลาให้บริการ (Schedule) ถูกเก็บเพียงครั้งเดียว และหลายการจองอ้างอิงถึงได้ ตรงกับความสัมพันธ์ `room_schedules (1) -> room_bookings (N)` ที่ควบคุมด้วย `max_slots`

### 1.3 Third Normal Form (3NF): กำจัดความสัมพันธ์แบบส่งผ่าน

**กฎ:** ต้องอยู่ใน 2NF และแอตทริบิวต์ที่ไม่ใช่คีย์ต้องไม่ขึ้นกับแอตทริบิวต์ที่ไม่ใช่คีย์ด้วยกัน

**ความสัมพันธ์แบบส่งผ่าน (Transitive Dependency) ที่พบ:**

| ตาราง              | ความสัมพันธ์แบบส่งผ่าน                                                       |
|--------------------|------------------------------------------------------------------------------|
| `BOOKING_2NF`      | Booking_ID -> User_ID -> Full_Name, Role_Name (และ Role_ID -> Role_Name)     |
| `BOOKING_2NF`      | Booking_ID -> Status -> Status_Name                                          |
| `ROOM_SCHEDULE_2NF`| Schedule_ID -> Room_ID -> Room_Code, Room_Name, Location, Capacity           |

**การดำเนินการ:** แยกตัวกำหนดแต่ละตัวออกเป็นตารางของตัวเอง และเพิ่มคีย์สังเคราะห์ (Surrogate Key) ให้ตารางอ้างอิง ได้แก่ `role_id` และ `booking_status_id`

### 1.4 ตาราง 3NF สุดท้าย (ตรงกับสคีมาโปรเจกต์)

| ตาราง                | PK                                | FK                                                                           | แอตทริบิวต์อื่น                                                                                                                      |
|----------------------|-----------------------------------|------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------|
| `user_roles`         | `role_id`                         | ไม่มี                                                                        | `role_name` (UNIQUE)                                                                                                                 |
| `users`              | `user_id`                         | `role_id` -> `user_roles`                                                    | `user_code`, `google_id`, `university_id`, `full_name`, `email` (UNIQUE), `phone`, `password_hash`, `user_status`, `created_at`, `last_login` |
| `booking_status`     | `booking_status_id`               | ไม่มี                                                                        | `booking_status_name` (UNIQUE)                                                                                                       |
| `resources`          | `resource_id`                     | `type_id` -> `resource_categories`, `resource_status_id` -> `resource_status` | `resource_code` (UNIQUE), `resource_name`, `location`, `capacity` (> 0), `created_at`                                                |
| `room_schedules`     | `schedule_id`                     | `resource_id` -> `resources`, `schedule_status_id` -> `schedule_status`      | `work_date`, `start_time`, `end_time` (> start_time), `max_slots` (> 0), `created_at`                                                |
| `room_bookings`      | `booking_id`                      | `user_id` -> `users`, `schedule_id` -> `room_schedules`, `booking_status_id` -> `booking_status` | `booking_code` (UNIQUE), `booking_time`, `booking_purpose`                                                       |
| `booking_equipment`  | (`booking_id`, `equipment_name`)  | `booking_id` -> `room_bookings`                                              | ไม่มี                                                                                                                                |

**หมายเหตุเรื่องอุปกรณ์:** ER Diagram สุดท้ายของโปรเจกต์ไม่มีตาราง `booking_equipment` เพราะอุปกรณ์ถูกแยกเป็นหมวดทรัพยากรของตัวเองพร้อมกระบวนการจองของมันเอง ดังนั้นแอตทริบิวต์ Equipment_List จึงถูกครอบคลุมโดยโมดูลอุปกรณ์แทนการมีตารางลูกในโมดูลห้อง หากต้องการแสดงในโมดูลห้อง ให้คงตาราง `booking_equipment` ตามข้างต้นไว้

**ผลลัพธ์ของการแยกตาราง:**

- ข้อเท็จจริงแต่ละอย่างถูกเก็บเพียงครั้งเดียว การเปลี่ยนชื่อห้องหรือบทบาทผู้ใช้แก้ที่แถวเดียว
- ไม่มี Partial หรือ Transitive Dependency เหลืออยู่ จึงไม่เกิดความผิดปกติของข้อมูล
- FK บังคับความสมบูรณ์เชิงอ้างอิง และตารางอ้างอิงช่วยให้ชื่อสถานะและบทบาทสอดคล้องกันทั้งระบบ

---

## ส่วนที่ 2: การออกแบบ View (PostgreSQL)

ทั้งสอง View ใช้ `security_invoker = true` ตามแนวทางของโปรเจกต์ เพื่อให้นโยบาย Row Level Security (RLS) ของผู้เรียกใช้ยังมีผลกับการดึงข้อมูลผ่าน View

### 2.1 View ที่ 1: `v_room_booking_summary`

```sql
CREATE OR REPLACE VIEW v_room_booking_summary
WITH (security_invoker = true) AS
SELECT rb.booking_id,
       rb.booking_code,
       u.user_id,
       u.full_name            AS user_name,
       ur.role_name           AS user_role,
       r.resource_id,
       r.resource_code        AS room_code,
       r.resource_name        AS room_name,
       r.location,
       r.capacity,
       rs.work_date,
       rs.start_time,
       rs.end_time,
       EXTRACT(EPOCH FROM (rs.end_time - rs.start_time)) / 3600.0 AS booked_hours,
       bs.booking_status_name AS booking_status,
       rb.booking_purpose,
       rb.booking_time
FROM room_bookings  AS rb
JOIN users          AS u  ON u.user_id            = rb.user_id
JOIN user_roles     AS ur ON ur.role_id           = u.role_id
JOIN room_schedules AS rs ON rs.schedule_id       = rb.schedule_id
JOIN resources      AS r  ON r.resource_id        = rs.resource_id
JOIN booking_status AS bs ON bs.booking_status_id = rb.booking_status_id;
```

**วัตถุประสงค์:** รวมข้อมูลจากตารางที่ผ่านการทำนอร์มัลไลเซชันทั้ง 6 ตาราง กลับมาเป็นภาพรวมของการจองหนึ่งรายการ (ผู้ใช้ บทบาท ห้อง ช่วงเวลา สถานะ วัตถุประสงค์) ด้วยคิวรีเดียว เหมือนมุมมองของ UNF เดิม โดยที่ข้อมูลจริงยังไม่ซ้ำซ้อน

**กรณีการใช้งานทางธุรกิจ:**

- เจ้าหน้าที่ตรวจรายการคำขอจอง โดยกรอง `booking_status = 'PENDING'` เพื่ออนุมัติหรือปฏิเสธ
- ผู้ใช้ดูประวัติการจองของตนเองในหน้าการจอง โดย RLS จำกัดให้เห็นเฉพาะแถวของตน
- แดชบอร์ดและแชตบอตตอบคำถาม เช่น "พรุ่งนี้ห้องไหนถูกจองบ้าง"
- ผู้ดูแลระบบส่งออกรายงานการจองตามวันที่ ห้อง หรือบทบาท

**ตัวอย่างการใช้งาน:**

```sql
-- คำขอที่รออนุมัติใน 7 วันข้างหน้า
SELECT booking_code, user_name, room_name, work_date, start_time, end_time
FROM v_room_booking_summary
WHERE booking_status = 'PENDING'
  AND work_date BETWEEN CURRENT_DATE AND CURRENT_DATE + 7
ORDER BY work_date, start_time;
```

### 2.2 View ที่ 2: `v_crms_room_analytics`

```sql
CREATE OR REPLACE VIEW v_crms_room_analytics
WITH (security_invoker = true) AS
SELECT r.resource_id,
       r.resource_code                                   AS room_code,
       r.resource_name                                   AS room_name,
       r.location,
       r.capacity,
       COUNT(rb.booking_id)                              AS total_bookings,
       COUNT(rb.booking_id) FILTER (WHERE bs.booking_status_name = 'PENDING')   AS pending_bookings,
       COUNT(rb.booking_id) FILTER (WHERE bs.booking_status_name = 'APPROVED')  AS approved_bookings,
       COUNT(rb.booking_id) FILTER (WHERE bs.booking_status_name = 'REJECTED')  AS rejected_bookings,
       COUNT(rb.booking_id) FILTER (WHERE bs.booking_status_name = 'COMPLETED') AS completed_bookings,
       COUNT(DISTINCT rb.user_id)                        AS unique_requesters,
       ROUND(
           COUNT(rb.booking_id) FILTER (WHERE bs.booking_status_name IN ('APPROVED', 'COMPLETED'))
           * 100.0 / NULLIF(COUNT(rb.booking_id), 0), 2) AS approval_rate_pct
FROM resources           AS r
JOIN resource_categories AS rc ON rc.type_id = r.type_id
                              AND rc.type_name = 'ROOM'
LEFT JOIN room_schedules AS rs ON rs.resource_id       = r.resource_id
LEFT JOIN room_bookings  AS rb ON rb.schedule_id       = rs.schedule_id
LEFT JOIN booking_status AS bs ON bs.booking_status_id = rb.booking_status_id
GROUP BY r.resource_id, r.resource_code, r.resource_name, r.location, r.capacity;
```

**วัตถุประสงค์:** สรุปข้อมูลรายห้อง 1 แถวต่อ 1 ห้อง ได้แก่ จำนวนการจองแยกตามสถานะ จำนวนผู้ขอใช้ที่ไม่ซ้ำกัน และอัตราการอนุมัติ การใช้ `LEFT JOIN` ทำให้ห้องที่ไม่มีการจองเลยยังแสดงอยู่ในผลลัพธ์ และ `NULLIF` ป้องกันการหารด้วยศูนย์

**กรณีการใช้งานทางธุรกิจ:**

- ผู้ดูแลระบบและเจ้าหน้าที่ดูว่าห้องใดถูกขอใช้มากหรือน้อยที่สุด เพื่อวางแผนความจุและการบำรุงรักษา
- คอลัมน์ `pending_bookings` แสดงภาระงานอนุมัติของแต่ละห้อง
- `unique_requesters` บอกว่าห้องถูกใช้โดยคนหลากหลายหรือถูกจองซ้ำโดยคนกลุ่มเดิม
- การ์ด KPI และกราฟบนแดชบอร์ดอ่านจาก View นี้ได้โดยไม่ต้องเขียน Join หลายตารางซ้ำ

**ตัวอย่างการใช้งาน:**

```sql
-- 5 ห้องที่ถูกขอใช้มากที่สุด
SELECT room_code, room_name, total_bookings, pending_bookings, unique_requesters
FROM v_crms_room_analytics
ORDER BY total_bookings DESC
LIMIT 5;
```

---

## สรุป

การทำนอร์มัลไลเซชัน (UNF -> 1NF -> 2NF -> 3NF) ได้ตาราง 7 ตารางข้างต้น ซึ่งลดความซ้ำซ้อนและรักษาความถูกต้องของข้อมูลด้วย PK, FK และตารางอ้างอิง จากนั้น View ทั้งสองช่วยให้ผู้ใช้และผู้ดูแลระบบอ่านข้อมูลได้สะดวกโดยไม่ต้องเขียน Join ซ้ำ
