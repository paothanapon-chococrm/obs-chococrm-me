# Frontend Brief — รับแต้มจาก order marketplace

spec เต็ม [[03-API-Spec]] · overview [[00-Overview]]

> วางต่อให้ AI coder / dev ฝั่ง frontend ได้เลย (ส่วน [[#Prompt วางได้เลย]])

## สรุปสั้นๆ ให้คนอ่าน
- ผู้ใช้เลือก platform + กรอกเลข order → กดรับแต้ม → **ออกแต้มจริงทันที** (ไม่ใช่ preview)
- ต้องเช็คผล **2 ชั้น**: envelope `status` (request ผ่านไหม) → แล้วดู `data.status` (ได้แต้ม 1 / ไม่ได้ 2)
- popup สำเร็จโชว์ `data.total_point` · ไม่สำเร็จโชว์ `data.reject_message` (backend ส่งไทยมาแล้ว)
- **กันกดซ้ำ** — endpoint ออกแต้มจริง (แม้ backend dedup แต้มซ้ำให้ แต่ FE ต้อง lock ปุ่มตอนรอ response)

## Prompt วางได้เลย

```
สร้างฟีเจอร์ "รับแต้มจากคำสั่งซื้อ marketplace" บน WebApp

API: POST /api/v1/internal/Marketplace/EarnCalculate  (แนบ auth token ของ WebApp)
Request body (property เป็นตัวพิมพ์เล็กทั้งหมด):
  { "platform_order_ref": string, "platform_id": number }
  platform_id: 1=Lazada, 2=Shopee, 4=TikTokShop  (3=LineMyShop ยังไม่รองรับ อย่าให้เลือก)

หมายเหตุ: endpoint นี้ "ออกแต้มจริงทันที" ไม่ใช่ preview → กดสำเร็จ = แต้มเข้าบัญชีแล้ว

UI ฟอร์ม:
  - dropdown เลือก platform (map เป็น platform_id) — โชว์แค่ Lazada/Shopee/TikTokShop
  - text input เลข order (platform_order_ref) — trim ก่อนส่ง, ปุ่มรับแต้ม disable ถ้าว่าง
  - ระหว่างรอ response: ปุ่ม loading + disable กันกดซ้ำ

อ่านผล 2 ชั้น:
  1) envelope.status !== "success"  → error จริง (validation/network/customer ไม่พบ)
     → toast/alert จาก error message หรือข้อความ fallback "เกิดข้อผิดพลาด ลองใหม่อีกครั้ง"
  2) envelope.status === "success" → ดู data.status
       data.status === 1  → สำเร็จ ได้แต้ม → popup สำเร็จ (โชว์ data.total_point)
       data.status === 2  → ไม่ได้แต้ม     → popup แจ้งเตือน (โชว์ data.reject_message)

Popup สำเร็จ (data.status === 1):
  - หัวข้อ: "รับแต้มสำเร็จ 🎉"
  - ตัวเลขเด่นกลางจอ: "+{data.total_point} แต้ม"
  - บรรทัดรอง: "คำสั่งซื้อ {data.order_number}" · "ยอดใช้จ่าย {data.spending} บาท"
  - ถ้ามี data.sku_lines (length > 0): list "{sku} × {qty} = {point} แต้ม"
  - ปุ่มเดียว: "ตกลง" → ปิด popup + reset ฟอร์ม

Popup ไม่สำเร็จ (data.status === 2):
  - หัวข้อ: "ยังรับแต้มไม่ได้"
  - เนื้อหา: data.reject_message  (ไทยพร้อมโชว์)
  - คำแนะนำเสริมตาม data.reject_code:
      1 = ตรวจสอบเลขคำสั่งซื้อให้ถูกต้อง หรือรอให้ระบบ sync order สักครู่แล้วลองใหม่
      2 = ยังไม่มีแคมเปญให้แต้มสำหรับช่องทางนี้
      3 = คำสั่งซื้อนี้ไม่เข้าเงื่อนไขรับแต้ม
  - ปุ่ม: "ลองอีกครั้ง" → ปิด popup แต่คงค่าในฟอร์มไว้

ห้ามคิดแต้มเองฝั่ง frontend — ใช้ data.total_point จาก response เท่านั้น
```

## ตัวอย่าง response ให้ FE ทดสอบ mapping
สำเร็จ → [[03-API-Spec#Response]] · reject codes → [[03-API-Spec#Reject Code]]
