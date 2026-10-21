# PRODUCTION.md — ระบบผลิต (System 1)
> ไฟล์นี้บันทึกรายละเอียดเฉพาะ `index.html` — อ่านก่อนแก้ไขทุกครั้ง
> ตั้งแต่ 2026-09-15 ไฟล์นี้เป็นที่เก็บ "สถานะ/ฟีเจอร์ล่าสุด" + "Changelog" ของ System 1 ทั้งหมด — ดู `CLAUDE.md` Section 0A สำหรับเหตุผลที่แยกไฟล์

---

## 0. สถานะล่าสุด (อัปเดต 2026-09-26)

✅ ใช้งานจริง — Dashboard ทุกเมนู (CDE/Propel/Sanon1/Sanon2/Mobile Plant), Executive Dashboard, รายงานรายปี (dash-annual: Dashboard + PDF + PPTX Export ทุกโรงงาน), ค่าไฟฟ้า, PDF Report, SSO, Mobile/Desktop System Switcher 6 ระบบ, LINE แจ้งเตือนจาก JS, Export CSV ทุกโรงงาน, Mobile Plant (โรงงานที่ 5 — Dashboard + ยอดผลิต + Approval ครบ), เพิ่มโรงงาน: กำหนดเป้าตัน/เดือน + ตัน/ชม. จาก UI ได้ทุกโรงงาน, วิเคราะห์รายวัน (กราฟ/ตาราง/Breakdown ครบทุกโรงงาน + auto-detect วันล่าสุดที่มีข้อมูล), material_types (is_feed_material + is_product), groundwater_usage (ผู้บันทึก), drone factory sort ตามลำดับ CDE→Propel→Sanon1→Sanon2→Mobile Plant

**ปัญหาที่รู้อยู่:** ต้องรัน SQL patches สำหรับ Mobile Plant ให้ครบ (ดู Section 11 — Changelog 2026-09-02)

---

## 0A. ⚠️ เช็คลิสต์เพิ่มโรงงานใหม่ — ป้องกันปัญหาเดิมซ้ำ (อัปเดต 2026-10-18)

**ทำไมต้องมีหัวข้อนี้:** ทุกครั้งที่เพิ่มโรงงานใหม่ (ล่าสุดคือ Mobile Plant) เจอ error เดิมซ้ำ ๆ จากตารางต่าง ๆ ทีละตาราง เพราะตารางเหล่านี้ถูกสร้างตั้งแต่ตอนระบบมีแค่ 4 โรงงาน (CDE/Propel/Sanon1/Sanon2) แล้วมี **CHECK constraint ที่ล็อกชื่อโรงงานไว้ตายตัวที่ชั้นฐานข้อมูล (Supabase)** ซึ่งแก้โค้ดฝั่ง UI ให้ dynamic แล้วก็ยังไม่พอ ต้องไปลบ constraint ที่ DB ด้วยเสมอ

**ตารางที่เจอปัญหานี้มาแล้ว (แก้ไปแล้วทุกตัว ณ 2026-10-18):**

| ตาราง | คอลัมน์ | ชื่อ constraint | แก้เมื่อ |
|---|---|---|---|
| `electricity_costs` | `factory` | `electricity_costs_factory_check` | 2026-10-18 |
| `sales` | `factory_code` | `sales_factory_code_check` | 2026-10-18 |
| `sales` | `factory_name` | `sales_factory_name_check` | 2026-10-18 |
| `electric_loader` | `factory_name` | `electric_loader_factory_name_check` | 2026-10-18 |
| `drone_stock` | `factory_name` | *(ตรวจแล้ว — ไม่มี constraint นี้ติดอยู่ ปลอดภัยอยู่แล้ว)* | ตรวจ 2026-10-18 |
| `production_daily_status` | `factory_code` | `production_daily_status_factory_code_check` | 2026-10-18 |

**ก่อนเพิ่มโรงงานใหม่ครั้งหน้า ให้รันคำสั่งนี้ใน Supabase SQL Editor ก่อนเสมอ** — จะไล่หา CHECK constraint ที่ยังล็อกชื่อโรงงานแบบเดิมค้างอยู่ทั้งฐานข้อมูล (ไม่ต้องเดาทีละตารางอีกต่อไป):
```sql
SELECT conrelid::regclass AS table_name, conname, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE contype = 'c'
  AND pg_get_constraintdef(oid) ILIKE '%CDE%'
  AND pg_get_constraintdef(oid) ILIKE '%Propel%';
```
ถ้ามีผลลัพธ์ขึ้นมา แปลว่ายังมีตารางที่ล็อกชื่อโรงงานค้างอยู่ — ลบ constraint นั้นด้วย `ALTER TABLE <ตาราง> DROP CONSTRAINT <ชื่อ constraint>;` ได้เลย (ไม่กระทบข้อมูลเดิม เป็นแค่การลบกฎตรวจสอบ)

**อาการที่บ่งชี้ว่าเจอปัญหานี้อีก:**
- บันทึก/แก้ไขข้อมูลแล้วขึ้น error แบบ `violates check constraint "..._check"` → ไปรัน query ด้านบนหาแล้วลบทิ้งได้เลย
- ปุ่ม/ฟอร์มทำงานเงียบ ๆ โดยไม่ขึ้น error แต่สถานะ/ป้ายไม่เปลี่ยนตามที่ควร (เช่นเคส `production_daily_status`) → มักเป็นเพราะโค้ดมี `try/catch` ดักไว้ไม่ให้ error ขึ้นจอ ต้องเปิด Console (F12) เพื่อหา error จริงที่ซ่อนอยู่

**ถ้าเพิ่มตารางใหม่ที่มีคอลัมน์เก็บชื่อโรงงาน** (ทั้งฟีเจอร์ใหม่ หรือสร้างตาราง `production_xxx` ใหม่) — **อย่าก๊อปโครงสร้างจากตารางเก่าที่มี `CHECK (factory IN (...))` ตรง ๆ** ให้ตัด constraint นี้ออกตั้งแต่ตอนออกแบบตาราง แล้วปล่อยให้ชั้นแอปพลิเคชัน (ที่ดึงรายชื่อจากตาราง `factories` แบบ dynamic อยู่แล้ว) เป็นตัวควบคุมความถูกต้องของชื่อโรงงานแทน

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

### 10.1 ถ้าเจอปัญหา "การ์ด/กราฟล้นจอมือถือ" อีก — เช็คตามลำดับนี้ (อย่าไล่แก้จากจุดที่เห็นอาการอย่างเดียว)

ปัญหานี้เคยใช้เวลาแก้หลายรอบ (ดู Changelog 2026-09-26 รอบ 1-5) เพราะไล่แก้จากจุดที่เห็นอาการ (เช่น Dashboard) ไปทีละจุด โดยไม่ตรวจ container ทุกชั้นตั้งแต่ root ครั้งหน้าให้เช็คตามลำดับนี้แทน:

1. **เช็ค root cause ระดับโครงสร้างแอปก่อนเป็นอันดับแรก** — `#app-shell-main` และ `#page-content` (ใน `renderAppShell()`) ต้องมี `min-width: 0` เสมอ (มีอยู่แล้วที่ CSS บรรทัด ~50 นอก media query) เพราะเป็น flex item ของ layout หลักทั้งแอป ถ้าเผลอลบ/ย้าย CSS นี้ออกไป ปัญหาล้นจอจะกลับมาทันทีทุกหน้า ไม่ใช่แค่ Dashboard
2. **grid/flex item ทุกตัวที่ใช้ `grid-cols-*` หรือ `flex` แล้วมีเนื้อหาข้างในกว้าง (ตัวเลข, กราฟ, การ์ด)** ต้องมี `min-width: 0` กำกับลูกด้วยเสมอ (browser default คือ `min-width: auto` ซึ่งยึดตามเนื้อหาไม่ยอมหด) — ดูตัวอย่างที่ `.dash-dark-bg .grid > *` และ `.dash-dark-bg .flex > *` (บรรทัด ~53-60)
3. **SVG/canvas ที่กำหนด `width`/`height` เป็น attribute ตรงๆ** (ไม่ใช่ CSS class) ต้องมี `max-width:100% !important; height:auto !important;` กำกับเสมอ เพราะ attribute พวกนี้ไม่หดตาม container เอง
4. **จุดที่สำคัญ/ซับซ้อนและพังบ่อย** (เช่น OEE Gauge) ให้เขียน CSS `display:grid`/`display:flex` เป็น class ของตัวเอง **ไม่พึ่ง Tailwind utility class ล้วนๆ** เพราะ Tailwind CDN (`cdn.tailwindcss.com`) เป็น JIT scan on-the-fly มีโอกาสไม่ generate CSS ให้ครบในไฟล์ขนาดใหญ่ (ดูตัวอย่าง `.oee-gauge-grid`)
5. **ทดสอบบนมือถือจริงเสมอ อย่าเชื่อ Chrome DevTools Responsive mode 100%** — เคยเจอกรณี DevTools แสดงตัวเลข/ภาพคลาดเคลื่อนจากขนาดจอที่ตั้งไว้จริง (ดู Changelog รอบ 4-5) ทำให้เข้าใจผิดว่าแก้ไม่หายทั้งที่ CSS ถูกต้องแล้ว หรือกลับกัน คือ DevTools ดูเหมือนไม่ล้นแต่มือถือจริงล้น

---

## 11. Changelog

### 2026-10-19 รอบ 2 — แก้ไข (correction) การ์ด "ยอดขายรวม" ใน Executive Summary ขึ้น 0 บาท เสมอ ทั้งที่มียอดขายจริงในระบบ

**ที่มา:** ผู้ใช้ถามว่าหน้า Executive Summary (dash-executive) ต้องเพิ่มอะไรอีกไหม ระหว่างตรวจสอบโค้ดพบว่าการ์ด "ยอดขายรวม" query คอลัมน์ `amount_baht` จากตาราง `sales` — แต่ตาราง `sales` **ไม่มีคอลัมน์นี้เลย** (คอลัมน์จริงที่เก็บมูลค่าคือ `total_value` ตามที่ใช้ตรงกันทุกจุดอื่นในระบบ เช่น กราฟ Dashboard ยอดขาย, ตารางจัดการยอดขาย, รายงานรายปี) ทำให้ query คืนค่า `null`/undefined เงียบๆ (Supabase ไม่ throw error เมื่อ column ไม่ตรง แค่คืนค่าว่าง) และยอดขายรวมคำนวณได้ 0 เสมอไม่ว่าจะมียอดขายจริงเท่าไหร่ในเดือนนั้น

**แก้ไข:** เปลี่ยน `.select('amount_baht')` → `.select('total_value')` และ `r.amount_baht` → `Number(r.total_value)||0` ในฟังก์ชัน `renderDashboardExecutive()`

**บทเรียน:** เป็นอีกตัวอย่างของ "silent failure" แต่คนละแบบกับ Section 0A (ไม่ใช่ CHECK constraint แต่เป็นชื่อคอลัมน์ผิด) — จุดเสี่ยงแบบนี้คือ query ที่เขียนแยกไว้คนละที่กับจุดอื่นที่ query ตารางเดียวกัน ทำให้ชื่อคอลัมน์เพี้ยนได้โดยไม่มีใครสังเกต เวลาเพิ่ม dashboard/การ์ดสรุปใหม่ที่ query ตารางเดิมซ้ำ ควร copy ชื่อคอลัมน์จากจุดที่ query ตารางนั้นอยู่แล้วแทนการพิมพ์ชื่อคอลัมน์ขึ้นใหม่เอง

**ไม่ต้องรัน SQL เพิ่ม — เป็นการแก้โค้ดฝั่ง frontend เท่านั้น**

### 2026-10-19 — แก้ไข (correction) จุด Silent Error ที่สำคัญที่สุดในระบบ: auto-confirm สถานะ "ยืนยันแล้ว" หลังนำเข้ายอดจริงสิ้นเดือน ไม่แจ้งเตือนเมื่อล้มเหลว

**ที่มา:** ต่อเนื่องจากปัญหา Mobile Plant สถานะไม่ขึ้นสีเขียว (บันทึกไว้แล้วด้านล่าง) ผู้ใช้ถามว่าระบบมีการแจ้งเตือนอะไรไหมถ้าเกิดข้อผิดพลาด ("มีผลอะไรไหมกับการบันทึกข้อมูลของระบบ... ถ้ามีปัญหาในระบบเราจะรู้ไหม") — จึงขอให้ตรวจค้นทุกจุดในโค้ดที่ error ถูก "ดักไว้เงียบๆ" (try/catch ที่ไม่ขึ้น toast แจ้งผู้ใช้) โดยเฉพาะจุดที่เกี่ยวกับการบันทึกข้อมูล (insert/update/upsert/delete)

**วิธีตรวจสอบ:** เขียนสคริปต์ไล่จับคู่ `try{...}catch{...}` ทุกจุดในไฟล์ (139 คู่) ด้วยการนับวงเล็บปีกกาให้แม่นยำ (ไม่ใช่แค่เดาจากบรรทัดใกล้เคียง) แล้วกรองเฉพาะจุดที่ภายใน `try` มีการเรียก `.insert()/.update()/.upsert()/.delete()/.rpc()` **และ** ภายใน `catch` ไม่มีการเรียก `showToast` เลย — พบ 3 จุด ตรวจสอบทีละจุด:
- `trySaveActiveForm()` (auto-save ฉุกเฉินตอน session timeout) — ไม่ต้องแก้ เพราะ caller (`handleSessionExpired`) เช็ค return value แล้วเลือกข้อความ toast ที่ถูกต้องอยู่แล้ว (ไม่หลอกผู้ใช้ว่า "บันทึกแล้ว" ถ้าจริงๆ ล้มเหลว)
- `openRolePermissionsMatrix()` → ปุ่มบันทึกสิทธิ์ (`doSave`) — ไม่ต้องแก้ เพราะมี try/catch + showToast ของตัวเองแยกต่างหากอยู่แล้วตรงจุดที่ save จริง
- **`importProductionExcel()` ส่วน auto-confirm `production_daily_status` (บรรทัด ~6458)** — **เป็นจุดที่พังจริง** และเป็น **root cause เดียวกับบั๊ก Mobile Plant ที่เพิ่งแก้ไป** แต่ฟังก์ชันนี้ใช้ร่วมกันทุกโรงงาน (CDE/Propel/Sanon1/Sanon2/Mobile ผ่าน `PLANT_FACTORY_CODE[plantKey]`) แปลว่าความเสี่ยงนี้มีกับทุกโรงงาน ไม่ใช่แค่ Mobile Plant — อีกทั้งโค้ดเดิมไม่เคยอ่านค่า `error` จาก response ของ `.upsert()` เลย (Supabase JS ไม่ throw error เองเมื่อ query ล้มเหลว ต้องเช็ค `{ error }` แล้ว throw เองเสมอ) ทำให้ catch ไม่เคยถูกเรียกจริงๆ ด้วยซ้ำ

**แก้ไข (โค้ด, แก้ไปแล้ว):**
```js
// เดิม — ไม่เช็ค error, ไม่แจ้งผู้ใช้เลย
try {
  await db.from('production_daily_status').upsert(sp, { onConflict:'factory_code,production_date' });
} catch(e) { console.warn('auto-confirm:', e); }

// ใหม่ — เช็ค error แล้ว throw เอง + แจ้งเตือนผู้ใช้เป็น toast สีเหลือง (warning)
try {
  const { error: autoConfirmError } = await db.from('production_daily_status').upsert(sp, { onConflict:'factory_code,production_date' });
  if (autoConfirmError) throw autoConfirmError;
} catch(e) {
  console.warn('auto-confirm:', e);
  showToast('นำเข้าข้อมูลสำเร็จ แต่ปรับสถานะ "ยืนยันแล้ว" อัตโนมัติไม่สำเร็จ (' + (e.message || '') + ') กรุณาตรวจสอบและยืนยันสถานะด้วยตนเองที่หน้าจัดการ', 'warning', 9000);
}
```
ผลคือ: ถ้ามี CHECK constraint ของโรงงานใหม่ตกหล่นแบบเดิมอีกในอนาคต (ดู Section 0A) ผู้ใช้จะ **เห็น toast เตือนทันทีหน้าจอ** แทนที่จะต้องรอสังเกตเองว่าสถานะไม่ขึ้นสีเขียว

**จุดอื่นๆ ที่ตรวจแล้วไม่ใช่ความเสี่ยง (ไม่ได้แก้ เพื่อไม่ให้ toast รกจอเกินจำเป็น):** catch block อีก ~90 จุดในไฟล์เป็นของการ**โหลดข้อมูลมาแสดงผล** (dropdown, กราฟ, การ์ดสถิติ) ไม่ใช่การบันทึกข้อมูล — ทุกจุดมี fallback ที่ผู้ใช้เห็นอยู่แล้ว (ขึ้นข้อความ "โหลดไม่สำเร็จ" ในบล็อกนั้นๆ หรือ reset เป็นค่าว่างอย่างปลอดภัย) จึงไม่ใช่ "silent failure" ที่เป็นอันตรายในความหมายเดียวกับจุดที่แก้ไป

**บทเรียนสำคัญ:** เวลาจะหาจุด error ที่ถูกดักเงียบในโค้ด ให้โฟกัสเฉพาะจุดที่เป็นการ **เขียน/บันทึกข้อมูล** (insert/update/upsert/delete/rpc) เท่านั้น เพราะเป็นจุดเดียวที่ "ความเงียบ" เท่ากับ "ข้อมูลอาจไม่ถูกบันทึกโดยที่ไม่มีใครรู้" — ส่วนจุดอ่านข้อมูลเพื่อแสดงผล ความเงียบมักไม่อันตรายเท่าเพราะอย่างมากก็แค่แสดงผลว่างหรือข้อความโหลดไม่สำเร็จ ไม่ทำให้ข้อมูลเสียหาย และเวลาตรวจแนะนำให้เขียนสคริปต์จับคู่วงเล็บปีกกาจริงแทนการเดาจาก "บรรทัดใกล้ๆ" เพราะจะได้ผลผิดพลาดสูง (กรณีนี้วิธีเดาบรรทัดใกล้เคียงรายงานผลบวกปลอมและลบปลอมหลายจุด)

**ไม่ต้องรัน SQL เพิ่ม — เป็นการแก้โค้ดฝั่ง frontend เท่านั้น**

### 2026-09-26 รอบ 5 — แก้ root cause จริงระดับโครงสร้างแอป: #app-shell-main ไม่มี min-width:0 (ทุกหน้า ไม่ใช่แค่ Dashboard)

**ที่มา:** หลังแก้รอบ 4 ผู้ใช้ตรวจสอบด้วย DevTools พบตัวเลขที่ดูเหมือนไม่ล้น (`innerWidth` 574px, เนื้อหาพอดี) แต่ภาพหน้าจอยังเห็นเหมือนล้นอยู่ — เมื่อขอให้ทดสอบบน**มือถือจริง** (ไม่ผ่าน DevTools) ผลออกมาว่า **ล้นจอจริง** ทั้ง OEE Gauge (กราฟ Performance ถูกตัดขอบ) และการ์ดสถิติ (หินป้อนรวม, Throughput ถูกตัดตัวเลขฝั่งขวา) — สรุปว่า DevTools ก่อนหน้านี้รายงานค่าคลาดเคลื่อน (อาจเป็นปัญหาของ DevTools เอง) แต่ปัญหาจริงบนมือถือยังคงอยู่

**Root cause ตัวจริง (อยู่ลึกกว่าที่คิดไว้ทุกรอบก่อนหน้า):** โครงสร้างหลักของทั้งแอป (Section 11: APP SHELL) คือ
```html
<div class="min-h-screen flex bg-secondary-50">   <!-- flex container ระดับบนสุด -->
  <aside class="... fixed ...">...</aside>          <!-- sidebar: fixed position ไม่กินพื้นที่ flex -->
  <div class="flex-1 flex flex-col lg:ml-64 min-h-screen">  <!-- flex item เดียวที่เหลือ -->
    <header>...</header>
    <main id="page-content" class="flex-1 ...">...</main>   <!-- เนื้อหาทุกหน้ารวมถึง Dashboard -->
  </div>
</div>
```
`<div class="flex-1 ...">` เป็น **flex item ของ flex container ระดับบนสุดของทั้งแอป** และเหมือนปัญหาที่เจอซ้ำๆ ในทุกรอบก่อนหน้า (grid item / flex item มี `min-width:auto` เป็นค่า default) — จุดนี้ไม่เคยถูกแก้เลยเพราะการแก้ทุกรอบก่อนหน้าใส่ CSS ไว้แค่ **ภายใน** `.dash-dark-bg` เท่านั้น (เช่น `.dash-dark-bg .grid > *`, `.dash-dark-bg .flex > *`) แต่จุดนี้เป็น **บรรพบุรุษ (ancestor) ของ `.dash-dark-bg`** อยู่คนละชั้น การแก้ข้างในไม่มีทางไปถึงจุดนี้ได้เลย

ผลคือ: ถ้าเนื้อหาลึกๆ ข้างในหน้าใดก็ตาม (การ์ด, กราฟ, ตัวเลข) มีความกว้างขั้นต่ำที่ไม่ยอมหด (min-content) กว้างกว่าจอมือถือ ทั้ง `#app-shell-main` และ `#page-content` จะปฏิเสธไม่ยอมหดตามจอ — `body { overflow-x:hidden }` ที่มีอยู่เดิมแค่ "ซ่อน" ส่วนเกินไม่ให้เกิด scrollbar แนวนอน แต่ไม่ได้แก้ให้เนื้อหาหดจริง เนื้อหาฝั่งขวาที่เกินจอเลยถูกตัดขาดหายไปเลย (ไม่ใช่แค่ Dashboard — เป็นปัญหาระดับโครงสร้างที่กระทบทุกเมนู เพียงแต่ Dashboard เห็นชัดที่สุดเพราะมีกราฟ/การ์ดกว้างๆ)

**แก้ไข:**
1. ใส่ `id="app-shell-main"` ให้ div หลักใน `renderAppShell()` (บรรทัด ~1814)
2. เพิ่ม CSS (บรรทัด ~44 นอก media query — มีผลทุกหน้า ทุกขนาดจอ):
```css
#app-shell-main, #page-content { min-width: 0; }
```

**บทเรียนสำคัญ:** ปัญหา "min-width:auto บน flex/grid item" ที่ไล่แก้มา 4 รอบ (stat cards → OEE gauge SVG → แถบช่วงเวลา) ล้วนเป็นอาการย่อยของปัญหาเดียวกันที่ **รากลึกที่สุดคือโครงสร้าง app shell เอง** — การไล่แก้จากจุดที่เห็นอาการ (Dashboard) โดยไม่ตรวจสอบ DOM ทั้งสายจนถึง `<body>` ทำให้แก้ไม่ครบ ครั้งต่อไปถ้าเจอปัญหาการ์ด/กราฟล้นจอในลักษณะนี้อีก ให้ตรวจ container ทุกชั้นตั้งแต่ root ไม่ใช่แค่จุดที่เห็นปัญหา

**ไม่ต้องรัน SQL เพิ่ม**

### 2026-09-26 รอบ 4 — แก้ OEE Gauge แบบเขียน CSS grid เอง ไม่พึ่ง Tailwind class

**ที่มา:** หลังแก้รอบ 3 (เพิ่ม `.flex > * { min-width:0 }`) ผู้ใช้ทดสอบซ้ำอีกครั้ง OEE Gauge (Performance) ยังถูกตัดขอบเหมือนเดิมทุกประการ ไม่มีอะไรเปลี่ยน ผู้ใช้ขอให้ตรวจสอบว่าการแก้ไขที่ผ่านมาจุดไหนที่ทำให้เกิดปัญหานี้

**การตรวจสอบ:** จำลองโครงสร้าง HTML/CSS ของ OEE Gauge แยกต่างหาก (นอกระบบจริง) แล้วทดสอบด้วย headless browser ที่ viewport 400px — พบว่า **ตรรกะ CSS ที่เขียนไว้ (min-width:0 + max-width:100%) ถูกต้องแล้ว 100%** เมื่อ class `grid grid-cols-2` ของ Tailwind ถูกแปลงเป็น `display:grid` จริง (คอลัมน์แบ่ง 181px/181px พอดี SVG 128px ไม่ล้นแน่นอน) — แปลว่าปัญหาที่ผู้ใช้เจอไม่ได้อยู่ที่สูตร CSS ที่เขียนผิด แต่น่าจะอยู่ที่ **Tailwind CDN (โหลดจาก `cdn.tailwindcss.com`) ไม่ได้ generate CSS ให้ class `grid grid-cols-2` ของจุดนี้ทันเวลา/ครบถ้วน** (ไฟล์มีขนาดใหญ่มาก ~12,000+ บรรทัด และ Tailwind ต้องสแกนข้อความทั้งหน้าเพื่อสร้าง utility CSS แบบ on-the-fly ซึ่งมีโอกาสพลาดจุดที่อยู่ลึกในไฟล์ได้)

**แก้ไข:** เลิกพึ่งพา Tailwind class `grid grid-cols-2` สำหรับจุดนี้ เขียน CSS class ของตัวเองตรงๆ แทน (ไม่ต้องรอ Tailwind สแกน รับประกันว่าเป็น 2 คอลัมน์แน่นอน 100%)

โครงสร้าง (`renderOeeGaugeBlock`, บรรทัด ~2324):
```html
<div class="oee-gauge-grid">
  ...gaugeSvg() x2...
</div>
```

CSS (บรรทัด ~175):
```css
.dash-dark-bg .oee-gauge-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 0.5rem; }
.dash-dark-bg .oee-gauge-grid > * { min-width: 0; }
```

**บทเรียน:** เมื่อเจอ layout ที่ CSS ดูถูกต้องแล้วแต่ยังไม่เปลี่ยนพฤติกรรมจริงในเบราว์เซอร์ ให้สงสัย Tailwind CDN (JIT scan แบบ on-the-fly) ว่าอาจไม่ generate utility class ให้ครบ โดยเฉพาะจุดที่อยู่ลึกในไฟล์ขนาดใหญ่ — วิธีแก้ที่นิ่งที่สุดคือเขียน CSS ของจุดสำคัญๆ (เช่น layout ที่พังแล้วซ่อมยาก) เป็น custom class ของตัวเองแทนการพึ่ง Tailwind utility ล้วนๆ

**ผลการยืนยัน (หลังแก้):** ตรวจสอบด้วย Console โดยตรง (`getBoundingClientRect()` ของ grid/SVG + `document.body.scrollWidth` เทียบ `window.innerWidth`) พบว่าเนื้อหาพอดีกับความกว้างจอจริง ไม่มีส่วนล้น — ที่เห็น "ตัดขอบ" ในภาพ DevTools Responsive mode ก่อนหน้านี้ เกิดจากช่อง Dimensions ที่ตั้งไว้ (400px) ยังไม่ถูกใช้งานจริง (ค่าจริงตอนวัดคือ 574px) ไม่ใช่ปัญหาโค้ด — ผู้ใช้ทดสอบซ้ำบนมือถือจริงแล้วยืนยันว่าใช้งานได้ปกติ ✅ ปิดปัญหานี้

**ไม่ต้องรัน SQL เพิ่ม**

### 2026-09-26 รอบ 3 — แก้ root cause จริง: flex item ก็มี min-width:auto เหมือน grid item

**ที่มา:** หลังแก้รอบ 2 (SVG max-width:100% + ลด padding แถบช่วงเวลา) ผู้ใช้ทดสอบด้วย Chrome DevTools 400px ซ้ำหลายรอบ ยังเห็น OEE Gauge (กราฟ Performance) ถูกตัดขอบเหมือนเดิมทุกประการ ไม่มีอะไรเปลี่ยนเลย — ตรวจสอบผ่าน View Page Source (Ctrl+U) ยืนยันแล้วว่า browser โหลด CSS ที่แก้ล่าสุดถูกต้อง ไม่ใช่ปัญหา cache

**Root cause ตัวจริง:** ตัว SVG ของ OEE Gauge อยู่ใน `<div class="flex flex-col items-center">` (ไม่ใช่ grid) — และ **flex item ก็มีค่า default `min-width: auto` เหมือน grid item ทุกประการ** (ยึดตามขนาดเนื้อหา/ความกว้าง attribute ของ SVG เอง ไม่ยอมหด) กฎ `.dash-dark-bg .grid > *` ที่แก้ไว้ตั้งแต่รอบแรกครอบคลุมเฉพาะลูกของ `.grid` เท่านั้น **ไม่ครอบคลุมลูกของ `.flex`** จึงเป็นเหตุผลที่ `max-width:100%` บน SVG (รอบ 2) ไม่มีผลจริง — เพราะ `min-width:auto` (ค่า default ที่ไม่เคยถูกลบ) ชนะ `max-width` เสมอเมื่อขัดแย้งกัน (กฎ CSS: min-width สูงกว่า max-width) แถบเลือกช่วงเวลาก็อยู่ใน `flex flex-wrap` เช่นกัน จึงเป็นสาเหตุเดียวกัน

**แก้ไข (CSS บรรทัด ~164 และ ~187):**
```css
/* เพิ่มคู่กับกฎ .grid > * เดิม — ใช้ตรรกะเดียวกัน มีผลทุกขนาดจอ */
.dash-dark-bg .flex > * { min-width: 0; }

/* กันเผื่อ Chart.js canvas อีกชั้น (เฉพาะจอ ≤640px) */
.dash-dark-bg canvas { max-width: 100% !important; }
```

**หมายเหตุ:** นี่คือ root cause ตัวจริงที่อธิบายได้ครบทุกจุดที่ยังล้นจอ (OEE Gauge SVG + แถบเลือกช่วงเวลา) เพราะทั้งสองจุดอยู่ใน flex container ไม่ใช่ grid — บทเรียน: เวลาเจอ container ที่ไม่ยอมหดตามพื้นที่จริง ต้องเช็คทั้ง `.grid > *` และ `.flex > *` คู่กันเสมอ (browser default `min-width:auto` มีผลกับทั้งสองแบบเหมือนกัน)

**ไม่ต้องรัน SQL เพิ่ม**

### 2026-09-26 รอบ 2 — แก้ overflow ที่เหลือ: OEE Gauge (SVG) + แถบเลือกช่วงเวลา

**ที่มา:** หลังแก้ `min-width:0` รอบแรก การ์ดสถิติ (stat cards) เรียง 2 คอลัมน์ถูกต้องแล้ว แต่ทดสอบด้วย Chrome DevTools 400px อีกครั้งพบว่ายังล้นจอ 2 จุด: (1) กราฟ OEE Gauge (Availability/Performance) กราฟที่ 2 ถูกตัดขอบขวา (2) แถบเลือกช่วงเวลา "รายวัน/รายเดือน/รายปี" + dropdown เดือน/ปี ล้นขอบขวาเล็กน้อย

**Root cause เพิ่มเติม:**
- OEE Gauge เป็น SVG ที่กำหนด `width="128" height="74"` เป็น **attribute ตรงๆ** (ไม่ใช่ CSS class) ค่า `min-width:0` ที่แก้ไปรอบแรกใช้ไม่ได้กับ SVG attribute แบบนี้ — SVG จึงคงความกว้าง 128px แน่นอนไม่ยอมหด แม้ parent จะแคบกว่า
- แถบเลือกช่วงเวลา: ปุ่ม "รายวัน/รายเดือน/รายปี" (3 ปุ่ม) + dropdown เดือน + dropdown ปี รวมความกว้างที่ padding/font ขนาด Desktop เดิม ยาวเกินพื้นที่ที่เหลือบนจอ 400px เล็กน้อย

**แก้ไข (CSS บรรทัด ~170, เฉพาะจอ ≤640px):**
```css
.dash-dark-bg svg { max-width: 100% !important; height: auto !important; }
.dash-dark-bg [id$="-range-controls"] { width: 100%; }
.dash-dark-bg [id$="-range-controls"] .range-mode-btn { padding: 4px 7px !important; font-size: 10.5px !important; }
.dash-dark-bg [id$="-range-controls"] select,
.dash-dark-bg [id$="-range-controls"] input[type="date"] { padding: 4px 6px !important; font-size: 10.5px !important; }
```
- บังคับ SVG หดตามพื้นที่จริงด้วย `max-width:100%` (ใช้ `height:auto` คู่กันเพื่อรักษาสัดส่วนไม่ให้ภาพเบี้ยว)
- ลด padding/font ของปุ่ม+dropdown ในแถบเลือกช่วงเวลาให้กระชับพอดีจอแคบ
- เพิ่ม `.dash-dark-bg { overflow-x: hidden !important; }` (ใส่ !important เพิ่มจากรอบแรก) เป็นตาข่ายนิรภัยชั้นสุดท้ายกันล้นจอในจุดที่ยังไม่เจอ

**หมายเหตุ:** ใช้ attribute selector `[id$="-range-controls"]` (ลงท้ายด้วยคำนี้) ครอบคลุมทุกโรงงานในคำเรียกเดียว (`cde-range-controls`, `propel-range-controls`, `sanon1-range-controls` ฯลฯ) ไม่ต้องเขียนแยกทีละโรงงาน

**ไม่ต้องรัน SQL เพิ่ม**

### 2026-09-26 — แก้ root cause: การ์ด Dashboard ล้นจอมือถือ (min-width:0)

**ที่มา:** ปรับ CSS มือถือของ Dashboard เมื่อ 2026-09-22 (ลด font-size/padding) แล้วผู้ใช้ยังเห็นว่าจอมือถือ "ซูมเต็มหน้าจอ" อยู่ — ทดสอบด้วย Chrome DevTools ที่ 400px พบว่าการ์ดสถิติ (เช่น "วันทำงาน", "Runtime รวม") แสดงทีละใบเต็มความกว้างจอ แทนที่จะเป็น 2 คอลัมน์ตามที่ตั้งใจ (`grid-cols-2`)

**Root cause:** grid item ของ browser มีค่า default `min-width: auto` (ยึดตามความกว้างเนื้อหาข้างในที่ไม่ยอมหด เช่น ไอคอน+ป้ายชื่อในแถว flex เดียวกัน) ทำให้คอลัมน์ที่ 2 ของ `grid-cols-2` ถูกดันกว้างเกินขอบจอมือถือ — มองไม่เห็นการ์ดที่เหลือ (ต้องเลื่อนขวาถึงจะเห็น) และการ์ดที่เห็นก็ขยายเต็มจอจนดูเหมือน "ซูมเข้ามาเยอะ"

**แก้ไข (CSS บรรทัด ~159, มีผลทุกขนาดจอ ไม่จำกัดเฉพาะมือถือ เพราะเป็นค่าที่ถูกต้องเสมอ):**
```css
.dash-dark-bg .grid > * { min-width: 0; }
.dash-dark-bg .dash-dark-card { overflow-wrap: break-word; }
.dash-dark-bg { overflow-x: hidden; }
```
บังคับให้การ์ดหดตามความกว้างคอลัมน์จริงแทนการดันล้น + กันข้อความยาวดันกว้างซ้ำ + กัน scroll แนวนอนเป็นตาข่ายนิรภัยชั้นสุดท้าย

**ไม่ต้องรัน SQL เพิ่ม**

### 2026-09-22 — ปรับขนาดหน้า Dashboard (พื้นหลังเข้ม) ให้เหมาะกับจอมือถือ

**ที่มา:** หน้า Dashboard ทุกหน้าที่ใช้ธีมพื้นหลังเข้ม (CDE/Propel/Sanon1/Sanon2/Mobile Plant/ค่าไฟฟ้า/ยอดขาย/รถตักไฟฟ้า/น้ำบาดาล ฯลฯ) ใช้ font-size/padding/ความสูงกราฟเท่ากับจอ Desktop เมื่อดูบนมือถือหน้าจอแคบกว่ามาก ทำให้รู้สึกเหมือน "ซูมเข้ามาเยอะ"

**แก้ไข (CSS ใน `<style>` หลัก บรรทัด ~159, มีผลเฉพาะจอ ≤640px และเฉพาะภายใน `.dash-dark-bg`):**
- ลด padding การ์ด (`.dash-dark-card`) จาก 20px → 14px
- ลดขนาดตัวเลขใหญ่ (`text-2xl`) จาก 24px → 19px และหัวข้อ (`text-xl`, `h2.text-lg`) ให้เล็กลงตามสัดส่วน
- ลดระยะห่างระหว่างการ์ดในกริด (`gap-4`/`gap-5`/`gap-6`) ให้กระชับขึ้น
- ลดความสูงพื้นที่กราฟ (`h-72`/`h-64`/`h-56` และ inline height 320px/270px) ให้พอดีจอมือถือ ลดการเลื่อนหน้าจอ

**ขอบเขต:** เป็น CSS scope เฉพาะ `.dash-dark-bg` เท่านั้น ไม่กระทบฟอร์มกรอกข้อมูล/ตาราง/หน้าอื่นที่ไม่ใช่ Dashboard

**ไม่ต้องรัน SQL เพิ่ม**

### 2026-10-18 — แก้ไข (correction) "นำเข้า ยอดจริงสิ้นเดือน" ของ Mobile Plant ล้มเหลว: ไม่พบคอลัมน์ is_final

**อาการ:** กดปุ่ม "นำเข้า ยอดจริงสิ้นเดือน" ที่หน้า "ยอดผลิต Mobile Plant" แล้วขึ้น error:
```
นำเข้าข้อมูลล้มเหลว: Could not find the 'is_final' column of 'production_mobile' in the schema cache
```

**Root cause:** ฟังก์ชัน `importProductionExcel(e, plantKey, finalMode)` (ใช้ร่วมกันทุกโรงงานผ่าน `PRODUCTION_PLANT_CONFIG[plantKey]`) ใส่ `is_final: finalMode` ในข้อมูลที่จะบันทึกเสมอ โดยคาดว่าทุกตาราง `production_*` มีคอลัมน์ `is_final` อยู่แล้ว — แต่ตาราง `production_mobile` ถูกสร้างเมื่อ 2026-09-02 (ไฟล์ `production_mobile_schema.sql`) **ก่อน** ที่ฟีเจอร์ `is_final` (ยอดเบื้องต้น vs ยอดจริงสิ้นเดือน) จะถูกเพิ่มเข้าตาราง `production_cde`/`production_propel`/`production_sanon1`/`production_sanon2` ภายหลัง จึงไม่เคยถูกเพิ่มคอลัมน์นี้ให้ `production_mobile` เลยตั้งแต่ต้น เป็นปัญหา schema drift แบบเดียวกับที่เจอกับ CHECK constraint ของค่าไฟฟ้า/ยอดขาย/สต็อกโดรน/รถตักไฟฟ้าก่อนหน้านี้

**วิธีแก้ — รันที่ Supabase SQL Editor:**
```sql
ALTER TABLE production_mobile ADD COLUMN IF NOT EXISTS is_final boolean NOT NULL DEFAULT false;
```
ถ้ารันแล้วยังเจอ error เดิม (schema cache ของ PostgREST ยังไม่รีเฟรช) ให้รันคำสั่งนี้ตามเพื่อบังคับรีเฟรช:
```sql
NOTIFY pgrst, 'reload schema';
```

**บทเรียน:** เวลาเพิ่มคอลัมน์ใหม่ให้ตาราง `production_*` ของโรงงานใดโรงงานหนึ่ง (เช่นฟีเจอร์ยอดจริงสิ้นเดือน) ต้องไล่เพิ่มให้ครบทุกตาราง `production_*` ของทุกโรงงานพร้อมกัน ไม่ใช่แค่โรงงานที่ทดสอบตอนนั้น — โดยเฉพาะโรงงานที่สร้างตารางทีหลัง (เช่น Mobile Plant) มักตกหล่นฟีเจอร์ที่เพิ่มเข้าตารางอื่นไปแล้ว

### 2026-10-18 — รายงานรายปี + Executive Summary ดึงรายชื่อโรงงานอัตโนมัติจาก `factories` — ไม่ต้อง hardcode ซ้ำอีกแล้ว

**ที่มา:** ผู้ใช้ถามว่าเวลาเพิ่มโรงงานใหม่ จะให้โผล่ในรายงานรายปีและ Executive Summary ได้เองโดยไม่ต้องแก้โค้ดทุกครั้งได้หรือไม่ (เดิมทีเดียว `ANNUAL_PLANT_LABELS`/`ANNUAL_FACTORY_NAMES`/`ANNUAL_PLANT_COLORS` และ Executive Summary hardcode ชื่อโรงงานไว้คนละชุดแยกจากกัน เพิ่มโรงงานใหม่ทีเดียวต้องมาแก้สูงสุด 4 จุดในโค้ด)

**ขอบเขตที่ทำ (ตามที่ผู้ใช้เลือก):** ทำเฉพาะ 2 หน้านี้ ส่วนการสร้างตาราง `production_xxx` ใหม่ + เขียนหน้าบันทึก/Dashboard ยอดผลิตเฉพาะของแต่ละโรงงานยังคงต้องทำเองเหมือนเดิม (สถาปัตยกรรมแยกตารางต่อโรงงาน เพราะแต่ละโรงผลิตหินคนละชนิด/คนละจำนวนคอลัมน์กัน — ความเสี่ยงสูงเกินไปถ้าเปลี่ยนเป็นสคีมาปกติเดียวสำหรับทุกโรงงาน ผู้ใช้เลือกไม่เอาโดยระบุความเสี่ยงสูงเกินไป)

**แก้ไข (บรรทัด ~5587 เป็นต้น):**
1. `PRODUCTION_PLANT_CONFIG` (เดิมมีแค่ `table`/`title`/`productColumns`) — เพิ่ม 2 ฟิลด์ใหม่ต่อ plant: `factoryDbName` (ชื่อโรงงานแบบเป๊ะเดียวกับคอลัมน์ `factories.name` ใน DB) และ `color`
2. เพิ่ม `PRODUCTION_FACTORY_MAP` — object `{factories.name -> {plantKey, table, color}}` สร้างอัตโนมัติจาก `PRODUCTION_PLANT_CONFIG` เพื่อใช้หาตารางยอดผลิตของแต่ละโรงงานแบบ dynamic
3. `ANNUAL_PLANT_LABELS` / `ANNUAL_FACTORY_NAMES` / `ANNUAL_PLANT_COLORS` (รายงานรายปี บรรทัด ~11230) — เปลี่ยนจาก hardcode → `Object.fromEntries(Object.entries(PRODUCTION_PLANT_CONFIG).map(...))` ดึงออกมาจาก PRODUCTION_PLANT_CONFIG โดยตรง (ค่าเดิมเท่ากับของเดิมทุกประการ ยืนยันด้วยสคริปต์เช็คแล้ว)
4. `renderDashboardExecutive()` (บรรทัด ~11071) เขียนใหม่ทั้งหมด: ดึงรายชื่อโรงงาน active จากตาราง `factories` ก่อน → จับคู่แต่ละโรงกับ `PRODUCTION_FACTORY_MAP` เพื่อหาตารางยอดผลิต → query เฉพาะโรงงานที่มีตารางผูกไว้ ส่วนโรงงานที่ยังไม่มีตารางผูก (เพิ่งเพิ่มใหม่ ยังไม่ได้สร้างหน้าบันทึกยอดผลิต) จะแสดงเป็นการ์ด "ยังไม่ผูกข้อมูล" แทนการขึ้น 0% (แยกจากโรงงานที่ผลิตจริงแต่เป็น 0 ชัดเจน)
   - "เป้า" ของแต่ละโรงงานเปลี่ยนมาดึงจากคอลัมน์ `factories.target_month` โดยตรง (เดิม hardcode เป็น 120/180/500/400 ตัน/วัน คูณด้วยจำนวนวันในเดือน ซึ่งไม่ตรงกับเป้าที่ตั้งจริงในระบบอยู่แล้ว) — ถ้าโรงงานไหนยังไม่ได้ตั้งค่า target_month ไว้ จะขึ้น "ไม่มีเป้า" แทนการเดา% ผิดๆ
   - ตาราง "ค่าไฟรายโรง" ด้านล่างเปลี่ยนการจับคู่ยอดผลิตต่อโรงงานจาก `facKey==='cde'?...` เดิม → lookup แบบ dynamic ด้วย `tonByFactory` (normalize ชื่อแบบไม่สนใจตัวพิมพ์เล็ก/ใหญ่และช่องว่าง)
   - ผลพลอย่างเพิ่มเติม: เดิม "ผลผลิตรวม" นับแค่ 4 โรงงาน (ไม่รวม Mobile Plant) — หลังแก้จะรวม Mobile Plant และโรงงานใหม่ใดๆที่มีตารางผูกด้วยอัตโนมัติ

**เพิ่มโรงงานใหม่ในอนาคต ต้องทำอะไรบ้าง (สรุปรวม):**
1. เมนู "จัดการ → โรงงาน" — เพิ่มชื่อโรงงาน (status=active, ตั้ง `target_month` ถ้ามี)
2. ข้อมูลค่าไฟฟ้า/ยอดขาย/รถตักไฟฟ้า/สต็อกหินบินโดรน — จะรองรับโรงงานใหม่อัตโนมัติอยู่แล้ว (แก้ CHECK constraint ใน Supabase ตาม Changelog ด้านบน 2026-10-18)
3. **ยอดผลิต (บันทึกข้อมูลรายวัน)** — ยังต้องสร้างตาราง `production_xxx` ใหม่ + เพิ่ม entry ใน `PRODUCTION_PLANT_CONFIG` (ระบุ table/productColumns/factoryDbName/color) + เขียนหน้า manage/dashboard ยอดผลิตใหม่ — **พอเพิ่ม entry นี้แล้ว รายงานรายปี + Executive Summary จะดึงโรงงานนี้มาแสดงเองอัตโนมัติทันที ไม่ต้องแก้อะไรเพิ่ม**

**ไม่ต้องรัน SQL เพิ่ม** — ใช้ตาราง `factories` เดิม แก้เฉพาะโค้ด index.html

---

### 2026-10-18 — แก้ไข (correction) เพิ่มโรงงานใหม่แล้วบันทึกยอดขาย/รถตักไฟฟ้าไม่ได้ (ชุดเดียวกับค่าไฟฟ้าด้านล่าง)

**อาการ:** หลังแก้ `electricity_costs_factory_check` (ด้านล่าง) แล้ว ผู้ใช้ถามต่อว่าโมดูลอื่นจะเจอปัญหาเดียวกันไหม — ตรวจสอบเชิงรุกก่อนเจอ error จริง พบว่า `schema.sql` มี CHECK constraint แบบเดียวกันซ่อนอยู่อีก 3 จุด

**ตรวจพบและแก้ไข (รันใน Supabase SQL Editor):**
```sql
ALTER TABLE sales DROP CONSTRAINT sales_factory_code_check;
ALTER TABLE sales DROP CONSTRAINT sales_factory_name_check;
ALTER TABLE electric_loader DROP CONSTRAINT electric_loader_factory_name_check;
```
**หมายเหตุ:** ตรวจ `drone_stock` ด้วย — ไม่มี constraint ชื่อ `drone_stock_factory_name_check` อยู่จริงในฐานข้อมูล (คอลัมน์ `factory_name` ของตารางนี้ไม่เคยถูกใส่ CHECK ไว้ตั้งแต่สร้าง) จึงไม่ต้องแก้อะไร

**บทเรียน:** เจอ constraint แบบนี้ 1 ตารางแล้ว ควรไล่เช็คทุกตารางที่มีคอลัมน์ชื่อโรงงานทันที อย่ารอให้ผู้ใช้เจอ error ทีละจุด — ดูเช็คลิสต์รวมที่ Section 0A ด้านบน

---

### 2026-10-18 — แก้ไข (correction) สถานะ "ยืนยันแล้ว/ยอดจริง" ของ Mobile Plant ไม่เปลี่ยนเป็นสีเขียว แม้นำเข้ายอดจริงสำเร็จแล้ว (production_daily_status)

**อาการ:** กด "นำเข้า ยอดจริงสิ้นเดือน" สำเร็จ (toast ขึ้น success) แต่ป้ายสถานะทั้งที่หน้า Dashboard Mobile Plant และหน้า "ยอดผลิต Mobile Plant" ยังค้างเป็น "🟡 เบื้องต้น" สีเหลืองไม่เปลี่ยนเป็น "🟢 จริง"

**Root cause:** `importProductionExcel(..., finalMode=true)` หลังบันทึกตัวเลขลง `production_mobile` สำเร็จ จะพยายาม auto-upsert สถานะ `confirmed` ลงตาราง `production_daily_status` (`factory_code:'Mobile'`) แต่ตารางนี้มี CHECK constraint เดิม `production_daily_status_factory_code_check` ล็อกไว้แค่ 4 โรงงานเดิมเหมือนกรณีอื่น ๆ ทำให้ upsert ล้มเหลว — จุดที่ทำให้วินิจฉัยยากคือโค้ดดักส่วนนี้ด้วย `try/catch` แล้วแค่ `console.warn()` ไม่ขึ้น error ให้ผู้ใช้เห็นเลย (ผู้ใช้เห็นแค่ toast "สำเร็จ" ของการนำเข้าหลัก)

**วิธีแก้ (รันใน Supabase SQL Editor):**
```sql
ALTER TABLE production_daily_status DROP CONSTRAINT production_daily_status_factory_code_check;

INSERT INTO production_daily_status (factory_code, production_date, status, note)
SELECT 'Mobile', production_date, 'confirmed', 'Backfill - แก้ constraint ย้อนหลัง'
FROM production_mobile
WHERE is_final = true
ON CONFLICT (factory_code, production_date) DO UPDATE SET status = 'confirmed';
```
ขั้นแรกแก้ปัญหาการบันทึกในอนาคต ขั้นสองจำเป็นต้องรันคู่กันเสมอ เพราะวันที่เคยนำเข้าไปแล้วก่อนแก้ constraint ไม่เคยมี record `confirmed` เกิดขึ้นจริง ลบ constraint อย่างเดียวไม่ช่วยย้อนแก้ข้อมูลเก่า

**บทเรียน:** โค้ดที่ดัก error ด้วย `try/catch` แล้วแค่ `console.warn` (ไม่ throw/ไม่แจ้ง toast) จะซ่อนปัญหา constraint แบบนี้ไว้ได้นาน ควรพิจารณาเปลี่ยนเป็นแจ้งเตือนผู้ใช้แบบเบา ๆ (เช่น toast warning) แทนการเงียบสนิท จะได้รู้ตัวเร็วกว่านี้

---

### 2026-10-18 — แก้ไข (correction) เพิ่มโรงงานใหม่แล้วบันทึกค่าไฟฟ้าไม่ได้ (แก้ไขเพิ่มเติมจากรอบ 2026-09-20 ด้านล่าง)

**อาการ:** เพิ่มโรงงานใหม่ที่เมนู "จัดการ → โรงงาน" แล้วไปบันทึกค่าไฟฟ้าที่เมนู "ค่าไฟฟ้า" ขึ้นข้อความ:
```
บันทึกไม่สำเร็จ: new row for relation "electricity_costs" violates check constraint "electricity_costs_factory_check"
```
**สาเหตุจริง:** การแก้เมื่อ 2026-09-20 ด้านบน (ให้ `ELEC_FACTORIES` ดึงรายชื่อโรงงานแบบ dynamic จากตาราง `factories`) **แก้เฉพาะชั้น UI/โค้ด แต่ลืมแก้ชั้นฐานข้อมูล** ตาราง `electricity_costs` (สร้างจาก `electricity_schema.sql` ตั้งแต่ 2026-07-16) ยังมี CHECK constraint บังคับคอลัมน์ `factory` ให้เป็นได้แค่ 4 ชื่อเดิมค้างอยู่:
```sql
factory text NOT NULL CHECK (factory IN ('CDE','Propel','Sanon1','Sanon2'))
```
บันทึกข้อมูลเดิมตอน 2026-09-20 เขียนระบุไว้ผิดว่า "ไม่ต้องรัน SQL เพิ่ม" — ที่จริงคือต้องแก้ CHECK constraint นี้ด้วย มิเช่นนั้นเลยทำให้โรงงานใหม่ทุกโรงที่เพิ่มหลังจากนั้น จะบันทึกค่าไฟฟ้าไม่ได้เสมอ

**แก้ไข (รันใน Supabase SQL Editor เท่านั้น — ไม่กระทบข้อมูลเดิม):**
```sql
ALTER TABLE electricity_costs DROP CONSTRAINT electricity_costs_factory_check;
```
ลบ constraint ทิ้งเลยโดยไม่ต้องสร้างใหม่แทน เพราะรายชื่อโรงงานที่ถูกต้องควบคุมอยู่ที่ชั้นแอปพลิเคชันอยู่แล้ว (ผ่าน `ensureElecFactoriesLoaded()` ที่ดึงจากตาราง `factories` เฉพาะ `status=active`)

**บทเรียน:** เวลาเปลี่ยน UI จาก hardcode → dynamic ต้องเช็ค CHECK constraint / ข้อจำกัดระดับฐานข้อมูลใน Supabase ด้วยเสมอ เพราะการแก้โค้ดอย่างเดียวไม่สามารถแก้ข้อจำกัดระดับ DB ได้

---

### 2026-09-20 — หน้าค่าไฟฟ้าดึงรายชื่อโรงงานอัตโนมัติจากตาราง `factories`

**ที่มา:** เดิมหน้า "ค่าไฟฟ้า" (Dashboard + จัดการ) ใช้รายชื่อโรงงาน hardcode ไว้ในโค้ด (`ELEC_FACTORIES` มีแค่ CDE/Propel/Sanon1/Sanon2) เพิ่มโรงงานใหม่ที่เมนู "จัดการ → โรงงาน" (เช่น Mobile Plant) แล้วไม่โผล่ในฟอร์มค่าไฟฟ้า ต้องแก้โค้ดเองทุกครั้ง

**แก้ไข (บรรทัด ~10268 เป็นต้นไป):**
- เปลี่ยน `ELEC_FACTORIES`/`ELEC_PROD_TABLES` จาก `const` hardcode → `let` + ฟังก์ชัน `ensureElecFactoriesLoaded()` ที่ดึงรายชื่อโรงงานจากตาราง `factories` (เฉพาะ `status = active`) มาสร้าง key/label/สีให้อัตโนมัติ (cache 60 วิ กันยิง query ถี่)
- โรงงานเดิม (CDE/Propel/Sanon1/Sanon2/Mobile Plant) ยังใช้สีเดิมตาม `ELEC_KNOWN_META` เพื่อความต่อเนื่องของกราฟ ส่วนโรงงานใหม่ที่ไม่รู้จักจะสุ่มสีจาก palette ให้อัตโนมัติ
- เพิ่ม `await ensureElecFactoriesLoaded()` ที่จุดเริ่มของทุกฟังก์ชันที่ใช้รายชื่อโรงงาน: `loadElecData()`, `renderElecManageTable()`, `openElecMonthModal()`, `openElecBulkModal()` (เปลี่ยนเป็น async), `fetchExecReportData()`
- แก้ query ยอดผลิตให้ปลอดภัยขึ้น: โรงงานที่ยังไม่มีตาราง production ผูกไว้ใน `ELEC_PROD_TABLES` จะข้าม query (ได้ผลลัพธ์ว่างแทน error) — บันทึก/แสดงค่าไฟฟ้า (บาท) ได้ปกติ แต่จะยังไม่มี "บาท/ตัน" จนกว่าจะเพิ่ม mapping ตารางผลิตของโรงงานนั้นเองใน `ELEC_KNOWN_META`
- แก้ข้อความ hardcode "ค่าไฟฟ้า 4 โรงงาน" → "ค่าไฟฟ้ารายโรงงาน" และ "ค่าไฟฟ้ารวม 4 โรงงาน" (ใน Executive Summary) → "ค่าไฟฟ้ารวมทุกโรงงาน"

**ขอบเขต:** แก้เฉพาะโมดูลค่าไฟฟ้าตามที่ผู้ใช้ยืนยัน — ระบบยอดผลิตหลัก (Dashboard/บันทึกยอดผลิตของแต่ละโรงงาน) ยังคงต้องสร้างตาราง `production_*` + หน้า manage-prod/dash ใหม่ต่อโรงงานเหมือนเดิม (สถาปัตยกรรมแยกตารางต่อโรงงาน ไม่ใช่ตารางเดียวแบบ factory_id) — ไม่ได้ทำ full auto-add เพราะมีความเสี่ยงสูงและอยู่นอกขอบเขตที่ผู้ใช้ต้องการรอบนี้

**ไม่ต้องรัน SQL เพิ่ม** — ใช้ตาราง `factories`/`electricity_costs` เดิม

### 2026-09-19 — เอาปุ่ม +/- ออกจากช่องกรอกตัวเลข + กันตัวเลขวิ่งตามลูกกลิ้งเมาส์

**ที่มา:** ฟอร์ม "เพิ่มข้อมูลผลผลิต" (เช่น ชม.เครื่อง (หยุด), มิเตอร์หยุด) มีปุ่ม spinner (+/-) ของ browser และตัวเลขเปลี่ยนค่าไปเองเมื่อเลื่อนลูกกลิ้งเมาส์ผ่านช่องที่กำลังโฟกัสอยู่ เสี่ยงกรอกข้อมูลผิดโดยไม่ตั้งใจ

**แก้ไข (มีผลกับ `input[type="number"]` ทุกช่องทั้งระบบ ไม่ใช่เฉพาะฟอร์มผลิต):**
- CSS (บรรทัด ~90, ใน `<style>` หลัก): ซ่อนปุ่ม spin button ของ Chrome/Edge/Safari ด้วย `::-webkit-outer/inner-spin-button { -webkit-appearance: none; }` และปิดปุ่มของ Firefox ด้วย `-moz-appearance: textfield`
- JS (ก่อน SECTION 19: APP BOOTSTRAP, บรรทัด ~10853): เพิ่ม global `document.addEventListener('wheel', ...)` — ถ้ากำลังโฟกัสอยู่ที่ `input[type=number]` ขณะเลื่อนลูกกลิ้ง จะเรียก `.blur()` ทันที ทำให้ค่าตัวเลขไม่เปลี่ยน (ใช้ event delegation ระดับ document จึงครอบคลุมฟอร์มที่สร้างขึ้นภายหลังด้วย ไม่ต้องแก้ทีละฟอร์ม)

**ไม่ต้องรัน SQL เพิ่ม**

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
