# PM.md — ระบบ PM เครื่องจักร (System 3)
> ไฟล์นี้บันทึกรายละเอียดเฉพาะ `pm.html` — อ่านก่อนแก้ไขทุกครั้ง

---

## 1. ข้อมูลระบบ

- **ไฟล์:** `pm.html` (~4,500+ บรรทัด)
- **สถานะ:** ✅ ใช้งานจริง
- **Supabase:** `https://pcmpwkcmvsxrvbximjgf.supabase.co` (project เดิม)
- **Session key:** `_sn_pm_sess` (SSO ใช้ `_sn_shared_sess` ข้ามระบบ)
- **GitHub Pages:** `https://sanon-saraburi.github.io/sanon-webapp/pm.html`

---

## 2. Architecture

- **Pattern:** Single-file SPA, Vanilla JS, Tailwind CDN
- **Libraries:** Lucide Icons, Chart.js, SheetJS (xlsx)
- **Font:** Kanit (Google Fonts)
- **Auth:** query `app_users` table โดยตรง (ไม่ใช้ Supabase Auth)
- **Session Timeout:** 2 ชั่วโมง (ยกเว้น admin)
- **PM Type:** Hour-based (ชม.) หรือ Km-based (กม.) ต่อเครื่อง
- **Menu prefix:** `pm-`

---

## 3. เมนูทั้งหมด (prefix: `pm-`)

| key | ชื่อ | หน้าที่ |
|-----|------|---------|
| `pm-dashboard` | Dashboard PM | Alert Grid ต่อโรงงาน, ตารางรอบ PM ทุกเครื่อง |
| `pm-items` | รายการ PM | ตาราง PM item ต่อเครื่อง + **filter โรงงาน/เครื่อง** (เพิ่ม 2026-07-31) |
| `pm-meter` | บันทึกมิเตอร์ | ตารางรวมทุกเครื่อง + filter เครื่อง/เดือน + modal บันทึก |
| `pm-repair` | บันทึกซ่อม | repair log + อะไหล่ที่ใช้ + ค่าใช้จ่าย |
| `pm-parts` | คลังอะไหล่ | CRUD อะไหล่ + รับเข้า/เบิกออก + stock log |
| `pm-report` | รายงาน PM | รายงานรายเดือน, filter เดือน/ปี, export Excel/Print |
| `pm-oee` | OEE / Availability | คำนวณ availability จาก downtime ÷ planned_hours |
| `pm-machines` | จัดการเครื่องจักร | CRUD เครื่องจักร + planned_hours_per_day |
| `pm-settings` | ตั้งค่า | โรงงาน, ประเภท PM, หมวดหมู่ |

---

## 4. ตาราง Database (System 3)

```sql
-- เครื่องจักร
pm_machines          -- เครื่องจักร (name, factory, category, meter_type,
                     --   current_meter, alert_threshold, planned_hours_per_day,
                     --   is_active, sort_order)
pm_items             -- รายการ PM ต่อเครื่อง (pm_type, interval_value,
                     --   last_pm_date, last_pm_meter, is_active, sort_order)
pm_logs              -- ประวัติการทำ PM จริง (done_date, done_meter, parts_used JSONB, total_cost)
pm_downtime          -- Downtime Log (machine_id, start_time, end_time, duration_hours,
                     --   type: breakdown/planned_pm/setup/other, cause)
pm_config            -- ตั้งค่าระบบ (key-value: categories, pm_types, factories)

-- มิเตอร์
pm_meter_logs        -- บันทึกเลขมิเตอร์รายวัน (machine_id, log_date,
                     --   start_meter, stop_meter, total_hours, breakdown_hours)

-- ซ่อมบำรุง
pm_repair_logs       -- บันทึกการซ่อม (machine_id, repair_date, type, symptoms,
                     --   root_cause, action_taken, labor_cost, parts_cost, total_cost)
pm_repair_parts      -- อะไหล่ที่ใช้ต่อการซ่อม (repair_id, part_id, qty_used, unit_price)

-- คลังอะไหล่
pm_parts             -- master อะไหล่ (code, name, category, unit, unit_price,
                     --   stock_qty, min_stock)
pm_parts_stock_log   -- ประวัติรับเข้า/เบิกออก/ปรับยอด
```

### SQL Files
| ไฟล์ | รายละเอียด | สถานะ |
|------|-----------|-------|
| `pm_schema.sql` | โครงสร้าง DB System 3 (pm_machines, pm_items, pm_logs, pm_downtime, pm_config) | ✅ รันแล้ว |
| `pm_repair_schema.sql` | ตาราง pm_repair_logs, pm_repair_parts, pm_parts, pm_parts_stock_log | ✅ รันแล้ว |
| `pm_meter_schema.sql` | ตาราง pm_meter_logs | ✅ รันแล้ว |
| `planned_hours.sql` | `ALTER TABLE pm_machines ADD COLUMN planned_hours_per_day` | ✅ รันแล้ว |

---

## 5. Global State

```js
_pmMachines      // pm_machines ทั้งหมด (รวม inactive)
_pmItems         // pm_items ทั้งหมด (รวม inactive)
_pmFactories     // ['CDE','Propel','Sanon1','Sanon2','ทั่วไป'] (จาก pm_config)
_pmParts         // pm_parts (คลังอะไหล่)
_pmRepairs       // pm_repair_logs
currentPmUser    // user ที่ login อยู่
```

---

## 6. Logic PM Status

```js
// คำนวณ meter คงเหลือก่อนถึงรอบ PM ถัดไป
calcRemaining(item, machine)
  → remaining = (last_pm_meter + interval_value) - current_meter

// สถานะตาม remaining
pmStatus(remaining, alert_threshold)
  → 'overdue'  : remaining < 0         (🔴 เกินกำหนด)
  → 'alert'    : remaining <= threshold (🟡 ใกล้ถึง)
  → 'ok'       : remaining > threshold  (🟢 ปกติ)

// เรียงลำดับใน pm-items
STATUS_PRIORITY = { overdue:0, alert:1, ok:2 }
```

---

## 7. OEE / Availability (pm-oee)

```
planned_hours_per_day  ← จาก pm_machines.planned_hours_per_day (default 8)
planned_total          = planned_hours_per_day × วันในช่วงที่เลือก
downtime_total         = sum(pm_downtime.duration_hours) ในช่วงนั้น
Availability           = 100 − (downtime_total ÷ planned_total × 100)
```

> ⚠️ ใช้ `planned_hours_per_day` ต่อเครื่อง ไม่ใช่ 24 ชม. (calendar hours)

---

## 8. SSO ข้ามระบบ

```js
// localStorage key ที่ใช้
'_sn_shared_sess'  // SSO token ร่วมกัน System 1/2/3
'_sn_pm_sess'      // Session เฉพาะ System 3

// Flow
doLogin()       → เขียน _sn_shared_sess + _sn_pm_sess
restoreSession() → อ่าน _sn_shared_sess ถ้าไม่มี _sn_pm_sess
doLogout()      → ลบทั้ง _sn_shared_sess + _sn_pm_sess
```

---

## 9. LINE Notification (System 3)

| ตาราง | Trigger | หมายเหตุ |
|-------|---------|---------|
| `pm_repair_logs` | `trg_line_notify` AFTER INSERT | ส่ง LINE ทุกครั้งที่บันทึกการซ่อม |
| Edge Function `pm-daily` | pg_cron ทุกวันจันทร์ 07:00 | แจ้ง PM เกินกำหนด/ใกล้ถึง แยกตามโรงงาน |

---

## 10. pm-items Filter (เพิ่ม 2026-07-31)

```js
// Functions ใหม่
renderPmItemsPage()    // วาง filter bar (factory + machine) + cards area
onPmItemsFacChange()   // เปลี่ยน factory → อัปเดต machine dropdown อัตโนมัติ
renderPmItemCards()    // filter + render เฉพาะ machine ที่ตรง
```

---

## 11. Changelog

### 2026-07-31
- `pm-items`: เพิ่ม filter โรงงาน + เครื่องจักร (`onPmItemsFacChange`, `renderPmItemCards`)
- เพิ่ม PWA tags: `manifest-pm.json`, SW registration

### 2026-07-21
- `pm-meter`: redesign เป็นตารางรวมทุกเครื่อง + filter
- `pm-report` (Section 16B): รายงานรายเดือน + export Excel
- `pm-oee` (Section 16C): Availability จาก `planned_hours_per_day`
- SSO `_sn_shared_sess` ข้ามระบบ
- Edge Function `pm-daily`: LINE Flex Card แจ้ง PM เกินกำหนด

### 2026-07-17
- `pm-items`: แยกออกมาเป็น Sidebar menu ต่างหาก
- `pm-repair` + `pm-parts`: ระบบซ่อม/คลังอะไหล่
- Dashboard: Alert Grid แบบคอลัมน์ต่อโรงงาน
- Factory Management: จัดการโรงงานผ่าน pm_config

### 2026-07-16
- สร้าง `pm.html` และ `pm_schema.sql` ครั้งแรก
- PM Hour-based: dashboard, pm-log, pm-downtime, pm-history, pm-machines
