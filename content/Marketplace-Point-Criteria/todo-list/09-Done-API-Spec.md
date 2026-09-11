# ✅ Done — API Spec (ที่ implement แล้ว)

กลับไป [[00-Todo-List]] · schema [[01-Schema]] · validation [[05-Validation]]

สเปกจริงของ endpoint ที่ลงโค้ดไปแล้วใน `lms-backend` + constant/entity ใน `lms-core` (branch `feature/mkp/criteria-config`). ทุกอันเทียบ pattern `PrivilegeCriteriaGroup`

> **Base:** `api/v1/MarketplacePointCriteria/[action]` · ทุก endpoint `[LmsAuthorize]` · `brand_ref` มาจาก token (route data) ไม่ต้องส่งใน body
> **Envelope:** ทุก response ห่อด้วย `LmsController` → `{ "Status": ..., "Data": <payload> }` (ช่อง `Data` ด้านล่างคือตัว payload)

---

## ที่เพิ่มใน core (`lms-core`)
- `Choco.LMS.Core/Constants/Marketplace/LmsMarketplaceConst.cs` — `Platform` (1-4), `PointBy` (bitmask 1/2/4 + `HasFixed/HasSpending/HasSkus` + `IsValid` + `GetDesc` + `DropdownOrder`), `OrderStatusByPlatform` (token+label ต่อ platform)
- entity + context: ใช้ **standalone** `BCRM_MKP_Criteria_Entities` (`DBModel/MkpCriteria/`) — scaffold ไว้อยู่แล้ว, ตารางอยู่ brand DB เดียวกับ Privilege
- factory ใหม่: `BCRM_MKP_Criteria_Entities_Factory`
- ⚠️ ต้องรัน [[07-Create-Tables]] ต่อ brand DB ก่อนใช้งานจริง

---

## 1) GET `PointByList`
dropdown Point By — 7 ค่า bitmask (single ก่อน combo)

**Resp** `List<OptionResp>`
```jsonc
[
  { "Value": 1, "Desc": "Fixed points" },
  { "Value": 2, "Desc": "Spending" },
  { "Value": 4, "Desc": "SKUs" },
  { "Value": 3, "Desc": "Fixed points + Spending" },
  { "Value": 5, "Desc": "Fixed points + SKUs" },
  { "Value": 6, "Desc": "Spending + SKUs" },
  { "Value": 7, "Desc": "Fixed points + Spending + SKUs" }
]
```

## 2) GET `OrderStatusList`
status ทุก platform ยิงรอบเดียว → frontend filter ตาม `PlatformId` ที่เลือกเอง (ไม่มี param)

**Resp** `List<OrderStatusGroupResp>`
```jsonc
[
  {
    "PlatformId": 1, "Platform_Desc": "lazada",
    "Statuses": [ { "Value": "delivered", "Desc": "จัดส่งสำเร็จ" }, /* … */ ]
  },
  {
    "PlatformId": 2, "Platform_Desc": "shopee",
    "Statuses": [ { "Value": "COMPLETED", "Desc": "สำเร็จ" }, /* … */ ]
  },
  { "PlatformId": 3, "Platform_Desc": "linemyshop", "Statuses": [] }, // ⚠️ รอ payload hub
  { "PlatformId": 4, "Platform_Desc": "tiktokshop", "Statuses": [ /* … */ ] }
]
```
> `Value` = raw token (string), `Desc` = label ไทย

## 3) POST `List`
list หน้าตาราง — paging + filter

**Req** (body)
```jsonc
{ "Keyword": null, "PlatformId": null, "IsActive": null, "Page": 1, "Limit": 10 }
```
**Resp** `ListResult<MarketplacePointCriteriaListItemResp>`
```jsonc
{
  "TotalRecord": 12, "FilteredRecord": 12, "TotalPage": 2, "CurrentPage": 1,
  "DataList": [
    {
      "Criteria_ConfigId": 5,
      "Criteria_Name": "โปรโมชั่นเดือนตุลา",
      "PlatformId": 2, "Platform_Desc": "shopee",
      "Point_By": 5,
      "Point_By_Badges": ["Fixed points", "SKUs"],   // derive จาก bit
      "IsActive": true,
      "UpdatedTime": "2026-09-02T10:00:00"
    }
  ]
}
```
> order: `UpdatedTime desc, Criteria_ConfigId desc` · filter `Keyword` = contains บน `Criteria_Name`

## 4) GET `Detail/{criteriaConfigId}`
header + stores + skus ไว้ทำหน้า Edit/View

**Resp** `MarketplacePointCriteriaDetailResp`
```jsonc
{
  "Criteria_ConfigId": 5,
  "Criteria_Name": "โปรโมชั่นเดือนตุลา",
  "PlatformId": 2, "Platform_Desc": "shopee",
  "Point_By": 5, "Point_By_Desc": "Fixed points + SKUs",
  "Fixed_Point": 50, "Extra_Point": 10,
  "Spending_Base": 0, "Spending_Point": 0,
  "Grand_Total_Point": 60,            // = Fixed + Extra
  "Remark": null, "IsActive": true,
  "UpdatedTime": "2026-09-02T10:00:00",
  "Stores": [
    { "Store_Ref": "choco-official", "Order_Status": "COMPLETED", "Order_Status_Desc": "สำเร็จ" }
  ],
  "Skus": [
    { "SKU": "ABC-001", "Quantity": 2, "Point_Per_Qty": 5 }
  ]
}
```
> ไม่พบ → error `1000404`

## 5) POST `Add`
**Req** (body) — desc/Grand_Total derive ที่ server ไม่รับจาก client
```jsonc
{
  "Criteria_Name": "โปรโมชั่นเดือนตุลา",
  "PlatformId": 2,
  "Point_By": 5,                       // Fixed + SKUs
  "IsActive": true,
  "Fixed_Point": 50, "Extra_Point": 10,
  "Spending_Base": 0, "Spending_Point": 0,
  "Remark": null,
  "Stores": [
    { "Store_Ref": "choco-official", "Order_Status": "COMPLETED" },
    { "Store_Ref": "choco-sp",       "Order_Status": "SHIPPED"   }
  ],
  "Skus": [
    { "SKU": "ABC-001", "Quantity": 2, "Point_Per_Qty": 5 }
  ]
}
```
**Resp** = row `BCRM_MKP_Criteria_Config` ที่สร้าง (มี `Criteria_ConfigId`)

## 6) PATCH `Edit/{criteriaConfigId}`
body เหมือน Add เป๊ะ (ไม่ต้องส่ง id ใน body — อยู่ใน path) · soft-delete detail เดิม แล้ว insert ชุดใหม่

## 7) DELETE `Delete/{criteriaConfigId}`
soft delete header + detail + sku · **Resp** ว่าง

---

## Validation (Add + Edit) — implement ครบตาม [[05-Validation]]
| Rule   | เช็ค                                                                                                                            | error     |
| ------ | ------------------------------------------------------------------------------------------------------------------------------- | --------- |
| **R1** | 1 active ต่อ 1 `PlatformId` (exclude ตัวเองตอน edit) · ตั้ง active ชนตัวเดิม → reject ไม่ auto-disable                          | `1000400` |
| **R2** | field ตาม mode ที่เปิด — Spending `Base/Point > 0`, SKU ≥1 แถว `Quantity>0`; mode ที่ไม่เปิด server บังคับ 0 / เคลียร์แถวให้เอง | `1000400` |
| **R3** | `PlatformId ∈ 1-4`, `PointBy.IsValid`, `Order_Status` ต้องอยู่ในชุดของ platform (ยกเว้น LineMyShop ที่ยังไม่มีชุด → ข้าม)       | `1000400` |
| **R4** | ชื่อไม่ว่าง, ร้าน ≥1 และแต่ละร้านมี status, SKU ห้ามซ้ำต่อ criteria                                                             | `1000400` |

**Derive ที่ server (ไม่รับจาก client):** `Point_By_Desc`, `Order_Status_Desc`, `Grand_Total_Point (= Fixed + Extra)`, audit (`Req_IdentityId/SRef`, `Updated/CreatedTime`)

---

## ยังไม่ทำ (นอก scope config)
- **earn matching** — คิดแต้มตอนมีออเดอร์จริง (Spending/SKU floor, multi-mode บวกกัน) เป็น consumer แยกใน hub
- **LineMyShop** — ชุด order status token (dropdown ว่างไว้ก่อน รอ payload จริง)
- **PlatformList** endpoint — ไม่ทำ (channel dropdown ใช้ `Platform_Desc` จาก `OrderStatusList` ได้เลย)
