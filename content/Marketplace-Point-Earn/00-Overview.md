# Marketplace Point Earn (WebApp) — Overview

ขา **WebApp** ที่ลูกค้ากดรับแต้มจากออเดอร์ marketplace ด้วยตัวเอง — กรอกแค่ **`OrderId` + `PlatformId`** ระบบไปดึงออเดอร์จาก marketplace hub, match กับเกณฑ์ที่ตั้งไว้ ([[../Marketplace-Point-Criteria/00-Overview]]) แล้วออกแต้มให้

เป็น "ผู้บริโภค" ของ `CRM_Criteria_Config` — ฝั่ง Criteria คือ config, ฝั่งนี้คือ transaction

## Input จากผู้ใช้
| Field | มาจาก | Note |
|---|---|---|
| `OrderId` | ผู้ใช้กรอก | เลขออเดอร์ในระบบ marketplace (string) |
| `PlatformId` | ผู้ใช้เลือก | `LmsMarketplaceConst.Platform` — lazada/shopee/linemyshop/tiktokshop ([[../Marketplace-Point-Criteria/03-Platform-Constant]]) |

ลูกค้า (identity) มาจาก session WebApp ที่ login อยู่ ไม่ต้องกรอก

## สิ่งที่ระบบ derive เอง (ผู้ใช้ไม่กรอก)
ดึงจาก marketplace hub ด้วย `(PlatformId, OrderId)`:
- ร้านค้า (`Store_Ref`), สถานะออเดอร์, ยอด/จำนวน SKU
แล้ว match กับ `CRM_Criteria_Config_Detail` (store + order status) → ได้เกณฑ์ + แต้มที่จะให้

> [!warning] ดีไซน์ที่ตั้งใจ — โค้ดยังไม่ทำครบ
> การ match ด้วย **store + order status** ข้างบนคือ **เป้าหมาย** เท่านั้น. โค้ดตอนนี้ยัง gate ด้วย **platform อย่างเดียว** (store ตรงไม่ตรงไม่มีผล) เพราะ shop list ยังไม่เสร็จ → รายละเอียด [[04-Store-Gating-ยังไม่-enforce]]

## โครงสร้างข้อมูล
| ตาราง | หน้าที่ |
|---|---|
| `CRM_Criteria_Claim` | 1 แถว = 1 ครั้งที่ลูกค้าเคลมแต้มจาก 1 ออเดอร์ (กันเคลมซ้ำด้วย unique `(PlatformId, Order_Ref)`) |

ไม่มีตาราง config ใหม่ — ใช้ `CRM_Criteria_Config` เดิม

## เอกสาร
- [[01-Schema]] — ตาราง claim + ER
- [[02-Flow]] — ลำดับการเคลม + จุด validate + กันเคลมซ้ำ
- [[03-API-Spec]] — endpoint `EarnCalculate` (req/resp/status/สูตร) — เฟสคำนวณ (ทำแล้ว, lazada)
- [[04-Store-Gating-ยังไม่-enforce]] — ⚠️ **store/status gate ยังไม่ทำ** (คิดแต้มด้วย platform อย่างเดียว) — อ่านก่อนตรวจว่าแต้มออกถูก

## Convention ที่ยึด
เหมือนฝั่ง Criteria — อ้าง lms-core:
- PK `<Entity>Id` (int identity), status int คู่ `*_Desc`
- ออกแต้มผ่าน flow core `CrmPointIssueDto` (`Point_Calc`, `Spending`) + `CrmPointRefInfo` (`Store_Ref`, `Reference`, `Channel`, `Area`) — ไม่คำนวณ/insert point ledger เอง
- Audit: `Req_IdentityId`, `Req_Identity_SRef`, `CreatedTime`, `CreatedUser`, `UpdatedTime`, `UpdatedUser`
