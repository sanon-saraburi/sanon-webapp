-- ============================================================
-- System 6 — ระบบขอลา/อนุมัติ (Leave Management)
-- รันใน Supabase SQL Editor
-- วันที่สร้าง: 2026-08-15
-- ============================================================

-- 1. ประเภทการลา
CREATE TABLE IF NOT EXISTS leave_types (
  type_id       SERIAL PRIMARY KEY,
  name          TEXT NOT NULL,
  code          TEXT UNIQUE NOT NULL,
  default_quota INTEGER DEFAULT 0,
  color         TEXT DEFAULT '#64748b',
  icon          TEXT DEFAULT '📋',
  requires_doc  BOOLEAN DEFAULT false,
  is_active     BOOLEAN DEFAULT true,
  sort_order    INTEGER DEFAULT 0
);

INSERT INTO leave_types (name, code, default_quota, color, icon, sort_order) VALUES
  ('ลาป่วย',       'sick',     30, '#ef4444', '🤒', 1),
  ('ลากิจ',        'personal',  3, '#f59e0b', '📌', 2),
  ('พักร้อน',      'annual',    6, '#22c55e', '🏖️', 3),
  ('ออกนอกบริษัท','out',        0, '#3b82f6', '🚗', 4)
ON CONFLICT (code) DO NOTHING;

-- 2. คำขอลา
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
  half_day      TEXT DEFAULT NULL,
  reason        TEXT,
  status        TEXT DEFAULT 'pending',
  approver_id   TEXT,
  approver_name TEXT,
  approved_at   TIMESTAMP,
  reject_note   TEXT,
  line_notified BOOLEAN DEFAULT false,
  created_at    TIMESTAMP DEFAULT NOW(),
  updated_at    TIMESTAMP DEFAULT NOW()
);

-- 3. โควต้าวันลาต่อคน
CREATE TABLE IF NOT EXISTS leave_balances (
  balance_id  SERIAL PRIMARY KEY,
  employee_id TEXT NOT NULL,
  type_id     INTEGER REFERENCES leave_types(type_id),
  year        INTEGER NOT NULL,
  quota       NUMERIC(5,1) DEFAULT 0,
  UNIQUE(employee_id, type_id, year)
);

-- 4. หัวหน้าแต่ละแผนก
CREATE TABLE IF NOT EXISTS leave_dept_supervisors (
  department      TEXT PRIMARY KEY,
  supervisor_id   TEXT,
  supervisor_name TEXT,
  line_token      TEXT
);

-- 5. การตั้งค่าระบบ
CREATE TABLE IF NOT EXISTS leave_settings (
  key   TEXT PRIMARY KEY,
  value TEXT
);

INSERT INTO leave_settings (key, value) VALUES
  ('line_token_default', ''),
  ('working_days',       '5'),
  ('system_name',        'ระบบขอลา สานนท์'),
  ('app_url',            'https://sanon-saraburi.github.io/sanon-webapp/leave.html')
ON CONFLICT (key) DO NOTHING;

-- 6. วันหยุดนักขัตฤกษ์
CREATE TABLE IF NOT EXISTS leave_holidays (
  holiday_id  SERIAL PRIMARY KEY,
  date        DATE NOT NULL,
  name        TEXT NOT NULL,
  year        INTEGER NOT NULL,
  UNIQUE(date)
);

-- วันหยุดปี 2568 (2025)
INSERT INTO leave_holidays (date, name, year) VALUES
  ('2025-01-01','วันขึ้นปีใหม่',2025),
  ('2025-04-06','วันจักรี',2025),('2025-04-13','วันสงกรานต์',2025),
  ('2025-04-14','วันสงกรานต์',2025),('2025-04-15','วันสงกรานต์',2025),
  ('2025-05-01','วันแรงงานแห่งชาติ',2025),('2025-05-04','วันฉัตรมงคล',2025),
  ('2025-07-28','วันเฉลิมพระชนมพรรษา ร.10',2025),
  ('2025-08-12','วันแม่แห่งชาติ',2025),('2025-10-13','วันนวมินทรมหาราช',2025),
  ('2025-10-23','วันปิยมหาราช',2025),('2025-12-05','วันพ่อแห่งชาติ',2025),
  ('2025-12-10','วันรัฐธรรมนูญ',2025),('2025-12-31','วันสิ้นปี',2025)
ON CONFLICT (date) DO NOTHING;

-- วันหยุดปี 2569 (2026)
INSERT INTO leave_holidays (date, name, year) VALUES
  ('2026-01-01','วันขึ้นปีใหม่',2026),
  ('2026-04-06','วันจักรี',2026),('2026-04-13','วันสงกรานต์',2026),
  ('2026-04-14','วันสงกรานต์',2026),('2026-04-15','วันสงกรานต์',2026),
  ('2026-05-01','วันแรงงานแห่งชาติ',2026),('2026-05-04','วันฉัตรมงคล',2026),
  ('2026-07-28','วันเฉลิมพระชนมพรรษา ร.10',2026),
  ('2026-08-12','วันแม่แห่งชาติ',2026),('2026-10-13','วันนวมินทรมหาราช',2026),
  ('2026-10-23','วันปิยมหาราช',2026),('2026-12-05','วันพ่อแห่งชาติ',2026),
  ('2026-12-10','วันรัฐธรรมนูญ',2026),('2026-12-31','วันสิ้นปี',2026)
ON CONFLICT (date) DO NOTHING;

-- 7. ประเภทลาเพิ่มเติม (patch v3)
INSERT INTO leave_types (code, name, default_quota, sort_order) VALUES
  ('married',   'ลาสมรส',                           3,  5),
  ('paternity', 'ลาเพื่อช่วยเหลือภรรยาคลอดบุตร',  15,  6),
  ('maternity', 'ลาคลอดบุตร',                       90,  7),
  ('ordination','ลาอุปสมบท',                        15,  8),
  ('funeral',   'ลาพิธีฌาปนกิจศพ',                  3,  9),
  ('training',  'ลาเพื่อฝึกอบรม / ศึกษา',           0, 10)
ON CONFLICT (code) DO NOTHING;

UPDATE leave_types SET sort_order=1 WHERE code='sick';
UPDATE leave_types SET sort_order=2 WHERE code='personal';
UPDATE leave_types SET sort_order=3 WHERE code='annual';
UPDATE leave_types SET sort_order=4 WHERE code='out';

-- 8. Pass Request — คำขอออกนอกบริเวณ
CREATE TABLE IF NOT EXISTS pass_reasons (
  reason_id         SERIAL PRIMARY KEY,
  name              TEXT NOT NULL,
  icon              TEXT DEFAULT '📋',
  max_minutes       INTEGER DEFAULT 60,
  requires_approval BOOLEAN DEFAULT true,
  is_active         BOOLEAN DEFAULT true,
  sort_order        INTEGER DEFAULT 0
);

INSERT INTO pass_reasons (name, icon, max_minutes, requires_approval, sort_order) VALUES
  ('ทานข้าว',        '🍚', 60,  false, 1),
  ('ธุระส่วนตัว',    '🧍', 120, true,  2),
  ('พบแพทย์',        '🏥', 240, true,  3),
  ('ออกรถ / ส่งของ','🚗', 120, true,  4),
  ('ฝึกอบรมภายนอก', '📚', 480, true,  5),
  ('อื่นๆ',          '📝', 120, true,  6)
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS pass_requests (
  pass_id         SERIAL PRIMARY KEY,
  employee_id     TEXT NOT NULL,
  employee_name   TEXT NOT NULL,
  department      TEXT,
  reason_id       INTEGER REFERENCES pass_reasons(reason_id),
  reason_name     TEXT NOT NULL,
  request_date    DATE NOT NULL,
  out_time        TIME NOT NULL,
  expected_return TIME NOT NULL,
  note            TEXT,
  status          TEXT DEFAULT 'pending',
  approver_id     TEXT,
  approver_name   TEXT,
  approved_at     TIMESTAMP,
  reject_note     TEXT,
  gate_out        TEXT,
  gate_in         TEXT,
  actual_out      TIMESTAMP,
  actual_return   TIMESTAMP,
  scanned_by      TEXT,
  line_notified   BOOLEAN DEFAULT false,
  created_at      TIMESTAMP DEFAULT NOW(),
  updated_at      TIMESTAMP DEFAULT NOW()
);

-- 9. System 5 — meeting_access column
ALTER TABLE app_users ADD COLUMN IF NOT EXISTS meeting_access boolean DEFAULT false;

-- ============================================================
-- Row Level Security (ทุกตาราง)
-- ============================================================
ALTER TABLE leave_types            ENABLE ROW LEVEL SECURITY;
ALTER TABLE leave_requests         ENABLE ROW LEVEL SECURITY;
ALTER TABLE leave_balances         ENABLE ROW LEVEL SECURITY;
ALTER TABLE leave_dept_supervisors ENABLE ROW LEVEL SECURITY;
ALTER TABLE leave_settings         ENABLE ROW LEVEL SECURITY;
ALTER TABLE leave_holidays         ENABLE ROW LEVEL SECURITY;
ALTER TABLE pass_reasons           ENABLE ROW LEVEL SECURITY;
ALTER TABLE pass_requests          ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS anon_all ON leave_types;
DROP POLICY IF EXISTS anon_all ON leave_requests;
DROP POLICY IF EXISTS anon_all ON leave_balances;
DROP POLICY IF EXISTS anon_all ON leave_dept_supervisors;
DROP POLICY IF EXISTS anon_all ON leave_settings;
DROP POLICY IF EXISTS anon_all ON leave_holidays;
DROP POLICY IF EXISTS anon_all ON pass_reasons;
DROP POLICY IF EXISTS anon_all ON pass_requests;

CREATE POLICY anon_all ON leave_types            FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY anon_all ON leave_requests         FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY anon_all ON leave_balances         FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY anon_all ON leave_dept_supervisors FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY anon_all ON leave_settings         FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY anon_all ON leave_holidays         FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY anon_all ON pass_reasons           FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY anon_all ON pass_requests          FOR ALL TO anon USING (true) WITH CHECK (true);

-- ============================================================
-- Index
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_lreq_emp    ON leave_requests (employee_id);
CREATE INDEX IF NOT EXISTS idx_lreq_dept   ON leave_requests (department);
CREATE INDEX IF NOT EXISTS idx_lreq_status ON leave_requests (status);
CREATE INDEX IF NOT EXISTS idx_lbal_emp    ON leave_balances (employee_id, year);
CREATE INDEX IF NOT EXISTS idx_leave_hol_year ON leave_holidays (year);
CREATE INDEX IF NOT EXISTS idx_pass_employee ON pass_requests(employee_id);
CREATE INDEX IF NOT EXISTS idx_pass_date     ON pass_requests(request_date);
CREATE INDEX IF NOT EXISTS idx_pass_status   ON pass_requests(status);
