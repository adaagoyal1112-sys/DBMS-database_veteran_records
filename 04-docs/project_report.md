# Project Report
## IVRPMS — Indian Veteran Resource & Pension Management System

**Course:** Database Management Systems & Design and Analysis of Algorithms  
**Submission Type:** Combined DBMS + DAA Academic Project  
**Technology Stack:** MySQL 8.0+ · Python 3.10+  
**Data Coverage:** 50 Veterans · 15 Regiments · 308 Rows Across 6 Tables

---

## 1. Project Overview

IVRPMS is a relational database system designed to manage Indian Army veteran records, pension disbursements, rank histories, and nominee registrations. The system models the administrative workflows of a veteran welfare department, handling everything from initial enlistment records to monthly pension batch processing.

The project was designed to demonstrate four core competencies:

1. **Schema Design** — Normalized relational schema (BCNF) with integrity constraints
2. **PL/SQL Programming** — Triggers, stored procedures, cursors, and analytical queries
3. **Algorithm Implementation** — Merge Sort and KMP Search with formal complexity analysis
4. **Documentation** — ER diagrams, normalization proofs, and execution evidence

---

## 2. Problem Statement

Veterans of the Indian Army require a centralized, consistent system to track:
- Service records and rank progressions over a career spanning decades
- Monthly pension disbursements adjusted for Dearness Allowance (7th Pay Commission)
- Nominee registrations for family pension eligibility upon a veteran's death
- Audit trails for all changes to sensitive veteran data

Paper-based or spreadsheet-based systems suffer from data redundancy, update anomalies, and inability to enforce referential integrity. This project implements a normalized RDBMS solution addressing all these concerns.

---

## 3. Database Design

### 3.1 Schema Overview

The database contains six tables organized around the central `VETERAN` entity:

| Table          | Rows | Purpose                                                  |
|----------------|-----:|----------------------------------------------------------|
| REGIMENT       |   15 | Master data for Indian Army regiments                    |
| VETERAN        |   50 | Personal and service records for each veteran            |
| PENSION_RECORD |   44 | Monthly disbursement records with DA calculation         |
| NOMINEE        |  107 | Family members eligible for pension continuation         |
| RANK_HISTORY   |   92 | Immutable audit trail of rank promotions                 |
| AUDIT_LOG      |    — | System-wide change log populated by triggers             |

### 3.2 Key Design Decisions

**Surrogate Primary Keys:** Each table uses an auto-increment integer PK (`veteran_id`, `pension_id`, etc.) rather than natural keys. This insulates foreign key relationships from changes to business data such as service numbers.

**Aadhaar Privacy:** The schema stores only the last 4 digits of Aadhaar numbers (`aadhaar_last4 CHAR(4)`), complying with UIDAI guidelines that prohibit storing full Aadhaar numbers in non-certified systems.

**IFSC Validation:** A CHECK constraint enforces the format `[A-Z]{4}0[A-Z0-9]{6}` on all IFSC codes, preventing invalid bank routing data at the database level.

**Service Number Format:** Indian Army service numbers follow `IC-XXXXX` (commissioned officers) or `JC-XXXXX` (Junior Commissioned Officers). A regex CHECK constraint enforces this format.

**Dearness Allowance:** Pension records store both `basic_pension` and `dearness_allowance` as separate columns rather than a pre-computed total, allowing DA rates to be updated historically without data loss.

### 3.3 Views

Three views provide application-layer access to commonly needed derived data:

```sql
-- vw_active_pensioners: DA-adjusted monthly total for all active disbursements
-- vw_service_summary: Computed years_of_service per veteran
-- vw_family_pension_due: Nominees of deceased veterans with 60% family pension
```

### 3.4 Normalization

The schema is fully normalized to BCNF. The normalization process proceeded through three stages:

- **1NF:** Eliminated repeating groups by extracting `RANK_HISTORY` and `NOMINEE` into separate tables.
- **2NF:** Eliminated partial dependencies by extracting `REGIMENT` from the veteran row.
- **3NF / BCNF:** Removed transitive dependencies; verified all determinants are superkeys.

Full before/after tables with functional dependency analysis are documented in `normalization_report.md`.

---

## 4. PL/SQL Implementation

### 4.1 Triggers (`triggers.sql`)

**`trg_veteran_rank_update`** — An `AFTER UPDATE` trigger on the `VETERAN` table. When `current_rank` is modified, the trigger:
1. Inserts a row into `RANK_HISTORY` with the old rank, new rank, timestamp, and the MySQL user who made the change.
2. Inserts a row into `AUDIT_LOG` capturing the full old and new values as JSON.

This ensures the rank audit trail is always complete regardless of which application or user modifies the veteran record.

### 4.2 Stored Procedures (`stored_procedures.sql`)

**`calculate_annual_benefit(veteran_id)`** — Computes the total annual pension benefit for a given veteran by summing `basic_pension + dearness_allowance + medical_allowance` across all active pension records and multiplying by 12.

**`years_of_service(veteran_id)`** — Returns the number of complete years of service using `TIMESTAMPDIFF(YEAR, date_of_enlistment, IFNULL(date_of_discharge, CURDATE()))`.

**`get_pension_summary()`** — Generates a summary report grouped by regiment, showing total active pensioners, average basic pension, and total annual payout per regiment.

### 4.3 Cursors (`cursors.sql`)

A cursor-based monthly batch processor iterates over all veterans with `pension_status = 'Active'`. For each active pensioner, it:
1. Fetches the latest pension record
2. Calculates the DA-adjusted disbursement total
3. Prints a formatted disbursement slip to standard output
4. Logs the batch run timestamp

This demonstrates row-by-row processing and the use of cursor variables, `FETCH`, and `CLOSE` within a stored procedure.

### 4.4 Analytical Queries (`queries.sql`)

Twelve SELECT queries demonstrating advanced SQL features:

| Query | Technique Used                                          |
|-------|---------------------------------------------------------|
| Q1    | Multi-table JOIN (VETERAN ⋈ REGIMENT ⋈ PENSION_RECORD) |
| Q2    | GROUP BY regiment with HAVING (min 3 veterans)         |
| Q3    | Subquery — veterans earning above average pension       |
| Q4    | LEFT JOIN — veterans with no nominee registered         |
| Q5    | Window function — RANK() on pension amount per regiment |
| Q6    | CASE expression — pension tier classification           |
| Q7    | Self-join on RANK_HISTORY — multi-promotion veterans    |
| Q8    | EXISTS subquery — nominees eligible for family pension  |
| Q9    | Aggregate with ROLLUP — pension totals with grand total |
| Q10   | DATE functions — veterans completing 20 years this year |
| Q11   | JSON_OBJECT — audit log export format                  |
| Q12   | View query on vw_active_pensioners with sort + limit   |

---

## 5. Algorithm Implementation

### 5.1 Merge Sort (`merge_sort.py`)

Merge Sort is applied to sort veteran records by pension amount for batch processing.

**Why Merge Sort over Quicksort?**  
Pension batch files from prior runs are partially sorted. Quicksort degrades to Θ(n²) on nearly-sorted input due to poor pivot selection. Merge Sort guarantees Θ(n log n) in all cases (best, average, worst) and is stable — equal pension amounts retain their original relative order, preserving disbursement sequence integrity.

**Recurrence and Master Theorem Proof:**

```
T(n) = 2T(n/2) + Θ(n)

Master Theorem Form: T(n) = aT(n/b) + f(n)
  a = 2, b = 2, f(n) = Θ(n)

log_b(a) = log_2(2) = 1
f(n) = Θ(n^1) = Θ(n^(log_b a))

→ Case 2 of Master Theorem applies
→ T(n) = Θ(n log n)
```

**Space Complexity:** Θ(n) auxiliary space for the merge step.

### 5.2 KMP Search (`kmp_search.py`)

KMP (Knuth-Morris-Pratt) string search is applied to locate veteran service numbers in a dataset without re-examining characters.

**Why KMP over Naive Search?**  
Naive string search has worst-case Θ(n×m) complexity where n is the text length and m is the pattern length. For a dataset of 50,000 service number records and a 10-character pattern, naive search may examine up to 500,000 character comparisons. KMP's failure function (LPS array) ensures no character in the text is ever re-examined, giving Θ(n+m) always.

**Complexity Proof:**

```
LPS (Failure Function) Construction: Θ(m)
  - Single pass through the pattern
  - Each character processed at most twice (once forward, once back via LPS)

Search Phase: Θ(n)
  - Text pointer i never decrements
  - Pattern pointer j decrements via LPS but total increments of i = n
  - Total character comparisons ≤ 2n

Combined: T(n, m) = Θ(m) + Θ(n) = Θ(n + m)
```

**Space Complexity:** Θ(m) for the LPS failure function array.

---

## 6. Data Notes

All data in this project is entirely synthetic and generated for academic purposes. No real veteran personal data is used or represented.

- **Regiment names** follow actual Indian Army regimental structure for realism
- **Pension amounts** are based on 7th Pay Commission (2016) rates for reference ranks
- **Service numbers** follow the real Indian Army format: `IC-XXXXX` for officers, `JC-XXXXX` for JCOs
- **Aadhaar references** store only a fictitious last 4 digits for schema demonstration
- **IFSC codes** follow correct format but reference fictitious bank accounts

---

## 7. Repository Structure

```
DBMS-database_veteran_records/
├── 01-schema/
│   ├── create_tables.sql        DDL: 6 tables, 8 indexes, 3 views, CHECK constraints
│   ├── sample_data.sql          308 rows of synthetic data across all tables
│   └── normalization_steps.md   1NF → 2NF → 3NF walkthrough with examples
│
├── 02-plsql/
│   ├── triggers.sql             AFTER UPDATE on VETERAN → RANK_HISTORY + AUDIT_LOG
│   ├── stored_procedures.sql    calculate_annual_benefit(), years_of_service(), get_pension_summary()
│   ├── cursors.sql              Monthly batch processor for active pension disbursement
│   └── queries.sql              12 SELECT queries: JOINs, GROUP BY, HAVING, subqueries, window functions
│
├── 03-algorithms/
│   ├── merge_sort.py            Θ(n log n) sort on pension records with Master Theorem proof in comments
│   ├── kmp_search.py            Θ(n+m) service number search with LPS failure function walkthrough
│   └── complexity_proof.md      Formal proofs for both algorithms
│
├── 04-docs/
│   ├── er_diagram.md            Entity-Relationship diagram with ASCII art and attribute tables
│   ├── normalization_report.md  Full normalization report with before/after tables (UNF → BCNF)
│   └── project_report.md        This file
│
└── README.md                    Setup instructions, schema overview, algorithm rationale
```

---

## 8. Setup Instructions

### Prerequisites

- MySQL 8.0 or higher
- Python 3.10 or higher (standard library only — no pip installs required)

### Database Setup

```bash
# Step 1: Create the database
mysql -u root -p -e "CREATE DATABASE ivrpms;"

# Step 2: Load schema (tables, indexes, views, constraints)
mysql -u root -p ivrpms < 01-schema/create_tables.sql

# Step 3: Load 308 rows of sample data
mysql -u root -p ivrpms < 01-schema/sample_data.sql

# Step 4: Load PL/SQL objects
mysql -u root -p ivrpms < 02-plsql/triggers.sql
mysql -u root -p ivrpms < 02-plsql/stored_procedures.sql
mysql -u root -p ivrpms < 02-plsql/cursors.sql

# Step 5: Run analytical queries
mysql -u root -p ivrpms < 02-plsql/queries.sql
```

### Algorithm Demo

```bash
python 03-algorithms/merge_sort.py
python 03-algorithms/kmp_search.py
```

---

## 9. Conclusion

IVRPMS demonstrates a complete database application lifecycle — from requirements analysis and schema design through normalization, procedural SQL programming, algorithm implementation, and documentation. The system handles real-world constraints specific to the Indian Army administrative domain while remaining academically rigorous in its application of database theory and algorithm analysis.

**Key outcomes:**
- A BCNF-normalized schema enforcing domain integrity through CHECK constraints, FK relationships, and trigger-maintained audit trails
- PL/SQL objects covering all major MySQL procedural constructs (triggers, procedures, cursors)
- Two classic algorithms implemented with correct formal complexity proofs using the Master Theorem
- Complete documentation suitable for examiner review

---

*Academic project — DBMS + DAA course submission*  
*Indian Army structure reference: 7th Pay Commission, 2016*  
*All data is synthetic and for educational use only*
