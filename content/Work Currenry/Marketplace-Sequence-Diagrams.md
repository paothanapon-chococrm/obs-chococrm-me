---
publish: true
tags: [work, marketplace, sequence, criteria, earn, realtime]
status: draft
created: 2026-09-11
---

# Marketplace — Sequence Diagrams (Config Criteria + EarnPointByOrderId)

รวม sequence diagram ปัจจุบันของ 2 ขา marketplace point + ขา **realtime pull จาก hub**

- 🟦 **Config Criteria** — admin ตั้งเกณฑ์ให้แต้ม (lms-backend · `MarketplacePointCriteriaController`)
- 🟩 **EarnPointByOrderId** — ลูกค้ากดรับแต้มจาก order (core `LmsMarketplaceEarnService`)
- ⚡ **Realtime** — ดึง order สดจาก marketplace hub เมื่อถังยังไม่มี

อ้างอิงโค้ดจริง: `lms-core` `Choco.LMS.Core/Services/Marketplace/*` · `lms-backend` `LMS.Backend.{Api,Application}/.../Marketplace/*`

> ดูคู่กับ spec เดิม: [[../Marketplace-Point-Criteria/00-Overview]] · [[../Marketplace-Point-Earn/00-Overview]]

---

## ผู้เล่น (participants) ที่ใช้ร่วมกัน

| ชื่อย่อ | จริงๆ คือ | repo |
|---|---|---|
| `CritCtrl` | `MarketplacePointCriteriaController` | lms-backend |
| `CritHdlr` | MediatR handler (List/Detail/Add/Edit/Delete/…) | lms-backend |
| `CritSvc` | `ILmsMarketplaceCriteriaService` | lms-core |
| `EarnCtrl` | `MarketplaceController` (action `EarnCalculate`) | WebApp (LMS.App.Api) |
| `EarnHdlr` | `MarketplaceEarnCalculateHandler` | WebApp |
| `EarnSvc` | `ILmsMarketplaceEarnService` | lms-core |
| `Calc` | `MarketplaceEarnCalculator.Apply` (สูตรล้วน) | lms-core |
| `PointSvc` | `ILmsCrmPointService.Issue` | lms-core |
| `HubPull` | `IMkpHubOrderPullClient.PullAsync` | lms-core |
| `HUB` | Marketplace Hub (`platform-marketplace-hub`) | hub |
| `MKPDB` | `BCRM_MKP_Entities` (brand DB: raw order/product + config + order_request) | brand DB |

---

## (A) Config Criteria — CRUD

ทุก action เป็น `[LmsAuthorize]` → `brand_ref` ดึงจาก token (`GetBrandRefOrThrow`) · controller บาง, logic อยู่ core ชั้นเดียว

### A1. ภาพรวม endpoint ทั้งชุด

```mermaid
sequenceDiagram
    autonumber
    actor AD as Admin (BackOffice)
    participant CritCtrl as MarketplacePointCriteriaController
    participant CritHdlr as MediatR Handler
    participant CritSvc as LmsMarketplaceCriteriaService
    participant MKPDB as BCRM_MKP_Entities (brand DB)

    Note over AD,MKPDB: ---- โหลด dropdown ก่อนเปิดฟอร์ม ----
    AD->>CritCtrl: GET PointByList
    CritCtrl->>CritHdlr: Send(PointByListReq)
    CritHdlr-->>CritCtrl: PointBy bitmask options (จาก const)
    AD->>CritCtrl: GET ShopList?platform_code=
    CritCtrl->>CritHdlr: Send(ShopListReq)
    CritHdlr->>MKPDB: read BCRM_MKP_Shop_Sync (ของ brand)
    AD->>CritCtrl: GET SkuList?platform_id=&shop_ref=
    CritCtrl->>CritHdlr: Send(SkuListReq) → CritSvc.GetSkuList
    Note right of CritSvc: resolve Product_Platform_Connect_Id<br/>→ read raw product → parse JSON (ดู A3)
    AD->>CritCtrl: GET OrderStatusList
    CritCtrl->>CritHdlr: Send(OrderStatusListReq)
    Note right of CritHdlr: คืน status token ต่อ platform<br/>กรองตาม GetEnabledPlatforms(brand)

    Note over AD,MKPDB: ---- list / detail ----
    AD->>CritCtrl: POST List {keyword,platformId,isActive,page,limit}
    CritCtrl->>CritSvc: GetList(...)
    CritSvc->>MKPDB: page BCRM_MKP_Criteria_Config (!IsDeleted)
    CritSvc->>MKPDB: join Store_Ref → Shop_Sync.Shop_Name
    CritSvc-->>AD: ListResult[Row]
    AD->>CritCtrl: GET Detail/{criteriaConfigId}
    CritCtrl->>CritSvc: GetDetail(brand,id)
    CritSvc->>MKPDB: read Config + Config_Detail + Config_SKU
    CritSvc-->>AD: MarketplaceCriteriaDetail
```

### A2. Add / Edit (Upsert) — กฎ validate R1–R4

`Upsert` ใช้ทั้ง Add (`Criteria_ConfigId == 0` → insert) และ Edit (reconcile ตาม natural key)

```mermaid
sequenceDiagram
    autonumber
    actor AD as Admin
    participant CritCtrl as MarketplacePointCriteriaController
    participant CritHdlr as Add/EditHandler + ReqMapper
    participant CritSvc as LmsMarketplaceCriteriaService.Upsert
    participant MKPDB as BCRM_MKP_Entities

    AD->>CritCtrl: POST Add / PATCH Edit/{id} {header, stores[], skus[]}
    CritCtrl->>CritCtrl: brand_ref = GetBrandRefOrThrow()
    CritCtrl->>CritHdlr: Send(req)
    CritHdlr->>CritHdlr: map req → MarketplaceCriteriaUpsertDto
    CritHdlr->>CritSvc: Upsert(brand, dto)

    CritSvc->>CritSvc: GetEnabledPlatforms(brand) ∋ PlatformId?
    alt platform ไม่ได้เปิดใช้
        CritSvc-->>AD: 400 "Platform นี้ไม่ได้เปิดใช้"
    end

    CritSvc->>CritSvc: ValidateAndNormalize(dto)
    Note right of CritSvc: R2 Point_By ต้อง valid bitmask<br/>R2 Fixed/Spending/SKU ตาม bit ที่เปิด (bit ปิด→บังคับ 0)<br/>SKU: qty>0, ไม่ซ้ำ · Store ≥1 + มี order_status<br/>R3 order_status token ∈ ชุดของ platform

    CritSvc->>MKPDB: EnsureSingleActivePerPlatform (R1)
    alt IsActive && มี active อื่นของ platform นี้
        CritSvc-->>AD: 400 "ปิดตัวเดิมก่อนจึงเปิดตัวใหม่ได้"
    end

    alt Add (id==0)
        CritSvc->>MKPDB: INSERT Config + Details + SKUs
    else Edit
        CritSvc->>MKPDB: ApplyHeader(config)
        CritSvc->>MKPDB: ReconcileStores (match Store_Ref+Order_Status:<br/>คงเดิม / soft-delete หลุด / insert ใหม่)
        CritSvc->>MKPDB: ReconcileSkus (match SKU:<br/>update qty+point / soft-delete / insert)
    end
    CritSvc->>MKPDB: SaveChanges
    CritSvc->>MKPDB: LoadDetail (อ่านกลับ)
    CritSvc-->>AD: MarketplaceCriteriaDetail
```

> `Grand_Total_Point = Fixed + Extra` เท่านั้น — ส่วน Spending/SKU คิดตอน **earn** ไม่ได้ freeze ที่ config
> Audit เขียน `Req_IdentityId` / `Req_Identity_SRef` จาก `IdentityContext.Current`

### A3. SkuList dropdown — แกะ SKU จาก raw product (ต้องตรงกับที่ earn match)

```mermaid
sequenceDiagram
    autonumber
    participant CritSvc as CritSvc.GetSkuList(brand,platform,shopRef?)
    participant MKPDB as BCRM_MKP_Entities

    CritSvc->>CritSvc: validate brand + platform ∈ ValidList
    CritSvc->>MKPDB: Shop_Sync → distinct Product_Platform_Connect_Id<br/>(กรอง brand + platform + shopRef?)
    alt ไม่มี connect
        CritSvc-->>CritSvc: คืน [] (ร้านยังไม่ sync สินค้า)
    end
    alt platform
        CritSvc->>MKPDB: LAZADA → Raw_lazada_products (attributes.name, skus[].SkuId)
        CritSvc->>MKPDB: SHOPEE → Raw_shopee_product_models (model[].model_sku + tier_variation)
        CritSvc->>MKPDB: TIKTOK → Raw_tik_tok_shop_product_details (title, skus[].id)
    end
    Note right of CritSvc: value (SKU) = key ที่ earn ใช้ match เป๊ะ<br/>distinct ตาม SKU, sort ตามชื่อ
    CritSvc-->>CritSvc: List[MarketplaceSkuOption{Sku,Name}]
```

---

## (B) EarnPointByOrderId — ลูกค้ากดรับแต้ม

entry 2 ทางใน `LmsMarketplaceEarnService`:
- **`Calculate(brand, platform, orderRef, shopId, identitySRef)`** — เลือกร้าน → resolve connect → **หาในถังก่อน** ไม่เจอค่อย pull สด
- **`CalculateByConnect(brand, platform, orderRef, connectRef, identitySRef)`** — ข้ามถัง → **pull สดจาก hub ตรงๆ** (ขา realtime ล้วน)

ทั้งคู่วิ่งลง `CalculateCore` pipeline เดียวกัน

### B1. Flow เต็ม (Calculate → ถังก่อน, ไม่เจอ pull)

```mermaid
sequenceDiagram
    autonumber
    actor U as ลูกค้า (WebApp)
    participant EarnCtrl as MarketplaceController
    participant EarnHdlr as EarnCalculateHandler
    participant EarnSvc as LmsMarketplaceEarnService
    participant MKPDB as BCRM_MKP_Entities (raw + request)
    participant HubPull as MkpHubOrderPullClient
    participant HUB as Marketplace Hub
    participant CritSvc as CriteriaService
    participant Calc as MarketplaceEarnCalculator
    participant PointSvc as LmsCrmPointService.Issue

    U->>EarnCtrl: POST EarnCalculate {platform_order_ref, platform_id, shop_id}
    EarnCtrl->>EarnCtrl: อ่าน brand_ref + identity_sref จาก token
    EarnCtrl->>EarnHdlr: Send(req)
    EarnHdlr->>EarnHdlr: validate brand_ref + platform_order_ref (ไม่งั้น 400)
    EarnHdlr->>EarnSvc: Calculate(brand, platform, orderRef, shopId, identitySRef)

    EarnSvc->>EarnSvc: ValidateEarnInput (orderRef ว่าง / platform ∉ ValidList → 400, ยังไม่ log)
    EarnSvc->>MKPDB: ResolveOrderConnect → Shop_Sync (scope brand+platform)
    Note right of EarnSvc: ไม่เจอร้าน → 404 · ร้านไม่มี order-lane connect → 400<br/>ได้ (connectRef, connectId, shopRef)

    rect rgb(235,245,255)
    Note over EarnSvc,HUB: หา order: ถังก่อน → ไม่เจอค่อย pull สด (⚡ ดู C)
    EarnSvc->>MKPDB: QueryOrder(platform, orderRef, connectId)
    alt เจอในถัง
        MKPDB-->>EarnSvc: MarketplaceOrderSnapshot
    else ไม่เจอในถัง
        EarnSvc->>HubPull: PullAsync(connectRef, orderRef)
        HubPull->>HUB: POST /connects/{ref}/orders/{ref}/pull
        HUB-->>HubPull: order ดิบ (JSON) / null
        HubPull-->>EarnSvc: resp → ParsePulledOrder → Snapshot / null
    end
    end

    EarnSvc->>CritSvc: GetActiveByPlatform(brand, platform) → เกณฑ์ active ≤ 1
    EarnSvc->>MKPDB: customerQuery.Query(identity_sref) → customer?

    alt order == null
        EarnSvc->>EarnSvc: Reject OrderNotFound(1)
    else criteria == null
        EarnSvc->>EarnSvc: Reject NoActiveCriteria(2)
    else IsOrderAlreadyEarned (Confirm + ไม่ถูก void)
        EarnSvc->>EarnSvc: Reject AlreadyEarned(4)
    else IsBuyerAccountMismatch (1 user : 1 buyer/platform)
        EarnSvc->>EarnSvc: Reject BuyerAccountMismatch(5)
    else ผ่านหมด
        EarnSvc->>Calc: Apply(result, config, skus, order)
        Note right of Calc: Fixed(1)=Fixed+Extra · Spending(2)=⌊spend/base⌋×pt<br/>SKUs(4)=Σ ⌊qty/Q⌋×pt/Q · Total = ผลรวม bit ที่เปิด
        alt Total_Point ≤ 0
            EarnSvc->>EarnSvc: Reject ZeroPoint(3)
        else Total_Point > 0
            EarnSvc->>PointSvc: Issue(Custom, Point, Ext_Tx=MKP-{platform}-{orderRef})
            alt tx.Is_Duplicate_TX
                PointSvc-->>EarnSvc: dup → Reject AlreadyEarned(4) (ไม่ Confirm ทับ)
            else สำเร็จ
                PointSvc-->>EarnSvc: tx → Status = Confirm(1)
            end
        end
    end

    EarnSvc->>MKPDB: LogRequest → INSERT 1 แถว BCRM_MKP_Order_Request (เสมอ หลังออกแต้ม)
    EarnSvc->>EarnSvc: logger.LogInformation(สรุป 1 บรรทัด)
    EarnSvc-->>EarnHdlr: MarketplaceEarnResult
    EarnHdlr-->>EarnCtrl: map → MarketplaceEarnResp
    EarnCtrl-->>U: {status, data:{status, total_point, reject_code, ...}}
```

> ⚠️ ลำดับสำคัญ: **ออกแต้มก่อน → แล้วค่อย log** (แถว log มี input + ผลคำนวณ + tx id ครบ)
> ⚠️ customer == null ตอนจะ `IssuePoint` → throw **1000404** (identity ล็อกอินมาแต่ map customer ไม่เจอ = ผิดปกติ, ไม่ log ว่าออกสำเร็จ)

### B2. เช็ค 2 ชั้นที่ฝั่ง client ต้องอ่าน

| ชั้น | field | ความหมาย |
|---|---|---|
| envelope | `status` = success/fail/error | request ผ่าน/ไม่ผ่านเท่านั้น |
| data | `data.status` = 1 Confirm / 2 Reject | ได้แต้มจริงไหม |
| data | `data.reject_code` (1–5) | เหตุผลเมื่อ Reject |

Reject code: `1` order ไม่พบ · `2` ไม่มีเกณฑ์ active · `3` คิดได้ 0 แต้ม · `4` รับแต้มไปแล้ว · `5` buyer ไม่ตรงบัญชีที่ผูก

---

## (C) ⚡ Realtime — pull order สดจาก hub

หัวใจของขา realtime: เมื่อ order **ยังไม่ถูก ingest เข้าถังเรา** `EarnSvc` ดึงสดจาก marketplace hub ทีละ connect แล้วแกะเป็น snapshot เดียวกับขาถัง → คิดแต้มต่อได้เลย

**จุด trigger 2 แบบ:**
1. `Calculate` → `QueryOrder` คืน `null` (ถังไม่มี) → fallback `PullOrder`
2. `CalculateByConnect` → `connectId = null` → **ข้ามถังเลย** ดึงสดอย่างเดียว

```mermaid
sequenceDiagram
    autonumber
    participant EarnSvc as EarnSvc.CalculateCore
    participant MKPDB as BCRM_MKP_Entities (raw tank)
    participant HubPull as MkpHubOrderPullClient
    participant Sender as MarketplaceHubHttpSender
    participant HUB as Marketplace Hub API

    alt มี connectId (สาย Calculate)
        EarnSvc->>MKPDB: QueryOrder(platform, orderRef, connectId)
        alt เจอในถัง
            MKPDB-->>EarnSvc: Snapshot → จบ (ไม่ pull)
        end
    end

    Note over EarnSvc,HUB: ถังไม่มี / ไม่มี connectId → pull สด
    EarnSvc->>HubPull: PullAsync(connectRef, orderRef)
    HubPull->>Sender: POST api/v1/connects/{connectRef}/orders/{orderRef}/pull
    Sender->>HUB: HTTP POST (+ hub auth)
    HUB-->>Sender: MkpHubOrderPullResp {order(JSON?), order_items(JSON?)}
    Sender-->>HubPull: resp
    HubPull-->>EarnSvc: resp

    alt resp.Order == null / ไม่ใช่ object
        EarnSvc-->>EarnSvc: return null → ขึ้น Reject OrderNotFound(1)
    else มี order
        EarnSvc->>EarnSvc: ParsePulledOrder(platform, order, order_items)
        alt platform
            EarnSvc->>EarnSvc: LAZADA → ParsePulledLazada (items[], paid_price, sku_id, buyer_id, statuses[0])
            EarnSvc->>EarnSvc: SHOPEE → ParsePulledShopee (item_list, model_*, currency@order, buyer_user_id)
            EarnSvc->>EarnSvc: TIKTOK → ParsePulledTikTok (items[], sale_price, sku_id, user_id, status)
        end
        EarnSvc-->>EarnSvc: MarketplaceOrderSnapshot (ยอด THB เท่านั้น) → เข้า pipeline B1 ต่อ
    end
```

**หมายเหตุ realtime (ponytail ในโค้ด):**
- hard **THB เท่านั้น** — item สกุลอื่นถูกข้าม (ยังไม่มี multi-currency)
- hub ยก `order_items` ขึ้น top-level array ให้แล้ว แต่ field ในแต่ละ item ยังต่างตาม platform
- **shopee** shape ยังเดาจาก entity DB (รอ resp จริงยืนยัน); lazada/tiktok ยืนยันแล้ว
- **linemyshop** ยังไม่รองรับทั้ง query และ pull → throw `1000501` "ยังไม่รองรับ"
- `IMkpHubOrderPullClient` resolve แบบ lazy จาก DI (`di.GetService`) — host ที่ไม่ได้ต่อ hub จะ throw `1000501` ตอนเรียก ไม่ใช่ตอน startup

---

## สรุปการ gating ที่ **ยังไม่** enforce (อ่านก่อนตรวจว่าแต้มถูก)

- **store + order-status gating** ตอน earn ยัง **ไม่** enforce — 1 platform มี active config เดียว เลยคิดจากตัวนั้นเลย (รอ payload hub จริงมาแจกแจง)
- ดังนั้น `Config_Detail.Order_Status` ที่ตั้งไว้ฝั่ง config **ยังไม่ถูกเทียบ** ตอนคิดแต้ม
- lazada/tiktok qty ต่อ SKU = นับจำนวนแถว item (สมมติ 1 แถว = 1 ชิ้น)
- tiktok currency อยู่ใน `order.payment` JSON ยัง parse ไม่ได้ → assume THB

ดูเพิ่ม [[../Marketplace-Point-Earn/04-Store-Gating-ยังไม่-enforce]]
