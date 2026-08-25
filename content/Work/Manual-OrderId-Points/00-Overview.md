---
tags: [work, lms, points, manual-order]
status: planning
created: 2026-08-20
---

# Manual OrderId → คิดแต้ม (Overview)

> 🗺️ ภาพรวมหน้าเดียว → graph relation [[09-System-Relation-Graph]] · sequence diagram [[10-Sequence-Diagram]]

> [!summary] งานคืออะไร
> เพิ่มช่องทาง **manual** ให้กรอก `orderId` เอง แล้วระบบ query order ฝั่งเรา,
> เช็คเงื่อนไข, เลือก criteria config ที่จะใช้คิดคะแนน, ออกแต้มผ่าน `LmsCrmPointService.Issue`
> (ส่ง `Override_Exp_DT + Exp_DT` กำหนดวันหมดอายุเองตามที่คำนวณ) และ mark ว่า order นี้คิดแต้มไปแล้ว

## Flow ที่ต้องทำ (จากที่จดไว้)

```
เลือก Shop/Channel → กรอก orderId
   ↓
query DB ฝั่งเรา (แนบ ShopId, หา order + buyerId)
   ↓
หา/auto-link (ShopId, BuyerId) → CRM_CustomerId  ← [[08-Buyer-Customer-Mapping]]
   ↓
[เงื่อนไขแรก] order นี้เคยคิดแต้มไปแล้วหรือยัง?  ← flag IsUse
   ↓ ยังไม่เคย
เลือก criteria config ไหนที่ใช้คิดคะแนน
   ↓
คำนวณแต้ม (สูตร × transaction) + วันหมดอายุ
   ↓
LmsCrmPointService.Issue (Point_Calc=Custom, Override_Exp_DT)  ← ดู [[02-AddFundsV2-Usage]]
   ↓
set IsUse = true (กันคิดซ้ำ)
   ↓
show สถานะกลับไป
```

## แบ่งเฟส

- [ ] **Phase 1 — Criteria config** (รอ UI) → [[01-Criteria-Config]]
  - [x] เข้าใจ action ที่มีคร่าวๆ แล้ว
  - [ ] สรุป schema/รูปแบบ config ที่ UI จะส่งมา
- [ ] **Phase 2 — Manual endpoint** → [[03-Manual-Endpoint]]
  - [ ] ดูวิธีเก็บ data order ฝั่งเรา (สำคัญ — ยังไม่รู้)
  - [ ] เลือก Shop → query orderId (แนบ ShopId) → order + buyerId
  - [ ] หา/auto-link (ShopId, BuyerId) → customer → [[08-Buyer-Customer-Mapping]]
  - [ ] เช็ค IsUse (เคยคิดแต้มยัง)
  - [ ] match criteria config
  - [ ] คิดแต้ม + exp
  - [ ] เรียก LmsCrmPointService.Issue
  - [ ] set IsUse
  - [ ] return สถานะ
- [ ] **Phase 3 — Data flag IsUse** → [[04-Data-IsUse-Flag]]
- [ ] **Phase 4 — Buyer↔Customer mapping** → [[08-Buyer-Customer-Mapping]] (key `(ShopId, BuyerId)`, N:1)

## User Journey
user ต้องทำอะไรบ้าง (3 actor) → [[07-User-Journey]]

## จุดที่ยังต้องเคลียร์ (Open Questions)
ดูรวมที่ [[05-Open-Questions]]

## Context ภาพใหญ่ (mockup ทั้งโมดูล)
งานเราเป็นส่วนหนึ่งของโมดูล **Marketplace Point Accumulation** (4 ซับโมดูล: Dashboard /
Channel Connection / Point Criteria / Campaign Period) → รายละเอียด + REQ table ที่ [[06-MKP-Reference]]
(⚠️ ยังไม่ลงมติ เอาเป็นแนว)

## Related code (ของจริงในโปรเจกต์)
- Auto flow เดิม: `LMS.Transaction/Services/LmsTransactionProcessor.cs` → `IssuePointV2` → `LmsCrmPointService.Issue`
- ออกแต้ม + exp: `Choco.LMS.Core/Services/Wallet/LmsWalletService.cs` → `AddFundsV2`
- CRM point wrapper: `Choco.LMS.Core/Services/CRM/LmsCrmPointService.cs`
