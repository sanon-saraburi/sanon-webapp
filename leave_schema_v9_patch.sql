-- leave_schema_v9_patch.sql
-- เพิ่มคอลัมน์ emp_id ในตาราง leave_dept_supervisors — เชื่อมหัวหน้ากับ checkin_employees
-- (แก้บั๊ก: PIN quick-login ที่แท็บ "หัวหน้า / Admin" ตรวจสิทธิ์ผิดตาราง — supervisor_id เดิมผูกกับ
--  app_users.id (บัญชี Username/Password) คนละ ID space กับ checkin_employees.employee_id ที่ PIN login ใช้จริง)
-- รันใน Supabase SQL Editor (หลังจาก leave_schema_v7_patch.sql และ leave_schema_v8_patch.sql แล้ว)
-- วันที่: 2026-10-17

ALTER TABLE leave_dept_supervisors ADD COLUMN IF NOT EXISTS emp_id TEXT DEFAULT NULL;

COMMENT ON COLUMN leave_dept_supervisors.emp_id IS
  'เชื่อมกับ checkin_employees.employee_id — ใช้เมื่อหัวหน้าแผนกเป็นพนักงานที่ login ผ่าน PIN (แท็บ "หัวหน้า / Admin") แทนบัญชี Username/Password (app_users) ที่ผูกกับคอลัมน์ supervisor_id เดิม — มีค่าได้แค่ 1 ใน 2 คอลัมน์ต่อแถว (เลือกแหล่งที่มาตอนเพิ่ม/แก้ไขหัวหน้าในหน้าตั้งค่าระบบ)';

CREATE INDEX IF NOT EXISTS idx_dept_sup_emp_id ON leave_dept_supervisors (emp_id);

-- หมายเหตุ:
-- * ไม่มีการเปลี่ยนแปลง RLS — policy anon_all เดิมครอบคลุมคอลัมน์ใหม่นี้อยู่แล้ว ไม่ต้องรันเพิ่ม
-- * แถวหัวหน้าที่มีอยู่เดิม (เพิ่มผ่าน app_users) จะมี emp_id = NULL โดยอัตโนมัติ — ยังใช้งานได้ปกติถ้าคนนั้น
--   login ด้วย Username/Password (ช่อง "เข้าด้วย password สำรอง") แต่ยังไม่สามารถ login ด้วย PIN เร็วได้
--   จนกว่าจะถูกเพิ่ม/แก้ไขใหม่ในหน้า "จัดการหัวหน้าแต่ละแผนก" โดยเลือกแหล่งที่มา "👤 พนักงาน (เข้าด้วย PIN)"
-- * โค้ดฝั่ง leave.html: ฟังก์ชัน _proceedSupLogin() (PIN login) ตรวจสิทธิ์จากคอลัมน์ emp_id นี้
--   ส่วนฟังก์ชัน doLogin() (Username/Password) ไม่เกี่ยวข้องกับตารางนี้ อ่านสิทธิ์จาก app_users.role ตรง ๆ อยู่แล้ว
