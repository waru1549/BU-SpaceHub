# รายงานส่วนบุคคล: โมดูลระบบยืมอุปกรณ์ (Equipment Borrowing System)

**โครงงาน:** BU SpaceHub (CRMS – Campus Resource Management System)
**รายวิชา:** Database System
**ผู้จัดทำ:** ______________________ รหัสนักศึกษา: ______________

---

## บทนำ

รายงานนี้อธิบายการออกแบบฐานข้อมูลของโมดูลระบบยืมอุปกรณ์ โดยแบ่งเป็น 2 หัวข้อหลัก ได้แก่ (1) การทำนอร์มัลไลเซชัน (Normalization) จาก UNF ถึง 3NF และ (2) การออกแบบ View ด้วย PostgreSQL

**ฐานของรายงาน:** ใช้ไฟล์ `EQUIPMENT BORROWING SYSTEM.sql`, เอกสาร PDF ของโมดูล และ ER Diagram เป็นสคีมาอ้างอิง ใน ER Diagram ตารางการยืมชื่อ `equipment_bookings` แต่ไฟล์ SQL เดี่ยวของโมดูลใช้ชื่อ `bookings` ส่วนสคีมา CRMS แบบรวมมีโครงสร้างต่างออกไปเล็กน้อย จึงมีหมายเหตุการปรับชื่อไว้ท้ายหัวข้อ 2.2

**ข้อสมมติที่ใช้ในรายงาน:**

- กำหนดให้คีย์ของ UNF เป็นคีย์ผสม (Booking_ID, Resource_ID) เพื่อให้ขั้นตอน 2NF มีการแยกความสัมพันธ์บางส่วน (Partial Dependency) อย่างชัดเจน
- สคีมาจริงไม่มีตารางรายการที่ยืม (Item) จึงแสดง `borrow_item` เป็นผลลัพธ์ของขั้น 1NF และอธิบายไว้ในหัวข้อ 1.4

---

## ส่วนที่ 1: การทำนอร์มัลไลเซชัน (Normalization)

### 1.0 รูปแบบที่ยังไม่ผ่านการทำนอร์มัลไลเซชัน (UNF)

```text
EQUIPMENT_LOAN_UNF (
    Booking_ID, User_ID, Full_Name, User_Status,
    Resource_ID, Resource_Code, Resource_Name,
    Borrow_Date, Expected_Return_Date, Actual_Return_Date,
    Status_Name, Borrow_Purpose,
    Fine_Amount, Fine_Status,
    Item_List
)
```

ตัวอย่างค่าใน Item_List: `Laptop, Charger, Mouse`

**ปัญหาที่พบ:**

- Item_List เก็บหลายค่าไว้ในเซลล์เดียว
- ข้อมูลผู้ใช้ อุปกรณ์ และสถานะ ถูกเก็บซ้ำในทุกแถวการยืม
- ค่าปรับปนอยู่ในแถวการยืม ทั้งที่การยืม 1 รายการมีค่าปรับได้หลายรายการ (ตามความสัมพันธ์ `BOOKINGS (1:N) FINES`)
- เกิดความผิดปกติในการแก้ไข (การเปลี่ยนชื่ออุปกรณ์ต้องแก้หลายแถว) การเพิ่ม (เพิ่มอุปกรณ์ใหม่ไม่ได้ถ้ายังไม่มีการยืม) และการลบ (ลบรายการยืมแล้วข้อมูลผู้ใช้หรืออุปกรณ์อาจหายไปด้วย)

### 1.1 First Normal Form (1NF): ค่าต้องเป็นอะตอมิก

**กฎ:** ทุกแอตทริบิวต์เก็บค่าเดียว (Atomic) และไม่มีกลุ่มข้อมูลซ้ำ

**การดำเนินการ:** แยก Item_List ออกเป็นตารางของตัวเอง โดยให้รายการ 1 ชิ้นต่อ 1 แถว

```text
LOAN_1NF (
    PK (Booking_ID, Resource_ID),
    User_ID, Full_Name, User_Status,
    Resource_Code, Resource_Name,
    Borrow_Date, Expected_Return_Date, Actual_Return_Date,
    Status_Name, Borrow_Purpose,
    Fine_Amount, Fine_Status
)

BORROW_ITEM (
    PK (Booking_ID, Item_Name),
    FK Booking_ID -> LOAN_1NF
)
```

**เหตุผล:** ทุกเซลล์เก็บค่าเดียว จึงค้นหา นับ และเพิ่มรายการที่ยืมได้โดยไม่ต้องตัดข้อความ

### 1.2 Second Normal Form (2NF): กำจัดความสัมพันธ์บางส่วน

**กฎ:** ต้องอยู่ใน 1NF และทุกแอตทริบิวต์ที่ไม่ใช่คีย์ต้องขึ้นกับคีย์ทั้งหมด ไม่ใช่เพียงบางส่วน

**ความสัมพันธ์ที่พบ** ใน `LOAN_1NF` ซึ่งมีคีย์ผสม (Booking_ID, Resource_ID):

| ส่วนหนึ่งของคีย์ | กำหนดค่าของ                                                                                                                                  |
|------------------|----------------------------------------------------------------------------------------------------------------------------------------------|
| Booking_ID       | User_ID, Full_Name, User_Status, Borrow_Date, Expected_Return_Date, Actual_Return_Date, Status_Name, Borrow_Purpose, Fine_Amount, Fine_Status |
| Resource_ID      | Resource_Code, Resource_Name                                                                                                                 |

**การดำเนินการ:** แยกข้อมูลการยืมออกจากข้อมูลอุปกรณ์

```text
BOOKING_2NF (
    PK Booking_ID,
    FK Resource_ID -> RESOURCE_2NF,
    User_ID, Full_Name, User_Status,
    Borrow_Date, Expected_Return_Date, Actual_Return_Date,
    Status_Name, Borrow_Purpose,
    Fine_Amount, Fine_Status
)

RESOURCE_2NF (
    PK Resource_ID,
    Resource_Code, Resource_Name
)

BORROW_ITEM (
    PK (Booking_ID, Item_Name),
    FK Booking_ID -> BOOKING_2NF
)
```

**เหตุผล:** รายละเอียดอุปกรณ์ถูกเก็บเพียงครั้งเดียว และหลายการยืมอ้างอิงถึงได้ ขั้นนี้ยังเหลือค่าปรับและข้อมูลผู้ใช้ปนอยู่ในตารางการยืม ซึ่งเป็นความสัมพันธ์แบบส่งผ่านที่จะแก้ในขั้น 3NF

### 1.3 Third Normal Form (3NF): กำจัดความสัมพันธ์แบบส่งผ่าน

**กฎ:** ต้องอยู่ใน 2NF และแอตทริบิวต์ที่ไม่ใช่คีย์ต้องไม่ขึ้นกับแอตทริบิวต์ที่ไม่ใช่คีย์ด้วยกัน

| ตาราง          | ความสัมพันธ์แบบส่งผ่าน                                                                                                                | วิธีแก้                                          |
|----------------|---------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------|
| `BOOKING_2NF`  | Booking_ID -> User_ID -> Full_Name, User_Status (และบทบาทของผู้ใช้)                                                                   | แยก `users` และ `user_roles`                     |
| `BOOKING_2NF`  | Booking_ID -> Status -> Status_Name                                                                                                   | แยก `booking_status`                             |
| `BOOKING_2NF`  | Booking_ID -> Fine -> Fine_Amount, Fine_Status (ค่าปรับขึ้นกับรายการปรับ ไม่ใช่การยืมโดยตรง และ 1 การยืมมีได้หลายรายการ)              | แยก `fines`                                      |
| `RESOURCE_2NF` | Resource_ID -> Model_ID -> Resource_Name (และผู้ผลิต ข้อกำหนด และประเภทอุปกรณ์)                                                       | แยก `resource_models` และ `resource_categories`  |
| `RESOURCE_2NF` | Resource_ID -> สถานะอุปกรณ์                                                                                                           | แยก `resource_status`                            |

**ข้อสังเกตเกี่ยวกับสคีมาจริง:**

- Resource_Name ของ UNF ในสคีมาจริงคือ `model_name` ในตาราง `resource_models`
- ตาราง `resources` เก็บจำนวนชิ้นไว้ในคอลัมน์ `quantity`
- ประเภทอุปกรณ์ (`resource_categories`) มี `max_borrow_days` เป็นกฎจำนวนวันยืมสูงสุด
- การยืมในสคีมาจริงเชื่อมกับอุปกรณ์ผ่านตาราง `resource_schedules` (`schedule_id`) แทนการอ้างถึง Resource_ID โดยตรง เพื่อบังคับกฎ Borrowing Conflict ด้วยช่วงเวลาที่ไม่ซ้ำกัน

### 1.4 ตาราง 3NF สุดท้าย (ตรงกับสคีมาจริง)

| ตาราง                 | PK                              | FK                                                                                                                | แอตทริบิวต์อื่น                                                                                                                                                                                              |
|-----------------------|---------------------------------|-------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `user_roles`          | `role_id`                       | ไม่มี                                                                                                             | `role_name` (UNIQUE)                                                                                                                                                                                         |
| `users`               | `user_id`                       | `role_id` -> `user_roles`                                                                                         | `user_code`, `google_id` (UNIQUE), `university_id`, `full_name`, `email` (UNIQUE), `phone`, `password_hash`, `user_status`, `created_at`, `last_login`                                                        |
| `resource_categories` | `type_id`                       | ไม่มี                                                                                                             | `type_name` (UNIQUE), `max_borrow_days` (> 0)                                                                                                                                                                |
| `resource_models`     | `model_id`                      | `type_id` -> `resource_categories`                                                                                | `model_name`, `manufacturer`, `specification`                                                                                                                                                                |
| `resource_status`     | `resource_status_id`            | ไม่มี                                                                                                             | `resource_status_name` (UNIQUE)                                                                                                                                                                              |
| `resources`           | `resource_id`                   | `model_id` -> `resource_models`, `resource_status_id` -> `resource_status`                                        | `resource_code` (UNIQUE), `location`, `quantity` (> 0), `created_at`                                                                                                                                         |
| `schedule_status`     | `schedule_status_id`            | ไม่มี                                                                                                             | `schedule_status_name` (UNIQUE)                                                                                                                                                                              |
| `resource_schedules`  | `schedule_id`                   | `resource_id` -> `resources` (ON DELETE CASCADE), `schedule_status_id` -> `schedule_status`                       | `work_date`, `start_time`, `end_time` (> start_time), `max_slots` (> 0, ค่าเริ่มต้น 1), `created_at`; UNIQUE (`resource_id`, `work_date`, `start_time`, `end_time`)                                           |
| `booking_status`      | `booking_status_id`             | ไม่มี                                                                                                             | `booking_status_name` (UNIQUE)                                                                                                                                                                               |
| `equipment_bookings`  | `booking_id`                    | `user_id` -> `users`, `schedule_id` -> `resource_schedules` (ON DELETE CASCADE), `booking_status_id` -> `booking_status` | `booking_code` (UNIQUE), `borrow_date`, `expected_return_date` (>= borrow_date), `actual_return_date` (NULL หรือ >= borrow_date), `booking_time`, `borrow_purpose`                                         |
| `fines`               | `fine_id`                       | `booking_id` -> `equipment_bookings` (ON DELETE CASCADE)                                                          | `fine_amount` (>= 0), `fine_reason`, `fine_status` (UNPAID / PAID / WAIVED), `created_at`                                                                                                                    |
| `borrow_item`         | (`booking_id`, `item_name`)     | `booking_id` -> `equipment_bookings`                                                                              | ไม่มี                                                                                                                                                                                                        |

**หมายเหตุ:**

- ตารางหลัก 5 ตาราง (`users`, `resources`, `equipment_bookings`, `fines`, `booking_status`) อยู่ในตารางข้างต้นแล้ว ส่วน `user_roles`, `resource_categories`, `resource_models`, `resource_status`, `schedule_status` และ `resource_schedules` เป็นตารางที่เกิดจากการแยกใน 3NF และการเชื่อมช่วงเวลา
- ไฟล์ SQL เดี่ยวของโมดูลตั้งชื่อตารางการยืมว่า `bookings` ส่วนในรายงานนี้ใช้ชื่อ `equipment_bookings` ตาม ER Diagram
- **เรื่องรายการที่ยืม:** สคีมาจริงไม่มีตาราง `borrow_item` รายงานนี้แสดงเป็นผลลัพธ์ของ 1NF และเป็นส่วนขยายเสริม ข้อมูลรายการที่ยืมในระบบจริงถูกครอบคลุมด้วย `quantity` ของอุปกรณ์และข้อความใน `borrow_purpose`

**ผลลัพธ์ของการแยกตาราง:**

- ข้อเท็จจริงแต่ละอย่างถูกเก็บเพียงครั้งเดียว
- ค่าปรับแยกเป็นรายการของตัวเอง (1 การยืมมีได้หลายค่าปรับ)
- ไม่เหลือ Partial หรือ Transitive Dependency
- FK และตารางอ้างอิงช่วยให้ข้อมูลสอดคล้องกันทั้งระบบ

---

## ส่วนที่ 2: การออกแบบ View (PostgreSQL)

ทั้งสอง View ใช้ `security_invoker = true` ตามแนวทางของโปรเจกต์ เพื่อให้นโยบาย Row Level Security (RLS) ยังมีผลกับผู้ที่เรียกใช้ View

### 2.1 View ที่ 1: `v_equipment_overdue_summary`

```sql
CREATE OR REPLACE VIEW v_equipment_overdue_summary
WITH (security_invoker = true) AS
SELECT eb.booking_id,
       eb.booking_code,
       u.user_id,
       u.full_name            AS borrower_name,
       u.user_status,
       r.resource_id,
       r.resource_code        AS equipment_code,
       rm.model_name          AS equipment_name,
       eb.borrow_date,
       eb.expected_return_date,
       eb.actual_return_date,
       (COALESCE(eb.actual_return_date::date, CURRENT_DATE)
          - eb.expected_return_date::date)       AS overdue_days,
       CASE WHEN eb.actual_return_date IS NULL
            THEN 'NOT_RETURNED'
            ELSE 'RETURNED_LATE'
       END                    AS overdue_type,
       bs.booking_status_name AS booking_status,
       COALESCE(f.total_fine, 0)                 AS total_fine,
       COALESCE(f.unpaid_fine, 0)                AS unpaid_fine
FROM equipment_bookings AS eb
JOIN users              AS u  ON u.user_id            = eb.user_id
JOIN resource_schedules AS rs ON rs.schedule_id       = eb.schedule_id
JOIN resources          AS r  ON r.resource_id        = rs.resource_id
JOIN resource_models    AS rm ON rm.model_id          = r.model_id
JOIN booking_status     AS bs ON bs.booking_status_id = eb.booking_status_id
LEFT JOIN (
    SELECT booking_id,
           SUM(fine_amount) AS total_fine,
           SUM(fine_amount) FILTER (WHERE fine_status = 'UNPAID') AS unpaid_fine
    FROM fines
    GROUP BY booking_id
) AS f ON f.booking_id = eb.booking_id
WHERE bs.booking_status_name IN ('BORROWED', 'OVERDUE', 'RETURNED')
  AND COALESCE(eb.actual_return_date::date, CURRENT_DATE) > eb.expected_return_date::date;
```

**วัตถุประสงค์:** แสดงเฉพาะการยืมที่เกินกำหนด ทั้งรายการที่ยังไม่คืน (`NOT_RETURNED`) และรายการที่คืนแล้วแต่ล่าช้า (`RETURNED_LATE`) พร้อมจำนวนวันที่เกินกำหนด (`overdue_days`) และยอดค่าปรับค้างชำระ (`unpaid_fine`) คำนวณจากวันที่คืนจริง หรือวันนี้ถ้ายังไม่คืน ค่าปรับถูกรวมยอดต่อการยืมแต่ละรายการก่อน แล้วค่อย `LEFT JOIN` จึงไม่ทำให้แถวการยืมซ้ำเมื่อมีหลายรายการปรับ

**กรณีการใช้งานทางธุรกิจ:**

- เจ้าหน้าที่ติดตามอุปกรณ์ที่ค้างคืน และติดต่อผู้ยืมที่เกินกำหนดมากที่สุดก่อน
- เจ้าหน้าที่บันทึกค่าปรับ และตรวจว่าค่าปรับใดยังไม่ได้ชำระ
- ผู้ดูแลระบบตรวจผู้ใช้ที่คืนช้าซ้ำ ๆ เพื่อพิจารณาระงับสิทธิ์ (`user_status`)
- ผู้ใช้ตรวจสอบรายการยืมที่เกินกำหนดและค่าปรับของตนเอง (RLS จำกัดให้เห็นเฉพาะแถวของตน)

**ตัวอย่างการใช้งาน:**

```sql
-- รายการที่ยังไม่คืน เรียงตามจำนวนวันที่เกินกำหนดมากที่สุด
SELECT booking_code, borrower_name, equipment_name,
       expected_return_date, overdue_days, unpaid_fine
FROM v_equipment_overdue_summary
WHERE overdue_type = 'NOT_RETURNED'
ORDER BY overdue_days DESC;
```

### 2.2 View ที่ 2: `v_crms_equipment_analytics`

```sql
CREATE OR REPLACE VIEW v_crms_equipment_analytics
WITH (security_invoker = true) AS
WITH loan_base AS (
    SELECT eb.booking_id,
           eb.user_id,
           rc.type_id,
           bs.booking_status_name,
           (   bs.booking_status_name = 'OVERDUE'
            OR (eb.actual_return_date IS NULL
                AND eb.expected_return_date::date < CURRENT_DATE)
            OR (eb.actual_return_date IS NOT NULL
                AND eb.actual_return_date::date > eb.expected_return_date::date)
           ) AS is_overdue
    FROM equipment_bookings  AS eb
    JOIN resource_schedules  AS rs ON rs.schedule_id       = eb.schedule_id
    JOIN resources           AS r  ON r.resource_id        = rs.resource_id
    JOIN resource_models     AS rm ON rm.model_id          = r.model_id
    JOIN resource_categories AS rc ON rc.type_id           = rm.type_id
    JOIN booking_status      AS bs ON bs.booking_status_id = eb.booking_status_id
),
fine_by_booking AS (
    SELECT booking_id,
           SUM(fine_amount) FILTER (WHERE fine_status = 'UNPAID') AS unpaid_fine
    FROM fines
    GROUP BY booking_id
)
SELECT rc.type_id,
       rc.type_name                                        AS equipment_category,
       rc.max_borrow_days,
       COUNT(lb.booking_id)                                AS total_loans,
       COUNT(lb.booking_id) FILTER (
           WHERE lb.booking_status_name IN ('BORROWED', 'OVERDUE')) AS active_loans,
       COUNT(lb.booking_id) FILTER (WHERE lb.is_overdue)   AS overdue_count,
       COUNT(DISTINCT lb.user_id)                          AS unique_borrowers,
       COALESCE(SUM(fb.unpaid_fine), 0)                    AS total_unpaid_fines
FROM resource_categories AS rc
LEFT JOIN loan_base        AS lb ON lb.type_id    = rc.type_id
LEFT JOIN fine_by_booking  AS fb ON fb.booking_id = lb.booking_id
GROUP BY rc.type_id, rc.type_name, rc.max_borrow_days;
```

**วัตถุประสงค์:** สรุปตัวชี้วัดการยืมรายประเภทอุปกรณ์ (เช่น LAPTOP, CAMERA, ARDUINO) ได้แก่ จำนวนการยืมทั้งหมด การยืมที่ยังดำเนินอยู่ จำนวนรายการเกินกำหนด จำนวนผู้ยืมที่ไม่ซ้ำกัน และยอดค่าปรับค้างชำระรวม ค่าปรับถูกรวมยอดต่อการยืมก่อนเชื่อมกลับ จึงไม่ทำให้ตัวเลขเกินจริง การใช้ `LEFT JOIN` กับ `COALESCE` ทำให้ประเภทอุปกรณ์ที่ยังไม่เคยถูกยืมแสดงอยู่ โดยมีค่าเป็น 0 หากต้องการตัวเลขรวมทั้งระบบ ให้ใช้ `SUM()` กับคอลัมน์ของ View นี้

**กรณีการใช้งานทางธุรกิจ:**

- ผู้ดูแลระบบดูว่าประเภทอุปกรณ์ใดถูกยืมมากที่สุด เพื่อวางแผนจัดซื้อหรือเพิ่มจำนวน
- เจ้าหน้าที่ดูภาระงานติดตามคืน (`active_loans` และ `overdue_count`) แยกตามประเภท
- ผู้บริหารดูยอดค่าปรับค้างชำระรวม และประเมินว่ากฎ `max_borrow_days` ของแต่ละประเภทเหมาะสมหรือไม่
- แดชบอร์ดดึงตัวชี้วัดเหล่านี้ได้โดยไม่ต้องเขียน Join ซ้ำ

**ตัวอย่างการใช้งาน:**

```sql
-- ประเภทอุปกรณ์ที่มีรายการเกินกำหนดมากที่สุด
SELECT equipment_category, total_loans, active_loans,
       overdue_count, total_unpaid_fines
FROM v_crms_equipment_analytics
ORDER BY overdue_count DESC;
```

**หากนำไปรันบนสคีมา CRMS แบบรวม:**

- ตารางการยืมของสคีมาแบบรวมชื่อ `equipment_bookings` และอ้างถึง `resource_id` โดยตรง ให้ตัดการ Join `resource_schedules` ออก แล้ว Join `resources` ด้วย `r.resource_id = eb.resource_id`
- หาก `resources` มีคอลัมน์ `resource_name` ให้ใช้แทน `rm.model_name`
- ชื่อสถานะในสคีมาแบบรวมต่างออกไป (`RECEIVED`, `IN_PROGRESS`, `RETURNED`, `OVERDUE`) ให้ปรับรายชื่อสถานะใน `WHERE` และ `FILTER` ให้ตรงกับตาราง `booking_status` ของคุณ

---

## สรุป

การทำนอร์มัลไลเซชัน (UNF -> 1NF -> 2NF -> 3NF) ให้ตารางตามข้างต้น พร้อม PK, FK และตารางอ้างอิง โดยแยกการจัดการค่าปรับ (`fines`) และคุณลักษณะของอุปกรณ์ (`resource_models`, `resource_categories`) ออกจากตารางการยืม ลดความซ้ำซ้อนและรักษาความถูกต้องของข้อมูล จากนั้น View ทั้งสองช่วยให้เจ้าหน้าที่ ผู้ใช้ และผู้ดูแลระบบติดตามรายการเกินกำหนด ค่าปรับ และสถิติการยืมได้โดยไม่ต้องเขียน Join ซ้ำ
