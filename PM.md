# PM.md — ระบบ PM เครื่องจักร (System 3)
> ไฟล์นี้บันทึกรายละเอียดเฉพาะ `pm.html` — อ่านก่อนแก้ไขทุกครั้ง
> ตั้งแต่ 2026-09-15: สถานะ/ฟีเจอร์ล่าสุดและ Changelog ของ System 3 ทั้งหมดอยู่ที่นี่ — `CLAUDE.md` Section 0 มีแค่บรรทัดสั้นๆ ชี้มาที่ไฟล์นี้เท่านั้น

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
| `pm_sync.sql` | เพิ่มคอลัมน์ `sync_source` + `sync_loader_name` ใน pm_machines พร้อม CHECK constraint | ✅ รันแล้ว (อัปเดตไฟล์เพิ่ม `production_mobile` แล้ว 2026-09-20 — สำหรับติดตั้งใหม่เท่านั้น) |
| `pm_sync_v2_patch.sql` | เพิ่ม `production_mobile` เข้า CHECK constraint `pm_machines_sync_source_check` | ⏳ **ต้องรันก่อนใช้งาน Mobile Plant sync** |

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

## 8. SSO ข้ามระบบ + System Switcher ("เปลี่ยนระบบ")

```js
// localStorage / sessionStorage key ที่ใช้
'_sn_shared_sess'  // SSO token ร่วมกัน System 1/2/3 (localStorage — ข้าม tab)
'_sn_pm_sess'      // Session เฉพาะ System 3 (sessionStorage)
'_sn_inv_sess'     // Session ของ System 2 (เขียนโดย gotoSystem() ตอนออกจาก PM)
'_sn_sess'         // Session ของ System 1 (เขียนโดย gotoSystem() ตอนออกจาก PM)

// Flow
doLogin()        → เขียน _sn_shared_sess + _sn_pm_sess
gotoSystem(url)   → เขียน _sn_pm_sess + _sn_inv_sess + _sn_sess (base object) แล้ว redirect
restoreSession()  → ลำดับ fallback 3 ชั้น (ดูด้านล่าง)
doLogout()       → ลบทั้ง _sn_shared_sess + _sn_pm_sess
```

**`restoreSession()` — ลำดับ fallback 3 ชั้น:**
1. อ่าน `_sn_pm_sess` ของตัวเอง — ถ้ามีใช้เลย
2. Fallback จาก `_sn_inv_sess` / `_sn_sess` (มาจาก `gotoSystem()` ของ System 1/2) → re-fetch `extra_manage` (user + role) และ **`meeting_access`** จาก `app_users` แล้วค่อยตั้ง `currentUser`
3. Fallback จาก `_sn_shared_sess` (localStorage ข้าม tab) → re-fetch เหมือนข้อ 2

> ⚠️ **สำคัญ:** object `base` ที่ `gotoSystem()` เขียนลง session ไม่มี field `meeting_access` (ไม่ใช่ทุก field ของ `app_users`) ดังนั้น `restoreSession()` ทั้ง fallback ข้อ 2 และ 3 **ต้อง re-fetch `meeting_access` จาก `app_users` เองเสมอ** (เพิ่มเมื่อ 2026-09-22) มิฉะนั้นการ์ด "จองห้อง" ในสวิตช์เชอร์จะไม่ขึ้นให้ผู้ใช้ที่ SSO เข้ามาจากระบบอื่น แม้จะมีสิทธิ์จริงก็ตาม

**System Switcher ("เปลี่ยนระบบ") ใน Sidebar** — grid 3 คอลัมน์, ใช้ `gotoSystem('xxx.html')` เสมอ (ไม่ใช้ `<a href="xxx.html">` เฉยๆ เพราะจะไม่ sync session):

| ระบบ | ไฟล์ | สี | Icon | เงื่อนไขแสดงผล |
|------|------|-----|------|----------------|
| ผลิต | `index.html` | น้ำเงิน `#1d4ed8→#2563eb` | `bar-chart-2` | แสดงเสมอ |
| คลัง | `inventory.html` | เขียวอมฟ้า `#0f766e→#0d9488` | `package` | แสดงเสมอ |
| PM | `pm.html` | ส้ม `#b45309→#d97706` | `wrench` | ระบบปัจจุบัน (การ์ด active ไม่ใช่ลิงก์) |
| HR | `checkin.html` | เขียว `#065f46→#059669` | `clock` | แสดงเสมอ |
| จองห้อง | `meeting.html` | ฟ้าเข้ม `#0e7490→#0284c7` | `calendar-check` | เฉพาะ `currentUser?.meeting_access` หรือ `role==='admin'` (ตามเงื่อนไขเดียวกับ System 1) |
| ขอลา | `leave.html` | ม่วง `#6d28d9→#7c3aed` | `clipboard-check` | แสดงเสมอ |

> Portal (`portal.html`) เคยเพิ่มไว้ 2026-09-22 แล้วเอาออกตามคำสั่งคุณใหญ่วันเดียวกัน — ดู Changelog

> **หมายเหตุ:** `checkin.html` และ `leave.html` ใช้ตาราง `checkin_users` (คนละระบบ auth กับ `app_users`) — `gotoSystem()` ยัง sync session ไปให้ได้ตามปกติ (ไม่ error) แต่ผู้ใช้จะต้อง login ใหม่ที่ปลายทางเพราะ session ที่ถูกต้องสำหรับ 2 ระบบนี้เป็นคนละ key/ตาราง — เป็นพฤติกรรมที่ถูกต้องแล้ว ไม่ใช่บั๊ก

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

## 11. Sync มิเตอร์อัตโนมัติจาก System 1 (sync_source)

ตั้งค่าได้ต่อเครื่องจักร (หน้า `pm-machines` → แก้ไข/เพิ่มเครื่อง) — ไม่ต้องกรอกเลขมิเตอร์ 1 (ชม.) เอง ระบบดึงค่าล่าสุดจากตาราง production ของ System 1 หรือ `electric_loader` ให้อัตโนมัติทุกครั้งที่เปิดหน้า `pm-machines` (`syncCurrentMeters()` — Section 16B)

**ตัวเลือก `sync_source` ปัจจุบัน:**

| value | ตาราง.คอลัมน์ที่ดึง | หมายเหตุ |
|---|---|---|
| `manual` | — | กรอกเอง ไม่ sync |
| `production_cde` | `production_cde.stop_hour` | |
| `production_propel` | `production_propel.stop_hour` | |
| `production_sanon1` | `production_sanon1.stop_hour` | |
| `production_sanon2` | `production_sanon2.stop_hour` | |
| `production_mobile` | `production_mobile.stop_hour` | เพิ่ม 2026-09-20 (เดิมขาดจาก dropdown หลัง System 1 เพิ่ม Mobile Plant) |
| `electric_loader` | `electric_loader.machine_hour_stop` | กรองเพิ่มด้วย `sync_loader_name` |

**Logic:** ดึงแถวล่าสุด (เรียงตามวันที่ descending, limit 1) → อัปเดต `pm_machines.current_meter` **เฉพาะเมื่อค่าใหม่มากกว่าค่าปัจจุบัน** (กันค่าเก่า sync ทับค่าที่กรอกมือไว้)

> ⚠️ **ข้อควรระวัง:** ถ้า System 1 เพิ่มโรงงาน/แหล่งข้อมูลใหม่ในอนาคต ต้องเพิ่มพร้อมกัน 3 จุดใน `pm.html` มิฉะนั้นโรงงานใหม่จะ sync มิเตอร์อัตโนมัติไม่ได้:
> 1. `PROD_TABLES` array (Section 16B `syncCurrentMeters()`)
> 2. `SOURCE_LABEL` map (label แสดงผลหน้า `pm-dashboard`)
> 3. `<option>` dropdown **ทั้ง 2 จุด** — modal แก้ไขเครื่อง และฟอร์มเพิ่มเครื่องใหม่ (`am-sync-source`)

> ⚠️ **ข้อควรระวัง (เพิ่ม 2026-09-26):** เพราะ logic กันค่าเก่าทับ (`newMeter > current_meter` เท่านั้นถึงจะอัปเดต) เป็นแบบ **"ขึ้นได้ทางเดียว ลงไม่ได้"** ถ้าข้อมูลต้นทางใน System 1 (เช่น `production_propel.stop_hour`) มีการกรอกผิดพลาด (typo) เป็นตัวเลขที่สูงผิดปกติแม้เพียงแถวเดียว ค่านั้นจะถูก sync เข้า `pm_machines.current_meter` ทันทีและ **ค้างอยู่ถาวร** — วันถัดๆ ไปที่ข้อมูลถูกต้อง (ค่าน้อยกว่า) จะถูก logic นี้เพิกเฉยไปเรื่อยๆ ไม่มีทางแก้ไขตัวเองอัตโนมัติ ต้องแก้ 2 จุดพร้อมกันคือ (1) ข้อมูลผิดในตาราง production ต้นทาง และ (2) ค่า `current_meter` ที่ค้างผิดใน `pm_machines` โดยตรง — ดูกรณีจริงที่พบใน Changelog 2026-09-26

**ปุ่ม "บังคับซิงก์ใหม่" (`forceSyncMachine()`, เพิ่ม 2026-09-26):** ปุ่มไอคอน `rotate-ccw` สีเขียว ในการ์ดแต่ละเครื่องจักรที่หน้า `pm-machines` (แสดงเฉพาะเครื่องที่ตั้ง `sync_source` ≠ manual และผู้ใช้เป็น manager ขึ้นไป) — ดึงค่าล่าสุดจากต้นทางเดียวกับ `syncCurrentMeters()` ทุกประการ แต่**ไม่มี guard "ต้องมากกว่าเดิม"** จึงเขียนทับ `current_meter` ได้ทั้งขึ้นและลง มี `confirm()` แสดงค่าเดิม/ค่าใหม่/ทิศทางก่อนบันทึกเสมอ ใช้สำหรับกรณีแก้ไขข้อมูลต้นทางที่เคยกรอกผิดแล้ว ต้องการดึงค่าที่ถูกต้อง (ซึ่งอาจต่ำกว่าเดิม) กลับมาโดยไม่ต้องรอ SQL แก้มือ

---

## 12. Changelog

### 2026-09-26 (รอบ 2) — เพิ่มปุ่ม "บังคับซิงก์ใหม่" (force resync) ต่อเครื่องจักร

**คำสั่งคุณใหญ่:** หลังแก้ไขข้อมูลวันที่ 13 ก.ย. ใน `production_propel` เรียบร้อยแล้ว ขอปุ่มสำหรับกรณีถ้ามีการกรอกเลขผิดอีกในอนาคต แก้ไขข้อมูลต้นทางแล้ว แล้วกดบังคับซิงก์ดึงค่าที่ถูกต้องกลับมาได้เอง โดยไม่ต้องรอแก้ `current_meter` ด้วย SQL มือ

**ปัญหาเดิม:** ปุ่ม "ซิงค์ชั่วโมง" (`syncAndRefreshMachines()`) ที่มีอยู่เดิม เรียก `syncCurrentMeters()` ซึ่งมี guard "อัปเดตเฉพาะค่าใหม่ > ค่าเดิม" (กันมิเตอร์รีเซ็ตทับ) — ถ้าค่าที่ค้างอยู่สูงผิดพลาด (เช่นกรณี Propel 59,108 ชม.) แม้แก้ข้อมูลต้นทางถูกต้องแล้ว ปุ่มเดิมก็ยังดึงค่าที่ถูกต้อง (ต่ำกว่า) กลับมาไม่ได้ ต้องรอผมแก้ `current_meter` ตรงในฐานข้อมูลให้ทุกครั้ง

**แก้ไข (`pm.html`):**
- เพิ่มฟังก์ชัน `forceSyncMachine(machineId)` — ดึงค่าล่าสุดจากต้นทางเดียวกับ `syncCurrentMeters()` (ใช้ `PROD_TABLES`/`electric_loader` logic เดียวกันทุกประการ) แต่**ไม่มี guard "ต้องมากกว่าเดิม"** จึงเขียนทับ `current_meter` ได้ทั้งขึ้นและลง
- แสดง `confirm()` บอกค่าปัจจุบัน → ค่าจากต้นทาง (พร้อมทิศทางเพิ่ม/ลด) ก่อนยืนยันเขียนทับทุกครั้ง กันกดพลาด
- เพิ่มปุ่มไอคอน `rotate-ccw` สีเขียว ในการ์ดเครื่องจักรแต่ละเครื่องที่หน้า `pm-machines` (ถัดจากปุ่มแก้ไข/ลบ) — แสดงเฉพาะเครื่องที่ตั้ง `sync_source` ≠ manual **และผู้ใช้เป็น manager ขึ้นไปเท่านั้น** (จำกัดสิทธิ์เพราะเป็นการเขียนทับข้อมูลมิเตอร์โดยตรง)

**ตรวจสอบ:** `node --check` ผ่าน syntax ของ inline script ทั้งไฟล์ + `diff` ยืนยันว่าแก้เฉพาะ 2 จุดที่ตั้งใจ (ปุ่มในการ์ด + ฟังก์ชันใหม่) ไม่กระทบส่วนอื่น

**ไฟล์ที่แก้ไข:** `pm.html`, `PM.md`
**Copy ไป GitHub/:** `pm.html` ✅

---

### 2026-09-26 — ตรวจพบ current_meter ค้างผิดจากข้อมูลต้นทาง System 1 กรอกผิด (โรงงาน Propel)

**คำสั่งคุณใหญ่:** ส่งภาพหน้า Dashboard มาถามว่า "เครื่องล้างหิน Propel" และ "Filter Press Propel" ที่ขึ้นเลขซิงก์เท่ากัน **59,108 ชม.** ทั้งคู่ — อัปเดตข้อมูลตรงกันไหม

**ขั้นตอนตรวจสอบ:** เข้าหน้า `pm.html` ที่ deploy จริงผ่านเบราว์เซอร์ (ตรง `https://sanon-saraburi.github.io/sanon-webapp/pm.html`) แล้วรัน query ผ่าน Supabase client ของหน้าเว็บเอง (`db.from(...)`) เทียบข้อมูลจริงเพราะ direct API/curl จาก container ถูก network allowlist บล็อก:

1. **`pm_machines`** — ยืนยันว่าทั้ง 2 เครื่องมี `sync_source='production_propel'` ตรงกัน จึงเป็น**เรื่องปกติที่ค่าจะเท่ากัน** (ดึงจากตาราง production ต้นทางเดียวกัน ไม่ใช่บั๊กที่ค่าเท่ากัน) และ `current_meter` ทั้งคู่ = 59,108 ตรงกับที่ Dashboard แสดง
2. **`production_propel`** (ตรวจตาม logic เดียวกับ `syncCurrentMeters()` เป๊ะ: `order by production_date desc limit 1 where stop_hour not null`) — พบว่าแถวล่าสุดจริง (2026-09-20) มี `stop_hour = 6,008` เท่านั้น **ไม่ตรงกับ 59,108 ที่ sync ไว้**
3. ไล่ดู trend ย้อนหลัง: ค่าตั้งแต่ 2025-01-01 (`stop_hour=667`) ไล่ขึ้นเรื่อยๆ อย่างสม่ำเสมอถึง ~6,008 ในปัจจุบัน (เพิ่มวันละ ~10-15 ชม.) **ยกเว้นแถวเดียว**: `production_date=2026-09-13` มี `start_hour=stop_hour=59,108` (บันทึกย้อนหลังเมื่อ `created_at=2026-09-22`, หมายเหตุ "หยุดเครื่อง 1 วัน *วันเกิดเสี่ยจ๋อง เจ๊อู๊ด") — สูงผิดปกติเทียบวันข้างเคียง (09-12 ≈ 09-14 ควรอยู่แถว ~5,970-5,990) น่าจะเป็นการกรอกข้อมูลผิดพลาด (สังเกตว่าฟิลด์ `meter_start`/`meter_stop` ของแถวเดียวกันก็เท่ากับ 61,622 ซึ่งเป็นคนละฟิลด์แต่ตัวเลขสเกลใกล้เคียงกัน อาจกรอกสลับฟิลด์)

**Root cause:** แถวข้อมูลผิดพลาด 1 แถวในตาราง **`production_propel`** (ข้อมูลของ System 1 ไม่ใช่โค้ด `pm.html`) ถูก `syncCurrentMeters()` ดึงไปเป็นค่าสูงสุดตาม logic "อัปเดตเฉพาะเมื่อค่าใหม่มากกว่าค่าปัจจุบัน" (ทำงานถูกต้องตามที่ออกแบบไว้) แล้วค่านั้น**ค้างอยู่ถาวร** เพราะวันถัดๆ มาข้อมูลที่ถูกต้อง (~5,983-6,008) ต่ำกว่าค่าที่ค้างไว้ จึงไม่มีวันถูกอัปเดตทับเองอัตโนมัติ — ดูรายละเอียด logic นี้เพิ่มที่ Section 11

**สรุปคำตอบคุณใหญ่:** ❌ **เลขไม่ตรง** — 59,108 ชม. เป็นค่าที่ค้างผิดจากข้อมูลกรอกผิดในระบบผลิต (System 1) เมื่อ 2026-09-13 ไม่ใช่ชั่วโมงจริงปัจจุบัน (ค่าจริงล่าสุดคือ ~6,008 ชม. ณ 2026-09-20)

**ยังไม่ได้แก้ไขข้อมูล** (รอการยืนยัน) — ต้องแก้ 2 จุด:
1. แก้แถว `production_propel` วันที่ 2026-09-13 ให้เป็นค่าที่ถูกต้อง (นอก scope ของแชตนี้ — เป็นข้อมูล System 1 ต้องแจ้ง/ขอทีมระบบผลิตแก้ หรือคุณใหญ่ยืนยันให้ผมแก้ตรงๆ ในฐานข้อมูลก็ได้)
2. แก้ `pm_machines.current_meter` ของทั้ง 2 เครื่อง (เครื่องล้างหิน Propel, Filter Press Propel) กลับเป็นค่าที่ถูกต้อง (~6,008 หรือค่าล่าสุดหลังแก้ข้อ 1) — จุดนี้อยู่ใน scope System 3 ของผม แต่เป็นการแก้ข้อมูลตรง ไม่ใช่แก้โค้ด จึงขอยืนยันจากคุณใหญ่ก่อนดำเนินการ

**ไฟล์ที่แก้ไข:** `PM.md` (บันทึกผลตรวจสอบ + เพิ่มคำเตือนใน Section 11) — ยังไม่แก้ `pm.html` หรือฐานข้อมูล

---

### 2026-09-22 (รอบ 3) — เอาการ์ด Portal ออกจาก System Switcher

**คำสั่ง:** คุณใหญ่ให้เอาการ์ด Portal ออก (หลังเห็นภาพหน้าจอที่ Portal ไม่ขึ้น — ไม่ทราบสาเหตุที่แท้จริงว่าเป็นแคชหรือคุณใหญ่ตัดสินใจไม่ต้องการการ์ดนี้)

**แก้ไข (`pm.html`):** ลบการ์ด `<a>` ของ `gotoSystem('portal.html')` ออกจาก switcher — เหลือ 6 การ์ด (ผลิต, คลัง, PM, HR, จองห้อง, ขอลา) พอดี 2 แถว × 3 คอลัมน์ ไม่มีที่ว่างเหลือ

**คงไว้:** การแก้ `overflow-y-auto` ของ `<nav>` (รอบ 2) — ยังมีประโยชน์ป้องกันเนื้อหาล้นจอในอนาคตแม้ไม่มี Portal แล้ว

**ไฟล์ที่แก้ไข:** `pm.html`, `PM.md`
**Copy ไป GitHub/:** `pm.html` ✅

---

### 2026-09-22 (รอบ 2) — sidebar nav ไม่มี scroll เสี่ยงเนื้อหาล้นจอหลังสวิตช์เชอร์ใหญ่ขึ้น

**ปัญหา:** คุณใหญ่ส่งภาพหน้าจอมาถามว่าใช่หน้าตาที่แก้ไหม — พบว่าการ์ด **Portal** (การ์ดที่ 7 ของสวิตช์เชอร์) ไม่ปรากฏในภาพ ทั้งที่ตรวจโค้ดในไฟล์แล้วมีอยู่ถูกต้อง — สาเหตุที่เป็นไปได้ 2 ทาง: (1) แคช/PWA service worker เสิร์ฟไฟล์เก่า (`pm.html` อยู่ใน `PRECACHE` ของ `sw.js`) หรือ (2) `<nav>` เมนูหลักใน sidebar **ไม่มี `overflow-y-auto`** ต่างจาก `index.html` — เมื่อสวิตช์เชอร์โตขึ้นจาก 1 แถวเป็น 3 แถว เนื้อหารวมของ sidebar อาจสูงเกินจอ แล้วถูกตัดโดย `overflow-hidden` ของ container นอกสุด (`flex h-screen overflow-hidden`) โดยไม่มี scrollbar ให้เลื่อนดู

**แก้ไข (`pm.html`):** เพิ่ม `overflow-y-auto` ให้ `<nav>` เมนูหลัก (บรรทัดเดิม `class="flex-1 px-3 py-3 space-y-0.5"` → เพิ่ม `overflow-y-auto`) ให้ตรงกับ pattern ของ `index.html` — เมนูจะเลื่อนดูได้เองถ้ายาวเกินจอ โดยสวิตช์เชอร์+ปุ่มออกจากระบบด้านล่างจะไม่ถูกดันหายไป

**ยังต้องตรวจสอบเพิ่ม (ฝั่งคุณใหญ่):** กด Hard Refresh (Ctrl+Shift+R) หรือล้าง cache ของ PWA แล้วลองดูอีกครั้ง — ถ้าทดสอบผ่าน GitHub Pages URL ต้อง upload ไฟล์ใน `GitHub/` ขึ้น GitHub ก่อนด้วย (ยังไม่ได้ upload ให้อัตโนมัติ)

**ไฟล์ที่แก้ไข:** `pm.html`, `PM.md`
**Copy ไป GitHub/:** `pm.html` ✅

---

### 2026-09-22 — เพิ่มลิงก์ครบทุกระบบใน System Switcher ("เปลี่ยนระบบ")

**สั่งการจาก:** ประกาศกลาง — ให้ทุกระบบตรวจสอบ/เพิ่มลิงก์ในสวิตช์ "เปลี่ยนระบบ" ให้ครบทุกระบบ (7 ไฟล์) โดยใช้ pattern `gotoSystem('xxx.html')` เสมอ

**ปัญหาเดิม:** สวิตช์ "เปลี่ยนระบบ" ใน `pm.html` (sidebar) มีลิงก์แค่ 2 ระบบ (ผลิต, คลัง) นอกจาก PM เอง — ขาด HR, จองห้อง, ขอลา, และ **Portal** (จุดที่มักตกหล่นตามที่ประกาศระบุ)

**แก้ไข (`pm.html`):**
- เปลี่ยน container จาก `flex gap-1.5` (แถวเดียว, การ์ด `flex-1`) → `grid grid-cols-3 gap-1.5` (รองรับ 7 การ์ดพอดี ไม่บีบจนอ่านไม่ออก)
- เพิ่มการ์ด **HR** (`checkin.html`), **จองห้อง** (`meeting.html` — เงื่อนไข `meeting_access`/`admin` เหมือน System 1), **ขอลา** (`leave.html`), **Portal** (`portal.html` — สีเทาเข้ม `#334155→#475569`, icon `layout-grid`, คิดค้นใหม่เพราะยังไม่มีระบบไหนอ้างอิงสีของ Portal มาก่อน)
- เพิ่ม `event.preventDefault();` หน้า `gotoSystem(...)` ทุกการ์ด (ของเดิม 2 การ์ดแรกไม่มี) ให้ตรง pattern เดียวกับ `index.html`

**พบและแก้บั๊กที่เกี่ยวข้อง (ไม่ได้อยู่ใน scope เดิมแต่กระทบฟีเจอร์ที่เพิ่ม):**
`restoreSession()` fallback (SSO จากระบบอื่น) ไม่เคย re-fetch `meeting_access` จาก `app_users` — ทำให้การ์ด "จองห้อง" ที่เพิ่งเพิ่มจะไม่ขึ้นให้ผู้ใช้ที่มีสิทธิ์จริงแต่ SSO เข้ามาจาก index.html/inventory.html (มีแต่ตอน login ตรงที่ `pm.html` เท่านั้นที่เห็น) — แก้โดยเพิ่ม query `app_users.meeting_access` ใน fallback ทั้ง 2 ชั้น (`_sn_inv_sess`/`_sn_sess` และ `_sn_shared_sess`)

**ไม่ต้องรัน SQL เพิ่ม**

**ที่ยังไม่ได้แก้ (นอก scope — เป็นของแชตอื่น):** พบว่า `index.html` เองก็ไม่มีลิงก์กลับ Portal ในสวิตช์เดียวกันนี้เช่นกัน — แจ้งให้ System 1 ตรวจสอบเพิ่ม

**ไฟล์ที่แก้ไข:** `pm.html`, `PM.md`
**Copy ไป GitHub/:** `pm.html` ✅

---

### 2026-09-20 (รอบ 2) — แก้ CHECK constraint บล็อกการบันทึก sync_source='production_mobile'

**ปัญหา:** หลังเพิ่ม dropdown `production_mobile` ใน `pm.html` แล้ว คุณใหญ่ทดสอบบันทึกจริงแล้วเจอ error:
> `บันทึกไม่สำเร็จ: new row for relation "pm_machines" violates check constraint "pm_machines_sync_source_check"`

**Root cause:** คอลัมน์ `pm_machines.sync_source` มี CHECK constraint (สร้างจาก `pm_sync.sql`) จำกัดค่าที่รับได้ไว้ตายตัว — ตอนแก้ frontend (รอบแรกวันเดียวกัน) ลืมว่ามี constraint ระดับ database กั้นอยู่ด้วย ไม่ใช่แค่ dropdown ฝั่ง JS

**แก้ไข:**
- สร้าง `pm_sync_v2_patch.sql` — DROP + ADD CONSTRAINT `pm_machines_sync_source_check` ใหม่ ให้รวม `'production_mobile'`
- อัปเดต `pm_sync.sql` เดิมให้มี `production_mobile` ในรายการ CHECK ด้วย (สำหรับกรณีติดตั้งระบบใหม่ตั้งแต่ต้น)

**⏳ คุณใหญ่ต้องรัน `pm_sync_v2_patch.sql` ใน Supabase SQL Editor ก่อน** จึงจะบันทึก sync_source='production_mobile' ได้จริง

**ไฟล์ที่แก้ไข:** `pm_sync_v2_patch.sql` (ใหม่), `pm_sync.sql`, `PM.md`

---

### 2026-09-20 — เพิ่ม production_mobile (Mobile Plant) เข้า Sync มิเตอร์อัตโนมัติ

**ปัญหา:** คุณใหญ่แจ้งว่า dropdown "ดึงชั่วโมงอัตโนมัติจาก System 1" ในหน้าแก้ไข/เพิ่มเครื่องจักร ไม่มีตัวเลือก Mobile Plant (โรงงานที่ 5 ที่ System 1 เพิ่มเมื่อ 2026-09-02) ทำให้เครื่องจักรโซน Mobile Plant sync มิเตอร์อัตโนมัติไม่ได้

**แก้ไข (`pm.html`):**
- `SOURCE_LABEL`: เพิ่ม `production_mobile:'Mobile Plant'`
- `PROD_TABLES` (Section 16B `syncCurrentMeters()`): เพิ่ม `'production_mobile'` — ดึงจาก `production_mobile.stop_hour`
- Dropdown `sync_source`: เพิ่มตัวเลือก `Mobile Plant — production_mobile.stop_hour` ใน 2 จุด (modal แก้ไขเครื่อง + ฟอร์มเพิ่มเครื่องใหม่)

**⚠️ อัปเดต:** ขั้นตอนนี้แก้แค่ฝั่ง frontend — ยังต้องรัน SQL patch เพิ่ม (ดูรายการถัดไปด้านบน) ก่อนจึงจะบันทึกได้จริง

**ไฟล์ที่แก้ไข:** `pm.html`, `PM.md`
**Copy ไป GitHub/:** `pm.html` ✅

---

### 2026-08-05 — เรียงรายการ PM ตามสถานะ + คอลัมน์วันที่ PM ล่าสุด

**`fillItemOpts()` แก้ใหม่:**
- Dropdown "ประเภท PM" ใน modal บันทึก PM เรียงลำดับตามสถานะ:
  - 🔴 เกินกำหนด (remaining ≤ 0) → แสดงก่อน
  - 🟡 ใกล้ถึงกำหนด (0 < remaining ≤ alert_threshold) → แสดงกลาง
  - 🟢 ปกติ → แสดงท้าย
- ใช้ `<optgroup>` แบ่งหมวดให้เห็นชัด
- แสดงจำนวน ชม./กม. คงเหลือในชื่อ option เช่น `Apex Hydrocyclone ทรายหยาบ (-229 ชม.)`
- คำนวณจาก `last_pm_meter + interval_value - current_meter`

**`renderLogPage()` แก้ใหม่:**
- Query เพิ่ม `pm_items(last_pm_date, interval_value)` ผ่าน foreign key join
- เพิ่มคอลัมน์ **"วันที่ PM ล่าสุด"** ระหว่าง "ประเภท PM" กับ "Meter ที่ทำ"
- แสดง `pm_items.last_pm_date` ของรายการ PM นั้น (วันที่ทำ PM ครั้งล่าสุดตาม record)
- เพิ่ม colspan จาก 8 → 9 (รวมคอลัมน์ใหม่)
- เปลี่ยนหัวคอลัมน์แรกจาก "วันที่" → "วันที่บันทึก" ให้ชัดเจนขึ้น

**Copy ไป GitHub/:** `pm.html` ✅

---

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
