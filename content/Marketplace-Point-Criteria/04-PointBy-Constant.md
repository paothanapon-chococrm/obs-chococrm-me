# Point By Constant

กลับไป [[00-Overview]] · schema [[01-Schema]] · mapping [[02-UI-Mapping]]

`CRM_Criteria_Config.Point_By` เก็บเป็น **int code เรียง 1–7** ตรงกับ 7 ตัวเลือกใน dropdown (single mode 3 + combo 4). ไม่ใช้ bitmask เพราะอยากให้เลขเรียงต่อกัน อ่านง่าย

## 3 mode พื้นฐาน
| mode | ช่องบน form | column | สูตรแต้ม |
|---|---|---|---|
| Fixed | Fixed point + Extra | `Fixed_Point`, `Extra_Point` | `Fixed_Point + Extra_Point` (คงที่) |
| Spending | ยอดต่อรอบ + แต้มต่อรอบ เช่น "500 บ ได้ 10 point" | `Spending_Base`, `Spending_Point` | `floor(ยอดบิล / Spending_Base) × Spending_Point` (คำนวณตอน earn จากยอดบิลจริง) |
| SKUs | section **SKUs** หลายแถว | `CRM_Criteria_Config_SKU` | ต่อ SKU ที่ซื้อ: `floor(จำนวนที่ซื้อ / Quantity) × Point_Per_Qty` (คำนวณตอน earn จากรายการ item จริง — เหมือน Spending) |

## 7 ตัวเลือกใน dropdown → ค่า `Point_By`
เรียง single 3 ตัวก่อน แล้วค่อย combo — เลข 1–7 ต่อกันตรงๆ

| `Point_By` | Dropdown | Fixed | Spending | SKUs |
|---|---|:-:|:-:|:-:|
| 1 | Fixed points | ✓ | | |
| 2 | Spending | | ✓ | |
| 3 | SKUs | | | ✓ |
| 4 | Fixed points + Spending | ✓ | ✓ | |
| 5 | Fixed points + SKUs | ✓ | | ✓ |
| 6 | Spending + SKUs | | ✓ | ✓ |
| 7 | Fixed points + Spending + SKUs | ✓ | ✓ | ✓ |

แต้มที่เกณฑ์ให้ = ผลรวมของ mode ที่ ✓. `Grand_Total_Point` เก็บเฉพาะส่วนคงที่ (**Fixed เท่านั้น**); ทั้ง **Spending และ SKUs คำนวณตอน earn** เพราะต้องเห็นยอดบิล/รายการ item จริงก่อน (save-time ไม่รู้ว่าลูกค้าซื้ออะไรกี่ชิ้น)

## constant ที่ต้องเพิ่มใน core
ตาม pattern `LmsOrderingMethodConst.Type` (เหมือน [[03-Platform-Constant]]) — int const + `Desc` + `GetDesc`. เพิ่ม helper `HasX` ไว้เช็คว่าแต่ละ code เปิด mode ไหน:

```csharp
// Choco.LMS.Core/Constants/Marketplace/LmsMarketplaceConst.cs
public static partial class LmsMarketplaceConst
{
    public static class PointBy
    {
        public const int FIXED_POINTS            = 1;
        public const int SPENDING                = 2;
        public const int SKUS                    = 3;
        public const int FIXED_SPENDING          = 4;
        public const int FIXED_SKUS              = 5;
        public const int SPENDING_SKUS           = 6;
        public const int FIXED_SPENDING_SKUS     = 7;

        public static List<int> ValidList { get; } = [1, 2, 3, 4, 5, 6, 7];

        // code ไหนเปิด mode อะไร — จุดเดียวที่ผูก code กับ mode
        public static bool HasFixed(int p)    => p is 1 or 4 or 5 or 7;
        public static bool HasSpending(int p) => p is 2 or 4 or 6 or 7;
        public static bool HasSkus(int p)     => p is 3 or 5 or 6 or 7;

        public static string GetDesc(int p)
        {
            var parts = new List<string>();
            if (HasFixed(p))    parts.Add("Fixed points");
            if (HasSpending(p)) parts.Add("Spending");
            if (HasSkus(p))     parts.Add("SKUs");
            return string.Join(" + ", parts);
        }
    }
}
```

> validate: `PointBy.ValidList.Contains(Point_By)`, `Point_By_Desc` derive จาก `GetDesc()`

## เก็บ 7 ค่าไว้ไหน + เสิร์ฟให้ dropdown ยังไง
**ไม่เก็บใน DB** — pattern ของ backend นี้คือ dropdown ทุกตัว build จาก constant ใน core แล้วเปิด **list endpoint** คืน `List<OptionResp>` (`{ int Value; string Desc }`) เหมือน `PrivilegeCriteriaGroup/PointModeList`, `StatusList`

3 ชิ้นต่อ 1 dropdown (copy pattern เดิม):
1. **Req** — `MarketplacePointByListReq : IRequest<List<OptionResp>>` (empty)
2. **Handler** — วน `PointBy.ValidList` สร้าง `OptionResp { Value = p, Desc = GetDesc(p) }`
3. **Controller action** — `PointByList()` → send req → คืน list

```csharp
// Handler
public override async Task<List<OptionResp>> HandleRequest(
    MarketplacePointByListReq req, CancellationToken ct)
    => LmsMarketplaceConst.PointBy.ValidList
        .Select(p => new OptionResp { Value = p, Desc = LmsMarketplaceConst.PointBy.GetDesc(p) })
        .ToList();
```

> `PlatformId` ([[03-Platform-Constant]]) และ Order Status ก็ทำ list endpoint แบบเดียวกัน — source เป็น constant คนละ class เท่านั้น
> ถ้าต้องการ Desc 2 ภาษาค่อยเปลี่ยนเป็น `List<TwoLangOptionResp>` (`Desc_Th`/`Desc_En`) เหมือน `StatusList`

## เขียน/อ่าน mode ในโค้ดยังไง
`Point_By` เป็นเลขเดียว 1–7 — ตอนรับจาก UI ก็เก็บ code ที่ dropdown ส่งมาตรงๆ, ตอนให้แต้มก็ถาม `HasX(Point_By)` ว่า mode ไหนเปิดบ้าง (ตรรกะ code→mode รวมอยู่ที่ `HasX` ที่เดียว ไม่กระจาย)

```csharp
// ตอน earn — มี order (bill + รายการ item) จริงแล้ว
int p = cfg.Point_By;   // เช่น 5 = Fixed points + SKUs
int total = 0;

if (PointBy.HasFixed(p))                                   // 5 → true (คงที่ รู้ตั้งแต่ save)
    total += cfg.Fixed_Point + cfg.Extra_Point;

if (PointBy.HasSpending(p))                                // 5 → false, ข้าม
    total += order.Amount / cfg.Spending_Base * cfg.Spending_Point;

if (PointBy.HasSkus(p))                                    // 5 → true — ต้องดูรายการ item จริง
    total += skuRows.Sum(s =>
        order.QtyOf(s.SKU) / s.Quantity * s.Point_Per_Qty);   // floor ต่อ SKU ที่ซื้อ
```

- **ทั้งบล็อกนี้รันตอน earn** (Fixed ก็เอามารวม ณ ตอนนั้น) — save-time เก็บได้แค่ `Grand_Total_Point = Fixed + Extra` ไว้โชว์ preview
- แต่ละ mode เป็น `if` แยก **ไม่ใช่ `else if`** — combo เปิดพร้อมกันได้ แต้มบวกสะสม (`+=`) ตรงกับ [[02-UI-Mapping]] ว่า multi-mode = รวมกัน
- อยากได้ badge Fixed/Spending/SKUs ในหน้า List ก็ถาม `HasX(Point_By)` เหมือนกัน
- เลี่ยง `switch (p)` 7 เคส เพราะต้องเขียนตรรกะเดิมซ้ำ — `HasX` สั้นกว่าและแก้ที่เดียว
