-- ลบข้อมูลทดสอบ Step 10-2 (งานที่เพิ่มหลัง seed = booking_id > 34) แล้วคืนสถานะทรัพยากร
DELETE FROM maintenance_bookings WHERE booking_id > 34;   -- history/attachments ลบตาม (ON DELETE CASCADE)
UPDATE resources SET resource_status_id = 1 WHERE resource_id = 31 AND resource_status_id = 5;
SELECT setval(pg_get_serial_sequence('maintenance_bookings','booking_id'),        (SELECT COALESCE(MAX(booking_id),1) FROM maintenance_bookings));
SELECT setval(pg_get_serial_sequence('maintenance_booking_history','history_id'), (SELECT COALESCE(MAX(history_id),1) FROM maintenance_booking_history));
SELECT setval(pg_get_serial_sequence('attachments','attachment_id'),              (SELECT COALESCE(MAX(attachment_id),1) FROM attachments));
