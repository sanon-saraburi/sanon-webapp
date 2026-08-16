-- ============================================================
-- leave_schema_v4_patch.sql
-- เพิ่ม allow_exceed column ใน leave_types
-- รันใน Supabase SQL Editor (ต่อจาก v3_patch)
-- ============================================================

-- เพิ่ม column allow_exceed (true = ยื่นเกินได้พร้อมแจ้งเตือน, false = block เด็ดขาด)
ALTER TABLE leave_types ADD COLUMN IF NOT EXISTS allow_exceed boolean DEFAULT true;

-- ตั้งค่า default: ประเภทลาที่มีโควต้าตายตัวตามกฎหมาย → ปิดการยื่นเกิน
UPDATE leave_types SET allow_exceed = false
WHERE code IN ('ordination', 'maternity', 'paternity', 'funeral', 'married');

-- ประเภทที่ยืดหยุ่นได้ → อนุญาตยื่นเกิน (แต่แจ้งเตือน)
-- sick, personal, annual, training, out → allow_exceed = true (default)

-- ============================================================
-- ส่วนที่ 2: เพิ่ม columns กฎเวลา ใน pass_reasons
-- ============================================================

ALTER TABLE pass_reasons ADD COLUMN IF NOT EXISTS level1_minutes int DEFAULT NULL;
ALTER TABLE pass_reasons ADD COLUMN IF NOT EXISTS level1_status  text DEFAULT NULL;
ALTER TABLE pass_reasons ADD COLUMN IF NOT EXISTS level2_minutes int DEFAULT NULL;
ALTER TABLE pass_reasons ADD COLUMN IF NOT EXISTS level2_status  text DEFAULT NULL;

-- ============================================================
-- ส่วนที่ 3: อัปเดต pass_reasons — requires_approval
-- พักทานข้าว = ไม่ต้องอนุมัติ, อื่นๆ = ต้องอนุมัติ
-- ============================================================

-- พักทานข้าว → ไม่ต้องอนุมัติ (auto-confirm + LINE ทันที)
UPDATE pass_reasons SET requires_approval = false
WHERE name ILIKE '%พักทาน%' OR name ILIKE '%ทานข้าว%' OR name ILIKE '%พักเที่ยง%';

-- ธุระ / พบแพทย์ / ออกรถ / ส่งของ / อื่นๆ → ต้องอนุมัติ
UPDATE pass_reasons SET requires_approval = true
WHERE name NOT ILIKE '%พักทาน%' AND name NOT ILIKE '%ทานข้าว%' AND name NOT ILIKE '%พักเที่ยง%';
