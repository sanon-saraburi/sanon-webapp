-- leave_schema_v10_patch.sql
-- เพิ่มคอลัมน์ proxy_by_id / proxy_by_name — รองรับฟีเจอร์ "แจ้งแทนพนักงาน"
-- (หัวหน้างานกรอกคำขอลา/ออกนอกบริษัท/โอที แทนพนักงานที่ใช้งานระบบเองไม่ได้ —
--  ข้อมูล/โควต้ายังผูกกับพนักงานตัวจริงในคอลัมน์ employee_id/employee_name เดิม
--  ส่วน proxy_by_id/proxy_by_name เก็บแค่ "ใครเป็นผู้แจ้งแทน" เพื่อแสดงผล/ตรวจสอบย้อนหลัง
--  คำขอที่แจ้งแทนยังต้องผ่านการอนุมัติตามปกติทุกขั้นตอน ไม่มี auto-approve)
-- รันใน Supabase SQL Editor (หลังจาก leave_schema_v9_patch.sql แล้ว)
-- วันที่: 2026-10-21

ALTER TABLE leave_requests ADD COLUMN IF NOT EXISTS proxy_by_id   TEXT DEFAULT NULL;
ALTER TABLE leave_requests ADD COLUMN IF NOT EXISTS proxy_by_name TEXT DEFAULT NULL;

ALTER TABLE pass_requests  ADD COLUMN IF NOT EXISTS proxy_by_id   TEXT DEFAULT NULL;
ALTER TABLE pass_requests  ADD COLUMN IF NOT EXISTS proxy_by_name TEXT DEFAULT NULL;

ALTER TABLE ot_requests    ADD COLUMN IF NOT EXISTS proxy_by_id   TEXT DEFAULT NULL;
ALTER TABLE ot_requests    ADD COLUMN IF NOT EXISTS proxy_by_name TEXT DEFAULT NULL;

COMMENT ON COLUMN leave_requests.proxy_by_id IS
  'เก็บ id ของผู้แจ้งแทน (หัวหน้า) เมื่อคำขอนี้ถูกกรอกแทนพนักงานที่ใช้งานระบบเองไม่ได้ — NULL = พนักงานยื่นเอง';
COMMENT ON COLUMN leave_requests.proxy_by_name IS
  'ชื่อผู้แจ้งแทน (หัวหน้า) — แสดงเป็น badge "แจ้งแทนโดย ..." ในหน้าอนุมัติ/ทุกคำขอ';
COMMENT ON COLUMN pass_requests.proxy_by_id   IS 'เช่นเดียวกับ leave_requests.proxy_by_id';
COMMENT ON COLUMN pass_requests.proxy_by_name IS 'เช่นเดียวกับ leave_requests.proxy_by_name';
COMMENT ON COLUMN ot_requests.proxy_by_id     IS 'เช่นเดียวกับ leave_requests.proxy_by_id';
COMMENT ON COLUMN ot_requests.proxy_by_name   IS 'เช่นเดียวกับ leave_requests.proxy_by_name';

-- หมายเหตุ:
-- * ไม่มีการเปลี่ยนแปลง RLS — policy anon_all เดิมครอบคลุมคอลัมน์ใหม่นี้อยู่แล้ว ไม่ต้องรันเพิ่ม
-- * แถวคำขอเดิมทั้งหมดจะมี proxy_by_id/proxy_by_name = NULL โดยอัตโนมัติ (ถือว่าพนักงานยื่นเอง) ไม่กระทบข้อมูลเดิม
-- * employee_id/employee_name/department ในคำขอที่แจ้งแทน ยังคงเป็นของ "พนักงานตัวจริง" เสมอ —
--   สถิติการลา/โควต้า/รายงานรายบุคคลจึงถูกต้องตามเดิมทุกจุด ไม่ต้องแก้ฟังก์ชันรายงาน/โควต้าใด ๆ เพิ่ม
