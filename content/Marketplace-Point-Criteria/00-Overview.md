# Marketplace Point Criteria — Overview

หน้า **Marketplace → Point Criteria** ให้ผู้ใช้สร้าง "เกณฑ์การให้คะแนน" (Point Criteria) ต่อ marketplace channel ได้เป็น List และในแต่ละเกณฑ์เลือกได้หลายร้านค้า โดยแต่ละร้านกำหนด "สถานะออเดอร์ที่จะให้คะแนน" ได้เอง

## โครงสร้างข้อมูล
เก็บเป็น master-detail 2 ตาราง:

| ตาราง | หน้าที่ | คำอธิบาย |
|---|---|---|
| `CRM_Criteria_Config` | header | 1 แถว = 1 เกณฑ์ = 1 แถวในหน้า List |
| `CRM_Criteria_Config_Detail` | detail | 1 แถว = 1 ร้านค้าที่เลือก + สถานะออเดอร์ที่ให้คะแนน |

Platform (Shopee/Lazada/Tiktok/MyShop) ไม่สร้างตาราง/FK — เก็บเป็น `PlatformId` (int) อ้าง Constants ใน core, derive desc ได้จาก `GetDesc()`

## เอกสาร
- [[01-Schema]] — schema เต็ม 2 ตาราง + ER diagram
- [[02-UI-Mapping]] — mapping ช่องบน UI → column + open points
- [[03-Platform-Constant]] — Platform constant ใน core ที่ `PlatformId` อ้าง

## Convention ที่ยึด
อ้างอิงจาก lms-core (`CRM_Package_Criteria_Group.cs`, `BCRM_Master_Channel.cs`):
- PK แบบ `<Entity>Id` (int identity)
- Status/mode เก็บ `int` คู่กับ `*_Desc` (string)
- Flag เป็น `bool` — `IsActive`, `IsDeleted`
- Audit: `Req_IdentityId`, `Req_Identity_SRef`, `CreatedTime`, `CreatedUser`, `UpdatedTime`, `UpdatedUser`
- Store อ้างด้วย `Store_Ref` (nvarchar) ตาม `BP_Payment_Channel_Store_Mapping`
