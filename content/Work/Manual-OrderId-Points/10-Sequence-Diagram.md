---
tags: [work, lms, sequence, overview]
status: draft
created: 2026-08-21
---

# Sequence Diagram — Setup + End-User Flow + DB (คร่าวๆ)

> [!info] มุมมองแบบ sequence ของ [[09-System-Relation-Graph]]
> เรียงตามเวลา: ใครเรียกใคร, อ่าน/เขียน table ไหน. 🟩 core · 🟦 ใหม่ · ⬜ ยังไม่รู้ table

## (A) Setup — admin เปิดร้าน/ตั้งค่า (ครั้งเดียว)
```mermaid
sequenceDiagram
    autonumber
    actor AD as Admin
    participant API as Backend API
    participant DShop as ShopAccount 🟦
    participant DCrit as MKP_Point_Criteria 🟦

    AD->>API: เชื่อม Channel/Account MKP (Shopee/Lazada/Tiktok)
    API->>DShop: write ร้าน + ได้ ShopId
    AD->>API: สร้าง Point Criteria (Shop+เวลา · Spend/Sku/Both)
    API->>DCrit: write เกณฑ์
    AD->>API: ตั้ง status ปล่อยแต้ม + Real-time/T+1 + ACTIVE
    API->>DCrit: write config
    Note over DShop,DCrit: setup พร้อม → runtime (B) ใช้ต่อได้
```

## (B) End-user flow — End-User คิดแต้มจาก orderId (one-shot)
```mermaid
sequenceDiagram
    autonumber
    actor OP as End-User
    participant API as Manual Endpoint
    participant DShop as ShopAccount 🟦
    participant DOrder as Order data ⬜
    participant DMap as BuyerCustomerMap 🟦
    participant DCust as CRM_Customer 🟩
    participant DIssue as OrderPointIssue 🟦
    participant DCrit as MKP_Point_Criteria 🟦
    participant PS as LmsCrmPointService.Issue
    participant DPtx as CRM_Point_Transaction 🟩
    participant DWL as WL_Wallet_Ledger/_Pending 🟩

    OP->>API: เลือก Shop + กรอก orderId + กด คิดแต้ม
    API->>DShop: read ShopId
    API->>DOrder: read order by (orderId, ShopId)

    alt ไม่พบ order
        API-->>OP: ❌ ไม่พบ order
    else เจอ order → ได้ BuyerId
        API->>DMap: read (ShopId, BuyerId) → CustomerId
        alt ยังไม่ผูก customer
            API->>DCust: read/auto-link customer
            API->>DMap: write map (ShopId, BuyerId, CustomerId)
        end

        API->>DIssue: read IsUse (orderId)
        alt IsUse = true (คิดไปแล้ว)
            API-->>OP: Resp : OrderId ถูกคิดไปแล้ว (duplicate)
        else ยังไม่คิด
            API->>DCrit: read criteria ที่ match
            Note right of API: คำนวณ point = สูตร × transaction (int) + Exp_DT (UTC)

            API->>PS: Issue(Point_Calc=Custom, Point, Override_Exp_DT, Exp_DT)
            PS->>DPtx: write tx (Ext_TransactionId = orderId)
            PS->>DWL: write ledger → แต้มเข้า balance เลย ใช้ได้ทันที
            Note over PS,DWL: idempotent: ยิงซ้ำ orderId เดิม → คืน tx เดิม ไม่ออกแต้มซ้ำ
            PS-->>API: CrmPointTransaction (point, exp, ref)

            API->>DIssue: write IsUse=true + ref ledger
            API-->>OP: Resp : ✅ N แต้ม หมดอายุ dd/mm/yyyy + ลูกค้า + criteria + ref
        end
    end
```

