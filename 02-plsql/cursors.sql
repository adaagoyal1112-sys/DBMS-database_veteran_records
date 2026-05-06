-- ============================================================
-- File   : 02-plsql/cursors.sql
-- Purpose: Monthly batch processor for Active pension disbursement.
--
-- Demonstrates the four core PL/SQL cursor concepts on MySQL:
--   1. DECLARE cursor over a SELECT
--   2. OPEN / FETCH / CLOSE lifecycle
--   3. NOT FOUND handler to terminate the loop
--   4. Per-row work (compute DA-adjusted total + AUDIT_LOG insert)
--
-- The procedure walks every Active pension, computes the
-- DA-adjusted monthly disbursement (monthly_amount * (1 + DA/100)),
-- accumulates a grand total, and writes a single AUDIT_LOG row
-- per pension recording the disbursement event.
--
-- USAGE:
--   CALL process_monthly_disbursement();
--   SELECT * FROM AUDIT_LOG WHERE operation='INSERT' AND
--          table_name='PENSION_RECORD' ORDER BY changed_on DESC;
-- ============================================================

DROP PROCEDURE IF EXISTS process_monthly_disbursement;

DELIMITER $$

CREATE PROCEDURE process_monthly_disbursement()
BEGIN
    -- ── Loop control ────────────────────────────────────────
    DECLARE done             INT DEFAULT 0;

    -- ── Per-row variables (must match cursor SELECT order) ──
    DECLARE v_pension_id     INT;
    DECLARE v_veteran_id     INT;
    DECLARE v_monthly_amount DECIMAL(10,2);
    DECLARE v_da_percentage  DECIMAL(5,2);
    DECLARE v_disbursement   DECIMAL(12,2);

    -- ── Aggregates ──────────────────────────────────────────
    DECLARE v_total_paid     DECIMAL(14,2) DEFAULT 0.00;
    DECLARE v_records_done   INT           DEFAULT 0;

    -- ── 1. DECLARE the cursor ───────────────────────────────
    DECLARE cur_active_pensions CURSOR FOR
        SELECT pension_id, veteran_id, monthly_amount, da_percentage
        FROM   PENSION_RECORD
        WHERE  payment_status = 'Active'
        ORDER  BY pension_id;

    -- ── 2. NOT FOUND handler ────────────────────────────────
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    -- ── 3. OPEN the cursor ──────────────────────────────────
    OPEN cur_active_pensions;

    -- ── 4. FETCH loop ───────────────────────────────────────
    disbursement_loop: LOOP
        FETCH cur_active_pensions
            INTO v_pension_id, v_veteran_id,
                 v_monthly_amount, v_da_percentage;

        IF done = 1 THEN
            LEAVE disbursement_loop;
        END IF;

        -- DA-adjusted disbursement for this pension
        SET v_disbursement = ROUND(
            v_monthly_amount * (1 + v_da_percentage / 100), 2
        );

        -- Audit-log this disbursement event
        INSERT INTO AUDIT_LOG
            (table_name, operation, record_id,
             changed_by, new_values)
        VALUES (
            'PENSION_RECORD',
            'INSERT',
            v_pension_id,
            CURRENT_USER(),
            CONCAT('Monthly disbursement: veteran_id=', v_veteran_id,
                   ' amount=', v_disbursement)
        );

        -- Running totals
        SET v_total_paid   = v_total_paid + v_disbursement;
        SET v_records_done = v_records_done + 1;
    END LOOP disbursement_loop;

    -- ── 5. CLOSE the cursor ─────────────────────────────────
    CLOSE cur_active_pensions;

    -- ── Summary row to caller ───────────────────────────────
    SELECT
        v_records_done   AS pensions_processed,
        v_total_paid     AS total_disbursed,
        CURRENT_TIMESTAMP AS run_at;
END$$

DELIMITER ;

-- ============================================================
-- SECONDARY CURSOR PROCEDURE
-- Lists at-risk veterans: Active veterans nearing retirement
-- (within 90 days of date_of_retirement) without a pension
-- record set up. Demonstrates a cursor with a WHERE/JOIN filter.
-- ============================================================

DROP PROCEDURE IF EXISTS list_pension_setup_pending;

DELIMITER $$

CREATE PROCEDURE list_pension_setup_pending()
BEGIN
    DECLARE done             INT DEFAULT 0;
    DECLARE v_veteran_id     INT;
    DECLARE v_full_name      VARCHAR(100);
    DECLARE v_retire_date    DATE;
    DECLARE v_count          INT DEFAULT 0;

    DECLARE cur_pending CURSOR FOR
        SELECT v.veteran_id, v.full_name, v.date_of_retirement
        FROM   VETERAN v
        LEFT   JOIN PENSION_RECORD p
               ON p.veteran_id = v.veteran_id
        WHERE  v.status = 'Active'
          AND  v.date_of_retirement IS NOT NULL
          AND  v.date_of_retirement <= DATE_ADD(CURDATE(), INTERVAL 90 DAY)
          AND  p.pension_id IS NULL
        ORDER  BY v.date_of_retirement ASC;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    -- Stage results in a temp table so the caller sees a normal result set
    DROP TEMPORARY TABLE IF EXISTS tmp_pending;
    CREATE TEMPORARY TABLE tmp_pending (
        veteran_id    INT,
        full_name     VARCHAR(100),
        retire_date   DATE,
        days_to_retire INT
    );

    OPEN cur_pending;
    pending_loop: LOOP
        FETCH cur_pending INTO v_veteran_id, v_full_name, v_retire_date;
        IF done = 1 THEN
            LEAVE pending_loop;
        END IF;

        INSERT INTO tmp_pending VALUES (
            v_veteran_id,
            v_full_name,
            v_retire_date,
            DATEDIFF(v_retire_date, CURDATE())
        );
        SET v_count = v_count + 1;
    END LOOP pending_loop;
    CLOSE cur_pending;

    SELECT * FROM tmp_pending ORDER BY days_to_retire ASC;
    SELECT v_count AS pending_setup_count;
END$$

DELIMITER ;
