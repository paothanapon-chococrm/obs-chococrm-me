---
tags: [work, lms, data-model]
status: todo
created: 2026-08-20
---

# Phase 3 — Flag `IsUse`

> [!summary]
> flag บอกว่า order/buyId นี้ **คิดแต้มไปแล้ว** กันคิดซ้ำ + โชว์สถานะได้เร็วโดยไม่ต้องยิง wallet

## ต้องตอบให้ได้
- [ ] เก็บ flag ที่ **table order เดิม** (เพิ่ม column) หรือ **table mapping ใหม่** (orderId/buyId ↔ ledger)?
- [ ] key ที่ผูก = `orderId` หรือ `buyId` หรือทั้งคู่?
- [ ] เก็บ ref กลับไป ledger ที่ออกด้วยไหม (`LedgerId`/`TXReference`) เผื่อ trace/void

## ข้อเสนอ (ร่าง — mapping table)
เก็บเป็น table แยกน่าจะยืดหยุ่นกว่าแก้ table order:
```
OrderPointIssue
- OrderId       (key)
- BuyId
- IsUse         bool
- CriteriaId    (config ที่ใช้)
- Point         decimal
- Exp_DT        datetime (UTC)
- WL_LedgerId   / WL_TXReference   ← ref กลับ wallet
- IssuedAt      datetime (UTC)
```
> [!tip] ทำไมไม่พึ่ง idempotent ของ AddFundsV2 อย่างเดียว
> `transactionId` กันซ้ำที่ชั้น wallet ได้จริง แต่ IsUse ให้ประโยชน์เพิ่ม:
> โชว์สถานะเร็ว, เก็บ criteria/point ที่คำนวณ, กัน UI กดซ้ำก่อนถึง wallet

## ต่อกับ
- ใช้ตอนเช็คเงื่อนไขแรกใน [[03-Manual-Endpoint]] (step 2)
- set หลังออกแต้มสำเร็จ (step 6)
