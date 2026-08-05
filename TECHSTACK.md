# TECHSTACK.md — โปรเจกต์เว็บสานนท์

> **อ่านไฟล์นี้ก่อนเริ่มเขียนโค้ดทุกครั้ง** เพื่อให้รู้ว่าโปรเจกต์ใช้เทคโนโลยีอะไร และมีกฎอะไรที่ต้องรู้ก่อน

---

## 1. ภาพรวมโปรเจกต์

| รายการ | รายละเอียด |
|--------|-----------|
| บริษัท | สานนท์ จำกัด (Sanon Co., Ltd.) โรงโมหินอุตสาหกรรม จ.สระบุรี |
| Hosting | GitHub Pages — `https://sanon-saraburi.github.io/sanon-webapp/` |
| Repo path | ไฟล์อยู่ใน `G:\เขียนเว็บ+Ai\เขียนเว็บสานนท์` |
| Staging | Copy ไฟล์ที่แก้ไปไว้ใน `GitHub\` ก่อน upload ขึ้น GitHub ทุกครั้ง |
| ผู้ดูแล | คุณใหญ่ (YAi) — วิศวกรการผลิต |

---

## 2. ระบบทั้งหมด (5 ไฟล์)

| ไฟล์ | ระบบ | สถานะ | Session Key |
|------|------|--------|-------------|
| `portal.html` | Portal — Smart Launcher | ✅ ใช้งานจริง | `_sn_shared_sess` |
| `index.html` | System 1 — Production (ยอดผลิต) | ✅ ใช้งานจริง | `_sn_sess` |
| `inventory.html` | System 2 — Inventory (คลังวัสดุ) | ✅ ใช้งานจริง | `_sn_inv_sess` |
| `pm.html` | System 3 — PM เครื่องจักร | ✅ ใช้งานจริง | `_sn_pm_sess` |
| `checkin.html` | System 4 — Checkin พนักงาน | 🚧 บางส่วน | `_sn_ck2_sess` |

**ขนาดไฟล์โดยประมาณ:**
- `index.html` — ~9,200+ บรรทัด
- `inventory.html` — ~4,000+ บรรทัด
- `pm.html` — ~4,500+ บรรทัด
- `checkin.html` — ~3,000+ บรรทัด
- `portal.html` — ~300 บรรทัด

**Pattern:** Single-file SPA ทุกระบบ — HTML + CSS + JavaScript รวมในไฟล์เดียว ไม่ใช้ Framework ไม่มี Build Tool

---

## 3. Backend — Supabase

| รายการ | ค่า |
|--------|-----|
| Project URL | `https://pcmpwkcmvsxrvbximjgf.supabase.co` |
| Database | PostgreSQL (managed by Supabase) |
| Anon Key | อ่านจาก CLAUDE.md — **ห้ามพิมพ์ในแชต** (security) |

### 3.1 Authentication
- **ไม่ใช้ Supabase Auth** — query ตรงจาก `app_users` table (username + password plaintext)
- System 1, 2, 3 ใช้ `app_users` table ร่วมกัน (SSO)
- System 4 ใช้ `checkin_users` table แยกต่างหาก
- Login ครั้งเดียวผ่าน portal หรือระบบใดก็ได้ → ใช้ได้ทุกระบบ (SSO ผ่าน `localStorage._sn_shared_sess`)

### 3.2 Row Level Security (RLS)
- เปิด RLS ทุกตาราง
- Policy: `anon_all` — `FOR ALL TO anon USING (true)` (อนุญาต anon key อ่าน/เขียนได้)
- ยกเว้น `app_users`: ไม่มี DELETE policy (ป้องกันลบ user ผ่าน anon key)

### 3.3 Edge Functions (Deno/TypeScript)
| Function | ทำหน้าที่ | Trigger |
|----------|----------|---------|
| `line-notify` | ส่ง LINE Flex Message แจ้งเตือน | เรียกจาก JS frontend (fire-and-forget) |
| `pm-daily` | ส่ง LINE แจ้ง PM เกินกำหนด | pg_cron ทุกวันจันทร์ 07:00 (ไทย) |
| `inventory-alert` | แจ้งสต็อกต่ำกว่า min_stock | pg_cron ทุกวันจันทร์ |

**Deploy:** วางโค้ดใน Supabase Dashboard → Edge Functions → [ชื่อ function] → Deploy
**ไฟล์ local:** `line-notify_index.txt` (ใช้วาง deploy), `supabase/functions/line-notify/index.ts`

### 3.4 pg_cron
- ติดตั้งใน Supabase ผ่าน Extension
- ใช้สั่ง job รายสัปดาห์ (LINE notifications อัตโนมัติ)
- ไฟล์ SQL: `pm_cron.sql`

---

## 4. Frontend Libraries (โหลดจาก CDN ทั้งหมด)

### 4.1 ทุกระบบ (index, inventory, pm, checkin)

| Library | CDN Source | Version | ใช้ทำ |
|---------|-----------|---------|------|
| **Tailwind CSS** | `cdn.tailwindcss.com` | latest | Styling ทั้งหมด — utility-first CSS |
| **Lucide Icons** | `unpkg.com/lucide` | latest | Icon set (SVG) |
| **Chart.js** | `cdn.jsdelivr.net/npm/chart.js@4` | v4 | กราฟ Bar, Line, Doughnut |
| **Supabase JS** | `cdn.jsdelivr.net/npm/@supabase/supabase-js@2` | v2 | เชื่อม Supabase DB |
| **SheetJS (xlsx)** | `cdn.jsdelivr.net/npm/xlsx@0.18.5` | 0.18.5 | Export Excel (.xlsx) |
| **Google Fonts Kanit** | `fonts.googleapis.com` | — | Font ภาษาไทยหลัก (weight 300–700) |

### 4.2 เฉพาะระบบ

| Library | CDN Source | ระบบ | ใช้ทำ |
|---------|-----------|------|------|
| **QRCodeJS** | `cdnjs.cloudflare.com/ajax/libs/qrcodejs` | Inventory | สร้าง QR Code label วัสดุ |
| **JsBarcode** | `cdnjs.cloudflare.com/ajax/libs/jsbarcode` | Inventory, Checkin | สร้าง Barcode (Code128) |
| **html5-qrcode** | `cdnjs.cloudflare.com/ajax/libs/html5-qrcode` | Inventory | สแกน Barcode/QR ผ่านกล้อง |
| **ZXing Library** | `cdn.jsdelivr.net/npm/@zxing/library@0.19.1` | Checkin | สแกน Barcode ผ่านกล้อง |
| **Tesseract.js** | `cdn.jsdelivr.net/npm/tesseract.js@5` | Checkin | OCR อ่านตัวอักษรจากรูป/กล้อง |
| **PapaParse** | `cdnjs.cloudflare.com/ajax/libs/PapaParse` | Checkin | อ่าน/แปลง CSV |

### 4.3 Tailwind Config (ใช้ในทุกระบบ)
```js
tailwind.config = {
  theme: {
    extend: {
      fontFamily: { kanit: ['Kanit', 'sans-serif'] },
      colors: {
        primary:   { 50–900: ... }, // indigo/violet
        secondary: { 50–900: ... }, // slate
      }
    }
  }
};
```

---

## 5. PWA (Progressive Web App)

| ไฟล์ | ทำหน้าที่ |
|------|----------|
| `sw.js` | Service Worker — Cache v3, PRECACHE ทุกไฟล์หลัก |
| `manifest-production.json` | PWA manifest สำหรับ index.html |
| `manifest-inventory.json` | PWA manifest สำหรับ inventory.html |
| `manifest-pm.json` | PWA manifest สำหรับ pm.html |
| `manifest-checkin.json` | PWA manifest สำหรับ checkin.html |
| `manifest-portal.json` | PWA manifest สำหรับ portal.html |
| `icon-192.png` | App icon 192×192 (square, navy bg) |
| `icon-512.png` | App icon 512×512 (square, navy bg) |

**กฎ:** path ใน manifest ต้องขึ้นต้นด้วย `/sanon-webapp/` เสมอ
**กฎ:** ถ้าแก้ `sw.js` ต้องเพิ่ม version ใน `CACHE_NAME` ทุกครั้ง

---

## 6. LINE Notification System

| รายการ | รายละเอียด |
|--------|-----------|
| API | LINE Messaging API v2 |
| Message Type | Flex Message (Bubble Card) |
| Target | LINE Group (LINE_GROUP_ID — เก็บใน Supabase env) |
| Token | LINE Channel Access Token (Long-lived) — เก็บใน Supabase env |
| วิธีส่ง | JavaScript `fetch()` → Supabase Edge Function `line-notify` (fire-and-forget) |
| CORS | Edge Function ต้องมี OPTIONS handler + CORS headers ทุก Response |

**Trigger แต่ละระบบ:**

| ระบบ | เหตุการณ์ | เงื่อนไข |
|------|----------|---------|
| System 1 | บันทึกยอดผลิต | status = pending เท่านั้น |
| System 2 | เบิกวัสดุ | status = pending เท่านั้น |
| System 2 | สต็อกต่ำกว่า min_stock | ทันทีหลังอนุมัติ/เบิก |
| System 3 | บันทึกมิเตอร์ | เฉพาะ role ไม่ใช่ admin/manager |
| System 3 | รอบ PM ใกล้/เกินกำหนด | หลังบันทึกมิเตอร์ (ถ้ามี alert) |
| ทุกระบบ | สต็อกต่ำ / PM เกิน | อัตโนมัติทุกวันจันทร์ 07:00 (pg_cron) |

---

## 7. Database — ตารางหลัก

### System 1 — Production
| ตาราง | เนื้อหา |
|-------|---------|
| `app_users` | ผู้ใช้งานทุกระบบ (username, password, role, factory, department) |
| `roles` | กำหนด role |
| `role_permissions` | สิทธิ์ต่อ role ต่อเมนู |
| `user_permissions` | override สิทธิ์รายบุคคล |
| `factories` | รายชื่อโรงงาน |
| `machines` | เครื่องจักร |
| `material_types` | ประเภทวัสดุ |
| `production_cde` | ยอดผลิต CDE |
| `production_propel` | ยอดผลิต Propel |
| `production_sanon1` | ยอดผลิต Sanon 1 |
| `production_sanon2` | ยอดผลิต Sanon 2 |
| `drone_stock` | สต็อกหินโดรน |
| `sales` | ยอดขาย |
| `electric_loader` | รถตักไฟฟ้า |
| `groundwater_usage` | น้ำบาดาล |
| `electricity_costs` | ค่าไฟฟ้า 4 โรงงาน |
| `approval_log` | Log การอนุมัติ |
| `water_sources` | แหล่งน้ำ |

### System 2 — Inventory
| ตาราง | เนื้อหา |
|-------|---------|
| `inventory_items` | master วัสดุ (code, name, category, unit, min_stock, allowed_factories) |
| `inventory_transactions` | รับ/เบิก/ปรับยอด |
| `inventory_lots` | FIFO lot tracking (remaining_qty, unit_cost) |

### System 3 — PM
| ตาราง | เนื้อหา |
|-------|---------|
| `pm_machines` | เครื่องจักร (name, factory, current_meter, alert_threshold) |
| `pm_items` | รายการ PM ต่อเครื่อง (interval_value, last_pm_meter) |
| `pm_logs` | ประวัติทำ PM |
| `pm_downtime` | Downtime log |
| `pm_meter_logs` | บันทึกเลขมิเตอร์รายวัน |
| `pm_repair_logs` | บันทึกการซ่อม |
| `pm_repair_parts` | อะไหล่ที่ใช้ต่อการซ่อม |
| `pm_parts` | master อะไหล่ (stock_qty, min_stock) |
| `pm_parts_stock_log` | ประวัติรับ/เบิกอะไหล่ |
| `pm_config` | ตั้งค่าระบบ (categories, factories, pm_types) |

### System 4 — Checkin
| ตาราง | เนื้อหา |
|-------|---------|
| `checkin_users` | ผู้ใช้งานระบบเช็คอิน (แยกจาก app_users, SESSION_KEY = `_sn_ck2_sess`) |
| `checkin_employees` | ข้อมูลพนักงาน (employee_id, name, department, status) |
| `checkin_records` | บันทึกเวลาเข้า/ออกพักเที่ยง |
| `checkin_visitors` | บุคคลภายนอก (person_count, gate, status) |
| `checkin_config` | ตั้งค่าระบบ (reason_rules, gate_names, timecard_rules) |
| `checkin_timecards` | Header บัตรตอก (1 row = 1 รอบ 15 วัน) — v6 |
| `checkin_timecard_logs` | บันทึกรายวันจากบัตรตอก (OT, สาย, ขาด) — v6 |

---

## 8. RBAC — สิทธิ์การใช้งาน

| Role | สิทธิ์ |
|------|--------|
| `admin` | เต็มทุกเมนู (hardcode) |
| `managing_md` | กรรมการผู้จัดการ |
| `manager` | ผู้จัดการ — อนุมัติได้ |
| `supervisor` | หัวหน้างาน |
| `operator` | ผู้ควบคุมเครื่องจักร |
| `excavator_operator` | ผู้ควบคุมรถขุด |
| `office` | สำนักงาน |
| `clerk` | เสมียน |

- สิทธิ์มาจาก `role_permissions` + `user_permissions` (override รายบุคคล)
- Menu prefix แยกต่างระบบ: `dash-` / `manage-` (S1), `inv-` (S2), `pm-` (S3), `ck-` (S4)
- `isManager()` = `role === 'admin' || role === 'manager'`

---

## 9. กฎสำคัญที่ต้องรู้ (ห้ามทำผิด)

### Code Rules
```
✅ ใช้ in-memory state เท่านั้น (JavaScript variables)
❌ ห้ามใช้ localStorage / sessionStorage สำหรับข้อมูล
   ข้อยกเว้นเดียว: _sn_shared_sess สำหรับ SSO ข้ามระบบ

✅ Auth ผ่าน query ตรงจาก app_users table (S1/S2/S3) หรือ checkin_users (S4)
❌ ห้ามใช้ Supabase Auth (supabase.auth.signIn ฯลฯ)

✅ Factory name normalize ก่อนใช้งานเสมอ: "Sanon 1" → "Sanon1", "Sanon 2" → "Sanon2"
✅ Session Timeout 2 ชั่วโมง (ยกเว้น admin)
✅ ทุกระบบต้องมี SSO — เขียน/อ่าน _sn_shared_sess ใน localStorage
```

### File Rules
```
✅ แก้ไขไฟล์ในโฟลเดอร์หลัก → copy ไป GitHub\ → upload GitHub
✅ อัปเดต CLAUDE.md Section 0 ทุกครั้งที่แก้ไขสำเร็จ
❌ ห้าม copy sw.js / manifest-*.json ข้ามแชต (ยกเว้นถูกสั่งโดยเฉพาะ)
❌ ห้ามอัปไฟล์เก่าขึ้น GitHub
```

### Security Rules
```
❌ ห้ามพิมพ์ Supabase Anon Key ในแชต (เก็บประวัติการสนทนา)
❌ ห้ามพิมพ์ LINE Token ในแชต
✅ เวลาจะให้รัน SQL → ส่งไฟล์เสมอ ห้ามพิมพ์ในแชต
```

### SQL Patch Order Rules (System 4)
```
⚠️ ต้องรัน SQL patch ตามลำดับเสมอ — ห้ามข้ามลำดับ
   v4 → v5 → v6 (ไม่งั้น FK constraint จะพัง)
```

---

## 10. Global State Variables (index.html — System 1)

```js
let currentUser = null;          // { id, username, full_name, role, factory, department }
let currentPage = 'landing';     // page key ปัจจุบัน
let pendingApprovalCount = 0;    // badge นับรายการ pending
let isMobileSheetOpen = false;   // bottom-sheet dashboard เพิ่มเติม
let isManageSheetOpen = false;   // bottom-sheet จัดการข้อมูล
let isSystemSheetOpen = false;   // bottom-sheet เปลี่ยนระบบ
let chartRegistry = {};          // Chart.js instances (destroy ก่อน redraw)
let sessionTimerInterval = null; // countdown timer handle
let sessionSecondsLeft = 0;
let sessionWarnShown = false;
let approvalCountInterval = null;
let _loginTargetSystem = null;   // 'inventory' | 'pm' | null
```

---

## 11. ไฟล์ SQL สำคัญ

| ไฟล์ | ใช้ทำ | สถานะ |
|------|------|--------|
| `schema.sql` | โครงสร้าง DB System 1 | รันแล้ว |
| `inventory_schema.sql` | โครงสร้าง DB System 2 | รันแล้ว |
| `lot_tracking.sql` | FIFO lot tracking | รันแล้ว |
| `pm_schema.sql` | โครงสร้าง DB System 3 | รันแล้ว |
| `pm_repair_schema.sql` | ตารางซ่อม/อะไหล่ | รันแล้ว |
| `pm_meter_schema.sql` | ตารางบันทึกมิเตอร์ | รันแล้ว |
| `electricity_schema.sql` | ค่าไฟฟ้า | รันแล้ว |
| `pm_cron.sql` | pg_cron ส่ง LINE ทุกจันทร์ | รันแล้ว |
| `line_webhook.sql` | DB trigger LINE (เก่า — ไม่ใช้แล้ว) | deprecated |
| `checkin_schema_v4_patch.sql` | เพิ่ม person_count ใน checkin_visitors | ✅ รันแล้ว |
| `checkin_schema_v5_patch.sql` | เพิ่ม permissions text[] ใน checkin_users | ✅ รันแล้ว |
| `checkin_schema_v6_patch.sql` | ตาราง checkin_timecards + checkin_timecard_logs + OT rules ใน checkin_config | ✅ รันแล้ว |

---

*อัปเดตล่าสุด: 2026-08-02*
