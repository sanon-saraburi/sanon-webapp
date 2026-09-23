-- leave_schema_v7_patch.sql
-- อนุญาตให้ 1 แผนกมี "หัวหน้า" ได้หลายคนในตาราง leave_dept_supervisors
-- (เดิม department เป็น PRIMARY KEY → จำกัดไว้แผนกละ 1 แถว/1 คนเท่านั้น)
-- รันใน Supabase SQL Editor (หลังจาก leave_schema.sql แล้ว)
-- วันที่: 2026-09-20

-- 1. ถอด PRIMARY KEY เดิมที่ผูกกับ department ออก
ALTER TABLE leave_dept_supervisors DROP CONSTRAINT IF EXISTS leave_dept_supervisors_pkey;

-- 2. เพิ่มคอลัมน์ id (SERIAL) เป็น PK ใหม่แทน — แถวเดิมที่มีอยู่จะได้เลขรันอัตโนมัติให้ทันที
ALTER TABLE leave_dept_supervisors ADD COLUMN IF NOT EXISTS id SERIAL;
ALTER TABLE leave_dept_supervisors ADD PRIMARY KEY (id);

-- 3. สร้าง index บน department แทน (เดิมได้ index ฟรีจาก PK เก่า ตอนนี้ department ไม่ unique แล้วต้องสร้างเอง)
CREATE INDEX IF NOT EXISTS idx_dept_sup_department ON leave_dept_supervisors (department);

-- หมายเหตุ: หลังรัน patch นี้ 1 แผนกสามารถมีได้หลายแถว (หลายหัวหน้า) พร้อมกัน
-- โค้ดฝั่ง leave.html เปลี่ยนจาก upsert(onConflict:'department') เป็น insert แถวใหม่ / update ตาม id แทน
-- RLS เดิม (policy anon_all ครอบคลุมทุก operation) ใช้ต่อได้เลย ไม่ต้องแก้
