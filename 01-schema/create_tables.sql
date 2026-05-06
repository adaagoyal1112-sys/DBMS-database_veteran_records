-- ============================================================
-- IVRPMS — Indian Veteran Resource & Pension Management System
-- DDL Script: MySQL 8.0+ compatible
-- Normalization: 3NF / BCNF compliant
-- ============================================================

-- ============================================================
-- STEP 0: Drop tables in reverse dependency order (safe re-run)
-- ============================================================
CREATE DATABASE IF NOT EXISTS ivrpms;
USE ivrpms;
DROP TABLE IF EXISTS RANK_HISTORY;
DROP TABLE IF EXISTS AUDIT_LOG;
DROP TABLE IF EXISTS NOMINEE;
DROP TABLE IF EXISTS PENSION_RECORD;
DROP TABLE IF EXISTS VETERAN;
DROP TABLE IF EXISTS REGIMENT;

-- ============================================================
-- TABLE 1: REGIMENT
-- Purpose : Master list of Indian Army regiments
-- No FK dependencies — created first
-- ============================================================
CREATE TABLE REGIMENT (
    regiment_id     INT             NOT NULL AUTO_INCREMENT,
    regiment_name   VARCHAR(80)     NOT NULL,
    base_location   VARCHAR(60)     NOT NULL,
    arm_of_service  VARCHAR(30)     NOT NULL,

    CONSTRAINT pk_regiment
        PRIMARY KEY (regiment_id),

    CONSTRAINT chk_arm_of_service
        CHECK (arm_of_service IN (
            'Infantry', 'Artillery', 'Armour',
            'Engineers', 'Signals', 'Support', 'Medical'
        ))
);

-- ============================================================
-- TABLE 2: VETERAN
-- Purpose : Core entity — personal and service record
-- Depends on: REGIMENT
-- ============================================================
CREATE TABLE VETERAN (
    veteran_id          INT             NOT NULL AUTO_INCREMENT,
    service_number      VARCHAR(15)     NOT NULL,
    full_name           VARCHAR(100)    NOT NULL,
    date_of_birth       DATE            NOT NULL,
    gender              CHAR(1)         NOT NULL,
    rank_name               VARCHAR(30)     NOT NULL,
    regiment_id         INT             NOT NULL,
    date_of_enlistment  DATE            NOT NULL,
    date_of_retirement  DATE,
    status              VARCHAR(15)     NOT NULL,
    state_of_domicile   VARCHAR(30),
    contact_number      VARCHAR(12),
    aadhar_ref          VARCHAR(4),

    CONSTRAINT pk_veteran
        PRIMARY KEY (veteran_id),

    CONSTRAINT uq_service_number
        UNIQUE (service_number),

    CONSTRAINT fk_vet_regiment
        FOREIGN KEY (regiment_id)
        REFERENCES REGIMENT(regiment_id),

    CONSTRAINT chk_vet_gender
        CHECK (gender IN ('M', 'F')),

    CONSTRAINT chk_vet_status
        CHECK (status IN ('Active', 'Retired', 'Deceased', 'Missing')),

    CONSTRAINT chk_vet_rank
        CHECK (rank_name IN (
            'Sepoy', 'Naik', 'Havildar',
            'Naib Subedar', 'Subedar', 'Subedar Major',
            'Lieutenant', 'Captain', 'Major',
            'Lt. Colonel', 'Colonel', 'Brigadier',
            'Major General', 'Lt. General', 'General'
        )),

    -- Retirement must be after enlistment
    CONSTRAINT chk_retire_after_enlist
        CHECK (date_of_retirement IS NULL
            OR date_of_retirement > date_of_enlistment),

    -- Must be born before enlisting
    CONSTRAINT chk_dob_before_enlist
        CHECK (date_of_enlistment > date_of_birth),

    -- Service number format: IC-, JC-, or GC- followed by 5-6 digits
    CONSTRAINT chk_service_number_format
        CHECK (service_number REGEXP '^(IC|JC|GC)-[0-9]{5,6}$'),

    -- Indian mobile numbers start with 6-9
    CONSTRAINT chk_contact_number
        CHECK (contact_number IS NULL
            OR contact_number REGEXP '^[6-9][0-9]{9}$'),

    -- Aadhar: last 4 digits only
    CONSTRAINT chk_aadhar_ref
        CHECK (aadhar_ref IS NULL
            OR aadhar_ref REGEXP '^[0-9]{4}$')
);

-- ============================================================
-- TABLE 3: PENSION_RECORD
-- Purpose : Financial disbursement record per veteran
-- Depends on: VETERAN
-- ============================================================
CREATE TABLE PENSION_RECORD (
    pension_id          INT             NOT NULL AUTO_INCREMENT,
    veteran_id          INT             NOT NULL,
    pension_type        VARCHAR(20)     NOT NULL,
    monthly_amount      DECIMAL(10, 2)  NOT NULL,
    da_percentage       DECIMAL(5, 2)   NOT NULL DEFAULT 0.00,
    bank_account_no     VARCHAR(18)     NOT NULL,
    bank_ifsc           VARCHAR(11)     NOT NULL,
    pension_start_date  DATE            NOT NULL,
    pension_end_date    DATE,
    payment_status      VARCHAR(15)     NOT NULL,

    CONSTRAINT pk_pension
        PRIMARY KEY (pension_id),

    CONSTRAINT fk_pen_veteran
        FOREIGN KEY (veteran_id)
        REFERENCES VETERAN(veteran_id),

    -- One pension type per veteran (e.g. only one 'Service' pension)
    CONSTRAINT uq_active_pension
        UNIQUE (veteran_id, pension_type),

    CONSTRAINT chk_pension_type
        CHECK (pension_type IN (
            'Service', 'Family', 'Disability', 'Gallantry'
        )),

    CONSTRAINT chk_payment_status
        CHECK (payment_status IN (
            'Active', 'Suspended', 'Terminated', 'Pending'
        )),

    CONSTRAINT chk_pension_amount
        CHECK (monthly_amount > 0),

    CONSTRAINT chk_da_percentage
        CHECK (da_percentage BETWEEN 0 AND 100),

    CONSTRAINT chk_pension_dates
        CHECK (pension_end_date IS NULL
            OR pension_end_date > pension_start_date),

    -- RBI mandated IFSC format: 4 letters + 0 + 6 alphanumeric
    CONSTRAINT chk_ifsc_format
        CHECK (bank_ifsc REGEXP '^[A-Z]{4}0[A-Z0-9]{6}$')
);

-- ============================================================
-- TABLE 4: NOMINEE
-- Purpose : Family members eligible for pension benefits
-- Depends on: VETERAN
-- ============================================================
CREATE TABLE NOMINEE (
    nominee_id          INT             NOT NULL AUTO_INCREMENT,
    veteran_id          INT             NOT NULL,
    nominee_name        VARCHAR(100)    NOT NULL,
    relationship        VARCHAR(20)     NOT NULL,
    date_of_birth       DATE            NOT NULL,
    share_percentage    DECIMAL(5, 2)   NOT NULL,
    is_active           CHAR(1)         NOT NULL DEFAULT 'Y',

    CONSTRAINT pk_nominee
        PRIMARY KEY (nominee_id),

    CONSTRAINT fk_nom_veteran
        FOREIGN KEY (veteran_id)
        REFERENCES VETERAN(veteran_id),

    CONSTRAINT chk_nominee_relationship
        CHECK (relationship IN (
            'Spouse', 'Child', 'Parent', 'Sibling'
        )),

    CONSTRAINT chk_share_percentage
        CHECK (share_percentage BETWEEN 1 AND 100),

    CONSTRAINT chk_nominee_active
        CHECK (is_active IN ('Y', 'N'))
);

-- ============================================================
-- TABLE 5: RANK_HISTORY
-- Purpose : Audit trail of rank promotions (trigger-populated)
-- Depends on: VETERAN
-- ============================================================
CREATE TABLE RANK_HISTORY (
    history_id      INT             NOT NULL AUTO_INCREMENT,
    veteran_id      INT             NOT NULL,
    old_rank        VARCHAR(30)     NOT NULL,
    new_rank        VARCHAR(30)     NOT NULL,
    changed_on      DATE            NOT NULL DEFAULT (CURRENT_DATE),
    changed_by      VARCHAR(30)     NOT NULL,

    CONSTRAINT pk_rank_history
        PRIMARY KEY (history_id),

    CONSTRAINT fk_rh_veteran
        FOREIGN KEY (veteran_id)
        REFERENCES VETERAN(veteran_id),

    CONSTRAINT chk_rh_ranks_differ
        CHECK (old_rank != new_rank),

    CONSTRAINT chk_rh_old_rank
        CHECK (old_rank IN (
            'Sepoy', 'Naik', 'Havildar',
            'Naib Subedar', 'Subedar', 'Subedar Major',
            'Lieutenant', 'Captain', 'Major',
            'Lt. Colonel', 'Colonel', 'Brigadier',
            'Major General', 'Lt. General', 'General'
        )),

    CONSTRAINT chk_rh_new_rank
        CHECK (new_rank IN (
            'Sepoy', 'Naik', 'Havildar',
            'Naib Subedar', 'Subedar', 'Subedar Major',
            'Lieutenant', 'Captain', 'Major',
            'Lt. Colonel', 'Colonel', 'Brigadier',
            'Major General', 'Lt. General', 'General'
        ))
);

-- ============================================================
-- TABLE 6: AUDIT_LOG
-- Purpose : System-wide change log for all sensitive tables
-- No FK — must survive even if referenced rows are deleted
-- ============================================================
CREATE TABLE AUDIT_LOG (
    log_id          INT             NOT NULL AUTO_INCREMENT,
    table_name      VARCHAR(30)     NOT NULL,
    operation       VARCHAR(10)     NOT NULL,
    record_id       INT             NOT NULL,
    changed_by      VARCHAR(30)     NOT NULL,
    changed_on DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    old_values      TEXT,
    new_values      TEXT,

    CONSTRAINT pk_audit_log
        PRIMARY KEY (log_id),

    CONSTRAINT chk_al_operation
        CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE'))
);

-- ============================================================
-- INDEXES — for fast retrieval, JOINs, and batch processing
-- ============================================================

-- Fast lookup by service number (supports KMP search complement)
CREATE UNIQUE INDEX idx_vet_svc_no
    ON VETERAN(service_number);

-- Filter veterans by status (batch pension processing)
CREATE INDEX idx_vet_status
    ON VETERAN(status);

-- JOIN veteran to regiment
CREATE INDEX idx_vet_regiment
    ON VETERAN(regiment_id);

-- Most common JOIN: pension → veteran
CREATE INDEX idx_pen_veteran
    ON PENSION_RECORD(veteran_id);

-- Batch processing filter: only Active pensions
CREATE INDEX idx_pen_status
    ON PENSION_RECORD(payment_status);

-- Nominee lookups by veteran
CREATE INDEX idx_nom_veteran
    ON NOMINEE(veteran_id);

-- Rank history audit queries
CREATE INDEX idx_rh_veteran
    ON RANK_HISTORY(veteran_id);

-- Security reports: audit log by table + date
CREATE INDEX idx_al_table_date
    ON AUDIT_LOG(table_name, changed_on);

-- ============================================================
-- VIEWS — pre-built queries for reports and PL/SQL procedures
-- ============================================================

-- V1: All active pensioners with DA-adjusted monthly total
CREATE OR REPLACE VIEW vw_active_pensioners AS
    SELECT
        v.veteran_id,
        v.service_number,
        v.full_name,
        v.rank_name,
        r.regiment_name,
        v.state_of_domicile,
        p.pension_type,
        p.monthly_amount,
        p.da_percentage,
        ROUND(p.monthly_amount * (1 + p.da_percentage / 100), 2) AS total_monthly,
        p.pension_start_date,
        p.payment_status
    FROM   VETERAN v
    JOIN   PENSION_RECORD p ON v.veteran_id = p.veteran_id
    JOIN   REGIMENT r       ON v.regiment_id = r.regiment_id
    WHERE  p.payment_status = 'Active';

-- V2: Service summary with computed years_of_service
CREATE OR REPLACE VIEW vw_service_summary AS
    SELECT
        v.veteran_id,
        v.service_number,
        v.full_name,
        v.rank_name,
        r.regiment_name,
        v.date_of_enlistment,
        v.date_of_retirement,
        FLOOR(
            DATEDIFF(
                COALESCE(v.date_of_retirement, CURDATE()),
                v.date_of_enlistment
            ) / 365
        )                   AS years_of_service,
        v.status
    FROM   VETERAN v
    JOIN   REGIMENT r ON v.regiment_id = r.regiment_id;

-- V3: Family pension due to nominees of deceased veterans (60% rule)
CREATE OR REPLACE VIEW vw_family_pension_due AS
    SELECT
        v.veteran_id,
        v.full_name             AS veteran_name,
        v.rank_name,
        n.nominee_id,
        n.nominee_name,
        n.relationship,
        n.share_percentage,
        p.monthly_amount        AS veteran_pension,
        ROUND(
            p.monthly_amount * 0.60 * n.share_percentage / 100,
        2)                      AS family_pension_due
    FROM   VETERAN v
    JOIN   NOMINEE n        ON v.veteran_id = n.veteran_id
    JOIN   PENSION_RECORD p ON v.veteran_id = p.veteran_id
    WHERE  v.status    = 'Deceased'
    AND    n.is_active = 'Y';

-- ============================================================
-- SUMMARY
-- Engine  : MySQL 8.0+
-- Tables  : REGIMENT, VETERAN, PENSION_RECORD, NOMINEE,
--           RANK_HISTORY, AUDIT_LOG
-- Views   : vw_active_pensioners, vw_service_summary,
--           vw_family_pension_due
-- Indexes : 8 performance indexes
-- Normal Form: 3NF / BCNF compliant
-- ============================================================


