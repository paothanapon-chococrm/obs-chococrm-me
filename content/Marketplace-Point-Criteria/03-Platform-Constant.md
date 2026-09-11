# Platform Constant (core)

กลับไป [[00-Overview]] · schema [[01-Schema]]

`BCRM_MKP_Criteria_Config.PlatformId` เก็บเป็น **int code** อ้าง Constants ใน lms-core แทนการทำ FK ไปตาราง `BCRM_Master_Channel` — ไม่ต้อง join, derive ชื่อ platform ได้จาก `GetDesc()`

## สถานะปัจจุบันใน core
ยัง**ไม่มี** constant ที่ group marketplace platform (Shopee/Lazada/Tiktok/MyShop) โดยตรง
- pattern ที่ยึดเป็นแบบ: `Choco.LMS.Core/Constants/OrderingMethod/LmsOrderingMethodConst.cs` → class `Type` (int const + `Desc` + `GetDesc(int)`)
- constant ชื่อ `Platform` ที่มีอยู่ (`LmsCommonConst.Platform`, `LmsBrandConst.Platform`) เป็นคนละความหมาย (WebApp/CRMPOS/CDP, crm-pos/crm-user…) **ห้ามเอามาใช้**

## ที่ต้องเพิ่มใน core (ก่อน implement จริง)
เพิ่ม constant class ใหม่สำหรับ marketplace platform ตาม pattern `LmsOrderingMethodConst.Type` เช่น:

```csharp
// Choco.LMS.Core/Constants/Marketplace/LmsMarketplaceConst.cs
public static partial class LmsMarketplaceConst
{
    public static class Platform
    {
        public const int LAZADA     = 1;
        public const int SHOPEE     = 2;
        public const int LINEMYSHOP = 3;
        public const int TIKTOKSHOP = 4;

        public static List<int> ValidList { get; } = [LAZADA, SHOPEE, LINEMYSHOP, TIKTOKSHOP];

        public static class Desc
        {
            public const string LAZADA     = "lazada";
            public const string SHOPEE     = "shopee";
            public const string LINEMYSHOP = "linemyshop";
            public const string TIKTOKSHOP = "tiktokshop";
        }

        public static string GetDesc(int id) => id switch
        {
            LAZADA     => Desc.LAZADA,
            SHOPEE     => Desc.SHOPEE,
            LINEMYSHOP => Desc.LINEMYSHOP,
            TIKTOKSHOP => Desc.TIKTOKSHOP,
            _ => string.Empty,
        };
    }
}
```

> id/desc ด้านบนเป็นชุดที่ยืนยันแล้ว: `1=lazada, 2=shopee, 3=linemyshop, 4=tiktokshop` — `PlatformId` ในตารางอ้างค่าเดียวกันนี้

## ผลต่อ schema
- ไม่ต้องมี column `Platform_Desc` — derive จาก `LmsMarketplaceConst.Platform.GetDesc(PlatformId)`
- validate `PlatformId` ด้วย platform ที่ brand เปิดใช้ (ดูหัวข้อล่าง) ไม่ใช่ `ValidList` ทั้งหมด

## Per-brand enabled platforms (แต่ละ brand เปิด platform ไม่เท่ากัน)
platform ที่ brand ให้บริการเก็บ **per-brand ใน `BCRM_Config`** (ไม่ทำตารางใหม่ / ไม่มีหน้าจอ toggle — set ด้วย SQL) :

| column | ค่า |
|---|---|
| `Namespace` | `NULL` |
| `Key` | `mkp-enabled-platforms` |
| `Data_Flag` | `1` (String) |
| `String_Val` | CSV ของ PlatformId เช่น `1,2,4` |

- constant: `LmsMarketplaceConst.Platform.EnabledConfig` (`NAME_SPACE = null`, `KEY = "mkp-enabled-platforms"`)
- **ไม่มีแถว = เปิดครบทุก platform** (default) — brand เก่าไม่ต้อง migrate อะไร
- อ่านผ่าน `ILmsMarketplaceCriteriaService.GetEnabledPlatforms(brandRef)` → intersect กับ `ValidList` เสมอ (กันค่าขยะ / platform ที่ถอดออกแล้ว)

### จุดที่ใช้ (2 seam)
1. `LmsMarketplaceCriteriaService.Upsert` — reject ถ้า `PlatformId` ไม่อยู่ใน enabled list (error `1000400` "Platform นี้ไม่ได้เปิดใช้สำหรับ brand นี้") — ย้ายมาจาก `ValidateAndNormalize` เดิม
2. `OrderStatusList` API — dropdown platform โชว์เฉพาะที่ brand เปิด (handler เรียก `GetEnabledPlatforms`, req เพิ่ม `Brand_Ref` ที่ controller set จาก token)

### set ตัวอย่าง (per brand DB)
```sql
-- brand นี้ให้บริการเฉพาะ lazada + shopee + tiktokshop
INSERT INTO BCRM_Config (Namespace, [Key], Data_Flag, String_Val, Created_DT, Updated_DT)
VALUES (NULL, 'mkp-enabled-platforms', 1, '1,2,4', GETDATE(), GETDATE());
```
> config มี cache ใน `LmsConfigContext` — แก้ String_Val แล้วอาจต้อง reload/รอ cache expire
