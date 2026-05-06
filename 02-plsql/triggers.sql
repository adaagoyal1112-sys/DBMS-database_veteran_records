USE ivrpms;

-- ============================================================
-- IVRPMS — 02-plsql/triggers.sql
-- MySQL 8.0+ compatible
--
-- Contains 5 triggers:
--   T1. trg_rank_change_log            — logs every rank_name update
--   T2. trg_pension_audit_log          — logs pension amount changes
--   T3. trg_prevent_pension_delete     — blocks hard-delete of pensions
--   T4. trg_nominee_share_insert_check — enforces share% sum = 100 on INSERT
--   T5. trg_nominee_share_update_check — enforces share% sum = 100 on UPDATE
--
-- NOTE: Column is rank_name (not rank) because RANK is a
--       reserved keyword in MySQL 8.0+ (window function).
--       Using rank as a column name causes parser conflicts.
-- ============================================================


-- ============================================================
-- TRIGGER 1: trg_rank_change_log
--
-- WHAT IT DOES:
--   Fires AFTER any UPDATE on VETERAN. If rank_name changed
--   (e.g. Havildar → Naib Subedar), it automatically inserts
--   one row into RANK_HISTORY capturing the old rank_name,
--   new rank_name, date, and which DB user made the change.
--
-- WHY WE NEED IT:
--   Pension amounts depend on rank_name. Any rank_name change
--   must be permanently logged so disputes can be resolved
--   with a timestamped audit trail. Without this trigger,
--   rank_name changes leave no trace in the system.
--
-- KEY MYSQL CONCEPTS USED:
--   OLD.column — value of the column BEFORE the UPDATE
--   NEW.column — value of the column AFTER  the UPDATE
--   USER()     — built-in function: returns current DB username
--   IF...END IF — conditional block inside trigger body
--
-- FIRES: AFTER UPDATE on VETERAN
-- ============================================================

DROP TRIGGER IF EXISTS trg_rank_change_log;

DELIMITER $$

CREATE TRIGGER trg_rank_change_log
AFTER UPDATE ON VETERAN
FOR EACH ROW
BEGIN
    -- Only log if rank_name actually changed.
    -- Prevents junk rows when other columns (e.g. contact_number)
    -- are updated without any rank_name change.
    IF OLD.rank_name != NEW.rank_name THEN
        INSERT INTO RANK_HISTORY (
            veteran_id,
            old_rank,
            new_rank,
            changed_on,
            changed_by
        )
        VALUES (
            OLD.veteran_id,      -- which veteran was updated
            OLD.rank_name,       -- rank_name before the UPDATE
            NEW.rank_name,       -- rank_name after  the UPDATE
            CURRENT_DATE,        -- date of the change
            USER()               -- e.g. 'root@localhost'
        );
    END IF;
END$$

DELIMITER ;

-- ── Test T1 ──────────────────────────────────────────────────
-- UPDATE VETERAN SET rank_name = 'Naib Subedar'
--  WHERE veteran_id = 1001;
-- SELECT * FROM RANK_HISTORY WHERE veteran_id = 1001;
-- Expect: new row with old_rank='Subedar', new_rank='Naib Subedar'
-- -------------------------------------------------------------


-- ============================================================
-- TRIGGER 2: trg_pension_audit_log
--
-- WHAT IT DOES:
--   Fires AFTER any UPDATE on PENSION_RECORD. If monthly_amount
--   or payment_status changed, it writes a row into AUDIT_LOG
--   with a snapshot of the old and new values as readable text.
--
-- WHY WE NEED IT:
--   Pension amounts are financial records — any change must be
--   permanently logged with a timestamp and user for government
--   audit compliance. Supports Pillar 6 (Security & Audit).
--
-- KEY MYSQL CONCEPTS USED:
--   CONCAT_WS(sep, v1, v2) — joins values with a separator
--   NOW()                  — returns current datetime
--   CONCAT('key=', value)  — builds readable key=value string
--
-- FIRES: AFTER UPDATE on PENSION_RECORD
-- ============================================================

DROP TRIGGER IF EXISTS trg_pension_audit_log;

DELIMITER $$

CREATE TRIGGER trg_pension_audit_log
AFTER UPDATE ON PENSION_RECORD
FOR EACH ROW
BEGIN
    -- Only log if a financially significant column changed
    IF OLD.monthly_amount != NEW.monthly_amount
    OR OLD.payment_status != NEW.payment_status THEN

        INSERT INTO AUDIT_LOG (
            table_name,
            operation,
            record_id,
            changed_by,
            changed_on,
            old_values,
            new_values
        )
        VALUES (
            'PENSION_RECORD',
            'UPDATE',
            OLD.pension_id,
            USER(),
            NOW(),
            -- Snapshot BEFORE the change
            CONCAT_WS(' | ',
                CONCAT('amount=',  OLD.monthly_amount),
                CONCAT('status=',  OLD.payment_status),
                CONCAT('da_pct=',  OLD.da_percentage)
            ),
            -- Snapshot AFTER the change
            CONCAT_WS(' | ',
                CONCAT('amount=',  NEW.monthly_amount),
                CONCAT('status=',  NEW.payment_status),
                CONCAT('da_pct=',  NEW.da_percentage)
            )
        );
    END IF;
END$$

DELIMITER ;

-- ── Test T2 ──────────────────────────────────────────────────
-- UPDATE PENSION_RECORD SET monthly_amount = 21000.00
--  WHERE pension_id = 5001;
-- SELECT * FROM AUDIT_LOG WHERE table_name = 'PENSION_RECORD';
-- Expect: old_values='amount=19550.00 | status=Active | da_pct=46.00'
-- -------------------------------------------------------------


-- ============================================================
-- TRIGGER 3: trg_prevent_pension_delete
--
-- WHAT IT DOES:
--   Fires BEFORE any DELETE on PENSION_RECORD and immediately
--   raises a custom error, aborting the DELETE entirely.
--   Forces admins to use a soft-delete instead:
--     SET payment_status = 'Terminated', pension_end_date = today
--
-- WHY WE NEED IT:
--   Pension records are legal financial documents. Hard-deleting
--   them destroys the audit trail. SIGNAL SQLSTATE '45000' is
--   MySQL's mechanism for throwing user-defined errors from
--   inside trigger/procedure bodies.
--
-- KEY MYSQL CONCEPTS USED:
--   SIGNAL SQLSTATE '45000' — raises a user-defined exception
--   SET MESSAGE_TEXT        — sets the error message shown to user
--
-- FIRES: BEFORE DELETE on PENSION_RECORD
-- ============================================================

DROP TRIGGER IF EXISTS trg_prevent_pension_delete;

DELIMITER $$

CREATE TRIGGER trg_prevent_pension_delete
BEFORE DELETE ON PENSION_RECORD
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT =
        'IVRPMS: Direct deletion of pension records is not allowed. '
        'Use: SET payment_status = Terminated, pension_end_date = CURDATE()';
END$$

DELIMITER ;

-- ── Test T3 ──────────────────────────────────────────────────
-- DELETE FROM PENSION_RECORD WHERE pension_id = 5001;
-- Expect: ERROR 1644 — IVRPMS: Direct deletion of pension records...
--
-- Correct soft-delete approach:
-- UPDATE PENSION_RECORD
--    SET payment_status   = 'Terminated',
--        pension_end_date = CURDATE()
--  WHERE pension_id = 5001;
-- -------------------------------------------------------------


-- ============================================================
-- TRIGGER 4 & 5: trg_nominee_share_insert_check
--                trg_nominee_share_update_check
--
-- WHAT THEY DO:
--   Before any INSERT or UPDATE on NOMINEE, they check whether
--   the total share_percentage for all active nominees of that
--   veteran would exceed 100. If yes, the operation is blocked.
--
-- WHY WE NEED THEM:
--   A column-level CHECK constraint can only validate one row
--   at a time (share between 1 and 100). It cannot check the
--   SUM across multiple rows for the same veteran. A trigger
--   is the correct tool for this cross-row business rule.
--
-- EXAMPLE:
--   Veteran 1001 has nominee A (60%) and nominee B (40%) = 100%.
--   Attempting to add nominee C (20%) would make total = 120%.
--   The trigger blocks this and shows a clear error message.
--
-- KEY MYSQL CONCEPTS USED:
--   DECLARE var TYPE      — declares a local variable
--   SELECT ... INTO var   — stores query result in variable
--   COALESCE(val, 0)      — returns 0 if SUM is NULL (no rows yet)
--
-- FIRES: BEFORE INSERT on NOMINEE (T4)
--        BEFORE UPDATE on NOMINEE (T5)
-- ============================================================

DROP TRIGGER IF EXISTS trg_nominee_share_insert_check;
DROP TRIGGER IF EXISTS trg_nominee_share_update_check;

DELIMITER $$

-- T4: INSERT check
CREATE TRIGGER trg_nominee_share_insert_check
BEFORE INSERT ON NOMINEE
FOR EACH ROW
BEGIN
    DECLARE current_total DECIMAL(6,2);

    -- Sum all existing active nominees for this veteran
    SELECT COALESCE(SUM(share_percentage), 0)
      INTO current_total
      FROM NOMINEE
     WHERE veteran_id = NEW.veteran_id
       AND is_active  = 'Y';

    -- Block if adding this share would push total over 100
    IF (current_total + NEW.share_percentage) > 100 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'IVRPMS: Total share_percentage for this veteran\'s '
            'nominees would exceed 100. Adjust existing shares first.';
    END IF;
END$$

-- T5: UPDATE check (excludes the row being updated from the sum)
CREATE TRIGGER trg_nominee_share_update_check
BEFORE UPDATE ON NOMINEE
FOR EACH ROW
BEGIN
    DECLARE current_total DECIMAL(6,2);

    -- Sum all OTHER active nominees (exclude the row being changed)
    SELECT COALESCE(SUM(share_percentage), 0)
      INTO current_total
      FROM NOMINEE
     WHERE veteran_id  = NEW.veteran_id
       AND nominee_id != OLD.nominee_id
       AND is_active   = 'Y';

    IF (current_total + NEW.share_percentage) > 100 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'IVRPMS: Total share_percentage for this veteran\'s '
            'nominees would exceed 100. Adjust other shares first.';
    END IF;
END$$

DELIMITER ;

-- ── Test T4 ──────────────────────────────────────────────────
-- Veteran 1002 already has 100% assigned to one nominee.
-- INSERT INTO NOMINEE
--   (veteran_id, nominee_name, relationship,
--    date_of_birth, share_percentage, is_active)
-- VALUES (1002, 'Test Person', 'Child', '1995-01-01', 20.00, 'Y');
-- Expect: ERROR 1644 — Total share_percentage would exceed 100
-- -------------------------------------------------------------


-- ============================================================
-- VERIFY ALL 5 TRIGGERS ARE ACTIVE
-- Run after executing this file:
--   SHOW TRIGGERS FROM college;
-- Expected: 5 rows listed
-- ============================================================
