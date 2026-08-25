---
tags: [reference, lms, wallet, points]
created: 2026-08-20
---

# ออกแต้มพร้อมกำหนดวันหมดอายุ

> [!success] ตัดสินใจแล้ว (21-Aug-2026) — ใช้ `LmsCrmPointService.Issue` ตัวหลัก **ไม่ใช้ AddFundsV2 ตรง**
> wallet เป้าหมายเป็นชนิด **CRM** → ต้องผ่าน `Issue` อยู่แล้ว เราแค่ **ส่ง param กำหนด exp เอง**
> (`Override_Exp_DT + Exp_DT`) ให้ core ไป set `AddFundsV2(ExpCalcMode.Custom)` ให้ข้างใน
> → ดูวิธีเรียกที่ [section "ใช้จริง: LmsCrmPointService.Issue"](#ใช้จริง-lmscrmpointserviceissue) ด้านล่าง
> ส่วน AddFundsV2 ข้างล่างนี้เก็บไว้เป็น **เลเยอร์ล่างที่ Issue เรียกต่อ** (reference เฉยๆ)

## ใช้จริง: LmsCrmPointService.Issue

> [!info] ที่มา `Choco.LMS.Core/Services/CRM/LmsCrmPointService.cs:394`

### Signature (ของจริง)
```csharp
Task<CrmPointTransaction> Issue(
    string brandRef,
    int refType,                         // LmsCrmConst.Customer.RefType.* (ต้องอยู่ใน ValidList)
    string customerRef,
    string transactionId,                // = idempotency key, max 100 (ใช้ orderId/buyId กันซ้ำ)
    CrmPointIssueDto issueData,
    CrmPointRefInfo? refInfo = null,     // metadata ที่มา (optional) — ดู "refInfo คืออะไร"
    Dictionary<string, object>? @params = null,
    DateTime? reqTimestamp = null,
    bool lockCustomer = true)
```

### ปั้น issueData + เรียก (ตรงกับที่จดไว้)
```csharp
var issueData = new CrmPointIssueDto
{
    Point_Calc      = LmsCrmConst.Point.CalculationMode.Custom, // = 9 (ใช้ค่า Point ตรงๆ ไม่ convert)
    Point           = pointSum,        // int! (สูตร × transaction, ปัดเป็น int) จำนวนแต้มที่จะเพิ่ม
    Visit_Calc_Mode = LmsCrmConst.Visit.CalculationMode.Skip,   // = 2 (ไม่คิด visit)
    Override_Exp_DT = true,
    Exp_DT          = criteriaConfig.Exp_DT,   // วันหมดอายุแต้ม — UTC!
};

var pointTran = await crmPointService.Issue(
    brandRef, refType, customerRef,
    transactionId: issueTransactionId,   // orderId/buyId
    issueData: issueData,
    refInfo: pointRefInfo);

if (pointTran.Is_Duplicate_TX) { /* txId ซ้ำ = order นี้คิดไปแล้ว, คืน ledger เดิม */ }
```

> [!warning] แก้จาก pseudocode ที่จด
> - `Point_Calc = custom` → ค่าจริงคือ **`9`** (`CalculationMode.Custom`) ไม่ใช่ string
> - `Visit_Calc_Mode = skip` → **`2`** (`CalculationMode.Skip`)
> - `Point` เป็น **`int`** (ไม่ใช่ decimal) → `pointSum` ต้องปัดเป็น int ก่อน
> - `Exp_DT` ต้องเป็น **UTC** (DB GETDATE()=UTC, ดู memory lms-job-quartz-utc)

### refInfo คืออะไร (ที่ยัง งง)
`CrmPointRefInfo` = **metadata บอกที่มาของแต้ม เอาไว้ trace เฉยๆ ไม่ได้ใช้คิดคะแนน → ส่ง null ได้**
(`Choco.LMS.Core/Services/CRM/Models/CrmPointRefInfo.cs`). สำหรับ manual orderId ควร fill:

| field | ใส่อะไร |
|---|---|
| `Reference` | `orderId` (อ้างอิงหลัก) |
| `Extra_Ref` | `buyId` (max 250) |
| `Store_Ref` | ถ้ามีร้าน → core map เป็น `storeId` ให้ (`Issue():422`); ไม่มีก็ข้าม |
| `Channel` / `Area` | `LmsActivityConst.Channel.*` / `Area.*` (default Area = CRM) |
| `POS_OrderId` | ถ้า order เป็นเลข POS |
| `Remark` | ข้อความ audit |

ทั้งหมด nullable → เริ่มแค่ `new CrmPointRefInfo { Reference = orderId, Extra_Ref = buyId }` พอ

---

## (เลเยอร์ล่าง) AddFundsV2 — reference
> `Choco.LMS.Core/Services/Wallet/LmsWalletService.cs` → `AddFundsV2(...)`
> `Issue` เรียกต่อตัวนี้ให้ ไม่ต้องเรียกเอง — เก็บไว้เข้าใจว่า `Override_Exp_DT` ไปโผล่ที่ไหน

## Signature
```csharp
Task<WalletTransaction> AddFundsV2(
    string brandRef, string walletRef, string transactionId, decimal amount,
    WalletAddFundsDto? info = null,
    LmsRequestContext? reqContext = null,
    Dictionary<string, object>? @params = null)
```

## กำหนดวันหมดอายุเอง (Custom Expiration)
ส่ง 2 key ใน `@params`:

| Key (constant) | ค่า string | ความหมาย |
|---|---|---|
| `LmsWalletConst.Ledger.ExpCalcMode.Param_Key` | `"ExpCalcMode"` | โหมดคิด exp |
| `...ExpCalcMode.Custom` | `3` | ใช้วันที่เราส่งเอง |
| `...ExpCalcMode.Param_Exp_DT_Key` | `"Exp_Calc_Custom_Exp_DT"` | วันหมดอายุ (`DateTime`) |

โหมดทั้งหมด: `Default = 1` (คิดจาก scheme), `Package = 2`, `Custom = 3`

## ตัวอย่าง — เรียกตรง (non-CRM wallet)
```csharp
var expDt = new DateTime(2026, 12, 31, 23, 59, 59, DateTimeKind.Utc); // ส่งเป็น UTC
var wlParams = new Dictionary<string, object>
{
    [LmsWalletConst.Ledger.ExpCalcMode.Param_Key]        = LmsWalletConst.Ledger.ExpCalcMode.Custom,
    [LmsWalletConst.Ledger.ExpCalcMode.Param_Exp_DT_Key] = expDt,
};
var result = await walletService.AddFundsV2(
    brandRef, walletRef, transactionId: "ORDER-12345",
    amount: 100M,
    info: new WalletAddFundsDto { Reference = orderId, Extra_Ref = buyId },
    reqContext: new LmsRequestContext(IdentityContext),
    @params: wlParams);

if (result.Is_Duplicate_TX) { /* transactionId ซ้ำ = ไม่ได้เติมรอบนี้ */ }
```

## ตัวอย่าง — ผ่าน CRM point (แต้ม CRM)
Wallet ชนิด CRM **ห้ามเรียก AddFundsV2 ตรง** ต้องผ่าน `LmsCrmPointService.Issue`
แล้ว set flag บน issueData → ภายในจะ set `ExpCalcMode.Custom` ให้เอง
(`LmsCrmPointService.cs:568-572`):
```csharp
issueData.Override_Exp_DT = true;
issueData.Exp_DT = expDt;   // UTC
```

## กฎที่พลาดบ่อย ⚠️
1. **`transactionId` = idempotency key** — ซ้ำ = ได้ ledger เดิมกลับมา (`Is_Duplicate_TX=true`) ไม่เติมซ้ำ
   → เหมาะมากกับงานเรา: ใช้ `orderId`/`buyId` เป็น transactionId กันคิดซ้ำได้ตั้งแต่ชั้น wallet
2. **exp ส่งเป็น UTC** — DB ใช้ GETDATE() = UTC (ดู memory lms-job-quartz-utc); ส่ง local จะเพี้ยน ±7 ชม.
3. **อย่าส่ง exp เป็นอดีต** — โค้ดไม่ validate; แต้มจะเข้ามาแล้ว expired ทันที
4. wallet CRM ต้องมี `@params["caller"] = "crm"` ไม่งั้น throw

## เชื่อมกับ IsUse flag
`transactionId` idempotent = การกันซ้ำชั้นหนึ่งอยู่แล้ว แต่เรายังต้องมี [[04-Data-IsUse-Flag]]
ฝั่ง order ของเราเพื่อ (ก) โชว์สถานะเร็ว ไม่ต้องยิง wallet, (ข) กัน race ก่อนถึง wallet
