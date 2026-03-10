# SOP Compliance & Training Tracker

A MySQL 8.0+ relational database system for tracking Standard Operating Procedure (SOP) compliance, employee training attendance, and acknowledgement status across departments in a regulated manufacturing environment (pharmaceutical / GMP context).

---

## Project Structure

| File | Purpose |
|------|---------|
| `01_schema.sql` | Database, tables, triggers, and stored procedures |
| `02_seed_data.sql` | Sample data — 15 employees, 8 SOPs, sessions, acknowledgements |
| `03_queries.sql` | 14 analytical queries (moderate + advanced) |

> **Run order is strict:** `01_schema.sql` → `02_seed_data.sql` → `03_queries.sql`

---

## Prerequisites

- MySQL 8.0 or higher (window function support required)
- A MySQL client: MySQL Workbench, DBeaver, or the `mysql` CLI

---

## Setup

```sql
-- From the MySQL CLI:
source /path/to/01_schema.sql;
source /path/to/02_seed_data.sql;
source /path/to/03_queries.sql;
```

After running `02_seed_data.sql`, a verification query at the end of the file prints row counts for all 8 tables as a sanity check.

---

## Database Schema

### Entity Overview

```
employees ──< sop_assignments >── sops ──< sop_revisions
                                   │
                    ┌──────────────┤
                    │              │
              training_sessions   acknowledgements
                    │
              training_attendance
```

### Tables

| Table | Description |
|-------|-------------|
| `employees` | All personnel; flags inactive with `is_active = 0` |
| `sops` | Master SOP list with version, effective date, review due date |
| `sop_revisions` | Full version history for every SOP |
| `sop_assignments` | Many-to-many: which employee is responsible for which SOP |
| `training_sessions` | Training events (Classroom / Online / On-the-Job) |
| `training_attendance` | Junction table: which employee attended which session |
| `acknowledgements` | Formal sign-off records tied to a specific SOP version |
| `revision_log` | Auto-populated by trigger when an SOP is revised |

---

## Trigger

### `after_sop_revision`
Fires **after INSERT** on `sop_revisions`. Automatically:
1. Bumps `sops.version` to the new version number.
2. Writes a log entry to `revision_log` flagging that all existing acknowledgements for that SOP are now **outdated** and require re-acknowledgement.

---

## Stored Procedures

### `get_compliance_gap(p_department)`
Returns a per-employee, per-SOP breakdown for a given department showing:
- Required SOP version
- Latest acknowledged version
- Status: `Acknowledged` or `Pending`

```sql
CALL get_compliance_gap('QC');
CALL get_compliance_gap('Production');
```

### `get_training_status()`
Returns training completion rate per department per SOP — how many assigned employees have attended at least one training session vs. total assigned.

```sql
CALL get_training_status();
```

---

## Analytical Queries

### Moderate (MQ1 – MQ6)

| Query | What it answers |
|-------|----------------|
| MQ1 | Employees who joined in the last 1 year and are active |
| MQ2 | Employees with ≥ 2 SOP assignments (GROUP BY + HAVING) |
| MQ3 | Training sessions conducted in the last 6 months |
| MQ4 | Total acknowledgement count per SOP across all versions |
| MQ5 | SOPs never assigned to any employee (LEFT JOIN + IS NULL) |
| MQ6 | Employees who acknowledged SOPs but never attended training (NOT EXISTS) |

### Advanced (AQ1 – AQ8)

| Query | What it answers | Key technique |
|-------|----------------|---------------|
| AQ1 | Employees with pending acknowledgements on current SOP versions | Correlated NOT EXISTS |
| AQ2 | Overall compliance rate (%) per department | COUNT + CASE + subquery |
| AQ3 | Each employee's ack count vs. their department average | `AVG() OVER (PARTITION BY)` |
| AQ4 | SOPs overdue for review with days overdue | `DATEDIFF` |
| AQ5 | Employees assigned > 3 SOPs but acknowledged < 50% | CTE + conditional COUNT |
| AQ6 | Pareto-style pending ack breakdown with running total | `SUM() OVER()` |
| AQ7 | Trainer-wise coverage — employees trained and sessions conducted | `GROUP_CONCAT` |
| AQ8 | SOP version progression showing old vs. new version side-by-side | `LAG()` window function |

---

## Sample Data Highlights

The seed data is intentionally designed to produce **non-trivial compliance gaps**:

- **Batch Manufacturing (SOP-PRD-001)** was revised from v1.0 → v2.0. Only Rajesh Kumar has acknowledged the latest version; Anita Sharma and Vikram Singh are pending.
- **HPLC Method Validation (SOP-QC-001)** was revised to v1.1. Priya Menon is compliant; Suresh Reddy has only the old v1.0 acknowledgement; Kavita Joshi has none.
- **Material Receipt (SOP-WH-002)** has zero acknowledgements — a complete compliance gap.
- **Sanjay Kulkarni** (Warehouse Manager) is marked inactive (`is_active = 0`) and is excluded from all compliance calculations.

---

## Key Design Decisions

- `sop_assignments` uses a composite `UNIQUE KEY (employee_id, sop_id)` to prevent duplicate assignments.
- `acknowledgements` stores `version_acked` explicitly, enabling accurate version-aware compliance checks even as SOPs evolve.
- The trigger approach to version bumping keeps `sops.version` in sync without requiring application-layer logic.
- All compliance queries filter `e.is_active = 1` to exclude terminated employees.

---

## License

For internal / educational use.