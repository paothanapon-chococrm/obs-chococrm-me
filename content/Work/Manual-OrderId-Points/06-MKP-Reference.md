---
tags: [reference, lms, marketplace, mockup]
status: not-decided
created: 2026-08-20
source: "Downloads/CRM Marketplace Point Accumulation Module (mockup)"
---

# MKP Point Accumulation — Reference (mockup)

> [!warning] ยังไม่ลงมติ
> นี่คือ **mockup/ตัวอย่าง** จาก UI ที่ nutthanicha ทำไว้ ยังไม่ผ่านการตัดสินใจว่าจะเอาแบบนี้จริง
> ดูเป็นแนว เอาเฉพาะส่วนที่เกี่ยวกับงานเรา ([[00-Overview]]) — **ไม่ต้องลอกทั้งหมด**

## โมดูล Marketplace = 4 ซับโมดูล
1. **MKP Dashboard** — สรุปการเชื่อมต่อ/order แต่ละ channel
2. **Channel Connection** — ผูก Buyer ID ↔ Customer ID, จัดการบัญชีร้าน
3. **Point Criteria** — เกณฑ์คิดแต้ม ← **เกี่ยวกับงานเรา** [[01-Criteria-Config]]
4. **Campaign Period** — ช่วงเวลา campaign

## Requirements (REQ table — 11 ข้อ)
| ID | ย่อ |
|----|-----|
| REQ-001 | sync / un-sync / re-sync account |
| REQ-002 | เลือก solution ปล่อยแต้ม **Real-time หรือ T+1 (batch)** |
| REQ-003 | เลือก **status** ที่จะปล่อยแต้ม ต่อ MKP |
| REQ-004 | สร้าง Account MKP ต่อแบรนด์ |
| REQ-005 | ผูกได้หลาย **Buyer ID** > 1 account ต่อ MKP (Shopee/Lazada/Tiktok) |
| RQ-006 | ผูกได้หลายบัญชีร้าน > 1 account; แบรนด์เพิ่มเองได้ |
| **RQ-007** | **ตั้งค่า Point แยกได้ทั้ง ยอดใช้จ่ายทั้งหมด และ ราย SKU** ← หัวใจ criteria |
| RQ-008 | Dashboard สรุปการเชื่อมต่อแต่ละ channel |
| RQ-009 | Report แยกรายร้าน/account ต่อ MKP |
| RQ-010 | ร้านตั้งเองได้ว่าให้แต้มตั้งแต่ status ไหน (Ship, Complete) |
| RQ-011 | Authen security ทั้งขา **Check Order ID** และขา **Earn Point** |

## Point Criteria — โครงที่ mockup วางไว้
- **Rule Set** เช่น "MKP Point Earning 2026" — ประเมิน **บนลงล่าง**, ชนกันใช้ **priority สูงกว่า**
- คอลัมน์: `# | ชื่อเกณฑ์ | ประเภท | เงื่อนไข | ผลลัพธ์ | สถานะ | ช่วงเวลา`
- **ประเภทเกณฑ์**: ยอดใช้จ่ายรวม (spend-based) / ราย SKU (SKU-based, ตั้งทีละรายการได้)
- **ผลลัพธ์**: ตัวคูณจาก base point (× multiplier เช่น x1–x9)
- **เพดาน (Cap)**: ต่อ 1 order (เช่น 2,000pt) / ต่อลูกค้า·เดือน (เช่น 10,000pt) / order ต่อวัน·ลูกค้า (เช่น 5)

> [!important] design จริงเราต่างจาก mockup นี้แล้ว → ยึด [[01-Criteria-Config]]
> ตัด **Rule Set / priority / บนลงล่าง** ทิ้ง · กันชนที่ **config-time validate** (Shop+SKU/Spend+เวลา) แทน ·
> `Type` เป็น **bitflag Spend/Sku/Both** · ตัวคูณอยู่ **ราย SKU** · **ไม่มี All-Shop** (บังคับเลือกร้าน) · ยุบ Group เหลือ 2 table ·
> **ยังไม่มี Cap** (YAGNI — เพิ่มตอนมี requirement จริง, ถ้าเพิ่ม = shop-level clamp ผลรวม)

## Pending Point (สำคัญต่อ flow เรา)
- แต้มปล่อยเข้ากระเป๋าเมื่อ **status = Confirm Order** เท่านั้น
- ก่อนถึง status → แสดง **Pending Point** (ล็อกไว้ ยังไม่เข้า balance)
- ต่อ [[04-Data-IsUse-Flag]]: IsUse อาจต้องมีมากกว่า bool → มี state (Pending / Issued / Void)

## Security (REQ-011) → เชื่อมกับ manual endpoint เรา
- ขา **Check Order ID**: กันยิงสุ่มเลข order
- ขา **Earn Point**: กันได้แต้มซ้ำ / แต้มปลอม
→ ตรงกับ [[03-Manual-Endpoint]] (idempotent ด้วย orderId) + [[04-Data-IsUse-Flag]]

## Account linking (ยังไม่ตัดสินใจ)
Buyer ID ↔ Customer ID ออกแบบไว้ 2 ทางให้เทียบ — ยังไม่เลือก default
→ นี่คือ "เคยผูก buyid ไปแล้วหรือยัง" ใน [[00-Overview]]
