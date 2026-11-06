-- =====================================================================
-- ส่วนที่ 5 : คิวรีวิเคราะห์ข้อมูล 16 ข้อ (4 กลุ่ม x 4 คำสั่ง)
--   รูปแบบของแต่ละข้อ : คำถามทางธุรกิจ -> คำสั่ง SQL -> ผลลัพธ์ที่ได้ -> การแปลความหมาย
--   ตัวเลขผลลัพธ์ได้จากการรันจริงกับข้อมูลจำลองในส่วนที่ 2 ณ วันที่ 2 พ.ย. 2569
--   (ข้อที่ใช้ CURRENT_DATE คือ Q3 ตัวเลข "วันที่เกินกำหนด" จะเพิ่มขึ้นตามวันที่รัน)
--   วิธีรัน : เลือก (คลุมดำ) เฉพาะคิวรีที่ต้องการ แล้วกด Run selected
--
--   ความสัมพันธ์กับวิว :
--     v_room_booking_summary       <- Q1, Q9        v_printer_booking_summary   <- Q6
--     v_equipment_overdue_summary  <- Q3, Q15       v_maintenance_tracking_summary <- Q8, Q10
--     v_resource_utilization       <- Q2, Q13       v_user_activity_summary     <- Q4, Q16
--     v_monthly_booking_trend      <- Q11, Q12      v_dashboard_kpi             <- Q5, Q7
--   คิวรีที่แนะนำให้แสดงบน Dashboard และถามผ่าน Chat (ตามข้อกำหนดอย่างน้อย 3 รายการ) :
--     Q3 (อุปกรณ์ค้างคืน), Q10 (ทรัพยากรที่ซ่อมซ้ำ), Q12 (แนวโน้มรายเดือนแยกโมดูล)
-- =====================================================================


-- #####################################################################
-- กลุ่มที่ 1 : SELECT JOIN TABLES  (INNER JOIN / LEFT JOIN ข้ามหลายโมดูล)
-- #####################################################################

-- ---------------------------------------------------------------------
-- Q1 [INNER JOIN 6 ตาราง]
-- คำถามทางธุรกิจ : ตั้งแต่วันนี้เป็นต้นไป มีการจองห้องที่ "รออนุมัติหรืออนุมัติแล้ว" อะไรบ้าง
--                  ใครเป็นผู้จอง (พร้อมบทบาท) ห้องอะไร ที่ไหน เวลาใด เพื่อให้เจ้าหน้าที่เตรียมห้อง
-- ---------------------------------------------------------------------
SELECT rb.booking_code, u.full_name, ur.role_name, r.resource_name AS room_name, r.location,
       rs.work_date, rs.start_time, rs.end_time, bs.booking_status_name AS status, rb.booking_purpose
FROM room_bookings  AS rb
INNER JOIN users          AS u  ON u.user_id            = rb.user_id
INNER JOIN user_roles     AS ur ON ur.role_id           = u.role_id
INNER JOIN room_schedules AS rs ON rs.schedule_id       = rb.schedule_id
INNER JOIN resources      AS r  ON r.resource_id        = rs.resource_id
INNER JOIN booking_status AS bs ON bs.booking_status_id = rb.booking_status_id
WHERE bs.booking_status_name IN ('PENDING', 'APPROVED')
  AND rs.work_date >= DATE '2026-11-02'
ORDER BY rs.work_date, rs.start_time;
-- ผลลัพธ์ที่ได้ : 9 แถว (APPROVED 6, PENDING 3) ช่วง 2 - 19 พ.ย. 2569
--   เช่น RB-2026-0033 ห้อง Studio C301 วันนี้ 09:00-12:00 (APPROVED) และ
--   RB-2026-0037 / 0040 / 0041 ยังเป็น PENDING
-- การแปลความหมาย : มี 3 รายการ (ระหว่าง 13 - 19 พ.ย.) ที่เจ้าหน้าที่ยังต้องพิจารณาอนุมัติ
--   วันที่ 17 พ.ย. มีการใช้ห้อง 2 ห้องพร้อมกัน (A101 และ B101) ควรเตรียมเจ้าหน้าที่ดูแล
--   ทุกคนที่จองล่วงหน้าเป็นบทบาท USER (นักศึกษา) ไม่มีเจ้าหน้าที่จองห้องในช่วงนี้


-- ---------------------------------------------------------------------
-- Q2 [LEFT JOIN + HAVING] ห้องที่ไม่ค่อยถูกใช้
-- คำถามทางธุรกิจ : ห้องใดไม่มีการจองเลยหรือถูกจองไม่เกิน 1 ครั้ง ทั้งที่เป็นทรัพยากรของมหาวิทยาลัย
--                  (LEFT JOIN เพื่อให้ห้องที่ไม่มีตารางเวลา/การจองยังปรากฏในผลลัพธ์)
-- ---------------------------------------------------------------------
SELECT r.resource_code, r.resource_name, rst.resource_status_name AS resource_status,
       COUNT(DISTINCT rs.schedule_id) AS schedule_slots,
       COUNT(rb.booking_id)           AS bookings
FROM resources AS r
INNER JOIN resource_categories AS rc  ON rc.type_id = r.type_id
INNER JOIN resource_status     AS rst ON rst.resource_status_id = r.resource_status_id
LEFT  JOIN room_schedules      AS rs  ON rs.resource_id = r.resource_id
LEFT  JOIN room_bookings       AS rb  ON rb.schedule_id = rs.schedule_id
WHERE rc.type_name = 'ROOM'
GROUP BY r.resource_id, r.resource_code, r.resource_name, rst.resource_status_name
HAVING COUNT(rb.booking_id) <= 1
ORDER BY bookings, r.resource_code;
-- ผลลัพธ์ที่ได้ : 3 ห้อง
--   RM-C102 (UNDER_MAINTENANCE) 0 ช่วงเวลา 0 การจอง | RM-D102 (OUT_OF_SERVICE) 0 ช่วงเวลา 0 การจอง
--   RM-B201 Seminar Room (AVAILABLE) เปิด 3 ช่วงเวลา แต่ถูกจองเพียง 1 ครั้ง
-- การแปลความหมาย : สองห้องแรกไม่มีการจองเพราะสถานะห้องไม่พร้อมใช้งาน (ซ่อม/ปิดปรับปรุง) ไม่ใช่ปัญหาด้านความนิยม
--   ส่วน RM-B201 พร้อมใช้งานแต่มีผู้จองเพียง 1 ใน 3 ช่วง ควรประชาสัมพันธ์ห้องสัมมนานี้เพิ่ม


-- ---------------------------------------------------------------------
-- Q3 [INNER JOIN + LEFT JOIN ข้ามโมดูล ผู้ใช้-อุปกรณ์-ค่าปรับ]   (* แนะนำให้แสดงบน Dashboard/Chat)
-- คำถามทางธุรกิจ : ขณะนี้ใครค้างคืนอุปกรณ์เกินกำหนด ค้างกี่วัน และมีค่าปรับค้างชำระเท่าไร
-- ---------------------------------------------------------------------
SELECT u.full_name, u.user_status, eb.booking_code, r.resource_name AS equipment,
       eb.expected_return_date::date AS due_date,
       (CURRENT_DATE - eb.expected_return_date::date) AS days_overdue,
       f.fine_amount, COALESCE(f.fine_status, 'ยังไม่มีค่าปรับ') AS fine_status
FROM equipment_bookings AS eb
INNER JOIN users          AS u  ON u.user_id            = eb.user_id
INNER JOIN resources      AS r  ON r.resource_id        = eb.resource_id
INNER JOIN booking_status AS bs ON bs.booking_status_id = eb.booking_status_id
LEFT  JOIN fines          AS f  ON f.booking_id         = eb.booking_id
WHERE bs.booking_status_name = 'OVERDUE'
ORDER BY days_overdue DESC;
-- ผลลัพธ์ที่ได้ : 6 รายการ ณ 2 พ.ย. 2569 ค้างนานสุด 16 วัน (Arduino Uno R4 ของ กิตติพงษ์ ยอดสุวรรณ)
--   ค่าปรับรวม 1,480 บาท ทุกรายการสถานะ UNPAID (320, 280, 280, 240, 200, 160 บาท)
-- การแปลความหมาย : ผู้ยืม 2 คนมีสถานะ SUSPENDED แล้ว (สุภาพร รัตนะ, รัฐภูมิ แสงทอง) ส่วน กิตติพงษ์ ยอดสุวรรณ
--   ค้าง 2 รายการพร้อมกัน ควรติดตามเป็นลำดับแรก อุปกรณ์ที่ค้างคือ Arduino 3 ชิ้น (50% ของรายการค้าง)
--   ซึ่งกระทบการเรียนวิชา IoT ควรทวงคืนก่อน


-- ---------------------------------------------------------------------
-- Q4 [LEFT JOIN ข้าม 4 โมดูล] ภาพรวมการใช้บริการของผู้ใช้แต่ละคน
-- คำถามทางธุรกิจ : ผู้ใช้ที่ยังใช้งานอยู่ (ACTIVE) 10 อันดับแรกใช้บริการระบบมากที่สุด
--                  และใช้โมดูลไหนบ้าง (ใช้ LEFT JOIN กับตารางย่อยเพื่อให้คนที่ไม่เคยใช้โมดูลนั้นนับเป็น 0)
-- ---------------------------------------------------------------------
SELECT u.full_name, ur.role_name,
       COALESCE(rb.n, 0) AS room_cnt, COALESCE(pb.n, 0) AS printer_cnt,
       COALESCE(eb.n, 0) AS equip_cnt, COALESCE(mb.n, 0) AS repair_cnt,
       COALESCE(rb.n, 0) + COALESCE(pb.n, 0) + COALESCE(eb.n, 0) + COALESCE(mb.n, 0) AS total_activities
FROM users AS u
INNER JOIN user_roles AS ur ON ur.role_id = u.role_id
LEFT JOIN (SELECT user_id, COUNT(*) AS n FROM room_bookings        GROUP BY user_id) AS rb ON rb.user_id = u.user_id
LEFT JOIN (SELECT user_id, COUNT(*) AS n FROM printer_bookings     GROUP BY user_id) AS pb ON pb.user_id = u.user_id
LEFT JOIN (SELECT user_id, COUNT(*) AS n FROM equipment_bookings   GROUP BY user_id) AS eb ON eb.user_id = u.user_id
LEFT JOIN (SELECT user_id, COUNT(*) AS n FROM maintenance_bookings GROUP BY user_id) AS mb ON mb.user_id = u.user_id
WHERE u.user_status = 'ACTIVE'
ORDER BY total_activities DESC, u.full_name
LIMIT 10;
-- ผลลัพธ์ที่ได้ : อันดับ 1 คือ ปวีณา สายสุวรรณ และ อัญชลี ขจรเกียรติ ใช้บริการคนละ 16 ครั้ง
--   (ปวีณา: ห้อง 7 / เครื่องพิมพ์ 1 / ยืมอุปกรณ์ 4 / แจ้งซ่อม 4, อัญชลี: 6 / 2 / 6 / 2) ตามด้วย เจษฎา ปัญญาดี 8 ครั้ง
-- การแปลความหมาย : ผู้ใช้หนักสองคนแรกใช้บริการมากกว่าอันดับ 3 เท่าตัว ทั้งสองใช้ครบทุกโมดูล
--   ส่วนผู้ใช้อื่นมักใช้เพียง 1 - 2 โมดูล (เช่น อนุชา ทวีสุข ยืมอุปกรณ์ 5 ครั้งแต่ไม่เคยจองห้อง)


-- #####################################################################
-- กลุ่มที่ 2 : AGGREGATE FUNCTIONS  (COUNT / COUNT DISTINCT / SUM / AVG / MIN / MAX)
-- #####################################################################

-- ---------------------------------------------------------------------
-- Q5 [Aggregate ครบทุกฟังก์ชัน + JOIN] ภาพรวมการใช้ห้อง
-- คำถามทางธุรกิจ : การจองห้องที่ไม่ถูกปฏิเสธมีกี่ครั้ง กี่คนใช้ ใช้กี่ห้อง รวมกี่ชั่วโมง
--                  เฉลี่ยครั้งละกี่ชั่วโมง ช่วงวันที่ใดบ้าง และห้องที่ถูกใช้มีความจุเล็กสุด/ใหญ่สุดเท่าไร
-- ---------------------------------------------------------------------
SELECT COUNT(*)                              AS total_bookings,
       COUNT(DISTINCT rb.user_id)            AS distinct_users,
       COUNT(DISTINCT rs.resource_id)        AS rooms_used,
       SUM(rs.end_time - rs.start_time)      AS total_booked_time,
       ROUND(AVG(EXTRACT(EPOCH FROM (rs.end_time - rs.start_time)) / 3600.0), 2) AS avg_hours,
       MIN(rs.work_date)                     AS first_date,
       MAX(rs.work_date)                     AS last_date,
       MIN(r.capacity)                       AS min_capacity,
       MAX(r.capacity)                       AS max_capacity
FROM room_bookings   AS rb
JOIN room_schedules  AS rs ON rs.schedule_id = rb.schedule_id
JOIN resources       AS r  ON r.resource_id  = rs.resource_id
JOIN booking_status  AS bs ON bs.booking_status_id = rb.booking_status_id
WHERE bs.booking_status_name <> 'REJECTED';
-- ผลลัพธ์ที่ได้ : total_bookings = 37, distinct_users = 17, rooms_used = 10, total_booked_time = 84:00:00,
--   avg_hours = 2.27, first_date = 2026-09-07, last_date = 2026-11-19, min_capacity = 6, max_capacity = 120
-- การแปลความหมาย : 17 คนใช้ห้อง 10 ห้องรวม 84 ชั่วโมง เฉลี่ยครั้งละประมาณ 2.3 ชั่วโมง
--   ความจุห้องที่ถูกใช้ตั้งแต่ 6 ถึง 120 ที่นั่ง แสดงว่าระบบรองรับทั้งกลุ่มติวเล็กและห้องบรรยายใหญ่


-- ---------------------------------------------------------------------
-- Q6 [Aggregate + CASE WHEN] สถานะการจองเครื่องพิมพ์ 3 มิติในแถวเดียว
-- คำถามทางธุรกิจ : คำขอใช้เครื่องพิมพ์ทั้งหมดแยกตามสถานะเป็นอย่างไร อัตราสำเร็จและอัตราถูกปฏิเสธกี่เปอร์เซ็นต์
-- ---------------------------------------------------------------------
SELECT COUNT(*)                                                         AS total_requests,
       SUM(CASE WHEN bs.booking_status_name = 'PENDING'     THEN 1 ELSE 0 END) AS pending,
       SUM(CASE WHEN bs.booking_status_name = 'APPROVED'    THEN 1 ELSE 0 END) AS approved,
       SUM(CASE WHEN bs.booking_status_name = 'IN_PROGRESS' THEN 1 ELSE 0 END) AS in_progress,
       SUM(CASE WHEN bs.booking_status_name = 'COMPLETED'   THEN 1 ELSE 0 END) AS completed,
       SUM(CASE WHEN bs.booking_status_name = 'RECEIVED'    THEN 1 ELSE 0 END) AS received,
       SUM(CASE WHEN bs.booking_status_name = 'REJECTED'    THEN 1 ELSE 0 END) AS rejected,
       ROUND(100.0 * SUM(CASE WHEN bs.booking_status_name IN ('COMPLETED', 'RECEIVED') THEN 1 ELSE 0 END)
             / COUNT(*), 2)                                              AS success_rate_pct,
       ROUND(100.0 * SUM(CASE WHEN bs.booking_status_name = 'REJECTED' THEN 1 ELSE 0 END)
             / COUNT(*), 2)                                              AS reject_rate_pct
FROM printer_bookings AS pb
JOIN booking_status   AS bs ON bs.booking_status_id = pb.booking_status_id;
-- ผลลัพธ์ที่ได้ : total_requests = 34 | pending 4 | approved 7 | in_progress 2 | completed 9 | received 10 | rejected 2
--   success_rate_pct = 55.88 | reject_rate_pct = 5.88
-- การแปลความหมาย : งานพิมพ์ที่เสร็จและมารับแล้ว 19 จาก 34 งาน (55.88%) อีก 13 งานยังอยู่ในกระบวนการ (รอ/อนุมัติ/กำลังพิมพ์)
--   อัตราถูกปฏิเสธต่ำเพียง 5.88% แสดงว่าคำขอส่วนใหญ่ผ่านเกณฑ์ ส่วนงานที่ "เสร็จแล้วแต่ยังไม่มารับ" มี 9 งาน ควรแจ้งเตือนผู้ใช้


-- ---------------------------------------------------------------------
-- Q7 [Aggregate + JOIN + FILTER] ค่าปรับการยืมอุปกรณ์
-- คำถามทางธุรกิจ : ระบบมีค่าปรับรวมเท่าไร ใครถูกปรับกี่คน ค่าปรับต่อครั้งเฉลี่ย/ต่ำสุด/สูงสุดเท่าไร และยังค้างชำระเท่าไร
-- ---------------------------------------------------------------------
SELECT COUNT(*)                         AS fine_records,
       COUNT(DISTINCT f.booking_id)     AS bookings_with_fine,
       COUNT(DISTINCT eb.user_id)       AS users_fined,
       SUM(f.fine_amount)               AS total_fine,
       ROUND(AVG(f.fine_amount), 2)     AS avg_fine,
       MIN(f.fine_amount)               AS min_fine,
       MAX(f.fine_amount)               AS max_fine,
       SUM(f.fine_amount) FILTER (WHERE f.fine_status = 'UNPAID') AS unpaid_total
FROM fines AS f
JOIN equipment_bookings AS eb ON eb.booking_id = f.booking_id;
-- ผลลัพธ์ที่ได้ : fine_records = 22, bookings_with_fine = 22, users_fined = 13, total_fine = 4,660.00,
--   avg_fine = 211.82, min_fine = 40.00, max_fine = 800.00, unpaid_total = 3,460.00
-- การแปลความหมาย : ค่าปรับค้างชำระ 3,460 บาท คิดเป็น 74% ของค่าปรับทั้งหมด แสดงว่าการเก็บค่าปรับยังไม่มีประสิทธิภาพ
--   ผู้ถูกปรับ 13 คนจาก 29 นักศึกษา (ประมาณ 45%) ค่าปรับสูงสุด 800 บาทน่าจะเป็นกรณีอุปกรณ์เสียหาย ไม่ใช่การคืนช้า
-- TODO: อัปเดตตัวเลขผลลัพธ์ใหม่หลังรัน Item 5

-- ---------------------------------------------------------------------
-- Q8 [Aggregate + JOIN 3 ตาราง + ประวัติ] ประสิทธิภาพการซ่อม
-- คำถามทางธุรกิจ : งานซ่อมที่ปิดแล้วมีกี่งาน ใช้เวลาเฉลี่ย เร็วที่สุด ช้าที่สุดกี่วัน (นับจากวันแจ้งถึงวันที่บันทึก COMPLETE)
-- ---------------------------------------------------------------------
SELECT COUNT(*)                                              AS completed_jobs,
       COUNT(DISTINCT mb.resource_id)                        AS resources_repaired,
       ROUND(AVG(EXTRACT(EPOCH FROM (h.action_date - mb.reported_date)) / 86400.0), 2) AS avg_repair_days,
       ROUND(MIN(EXTRACT(EPOCH FROM (h.action_date - mb.reported_date)) / 86400.0), 2) AS fastest_days,
       ROUND(MAX(EXTRACT(EPOCH FROM (h.action_date - mb.reported_date)) / 86400.0), 2) AS slowest_days,
       ROUND(SUM(EXTRACT(EPOCH FROM (h.action_date - mb.reported_date)) / 86400.0), 2) AS total_repair_days
FROM maintenance_bookings        AS mb
JOIN maintenance_booking_history AS h  ON h.booking_id = mb.booking_id
JOIN booking_actions             AS ba ON ba.action_id = h.action_id
WHERE ba.action_name = 'COMPLETE';
-- ผลลัพธ์ที่ได้ : completed_jobs = 18, resources_repaired = 13, avg_repair_days = 8.29,
--   fastest_days = 2.04, slowest_days = 14.17, total_repair_days = 149.21
-- การแปลความหมาย : งานซ่อมใช้เวลาเฉลี่ยประมาณ 8 วัน ช่วงห่างระหว่างงานเร็วสุด (2 วัน) กับช้าสุด (14 วัน) กว้างมาก
--   ควรตั้งเป้าหมายเวลาซ่อม (SLA) เช่น ไม่เกิน 7 วัน และตรวจงานที่เกิน 10 วันว่ารออะไหล่หรือไม่


-- #####################################################################
-- กลุ่มที่ 3 : GROUPING FUNCTIONS  (GROUP BY / HAVING / ROLLUP / Window ORDER BY)
-- #####################################################################

-- ---------------------------------------------------------------------
-- Q9 [GROUP BY มากกว่า 1 คอลัมน์] การจองห้องแยกตามอาคาร/ชั้น และสถานะ
-- คำถามทางธุรกิจ : แต่ละอาคาร/ชั้นมีการจองกี่ครั้งในแต่ละสถานะ และใช้ห้องรวมกี่ชั่วโมง
-- ---------------------------------------------------------------------
SELECT r.location, bs.booking_status_name AS status,
       COUNT(*)                                                                  AS bookings,
       ROUND(SUM(EXTRACT(EPOCH FROM (rs.end_time - rs.start_time)) / 3600.0), 1) AS total_hours
FROM room_bookings  AS rb
JOIN room_schedules AS rs ON rs.schedule_id = rb.schedule_id
JOIN resources      AS r  ON r.resource_id  = rs.resource_id
JOIN booking_status AS bs ON bs.booking_status_id = rb.booking_status_id
GROUP BY r.location, bs.booking_status_name
ORDER BY r.location, bookings DESC;
-- ผลลัพธ์ที่ได้ : 19 แถว (ตำแหน่ง x สถานะ) รวมทุกแถว 41 การจอง
--   Building A Floor 1 มากสุด 10 การจอง (COMPLETED 7 / APPROVED 2 / REJECTED 1) รองลงมาคือ Building B Floor 1 (8) และ Building C Floor 1 (7)
--   Library Floor 1 น้อยสุด 2 การจอง
-- การแปลความหมาย : ความต้องการจองกระจุกที่ชั้น 1 ของอาคาร A, B, C ซึ่งเดินถึงง่าย ส่วนห้องสมุดมีน้อยเพราะห้อง D102 ปิดปรับปรุง
--   ผู้บริหารควรพิจารณาเพิ่มจำนวนห้องบริเวณอาคาร A ชั้น 1 และเปิดห้อง D102 เร็วขึ้น


-- ---------------------------------------------------------------------
-- Q10 [GROUP BY + HAVING] ทรัพยากรที่ซ่อมซ้ำบ่อย
-- คำถามทางธุรกิจ : ทรัพยากรชิ้นใดถูกแจ้งซ่อมตั้งแต่ 3 ครั้งขึ้นไป ควรพิจารณาเปลี่ยนแทนหรือทำ Preventive Maintenance
-- (* แนะนำให้แสดงบน Dashboard/Chat)
-- ---------------------------------------------------------------------
SELECT r.resource_code, r.resource_name, rc.type_name AS category,
       COUNT(*)                                  AS repair_count,
       MIN(mb.reported_date)::date               AS first_report,
       MAX(mb.reported_date)::date               AS last_report
FROM maintenance_bookings AS mb
JOIN resources            AS r  ON r.resource_id = mb.resource_id
JOIN resource_categories  AS rc ON rc.type_id    = r.type_id
GROUP BY r.resource_id, r.resource_code, r.resource_name, rc.type_name
HAVING COUNT(*) >= 3
ORDER BY repair_count DESC, r.resource_code;
-- ผลลัพธ์ที่ได้ : 7 ทรัพยากร แจ้งซ่อมชิ้นละ 3 ครั้ง ได้แก่ 3DP003 (Formlabs Form 3), 3DP006 (Ultimaker S5),
--   AC001, AC002 (เครื่องปรับอากาศ), LP002 (MacBook Air M2), NET001 (Network Switch B201), PJ-C301 (โปรเจกเตอร์ห้อง C301)
-- การแปลความหมาย : 4 ใน 7 เป็นระบบสิ่งอำนวยความสะดวกของอาคาร (แอร์ 2, เครือข่าย 1, โปรเจกเตอร์ 1) ซึ่งเสียซ้ำภายในไม่ถึง 2 เดือน
--   สะท้อนว่าการซ่อมครั้งก่อนไม่แก้ที่ต้นเหตุ ควรทำแผนบำรุงรักษาเชิงป้องกันและพิจารณาเปลี่ยนอุปกรณ์ที่เสียซ้ำ


-- ---------------------------------------------------------------------
-- Q11 [GROUP BY ROLLUP] ยอดรวมทุกโมดูลรายเดือนพร้อมยอดรวมย่อยและยอดรวมทั้งหมด
-- คำถามทางธุรกิจ : แต่ละโมดูลมีรายการกี่รายการต่อเดือน รวมต่อโมดูลเท่าไร และรวมทั้งระบบเท่าไร
--                  (ROLLUP สร้างแถวยอดรวมย่อย/ยอดรวมใหญ่ให้ในคำสั่งเดียว ใช้ GROUPING() ระบุแถวสรุป)
-- ---------------------------------------------------------------------
SELECT CASE WHEN GROUPING(module) = 1      THEN '== ทุกโมดูล ==' ELSE module      END AS module,
       CASE WHEN GROUPING(month_label) = 1 THEN '== ทุกเดือน =='  ELSE month_label END AS month,
       SUM(total_bookings) AS bookings
FROM v_monthly_booking_trend
GROUP BY ROLLUP (module, month_label)
ORDER BY GROUPING(module), module, GROUPING(month_label), month_label;
-- ผลลัพธ์ที่ได้ : 17 แถว  EQUIPMENT 45 (ก.ย. 16 / ต.ค. 21 / พ.ย. 8), MAINTENANCE 34 (14 / 19 / 1),
--   PRINTER 34 (8 / 13 / 13), ROOM 41 (19 / 13 / 9) และยอดรวมทั้งระบบ 154 รายการ
-- การแปลความหมาย : การยืมอุปกรณ์เป็นโมดูลที่ใช้มากที่สุด (45 รายการ หรือ 29% ของทั้งหมด) เดือน พ.ย. ตัวเลขน้อยเพราะเป็นเดือนที่ยังไม่จบ
--   (เหลือเฉพาะรายการล่วงหน้า) ไม่ได้หมายความว่าความต้องการลดลง


-- ---------------------------------------------------------------------
-- Q12 [Window Function: SUM / MAX / MIN / RANK ... OVER (... ORDER BY ...)]  (* แนะนำให้แสดงบน Dashboard/Chat)
-- คำถามทางธุรกิจ : แนวโน้มสะสมรายเดือนของแต่ละโมดูลเป็นอย่างไร เดือนใดสูงสุด/ต่ำสุดของโมดูลนั้น
--                  และในแต่ละเดือนโมดูลใดมีการใช้งานมากเป็นอันดับที่เท่าไร
-- ---------------------------------------------------------------------
SELECT month_label, module, total_bookings,
       SUM(total_bookings) OVER (PARTITION BY module ORDER BY month_label)  AS running_total,
       MAX(total_bookings) OVER (PARTITION BY module)                       AS module_peak,
       MIN(total_bookings) OVER (PARTITION BY module)                       AS module_low,
       RANK() OVER (PARTITION BY month_label ORDER BY total_bookings DESC)  AS rank_in_month
FROM v_monthly_booking_trend
ORDER BY module, month_label;
-- ผลลัพธ์ที่ได้ : 12 แถว (3 เดือน x 4 โมดูล) เช่น EQUIPMENT: 16 -> 37 -> 45 (สะสม) สูงสุด 21 ใน ต.ค.,
--   ROOM: 19 -> 32 -> 41 สูงสุด 19 ใน ก.ย., PRINTER: 8 -> 21 -> 34 เพิ่มขึ้นต่อเนื่อง และเป็นอันดับ 1 ของ พ.ย. (13 รายการ)
-- การแปลความหมาย : การจองห้องลดลงจาก 19 ในเดือน ก.ย. เหลือ 13 (ต.ค.) และ 9 (พ.ย. ซึ่งยังไม่จบเดือนและนับเฉพาะรายการล่วงหน้า)
--   ในขณะที่เครื่องพิมพ์ 3 มิติเพิ่มจาก 8 เป็น 13 ครั้งต่อเดือน และเป็นโมดูลที่ใช้มากสุดของเดือน พ.ย. จึงควรเตรียมวัสดุสิ้นเปลือง (เส้นพลาสติก/เรซิน) ให้เพียงพอ


-- #####################################################################
-- กลุ่มที่ 4 : STATISTICAL AND MATHEMATICAL FUNCTIONS
--              (STDDEV_POP, VAR_POP, MODE, PERCENTILE_CONT, ROUND, NULLIF, COALESCE)
-- #####################################################################

-- ---------------------------------------------------------------------
-- Q13 [STDDEV_POP, VAR_POP, ROUND] ความสม่ำเสมอของระยะเวลาการจองห้อง
-- คำถามทางธุรกิจ : ห้องใดมีระยะเวลาการจองแต่ละครั้งแกว่งมาก/น้อย (ส่วนเบี่ยงเบนมาตรฐานและความแปรปรวน)
--                  เพื่อวางช่วงเวลาให้ตรงกับพฤติกรรมการใช้งาน (เฉพาะห้องที่มีการจองตั้งแต่ 4 ครั้ง)
-- ---------------------------------------------------------------------
SELECT r.resource_code, r.resource_name,
       COUNT(*) AS bookings,
       ROUND(AVG(EXTRACT(EPOCH FROM (rs.end_time - rs.start_time)) / 3600.0), 2)         AS avg_hours,
       ROUND(STDDEV_POP(EXTRACT(EPOCH FROM (rs.end_time - rs.start_time)) / 3600.0), 3)  AS stddev_hours,
       ROUND(VAR_POP(EXTRACT(EPOCH FROM (rs.end_time - rs.start_time)) / 3600.0), 3)     AS var_hours
FROM room_bookings  AS rb
JOIN room_schedules AS rs ON rs.schedule_id = rb.schedule_id
JOIN resources      AS r  ON r.resource_id  = rs.resource_id
GROUP BY r.resource_id, r.resource_code, r.resource_name
HAVING COUNT(*) >= 4
ORDER BY stddev_hours DESC;
-- ผลลัพธ์ที่ได้ : 8 ห้อง ส่วนเบี่ยงเบนมาตรฐานสูงสุด 0.500 ชม. (RM-A101 เฉลี่ย 2.50 ชม. และ RM-A102 เฉลี่ย 1.50 ชม.)
--   RM-C101 0.452, RM-B101/B102/B202 0.433, RM-C301 0.400 และ RM-A201 = 0.000 (ความแปรปรวน 0)
-- การแปลความหมาย : ทุกห้องมีความแปรปรวนต่ำ (ไม่เกิน 0.25 ชม.²) แสดงว่าผู้ใช้จองเป็นช่วงเวลามาตรฐาน
--   ห้อง Lecture Hall A201 ถูกจอง 2 ชม. เท่ากันทุกครั้ง (stddev = 0) จึงกำหนดบล็อกเวลา 2 ชม. ตายตัวได้
--   (VAR_POP = STDDEV_POP ยกกำลังสอง เช่น 0.5 ชม. -> 0.25)


-- ---------------------------------------------------------------------
-- Q14 [MODE, PERCENTILE_CONT, STDDEV_POP, ROUND] ชั่วโมงเริ่มและระยะเวลาที่พบบ่อย
-- คำถามทางธุรกิจ : ผู้ใช้เริ่มใช้ห้อง/เครื่องพิมพ์ชั่วโมงใดบ่อยที่สุด (ฐานนิยม) ระยะเวลามัธยฐานเท่าไร
--                  เทียบกับค่าเฉลี่ยและส่วนเบี่ยงเบนมาตรฐาน เพื่อจัดช่วงเวลาให้เหมาะสม
-- ---------------------------------------------------------------------
SELECT 'ROOM' AS module,
       MODE() WITHIN GROUP (ORDER BY EXTRACT(HOUR FROM rs.start_time))  AS most_common_start_hour,
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (rs.end_time - rs.start_time)) / 3600.0))::numeric, 2) AS median_hours,
       ROUND(AVG(EXTRACT(EPOCH FROM (rs.end_time - rs.start_time)) / 3600.0), 2)        AS avg_hours,
       ROUND(STDDEV_POP(EXTRACT(EPOCH FROM (rs.end_time - rs.start_time)) / 3600.0), 3) AS stddev_hours
FROM room_bookings rb JOIN room_schedules rs ON rs.schedule_id = rb.schedule_id
UNION ALL
SELECT 'PRINTER',
       MODE() WITHIN GROUP (ORDER BY EXTRACT(HOUR FROM ps.start_time)),
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (ps.end_time - ps.start_time)) / 3600.0))::numeric, 2),
       ROUND(AVG(EXTRACT(EPOCH FROM (ps.end_time - ps.start_time)) / 3600.0), 2),
       ROUND(STDDEV_POP(EXTRACT(EPOCH FROM (ps.end_time - ps.start_time)) / 3600.0), 3)
FROM printer_bookings pb JOIN printer_schedules ps ON ps.schedule_id = pb.schedule_id;
-- ผลลัพธ์ที่ได้ : ROOM  : เริ่มบ่อยสุด 09:00 | มัธยฐาน 2.00 | เฉลี่ย 2.27 | stddev 0.542
--                  PRINTER : เริ่มบ่อยสุด 13:00 | มัธยฐาน 4.00 | เฉลี่ย 3.44 | stddev 1.034
-- การแปลความหมาย : ห้องเรียนนิยมเริ่มช่วงเช้า 09:00 ส่วนเครื่องพิมพ์นิยมเริ่มช่วงบ่าย 13:00 ควรจัดเจ้าหน้าที่ประจำให้ตรงช่วงเวลา
--   ห้อง : ค่าเฉลี่ยสูงกว่ามัธยฐานเล็กน้อย (มีการจอง 3 ชม. บางส่วนดึงค่าเฉลี่ยขึ้น)
--   เครื่องพิมพ์ : มัธยฐาน 4 ชม. สูงกว่าค่าเฉลี่ย 3.44 ชม. เพราะมีงานสั้น 2 ชม. ดึงค่าเฉลี่ยลง และ stddev 1.03 ชม. แสดงว่าความยาวงานพิมพ์หลากหลายกว่าการจองห้องเท่าตัว


-- ---------------------------------------------------------------------
-- Q15 [NULLIF, COALESCE, STDDEV_POP, ROUND] อัตราค่าปรับรายอุปกรณ์
-- คำถามทางธุรกิจ : อุปกรณ์ชนิดใดมีอัตราการถูกปรับ (ต่อจำนวนครั้งที่ถูกยืม) สูงที่สุด และค่าปรับต่อครั้งกระจายตัวมากแค่ไหน
--                  โดยใช้สัมประสิทธิ์การแปรผัน (CV = stddev / mean) เฉพาะอุปกรณ์ที่ถูกยืมตั้งแต่ 4 ครั้ง
--                  (NULLIF กันหารด้วยศูนย์ COALESCE ใส่ 0 ให้อุปกรณ์ที่ไม่มีค่าปรับ)
-- ---------------------------------------------------------------------
SELECT r.resource_code, r.resource_name,
       COUNT(*)                                                    AS borrow_count,
       COUNT(f.fine_id)                                            AS fine_count,
       ROUND(100.0 * COUNT(f.fine_id) / NULLIF(COUNT(*), 0), 2)    AS fine_rate_pct,
       COALESCE(SUM(f.fine_amount), 0)                             AS total_fine,
       ROUND(AVG(f.fine_amount), 2)                                AS avg_fine,
       ROUND(STDDEV_POP(f.fine_amount) / NULLIF(AVG(f.fine_amount), 0), 3) AS fine_cv
FROM equipment_bookings AS eb
JOIN resources          AS r ON r.resource_id = eb.resource_id
LEFT JOIN fines         AS f ON f.booking_id  = eb.booking_id
GROUP BY r.resource_id, r.resource_code, r.resource_name
HAVING COUNT(*) >= 4
ORDER BY fine_rate_pct DESC, total_fine DESC;
-- ผลลัพธ์ที่ได้ : 8 อุปกรณ์ อันดับ 1 RP001 Raspberry Pi 5 Kit อัตราปรับ 75.00% (3 จาก 4 ครั้ง) ค่าปรับรวม 440 บาท
--   อันดับ 2 TB001 iPad Pro 66.67% และมีค่าปรับรวมสูงสุด 1,360 บาท (เฉลี่ย 340 บาท, CV 0.791)
--   MC001 และ CM002 มี CV = 0.000 เพราะมีค่าปรับเพียงครั้งเดียว
-- การแปลความหมาย : อุปกรณ์ที่ผู้ใช้คืนช้าบ่อยคือบอร์ด IoT, แท็บเล็ตและโปรเจกเตอร์ (ปรับ 50 - 75%) ควรลดระยะเวลาให้ยืมหรือเพิ่มการแจ้งเตือนก่อนครบกำหนด
--   iPad มี CV สูง (0.791) แสดงว่าค่าปรับต่อครั้งไม่คงที่ (มีทั้งคืนช้าไม่กี่วันและกรณีเสียหาย) ส่วน CV = 0 ของ MC001/CM002 ห้ามตีความว่าสม่ำเสมอ เพราะมีเพียงค่าเดียว
--   หมายเหตุ : อัตราปรับคำนวณจากจำนวนการยืมทั้งหมดของอุปกรณ์นั้น (รวมรายการที่ยังรอ/ถูกปฏิเสธ)
-- TODO: อัปเดตตัวเลขผลลัพธ์ใหม่หลังรัน Item 5

-- ---------------------------------------------------------------------
-- Q16 [AVG/STDDEV_POP OVER (), NULLIF, ROUND] z-score หาผู้ใช้ที่ใช้งานสูงผิดปกติ
-- คำถามทางธุรกิจ : นักศึกษาคนใดใช้บริการมากกว่าค่าเฉลี่ยของกลุ่มอย่างมีนัยสำคัญ (z-score >= 2) เพื่อดูแลเป็นพิเศษหรือตรวจสอบการใช้งานผิดปกติ
-- ---------------------------------------------------------------------
WITH per_user AS (
    SELECT user_id, full_name, total_activities FROM v_user_activity_summary
    WHERE role_name = 'USER'
)
SELECT full_name, total_activities,
       ROUND(AVG(total_activities)        OVER (), 2) AS mean_all,
       ROUND(STDDEV_POP(total_activities) OVER (), 2) AS stddev_all,
       ROUND((total_activities - AVG(total_activities) OVER ())
             / NULLIF(STDDEV_POP(total_activities) OVER (), 0), 2) AS z_score
FROM per_user
ORDER BY z_score DESC
LIMIT 8;
-- ผลลัพธ์ที่ได้ : นักศึกษา 29 คน ค่าเฉลี่ย 5.24 ครั้ง ส่วนเบี่ยงเบนมาตรฐาน 4.48
--   z = 2.40 สามคน (ปวีณา สายสุวรรณ, อัญชลี ขจรเกียรติ, รัฐภูมิ แสงทอง คนละ 16 ครั้ง) และ z = 1.96 (สุภาพร รัตนะ 14 ครั้ง)
-- การแปลความหมาย : ผู้ใช้ 3 คนมีการใช้บริการสูงกว่าค่าเฉลี่ยกว่า 2 เท่าของส่วนเบี่ยงเบนมาตรฐาน (นับเป็นผู้ใช้หนักผิดปกติ) ไม่มีใครเกิน z = 3
--   สองคนในกลุ่มสูง (รัฐภูมิ, สุภาพร) ถูกระงับสิทธิ์ (SUSPENDED) จากการค้างคืนอุปกรณ์ จึงใช้ผลนี้ร่วมกับ Q3 เพื่อตรวจสอบพฤติกรรมได้

