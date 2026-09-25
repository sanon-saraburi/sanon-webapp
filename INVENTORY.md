# INVENTORY.md — ระบบคลังวัสดุ (System 2)
> ไฟล์นี้บันทึกรายละเอียดเฉพาะ `inventory.html` แยกจาก System 1

---

## 1. ข้อมูลระบบ

- **ไฟล์:** `inventory.html` (~4,953 บรรทัด)
- **สถานะ:** ✅ ใช้งานจริง
- **Supabase:** `https://pcmpwkcmvsxrvbximjgf.supabase.co` (project เดิม)
- **Session key:** `_sn_inv_sess` (แยกจาก `_sn_sess` ของ System 1)

---

## 2. Architecture

- Single-file SPA — Vanilla JS, Tailwind CDN, Lucide Icons, Chart.js
- Auth: query `app_users` table โดยตรง (ไม่ใช้ Supabase Auth)
- RBAC: `getAllowedInvMenus()`, `ROLE_DEFAULT_MENUS`, `INV_MENUS_MAIN`
- Libraries พิเศษ: `qrcodejs`, `JsBarcode`, `Html5Qrcode`

---

## 3. เมนูทั้งหมด (Menu prefix: `inv-`)

| key | ชื่อ | หน้าที่ |
|-----|------|---------|
| `inv-dashboard` | ภาพรวมคลัง | ยอดคงเหลือ, แจ้งเตือน Min Stock, Top เบิก |
| `inv-balance` | วัสดุคงเหลือ | ตาราง stock + filter + สแกน QR ตรวจสอบ |
| `inv-qr` | QR / Label | grid QR+Barcode, filter โรงงาน/ประเภท, พิมพ์ PDF |
| `inv-stock` | รับวัสดุเข้า | modal + สแกน + FIFO lot tracking |
| `inv-withdraw` | เบิกวัสดุ | modal + สแกน + คำนวณต้นทุน FIFO อัตโนมัติ |
| `inv-approvals` | รออนุมัติ | withdraw pending → อนุมัติ/ปฏิเสธ |
| `inv-po` | ใบสั่งซื้อ (PO) | สร้าง PO → รับของ → อัพสต็อก |
| `inv-chem` | สารตกตะกอน | บันทึกการใช้สาร, น้ำหนัก, โรงงาน |
| `inv-report` | รายงาน | รับเข้า/เบิก/สต็อก/ต้นทุน |
| `inv-settings` | ตั้งค่า | ประเภทวัสดุ, โรงงาน, หน่วย, ผู้จำหน่าย |

---

## 4. ตาราง Database (System 2)

```sql
inventory_items          -- วัสดุ/อะไหล่ (master) + is_chemical flag
inventory_transactions   -- รับเข้า/เบิก + lot_no, unit_cost, lot_breakdown (JSONB)
inventory_stock          -- ยอดคงเหลือ (อัพเดทโดย trigger อัตโนมัติ)
inventory_lots           -- FIFO lot tracking (remaining_qty, unit_cost ต่อ lot)
inventory_po             -- ใบสั่งซื้อ
inventory_po_items       -- รายการใน PO
inv_suppliers            -- ผู้จำหน่าย
inv_config               -- ตั้งค่าระบบ (factories, departments, locations)
chemical_usage           -- การใช้สารตกตะกอน
```

### SQL Files
| ไฟล์ | รายละเอียด | สถานะ |
|------|-----------|-------|
| `inventory_schema.sql` | สร้างตาราง + trigger ทั้งหมด | ✅ รันแล้ว |
| `fix_stock.sql` | แก้ยอดสต็อกที่ผิดจาก migration | ✅ รันแล้ว |
| `lot_tracking.sql` | สร้าง `inventory_lots` + เพิ่ม column | ⚠️ ต้องรันก่อนใช้ FIFO |
| `inventory_item_images.sql` | เพิ่ม `image_url` column + Storage bucket `item-images` + policy | ⚠️ ต้องรันก่อนใช้ฟีเจอร์รูปวัสดุ |

---

## 5. Global State

```js
_invItems     // inventory_items (active)
_stockMap     // item_id → current_quantity
_lotsMap      // item_id → [{id, lot_no, received_date, remaining_qty, unit_cost}] FIFO order
_suppliers    // inv_suppliers
_invConfig    // inv_config (factories, departments, locations)
_pendingCount // จำนวนรออนุมัติ
```

---

## 6. FIFO Lot Tracking

### แนวคิด
- วัสดุชนิดเดียวกัน = **1 item, 1 QR Code** ไม่เปลี่ยน
- แต่ละรอบที่รับเข้า = **1 Lot** พร้อม `unit_cost` ของตัวเอง
- เบิกออก = **FIFO** (ของเก่าออกก่อน) คำนวณต้นทุนตาม lot จริง
- ข้ามล็อต → ระบบแบ่ง breakdown อัตโนมัติ

### ตัวอย่าง (สารตกตะกอน)
```
Lot 1: 100 กก. @ 104 บ./กก.  → รับมาก่อน เบิกก่อน
Lot 2: 100 กก. @ 85 บ./กก.   → เบิกต่อเมื่อ Lot 1 หมด
เบิก 60 กก. (Lot 1 เหลือ 20 กก.):
  → 20 กก. × 104 = 2,080 บ. (จาก Lot 1)
  → 40 กก. × 85  = 3,400 บ. (จาก Lot 2)
  → รวม 5,480 บ. (ต้นทุนตรงกับของจริง)
```

### Functions
```js
calcFifoCost(item_id, qty)   // คำนวณ FIFO → {breakdown, totalCost, shortage}
genLotNo(dateStr)            // สร้าง LOT-YYYYMMDD-XXX
loadLots()                   // โหลด lots ที่ remaining_qty > 0
saveStockIn()                // insert transaction + insert inventory_lots
saveWithdraw()               // FIFO deduction + update remaining_qty ต่อ lot
showStockCheckModal()        // แสดง lots ทั้งหมด (lot แรก = สีน้ำเงิน = เบิกก่อน)
```

---

## 7. QR / Barcode

| รายการ | รายละเอียด |
|--------|-----------|
| QR Code | encode `item.code` (ITM-0001) ด้วย `qrcodejs` |
| Barcode | Code128 ด้วย `JsBarcode` |
| Scanner | `Html5Qrcode` ใช้กล้อง environment (ต้อง HTTPS) |
| Print | `window.open()` → HTML + print CSS → `window.print()` |
| Badge "ใหม่" | `created_at` < 7 วัน |
| Filter QR | ค้นหา / ประเภท / **โรงงาน** / ขนาด / ช่วงเวลา / การเรียง |

---

## 8. Layout Rules

```
Outer wrapper : h-screen overflow-hidden
Sidebar       : position: sticky; top: 0; height: 100vh; overflow-y: auto; scrollbar-width: none
Main content  : display: flex; flex-direction: column; overflow: hidden; height: 100vh
Topbar        : flex-shrink-0 (ค้างบนสุด)
#page-content : flex: 1; overflow-y: auto (scroll container หลัก)
.tbl-wrap     : overflow: auto; max-height: calc(100vh - 200px) (scroll ต่อตาราง)
thead th      : position: sticky; top: 0; z-index: 20 (หัวตารางค้างอยู่กับที่)
```

---

## 9. Changelog

### 2026-09-25 (รอบ 9) — สารตกตะกอน: ปรับกราฟเปรียบเทียบให้เต็มความกว้าง + ขยายตัวเลข "เบิกเดือนนี้/รับเข้าเดือนนี้" ให้เด่นขึ้น

**คำขอ:** คุณใหญ่ส่งภาพวงกลมสีแดง 2 จุด (1) พื้นที่ว่างด้านขวาของกราฟเปรียบเทียบการเบิกรายเดือน (2) แถวตัวเลข "เบิกเดือนนี้"/"รับเข้าเดือนนี้" ด้านล่างการ์ดสต็อกที่ตัวเลขเล็กไป

**จุดที่แก้:** `loadChemDash()` (SECTION 16 หน้า `inv-chem`)

**สิ่งที่เปลี่ยน:**
1. กราฟเปรียบเทียบการเบิกรายเดือน: เดิม canvas ถูกจำกัดด้วย `max-height` และ Chart.js ใช้ `maintainAspectRatio:true` (ค่าเริ่มต้น) ทำให้กราฟคำนวณความกว้างจาก aspect ratio ของ canvas เอง ไม่ยืดเต็มพื้นที่ว่างด้านขวา — แก้โดยเปลี่ยน wrapper เป็น `height:300px;width:100%;position:relative` และเพิ่ม `maintainAspectRatio:false` ใน options ของ Chart.js ทำให้กราฟยืดเต็มความกว้างของการ์ดเสมอ
2. การ์ดสต็อกแต่ละชนิด (Propel/CDE): แถวตัวเลข "เบิกเดือนนี้ (เดือน)" และ "รับเข้าเดือนนี้" ขยายจาก `text-sm` เป็น `text-2xl font-extrabold` พร้อมเพิ่มหน่วย (ถุง) ต่อท้ายตัวเลข และเพิ่มเส้นคั่นด้านบนให้หนาขึ้น (`border-t-2`) เพื่อให้เด่นชัดขึ้น


### 2026-09-25 (รอบ 8) — สารตกตะกอน: เปลี่ยนการเปรียบเทียบการเบิกจาก "12 เดือนล่าสุด (rolling)" เป็น "รายปีตามตัวกรองปีด้านบน"

**คำขอ:** คุณใหญ่ดูตารางเปรียบเทียบ 12 เดือนที่เพิ่งทำ (รอบ 7) แล้วพบว่าช่วง ต.ค. 68 – พ.ค. 69 ว่างเปล่าหมด (ยังไม่มีข้อมูล) เพราะนับถอยหลัง 12 เดือนจากเดือนที่เลือกเสมอ จึงขอให้แสดงข้อมูล "ต่อปี" แทน โดยใช้ตัวกรอง "ปี" (dropdown `#ch-dash-year`) ที่มีอยู่ด้านบนของหน้าเป็นตัวกำหนด

**จุดที่แก้:** ส่วน "── Comparison table (12 เดือนล่าสุด) ──" ใน `loadChemDash()` (SECTION 16 หน้า `inv-chem`)

**สิ่งที่เปลี่ยน:**
1. เปลี่ยนจากช่วงเวลาแบบ rolling 12 เดือน (นับถอยหลังจากเดือนที่เลือก) เป็นปีปฏิทินเต็ม ม.ค.–ธ.ค. ของปีที่เลือกจาก dropdown ด้านบน (`year`)
2. Query ดึงข้อมูลช่วง `${year}-01-01` ถึง `${year}-12-31` แทนช่วงเดิม
3. หัวข้อการ์ดเปลี่ยนจาก "เปรียบเทียบการเบิก 12 เดือนล่าสุด — [เดือนแรกสุด] – [เดือนที่เลือก]" เป็น "เปรียบเทียบการเบิกรายเดือน — ปี [ปีที่เลือก]"
4. กราฟและตารางยังคงรูปแบบเดิม (กราฟแท่งแยกสีตามชนิดสาร + ตารางแนวนอน 12 เดือน + แถวรวมท้ายตาราง) เพียงแต่คอลัมน์เดือนอ้างอิงปีปฏิทินแทน


### 2026-09-25 (รอบ 7) — สารตกตะกอน: เปลี่ยนตารางเปรียบเทียบการเบิกจาก 2 เดือน เป็น 12 เดือน + กราฟเทรนด์

**คำขอ:** คุณใหญ่ถามว่าหัวข้อ "เปรียบเทียบการเบิก" (เดิมเทียบแค่เดือนก่อนหน้า vs เดือนปัจจุบัน) ทำเป็นเปรียบเทียบ 12 เดือนได้ไหม มีพื้นที่พอไหม — เลือกรูปแบบ "กราฟเทรนด์ + ตารางรายละเอียด"

**จุดที่แก้:** ส่วน "── Comparison table ──" ใน `loadChemDash()` (SECTION 16 หน้า `inv-chem`)

**สิ่งที่เปลี่ยน:**
1. ดึงข้อมูลรายการเบิก (`inventory_transactions`, `transaction_type='withdraw'`, `status='approved'`) ของสารตกตะกอนแต่ละชนิด ย้อนหลัง 12 เดือนนับจากเดือนที่เลือกไว้ (query เดียว ช่วงวันที่ตั้งแต่ต้นเดือนแรกสุด ถึงสิ้นเดือนที่เลือก) แล้วรวมยอด (จำนวนถุง + มูลค่า) แยกตามเดือน/รายการด้วยฝั่ง client
2. เพิ่มกราฟแท่ง (Chart.js, `#chem-trend-chart`, key `chartRegistry['chemTrend']`) แสดงแนวโน้มจำนวนถุงที่เบิกต่อเดือน แยกสีตามชนิดสาร (CDE/Propel) ครบ 12 เดือน
3. เปลี่ยนตารางเปรียบเทียบจาก 2 คอลัมน์ (เดือนก่อน/เดือนนี้ + ส่วนต่าง) เป็นตารางแนวนอน 12 คอลัมน์เดือน (เลื่อนดูได้ทางขวาด้วย `overflow-x-auto` เพราะคอลัมน์เยอะ) แต่ละช่องแสดงจำนวนถุง + มูลค่า พร้อมแถวรวมทั้งหมดท้ายตาราง
4. หัวข้อการ์ดเปลี่ยนจาก "เปรียบเทียบการเบิก — [เดือนก่อน] vs [เดือนนี้]" เป็น "เปรียบเทียบการเบิก 12 เดือนล่าสุด — [เดือนแรกสุด] – [เดือนที่เลือก]"

**หมายเหตุ:** ตารางนี้ใช้ query แยกต่างหาก (ไม่ปนกับ query อื่นใน Promise.all เดิม) เพื่อไม่กระทบส่วนอื่นของหน้า


### 2026-09-25 (รอบ 6) — สารตกตะกอน: ซ่อนการ์ด "ยอดคงเหลือ ณ สิ้นเดือน" เมื่อเลือกเดือนปัจจุบัน

**ที่มา:** คุณใหญ่ไล่เช็คหน้า "สารตกตะกอน" แล้วสังเกตว่าเมื่อตัวกรองเดือนตรงกับเดือนปัจจุบัน (เช่น ก.ย. 2569 ขณะที่วันนี้คือ 25 ก.ย. 2569) การ์ด "ยอด ณ ปัจจุบัน" กับการ์ด "ยอดคงเหลือ ณ สิ้นเดือน" จะแสดงตัวเลขซ้ำกันเป๊ะ (เพราะยังไม่มีรายการเดือนถัดไปให้หักล้างตามสูตร — ไม่ใช่บั๊ก แต่ข้อมูลซ้ำจริง) เลือกวิธีแก้แบบที่ 3: **ซ่อนการ์ด "สิ้นเดือน" ไปเลยเมื่อเลือกเดือนปัจจุบัน** แสดงเฉพาะตอนเลือกเดือนที่ผ่านไปแล้วเท่านั้น

**สิ่งที่แก้ใน `loadChemDash()` (SECTION 16, บล็อก "── Stock ณ สิ้นเดือน ──"):**
- เพิ่มเช็ค `_isCurMonth = (year===วันนี้.getFullYear() && month===วันนี้.getMonth())`
- ถ้าเป็นเดือนปัจจุบัน → `eomWrap.innerHTML=''` (ไม่แสดงหัวข้อ/การ์ดเลย ไม่ query ข้อมูลเพิ่มด้วย ประหยัด request)
- ถ้าเป็นเดือนที่ผ่านไปแล้ว → แสดงการ์ดตามปกติเหมือนเดิม

**ตรวจสอบแล้ว:** extract inline `<script>` ที่ใหญ่ที่สุด (268,148 ตัวอักษร) → รัน `node --check` ผ่าน — `GitHub/inventory.html` กับ root `inventory.html` เทียบ `diff` แล้ว IDENTICAL

**ไฟล์ที่แก้ไข:** `inventory.html`, `INVENTORY.md`
**Copy ไป GitHub/:** `inventory.html` ✅ | `INVENTORY.md` ✅
**ยังไม่ได้ upload ขึ้น GitHub Pages / ทดสอบจริง**


### 2026-09-25 (รอบ 5) — 🐛 แก้บั๊ก: Dashboard ไม่มีข้อมูลเลย (รับเข้า/เบิกออก/การเคลื่อนไหว = 0 ทุกเดือน)

**อาการที่คุณใหญ่แจ้ง:** เปลี่ยนเดือนเป็น ก.ค. 2569 แล้วการ์ด "รับเข้า", "เบิกออก", "มูลค่าเบิก" ขึ้น 0 หมด และ "การเคลื่อนไหวล่าสุด" ขึ้น "ไม่มีรายการในเดือนนี้" ทั้งที่การ์ด "ใกล้หมด"/"วัสดุหมด" ยังมีข้อมูลปกติ (นี่คือครั้งแรกที่คุณใหญ่ทดสอบหลังอัป `GitHub/inventory.html` ที่แก้ไว้ในรอบ 3-4 วันเดียวกัน)

**สาเหตุ (root cause):** ในรอบ 3 (เพิ่ม popup รายละเอียดรายการ) ได้เพิ่ม join `inv_suppliers(name,code)` เข้าไปใน query ของ `loadDashboard()` บนตาราง `inventory_transactions` — แต่ตรวจสอบ `inventory_schema.sql` พบว่าคอลัมน์ `inventory_transactions.supplier_id` **ไม่มี foreign key constraint ไปยัง `inv_suppliers`** (มีแค่ `add column if not exists supplier_id uuid,` เฉยๆ ไม่มี `references inv_suppliers(id)` — ต่างจาก `inventory_po.supplier_id` ที่มี FK ถูกต้อง) ทำให้ PostgREST/Supabase หา relationship ไม่เจอ **query ทั้งก้อนพังทันทีทุกครั้งที่เรียก** (ไม่ใช่แค่ไม่เจอข้อมูล) ส่งผลให้ `_dashTxns` กลายเป็น array ว่างเปล่าเสมอ ไม่ว่าจะเลือกเดือน/โรงงานไหนก็ตาม — ระบบไม่ได้ error ป๊อปอัพแจ้งเตือน เพราะโค้ดเดิมไม่ได้เช็ค `error` จาก query เลย ทำให้ดูเหมือนข้อมูลหายไปเฉยๆ

**วิธีแก้:**
1. เอา `inv_suppliers(name,code)` ออกจาก query ของ `loadDashboard()` (บรรทัด ~1432) — ฟิลด์ "ผู้จำหน่าย" ใน popup รายละเอียดรายการ (`showDashMovementDetail`) จะแสดงว่างสำหรับตอนนี้ (เหมือนจุดอื่นที่มีปัญหาเดียวกันซึ่งเคยแจ้งไว้ในรอบ 3 — ยังไม่ได้แก้ เพราะต้องเพิ่ม FK ใน DB ก่อน)
2. เพิ่มการเช็ค `error` จาก query ใน `loadDashboard()` — ถ้า query ผิดพลาดจะขึ้น toast แจ้งเตือนทันที + log ใน console แทนที่จะแสดงเป็น 0 เงียบๆ (กันปัญหาแบบนี้เกิดซ้ำในอนาคต จะได้รู้ทันทีว่ามี error จริง ไม่ใช่แค่ไม่มีข้อมูล)

**ถ้าต้องการแก้ปัญหา "ผู้จำหน่าย" ว่างอย่างถาวร (ยังไม่ได้ทำ — ต้องขอ SQL เพิ่มทีหลัง):** ต้องรัน SQL เพิ่ม FK ให้ `inventory_transactions.supplier_id` เช่น
```sql
alter table inventory_transactions
  add constraint inventory_transactions_supplier_id_fkey
  foreign key (supplier_id) references inv_suppliers(id);
```
(ยังไม่ได้ส่งให้รัน — จะทำเป็นงานถัดไปถ้าคุณใหญ่ต้องการ)

**ตรวจสอบแล้ว:** extract inline `<script>` ที่ใหญ่ที่สุด (267,883 ตัวอักษร) → รัน `node --check` ผ่าน — `GitHub/inventory.html` กับ root `inventory.html` เทียบ `diff` แล้ว IDENTICAL

**ไฟล์ที่แก้ไข:** `inventory.html`, `INVENTORY.md`
**Copy ไป GitHub/:** `inventory.html` ✅ | `INVENTORY.md` ✅
**ยังไม่ได้ upload ขึ้น GitHub Pages / ทดสอบจริง** — คุณใหญ่ต้อง upload แล้วลองเปลี่ยนเดือนดูว่าข้อมูลกลับมาแล้วหรือยัง


### 2026-09-25 (รอบ 4) — Dashboard: คลิกการ์ด KPI เปิด popup รายละเอียด

**คำขอ:** คุณใหญ่ส่งภาพวงกรอบสีแดงรอบแถบการ์ด KPI ทั้ง 6 ใบ (รายการวัสดุ/รับเข้า/เบิกออก/มูลค่าเบิก/ใกล้หมด/วัสดุหมด) + ตาราง "การเคลื่อนไหวล่าสุด" ขอให้ทำเฉพาะส่วนในกรอบ — ตารางการเคลื่อนไหวทำไปแล้วรอบก่อน (2026-09-25 รอบ 3) รอบนี้จึงเพิ่มให้การ์ด KPI คลิกได้ด้วย

**สิ่งที่เพิ่มใน `loadDashboard()` (SECTION 12):**
1. เพิ่ม global ใหม่ `_dashLow`, `_dashOut` (เก็บ array วัสดุใกล้หมด/หมดของรอบที่โหลดล่าสุด), `_dashPeriodLabel` (ข้อความเดือน/ปีที่กำลังดู เช่น "ก.ย. 2569")
2. การ์ด KPI ทั้ง 6 ใบ เพิ่ม `cursor-pointer` + `onclick="dashKpiClick(k)"` — คลิกแล้วเปิด popup แสดงรายการที่ประกอบเป็นตัวเลขนั้น:
   - **รายการวัสดุ** → `showDashItemsPopup()` — ตารางวัสดุทั้งหมด (รหัส/ชื่อ/ประเภท/คงเหลือ)
   - **รับเข้า** → `showDashTxnListPopup('receive')` — ตารายการรับเข้าในเดือน/โรงงานที่กรองอยู่ พร้อมยอดรวม
   - **เบิกออก** และ **มูลค่าเบิก** → `showDashTxnListPopup('withdraw')` (ใช้ popup เดียวกัน เพราะเป็นข้อมูลชุดเดียวกัน)
   - **ใกล้หมด** → `showDashStockPopup('low')`, **วัสดุหมด** → `showDashStockPopup('out')`
3. แถวในตาราง popup รับเข้า/เบิก **คลิกซ้ำได้อีกชั้น** — เรียก `showDashMovementDetail(id)` เดิม (ที่ทำไว้รอบ 3) เปิดดูรายละเอียดเต็มของรายการนั้น — ทำให้ตรวจสอบที่มาของยอดรวมใน KPI ได้ครบทุกชั้น (การ์ด → รายการ → รายละเอียด)

**ตรวจสอบแล้ว:** extract inline `<script>` ที่ใหญ่ที่สุด (267,762 ตัวอักษร) → รัน `node --check` ผ่าน — `GitHub/inventory.html` กับ root `inventory.html` เทียบ `diff` แล้ว IDENTICAL

**ไฟล์ที่แก้ไข:** `inventory.html`, `INVENTORY.md`
**Copy ไป GitHub/:** `inventory.html` ✅ | `INVENTORY.md` ✅
**ยังไม่ได้ upload ขึ้น GitHub Pages / ทดสอบจริง**


### 2026-09-25 (รอบ 3) — Dashboard: คลิกแถว "การเคลื่อนไหวล่าสุด" เปิด popup รายละเอียด

**คำขอ:** คุณใหญ่ขอให้เพิ่ม option ให้คลิกที่รายการในหน้า Dashboard (ภาพรวมคลัง) แล้วเด้ง popup โชว์รายละเอียดของรายการนั้น — ยืนยันขอบเขตผ่าน AskUserQuestion แล้วว่าต้องการเฉพาะตาราง **"การเคลื่อนไหวล่าสุด"** เท่านั้น (ไม่รวมวัสดุใกล้หมด/หมด/Top 10)

**สิ่งที่แก้ใน `loadDashboard()` (SECTION 12):**
1. ขยาย `select()` ของ query `inventory_transactions` เพิ่มฟิลด์รายละเอียด: `doc_no, note, requested_by, status, approved_at, rejected_reason, purpose, supplier_id, lot_no, department` + join `inventory_items(name,unit,code)`, `inv_suppliers(name,code)`, และ join ชื่อผู้ทำรายการ/ผู้อนุมัติจาก `app_users` สองจุด (`creator:app_users!created_by`, `approver:app_users!approved_by`)
2. เก็บผลลัพธ์ query ไว้ในตัวแปร global ใหม่ `_dashTxns` เพื่อให้ popup ค้นรายละเอียดจาก id ได้โดยไม่ query ซ้ำ
3. แต่ละแถวในตาราง "การเคลื่อนไหวล่าสุด" เพิ่ม `cursor-pointer` + `onclick="showDashMovementDetail(id)"`
4. เพิ่มฟังก์ชันใหม่ `showDashMovementDetail(id)` — เปิด popup (ใช้ `showModal()` เดิมของระบบ) แสดง: เลขที่เอกสาร, ประเภท+สถานะ, วันที่ทำรายการ, วัสดุ, จำนวน, ราคา/หน่วย, มูลค่ารวม, โรงงาน/ฝ่าย, Lot No., ผู้จำหน่าย (เฉพาะรับเข้า), ผู้บันทึก/ผู้ขอเบิก, ผู้อนุมัติ+วันที่อนุมัติ, วัตถุประสงค์, หมายเหตุ

**หมายเหตุที่พบระหว่างทำ (ยังไม่ได้แก้ — แจ้งไว้เผื่อคุณใหญ่ต้องการแก้ต่อ):** ตาราง "รับวัสดุเข้า" (`inv-stock`, บรรทัด ~1446) และ export รายงานประเภท movement (`inv-report`, บรรทัด ~3093) อ้างอิง `r.inv_suppliers?.name` แต่ query เดิมไม่ได้ join `inv_suppliers` ไว้ ทำให้คอลัมน์ "ผู้จำหน่าย" ในสองจุดนั้นว่างเปล่าเสมอ (ไม่เกี่ยวกับงานที่แก้รอบนี้ ยังไม่ได้แตะ — แจ้งไว้เป็นข้อสังเกต)

**ตรวจสอบแล้ว:** extract inline `<script>` ที่ใหญ่ที่สุด (262,519 ตัวอักษร) → รัน `node --check` ผ่าน — `GitHub/inventory.html` กับ root `inventory.html` เทียบ `diff` แล้ว IDENTICAL

**ไฟล์ที่แก้ไข:** `inventory.html`, `INVENTORY.md`
**Copy ไป GitHub/:** `inventory.html` ✅ | `INVENTORY.md` ✅
**ยังไม่ได้ upload ขึ้น GitHub Pages / ทดสอบจริง**


### 2026-09-25 (รอบ 2) — เพิ่มตัวกรองเดือนในหน้า "รับวัสดุเข้า" (ประวัติการรับเข้า)

**คำขอ:** คุณใหญ่ส่งภาพหน้า "รับวัสดุเข้า" วงกรอบแดงช่องว่างข้างช่องค้นหา ขอให้เพิ่มตัวกรองเดือน

**วิธีแก้:** เพิ่ม `<select>` ตัวกรองเดือนในแถบหัวตาราง "ประวัติการรับเข้า" (`PAGE_RENDERERS['inv-stock']`) — ใช้ pattern เดียวกับตัวกรองเดือนที่มีอยู่แล้วในหน้า "เบิกวัสดุ" (`inv-withdraw` / `woFilterMonth`):
- Options สร้างจากเดือนที่มีข้อมูลจริงใน `hist` (ล่าสุด 100 รายการที่โหลดมา) เรียงใหม่→เก่า แสดงเป็น พ.ศ.
- แต่ละแถว `<tr>` ใน `#si-body` เพิ่ม `data-month` (yyyy-mm จาก `created_at`)
- เพิ่มฟังก์ชันใหม่: `siFilterMonth(val)`, `siFilterSearch(val)`, `_siApplyFilters()` — กรองร่วมกันทั้งเดือน+คำค้นหา (เดิมช่องค้นหาเรียก `filterTbl()` ตรงๆ ไม่รองรับกรองเดือนร่วมด้วย จึงเปลี่ยนมาเรียก `siFilterSearch()` แทน)

**ตรวจสอบแล้ว:** extract inline `<script>` ที่ใหญ่ที่สุด (259,143 ตัวอักษร) → รัน `node --check` ผ่าน — `GitHub/inventory.html` กับ root `inventory.html` เทียบ `diff` แล้ว IDENTICAL

**ไฟล์ที่แก้ไข:** `inventory.html`, `INVENTORY.md`
**Copy ไป GitHub/:** `inventory.html` ✅ | `INVENTORY.md` ✅
**ยังไม่ได้ upload ขึ้น GitHub Pages / ทดสอบจริง**


### 2026-09-25 — แก้ Export รายงาน (Excel) ไม่ตรงกับหน้าจอ

**ปัญหาที่คุณใหญ่แจ้ง:** กดปุ่ม "Export Excel" ในหน้ารายงาน (`inv-report`) แล้วไฟล์ที่ได้ใช้งานไม่ได้ — คอลัมน์เป็นชื่อ field ดิบจาก DB (`id, item_id, transaction_type, ...`), คอลัมน์วัสดุ (`inventory_items`) ว่างเปล่า, `item_id` เป็น UUID ดิบ ไม่ใช่ชื่อวัสดุ — ไม่ตรงกับตารางที่แสดงบนหน้าจอเลย (เลขที่/วันที่/ประเภท/วัสดุ/จำนวน/มูลค่า/โรง-ฝ่าย)

**สาเหตุ (root cause):** ฟังก์ชัน `exportReport()` (เดิมบรรทัด ~3086) เรียก `XLSX.utils.json_to_sheet(_rptData)` ส่งข้อมูลดิบจาก Supabase query ตรงๆ ลง Excel โดยไม่แปลงเป็นคอลัมน์ภาษาไทยแบบเดียวกับที่ตารางบนจอใช้ — และข้อมูล relation ที่ join มา เช่น `inventory_items(name)` เป็น nested object ซึ่ง `json_to_sheet` ไม่รู้จะแปลงยังไง เลยได้ค่าว่าง

**วิธีแก้:** เขียน `exportReport()` ใหม่ — เช็คประเภทรายงานที่เลือกอยู่ (`#rpt-type`) แล้ว map ข้อมูลเป็น array ของ object ที่มี key เป็นภาษาไทยตรงกับคอลัมน์บนจอ ก่อนส่งเข้า `json_to_sheet`:
- **balance** (สต็อคคงเหลือ): รหัส, ชื่อวัสดุ, ประเภท, คงเหลือ, หน่วย, ขั้นต่ำ, สถานะ, ที่เก็บ
- **movement/stock-in/stock-out/cost**: เลขที่, วันที่, ประเภท(รับเข้า/เบิก), วัสดุ, หน่วย, จำนวน, มูลค่า, โรง/ฝ่าย, ผู้ทำรายการ, สถานะ, หมายเหตุ — แก้จุดที่วัสดุว่างโดยดึงจาก `r.inventory_items?.name` ตรงๆ (join data มีอยู่แล้วใน query แต่ export เดิมไม่ได้ดึงมาใช้)
- **low-stock**: รหัส, ชื่อวัสดุ, คงเหลือ, ขั้นต่ำ, ที่เก็บ, สถานะ
- **chem** (สารตกตะกอน): เดือน, โรง, สาร, ใช้(ถุง), ใช้(กก.), ผลิต(ตัน), กก./ตัน, บาท/ตัน
- **po**: เลขที่ PO, วันที่, ผู้จำหน่าย, โรง, สถานะ

**ตรวจสอบแล้ว:** extract inline `<script>` ที่ใหญ่ที่สุด (258,010 ตัวอักษร) → รัน `node --check` ผ่าน — `GitHub/inventory.html` กับ root `inventory.html` เทียบ `diff` แล้ว IDENTICAL

**ไฟล์ที่แก้ไข:** `inventory.html`, `INVENTORY.md`
**Copy ไป GitHub/:** `inventory.html` ✅ | `INVENTORY.md` ⏳ (ทำต่อในขั้นถัดไป)
**ยังไม่ได้ upload ขึ้น GitHub Pages / ทดสอบจริง** — คุณใหญ่ต้อง upload แล้วลองกด Export Excel ทุกประเภทรายงานอีกครั้ง


### 2026-09-22 (รอบ 2) — System Switcher: เอาไอคอน Portal ออกตามคำสั่งคุณใหญ่
- คุณใหญ่ให้เอาไอคอน "Portal" ออกจากสวิตช์เปลี่ยนระบบใน `inventory.html` (เพิ่งเพิ่มไปในรอบก่อนหน้าวันเดียวกัน) — ลบออกทั้ง Desktop Sidebar และ Mobile Sidebar (2 จุด) เหลือ 6 ไอคอน: ผลิต, คลัง(ตัวเอง), PM, HR, จองห้อง(มีเงื่อนไขสิทธิ์), ขอลา
- ตรวจสอบแล้ว: `node --check` ผ่าน, sync root/GitHub ตรงกัน
- **หมายเหตุ:** `portal.html` (Smart Launcher) ยังทำงานปกติ ไม่ได้ถูกแก้ไข — แค่เอาลิงก์ลัดออกจาก switcher ของ inventory.html เท่านั้น ผู้ใช้ที่ต้องการกลับ Portal ยังกดปุ่ม back ของ browser หรือเข้า URL portal.html ตรงได้ตามปกติ
- Frontend ล้วน ไม่ต้องรัน SQL เพิ่ม

### 2026-09-22 — System Switcher: เพิ่มลิงก์ให้ครบทุกระบบ (checkin/meeting/leave/portal)
- **ที่มา:** คุณใหญ่ (แจ้งแบบ broadcast ให้ทุกระบบตรวจสอบ) — สวิตช์ "เปลี่ยนระบบ" ของแต่ละไฟล์แยกกันเอง ไม่ได้ใช้ร่วมกัน ให้แต่ละระบบเช็ค/เพิ่มลิงก์ให้ครบเอง
- **ตรวจพบ:** สวิตช์ "เปลี่ยนระบบ" ใน `inventory.html` (ทั้ง Desktop Sidebar footer + Mobile Sidebar footer) เดิมมีแค่ **ผลิต** (`index.html`) และ **PM** (`pm.html`) เท่านั้น — ขาด **HR** (`checkin.html`), **จองห้อง** (`meeting.html`), **ขอลา** (`leave.html`), และ **Portal** (`portal.html`) ครบทั้ง 4 ระบบ
- **แก้ไข:** เพิ่มลิงก์ที่ขาดทั้ง 4 ระบบ ในทั้ง 2 จุด (desktop + mobile) โดยใช้ `onclick="gotoSystem('xxx.html')"` ตาม pattern เดิม (เขียน SSO session ทุก key ก่อนเปลี่ยนหน้า) — ไม่ใช้ `<a href="xxx.html">` เฉยๆ
  - HR → `checkin.html` (สีเขียว emerald, icon `clock`)
  - จองห้อง → `meeting.html` (สีฟ้า cyan, icon `calendar-check`) — **มีเงื่อนไขสิทธิ์**: แสดงเฉพาะ `currentUser.meeting_access === true` หรือ `role === 'admin'` (pattern เดียวกับที่ `index.html` ใช้)
  - ขอลา → `leave.html` (สีม่วง violet, icon `clipboard-check`)
  - Portal → `portal.html` (สีเทาเข้ม slate, icon `layout-grid`)
- เปลี่ยน container จาก `flex gap-1.5` → `grid grid-cols-3 gap-1.5` (เพื่อรองรับ 7 ไอคอนแบบ 3 คอลัมน์ 3 แถว ไม่ล้นแถวเดียว) — สไตล์เดียวกับที่ `index.html` ใช้อยู่แล้ว
- **ตรวจสอบแล้ว:** extract inline `<script>` แล้วรัน `node --check` ผ่าน, sync root/GitHub inventory.html ตรงกันแล้ว (diff = IDENTICAL)
- **ยังไม่ได้ upload ขึ้น GitHub Pages** — รอคุณใหญ่ upload โฟลเดอร์ `GitHub/` ตามขั้นตอนปกติ แล้ว hard-refresh ทดสอบว่ากดสลับระบบได้ครบทุกปุ่ม + SSO ยังทำงาน (ไม่ต้อง login ซ้ำ)
- Frontend ล้วน ไม่ต้องรัน SQL เพิ่ม

### 2026-09-16 (รอบ 2) — เพิ่มรูปภาพวัสดุ (Item Photo)
- **เป้าหมาย:** ให้เห็นรูปวัสดุตอนเบิก/รับของ และในรายการวัสดุคงเหลือ ตามที่คุณใหญ่ขอ
- **DB:** เพิ่มคอลัมน์ `inventory_items.image_url` (text) + Storage bucket ใหม่ `item-images` (public read) — ดูสคริปต์ `inventory_item_images.sql` (⚠️ ต้องรันใน Supabase SQL Editor ก่อนใช้งานฟีเจอร์นี้)
- **Pattern:** ใช้แนวทางเดียวกับ `employee-photos` ใน `checkin.html` (resize ฝั่ง client ด้วย Canvas ก่อน upload, เก็บ URL เต็มใน DB พร้อม cache-bust `?t=timestamp`)
- **หน้าจัดการวัสดุ (`openItemModal`/`saveItem`):** เพิ่มช่องอัปโหลดรูป + preview + ปุ่มลบรูป — ย่อขนาดสูงสุด 600×600px คุณภาพ JPEG 80% ก่อนอัปโหลด (ฟังก์ชันใหม่: `resizeItemImage()`, `previewItemPhoto()`, `clearItemPhoto()`, `uploadItemImage()`, `deleteItemImageFromStorage()`) — วัสดุใหม่จะอัปโหลดรูปหลังบันทึกได้ id แล้ว
- **แสดงรูป:**
  - ตารางรายการวัสดุ (ตั้งค่า → รายการวัสดุ) — เพิ่มคอลัมน์ "รูป" ขนาด 32×32px
  - ตารางวัสดุคงเหลือ (`inv-balance`) — เพิ่มคอลัมน์ "รูป" (colspan 11→12)
  - Modal รับวัสดุเข้า (`siItemChange`) และ Modal เบิกวัสดุ (`woItemChange`) — แสดง thumbnail 56×56px เมื่อเลือกวัสดุ
  - ทุกจุดมี fallback ไอคอน 📦 ถ้าไม่มีรูปหรือโหลดรูปไม่สำเร็จ (`onerror`)
- **พื้นที่จัดเก็บ:** ประเมินแล้วไม่กระทบ Quota Free Plan (Storage 1GB, ปัจจุบันใช้ 0GB) แม้มีวัสดุนับพันรายการ เพราะย่อ/บีบอัดรูปก่อนอัปโหลดเสมอ (~100-200KB/รูป)
- **ตรวจสอบแล้ว:** extract inline `<script>` แล้วรัน `node --check` ผ่าน, sync root/GitHub inventory.html ตรงกันแล้ว (diff = IDENTICAL)
- **ยังไม่ได้ upload ขึ้น GitHub Pages** — รอคุณใหญ่ upload โฟลเดอร์ `GitHub/` ตามขั้นตอนปกติ + รัน `inventory_item_images.sql` ใน Supabase ก่อนใช้งานจริง
- **⚠️ อัปเดต:** รัน SQL รอบแรกแล้วเจอ error `42501: must be owner of table objects` ที่บรรทัด `ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY` (ตารางนี้เป็นของ role `supabase_storage_admin` ไม่ใช่ `postgres` จึงรันไม่ได้) — **แก้แล้ว** โดยตัดบรรทัดนั้นออก (ไม่จำเป็นเพราะ Supabase เปิด RLS ให้ `storage.objects` เป็นค่าเริ่มต้นอยู่แล้ว) ไฟล์ `inventory_item_images.sql` เป็นเวอร์ชันล่าสุดแล้ว — **ยังไม่ได้รันซ้ำ/ยืนยันว่าผ่าน** ดู TODO ด้านล่าง

### 2026-09-16 — รับวัสดุเข้า: กรองรายการวัสดุตามโรงงาน
- **⚠️ พบไฟล์ไม่ตรงกัน:** `inventory.html` ที่ root โฟลเดอร์เก่ากว่า `GitHub/inventory.html` (ขาดฟีเจอร์รอบ 2026-09-02 รอบ 3 — สต็อกการ์ดสารตกตะกอน/ราคา FIFO ในตารางวัตถุคงเหลือ) — แก้โดยใช้ `GitHub/inventory.html` เป็นฐานแทน แล้ว sync กลับ root ให้ตรงกัน
- Modal "รับวัสดุเข้า" (`openStockInModal`): dropdown "โรงงาน" (`#si-factory`) เดิมมีอยู่แล้วแต่ไม่กรอง item — เพิ่ม `onchange="siFilterItems()"` ให้กรองจริง
- ฟังก์ชันใหม่ `siFilterItems()`: กรอง `_invItems` ตาม `allowed_factories` ของแต่ละวัสดุ — วัสดุที่ไม่ระบุ `allowed_factories` (ของส่วนกลาง) แสดงทุกโรงงานเสมอ, เลือก "-- ทุกโรง --" = แสดงทั้งหมดเหมือนเดิม
- คงค่าที่เลือกไว้ถ้ายังอยู่ใน filter ใหม่ ไม่งั้น reset เป็น "-- เลือกวัสดุ --" แล้วเรียก `siItemChange()` ให้ข้อมูลสต็อก/หน่วยตรงกับตัวเลือกปัจจุบัน
- ใช้ pattern เดียวกับ filter ใน Modal เบิกวัสดุ (`allowed_factories`, `woFilterItems()`) — ไม่กระทบ logic รับเข้า/FIFO เดิม
- Frontend ล้วน ไม่ต้องรัน SQL เพิ่ม

### 2026-09-02 รอบ 3 — สารตกตะกอน UX + ราคา FIFO ในตารางวัตถุคงเหลือ
- สารตกตะกอน stock card: เพิ่ม stat "เบิก/รับเข้าเดือนนี้" (ถุง) + วันที่ปัจจุบันใน header + น้ำหนักรวม (กก.) ใต้ตัวเลขถุง (เฉพาะ card เบิกจ่าย/รับเข้าเดือนนี้)
- ตารางวัตถุคงเหลือ: คอลัมน์ราคาต่อหน่วยเปลี่ยนจาก `i.unit_price` (master) → weighted average จาก FIFO lot จริง (`_lotsMap` ที่ `remaining_qty > 0`) พร้อม fallback เป็น master price — **ไม่กระทบ logic เบิก** (`calcFifoCost()` ยังคง FIFO จริง)
- Frontend ล้วน ไม่ต้องรัน SQL เพิ่ม

### 2026-08-05 — Dashboard redesign + LINE วันที่เบิก + แก้ราคาสารตกตะกอน
- **Bug fix:** ราคาสารตกตะกอนคูณ `wpkg` ซ้อน (root cause: `ac` เป็น ฿/ถุงอยู่แล้ว) — แก้ stock card + annual report + เปลี่ยน label `บ./กก.` → `บ./ถุง`
- Dashboard (`inv-dashboard`): filter เปลี่ยนจากช่วง 30 วัน → dropdown เดือน/ปี (พ.ศ.), เปลี่ยน canvas chart-movement → ตาราง movement 25 รายการล่าสุด, KPI card สไตล์ enterprise, Top 10 เบิกสูงสุด (เหรียญ + progress bar)
- LINE Notification: เพิ่ม `withdraw_date` ใน payload + แสดงในการ์ด LINE (fallback `created_at`)
- Withdraw modal: เพิ่ม filter ประเภท + ค้นหาชื่อ/รหัส (`_woAllItems`, `woFilterItems()`)
- Report page: auto-load ทุก filter (ลบปุ่ม "แสดงผล"); ประวัติการเบิก: เพิ่ม month filter
- ไฟล์ที่แก้ไข: `inventory.html`, `line-notify_index.txt` (ต้อง deploy Edge Function)

### 2026-08-01 (ช่วงบ่าย) — Revert Loading Screen + normCat Filter Fix
- Revert loading screen (excavator) — เวอร์ชันก่อนหน้าทำให้ระบบพังเพราะ `hideSplash()` ไม่ได้ define
- เพิ่ม `normCat()` normalize whitespace แก้ปัญหา filter หาไม่เจอ (double space / non-breaking space) ใน `renderBalanceTable()`
- Withdraw modal: เพิ่ม filter ประเภท + search box ก่อน dropdown วัสดุ (`_woAllItems`, `woFilterItems()`)

### 2026-07-21 — ปุ่มยกเลิกยอดเบิก + สิทธิ์เบิกตามโรงงาน (allowed_factories)
- เพิ่มฟังก์ชัน `cancelWithdraw(id)` — เปลี่ยน status → `rejected` (trigger คืนสต็อกอัตโนมัติ) + คืน FIFO lots, เพิ่มคอลัมน์ "จัดการ" ในตารางรายงาน แสดงปุ่ม "ยกเลิก" เฉพาะ Manager ขึ้นไป
- สิทธิ์เบิกตามโรงงาน: SQL `ALTER TABLE inventory_items ADD COLUMN allowed_factories text[]` (`allowed_factories.sql`) — `openItemModal()`/`saveItem()` เพิ่ม checkbox โรงงาน CDE/Propel/Sanon1/Sanon2 ต่อวัสดุ (ไม่เลือก = ของส่วนกลาง) — Modal เบิก: User ทั่วไปเห็นเฉพาะวัสดุที่โรงงานตนมีสิทธิ์ / Admin+Manager เห็นทั้งหมด
- (SSO `_sn_shared_sess` ข้ามระบบ ทำพร้อมกันวันนี้ — ดูรายละเอียดร่วมใน `CLAUDE.md`)

### 2026-07-16 (ช่วงบ่าย) — Print Color Fix + inv-chem UX
- Print Color Fix: เพิ่ม `print-color-adjust:exact!important` ทุก popup window (สารตกตะกอน, QR/Label, PO Form, Main CSS) — root cause: background class ต้องมี `!important` และ `*{print-color-adjust}` ต้องอยู่ใน rule เดียวกัน, เพิ่ม class ที่ขาดหาย (`text-teal-700`, `text-orange-700`, `bg-green-200` ฯลฯ)
- `inv-chem`: ลบปุ่ม "+ บันทึกรายการ" (ดึงข้อมูลจากระบบเบิกโดยตรง ไม่ต้องกรอกซ้ำ)

### 2026-07-16 — Security RLS + UX/Layout + รายงานประจำปีสารตกตะกอน
- RLS เปิดครบทุกตาราง System 2 (policy `anon_all`) — ทำพร้อมกับ System 1 ดูรายละเอียดร่วมใน `CLAUDE.md`
- `app_users` เพิ่ม column `factory` + `department` — modal เบิกวัสดุ pre-fill โรงงาน/ฝ่ายจาก `currentUser` อัตโนมัติ
- UX: ย้ายเมนู "สารตกตะกอน" ขึ้นอันดับ 2, dashboard filter โรงงานเปลี่ยนเป็น toggle buttons (`dashSetFac()`), แก้ modal overflow แนวนอนบนมือถือ, Settings → ผู้ใช้งาน ค้าง tab หลังบันทึก + เพิ่มคอลัมน์โรงงาน/ฝ่าย
- รายงานประจำปีสารตกตะกอน: สูตรบาท/ตัน = ค่าใช้จ่ายเบิกจริง (qty × pricePerBag) ÷ ตันผลิต, เพิ่ม `CHEM_OV` (hardcode override ปี 2026 CDE/Propel ม.ค.–มิ.ย.)

### 2026-07-13
- **Sidebar sticky** — ไม่เลื่อนตามหน้า, ซ่อน scrollbar
- **Table sticky thead** — หัวตารางทุกตารางค้างอยู่กับที่ใน `.tbl-wrap`
- **FIFO + Lot Tracking** — รับเข้าสร้าง Lot, เบิกคำนวณต้นทุน FIFO, แสดง breakdown
- **QR filter โรงงาน** — เพิ่ม `#qr-factory` กรอง label ตามโรงงาน
- **lot_tracking.sql** — SQL สำหรับสร้าง `inventory_lots` + เพิ่ม column

---

## 10. สิ่งที่ต้องทำต่อ (TODO)

### 🔴 พรุ่งนี้ (2026-09-17) — ฟีเจอร์รูปวัสดุ (ค้างจาก 2026-09-16)
- [ ] **รัน `inventory_item_images.sql`** ใน Supabase SQL Editor — ⚠️ เวอร์ชันแรกที่ให้ไปมี error `42501: must be owner of table objects` เพราะมีบรรทัด `ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY` ซึ่งไม่มีสิทธิ์รัน (ไฟล์แก้ไขแล้ว/ตัดบรรทัดนั้นออกแล้ว — ใช้เวอร์ชันล่าสุดในไฟล์นี้รัน ไม่ต้องมีบรรทัดนั้นอีก)
- [ ] **อัปโหลดรูปทดสอบ** ที่หน้า ตั้งค่า → รายการวัสดุ → แก้ไขวัสดุ → เลือกรูป → บันทึก (ต้องรัน SQL ข้อบนก่อน ไม่งั้น error เพราะยังไม่มีคอลัมน์ `image_url`/bucket `item-images`)
- [ ] **Upload โฟลเดอร์ `GitHub/`** ขึ้น GitHub Pages (โค้ด `inventory.html` แก้เสร็จแล้ว รอ deploy) แล้ว hard-refresh (Ctrl+Shift+R) ทดสอบว่ารูปขึ้นจริงในโมดัลรับเข้า/เบิก + ตารางคงเหลือ/รายการวัสดุ

### 🔴 พรุ่งนี้ (2026-07-16) — ลำดับความสำคัญ (เดิม — cross-check ว่าทำเสร็จหรือยัง)
- [ ] **รัน `lot_tracking.sql`** ใน Supabase SQL Editor (ทำก่อนสุด)
- [ ] **แก้โค้ด `inventory.html`** — click sort + drag & drop column ordering
- [ ] **Push `inventory.html`** ขึ้น GitHub (มีการแก้หลายอย่างวันนี้)

### 🟡 ถัดไป
- [ ] ทดสอบ FIFO รับเข้า → เบิกจ่าย → ตรวจสอบ lot breakdown
- [ ] หน้า `inv-approvals`: เพิ่มการหัก lot เมื่ออนุมัติ pending withdraw
- [ ] รายงานต้นทุน: ดึง `lot_breakdown` มาแสดงรายละเอียดต้นทุน FIFO
- [ ] ระบบ PM เครื่องจักร (`pm.html`) — ยังไม่ได้เริ่ม
