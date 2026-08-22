-- leave_schema_v6_patch.sql
-- เพิ่ม pin_code ให้ app_users สำหรับ Supervisor/Admin login ด้วย PIN ใน System 6

ALTER TABLE app_users
  ADD COLUMN IF NOT EXISTS pin_code text DEFAULT NULL;

-- หมายเหตุ: pin_code = NULL หมายความว่ายังไม่ตั้ง PIN
-- ครั้งแรกที่ supervisor login ระบบจะให้ตั้ง PIN 4 หลัก
-- Admin reset: ตั้ง pin_code = NULL เพื่อให้ตั้งใหม่ครั้งต่อไปที่ login
