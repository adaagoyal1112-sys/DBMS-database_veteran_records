USE ivrpms;

-- ============================================================
-- IVRPMS — 02-plsql/queries.sql
-- MySQL 8.0+ compatible
--
-- 15 queries demonstrating:
--   Q1  - Q3  : Basic SELECT with WHERE and ORDER BY
--   Q4  - Q6  : JOINS (INNER, LEFT, multi-table)
--   Q7  - Q9  : Aggregate functions + GROUP BY + HAVING
--   Q10 - Q12 : Subqueries (scalar, correlated, IN clause)
--   Q13 - Q14 : Views usage + window functions
--   Q15        : Full business report query
-- ============================================================


-- ============================================================
-- Q1: List all retired veterans sorted by years of service
--
-- CONCEPTS: SELECT, WHERE, ORDER BY, function call
-- BUSINESS USE: Generate seniority list for pension review
-- ============================================================

SELECT
    v.veteran_id,
    v.service_number,
    v.full_name,
    v.rank_name,
    v.state_of_domicile,
    fn_years_of_service(v.veteran_id)      AS years_of_service,
    v.date_of_retirement
FROM   VETERAN v
WHERE  v.status = 'Retired'
ORDER  BY fn_years_of_service(v.veteran_id) DESC;


-- ============================================================
-- Q2: Find all deceased veterans whose family pension is active
--
-- CONCEPTS: WHERE with multiple conditions, IS NULL check
-- BUSINESS USE: Identify families currently receiving pension
-- ============================================================

SELECT
    v.veteran_id,
    v.full_name                             AS deceased_veteran,
    v.rank_name,
    p.monthly_amount                        AS original_pension,
    ROUND(p.monthly_amount * 0.60, 2)       AS family_pension_60_pct,
    p.payment_status
FROM   VETERAN v
JOIN   PENSION_RECORD p ON v.veteran_id = p.veteran_id
WHERE  v.status         = 'Deceased'
AND    p.payment_status = 'Terminated'
ORDER  BY v.full_name;


-- ============================================================
-- Q3: Search veterans by service number pattern (KMP concept)
--
-- CONCEPTS: LIKE pattern matching, string search
-- BUSINESS USE: Simulates the KMP string search from Pillar 4
--               LIKE 'IC-%' finds all officer-rank veterans
-- ============================================================

SELECT
    veteran_id,
    service_number,
    full_name,
    rank_name,
    status
FROM   VETERAN
WHERE  service_number LIKE 'IC-%'
ORDER  BY service_number;


-- ============================================================
-- Q4: INNER JOIN — veteran with their regiment details
--
-- CONCEPTS: INNER JOIN (only rows matching on both sides)
-- BUSINESS USE: Full profile view combining personal + unit data
-- ============================================================

SELECT
    v.veteran_id,
    v.full_name,
    v.rank_name,
    v.status,
    r.regiment_name,
    r.base_location,
    r.arm_of_service
FROM   VETERAN v
INNER JOIN REGIMENT r ON v.regiment_id = r.regiment_id
ORDER  BY r.regiment_name, v.full_name;


-- ============================================================
-- Q5: LEFT JOIN — all veterans including those with no pension
--
-- CONCEPTS: LEFT JOIN (keeps all rows from left table even if
--           no match exists in right table — NULL shown instead)
-- BUSINESS USE: Audit to find veterans missing pension records
-- ============================================================

SELECT
    v.veteran_id,
    v.full_name,
    v.rank_name,
    v.status,
    p.pension_id,
    p.monthly_amount,
    p.payment_status,
    CASE
        WHEN p.pension_id IS NULL THEN 'NO PENSION RECORD — ACTION REQUIRED'
        ELSE 'Pension on file'
    END                                     AS pension_flag
FROM   VETERAN v
LEFT JOIN PENSION_RECORD p ON v.veteran_id = p.veteran_id
ORDER  BY pension_flag DESC, v.full_name;


-- ============================================================
-- Q6: Multi-table JOIN — full disbursement report
--
-- CONCEPTS: 3-table JOIN (VETERAN + PENSION_RECORD + REGIMENT)
-- BUSINESS USE: Complete monthly payout list with unit details
-- ============================================================

SELECT
    v.veteran_id,
    v.service_number,
    v.full_name,
    v.rank_name,
    r.regiment_name,
    r.arm_of_service,
    p.pension_type,
    p.monthly_amount,
    p.da_percentage,
    ROUND(p.monthly_amount * (1 + p.da_percentage / 100), 2)
                                            AS da_adjusted_monthly,
    fn_calculate_annual_benefit(v.veteran_id)
                                            AS annual_benefit,
    p.bank_ifsc,
    p.payment_status
FROM   VETERAN v
JOIN   PENSION_RECORD p ON v.veteran_id  = p.veteran_id
JOIN   REGIMENT r       ON v.regiment_id = r.regiment_id
WHERE  p.payment_status = 'Active'
ORDER  BY da_adjusted_monthly DESC;


-- ============================================================
-- Q7: GROUP BY — total pension outflow per regiment
--
-- CONCEPTS: GROUP BY, SUM, COUNT, aggregate functions
-- BUSINESS USE: Budget allocation report by regiment
-- ============================================================

SELECT
    r.regiment_name,
    r.arm_of_service,
    COUNT(v.veteran_id)                     AS total_veterans,
    COUNT(p.pension_id)                     AS pensioners,
    ROUND(SUM(p.monthly_amount), 2)         AS total_base_monthly,
    ROUND(SUM(
        p.monthly_amount * (1 + p.da_percentage / 100)
    ), 2)                                   AS total_da_adjusted_monthly,
    ROUND(AVG(p.monthly_amount), 2)         AS avg_pension
FROM   REGIMENT r
LEFT JOIN VETERAN v       ON r.regiment_id = v.regiment_id
LEFT JOIN PENSION_RECORD p ON v.veteran_id = p.veteran_id
                           AND p.payment_status = 'Active'
GROUP  BY r.regiment_id, r.regiment_name, r.arm_of_service
ORDER  BY total_da_adjusted_monthly DESC;


-- ============================================================
-- Q8: GROUP BY with HAVING — states with more than 2 veterans
--
-- CONCEPTS: GROUP BY + HAVING (filter on aggregated results)
--           HAVING filters AFTER grouping (WHERE filters before)
-- BUSINESS USE: Identify high-density states for regional offices
-- ============================================================

SELECT
    v.state_of_domicile,
    COUNT(v.veteran_id)                     AS total_veterans,
    SUM(CASE WHEN v.status = 'Retired'  THEN 1 ELSE 0 END)
                                            AS retired_count,
    SUM(CASE WHEN v.status = 'Deceased' THEN 1 ELSE 0 END)
                                            AS deceased_count,
    ROUND(SUM(p.monthly_amount), 2)         AS state_pension_outflow
FROM   VETERAN v
LEFT JOIN PENSION_RECORD p ON v.veteran_id  = p.veteran_id
                           AND p.payment_status = 'Active'
GROUP  BY v.state_of_domicile
HAVING COUNT(v.veteran_id) > 2
ORDER  BY total_veterans DESC;


-- ============================================================
-- Q9: GROUP BY rank_name — pension statistics per rank tier
--
-- CONCEPTS: GROUP BY on non-ID column, MIN, MAX, AVG
-- BUSINESS USE: Pay commission analysis — pension spread by rank
-- ============================================================

SELECT
    v.rank_name,
    COUNT(v.veteran_id)                     AS veteran_count,
    ROUND(MIN(p.monthly_amount), 2)         AS min_pension,
    ROUND(MAX(p.monthly_amount), 2)         AS max_pension,
    ROUND(AVG(p.monthly_amount), 2)         AS avg_pension,
    ROUND(SUM(
        p.monthly_amount * (1 + p.da_percentage / 100)
    ), 2)                                   AS total_monthly_outflow
FROM   VETERAN v
JOIN   PENSION_RECORD p ON v.veteran_id = p.veteran_id
WHERE  p.payment_status = 'Active'
GROUP  BY v.rank_name
ORDER  BY avg_pension DESC;


-- ============================================================
-- Q10: Scalar subquery — veterans earning above average pension
--
-- CONCEPTS: Subquery in WHERE clause (scalar — returns one value)
-- BUSINESS USE: Flag high-value pension cases for senior review
-- ============================================================

SELECT
    v.full_name,
    v.rank_name,
    p.monthly_amount,
    ROUND(p.monthly_amount * (1 + p.da_percentage / 100), 2)
                                            AS da_adjusted,
    ROUND(
        p.monthly_amount -
        (SELECT AVG(monthly_amount) FROM PENSION_RECORD
          WHERE payment_status = 'Active'),
    2)                                      AS above_average_by
FROM   VETERAN v
JOIN   PENSION_RECORD p ON v.veteran_id = p.veteran_id
WHERE  p.payment_status = 'Active'
AND    p.monthly_amount > (
           SELECT AVG(monthly_amount)
             FROM PENSION_RECORD
            WHERE payment_status = 'Active'
       )
ORDER  BY p.monthly_amount DESC;


-- ============================================================
-- Q11: IN subquery — nominees of deceased veterans
--
-- CONCEPTS: Subquery with IN clause (returns a list of values)
-- BUSINESS USE: Pull all nominees who should now receive
--               family pension after veteran's death
-- ============================================================

SELECT
    n.nominee_name,
    n.relationship,
    n.share_percentage,
    v.full_name                             AS veteran_name,
    v.rank_name,
    ROUND(
        p.monthly_amount * 0.60 * n.share_percentage / 100,
    2)                                      AS monthly_family_pension
FROM   NOMINEE n
JOIN   VETERAN v ON n.veteran_id = v.veteran_id
JOIN   PENSION_RECORD p ON v.veteran_id = p.veteran_id
WHERE  n.is_active  = 'Y'
AND    n.veteran_id IN (
           SELECT veteran_id
             FROM VETERAN
            WHERE status = 'Deceased'
       )
ORDER  BY monthly_family_pension DESC;


-- ============================================================
-- Q12: Correlated subquery — veterans with more than 1 nominee
--
-- CONCEPTS: Correlated subquery (inner query references outer row)
--           Runs once per row in the outer query
-- BUSINESS USE: Identify complex pension split cases needing review
-- ============================================================

SELECT
    v.veteran_id,
    v.full_name,
    v.rank_name,
    v.status,
    (
        SELECT COUNT(*)
          FROM NOMINEE n
         WHERE n.veteran_id = v.veteran_id
           AND n.is_active  = 'Y'
    )                                       AS active_nominee_count,
    (
        SELECT GROUP_CONCAT(nominee_name ORDER BY share_percentage DESC)
          FROM NOMINEE n
         WHERE n.veteran_id = v.veteran_id
           AND n.is_active  = 'Y'
    )                                       AS nominee_names
FROM   VETERAN v
WHERE  (
           SELECT COUNT(*)
             FROM NOMINEE n
            WHERE n.veteran_id = v.veteran_id
              AND n.is_active  = 'Y'
       ) > 1
ORDER  BY active_nominee_count DESC;


-- ============================================================
-- Q13: Using a VIEW — query the pre-built active pensioners view
--
-- CONCEPTS: Views as virtual tables, querying vw_active_pensioners
-- BUSINESS USE: Dashboard query — always reflects live data
-- ============================================================

SELECT
    service_number,
    full_name,
    rank_name,
    regiment_name,
    pension_type,
    monthly_amount                          AS base_pension,
    da_percentage,
    total_monthly,
    pension_start_date,
    DATEDIFF(CURDATE(), pension_start_date) / 365.0
                                            AS pension_tenure_years
FROM   vw_active_pensioners
ORDER  BY total_monthly DESC
LIMIT  10;


-- ============================================================
-- Q14: Rank history audit — full promotion trail per veteran
--
-- CONCEPTS: JOIN with audit table, ORDER BY on date column
-- BUSINESS USE: Generate promotion certificate / service record
-- ============================================================

SELECT
    v.full_name,
    v.service_number,
    rh.old_rank,
    rh.new_rank,
    rh.changed_on                           AS promotion_date,
    rh.changed_by,
    DATEDIFF(rh.changed_on, v.date_of_enlistment) / 365
                                            AS years_to_reach_rank
FROM   RANK_HISTORY rh
JOIN   VETERAN v ON rh.veteran_id = v.veteran_id
ORDER  BY v.veteran_id, rh.changed_on;


-- ============================================================
-- Q15: Full executive summary — pension disbursement dashboard
--
-- CONCEPTS: Multiple aggregates, CASE expressions, formatting
-- BUSINESS USE: Monthly finance meeting — single-query summary
-- ============================================================

SELECT
    COUNT(DISTINCT v.veteran_id)            AS total_veterans,
    SUM(CASE WHEN v.status = 'Retired'
             THEN 1 ELSE 0 END)             AS retired,
    SUM(CASE WHEN v.status = 'Deceased'
             THEN 1 ELSE 0 END)             AS deceased,
    SUM(CASE WHEN v.status = 'Active'
             THEN 1 ELSE 0 END)             AS still_serving,
    COUNT(DISTINCT p.pension_id)            AS active_pensions,
    ROUND(SUM(
        CASE WHEN p.payment_status = 'Active'
             THEN p.monthly_amount ELSE 0 END
    ), 2)                                   AS total_base_monthly_INR,
    ROUND(SUM(
        CASE WHEN p.payment_status = 'Active'
             THEN p.monthly_amount * (1 + p.da_percentage / 100)
             ELSE 0 END
    ), 2)                                   AS total_da_adjusted_monthly_INR,
    ROUND(SUM(
        CASE WHEN p.payment_status = 'Active'
             THEN p.monthly_amount * (1 + p.da_percentage / 100) * 12
             ELSE 0 END
    ), 2)                                   AS total_annual_outflow_INR,
    COUNT(DISTINCT n.nominee_id)            AS total_nominees_registered,
    COUNT(DISTINCT rh.history_id)           AS total_promotions_logged
FROM   VETERAN v
LEFT JOIN PENSION_RECORD p ON v.veteran_id = p.veteran_id
LEFT JOIN NOMINEE n        ON v.veteran_id = n.veteran_id
LEFT JOIN RANK_HISTORY rh  ON v.veteran_id = rh.veteran_id;

-- ============================================================
-- END OF QUERIES
-- Run order: execute all 15 sequentially in MySQL Workbench
-- Use Ctrl+Enter to run a single highlighted query
-- Use Ctrl+Shift+Enter to run the entire file
-- ============================================================
