# Normalization Report — IVRPMS
## Indian Veteran Resource & Pension Management System

---

## 1. Introduction

Normalization is the process of structuring a relational database to reduce data redundancy and improve data integrity. This report documents the step-by-step normalization of the IVRPMS schema from an unnormalized flat table through First Normal Form (1NF), Second Normal Form (2NF), and Third Normal Form (3NF).

---

## 2. Starting Point — Unnormalized (UNF) Table

Consider a single flat table capturing all veteran and pension data as it might appear in a paper register:

```
VETERAN_REGISTER (unnormalized)
──────────────────────────────────────────────────────────────────────────────
service_no | name   | regiment | regiment_home | rank | rank_history       | pension | nominees
──────────────────────────────────────────────────────────────────────────────
IC-00001   | Arjun  | Rajputana| Jaipur        | Col  | Maj→Lt Col→Col    | 45000   | Priya (wife), Ravi (son)
IC-00002   | Balan  | Madras   | Chennai       | Brig | Col→Brig          | 52000   | Meena (wife)
```

**Problems identified:**
- `rank_history` is a multi-valued, non-atomic column (violates 1NF)
- `nominees` stores multiple values in one cell (violates 1NF)
- `regiment_home` depends on `regiment`, not on the veteran (partial/transitive dependency)
- Updating a regiment's home station requires changing every veteran row in that regiment

---

## 3. First Normal Form (1NF)

**Rule:** Every column must be atomic (single-valued). No repeating groups. A primary key must exist.

### Changes Made

1. Split `rank_history` into a separate `RANK_HISTORY` table — one row per promotion event.
2. Split `nominees` into a separate `NOMINEE` table — one row per nominee.
3. Assigned a surrogate primary key (`veteran_id`) to `VETERAN`.
4. Ensured every column holds a single, indivisible value.

### After 1NF

**VETERAN**

| veteran_id | service_no | name  | regiment   | regiment_home | current_rank | pension |
|------------|------------|-------|------------|---------------|--------------|---------|
| 1          | IC-00001   | Arjun | Rajputana  | Jaipur        | Col          | 45000   |
| 2          | IC-00002   | Balan | Madras     | Chennai       | Brig         | 52000   |

**RANK_HISTORY**

| history_id | veteran_id | previous_rank | new_rank | change_date |
|------------|------------|---------------|----------|-------------|
| 1          | 1          | Maj           | Lt Col   | 2010-06-01  |
| 2          | 1          | Lt Col        | Col      | 2015-03-15  |
| 3          | 2          | Col           | Brig     | 2018-07-22  |

**NOMINEE**

| nominee_id | veteran_id | nominee_name | relationship |
|------------|------------|--------------|--------------|
| 1          | 1          | Priya        | Wife         |
| 2          | 1          | Ravi         | Son          |
| 3          | 2          | Meena        | Wife         |

**Repeating groups and multi-valued attributes are eliminated. ✓**

---

## 4. Second Normal Form (2NF)

**Rule:** Must be in 1NF. Every non-key attribute must depend on the **whole** primary key (no partial dependencies). Partial dependencies only arise with composite keys.

### Analysis

In `VETERAN` after 1NF, the primary key is `veteran_id` (a single column), so there are no partial dependencies in VETERAN itself. However, `regiment_home` and other regiment attributes like `regiment_code` appear in the veteran row — they depend on `regiment` (a non-key attribute), not on `veteran_id` directly. This is a transitive dependency (addressed in 3NF), but we note it here.

**PENSION_RECORD** uses a composite natural key `(veteran_id, disbursement_date)` before adding a surrogate key. In that form:

| veteran_id | disbursement_date | pension_amount | ifsc_code | bank_account | regiment_name |
|------------|-------------------|----------------|-----------|--------------|---------------|
| 1          | 2024-01-01        | 45000          | SBIN0001  | 123456       | Rajputana     |
| 1          | 2024-02-01        | 45000          | SBIN0001  | 123456       | Rajputana     |

Here `regiment_name` depends only on `veteran_id`, not on the full composite key `(veteran_id, disbursement_date)` — a **partial dependency**.

### Changes Made

1. Added surrogate key `pension_id` to `PENSION_RECORD`, eliminating the composite key scenario.
2. Removed `regiment_name` from `PENSION_RECORD` (it belongs in `VETERAN` / `REGIMENT`).
3. Extracted `regiment` data into its own `REGIMENT` table, referenced by `veteran_id` → `regiment_id` FK.

### After 2NF

**REGIMENT** (new table)

| regiment_id | regiment_name | regiment_code | home_station  |
|-------------|---------------|---------------|---------------|
| 1           | Rajputana     | RAJ001        | Jaipur        |
| 2           | Madras        | MAD001        | Chennai       |

**VETERAN** (updated)

| veteran_id | service_no | name  | regiment_id | current_rank | pension_basic |
|------------|------------|-------|-------------|--------------|---------------|
| 1          | IC-00001   | Arjun | 1           | Col          | 45000         |
| 2          | IC-00002   | Balan | 2           | Brig         | 52000         |

**PENSION_RECORD** (updated)

| pension_id | veteran_id | pension_amount | ifsc_code | bank_account | disbursement_date |
|------------|------------|----------------|-----------|--------------|-------------------|
| 1          | 1          | 45000          | SBIN0001  | 123456       | 2024-01-01        |
| 2          | 1          | 45000          | SBIN0001  | 123456       | 2024-02-01        |

**All non-key attributes now depend on the entire primary key. ✓**

---

## 5. Third Normal Form (3NF)

**Rule:** Must be in 2NF. No transitive dependencies — non-key attributes must not depend on other non-key attributes.

### Transitive Dependencies Found

**In VETERAN (before fix):** If we had stored `home_state` derived from `home_district` (e.g., district "Amritsar" → state "Punjab"), then:

```
veteran_id → home_district → home_state
```

`home_state` transitively depends on `veteran_id` through `home_district`. The fix is to store both independently in `VETERAN`, as neither is derived from the other in the current schema — they are independent attributes of the veteran's residence.

**In PENSION_RECORD:** If we stored `bank_name` derived from `ifsc_code` (the first 4 characters of an IFSC code identify the bank), that would be a transitive dependency:

```
pension_id → ifsc_code → bank_name
```

### Changes Made

1. Removed any derived or transitively-dependent columns.
2. `home_district` and `home_state` are stored as independent veteran attributes (not derived from each other).
3. `bank_name` is not stored — it can be derived from `ifsc_code` at the application layer.
4. `AUDIT_LOG` is a standalone table referencing `veteran_id`; its columns (`table_name`, `operation`, `old_value`, `new_value`, `log_timestamp`) all depend directly on `log_id`.

### Final Schema After 3NF

```
REGIMENT (regiment_id PK, regiment_name, regiment_code, raising_date, home_station, commanding_officer)

VETERAN (veteran_id PK, regiment_id FK, service_number, full_name, date_of_birth,
         date_of_enlistment, date_of_discharge, current_rank, aadhaar_last4,
         contact_phone, home_district, home_state, veteran_status)

PENSION_RECORD (pension_id PK, veteran_id FK, basic_pension, dearness_allowance,
                medical_allowance, disbursement_date, bank_account_no, ifsc_code, pension_status)

NOMINEE (nominee_id PK, veteran_id FK, nominee_name, relationship, date_of_birth,
         aadhaar_last4, contact_phone, family_pension_pct)

RANK_HISTORY (history_id PK, veteran_id FK, previous_rank, new_rank, change_date, changed_by)

AUDIT_LOG (log_id PK, veteran_id FK, table_name, operation, old_value, new_value, log_timestamp)
```

**No transitive dependencies remain. ✓**

---

## 6. BCNF Check (Boyce-Codd Normal Form)

BCNF is a stricter version of 3NF: for every non-trivial functional dependency X → Y, X must be a superkey.

| Table          | Functional Dependencies                       | BCNF? |
|----------------|-----------------------------------------------|-------|
| REGIMENT       | regiment_id → all; regiment_code → all        | ✓ (both are candidate keys) |
| VETERAN        | veteran_id → all; service_number → all        | ✓ (both are candidate keys) |
| PENSION_RECORD | pension_id → all                              | ✓     |
| NOMINEE        | nominee_id → all                              | ✓     |
| RANK_HISTORY   | history_id → all                              | ✓     |
| AUDIT_LOG      | log_id → all                                  | ✓     |

**All tables satisfy BCNF. ✓**

---

## 7. Summary

| Stage | What Was Done                                              | Anomalies Eliminated              |
|-------|------------------------------------------------------------|-----------------------------------|
| UNF   | Single flat register with multi-valued columns             | —                                 |
| 1NF   | Atomic columns; separate RANK_HISTORY and NOMINEE tables   | Insertion, update, deletion anomalies from repeating groups |
| 2NF   | Extracted REGIMENT; removed partial dependencies           | Regiment data duplicated per veteran |
| 3NF   | Removed transitive dependencies (derived attributes)       | bank_name, redundant location data |
| BCNF  | Verified all determinants are superkeys                    | No further violations found       |

The final IVRPMS schema is fully normalized to BCNF with 6 tables, 8 indexes, and 3 views supporting the application layer.
