# Validation Rules

กลับไป [[00-Overview]] · schema [[01-Schema]] · Point By [[04-PointBy-Constant]]

รวม rule ที่ต้องเช็คตอน Add / Edit ก่อนบันทึก `CRM_Criteria_Config`

## R1 — 1 Platform มีเกณฑ์ที่ active ได้แค่ 1 เกณฑ์
ต่อ 1 `PlatformId` มีแถวที่ `IsActive = true` (และ `IsDeleted = false`) ได้ **ไม่เกิน 1**

- ตอน save ถ้าจะตั้ง `IsActive = true` → เช็คว่าไม่มีเกณฑ์อื่น `PlatformId` เดียวกันที่ active อยู่แล้ว
- ถ้ามี → **reject** บอก user ให้ปิด (`IsActive = false`) ตัวเก่าก่อน แล้วค่อยเปิดตัวใหม่ (ไม่ auto-ปิดให้)
- ต้อง exclude ตัวเอง (`Criteria_ConfigId != @current`) ตอน edit ตัวที่ active อยู่แล้ว

```csharp
// ใน Add/Edit handler ก่อน save เมื่อ req.IsActive == true
bool hasActive = await db.CRM_Criteria_Config.AnyAsync(x =>
    x.PlatformId == req.PlatformId &&
    x.IsActive && !x.IsDeleted &&
    x.Criteria_ConfigId != req.Criteria_ConfigId, ct);   // 0 ตอน Add

if (hasActive)
    return Error("มีเกณฑ์ที่ใช้งานอยู่ของ Platform นี้แล้ว ปิดตัวเดิมก่อนจึงเปิดตัวใหม่ได้");
```

// อันนี้ ข้อแนะนำเฉยๆ กัน Race 

> DB-level backstop (ถ้าอยากกันแน่น): filtered unique index
> `CREATE UNIQUE INDEX UX_Criteria_ActivePerPlatform ON CRM_Criteria_Config(PlatformId) WHERE IsActive = 1 AND IsDeleted = 0;`
> — ponytail: เริ่มด้วย app-check ตาม pattern handler เดิมก่อน; เพิ่ม filtered index เมื่อกลัว race condition

## R2 — field ตาม `Point_By` ที่เลือก
`Point_By` เปิด mode ไหน field ของ mode นั้นต้องมีค่า (ดู `HasFixed/HasSpending/HasSkus` ใน [[04-PointBy-Constant]])

| mode ที่เปิด | ต้องมี |
|---|---|
| Fixed | `Fixed_Point >= 0` (Extra จะ 0 ได้) |
| Spending | `Spending_Base > 0` (**ห้าม 0** — หารตอน earn), `Spending_Point > 0` |
| SKUs | มี `CRM_Criteria_Config_SKU` ≥ 1 แถว, ทุกแถว `Quantity > 0` และ `Point_Per_Qty >= 0` |

- mode ที่ **ไม่เปิด** → บังคับ field เป็น 0 / ไม่มีแถว (กันข้อมูลขยะ)

## R3 — ค่า enum/constant ต้อง valid
- `Point_By` ∈ `PointBy.ValidList` (1–7) · [[04-PointBy-Constant]]
- `PlatformId` ∈ `Platform.ValidList` · [[03-Platform-Constant]]
- `Order_Status` ∈ ชุด code สถานะออเดอร์ที่ยืนยันแล้ว · [[02-UI-Mapping]]

## R4 — required พื้นฐาน
- `Criteria_Name` ไม่ว่าง
- เลือกร้าน ≥ 1 (มี `CRM_Criteria_Config_Detail` ≥ 1 แถว) และแต่ละร้านต้องเลือก `Order_Status`
- SKU ในเกณฑ์เดียวกันห้ามซ้ำ (`SKU` unique ต่อ `Criteria_ConfigId`)

## Derive ตอน save (ไม่รับจาก client)
- `Point_By_Desc` = `PointBy.GetDesc(Point_By)`
- `Order_Status_Desc`, platform desc — derive จาก constant
- `Grand_Total_Point` = `Fixed_Point + Extra_Point` เท่านั้น (Spending + SKUs ไม่รวม — คำนวณตอน earn จากยอดบิล/รายการ item จริง)
