# UI → Column Mapping

กลับไป [[00-Overview]] · ดู schema [[01-Schema]]

## หน้า List (Point Criteria)
| ช่องบน UI | Column |
|---|---|
| ชื่อเกณฑ์ | `CRM_Criteria_Config.Criteria_Name` |
| Channel (icon Lazada/Shopee/…) | `PlatformId` → desc จาก core constant `GetDesc()` ([[03-Platform-Constant]]) |
| ประเภท (badge Spending / SKU) | **derive จาก `Point_By`** — ไม่เก็บ column แยก |
| สถานะ (ใช้งานอยู่ / ไม่ใช้งาน) | `IsActive` |
| Lasted Update | `UpdatedTime` |

## หน้า Add / Edit Point Criteria
| ช่องบน UI | Column |
|---|---|
| สถานะ (toggle ใช้งานอยู่) | `IsActive` |
| ชื่อเกณฑ์ | `Criteria_Name` |
| เลือก Channel (Shopee/Lazada/Tiktok/MyShop) | `PlatformId` (core constant) |
| เลือกร้านค้า (checkbox หลายร้าน) | 1 แถว `CRM_Criteria_Config_Detail` ต่อ 1 ร้าน → `Store_Ref` |
| dropdown "เลือกสถานะให้คะแนน" ต่อร้าน (ค่าตาม Platform ที่เลือก) | `Order_Status` (raw token) + `Order_Status_Desc` |
| SKUs — ปุ่ม `+` เพิ่มได้หลายแถว (ตอน Point By = SKU) | 1 แถว `CRM_Criteria_Config_SKU` ต่อ 1 SKU |
| ↳ SKU (dropdown) | `SKU` |
| ↳ Quantity (Pc(s)) | `Quantity` |
| ↳ Point/Qt. | `Point_Per_Qty` |
| Total Point (read-only ใต้ SKUs) | **preview ฝั่งหน้าบ้าน** `Σ Quantity × Point_Per_Qty` — ไม่เก็บ DB, ไม่ใช่ยอดจริง (คิดจริงตอน earn) |
| Point By (dropdown) | `Point_By` (code 1–7) + `Point_By_Desc` |
| Fixed point (mode FIXED) | `Fixed_Point` |
| Extra (mode FIXED) | `Extra_Point` |
| ยอดต่อรอบ เช่น 500 (mode SPENDING) | `Spending_Base` |
| แต้มต่อรอบ เช่น 10 (mode SPENDING) | `Spending_Point` |
| Grand Total Point (read-only) | `Grand_Total_Point` = `Fixed_Point + Extra_Point` (ส่วนคงที่เท่านั้น; Spending/SKU คิดตอน earn) |
| Remark | `Remark` |

## ส่ง payload ตอน Add/Edit ยังไง
ตาม pattern req ของ repo นี้ (`PrivilegeCriteriaGroupAddReq`): header แบนๆ + `List<Dto>` ต่อ detail. **dropdown status เก็บ value เป็น raw token** แล้วส่งไปในลิสต์ร้าน — ไม่ใช่ id/index

```jsonc
// POST add criteria
{
  "Criteria_Name": "โปรโมชั่นเดือนตุลา",
  "PlatformId": 2,                 // Shopee (core constant)
  "IsActive": true,
  "Point_By": 5,                   // Fixed + SKUs
  "Fixed_Point": 50, "Extra_Point": 10,
  "Spending_Base": 0, "Spending_Point": 0,
  "Stores": [
    { "Store_Ref": "choco-official", "Order_Status": "COMPLETED" },  // ← ค่าจาก dropdown = raw token ของ Shopee
    { "Store_Ref": "choco-sp",       "Order_Status": "SHIPPED"   }
  ],
  "Skus": [
    { "SKU": "ABC-001", "Quantity": 2, "Point_Per_Qty": 5 }
  ]
}
```

- `Order_Status` = token ตรงจาก dropdown (`value` ของ option = token, `label` = ข้อความไทย)
- ไม่ต้องส่ง `Order_Status_Desc` / `Point_By_Desc` / `Total_Point` / `Grand_Total_Point` — **derive ที่ server ตอน save** (ดู [[05-Validation]])
- `PlatformId` คุมว่า dropdown แต่ละร้าน list token ชุดไหน — frontend โหลดจาก [[06-OrderStatus-Mapping]] endpoint ตาม platform ที่เลือก

## Order Status dropdown (ต่อ Platform)
dropdown แสดง status **ของ platform ที่เลือก** แล้วเก็บ raw token ตรงๆ ลง `Order_Status` (ไม่ normalize) — เช่น Shopee โชว์ `COMPLETED/SHIPPED/…`, Lazada โชว์ `delivered/shipped/…`. ค่าที่ show ใน 4 ข้อของ mockup เป็น label ไทย ไปอยู่ `Order_Status_Desc` · ชุด token เต็มต่อเจ้า + earn matching [[06-OrderStatus-Mapping]]

## Point By dropdown → mode
`Point_By` เป็น code เรียง 1–7 ตรงกับ dropdown (single 3 + combo 4) · รายละเอียด [[04-PointBy-Constant]]

| `Point_By` | Dropdown | เปิด sub-section |
|---|---|---|
| 1 | Fixed points | Fixed point + Extra |
| 2 | Spending | Spending_Base/Spending_Point |
| 3 | SKUs | SKUs (`CRM_Criteria_Config_SKU`) |
| 4 | Fixed points + Spending | Fixed + Spending |
| 5 | Fixed points + SKUs | Fixed + SKUs |
| 6 | Spending + SKUs | Spending + SKUs |
| 7 | Fixed points + Spending + SKUs | ทั้ง 3 |

badge Spending/SKU ในหน้า List = derive จาก bit ที่เปิดใน `Point_By` (ตอบ row ที่แสดงหลาย badge พร้อมกันได้แล้ว)

## แต้มต่อ mode (ยืนยันแล้ว)
| mode | column | สูตร | เวลาคำนวณ |
|---|---|---|---|
| `FIXED` | `Fixed_Point` + `Extra_Point` | `Fixed_Point + Extra_Point` | ตอน save (คงที่) |
| `SPENDING` | `Spending_Base` + `Spending_Point` | `floor(ยอดบิล / Spending_Base) × Spending_Point` | ตอน earn (ต้องรู้ยอดบิล) |
| `SKUS` | `CRM_Criteria_Config_SKU` | ต่อ SKU ที่ซื้อ: `floor(จำนวนที่ซื้อ / Quantity) × Point_Per_Qty` | ตอน earn (ต้องเห็นรายการ item) |

`Grand_Total_Point` (read-only บน UI) = ส่วนคงที่ = `FIXED` เท่านั้น; `SPENDING` และ `SKUS` บวกเพิ่มตอน earn (ต้องเห็นยอดบิล/รายการ item จริง)

## Open Points
1. **rounding ของ SPENDING** — `floor(ยอดบิล / Spending_Base) × Spending_Point` ปัดลงเป็น default; ยืนยันกฎปัด/เศษกับ marketplace hub
2. **หลาย mode รวมกัน** — เมื่อเปิดหลาย flag แต้มที่ลูกค้าได้ = บวกกันทุก mode (ยืนยันว่าไม่ใช่ max/override)
