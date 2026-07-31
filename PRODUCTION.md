# PRODUCTION.md — ระบบผลิต (System 1)
> ไฟล์นี้บันทึกรายละเอียดเฉพาะ `index.html` — อ่านก่อนแก้ไขทุกครั้ง

---

## 1. ข้อมูลระบบ

- **ไฟล์:** `index.html` (~9,200+ บรรทัด)
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

### จัดการข้อมูล (prefix: `manage-`)
| key | ชื่อ |
|-----|------|
| `manage-approvals` | รออนุมัติยอดผลิต |
| `manage-prod-cde` | บันทึกยอดผลิต CDE |
| `manage-prod-propel` | บันทึกยอดผลิต Propel |
| `manage-prod-sanon1` | บันทึกยอดผลิต Sanon1 |
| `manage-prod-sanon2` | บันทึกยอดผลิต Sanon2 |
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
