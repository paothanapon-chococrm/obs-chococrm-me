---
tags: [work, lms, graph, overview, data-model]
status: draft
created: 2026-08-21
---

# System Relation Graph — Setup + End-User Flow + DB (คร่าวๆ)

> [!info] หน้านี้คืออะไร
> ภาพรวมหน้าเดียว: **(A) admin เปิดร้าน/ตั้งค่าอะไรก่อน** → **(B) end-user flow คิดแต้ม** →
> แต่ละ step แตะ **table ไหน** (อ่าน/เขียน). ยังเป็น **ร่าง** — ยึด [[00-Overview]] เป็นหลัก
>
> 🟩 มีจริงใน core (brand DB) · 🟦 ต้องสร้างใหม่ (งานเรา) · ⬜ ยังไม่รู้ table (open question [[05-Open-Questions]])

## 1) Flow + DB touch (relation graph)
```mermaid
flowchart TD
    %% ================= SETUP (admin ทำก่อน) =================
    subgraph SETUP["🛠️ (A) Setup — admin เปิดร้าน/ตั้งค่า (ครั้งเดียว)"]
        direction TB
        A1[เชื่อม Channel/Account MKP<br/>Shopee·Lazada·Tiktok] -->|write| DShop[(ShopAccount 🟦)]
        A2[สร้าง Point Criteria<br/>Shop+เวลา · Type Spend/Sku/Both] -->|write| DCrit[(MKP_Point_Criteria 🟦)]
        A3[ตั้ง status ปล่อยแต้ม + Real-time/T+1] -->|write| DCrit
        A4[เปิดใช้งาน ACTIVE]
    end

    %% ================= RUNTIME (end-user flow) =================
    subgraph RUN["⭐ (B) End-user flow — operator คิดแต้มจาก orderId (one-shot)"]
        direction TB
        B0[เลือก Shop] -->|read| DShop
        B0 --> B1[กรอก orderId + กด คิดแต้ม]
        B1 -->|read: order by orderId+ShopId| DOrder[(Order data ⬜)]
        B1 --> B2{เจอ order?}
        B2 -->|ไม่เจอ| X1[❌ ไม่พบ order]
        B2 -->|เจอ → ได้ BuyerId| B3

        B3["หา (ShopId, BuyerId) → CustomerId"] -->|read| DMap[(BuyerCustomerMap 🟦)]
        B3 --> B4{ผูก customer ยัง?}
        B4 -->|ยัง| B4a[auto-link customer] -->|read| DCust[(CRM_Customer 🟩)]
        B4a -->|write map| DMap
        B4 -->|ผูกแล้ว| B5
        B4a --> B5

        B5{เคยคิดแต้ม? IsUse} -->|read| DIssue[(OrderPointIssue 🟦)]
        B5 -->|IsUse=true| X2[ℹ️ คิดไปแล้ว N แต้ม]
        B5 -->|ยัง| B6

        B6[match criteria + คำนวณ point×tx + Exp_DT] -->|read| DCrit
        B6 --> B7[LmsCrmPointService.Issue<br/>Point_Calc=Custom, Override_Exp_DT]
        B7 -->|write tx idempotent| DPtx[(CRM_Point_Transaction 🟩)]
        B7 -->|write balance เข้าเลย| DWL[(WL_Wallet_Ledger 🟩)]
        B7 -.->|log| DAct[(CRM_Activity 🟩)]
        B7 --> B8[set IsUse=true + เก็บ ref ledger]
        B8 -->|write| DIssue
        B8 --> S[✅ N แต้ม หมดอายุ dd/mm/yyyy]
    end

    SETUP -.ตั้งไว้ให้ runtime ใช้.-> RUN

    classDef exist fill:#DCFCE7,stroke:#22C55E,color:#065F46;
    classDef new   fill:#DBEAFE,stroke:#3B82F6,color:#1E3A8A;
    classDef tbd   fill:#F3F4F6,stroke:#9CA3AF,color:#374151,stroke-dasharray:4 3;
    class DCust,DPtx,DWL,DAct,DConfig exist;
    class DShop,DCrit,DMap,DIssue new;
    class DOrder tbd;
```

## 2) Table relation (ER — ร่าง)
```mermaid
erDiagram
    ShopAccount        ||--o{ Order              : "มี order (ต่อร้าน)"
    ShopAccount        ||--o{ BuyerCustomerMap   : "scope ของ buyer"
    CRM_Customer       ||--o{ BuyerCustomerMap   : "1 customer : N buyer (REQ-005)"
    Order              ||--o| OrderPointIssue     : "1 order : 1 การคิดแต้ม"
    MKP_Point_Criteria ||--o{ OrderPointIssue     : "criteria ที่ใช้คิด"
    CRM_Customer       ||--o{ CRM_Point_Transaction : "ออกแต้มให้ลูกค้า"
    OrderPointIssue    ||--o| CRM_Point_Transaction : "ref กลับ ledger/tx (void ได้)"
    CRM_Point_Transaction ||--o{ WL_Wallet_Ledger : "ลง ledger กระเป๋า"

    BuyerCustomerMap {
        int Id PK
        string ShopId "🟦 (ShopId,BuyerId) UNIQUE"
        string BuyerId
        long CustomerId FK "→ CRM_Customer (ไม่ unique = N:1)"
        string LinkMethod "auto|manual|self"
    }
    OrderPointIssue {
        string OrderId PK "🟦"
        string BuyerId
        bool IsUse
        int CriteriaId FK
        int Point
        datetime Exp_DT "UTC"
        long WL_LedgerId "ref กลับ wallet"
    }
    MKP_Point_Criteria {
        int CriteriaId PK "🟦"
        string ShopId "scope: ร้าน (required)"
        datetime Valid_From
        datetime Valid_Through
        int Type "bitflag Spend/Sku/Both — ไม่มี Priority"
        decimal Spend_Per_Point
    }
    CRM_Customer {
        long CustomerId PK "🟩 มีอยู่แล้ว"
        string Customer_Ref
    }
    CRM_Point_Transaction {
        long Id PK "🟩 มีอยู่แล้ว"
        string Ext_TransactionId "= idempotency (orderId)"
        int Point
        datetime Exp_DT
    }
```

## 3) สรุป table ที่เกี่ยวข้อง
| Table | สถานะ | หน้าที่ | โน้ต |
|-------|-------|---------|------|
| `CRM_Customer` | 🟩 core | ลูกค้าในระบบเรา | — |
| `CRM_Point_Transaction` | 🟩 core | บันทึกออกแต้ม (idempotent ด้วย `Ext_TransactionId`) | [[02-AddFundsV2-Usage]] |
| `WL_Wallet_Ledger` | 🟩 core | ledger กระเป๋า — แต้มเข้า balance เลย ใช้ได้ทันที | — |
| `CRM_Activity` | 🟩 core | log กิจกรรม | — |
| `CRM_Config` / `CRM_Point_Campaign` | 🟩 core | อัตราแปลงแต้ม/campaign (เราใช้ Custom เลยไม่พึ่ง) | — |
| `ShopAccount` (ชื่อชั่วคราว) | 🟦 ใหม่ | channel/ร้าน MKP, ให้ `ShopId` | REQ-004/006 · [[08-Buyer-Customer-Mapping]] |
| `MKP_Point_Criteria` (+`_Sku`) | 🟦 ใหม่ | เกณฑ์คิดแต้ม: Shop+เวลา · Type Spend/Sku/Both · ไม่มี priority/Group/cap | [[01-Criteria-Config]] |
| `BuyerCustomerMap` | 🟦 ใหม่ | `(ShopId,BuyerId) → CustomerId` (N:1) | [[08-Buyer-Customer-Mapping]] |
| `OrderPointIssue` | 🟦 ใหม่ | flag IsUse + ref ledger | [[04-Data-IsUse-Flag]] |
| Order data | ⬜ ยังไม่รู้ | เก็บ order ฝั่งเรา (orderId, buyerId, ShopId, status) + **line-item ราย SKU** (สมมติว่ามี — prereq SKU track) | บล็อกอยู่ [[05-Open-Questions]] |

> [!warning] ยังคร่าวๆ
> ชื่อ table ใหม่ (ShopAccount/MKP_Point_Criteria) เป็นชื่อชั่วคราว · Order data ยังไม่รู้เก็บที่ไหน (ก้อนใหญ่สุดที่บล็อก)
> · **แต้มเข้า balance เลย ไม่มี Pending** — คิดแต้มได้เฉพาะ order ที่ถึง status ปล่อยแต้มแล้ว
