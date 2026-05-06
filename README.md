# IVRPMS — Indian Veteran Resource & Pension Management System

> Academic database project · MySQL 8.0+ · Python 3.10+ · Flask
> Demonstrates: Schema Design · PL/SQL · Algorithm Analysis · Normalization · Web UI

**Live deployment:** https://dbms-databaseveteranrecords-production.up.railway.app

---

## What This Project Is

IVRPMS is a relational database system for managing Indian Army veteran records, pension disbursements, and nominee registrations. It covers 50 veterans across 15 regiments with full pension and rank history data, fronted by a Flask web dashboard.

Built as a college DBMS project, it demonstrates:
- **3NF/BCNF normalized schema** with 6 tables and 8 indexes
- **PL/SQL** — triggers, stored procedures, cursors, and analytical queries
- **Algorithm implementation** — Merge Sort and KMP Search with formal complexity proofs
- **Real-world constraints** — IFSC format checks, Aadhaar validation, service number regex
- **Working web UI** — Flask + vanilla JS dashboard with CRUD, search, and live trigger demo

---

## Repository Structure

```
DBMS-database_veteran_records/
│
├── 01-schema/
│   ├── create_tables.sql        ← DDL: all 6 tables, constraints, indexes, views
│   ├── sample_data.sql          ← 308 rows across all tables
│   └── normalization_steps.md   ← 1NF → 2NF → 3NF walkthrough with examples
│
├── 02-plsql/
│   ├── triggers.sql             ← AFTER UPDATE on VETERAN → RANK_HISTORY + AUDIT_LOG
│   ├── stored_procedures.sql    ← calculate_annual_benefit(), years_of_service(), get_pension_summary()
│   ├── cursors.sql              ← Monthly batch processor for Active pension disbursement
│   └── queries.sql              ← 12 SELECT queries: JOINs, GROUP BY, HAVING, subqueries
│
├── 03-algorithms/
│   ├── merge_sort.py            ← Θ(n log n) sort on pension records, Master Theorem proof
│   ├── kmp_search.py            ← Θ(n+m) service number search, LPS failure function
│   └── complexity_proof.md      ← Formal proofs for both algorithms
│
├── 04-docs/
│   ├── er_diagram.md            ← Entity-Relationship diagram (text notation)
│   ├── normalization_report.md  ← Full normalization report
│   └── project_report.md        ← Complete project report for submission
│
├── 05-ui/
│   ├── app.py                   ← Flask backend (12 REST endpoints)
│   └── index.html               ← Single-page dashboard (vanilla JS)
│
├── bootstrap_db.py              ← Idempotent schema loader for fresh deploys
├── requirements.txt             ← Python dependencies
├── Procfile                     ← Railway / Heroku start command
├── runtime.txt                  ← Python version pin
├── .env.example                 ← Local env-var template
└── README.md                    ← This file
```

---

## Local Setup

### Prerequisites
- MySQL 8.0+
- Python 3.10+

### 1. Clone and install dependencies

```bash
git clone <your-fork-url> veteran_records
cd veteran_records
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
```

### 2. Create the database

```bash
mysql -u root -p -e "CREATE DATABASE ivrpms;"
```

### 3. Configure environment

```bash
cp .env.example .env
# Edit .env with your local MySQL credentials
```

### 4. Bootstrap schema + data

The bootstrap script reads your `.env` and runs every SQL file in order. Idempotent — re-running it on a populated DB is a no-op.

```bash
set -a; source .env; set +a
python bootstrap_db.py
```

You can also run the SQL files manually if you prefer:

```bash
mysql -u root -p ivrpms < 01-schema/create_tables.sql
mysql -u root -p ivrpms < 01-schema/sample_data.sql
mysql -u root -p ivrpms < 02-plsql/triggers.sql
mysql -u root -p ivrpms < 02-plsql/stored_procedures.sql
mysql -u root -p ivrpms < 02-plsql/cursors.sql
```

### 5. Start the web UI

```bash
cd 05-ui && python app.py
```

Open <http://localhost:5000>.

### 6. Run the algorithms (standalone)

```bash
python 03-algorithms/merge_sort.py
python 03-algorithms/kmp_search.py
```

---

## Deploying to Railway

The repo is configured for one-click deploy on [Railway](https://railway.app/) (free tier works).

### Steps

1. **Sign in** at [railway.app](https://railway.app/) (use GitHub).
2. **New Project → Deploy from GitHub repo** → pick this repo.
3. **Add a MySQL service**: in the project canvas, click **+ New → Database → MySQL**.
4. **Wire env vars** on the web service (Variables tab):
   ```
   MYSQL_HOST=${{MySQL.MYSQLHOST}}
   MYSQL_PORT=${{MySQL.MYSQLPORT}}
   MYSQL_USER=${{MySQL.MYSQLUSER}}
   MYSQL_PASSWORD=${{MySQL.MYSQLPASSWORD}}
   MYSQL_DATABASE=${{MySQL.MYSQLDATABASE}}
   ```
   Railway substitutes the `${{...}}` references automatically.
5. **Generate a public domain** (Settings → Networking → Generate Domain).
6. First boot runs `bootstrap_db.py` and loads schema + 308 rows. Subsequent boots skip bootstrap.

Health check: `https://<your-domain>/api/health` → `{"status":"ok","db":"connected"}`.

---

## Web UI Features

The Flask dashboard at `05-ui/` provides:

| Page         | What it shows                                                       |
|--------------|---------------------------------------------------------------------|
| Dashboard    | Live stats, recent enlistments, top pensions                        |
| Veterans     | Full registry · search · **Enlist New** modal · **Update Rank** modal (fires `trg_rank_change_log`) |
| Pensions     | Disbursement ledger with DA-adjusted totals                         |
| Nominees     | Family beneficiaries with share allocation                          |
| Regiments    | Visual strength overview (bar chart per unit)                       |
| Rank Log     | Audit trail populated by trigger                                    |
| Schema       | Live `information_schema.TABLES` snapshot                           |

### REST API

All endpoints under `/api/`:

| Method | Path                            | Purpose                       |
|--------|---------------------------------|-------------------------------|
| GET    | `/api/health`                   | DB connectivity probe         |
| GET    | `/api/stats`                    | Dashboard counters            |
| GET    | `/api/veterans`                 | List all veterans             |
| POST   | `/api/veterans` or `/add`       | Enlist new veteran            |
| POST   | `/api/veterans/<id>/rank`       | Update rank → fires trigger   |
| GET    | `/api/pensions`                 | Pension records               |
| GET    | `/api/nominees`                 | Family beneficiaries          |
| GET    | `/api/regiments`                | Regiment + headcount          |
| GET    | `/api/regiments_list`           | Regiment dropdown source      |
| GET    | `/api/rank_log`                 | RANK_HISTORY audit trail      |
| GET    | `/api/recent_veterans`          | Last 5 enlistments            |
| GET    | `/api/top_pensions`             | Top 5 pensions by amount      |
| GET    | `/api/schema`                   | information_schema metadata   |

---

## Database Schema

| Table          | Rows | Description                                      |
|----------------|-----:|--------------------------------------------------|
| REGIMENT       |   15 | Indian Army regiment master data                 |
| VETERAN        |   50 | Personal and service records                     |
| PENSION_RECORD |   44 | Monthly disbursement records with DA             |
| NOMINEE        |  107 | Family members eligible for pension benefits     |
| RANK_HISTORY   |   92 | Audit trail of promotions (trigger-populated)    |
| AUDIT_LOG      |    — | System-wide change log (populated by triggers)   |

### Key Relationships

```
REGIMENT ──< VETERAN ──< PENSION_RECORD
                    ──< NOMINEE
                    ──< RANK_HISTORY
                    ──< AUDIT_LOG
```

---

## Algorithm Complexity

| Algorithm  | File               | Time Complexity | Space |
|------------|--------------------|-----------------|-------|
| Merge Sort | `merge_sort.py`    | Θ(n log n)      | Θ(n)  |
| KMP Search | `kmp_search.py`    | Θ(n + m)        | Θ(m)  |

**Why Merge Sort over Quicksort?**
Pension batch files arrive partially sorted from prior runs. Quicksort degrades to Θ(n²) on nearly-sorted input; Merge Sort guarantees Θ(n log n) in all cases and is stable (equal pension amounts retain their original relative order).

**Why KMP over Naive Search?**
Naive string search is Θ(n×m). KMP's failure function ensures no character in the text is ever re-examined, giving Θ(n+m) always.

---

## Views Included

| View                    | Description                                           |
|-------------------------|-------------------------------------------------------|
| `vw_active_pensioners`  | All active pensioners with DA-adjusted monthly total  |
| `vw_service_summary`    | Veterans with computed years_of_service               |
| `vw_family_pension_due` | Nominees of deceased veterans with 60% family pension |

---

## Data Notes

- All data is **synthetic** — generated for academic use only
- Pension amounts follow **7th Pay Commission** rates
- Service numbers follow Indian Army format: `IC-XXXXX` (officers) / `JC-XXXXX` (JCOs)
- Aadhaar references store last 4 digits only (privacy-safe)

---

## Tech Stack

| Layer      | Technology                                      |
|------------|-------------------------------------------------|
| Database   | MySQL 8.0+                                      |
| PL/SQL     | MySQL Stored Procedures, Triggers, Cursors      |
| Backend    | Python 3.11 · Flask 3.x · gunicorn              |
| Frontend   | Vanilla HTML/CSS/JS (no build step)             |
| Algorithms | Python 3.10+                                    |
| Hosting    | Railway (Flask + MySQL)                         |
| Docs       | Markdown                                        |

---

## Author

Academic project — DBMS + DAA course submission
Indian Army structure reference: 7th Pay Commission, 2016
