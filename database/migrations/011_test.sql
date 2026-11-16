-- 011_test.sql : ทดสอบ Step 11-1 (ไม่ทิ้งข้อมูลค้าง) | ผลลัพธ์: ตาราง test_no / ผล PASS|FAIL
BEGIN;
CREATE TEMP TABLE t_res (n INT, name TEXT, ok BOOLEAN, detail TEXT) ON COMMIT DROP;

-- T1 chat_logs รองรับผู้ใช้สาธารณะ (user_id NULL + session_id + ip_hash)
DO $$ DECLARE v_id BIGINT; BEGIN
  INSERT INTO chat_logs (user_id, session_id, ip_hash, question, answer, tools_used, model, chat_status, response_ms)
  VALUES (NULL, 'sess-test-1', 'abc123', 'ห้องไหนว่างพรุ่งนี้', 'ตัวอย่าง', '[{"tool":"x"}]'::jsonb, 'test-model', 'SUCCESS', 120)
  RETURNING chat_id INTO v_id;
  INSERT INTO t_res VALUES (1,'insert chat_log แบบไม่ล็อกอิน', v_id IS NOT NULL, 'chat_id='||v_id);
END $$;

-- T2 สถานะ RATE_LIMITED ใช้ได้ / สถานะมั่วถูกปฏิเสธ
DO $$ BEGIN
  INSERT INTO chat_logs (session_id, question, chat_status) VALUES ('s2','q','RATE_LIMITED');
  INSERT INTO t_res VALUES (2,'chat_status = RATE_LIMITED ได้', true, '');
EXCEPTION WHEN OTHERS THEN INSERT INTO t_res VALUES (2,'chat_status = RATE_LIMITED ได้', false, SQLERRM); END $$;
DO $$ BEGIN
  BEGIN
    INSERT INTO chat_logs (session_id, question, chat_status) VALUES ('s3','q','HACKED');
    INSERT INTO t_res VALUES (3,'สถานะมั่วต้องถูกปฏิเสธ', false, 'insert ผ่าน');
  EXCEPTION WHEN check_violation THEN INSERT INTO t_res VALUES (3,'สถานะมั่วต้องถูกปฏิเสธ', true, ''); END;
END $$;

-- T4 คำถามว่าง/ยาวเกิน 1000 ต้องถูกปฏิเสธ
DO $$ DECLARE a BOOLEAN := false; b BOOLEAN := false; BEGIN
  BEGIN INSERT INTO chat_logs (session_id, question) VALUES ('s4','   '); EXCEPTION WHEN check_violation THEN a := true; END;
  BEGIN INSERT INTO chat_logs (session_id, question) VALUES ('s4', repeat('ก',1001)); EXCEPTION WHEN check_violation THEN b := true; END;
  INSERT INTO t_res VALUES (4,'คำถามว่างหรือยาว >1000 ถูกปฏิเสธ', a AND b, 'empty='||a||' long='||b);
END $$;

-- T5 tools_used ต้องเป็น array
DO $$ BEGIN
  BEGIN INSERT INTO chat_logs (session_id, question, tools_used) VALUES ('s5','q','{"a":1}'::jsonb);
        INSERT INTO t_res VALUES (5,'tools_used ต้องเป็น array', false, 'insert ผ่าน');
  EXCEPTION WHEN check_violation THEN INSERT INTO t_res VALUES (5,'tools_used ต้องเป็น array', true, ''); END;
END $$;

-- T6 ai_knowledge มี 7 หัวข้อ ครบ 5 หมวด
INSERT INTO t_res SELECT 6,'ai_knowledge 6 หัวข้อ/5 หมวด',
  (SELECT count(*) FROM ai_knowledge)=6 AND (SELECT count(DISTINCT category) FROM ai_knowledge)=5,
  (SELECT count(*)||' rows' FROM ai_knowledge);

-- T7 v_ai_resources: ทรัพยากรทั้งหมด
INSERT INTO t_res SELECT 7,'v_ai_resources = จำนวน resources', (SELECT count(*) FROM v_ai_resources)=(SELECT count(*) FROM resources),
  (SELECT count(*)::text FROM v_ai_resources);

-- T8 v_ai_equipment_stock: available ไม่ติดลบ และไม่เกิน total
INSERT INTO t_res SELECT 8,'equipment stock สมเหตุสมผล',
  NOT EXISTS (SELECT 1 FROM v_ai_equipment_stock WHERE available_quantity<0 OR available_quantity>total_quantity),
  (SELECT count(*)||' rows' FROM v_ai_equipment_stock);

-- T9 slots: มี is_bookable และ remaining ไม่ติดลบ
INSERT INTO t_res SELECT 9,'room/printer slots remaining >= 0',
  NOT EXISTS (SELECT 1 FROM v_ai_room_slots WHERE remaining_slots<0)
  AND NOT EXISTS (SELECT 1 FROM v_ai_printer_slots WHERE remaining_slots<0),
  (SELECT count(*) FROM v_ai_room_slots)||' room / '||(SELECT count(*) FROM v_ai_printer_slots)||' printer slots';

-- T10 v_ai_maintenance_summary รวม = 34 (ไม่นับซ้ำ)
INSERT INTO t_res SELECT 10,'maintenance summary รวม = maintenance_bookings',
  (SELECT sum(total) FROM v_ai_maintenance_summary)=(SELECT count(*) FROM maintenance_bookings),
  (SELECT sum(total)::text FROM v_ai_maintenance_summary);

-- T11 PII-free: ไม่มีคอลัมน์ที่เสี่ยงในทุก view v_ai_*
INSERT INTO t_res SELECT 11,'v_ai_* ไม่มีคอลัมน์ PII',
  NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name LIKE 'v\_ai\_%'
      AND (column_name ~* '(user_id|user_name|full_name|email|phone|booking_code|booking_id|reporter|assignee|user_code|staff_note)')),
  (SELECT count(DISTINCT table_name)||' views' FROM information_schema.columns WHERE table_schema='public' AND table_name LIKE 'v\_ai\_%');

-- T12 สิทธิ์: anon/authenticated อ่าน v_ai_* / chat_logs / ai_knowledge ไม่ได้ ส่วน service_role อ่านได้
INSERT INTO t_res SELECT 12,'anon/authenticated ไม่มีสิทธิ์ | service_role มี',
  NOT EXISTS (SELECT 1 FROM (VALUES ('v_ai_resources'),('v_ai_room_slots'),('v_ai_printer_slots'),('v_ai_equipment_stock'),
      ('v_ai_usage_stats'),('v_ai_monthly_trend'),('v_ai_maintenance_summary'),('chat_logs'),('ai_knowledge')) x(t)
      WHERE has_table_privilege('anon', 'public.'||t, 'SELECT') OR has_table_privilege('authenticated', 'public.'||t, 'SELECT'))
  AND has_table_privilege('service_role','public.v_ai_resources','SELECT')
  AND has_table_privilege('service_role','public.chat_logs','INSERT'),
  '';

-- T13 RLS เปิดที่ chat_logs และ ai_knowledge
INSERT INTO t_res SELECT 13,'RLS เปิด chat_logs + ai_knowledge',
  (SELECT bool_and(relrowsecurity) FROM pg_class WHERE relname IN ('chat_logs','ai_knowledge') AND relnamespace='public'::regnamespace), '';

-- T14 v_ai_usage_stats / monthly_trend มีข้อมูล
INSERT INTO t_res SELECT 14,'usage_stats + monthly_trend มีข้อมูล',
  (SELECT count(*) FROM v_ai_usage_stats)>0 AND (SELECT count(*) FROM v_ai_monthly_trend)>0,
  (SELECT count(*) FROM v_ai_usage_stats)||' / '||(SELECT count(*) FROM v_ai_monthly_trend);

SELECT n AS test_no, name, CASE WHEN ok THEN 'PASS' ELSE 'FAIL' END AS result, detail FROM t_res ORDER BY n;
ROLLBACK;
