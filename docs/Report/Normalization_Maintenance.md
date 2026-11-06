# รายงานส่วนบุคคล: โมดูลระบบแจ้งซ่อมและจัดการเหตุขัดข้อง (Maintenance & Incident Management System)

**โครงงาน:** BU SpaceHub (CRMS – Campus Resource Management System)
**รายวิชา:** Database System
**ผู้จัดทำ:** ______________________ รหัสนักศึกษา: ______________

---

## บทนำ

รายงานนี้อธิบายการออกแบบฐานข้อมูลของโมดูลระบบแจ้งซ่อมและจัดการเหตุขัดข้อง โดยแบ่งเป็น 2 หัวข้อหลัก ได้แก่ (1) การทำนอร์มัลไลเซชัน (Normalization) จาก UNF ถึง 3NF และ (2) การออกแบบ View ด้วย PostgreSQL

**ฐานของรายงาน:** ใช้ไฟล์ `MAINTENANCE MANAGEMENT SYSTEM.sql`, เอกสาร PDF ของโมดูล และ ER Diagram เป็นสคีมาอ้างอิง ใน ER Diagram ตารางแจ้งซ่อมชื่อ `maintenance_bookings` และตารางประวัติชื่อ `maintenance_booking_history` แต่ไฟล์ SQL เดี่ยวของโมดูลใช้ชื่อ `bookings` และ `booking_history` ในรายงานนี้ใช้ชื่อตาม ER Diagram

**ข้อสมมติที่ใช้ในรายงาน:**

- กำหนดให้คีย์ของ UNF เป็นคีย์ผสม (Booking_ID, Resource_ID) เพื่อให้ขั้นตอน 2NF มีการแยกความสัมพันธ์บางส่วน (Partial Dependency) อย่างชัดเจน
- สคีมาจริงไม่มีคอลัมน์ Staff_Note ความคืบหน้าของงานซ่อมบันทึกเป็นเหตุการณ์ในตารางประวัติแทน ซึ่งอธิบายไว้ในหัวข้อ 1.3

---

## ส่วนที่ 1: การทำนอร์มัลไลเซชัน (Normalization)

### 1.0 รูปแบบที่ยังไม่ผ่านการทำนอร์มัลไลเซชัน (UNF)

```text
MAINTENANCE_REPORT_UNF (
    Booking_ID, User_ID, Reporter_Name,
    Resource_ID, Resource_Code, Resource_Name, Resource_Category, Location,
    Repair_Title, Repair_Description, Reported_Date,
    Status_Name, Staff_Note,
    Attachment_List
)
```

ตัวอย่างค่าใน Attachment_List: `photo1.jpg, photo2.jpg, report.pdf`

**ปัญหาที่พบ:**

- Attachment_List เก็บหลายไฟล์ไว้ในเซลล์เดียว
- ข้อมูลผู้แจ้ง ทรัพยากร ประเภท และสถานะ ถูกเก็บซ้ำในทุกใบแจ้งซ่อม
- เกิดความผิดปกติในการแก้ไข (การเปลี่ยนที่ตั้งของทรัพยากรต้องแก้หลายแถว) การเพิ่ม (เพิ่มทรัพยากรใหม่ไม่ได้ถ้ายังไม่มีใบแจ้งซ่อม) และการลบ (ลบใบแจ้งซ่อมสุดท้ายแล้วข้อมูลทรัพยากรหายไปด้วย)

### 1.1 First Normal Form (1NF): ค่าต้องเป็นอะตอมิก

**กฎ:** ทุกแอตทริบิวต์เก็บค่าเดียว (Atomic) และไม่มีกลุ่มข้อมูลซ้ำ

**การดำเนินการ:** แยก Attachment_List ออกเป็นตารางของตัวเอง โดยให้ไฟล์ 1 ไฟล์ต่อ 1 แถว

```text
REPORT_1NF (
    PK (Booking_ID, Resource_ID),
    User_ID, Reporter_Name,
    Resource_Code, Resource_Name, Resource_Category, Location,
    Repair_Title, Repair_Description, Reported_Date,
    Status_Name, Staff_Note
)

ATTACHMENT_1NF (
    PK (Booking_ID, File_Name),
    File_Path,
    FK Booking_ID -> REPORT_1NF
)
```

**เหตุผล:** ทุกเซลล์เก็บค่าเดียว จึงนับ ค้นหา และเพิ่มไฟล์แนบได้โดยไม่ต้องตัดข้อความ

### 1.2 Second Normal Form (2NF): กำจัดความสัมพันธ์บางส่วน

**กฎ:** ต้องอยู่ใน 1NF และทุกแอตทริบิวต์ที่ไม่ใช่คีย์ต้องขึ้นกับคีย์ทั้งหมด ไม่ใช่เพียงบางส่วน

**ความสัมพันธ์ที่พบ** ใน `REPORT_1NF` ซึ่งมีคีย์ผสม (Booking_ID, Resource_ID):

| ส่วนหนึ่งของคีย์ | กำหนดค่าของ                                                                                                   |
|------------------|---------------------------------------------------------------------------------------------------------------|
| Booking_ID       | User_ID, Reporter_Name, Repair_Title, Repair_Description, Reported_Date, Status_Name, Staff_Note               |
| Resource_ID      | Resource_Code, Resource_Name, Resource_Category, Location                                                     |

**การดำเนินการ:** แยกข้อมูลใบแจ้งซ่อมออกจากข้อมูลทรัพยากร โดยที่ตั้ง (Location) เป็นแอตทริบิวต์ของทรัพยากร จึงอยู่กับรายละเอียดทรัพยากร

```text
REPORT_2NF (
    PK Booking_ID,
    FK Resource_ID -> RESOURCE_2NF,
    User_ID, Reporter_Name,
    Repair_Title, Repair_Description, Reported_Date,
    Status_Name, Staff_Note
)

RESOURCE_2NF (
    PK Resource_ID,
    Resource_Code, Resource_Name, Resource_Category, Location
)

ATTACHMENT_1NF (
    PK (Booking_ID, File_Name),
    File_Path,
    FK Booking_ID -> REPORT_2NF
)
```

**เหตุผล:** รายละเอียดทรัพยากรและที่ตั้งถูกเก็บเพียงครั้งเดียว และหลายใบแจ้งซ่อมอ้างอิงถึงได้ สอดคล้องกับความสัมพันธ์ `RESOURCES (1:N) BOOKINGS` ที่ทรัพยากร 1 รายการมีประวัติแจ้งซ่อมได้หลายครั้ง ที่ตั้งไม่แยกเป็นตารางต่างหาก เพราะเป็นค่าธรรมดาที่ขึ้นกับทรัพยากรเพียงอย่างเดียว

### 1.3 Third Normal Form (3NF): กำจัดความสัมพันธ์แบบส่งผ่าน

**กฎ:** ต้องอยู่ใน 2NF และแอตทริบิวต์ที่ไม่ใช่คีย์ต้องไม่ขึ้นกับแอตทริบิวต์ที่ไม่ใช่คีย์ด้วยกัน

| ตาราง            | ความสัมพันธ์แบบส่งผ่าน                                                                                        | วิธีแก้                                                                              |
|------------------|---------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------|
| `REPORT_2NF`     | Booking_ID -> User_ID -> Reporter_Name (และบทบาทของผู้ใช้)                                                    | แยก `users` และ `user_roles`                                                         |
| `REPORT_2NF`     | Booking_ID -> Status -> Status_Name                                                                           | แยก `booking_status`                                                                 |
| `REPORT_2NF`     | Booking_ID -> Staff_Note (ความคืบหน้าเกิดหลายครั้งตามเวลา ไม่ใช่ค่าเดียวต่อใบแจ้งซ่อม)                        | บันทึกเป็นเหตุการณ์ใน `maintenance_booking_history` พร้อม `booking_actions`          |
| `RESOURCE_2NF`   | Resource_ID -> Resource_Category                                                                              | แยก `resource_categories`                                                            |
| `RESOURCE_2NF`   | Resource_ID -> สถานะทรัพยากร                                                                                  | แยก `resource_status`                                                                |
| `ATTACHMENT_1NF` | แอตทริบิวต์ของไฟล์ขึ้นกับตัวไฟล์ ไม่ใช่ใบแจ้งซ่อม                                                             | ตาราง `attachments` ของตัวเอง ใช้ `attachment_id` เป็น PK แทนคีย์ผสม เพราะชื่อไฟล์ซ้ำกันได้ |

**ข้อสังเกตเกี่ยวกับสคีมาจริง:**

- ไม่มีคอลัมน์ Staff_Note ในสคีมาจริง ความคืบหน้าของงานซ่อมบันทึกเป็นลำดับเหตุการณ์ (`CREATE_REPORT`, `RECEIVE_REQUEST`, `START_REPAIR`, `COMPLETE_REPAIR`, `REJECT_REQUEST`) ในตารางประวัติ จึงสืบค้นย้อนหลังได้ครบ ซึ่งดีกว่าข้อความอิสระที่เขียนทับกัน
- ตาราง `resources` ในโมดูลนี้เก็บ `resource_name` และ `type_id` โดยตรง ไม่มีตารางรุ่น (model) เหมือนโมดูลเครื่องพิมพ์และอุปกรณ์

### 1.4 ตาราง 3NF สุดท้าย (ตรงกับสคีมาจริง)

| ตาราง                         | PK                   | FK                                                                                                  | แอตทริบิวต์อื่น                                                                                                                                       |
|-------------------------------|----------------------|-----------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------|
| `user_roles`                  | `role_id`            | ไม่มี                                                                                               | `role_name` (UNIQUE)                                                                                                                                  |
| `users`                       | `user_id`            | `role_id` -> `user_roles`                                                                           | `user_code`, `google_id` (UNIQUE), `university_id`, `full_name`, `email` (UNIQUE), `phone`, `password_hash`, `user_status`, `created_at`, `last_login` |
| `resource_categories`         | `type_id`            | ไม่มี                                                                                               | `type_name` (UNIQUE)                                                                                                                                  |
| `resource_status`             | `resource_status_id` | ไม่มี                                                                                               | `resource_status_name` (UNIQUE)                                                                                                                       |
| `resources`                   | `resource_id`        | `type_id` -> `resource_categories`, `resource_status_id` -> `resource_status`                       | `resource_code` (UNIQUE), `resource_name`, `location`, `created_at`                                                                                   |
| `booking_status`              | `booking_status_id`  | ไม่มี                                                                                               | `booking_status_name` (UNIQUE)                                                                                                                        |
| `maintenance_bookings`        | `booking_id`         | `user_id` -> `users`, `resource_id` -> `resources`, `booking_status_id` -> `booking_status`         | `booking_code` (UNIQUE), `booking_time`, `repair_title`, `repair_description`, `reported_date`                                                        |
| `attachments`                 | `attachment_id`      | `booking_id` -> `maintenance_bookings` (ON DELETE CASCADE)                                          | `file_name`, `file_path`, `upload_date`                                                                                                               |
| `booking_actions`             | `action_id`          | ไม่มี                                                                                               | `action_name` (UNIQUE)                                                                                                                                |
| `maintenance_booking_history` | `history_id`         | `booking_id` -> `maintenance_bookings` (ON DELETE CASCADE), `action_id` -> `booking_actions`        | `action_date`                                                                                                                                         |

**หมายเหตุ:**

- ตารางหลัก 6 ตาราง (`users`, `resources`, `resource_categories`, `maintenance_bookings`, `attachments`, `booking_status`) อยู่ในตารางข้างต้นแล้ว ส่วน `user_roles`, `resource_status`, `booking_actions` และ `maintenance_booking_history` เป็นตารางที่เกิดจากการแยกใน 3NF

**ผลลัพธ์ของการแยกตาราง:**

- ข้อเท็จจริงแต่ละอย่างถูกเก็บเพียงครั้งเดียว
- ไฟล์แนบแยกเป็นตารางของตัวเอง (1 ใบแจ้งซ่อมมีได้หลายไฟล์)
- ไม่เหลือ Partial หรือ Transitive Dependency
- FK และตารางอ้างอิงช่วยให้ข้อมูลสอดคล้องกันทั้งระบบ

---

## ส่วนที่ 2: การออกแบบ View (PostgreSQL)

ทั้งสอง View ใช้ `security_invoker = true` ตามแนวทางของโปรเจกต์ เพื่อให้นโยบาย Row Level Security (RLS) ยังมีผลกับผู้ที่เรียกใช้ View วันที่ปิดงานดึงจากเหตุการณ์ `COMPLETE_REPAIR` ในตารางประวัติ (รองรับชื่อ `COMPLETE` ของสคีมาแบบรวมด้วย)

### 2.1 View ที่ 1: `v_maintenance_tracking_summary`

```sql
CREATE OR REPLACE VIEW v_maintenance_tracking_summary
WITH (security_invoker = true) AS
SELECT mb.booking_id,
       mb.booking_code,
       mb.repair_title,
       mb.repair_description,
       r.resource_code,
       r.resource_name,
       rc.type_name           AS resource_category,
       r.location,
       u.user_id,
       u.full_name            AS reporter_name,
       bs.booking_status_name AS repair_status,
       mb.reported_date,
       h.completed_date,
       CASE WHEN bs.booking_status_name = 'REJECTED' THEN NULL
            ELSE ROUND(EXTRACT(EPOCH FROM
                     (COALESCE(h.completed_date, CURRENT_TIMESTAMP)
                      - mb.reported_date)) / 86400.0, 1)
       END                    AS days_elapsed,
       CASE WHEN bs.booking_status_name = 'COMPLETED' THEN 'CLOSED'
            WHEN bs.booking_status_name = 'REJECTED'  THEN 'REJECTED'
            ELSE 'ACTIVE'
       END                    AS tracking_state,
       COALESCE(a.attachment_count, 0) AS attachment_count
FROM maintenance_bookings AS mb
JOIN users                AS u  ON u.user_id            = mb.user_id
JOIN resources            AS r  ON r.resource_id        = mb.resource_id
JOIN resource_categories  AS rc ON rc.type_id           = r.type_id
JOIN booking_status       AS bs ON bs.booking_status_id = mb.booking_status_id
LEFT JOIN (
    SELECT mh.booking_id, MAX(mh.action_date) AS completed_date
    FROM maintenance_booking_history AS mh
    JOIN booking_actions AS ba ON ba.action_id = mh.action_id
    WHERE ba.action_name IN ('COMPLETE_REPAIR', 'COMPLETE')
    GROUP BY mh.booking_id
) AS h ON h.booking_id = mb.booking_id
LEFT JOIN (
    SELECT booking_id, COUNT(*) AS attachment_count
    FROM attachments
    GROUP BY booking_id
) AS a ON a.booking_id = mb.booking_id;
```

**วัตถุประสงค์:** แสดงใบแจ้งซ่อมแต่ละรายการพร้อมข้อมูลผู้แจ้ง ทรัพยากร ประเภท ที่ตั้ง จำนวนวันที่ผ่านไป (`days_elapsed`) และจำนวนไฟล์แนบ (`attachment_count`) สำหรับติดตามงานที่ยังเปิดอยู่ จำนวนวันนับจากวันที่แจ้งถึงวันที่ปิดงาน หรือถึงปัจจุบันถ้ายังไม่ปิด และเป็น NULL สำหรับงานที่ถูกปฏิเสธ ไฟล์แนบและวันที่ปิดงานถูกรวมยอดต่อใบแจ้งซ่อมก่อนแล้วค่อย `LEFT JOIN` จึงไม่ทำให้แถวซ้ำเมื่อมีหลายไฟล์หรือหลายเหตุการณ์

**กรณีการใช้งานทางธุรกิจ:**

- เจ้าหน้าที่ติดตามงานค้าง (`tracking_state = 'ACTIVE'`) และเรียงตามจำนวนวันที่ผ่านไปมากที่สุดก่อน
- ผู้ใช้ติดตามสถานะใบแจ้งซ่อมของตนเอง (RLS จำกัดให้เห็นเฉพาะแถวของตน)
- ช่างซ่อมตรวจว่าใบแจ้งซ่อมใดมีรูปภาพประกอบ (`attachment_count`) ก่อนไปดูหน้างาน
- ผู้ดูแลระบบดูทรัพยากรที่แจ้งซ่อมซ้ำ ๆ เพื่อพิจารณาเปลี่ยนหรือปรับปรุง

**ตัวอย่างการใช้งาน:**

```sql
-- งานที่ยังเปิดอยู่ เรียงตามจำนวนวันที่ค้างมากที่สุด
SELECT booking_code, repair_title, resource_name, location,
       repair_status, days_elapsed, attachment_count
FROM v_maintenance_tracking_summary
WHERE tracking_state = 'ACTIVE'
ORDER BY days_elapsed DESC;
```

### 2.2 View ที่ 2: `v_crms_maintenance_analytics`

```sql
CREATE OR REPLACE VIEW v_crms_maintenance_analytics
WITH (security_invoker = true) AS
WITH completion AS (
    SELECT mh.booking_id, MAX(mh.action_date) AS completed_date
    FROM maintenance_booking_history AS mh
    JOIN booking_actions AS ba ON ba.action_id = mh.action_id
    WHERE ba.action_name IN ('COMPLETE_REPAIR', 'COMPLETE')
    GROUP BY mh.booking_id
)
SELECT rc.type_id,
       rc.type_name                                   AS resource_category,
       COUNT(mb.booking_id)                           AS total_reports,
       COUNT(mb.booking_id) FILTER (
           WHERE bs.booking_status_name = 'PENDING')      AS pending_tickets,
       COUNT(mb.booking_id) FILTER (
           WHERE bs.booking_status_name = 'RECEIVED')     AS received_tickets,
       COUNT(mb.booking_id) FILTER (
           WHERE bs.booking_status_name = 'IN_PROGRESS')  AS in_progress_tasks,
       COUNT(mb.booking_id) FILTER (
           WHERE bs.booking_status_name = 'COMPLETED')    AS completed_reports,
       COUNT(mb.booking_id) FILTER (
           WHERE bs.booking_status_name = 'REJECTED')     AS rejected_reports,
       ROUND(AVG(EXTRACT(EPOCH FROM (c.completed_date - mb.reported_date)) / 86400.0)
             FILTER (WHERE bs.booking_status_name = 'COMPLETED'
                       AND c.completed_date IS NOT NULL), 2) AS avg_turnaround_days
FROM resource_categories AS rc
LEFT JOIN resources            AS r  ON r.type_id             = rc.type_id
LEFT JOIN maintenance_bookings AS mb ON mb.resource_id        = r.resource_id
LEFT JOIN booking_status       AS bs ON bs.booking_status_id  = mb.booking_status_id
LEFT JOIN completion           AS c  ON c.booking_id          = mb.booking_id
GROUP BY rc.type_id, rc.type_name;
```

**วัตถุประสงค์:** สรุปตัวชี้วัด (KPI) ของงานซ่อมรายประเภททรัพยากร (เช่น ELECTRICAL, NETWORK, AIR_CONDITIONER) ได้แก่ จำนวนใบแจ้งซ่อมทั้งหมด จำนวนที่รอรับเรื่อง กำลังดำเนินการ ปิดงานแล้ว และถูกปฏิเสธ รวมถึงจำนวนวันเฉลี่ยที่ใช้ซ่อมจนเสร็จ (`avg_turnaround_days`) ซึ่งคำนวณเฉพาะงานที่ปิดแล้วและมีวันที่ปิดงานในประวัติ การใช้ `LEFT JOIN` ทำให้ประเภทที่ยังไม่มีการแจ้งซ่อมแสดงอยู่โดยจำนวนเป็น 0 และค่าเฉลี่ยเป็น NULL (หมายถึงยังไม่มีข้อมูล ไม่ใช่ 0 วัน) หากต้องการตัวเลขรวมทั้งระบบ ให้ใช้ `SUM()` กับคอลัมน์จำนวน

**กรณีการใช้งานทางธุรกิจ:**

- ผู้ดูแลระบบดูว่าประเภททรัพยากรใดมีปัญหาบ่อยที่สุด เพื่อวางแผนบำรุงรักษาเชิงป้องกัน
- เจ้าหน้าที่ดูภาระงานค้าง (`pending_tickets` และ `in_progress_tasks`) แยกตามประเภท
- ผู้บริหารวัดประสิทธิภาพงานซ่อมด้วย `avg_turnaround_days` และเปรียบเทียบระหว่างประเภท
- แดชบอร์ดดึงตัวชี้วัดเหล่านี้ได้โดยไม่ต้องเขียน Join ซ้ำ

**ตัวอย่างการใช้งาน:**

```sql
-- ประเภทที่ซ่อมช้าที่สุด พร้อมงานที่ยังค้างอยู่
SELECT resource_category, total_reports, pending_tickets,
       in_progress_tasks, completed_reports, avg_turnaround_days
FROM v_crms_maintenance_analytics
ORDER BY avg_turnaround_days DESC NULLS LAST;
```

**หากนำไปรันกับไฟล์ SQL เดี่ยวของโมดูล:**

- เปลี่ยน `maintenance_bookings` เป็น `bookings`
- เปลี่ยน `maintenance_booking_history` เป็น `booking_history`
- โครงสร้างคอลัมน์อื่นเหมือนกัน และชื่อสถานะ (`PENDING`, `RECEIVED`, `IN_PROGRESS`, `COMPLETED`, `REJECTED`) ตรงกันทั้งสองสคีมา

---

## สรุป

การทำนอร์มัลไลเซชัน (UNF -> 1NF -> 2NF -> 3NF) ให้ตารางตามข้างต้น พร้อม PK, FK และตารางอ้างอิง โดยแยกไฟล์แนบ (`attachments`) ประเภททรัพยากร (`resource_categories`) และนิยามสถานะ (`booking_status`) ออกจากตารางใบแจ้งซ่อม ลดความซ้ำซ้อนและรักษาความถูกต้องของข้อมูล จากนั้น View ทั้งสองช่วยให้เจ้าหน้าที่ ผู้ใช้ และผู้ดูแลระบบติดตามสถานะงานซ่อมและวัดประสิทธิภาพได้โดยไม่ต้องเขียน Join ซ้ำ
