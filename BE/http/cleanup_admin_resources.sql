-- ใช้กับการทดสอบ Step A2 (รันใน Supabase SQL Editor ทีละข้อ) ---------------------------------

-- (1) ก่อนเริ่ม: หา id สำหรับข้อ A33 (มีประวัติ ไม่มีงานค้าง พร้อมใช้งาน) และ A34 (มีงานค้าง)
SELECT 'histId' AS use_as, resource_id, resource_code, resource_name, history_count, active_count
FROM v_admin_resources WHERE history_count > 0 AND active_count = 0 AND resource_status = 'AVAILABLE'
ORDER BY resource_id LIMIT 3;
SELECT 'activeId' AS use_as, resource_id, resource_code, resource_name, history_count, active_count
FROM v_admin_resources WHERE active_count > 0 ORDER BY resource_id LIMIT 3;

-- (2) ตรวจหลังทดสอบ: ต้องไม่เหลือข้อมูล TST- (ผลต้องเป็น 0 แถว)
SELECT resource_id, resource_code FROM resources WHERE resource_code LIKE 'TST-%';

-- (3) คืนสถานะทรัพยากรที่ถูกปิดจากข้อ A33 (แก้เลข 0 เป็น @histId ที่ใช้) แล้วรันคำสั่งนี้
-- UPDATE resources SET resource_status_id = (SELECT resource_status_id FROM resource_status WHERE resource_status_name = 'AVAILABLE')
-- WHERE resource_id = 0;

-- (4) เผื่อมี TST- ค้าง (ตารางเวลาลบตามอัตโนมัติ)
-- DELETE FROM resources WHERE resource_code LIKE 'TST-%';
