# Decision — แยก Status (lifecycle) ออกจาก Earn_Result (calc detail)

กลับไป [[00-Overview]] · schema [[01-Schema]] · flow [[02-Flow]]

> สถานะ: **ตกลงแนวทางแล้ว ยังไม่ลงมือ** — กลับมาทำต่อ

## ปัญหา
โค้ดตอนนี้มี `EarnStatus` 3 ค่าปนใน column เดียว:
- 1 = Calculated (เจอ order + เกณฑ์ active → คิดแต้มได้)
- 2 = OrderNotFound
- 3 = NoActiveCriteria

แต่ **จอ Marketplace โชว์ Status แค่ 2 ค่า: Confirm / Reject** → ค่า 1/2/3 มันจริงๆ คือ "1 confirm + 2 เหตุผลของ reject" ไม่ใช่สถานะที่จอโชว์

## ข้อสรุป
มัน **2 แกนคนละเรื่อง** — ต้องแยก:

| Column | ค่า | คือ | Null |
|---|---|---|---|
| `Status` | Pending / Confirm / Reject | สถานะคำขอ (lifecycle) — จอโชว์อันนี้ | No |
| `Earn_Result` | 1=Calculated, 2=OrderNotFound, 3=NoActiveCriteria | ผลการคิดแต้ม (detail/diagnostic) | Yes (null ตอน Pending) |

เหตุผล:
- Confirm/Reject **derive จาก Earn_Result ได้** (`Earn_Result == 1` → Confirm) ตราบใดที่มีแค่ 2 สถานะ
- แต่ **Pending derive ไม่ได้** เพราะตอน pending ยังไม่มีผลคำนวณเลย (Earn_Result = null) → พอ Pending เข้ามา จึงต้องมี `Status` แยกจริงๆ
- อย่าตั้งชื่อสอง column ลงท้าย `Status` เหมือนกัน (เคยคิด `State_Status` + `Status` — งงกว่าเดิม เพราะ state=status) ชื่อต้องบอกความหมายที่ต่างกัน

## ทำตอนนี้ vs ทีหลัง
- **ตอนนี้ (ยังไม่มี Pending):** มี `Earn_Result` column เดียวพอ, อย่าตั้งชื่อว่า `Status`
  - `ponytail:` YAGNI — ยังไม่มี Pending อย่าเพิ่งสร้าง column lifecycle
- **วัน Pending ship จริง:** `ALTER TABLE ADD Status` (additive migration ถูกๆ ไม่ต้อง rename/repaint ค่าเดิม, query เก่าไม่พัง)

## Query ตัวอย่าง (ตาราง `BCRM_MKP_Order_Request`)
```sql
-- Confirm
SELECT * FROM BCRM_MKP_Order_Request WHERE Earn_Result = 1;
-- Reject ทุกเหตุผล
SELECT * FROM BCRM_MKP_Order_Request WHERE Earn_Result <> 1;
-- Reject เฉพาะ order ไม่พบ
SELECT * FROM BCRM_MKP_Order_Request WHERE Earn_Result = 2;
```
ฝั่งโค้ดใช้ constant (`EarnStatus.Calculated`) แทน hardcode เลข

## ⚠️ ต้อง reconcile ชื่อ
- [[01-Schema]] ปัจจุบันใช้ตาราง `CRM_Criteria_Claim` + column `Claim_Status` (1 Success / 2 Rejected / 3 Pending) รวมทุกอย่างไว้ column เดียว
- แต่โค้ด/บทสนทนานี้อ้างตาราง `BCRM_MKP_Order_Request` + `Status`/`Earn_Result`
- **ยังไม่ตรงกัน** — กลับมาแล้วเคาะให้ชื่อตาราง + column เป็นอันเดียวก่อนลงมือ
