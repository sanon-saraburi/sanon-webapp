-- ============================================================
-- leave_schema_v5_patch.sql
-- เพิ่ม pin_code ใน checkin_employees สำหรับ PIN authentication
-- รันใน Supabase SQL Editor (ต่อจาก v4_patch)
-- ============================================================

-- เพิ่ม column pin_code (plain text 4 หลัก, null = ยังไม่ตั้ง PIN)
ALTER TABLE checkin_employees
  ADD COLUMN IF NOT EXISTS pin_code text DEFAULT NULL;

-- หมายเหตุ: ค่า null หมายถึงพนักงานยังไม่ได้ตั้ง PIN
-- ระบบจะให้ตั้ง PIN ครั้งแรกเมื่อ login ผ่าน employee mode ใน leave.html
-- Admin สามารถ reset PIN = NULL ได้ในหน้าตั้งค่าระบบ
