-- =====================================================================
-- production_mobile_schema.sql
-- ตาราง production_mobile สำหรับ Mobile Plant
-- สร้าง: 2026-09-02
-- รัน: Supabase SQL Editor ก่อนใช้งาน
-- =====================================================================

-- 1. สร้างตาราง production_mobile
CREATE TABLE IF NOT EXISTS production_mobile (
  id                    uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  production_date       date NOT NULL,

  -- เวลาเดินเครื่อง (hour meter mode)
  start_hour            integer DEFAULT 0,
  start_minute          integer DEFAULT 0,
  stop_hour             integer DEFAULT 0,
  stop_minute           integer DEFAULT 0,
  runtime_minute        integer DEFAULT 0,
  runtime_hour          numeric(8,2) GENERATED ALWAYS AS (runtime_minute::numeric / 60) STORED,

  -- วัตถุดิบและอัตราป้อน
  raw_material          text,
  feed_ton              numeric(10,2) DEFAULT 0,    -- หินป้อน (รวม)
  avg_ton_per_hour      numeric(8,2)  DEFAULT 0,    -- Throughput เฉลี่ย

  -- ผลิตภัณฑ์ UH 312
  uh312_stone_3_4_ton   numeric(10,2) DEFAULT 0,    -- UH312 หิน 3/4
  uh312_stone_dust_ton  numeric(10,2) DEFAULT 0,    -- UH312 หินฝุ่น

  -- ผลิตภัณฑ์ QA 451
  qa451_stone_3_4_ton   numeric(10,2) DEFAULT 0,    -- QA451 หิน 3/4
  qa451_stone_3_8_ton   numeric(10,2) DEFAULT 0,    -- QA451 หิน 3/8
  qa451_stone_dust_ton  numeric(10,2) DEFAULT 0,    -- QA451 หินฝุ่น

  -- ผลิตภัณฑ์อื่น
  stone_kluk_ton        numeric(10,2) DEFAULT 0,    -- หินคลุก

  -- ข้อมูลเสริม
  breakdown_detail      text,
  note                  text,

  -- สถานะอนุมัติ
  status                text DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),

  -- ผู้บันทึก/ผู้อนุมัติ
  recorded_by           uuid,
  recorder_name         text,
  approved_by           uuid,
  approved_at           timestamptz,
  rejection_reason      text,

  -- Timestamp
  created_at            timestamptz DEFAULT now(),
  updated_at            timestamptz DEFAULT now()
);

-- 2. Index สำหรับ query เร็ว
CREATE INDEX IF NOT EXISTS idx_production_mobile_date   ON production_mobile (production_date);
CREATE INDEX IF NOT EXISTS idx_production_mobile_status ON production_mobile (status);

-- 3. เปิด Row Level Security
ALTER TABLE production_mobile ENABLE ROW LEVEL SECURITY;

-- 4. Policy: anon สามารถทำได้ทุกอย่าง (เหมือน production_* อื่น)
DROP POLICY IF EXISTS anon_all ON production_mobile;
CREATE POLICY anon_all ON production_mobile
  FOR ALL TO anon USING (true) WITH CHECK (true);

-- 5. เพิ่ม production_daily_status สำหรับ factory_code = 'Mobile'
--    (ถ้าตาราง production_daily_status มีอยู่แล้ว)
-- INSERT INTO production_daily_status (factory_code) VALUES ('Mobile') ON CONFLICT DO NOTHING;

-- =====================================================================
-- หมายเหตุ:
-- - ไม่มี meter_start / meter_stop (ไม่มี Flowmeter)
-- - ค่า runtime_hour คำนวณอัตโนมัติจาก runtime_minute
-- - factory_code ใน production_daily_status = 'Mobile'
-- =====================================================================
