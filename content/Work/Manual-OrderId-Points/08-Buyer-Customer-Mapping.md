---
tags: [work, lms, data-model, mapping]
status: todo
created: 2026-08-21
---

# Buyer ↔ Customer Mapping (identity link)

> [!summary]
> map **BuyerId (ฝั่ง MKP) → CRM_CustomerId (ระบบเรา)** เพื่อรู้ว่า order นี้ให้แต้มลูกค้าคนไหน
> ต่างจาก [[04-Data-IsUse-Flag]] (นั่นคือ order↔ledger กันคิดซ้ำ) — อันนี้คือ **identity ของคน**

## ข้อเท็จจริงที่คุมดีไซน์
1. **เลือก Shop/Channel ก่อน** แล้วค่อย query orderId → ทุก query ผูกกับ **ShopId** เสมอ
2. **BuyerId ไม่ unique ข้ามร้าน** — เบอร์/ไอดี buyer ของ Shopee ร้าน A ชนกับร้าน B ได้
   → key จริงต้องเป็น **`(ShopId, BuyerId)`** ไม่ใช่ BuyerId เดี่ยว
3. **BuyerId : CRM_CustomerId = N : 1** (REQ-005 [[06-MKP-Reference]])
   ลูกค้า 1 คนมีได้หลาย buyer account (หลายร้าน/หลาย MKP) → หลาย BuyerId ชี้ customer เดียวกันได้
   แต่ **1 `(ShopId, BuyerId)` ต้องชี้ customer เดียว** (ห้ามคนเดียว buyer ไปโผล่ 2 customer)

## ข้อเสนอ table (ร่าง)
```
BuyerCustomerMap
- Id            (pk)
- ShopId        ← ร้าน/channel account
- BuyerId       ← id ฝั่ง MKP
- CustomerId    ← CRM_CustomerId ระบบเรา (ไม่ unique = อนุญาต N:1)
- LinkMethod    auto | manual | customer-self
- LinkedAt      datetime (UTC)

UNIQUE (ShopId, BuyerId)     ← กัน buyer เดียวผูกซ้อน 2 customer
INDEX  (CustomerId)          ← ดู buyer ทั้งหมดของลูกค้า 1 คน
```
> ทำไมแยก table ไม่ยัด column บน customer: N:1 ยัดไม่ลง (customer 1 แถวมีหลาย buyer) + query ขาเข้าคือ `(ShopId, BuyerId) → CustomerId`

## Lookup / auto-link (ใช้ใน journey B)
```
เลือก Shop → กรอก orderId → query order (แนบ ShopId) → ได้ BuyerId
   ↓
หา BuyerCustomerMap by (ShopId, BuyerId)
   ├─ เจอ    → ได้ CustomerId → คิดแต้มต่อ [[03-Manual-Endpoint]]
   └─ ไม่เจอ → auto-link: จับคู่ customer แล้ว insert map (ShopId, BuyerId, CustomerId)
```

## ยังต้องเคลียร์ → [[05-Open-Questions]]
- [ ] auto-link จับ customer ด้วย key อะไร (เบอร์/email/ชื่อ จาก order MKP) — กันผูกผิดคน
- [ ] ถ้า order ไม่มีข้อมูลพอ match customer → ทำไง (สร้าง customer ใหม่ / บล็อกให้ผูก manual)
- [ ] ShopId เก็บที่ table ร้าน/channel account ตัวไหน (ต่อกับ REQ-004/006)
