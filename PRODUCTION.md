# PRODUCTION.md — ระบบผลิต (System 1)
> ไฟล์นี้บันทึกรายละเอียดเฉพาะ `index.html` — อ่านก่อนแก้ไขทุกครั้ง
> ตั้งแต่ 2026-09-15 ไฟล์นี้เป็นที่เก็บ "สถานะ/ฟีเจอร์ล่าสุด" + "Changelog" ของ System 1 ทั้งหมด — ดู `CLAUDE.md` Section 0A สำหรับเหตุผลที่แยกไฟล์

---

## 0. สถานะล่าสุด (อัปเดต 2026-09-26)

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

### 10.1 ถ้าเจอปัญหา "การ์ด/กราฟล้นจอมือถือ" อีก — เช็คตามลำดับนี้ (อย่าไล่แก้จากจุดที่เห็นอาการอย่างเดียว)

ปัญหานี้เคยใช้เวลาแก้หลายรอบ (ดู Changelog 2026-09-26 รอบ 1-5) เพราะไล่แก้จากจุดที่เห็นอาการ (เช่น Dashboard) ไปทีละจุด โดยไม่ตรวจ container ทุกชั้นตั้งแต่ root ครั้งหน้าให้เช็คตามลำดับนี้แทน:

1. **เช็ค root cause ระดับโครงสร้างแอปก่อนเป็นอันดับแรก** — `#app-shell-main` และ `#page-content` (ใน `renderAppShell()`) ต้องมี `min-width: 0` เสมอ (มีอยู่แล้วที่ CSS บรรทัด ~50 นอก media query) เพราะเป็น flex item ของ layout หลักทั้งแอป ถ้าเผลอลบ/ย้าย CSS นี้ออกไป ปัญหาล้นจอจะกลับมาทันทีทุกหน้า ไม่ใช่แค่ Dashboard
2. **grid/flex item ทุกตัวที่ใช้ `grid-cols-*` หรือ `flex` แล้วมีเนื้อหาข้างในกว้าง (ตัวเลข, กราฟ, การ์ด)** ต้องมี `min-width: 0` กำกับลูกด้วยเสมอ (browser default คือ `min-width: auto` ซึ่งยึดตามเนื้อหาไม่ยอมหด) — ดูตัวอย่างที่ `.dash-dark-bg .grid > *` และ `.dash-dark-bg .flex > *` (บรรทัด ~53-60)
3. **SVG/canvas ที่กำหนด `width`/`height` เป็น attribute ตรงๆ** (ไม่ใช่ CSS class) ต้องมี `max-width:100% !important; height:auto !important;` กำกับเสมอ เพราะ attribute พวกนี้ไม่หดตาม container เอง
4. **จุดที่สำคัญ/ซับซ้อนและพังบ่อย** (เช่น OEE Gauge) ให้เขียน CSS `display:grid`/`display:flex` เป็น class ของตัวเอง **ไม่พึ่ง Tailwind utility class ล้วนๆ** เพราะ Tailwind CDN (`cdn.tailwindcss.com`) เป็น JIT scan on-the-fly มีโอกาสไม่ generate CSS ให้ครบในไฟล์ขนาดใหญ่ (ดูตัวอย่าง `.oee-gauge-grid`)
5. **ทดสอบบนมือถือจริงเสมอ อย่าเชื่อ Chrome DevTools Responsive mode 100%** — เคยเจอกรณี DevTools แสดงตัวเลข/ภาพคลาดเคลื่อนจากขนาดจอที่ตั้งไว้จริง (ดู Changelog รอบ 4-5) ทำให้เข้าใจผิดว่าแก้ไม่หายทั้งที่ CSS ถูกต้องแล้ว หรือกลับกัน คือ DevTools ดูเหมือนไม่ล้นแต่มือถือจริงล้น

---

## 11. Changelog

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
