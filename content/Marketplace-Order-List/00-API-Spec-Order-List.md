# API Spec — Marketplace Order List (GetListOrderTransaction)

หน้า **Marketplace → tab "Marketplace"** (BackOffice CRM) — list ของ earn request ที่ลูกค้ากดรับแต้มผ่าน WebApp
อ่านจากตาราง `BCRM_MKP_Order_Request` เดียวกับที่ [[../Marketplace-Point-Earn/03-API-Spec|Point Earn]] เป็นคนเขียน

> [!info] หน้านี้ = **อ่านอย่างเดียว** (list + filter + search + unmask)
> ไม่มี insert/update — แถวถูกสร้างโดย Point Earn (1 ครั้งกดรับแต้ม = 1 แถว, Confirm/Reject)

---

## Endpoint
```
POST api/v1/MarketplaceOrder/List
```
- **Auth:** `LmsAuthorize` (BackOffice token) — `brand_ref` ดึงจาก token ไม่ต้องส่ง
- **Controller:** `LMS.Backend.Api/.../Controllers/Marketplace/MarketplaceOrderController.cs`
- **Handler:** `LMS.Backend.Application/.../Marketplace/MarketplaceOrder/MarketplaceOrderRequestListHandler.cs`
- **Core service:** `lms-core` → `Services/Marketplace/LmsMarketplaceOrderService.cs`
- **JSON casing:** backend ใช้ `LowerCaseNamingStrategyUtil` → property บน wire **ตัวพิมพ์เล็กทั้งหมด คง `_`** (`order_number`, `platform_desc`, `reject_code`)

---

## Request
```jsonc
{
  "keyword": "สมชาย",   // ค้น order_number + ชื่อลูกค้า (optional)
  "platformid": 2,       // filter Channel (optional)
  "status": 1,           // filter Status (optional)
  "page": 1,
  "limit": 10,
  "reveal": false        // true = ปุ่ม UnMask → ส่งชื่อไม่ mask
}
```
| Field | Type | Req | Note |
|---|---|:-:|---|
| `keyword` | string | – | ค้น **ทั้ง** `order_number` และ **ชื่อลูกค้า** (in-memory, case-insensitive) |
| `platformid` | int | – | filter Channel · 1 Lazada · 2 Shopee · 3 LineMyShop · 4 TiktokShop · ไม่ส่ง = ทุก channel |
| `status` | int | – | filter Status · 1 Confirm · 2 Reject · ไม่ส่ง = ทั้งหมด |
| `page` | int | – | default 1 |
| `limit` | int | – | default 10 (dropdown "แสดงจำนวนแถว") |
| `reveal` | bool | – | default false = ชื่อ mask · true = ชื่อเต็ม (กดปุ่ม UnMask ต่อแถว/ทั้งหน้า) |

> ปุ่ม **UnMask** = เรียก endpoint เดิมซ้ำด้วย `reveal:true` (หลักการเดียวกับ Customer Management)

---

## Response
ห่อ envelope มาตรฐาน `{ request_id, status, data }` — `data` เป็น `ListResult`:
```jsonc
{
  "totalrecord": 128,      // จำนวนในลิสต์ (ในโควต้า + filter platform/status, ก่อน keyword) — คนละตัวกับ quota.used
  "filteredrecord": 3,     // หลัง keyword
  "totalpage": 1,
  "currentpage": 1,
  "quota": {                          // ← สำหรับ banner "Credit Transaction ใกล้หมด"
    "total": 100000,                  // โควต้า (null = ไม่จำกัด / ยังไม่ตั้ง config)
    "used": 99999,                    // ใช้ไปแล้ว (นับทุกแถว brand — เกิน total ได้)
    "near_limit": true                // used ≥ 95% ของ total → โชว์ banner
  },
  "datalist": [
    {
      "request_id": 1024,             // PK — ใช้เป็น key ต่อแถว / ปุ่ม unmask
      "order_number": "ON-2026-0001",
      "full_name": "ส**** น****",     // mask แล้ว (reveal=false) · "-" ถ้าไม่ผูกลูกค้า
      "platformid": 2,
      "platform_desc": "shopee",      // ใช้ map icon/label channel
      "request_time": "2026-08-11T09:31:00",  // = Created_Time (เวลากดรับแต้ม)
      "status": 1,                    // 1 Confirm · 2 Reject
      "status_desc": "Confirm",
      "reject_code": null,            // มีค่าเมื่อ status=2
      "reject_message": null          // ข้อความไทย โชว์เป็น tooltip เหตุผล reject ได้เลย
    }
  ]
}
```

### Credit Transaction Quota (`data.quota`)
| field | ความหมาย |
|---|---|
| `total` | โควต้าที่ตั้งให้ brand (config `mkp-transaction-quota`) · **null = ไม่จำกัด** |
| `used` | จำนวน transaction ที่ใช้ไป = นับทุกแถวของ brand (Confirm+Reject) · **เกิน `total` ได้** |
| `near_limit` | `true` เมื่อ `used ≥ total × 95%` → FE โชว์ banner ฟ้า + ตัวนับ `used/total` |

**พฤติกรรม:**
- **ไม่บล็อกการเก็บ** — ถึงโควต้าแล้วยังกดรับแต้ม/insert แถวใหม่ได้เรื่อย ๆ
- **แต่ list โชว์ได้แค่ในโควต้า** = แถว **แรกสุดยันลำดับที่ `total`** (เรียงตามการเกิด, Request_Id น้อย→มาก) · แถวที่ `total+1` เป็นต้นไป **เก็บใน DB แต่ไม่โผล่ใน list**
- **ซื้อโควต้าเพิ่ม** = ChocoCRM แก้ค่า config `mkp-transaction-quota` ให้สูงขึ้น → แถวที่เคยล้นจะกลับมาโผล่
- ตัวนับโชว์ `used/total` (เช่น `99,999/100,000`) — `used` เกิน `total` ได้ FE cap ที่ `total` เองถ้าอยากโชว์ไม่ให้เกิน

### mapping UI → field
| คอลัมน์ UI | field | หมายเหตุ |
|---|---|---|
| Order | (running no.) | FE รันเลขจาก `page`/`limit` เอง · id จริงใช้ `request_id` |
| Full Name | `full_name` | mask default · `"-"` ถ้าไม่มีลูกค้าผูก |
| Channel | `platformid` + `platform_desc` | map icon จาก id (1/2/3/4) |
| Request Time | `request_time` | Created_Time — FE format `dd/MM/yyyy HH:mm` |
| Status | `status` / `status_desc` | badge เขียว Confirm(1) / แดง Reject(2) |
| (tooltip reject) | `reject_message` | โชว์ตอน hover badge Reject |
| Filter Channel | req `platformid` | |
| Filter Status (ทั้งหมด) | req `status` | |
| Search | req `keyword` | ค้น order + ชื่อ |

---

## Status (`status` = `LmsMarketplaceConst.EarnStatus`)
| code | `status_desc` | ความหมาย |
|:-:|---|---|
| 1 | Confirm | ออกแต้มเข้า wallet สำเร็จ |
| 2 | Reject | ไม่ออกแต้ม — เหตุผลที่ `reject_code`/`reject_message` |

## Reject Code (`reject_code`, มีเมื่อ status=2)
| code | `reject_message` |
|:-:|---|
| 1 | ไม่พบ order ในระบบ marketplace |
| 2 | ไม่มีเกณฑ์ที่ใช้งานอยู่ของ platform นี้ |
| 3 | คิดแต้มได้ 0 (order ไม่เข้าเงื่อนไขให้แต้ม) |
| 4 | ออเดอร์นี้รับแต้มไปแล้ว |

---

## เรื่องชื่อลูกค้า (Full Name) — สำคัญกับ FE
- ตาราง `BCRM_MKP_Order_Request` **ไม่เก็บชื่อ** เก็บแค่ `Customer_Id` → backend **JOIN** `CRM_Customer` เอาชื่อจริง
- ชื่อใน `CRM_Customer` เป็น **Always-Encrypted** → ค้น/mask ทำ **in-memory** ฝั่ง server (FE ไม่ต้องรู้)
- `Customer_Id = null` (order ไม่ผูกลูกค้า) → `full_name = "-"` และ **ค้นด้วยชื่อจะไม่เจอแถวนั้น** (ไม่มีชื่อให้ค้น) — by design
- mask ใช้ `PiiMaskHelper.MaskName` (ตัวอักษรแรกของแต่ละคำ + `*`) → `"สมชาย ใจดี"` → `"ส**** ใ***"`

---

## Behavior / ceiling ที่ FE ควรรู้
- **ordering:** ใหม่สุดก่อน (`request_time` desc, tie-break `request_id` desc) — fix ฝั่ง server, FE ไม่ต้องส่ง sort
- **keyword** ค้นทั้ง `order_number` (ในตาราง MKP) และ **ชื่อ** (หลัง decrypt) — term เดียว OR กัน
- **ponytail:** ฝั่ง server โหลด order ใน window โควต้า (≤ `quota.total`) เข้า memory แล้ว search/paginate
  (เพราะชื่อ encrypted ทำ LIKE ฝั่ง SQL ไม่ได้ — pattern เดียวกับ Customer BW list) → ถ้า quota ถึงหลักหมื่น–แสนจริง ต้องย้าย name search ไป NGram index + paging ฝั่ง SQL

---

## ไฟล์ที่แตะ (impl)
| repo | ไฟล์ |
|---|---|
| lms-core | `Services/Marketplace/LmsMarketplaceOrderService.cs` (ใหม่) + register DI ใน `LmsServiceCollectionExtension.cs` |
| lms-core | `Constants/Marketplace/LmsMarketplaceConst.Earn.cs` — const `TransactionQuota` (key `mkp-transaction-quota`, near 95%) |
| config | ตั้งค่าโควต้าต่อ brand ที่ `BCRM_Config` key `mkp-transaction-quota` (`Int_Val`) — ไม่ตั้ง = ไม่จำกัด |
| lms-backend | `Contract/.../Requests/Marketplace/MarketplaceOrder/MarketplaceOrderRequestListReq.cs` |
| lms-backend | `Contract/.../Responses/Marketplace/MarketplaceOrderRequestListItemResp.cs` |
| lms-backend | `Application/.../Marketplace/MarketplaceOrder/MarketplaceOrderRequestListHandler.cs` |
| lms-backend | `Api/.../Controllers/Marketplace/MarketplaceOrderController.cs` |

> ไม่ต้องเพิ่มคอลัมน์/ตาราง — `BCRM_MKP_Order_Request` มีข้อมูลครบ (ดู [[../Marketplace-Point-Earn/03-API-Spec|Earn spec §Log column]] สำหรับ schema เต็ม)
