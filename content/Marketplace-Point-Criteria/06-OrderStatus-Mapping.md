# Order Status (ต่อ Platform)

กลับไป [[00-Overview]] · schema [[01-Schema]] · mapping [[02-UI-Mapping]]

## หลักการ — เก็บ status ดิบของ platform ตรงๆ ไม่ต้อง normalize
1 เกณฑ์ผูกกับ **1 Platform** อยู่แล้ว (`CRM_Criteria_Config.PlatformId`) → dropdown "เลือกสถานะให้คะแนน" แสดง status ของ platform นั้น แล้วเก็บ **raw token ของ platform** ลง `Order_Status` ตรงๆ

- ตั้งเกณฑ์ Shopee เลือก `COMPLETED` → เก็บ `Order_Status = "COMPLETED"`
- ตั้งเกณฑ์ Lazada เลือก `delivered` → เก็บ `Order_Status = "delivered"`

ตอน earn: order จาก hub มี (platform, raw status) → เทียบตรงๆ กับ `Order_Status` ของเกณฑ์ platform เดียวกัน **string ตรงกัน = เข้าเกณฑ์** ไม่มีชั้น map/canonical มาคั่น

## ผลต่อ schema (`CRM_Criteria_Config_Detail`)
| Column              | เดิม     | ใหม่                                                                                          |
| ------------------- | -------- | --------------------------------------------------------------------------------------------- |
| `Order_Status`      | int code | **nvarchar(64)** — raw token ของ platform (`"COMPLETED"`, `"delivered"`, …) ใช้ match กับ hub |
| `Order_Status_Desc` | nvarchar | label แสดงบน UI (เช่น "จัดส่งสำเร็จ") — optional, ไว้โชว์เฉยๆ                                 |

> เก็บ raw token เป็นตัว match ไม่ใช่ int เพราะ token คือ id ที่เสถียรจาก API แต่ละเจ้า — เทียบกับ hub ได้ตรงไม่ต้องแปลง

## เก็บที่ไหน — code constant ไม่ใช่ table
เก็บเป็น **constant ใน core** (เหมือน dropdown อื่นทั้งหมดใน repo นี้) **ไม่ทำเป็น table** เพราะ:
- เป็น reference data นิ่ง เปลี่ยนเฉพาะตอน marketplace เปลี่ยน API — ซึ่งต้อง deploy code แก้ earn-matching อยู่แล้ว
- token ต้องตรงเป๊ะกับ status ที่ hub/adapter ยิงออกมา (อยู่ใน code เหมือนกัน) — อยู่ที่เดียวกันกัน drift
- ไม่มี requirement ให้ admin เพิ่ม/แก้ status ตอน runtime และไม่ต่างราย brand
- (ถ้าวันหน้าต้องแก้ผ่านจอ/ต่าง brand ค่อยย้ายลง table — ตอนนี้ YAGNI)

```csharp
// Choco.LMS.Core/Constants/Marketplace/LmsMarketplaceConst.cs
public static class OrderStatusByPlatform
{
    public record Item(string Token, string Label);

    // token = ค่าดิบที่ hub ยิงมา (ห้ามพิมพ์ผิด), Label = ข้อความไทยบน dropdown
    // ใส่เฉพาะ status สายที่ให้แต้มได้ — ตัด cancel/return/fail/lost ออก (ไม่มีวันเลือกให้แต้ม)
    private static readonly Dictionary<int, List<Item>> Map = new()
    {
        [Platform.SHOPEE] =
        [
            new("UNPAID",             "รอชำระเงิน"),
            new("READY_TO_SHIP",      "พร้อมจัดส่ง"),
            new("PROCESSED",          "กำลังดำเนินการจัดส่ง"),
            new("SHIPPED",            "จัดส่งแล้ว"),
            new("TO_CONFIRM_RECEIVE", "รอยืนยันรับสินค้า"),
            new("COMPLETED",          "สำเร็จ"),
        ],
        [Platform.TIKTOKSHOP] =
        [
            new("UNPAID",              "รอชำระเงิน"),
            new("AWAITING_SHIPMENT",   "รอจัดส่ง"),
            new("AWAITING_COLLECTION", "รอเข้ารับพัสดุ"),
            new("PARTIALLY_SHIPPING",  "จัดส่งบางส่วน"),
            new("IN_TRANSIT",          "กำลังจัดส่ง"),
            new("DELIVERED",           "จัดส่งสำเร็จ"),
            new("COMPLETED",           "สำเร็จ"),
        ],
        [Platform.LAZADA] =
        [
            new("unpaid",        "รอชำระเงิน"),
            new("pending",       "รอดำเนินการ"),
            new("packed",        "แพ็คสินค้าแล้ว"),
            new("ready_to_ship", "พร้อมจัดส่ง"),
            new("shipped",       "จัดส่งแล้ว"),
            new("delivered",     "จัดส่งสำเร็จ"),
        ],
        [Platform.LINEMYSHOP] = [ /* ⚠️ รอ payload จริงจาก hub */ ],
    };

    public static List<Item> Get(int platformId) =>
        Map.TryGetValue(platformId, out var list) ? list : [];
}
```

> - token เก็บ case ตามต้นทาง (Shopee UPPER, Lazada lower) เพื่อ match กับ hub ตรงๆ
> - earn-matching (เทียบ `Order_Status` กับ status จาก hub) กับชุด token นี้ = source of truth เดียวกัน อยู่ไฟล์เดียวกันได้ยิ่งดี

## ชุด status ต่อ platform (dropdown source)
ชุด token เต็มที่ต้องใส่ใน `Map` ด้านบน — dropdown ดึงตาม `PlatformId` ที่เลือก

| Platform | raw token ที่เลือกได้ (จากเอกสาร API) |
|---|---|
| Shopee | UNPAID / READY_TO_SHIP / PROCESSED / RETRY_SHIP / SHIPPED / TO_CONFIRM_RECEIVE / COMPLETED / IN_CANCEL / CANCELLED / TO_RETURN |
| TikTok | UNPAID / AWAITING_SHIPMENT / AWAITING_COLLECTION / PARTIALLY_SHIPPING / IN_TRANSIT / DELIVERED / COMPLETED / CANCELLED |
| Lazada | unpaid / pending / packed / ready_to_ship / shipped / delivered / canceled / returned / failed / … |
| LineMyShop | ⚠️ ยังไม่มีชุด public — ดึงจาก payload จริงใน hub |

> ที่มา: Shopee = entity ใน `platform-marketplace-hub`; TikTok = order status API v2; Lazada = [Order Status Flow](https://open.lazada.com/apps/doc/doc?nodeId=29484&docId=120167)

## dropdown endpoint — ยิงรอบเดียว เอาทั้งก้อน
status ของทุก platform เป็น **constant นิ่ง ตัวเล็ก** (4 เจ้า × ~10 ค่า) → ไม่ต้องยิงใหม่ทุกครั้งที่สลับ channel. คืน **ทั้งก้อน group ตาม platform** ในครั้งเดียว แล้ว frontend filter ตาม `PlatformId` ที่เลือกเอง (ไม่มี param, ไม่ refetch)

```
GET api/v1/MarketplacePointCriteria/OrderStatusList
```

**Resp** — list ต่อ platform:
```jsonc
[
  { "PlatformId": 2, "Statuses": [ { "Value": "COMPLETED", "Desc": "สำเร็จ" }, { "Value": "SHIPPED", "Desc": "จัดส่งแล้ว" } ] },
  { "PlatformId": 1, "Statuses": [ { "Value": "delivered", "Desc": "จัดส่งสำเร็จ" }, /* … */ ] }
  // TikTok / LineMyShop …
]
```

**Controller + Handler** (no param, ตาม pattern `StatusList` เป๊ะ):
```csharp
[LmsHttpGet]
[LmsAuthorize]
public async Task<IActionResult> OrderStatusList()
{
    try { Data = await mediator.Send(new MarketplaceOrderStatusListReq()); Status = ...Success; }
    catch (Exception ex) { ApiException = ex; }
    return BuildJsonResp();
}

// Handler — วนทุก platform ใน constant ประกอบเป็น group
=> Platform.ValidList.Select(pid => new OrderStatusGroupResp {
       PlatformId = pid,
       Statuses = OrderStatusByPlatform.Get(pid)
                    .Select(s => new StringOptionResp { Value = s.Token, Desc = s.Label }).ToList()
   }).ToList();
```

**flow ฝั่ง frontend:** โหลด `OrderStatusList` ครั้งเดียวตอนเข้าหน้า Add/Edit → เก็บไว้ → สลับ channel ก็แค่หยิบ group ที่ `PlatformId` ตรงมาโชว์ ไม่ยิงซ้ำ

> - `OptionResp` เดิม `Value` เป็น int — token เป็น string เลยต้องมี `StringOptionResp { string Value; string Desc }` + wrapper `OrderStatusGroupResp { int PlatformId; List<StringOptionResp> Statuses }`
> - ถ้าไม่อยากยัด status ทุกเจ้ามาทุกครั้ง (เช่น list เยอะขึ้นมากในอนาคต) ค่อยเปลี่ยนเป็น per-platform `OrderStatusList/{platformId}` — ตอนนี้ก้อนเล็ก ยิงรวมคุ้มกว่า

## ตอน earn — เทียบตรง
```
order จาก hub: (platformId, rawStatus เช่น "COMPLETED")
  → หา CRM_Criteria_Config ที่ PlatformId ตรง + active
  → ใน detail ของร้านนั้น ถ้า Order_Status == rawStatus → เข้าเกณฑ์ ให้แต้มตาม Point_By
```

## Open Points
1. **1 ร้านเลือกได้กี่ status** — mockup มี dropdown "Select Rating Status" เดียวต่อร้าน. ถ้าเลือกได้หลาย status ต่อร้าน → 1 แถว `CRM_Criteria_Config_Detail` ต่อ (ร้าน × status) ไม่ใช่ต่อร้าน
2. **Lazada** `statuses` เป็น array ระดับ item — order นับว่า "delivered" เมื่อไหร่ (ทุกชิ้น? ชิ้นใดชิ้นหนึ่ง?) ต้องยืนยันกติกาตอน earn
3. **LineMyShop** — status อยู่ 3 field (`order_status`/`payment_status`/`shipment_status`) dropdown ควรโชว์ field ไหน/รวมยังไง ต้องดู payload จริง
4. เช็คว่า hub ส่ง raw status ออกมาในรูปไหน (string เดิม vs แปลงแล้ว) ให้ match กับ token ที่เก็บได้
