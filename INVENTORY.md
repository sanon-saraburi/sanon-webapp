# INVENTORY.md — ระบบคลังวัสดุ (System 2)
> ไฟล์นี้บันทึกรายละเอียดเฉพาะ `inventory.html` แยกจาก System 1

---

## 1. ข้อมูลระบบ

- **ไฟล์:** `inventory.html`
- **สถานะ:** ✅ ใช้งานได้ (~2,767 บรรทัด) — อยู่ระหว่างพัฒนาเพิ่มเติม
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

### 2026-07-13
- **Sidebar sticky** — ไม่เลื่อนตามหน้า, ซ่อน scrollbar
- **Table sticky thead** — หัวตารางทุกตารางค้างอยู่กับที่ใน `.tbl-wrap`
- **FIFO + Lot Tracking** — รับเข้าสร้าง Lot, เบิกคำนวณต้นทุน FIFO, แสดง breakdown
- **QR filter โรงงาน** — เพิ่ม `#qr-factory` กรอง label ตามโรงงาน
- **lot_tracking.sql** — SQL สำหรับสร้าง `inventory_lots` + เพิ่ม column

---

## 10. สิ่งที่ต้องทำต่อ (TODO)

### 🔴 พรุ่งนี้ (2026-07-16) — ลำดับความสำคัญ
- [ ] **รัน `lot_tracking.sql`** ใน Supabase SQL Editor (ทำก่อนสุด)
- [ ] **แก้โค้ด `inventory.html`** — click sort + drag & drop column ordering
- [ ] **Push `inventory.html`** ขึ้น GitHub (มีการแก้หลายอย่างวันนี้)

### 🟡 ถัดไป
- [ ] ทดสอบ FIFO รับเข้า → เบิกจ่าย → ตรวจสอบ lot breakdown
- [ ] หน้า `inv-approvals`: เพิ่มการหัก lot เมื่ออนุมัติ pending withdraw
- [ ] รายงานต้นทุน: ดึง `lot_breakdown` มาแสดงรายละเอียดต้นทุน FIFO
- [ ] ระบบ PM เครื่องจักร (`pm.html`) — ยังไม่ได้เริ่ม
