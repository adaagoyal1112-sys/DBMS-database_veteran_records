USE ivrpms;

-- ============================================================
-- IVRPMS — 02-plsql/stored_procedures.sql
-- MySQL 8.0+ compatible
--
-- Contains 5 procedures / functions:
--   F1. fn_years_of_service       — calculates years served
--   F2. fn_calculate_annual_benefit — calculates yearly pension
--   P1. sp_get_pension_summary    — full pension report per veteran
--   P2. sp_monthly_batch_report   — batch report for all active pensions
--   P3. sp_update_da_percentage   — updates DA rate for all active pensions
--
-- DIFFERENCE: FUNCTION vs PROCEDURE
--   FUNCTION   — returns a single value, used inside SELECT queries
--   PROCEDURE  — executes a block of logic, called with CALL statement
-- ============================================================


-- ============================================================
-- FUNCTION 1: fn_years_of_service
--
-- WHAT IT DOES:
--   Takes a veteran_id, looks up their enlistment and retirement
--   dates, and returns the number of complete years they served.
--   If still Active (no retirement date), calculates up to today.
--
-- WHY WE NEED IT:
--   Years of service is used in pension calculation, reports,
--   and eligibility checks. Writing this logic once in a function
--   means every procedure and query can reuse it — no duplication.
--
-- RETURNS: INT (number of complete years served)
--
-- HOW TO CALL:
--   SELECT fn_years_of_service(1001);
--   SELECT full_name, fn_years_of_service(veteran_id) AS years
--     FROM VETERAN;
-- ============================================================

DROP FUNCTION IF EXISTS fn_years_of_service;

DELIMITER $$

CREATE FUNCTION fn_years_of_service(p_veteran_id INT)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_enlist    DATE;
    DECLARE v_retire    DATE;
    DECLARE v_years     INT;

    -- Fetch the veteran's service dates
    SELECT date_of_enlistment, date_of_retirement
      INTO v_enlist, v_retire
      FROM VETERAN
     WHERE veteran_id = p_veteran_id;

    -- If still active (no retirement date), use today
    IF v_retire IS NULL THEN
        SET v_retire = CURDATE();
    END IF;

    -- DATEDIFF gives days; divide by 365 and floor for full years
    SET v_years = FLOOR(DATEDIFF(v_retire, v_enlist) / 365);

    RETURN v_years;
END$$

DELIMITER ;

-- ── Test F1 ──────────────────────────────────────────────────
-- SELECT fn_years_of_service(1001);
-- Expect: 30  (enlisted 1975, retired 2005)
--
-- SELECT veteran_id, full_name, fn_years_of_service(veteran_id)
--        AS years_served
--   FROM VETERAN LIMIT 5;
-- -------------------------------------------------------------


-- ============================================================
-- FUNCTION 2: fn_calculate_annual_benefit
--
-- WHAT IT DOES:
--   Given a veteran_id, calculates their total annual pension
--   payout including the current Dearness Allowance (DA).
--   Formula: monthly_amount × (1 + da_percentage/100) × 12
--
-- WHY WE NEED IT:
--   Financial reports need annual figures, not just monthly.
--   The DA adjustment is mandated by Government of India and
--   changes biannually — storing just the base amount and
--   computing DA at query time means the system always reflects
--   the current rate without touching every row.
--
-- RETURNS: DECIMAL(12,2) — annual pension in rupees
--
-- HOW TO CALL:
--   SELECT fn_calculate_annual_benefit(1001);
--   SELECT full_name, fn_calculate_annual_benefit(veteran_id)
--          AS annual_benefit FROM VETERAN WHERE status = 'Retired';
-- ============================================================

DROP FUNCTION IF EXISTS fn_calculate_annual_benefit;

DELIMITER $$

CREATE FUNCTION fn_calculate_annual_benefit(p_veteran_id INT)
RETURNS DECIMAL(12,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_monthly   DECIMAL(10,2);
    DECLARE v_da_pct    DECIMAL(5,2);
    DECLARE v_annual    DECIMAL(12,2);

    -- Fetch the active pension record for this veteran
    SELECT monthly_amount, da_percentage
      INTO v_monthly, v_da_pct
      FROM PENSION_RECORD
     WHERE veteran_id     = p_veteran_id
       AND payment_status = 'Active'
     LIMIT 1;

    -- If no active pension found, return 0
    IF v_monthly IS NULL THEN
        RETURN 0.00;
    END IF;

    -- Annual = monthly × DA-adjusted rate × 12 months
    SET v_annual = v_monthly * (1 + v_da_pct / 100) * 12;

    RETURN ROUND(v_annual, 2);
END$$

DELIMITER ;

-- ── Test F2 ──────────────────────────────────────────────────
-- SELECT fn_calculate_annual_benefit(1001);
-- Expect: 19550 × 1.46 × 12 = 342,396.00
--
-- SELECT full_name, fn_calculate_annual_benefit(veteran_id)
--        AS annual_pension_INR
--   FROM VETERAN
--  WHERE status = 'Retired'
--  ORDER BY annual_pension_INR DESC;
-- -------------------------------------------------------------


-- ============================================================
-- PROCEDURE 1: sp_get_pension_summary
--
-- WHAT IT DOES:
--   Generates a complete pension report for a single veteran.
--   Displays personal details, service record, pension amounts,
--   DA-adjusted totals, and nominee information in one call.
--   Uses both functions defined above internally.
--
-- WHY WE NEED IT:
--   A clerk handling a pension query should get all relevant
--   information in one call — not run 4 separate JOIN queries.
--   Stored procedures encapsulate complex logic and expose
--   a simple interface: just pass the veteran_id.
--
-- HOW TO CALL:
--   CALL sp_get_pension_summary(1001);
--   CALL sp_get_pension_summary(1003);
-- ============================================================

DROP PROCEDURE IF EXISTS sp_get_pension_summary;

DELIMITER $$

CREATE PROCEDURE sp_get_pension_summary(IN p_veteran_id INT)
BEGIN
    -- ── Section 1: Veteran + service details ─────────────────
    SELECT
        v.veteran_id,
        v.service_number,
        v.full_name,
        v.rank_name,
        r.regiment_name,
        v.status,
        v.state_of_domicile,
        v.date_of_enlistment,
        v.date_of_retirement,
        fn_years_of_service(v.veteran_id)      AS years_of_service
    FROM   VETERAN v
    JOIN   REGIMENT r ON v.regiment_id = r.regiment_id
    WHERE  v.veteran_id = p_veteran_id;

    -- ── Section 2: Pension financial details ─────────────────
    SELECT
        p.pension_type,
        p.monthly_amount                        AS base_monthly,
        p.da_percentage,
        ROUND(p.monthly_amount *
              (1 + p.da_percentage / 100), 2)   AS da_adjusted_monthly,
        fn_calculate_annual_benefit(p.veteran_id) AS annual_total,
        p.pension_start_date,
        p.pension_end_date,
        p.payment_status,
        p.bank_ifsc
    FROM   PENSION_RECORD p
    WHERE  p.veteran_id = p_veteran_id;

    -- ── Section 3: Nominee details ────────────────────────────
    SELECT
        n.nominee_name,
        n.relationship,
        n.date_of_birth,
        n.share_percentage,
        ROUND(
            (SELECT monthly_amount FROM PENSION_RECORD
              WHERE veteran_id = p_veteran_id LIMIT 1)
            * 0.60                              -- 60% family pension rule
            * n.share_percentage / 100, 2
        )                                       AS family_pension_if_applicable,
        n.is_active
    FROM   NOMINEE n
    WHERE  n.veteran_id = p_veteran_id;
END$$

DELIMITER ;

-- ── Test P1 ──────────────────────────────────────────────────
-- CALL sp_get_pension_summary(1001);
-- Expect: 3 result sets —
--   1st: Rajinder Singh, Subedar, Punjab Regiment, 30 years
--   2nd: Service pension 19550, DA 46%, annual 342396
--   3rd: Gurpreet Kaur (Spouse 60%), Manpreet Singh (Child 40%)
-- -------------------------------------------------------------


-- ============================================================
-- PROCEDURE 2: sp_monthly_batch_report
--
-- WHAT IT DOES:
--   Processes ALL active pension records at once using a CURSOR.
--   A cursor loops row-by-row through a result set — this is
--   how you handle batch processing of thousands of records
--   in SQL, equivalent to a for-loop in programming.
--
--   For each active pensioner it prints:
--     - veteran name, rank_name, pension amount, DA-adjusted total
--   At the end it prints a grand total of all disbursements.
--
-- WHY WE NEED IT:
--   Every month the pension office must process payments for
--   all active veterans. This procedure simulates that batch
--   run and demonstrates CURSOR usage — a core PL/SQL concept
--   required by your project guidelines.
--
-- KEY MYSQL CONCEPTS USED:
--   CURSOR          — pointer that iterates over a SELECT result
--   FETCH           — moves cursor to next row, loads into variables
--   HANDLER         — catches the "no more rows" signal to stop loop
--   NOT FOUND       — MySQL condition raised when cursor is exhausted
--
-- HOW TO CALL:
--   CALL sp_monthly_batch_report();
-- ============================================================

DROP PROCEDURE IF EXISTS sp_monthly_batch_report;

DELIMITER $$

CREATE PROCEDURE sp_monthly_batch_report()
BEGIN
    -- ── Declare variables to hold each row from the cursor ────
    DECLARE v_veteran_id    INT;
    DECLARE v_full_name     VARCHAR(100);
    DECLARE v_rank_name     VARCHAR(30);
    DECLARE v_monthly       DECIMAL(10,2);
    DECLARE v_da_pct        DECIMAL(5,2);
    DECLARE v_adjusted      DECIMAL(10,2);
    DECLARE v_grand_total   DECIMAL(15,2) DEFAULT 0.00;
    DECLARE v_count         INT DEFAULT 0;
    DECLARE v_done          BOOLEAN DEFAULT FALSE;

    -- ── Declare the cursor ────────────────────────────────────
    -- This SELECT defines which rows the cursor will iterate over
    DECLARE pension_cursor CURSOR FOR
        SELECT
            v.veteran_id,
            v.full_name,
            v.rank_name,
            p.monthly_amount,
            p.da_percentage
        FROM   VETERAN v
        JOIN   PENSION_RECORD p ON v.veteran_id = p.veteran_id
        WHERE  p.payment_status = 'Active'
        ORDER  BY v.veteran_id;

    -- ── Handler: fires when cursor runs out of rows ───────────
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

    -- ── Print report header ───────────────────────────────────
    SELECT '=======================================' AS monthly_batch_report;
    SELECT CONCAT('Run Date: ', CURDATE())           AS report_date;
    SELECT '=======================================' AS divider;

    -- ── Open cursor and begin loop ────────────────────────────
    OPEN pension_cursor;

    batch_loop: LOOP
        -- Fetch one row into the declared variables
        FETCH pension_cursor
          INTO v_veteran_id, v_full_name, v_rank_name,
               v_monthly, v_da_pct;

        -- If no more rows, exit the loop
        IF v_done THEN
            LEAVE batch_loop;
        END IF;

        -- Calculate DA-adjusted amount for this veteran
        SET v_adjusted = ROUND(v_monthly * (1 + v_da_pct / 100), 2);

        -- Add to running grand total
        SET v_grand_total = v_grand_total + v_adjusted;
        SET v_count       = v_count + 1;

        -- Output this veteran's disbursement line
        SELECT
            v_veteran_id                AS veteran_id,
            v_full_name                 AS name,
            v_rank_name                 AS rank_name,
            v_monthly                   AS base_pension,
            v_da_pct                    AS da_pct,
            v_adjusted                  AS total_disbursement;

    END LOOP batch_loop;

    -- ── Close cursor ──────────────────────────────────────────
    CLOSE pension_cursor;

    -- ── Print summary footer ──────────────────────────────────
    SELECT '=======================================' AS divider;
    SELECT
        v_count         AS total_veterans_processed,
        v_grand_total   AS total_monthly_disbursement_INR;
END$$

DELIMITER ;

-- ── Test P2 ──────────────────────────────────────────────────
-- CALL sp_monthly_batch_report();
-- Expect: one SELECT result per active veteran (38 rows)
-- Final result: total_veterans_processed=38,
--               total_monthly_disbursement_INR = sum of all
-- -------------------------------------------------------------


-- ============================================================
-- PROCEDURE 3: sp_update_da_percentage
--
-- WHAT IT DOES:
--   The Government of India revises the Dearness Allowance (DA)
--   rate twice a year (Jan and Jul). This procedure updates
--   da_percentage for ALL active pension records in one call,
--   and logs every change to AUDIT_LOG automatically
--   (the trg_pension_audit_log trigger fires for each UPDATE).
--
-- WHY WE NEED IT:
--   Without this, an admin would have to update 10,000 rows
--   manually every 6 months. One procedure call handles all
--   records and the trigger handles all audit logging.
--   This demonstrates how triggers + procedures work together.
--
-- PARAMETERS:
--   p_new_da_rate DECIMAL(5,2) — new DA percentage (e.g. 50.00)
--
-- HOW TO CALL:
--   CALL sp_update_da_percentage(50.00);
-- ============================================================

DROP PROCEDURE IF EXISTS sp_update_da_percentage;

DELIMITER $$

CREATE PROCEDURE sp_update_da_percentage(IN p_new_da_rate DECIMAL(5,2))
BEGIN
    DECLARE v_rows_updated INT;

    -- Validate: DA must be between 0 and 100
    IF p_new_da_rate < 0 OR p_new_da_rate > 100 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'IVRPMS: DA percentage must be between 0 and 100.';
    END IF;

    -- Update all active pension records with the new DA rate
    -- NOTE: trg_pension_audit_log fires for each row updated here
    UPDATE PENSION_RECORD
       SET da_percentage = p_new_da_rate
     WHERE payment_status = 'Active';

    -- Capture how many rows were changed
    SET v_rows_updated = ROW_COUNT();

    -- Confirm the update
    SELECT
        v_rows_updated      AS records_updated,
        p_new_da_rate       AS new_da_percentage,
        NOW()               AS updated_at;
END$$

DELIMITER ;

-- ── Test P3 ──────────────────────────────────────────────────
-- CALL sp_update_da_percentage(50.00);
-- Expect: records_updated=38, new_da_percentage=50.00
--
-- Check audit trail (trigger fired for each row):
-- SELECT COUNT(*) FROM AUDIT_LOG
--  WHERE table_name = 'PENSION_RECORD';
-- Expect: 38 new rows in AUDIT_LOG
-- -------------------------------------------------------------


-- ============================================================
-- VERIFY ALL OBJECTS CREATED SUCCESSFULLY
-- ============================================================
-- SHOW FUNCTION STATUS  WHERE Db = 'college';
-- SHOW PROCEDURE STATUS WHERE Db = 'college';
--
-- Expected functions  : fn_years_of_service
--                       fn_calculate_annual_benefit
-- Expected procedures : sp_get_pension_summary
--                       sp_monthly_batch_report
--                       sp_update_da_percentage
-- ============================================================
