-- ตรวจคำตอบ AI Chat เทียบกับฐานข้อมูล (รันใน Supabase SQL Editor ทีละข้อ) -------------------
-- ใช้ผลลัพธ์นี้เป็นหลักฐานคู่กับภาพหน้าจอแชตในรายงาน

-- Q1 (กฎ) : ยืมอุปกรณ์ได้กี่วัน/กี่ชิ้น/ค่าปรับ
SELECT title, content FROM ai_knowledge WHERE category = 'EQUIPMENT';

-- Q2 (ว่าง) : ห้องที่ว่างจองได้ (5 รายการแรก)
SELECT resource_code, resource_name, work_date, start_time, end_time, remaining_slots
FROM v_ai_room_slots WHERE is_bookable = true
ORDER BY work_date, start_time, resource_code LIMIT 5;

-- Q3 (ว่าง) : อุปกรณ์ที่ยังเหลือให้ยืม
SELECT resource_code, resource_name, total_quantity, on_loan, available_quantity
FROM v_ai_equipment_stock WHERE available_quantity > 0 ORDER BY resource_code;

-- Q4 (สถิติ) : 3 ห้องที่ถูกจองมากที่สุด
SELECT resource_code, resource_name, total_bookings, used_hours, utilization_pct
FROM v_ai_usage_stats WHERE resource_category = 'ROOM'
ORDER BY total_bookings DESC NULLS LAST, resource_code LIMIT 3;

-- Q5 (สถิติ) : งานแจ้งซ่อมแยกสถานะ + ทรัพยากรที่ถูกแจ้งบ่อยสุด
SELECT status, SUM(total) AS total FROM v_ai_maintenance_summary GROUP BY status ORDER BY total DESC;
SELECT resource_code, resource_name, repair_count, open_count
FROM v_dashboard_repair_ranking ORDER BY repair_count DESC, resource_code LIMIT 5;

-- Q6 (สถิติ) : ค่าปรับค้างชำระ / อุปกรณ์เกินกำหนดคืน
SELECT module, kpi_key, kpi_value FROM v_dashboard_module_kpi WHERE module = 'EQUIPMENT' ORDER BY kpi_key;

-- หลักฐานการบันทึก log (ไม่มีข้อมูลส่วนบุคคล: ip_hash เป็น hash)
SELECT chat_id, chat_status, tool_name, result_rows, response_ms, left(question, 50) AS question
FROM chat_logs ORDER BY chat_id DESC LIMIT 10;
