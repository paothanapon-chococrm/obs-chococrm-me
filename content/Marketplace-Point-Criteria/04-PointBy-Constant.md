# Point By Constant

กลับไป [[00-Overview]] · schema [[01-Schema]] · mapping [[02-UI-Mapping]]

`BCRM_MKP_Criteria_Config.Point_By` เก็บเป็น **bitmask** ของ 3 mode พื้นฐาน — 1 bit ต่อ 1 mode. combo = OR bit เข้าด้วยกัน ไม่ต้อง enumerate 7 เคสมือ, เพิ่ม mode ที่ 4 ในอนาคตก็แค่เพิ่ม bit ถัดไป (`1 << 3`)

## 3 mode พื้นฐาน (= 3 bit)
| mode | bit | ค่า | ช่องบน form | column | สูตรแต้ม |
|---|:-:|:-:|---|---|---|
| Fixed | `1 << 0` | 1 | Fixed point + Extra | `Fixed_Point`, `Extra_Point` | `Fixed_Point + Extra_Point` (คงที่) |
| Spending | `1 << 1` | 2 | ยอดต่อรอบ + แต้มต่อรอบ เช่น "500 บ ได้ 10 point" | `Spending_Base`, `Spending_Point` | `floor(ยอดบิล / Spending_Base) × Spending_Point` (คำนวณตอน earn จากยอดบิลจริง) |
| SKUs | `1 << 2` | 4 | section **SKUs** หลายแถว | `BCRM_MKP_Criteria_Config_SKU` | ต่อ SKU ที่ซื้อ: `floor(จำนวนที่ซื้อ / Quantity) × Point_Per_Qty` (คำนวณตอน earn จากรายการ item จริง — เหมือน Spending) |

## 7 ตัวเลือกใน dropdown → ค่า `Point_By`
combo ทั้งหมด = OR ของ bit ที่เปิด. ลำดับแสดง: single ก่อน แล้วค่อย combo (เลขไม่เรียงต่อกันแล้ว — เป็น bit)

| `Point_By` | bits  | Dropdown                       | Fixed | Spending | SKUs |
| :--------: | :---: | ------------------------------ | :---: | :------: | :--: |
|     1      | `001` | Fixed points                   |   ✓   |          |      |
|     2      | `010` | Spending                       |       |    ✓     |      |
|     4      | `100` | SKUs                           |       |          |  ✓   |
|     3      | `011` | Fixed points + Spending        |   ✓   |    ✓     |      |
|     5      | `101` | Fixed points + SKUs            |   ✓   |          |  ✓   |
|     6      | `110` | Spending + SKUs                |       |    ✓     |  ✓   |
|     7      | `111` | Fixed points + Spending + SKUs |   ✓   |    ✓     |  ✓   |

แต้มที่เกณฑ์ให้ = ผลรวมของ mode ที่ ✓. `Grand_Total_Point` เก็บเฉพาะส่วนคงที่ (**Fixed เท่านั้น**); ทั้ง **Spending และ SKUs คำนวณตอน earn** เพราะต้องเห็นยอดบิล/รายการ item จริงก่อน (save-time ไม่รู้ว่าลูกค้าซื้ออะไรกี่ชิ้น)

## constant ที่ต้องเพิ่มใน core
bit const + bitwise `HasX` + `GetDesc`. ตรรกะ code→mode เป็น bit-test ที่เดียว:

```csharp
// Choco.LMS.Core/Constants/Marketplace/LmsMarketplaceConst.cs
public static partial class LmsMarketplaceConst
{
    public static class PointBy
    {
        public const int FIXED    = 1 << 0;   // 1
        public const int SPENDING = 1 << 1;   // 2
        public const int SKUS     = 1 << 2;   // 4

        public const int ALL = FIXED | SPENDING | SKUS;   // 7

        // code ไหนเปิด mode อะไร — bit-test จุดเดียว
        public static bool HasFixed(int p)    => (p & FIXED)    != 0;
        public static bool HasSpending(int p) => (p & SPENDING) != 0;
        public static bool HasSkus(int p)     => (p & SKUS)     != 0;

        // valid = อย่างน้อย 1 bit และไม่มี bit นอก 3 mode
        public static bool IsValid(int p) => p > 0 && (p & ~ALL) == 0;

        // ลำดับที่โชว์บน dropdown (single ก่อน combo)
        public static List<int> DropdownOrder { get; } =
            [FIXED, SPENDING, SKUS, FIXED | SPENDING, FIXED | SKUS, SPENDING | SKUS, ALL];

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

> validate: `PointBy.IsValid(Point_By)` (แทน `ValidList.Contains`), `Point_By_Desc` derive จาก `GetDesc()`

## เก็บ 7 ค่าไว้ไหน + เสิร์ฟให้ dropdown ยังไง
**ไม่เก็บใน DB** — pattern ของ backend นี้คือ dropdown ทุกตัว build จาก constant ใน core แล้วเปิด **list endpoint** คืน `List<OptionResp>` (`{ int Value; string Desc }`) เหมือน `PrivilegeCriteriaGroup/PointModeList`, `StatusList`

3 ชิ้นต่อ 1 dropdown (copy pattern เดิม):
1. **Req** — `MarketplacePointByListReq : IRequest<List<OptionResp>>` (empty)
2. **Handler** — วน `PointBy.DropdownOrder` สร้าง `OptionResp { Value = p, Desc = GetDesc(p) }`
3. **Controller action** — `PointByList()` → send req → คืน list

```csharp
// Handler
public override async Task<List<OptionResp>> HandleRequest(
    MarketplacePointByListReq req, CancellationToken ct)
    => LmsMarketplaceConst.PointBy.DropdownOrder
        .Select(p => new OptionResp { Value = p, Desc = LmsMarketplaceConst.PointBy.GetDesc(p) })
        .ToList();
```

> `PlatformId` ([[03-Platform-Constant]]) และ Order Status ก็ทำ list endpoint แบบเดียวกัน — source เป็น constant คนละ class เท่านั้น
> ถ้าต้องการ Desc 2 ภาษาค่อยเปลี่ยนเป็น `List<TwoLangOptionResp>` (`Desc_Th`/`Desc_En`) เหมือน `StatusList`

## เขียน/อ่าน mode ในโค้ดยังไง
ตอนรับจาก UI เก็บ code ที่ dropdown ส่งมาตรงๆ, ตอนให้แต้มก็ถาม `HasX(Point_By)` ว่า bit ไหนเปิด (bit-test รวมอยู่ที่ `HasX` ที่เดียว ไม่กระจาย)

```csharp
// ตอน earn — มี order (bill + รายการ item) จริงแล้ว
int p = cfg.Point_By;   // เช่น 5 = 101 = Fixed points + SKUs
int total = 0;

if (PointBy.HasFixed(p))                                   // 5 & 1 → true (คงที่ รู้ตั้งแต่ save)
    total += cfg.Fixed_Point + cfg.Extra_Point;

if (PointBy.HasSpending(p))                                // 5 & 2 → false, ข้าม
    total += order.Amount / cfg.Spending_Base * cfg.Spending_Point;

if (PointBy.HasSkus(p))                                    // 5 & 4 → true — ต้องดูรายการ item จริง
    total += skuRows.Sum(s =>
        order.QtyOf(s.SKU) / s.Quantity * s.Point_Per_Qty);   // floor ต่อ SKU ที่ซื้อ
```

- **ทั้งบล็อกนี้รันตอน earn** (Fixed ก็เอามารวม ณ ตอนนั้น) — save-time เก็บได้แค่ `Grand_Total_Point = Fixed + Extra` ไว้โชว์ preview
- แต่ละ mode เป็น `if` แยก **ไม่ใช่ `else if`** — combo เปิดพร้อมกันได้ แต้มบวกสะสม (`+=`) ตรงกับ [[02-UI-Mapping]] ว่า multi-mode = รวมกัน
- อยากได้ badge Fixed/Spending/SKUs ในหน้า List ก็ถาม `HasX(Point_By)` เหมือนกัน
- ไม่มี `switch (p)` 7 เคสให้ต้อง maintain — bit-test 3 ตัวครอบทุก combo

## Resync ข้อมูลเดิม (ถ้ามี data สคีมา 1–7 แบบเรียงลำดับอยู่ก่อน)
เดิม `Point_By` เรียง 1–7 (single 3 + combo 4). ย้ายมา bitwise แล้ว **ความหมายสลับเฉพาะ 3 ↔ 4**; ที่เหลือ (1, 2, 5, 6, 7) ค่าเดิม = ความหมายเดิมพอดี

| old | old meaning | new value |
|:-:|---|:-:|
| 1 | Fixed | 1 |
| 2 | Spending | 2 |
| **3** | **SKUs** | **4** |
| **4** | **Fixed + Spending** | **3** |
| 5 | Fixed + SKUs | 5 |
| 6 | Spending + SKUs | 6 |
| 7 | ทั้งหมด | 7 |

```sql
-- swap เฉพาะ 3↔4 (ที่เหลือไม่แตะ). ครั้งเดียวจบ, idempotent ไม่ได้ — รันซ้ำจะ swap กลับ
UPDATE BCRM_MKP_Criteria_Config
SET Point_By = CASE Point_By WHEN 3 THEN 4 WHEN 4 THEN 3 ELSE Point_By END
WHERE Point_By IN (3, 4);
```

> `Point_By_Desc` **ไม่ต้องแก้** — desc ผูกกับความหมาย ไม่ใช่ตัวเลข, และความหมายของทุก row คงเดิม (old 3 = SKUs → new 4 ก็ยัง SKUs). ถ้าจะชัวร์ค่อย re-derive ทีหลังด้วย `GetDesc(Point_By)`
> ถ้าเพิ่งจะเริ่มลง (ยังไม่มี data) — ข้ามส่วนนี้ได้เลย
