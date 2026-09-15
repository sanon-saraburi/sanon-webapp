# PRODUCTION.md — ระบบผลิต (System 1)
> ไฟล์นี้บันทึกรายละเอียดเฉพาะ `index.html` — อ่านก่อนแก้ไขทุกครั้ง
> ตั้งแต่ 2026-09-15 ไฟล์นี้เป็นที่เก็บ "สถานะ/ฟีเจอร์ล่าสุด" + "Changelog" ของ System 1 ทั้งหมด — ดู `CLAUDE.md` Section 0A สำหรับเหตุผลที่แยกไฟล์

---

## 0. สถานะล่าสุด (อัปเดต 2026-09-15)

✅ ใช้งานจริง — Dashboard ทุกเมนู (CDE/Propel/Sanon1/Sanon2/Mobile Plant), Executive Dashboard, รายงานรายปี (dash-annual: Dashboard + PDF + PPTX Export ทุกโรงงาน), ค่าไฟฟ้า, PDF Report, SSO, Mobile/Desktop System Switcher 6 ระบบ, LINE แจ้งเตือนจาก JS, Export CSV ทุกโรงงาน, Mobile Plant (โรงงานที่ 5 — Dashboard + ยอดผลิต + Approval ครบ), เพิ่มโรงงาน: กำหนดเป้าตัน/เดือน + ตัน/ชม. จาก UI ได้ทุกโรงงาน, วิเคราะห์รายวัน (กราฟ/ตาราง/Breakdown ครบทุกโรงงาน + auto-detect วันล่าสุดที่มีข้อมูล), material_types (is_feed_material + is_product), groundwater_usage (ผู้บันทึก), drone factory sort ตามลำดับ CDE→Propel→Sanon1→Sanon2→Mobile Plant

**ปัญหาที่รู้อยู่:** ต้องรัน SQL patches สำหรับ Mobile Plant ให้ครบ (ดู Section 11 — Changelog 2026-09-02)

---

## 1. ข้อมูลระบบ

- **ไฟล์:** `index.html` (~12,100+ บรรทัด)
- **สถานะ:** ✅ ใช้งานจริง
- **Supabase:** `https://pcmpwkcmvsxrvbximjgf.supabase.co`
- **Anon Key:** `sb_publishable_RckQgaumQeIgaCICUc_6ZQ_T42qI2Nq`
- **Session key:** `_sn_sess` (SSO ใช้ `_sn_shared_sess` ข้ามระบบ)
- **GitHub Pages:** `https://sanon-saraburi.github.io/sanon-webapp/index.html`

---

## 2. Architecture

- **Pattern:** Single-file SPA, 30 Sections, Vanilla JS
- **Libraries:** Tailwind CDN, Lucide Icons, Chart.js, SheetJS (xlsx), PptxGenJS
- **Font:** Kanit (Google Fonts)
- **Auth:** query `app_users` table โดยตรง (ไม่ใช้ Supabase Auth)
- **Session Timeout:** 2 ชั่วโมง (ยกเว้น admin)
- **Factory normalize:** `Sanon 1` → `Sanon1`, `Sanon 2` → `Sanon2`

---

## 3. เมนูทั้งหมด

### Dashboard (prefix: `dash-`)
| key | ชื่อ | ข้อมูลจากตาราง |
|-----|------|--------------|
| `dash-cde` | Dashboard CDE | `production_cde` |
| `dash-propel` | Dashboard Propel | `production_propel` |
| `dash-sanon1` | Dashboard Sanon1 | `production_sanon1` |
| `dash-sanon2` | Dashboard Sanon2 | `production_sanon2` |
| `dash-drone` | สต็อกหินโดรน | `drone_stock` |
| `dash-sales` | ยอดขาย | `sales` |
| `dash-loader` | รถตักไฟฟ้า | `electric_loader` |
| `dash-water` | น้ำบาดาล | `groundwater_usage` |
| `dash-electricity` | ค่าไฟฟ้า | `electricity_costs` |
| `dash-executive` | Executive Dashboard | รวม 7 ตาราง parallel |
| `dash-mobile` | Dashboard Mobile Plant (โรงงานที่ 5) | `production_mobile` |
| `dash-annual` | รายงานรายปี (รายโรงงาน + PDF + PPTX Export) | production tables + `factories` |

### จัดการข้อมูล (prefix: `manage-`)
| key | ชื่อ |
|-----|------|
| `manage-approvals` | รออนุมัติยอดผลิต |
| `manage-prod-cde` | บันทึกยอดผลิต CDE |
| `manage-prod-propel` | บันทึกยอดผลิต Propel |
| `manage-prod-sanon1` | บันทึกยอดผลิต Sanon1 |
| `manage-prod-sanon2` | บันทึกยอดผลิต Sanon2 |
| `manage-prod-mobile` | บันทึกยอดผลิต Mobile Plant (โรงงานที่ 5) |
| `manage-electric-loader` | รถตักไฟฟ้า |
| `manage-sales` | ยอดขาย |
| `manage-groundwater` | น้ำบาดาล |
| `manage-electricity` | ค่าไฟฟ้า (upsert รายเดือน) |
| `manage-drone-stock` | สต็อกหินโดรน |
| `manage-reports` | รายงาน (multi-table, DnD) |
| `manage-materials` | ประเภทวัสดุ |
| `manage-factories` | โรงงาน |
| `manage-machines` | เครื่องจักร |
| `manage-water-sources` | แหล่งน้ำ |
| `manage-users` | จัดการผู้ใช้ (admin) |
| `manage-settings` | ตั้งค่าระบบ (admin) |

---

## 4. ตาราง Database (System 1)

```sql
-- Production
production_cde        -- ยอดผลิต CDE (feed_ton, product_*, runtime_*)
production_propel     -- ยอดผลิต Propel
production_sanon1     -- ยอดผลิต Sanon1
production_sanon2     -- ยอดผลิต Sanon2
production_mobile     -- ยอดผลิต Mobile Plant (โรงงานที่ 5, UH312/QA451 columns)
approval_log          -- log การอนุมัติ/ปฏิเสธ

-- Master Data
app_users             -- ผู้ใช้งานทุกระบบ (full_name, username, role, factory, department)
roles                 -- roles ที่มีในระบบ
role_permissions      -- สิทธิ์ต่อ role
user_permissions      -- สิทธิ์ override รายบุคคล
factories             -- โรงงาน
machines              -- เครื่องจักร (ใน System 1)
material_types        -- ประเภทวัสดุ
water_sources         -- แหล่งน้ำ

-- Other Data
drone_stock           -- สต็อกหิน (บินโดรน)
electric_loader       -- รถตักไฟฟ้า
sales                 -- ยอดขาย
groundwater_usage     -- น้ำบาดาล
electricity_costs     -- ค่าไฟฟ้า (factory, year, month, baht, kwh)
```

### SQL Files
| ไฟล์ | รายละเอียด | สถานะ |
|------|-----------|-------|
| `schema.sql` | โครงสร้าง DB System 1 ทั้งหมด | ✅ รันแล้ว |
| `electricity_schema.sql` | ตาราง electricity_costs | ✅ รันแล้ว |
| `line_webhook.sql` | Trigger ส่ง LINE ทุกตาราง | ✅ รันแล้ว (มี Authorization header) |

---

## 5. Global State

```js
currentUser           // user ที่ login อยู่ {id, username, full_name, role, factory, department}
currentPage           // หน้าที่แสดงอยู่
pendingApprovalCount  // จำนวน pending รออนุมัติ (4 production tables)
chartRegistry         // Chart.js instances (destroy ก่อน re-render)
sessionTimerInterval  // Timer Session Timeout
```

---

## 6. RBAC System

- `admin` → สิทธิ์เต็มทุกเมนู (hardcode)
- Role อื่น → สิทธิ์จาก `role_permissions` + `user_permissions` (override รายบุคคล)
- **Permission Templates (PERM_TEMPLATES):** Manager CDE/Sanon, Supervisor, Operator, Clerk
- `getAllowedMenus(user)` → คืน array ของ menu key ที่ user มีสิทธิ์

---

## 7. SSO ข้ามระบบ

```js
// localStorage key ที่ใช้
'_sn_shared_sess'  // SSO token ร่วมกัน System 1/2/3
'_sn_sess'         // Session เฉพาะ System 1

// Flow
doLogin()  → เขียน _sn_shared_sess + _sn_sess
Bootstrap  → อ่าน _sn_shared_sess ถ้าไม่มี _sn_sess
doLogout() → ลบทั้ง _sn_shared_sess + _sn_sess
```

---

## 8. LINE Notification

| ตาราง | Trigger | หมายเหตุ |
|-------|---------|---------|
| `production_cde/propel/sanon1/sanon2` | `trg_line_notify` AFTER INSERT | ส่ง LINE ทุกครั้งที่บันทึกยอด |
| ⚠️ Authorization header | ต้องมีใน `notify_line_on_insert()` เสมอ | ไม่งั้น Edge Function ไม่รับ |

---

## 9. PDF Executive Report (Section 30)

- ดึงข้อมูล 7 ตาราง: production × 4, drone_stock, electricity_costs, inventory pending
- คำนวณ Traffic Light 🟢🟡🔴 ตาม KPI
- Export เป็น PDF ด้วย browser print

---

## 10. กฎสำคัญของโค้ด

- **ห้ามใช้ localStorage** สำหรับข้อมูล production (ใช้ in-memory เท่านั้น)
- ยกเว้น SSO token `_sn_shared_sess` และ session `_sn_sess` ที่ต้องใช้ localStorage
- `escapeHtml()` ทุกครั้งที่ render ข้อมูลจาก DB ลง HTML
- `destroyChart(id)` ก่อน create chart ใหม่เสมอ

---

## 11. Changelog

### 2026-09-15 — แก้นำเข้า Excel/CSV ยอดขายพังเมื่อไม่มีวันที่

**ปัญหาที่พบ:** หน้า "จัดการยอดขาย" กด "นำเข้า Excel/CSV" แล้วขึ้น error `นำเข้าข้อมูลล้มเหลว: invalid input syntax for type date: ""`

**Root cause:** ฟังก์ชัน `importSalesExcel()` เดิมส่งค่า `sale_date` เป็น empty string `''` เข้า Supabase เมื่อไฟล์ที่นำเข้าไม่มีวันที่ในแถวนั้น — Postgres ปฏิเสธเพราะ column เป็น type `date` รับ `''` ไม่ได้ ทำให้การ insert ทั้งชุดล้มเหลว

**แก้ไข (`importSalesExcel()` บรรทัด ~7402):**
- ตรวจสอบก่อน insert: ถ้าแถวไหนไม่มีวันที่ → เก็บเลขแถวไว้ใน `missingDate[]`
- ถ้ามีแถวขาดวันที่ → แจ้งเตือนระบุเลขแถวที่มีปัญหา แล้ว**หยุดการนำเข้าทั้งหมด** (ไม่ insert บางส่วน) ให้แก้ไฟล์ต้นทางแล้วอัปโหลดใหม่ — ไม่เดาใส่วันที่ให้เอง

**ไม่ต้องรัน SQL เพิ่ม**

### 2026-09-11 — แก้ CSV Export แถวสูงผิดปกติ (breakdown_detail หลายบรรทัด)

**ปัญหาที่พบ:** Export CSV จากหน้า `manage-prod-*` แล้วเปิดใน Excel บางแถวสูงผิดปกติ

**Root cause:** ช่อง `breakdown_detail` มีข้อความหลายบรรทัด ระบบ export ครอบด้วย `"..."` ตามมาตรฐาน CSV ถูกต้อง แต่ Excel ขยายความสูงแถวอัตโนมัติเมื่อเจอ cell ที่มีการขึ้นบรรทัดใหม่ภายใน

**แก้ไข (`exportProductionExcel()` บรรทัด ~6177):** แปลงตัวขึ้นบรรทัดใหม่ (`\r\n`,`\r`,`\n`) ในทุกค่าที่ export เป็นตัวคั่น `" / "` ก่อนเขียนลง CSV — ทุกแถวอยู่บรรทัดเดียวเสมอ ไม่กระทบข้อมูลจริงใน DB

**ไม่ต้องรัน SQL เพิ่ม**

### 2026-09-08 — วิเคราะห์รายวัน + แก้ material_types + groundwater + drone sort

- **Section 12B ใหม่ — Daily Analysis Block** (ทุกโรงงาน CDE/Propel/Sanon1/Sanon2/Mobile Plant): กราฟ Bar+Line รายวัน (ยอดป้อน + Throughput + เส้น target), ตารางรายวันครบ (วันที่/ยอดป้อน/Runtime/Throughput สี 🟢🟡🔴/product columns/Breakdown + แถวรวม/เฉลี่ย)
- **"รายวัน" mode auto-detect วันล่าสุดที่มีข้อมูล** — เดิมแสดงวันนี้ (ไม่มีข้อมูล) ใหม่แสดงวันล่าสุดที่บันทึกไว้จริง
- **material_types:** เพิ่ม `is_feed_material` + `is_product` — checkbox ในฟอร์ม, คอลัมน์ในตาราง, dropdown บันทึกยอดผลิตกรองเฉพาะ feed material ของโรงงานที่ตรงกัน
- **groundwater_usage:** เพิ่มคอลัมน์ "ผู้บันทึก" (`recorder_name`)
- **Drone stock:** เรียงปุ่มกรองโรงงานตามลำดับ CDE→Propel→Sanon1→Sanon2→Mobile Plant (ไม่ใช่ alphabetical)

**SQL:** `ALTER TABLE material_types ADD COLUMN IF NOT EXISTS is_feed_material boolean DEFAULT false;` + `is_product` เช่นกัน, `ALTER TABLE groundwater_usage ADD COLUMN IF NOT EXISTS recorder_name text;` (รันแล้ว)

### 2026-09-04 — System Switcher เปลี่ยนชื่อเป็น HR + การ์ดจองห้องซ่อนตามสิทธิ์

- System Switcher: "เช็คอิน" → "HR" (Desktop sidebar + Mobile bottom sheet)
- การ์ด "จองห้อง" แสดงเฉพาะ `currentUser.meeting_access === true` หรือ `role === 'admin'` — Admin กำหนดสิทธิ์ผ่าน SQL `UPDATE app_users SET meeting_access = true WHERE username = 'xxx';`

### 2026-09-03 — เพิ่ม Annual Report Dashboard (dash-annual) + PPTX Export

- เมนูใหม่ `dash-annual` "รายงานรายปี" — Section 29B: Factory tabs (CDE/Propel/Sanon1/Sanon2/Mobile Plant), Year dropdown ย้อนหลัง 5 ปี, KPI cards 4 ใบ, Chart.js bar+line Actual vs แผน, ตารางสรุปรายเดือน + ตารางผลิตภัณฑ์รายเดือน
- ปุ่ม PDF (`printAnnualReport()`) + ปุ่ม Export PPTX (`generateAnnualPptx()` — โหลด PptxGenJS 3.12.0 จาก cdnjs on-demand, สร้างสไลด์ Cover + Overview + ต่อโรงงาน 5 โรงงาน × 2 สไลด์)
- สีตามโรงงาน: CDE=teal, Propel=blue, Sanon1=purple, Sanon2=red, Mobile=orange
- ไม่ต้องรัน SQL เพิ่ม — ใช้ข้อมูลจาก production tables และ factories table เดิม

### 2026-09-02 รอบ 2 — แก้ Runtime Mobile Plant + เป้าตัน/เดือน + sw.js v6

- **แก้ Runtime Mobile Plant:** root cause `runtime_hour` เป็น GENERATED ALWAYS จาก `runtime_minute` ที่ default 0 ไม่มี trigger คำนวณจาก start/stop hour — สร้าง trigger `calc_mobile_runtime()` คำนวณใหม่
- **เป้าผลิต (ตัน/เดือน):** เพิ่ม column `target_month` ใน `factories`, ช่องกรอกในฟอร์มเพิ่มโรงงาน, ใช้ได้ทุกโรงงาน (CDE 30,000 / Propel 45,000 / Sanon1 100,000 / Sanon2 100,000 / Mobile Plant 84,000 ตัน/เดือน)
- แก้ `factoryErr` ไม่ crash Dashboard เมื่อไม่พบแถว factory
- `sw.js` → v6: แก้ bug root URL `/sanon-webapp/` ถูก Cache First แทน Network First

**SQL ที่ต้องรันใน Supabase (ถ้ายังไม่ได้รัน):** `ALTER TABLE production_mobile DROP COLUMN IF EXISTS runtime_hour;` → `ADD COLUMN runtime_hour numeric(8,2) DEFAULT 0;` → สร้าง trigger `calc_mobile_runtime` → `UPDATE production_mobile SET updated_at = now();` → `ALTER TABLE factories ADD COLUMN IF NOT EXISTS target_month numeric DEFAULT NULL;` → `NOTIFY pgrst, 'reload schema';`

**⚠️ ข้อควรระวัง:** ชื่อ factory ต้องตรงกับ `cfg.factoryName` ใน code — "Mobile Plant" (1 space) ไม่ใช่ "Mobile  Plant" (2 space)

### 2026-09-02 — เพิ่ม Mobile Plant (โรงงานที่ 5)

- เพิ่มเมนู `dash-mobile`, `manage-prod-mobile`, approval key `approve-mobile`
- Config: `PLANT_FACTORY_CODE.mobile = 'Mobile'`, `PRODUCTION_PLANT_CONFIG.mobile` (productColumns: UH312 หิน 3/4, UH312 หินฝุ่น, QA451 หิน 3/4, QA451 หิน 3/8, QA451 หินฝุ่น, หินคลุก — `hourMeterMode: true` ไม่มี Flowmeter)
- Dashboard ใช้ style เดียวกับ Sanon (`renderDashboardSanon('mobile')`)
- Permission Templates เพิ่ม `manager-mobile`, `supervisor-mobile`, `op-mobile`
- ตาราง `production_mobile` ใหม่ (`production_mobile_schema.sql`) — RLS policy `anon_all`

**⏳ สิ่งที่ต้องทำก่อนใช้งาน:** รัน `production_mobile_schema.sql` ใน Supabase → Admin ตั้งสิทธิ์ Permission Matrix ให้ User ที่ดูแล Mobile Plant

### 2026-08-08 — แก้ Export รายงานการผลิต + เปลี่ยน Export Excel → CSV

- หน้ารายงาน (manage-reports): สร้าง `buildProductionExportData()` — export ครบทุกคอลัมน์ตรงกับตารางที่แสดงผล, status แปลงเป็นภาษาไทย
- หน้า manage-prod-* : เปลี่ยน export จาก `.xlsx` → `.csv` (UTF-8 with BOM), หัวคอลัมน์ตรงกับ import template, เรียงวันที่ ascending เพื่อแก้แล้ว re-import ได้

### 2026-07-31
- เพิ่ม PWA tags: `manifest-production.json`, `apple-touch-icon`, SW registration
- เพิ่ม Section 0 (System Status Board) ใน CLAUDE.md

### 2026-07-21
- Executive Dashboard (dash-executive): KPI 7 ตาราง parallel
- SSO `_sn_shared_sess` ข้ามระบบ (index + inventory + pm)
- LINE webhook: เพิ่ม Authorization header ใน `notify_line_on_insert()`

### 2026-07-16
- Dashboard ค่าไฟฟ้า (dash-electricity) + Manage (manage-electricity)
- `electricity_schema.sql` สร้างตาราง electricity_costs
- PDF Executive Report: เพิ่มส่วนค่าไฟ + print-color-adjust fix

### 2026-07-12
- Mobile UX: viewport, font-size 16px, table-layout:fixed
- Bottom Nav auto-close
- PDF Executive Report: Traffic Light, Trend ▲▼, Breakdown Log
