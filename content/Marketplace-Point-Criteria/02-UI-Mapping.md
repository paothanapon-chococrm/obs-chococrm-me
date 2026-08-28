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
| dropdown "เลือกสถานะให้คะแนน" ต่อร้าน | `Order_Status` + `Order_Status_Desc` |
| Earn Point | `Earn_Point` |
| Extra | `Extra_Point` |
| Point By (dropdown) | `Point_By` + `Point_By_Desc` |
| Grand Total Point | `Grand_Total_Point` |
| Remark | `Remark` |

## Order Status dropdown (ค่าที่พบใน mockup)
`Order_Status` เป็น code, `Order_Status_Desc` เก็บข้อความ:
- รอชำระเงิน
- ชำระเงินสำเร็จ
- อยู่ระหว่างการจัดส่ง
- จัดส่งสำเร็จ

> ค่าจริงควร map กับ enum สถานะออเดอร์ของ marketplace hub (ยืนยันชุด code ก่อน implement)

## Open Points
1. **ประเภท Spending + SKU พร้อมกัน** — row ที่ 3 ในหน้า List แสดง badge ทั้ง Spending และ SKU
   - ปัจจุบันออกแบบให้ `Point_By` เป็น mode เดียวต่อเกณฑ์ แล้ว derive badge จากมัน
   - ถ้า 1 เกณฑ์ต้องรองรับหลาย mode จริง → เปลี่ยน `Point_By` เป็น bitmask หรือแยกเป็นตาราง mapping
   - **ponytail:** เริ่มด้วย single `Point_By` ก่อน ขยายเป็น bitmask เมื่อ requirement ยืนยันว่าต้องหลาย mode
2. **Point By มีค่าอะไรบ้าง** — dropdown "Point By" ใน mockup ยังเป็น "Select" ต้องได้ชุดค่าจริง (เช่น by spending / by SKU / by order) เพื่อ fix code ของ `Point_By`
3. **Grand Total Point** — คำนวณ = `Earn_Point + Extra_Point` ตอน save (ช่องบน UI เป็น read-only) หรือให้เก็บค่าที่ backend คำนวณเท่านั้น
