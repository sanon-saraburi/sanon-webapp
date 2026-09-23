# LEAVE.md — ระบบขอลา (System 6)
> ไฟล์นี้บันทึกรายละเอียดเฉพาะ `leave.html` — อ่านก่อนแก้ไขทุกครั้ง

---

## 1. ข้อมูลระบบ

- **ไฟล์:** `leave.html` (~3,900+ บรรทัด)
- **สถานะ:** 🚧 พร้อม deploy (รอ SQL 6 ชุด + Deploy Edge Function + Upload GitHub Pages + เปิด Realtime ใน Supabase Dashboard)
- **Supabase:** `https://pcmpwkcmvsxrvbximjgf.supabase.co` (project เดิม)
- **Session key:** `_sn_lv_sess`
- **GitHub Pages:** `https://sanon-saraburi.github.io/sanon-webapp/leave.html`

---

## 2. Architecture

- **Pattern:** Single-file SPA, Vanilla JS, Tailwind CDN, Lucide Icons
- **Menu prefix:** `lv-`
- **Auth — มี 2 แท็บ / 3 เส้นทาง login:**
  1. **แท็บ "หัวหน้า/Admin" → Password login (`doLogin()`):** query ตรงจาก `app_users` table ใช้ `role` จริงจาก DB (`admin` / `supervisor` / `viewer`) — **เป็นเส้นทางเดียวที่ให้สิทธิ์ admin ได้**
  2. **แท็บ "หัวหน้า/Admin" → PIN quick-access (`_proceedSupLogin()`):** query จาก `checkin_employees` table — **hardcode `role: 'supervisor'` เสมอ ไม่ว่าใครล็อกอิน** (ไม่มีทางได้สิทธิ์ admin ผ่านเส้นทางนี้)
  3. **แท็บ "พนักงาน" → PIN quick-access:** query จาก `checkin_employees` เช่นกัน, `role: 'employee'` เสมอ, ไม่ต้องใส่รหัสผ่าน — ยืนยันตัวตนด้วย PIN 4 หลัก (ดู Section 6)
- **ตารางที่ใช้ร่วมกับ System 4 (Checkin/HR):** `checkin_employees` — ทั้งสองระบบอ่าน/เขียนตารางเดียวกัน (photo_url, pin_code ใช้ร่วมกัน)

---

## 3. ฟีเจอร์หลัก (ตามหน้าเมนู)

- **Dashboard** — วันลาคงเหลือของพนักงาน, รูปโปรไฟล์ (เฉพาะโหมดพนักงาน)
- **ยื่นคำขอลา** — 10 ประเภท, คำนวณ working day (จันทร์–เสาร์), เช็ค `leave_holidays`
- **ขอออกนอกบริเวณ (Pass Request)** — ทุกประเภทต้องอนุมัติ (รวมพักทานข้าว)
- **อนุมัติ/ปฏิเสธคำขอ** — กรองตามแผนกของผู้อนุมัติ (department-scoped, ดู Section 6) — Admin เห็นทุกแผนก
- **Admin: แก้ไข/ลบคำขอ**
- **พิมพ์ใบลาฟอร์มบริษัท**
- **Export CSV**
- **ตั้งค่าโควต้าวันลา** (`leave_settings`)
- **Calendar วันหยุด** (`leave_holidays`)
- **เปลี่ยน PIN** (พนักงาน) / **รีเซ็ต PIN** (Admin)
- **ขอทำโอที (OT Request)** — 2 ประเภทในหน้าเดียว: ขอล่วงหน้า (advance) ก่อนทำ OT / บันทึกย้อนหลังขอเบิก (actual) หลังทำแล้ว, มีประวัติของฉันและหน้าอนุมัติแยก department-scoped เหมือน Pass (ดู Section 4/6/11 — เพิ่ม 2026-09-15)

---

## 4. ตาราง Database (System 6)

```sql
leave_types             -- ประเภทการลา (10 ประเภท)
leave_requests           -- คำขอลา (employee_id, department, type, days, status, ...)
leave_balances            -- วันลาคงเหลือต่อพนักงาน/ปี
leave_dept_supervisors    -- แมปแผนก → หัวหน้า (1 แผนกมีได้หลายคน หลัง leave_schema_v7_patch.sql — 2026-09-20)
leave_settings            -- ตั้งค่าโควต้าต่อประเภทการลา
leave_holidays            -- ปฏิทินวันหยุด (รวมวันหยุดไทย)
pass_requests             -- คำขอออกนอกบริเวณ (+ photo_url)
pass_reasons              -- เหตุผลออกนอกบริษัท + max_minutes (เวลาสูงสุดที่อนุญาต, แก้ได้จากตั้งค่าระบบ)
                          --   level1_minutes/level1_status/level2_minutes/level2_status (ขั้นรุนแรง, ทางเลือก) ⏳ ต้องรัน checkin_system/pass_schema_time_levels_patch.sql ก่อนจึงจะบันทึกติด — 2026-09-15
ot_requests               -- คำขอทำโอที (request_type: advance/actual, estimated_hours, actual_hours) — ใหม่ 2026-09-15

-- ใช้ร่วมกับระบบอื่น
checkin_employees         -- พนักงาน (+ pin_code, photo_url) — ร่วมกับ System 4
app_users                 -- ผู้ใช้ที่มี role จริง (admin/supervisor/viewer) — ร่วมกับ System 1-3
```

### SQL Files
| ไฟล์ | รายละเอียด | สถานะ |
|------|-----------|-------|
| `leave_schema.sql` | ตารางหลัก: `leave_types`, `leave_requests`, `leave_balances`, `leave_dept_supervisors`, `leave_settings` + RLS | ✅ รันแล้ว |
| `leave_schema_v2_patch.sql` | `leave_holidays` + วันหยุดไทย 2025–2026 | ✅ รันแล้ว |
| `leave_schema_v3_patch.sql` | (ดูรายละเอียดในแชตที่แก้ไข) | ⏳ ตรวจสอบสถานะรัน |
| `leave_schema_v5_patch.sql` | `ALTER TABLE checkin_employees ADD COLUMN pin_code text DEFAULT NULL;` | ✅ รันแล้ว |
| `pass_schema.sql` | ตาราง `pass_requests` | ⏳ ตรวจสอบสถานะรัน |
| `leave_schema_v6_patch.sql` | อยู่ในขอบเขตแก้ไขได้ — ยังไม่ได้ตรวจสอบเนื้อหาในแชตนี้ | ⏳ |
| `leave_schema_v7_patch.sql` | เปลี่ยน `leave_dept_supervisors` จาก PK=`department` (1 แถว/แผนก) เป็น PK=`id` (SERIAL) — รองรับหลายหัวหน้า/แผนก (ใหม่ 2026-09-20) | ⏳ ยังไม่ได้รัน |
| photo_url patch | `ALTER TABLE pass_requests ADD COLUMN IF NOT EXISTS photo_url TEXT;` | ⏳ ตรวจสอบสถานะรัน |
| `ALTER TABLE app_users ADD COLUMN IF NOT EXISTS meeting_access boolean DEFAULT false;` | จำเป็นสำหรับ System 5 (ไม่ใช่ Leave โดยตรง แต่เคยอยู่ใน checklist เดียวกัน) | ⏳ |
| `checkin_system/ot_schema.sql` | ตาราง `ot_requests` + RLS (ใหม่ 2026-09-15) | ⏳ ยังไม่ได้รัน — ต้องรันใน Supabase SQL Editor ก่อนใช้ฟีเจอร์ขอทำโอที |

---

## 5. Global State

```js
currentUser     // จาก app_users (password login) — { id, username, full_name, role, department }
currentEmp      // จาก checkin_employees (PIN quick-access) — { employee_id, full_name, department, photo_url, pin_code }
currentMode      // 'employee' | 'supervisor' | 'admin'
_empPinHash      // สถานะ PIN ระหว่างกรอก (employee mode)
```

---

## 6. RBAC System

- **`can(action)` helper:**
  - `approve` → true สำหรับ `admin` + `supervisor`
  - `admin` → true เฉพาะ `admin`
  - `viewAll` → true สำหรับ `admin` + `supervisor`
- **Department-scoped visibility (by design, ตรวจสอบแล้วว่าถูกต้องตามที่ต้องการ):**
  ทั้ง `renderDashboard()`, `renderApprovals()`, `renderPassApprovals()` ใช้ pattern เดียวกัน:
  ```js
  if (!can('admin') && currentUser?.department) {
    q = q.eq('department', currentUser.department);
  }
  ```
  → หัวหน้างาน (supervisor) เห็นเฉพาะคำขอของแผนกตัวเอง, Admin เห็นทุกแผนก
- **⚠️ ข้อสำคัญ — เส้นทาง PIN quick-access ไม่สามารถให้สิทธิ์ admin ได้:**
  `_proceedSupLogin()` hardcode `role: 'supervisor'` เสมอ ไม่ว่า `checkin_employees` แถวนั้นจะเป็นใคร — ถ้าต้องการให้ใครเป็น admin ต้อง (1) มี record ใน `app_users` ที่ `role='admin'` และ (2) ให้คนนั้น login ผ่านปุ่ม **Password** (ไม่ใช่ PIN) ในแท็บ "หัวหน้า/Admin"

---

## 7. LINE Notification

| Trigger | ปลายทาง | หมายเหตุ |
|---------|---------|---------|
| คำขอลา (`leave_requests`, status=pending) | OA HR → กลุ่ม Sanon HR 2 | มีรูปโปรไฟล์พนักงาน (`photo_url`) ในการ์ด |
| ขอออกนอกบริเวณ — pending (`pass_requests`) | OA HR → กลุ่ม Sanon HR 2 | 🟠 แจ้งหัวหน้า |
| ขอออกนอกบริเวณ — approved (walk-in) | OA Security → กลุ่ม รปภ สานนท์ | 🔵 แจ้งยาม, มีรูปโปรไฟล์ |
| คำขอโอที (`ot_requests`, status=pending) | OA HR → กลุ่ม Sanon HR 2 | ใหม่ 2026-09-15 — ส่งเฉพาะ pending เหมือน leave_requests (ไม่มีรอบ approved แยกไป รปภ.) |

- ใช้ **LINE Messaging API** (`api.line.me/v2/bot/message/push`) ผ่าน Edge Function `line-notify_index.txt` (ไฟล์ shared กับ System 1-3 — ดู Section 0B ใน `CLAUDE.md` ก่อนแก้)
- Secrets: `LINE_CHANNEL_TOKEN_HR` + `LINE_GROUP_ID_HR` (OA HR), `LINE_CHANNEL_TOKEN_SECURITY` + `LINE_GROUP_ID_SECURITY` (OA รปภ.)
- ปุ่มกดอนุมัติ/ไม่อนุมัติใน LINE การ์ด ใช้ **URI button** (ไม่ใช่ postback)

---

## 8. PWA

- `manifest-leave.json` — สร้างใหม่ 2026-09-11 (ใช้ `icon-192.png`/`icon-512.png` เดิม เพราะยังไม่มีไอคอนเฉพาะของ Leave), `theme_color: #1d4ed8`
- `<head>` ของ `leave.html` มี `<link rel="manifest">`, `apple-touch-icon`, `apple-mobile-web-app-*` meta, service-worker registration script ครบแล้ว (2026-09-11)
- **⚠️ ยังไม่ได้เพิ่มใน `sw.js` PRECACHE list** — `leave.html`/`manifest-leave.json` ยังใช้งานออฟไลน์ไม่ได้ (ต้องแก้ `sw.js` + bump `CACHE_NAME` ถ้าต้องการ — ไฟล์ shared กระทบทุกระบบ ต้องแจ้งก่อนแก้)
- ผู้ใช้ที่เคย "เพิ่มลงหน้าจอโฮม" ก่อน 2026-09-11 ต้องลบ shortcut เดิมแล้วเพิ่มใหม่เพื่อให้ไอคอนอัปเดต (ไอคอนเก่าไม่ auto-update)

---

## 9. Realtime Features (Supabase Broadcast)

ใช้ **Broadcast channel** (ไม่ใช่ `postgres_changes`) ทั้งสองทิศทาง — ไม่ต้องพึ่ง RLS auth, ไม่ต้องเปิด Realtime บนตารางเพิ่ม (แต่ยังต้องเปิด Realtime ใน Supabase Dashboard สำหรับ Broadcast เอง — ดู checklist ด้านล่าง)

### 9.1 พนักงาน ← ผลอนุมัติ/ปฏิเสธ (2026-08-22)
- Channel: `emp-notif-{employee_id}`
- `_startNotifRealtime()` / `_stopNotifRealtime()` — subscribe ตอน login / unsubscribe ตอน logout
- `_sendBroadcastNotif(employeeId, payload)` — เรียกจาก `dashApprove()`, `approveRequest()`, `rejectRequest()`, `approvePass()`, `rejectPass()`
- `_showSingleNotifPopup(...)` — แสดง modal popup ทันที
- `checkLeaveStatusNotifications()` — เช็คสถานะที่ missed ตอน login (เผื่อพลาดตอน offline)

### 9.2 หัวหน้า/Admin ← คำขอใหม่ (เพิ่ม 2026-09-11)
- Channel: `leave-approvers-notif`
- `_broadcastNewRequestToApprovers(kind, r)` — พนักงานเรียกทันทีหลัง insert `leave_requests`/`pass_requests` สำเร็จ (ใน `submitRequest()`, `submitPassRequest()`) — payload `{kind, employee_name, department, type_name, days}`
- `_startApproverRealtime()` / `_stopApproverRealtime()` — subscribe ตอน `_bootApp()` เมื่อ `can('approve')` เป็นจริง / unsubscribe ใน `doLogout()`
- `_onNewApproverRequest(payload)` — จัดการเมื่อมี broadcast เข้ามา:
  - Supervisor ได้รับแจ้งเฉพาะแผนกตัวเอง (เทียบ `currentUser.department`), Admin ได้รับทุกแผนก
  - แสดง toast `🔔 คำขอใหม่: ...`
  - อยู่หน้า `lv-approvals`/`lv-pass-approve`/`lv-ot-approve`/`lv-dashboard` → re-render อัตโนมัติ, หน้าอื่น → อัปเดตแค่ badge (`_refreshApproveBadgeOnly()`, `_refreshPassBadgeOnly()`, `_refreshOtBadgeOnly()`)
  - **2026-09-15:** ขยาย `kind` ให้รองรับ `'ot'` เพิ่มจาก `'leave'`/`'pass'` เดิม — ใช้ channel `leave-approvers-notif` ร่วมกัน ไม่ต้องเปิด channel ใหม่

> **⚠️ ต้องเปิด Realtime ใน Supabase Dashboard:** Table Editor → ตรวจว่า Realtime เปิดอยู่ (จำเป็นสำหรับ Broadcast ด้วย แม้ไม่ผูกกับตารางเฉพาะ)

---

## 10. กฎสำคัญของโค้ด

- Realtime ทุกจุดใน `leave.html` ใช้ **Broadcast** ไม่ใช่ `postgres_changes` — หลีกเลี่ยงปัญหา RLS auth
- Query ที่แสดงคำขอ (approvals/dashboard) ต้องกรองตามแผนกเสมอเมื่อ `!can('admin')` — ห้ามลบเงื่อนไขนี้ออกโดยไม่ถามคุณใหญ่ก่อน (เป็น business rule ที่ยืนยันแล้วว่าตั้งใจ)
- `_proceedSupLogin()` (PIN path) ต้อง hardcode `role: 'supervisor'` เสมอ — ห้ามเปลี่ยนให้อ่าน role จาก `checkin_employees` โดยไม่ได้คุยกับคุณใหญ่ก่อน (จะกระทบ security model)
- ไฟล์ shared ที่ `leave.html` แตะ (`sw.js`, `manifest-*.json`, `line-notify_index.txt`) ต้องแจ้งในแชตก่อนแก้ตามกฎ Section 0B ของ `CLAUDE.md`

---

## 11. Changelog

### 2026-09-22 (รอบ 16) — แก้ไข: แยกการ์ด "ออกนอกบริษัท" และ "โอที" ออกจากตารางลา + เปลี่ยนโอทีเป็นสรุปรายครึ่งเดือน (แก้ไขต่อจากรอบ 15)

**คำขอแก้ไข:** หลังจากรอบ 15 (รวม 3 หัวข้อเป็นตารางแถวเดียว) คุณใหญ่ดูผลแล้วแจ้งว่า **"ไม่ใช่ให้แยกของใครของมันดิ อย่าเอามารวมกัน"** พร้อมยกตัวอย่าง: โอทีให้สรุปทุก 15 วัน เช่น วันที่ 1-15 ได้โอทีรวม 20 ชั่วโมง วันที่ 16-31 ได้โอทีรวม 30 ชั่วโมง — ถามเพิ่มเติม 2 ข้อแล้วคุณใหญ่ยืนยัน: (1) "ออกนอกบริษัท" ให้เป็นสรุปรายครึ่งเดือนแบบเดียวกับโอที ไม่ใช่ลิสต์รายการ (2) แสดงย้อนหลัง 2 งวด = เดือนปัจจุบัน จากนั้นแจ้งว่า "ทำเป็นสรุปผล"

**สิ่งที่แก้ (`renderDashboard()`):**
- **ยกเลิกการรวมเป็นตารางเดียว** — เอา `combinedRecent`/`OT_TYPE_LABEL_SHORT` ของรอบ 15 ออกทั้งหมด
- **การ์ด "คำขอลาล่าสุด"** — กลับไปแสดงเฉพาะ `leave_requests` เหมือนเดิมก่อนรอบ 15 (ลิสต์รายการ ไม่ใช่สรุป)
- **การ์ดใหม่ "🚪 สรุปออกนอกบริษัท (รายครึ่งเดือน)"** และ **"⏱️ สรุปโอที (รายครึ่งเดือน)"** — แยกการ์ดคนละหัวข้อ ไม่ปนกับตารางลา แต่ละการ์ดแบ่ง 2 แถวตามงวดของเดือนปัจจุบัน (งวด 1: วันที่ 1-15, งวด 2: วันที่ 16-สิ้นเดือน) แสดง:
  - ยอดรวมชั่วโมง (เฉพาะรายการที่ `status='approved'` เท่านั้น) — ออกนอกบริษัทคำนวณจาก `out_time`→`expected_return` ด้วย `_passMinutesBetween()` ที่มีอยู่แล้ว, โอทีคำนวณจาก `actual_hours ?? estimated_hours`
  - จำนวนครั้งที่อนุมัติแล้ว
  - ถ้ามีรายการ `status='pending'` ในงวดนั้น แสดงกำกับแยกต่างหาก ("⏳ รออนุมัติ N รายการ") ไม่รวมเข้ายอดชั่วโมง
- เปลี่ยน query `pass_requests`/`ot_requests` ใน `Promise.all` จาก "ล่าสุด 5 รายการ" (รอบ 15) เป็น "ทั้งหมดในเดือนปัจจุบัน" (`gte/lte` ช่วง `monthStartStr`–`monthEndStr`) เพื่อใช้คำนวณผลรวมรายงวดแทน
- สีการ์ด: ออกนอกบริษัทใช้สีเหลืองอำพัน `#ea9d0a` (ตรงกับสี bottom-nav เดิมของเมนูนี้), โอทีใช้สีเขียวเทียล `#0f766e` (ตรงกับสี bottom-nav เดิมของเมนูนี้) — ให้ตรงกับโทนสีที่ใช้อยู่แล้วในระบบ

**ขอบเขตที่ยังไม่แตะ:** ส่วน "วันลาคงเหลือ" (quota bar) และปุ่ม "ดูทั้งหมด" ยังคงเดิม (ลิงก์ไปหน้าประวัติแยกของแต่ละหัวข้อ: `lv-my-hist` / `lv-pass-hist` / `lv-ot-hist`), การขยาย `statusBadge()` ให้รองรับสถานะ `out`/`returned` จากรอบ 15 คงไว้ (ไม่กระทบอะไร แม้ปัจจุบันยังไม่มีจุดเรียกใช้กับสถานะนี้บนหน้า dashboard)

**Deploy:** `leave.html` main + `GitHub/` = 289,311 bytes (จากรอบ 15 = 286,178 bytes) ตรงกันทั้งสองชุด, `node --check` ผ่านทั้งใน container และบนเครื่อง

---

### 2026-09-22 (รอบ 15) — เพิ่มสรุป "ออกนอกบริษัท" และ "โอที" เข้าตาราง "คำขอล่าสุด" ในหน้าแดชบอร์ด (⚠️ ถูกแก้ไขในรอบ 16 — ดูด้านบน)

**คำขอ:** คุณใหญ่ส่งภาพหน้าแดชบอร์ด (มีวันลาคงเหลือ + ตาราง "คำขอล่าสุด" ที่ว่างเปล่า) ถามว่า "ในหน้า DB เราไม่ได้ทำสรุปการลา ออกนอกบริษัท โอทีใช่ไหม" → ตรวจโค้ด `renderDashboard()` พบว่าดึงข้อมูลจาก `leave_requests` เพียงตารางเดียว ไม่ได้ดึง `pass_requests` (ออกนอกบริษัท) หรือ `ot_requests` (โอที) มาแสดงเลย → คุณใหญ่ยืนยันให้แก้ ("จัดมา")

**สาเหตุที่ตาราง "คำขอล่าสุด" ว่าง:** ระบบเก็บ "ลา" / "ออกนอกบริษัท" / "โอที" ไว้คนละตาราง (`leave_requests`, `pass_requests`, `ot_requests`) แต่ Dashboard ดึงมาแสดงเฉพาะ `leave_requests` — พนักงานที่มีแต่ประวัติออกนอก/โอที (ไม่มีประวัติลา) จึงเห็นตารางว่างแม้จะมีคำขอจริงอยู่ในระบบ

**สิ่งที่แก้ (`renderDashboard()`):**
- เพิ่ม query ดึง `pass_requests` และ `ot_requests` (5 รายการล่าสุดของตัวเอง เรียงตาม `created_at`) เข้าไปใน `Promise.all` เดิม
- รวมผลลัพธ์ทั้ง 3 ตาราง (ลา/ออกนอก/โอที) เป็น array เดียว normalize เป็นโครงสร้าง `{icon, typeLabel, dateLabel, qtyLabel, status, sortKey}` แล้วเรียงตาม `created_at` ล่าสุดก่อน ตัดเหลือ 8 รายการบนสุด
  - ลา: ไอคอนตาม `_typeIcon()`, วันที่ = ช่วงวันลา, จำนวน = X วัน
  - ออกนอกบริษัท: ไอคอน 🚪, ชื่อเหตุผล, วันที่ = `request_date`, จำนวน = เวลาออก→เวลากลับ
  - โอที: ไอคอน ⏱️, ประเภท (ล่วงหน้า/ย้อนหลัง), วันที่ = `ot_date`, จำนวน = ชั่วโมงประมาณการ
- เปลี่ยนหัวการ์ดจาก "📄 คำขอล่าสุด" → "📄 คำขอล่าสุด (ลา · ออกนอก · โอที)" ให้ชัดเจนว่ารวม 3 หัวข้อ
- ขยาย `statusBadge()` ให้รองรับสถานะเฉพาะของ `pass_requests` ที่ `leave_requests`/`ot_requests` ไม่มี คือ `out` (🚪 กำลังออก) และ `returned` (🏭 กลับแล้ว) — เดิม fallback เป็นข้อความสถานะดิบ

**ขอบเขตที่ยังไม่แตะ:** ส่วน "วันลาคงเหลือ" (quota bar) ยังกรองเฉพาะประเภทลาเหมือนเดิม (ไม่รวมออกนอก/โอทีที่ไม่มีโควตาแบบเดียวกัน), ปุ่ม "ดูทั้งหมด" ยังลิงก์ไปหน้า "ประวัติของฉัน" (leave history) เหมือนเดิม — หน้ารายงานรวม 3 หัวข้อแบบสรุปรายปี (`renderReport()` / เมนู "รายงาน") มีอยู่แล้วแยกต่างหาก จำกัดสิทธิ์เฉพาะ Admin/HR

**Deploy:** `leave.html` main + `GitHub/` = 286,178 bytes (เดิม 283,887 bytes) ตรงกันทั้งสองชุด, `node --check` ผ่านทั้งใน container และบนเครื่อง

---

### 2026-09-22 (รอบ 14) — เปลี่ยนสวิตช์ "เปลี่ยนระบบ" เป็นการ์ดสีสัน (เหมือน index.html) + ตัด Portal ออก

**คำขอ:** คุณใหญ่ส่งภาพสวิตช์ "เปลี่ยนระบบ" แบบการ์ดสีสัน 6 ใบของ index.html ถามว่าที่ทำไว้ (รอบ 13 — แบบลิสต์รายการธรรมดา) หน้าตาเหมือนภาพนี้ไหม → ตอบว่าไม่เหมือน (ทำเป็นลิสต์ธรรมดาตามสไตล์ sidebar เดิมของไฟล์ ไม่ใช่การ์ด) → คุณใหญ่ขอให้ทำให้เหมือนภาพ → ระหว่างทำ คุณใหญ่แจ้งเพิ่มว่า "เอา portal ออก"

**การแก้ไข:**
- แทนที่ HTML ของ section `sb-sec-switch` จาก `.sb-link` (ลิสต์รายการ) เป็น grid การ์ด 3 คอลัมน์ (`.sys-switch-grid`/`.sys-card`) สีไล่เฉด (gradient) ต่อระบบ ตรงกับโทนสีที่ index.html ใช้ทุกจุด: ผลิต (น้ำเงิน #1d4ed8→#2563eb), คลัง (เขียวมิ้นท์ #0f766e→#0d9488), PM (ส้ม #b45309→#d97706), HR (เขียว #065f46→#059669), จองห้อง (ฟ้า #0e7490→#0284c7)
- **ตัด Portal ออกจากสวิตช์** ตามที่คุณใหญ่แจ้งเพิ่มเติม (รอบ 13 เคยใส่ไว้) — เหลือ 5 การ์ด: ผลิต, คลัง, PM, HR, จองห้อง (ไม่รวมตัวเอง "ขอลา")
- เพิ่ม CSS ใหม่ (`.sys-switch-grid`, `.sys-card`, `.sys-card-icon`, `.sys-card-label`) เป็น plain CSS grid ธรรมดา ไม่ใช้ Tailwind (แม้ leave.html จะโหลด Tailwind CDN ไว้ แต่ sidebar เดิมใช้ CSS ของตัวเองทั้งหมด จึงทำให้สอดคล้องกับไฟล์เดิม)
- ตรรกะการแสดง/ซ่อน (`currentMode==='supervisor' && !currentEmp`, เงื่อนไขจองห้องประชุม) **ไม่เปลี่ยนแปลง** จากรอบ 13 — แก้เฉพาะรูปลักษณ์การแสดงผล

**ตรวจสอบแล้ว:** extract inline `<script>` แล้วรัน `node --check` ผ่านทั้งไฟล์ต้นทางและไฟล์บนเครื่องหลัง commit, เทียบขนาดไฟล์ + `diff` ระหว่าง `leave.html` กับ `GitHub/leave.html` ตรงกันทุกไบต์ (283,887 ไบต์), grep ยืนยันไม่มี `gotoSystem('portal.html')` เหลืออยู่แล้ว

**ไฟล์ที่แก้ไข:** `leave.html`, `LEAVE.md`
**Copy ไป GitHub/:** `leave.html` ✅

---



### 2026-09-22 (รอบ 13) — เพิ่มสวิตช์ "เปลี่ยนระบบ" เชื่อมไปทุกระบบ (leave.html เดิมไม่มีสวิตช์นี้เลย)

**คำขอ:** ให้ตรวจสอบ/เพิ่มลิงก์ในสวิตช์ "เปลี่ยนระบบ" ให้ครบทุกระบบ (7 ไฟล์: index.html/inventory.html/pm.html/checkin.html/meeting.html/leave.html/portal.html) ใช้ pattern `gotoSystem(url)` เดียวกับ index.html เพื่อให้ SSO session ทำงานข้ามระบบ ไม่ใช้ `<a href>` เฉยๆ

**ตรวจสอบก่อนแก้ไข:** `leave.html` ไม่มีสวิตช์ "เปลี่ยนระบบ" อยู่เลย (ไม่มีฟังก์ชัน `gotoSystem`, ไม่มีลิงก์ไปหาระบบอื่นใดๆ ในหน้าเว็บทั้งไฟล์)

**พบประเด็นสำคัญที่ต้องระวัง (ไม่ใช่ทุก "supervisor" ใน leave.html เป็นบัญชี app_users จริง):**
leave.html มี 2 ทางล็อกอินที่ตั้ง `currentMode='supervisor'` เหมือนกัน แต่เป็นคนละบัญชีกันโดยสิ้นเชิง —
1. `doLogin()` — login ด้วย username/password จากตาราง **`app_users`** (บัญชีเดียวกับ System 1/2/3/Portal) → มี `id` ที่ถูกต้องสำหรับส่ง SSO ข้ามระบบได้จริง
2. `_proceedSupLogin()` — login ด้วย PIN 4 หลักจากตาราง **`checkin_employees`** (ฟีเจอร์ "หัวหน้า login ด้วย PIN" ที่เพิ่มไว้ก่อนหน้านี้) → `currentUser.id` เป็น `employee_id` จาก checkin_employees ไม่ใช่ `app_users.id` — ถ้าส่งเป็น SSO ไปให้ระบบอื่น จะเป็นการยัด id ปลอมเข้าไปใน session ของระบบอื่น (ระบบอื่นคาดหวัง id จาก app_users)

แยกสองเคสนี้ด้วยการเช็ค `currentEmp` — ฟังก์ชัน `_proceedSupLogin()` เพียงจุดเดียวที่ตั้งค่า `currentEmp` พร้อม `currentMode='supervisor'` (ส่วน `doLogin()` ไม่แตะ `currentEmp` เลย) จึงใช้ `currentMode==='supervisor' && !currentEmp` เป็นตัวเช็คว่าเป็นบัญชี app_users จริงหรือไม่

**การแก้ไข (`leave.html`):**
- เพิ่ม field `factory`, `meeting_access`, `_extraManage` ให้ `currentUser` ใน `doLogin()` (ดึงจาก `app_users` row ที่ query มาอยู่แล้ว) — ใช้สำหรับส่งต่อ SSO และเช็คสิทธิ์จองห้องประชุม
- เพิ่ม sidebar section ใหม่ `id="sb-sec-switch"` (ซ่อนไว้ก่อน) มีลิงก์ไป: Portal, ระบบผลิต (index.html), ระบบคลัง (inventory.html), ระบบ PM (pm.html), งานบุคคล/HR (checkin.html), จองห้องประชุม (meeting.html — ซ่อนไว้ก่อน แสดงเมื่อมีสิทธิ์)
- เพิ่มฟังก์ชัน `gotoSystem(url)` — **เขียน SSO session (sessionStorage: `_sn_inv_sess`/`_sn_pm_sess`/`_sn_sess`) เฉพาะกรณี `currentMode==='supervisor' && !currentEmp`** (บัญชี app_users จริงเท่านั้น) ตามแพทเทิร์นเดียวกับ index.html/pm.html — กรณี login ด้วย PIN จะแค่เปลี่ยนหน้าเฉยๆ ไม่ส่ง session ปลอม
- gating การแสดงผล: `sb-sec-switch` แสดงเมื่อ `currentMode==='supervisor' && !currentEmp` เท่านั้น (ซ่อนทั้งโหมดพนักงาน (`currentMode==='employee'`) และโหมด PIN-login เพราะไม่มีประโยชน์ข้ามระบบจริง) — ลิงก์จองห้องประชุมแสดงเพิ่มเมื่อ `currentUser.meeting_access || currentUser.role==='admin'`

**หมายเหตุ:** ไม่ได้เพิ่มลิงก์กลับ `leave.html` เอง (ไม่นับตัวเองตามที่ขอ) — Portal ที่มักตกหล่นได้ใส่ลิงก์ไว้ครบแล้ว

**ตรวจสอบแล้ว:** extract inline `<script>` แล้วรัน `node --check` ผ่านทั้งไฟล์ต้นทางและไฟล์บนเครื่องหลัง commit, เทียบขนาดไฟล์ + `diff` ระหว่าง `leave.html` กับ `GitHub/leave.html` ตรงกันทุกไบต์ (282,863 ไบต์)

**ไฟล์ที่แก้ไข:** `leave.html`, `LEAVE.md`
**Copy ไป GitHub/:** `leave.html` ✅

---



### 2026-09-20 (รอบ 12) — รองรับ "หัวหน้าแต่ละแผนก" ได้หลายคนต่อ 1 แผนก

**คำขอ:** คุณใหญ่ส่งภาพหน้า "หัวหน้าแต่ละแผนก" (หน้าตั้งค่าระบบ) ถามว่าสามารถเพิ่มหัวหน้าได้หลายคนต่อ 1 แผนกหรือไม่

**ตรวจสอบก่อนแก้ไข:** พบว่าตาราง `leave_dept_supervisors` เป็นแค่ทำเนียบรายชื่อ (แสดงผลในหน้าตั้งค่าเท่านั้น ไม่ถูกอ้างอิงที่อื่นในระบบ) — ส่วนสิทธิ์การอนุมัติจริงมาจากแผนกที่ผูกไว้กับบัญชี `app_users` แต่ละคน ซึ่งรองรับหลายคนต่อแผนกอยู่แล้วโดยไม่ต้องแก้โค้ด (ผ่านเมนู "จัดการผู้ใช้") — ได้ถามคุณใหญ่ยืนยันแล้วว่าต้องการแก้ที่ตาราง "หัวหน้าแต่ละแผนก" นี้โดยตรงให้แสดง/บันทึกได้หลายคน (ไม่ใช่แค่ใช้กลไกบัญชีผู้ใช้)

**ข้อจำกัดเดิม:** `leave_dept_supervisors.department` เป็น PRIMARY KEY → บันทึกได้แผนกละ 1 แถว (1 คน) เท่านั้น การบันทึกซ้ำจะ upsert ทับคนเดิม

**DB — SQL Patch ใหม่ (`leave_schema_v7_patch.sql`, ยังไม่ได้รัน):**
- ถอด PRIMARY KEY เดิมที่ผูกกับ `department` ออก
- เพิ่มคอลัมน์ `id SERIAL` เป็น PK ใหม่แทน (แถวเดิมได้เลขรันอัตโนมัติให้ทันที ไม่มีข้อมูลหาย)
- สร้าง index บน `department` แทน index ที่หายไปจาก PK เดิม
- RLS เดิม (`anon_all`) ใช้ต่อได้เลย ไม่ต้องแก้

**`leave.html` — การแก้ไข:**
- หน้า "ตั้งค่าระบบ" → การ์ด "หัวหน้าแต่ละแผนก": จัดกลุ่มแสดงหัวหน้าทุกคนของแต่ละแผนกไว้ในแถวเดียวกัน (แต่ละคนมีปุ่ม "แก้ไข"/"ลบ" ของตัวเอง) + ปุ่ม "+ เพิ่มหัวหน้า" ต่อแผนกสำหรับเพิ่มคนใหม่โดยไม่ลบคนเดิม
- `editDeptSupervisor(dept, id)` — เพิ่มพารามิเตอร์ `id`: ไม่ระบุ = เปิดฟอร์มเพิ่มหัวหน้าใหม่, ระบุ = โหลดข้อมูลคนนั้นมาแก้ไข (เปลี่ยนจาก `.single()` เป็น `.maybeSingle()` ตาม `id`)
- `saveDeptSupervisor(dept, id)` — เปลี่ยนจาก `upsert(onConflict:'department')` (ทับคนเดิมเสมอ) เป็น `insert` แถวใหม่ (กรณีเพิ่ม) หรือ `update` ตาม `id` (กรณีแก้ไข) — เพิ่มการตรวจสอบ error จาก Supabase และแสดงข้อความแจ้งถ้าบันทึกไม่สำเร็จ (เช่น ยังไม่ได้รัน SQL patch)
- เพิ่มฟังก์ชันใหม่ `deleteDeptSupervisor(id, dept)` — ลบหัวหน้าเฉพาะคน (มี native confirm ยืนยันก่อนลบ ตามแพทเทิร์นเดียวกับ `deleteQuota`)

**ตรวจสอบแล้ว:** extract inline `<script>` แล้วรัน `node --check` ผ่านทั้งไฟล์ต้นทางและไฟล์บนเครื่องหลัง commit, เทียบขนาดไฟล์ + `diff` ระหว่าง `leave.html` กับ `GitHub/leave.html` ตรงกันทุกไบต์ (279,416 ไบต์)

**⏳ สิ่งที่ต้องทำก่อนใช้งานจริง:**
1. รัน `leave_schema_v7_patch.sql` ใน Supabase SQL Editor ก่อน — ถ้ายังไม่รัน จะเพิ่มหัวหน้าคนที่ 2 ขึ้นไปให้แผนกเดียวกันไม่ได้ (ติด PRIMARY KEY เดิม จะมี error message แจ้งในฟอร์มให้ทราบ) — เพิ่มหัวหน้าคนแรกของแผนกที่ยังว่างยังทำได้ปกติแม้ยังไม่รัน patch

**ไฟล์ที่แก้ไข:** `leave.html`, `leave_schema_v7_patch.sql` (ใหม่), `LEAVE.md`
**Copy ไป GitHub/:** `leave.html` ✅ | `leave_schema_v7_patch.sql` ✅ (เก็บสำเนาไว้อ้างอิง — ไม่ต้องรันผ่าน GitHub Pages)

---



### 2026-09-15 (รอบ 2) — เพิ่มระบบ "ขอทำโอที" (OT Request) — ขอล่วงหน้า + บันทึกย้อนหลัง

**คำขอ:** คุณใหญ่ถามว่าเพิ่มหัวข้อระบบขอทำโอทีได้ไหม — ยืนยันให้อยู่ใน `leave.html` (System 6) ใช้ pattern คำขอ→อนุมัติ→แจ้งเตือน LINE เดียวกับลา/Pass และต้องการทั้ง 2 รูปแบบคำขอ (ขอล่วงหน้า + บันทึกย้อนหลังขอเบิก)

**DB — ตารางใหม่ `ot_requests` (`checkin_system/ot_schema.sql`, ยังไม่ได้รัน):**
- `request_type` ('advance'|'actual'), `ot_date`, `start_time`, `end_time`, `estimated_hours`, `is_holiday`, `reason`, `status`, approval fields (เหมือน pass_requests), `actual_hours` (สำหรับ payroll)
- RLS `anon_all` เหมือนตารางอื่นในระบบ

**`leave.html` — การเปลี่ยนแปลง:**

**1. Sidebar — เพิ่มหมวดใหม่ "โอที":**
- `sb-lv-ot` (ขอทำโอที), `sb-lv-ot-hist` (ประวัติโอทีของฉัน), `sb-lv-ot-approve` (อนุมัติโอที — ซ่อนไว้ก่อน แสดงเมื่อ `can('approve')` ใน `_bootApp()`)
- เพิ่ม `PAGE_TITLES` + case ใน router (`navigateTo`) สำหรับ 3 หน้าใหม่ — ไม่ได้เพิ่มใน bottom-nav มือถือ (ตามแบบ Pass ที่หน้ารองก็ไม่อยู่ใน bottom-nav)

**2. `renderOtRequest()` + `submitOtRequest()`:**
- Toggle ประเภทคำขอ 2 ปุ่ม (`selectOtType()`): "ขอล่วงหน้า" (วันที่ ≥ วันนี้) / "บันทึกย้อนหลัง" (วันที่ ≤ วันนี้, โชว์ช่องกรอกชั่วโมงจริงสำหรับเบิก)
- คำนวณชั่วโมงอัตโนมัติจากเวลาเริ่ม-สิ้นสุด (`_otHoursBetween()` รองรับกรณีข้ามเที่ยงคืน)
- Insert → `sendOtLineNotify()` + `_broadcastNewRequestToApprovers('ot', payload)`

**3. `renderMyOtHistory()` / `cancelOtRequest()`** — เหมือนแพทเทิร์นประวัติ Pass

**4. `renderOtApprovals()` / `approveOt()` / `rejectOt()`** — department-scoped เหมือน `renderPassApprovals()`, อัปเดต badge `sb-badge-ot`

**5. ขยาย Realtime เดิม (ไม่ได้เปิด channel ใหม่):**
- `_broadcastNewRequestToApprovers()` รองรับ `kind='ot'`
- `_onNewApproverRequest()` แยกเคส `kind==='ot'` → re-render `lv-ot-approve` หรือ `_refreshOtBadgeOnly()`

**`line-notify_index.txt` (Edge Function shared กับ System 1-3 — แจ้งในแชตตามกฎ Section 0B):**
- เพิ่ม `buildOtRequestCard()` — การ์ดสีเขียวอมฟ้า ส่งเฉพาะ `status='pending'` ไปกลุ่ม HR (เหมือน `leave_requests`, ไม่มีรอบ approved แยกไป รปภ. เพราะ OT ไม่เกี่ยวกับการออกนอกบริเวณ)
- เพิ่ม handler `table === "ot_requests"` ใน main serve()

**ตรวจสอบแล้ว:** `node --check` ผ่าน (leave.html), `tsc --noEmit` ไม่พบ syntax error ใหม่ใน `line-notify_index.txt` (error ที่เหลือเป็น Deno/lib environment เดิมของไฟล์ ไม่เกี่ยวกับโค้ดที่เพิ่ม)

**⏳ สิ่งที่ต้องทำก่อนใช้งานจริง:**
1. รัน `checkin_system/ot_schema.sql` ใน Supabase SQL Editor
2. Deploy Edge Function `line-notify` เวอร์ชันล่าสุด (มี `buildOtRequestCard`)
3. Upload `leave.html` + `line-notify_index.txt` ขึ้น GitHub Pages / Supabase

**ไฟล์ที่แก้ไข:** `leave.html`, `line-notify_index.txt`, `checkin_system/ot_schema.sql` (ใหม่), `LEAVE.md`
**Copy ไป GitHub/:** `leave.html` ✅ | `line-notify_index.txt` ✅ | `ot_schema.sql` — ไม่ต้อง copy (รันตรงใน Supabase ไม่ใช่ asset ที่ deploy ผ่าน GitHub Pages)

---

### 2026-09-19 (รอบ 10) — เพิ่มการแจ้งเตือนหัวหน้า/Admin: สรุปคำขอค้างอนุมัติตอนเข้าระบบ + Desktop Notification

**คำขอ:** คุณใหญ่ส่งภาพหน้าจอหน้า "อนุมัติโอที" ที่มีคำขอค้างอยู่ 2 รายการ แจ้งว่า "ระบบไม่มีป๊อปอัพแจ้งเตือนว่ามีคำขอมา" — สอบถามเพิ่มเติมพบว่า: หัวหน้าเพิ่งเปิดเข้าหน้าเว็บ (ไม่ได้เปิดค้างไว้ตอนคำขอเข้ามา) แต่ไม่มีป๊อปอัพใดๆ แจ้งว่ามีคำขอรออนุมัติอยู่ ต้องกดเข้าไปเช็คแต่ละเมนูอนุมัติเองถึงจะเห็น

**สาเหตุ:** ระบบเดิมมีกลไก Realtime broadcast (`_startApproverRealtime`/`_onNewApproverRequest`) ที่เด้ง toast แจ้งเตือนได้ก็ต่อเมื่อ **คำขอใหม่เข้ามาขณะเปิดหน้าเว็บค้างไว้อยู่แล้วเท่านั้น** — ไม่มีกลไกสรุปแจ้งคำขอที่ "ค้างอยู่ก่อนแล้ว" ตอนหัวหน้าเพิ่งล็อกอินเข้าระบบ (มีแค่ตัวเลข badge บนเมนูซึ่งไม่มีความโดดเด่นพอ) และ toast เดิมก็เห็นเฉพาะตอนแท็บ/หน้าต่างเปิดอยู่ตรงหน้าเท่านั้น สลับแท็บไปทำงานอื่นจะพลาดการแจ้งเตือนไปเลย

**`leave.html` — การแก้ไข (เลือกทำตามที่คุณใหญ่ยืนยัน: ทำทั้ง 2 ข้อ):**
1. **ป๊อปอัพสรุปคำขอค้างอนุมัติตอนเข้าระบบ** — เพิ่มฟังก์ชัน `_checkApproverPendingSummary()` เรียกอัตโนมัติ 800ms หลังหัวหน้า/Admin ล็อกอินเข้าระบบ ดึงจำนวนคำขอ pending ทั้ง 3 ประเภท (ลา/Pass/โอที ตามขอบเขตแผนกที่มีสิทธิ์เห็น) พร้อมกัน หากมีคำขอค้างอยู่จะเด้ง modal สรุปจำนวนแยกตามประเภท คลิกแต่ละรายการเพื่อไปหน้าอนุมัตินั้นได้ทันที
2. **Desktop Notification** — เพิ่มปุ่ม 🔔 บน topbar (เห็นเฉพาะหัวหน้า/Admin) สำหรับเปิด/ตรวจสอบสิทธิ์แจ้งเตือนของเบราว์เซอร์ (`_toggleDesktopNotifPermission`, `_requestDesktopNotifPermission`, `_updateNotifToggleIcon`) — เมื่อได้รับอนุญาตแล้ว ทั้งคำขอใหม่ที่เข้ามาแบบ Realtime (`_onNewApproverRequest`) และสรุปคำขอค้างตอนล็อกอิน จะเด้งแจ้งเตือนระดับ Desktop (`_showDesktopNotification`) ให้เห็นแม้สลับแท็บ/ย่อหน้าต่างเบราว์เซอร์ไปทำงานอื่น (ระบบเช็ค `document.visibilityState`/`hasFocus()` ก่อน — ถ้ากำลังเปิดหน้าเว็บโฟกัสอยู่แล้วจะไม่เด้งซ้ำกับ toast/modal ในหน้าเว็บ)

**หมายเหตุ:** สิทธิ์ Desktop Notification เป็นของเบราว์เซอร์ต่อเครื่อง/ต่อผู้ใช้ — หัวหน้าแต่ละคนต้องกดปุ่ม 🔔 (หรือรอ prompt อัตโนมัติตอนล็อกอินครั้งแรก) เพื่ออนุญาตเองครั้งแรกในเบราว์เซอร์ที่ใช้งาน ถ้าเบราว์เซอร์บล็อกไว้ก่อนหน้านี้ ต้องไปเปิดสิทธิ์จากการตั้งค่าเบราว์เซอร์เอง (ปุ่มจะแจ้งเตือนกรณีนี้ให้)

**ตรวจสอบแล้ว:** extract inline `<script>` แล้วรัน `node --check` ผ่าน

**ไฟล์ที่แก้ไข:** `leave.html`, `LEAVE.md`
**Copy ไป GitHub/:** `leave.html` ✅

---

### 2026-09-19 (รอบ 11) — เปิดให้พนักงานยื่นคำขอลาย้อนหลังได้ (ลบข้อจำกัดวันที่ขั้นต่ำ)

**คำขอ:** คุณใหญ่ส่งภาพหน้าจอฟอร์ม "ยื่นคำขอลา" ฝั่งพนักงาน พบว่าวันที่ก่อนวันนี้ถูกเทาไว้เลือกไม่ได้บนปฏิทิน ถามว่าตั้งใจไม่ให้ลาย้อนหลังใช่ไหม และขอให้เพิ่มความสามารถนี้

**สาเหตุ:** ช่อง `#req-start` และ `#req-end` มี attribute `min="${today}"` กำหนดไว้ ทำให้ date picker ของเบราว์เซอร์บล็อกวันที่ก่อนวันนี้ทั้งหมด

**`leave.html` — การแก้ไข (ยืนยันกับคุณใหญ่แล้ว: ลบข้อจำกัดออกทั้งหมด ไม่จำกัดจำนวนวันย้อนหลัง และไม่ต้องแยกแสดงผลให้หัวหน้าเห็นความแตกต่างจากคำขอลาปกติ):**
1. ลบ attribute `min="${today}"` ออกจากทั้ง `#req-start` และ `#req-end` (บรรทัด ~1529, 1533) — พนักงานเลือกวันที่ย้อนหลังได้อิสระแล้ว ค่า default ยังเป็นวันนี้เหมือนเดิม
2. ไม่แตะ logic การคำนวณวันลา (`_calcDays`), การเช็คโควต้า, หรือ flow การอนุมัติ — คำขอลาย้อนหลังเข้าสู่ระบบอนุมัติแบบเดียวกับคำขอลาปกติทุกประการ (ตามที่คุณใหญ่ยืนยันว่าไม่ต้องการให้หัวหน้าเห็นความแตกต่าง)

**หมายเหตุ:** `#pass-date` และ `#ot-date` (ฟอร์มขอออกนอกบริษัท/โอที) ยังคงมี `min="${todayISO}"` เหมือนเดิม — ไม่ได้ถูกขอให้แก้ในรอบนี้ (ฝั่ง OT มีโหมด "บันทึกย้อนหลัง" แยกอยู่แล้วซึ่งอนุญาตวันที่ในอดีตอยู่แล้ว)

**ตรวจสอบแล้ว:** extract inline `<script>` แล้วรัน `node --check` ผ่าน

**ไฟล์ที่แก้ไข:** `leave.html`, `LEAVE.md`
**Copy ไป GitHub/:** `leave.html` ✅

---

### 2026-09-15 (รอบ 9) — ตรวจสอบ + แก้ไข: ตั้งค่า "เวลาสูงสุดที่อนุญาต" ต่อเหตุผลออกนอกบริษัท

**คำขอ:** คุณใหญ่ส่งภาพหน้าจอการ์ดเหตุผลในฟอร์ม "ขอออกนอกบริษัท" (ทานข้าว 60 นาที, ธุระส่วนตัว 120 นาที, พบแพทย์ 240 นาที, ออกรถ/ส่งของ 120 นาที, อื่นๆ 120 นาที) ถามว่าเพิ่มหัวข้อตั้งเงื่อนไขเวลานี้ในตั้งค่าระบบได้ไหม

**ตรวจสอบพบว่ามีหัวข้อนี้อยู่แล้ว** ในตั้งค่าระบบ ("⏱ กำหนดเวลาออกนอกบริษัทตามเหตุผล" ใต้การ์ด "ประเภทการลา") แต่พบปัญหา 2 จุดที่ทำให้ใช้งานไม่ได้ตามที่ควร:
1. **ช่องกรอกค่าว่างเปล่าตอนโหลด** — ฟอร์มดึงค่าจาก `level1_minutes` เท่านั้น แต่ค่าจริงที่แสดงบนการ์ด (60/120/240 นาที) มาจาก `max_minutes` คนละคอลัมน์กัน ทำให้แอดมินเห็นช่องว่างและเข้าใจผิดว่ายังไม่เคยตั้งค่า
2. **บันทึกอาจล้มเหลวเงียบๆ** — `savePassTimeRules()` เดิมไม่เช็ค error จาก Supabase เลย และพยายาม update คอลัมน์ `level1_minutes/level1_status/level2_minutes/level2_status` ซึ่ง**ยังไม่มีอยู่จริงในตาราง** `pass_reasons` (schema เดิมมีแค่ `max_minutes`) — ถ้าคอลัมน์เหล่านี้ไม่มีจริง การ update ทั้งก้อนจะ error และไม่มีอะไรถูกบันทึกเลยแม้แต่ "เวลาสูงสุดที่อนุญาต" แต่ระบบเงียบแล้วโชว์ "บันทึกสำเร็จ" ให้แอดมินเข้าใจผิด

**`leave.html` — การแก้ไข:**
1. เปลี่ยน label หัวตาราง/คำอธิบายให้ชัดเจนขึ้น: "ระดับ 1"→"เวลาสูงสุดที่อนุญาต (นาที)" (ค่านี้คือค่าที่พนักงานเห็นบนการ์ด), "ระดับ 2"→"ขั้นรุนแรง (นาที)" (ฟีเจอร์เสริม แยกจากเวลาสูงสุด)
2. แก้ค่าเริ่มต้นในช่องกรอกเป็น `level1_minutes || max_minutes` — ตอนนี้โหลดมาแสดงค่าจริงที่ใช้งานอยู่ถูกต้อง ไม่ว่างเปล่า
3. `savePassTimeRules()` ปรับเป็น 2 ชั้น — ลอง update/insert พร้อมฟิลด์ระดับ 2 ก่อน ถ้า error (เพราะคอลัมน์ยังไม่มี) จะ fallback ไป update/insert เฉพาะฟิลด์หลัก (`max_minutes` ฯลฯ) แทนทันที การันตีว่า "เวลาสูงสุดที่อนุญาต" บันทึกติดเสมอไม่ว่าจะรัน patch SQL ด้านล่างแล้วหรือยัง และเพิ่มการเช็ค error จริง — ถ้าล้มเหลวจะแจ้งชื่อรายการที่ไม่สำเร็จแทนที่จะโชว์ "สำเร็จ" เท็จๆ

**SQL ใหม่ (ทางเลือก, ไม่รันก่อนก็ใช้ "เวลาสูงสุดที่อนุญาต" ได้ทันที):** `checkin_system/pass_schema_time_levels_patch.sql` — เพิ่มคอลัมน์ `level1_minutes/level1_status/level2_minutes/level2_status` ให้ตาราง `pass_reasons` จำเป็นเฉพาะถ้าต้องการใช้ฟีเจอร์ "ขั้นรุนแรง (ระดับ 2)" ด้วย — ไม่ copy ไป `GitHub/` (รันตรงใน Supabase SQL Editor)

**ตรวจสอบแล้ว:** extract inline `<script>` แล้วรัน `node --check` ผ่าน

**ไฟล์ที่แก้ไข:** `leave.html`, `checkin_system/pass_schema_time_levels_patch.sql` (ใหม่), `LEAVE.md`
**Copy ไป GitHub/:** `leave.html` ✅ | `pass_schema_time_levels_patch.sql` — ไม่ต้อง copy (SQL รันตรงใน Supabase)

---

### 2026-09-15 (รอบ 8) — แก้บั๊ก: เมนู hamburger (มือถือ) ค้างเป็น overlay ทับเนื้อหา

**คำขอ:** คุณใหญ่ส่งภาพหน้าจอ 2 รูป (หน้า "ตั้งค่าระบบ") พบว่าแถบเมนูด้านซ้าย (sidebar) ค้างทับเนื้อหาอยู่ ทำให้เนื้อหาฝั่งซ้าย (เช่น ลิงก์ GitHub Pages, คอลัมน์แรกของตารางประเภทการลา) ถูกบังมองไม่เห็น

**Root cause:** `toggleMobileMenu()` (เดิม) เปิดเมนู sidebar บนมือถือด้วยการตั้ง inline style `position:fixed;zIndex:200` ให้ลอยทับหน้าจอ — แต่ตัวปิดเดิม (listener แยกต่างหากท้ายไฟล์ ผูกกับ `.sb-link` เท่านั้น) เช็คเงื่อนไข `window.innerWidth<=768` ตอนคลิกแต่ละครั้ง และรีเซ็ตไม่ครบ (ลบแค่ `display`ไม่ได้ลบ `position/top/left/zIndex`) เมื่อขนาดหน้าจอเปลี่ยนไปหลังเปิดเมนู (เช่น หมุนจอ/ย่อ-ขยายหน้าต่าง) เงื่อนไขความกว้างจะไม่ตรงอีกต่อไป ทำให้เมนูค้างเป็น overlay ทับเนื้อหาถาวร แก้ไม่ได้จากปุ่ม ☰ เพราะปุ่มอยู่ใน topbar (z-index 50) ซึ่งถูกเมนู (z-index 200) บังไปด้วย

**`leave.html` — การแก้ไข:**
1. เพิ่ม `#sidebar-backdrop` — ฉากหลังโปร่งแสง (z-index 190, ต่ำกว่าเมนู) แตะเพื่อปิดเมนูได้ทันที แก้ปัญหาปุ่ม ☰ ถูกบังไม่ให้กดปิดได้
2. แยก `toggleMobileMenu()` เดิมออกเป็น `openMobileMenu()` / `closeMobileMenu()` ที่ชัดเจน — `closeMobileMenu()` เช็คจาก `sb.style.position==='fixed'` (สถานะจริงของเมนู) แทนการเช็คความกว้างหน้าจอ และล้าง inline style ที่ตั้งไว้ครบทุกตัว (`display/position/top/left/bottom/zIndex`) พร้อมซ่อน backdrop ด้วย
3. เรียก `closeMobileMenu()` ที่ต้นฟังก์ชัน `navigateTo()` — ทำให้ทุกครั้งที่กดเมนูสำหรับไปหน้าใหม่ (ไม่ว่าจะจาก sidebar, bottom-nav, หรือปุ่มไหนก็ตามที่เรียก `navigateTo()`) เมนู overlay จะถูกปิดอัตโนมัติเสมอ ไม่ขึ้นกับความกว้างหน้าจอ ณ ขณะนั้น
4. ลบ listener เดิมท้ายไฟล์ที่ผูกกับ `.sb-link` อย่างเดียวและรีเซ็ตไม่ครบ (ใส่คอมเมนต์อธิบายไว้แทนที่)

**ตรวจสอบแล้ว:** extract inline `<script>` แล้วรัน `node --check` ผ่าน

**ไฟล์ที่แก้ไข:** `leave.html`, `LEAVE.md`
**Copy ไป GitHub/:** `leave.html` ✅

---

### 2026-09-15 (รอบ 7) — Bottom Nav (มือถือ): เปลี่ยน "ประวัติ" เป็น "ขอทำโอที" + ปรับสีสันใหม่

**คำขอ:** คุณใหญ่ส่งภาพหน้าจอแถบเมนูล่างสุดบนมือถือ วงกลมแดงชี้ปุ่ม "ประวัติ" ขอให้เปลี่ยนเป็น "ขอทำโอที" และขอให้ปรับสีสันให้สวยงามขึ้น

**`leave.html` — การเปลี่ยนแปลง:**
1. **เปลี่ยนปุ่มที่ 4 ใน bottom-nav:** จาก `id="bn-lv-my-hist"` (ไอคอนเอกสาร, label "ประวัติ", ไปหน้า `lv-my-hist`) → `id="bn-lv-ot"` (ไอคอนนาฬิกา, label "ขอทำโอที", ไปหน้า `lv-ot`) — ปุ่มนี้เดิมใช้เข้าประวัติของฉัน ตอนนี้เปลี่ยนเป็นทางลัดยื่นคำขอโอทีแทน (เข้าถึงประวัติได้ผ่าน sidebar/hamburger เหมือนเดิม ไม่ได้ถูกลบออกจากระบบ)
2. **ปรับสีสัน bottom-nav ทั้งแถบ:** จากพื้นสีทึบเรียบๆ เปลี่ยนเป็น gradient (linear-gradient 145deg) ต่อปุ่ม พร้อมเงาสี (glow shadow) ตามโทนของแต่ละหมวด, ปุ่มที่ active ยกตัวขึ้นเล็กน้อย (translateY) และไอคอนขยายขึ้นเล็กน้อยตอน active, เพิ่ม tap feedback (ไอคอนย่อเล็กลงชั่วขณะตอนกด) — โทนสีต่อปุ่ม: หน้าหลัก (ม่วงอินดิโก), ยื่นลา (เขียว), ออกนอก (เหลือง/ส้ม), ขอทำโอที (เขียวอมฟ้า/teal — ให้สีเดียวกับธีม OT ที่ใช้ใน sidebar/การ์ดอยู่แล้ว), อนุมัติ (แดง)

**ตรวจสอบแล้ว:** extract inline `<script>` แล้วรัน `node --check` ผ่าน (ไม่กระทบ JS เพราะเป็นการแก้ HTML/CSS ล้วน — ขนาดสคริปต์ที่ extract ได้เท่าเดิมก่อน-หลังแก้)

**ไฟล์ที่แก้ไข:** `leave.html`, `LEAVE.md`
**Copy ไป GitHub/:** `leave.html` ✅

---

### 2026-09-15 (รอบ 6) — เพิ่ม Mobile card layout ให้หน้า "ประวัติโอทีของฉัน"

**คำขอ:** คุณใหญ่ถามว่าฟีเจอร์แก้ไขคำขอโอที (รอบ 5) ปรับให้ใช้งานในเวอร์ชันมือถือด้วยหรือยัง

**ตรวจสอบ:** พบว่า `renderMyOtHistory()` เดิมมีแค่ตาราง (`tbl-wrap`) ไม่มี branch การ์ดสำหรับมือถือเหมือนหน้าอื่นที่มีปุ่มกดเยอะ (เช่น `renderOtApprovals()`, `renderPassApprovals()`, `renderAllRequests()`) ทำให้ปุ่ม "แก้ไข"/"ยกเลิก" ที่เพิ่งเพิ่มไปอยู่ในเซลล์ตารางแคบๆ ต้องเลื่อนแนวนอนดูบนจอมือถือ

**`leave.html` — การเปลี่ยนแปลง:** เพิ่ม `isMobile = window.innerWidth <= 768` branch ให้ `renderMyOtHistory()` ตามแพทเทิร์นเดียวกับ `renderOtApprovals()` — จอมือถือแสดงเป็นการ์ดเต็มความกว้าง (วันที่/ประเภท/เวลา/สถานะ + ปุ่ม "✏️ แก้ไข" และ "🚫 ยกเลิก" เต็มแถวสำหรับคำขอที่ยังรออนุมัติ) จอเดสก์ท็อปยังคงเป็นตารางเหมือนเดิม — ไม่กระทบฟอร์มแก้ไข/สร้างคำขอ (`openEditOtModal`, `renderOtRequest`) เพราะใช้ modal/ฟอร์มแบบ single-column ที่รองรับมือถืออยู่แล้วในแพทเทิร์นเดิมของระบบ

**ตรวจสอบแล้ว:** extract inline `<script>` แล้วรัน `node --check` ผ่าน

**ไฟล์ที่แก้ไข:** `leave.html`, `LEAVE.md`
**Copy ไป GitHub/:** `leave.html` ✅

---

### 2026-09-15 (รอบ 5) — เพิ่มปุ่ม "แก้ไข" ให้พนักงานแก้ไขคำขอโอทีของตัวเอง (เฉพาะสถานะรออนุมัติ)

**คำขอ:** คุณใหญ่ถามว่ากรณีพนักงานยื่นคำขอทำโอทีแล้วกรอกข้อมูลผิด สามารถแก้ไขเองได้ไหม — ตรวจสอบพบว่าหน้า "ประวัติโอทีของฉัน" มีแค่ปุ่ม "ยกเลิก" ยังไม่มีปุ่มแก้ไข จึงถามยืนยันแล้วเพิ่มฟีเจอร์ตามคำตอบ "เพิ่มเลย"

**`leave.html` — การเปลี่ยนแปลง:**
- เพิ่ม global cache `_otCache` (เก็บ row ot_requests ที่โหลดมาแล้ว key=ot_id) — populate ใน `renderMyOtHistory()`
- เพิ่มปุ่ม "✏️ แก้ไข" ข้างปุ่ม "ยกเลิก" ในตาราง `renderMyOtHistory()` — แสดงเฉพาะแถวที่ `status==='pending'`
- เพิ่มฟังก์ชันชุดใหม่ (มินิฟอร์มในโมดัล ใช้ `openModal()`/`closeModal()` เดิม): `openEditOtModal(otId)` (เปิดฟอร์มแก้ไข พร้อมกันไม่ให้แก้คำขอที่ไม่ใช่ pending), `_selectEditOtType(type)`, `_calcEditOtHours()` (คำนวณชั่วโมงใหม่แบบเรียลไทม์เหมือนฟอร์มยื่นคำขอ), `saveEditOt(otId)` (validate แล้ว update `ot_requests` — ใส่เงื่อนไข `.eq('status','pending')` กันแก้ไขซ้อนกรณีหัวหน้าอนุมัติ/ปฏิเสธไปแล้วระหว่างที่พนักงานเปิดฟอร์มค้างไว้)
- แก้ไขได้ทุกฟิลด์ที่กรอกตอนยื่นคำขอ: ประเภทคำขอ (ขอล่วงหน้า/ย้อนหลัง), วันที่, เวลาเริ่ม-สิ้นสุด, ชั่วโมงจริง (กรณีย้อนหลัง), วันหยุด, เหตุผล — คำนวณ `estimated_hours` ใหม่อัตโนมัติจากเวลาที่แก้
- ไม่ส่งแจ้งเตือน LINE ซ้ำเมื่อแก้ไข (คำขอยังอยู่สถานะ pending เดิม หัวหน้าเห็นข้อมูลล่าสุดตอนเข้าหน้าอนุมัติอยู่แล้ว)

**ตรวจสอบแล้ว:** extract inline `<script>` แล้วรัน `node --check` ผ่าน

**ไฟล์ที่แก้ไข:** `leave.html`, `LEAVE.md`
**Copy ไป GitHub/:** `leave.html` ✅

---

### 2026-09-15 (รอบ 4) — เปลี่ยนชื่อเมนู "ประวัติ Pass ของฉัน" → "ประวัติอนุญาต"

**คำขอ:** คุณใหญ่ส่งภาพหน้าจอเมนู "ประวัติของฉัน" ขอเปลี่ยนชื่อเมนู "ประวัติ Pass ของฉัน" เป็น "ประวัติอนุญาต"

**การเปลี่ยนแปลง (`leave.html`):** แก้ label ที่ใช้แสดงผล 2 จุด — sidebar link ของ `sb-lv-pass-hist` และค่าใน `PAGE_TITLES['lv-pass-hist']` (หัวข้อหน้าเวลานำทางเข้ามา) — เปลี่ยนเป็น "ประวัติอนุญาต" ทั้งคู่ — ไม่กระทบ id, route, หรือเมนู "อนุมัติ Pass" (คนละเมนูกัน ไม่ได้ขอให้เปลี่ยน)

**ตรวจสอบแล้ว:** extract inline `<script>` แล้วรัน `node --check` ผ่าน

**ไฟล์ที่แก้ไข:** `leave.html`, `LEAVE.md`
**Copy ไป GitHub/:** `leave.html` ✅

---

### 2026-09-15 (รอบ 3) — จัดหมวดหมู่ Sidebar ใหม่ทั้งหมด (รวม "ขอทำโอที" + รวมประวัติ + ย้ายเมนูอนุมัติเข้า "จัดการ")

**คำขอ:** คุณใหญ่ส่งภาพหน้าจอ sidebar หน้า "ขอทำโอที" พร้อมวาดลูกศรชี้ ขอให้ (1) ย้ายเมนู "ขอทำโอที" ไปไว้ใต้ "ขอออกนอกบริษัท", (2) เปลี่ยนชื่อหมวด "ออกนอกบริษัท" ใหม่, (3) รวมเมนูประวัติทั้ง 3 รายการ (ประวัติของฉัน / ประวัติ Pass ของฉัน / ประวัติโอทีของฉัน) มาไว้ด้วยกัน — ตามด้วยข้อความยืนยัน "จัดหมวดหมู่ใหม่"

ถามคุณใหญ่เพิ่ม 2 ข้อผ่าน AskUserQuestion ก่อนแก้:
- ชื่อหมวดใหม่ (แทน "ออกนอกบริษัท") → คุณใหญ่เลือก **"ประวัติของฉัน"**
- ย้าย "อนุมัติ Pass" + "อนุมัติโอที" (เมนูลับเฉพาะหัวหน้า) ไปรวมกับ "อนุมัติคำขอ" ในหมวด "จัดการ" ด้วยหรือไม่ → คุณใหญ่เลือก **ย้ายไปรวมกับ "จัดการ"**

**โครงสร้าง Sidebar ใหม่ (`leave.html`, ผลจากการจัดหมวดใหม่ — ใช้ ID เดิมทั้งหมด ย้ายตำแหน่งเท่านั้น ไม่มีการสร้าง/ลบเมนู):**

1. **ภาพรวม** — แดชบอร์ด, ยื่นคำขอลา, ขอออกนอกบริษัท, ขอทำโอที
2. **ประวัติของฉัน** (เปลี่ยนชื่อจาก "ออกนอกบริษัท") — ประวัติของฉัน (`lv-my-hist`), ประวัติ Pass ของฉัน (`lv-pass-hist`), ประวัติโอทีของฉัน (`lv-ot-hist`)
3. **จัดการ** (`sb-sec-approve`, ซ่อนเมื่อไม่ใช่ supervisor/admin) — อนุมัติคำขอ (`lv-approvals`), อนุมัติ Pass (`lv-pass-approve` — ย้ายมาจากหมวดเดิม), อนุมัติโอที (`lv-ot-approve` — ย้ายมาจากหมวดเดิม), ทุกคำขอ (`lv-all`), รายงาน (`lv-report`)

หมวด "โอที" แยกต่างหาก (จากการเพิ่มฟีเจอร์รอบ 2) ถูกยุบรวมเข้ากับโครงสร้างข้างต้น — ไม่มีหมวด "โอที" แยกอีกต่อไป

**การตรวจสอบ:** ย้ายเฉพาะตำแหน่ง DOM ของเมนูเดิม ไม่แก้ id/logic ใดๆ — extract inline `<script>` ทั้งหมดแล้วรัน `node --check` ผ่าน, จำนวนตัวอักษรของสคริปต์ (184,202) เท่าเดิมก่อน-หลังแก้ ยืนยันว่าไม่มีเนื้อหาโค้ดหาย/เพี้ยน อ่านซ้ำ HTML ที่แก้แล้วเทียบกับโครงสร้างที่ตั้งใจไว้ — ตรงกัน

**หมายเหตุ:** เมนู mobile bottom-nav และ drawer เมนูมือถือใช้ DOM sidebar เดียวกับ desktop จึงได้ผลลัพธ์เดียวกันโดยอัตโนมัติ ไม่ต้องแก้เพิ่ม

**ไฟล์ที่แก้ไข:** `leave.html`, `LEAVE.md`
**Copy ไป GitHub/:** `leave.html` ✅

---

### 2026-09-15 — Sidebar (desktop): ย้าย "ขอออกนอกบริษัท" มาอยู่ใต้ "ยื่นคำขอลา"

**คำขอ:** คุณใหญ่ส่งภาพหน้าจอ sidebar พร้อมวาดลูกศรชี้ว่าต้องการให้เมนู "ขอออกนอกบริษัท" ย้ายจากหมวด "ออกนอกบริษัท" มาอยู่ใต้ "ยื่นคำขอลา" ในหมวด "ภาพรวม"

**แก้ไข (`<div id="sidebar">`, desktop เท่านั้น — ไม่ได้แตะ bottom-nav มือถือ):**
- ย้าย `<div class="sb-link" id="sb-lv-pass">` (ขอออกนอกบริษัท) จากหมวด "ออกนอกบริษัท" มาอยู่ระหว่าง `sb-lv-request` (ยื่นคำขอลา) กับ `sb-lv-my-hist` (ประวัติของฉัน) ในหมวด "ภาพรวม"
- หมวด "ออกนอกบริษัท" เหลือ 2 รายการ: `sb-lv-pass-hist` (ประวัติ Pass ของฉัน) และ `sb-lv-pass-approve` (อนุมัติ Pass — เฉพาะผู้มีสิทธิ์)
- ไม่กระทบ `navigateTo()`, badge count, หรือ logic อื่นใดๆ — เป็นการย้ายตำแหน่ง DOM ล้วนๆ

**ไฟล์ที่แก้ไข:** `leave.html`
**Copy ไป GitHub/:** `leave.html` ✅

---

### 2026-09-11 รอบ 2 — เพิ่ม PWA manifest + ไอคอน (แก้ไอคอนไม่ขึ้นตอน Add to Home Screen)

**ปัญหาที่พบ:** คุณใหญ่กด "เพิ่มลงหน้าจอโฮม" จาก `leave.html` บน iPhone แล้วไอคอนที่ได้เป็นกล่องเทาๆ ตัวอักษร "ร" (fallback จากตัวอักษรแรกของ title) แทนที่จะเป็นโลโก้ เทียบกับระบบผลิต (`index.html`) ที่ขึ้นไอคอนโลโก้ปกติ

**Root cause:** `leave.html` ไม่มีแท็ก PWA ใน `<head>` เลย — ไม่มี `<link rel="manifest">`, ไม่มี `<link rel="apple-touch-icon">`, ไม่มี `apple-mobile-web-app-*` meta และไม่มีการ register service worker — ต่างจากทุกระบบอื่น (index/inventory/pm/checkin/portal) ที่มีครบ และไม่เคยมี `manifest-leave.json` อยู่ในโปรเจกต์มาก่อน (เช่นเดียวกับ `meeting.html` ที่ยังไม่มี manifest เหมือนกัน — ยังไม่ได้แก้ในรอบนี้เพราะอยู่นอกขอบเขตแชตนี้)

**แก้ไข:**
- สร้าง `manifest-leave.json` ใหม่ (รูปแบบเดียวกับ `manifest-checkin.json`/`manifest-production.json`) — ใช้ `icon-192.png`/`icon-512.png` เดิม (ยังไม่มีไอคอนเฉพาะของ Leave), theme_color `#1d4ed8` (ตรงกับสี btn-primary ของระบบ), start_url/scope ชี้ไป `leave.html`
- เพิ่มใน `<head>` ของ `leave.html`: `<link rel="manifest">`, `<meta name="theme-color">`, `apple-mobile-web-app-capable/status-bar-style/title`, `<link rel="apple-touch-icon">`, และสคริปต์ register service worker (`sw.js` เดิม ไม่ได้แก้ไฟล์ `sw.js`)

**หมายเหตุ:** ยังไม่ได้เพิ่ม `leave.html`/`manifest-leave.json` ใน PRECACHE list ของ `sw.js` (ไฟล์ shared กระทบทุกระบบ — ยังไม่แก้เพราะไม่จำเป็นต่อการแก้ปัญหาไอคอน ถ้าต้องการให้ Leave ใช้งานออฟไลน์ได้ด้วยต้องแจ้งแยกเพื่อแก้ `sw.js` + bump `CACHE_NAME`)

**คุณใหญ่ต้องทำหลัง Upload GitHub:** ลบ shortcut เดิมที่หน้าจอโฮม (ไอคอน "ร") ออกก่อน แล้วเปิดเว็บใหม่ผ่าน Safari/Chrome → กด "เพิ่มลงหน้าจอโฮม" ใหม่อีกครั้ง (ไอคอนเก่าที่ติดตั้งไปแล้วจะไม่อัปเดตเองแม้อัปโหลดไฟล์ใหม่)

**ไฟล์ที่แก้ไข:** `leave.html`, `manifest-leave.json` (ใหม่), `CLAUDE.md`
**Copy ไป GitHub/:** `leave.html` ✅ | `manifest-leave.json` ✅ | `CLAUDE.md` ✅

---

### 2026-09-11 — Realtime แจ้งเตือนหัวหน้า/Admin เมื่อมีคำขอใหม่

**ปัญหาที่พบ:** เดิมเมื่อพนักงานยื่นคำขอลา/Pass ใหม่ LINE แจ้งเตือนไปกลุ่ม HR ตามปกติ แต่ในหน้าเว็บแอป (หน้า "อนุมัติคำขอ" / Dashboard) หัวหน้างานหรือ Admin ที่ล็อกอินค้างอยู่ **ไม่เห็นคำขอใหม่จนกว่าจะกดรีเฟรชเอง** เพราะไม่มีกลไก realtime ฝั่งผู้อนุมัติ (มีแต่ฝั่งพนักงานที่ subscribe รอฟังผลอนุมัติ/ปฏิเสธผ่าน `emp-notif-{employee_id}` channel เท่านั้น)

**การเปลี่ยนแปลง:**

**1. เพิ่ม Supabase Broadcast channel ใหม่ `leave-approvers-notif`:**
- `_broadcastNewRequestToApprovers(kind, r)` — พนักงานเรียกทันทีหลัง insert `leave_requests`/`pass_requests` สำเร็จ (ใน `submitRequest()` และ `submitPassRequest()`) ส่ง payload `{kind, employee_name, department, type_name, days}`
- `_startApproverRealtime()` / `_stopApproverRealtime()` — หัวหน้า/Admin subscribe channel นี้ตอน `_bootApp()` เมื่อ `can('approve')` เป็นจริง (และ unsubscribe ใน `doLogout()`)

**2. `_onNewApproverRequest(payload)` — ตัวจัดการเมื่อมี broadcast เข้ามา:**
- ทำงานเฉพาะผู้มีสิทธิ์อนุมัติ (`can('approve')`)
- Supervisor (ไม่ใช่ admin) จะได้รับแจ้งเฉพาะคำขอแผนกตัวเองเท่านั้น (เทียบ `currentUser.department` — ตรงกับ logic กรองที่ใช้ในหน้าอนุมัติเดิม) ส่วน Admin ได้รับแจ้งทุกแผนก
- แสดง toast `🔔 คำขอใหม่: ...` ทันที
- ถ้ากำลังอยู่หน้า `lv-approvals` → re-render อัตโนมัติ, หน้า `lv-pass-approve` → re-render Pass, หน้า `lv-dashboard` → re-render dashboard, หน้าอื่น → อัปเดตแค่ตัวเลข badge (`_refreshApproveBadgeOnly()` / `_refreshPassBadgeOnly()`)

**ไม่ต้องรัน SQL เพิ่ม** — ใช้ Supabase Realtime Broadcast (เหมือน popup แจ้งพนักงานเดิม) ไม่ต้องเปิด Realtime บนตารางเพิ่มเติม (ใช้ broadcast ไม่ใช่ postgres_changes)

**ไฟล์ที่แก้ไข:** `leave.html`, `CLAUDE.md`
**Copy ไป GitHub/:** `leave.html` ✅ | `CLAUDE.md` ✅

---

### 2026-08-22 — หน้า Login ใหม่ + Realtime Popup + LINE Security มีรูป

**การเปลี่ยนแปลงหลัก:**

**1. หน้า Login ออกแบบใหม่ (Supervisor + Employee):**
- แสดง avatar วงกลม 84px (รูปภาพหรือ emoji placeholder) ด้านบน ก่อน login
- ใต้วงกลม: ชื่อ / รหัสพนักงาน / แผนก — อัปเดตทันทีเมื่อเลือกจาก dropdown ค้นหา
- ปุ่ม "ถัดไป" → ซ่อน search wrap → แสดง PIN step (profile ยังอยู่ด้านบน)
- Helper functions: `_supFillProfile()`, `_supResetProfile()`, `_empFillProfile()`, `_empResetProfile()`
- Mobile CSS: avatar เล็กลง (72px), padding ลดลง, responsive บน 480px

**2. Realtime Popup แจ้งพนักงานทันที (Supabase Broadcast):**
- `_startNotifRealtime()` — subscribe channel `emp-notif-{employee_id}` เมื่อพนักงาน login
- `_stopNotifRealtime()` — unsubscribe เมื่อ logout
- `_sendBroadcastNotif(employeeId, payload)` — supervisor ส่ง broadcast หลัง approve/reject
- `_showSingleNotifPopup({icon, label, detail, status, note})` — modal popup แสดงทันที
- เรียก broadcast จาก: `dashApprove()`, `approveRequest()`, `rejectRequest()`, `approvePass()`, `rejectPass()`
- `checkLeaveStatusNotifications()` — ตรวจ leave_requests + pass_requests ที่ missed ตอน login
- ใช้ Supabase Broadcast (ไม่ใช่ postgres_changes) — ไม่ต้องการ RLS auth

> **⚠️ ต้องเปิด Realtime ใน Supabase Dashboard:**
> Table Editor → เลือกตาราง → Disable Realtime → เปิดเป็น Enable (หรือตรวจว่าเปิดอยู่แล้ว)

**3. LINE Security การ์ดมีรูปพนักงาน:**
- Root cause: `sendPassLineNotify('approved')` ถูกเรียกจาก supervisor → `currentEmp = null` → `photo_url` ว่าง
- Fix: เพิ่ม `photo_url: currentEmp?.photo_url || null` ใน `submitPassRequest()` payload → เก็บลง `pass_requests` ตั้งแต่แรก
- `approvePass()`: ลบ DB lookup แยก (`checkin_employees`) ออก — ใช้ `data.photo_url` จาก SELECT ได้เลย

> **⚠️ ต้องรัน SQL:**
> ```sql
> ALTER TABLE pass_requests ADD COLUMN IF NOT EXISTS photo_url TEXT;
> ```

**`_loadSupRemembered()` — Bug fix:**
- แก้ไข: ใช้ `u?.employee_id` แทน `u?.id` (หลังจาก supervisor ย้ายมาใช้ `checkin_employees`)

**ไฟล์ที่แก้ไข:** `leave.html`, `CLAUDE.md`
**Copy ไป GitHub/:** `leave.html` ✅ | `CLAUDE.md` ✅
**ยังต้องทำ:** รัน SQL (photo_url patch) + Deploy Edge Function + Upload GitHub Pages

---

### 2026-08-17 — LINE 3 OA + รูปโปรไฟล์ใน LINE Card

> **หมายเหตุการย้าย:** entry นี้แตะไฟล์ shared `line-notify_index.txt` (Edge Function ที่ System 1-3 ใช้ด้วย) แต่เนื้อหาหลักคือการตั้งค่า OA HR/Security สำหรับ Leave+Pass โดยเฉพาะ จึงย้ายมาไว้ที่นี่ — ถ้าต้องการดู Secrets ที่ตั้งไว้ (ใช้ร่วมกับระบบอื่นด้วย) อ้างอิง Section 0 ของ `CLAUDE.md` (LINE Notification Status)

**เป้าหมาย:** แยก LINE OA 3 บัญชี เพื่อแบ่ง quota 200 msg/เดือน และแยกกลุ่มแจ้งเตือน

**LINE OA ที่สร้างใหม่:**
- **Sanon HR** → กลุ่ม "Sanon HR 2" — Leave requests (pending) + Pass requests (pending)
- **Sanon Security** → กลุ่ม "รปภ สานนท์" — Pass requests (approved)

**Supabase Secrets (ครบทั้ง 6):**
- `LINE_CHANNEL_TOKEN` / `LINE_GROUP_ID` — OA ผลิต → กลุ่มผลิต (เดิม, ใช้โดย System 1-3 — ห้ามยุ่ง)
- `LINE_CHANNEL_TOKEN_HR` / `LINE_GROUP_ID_HR` = `C35db76ecdc10af3e1fef08821131ffbf` — OA HR
- `LINE_CHANNEL_TOKEN_SECURITY` / `LINE_GROUP_ID_SECURITY` = `Cb48b8d0469f371b84292eed2b1320959` — OA รปภ.

**`line-notify_index.txt` — การเปลี่ยนแปลง:**
- เพิ่มตัวแปร `LINE_TOKEN_HR`, `LINE_TOKEN_SEC`, `LINE_GROUP_ID_HR`, `LINE_GROUP_ID_SEC`
- `buildLeaveRequestCard()`: header เปลี่ยนเป็น `layout: "horizontal"` — มีรูปโปรไฟล์ (`photo_url`) ขนาด 60px ทรงกลมมุมขวา
- `buildPassRequestCard()`: เช่นเดียวกัน (ทั้ง pending และ approved mode)
- Postback handler: เปลี่ยน profile lookup จาก `LINE_TOKEN` → `LINE_TOKEN_HR || LINE_TOKEN` (แสดงชื่อผู้อนุมัติถูกต้อง)
- Leave routing: ใช้ `LINE_TOKEN_HR || LINE_TOKEN` + `LINE_GROUP_ID_HR || LINE_GROUP_ID`
- Pass approved routing: ใช้ `LINE_TOKEN_SEC` → กลุ่ม รปภ.

**`leave.html` — การเปลี่ยนแปลง:**
- `sendLineNotify()`: เพิ่ม `photo_url: currentEmp?.photo_url || null` ใน payload
- `sendPassLineNotify()`: เพิ่ม `photo_url: currentEmp?.photo_url || null` ใน payload

**ทดสอบแล้ว ✅:**
- Leave request → Sanon HR 2 ✅
- Pass pending → Sanon HR 2 ✅
- Pass approved → รปภ สานนท์ ✅
- กด อนุมัติ/ไม่อนุมัติ ใน LINE → อัปเดต DB ทันที ✅

**⏳ สิ่งที่ยังต้องทำ:**
- Deploy `line-notify_index.txt` ล่าสุด (มีรูปโปรไฟล์) ใน Supabase
- Upload `leave.html` ขึ้น GitHub Pages

**ไฟล์ที่แก้ไข:** `line-notify_index.txt`, `leave.html`, `CLAUDE.md`
**Copy ไป GitHub/:** `line-notify_index.txt` ✅ | `leave.html` ✅ | `CLAUDE.md` ✅

---

### 2026-08-16 — PIN 4 หลัก สำหรับ Employee Mode

**การเปลี่ยนแปลง:**

**1. PIN Authentication สำหรับ Employee Mode:**
- `doEmpAccess()`: ดึง `pin_code` จาก DB ก่อน → แสดงขั้นตอน PIN แทนการ login ทันที
- `_showPinStep(pinCode)`: ซ่อน search form + access button → แสดง `#pin-step`
  - ถ้า `pin_code = null` → โหมด "ตั้ง PIN ครั้งแรก" (มี confirm boxes)
  - ถ้ามี PIN → โหมด "ยืนยัน PIN" (auto-submit เมื่อใส่ครบ 4 หลัก)
- `_submitPin()`: ตรวจสอบหรือบันทึก PIN → เรียก `_proceedEmpLogin()`
- `_backToEmpSelect()`: ปุ่มย้อนกลับ — คืน search form ปกติ
- Inline handlers: `_pinIn()`, `_pinKd()`, `_pincIn()`, `_pincKd()` — auto-advance + backspace navigation
- `_shakePins()` — animation เขย่าเมื่อ PIN ผิด

**2. เปลี่ยน PIN (พนักงาน):**
- ปุ่ม "🔐 เปลี่ยน PIN" ในหน้า Dashboard (เฉพาะ `currentMode === 'employee'`)
- `changePinModal()` + `saveNewPin()` — modal ป้อน PIN ใหม่ + ยืนยัน
- PIN boxes ใน modal มี auto-advance เหมือนกัน (`_npIn/Kd`, `_npcIn/Kd`)

**3. Admin รีเซ็ต PIN:**
- Card ใหม่ "🔐 รีเซ็ต PIN พนักงาน" ในหน้าตั้งค่าระบบ
- `searchResetPin()` — ค้นหาพนักงาน แสดงสถานะ PIN (ตั้งแล้ว/ยังไม่มี)
- `selectResetPinEmp()` — เลือกจากผลค้นหาหลายรายการ
- `doResetPin()` — set `pin_code = NULL` → พนักงานต้องตั้งใหม่เมื่อ login ครั้งต่อไป

**`leave_schema_v5_patch.sql` — SQL ใหม่:**
- `ALTER TABLE checkin_employees ADD COLUMN IF NOT EXISTS pin_code text DEFAULT NULL;`

**`doLogout()`:** reset `_empPinHash`, ซ่อน `#pin-step`, คืน `#btn-emp-access`, enable `emp-search`

**ไฟล์ที่แก้ไข:** `leave.html`, `CLAUDE.md`, `leave_schema_v5_patch.sql`
**Copy ไป GitHub/:** `leave.html` ✅ | `leave_schema_v5_patch.sql` ✅ | `CLAUDE.md` ✅

---

### 2026-08-16 (เพิ่มเติม) — รูปโปรไฟล์พนักงานใน Dashboard

**การเปลี่ยนแปลง:**

**รูปโปรไฟล์พนักงานใน Dashboard (Employee mode):**
- `renderDashboard()`: เพิ่มรูปโปรไฟล์ขนาด 72×72px ทรงกลมที่มุมขวาบนของ Greeting area
- ดึง `photo_url` จาก `currentEmp.photo_url` — ซิ้งข้อมูลจาก `checkin_employees` ตารางเดียวกับ System 4 (ไม่ต้องดึงข้อมูลเพิ่ม)
- ถ้า session เก่าไม่มี `photo_url` → auto-fetch จาก DB 1 ครั้ง (แก้ปัญหาพนักงานที่ login ไว้ก่อนเพิ่มรูปใน System 4)
- ถ้า URL โหลดไม่ได้ → `onerror` fallback แสดง avatar 👤 สีฟ้าแทน
- เฉพาะ `currentMode === 'employee'` เท่านั้น (Supervisor/Admin ไม่มีรูป)
- ย้ายปุ่ม "🔐 เปลี่ยน PIN" ไปอยู่ใต้ชื่อ/วันที่ (ซ้ายล่าง) เพื่อให้รูปอยู่ขวา

**ไฟล์ที่แก้ไข:** `leave.html`, `CLAUDE.md`
**Copy ไป GitHub/:** `leave.html` ✅ | `CLAUDE.md` ✅

---

### 2026-08-15 (เย็น) — Username Autocomplete + Pass/Leave LINE Notification

**`leave.html` — การเปลี่ยนแปลง:**
- เพิ่ม `<datalist id="lg-user-list">` + `list="lg-user-list"` ใน input username login
- เพิ่ม `saveRecentLvUser(username)` — บันทึก username ใน `localStorage._sn_lv_recent_users` (max 10, dedup)
- เพิ่ม `loadRecentLvUsers()` — โหลด datalist ตอนแสดงหน้า login
- เรียก `saveRecentLvUser()` ใน `doLogin()` หลัง login สำเร็จ

**`line-notify_index.txt` (Edge Function) — การเปลี่ยนแปลง:**
- เพิ่ม `buildLeaveRequestCard()` — Flex Card สีตามประเภทลา (sick/personal/annual ฯลฯ) แสดงชื่อ/แผนก/วันที่/จำนวนวัน/เหตุผล — ส่งเฉพาะ `status=pending`
- เพิ่ม `buildPassRequestCard(r, isPending)` — 2 โหมด: pending (🟠 แจ้งหัวหน้า) / approved walk-in (🔵 แจ้งยาม)
- เพิ่ม handler `leave_requests` + `pass_requests` ใน main serve()
- ยืนยัน: Edge Function ใช้ **LINE Messaging API** (`api.line.me/v2/bot/message/push`) แล้ว — ไม่ใช่ LINE Notify ที่ปิดไปแล้ว

**⏳ สิ่งที่ต้องทำก่อน deploy (ณ ตอนบันทึก entry นี้):**
1. รัน SQL ใน Supabase (ตามลำดับ): `leave_schema.sql` → `leave_schema_v2_patch.sql` → `leave_schema_v3_patch.sql` → `pass_schema.sql` → `ALTER TABLE app_users ADD COLUMN IF NOT EXISTS meeting_access boolean DEFAULT false;` (สำหรับ System 5)
2. ตั้งค่า LINE Official Account: สร้าง LINE OA → ได้ Channel Access Token, เพิ่ม Bot เข้ากลุ่ม → ได้ Group ID, ตั้ง Supabase Secrets: `LINE_CHANNEL_TOKEN` + `LINE_GROUP_ID`
3. Deploy Edge Function `line-notify` (วาง code จาก `line-notify_index.txt`)
4. Upload GitHub/ → GitHub Pages

**ไฟล์ที่แก้ไข:** `leave.html`, `line-notify_index.txt`, `CLAUDE.md`
**Copy ไป GitHub/:** `leave.html` ✅ | `line-notify_index.txt` ✅ | `CLAUDE.md` ⏳

---
