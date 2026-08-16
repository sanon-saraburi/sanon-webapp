-- ============================================================
-- Pass Request System — คำขอออกนอกบริเวณโรงงาน
-- รันใน Supabase SQL Editor (หลังจาก leave_schema.sql)
-- วันที่สร้าง: 2026-08-15
-- ============================================================

-- 1. เหตุผลการออกนอกบริเวณ (สอดคล้องกับ checkin reason_rules)
-- ============================================================
CREATE TABLE IF NOT EXISTS pass_reasons (
  reason_id   SERIAL PRIMARY KEY,
  name        TEXT NOT NULL,          -- ทานข้าว, ธุระส่วนตัว, พบแพทย์, ออกรถ, อื่นๆ
  icon        TEXT DEFAULT '📋',
  max_minutes INTEGER DEFAULT 60,     -- เวลาสูงสุดที่อนุญาต (นาที)
  requires_approval BOOLEAN DEFAULT true,  -- false = walk-in ไม่ต้องรออนุมัติ
  is_active   BOOLEAN DEFAULT true,
  sort_order  INTEGER DEFAULT 0
);

INSERT INTO pass_reasons (name, icon, max_minutes, requires_approval, sort_order) VALUES
  ('ทานข้าว',         '🍚', 60,  false, 1),  -- walk-in ไม่ต้องรออนุมัติ
  ('ธุระส่วนตัว',     '🧍', 120, true,  2),
  ('พบแพทย์',         '🏥', 240, true,  3),
  ('ออกรถ / ส่งของ', '🚗', 120, true,  4),
  ('ฝึกอบรมภายนอก',  '📚', 480, true,  5),
  ('อื่นๆ',           '📝', 120, true,  6)
ON CONFLICT DO NOTHING;

-- 2. คำขอออกนอกบริเวณ
-- ============================================================
CREATE TABLE IF NOT EXISTS pass_requests (
  pass_id         SERIAL PRIMARY KEY,
  employee_id     TEXT NOT NULL,
  employee_name   TEXT NOT NULL,
  department      TEXT,
  reason_id       INTEGER REFERENCES pass_reasons(reason_id),
  reason_name     TEXT NOT NULL,            -- snapshot ชื่อเหตุผล
  request_date    DATE NOT NULL,            -- วันที่ต้องการออก
  out_time        TIME NOT NULL,            -- เวลาที่ต้องการออก
  expected_return TIME NOT NULL,            -- เวลาที่คาดว่าจะกลับ
  note            TEXT,
  status          TEXT DEFAULT 'pending',   -- pending | approved | rejected | out | returned | cancelled
  -- Approval
  approver_id     TEXT,
  approver_name   TEXT,
  approved_at     TIMESTAMP,
  reject_note     TEXT,
  -- Gate scan (โดย รปภ.)
  gate_out        TEXT,                     -- ป้อมที่ออก
  gate_in         TEXT,                     -- ป้อมที่กลับเข้า
  actual_out      TIMESTAMP,               -- เวลาออกจริง
  actual_return   TIMESTAMP,               -- เวลากลับจริง
  scanned_by      TEXT,                    -- รปภ. ที่สแกน
  -- Meta
  line_notified   BOOLEAN DEFAULT false,
  created_at      TIMESTAMP DEFAULT NOW(),
  updated_at      TIMESTAMP DEFAULT NOW()
);

-- Index สำหรับ query บ่อย
CREATE INDEX IF NOT EXISTS idx_pass_employee   ON pass_requests(employee_id);
CREATE INDEX IF NOT EXISTS idx_pass_date       ON pass_requests(request_date);
CREATE INDEX IF NOT EXISTS idx_pass_status     ON pass_requests(status);

-- 3. RLS
-- ============================================================
ALTER TABLE pass_reasons  ENABLE ROW LEVEL SECURITY;
ALTER TABLE pass_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS anon_all ON pass_reasons;
DROP POLICY IF EXISTS anon_all ON pass_requests;

CREATE POLICY anon_all ON pass_reasons  FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY anon_all ON pass_requests FOR ALL TO anon USING (true) WITH CHECK (true);
