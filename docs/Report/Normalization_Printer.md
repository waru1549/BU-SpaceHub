# รายงานส่วนบุคคล: โมดูลระบบจองเครื่องพิมพ์ 3 มิติ (3D Printer Booking System)

**โครงงาน:** BU SpaceHub (CRMS – Campus Resource Management System)
**รายวิชา:** Database System
**ผู้จัดทำ:** ______________________ รหัสนักศึกษา: ______________

---

## บทนำ

รายงานนี้อธิบายการออกแบบฐานข้อมูลของโมดูลระบบจองเครื่องพิมพ์ 3 มิติ โดยแบ่งเป็น 2 หัวข้อหลัก ได้แก่ (1) การทำนอร์มัลไลเซชัน (Normalization) จาก UNF ถึง 3NF และ (2) การออกแบบ View ด้วย PostgreSQL

**ฐานของรายงาน:** ใช้ไฟล์ `3D PRINTER.sql` และเอกสาร PDF ของโมดูลเป็นสคีมาอ้างอิง ได้แก่ตาราง `bookings`, `printer_schedules`, `resources` (ที่มี `printer_code`) และ `printer_models` ส่วนสคีมา CRMS แบบรวมตั้งชื่อตารางการจองว่า `printer_bookings` และให้ `resources` มี `resource_code` กับ `resource_name` แทน จึงมีหมายเหตุการเปลี่ยนชื่อไว้ท้ายหัวข้อ 2.2

**ข้อสมมติที่ใช้ในรายงาน:**

- กำหนดให้คีย์ของ UNF เป็นคีย์ผสม (Booking_ID, Schedule_ID) เพื่อให้ขั้นตอน 2NF มีการแยกความสัมพันธ์บางส่วน (Partial Dependency) อย่างชัดเจน
- สคีมาจริงไม่มีตารางวัสดุ (Material) จึงแสดง `print_material` เป็นผลลัพธ์ของขั้น 1NF และอธิบายไว้ในหัวข้อ 1.4

---

## ส่วนที่ 1: การทำนอร์มัลไลเซชัน (Normalization)

### 1.0 รูปแบบที่ยังไม่ผ่านการทำนอร์มัลไลเซชัน (UNF)

```text
PRINT_JOB_UNF (
    Booking_ID, User_ID, Full_Name, Email,
    Model_ID, Model_Name,
    Resource_ID, Printer_Code, Location,
    Schedule_ID, Work_Date, Start_Time, End_Time,
    Status_Name, Print_Purpose,
    Material_List
)
```

ตัวอย่างค่าใน Material_List: `PLA, PETG, Resin`

**ปัญหาที่พบ:**

- Material_List เก็บหลายค่าไว้ในเซลล์เดียว
- ข้อมูลผู้ใช้ รุ่น เครื่องพิมพ์ และสถานะ ถูกเก็บซ้ำในทุกแถวการจอง
- ทำให้เกิดความผิดปกติในการแก้ไข (การเปลี่ยนชื่อรุ่นต้องแก้หลายแถว) การเพิ่ม (เพิ่มเครื่องพิมพ์ใหม่ไม่ได้ถ้ายังไม่มีการจอง) และการลบ (ลบการจองสุดท้ายแล้วข้อมูลเครื่องพิมพ์หายไปด้วย)

### 1.1 First Normal Form (1NF): ค่าต้องเป็นอะตอมิก

**กฎ:** ทุกแอตทริบิวต์เก็บค่าเดียว (Atomic) และไม่มีกลุ่มข้อมูลซ้ำ

**การดำเนินการ:** แยก Material_List ออกเป็นตารางของตัวเอง โดยให้วัสดุ 1 ชนิดต่อ 1 แถว

```text
PRINT_JOB_1NF (
    PK (Booking_ID, Schedule_ID),
    User_ID, Full_Name, Email,
    Model_ID, Model_Name,
    Resource_ID, Printer_Code, Location,
    Work_Date, Start_Time, End_Time,
    Status_Name, Print_Purpose
)

PRINT_MATERIAL (
    PK (Booking_ID, Material_Name),
    FK Booking_ID -> PRINT_JOB_1NF
)
```

**เหตุผล:** ค้นหา นับ และเพิ่มวัสดุแต่ละชนิดได้โดยไม่ต้องตัดข้อความ

### 1.2 Second Normal Form (2NF): กำจัดความสัมพันธ์บางส่วน

**กฎ:** ต้องอยู่ใน 1NF และทุกแอตทริบิวต์ที่ไม่ใช่คีย์ต้องขึ้นกับคีย์ทั้งหมด ไม่ใช่เพียงบางส่วน

**ความสัมพันธ์ที่พบ** ใน `PRINT_JOB_1NF` ซึ่งมีคีย์ผสม (Booking_ID, Schedule_ID):

| ส่วนหนึ่งของคีย์                    | กำหนดค่าของ                                            |
|-------------------------------------|--------------------------------------------------------|
| Booking_ID                          | User_ID, Full_Name, Email, Status_Name, Print_Purpose  |
| Schedule_ID                         | Resource_ID, Work_Date, Start_Time, End_Time           |
| Resource_ID (ผ่าน Schedule_ID)      | Printer_Code, Location, Model_ID, Model_Name           |

**การดำเนินการ:** แยกข้อมูลการจอง ช่วงเวลา (Schedule Slot) และข้อมูลฮาร์ดแวร์ของเครื่องพิมพ์ออกจากกัน

```text
BOOKING_2NF (
    PK Booking_ID,
    FK Schedule_ID -> SCHEDULE_2NF,
    User_ID, Full_Name, Email, Status_Name, Print_Purpose
)

SCHEDULE_2NF (
    PK Schedule_ID,
    FK Resource_ID -> PRINTER_2NF,
    Work_Date, Start_Time, End_Time
)

PRINTER_2NF (
    PK Resource_ID,
    Printer_Code, Location, Model_ID, Model_Name
)

PRINT_MATERIAL (
    PK (Booking_ID, Material_Name),
    FK Booking_ID -> BOOKING_2NF
)
```

**เหตุผล:** ช่วงเวลาถูกเก็บเพียงครั้งเดียว และรายละเอียดฮาร์ดแวร์ของเครื่องพิมพ์ก็ถูกเก็บเพียงครั้งเดียว อย่างไรก็ตาม โดยหลักการแล้ว แอตทริบิวต์ของเครื่องพิมพ์ขึ้นกับ Resource_ID ซึ่งไม่ใช่คีย์ จึงเป็น Transitive Dependency จริง ๆ ที่นี่จัดกลุ่มไว้เป็นขั้นกลาง และแยกให้เสร็จสมบูรณ์ในขั้น 3NF

### 1.3 Third Normal Form (3NF): กำจัดความสัมพันธ์แบบส่งผ่าน

**กฎ:** ต้องอยู่ใน 2NF และแอตทริบิวต์ที่ไม่ใช่คีย์ต้องไม่ขึ้นกับแอตทริบิวต์ที่ไม่ใช่คีย์ด้วยกัน

| ตาราง          | ความสัมพันธ์แบบส่งผ่าน                                                        | วิธีแก้                                  |
|----------------|-------------------------------------------------------------------------------|------------------------------------------|
| `BOOKING_2NF`  | Booking_ID -> User_ID -> Full_Name, Email (และบทบาทของผู้ใช้)                 | แยก `users` และ `user_roles`             |
| `BOOKING_2NF`  | Booking_ID -> Status -> Status_Name                                           | แยก `booking_status`                     |
| `PRINTER_2NF`  | Resource_ID -> Model_ID -> Model_Name (และผู้ผลิตกับประเภทของรุ่น)            | แยก `printer_models` และ `resource_categories` |
| `PRINTER_2NF`  | Resource_ID -> สถานะเครื่องพิมพ์                                              | แยก `resource_status`                    |
| `SCHEDULE_2NF` | Schedule_ID -> สถานะตารางเวลา                                                 | แยก `schedule_status`                    |

บทบาทผู้ใช้ ประเภทเครื่องพิมพ์ และนิยามสถานะ ไม่ได้อยู่ในรายการ UNF แต่เป็นแอตทริบิวต์ของผู้ใช้ รุ่น และเครื่องพิมพ์ในสคีมาจริง ขั้น 3NF จึงแยกแต่ละอย่างออกเป็นตารางอ้างอิง (Lookup Table) พร้อมคีย์สังเคราะห์ (Surrogate Key)

### 1.4 ตาราง 3NF สุดท้าย (ตรงกับสคีมาจริง)

| ตาราง                  | PK                               | FK                                                                                                  | แอตทริบิวต์อื่น                                                                                                                              |
|------------------------|----------------------------------|-----------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------|
| `user_roles`           | `role_id`                        | ไม่มี                                                                                               | `role_name` (UNIQUE)                                                                                                                         |
| `users`                | `user_id`                        | `role_id` -> `user_roles`                                                                           | `user_code`, `google_id` (UNIQUE), `university_id`, `full_name`, `email` (UNIQUE), `phone`, `password_hash`, `user_status`, `created_at`, `last_login` |
| `resource_categories`  | `type_id`                        | ไม่มี                                                                                               | `type_name` (UNIQUE)                                                                                                                         |
| `printer_models`       | `model_id`                       | `type_id` -> `resource_categories`                                                                  | `model_name`, `manufacturer`, `specification`                                                                                                |
| `resource_status`      | `resource_status_id`             | ไม่มี                                                                                               | `resource_status_name` (UNIQUE)                                                                                                              |
| `resources`            | `resource_id`                    | `model_id` -> `printer_models`, `resource_status_id` -> `resource_status`                           | `printer_code` (UNIQUE), `location`, `capacity` (> 0), `created_at`                                                                          |
| `schedule_status`      | `schedule_status_id`             | ไม่มี                                                                                               | `schedule_status_name` (UNIQUE)                                                                                                              |
| `printer_schedules`    | `schedule_id`                    | `resource_id` -> `resources` (ON DELETE CASCADE), `schedule_status_id` -> `schedule_status`         | `work_date`, `start_time`, `end_time` (> start_time), `max_slots` (> 0, ค่าเริ่มต้น 1), `created_at`; UNIQUE (`resource_id`, `work_date`, `start_time`, `end_time`) |
| `booking_status`       | `booking_status_id`              | ไม่มี                                                                                               | `booking_status_name` (UNIQUE)                                                                                                               |
| `bookings`             | `booking_id`                     | `user_id` -> `users`, `schedule_id` -> `printer_schedules`, `booking_status_id` -> `booking_status` | `booking_code` (UNIQUE), `booking_time`, `print_purpose`; UNIQUE (`schedule_id`)                                                             |
| `print_material`       | (`booking_id`, `material_name`)  | `booking_id` -> `bookings`                                                                          | ไม่มี                                                                                                                                        |

**หมายเหตุ:**

- ตารางหลัก 6 ตาราง (`users`, `printer_models`, `resources`, `printer_schedules`, `bookings`, `booking_status`) อยู่ในตารางข้างต้นแล้ว ส่วน `user_roles`, `resource_categories`, `resource_status` และ `schedule_status` เป็นตารางอ้างอิงที่เกิดจาก 3NF ตามหัวข้อ 1.3
- **เรื่องวัสดุ (Material):** สคีมาจริงไม่มีตารางวัสดุ ข้อมูลวัสดุถูกครอบคลุมเพียงด้วยข้อความอิสระใน `print_purpose` และ `specification` รายงานนี้แสดง `print_material` เป็นผลลัพธ์ของ 1NF และเป็นส่วนขยายเสริม
- **หนึ่งช่วงเวลา หนึ่งการจอง:** `UNIQUE(schedule_id)` ในตาราง `bookings` บังคับกฎ Booking Conflict จึงจองเครื่องพิมพ์ซ้ำในช่วงเวลาเดียวกันไม่ได้

**ผลลัพธ์ของการแยกตาราง:**

- ข้อเท็จจริงแต่ละอย่างถูกเก็บเพียงครั้งเดียว
- ไม่เหลือ Partial หรือ Transitive Dependency
- FK และตารางอ้างอิงช่วยให้ข้อมูลสอดคล้องกันทั้งระบบ

---

## ส่วนที่ 2: การออกแบบ View (PostgreSQL)

ทั้งสอง View ใช้ `security_invoker = true` ตามแนวทางของโปรเจกต์ เพื่อให้นโยบาย Row Level Security (RLS) ยังมีผลกับผู้ที่เรียกใช้ View

### 2.1 View ที่ 1: `v_printer_booking_summary`

```sql
CREATE OR REPLACE VIEW v_printer_booking_summary
WITH (security_invoker = true) AS
SELECT b.booking_id,
       b.booking_code,
       u.user_id,
       u.full_name            AS user_name,
       u.email                AS user_email,
       r.resource_id,
       r.printer_code,
       pm.model_name          AS printer_model,
       pm.manufacturer,
       r.location,
       ps.work_date,
       ps.start_time,
       ps.end_time,
       EXTRACT(EPOCH FROM (ps.end_time - ps.start_time)) / 3600.0 AS print_hours,
       bs.booking_status_name AS booking_status,
       b.print_purpose,
       b.booking_time,
       CASE
           WHEN bs.booking_status_name IN ('PENDING', 'APPROVED')
           THEN ROW_NUMBER() OVER (
                    PARTITION BY r.resource_id,
                                 (bs.booking_status_name IN ('PENDING', 'APPROVED'))
                    ORDER BY ps.work_date, ps.start_time)
       END                    AS queue_position
FROM bookings          AS b
JOIN users             AS u  ON u.user_id            = b.user_id
JOIN printer_schedules AS ps ON ps.schedule_id       = b.schedule_id
JOIN resources         AS r  ON r.resource_id        = ps.resource_id
JOIN printer_models    AS pm ON pm.model_id          = r.model_id
JOIN booking_status    AS bs ON bs.booking_status_id = b.booking_status_id;
```

**วัตถุประสงค์:** แสดงรายละเอียดงานพิมพ์ครบถ้วนในที่เดียว และกำหนดลำดับคิวปัจจุบันของแต่ละเครื่องตามเวลา คอลัมน์ `queue_position` จะมีค่าเฉพาะงานที่เป็น PENDING และ APPROVED ส่วนงานที่เสร็จสิ้นหรือถูกยกเลิกจะเป็น NULL

**กรณีการใช้งานทางธุรกิจ:**

- เจ้าหน้าที่ตรวจคิวงานพิมพ์ปัจจุบันของแต่ละเครื่อง และอนุมัติหรือปฏิเสธคำขอ PENDING
- ผู้ใช้ดูงานของตนเอง สถานะ และลำดับในคิว (RLS จำกัดให้เห็นเฉพาะแถวของตน)
- ผู้ดูแลห้องปฏิบัติการดูว่างานแต่ละงานใช้เครื่องและรุ่นใด เพื่อวางแผนเรซินหรือเส้นพลาสติก และการบำรุงรักษา
- ผู้ดูแลระบบส่งออกรายงานงานพิมพ์ตามวันที่ เครื่อง หรือผู้ใช้

**ตัวอย่างการใช้งาน:**

```sql
-- คิวที่ใช้งานอยู่ใน 7 วันข้างหน้า
SELECT printer_code, queue_position, work_date, start_time, user_name, booking_status
FROM v_printer_booking_summary
WHERE queue_position IS NOT NULL
  AND work_date BETWEEN CURRENT_DATE AND CURRENT_DATE + 7
ORDER BY printer_code, queue_position;
```

### 2.2 View ที่ 2: `v_crms_printer_analytics`

```sql
CREATE OR REPLACE VIEW v_crms_printer_analytics
WITH (security_invoker = true) AS
WITH booking_stats AS (
    SELECT ps.resource_id,
           COUNT(b.booking_id) AS total_bookings,
           COUNT(b.booking_id) FILTER (
               WHERE bs.booking_status_name IN ('APPROVED', 'COMPLETED')) AS confirmed_bookings,
           SUM(EXTRACT(EPOCH FROM (ps.end_time - ps.start_time)) / 3600.0) FILTER (
               WHERE bs.booking_status_name IN ('APPROVED', 'COMPLETED')) AS total_print_hours,
           AVG(EXTRACT(EPOCH FROM (ps.end_time - ps.start_time)) / 3600.0) FILTER (
               WHERE bs.booking_status_name IN ('APPROVED', 'COMPLETED')) AS avg_print_hours
    FROM bookings          AS b
    JOIN printer_schedules AS ps ON ps.schedule_id       = b.schedule_id
    JOIN booking_status    AS bs ON bs.booking_status_id = b.booking_status_id
    GROUP BY ps.resource_id
),
slot_stats AS (
    SELECT ps.resource_id,
           COUNT(*) AS total_schedule_slots,
           COUNT(*) FILTER (
               WHERE ss.schedule_status_name = 'AVAILABLE'
                 AND ps.work_date >= CURRENT_DATE
                 AND b.booking_id IS NULL) AS available_slots
    FROM printer_schedules AS ps
    JOIN schedule_status   AS ss ON ss.schedule_status_id = ps.schedule_status_id
    LEFT JOIN bookings     AS b  ON b.schedule_id = ps.schedule_id
                                AND b.booking_status_id IN (
                                    SELECT booking_status_id
                                    FROM booking_status
                                    WHERE booking_status_name IN ('PENDING', 'APPROVED', 'COMPLETED'))
    GROUP BY ps.resource_id
)
SELECT r.resource_id,
       r.printer_code,
       pm.model_name                                   AS printer_model,
       rc.type_name                                    AS printer_type,
       r.location,
       COALESCE(bk.total_bookings, 0)                  AS total_bookings,
       COALESCE(bk.confirmed_bookings, 0)              AS confirmed_bookings,
       ROUND(COALESCE(bk.total_print_hours, 0), 2)     AS total_print_hours,
       ROUND(COALESCE(bk.avg_print_hours, 0), 2)       AS avg_print_hours,
       COALESCE(sl.total_schedule_slots, 0)            AS total_schedule_slots,
       COALESCE(sl.available_slots, 0)                 AS available_slots
FROM resources           AS r
JOIN printer_models      AS pm ON pm.model_id = r.model_id
JOIN resource_categories AS rc ON rc.type_id  = pm.type_id
LEFT JOIN booking_stats  AS bk ON bk.resource_id = r.resource_id
LEFT JOIN slot_stats     AS sl ON sl.resource_id = r.resource_id;
```

**วัตถุประสงค์:** สรุปสถิติของเครื่องพิมพ์แต่ละเครื่องไว้ในแถวเดียว CTE สองตัวรวมข้อมูลการจองและช่วงเวลาแยกกัน แล้วจึงนำมาเชื่อมกับ `resources` เพราะถ้า Join ทั้งสองอย่างพร้อมกันในรอบเดียว แถวจะคูณกันและทำให้ตัวเลขเกินจริง การใช้ `LEFT JOIN` ร่วมกับ `COALESCE` ทำให้เครื่องพิมพ์ที่ไม่มีการจองหรือไม่มีช่วงเวลายังแสดงอยู่ โดยมีค่าเป็น 0 ชั่วโมงพิมพ์นับเฉพาะงานที่ APPROVED และ COMPLETED เพื่อไม่ให้คำขอที่รออนุมัติหรือถูกปฏิเสธทำให้ยอดการใช้งานสูงเกินจริง

**กรณีการใช้งานทางธุรกิจ:**

- ผู้ดูแลระบบดูว่าเครื่องและรุ่นใดถูกใช้มากหรือน้อยที่สุด เพื่อตัดสินใจเรื่องการจัดซื้อและการบำรุงรักษา
- เจ้าหน้าที่ดู `available_slots` เพื่อรู้ว่าเหลือช่วงเวลาว่างเท่าไร และควรเปิดตารางเพิ่มหรือไม่
- `total_print_hours` และ `avg_print_hours` ใช้ทำรายงานการใช้งานและดูความยาวงานโดยทั่วไปของแต่ละเครื่อง
- แดชบอร์ดดึงตัวชี้วัดเหล่านี้ได้โดยไม่ต้องเขียน Join ซ้ำ

**ตัวอย่างการใช้งาน:**

```sql
-- จัดอันดับเครื่องพิมพ์ตามการใช้งาน พร้อมช่วงเวลาที่ยังว่าง
SELECT printer_code, printer_model, total_bookings,
       total_print_hours, avg_print_hours, available_slots
FROM v_crms_printer_analytics
ORDER BY total_print_hours DESC;
```

**หากนำไปรันบนสคีมา CRMS แบบรวม:**

- เปลี่ยน `bookings` เป็น `printer_bookings`
- ในตาราง `resources` ของสคีมาแบบรวม ให้แทน `r.printer_code` ด้วย `r.resource_code`
- หากตารางนั้นไม่มี `model_id` ให้ตัดการ Join `printer_models` ออก แล้วใช้ `r.resource_name` แทน พร้อม Join `resource_categories` ด้วย `r.type_id`

---

## สรุป

การทำนอร์มัลไลเซชัน (UNF -> 1NF -> 2NF -> 3NF) ให้ตารางตามข้างต้น พร้อม PK, FK และตารางอ้างอิงที่ลดความซ้ำซ้อนและรักษาความถูกต้องของข้อมูล จากนั้น View ทั้งสองช่วยให้เจ้าหน้าที่ ผู้ใช้ และผู้ดูแลระบบอ่านคิวงานพิมพ์และสถิติของเครื่องพิมพ์ได้โดยไม่ต้องเขียน Join ซ้ำ
