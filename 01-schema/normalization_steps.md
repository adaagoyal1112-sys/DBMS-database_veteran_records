# IVRPMS — Normalization Steps (1NF → 3NF / BCNF)

## Overview

Before designing the final schema, all veteran and pension data was
imagined as a single flat table — the way it might exist in a manual
register or an Excel sheet. That unnormalized table was then processed
through each normal form to eliminate redundancy, anomalies, and
inconsistency.

---

## Unnormalized Form (UNF) — The Raw Register

This is what the data looks like in a manual army pension register.
One row per veteran, with multiple nominees and rank history crammed
into the same record.

| veteran_id | full_name | rank | regiment_name | base_location | pension_amt | nominee_1 | nominee_2 | old_rank_1 | old_rank_2 |
|---|---|---|---|---|---|---|---|---|---|
| 1001 | Rajinder Singh | Subedar | Punjab Regiment | Ramgarh | 19550 | Gurpreet Kaur (Spouse) | Manpreet Singh (Child) | Sepoy | Naik |
| 1003 | Arun Sharma | Colonel | Regiment of Artillery | Nashik | 65300 | Sunita Sharma (Spouse) | Rahul Sharma (Child) | Lieutenant | Captain |

**Problems visible immediately:**
- `nominee_1`, `nominee_2` are repeating groups — not atomic
- `regiment_name` and `base_location` repeat for every veteran in the same regiment
- `old_rank_1`, `old_rank_2` are repeating groups for history
- If the regiment relocates, you update hundreds of rows

---

## 1NF — First Normal Form

**Rule:** Every column must be atomic (one value per cell). No repeating groups. Each row must be uniquely identifiable.

**Changes made:**
- Removed `nominee_1`, `nominee_2` columns — each nominee gets its own row
- Removed `old_rank_1`, `old_rank_2` columns — each promotion gets its own row
- Added `veteran_id` as primary key

**Result — VETERAN_1NF table (single flat table, now atomic):**

| veteran_id | full_name | rank | regiment_name | base_location | pension_amt | nominee_name | relationship | old_rank | new_rank | promotion_date |
|---|---|---|---|---|---|---|---|---|---|---|
| 1001 | Rajinder Singh | Subedar | Punjab Regiment | Ramgarh | 19550 | Gurpreet Kaur | Spouse | Sepoy | Naik | 1978-03-10 |
| 1001 | Rajinder Singh | Subedar | Punjab Regiment | Ramgarh | 19550 | Manpreet Singh | Child | Naik | Havildar | 1983-06-22 |
| 1003 | Arun Sharma | Colonel | Regt of Artillery | Nashik | 65300 | Sunita Sharma | Spouse | Lieutenant | Captain | 1978-04-05 |
| 1003 | Arun Sharma | Colonel | Regt of Artillery | Nashik | 65300 | Rahul Sharma | Child | Captain | Major | 1984-07-19 |

**1NF satisfied:** ✅ Every cell is atomic. Primary key exists.

**Problems still remaining:**
- `full_name`, `rank`, `regiment_name`, `base_location`, `pension_amt`
  repeat for every nominee and every promotion of the same veteran
- `regiment_name` and `base_location` depend only on the regiment,
  not on the veteran — this is a **partial dependency**

---

## 2NF — Second Normal Form

**Rule:** Must be in 1NF. No partial dependencies — every non-key
column must depend on the **whole** primary key, not just part of it.

In 1NF, the composite key would be `(veteran_id, nominee_name,
old_rank)` to uniquely identify rows. But `full_name`, `rank`,
`regiment_name` depend only on `veteran_id` — that is a partial
dependency.

**Changes made:**
- Separated `regiment_name` and `base_location` into a new
  **REGIMENT** table (they depend on the regiment, not the veteran)
- Separated nominee data into a **NOMINEE** table
- Separated rank promotion data into **RANK_HISTORY** table
- Kept core veteran attributes in **VETERAN** table with `regiment_id`
  as a foreign key

**Result after 2NF:**

**REGIMENT table:**

| regiment_id | regiment_name | base_location | arm_of_service |
|---|---|---|---|
| 1 | Punjab Regiment | Ramgarh Cantonment | Infantry |
| 12 | Regiment of Artillery | Nashik | Artillery |

**VETERAN table:**

| veteran_id | full_name | rank | regiment_id | pension_amt | date_of_birth | ... |
|---|---|---|---|---|---|---|
| 1001 | Rajinder Singh | Subedar | 1 | 19550 | 1955-04-12 | ... |
| 1003 | Arun Sharma | Colonel | 12 | 65300 | 1952-11-05 | ... |

**NOMINEE table:**

| nominee_id | veteran_id | nominee_name | relationship | share_pct |
|---|---|---|---|---|
| 7001 | 1001 | Gurpreet Kaur | Spouse | 60 |
| 7002 | 1001 | Manpreet Singh | Child | 40 |
| 7004 | 1003 | Sunita Sharma | Spouse | 50 |

**RANK_HISTORY table:**

| history_id | veteran_id | old_rank | new_rank | changed_on |
|---|---|---|---|---|
| 1 | 1001 | Sepoy | Naik | 1978-03-10 |
| 2 | 1001 | Naik | Havildar | 1983-06-22 |

**2NF satisfied:** ✅ No partial dependencies remain.

**Problem still remaining:**
- `pension_amt` in VETERAN depends on `rank` and `years_of_service`,
  not directly on `veteran_id` — this is a **transitive dependency**
- If the pension rate for "Colonel" changes, every Colonel's row
  must be updated separately

---

## 3NF — Third Normal Form

**Rule:** Must be in 2NF. No transitive dependencies — non-key columns
must depend **only** on the primary key, not on other non-key columns.

**Transitive dependency found:**
```
veteran_id → rank → pension_amt
```
`pension_amt` depends on `rank` (a non-key column), not directly on
`veteran_id`. This means it transitively depends on the primary key
through `rank`.

**Changes made:**
- Moved `pension_amt`, `bank_account_no`, `bank_ifsc`,
  `pension_start_date`, `payment_status`, `da_percentage` into a
  new **PENSION_RECORD** table
- Each pension record links to `veteran_id` directly
- `rank` stays in VETERAN (it is a direct attribute of the veteran)
- Pension amounts are now calculated by stored procedures using rank
  and years of service — not stored redundantly

**Final VETERAN table (3NF):**

| veteran_id | service_number | full_name | rank | regiment_id | date_of_birth | date_of_enlistment | date_of_retirement | status | state_of_domicile |
|---|---|---|---|---|---|---|---|---|---|
| 1001 | JC-40001 | Rajinder Singh | Subedar | 1 | 1955-04-12 | 1975-06-01 | 2005-06-01 | Retired | Punjab |

**Final PENSION_RECORD table (3NF):**

| pension_id | veteran_id | pension_type | monthly_amount | da_percentage | bank_account_no | pension_start_date | payment_status |
|---|---|---|---|---|---|---|---|
| 5001 | 1001 | Service | 19550.00 | 46.00 | XXXXXXXX4521 | 2005-07-01 | Active |

**3NF satisfied:** ✅ No transitive dependencies remain.

---

## BCNF — Boyce-Codd Normal Form

**Rule:** For every functional dependency X → Y, X must be a
superkey (candidate key or primary key).

**Check on all tables:**

| Table | Functional Dependencies | Determinant is superkey? | BCNF? |
|---|---|---|---|
| REGIMENT | regiment_id → all others | Yes — PK | ✅ |
| VETERAN | veteran_id → all others | Yes — PK | ✅ |
| VETERAN | service_number → veteran_id | Yes — candidate key (UNIQUE) | ✅ |
| PENSION_RECORD | pension_id → all others | Yes — PK | ✅ |
| NOMINEE | nominee_id → all others | Yes — PK | ✅ |
| RANK_HISTORY | history_id → all others | Yes — PK | ✅ |
| AUDIT_LOG | log_id → all others | Yes — PK | ✅ |

**BCNF satisfied:** ✅ Every determinant is a candidate key.

---

## Summary — What Each Normal Form Fixed

| Stage | Problem eliminated | Tables affected |
|---|---|---|
| UNF → 1NF | Repeating groups (nominees, rank history) | All |
| 1NF → 2NF | Partial dependencies (regiment data, nominee data) | REGIMENT, NOMINEE, RANK_HISTORY split out |
| 2NF → 3NF | Transitive dependency (pension via rank) | PENSION_RECORD split out |
| 3NF → BCNF | Verified all determinants are candidate keys | All — confirmed compliant |

**Final schema:** 6 tables — REGIMENT, VETERAN, PENSION_RECORD,
NOMINEE, RANK_HISTORY, AUDIT_LOG — normalized to 3NF/BCNF.

**Benefits achieved:**
- No update anomalies: changing a regiment's base location updates
  one row in REGIMENT, not thousands of VETERAN rows
- No insertion anomalies: a nominee can be recorded independently
- No deletion anomalies: deleting a pension record does not delete
  the veteran's personal record
- Reduced redundancy: regiment data stored once, referenced by FK
- Query performance: targeted indexes on FK columns enable fast JOINs
