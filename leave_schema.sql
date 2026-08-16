-- ============================================================
-- System 6 — ระบบขอลา/อนุมัติ (Leave Management)
-- รันใน Supabase SQL Editor
-- วันที่สร้าง: 2026-08-15
-- ============================================================

-- 1. ประเภทการลา
-- ============================================================
CREATE TABLE IF NOT EXISTS leave_types (
  type_id       SERIAL PRIMARY KEY,
  name          TEXT NOT NULL,
  code          TEXT UNIQUE NOT NULL,   -- sick | personal | annual | out
  default_quota INTEGER DEFAULT 0,     -- วัน/ปี (0 = ไม่จำกัด/ไม่นับ)
  color         TEXT DEFAULT '#64748b',
  icon          TEXT DEFAULT '📋',
  requires_doc  BOOLEAN DEFAULT false,  -- ต้องแนบใบรับรองหรือไม่
  is_active     BOOLEAN DEFAULT true,
  sort_order    INTEGER DEFAULT 0
);

INSERT INTO leave_types (name, code, default_quota, color, icon, sort_order) VALUES
  ('ลาป่วย',             'sick',     30, '#ef4444', '🤒', 1),
  ('ลากิจ',              'personal',  3, '#f59e0b', '📌', 2),
  ('พักร้อน',            'annual',    6, '#22c55e', '🏖️', 3),
  ('ออกนอกบริษัท',       'out',       0, '#3b82f6', '🚗', 4)
ON CONFLICT (code) DO NOTHING;

-- 2. คำขอลา
-- ============================================================
CREATE TABLE IF NOT EXISTS leave_requests (
  request_id    SERIAL PRIMARY KEY,
  employee_id   TEXT NOT NULL,
  employee_name TEXT NOT NULL,
  department    TEXT,
  type_id       INTEGER REFERENCES leave_types(type_id),
  type_name     TEXT,
  type_code     TEXT,
  start_date    DATE NOT NULL,
  end_date      DATE NOT NULL,
  days          NUMERIC(4,1) NOT NULL,
  half_day      TEXT DEFAULT NULL,    -- 'am' | 'pm' | null
  reason        TEXT,
  status        TEXT DEFAULT 'pending', -- pending | approved | rejected | cancelled
  approver_id   TEXT,
  approver_name TEXT,
  approved_at   TIMESTAMP,
  reject_note   TEXT,
  line_notified BOOLEAN DEFAULT false,
  created_at    TIMESTAMP DEFAULT NOW(),
  updated_at    TIMESTAMP DEFAULT NOW()
);

-- 3. โควต้าวันลาต่อคน (override default จาก leave_types)
-- ============================================================
CREATE TABLE IF NOT EXISTS leave_balances (
  balance_id  SERIAL PRIMARY KEY,
  employee_id TEXT NOT NULL,
  type_id     INTEGER REFERENCES leave_types(type_id),
  year        INTEGER NOT NULL,
  quota       NUMERIC(5,1) DEFAULT 0,
  UNIQUE(employee_id, type_id, year)
);

-- 4. กำหนดหัวหน้าแต่ละแผนก
-- ============================================================
CREATE TABLE IF NOT EXISTS leave_dept_supervisors (
  department      TEXT PRIMARY KEY,
  supervisor_id   TEXT,
  supervisor_name TEXT,
  line_token      TEXT   -- LINE Notify token สำหรับแจ้งเตือนหัวหน้าแผนก
);

-- 5. การตั้งค่าระบบ
-- ============================================================
CREATE TABLE IF NOT EXISTS leave_settings (
  key   TEXT PRIMARY KEY,
  value TEXT
);

INSERT INTO leave_settings (key, value) VALUES
  ('line_token_default', ''),   -- LINE token หลัก (แจ้งเตือนถ้าแผนกไม่มี token เฉพาะ)
  ('working_days',       '5'),  -- วันทำงานต่อสัปดาห์
  ('system_name',        'ระบบขอลา สานนท์'),
  ('app_url',            'https://sanon-saraburi.github.io/sanon-webapp/leave.html')
ON CONFLICT (key) DO NOTHING;

-- ============================================================
-- Row Level Security
-- ============================================================
ALTER TABLE leave_types            ENABLE ROW LEVEL SECURITY;
ALTER TABLE leave_requests         ENABLE ROW LEVEL SECURITY;
ALTER TABLE leave_balances         ENABLE ROW LEVEL SECURITY;
ALTER TABLE leave_dept_supervisors ENABLE ROW LEVEL SECURITY;
ALTER TABLE leave_settings         ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS anon_all ON leave_types;
DROP POLICY IF EXISTS anon_all ON leave_requests;
DROP POLICY IF EXISTS anon_all ON leave_balances;
DROP POLICY IF EXISTS anon_all ON leave_dept_supervisors;
DROP POLICY IF EXISTS anon_all ON leave_settings;

CREATE POLICY anon_all ON leave_types            FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY anon_all ON leave_requests         FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY anon_all ON leave_balances         FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY anon_all ON leave_dept_supervisors FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY anon_all ON leave_settings         FOR ALL TO anon USING (true) WITH CHECK (true);

-- ============================================================
-- Index
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_lreq_emp    ON leave_requests (employee_id);
CREATE INDEX IF NOT EXISTS idx_lreq_dept   ON leave_requests (department);
CREATE INDEX IF NOT EXISTS idx_lreq_date   ON leave_requests (start_date);
CREATE INDEX IF NOT EXISTS idx_lreq_status ON leave_requests (status);
CREATE INDEX IF NOT EXISTS idx_lbal_emp    ON leave_balances (employee_id, year);

-- ============================================================
-- เพิ่ม supervisor role ใน checkin_users (ถ้ายังไม่มี)
-- ✅ ไม่ต้องทำถ้า checkin_users มี role = 'supervisor' อยู่แล้ว
-- ALTER TABLE checkin_users ADD COLUMN IF NOT EXISTS leave_dept TEXT;
-- ============================================================
