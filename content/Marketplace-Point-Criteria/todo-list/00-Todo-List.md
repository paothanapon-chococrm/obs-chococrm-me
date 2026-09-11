# Todo List — Marketplace Point Criteria (Criteria Config)

กลับไป [[00-Overview]] · schema [[01-Schema]] · validation [[05-Validation]]

รวมงานที่ต้องทำสำหรับฟีเจอร์ **criteria-config** map กับสเปกใน vault + pattern `PrivilegeCriteriaGroup` ใน repo `lms-backend`

> ขอบเขต: ทำเฉพาะฝั่ง **config (CRUD + dropdown)** เท่านั้น — ส่วน **earn matching** (คิดแต้มตอนมีออเดอร์จริง) เป็น consumer แยกใน hub/earn flow ไม่รวมในนี้

---

## สิ่งที่ต้องทำก่อน (Prerequisites — ทุกอย่างขึ้นกับ 3 ข้อนี้)

### 1. Core constants
ไฟล์ใหม่ใน **lms-core** (ไม่ใช่ repo นี้): `Choco.LMS.Core/Constants/Marketplace/LmsMarketplaceConst.cs`
- [ ] `Platform` — int const 1–4 + `Desc` + `GetDesc` + `ValidList` (ดู [[03-Platform-Constant]])
- [ ] `PointBy` — const 1–7 + `HasFixed/HasSpending/HasSkus` + `GetDesc` + `ValidList` (ดู [[04-PointBy-Constant]])
- [ ] `OrderStatusByPlatform` — `Dictionary<int, List<Item(Token, Label)>>` + `Get(platformId)` (ดู [[06-OrderStatus-Mapping]])
  - ⚠️ ชุด status ของ LineMyShop ยังไม่รู้ — เว้นว่างไว้ก่อน รอ payload จริงจาก hub

### 2. DB tables
- [ ] `BCRM_MKP_Criteria_Config` (header)
- [ ] `BCRM_MKP_Criteria_Config_Detail` (ร้านค้า × สถานะ)
- [ ] `BCRM_MKP_Criteria_Config_SKU` (SKU) — ดู [[01-Schema]]
- [ ] Migration script + index ที่แนะนำ: `PlatformId`/`IsDeleted` (header), `Criteria_ConfigId` (2 detail)

### 3. EF entities + DbContext
- [ ] Entity class 1 ตัวต่อ 1 table
- [ ] Register `DbSet` ที่เดียวกับ `CRM_Package_Criteria_Group` (น่าจะอยู่ lms-core)

---

## Backend API (copy โครง `PrivilegeCriteriaGroup` → `MarketplacePointCriteria`)

ต่อ 1 endpoint = Req (Contract) + Handler (Application) + controller action (Api)

| # | Endpoint | Req | Handler | หมายเหตุ |
|---|---|---|---|---|
| [ ] | `List` | `...ListReq` | ListHandler | คืน header rows + derive Channel/badge จาก `PlatformId`/`Point_By` |
| [ ] | `Detail` | `...DetailReq` | DetailHandler | header + Stores + Skus ไว้ใช้หน้า Edit/view |
| [ ] | `Add` | `...AddReq` (+ `StoreDto`, `SkuDto`) | AddHandler | validate R1–R4, derive desc + `Grand_Total_Point`, insert 3 tables |
| [ ] | `Edit` | `...EditReq` | EditHandler | เหมือน Add + exclude ตัวเองใน R1; soft-delete/re-insert detail |
| [ ] | `Delete` | `...DeleteReq` | DeleteHandler | soft delete header (+ detail) |
| [ ] | `PointByList` | `...PointByListReq` | PointByListHandler | `List<OptionResp>` จาก `PointBy.ValidList` |
| [ ] | `OrderStatusList` | `...OrderStatusListReq` | OrderStatusListHandler | ทุก platform ยิงรอบเดียว → `List<OrderStatusGroupResp>` |
| [ ] | Controller | — | — | `MarketplacePointCriteriaController` รวม 7 action ข้างบน, attribute ชุดเดียวกับ reference |

### Response DTO ใหม่
- [ ] `StringOptionResp { string Value; string Desc }` — ของเดิม `OptionResp.Value` เป็น int แต่ token เป็น string
- [ ] `OrderStatusGroupResp { int PlatformId; List<StringOptionResp> Statuses }`

### Platform dropdown (เพิ่มถ้าจำเป็น)
- [ ] `PlatformList` endpoint — pattern 3 ชิ้นเหมือนกัน off `Platform.ValidList`
  - ทำเฉพาะถ้า frontend ไม่ hardcode 4 channel เอง

---

## Validation (ใส่ใน Add + Edit handler — ดู [[05-Validation]])
- [ ] **R1** — 1 active ต่อ 1 `PlatformId` (app-check, exclude ตัวเองตอน edit) → reject ไม่ auto-disable
- [ ] **R2** — field ตาม mode ที่เปิดจาก `HasX(Point_By)`; mode ที่ไม่เปิดบังคับเป็น 0 / ไม่มีแถว
- [ ] **R3** — `Point_By`, `PlatformId`, `Order_Status` ต้องอยู่ในชุดที่ valid
- [ ] **R4** — ชื่อไม่ว่าง, ร้าน ≥ 1 และแต่ละร้านต้องมี status, SKU ห้ามซ้ำต่อ criteria
- [ ] **Derive ที่ server** (ไม่รับจาก client) — `Point_By_Desc`, `Order_Status_Desc`, `Grand_Total_Point`

---

## คำถามที่ต้องเคลียร์ก่อน/ระหว่างทำ
1. [ ] **1 ร้าน → 1 หรือหลาย status?** ([[06-OrderStatus-Mapping]] #1) — ตัดสินว่าตาราง `_Detail` เก็บต่อร้าน หรือต่อ (ร้าน × status). **มีผลต่อ schema — ต้องเคลียร์ก่อนแตะ Add/Edit**
2. [ ] ชุด status token ของ **LineMyShop** (block dropdown + earn ของเจ้านี้)
3. [ ] rule การปัดของ SPENDING/SKU + multi-mode = บวกกัน — ใช้ตอน **earn** ไม่ใช่ config feature นี้

---

## ลำดับที่แนะนำ
1. ทำ Prerequisites 1–3 (constants → tables → entities)
2. เคลียร์คำถาม #1 ก่อนล็อค schema `_Detail`
3. Scaffold backend handler (dropdown ก่อน แล้วค่อย List/Detail/Add/Edit/Delete)
