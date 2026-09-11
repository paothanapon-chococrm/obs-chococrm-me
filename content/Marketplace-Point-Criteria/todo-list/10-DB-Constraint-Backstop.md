# ⏳ TODO (ยังไม่ทำ) — DB constraint backstop

กลับไป [[00-Todo-List]] · schema [[01-Schema]] · validation [[05-Validation]] · [[07-Create-Tables]]

> **สถานะ:** ยังไม่ลงมือ — บันทึกไว้กันลืม. ตัดสินใจ (2026-09-02) ว่ายังไม่เพิ่มตอนนี้

## ปัญหา
กฎทั้งหมด (R1–R4, bitmask, derive) อยู่ที่ **app layer (`LmsMarketplaceCriteriaService`) ไม่ใช่ DB**. ตอนนี้ DB มีแค่ PK / FK / NOT NULL / default — **ไม่มี CHECK, ไม่มี unique** (R1 filtered index เขียนไว้แล้วแต่ comment ปิดใน [[07-Create-Tables]]).

ผลคือ ถ้าใครยิง SQL แก้ row ตรงๆ = **bypass ทุก validation** และ unit test (`LmsMarketplaceConstTest`) จับไม่ได้ เพราะมันเฝ้าแค่โค้ด constant ไม่ได้เฝ้า data.

## เคสที่พังจริง (แดง — ควรปิดด้วย DB constraint)
| แก้ data | ผลตอน earn |
|---|---|
| `Spending_Base = 0` (Point_By เปิด SPENDING) | `Amount / Spending_Base` → **หารด้วยศูนย์ ระเบิด** |
| SKU `Quantity = 0` | `floor(qty / Quantity)` → **หารด้วยศูนย์** |
| 2 row `IsActive=1` platform เดียว | `GetActiveByPlatform` = `FirstOrDefault` → **หยิบมั่ว ไม่ determinstic** |
| `Point_By = 99` (ค่ามั่ว) | bit-test ค่าขยะ → เปิด mode ผิด แจกแต้มผิด (ไม่ re-validate ตอนอ่าน) |
| `PlatformId` นอก 1–4 | channel ว่างบนจอ + earn ไม่เจอ |

## เคสที่ constraint ก็กันไม่ได้ (ต้องพึ่ง "อย่าแก้ DB มือ")
- `Order_Status` เพี้ยน/ผิด case → earn match ไม่เจอ ลูกค้าไม่ได้แต้มเงียบๆ (token set อยู่ใน **code** ไม่ใช่ table เอามาทำ CHECK ไม่ได้)
- derive-drift: `Point_By_Desc` / `Grand_Total_Point` / `Order_Status_Desc` แก้แล้วไม่ตรงตัวเลขจริง (แค่ display เพี้ยน earn ไม่ได้ใช้ desc)

## สิ่งที่จะเพิ่ม (เมื่อพร้อม) — ลง [[07-Create-Tables]]
```sql
-- R1: 1 active ต่อ platform (มีใน 07 แล้ว แค่ปลด comment)
CREATE UNIQUE INDEX UX_MKP_Criteria_ActivePerPlatform
    ON BCRM_MKP_Criteria_Config (PlatformId) WHERE IsActive = 1 AND IsDeleted = 0;

-- กันหารศูนย์ + ค่ามั่ว (เพิ่มใหม่)
ALTER TABLE BCRM_MKP_Criteria_Config     ADD CONSTRAINT CK_MKP_PointBy   CHECK (Point_By BETWEEN 1 AND 7);
ALTER TABLE BCRM_MKP_Criteria_Config     ADD CONSTRAINT CK_MKP_Platform  CHECK (PlatformId BETWEEN 1 AND 4);
ALTER TABLE BCRM_MKP_Criteria_Config     ADD CONSTRAINT CK_MKP_Spending  CHECK (Spending_Base >= 0 AND Spending_Point >= 0);
ALTER TABLE BCRM_MKP_Criteria_Config_SKU ADD CONSTRAINT CK_MKP_SKU_Qty   CHECK (Quantity > 0);
```

> ⚠️ ก่อนเปิด R1 unique index ต้องเช็คว่า data เดิมไม่มี platform ไหน active ซ้ำอยู่แล้ว (ไม่งั้น create index fail)
> ⚠️ CHECK เป็น per-brand DB — ต้องรันทุก brand เหมือน [[07-Create-Tables]]
