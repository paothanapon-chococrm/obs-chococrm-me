# ⚠️ Store / Order-Status Gating — ยังไม่ enforce (ต้องรู้ก่อนตรวจว่าทำงานถูก)

> [!warning] ประเด็นสำคัญ อ่านก่อนเชื่อผลการคิดแต้ม
> เอกสาร [[00-Overview]] (บรรทัด "match กับ `CRM_Criteria_Config_Detail` (store + order status)") อธิบาย **ดีไซน์ที่ตั้งใจ** — แต่ **โค้ดตอนนี้ยังไม่ทำ gate นั้น**
> ตอนนี้: **platform ตรง + มี active config + เจอ order = คิดแต้มเลย** ไม่สนว่า store ใน config ตรงกับ order ไหม

บันทึก 2026-09-03 · code `lms-core` @ development

---

## ทำงานจริงตอนนี้ยังไง

3 จุดที่ไม่มีการเทียบ store/status สักจุด:

| # | ไฟล์ | ทำอะไร | ผล |
|---|---|---|---|
| 1 | `LmsMarketplaceCriteriaService.cs:91` `GetActiveByPlatform` | `FirstOrDefault(PlatformId == x && IsActive && !IsDeleted)` | เลือกเกณฑ์ **ด้วย platform อย่างเดียว** ไม่แตะ store/status |
| 2 | `LmsMarketplaceEarnService.cs` `QueryLazada/Shopee/TikTok` (บรรทัด ~126, 150, 177) | สร้าง `MarketplaceOrderSnapshot` | คืน `StoreRef: null` ทุกเจ้า — **ไม่มี store จาก order ให้เทียบด้วยซ้ำ** |
| 3 | `MarketplaceEarnCalculator.Apply` (`MarketplaceEarnModels.cs:53`) | คิดแต้ม | คิดจาก spending + sku ล้วนๆ **ไม่มีเงื่อนไข store** |

ponytail comment มาร์คไว้ที่ `LmsMarketplaceEarnService.cs:65`:
> `store/order-status gating ยังไม่ enforce — 1 platform มี active config เดียว เลยคิดจากตัวนั้นเลย เพื่อให้เทสได้`

**เหตุผลที่ทำแบบนี้:** ระบบ **shop list ยังไม่เสร็จ** — payload จาก hub ยังไม่ได้แจกแจง `store_ref` ออกมา เลยเอาไปเทียบไม่ได้อยู่ดี. เจตนา: ให้คิดแต้มได้ก่อนถ้า platform ตรง (ยอมรับแล้ว)

---

## ทำไมตอนนี้ยัง "ไม่พัง" ทั้งที่ไม่ filter store

`GetActiveByPlatform` ใช้ `FirstOrDefault` **ไม่มี `OrderBy`** — จะหยิบมั่วถ้ามี active หลายตัว. แต่ write path บังคับ invariant ไว้:

- `LmsMarketplaceCriteriaService.cs:190` `EnsureSingleActivePerPlatform` (**R1**) — ตอน Upsert ถ้าจะเปิด active ตัวใหม่ทั้งที่ platform นั้นมี active อยู่แล้ว → **throw**
- ⇒ การันตี **1 platform = active ได้ตัวเดียว** ⇒ `FirstOrDefault` เลยไม่มีทางหยิบผิด

> [!caution] จุดเปราะ (ยังไม่ใช่บั๊กตอนนี้)
> invariant R1 อยู่ที่ **app layer เท่านั้น ไม่มี DB constraint**
> ถ้ามี 2 request activate พร้อมกัน (race) หรือมีคนไป UPDATE ตรง DB ให้ active 2 ตัว → `FirstOrDefault` (ไม่มี OrderBy) จะหยิบ **non-deterministic** เงียบๆ
> กันได้ด้วย one-liner: ใส่ `OrderBy` ที่ `:91` (เช่น เอาตัวอัปเดตล่าสุด) ให้ deterministic

---

## ✅ เช็คลิสต์ยืนยันว่า "ทำงานถูก" ตอนนี้

ผลที่ **ถูกต้องสำหรับเฟสนี้**:
- [ ] platform ตรง + เจอ order + มี active config → **ได้แต้ม** (ถึงแม้ store ใน config ≠ store จริงของ order)
- [ ] ไม่มี active config ของ platform → `NoActiveCriteria`
- [ ] ไม่เจอ order → `OrderNotFound`

ถ้าเห็นแต้มออกทั้งที่ store ไม่ตรง = **ถูกต้องตามเฟสนี้** ไม่ใช่บั๊ก

---

## 🔜 ตอน shop list เสร็จ ต้องเติม gate (2 จุด)

1. `QueryLazada/Shopee/TikTok` — ดึง **`StoreRef` จริง** ใส่ใน `MarketplaceOrderSnapshot` (ตอนนี้ hardcode `null`)
2. เลือกเกณฑ์ — filter config ด้วย **(platform + store + order status)** แทน `GetActiveByPlatform` ตัวเดียว
   - ที่นี่ต้องดู [[../Marketplace-Point-Criteria/06-OrderStatus-Mapping]] ประกอบ (สถานะแต่ละ platform map เป็น status กลางยังไง)

ตอนนั้น invariant "1 active/platform" (R1) อาจต้องคลายเป็น "1 active ต่อ (platform + store)" ด้วย — ทบทวน R1 พร้อมกัน

related: [[02-Flow]] · [[03-API-Spec]]
