---
tags: [work, lms, questions]
created: 2026-08-20
---

# Open Questions — ต้องเคลียร์ก่อน/ระหว่างทำ

## บล็อกงาน (ต้องตอบก่อนเริ่ม code)
- [ ] **Data order ฝั่งเราเก็บที่ไหน?** table อะไร, มี `orderId` + `buyerId` ครบไหม + **ต้องมี line-item ราย SKU (SKU, qty)** ไม่ใช่แค่ยอดรวม (สมมติว่ามี — prereq ของ SKU track [[11-SKU]]) → บล็อก [[03-Manual-Endpoint]] step 1
- [ ] **ShopId เก็บที่ table ไหน** (channel account) — ต้องแนบตอน query orderId + เป็น key ของ mapping → [[08-Buyer-Customer-Mapping]]
- [ ] **auto-link จับ customer ด้วย key อะไร** (เบอร์/email/ชื่อ จาก order) กันผูกผิดคน → [[08-Buyer-Customer-Mapping]]
- [ ] **Criteria config schema** ที่ UI ส่งมาหน้าตายังไง → บล็อก [[01-Criteria-Config]]
- [ ] `IsUse` เก็บที่ table order เดิม หรือ mapping table ใหม่ → [[04-Data-IsUse-Flag]]

## ตัดสินใจ design
- [x] 1 order → **match ได้หลาย config** (มี scope Channel/Shop/Date range) → design ที่ [[01-Criteria-Config]]
- [x] **ตัด Priority + ตัด All-Shop** (บังคับเลือกร้าน) เพื่อลดความยุ่งยาก → [[01-Criteria-Config]]
- [x] **config-time validate**: sku-rule ห้าม `(Shop, SKU, เวลา)` ซ้อน (เช็ครายตัว SKU) · spend-rule ห้าม `(Shop, เวลา)` ซ้อน → Error บอกช่วงเวลา + rule ที่ชน
- [x] **runtime**: ไม่มี conflict — 2 track (SKU loop + Spend) → **บวกกัน (stack)** → จบ (ยังไม่มี cap, YAGNI)
- [x] **Type = bitflag Spend/Sku/Both** (เหมือน `ReceiptPointType` Document): Both = rule เดียวป้อน 2 track · config-time validate **ราย component** (bit) → [[01-Criteria-Config]]
- [x] ราคาที่จ่าย (promo ต้องตั้งทีละร้าน) → **รับได้** "ให้ admin เหนื่อยตั้งแทน ไม่เหนื่อยเรา"
- [x] **Result_Mode อยู่ราย SKU**: per SKU เลือก คงที่/คูณ · คูณ = ×base เดิม `Point_Per_Unit` · spend คิดตรง (บาท→แต้ม) ไม่มีคูณ → [[01-Criteria-Config]]
- [ ] endpoint แยก preview/confirm ไหม หรือ one-shot
- [ ] วาง endpoint ที่ project ไหน (`LMS.Backend.Api`?)
- [x] wallet เป้าหมายเป็นชนิด **CRM** → ใช้ `LmsCrmPointService.Issue` (set `Override_Exp_DT`) ไม่ใช่ AddFundsV2 ตรง

## ยืนยันแล้ว ✅
- [x] ออกแต้มผ่าน `LmsCrmPointService.Issue` ตัวหลัก (wallet เป็น CRM) — **เลิกใช้ AddFundsV2 ตรง**
      ส่ง `Point_Calc=Custom(9)` + `Point` + `Override_Exp_DT=true` + `Exp_DT` คุม exp เอง → [[02-AddFundsV2-Usage]]
- [x] `refInfo` (`CrmPointRefInfo`) = metadata trace ที่มาของแต้ม (ส่ง null ได้) ไม่ใช่ input การคิดคะแนน
      → manual: `Reference=orderId`, `Extra_Ref=buyId`
- [x] ต้องมี flag บอกว่าคิดแต้มไปแล้ว (IsUse)
- [x] เลือก **Shop/Channel ก่อน** แล้ว query orderId ของร้านนั้น (แนบ ShopId ทุก query)
- [x] mapping key = **`(ShopId, BuyerId)` → CRM_CustomerId** (N:1, BuyerId ไม่ unique ข้ามร้าน) → [[08-Buyer-Customer-Mapping]]
- [x] **ไม่ทำ Pending Point** — `Issue` โพสต์เข้า `WL_Wallet_Ledger` (balance) เลย ใช้ได้ทันที
      (core CRM point มีแค่ Posted/Void ไม่มี pending state อยู่แล้ว). order ที่ยังไม่ถึง status ปล่อยแต้ม = คิดไม่ได้

## เรื่องต้องระวัง (technical)
- [ ] `Exp_DT` ต้องเป็น **UTC** (DB GETDATE()=UTC) — อย่าส่ง local time
- [ ] ใช้ `orderId`/`buyId` เป็น `transactionId` เพื่อ idempotent
- [x] ช่วงเวลา rule = **inclusive `[From, Through]`** · วันชนขอบถือว่าชน → block, admin แก้เป็นวันถัดไปเอง → [[01-Criteria-Config]]
