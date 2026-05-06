# Entity-Relationship Diagram — IVRPMS

## Entities and Attributes

### REGIMENT
```
REGIMENT
├── regiment_id        INT           PK
├── regiment_name      VARCHAR(100)  NOT NULL, UNIQUE
├── regiment_code      CHAR(6)       NOT NULL, UNIQUE
├── raising_date       DATE
├── home_station       VARCHAR(100)
└── commanding_officer VARCHAR(100)
```

### VETERAN
```
VETERAN
├── veteran_id         INT           PK
├── regiment_id        INT           FK → REGIMENT
├── service_number     VARCHAR(15)   NOT NULL, UNIQUE  (regex: IC-\d{5}|JC-\d{5})
├── full_name          VARCHAR(150)  NOT NULL
├── date_of_birth      DATE          NOT NULL
├── date_of_enlistment DATE          NOT NULL
├── date_of_discharge  DATE
├── current_rank       VARCHAR(50)
├── aadhaar_last4      CHAR(4)       (privacy-safe, last 4 digits only)
├── contact_phone      VARCHAR(15)
├── home_district      VARCHAR(100)
├── home_state         VARCHAR(100)
└── veteran_status     ENUM('Active','Deceased','Missing')
```

### PENSION_RECORD
```
PENSION_RECORD
├── pension_id         INT           PK
├── veteran_id         INT           FK → VETERAN
├── basic_pension      DECIMAL(10,2) NOT NULL
├── dearness_allowance DECIMAL(10,2) (DA per 7th Pay Commission)
├── medical_allowance  DECIMAL(10,2)
├── disbursement_date  DATE          NOT NULL
├── bank_account_no    VARCHAR(20)
├── ifsc_code          CHAR(11)      (regex: [A-Z]{4}0[A-Z0-9]{6})
└── pension_status     ENUM('Active','Suspended','Terminated')
```

### NOMINEE
```
NOMINEE
├── nominee_id         INT           PK
├── veteran_id         INT           FK → VETERAN
├── nominee_name       VARCHAR(150)  NOT NULL
├── relationship       VARCHAR(50)   NOT NULL
├── date_of_birth      DATE
├── aadhaar_last4      CHAR(4)
├── contact_phone      VARCHAR(15)
└── family_pension_pct DECIMAL(5,2)  DEFAULT 60.00
```

### RANK_HISTORY
```
RANK_HISTORY
├── history_id         INT           PK
├── veteran_id         INT           FK → VETERAN
├── previous_rank      VARCHAR(50)
├── new_rank           VARCHAR(50)   NOT NULL
├── change_date        DATETIME      NOT NULL
└── changed_by         VARCHAR(100)  (populated by trigger)
```

### AUDIT_LOG
```
AUDIT_LOG
├── log_id             INT           PK
├── veteran_id         INT           FK → VETERAN
├── table_name         VARCHAR(50)   NOT NULL
├── operation          ENUM('INSERT','UPDATE','DELETE')
├── old_value          TEXT
├── new_value          TEXT
└── log_timestamp      DATETIME      DEFAULT CURRENT_TIMESTAMP
```

---

## Relationships (Crow's Foot Notation)

```
REGIMENT ||──o< VETERAN
  One regiment has zero or many veterans.
  Every veteran belongs to exactly one regiment.

VETERAN ||──o< PENSION_RECORD
  One veteran has zero or many pension records.
  Every pension record belongs to exactly one veteran.

VETERAN ||──o< NOMINEE
  One veteran has zero or many nominees.
  Every nominee is registered against exactly one veteran.

VETERAN ||──o< RANK_HISTORY
  One veteran has zero or many rank history entries.
  Every rank history entry belongs to exactly one veteran.

VETERAN ||──o< AUDIT_LOG
  One veteran has zero or many audit log entries.
  Every audit log entry references exactly one veteran.
```

---

## ER Diagram (Text / ASCII)

```
┌─────────────┐         ┌──────────────────┐
│  REGIMENT   │         │     VETERAN      │
│─────────────│         │──────────────────│
│ regiment_id │──PK     │ veteran_id   PK  │
│ regiment_name         │ regiment_id  FK──┼──→ REGIMENT
│ regiment_code         │ service_number   │
│ raising_date          │ full_name        │
│ home_station          │ date_of_birth    │
│ cmd_officer           │ current_rank     │
└─────────────┘         │ veteran_status   │
                        └────────┬─────────┘
              ┌──────────────────┼──────────────────────┐
              │                  │                       │
              ▼                  ▼                       ▼
   ┌────────────────┐  ┌──────────────────┐  ┌────────────────┐
   │ PENSION_RECORD │  │     NOMINEE      │  │  RANK_HISTORY  │
   │────────────────│  │──────────────────│  │────────────────│
   │ pension_id  PK │  │ nominee_id    PK │  │ history_id  PK │
   │ veteran_id  FK │  │ veteran_id    FK │  │ veteran_id  FK │
   │ basic_pension  │  │ nominee_name     │  │ previous_rank  │
   │ dearness_allow │  │ relationship     │  │ new_rank       │
   │ medical_allow  │  │ family_pension   │  │ change_date    │
   │ disbursement_dt│  │ aadhaar_last4    │  │ changed_by     │
   │ ifsc_code      │  └──────────────────┘  └────────────────┘
   │ pension_status │
   └────────────────┘
              │
              ▼
   ┌────────────────┐
   │   AUDIT_LOG    │
   │────────────────│
   │ log_id      PK │
   │ veteran_id  FK │
   │ table_name     │
   │ operation      │
   │ old_value      │
   │ new_value      │
   │ log_timestamp  │
   └────────────────┘
```

---

## Cardinality Summary

| Relationship                    | Type        | Min–Max (Left) | Min–Max (Right) |
|---------------------------------|-------------|----------------|-----------------|
| REGIMENT → VETERAN              | One-to-Many | 1..1           | 0..N            |
| VETERAN → PENSION_RECORD        | One-to-Many | 1..1           | 0..N            |
| VETERAN → NOMINEE               | One-to-Many | 1..1           | 0..N            |
| VETERAN → RANK_HISTORY          | One-to-Many | 1..1           | 0..N            |
| VETERAN → AUDIT_LOG             | One-to-Many | 1..1           | 0..N            |

---

## Indexes

| Index Name            | Table          | Column(s)                  | Type    |
|-----------------------|----------------|----------------------------|---------|
| idx_veteran_regiment  | VETERAN        | regiment_id                | BTREE   |
| idx_veteran_status    | VETERAN        | veteran_status             | BTREE   |
| idx_pension_veteran   | PENSION_RECORD | veteran_id                 | BTREE   |
| idx_pension_status    | PENSION_RECORD | pension_status             | BTREE   |
| idx_pension_date      | PENSION_RECORD | disbursement_date          | BTREE   |
| idx_nominee_veteran   | NOMINEE        | veteran_id                 | BTREE   |
| idx_rank_veteran      | RANK_HISTORY   | veteran_id                 | BTREE   |
| idx_audit_veteran     | AUDIT_LOG      | veteran_id, log_timestamp  | BTREE   |
