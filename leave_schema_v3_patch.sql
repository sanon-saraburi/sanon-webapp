-- ============================================================
-- Leave Schema Patch v3 — เพิ่มประเภทลาให้ตรงกับใบลาหยุดบริษัท
-- รันใน Supabase SQL Editor (หลังจาก leave_schema.sql แล้ว)
-- วันที่: 2026-08-15
-- ============================================================

-- เพิ่มประเภทลาใหม่ (ON CONFLICT DO NOTHING — ถ้ามีอยู่แล้วไม่ error)
-- default_quota = 0 หมายถึงไม่จำกัด (ตรงกับ schema จริง)
INSERT INTO leave_types (code, name, default_quota, sort_order) VALUES
  ('married',    'ลาสมรส',                              3,   5),
  ('paternity',  'ลาเพื่อช่วยเหลือภรรยาคลอดบุตร',     15,  6),
  ('maternity',  'ลาคลอดบุตร',                          90,  7),
  ('ordination', 'ลาอุปสมบท',                           15,  8),
  ('funeral',    'ลาพิธีฌาปนกิจศพ',                     3,   9),
  ('training',   'ลาเพื่อฝึกอบรม / ศึกษา',              0,   10)
ON CONFLICT (code) DO NOTHING;

-- อัปเดต sort_order ของประเภทเดิมให้เป็นระเบียบ
UPDATE leave_types SET sort_order=1 WHERE code='sick';
UPDATE leave_types SET sort_order=2 WHERE code='personal';
UPDATE leave_types SET sort_order=3 WHERE code='annual';
UPDATE leave_types SET sort_order=4 WHERE code='out';
