/* ============================================================================
   Marketplace Point Criteria — create tables
   Target: per-brand DB (BCRM_Privilege_Entities context), SQL Server
   รันครั้งเดียวต่อ brand DB → แล้วค่อย EF scaffold entities ออกมา
   spec: 01-Schema · convention ตาม CRM_Privilege / BP_Payment_Channel_Store_Mapping
   หมายเหตุ: Req_Identity_SRef = nvarchar(50) ตาม convention จริงของ sibling tables
             (doc 01 เขียน 100 — ยึด 50 ให้ตรงตารางอื่น)
   ============================================================================ */

SET XACT_ABORT ON;
BEGIN TRAN;

/* ---------- 1) header ---------------------------------------------------- */
IF OBJECT_ID(N'dbo.BCRM_MKP_Criteria_Config', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.BCRM_MKP_Criteria_Config
    (
        Criteria_ConfigId  INT            IDENTITY(1,1) NOT NULL,
        Criteria_Name      NVARCHAR(200)  NOT NULL,
        PlatformId         INT            NOT NULL,               -- core LmsMarketplaceConst.Platform (1-4)
        Point_By           INT            NOT NULL,               -- core LmsMarketplaceConst.PointBy (1-7)
        Point_By_Desc      NVARCHAR(100)  NOT NULL,
        Fixed_Point        INT            NOT NULL CONSTRAINT DF_MKP_Criteria_Fixed_Point      DEFAULT (0),
        Extra_Point        INT            NOT NULL CONSTRAINT DF_MKP_Criteria_Extra_Point      DEFAULT (0),
        Spending_Base      INT            NOT NULL CONSTRAINT DF_MKP_Criteria_Spending_Base    DEFAULT (0),
        Spending_Point     INT            NOT NULL CONSTRAINT DF_MKP_Criteria_Spending_Point   DEFAULT (0),
        Grand_Total_Point  INT            NOT NULL CONSTRAINT DF_MKP_Criteria_Grand_Total      DEFAULT (0),  -- = Fixed + Extra (save-time)
        Remark             NVARCHAR(500)  NULL,
        IsActive           BIT            NOT NULL CONSTRAINT DF_MKP_Criteria_IsActive         DEFAULT (0),
        Req_IdentityId     INT            NOT NULL,
        Req_Identity_SRef  NVARCHAR(50)   NOT NULL,
        CreatedTime        DATETIME       NOT NULL CONSTRAINT DF_MKP_Criteria_CreatedTime      DEFAULT (SYSUTCDATETIME()),
        UpdatedTime        DATETIME       NOT NULL CONSTRAINT DF_MKP_Criteria_UpdatedTime      DEFAULT (SYSUTCDATETIME()),
        IsDeleted          BIT            NOT NULL CONSTRAINT DF_MKP_Criteria_IsDeleted         DEFAULT (0),
        CONSTRAINT PK_BCRM_MKP_Criteria_Config PRIMARY KEY CLUSTERED (Criteria_ConfigId)
    );

    -- filter หน้า List (spec 01)
    CREATE NONCLUSTERED INDEX IX_MKP_Criteria_Platform_Deleted
        ON dbo.BCRM_MKP_Criteria_Config (PlatformId, IsDeleted);
END

/* ---------- 2) detail: ร้านค้า x สถานะ ----------------------------------- */
IF OBJECT_ID(N'dbo.BCRM_MKP_Criteria_Config_Detail', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.BCRM_MKP_Criteria_Config_Detail
    (
        Criteria_Config_DetailId INT           IDENTITY(1,1) NOT NULL,
        Criteria_ConfigId        INT           NOT NULL,
        Store_Ref                NVARCHAR(100) NOT NULL,          -- ตาม BP_Payment_Channel_Store_Mapping
        Order_Status             NVARCHAR(64)  NOT NULL,          -- raw token ของ platform ("COMPLETED", "delivered")
        Order_Status_Desc        NVARCHAR(100) NULL,              -- label ไทยไว้โชว์เฉยๆ
        IsDeleted                BIT           NOT NULL CONSTRAINT DF_MKP_Criteria_Detail_IsDeleted DEFAULT (0),
        CONSTRAINT PK_BCRM_MKP_Criteria_Config_Detail PRIMARY KEY CLUSTERED (Criteria_Config_DetailId),
        CONSTRAINT FK_MKP_Criteria_Detail_Config FOREIGN KEY (Criteria_ConfigId)
            REFERENCES dbo.BCRM_MKP_Criteria_Config (Criteria_ConfigId)
    );

    CREATE NONCLUSTERED INDEX IX_MKP_Criteria_Detail_ConfigId
        ON dbo.BCRM_MKP_Criteria_Config_Detail (Criteria_ConfigId);
END

/* ---------- 3) detail: SKU (Point By = SKU) ------------------------------ */
IF OBJECT_ID(N'dbo.BCRM_MKP_Criteria_Config_SKU', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.BCRM_MKP_Criteria_Config_SKU
    (
        Criteria_Config_SKUId INT           IDENTITY(1,1) NOT NULL,
        Criteria_ConfigId     INT           NOT NULL,
        SKU                   NVARCHAR(100) NOT NULL,             -- ตรงกับ CRM_Item.SKU
        Quantity              INT           NOT NULL,             -- ชิ้นต่อรอบ
        Point_Per_Qty         INT           NOT NULL,             -- แต้มต่อรอบ
        IsDeleted             BIT           NOT NULL CONSTRAINT DF_MKP_Criteria_SKU_IsDeleted DEFAULT (0),
        CONSTRAINT PK_BCRM_MKP_Criteria_Config_SKU PRIMARY KEY CLUSTERED (Criteria_Config_SKUId),
        CONSTRAINT FK_MKP_Criteria_SKU_Config FOREIGN KEY (Criteria_ConfigId)
            REFERENCES dbo.BCRM_MKP_Criteria_Config (Criteria_ConfigId)
    );

    CREATE NONCLUSTERED INDEX IX_MKP_Criteria_SKU_ConfigId
        ON dbo.BCRM_MKP_Criteria_Config_SKU (Criteria_ConfigId);
END

COMMIT TRAN;

/* ============================================================================
   OPTIONAL — R1 backstop (spec 05): 1 active ต่อ 1 platform
   เริ่มด้วย app-check ใน handler ก่อน; เปิด index นี้เมื่อกลัว race condition
   ----------------------------------------------------------------------------
   CREATE UNIQUE NONCLUSTERED INDEX UX_MKP_Criteria_ActivePerPlatform
       ON dbo.BCRM_MKP_Criteria_Config (PlatformId)
       WHERE IsActive = 1 AND IsDeleted = 0;
   ============================================================================ */
