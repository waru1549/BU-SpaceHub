-- ตรวจผล Step 11-2 (รันใน Supabase SQL Editor ทีละคำสั่ง) ---------------------------------
-- (1) log ล่าสุด: ดูสถานะ / tool / จำนวนแถว / user_id / ip_hash (ต้องเป็น hash 32 ตัว ไม่ใช่ IP จริง)
SELECT chat_id, session_id, user_id, left(ip_hash, 8) AS ip8, chat_status, tool_name, result_rows, response_ms,
       left(question, 40) AS question
FROM chat_logs ORDER BY chat_id DESC LIMIT 20;

-- (2) ดู SQL evidence ของข้อใดข้อหนึ่ง
SELECT question, sql_used, tools_used FROM chat_logs WHERE sql_used IS NOT NULL ORDER BY chat_id DESC LIMIT 3;

-- (3) ล้าง log ทดสอบหลังรายงานผลแล้ว (ตารางนี้ว่างมาก่อนเริ่มทดสอบ)
-- DELETE FROM chat_logs;
