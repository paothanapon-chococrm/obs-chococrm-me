---
tags: [work, lms, endpoint]
status: todo
created: 2026-08-20
---

# Phase 2 — Manual Endpoint

> [!note] แนวคิด — ตัดสินใจแล้ว: **one-shot**
> endpoint เดียว รับ `orderId` → query + auto-link + คิดแต้ม + ออกแต้ม + set IsUse → resp ว่าได้กี่แต้ม
> ไม่แยก preview/confirm (ลด db-roundtrip). ปลอดภัยเพราะ idempotent (orderId) กันซ้ำ + แต้ม deterministic + VoidIssue แก้ได้
> ถ้า order ถูกคิดไปแล้ว → resp duplicate พร้อมแต้มเดิม (ไม่ error)

## ขั้นตอนภายใน
1. **query order** จาก DB ฝั่งเราด้วย `orderId` → ได้ order + `buyId`
   - [ ] ⚠️ **ยังไม่รู้ว่า data order เก็บที่ไหน/table อะไร** → [[05-Open-Questions]]
2. **เช็คเงื่อนไขแรก**: order/buyId นี้เคยผูก/คิดแต้มไปแล้วหรือยัง
   - อ่าน flag `IsUse` → [[04-Data-IsUse-Flag]]
   - ถ้า `IsUse = true` → return "คิดไปแล้ว" (ไม่ทำต่อ)
3. **match criteria config** → [[01-Criteria-Config]]
   - หา config ที่ order นี้เข้าเงื่อนไข → ได้ สูตรคิดแต้ม + rule วันหมดอายุ
4. **คำนวณ** point (สูตร × transaction, ปัดเป็น int) + `Exp_DT`
5. **ออกแต้ม**: `LmsCrmPointService.Issue` (Point_Calc=Custom, Override_Exp_DT) → [[02-AddFundsV2-Usage]]
   - ใช้ `orderId` (หรือ buyId) เป็น `transactionId` = idempotent (ซ้ำ → `Is_Duplicate_TX`)
6. **set `IsUse = true`** ผูกกับ order/buyId
7. **return สถานะ** (ออกสำเร็จ / ซ้ำ / ไม่เข้าเงื่อนไข / order ไม่เจอ)

## จุดวาง endpoint (อิงของจริง)
- โปรเจกต์ transaction เดิม: `LMS.Transaction/` (auto flow ผ่าน ServiceBus → `LmsTransactionProcessor`)
- Manual (คนกรอกเอง) น่าจะเป็น HTTP endpoint — เลือกได้ระหว่าง:
  - [ ] เพิ่มใน API project (`LMS.Backend.Api`) แล้วเรียก core service
  - [ ] หรือ project เฉพาะทางถ้ามี
  → ตัดสินใจใน [[05-Open-Questions]]

## ลำดับ transaction / กัน race
- [ ] step 2 (เช็ค IsUse) + step 6 (set IsUse) ต้องอยู่ใน lock/transaction เดียว หรือพึ่ง idempotent ของ Issue
- ทางลัด: ให้ `Issue` เป็นด่านกันซ้ำหลัก (transactionId + lockCustomer ในตัว) แล้ว IsUse เป็นแค่ cache สถานะ
  → เขียนแต้มสำเร็จค่อย set IsUse; ถ้า crash หลังออกแต้มก่อน set flag → รอบหน้า AddFundsV2 คืน duplicate อยู่ดี ปลอดภัย

## return model (ร่าง)
```
{ orderId, buyId, status, matchedCriteria, calculatedPoint, expDt, alreadyIssued }
```
