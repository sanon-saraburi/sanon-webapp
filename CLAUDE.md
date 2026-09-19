# CLAUDE.md — โปรเจกต์เว็บสานนท์

---

## ⚠️ 0. อ่านก่อนทำงานทุกครั้ง — System Status Board

> **กฎ:** ทุกแชตที่เปิดใหม่ต้องอ่านส่วนนี้ก่อนเสมอ เพื่อให้รู้สถานะปัจจุบันของทุกระบบ
> อัปเดตทุกครั้งที่แก้ไขสำเร็จหรือพบปัญหา

### สถานะระบบ (อัปเดตล่าสุด: 2026-09-08)

| ระบบ | ไฟล์ | สถานะ | Feature ที่ทำงานได้ล่าสุด | ปัญหาที่รู้อยู่ |
|------|------|--------|--------------------------|--------------|
| Portal — Smart Launcher | `portal.html` | ✅ ใช้งานจริง | Login → แสดงเฉพาะระบบที่มีสิทธิ์, SSO, PWA shortcut เดียวสำหรับทุก User, **System 5 (จองห้องประชุม) ตรวจสิทธิ์ผ่าน meeting_access**, **System 6 (ขอลา) openAll=true ทุกคนมีสิทธิ์** | ต้องรัน SQL patch `meeting_access` ก่อน deploy |
| System 1 — Production | `index.html` | ✅ ใช้งานจริง | Dashboard ทุกเมนู, Executive Dashboard, ค่าไฟฟ้า, PDF Report, SSO, **Mobile/Desktop System Switcher 6 ระบบ**, LINE แจ้งเตือนจาก JS, **Export CSV ทุกโรงงาน**, **Mobile Plant — Dashboard + ยอดผลิต + Approval ครบ**, **เพิ่มโรงงาน: กำหนดเป้าตัน/เดือน + ตัน/ชม. จาก UI ได้ทุกโรงงาน**, **รายงานรายปี (dash-annual) — Dashboard + PDF + PPTX Export ทุกโรงงาน**, **System Switcher: ชื่อ "เช็คอิน" → "HR", การ์ดจองห้องซ่อนตาม meeting_access**, **วิเคราะห์รายวัน — กราฟ/ตาราง/Breakdown ครบทุกโรงงาน**, **รายวัน auto-detect วันล่าสุดที่มีข้อมูล**, **material_types: is_feed_material + is_product**, **groundwater_usage: ผู้บันทึก**, **drone factory sort: CDE→Propel→Sanon1→Sanon2→Mobile Plant** | ต้องรัน SQL patches สำหรับ Mobile Plant (ดู Section 7) |
| System 2 — Inventory  | `inventory.html` | ✅ ใช้งานจริง | รายละเอียดฟีเจอร์ + Changelog ทั้งหมดย้ายไปที่ **`INVENTORY.md`** แล้ว (ตามนโยบาย 2026-09-15) | ดู `INVENTORY.md` |
| System 3 — PM         | `pm.html` | ✅ ใช้งานจริง | รายละเอียดฟีเจอร์ทั้งหมด → ดู **`PM.md`** | ไม่มี Loading Screen (ถูก revert) — รายละเอียดเพิ่มเติมดู `PM.md` |
| System 4 — Checkin/HR | `checkin.html` | 🚧 ใช้งานได้บางส่วน | เช็คอิน/ออก, บุคคลภายนอก, Dashboard, รายงาน 2 แท็บ, Permission Matrix, QR+Barcode+สแกนกล้อง, สมัครสมาชิก, **บัตรตอก (OCR + OT calc + half_am/half_pm)**, **ชื่อ Sidebar → "สานนท์ — HR"**, **Refresh ค้างหน้าเดิม (sessionStorage._sn_ck_lastpage)**, **พิมพ์ตามตัวกรองแผนก**, **Guard Realtime Popup เมื่อ Pass approved (Supabase Broadcast)**, **ข้อมูลการลา: สรุปประจำเดือน + ประวัติทั้งหมด (ดึงจาก leave_requests + pass_requests)** | ยังไม่มี Export Excel — ยังไม่มี LINE แจ้งเตือน — ต้องรัน SQL: `ALTER TABLE checkin_users ADD COLUMN IF NOT EXISTS permissions text[];` |
| System 5 — Meeting    | `meeting.html` | 🚧 พร้อม deploy (รอ SQL) | **No-login public booking** — เปิดปฏิทินตรง ไม่ต้อง login, Admin login มุมขวาบน, จองได้ทันที (auto confirmed), Conflict check, FullCalendar, QR Share, Print, Soft-delete+Restore, Admin section ใน sidebar (rooms/users/settings) — เฉพาะ Admin login เท่านั้น | ต้องรัน SQL: `ALTER TABLE app_users ADD COLUMN IF NOT EXISTS meeting_access boolean DEFAULT false;` |
| System 6 — Leave      | `leave.html` | 🚧 พร้อม deploy (รอ SQL) | รายละเอียดฟีเจอร์ทั้งหมด → ดู **`LEAVE.md`** | ต้องรัน SQL 6 ชุด + Deploy Edge Function + Upload GitHub Pages + เปิด Realtime — รายละเอียดดู `LEAVE.md` |
| PWA                   | `sw.js` + manifests | ✅ พร้อม deploy | icon-192/512.png, manifest ทั้ง 5 ระบบ (รวม portal), **SW cache v6 — Network First สำหรับ root URL `/sanon-webapp/`** | — |

### LINE Notification Status

| Trigger | วิธีส่ง | สถานะ | หมายเหตุ |
|---------|--------|--------|---------|
| บันทึกยอดผลิต (production_*) | JS fetch() ใน index.html | ✅ พร้อมใช้ | ส่ง recorder_name ตรงจาก currentUser — ต้อง Deploy Edge Function ล่าสุด |
| เบิกวัสดุ (inventory_transactions) | JS fetch() ใน inventory.html | ✅ พร้อมใช้ | ส่ง item_name จาก dropdown ตรง — ต้อง Deploy Edge Function ล่าสุด |
| บันทึกซ่อม (pm_repair_logs) | JS fetch() ใน pm.html | ✅ พร้อมใช้ | ส่งทันทีหลัง INSERT — ต้อง Deploy Edge Function ล่าสุด |
| สต็อกต่ำกว่า min_stock | `inventory-alert` Edge Function | ✅ ทำงาน | Trigger + Weekly cron (ทุกวันจันทร์) |
| คำขอลา (leave_requests) | JS fetch() ใน leave.html | ✅ ทำงานแล้ว | ส่งไปกลุ่ม HR (Sanon HR 2) — OA HR — มีรูปโปรไฟล์พนักงานในการ์ด |
| ขอออกนอกบริเวณ (pass_requests) | JS fetch() ใน leave.html | ✅ ทำงานแล้ว | pending→กลุ่ม HR, approved→กลุ่ม รปภ. (Sanon Security) — มีรูปโปรไฟล์พนักงานในการ์ด |

> **⚠️ LINE Notify ปิดบริการแล้ว (1 เม.ย. 2025)** — ระบบแจ้งเตือนทั้งหมดใช้ **LINE Messaging API** แทน (`api.line.me/v2/bot/message/push`)

> **3 LINE OA (แยก quota 200 msg/เดือนต่อ OA):**
> - OA ผลิต (Sanon Production) → กลุ่มผลิต — System 1-3 — **Secrets: `LINE_CHANNEL_TOKEN` + `LINE_GROUP_ID`**
> - OA HR (Sanon HR) → กลุ่ม Sanon HR 2 (`C35db76ecdc10af3e1fef08821131ffbf`) — Leave+Pass pending — **Secrets: `LINE_CHANNEL_TOKEN_HR` + `LINE_GROUP_ID_HR`**
> - OA รปภ. (Sanon Security) → กลุ่ม รปภ สานนท์ (`Cb48b8d0469f371b84292eed2b1320959`) — Pass approved — **Secrets: `LINE_CHANNEL_TOKEN_SECURITY` + `LINE_GROUP_ID_SECURITY`**

> **🔒 กฎสำคัญ: ห้ามแก้ไข LINE notification ของ System 1-3 (ผลิต/คลัง/PM)**
> ระบบแจ้งเตือน System 1-3 → กลุ่มผลิต (`LINE_GROUP_ID`) — **สมบูรณ์แล้ว ห้ามยุ่ง**

---

## ⚠️ 0A. วิธีทำงานร่วมกันข้ามแชต — เอกสารแยกต่อระบบ (มีผลตั้งแต่ 15 ก.ย. 69)
> **เปิดอ่านก่อนแก้ไขงานครั้งถัดไป**

**ปัญหาที่พบ:** หลายแชตแก้ไข `CLAUDE.md` พร้อมกัน ทำให้ข้อมูลของแชตอื่นถูกเขียนทับหายไปหลายครั้ง (กระทบทั้งงานของ System 1 และ System 6)

**ทางแก้ — ย้าย "รายละเอียดสถานะ/ฟีเจอร์" และ "Changelog" ของแต่ละระบบ ออกจาก `CLAUDE.md` ไปไว้ในไฟล์ `.md` ของระบบตัวเอง:**

| ระบบ | ไฟล์เอกสาร | สถานะการย้าย |
|------|-----------|-------------|
| System 1 — Production | `PRODUCTION.md` | ✅ ตัวอย่างที่ทำเสร็จแล้ว (Changelog อาจยังไม่ครบ 100% — ตรวจสอบก่อนใช้อ้างอิง) |
| System 2 — Inventory | `INVENTORY.md` | ✅ ย้ายแล้ว (2026-09-15) |
| System 3 — PM | `PM.md` | ✅ ย้ายแล้ว (Section 0 เหลือ pointer แล้ว) |
| System 4 — Checkin/HR | `CHECKIN.md` | ⏳ ยังไม่สร้าง |
| System 5 — Meeting | `MEETING.md` | ⏳ ยังไม่สร้าง |
| System 6 — Leave | `LEAVE.md` | ✅ ย้ายแล้ว (2026-09-15) |
| Portal | `PORTAL.md` | ⏳ ยังไม่สร้าง |

**กฎหลังจากนี้ใน `CLAUDE.md`:**
- **Section 0 (สถานะระบบ):** ให้เหลือแค่บรรทัดสั้นๆ ชี้ไปไฟล์ของระบบตัวเอง ไม่ต้องพิมพ์ฟีเจอร์ยาวซ้ำอีก
- **Section 7 (Changelog):** ใช้เฉพาะเรื่องที่กระทบหลายระบบพร้อมกันเท่านั้น (เช่น แก้ `sw.js`, ย้ายไดรฟ์) — Changelog เฉพาะของแต่ละระบบให้บันทึกในไฟล์ `.md` ของระบบนั้นแทน

---

## ⚠️ 0B. ไฟล์ที่กระทบหลายระบบ (Shared Files — ระวังก่อนแก้)

> **กฎ:** ไฟล์ด้านล่างนี้ถ้าแก้แล้วกระทบทุกระบบ ต้องแจ้งในแชตด้วยว่าแก้อะไร

| ไฟล์ | กระทบระบบ | เนื้อหาสำคัญ |
|------|----------|-------------|
| `sw.js` | ทุกระบบ (PWA) | Service Worker cache — ถ้าแก้ต้องเพิ่ม version `CACHE_NAME` |
| `manifest-*.json` | แต่ละระบบ | PWA manifest — path ต้องขึ้นต้นด้วย `/sanon-webapp/` |
| `line_webhook.sql` | System 1,2,3 | Trigger ส่ง LINE — ต้องมี Authorization header ทุกครั้ง |
| `inventory_alert.sql` | System 2 | Trigger + cron สต็อกต่ำ |

---

## ⚠️ 0C. Checklist หลัง Upload GitHub ทุกครั้ง

หลังอัปไฟล์ขึ้น GitHub ให้ตรวจสอบดังนี้:

- [ ] เปิด GitHub Pages URL ได้ปกติ (`https://sanon-saraburi.github.io/sanon-webapp/`)
- [ ] Login เข้าระบบได้ (ทดสอบ System ที่แก้)
- [ ] SSO ข้ามระบบยังทำงาน (login ที่นึง → เปิดอีกระบบไม่ต้อง login ซ้ำ)
- [ ] LINE แจ้งเตือนยังทำงาน (ทดสอบบันทึกยอดผลิต/เบิกของ)
- [ ] ถ้าแก้ `sw.js` → เพิ่ม version number ใน `CACHE_NAME`

---

## ⚠️ 0D. กฎการแก้ไขข้ามแชต

1. **ก่อนแก้ไข** — อ่าน Section 0 นี้ก่อนเสมอ และอ่าน **`TECHSTACK.md`** ถ้าเปิดแชตใหม่
2. **หลังแก้ไขสำเร็จ** — อัปเดต System Status Board (Section 0) ทันที
3. **ถ้าพบว่าระบบอื่นพัง** — บันทึกใน "ปัญหาที่รู้อยู่" ก่อน แล้วค่อยแก้ทีละอย่าง
4. **ไฟล์ที่อัปขึ้น GitHub แล้ว** — ต้องเป็น version ล่าสุดจาก `G:\เขียนเว็บ+Ai\เขียนเว็บสานนท์` เท่านั้น ห้ามอัปไฟล์เก่า

> **📖 Tech Stack ทั้งหมด อ่านได้ที่ `TECHSTACK.md`** — Library, Backend, DB schema, กฎสำคัญ, LINE Notification

---

## ⚠️ 0E. โฟลเดอร์ GitHub/ — Staging Area สำหรับ Upload

> **โฟลเดอร์:** `G:\เขียนเว็บ+Ai\เขียนเว็บสานนท์\GitHub\`
> **กฎ:** ทุกครั้งที่มีการแก้ไขหรือทำระบบเพิ่ม ให้ copy ไฟล์ที่แก้ไปไว้ใน `GitHub/` ก่อนเสมอ
> แล้วค่อย upload ทุกอย่างใน `GitHub/` ขึ้น GitHub — ป้องกันอัปไฟล์ไม่ครบ

### ไฟล์ที่ต้องอยู่ใน GitHub/ เสมอ (อัปเดตล่าสุด: 2026-08-15)

| ไฟล์/โฟลเดอร์ | ระบบ | อัปเดตล่าสุด |
|--------------|------|------------|
| `portal.html` | Portal | 2026-08-15 (เพิ่ม System 6 ขอลา — openAll=true) |
| `index.html` | System 1 | 2026-09-08 (Daily Analysis Block + รายวัน auto-detect + material_types is_feed/is_product + groundwater recorder + drone sort) |
| `production_mobile_schema.sql` | System 1 | 2026-09-02 (ตาราง production_mobile — UH312/QA451 columns, RLS) |
| `meeting.html` | System 5 | 2026-08-14 (No-login public booking — Admin login มุมขวาบน, auto confirmed, Conflict check, Admin sections hidden จาก public) |
| `leave.html` | System 6 | 2026-09-11 (Realtime แจ้งเตือนหัวหน้า/Admin เมื่อมีคำขอใหม่ + เพิ่ม PWA manifest/icon สำหรับ Add to Home Screen) |
| `manifest-leave.json` | System 6 | 2026-09-11 (ใหม่ — PWA manifest สำหรับ leave.html ใช้ icon-192/512.png เดิม) |
| `leave_schema.sql` | System 6 | 2026-08-15 (leave_types, leave_requests, leave_balances, leave_dept_supervisors, leave_settings + RLS) |
| `leave_schema_v2_patch.sql` | System 6 | 2026-08-15 (leave_holidays + วันหยุดไทย 2025–2026) |
| `inventory.html` | System 2 | 2026-08-05 (Dashboard redesign + LINE วันที่เบิก + แก้ราคาสารตกตะกอน) |
| `pm.html` | System 3 | 2026-08-05 (dropdown PM เรียงตามสถานะ + คอลัมน์วันที่ PM ล่าสุด) |
| `checkin.html` | System 4 | 2026-09-15 (เพิ่ม "สรุปโอที" เชื่อมข้อมูลจาก ot_requests ของ System 6 + เปลี่ยนชื่อหมวด "ข้อมูลการลา-โอที") |
| `line-notify_index.txt` | Edge Function | 2026-08-22 (URI button footer แทน postback, cornerRadius fix, AbortController timeout 10s, postback token fix) |
| `CLAUDE.md` | ทุกระบบ | 2026-08-22 |
| `TECHSTACK.md` | ทุกระบบ | 2026-08-02 (Tech Stack ครบทุก Library/DB/กฎ — อ่านก่อนเปิดแชตใหม่) |
| `PRODUCTION.md` | System 1 | 2026-07-31 |
| `INVENTORY.md` | System 2 | 2026-07-21 |
| `PM.md` | System 3 | 2026-09-15 (ย้าย Changelog 2026-08-05 + สถานะฟีเจอร์เข้ามารวมที่นี่ ตามนโยบายแยกไฟล์) |
| `sw.js` | PWA | 2026-08-01 (v3 — เพิ่ม portal.html + manifest-portal.json) |
| `manifest-production.json` | PWA | 2026-07-31 (icon-192/512.png) |
| `manifest-inventory.json` | PWA | 2026-07-31 (icon-192/512.png) |
| `manifest-pm.json` | PWA | 2026-07-31 (icon-192/512.png) |
| `manifest-checkin.json` | PWA | 2026-07-31 (icon-192/512.png) |
| `icon-192.png` | PWA | 2026-07-31 (square, navy bg) |
| `icon-512.png` | PWA | 2026-07-31 (square, navy bg) |
| `excavator.png` | — | ⚠️ ไม่ใช้แล้ว (อยู่ใน GitHub/ แต่ไม่ได้ reference ใน sw.js หรือ HTML) |
| `manifest-portal.json` | Portal | 2026-08-01 (PWA manifest สำหรับ portal.html — ใหม่) |
| `manifest-production.json` | PWA | 2026-07-31 (icon-192/512.png) |
| `manifest-inventory.json` | PWA | 2026-07-31 (icon-192/512.png) |
| `manifest-pm.json` | PWA | 2026-07-31 (icon-192/512.png) |
| `manifest-checkin.json` | PWA | 2026-07-31 (icon-192/512.png) |
| `icon-192.png` | PWA | 2026-07-31 (square, navy bg) |
| `icon-512.png` | PWA | 2026-07-31 (square, navy bg) |
| `excavator.png` | — | ⚠️ ไม่ใช้แล้ว (อยู่ใน GitHub/ แต่ไม่ได้ reference ใน sw.js หรือ HTML) |
| `logo.png` | ทุกระบบ | เดิม |

### Workflow ทุกครั้งหลังแก้ไข

```
1. แก้ไขไฟล์ในโฟลเดอร์หลัก (G:\เขียนเว็บ+Ai\เขียนเว็บสานนท์\)
2. Copy ไฟล์ที่แก้ไปไว้ใน GitHub\
3. อัปเดต CLAUDE.md Section 0 (สถานะ) + Section 0E (วันที่อัปเดต)
4. Copy CLAUDE.md อัปเดตไปใน GitHub\ ด้วย
5. Upload ทุกอย่างใน GitHub\ ขึ้น GitHub
6. ตรวจสอบตาม Checklist 0C
```

### กฎเจ้าของไฟล์ (ห้ามข้าม)

| แชต | Copy ได้เฉพาะ | ห้าม copy |
|-----|-------------|---------|
| System 1 | `index.html` + `CLAUDE.md` + `PRODUCTION.md` | ไฟล์ระบบอื่น |
| System 2 | `inventory.html` + `CLAUDE.md` + `INVENTORY.md` | ไฟล์ระบบอื่น |
| System 3 | `pm.html` + `CLAUDE.md` + `PM.md` | ไฟล์ระบบอื่น |
| System 4 | `checkin.html` + `CLAUDE.md` | ไฟล์ระบบอื่น |
| ทุกแชต | ห้าม copy `sw.js`, `manifest-*.json`, `icons/` | ยกเว้นถูกสั่งให้แก้ PWA โดยเฉพาะ |

---

## ⚠️ 0F. ขอบเขตแชตที่คุณใหญ่กำหนดไว้ (Active Chat Scopes)

> **กฎ:** ส่วนนี้เป็น**ตาราง** — แต่ละแชตเพิ่ม/แก้ไข **เฉพาะแถวของตัวเอง** เท่านั้น ห้ามลบหรือแก้แถวของแชตอื่น
> (⚠️ พบว่าเดิมส่วนนี้เป็นข้อความเดียว ทำให้แชต System 2 เขียนทับขอบเขตของแชต System 3 ไปเมื่อ 2026-09-10 — แก้เป็นตารางเมื่อ 2026-09-15 เพื่อกันเขียนทับซ้ำ ถ้าคุณใหญ่มีขอบเขตอื่นที่เคยแจ้งไว้แล้วหายไป กรุณาแจ้งอีกครั้ง)

| แชต/ระบบ | ขอบเขตที่แก้ไขได้ | กำหนดเมื่อ | หมายเหตุ |
|---|---|---|---|
| System 4+6 — Checkin/HR + Leave | `checkin.html`, `leave.html`, `LEAVE.md`, `checkin_system/leave_schema*.sql`, `leave_schema_v6_patch.sql`, `checkin_system/pass_schema*.sql`, `checkin_system/pass_schema_time_levels_patch.sql`, `checkin_system/ot_schema.sql`, `line-notify_index.txt` (Edge Function), และ `CLAUDE.md` เฉพาะส่วน System 4/6 | 2026-09-15 (แก้ไขจากเดิม) | **แก้ไขขอบเขต:** เดิมแถวนี้ระบุเป็น "System 2 — Inventory" ซึ่งไม่ถูกต้อง — คุณใหญ่แจ้งว่า Inventory ไม่ได้เชื่อมระบบดึงข้อมูลกับงานที่แชตนี้ทำเลย จึงไม่จำเป็นต้องแก้ไข Inventory — **ขอบเขตที่ถูกต้องคือ:** `checkin.html` (System 4 — HR/บัตรตอก, สรุปโอที) + `leave.html` (System 6 — ลา/ออกนอกบริษัท/โอที) และไฟล์ที่เกี่ยวข้องโดยตรง — **หมายเหตุ:** แชตนี้จะไม่แก้ไข `inventory.html` หรือไฟล์ Inventory อื่นใดอีกต่อไป |
| System 3 — PM | `pm.html`, `pm_schema.sql`, `pm_repair_schema.sql`, `pm_meter_schema.sql`, `pm_sync.sql`, `pm_cron.sql`, `PM.md`, และ `CLAUDE.md` เฉพาะส่วน System 3 | 2026-09-10 | ขอบเขตงาน: บันทึกมิเตอร์, ซ่อมบำรุง, OEE, คลังอะไหล่ — ถ้าจะแก้ระบบอื่นต้องถามคุณใหญ่ก่อนทุกครั้ง |

> ทุกแชตในตารางนี้: ถ้าจะแก้ไขไฟล์นอกขอบเขตของตัวเอง (รวมไฟล์ shared เช่น `sw.js`/`manifest-*.json`) **ต้องถามคุณใหญ่ก่อนทุกครั้ง**

---

## 1. ข้อมูลบริษัทและบทบาทงาน

- **บริษัท:** สานนท์ จำกัด (Sanon Co., Ltd.)
- **ประเภทธุรกิจ:** โรงโมหินและโรงคัดแยกหินอุตสาหกรรม จ.สระบุรี
- **มาตรฐาน:** Green Mine / Green Industry Level 3
- **ผู้ดูแลระบบ:** คุณใหญ่ (YAi) — วิศวกรการผลิตและหัวหน้าทีม
- **ความรับผิดชอบ:** เก็บและวิเคราะห์ข้อมูลการผลิต, ระบบบริหารคลังสินค้า, รายงานเชิงปฏิบัติการ

---

## 2. ภาพรวมระบบทั้งหมด (Multi-System)

โปรเจกต์นี้มี **3 ระบบ** ใน folder เดียวกัน (`G:\เขียนเว็บ+Ai\เขียนเว็บสานนท์`) แชร์ **Supabase project เดิม** และ **app_users + RBAC เดิม**

| ระบบ | ไฟล์ | สถานะ | หมายเหตุ |
|------|------|--------|---------|
| System 1 — Production | `index.html` | ✅ ใช้งานจริง | ระบบผลิต CDE/Propel/Sanon1/Sanon2 |
| System 2 — Inventory | `inventory.html` | 🚧 กำลังสร้าง | ระบบคลังวัสดุ/อะไหล่ |
| System 3 — Maintenance PM | `pm.html` | 🚧 สร้างแล้ว v1 | ระบบ PM Hour-based เครื่องจักร |
| System 4 — Checkin | `checkin.html` | 🚧 กำลังสร้าง | ระบบเช็คอินพักเที่ยงพนักงาน |

### กฎสำคัญของ Multi-System
- **Supabase project เดิมทั้งหมด** — URL: `https://pcmpwkcmvsxrvbximjgf.supabase.co`
- **Supabase Anon Key:** `sb_publishable_RckQgaumQeIgaCICUc_6ZQ_T42qI2Nq`
- **app_users table ร่วมกัน** — login ครั้งเดียวใช้ได้ทุกระบบ (System 1/2/3 เท่านั้น)
- **checkin_users แยกต่างหาก** — System 4 ใช้ตารางแยก, SESSION_KEY = `_sn_ck2_sess`
- **System 6 (Leave) ใช้ checkin_users** — Supervisor/Admin login ด้วย checkin_users, Employee quick access ไม่ต้องใส่รหัสผ่าน, SESSION_KEY = `_sn_lv_sess`
- **ไฟล์ล่าสุดที่แก้ไข:** `checkin.html` — ชื่อระบบ = "ระบบบันทึกเวลาพักพนักงาน"
- **RBAC ร่วมกัน** — Admin กำหนดสิทธิ์แต่ละระบบผ่าน System 1
- **แยกไฟล์ HTML** — ไม่ให้ระบบหนึ่งกระทบอีกระบบ
- **Menu prefix แยกกัน**: `dash-` / `manage-` (System 1), `inv-` (System 2), `pm-` (System 3), `ck-` (System 4)

---

## 2B. ระบบ System 2 & 3 (แยกไฟล์)

> รายละเอียดแต่ละระบบบันทึกแยกไว้คนละไฟล์

| ระบบ | ไฟล์อ้างอิง |
|------|------------|
| System 2 — คลังวัสดุ | **`INVENTORY.md`** |
| System 3 — PM เครื่องจักร | `PM.md` (ยังไม่ได้สร้าง — ดู changelog 2026-07-16) |

---

## 3. ข้อมูล Web App — System 1 (index.html)

### Stack & Dependencies
- **Backend:** Supabase (PostgreSQL) — URL: `https://pcmpwkcmvsxrvbximjgf.supabase.co`
- **Frontend:** Tailwind CSS (CDN), Lucide Icons, Chart.js, SheetJS (xlsx), PptxGenJS
- **Font:** Kanit (Google Fonts)
- **Pattern:** Single-file SPA (9,198 บรรทัด), ไม่ใช้ Framework

### Architecture — 30 Sections ใน index.html

| Section | เนื้อหา |
|---------|---------|
| 0 | Config & Supabase Client |
| 1 | Global State (in-memory, ห้ามใช้ localStorage) |
| 2 | Menu Definitions (DASHBOARD_MENUS, MANAGE_MENUS) |
| 2B | Permission Templates (PERM_TEMPLATES) |
| 3 | RBAC — getAllowedMenus() |
| 4 | Utils (fmtNum, fmtDate, escapeHtml, normalizeFactoryName, ฯลฯ) |
| 5 | Toast Notification |
| 6 | Modal Dialog (reusable) |
| 7 | Auth — doLogin / doLogout (query ตรง app_users, ไม่ใช้ Supabase Auth) |
| 7B | Register (status เริ่มต้น pending) |
| 7C | Session Timeout (2 ชั่วโมง, ยกเว้น admin) |
| 8 | Pending Approval Count (รวม 4 ตาราง production_*) |
| 9 | Router — navigateTo() |
| 10 | Landing Page (guest) |
| 11 | App Shell (Sidebar desktop / Bottom-nav mobile) |
| 12 | Dashboard Shared Helpers |
| 13 | Dashboard CDE / Propel |
| 14 | Dashboard Sanon1 / Sanon2 |
| 15 | Dashboard สต็อคหินบินโดรน |
| 16 | Dashboard ยอดขาย |
| 17 | Dashboard รถตักไฟฟ้า |
| 18 | Dashboard น้ำบาดาล |
| 18B | Dashboard ค่าไฟฟ้า 4 โรงงาน (electricity_costs) |
| 20 | Manage — ประเภทวัสดุ (material_types) |
| 21 | Manage — โรงงาน (factories) |
| 21B | Manage — เครื่องจักร (machines) |
| 21C | Manage — แหล่งน้ำ (water_sources) |
| 22 | Manage — จัดการผู้ใช้ (app_users, admin only) |
| 23 | Manage — สต็อคหินโดรน (drone_stock) |
| 24 | Manage — ยอดผลิต CDE/Propel/Sanon1/Sanon2 (component ใช้ร่วมกัน) |
| 25 | Manage — รถตักไฟฟ้า (electric_loader) |
| 26 | Manage — ยอดขาย (sales, เพิ่มหลายแถวต่อครั้ง) |
| 26B | Manage — น้ำบาดาล (groundwater_usage) |
| 26C | Manage — ค่าไฟฟ้า (electricity_costs, upsert รายเดือน) |
| 27 | Manage — รออนุมัติ (production_* pending + approval_log) |
| 28 | Manage — ตั้งค่าระบบ (admin only) |
| 28B | Roles Management (admin) |
| 29 | Permission Matrix (admin only) |
| 29* | Manage — รายงาน (multi-table, DnD columns, export CSV/Excel/Print) |
| 30 | Executive Report — PowerPoint Generator |
| Bootstrap | App Bootstrap (Section 19) |

### เมนูหลัก
**Dashboard (9 เมนู):**
`dash-cde`, `dash-propel`, `dash-sanon1`, `dash-sanon2`, `dash-drone`, `dash-sales`, `dash-loader`, `dash-water`, `dash-electricity`

**จัดการข้อมูล (17 เมนู + approval scope):**
`manage-approvals`, `manage-materials`, `manage-reports`, `manage-users`, `manage-factories`, `manage-machines`, `manage-water-sources`, `manage-drone-stock`, `manage-prod-cde`, `manage-prod-propel`, `manage-prod-sanon1`, `manage-prod-sanon2`, `manage-electric-loader`, `manage-sales`, `manage-groundwater`, `manage-electricity`, `manage-settings`

### RBAC System
- `admin` → สิทธิ์เต็มทุกเมนู (hardcode)
- Role อื่น → สิทธิ์มาจาก `role_permissions` table + `user_permissions` table (override รายบุคคล)
- Permission Templates (PERM_TEMPLATES): Manager CDE/Sanon, Supervisor, Operator, Clerk ฯลฯ

### Global State Variables
```js
currentUser, currentPage, pendingApprovalCount,
isMobileSheetOpen, isManageSheetOpen,
chartRegistry, sessionTimerInterval, sessionSecondsLeft,
sessionWarnShown, approvalCountInterval
```

### กฎสำคัญของโค้ด
- **ห้ามใช้ localStorage/sessionStorage** สำหรับข้อมูล (ใช้ in-memory เท่านั้น)
- Auth ใช้ query ตรงจาก `app_users` table (ไม่ใช้ Supabase Auth)
- Session Timeout: 2 ชั่วโมง (ยกเว้น admin)
- Factory name normalize: `Sanon 1` → `Sanon1`, `Sanon 2` → `Sanon2`

---

## 3. ข้อมูลการผลิตเครื่องล้างหิน CDE

- **ช่วงข้อมูล:** ปี 2022–2026
- **Throughput เฉลี่ย:** 82–86 ตัน/ชั่วโมง
- **สัดส่วนผลิตภัณฑ์หลัก:** หิน 3/4 ประมาณ 50%
- **รูปแบบการเสียที่พบบ่อย:** ใบตะแกรงร้าว
- **ช่องว่าง KPI:** มีความแตกต่างระหว่างเป้าหมายกับผลจริง (ต้องวิเคราะห์รายปี)

---

## 4. KPI ที่ติดตาม

- OEE (Overall Equipment Effectiveness)
- Downtime (ประเภทและสาเหตุ)
- Production Output vs. Target
- Defect Rate

**กลุ่มผู้รับรายงาน:**
- ผู้บริหาร — ภาพรวม KPI
- หัวหน้างาน — รายละเอียดการผลิต
- ทีมซ่อมบำรุง — Maintenance Log, Root Cause

---

## 5. ไฟล์สำคัญในโปรเจกต์

| ไฟล์ | รายละเอียด |
|------|-----------|
| `index.html` | Web App System 1 — Production (Single-file SPA) |
| `inventory.html` | Web App System 2 — คลังวัสดุ (~3,900+ บรรทัด) |
| `pm.html` | Web App System 3 — PM เครื่องจักร (Hour-based PM) |
| `pm_schema.sql` | โครงสร้าง DB System 3 — ต้องรันใน Supabase ก่อนใช้งาน |
| `schema.sql` | โครงสร้าง DB System 1 |
| `inventory_schema.sql` | โครงสร้าง DB System 2 (inventory) |
| `lot_tracking.sql` | FIFO lot tracking — ต้องรันใน Supabase ก่อนใช้งาน |
| `fix_stock.sql` | แก้ยอดสต็อกที่ผิดจาก migration |
| `electricity_schema.sql` | โครงสร้าง DB ค่าไฟฟ้า (electricity_costs) — ต้องรันใน Supabase ก่อนใช้ dash-electricity |
| `production_cde_with_flowmeter.csv` | ข้อมูลการผลิต CDE |
| `production_propel_with_flowmeter.csv` | ข้อมูลการผลิต Propel |
| `logo.png` / `logo2.png` | โลโก้บริษัทพื้นหลังโปร่งใส |
| `generate_report.py` | Script สร้างรายงาน |

---

## 7. ประวัติการแก้ไข (Changelog)

> **📌 System 6 — Leave:** Changelog/รายละเอียดฟีเจอร์ย้ายไป **`LEAVE.md`** แล้ว (2026-09-15) — Section นี้เหลือเฉพาะเรื่องที่กระทบหลายระบบพร้อมกัน

### 2026-09-19 — checkin.html (System 4): เพิ่มเมนูใหม่ "สรุปออกนอกบริษัท" ให้ครบทั้ง 3 หัวข้อ

**คำขอ:** คุณใหญ่ถามว่าหมวด "ข้อมูลการลา-โอที" สรุปครบทุกหัวข้อ (ลา/ออกนอกบริษัท/โอที) เท่ากันหมดหรือไม่ — ตรวจสอบพบว่า "ออกนอกบริษัท (Pass)" มีแค่ตัวเลขจำนวนครั้งปนอยู่ในตาราง "สรุปการลาประจำเดือน" เท่านั้น ไม่มีหน้าสรุป/ประวัติ/ดูรายละเอียดรายบุคคลแยกเฉพาะเหมือนโอที — คุณใหญ่ยืนยันให้เพิ่มให้ครบ ("ขอรายละเอียดครบเหมือนโอที")

**`checkin.html` — การเปลี่ยนแปลง:**
1. เพิ่มเมนูใหม่ **"🚪 สรุปออกนอกบริษัท"** (`ck-pass-summary`) ในหมวด "ข้อมูลการลา-โอที" (วางไว้ระหว่าง "ประวัติการลาทั้งหมด" กับ "สรุปโอที") — เพิ่มใน `CK_PERM_MENUS`, `CK_ROLE_PERMS` (supervisor+admin), `PAGE_TITLES`, router (`nav()`)
2. เพิ่มฟังก์ชัน `renderPassSummary()` — query `pass_requests` ข้ามระบบจาก System 6 (leave.html) โครงสร้างเดียวกับ `renderOtSummary()` ทุกประการ: filter เดือน/แผนก, กลุ่มตามแผนก/พนักงาน, นับจำนวนครั้งที่อนุมัติแล้ว (`approved`/`out`/`returned`) + รวมชั่วโมง (คำนวณจาก `out_time`→`expected_return` ผ่าน `_passMinutesBetween()`) + จำนวนที่รออนุมัติ
3. เพิ่ม `_showPassEmployeeDetail(eid, ename)` — คลิกชื่อพนักงานเปิดป๊อปอัพรายละเอียดรายวัน: วันที่, เวลาออก→กลับ (คาด) พร้อมเวลาจริงถ้ามี (`actual_out`/`actual_return`), ชั่วโมง, สถานะ (อนุมัติ/กำลังออก/กลับแล้ว/รออนุมัติ/ปฏิเสธ), ผู้อนุมัติ+วันที่อนุมัติ (หรือเหตุผลปฏิเสธ), เหตุผล+หมายเหตุ — รูปแบบเดียวกับ `_showOtEmployeeDetail()`
4. เพิ่ม `exportPassSummaryCSV()` ปุ่ม Export CSV ในหน้าเดียวกัน

**ตอนนี้ทั้ง 3 หัวข้อ (ลา/ออกนอกบริษัท/โอที) มีความครบถ้วนเท่ากันแล้ว:** สรุปรายเดือน + คลิกดูรายละเอียดรายบุคคล + Export CSV — ยกเว้น "ประวัติการลาทั้งหมด" ที่ยังเป็นแบบตารางรวมทุกคน (ไม่ใช่แยกตามหัวข้อ) ซึ่งเป็นดีไซน์เดิมที่ใช้งานได้ดีอยู่แล้วสำหรับข้อมูลลา

**ตรวจสอบแล้ว:** extract inline `<script>` แล้วรัน `node --check` ผ่าน

**ไฟล์ที่แก้ไข:** `checkin.html`, `CLAUDE.md`
**Copy ไป GitHub/:** `checkin.html` ✅

---

### 2026-09-19 — checkin.html (System 4): แก้บั๊ก `esc()` + เพิ่มดูรายละเอียดรายบุคคลใน "สรุปการลา" + "ประวัติการลา"

**คำขอ:** คุณใหญ่ขอให้แก้บั๊ก `esc()` ที่พบไว้ (จากรอบก่อนหน้า) และย้ำว่าการแก้ไข "ไม่ใช่แค่ในส่วนของโอทีอย่างเดียว" — ให้ครอบคลุม "สรุปการลา" และ "ประวัติการลา" ด้วย

**`checkin.html` — การแก้ไข:**
1. **แก้บั๊กจริง:** เปลี่ยน `esc(...)` ทั้ง 4 จุด (การ์ดอนุมัติออกนอกบริษัทฝั่งยาม — ชื่อพนักงาน/แผนก/เหตุผล/หมายเหตุ) เป็น `escHtml(...)` ซึ่งเป็นฟังก์ชันจริงที่มีอยู่ในไฟล์ — แก้ที่ต้นเหตุแทนการเลี่ยงในโค้ดใหม่เหมือนรอบก่อน
2. **ขยาย "ดูรายละเอียดรายบุคคล" ให้ครบทั้ง 3 หน้าในหมวด "ข้อมูลการลา-โอที"** (เดิมทำแค่หน้าสรุปโอที):
   - **สรุปการลาประจำเดือน** (`renderLeaveSummary`) — ชื่อพนักงานคลิกได้ → เรียก `_goToEmployeeLeaveHistory(eid, ename)` พาไปหน้า "ประวัติการลาทั้งหมด" พร้อมกรองเฉพาะพนักงานคนนั้นทันที (แม่นยำกว่าการค้นหาด้วยชื่อ เพราะกรองด้วย `employee_id`)
   - **ประวัติการลาทั้งหมด** (`renderLeaveHistory`) — เพิ่มตัวแปร `_lhEmpId`/`_lhEmpName` สำหรับกรองเฉพาะพนักงาน (ใช้ `.eq('employee_id', _lhEmpId)` แทนการค้นหาด้วยชื่อเมื่อมีการกรองแบบนี้) พร้อมแถบแบนเนอร์แจ้งว่ากำลังกรองอยู่ + ปุ่ม "✕ ล้างตัวกรองพนักงาน" — และทำให้ชื่อพนักงานในตารางเองก็คลิกเพื่อกรองเฉพาะคนนั้นได้เช่นกัน (ไม่ต้องย้อนไปคลิกจากหน้าสรุปการลา)
   - หน้า **สรุปโอที** ยังคงพฤติกรรมเดิมจากรอบก่อนหน้า (คลิกชื่อ → ป๊อปอัพรายละเอียดในหน้าเดียวกัน — ต่างจาก 2 หน้าข้างต้นที่พาไปหน้าประวัติแทน เนื่องจาก "ประวัติการลาทั้งหมด" เป็นตารางที่มีรายละเอียดครบต่อแถวอยู่แล้ว การนำทางไปใช้ตัวกรองที่มีอยู่จึงคุ้มค่ากว่าการสร้างป๊อปอัพซ้ำซ้อน)

**ตรวจสอบแล้ว:** extract inline `<script>` แล้วรัน `node --check` ผ่าน

**ไฟล์ที่แก้ไข:** `checkin.html`, `CLAUDE.md`
**Copy ไป GitHub/:** `checkin.html` ✅

---

### 2026-09-19 — checkin.html (System 4): เพิ่มรายละเอียดโอทีรายบุคคล (คลิกชื่อพนักงานในหน้า "สรุปโอที")

**คำขอ:** คุณใหญ่ขอให้หน้า "สรุปโอที" (`ck-ot-summary`) คลิกที่ชื่อพนักงานแล้วดูรายละเอียดได้ (ทำโอทีวันไหน เวลาไหน กี่ชั่วโมง ใครอนุมัติ) เพื่อให้ตรวจเช็คข้อมูลง่ายขึ้น

**`checkin.html` — การเปลี่ยนแปลง:**
1. ชื่อพนักงานในตาราง `renderOtSummary()` เปลี่ยนเป็นลิงก์คลิกได้ (ขีดเส้นใต้จุด, สีเขียว) — คลิกแล้วเรียก `_showOtEmployeeDetail(eid, ename)`
2. เพิ่มฟังก์ชันใหม่ `_showOtEmployeeDetail()` — query `ot_requests` เฉพาะพนักงานคนนั้นในช่วงเดือน/ปีที่กำลังดูอยู่ (ตาม filter ของหน้าสรุปโอที) แสดงเป็น modal ป๊อปอัพ: วันที่, เวลาเริ่ม-สิ้นสุด (พร้อมป้าย "วันหยุด" ถ้ามี), ชั่วโมง, สถานะ (อนุมัติ/รออนุมัติ/ปฏิเสธ), ผู้อนุมัติ+วันที่อนุมัติ (หรือเหตุผลที่ปฏิเสธ), และเหตุผล/งานที่ทำ OT — พร้อมสรุปยอดรวมชั่วโมงที่อนุมัติแล้วด้านบน
3. เพิ่มข้อความคำแนะนำ "คลิกที่ชื่อพนักงานเพื่อดูรายละเอียด" ในแถบข้อมูลด้านบนตาราง

**พบและแก้บั๊กที่มีอยู่ก่อนแล้วระหว่างทาง:** โค้ดใหม่ต้องใช้ฟังก์ชัน escape HTML แต่พบว่าจุดอื่นในไฟล์ (การ์ดอนุมัติออกนอกบริษัท) เรียกใช้ `esc()` ซึ่ง**ไม่มีอยู่จริงในไฟล์** (ฟังก์ชันจริงชื่อ `escHtml()`) — เป็นบั๊กเดิมที่มีอยู่ก่อนแล้ว ไม่เกี่ยวกับงานนี้ จึงไม่ได้แก้จุดเดิม แก้เฉพาะโค้ดใหม่ที่เพิ่มให้เรียก `escHtml()` ให้ถูกต้อง — **หมายเหตุถึงแชตอื่นที่ดูแล `checkin.html`:** จุดเดิมที่เรียก `esc()` (การ์ดอนุมัติออกนอกบริษัทในหน้า guard) ยังเป็นบั๊กค้างอยู่ อาจต้องแก้ในรอบถัดไป

**ตรวจสอบแล้ว:** extract inline `<script>` แล้วรัน `node --check` ผ่าน

**ไฟล์ที่แก้ไข:** `checkin.html`, `CLAUDE.md`
**Copy ไป GitHub/:** `checkin.html` ✅

---

### 2026-09-15 — checkin.html (System 4): เพิ่ม "สรุปโอที" เชื่อมข้อมูลจาก System 6 (leave.html) + เปลี่ยนชื่อหมวด

**คำขอ:** คุณใหญ่ขอให้เชื่อมระบบสรุปโอทีเข้ากับระบบ HR (`checkin.html`) โดยให้อยู่ในหมวด "ข้อมูลการลา" พร้อมเปลี่ยนชื่อหมวดใหม่ — **นอกขอบเขตเดิมของแชตนี้** (เดิมมีแค่ System 2 + ข้อยกเว้น System 6) จึงถาม + บันทึกข้อยกเว้นใน Section 0F ก่อนแก้ (คุณใหญ่ยืนยันผ่าน AskUserQuestion)

**`checkin.html` — การเปลี่ยนแปลง:**
1. เปลี่ยนชื่อหมวด sidebar "ข้อมูลการลา" → **"ข้อมูลการลา-โอที"** (ทั้ง sidebar label และ `group` ใน `CK_PERM_MENUS` ที่ใช้สร้างหมวดใน Permission Matrix หน้าจัดการผู้ใช้ด้วย — เปลี่ยนจุดเดียวมีผลทั้งสองที่)
2. เพิ่มเมนูใหม่ **"⏱️ สรุปโอที"** (`ck-ot-summary`) ในหมวดเดียวกัน — เพิ่มใน `CK_PERM_MENUS`, `CK_ROLE_PERMS` (supervisor+admin), `PAGE_TITLES`, router (`nav()`)
3. เพิ่มฟังก์ชัน `renderOtSummary()` + `exportOtSummaryCSV()` — query ตาราง **`ot_requests` ข้ามระบบจาก System 6 (leave.html)** โดยตรง (เหมือนที่ `renderLeaveSummary()` เดิม query `leave_requests`/`pass_requests` ข้ามระบบอยู่แล้ว) แสดงสรุปรายเดือน/รายแผนก/รายพนักงาน: จำนวนครั้งที่อนุมัติ, ชั่วโมงรวม (ใช้ `actual_hours` ถ้ามี ไม่งั้น fallback `estimated_hours`), จำนวนที่รออนุมัติ — มี filter เดือน/แผนก + ปุ่ม Export CSV (ตามแพทเทิร์นเดียวกับ "สรุปการลาประจำเดือน")

**ตรวจสอบแล้ว:** extract inline `<script>` แล้วรัน `node --check` ผ่าน

**ไฟล์ที่แก้ไข:** `checkin.html`, `CLAUDE.md`
**Copy ไป GitHub/:** `checkin.html` ✅

---

### 2026-09-08 — index.html: วิเคราะห์รายวัน + แก้ material_types + groundwater + drone sort

**`index.html` — การเปลี่ยนแปลง:**

**1. เพิ่ม Section 12B: Daily Analysis Block (ทุกโรงงาน CDE/Propel/Sanon1/Sanon2/Mobile Plant)**
- `renderDailyDetailBlock(type, targetThroughput, rows)` — ฟังก์ชันใหม่
- กราฟ Bar+Line Chart รายวัน: ยอดป้อน (bar, ฟ้า) + Throughput (line, เหลือง) + เส้น target (แดงประ ถ้ากำหนดไว้)
- ตารางรายวันครบ: วันที่, ยอดป้อน(ตัน), Runtime(ชม.), Throughput(ตัน/ชม.สี 🟢🟡🔴), product columns ตามโรงงาน, Breakdown — พร้อมแถว "รวม/เฉลี่ย"
- สรุป Breakdown: แสดงเฉพาะวันที่มี Breakdown (ซ่อนถ้าไม่มี)
- เพิ่ม `<div id="${type}-daily-table-block">` ใน HTML template ทั้ง CDE/Propel และ Sanon/Mobile
- เพิ่ม `daily-table-block` ใน error block list ทั้ง 2 load functions

**2. แก้ "รายวัน" mode — auto-detect วันล่าสุดที่มีข้อมูล**
- `attachRangeControlEvents`: กดปุ่ม "รายวัน" → set `rangeState._dayInitialized = false`
- `loadCdePropelData` + `loadSanonData`: ถ้า mode=day && `!_dayInitialized` → query วันล่าสุด → set `rangeState.date` + update date input DOM
- เดิม: แสดงวันนี้ (ไม่มีข้อมูล) → ใหม่: แสดงวันล่าสุดที่บันทึกไว้

**3. material_types — เพิ่ม is_feed_material + is_product**
- SQL: `ALTER TABLE material_types ADD COLUMN IF NOT EXISTS is_feed_material boolean DEFAULT false;`
- SQL: `ALTER TABLE material_types ADD COLUMN IF NOT EXISTS is_product boolean DEFAULT false;`
- หน้าจัดการวัสดุ: เพิ่ม checkbox "วัตถุดิบป้อน" และ "ผลผลิต" ในฟอร์ม
- ตารางรายการวัสดุ: เพิ่มคอลัมน์ ✓ วัตถุดิบป้อน / ✓ ผลผลิต
- Dropdown บันทึกยอดผลิต: กรองเฉพาะ `is_feed_material=true` + factory ที่ตรงกัน (ไม่ปน product อื่น)

**4. groundwater_usage — เพิ่มคอลัมน์ผู้บันทึก**
- SQL: `ALTER TABLE groundwater_usage ADD COLUMN IF NOT EXISTS recorder_name text;` (รันแล้ว ✅)
- ตาราง: เพิ่มคอลัมน์ "ผู้บันทึก" (colspan 7→8)
- INSERT payload: เพิ่ม `recorder_name: currentUser.full_name`

**5. Drone stock — factory button sort**
- เพิ่ม `_droneOrder = ['CDE','Propel','Sanon 1','Sanon 2','Mobile Plant']`
- sort ปุ่มกรองตามลำดับนี้ (ไม่ใช่ alphabetical)

**ไม่ต้องรัน SQL เพิ่ม** (ยกเว้น material_types columns ถ้ายังไม่ได้รัน)

**ไฟล์ที่แก้ไข:** `index.html`, `CLAUDE.md`
**Copy ไป GitHub/:** `index.html` ✅ | `CLAUDE.md` ✅

---

### 2026-09-04 — checkin.html + index.html: สานนท์ HR + ข้อมูลการลา

**`checkin.html` — การเปลี่ยนแปลง:**

**1. ชื่อ Sidebar เปลี่ยนจาก "สานนท์ — เช็คอิน" → "สานนท์ — HR"**

**2. Refresh ค้างหน้าเดิม:**
- `nav()` บันทึก page ปัจจุบันลง `sessionStorage._sn_ck_lastpage`
- `bootApp()` อ่านกลับมา → ถ้า refresh ไปหน้าเดิม, ถ้า login ใหม่ → `ck-guard`
- `doLogout()` ล้าง `_sn_ck_lastpage`

**3. พิมพ์ตามตัวกรอง:**
- `printAllCards()` อ่านค่า `emp-search` + `emp-dept-filter` แล้วกรอง `_empAll` ก่อนพิมพ์
- พิมพ์เฉพาะแผนกหรือชื่อที่กรองไว้

**4. หมวดเมนูใหม่ "ข้อมูลการลา" (เฉพาะ Supervisor + Admin):**
- `ck-leave-summary` — สรุปการลาประจำเดือน
  - Filter: เดือน/ปี, แผนก
  - ตารางรายแผนก: ป่วย/กิจ/พักร้อน/ออกนอก/อื่นๆ/Pass/รวมวัน ต่อคน
  - Export CSV
- `ck-leave-history` — ประวัติการลาทั้งหมด
  - Filter: แผนก, สถานะ, ค้นหาชื่อ
  - ตาราง: รหัส, ชื่อ, แผนก, ประเภทลา, วันที่, จำนวนวัน, เหตุผล, สถานะ, ผู้อนุมัติ
  - Export CSV
- ดึงจาก `leave_requests` + `pass_requests` — DB เดียวกับ leave.html

**5. ย้ายหมวด "ข้อมูลการลา" ขึ้นมาก่อนหมวด "ข้อมูล"**

**ไม่ต้องรัน SQL เพิ่ม** (ยกเว้น `ALTER TABLE checkin_users ADD COLUMN IF NOT EXISTS permissions text[];` ถ้ายังไม่ได้รัน)

---

**`index.html` — การเปลี่ยนแปลง:**

**1. System Switcher: "เช็คอิน" → "HR"** (Desktop sidebar + Mobile bottom sheet)

**2. การ์ด "จองห้อง" ซ่อนตามสิทธิ์:**
- แสดงเฉพาะ `currentUser.meeting_access === true` หรือ `role === 'admin'`
- Admin กำหนดสิทธิ์ผ่าน SQL: `UPDATE app_users SET meeting_access = true WHERE username = 'xxx';`

**ไฟล์ที่แก้ไข:** `checkin.html`, `index.html`, `CLAUDE.md`
**Copy ไป GitHub/:** `checkin.html` ✅ | `index.html` ✅ | `CLAUDE.md` ✅
**ยังไม่ได้ upload ขึ้น GitHub Pages**

---

### 2026-09-03 — index.html: เพิ่ม Annual Report Dashboard + PPTX Export

**`index.html` — การเปลี่ยนแปลง:**

**เพิ่มเมนู `dash-annual` "รายงานรายปี":**
- เพิ่มใน `DASHBOARD_MENUS` (icon: `calendar-range`, group: extra)
- เพิ่ม case `dash-annual` ใน `renderPageContent()`
- เพิ่ม Section 29B: ANNUAL REPORT DASHBOARD

**หน้า Annual Report Dashboard (รายโรงงาน + รายปี):**
- Factory tabs: CDE / Propel / Sanon 1 / Sanon 2 / Mobile Plant
- Year dropdown: ปีปัจจุบัน ย้อนหลัง 5 ปี
- KPI cards 4 ใบ: ยอดป้อนรวม, วันผลิต, อัตราเฉลี่ย, YTD vs แผน
- Chart.js bar+line: ยอดผลิตรายเดือน Actual (bar) vs แผน (dashed line)
- ตารางสรุปรายเดือน: ยอดผลิต / แผน / % ทำได้ (สีตามเกณฑ์) / วันผลิต
- ตารางผลิตภัณฑ์รายเดือน: แยกตาม productColumns ของแต่ละโรงงาน
- ปุ่ม PDF (print window) + ปุ่ม Export PPTX

**PDF Print (`printAnnualReport()`):**
- หน้า HTML สำหรับพิมพ์/บันทึก PDF
- ออกแบบด้วย cover header สีโรงงาน + KPI cards + ตารางรายเดือน
- % ทำได้ มีสีพื้นหลัง (เขียว/เหลือง/แดง) เหมือนต้นแบบ PPTX

**PPTX Export (`generateAnnualPptx()`):**
- โหลด PptxGenJS 3.12.0 จาก cdnjs CDN (on-demand)
- ดึงข้อมูลทุกโรงงานพร้อมกัน (Promise.all)
- โครงสร้างสไลด์:
  - Slide 1: Cover — ชื่อบริษัท, ปี, โรงงานทุกแห่ง (พื้นหลัง navy)
  - Slide 2: Overview — ตารางสรุปทุกโรงงาน (ยอดผลิต/วัน/อัตรา/% vs แผน)
  - ต่อโรงงาน (5 โรงงาน):
    - Slide A: KPI summary + Bar+Line chart รายเดือน + Monthly % table
    - Slide B: Product breakdown รายเดือน ทุก productColumn
- สีตามโรงงาน: CDE=teal, Propel=blue, Sanon1=purple, Sanon2=red, Mobile=orange
- ชื่อไฟล์: `รายงานผลิต_สานนท์_ปี{thYear}.pptx`

**ไม่ต้องรัน SQL เพิ่ม** — ใช้ข้อมูลจาก production tables และ factories table ที่มีอยู่แล้ว

**ไฟล์ที่แก้ไข:** `index.html`, `CLAUDE.md`
**Copy ไป GitHub/:** `index.html` ✅ | `CLAUDE.md` ✅

---

### 2026-09-02 รอบ 2 — index.html: แก้ Runtime + เป้าตัน/เดือน + sw.js v6

**`index.html` — การเปลี่ยนแปลง:**

**1. แก้ Runtime Mobile Plant (เวลาเดิน):**
- Root cause: `runtime_hour` เป็น `GENERATED ALWAYS AS` จาก `runtime_minute` ที่ default 0 — ไม่มี trigger คำนวณจาก start/stop hour
- Fix: รัน SQL patch ใน Supabase:
  1. `ALTER TABLE production_mobile DROP COLUMN IF EXISTS runtime_hour;`
  2. `ALTER TABLE production_mobile ADD COLUMN IF NOT EXISTS runtime_hour numeric(8,2) DEFAULT 0;`
  3. สร้าง trigger `calc_mobile_runtime()` — คำนวณ `runtime_minute = total_min % 60`, `runtime_hour = total_min / 60`, `avg_ton_per_hour = feed_ton / hours`
  4. `UPDATE production_mobile SET updated_at = now();` — recalculate แถวเดิม

**2. เพิ่มช่อง "เป้าผลิต (ตัน/เดือน)" ในหน้าเพิ่มโรงงาน:**
- เพิ่ม `target_month` column ใน `factories` table: `ALTER TABLE factories ADD COLUMN IF NOT EXISTS target_month numeric DEFAULT NULL;`
- เพิ่ม `<input id="ff-target-month">` ในฟอร์ม `openFactoryForm()`
- payload เพิ่ม `target_month: isNaN(ffTm) ? null : ffTm`
- Dashboard query: `select('id, name, target_throughput, target_month')`
- Logic: `effectiveTargetMonth = targetMonthDB > 0 ? targetMonthDB : cfg.targetMonth` → ส่งต่อให้ `renderKpiGapBlock`
- ใช้ได้ทุกโรงงาน: CDE, Propel, Sanon1, Sanon2, Mobile Plant

**3. แก้ factoryErr ไม่ crash Dashboard:**
- เปลี่ยน `if (factoryErr) throw factoryErr` → `const factoryRow = (!factoryErr && factoryRows) ? factoryRows[0] : null`
- ทั้ง `renderDashboardCdePropel` และ `renderDashboardSanon`

**`sw.js` → v6:**
- แก้ bug root URL `/sanon-webapp/` ถูก Cache First แทน Network First
- เพิ่ม condition: `pathname.endsWith('/') || pathname === BASE` → Network First

**SQL ที่ต้องรันใน Supabase (ถ้ายังไม่ได้รัน):**
1. `ALTER TABLE production_mobile DROP COLUMN IF EXISTS runtime_hour;`
2. `ALTER TABLE production_mobile ADD COLUMN IF NOT EXISTS runtime_hour numeric(8,2) DEFAULT 0;`
3. สร้าง trigger `calc_mobile_runtime` (ดูรายละเอียดในแชต)
4. `UPDATE production_mobile SET updated_at = now();`
5. `ALTER TABLE factories ADD COLUMN IF NOT EXISTS target_month numeric DEFAULT NULL;`
6. `NOTIFY pgrst, 'reload schema';`

**factories table — ข้อมูลปัจจุบัน (รันผ่าน UI แล้ว):**

| name | target_throughput | target_month |
|------|-----------------|-------------|
| CDE | 120 | 30000 |
| Propel | 180 | 45000 |
| Sanon 1 | 500 | 100000 |
| Sanon 2 | 400 | 100000 |
| Mobile Plant | 350 | 84000 |

**⚠️ ข้อควรระวัง:** ชื่อ factory ต้องตรงกับ `cfg.factoryName` ใน code — "Mobile Plant" (1 space) ไม่ใช่ "Mobile  Plant" (2 space)

**ไฟล์ที่แก้ไข:** `index.html`, `sw.js`, `CLAUDE.md`
**Copy ไป GitHub/:** `index.html` ✅ | `sw.js` ✅ | `CLAUDE.md` ✅

---

### 2026-09-02 — index.html: เพิ่ม Mobile Plant (โรงงานที่ 5)

**เป้าหมาย:** เพิ่ม Mobile Plant เป็นโรงงานที่ 5 ครบทุก feature เหมือน Sanon1/Sanon2

**`index.html` — การเปลี่ยนแปลง (15+ จุด):**

**เมนู:**
- `DASHBOARD_MENUS`: เพิ่ม `dash-mobile` (Dashboard Mobile Plant)
- `MANAGE_MENUS`: เพิ่ม `manage-prod-mobile` (ยอดผลิต Mobile Plant)
- `MANAGE_MENUS` approval: เพิ่ม `approve-mobile`
- `renderPageContent()`: เพิ่ม case `dash-mobile` → `renderDashboardSanon(container, 'mobile')` และ `manage-prod-mobile` → `renderManageProduction(container, 'mobile')`

**Config:**
- `PLANT_FACTORY_CODE`: เพิ่ม `mobile: 'Mobile'`
- `PRODUCTION_PLANT_CONFIG`: เพิ่ม `mobile` config พร้อม productColumns: UH312 หิน 3/4, UH312 หินฝุ่น, QA451 หิน 3/4, QA451 หิน 3/8, QA451 หินฝุ่น, หินคลุก — `hourMeterMode: true`, ไม่มี Flowmeter

**Dashboard (ใช้ Sanon style):**
- `_sanonRangeState`: เพิ่ม `mobile: defaultRangeState()`
- `renderDashboardSanon()`: เพิ่ม branch `mobile` → `production_mobile`, title `Dashboard Mobile Plant`
- `renderSanonYieldChart()`: เพิ่ม branch `mobile` — แสดง sums ตาม UH312/QA451 columns
- `renderDashboardStatusBanner()`: เพิ่ม `mobile: 'Mobile'` ใน fc map

**Approval:**
- `APPROVAL_PLANT_LABELS`: เพิ่ม `mobile: 'Mobile Plant'`
- `APPROVE_KEY_MAP`: เพิ่ม `'approve-mobile': 'mobile'`
- `APPROVAL_TABLE_MAP`: เพิ่ม `mobile: 'production_mobile'`
- `isProductionApprovalKey()`: เพิ่ม `|| k === 'mobile'`
- `approvalDepartmentsForUser()`: เพิ่ม mobile dept
- `fetchPendingApprovalCount()`: เพิ่ม `production_mobile` ใน prodTables

**Landing Stats:**
- `loadLandingPublicStats()`: เพิ่ม `production_mobile` ใน tables

**Permission Templates:**
- เพิ่ม `manager-mobile`, `supervisor-mobile`, `op-mobile`

**`production_mobile_schema.sql` — ใหม่:**
- ตาราง `production_mobile` — columns: feed_ton, uh312_stone_3_4_ton, uh312_stone_dust_ton, qa451_stone_3_4_ton, qa451_stone_3_8_ton, qa451_stone_dust_ton, stone_kluk_ton
- RLS policy `anon_all`
- Index: production_date, status

**⏳ สิ่งที่ต้องทำก่อนใช้งาน:**
1. รัน `production_mobile_schema.sql` ใน Supabase SQL Editor
2. Upload `index.html` ขึ้น GitHub Pages
3. Admin → Permission Matrix → ตั้งสิทธิ์ให้ User ที่ดูแล Mobile Plant

**ไฟล์ที่แก้ไข:** `index.html`, `production_mobile_schema.sql`, `CLAUDE.md`
**Copy ไป GitHub/:** `index.html` ✅ | `production_mobile_schema.sql` ✅ | `CLAUDE.md` ⏳

---

### 2026-08-14 — meeting.html: No-login Public Booking + Admin Login มุมขวาบน

**`meeting.html` — การเปลี่ยนแปลงหลัก:**

**1. ยกเลิก Login Screen — เปิดปฏิทินตรง:**
- `DOMContentLoaded`: ซ่อน `#login-screen` ทันที แสดง `#main-app` + ปฏิทินโดยไม่ต้อง login
- `CURRENT_ROLE = 'user'` เริ่มต้น — ซ่อน sidebar และ admin UI ทั้งหมด
- ใครมีลิงก์ → เปิดระบบได้เลย จองห้องโดยพิมพ์ชื่อตัวเอง

**2. Admin Login มุมขวาบน:**
- เพิ่ม `#btn-admin-login` (ปุ่ม "เข้าสู่ระบบผู้ดูแล") ที่ top-bar ขวาสุด
- เพิ่ม `#admin-login-modal` — modal ป้อน username+password สำหรับ admin เท่านั้น
- เพิ่ม `#admin-badge` — แสดงชื่อ+avatar เมื่อ Admin logged in
- `openAdminLoginModal()`, `closeAdminLoginModal()`, `doAdminLogin()`, `applyAdminUI()`
- `applyAdminUI()`: แสดง sidebar+hamburger, เปลี่ยนป้าย admin, เรียก `applyRole()`
- Try-restore admin session จาก localStorage ทุกครั้งที่โหลดหน้า

**3. ยกเลิกระบบ Approval — ทุกการจองเป็น confirmed อัตโนมัติ:**
- `saveBooking()`: เพิ่ม `status: 'confirmed'` ใน payload เสมอ
- ไม่มีขั้นตอนรออนุมัติ — จองแล้วขึ้นปฏิทินทันที
- Approval panel ยังมีอยู่ใน sidebar แต่ซ่อนสำหรับ public (`can('approve')` gated)

**4. ต้องระบุชื่อผู้จอง (bk-by) — Validate:**
- `saveBooking()`: validate `bk-by` เป็น required, focus field ถ้าว่าง
- ลบ fallback `|| 'Admin'` เดิม

**5. doLogout() → Public mode:**
- ไม่ redirect ไป login-screen อีกต่อไป
- Reset `CURRENT_USER` เป็น public user, ซ่อน sidebar+admin-badge, แสดง `#btn-admin-login`

**6. Admin sections ใน sidebar คงอยู่:**
- จัดการห้อง, จัดการผู้ใช้, ตั้งค่า ยังมีในระบบ
- แสดงเฉพาะเมื่อ Admin login (`applyRole()` toggle via `can()`)
- Public user ไม่เห็น management menus เลย

**ไฟล์ที่แก้ไข:** `meeting.html`, `CLAUDE.md`
**Copy ไป GitHub/:** `meeting.html` ✅ | `CLAUDE.md` ✅

---

### 2026-08-13 — meeting.html: Colorful Events + Conflict Detection + Soft Delete + Portal/Index Integration

**`meeting.html` — การเปลี่ยนแปลงหลัก:**
- Rename จาก `meeting_demo.html` → `meeting.html`
- `buildEvents()`: custom `eventContent` HTML rendering, สีตามห้อง, filter cancelled
- `deleteBooking()`: soft-delete (status='cancelled') + restore ด้วย `restoreBooking()`
- `liveConflictCheck()`: real-time conflict detection ใน booking modal
- แก้ Hamburger ไม่ทำงานบน mobile — เปลี่ยน `classList.replace` → `style.display+classList`
- แก้ Login screen ไม่ scroll บน mobile — เปลี่ยน flex center → `overflow-y-auto items-start`
- ปุ่มจองห้องประชุม: เปลี่ยนเป็น amber/yellow โดดเด่น

**`portal.html` + `index.html`:** เพิ่ม System 5 card (จองห้องประชุม) ใน switcher ทุก platform

**ไฟล์ที่แก้ไข:** `meeting.html`, `portal.html`, `index.html`, `CLAUDE.md`

---

### 2026-08-08 — index.html: แก้ Export รายงานการผลิต + เปลี่ยน Export Excel → CSV

**`index.html` — การเปลี่ยนแปลงหลัก:**

**1. แก้ Export ในหน้า manage-reports (รายงาน) — เพิ่ม columns ครบ:**
- สร้างฟังก์ชัน `buildProductionExportData()` ใหม่สำหรับ production type
- Export CSV/Excel ของหน้ารายงานตอนนี้ครบทุก column ตรงกับตารางที่แสดงผล:
  - หน่วยผลิต, วันเดือนปี, ยอดข้อมูล, เวลาเดิน, เฉลี่ย(ตัน/ชม), ป้อน(ตัน)
  - Product cols ตามโรงงาน (O/S, หิน 3/4, หินเกล็ด 3/8, M-Sand, ตะกอน Silk ฯลฯ)
  - มิตร.เริ่ม, มิตร.หยุด, FM รวม, FM (เฉพาะ CDE/Propel)
  - Breakdown
- Status แปลงเป็นภาษาไทย: approved→จริง, rejected→ปฏิเสธ, else→เบื้องต้น

**2. เปลี่ยน Export ในหน้า manage-prod-* (ยอดผลิต CDE/Propel/Sanon1/Sanon2):**
- เปลี่ยนจาก `.xlsx` → `.csv` (UTF-8 with BOM เปิด Excel ได้ปกติ)
- หัวคอลัมน์เป็น DB column keys ตรงกับ import template ทุกโรงงาน
- ลำดับคอลัมน์: `production_date → start_hour → start_minute → stop_hour → stop_minute → breakdown_detail → raw_material → feed_ton → [product cols] → meter_start → meter_stop (ถ้ามี flowmeter) → note`
- เรียงวันที่จากน้อยไปหามาก (ascending) — เหมาะสำหรับนำไปแก้ไขแล้ว re-import
- เปลี่ยนชื่อปุ่ม "Export Excel" → "Export CSV"

**Workflow ที่รองรับ:**
1. กด Export CSV → ได้ไฟล์ `production_cde_export.csv`
2. เปิดใน Excel → แก้ยอดผลิตจริง → Save as CSV
3. กด "นำเข้า ยอดจริงสิ้นเดือน" → upload → ระบบ update ข้อมูลจริง

**ไฟล์ที่แก้ไข:** `index.html`
**Copy ไป GitHub/:** `index.html` ✅ | `CLAUDE.md` ✅
**ยังไม่ได้ upload ขึ้น GitHub Pages** — รอ upload

---

> 📌 **2026-08-05 — pm.html:** เรียงรายการ PM ตามสถานะ + เพิ่มคอลัมน์วันที่ PM ล่าสุด — รายละเอียดย้ายไปที่ **`PM.md`** Section 11 (Changelog) ตามนโยบายแยกไฟล์ 2026-09-15

---

### 2026-08-01 (กลางคืน) — Portal Smart Launcher + อัปเดต CLAUDE.md

**`portal.html` — สร้างใหม่:**
- หน้า Login กลาง → query สิทธิ์จาก `role_permissions` + `user_permissions` ใน Supabase
- แสดงการ์ดเฉพาะระบบที่ User มีสิทธิ์ (admin = 4 การ์ด, User ทั่วไป = ตามสิทธิ์)
- SSO: อ่าน/เขียน `localStorage._sn_shared_sess` ร่วมกับทุกระบบ — login ครั้งเดียวใช้ได้ทุกที่
- Responsive: 2 คอลัมน์บน tablet+, 1 คอลัมน์บน mobile เล็ก
- เมื่อ admin เพิ่มสิทธิ์ให้ User → User เปิด portal ใหม่ → เห็นการ์ดเพิ่มทันที (real-time จาก DB)

**`manifest-portal.json` — สร้างใหม่:**
- PWA manifest สำหรับ portal.html, start_url = `/sanon-webapp/portal.html`
- ใช้ icon-192/512.png เดิม

**`sw.js` → v3:**
- เพิ่ม `portal.html` + `manifest-portal.json` ใน PRECACHE list

**`CLAUDE.md` — อัปเดต Section 0:**
- แก้ข้อมูลเก่าที่ยังระบุ "Loading Screen" ซึ่ง revert ไปแล้ว
- sw.js v2 → v3, เพิ่ม Portal ใน status board + Section 0E

**ไฟล์ที่แก้ไข:** `portal.html` (ใหม่), `manifest-portal.json` (ใหม่), `sw.js`, `CLAUDE.md`
**Copy ไป GitHub/:** `portal.html`, `manifest-portal.json`, `sw.js`, `CLAUDE.md` ✅
**ยังไม่ได้ upload ขึ้น GitHub Pages** — รอ session ถัดไป

---

### 2026-08-01 (ดึกสุด) — Mobile System Switcher ครบ 4 ระบบ + Desktop Sidebar 2×2

**`index.html` — Mobile System Switcher ปรับใหม่:**

**Desktop Sidebar:**
- เปลี่ยน layout "เปลี่ยนระบบ" จาก `flex` 3 การ์ด → `grid grid-cols-2` 4 การ์ด (2×2)
- เพิ่ม System 4 (เช็คอิน) — gradient emerald (`#065f46→#059669`), icon `clock`

**Mobile — ปุ่ม "ระบบ" + Bottom Sheet:**
- เพิ่มปุ่ม "ระบบ" (icon: grid) ท้ายสุดของ Bottom Nav มือถือ
- เพิ่ม `mobile-system-sheet` — bottom sheet แสดง 4 ระบบ แบบ 2 คอลัมน์ การ์ดใหญ่ (มีชื่อ + คำอธิบาย)
- กด backdrop → ปิด sheet อัตโนมัติ
- กดการ์ดระบบอื่น → `gotoSystem()` เปลี่ยนหน้าทันที

**Global State เพิ่ม:**
- `isSystemSheetOpen` — reset ใน navigateTo(), doLogout(), session timeout

**ไฟล์ที่แก้ไข:** `index.html`
**Copy ไป GitHub/:** `index.html` ✅

---

### 2026-08-01 (ดึกมาก) — LINE Notification จาก JavaScript Frontend (ทั้ง 3 ระบบ)

**แนวทางใหม่:** เปลี่ยนจาก pg_net trigger → เรียก Edge Function โดยตรงจาก JavaScript หลัง INSERT สำเร็จ (fire-and-forget, ไม่ block UI)

**`index.html` — production INSERT:**
- เพิ่ม `fetch()` ไป `line-notify` หลัง `db.from(cfg2.table).insert([payload])` สำเร็จ
- เงื่อนไข: `payload.status === 'pending'` เท่านั้น
- ส่ง `recorder_name: currentUser.full_name` ตรงในทุก record (ไม่ต้อง DB lookup)

**`inventory.html` — saveWithdraw():**
- เพิ่ม `fetch()` ไป `line-notify` หลัง INSERT สำเร็จ
- เงื่อนไข: `!apv` (status=pending) เท่านั้น
- ส่ง `item_name` จาก dropdown option text, `item_unit` จาก `data-unit` attribute

**`pm.html` — saveRepair():**
- เพิ่ม `fetch()` ไป `line-notify` หลัง INSERT pm_repair_logs สำเร็จ
- ส่งทุก INSERT (ไม่มีเงื่อนไข status)

**`line-notify_index.txt` + `supabase/functions/line-notify/index.ts`:**
- Production handler: ใช้ `record.recorder_name` ก่อนถ้ามี แล้วค่อย lookup DB
- Inventory handler: ใช้ `record.item_name` + `record.item_unit` ก่อนถ้ามี แล้วค่อย lookup DB
- รองรับทั้ง frontend call (enriched) และ trigger call (UUID เท่านั้น)

**⚠️ ต้อง Deploy Edge Function ล่าสุดใน Supabase ก่อนใช้งาน:**
- ใช้ไฟล์ `line-notify_index.txt` → วางใน Supabase Dashboard → Edge Functions → line-notify → Deploy

**ไฟล์ที่แก้ไข:** `index.html`, `inventory.html`, `pm.html`, `line-notify_index.txt`, `supabase/functions/line-notify/index.ts`
**Copy ไป GitHub/:** `index.html`, `inventory.html`, `pm.html` ✅

---

### 2026-08-01 (ช่วงดึก) — Revert Loading Screen ทุกระบบ + อัปเดต CLAUDE.md

**ปัญหาที่เกิดขึ้น:**
- พยายามใส่ excavator loading screen (PNG + synthwave bg) ใน HTML ทั้ง 4 ระบบ
- Splash ค้างเพราะ `<script>` inline ใน splash div ต้องปิดด้วย `</script>` (ไม่มี backslash) แต่โค้ดที่ generate มาใช้ `<\/script>` ซึ่ง parser ไม่รู้จัก
- การแก้ไขซ้ำ ๆ ทำให้ไฟล์เสียหายหลายรอบ — print dialog popup เองเมื่อ F5, JS syntax error, blank page

**การแก้ไข:**
- Restore ทุกไฟล์จาก GitHub commit `754ed54` (30 ก.ค. 2569) ที่ YAi download มาด้วยตัวเอง
- ลบ stray `<\/script>` ที่เหลืออยู่หลัง restore ออกจาก index.html และ checkin.html
- อัปเดต `sw.js` → v2 (ลบ excavator.png ออกจาก PRECACHE list)
- **ผล:** ทุกระบบกลับมาทำงานปกติ ไม่มี loading screen

**สรุปสถานะหลัง Revert:**
- `index.html` — restore commit 754ed54, JS clean ✅
- `inventory.html` — restore commit 754ed54 + normCat fix ✅
- `pm.html` — restore commit 754ed54, JS clean ✅
- `checkin.html` — restore commit 754ed54, JS clean ✅
- `sw.js` — v2 (ไม่มี excavator.png) ✅
- `excavator.png` — ยังอยู่ใน GitHub/ แต่ไม่ได้ reference แล้ว (ลบด้วยมือได้)
- **ยังไม่ได้ upload ขึ้น GitHub Pages** — รอ session ถัดไป

---

### 2026-08-01 (ช่วงเย็น) — checkin.html: รายงานบุคคลภายนอก + Sync GitHub→Main

**`checkin.html` — เพิ่ม:**
- **รายงาน 2 แท็บ**: `ck-report` แยกแท็บ "👥 พนักงาน" / "🏢 บุคคลภายนอก"
- แท็บบุคคลภายนอก: query `checkin_visitors`, กรองได้ตามวันที่/ชื่อ/บริษัท/ประเภท/ประตู/สถานะ
- Summary card: รายการทั้งหมด, จำนวนคนรวม, ยังอยู่ในโรงงาน, ออกแล้ว
- Export CSV บุคคลภายนอก (`exportVisitorReport()`)
- แก้ bug `}` เกินใน `switchRpTab()` ทำให้ JS syntax error (login ไม่ได้)

**Sync ไฟล์:**
- Copy GitHub/ → Main/ ครบทั้ง 4 ไฟล์ (GitHub เป็น version ล่าสุดที่ deploy อยู่)
- อัปเดต CLAUDE.md Section 0 + 0E ให้ตรงกับสถานะจริง

**SQL ที่ยังต้องรัน (ยังไม่ได้ทำ):**
- `checkin_schema_v4_patch.sql` — เพิ่ม `person_count` ใน `checkin_visitors`
- `checkin_schema_v5_patch.sql` — เพิ่ม `permissions text[]` ใน `checkin_users`

---

### 2026-08-01 — LINE Notification Fix + Mobile System Switcher

**`line_webhook.sql` — trigger enrichment:**
- เพิ่ม lookup `item_name` + `unit` จาก `inventory_items` แนบใน payload ก่อนส่ง LINE (แก้ UUID แสดงชื่อวัสดุ)
- เพิ่ม lookup `recorder_name` จาก `app_users.full_name` สำหรับ production tables (แก้ UUID แสดงชื่อผู้บันทึก)
- รันใน Supabase SQL Editor แล้ว ✅

**`line-notify/index.ts` (Edge Function) — อัปเดตโค้ด:**
- `buildInventoryCard`: ใช้ `r.item_name`, `r.requested_by`, `r.doc_no`, `r.unit` แทน UUID
- `buildProductionCard`: เปลี่ยน `r.recorded_by` → `r.recorder_name`
- ไฟล์อัปเดตแล้ว — **ต้อง Deploy ใน Supabase Edge Functions** ⏳

**`index.html` — Mobile System Switcher:**
- เพิ่มปุ่ม "ระบบ" (icon: grid) ใน Bottom Nav มือถือ
- เพิ่ม bottom sheet `mobile-system-sheet` — แสดง System 1 (active), 2 คลัง, 3 PM, 4 Checkin
- เพิ่ม global state `isSystemSheetOpen`
- copy ไป `GitHub/` แล้ว ✅

**Global State Variables (index.html) อัปเดต:**
```js
currentUser, currentPage, pendingApprovalCount,
isMobileSheetOpen, isManageSheetOpen, isSystemSheetOpen,
chartRegistry, sessionTimerInterval, sessionSecondsLeft,
sessionWarnShown, approvalCountInterval
```

---

### 2026-07-21 (ช่วงบ่าย) — pm-meter Redesign + pm-report + pm-oee + Executive Dashboard

**pm.html — หน้าบันทึกเลขมิเตอร์ (pm-meter) ออกแบบใหม่:**
- เปลี่ยนจากระบบเลือกเครื่องแล้วดูตารางแยก → ตารางเดียวรวมทุกเครื่อง (เหมือนรถตักไฟฟ้า)
- ปุ่ม "+ เพิ่มข้อมูลมิเตอร์" ด้านบนขวา
- Filter bar: dropdown เครื่องจักร + เดือน + ปุ่ม Refresh
- `renderMeterPage()` ใหม่ — แสดง header + filter + table area
- `loadMeterTableData()` — query `pm_meter_logs` join `pm_machines` ทุกเครื่องพร้อมกัน, columns: วันที่/เครื่องจักร/โรงงาน/มิเตอร์เริ่ม/มิเตอร์หยุด/ชม.รวม/Breakdown/จัดการ
- `openMeterLogModal()` ใหม่: มี dropdown เครื่องจักรที่บนสุด, `#ml-hyd-section` render ใน DOM ตลอด (toggle display), label อัปเดตตามเครื่องที่เลือก
- `onMeterMachineChange()`: reset ช่องหยุด, อัปเดต label, toggle `#ml-hyd-section`, pre-fill ค่ามิเตอร์ปัจจุบัน
- `saveMeterLog()`: อ่าน `machine_id` จาก `#ml-machine` dropdown แทน global `_meterSelectedMachine`

**pm.html — เมนูใหม่:**
- `pm-report` — รายงาน PM รายเดือน (SECTION 16B): filter เดือน/ปี, ตาราง PM log, export Excel/Print
- `pm-oee` — OEE / Availability รายเครื่อง (SECTION 16C): คำนวณ availability จาก downtime_hours/calendar_hours

**index.html — Executive Dashboard (SECTION 18C):**
- เมนู `dash-executive` — ดึงข้อมูล 7 ตาราง parallel: production CDE/Propel/Sanon1/Sanon2, drone_stock, electricity_costs, inventory pending
- KPI cards โรงงาน, progress bars, ตารางค่าไฟ, alert คลังวัสดุ

**pm.html — ระบบ PM + DB ใหม่:**
- `pm-repair` — บันทึกซ่อม (pm_repair_logs + pm_repair_parts + หัก stock)
- `pm-parts` — คลังอะไหล่ (pm_parts CRUD + รับเข้า + stock_log)
- `pm_repair_schema.sql` + `pm_meter_schema.sql` — รันใน Supabase เรียบร้อยแล้ว

**SSO ข้ามระบบ (ทั้ง 3 ไฟล์ — ดูรายละเอียดด้านล่าง):**

---

### 2026-07-21 — SSO + LINE Webhook + สิทธิ์เบิกตามโรงงาน

**SSO ข้ามระบบ (ทั้ง 3 ไฟล์):**
- เพิ่ม `localStorage._sn_shared_sess` — login ระบบไหนก่อนก็ได้ ไม่ต้อง login ซ้ำ
- `index.html` doLogin/doLogout/Bootstrap: write + read + clear `_sn_shared_sess`
- `inventory.html` doLogin/doLogout/Bootstrap: write + read + clear + แก้ bug own-session ไม่ set `currentUser`
- `pm.html` doLogin/doLogout/restoreSession: write + read + clear + fetch pm- permissions จาก DB

**System Switcher (pm.html):**
- เพิ่ม card-style System Switcher ใน Sidebar footer ให้เหมือน System 1 & 2

**LINE Webhook — แก้ trigger:**
- `line_webhook.sql`: แก้ `body := _payload::text` → `body := _payload` (jsonb)
- เพิ่ม `EXCEPTION WHEN OTHERS THEN RETURN NEW` — ป้องกัน LINE error บล็อค INSERT ยอดผลิต/เบิก
- แก้ bug `line-notify/index.ts`: `record.type` → `record.transaction_type` (ทำให้ LINE แจ้งเตือนคลังไม่ส่ง)

**PM Scheduled Alert:**
- Deploy Edge Function `pm-daily` — ส่ง LINE Flex Card แจ้ง PM เกินกำหนด/ใกล้ถึง แยกตามโรงงาน
- `pm_cron.sql`: ตั้ง pg_cron job `pm-daily-notify` ทุกวันจันทร์ 07:00 (ไทย)

> รายละเอียด `inventory.html` วันเดียวกัน (ปุ่มยกเลิกยอดเบิก + สิทธิ์เบิกตามโรงงาน) ย้ายไปอยู่ใน `INVENTORY.md` แล้ว

---

### 2026-07-17 — System 3: pm.html — ขยาย Dashboard + เมนู + ระบบซ่อม/อะไหล่ + Factory Management

**pm.html — การเปลี่ยนแปลงหลัก:**

**1. เมนูใหม่ (PM_MENUS เพิ่ม 3 เมนู):**
- `pm-items` — รายการ PM (แยกออกมาจาก pm-machines เป็น Sidebar menu ต่างหาก)
- `pm-repair` — บันทึกซ่อม (repair log + อะไหล่ที่ใช้ + ค่าใช้จ่าย)
- `pm-parts` — คลังอะไหล่ (CRUD อะไหล่ + รับเข้า/เบิกออก)

**2. Dashboard — Alert Grid แบบคอลัมน์ต่อโรงงาน:**
- แสดงเฉพาะโรงงานที่มี `overdue` หรือ `alert` เท่านั้น (`alertFactories` filter)
- ถ้าไม่มี alert → แสดง banner เขียว "ทุกเครื่องอยู่ในสถานะปกติ ✅"
- Grid layout: 1/2/3/4 คอลัมน์ตามจำนวนโรงงานที่มี alert
- ปุ่มกรองโรงงานใน detail table (`dashSetFac()`) — "ทั้งหมด" + ปุ่มต่อโรงงาน

**3. รายการ PM (pm-items) — UX:**
- Scrollable table ต่อเครื่อง (`max-height:340px; overflow-y:scroll`)
- เรียงสถานะ: เกินกำหนด🔴 → ใกล้ถึง🟡 → ปกติ🟢 (`STATUS_PRIORITY`)
- ประเภท PM เป็น dropdown (`_pmTypes`) + "✏️ พิมพ์เอง…" option

**4. Global State เพิ่ม:**
```js
let _pmFactories = ['CDE','Propel','Sanon1','Sanon2','ทั่วไป'];
let _pmParts     = [];
let _pmRepairs   = [];
```

**5. loadPmData() — โหลด 5 configs พร้อมกัน:**
- `pm_config` key `categories`, `pm_types`, `factories`

**6. Factory Management (SECTION 15D):**
- `openFactoriesModal()` / `saveFactories()` — บันทึก `pm_config` key `factories`
- Settings page: card "โรงงาน" แสดง chip + ปุ่ม "เพิ่ม/แก้ไขโรงงาน"
- `machineFormHtml()` ใช้ `_pmFactories` แทน hardcode

**7. ระบบซ่อม/อะไหล่ (pm-repair + pm-parts):**
- `saveRepair()`: บันทึก `pm_repair_logs` + `pm_repair_parts` + หัก `pm_parts.stock_qty` + log ใน `pm_parts_stock_log`
- `PART_CATS`: motor/pump/belt/screen/electrical/other
- pm-parts: CRUD อะไหล่ + รับเข้าสต็อก + ประวัติ stock log

**DB ใหม่ — pm_repair_schema.sql (ต้องรันใน Supabase ก่อนใช้):**
- `pm_parts` — master อะไหล่ (code, name, category, unit_price, stock_qty, min_stock)
- `pm_repair_logs` — บันทึกการซ่อม (machine_id, repair_date, type, symptoms, root_cause, action_taken, labor_cost, parts_cost, total_cost)
- `pm_repair_parts` — อะไหล่ที่ใช้ต่อการซ่อม (repair_id, part_id, qty_used, unit_price)
- `pm_parts_stock_log` — ประวัติรับเข้า/เบิกออก/ปรับยอด
- RLS: `anon_all` ครบทุกตาราง

**สถานะ System 3 (pm.html) หลัง 2026-07-17:**
- ✅ Dashboard — Alert Grid + Factory filter
- ✅ pm-items — รายการ PM แยกเมนู + scrollable + เรียงสถานะ
- ✅ pm-repair — บันทึกซ่อม
- ✅ pm-parts — คลังอะไหล่
- ✅ pm-settings — จัดการโรงงาน/ประเภท PM/หมวดหมู่
- ⏳ ยังไม่ได้ทดสอบ pm-repair, pm-parts กับ DB จริง (ต้องรัน pm_repair_schema.sql ก่อน)

---

### 2026-07-16 (ช่วงเย็น) — System 3: pm.html + pm_schema.sql

**pm.html — ระบบ PM เครื่องจักร (Hour-based PM):**
- สร้าง `pm.html` ระบบ PM แบบ Hour/Km-based (แบบ Excel ตารางรอบ PM)
- Auth: query `app_users` table, SESSION_KEY `_sn_pm_sess`, Session Timeout 2 ชม.
- Menu prefix `pm-`: `pm-dashboard`, `pm-log`, `pm-downtime`, `pm-history`, `pm-machines`, `pm-settings`
- **Dashboard**: ตารางรอบ PM (เหมือน Excel) — machine + รายการ PM → ระยะ/รอบถัดไป/ระยะคงเหลือ/สีแดง🔴/เหลือง🟡/เขียว🟢
- **pm-log**: บันทึก PM จริง → update last_pm_meter/last_pm_date อัตโนมัติ + บันทึก downtime
- **pm-downtime**: Downtime Log (breakdown/planned_pm/setup/other) + stats
- **pm-history**: ประวัติต่อเครื่อง — PM status ปัจจุบัน + PM logs + Downtime logs
- **pm-machines**: CRUD เครื่องจักร + จัดการรายการ PM ต่อเครื่อง
- **pm-settings**: ข้อมูลระบบ + คำแนะนำ

**pm_schema.sql — DB System 3:**
- `pm_machines` — เครื่องจักร (name, factory, category, meter_type, current_meter, alert_threshold)
- `pm_items` — รายการ PM ต่อเครื่อง (pm_type, interval_value, last_pm_date, last_pm_meter)
- `pm_logs` — ประวัติการทำ PM จริง (done_date, done_meter, parts_used JSONB, total_cost)
- `pm_downtime` — Downtime Log (start_time, end_time, duration_hours, type, cause)
- `pm_config` — ตั้งค่าระบบ
- RLS: เปิดทุกตาราง, policy `anon_all`

**ออกแบบจากข้อมูล Excel:**
- คำนวณ: `next_due = last_pm_meter + interval` → `remaining = next_due - current_meter`
- รองรับ meter_type = `hours` (ชม.) หรือ `km` (กม.)
- alert_threshold: แจ้งเตือนก่อนถึงกำหนด N ชม/กม

### 2026-07-16 (ช่วงบ่าย) — ค่าไฟฟ้า + Print Color + UI

**ระบบค่าไฟฟ้า (ใหม่ทั้งหมด):**
- สร้าง `electricity_costs` table — `(factory, year, month, baht, kwh)` + UNIQUE constraint + RLS
- SQL ไฟล์: `electricity_schema.sql` — ต้องรันใน Supabase ก่อนใช้งาน
- เพิ่มเมนู `dash-electricity` (Dashboard ค่าไฟฟ้า 4 โรงงาน) และ `manage-electricity` (กรอก/แก้ไขรายเดือน)
- Dashboard: KPI cards 4 ใบ (บาท/ตัน + % vs เดือนก่อน) + Line chart รายเดือน + Ranking + ตารางรายเดือน chip ▲▼%
- Manage: ตาราง upsert ค่าไฟรายเดือน คลิกแถวแก้ไขได้ หรือกดปุ่ม "บันทึก/แก้ไขค่าไฟ"
- KPI เชื่อมกับ `ELEC_FACTORIES` + `ELEC_PROD_TABLES` (ดึง feed_ton จาก production tables อัตโนมัติ)
- เพิ่มใน Permission Templates: Manager CDE/Sanon มีสิทธิ์ `dash-electricity` และ `manage-electricity`

**Executive Report PDF — เพิ่มส่วนค่าไฟ:**
- `fetchExecReportData` ดึง `electricity_costs` ตามช่วงปี/เดือน รวมตาม factory + คำนวณ บาท/ตัน
- Summary line: `⚡ ค่าไฟฟ้ารวม 4 โรงงาน X บาท`
- Section ใหม่ใน PDF: "⚡ ค่าไฟฟ้าโรงงาน" — KPI cards + ตาราง ค่าไฟ/ผลิต/บาท/ตัน ต่อโรงงาน (ซ่อนอัตโนมัติถ้าไม่มีข้อมูล)

**index.html — UI ค่าไฟฟ้า Dashboard:**
- KPI cards: gradient อิ่มสีขึ้น (opacity 55%), border สว่างขึ้น, top glow bar, corner glow, ตัวเลข 30px + text-shadow
- Chart card + Rank card: พื้นหลัง `rgba(15,23,42,.6)` แยกจาก content ชัดเจน
- Ranking: medal icon (🥇🥈🥉), progress bar มี glow, แสดง "ดีที่สุด/สูงสุด"
- Badge %: มี border + background เข้มขึ้น อ่านง่าย

### 2026-07-16 — Security + index.html PDF

**Supabase Security (RLS):**
- เปิด Row Level Security (RLS) ครบทุกตาราง ทั้ง System 1 และ System 2
- สร้าง policy `anon_all` (FOR ALL TO anon USING true) บนทุกตารางปฏิบัติการ
- `app_users`: สร้าง policy SELECT/INSERT/UPDATE สำหรับ anon — **ไม่มี DELETE** (ป้องกันลบ user ผ่าน Anon Key)
- ตาราง `roles` เปิด RLS เพิ่มเติม (พบว่า rowsecurity=false จากการตรวจสอบ)
- Supabase Security Warning `rls_disabled_in_public` หายแล้ว

**app_users: เพิ่ม field โรงงาน/ฝ่าย:**
- เพิ่ม column `factory text` และ `department text` ใน `app_users`
- SQL: `ALTER TABLE app_users ADD COLUMN IF NOT EXISTS factory text, ADD COLUMN IF NOT EXISTS department text;`
- Settings → ผู้ใช้งาน: เพิ่มปุ่ม "โรงงาน/ฝ่าย" ต่อ user → `openUserFactoryModal()` → `saveUserFactory()`
- Modal เบิกวัสดุ: pre-fill โรงงาน + ฝ่ายจาก `currentUser.factory` / `currentUser.department` อัตโนมัติ (รายละเอียดฝั่ง inventory.html ดู `INVENTORY.md`)

**index.html — PDF Executive Report:**
- เพิ่ม `print-color-adjust:exact` และ `-webkit-print-color-adjust:exact` ใน CSS ของหน้ารายงาน
- เพิ่มใน `@media print` ด้วย — ทำให้สีพื้นหลังและตัวอักษรออกมาครบเมื่อ Save PDF

### 2026-07-13 — index.html: Landing Page Card Style (System 2/3 entry cards)

**index.html (Landing Page):**
- System 2 (Inventory): เปลี่ยนจาก `<a>` ทั้งก้อน → การ์ด + ปุ่ม "เข้าสู่ระบบ" สีเขียว
- System 2: Gradient `emerald-500 → teal-700` + ปุ่มขาว
- System 3 (PM): เปลี่ยนจาก link → การ์ด Gradient `amber-500 → orange-600` + ปุ่ม "เข้าสู่ระบบ" ขาว
- ทั้ง 3 ระบบมีสไตล์ Gradient card เหมือนกัน

> รายละเอียด FIFO/QR/Layout ของ `inventory.html` วันเดียวกัน ย้ายไปอยู่ใน `INVENTORY.md` แล้ว

### 2026-07-12 — Mobile UX + PDF Report + Bottom Nav

**Mobile UX:**
- Viewport meta: `minimum-scale=0.5, maximum-scale=3.0` (allow pinch zoom)
- ลบ `overflow-x:hidden` ออกจาก `html` element (คงไว้บน `body` เท่านั้น) — ป้องกัน pinch zoom ถูก block บน iOS
- เพิ่ม `font-size:16px !important` บน input/select/textarea ใน mobile — ป้องกัน iOS auto-zoom
- Production Form modal เพิ่ม `justify-center` — ให้ modal อยู่กลางจอบน desktop
- ปุ่มรถตักไฟฟ้าเปลี่ยนชื่อจาก "เพิ่ม" → "เพิ่มข้อมูลรถตัก"
- Mobile table: `table-layout:fixed`, `word-break:break-word`, font 10px, ซ่อน overflow-x
- **คอลัมน์ "จัดการ" (สุดท้าย) Sticky ขอบขวา** — `position:sticky; right:0; background:#fff` ให้กดปุ่มแก้ไขได้เสมอโดยไม่ต้อง scroll

**Bottom Nav (Mobile):**
- Auto-close sheet เมื่อกด nav-link — เพิ่ม `.classList.add('hidden')` บน `mobile-more-sheet` และ `mobile-manage-sheet` ใน `attachShellEvents()` โดยตรง (soft-navigate ไม่ full re-render จึงต้อง hide DOM เอง)

**PDF Executive Report (Section 30):**
- เพิ่ม Executive Summary + Traffic Light 🟢🟡🔴 + Trend ▲▼ + Breakdown Log
- แก้ runtime ให้รวม `runtime_minute/60` (เหมือน dashboard)
- แก้อัตราเฉลี่ยใช้ `avg(avg_ton_per_hour)` (เหมือน dashboard)
- แก้วันทำงานนับเฉพาะวันที่ runtime > 0
- แก้ column misalignment ด้วย string concatenation แทน nested template literal
- แก้ Sanon 1/2 runtime แสดง "-" เมื่อไม่มี start/stop time
- เพิ่มสีหัวข้อ section: Drone (น้ำเงิน), Sales (เขียว), Loader (ส้ม), Water (ฟ้า)

**ลบออก:**
- ลบ `<script src="pptxgen.bundled.js">` ออกจาก index.html (ไฟล์ไม่มีอยู่จริงใน repo)

---

## 6. การตั้งค่าการทำงานกับ Claude

- ตอบเป็น **ภาษาไทย** เสมอ ยกเว้นศัพท์เทคนิค
- เรียกผู้ใช้ว่า **"คุณใหญ่"** หรือ **"YAi"**
- Tone: ตรงประเด็น กระชับ มืออาชีพ
- ไฟล์ทั้งหมด Save ที่: `G:\เขียนเว็บ+Ai\เขียนเว็บสานนท์`
- **ก่อนแก้ไขโค้ด** → อ่าน index.html ในส่วน Section ที่เกี่ยวข้องก่อนเสมอ
- ห้ามเดาโดยไม่มีเหตุผล — ถ้าไม่แน่ใจให้ถามก่อน
- เมื่อแก้ไขโค้ดเสร็จ → Save ลง `G:\เขียนเว็บ+Ai\เขียนเว็บสานนท์\index.html` ทันที
