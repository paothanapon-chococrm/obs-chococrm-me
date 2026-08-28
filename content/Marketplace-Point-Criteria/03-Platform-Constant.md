# Platform Constant (core)

กลับไป [[00-Overview]] · schema [[01-Schema]]

`CRM_Criteria_Config.PlatformId` เก็บเป็น **int code** อ้าง Constants ใน lms-core แทนการทำ FK ไปตาราง `BCRM_Master_Channel` — ไม่ต้อง join, derive ชื่อ platform ได้จาก `GetDesc()`

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
- validate `PlatformId` ด้วย `Platform.ValidList` ตอนรับ request
