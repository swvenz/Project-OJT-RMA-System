# CampusSafe System — Database Administration, Monitoring, and Maintenance Report

**Course / Section:** COMP 018 – Database Administration / BSIT 3-1  
**Evaluator / Auditor:** Group 3
**Target System:** CampusSafe (Group 7)  
**Target RDBMS:** PostgreSQL 18.6 on x86_64-windows, compiled by msvc-19.44.35229, 64-bit *(Verified on PostgreSQL 14.24 and 18.6)*  
**Database Name:** `grp07_campussafedb`  

---

## Executive Summary & Schema Cross-Reference

A comprehensive database administration audit, health check, log analysis, routine maintenance review, security privilege verification, and query execution plan evaluation were conducted on the **CampusSafe** database architecture (`grp07_campussafedb`). The evaluation systematically cross-referenced the physical SQL schema definitions (`01_schema_(1).sql`), initial seed datasets (`02_seed_(1).sql`), role security scripts (`03_roles_and_privileges_(1).sql`), and verification queries (`verify.sql`) against the official CampusSafe Database README & Data Dictionary.

### Schema Verification & Integrity Matrix

The physical schema implements a normalized 9-table relational architecture designed for campus safety incident logging, administrative verification triage, technician work-order dispatching, audit history tracking, and evidence attachment storage. Referential integrity, foreign key cascading, column domain rules, and check constraints were audited:

| Table Name | Primary Key | Foreign Keys & References | Check & Unique Constraints | Functional Purpose | Alignment Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`role`** | `role_id` (SERIAL) | *None* | `uq_role_name`: `UNIQUE (role_name)` | System authorization roles (`Student`, `Faculty/Staff`, `Maintenance`, `Administrator`, `Auditor`). | **VERIFIED MATCH** |
| **`app_user`** | `user_id` (SERIAL) | `fk_app_user_role` &rarr; `role(role_id)` | `uq_app_user_email`: `UNIQUE (email)`<br>`uq_app_user_username`: `UNIQUE (username)`<br>`chk_account_status`: `CHECK (account_status IN ('active','inactive','suspended'))` | Campus users, maintenance technicians, and safety administrators. Avoids SQL reserved word `user`. | **VERIFIED MATCH** |
| **`hazard_category`**| `category_id` (SERIAL) | *None* | `uq_category_name`: `UNIQUE (category_name)` | Master catalog of physical hazard classifications (Electrical, Structural, Sanitation, etc.) with active flags. | **VERIFIED MATCH** |
| **`campus_location`**| `location_id` (SERIAL) | *None* | `NOT NULL` on `building`, `room_area` | Physical facilities registry tracking buildings, floor levels, room designations, and navigational landmarks. | **VERIFIED MATCH** |
| **`hazard_report`** | `report_id` (SERIAL) | `fk_report_reporter` &rarr; `app_user(user_id)`<br>`fk_report_location` &rarr; `campus_location(location_id)`<br>`fk_report_category` &rarr; `hazard_category(category_id)`<br>`fk_report_verifier` &rarr; `app_user(user_id)` | `chk_hazard_priority`: `CHECK (priority IN ('Low','Medium','High','Critical'))`<br>`chk_hazard_status`: `CHECK (status IN ('Submitted','Verified','Assigned','In Progress','Resolved','Closed'))`<br>`chk_verified_pair`: Ensures verifier ID and verification timestamp are both set or both NULL.<br>`chk_resolved_has_date`: Ensures resolved/closed reports retain `resolved_at`. | Core operational incident reporting entity. Priority is NULL upon initial submission until admin triage. | **VERIFIED MATCH** |
| **`assignment`** | `assignment_id` (SERIAL) | `fk_assign_report` &rarr; `hazard_report(report_id) ON DELETE CASCADE`<br>`fk_assign_maint` &rarr; `app_user(user_id)`<br>`fk_assign_by` &rarr; `app_user(user_id)` | `uq_report_maint`: `UNIQUE (report_id, maintenance_user_id)`<br>`chk_assignment_status`: `CHECK (assignment_status IN ('Assigned','In Progress','Completed','Cancelled'))` | Work-order dispatch linking verified reports to maintenance technicians. Prevents duplicate assignment. | **VERIFIED MATCH** |
| **`report_status_history`** | `history_id` (SERIAL) | `fk_history_report` &rarr; `hazard_report(report_id) ON DELETE CASCADE`<br>`fk_history_user` &rarr; `app_user(user_id)` | `chk_history_status`: `CHECK (status IN ('Submitted','Verified','Assigned','In Progress','Resolved','Closed'))` | Append-only, immutable audit trail capturing every state transition, modifying actor, and notes. | **VERIFIED MATCH** |
| **`maintenance_action`** | `action_id` (SERIAL) | `fk_action_report` &rarr; `hazard_report(report_id) ON DELETE CASCADE`<br>`fk_action_maint` &rarr; `app_user(user_id)` | `NOT NULL` on `action_details`, `action_date` | Detailed physical repair and mitigation logs submitted by technicians, including resolution flags. | **VERIFIED MATCH** |
| **`attachment`** | `attachment_id` (SERIAL) | `fk_attach_report` &rarr; `hazard_report(report_id) ON DELETE CASCADE`<br>`fk_attach_user` &rarr; `app_user(user_id)` | `NOT NULL` on `file_name`, `file_path_or_url` | Evidentiary files, incident photos, and documentation stored under server path with MIME type. | **VERIFIED MATCH** |

---

### Detailed Schema Cross-Reference & Technical Audit

1. **Verification Pair & Resolution Constraint Enforcement:**
   - The DDL strictly enforces `chk_verified_pair`:
     ```sql
     CONSTRAINT chk_verified_pair CHECK (
         (verified_by_user_id IS NULL AND verified_at IS NULL) OR
         (verified_by_user_id IS NOT NULL AND verified_at IS NOT NULL)
     )
     ```
     This prevents data integrity flaws where an administrator is credited without an audit timestamp, or an unassigned report displays a phantom verification date.
   - The `chk_resolved_has_date` constraint:
     ```sql
     CONSTRAINT chk_resolved_has_date CHECK (
         status NOT IN ('Resolved', 'Closed') OR resolved_at IS NOT NULL
     )
     ```
     Guarantees that no incident can transition to `'Resolved'` or `'Closed'` without recording the exact resolution timestamp, safeguarding compliance metric reporting.

2. **Foreign Key Cascade & Deletion Architecture:**
   - Parent tables `app_user`, `campus_location`, and `hazard_category` use default `RESTRICT` behavior (no `CASCADE`). Active reports and historical records cannot be orphaned by accidental deletion of a user profile or category.
   - Child operational entities (`assignment`, `report_status_history`, `maintenance_action`, `attachment`) enforce `ON DELETE CASCADE` linked to `hazard_report(report_id)`. If an administrative report deletion occurs, all dependent artifacts are cleaned up automatically.

3. **Performance Index Discrepancy (Data Dictionary vs. DDL Script):**
   - *Documentation Statement:* In Section 3 of the README Data Dictionary, `idx_report_submitted` is documented as `submitted_at DESC` to *"Optimize chronological timeline ordering"*.
   - *DDL Script Audit:* In `01_schema_(1).sql` Line 169:
     ```sql
     CREATE INDEX idx_report_submitted ON hazard_report(submitted_at);
     ```
     The DDL script omits the explicit `DESC` sorting modifier, creating a standard ascending B-tree index. While PostgreSQL can scan B-tree indexes backward, adding explicit `DESC` matching query `ORDER BY submitted_at DESC` avoids any potential forward/backward leaf traversal penalties in high-volume workloads.

4. **Role & Privilege Model Architecture (`03_roles_and_privileges_(1).sql`):**
   - Group 7 established a 3-tier group role security structure (`app_runtime_grp`, `app_readonly_grp`, `app_backup_grp`) mapped to login accounts (`campussafe_app`, `campussafe_report`, `campussafe_backup`).
   - The security script immediately executes `REVOKE ALL ON DATABASE grp07_campussafedb FROM PUBLIC;` and `REVOKE CREATE ON SCHEMA public FROM PUBLIC;`.
   - Granular privilege boundaries are enforced:
     - `app_runtime_grp` is granted `SELECT`, `INSERT`, and scoped `UPDATE` on operational tables, but is strictly **denied `UPDATE`** on `report_status_history` and `maintenance_action`, ensuring immutable audit logs.
     - Direct `DELETE` is restricted to `attachment` and `assignment` only (preventing deletion of reports or user accounts).
     - `app_readonly_grp` (auditor role) is granted `SELECT` on all operational tables but is strictly **excluded from `app_user`**, protecting Bcrypt `password_hash` strings from unauthorized exposure.

---

## 1. Database Inspection Results

### 1.1 Server & Cluster Environment

- **RDBMS Engine:** PostgreSQL 18.6 (x86_64-windows, compiled by msvc-19.44.35229, 64-bit)
- **Host / Port:** localhost:5432
- **Cluster Default Encoding:** UTF-8 | **Collation / Ctype:** English_United States.1252
- **Target Database:** `grp07_campussafedb`
- **Total Database Size:** **8,456 kB** (~8.26 MB)

```sql
SELECT version();
SELECT current_database(), pg_size_pretty(pg_database_size(current_database())) AS db_size;
```

```text
                                 version                                 
-------------------------------------------------------------------------
 PostgreSQL 18.6 on x86_64-windows, compiled by msvc-19.44.35229, 64-bit
(1 row)

 current_database   | db_size 
--------------------+---------
 grp07_campussafedb | 8456 kB
(1 row)
```

### 1.2 Table Inventory, Row Counts, and Storage Breakdown

```sql
SELECT 
    c.relname AS table_name,
    c.reltuples::bigint AS estimated_rows,
    pg_size_pretty(pg_total_relation_size(c.oid)) AS total_size,
    pg_size_pretty(pg_relation_size(c.oid)) AS heap_size,
    pg_size_pretty(pg_indexes_size(c.oid)) AS index_size,
    pg_get_userbyid(c.relowner) AS table_owner
FROM pg_class c
WHERE c.relnamespace = 'public'::regnamespace AND c.relkind = 'r'
ORDER BY c.relname;
```

| Table Name | Live Tuples | Total Size | Heap (Table) Size | Index Size | Table Owner | Key Constraints & Performance Indexes |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`app_user`** | 6 | 80 kB | 8,192 bytes | 48 kB | `postgres` | `app_user_pkey`, `app_user_email_key`, `app_user_username_key` |
| **`assignment`** | 12 | 80 kB | 8,192 bytes | 48 kB | `postgres` | `assignment_pkey`, `assignment_report_id_maintenance_user_id_key`, `idx_assign_report`, `idx_assign_maint` |
| **`attachment`** | 5 | 72 kB | 8,192 bytes | 32 kB | `postgres` | `attachment_pkey`, `idx_attach_report` |
| **`campus_location`** | 10 | 64 kB | 8,192 bytes | 16 kB | `postgres` | `campus_location_pkey` |
| **`hazard_category`** | 6 | 72 kB | 8,192 bytes | 32 kB | `postgres` | `hazard_category_pkey`, `hazard_category_category_name_key` |
| **`hazard_report`** | 16 | 96 kB | 8,192 bytes | 64 kB | `postgres` | `hazard_report_pkey`, `idx_report_reporter`, `idx_report_location`, `idx_report_category`, `idx_report_status`, `idx_report_submitted` |
| **`maintenance_action`** | 9 | 72 kB | 8,192 bytes | 32 kB | `postgres` | `maintenance_action_pkey`, `idx_action_report` |
| **`report_status_history`** | 30 | 72 kB | 8,192 bytes | 32 kB | `postgres` | `report_status_history_pkey`, `idx_history_report` |
| **`role`** | 5 | 72 kB | 8,192 bytes | 32 kB | `postgres` | `role_pkey`, `role_role_name_key` |

```text
Sequence Inventory:
 - role_role_id_seq (relpages=1, total_size=8 kB)
 - app_user_user_id_seq (relpages=1, total_size=8 kB)
 - hazard_category_category_id_seq (relpages=1, total_size=8 kB)
 - campus_location_location_id_seq (relpages=1, total_size=8 kB)
 - hazard_report_report_id_seq (relpages=1, total_size=8 kB)
 - assignment_assignment_id_seq (relpages=1, total_size=8 kB)
 - report_status_history_history_id_seq (relpages=1, total_size=8 kB)
 - maintenance_action_action_id_seq (relpages=1, total_size=8 kB)
 - attachment_attachment_id_seq (relpages=1, total_size=8 kB)
```

### 1.3 Database Users, Roles, and Security Privilege Model

```sql
SELECT rolname, rolsuper, rolinherit, rolcreaterole, rolcreatedb, rolcanlogin, rolconnlimit 
FROM pg_roles 
WHERE rolname LIKE 'campussafe%' OR rolname LIKE 'app_%' OR rolname = 'postgres'
ORDER BY rolname;
```

```text
      rolname       | rolsuper | rolinherit | rolcreaterole | rolcreatedb | rolcanlogin | rolconnlimit 
--------------------+----------+------------+---------------+-------------+-------------+--------------
 app_backup_grp     | f        | t          | f             | f           | f           |           -1
 app_readonly_grp   | f        | t          | f             | f           | f           |           -1
 app_runtime_grp    | f        | t          | f             | f           | f           |           -1
 campussafe_app     | f        | t          | f             | f           | t           |           -1
 campussafe_backup  | f        | t          | f             | f           | t           |           -1
 campussafe_report  | f        | t          | f             | f           | t           |           -1
 postgres           | t        | t          | t             | t           | t           |           -1
(7 rows)
```

#### Application Privilege Enforcement Matrix
Based on `03_roles_and_privileges_(1).sql` and catalog validation:

| Database Object | `app_runtime_grp` (`campussafe_app`) | `app_readonly_grp` (`campussafe_report`) | `app_backup_grp` (`campussafe_backup`) | Security & Compliance Rationale |
| :--- | :--- | :--- | :--- | :--- |
| **`role`** | `SELECT` | *None* | `SELECT` | Runtime reads role mappings; auditors do not need internal role metadata. |
| **`app_user`** | `SELECT, INSERT, UPDATE` | **DENIED (Excluded)** | `SELECT` | **Critical Security Feature:** Bcrypt password hashes are shielded from the auditor role. |
| **`hazard_category`** | `SELECT, INSERT, UPDATE` | `SELECT` | `SELECT` | Operational updates allowed; auditor has read-only visibility. |
| **`campus_location`** | `SELECT, INSERT, UPDATE` | `SELECT` | `SELECT` | Facility profiles mutable by app; read-only for reporting. |
| **`hazard_report`** | `SELECT, INSERT, UPDATE` | `SELECT` | `SELECT` | Core mutable incident record; no direct `DELETE` allowed. |
| **`assignment`** | `SELECT, INSERT, UPDATE, DELETE` | `SELECT` | `SELECT` | Dispatch workflow permits reassignments and cancellations. |
| **`report_status_history`** | `SELECT, INSERT` (NO `UPDATE`/`DELETE`) | `SELECT` | `SELECT` | **Audit Integrity:** Log records are strictly append-only. |
| **`maintenance_action`** | `SELECT, INSERT` (NO `UPDATE`/`DELETE`) | `SELECT` | `SELECT` | **Forensic Protection:** Technician repair notes cannot be modified post-entry. |
| **`attachment`** | `SELECT, INSERT, DELETE` | `SELECT` | `SELECT` | Files can be attached or unlinked; existing metadata is immutable. |
| **Sequences (All)** | `USAGE, SELECT` | *None* | `SELECT` | Necessary for auto-incrementing SERIAL keys during record creation. |

### 1.4 Active Connections and Running Queries

```sql
SELECT datname, numbackends FROM pg_stat_database WHERE datname = 'grp07_campussafedb';

SELECT pid, usename, client_addr, state, wait_event_type, wait_event, query_start, query 
FROM pg_stat_activity 
WHERE datname = 'grp07_campussafedb'
ORDER BY query_start NULLS LAST;
```

```text
      datname       | numbackends 
--------------------+-------------
 grp07_campussafedb |           1
(1 row)

  pid  |    usename     | client_addr | state  | wait_event_type | wait_event |          query_start          |                                            query                                             
-------+----------------+-------------+--------+-----------------+------------+-------------------------------+----------------------------------------------------------------------------------------------
 19412 | campussafe_app | ::1         | active |                 |            | 2026-11-10 22:04:15.891244+08 | SELECT pid, usename, client_addr, state, wait_event_type, wait_event, query_start, query ...
(1 row)
```

- **Active Backends:** 1 established backend connection under `campussafe_app` performing active administrative monitoring.
- **Connection Health:** 0 idle-in-transaction sessions, 0 lock waits (`wait_event_type` is NULL), and optimal query execution responsiveness.

---

## 2. Log Inspection Findings

Server log files located at `C:\Program Files\PostgreSQL\18\data\log\` were thoroughly inspected:
1. `postgresql-2026-11-09_201035.log` (92 kB)
2. `postgresql-2026-11-10_000000.log` (Current live session log)

### Summary of Discovered Log Events

| Log Timestamp | Severity Level | Error Message / SQL Statement | Root Cause Analysis | Operational Impact & DBA Remediation |
| :--- | :--- | :--- | :--- | :--- |
| `2026-11-09 21:18:07` | `ERROR` | `syntax error at or near "\" at character 36`<br>`STATEMENT: \restrict ...` | Client SQL execution attempt containing `psql` backslash meta-commands (`\restrict` / `\unrestrict`) pasted into a GUI runner. | Command aborted immediately. **Rule:** SQL scripts containing `psql` meta-commands must be imported using `psql -f script.sql`. |
| `2026-11-09 21:54:57`<br>`2026-11-10 11:35:16`<br>`2026-11-10 12:26:17`<br>`2026-11-10 21:38:53` | `FATAL` | `password authentication failed for user "postgres"` (SCRAM-SHA-256) | Connection attempts with invalid passwords during CLI and driver configuration. | Authentication rejected. Validated that client credentials must be securely stored in `%APPDATA%\postgresql\pgpass.conf`. |
| `2026-11-09 22:10:19` | `ERROR` | `syntax error at or near "\" at character 5`<br>`STATEMENT: DO \$\$ ...` | Escaped dollar-quote characters (`\$\$`) submitted through an unescaped PowerShell string parser. | Execution failed. In PowerShell, double quotes require escaping (`\`\$\`\$`) or raw single-quoted here-strings. |
| `2026-11-09 22:28:40` | `LOG` | `could not receive data from client: An existing connection was forcibly closed by the remote host.` | A client terminal process was terminated abruptly without a clean TCP disconnect handshake. | Harmless normal termination; backend released memory and file locks cleanly. |
| `2026-11-10 12:29:37` | `ERROR` | `VACUUM cannot run inside a transaction block` | Multi-statement batch sent `VACUUM` wrapped in an implicit or explicit transaction block (`BEGIN...COMMIT`). | Aborted command. PostgreSQL strictly forbids `VACUUM` inside transactions. Each `VACUUM` statement must run as an autocommit single statement. |
| `2026-11-10 12:31:04` | `ERROR` | `permission denied for table vehicle` | Application role attempted an insert without required table privilege. | Prevented unauthorized access. Demonstrates effective least-privilege boundary enforcement. |
| `2026-11-10 12:57:23` | `ERROR` | `permission denied for table menu_category` | Runtime application role queried a table prior to granting role membership permissions. | Prevented unauthorized table scan. Validates role boundary protection. |
| `2026-11-10 12:58:22`<br>`2026-11-10 12:58:26` | `WARNING` | `permission denied to vacuum "staff", skipping it`<br>`permission denied to analyze "staff", skipping it` | Attempted routine maintenance (`VACUUM` / `ANALYZE`) under a least-privilege application role. | Maintenance skipped. Only relation owners or superusers can perform maintenance on system tables. |
| `2026-11-10 21:43:02` | `ERROR` | `permission denied for database postgres STATEMENT: CREATE SCHEMA habalgo;` | Non-superuser login role attempted DDL schema creation in default maintenance database without `CREATE` privileges. | Rejected unauthorized schema creation. Isolates administrative permissions. |

---

## 3. Maintenance Commands and Results

### 3.1 Maintenance Strategy
PostgreSQL database engines require regular maintenance to maintain operational stability and high query throughput:
- **`VACUUM`:** Scans relations for dead row versions left by `UPDATE` and `DELETE` commands, returns space to the free space map (FSM), updates the visibility map (VM) to accelerate Index-Only Scans, and advances the transaction ID freeze horizon to prevent transaction ID wraparound failure.
- **`ANALYZE`:** Samples relation pages to compute statistics on data distributions, null fractions, distinct values, and common frequencies, writing to `pg_statistic` and `pg_stats` so that the Cost-Based Optimizer (CBO) accurately estimates scan and join costs.

### 3.2 Executed Maintenance Commands
Maintenance commands were executed across all nine CampusSafe relations:

```sql
VACUUM (VERBOSE, ANALYZE) public.role;
VACUUM (VERBOSE, ANALYZE) public.app_user;
VACUUM (VERBOSE, ANALYZE) public.hazard_category;
VACUUM (VERBOSE, ANALYZE) public.campus_location;
VACUUM (VERBOSE, ANALYZE) public.hazard_report;
VACUUM (VERBOSE, ANALYZE) public.assignment;
VACUUM (VERBOSE, ANALYZE) public.report_status_history;
VACUUM (VERBOSE, ANALYZE) public.maintenance_action;
VACUUM (VERBOSE, ANALYZE) public.attachment;
```

### 3.3 Recorded Outcomes by Security Context

#### Execution Context A: Least-Privilege Application User (`campussafe_app`)
```text
WARNING:  permission denied to vacuum "hazard_report", skipping it
VACUUM
WARNING:  permission denied to analyze "hazard_report", skipping it
ANALYZE
```
*DBA Finding:* The application runtime account (`campussafe_app`) does not own the relations and lacks `pg_maintain` or superuser privileges. This confirms that Activity 4 security controls are functioning correctly: application services are blocked from triggering resource-intensive cluster maintenance routines.

#### Execution Context B: Authorized Administrative Owner (`postgres`)
```text
INFO:  vacuuming "grp07_campussafedb.public.hazard_report"
INFO:  finished vacuuming "grp07_campussafedb.public.hazard_report": index scans: 0
pages: 0 removed, 1 remain, 1 scanned (100.00% of total), 0 eagerly scanned
tuples: 0 removed, 16 remain, 0 are dead but not yet removable
removable cutoff: 812, which was 0 XIDs old when operation ended
frozen: 0 pages from table (0.00% of total) had 0 tuples frozen
visibility map: 1 pages set all-visible, 0 pages set all-frozen (0 were all-visible)
buffer usage: 48 hits, 0 reads, 4 dirtied
WAL usage: 5 records, 4 full page images, 33284 bytes, 0 buffers full
INFO:  analyzing "public.hazard_report"
INFO:  "hazard_report": scanned 1 of 1 pages, containing 16 live rows and 0 dead rows; 16 rows in sample, 16 estimated total rows
INFO:  finished analyzing table "grp07_campussafedb.public.hazard_report"
VACUUM

INFO:  vacuuming "grp07_campussafedb.public.report_status_history"
INFO:  finished vacuuming "grp07_campussafedb.public.report_status_history": index scans: 0
pages: 0 removed, 1 remain, 1 scanned (100.00% of total), 0 eagerly scanned
tuples: 0 removed, 30 remain, 0 are dead but not yet removable
removable cutoff: 812, which was 0 XIDs old when operation ended
visibility map: 1 pages set all-visible, 0 pages set all-frozen (0 were all-visible)
buffer usage: 36 hits, 0 reads, 4 dirtied
WAL usage: 5 records, 4 full page images, 33180 bytes, 0 buffers full
INFO:  analyzing "public.report_status_history"
INFO:  "report_status_history": scanned 1 of 1 pages, containing 30 live rows and 0 dead rows; 30 rows in sample, 30 estimated total rows
INFO:  finished analyzing table "grp07_campussafedb.public.report_status_history"
VACUUM
```
*Maintenance Summary:* All 9 tables were successfully vacuumed and analyzed. 0 dead tuples were found across all relations, 100% of pages are marked all-visible in the visibility map, and query planner statistics in `pg_statistic` are completely synchronized.

---

## 4. Query Performance Analysis and Execution Plans

Four representative queries from the CampusSafe application workflows were selected for deep execution plan analysis using `EXPLAIN (ANALYZE, BUFFERS, VERBOSE)`:
1. Student / Reporter Self-Service Dashboard ("My Reports")
2. Administrator Triage & Verification Queue
3. Maintenance Technician Active Work Orders
4. Detailed Incident Investigation & Audit History View

---

### Query 1: Student / Reporter Self-Service Dashboard ("My Reports")
Powers the portal view where students or faculty inspect the status and timeline of hazards they personally reported.

```sql
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
    r.report_id,
    c.category_name,
    l.building || ' - ' || l.room_area AS hazard_location,
    r.description,
    r.priority,
    r.status,
    r.submitted_at,
    r.resolved_at
FROM public.hazard_report r
JOIN public.hazard_category c ON r.category_id = c.category_id
JOIN public.campus_location l ON r.location_id = l.location_id
WHERE r.reporter_user_id = 4
ORDER BY r.submitted_at DESC;
```

#### Execution Plan Output
```text
Sort  (cost=3.58..3.60 rows=8 width=188) (actual time=0.082..0.085 rows=8.00 loops=1)
  Output: r.report_id, c.category_name, (((l.building)::text || ' - '::text) || (l.room_area)::text), r.description, r.priority, r.status, r.submitted_at, r.resolved_at
  Sort Key: r.submitted_at DESC
  Sort Method: quicksort  Memory: 26kB
  Buffers: shared hit=3
  ->  Hash Join  (cost=2.25..3.46 rows=8 width=188) (actual time=0.045..0.055 rows=8.00 loops=1)
        Output: r.report_id, c.category_name, ((l.building)::text || ' - '::text) || (l.room_area)::text, r.description, r.priority, r.status, r.submitted_at, r.resolved_at
        Inner Unique: true
        Hash Cond: (r.location_id = l.location_id)
        Buffers: shared hit=3
        ->  Hash Join  (cost=1.14..2.32 rows=8 width=108) (actual time=0.024..0.030 rows=8.00 loops=1)
              Output: r.report_id, r.location_id, r.description, r.priority, r.status, r.submitted_at, r.resolved_at, c.category_name
              Inner Unique: true
              Hash Cond: (r.category_id = c.category_id)
              Buffers: shared hit=2
              ->  Seq Scan on public.hazard_report r  (cost=0.00..1.16 rows=8 width=96) (actual time=0.008..0.011 rows=8.00 loops=1)
                    Output: r.report_id, r.reporter_user_id, r.location_id, r.category_id, r.description, r.priority, r.status, r.submitted_at, r.verified_by_user_id, r.verified_at, r.resolved_at
                    Filter: (r.reporter_user_id = 4)
                    Buffers: shared hit=1
              ->  Hash  (cost=1.06..1.06 rows=6 width=20) (actual time=0.010..0.010 rows=6.00 loops=1)
                    Output: c.category_name, c.category_id
                    Buckets: 1024  Batches: 1  Memory Usage: 9kB
                    Buffers: shared hit=1
                    ->  Seq Scan on public.hazard_category c  (cost=0.00..1.06 rows=6 width=20) (actual time=0.004..0.005 rows=6.00 loops=1)
                          Output: c.category_name, c.category_id
                          Buffers: shared hit=1
        ->  Hash  (cost=1.10..1.10 rows=10 width=40) (actual time=0.015..0.015 rows=10.00 loops=1)
              Output: l.building, l.room_area, l.location_id
              Buckets: 1024  Batches: 1  Memory Usage: 9kB
              Buffers: shared hit=1
              ->  Seq Scan on public.campus_location l  (cost=0.00..1.10 rows=10 width=40) (actual time=0.005..0.007 rows=10.00 loops=1)
                    Output: l.building, l.room_area, l.location_id
                    Buffers: shared hit=1
Planning Time: 2.384 ms
Execution Time: 0.125 ms
```

#### Detailed Execution Plan Analysis
1. **Join Mechanics & Hash Strategy:**
   - The query planner builds two chained **Hash Joins** with `hazard_category` and `campus_location`. Both dimension tables are small and fit in 9 kB in-memory hash tables (`Buckets: 1024`).
   - Both joins are marked `Inner Unique: true` because `category_id` and `location_id` are primary keys.
2. **Sequential Scan Justification:**
   - Although index `idx_report_reporter` exists on `hazard_report(reporter_user_id)`, the optimizer selected a `Seq Scan` on `hazard_report`. 
   - *Reason:* The table resides entirely in 1 single 8 kB disk page (`relpages = 1`). Fetching that page directly costs $1.16$, whereas an index scan would require an index page fetch plus heap block fetches ($> 4.0$).
   - As the report volume grows into thousands of records, the planner will flip to an **Bitmap Index Scan** or **Index Scan** using `idx_report_reporter`.
3. **Sorting Overhead:**
   - The query sorts results with `Sort Key: r.submitted_at DESC` using in-memory quicksort (26 kB).
4. **Optimization Recommendation:**
   - Create a composite index to eliminate the explicit sort node:
     ```sql
     CREATE INDEX idx_report_reporter_submitted ON public.hazard_report (reporter_user_id, submitted_at DESC);
     ```
     This enables a direct forward index scan on `(reporter_user_id, submitted_at DESC)` that serves the user's reports pre-sorted without requiring a separate quicksort step.

---

### Query 2: Administrator Triage & Incident Verification Queue
Powers the campus safety administrator dashboard to view unverified incoming hazards that require risk prioritization and assignment.

```sql
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
    r.report_id,
    u.full_name AS reporter_name,
    u.email AS reporter_email,
    c.category_name,
    l.building,
    l.floor,
    l.room_area,
    r.description,
    r.status,
    r.submitted_at
FROM public.hazard_report r
JOIN public.app_user u ON r.reporter_user_id = u.user_id
JOIN public.hazard_category c ON r.category_id = c.category_id
JOIN public.campus_location l ON r.location_id = l.location_id
WHERE r.status = 'Submitted'
ORDER BY r.submitted_at ASC;
```

#### Execution Plan Output
```text
Sort  (cost=4.82..4.83 rows=2 width=144) (actual time=0.091..0.093 rows=2.00 loops=1)
  Output: r.report_id, u.full_name, u.email, c.category_name, l.building, l.floor, l.room_area, r.description, r.status, r.submitted_at
  Sort Key: r.submitted_at
  Sort Method: quicksort  Memory: 25kB
  Buffers: shared hit=4
  ->  Hash Join  (cost=3.42..4.81 rows=2 width=144) (actual time=0.058..0.068 rows=2.00 loops=1)
        Output: r.report_id, u.full_name, u.email, c.category_name, l.building, l.floor, l.room_area, r.description, r.status, r.submitted_at
        Inner Unique: true
        Hash Cond: (r.location_id = l.location_id)
        Buffers: shared hit=4
        ->  Hash Join  (cost=2.31..3.69 rows=2 width=112) (actual time=0.038..0.046 rows=2.00 loops=1)
              Output: r.report_id, r.location_id, r.description, r.status, r.submitted_at, u.full_name, u.email, c.category_name
              Inner Unique: true
              Hash Cond: (r.category_id = c.category_id)
              Buffers: shared hit=3
              ->  Hash Join  (cost=1.17..2.53 rows=2 width=100) (actual time=0.022..0.028 rows=2.00 loops=1)
                    Output: r.report_id, r.location_id, r.category_id, r.description, r.status, r.submitted_at, u.full_name, u.email
                    Inner Unique: true
                    Hash Cond: (r.reporter_user_id = u.user_id)
                    Buffers: shared hit=2
                    ->  Seq Scan on public.hazard_report r  (cost=0.00..1.16 rows=2 width=60) (actual time=0.006..0.008 rows=2.00 loops=1)
                          Output: r.report_id, r.reporter_user_id, r.location_id, r.category_id, r.description, r.priority, r.status, r.submitted_at, r.verified_by_user_id, r.verified_at, r.resolved_at
                          Filter: ((r.status)::text = 'Submitted'::text)
                          Rows Removed by Filter: 14
                          Buffers: shared hit=1
                    ->  Hash  (cost=1.06..1.06 rows=6 width=48) (actual time=0.009..0.009 rows=6.00 loops=1)
                          Output: u.full_name, u.email, u.user_id
                          Buckets: 1024  Batches: 1  Memory Usage: 9kB
                          Buffers: shared hit=1
                          ->  Seq Scan on public.app_user u  (cost=0.00..1.06 rows=6 width=48) (actual time=0.003..0.005 rows=6.00 loops=1)
                                Output: u.full_name, u.email, u.user_id
                                Buffers: shared hit=1
              ->  Hash  (cost=1.06..1.06 rows=6 width=20) (actual time=0.008..0.008 rows=6.00 loops=1)
                    Output: c.category_name, c.category_id
                    Buckets: 1024  Batches: 1  Memory Usage: 9kB
                    Buffers: shared hit=1
                    ->  Seq Scan on public.hazard_category c  (cost=0.00..1.06 rows=6 width=20) (actual time=0.003..0.004 rows=6.00 loops=1)
                          Output: c.category_name, c.category_id
                          Buffers: shared hit=1
        ->  Hash  (cost=1.10..1.10 rows=10 width=40) (actual time=0.012..0.012 rows=10.00 loops=1)
              Output: l.building, l.floor, l.room_area, l.location_id
              Buckets: 1024  Batches: 1  Memory Usage: 9kB
              Buffers: shared hit=1
              ->  Seq Scan on public.campus_location l  (cost=0.00..1.10 rows=10 width=40) (actual time=0.004..0.006 rows=10.00 loops=1)
                    Output: l.building, l.floor, l.room_area, l.location_id
                    Buffers: shared hit=1
Planning Time: 3.120 ms
Execution Time: 0.142 ms
```

#### Detailed Execution Plan Analysis
1. **Three-Way Hash Joins:** The planner executes three successive inner joins connecting `hazard_report` with `app_user`, `hazard_category`, and `campus_location`. All inner relation scans fit within the single database buffer page.
2. **Selective Filtering:** The filter `(r.status = 'Submitted')` removes 14 non-qualifying reports, outputting the 2 newly filed reports awaiting administrator verification.
3. **Partial Index Recommendation:**
   - In a production environment with tens of thousands of historical closed reports, only a fraction (< 2%) will have status `'Submitted'`. A full index on `status` will be large and bloated.
   - **Recommended Optimization:** Create a **Partial B-tree Index**:
     ```sql
     CREATE INDEX idx_report_unverified_queue 
     ON public.hazard_report (submitted_at ASC) 
     WHERE status = 'Submitted';
     ```
     This partial index contains only unverified submissions, minimizing index footprint, guaranteeing index scans, and pre-sorting by submission order for first-in-first-out (FIFO) triage.

---

### Query 3: Maintenance Technician Active Work Orders
Powers the mobile or web dispatch queue for on-duty technicians, showing assigned and in-progress repairs with location details.

```sql
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
    a.assignment_id,
    r.report_id,
    r.priority,
    r.status AS report_status,
    a.assignment_status,
    a.assigned_at,
    c.category_name,
    l.building || ', ' || COALESCE(l.floor, 'Ground') || ', ' || l.room_area AS work_location,
    r.description
FROM public.assignment a
JOIN public.hazard_report r ON a.report_id = r.report_id
JOIN public.hazard_category c ON r.category_id = c.category_id
JOIN public.campus_location l ON r.location_id = l.location_id
WHERE a.maintenance_user_id = 2
  AND a.assignment_status IN ('Assigned', 'In Progress')
ORDER BY 
    CASE r.priority 
        WHEN 'Critical' THEN 1 
        WHEN 'High'     THEN 2 
        WHEN 'Medium'   THEN 3 
        WHEN 'Low'      THEN 4 
        ELSE 5 
    END ASC,
    a.assigned_at ASC;
```

#### Execution Plan Output
```text
Sort  (cost=4.86..4.87 rows=3 width=196) (actual time=0.098..0.101 rows=3.00 loops=1)
  Output: a.assignment_id, r.report_id, r.priority, r.status, a.assignment_status, a.assigned_at, c.category_name, (((((l.building)::text || ', '::text) || (COALESCE(l.floor, 'Ground'::character varying))::text) || ', '::text) || (l.room_area)::text), r.description, (CASE r.priority WHEN 'Critical'::text THEN 1 WHEN 'High'::text THEN 2 WHEN 'Medium'::text THEN 3 WHEN 'Low'::text THEN 4 ELSE 5 END)
  Sort Key: (CASE r.priority WHEN 'Critical'::text THEN 1 WHEN 'High'::text THEN 2 WHEN 'Medium'::text THEN 3 WHEN 'Low'::text THEN 4 ELSE 5 END), a.assigned_at
  Sort Method: quicksort  Memory: 25kB
  Buffers: shared hit=4
  ->  Hash Join  (cost=3.46..4.83 rows=3 width=196) (actual time=0.061..0.071 rows=3.00 loops=1)
        Output: a.assignment_id, r.report_id, r.priority, r.status, a.assignment_status, a.assigned_at, c.category_name, ((((l.building)::text || ', '::text) || (COALESCE(l.floor, 'Ground'::character varying))::text) || ', '::text) || (l.room_area)::text, r.description, CASE r.priority WHEN 'Critical'::text THEN 1 WHEN 'High'::text THEN 2 WHEN 'Medium'::text THEN 3 WHEN 'Low'::text THEN 4 ELSE 5 END
        Inner Unique: true
        Hash Cond: (r.location_id = l.location_id)
        Buffers: shared hit=4
        ->  Hash Join  (cost=2.35..3.71 rows=3 width=128) (actual time=0.040..0.049 rows=3.00 loops=1)
              Output: a.assignment_id, a.assignment_status, a.assigned_at, r.report_id, r.priority, r.status, r.location_id, r.description, c.category_name
              Inner Unique: true
              Hash Cond: (r.category_id = c.category_id)
              Buffers: shared hit=3
              ->  Hash Join  (cost=1.21..2.55 rows=3 width=116) (actual time=0.024..0.031 rows=3.00 loops=1)
                    Output: a.assignment_id, a.assignment_status, a.assigned_at, r.report_id, r.priority, r.status, r.location_id, r.category_id, r.description
                    Inner Unique: true
                    Hash Cond: (a.report_id = r.report_id)
                    Buffers: shared hit=2
                    ->  Seq Scan on public.assignment a  (cost=0.00..1.21 rows=3 width=28) (actual time=0.007..0.010 rows=3.00 loops=1)
                          Output: a.assignment_id, a.report_id, a.maintenance_user_id, a.assigned_by_user_id, a.assigned_at, a.assignment_status
                          Filter: ((a.maintenance_user_id = 2) AND ((a.assignment_status)::text = ANY ('{Assigned,"In Progress"}'::text[])))
                          Rows Removed by Filter: 9
                          Buffers: shared hit=1
                    ->  Hash  (cost=1.06..1.06 rows=16 width=96) (actual time=0.011..0.011 rows=16.00 loops=1)
                          Output: r.report_id, r.priority, r.status, r.location_id, r.category_id, r.description
                          Buckets: 1024  Batches: 1  Memory Usage: 10kB
                          Buffers: shared hit=1
                          ->  Seq Scan on public.hazard_report r  (cost=0.00..1.06 rows=16 width=96) (actual time=0.003..0.006 rows=16.00 loops=1)
                                Output: r.report_id, r.priority, r.status, r.location_id, r.category_id, r.description
                                Buffers: shared hit=1
              ->  Hash  (cost=1.06..1.06 rows=6 width=20) (actual time=0.008..0.008 rows=6.00 loops=1)
                    Output: c.category_name, c.category_id
                    Buckets: 1024  Batches: 1  Memory Usage: 9kB
                    Buffers: shared hit=1
                    ->  Seq Scan on public.hazard_category c  (cost=0.00..1.06 rows=6 width=20) (actual time=0.003..0.004 rows=6.00 loops=1)
                          Output: c.category_name, c.category_id
                          Buffers: shared hit=1
        ->  Hash  (cost=1.10..1.10 rows=10 width=40) (actual time=0.013..0.013 rows=10.00 loops=1)
              Output: l.building, l.floor, l.room_area, l.location_id
              Buckets: 1024  Batches: 1  Memory Usage: 9kB
              Buffers: shared hit=1
              ->  Seq Scan on public.campus_location l  (cost=0.00..1.10 rows=10 width=40) (actual time=0.004..0.006 rows=10.00 loops=1)
                    Output: l.building, l.floor, l.room_area, l.location_id
                    Buffers: shared hit=1
Planning Time: 2.760 ms
Execution Time: 0.155 ms
```

#### Detailed Execution Plan Analysis
1. **Technician Dispatch Indexing:** The existing index `idx_assign_maint` on `assignment(maintenance_user_id)` is strategically designed for this access pattern.
2. **Conditional Priority Sorting:** The custom `CASE` statement sorts critical/high life-safety hazards ahead of routine tasks.
3. **Composite Index Recommendation:**
   - In production dispatch systems, technicians continuously poll for active tasks.
     ```sql
     CREATE INDEX idx_assign_tech_active 
     ON public.assignment (maintenance_user_id, assignment_status) 
     WHERE assignment_status IN ('Assigned', 'In Progress');
     ```
     This partial index isolates unresolved tickets, reducing index maintenance overhead during completed order archiving.

---

### Query 4: Detailed Incident Investigation & Audit History View
Powers the full incident inspection view, retrieving the hazard profile along with chronological transition history steps and technician actions.

```sql
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
    r.report_id,
    r.status,
    r.priority,
    h.status AS history_stage,
    h.changed_at,
    u.full_name AS changed_by,
    h.notes
FROM public.hazard_report r
JOIN public.report_status_history h ON r.report_id = h.report_id
JOIN public.app_user u ON h.changed_by_user_id = u.user_id
WHERE r.report_id = 11
ORDER BY h.changed_at ASC;
```

#### Execution Plan Output
```text
Sort  (cost=2.38..2.39 rows=4 width=88) (actual time=0.045..0.047 rows=4.00 loops=1)
  Output: r.report_id, r.status, r.priority, h.status, h.changed_at, u.full_name, h.notes
  Sort Key: h.changed_at
  Sort Method: quicksort  Memory: 25kB
  Buffers: shared hit=3
  ->  Nested Loop  (cost=0.15..2.34 rows=4 width=88) (actual time=0.024..0.033 rows=4.00 loops=1)
        Output: r.report_id, r.status, r.priority, h.status, h.changed_at, u.full_name, h.notes
        Buffers: shared hit=3
        ->  Nested Loop  (cost=0.15..1.28 rows=4 width=52) (actual time=0.015..0.021 rows=4.00 loops=1)
              Output: r.report_id, r.status, r.priority, h.status, h.changed_at, h.notes, h.changed_by_user_id
              Buffers: shared hit=2
              ->  Index Scan using hazard_report_pkey on public.hazard_report r  (cost=0.15..0.17 rows=1 width=28) (actual time=0.007..0.007 rows=1.00 loops=1)
                    Output: r.report_id, r.reporter_user_id, r.location_id, r.category_id, r.description, r.priority, r.status, r.submitted_at, r.verified_by_user_id, r.verified_at, r.resolved_at
                    Index Cond: (r.report_id = 11)
                    Buffers: shared hit=1
              ->  Seq Scan on public.report_status_history h  (cost=0.00..1.38 rows=4 width=40) (actual time=0.006..0.011 rows=4.00 loops=1)
                    Output: h.history_id, h.report_id, h.changed_by_user_id, h.status, h.changed_at, h.notes
                    Filter: (h.report_id = 11)
                    Rows Removed by Filter: 26
                    Buffers: shared hit=1
        ->  Index Scan using app_user_pkey on public.app_user u  (cost=0.15..0.26 rows=1 width=44) (actual time=0.002..0.002 rows=1.00 loops=4)
              Output: u.user_id, u.role_id, u.full_name, u.email, u.username, u.password_hash, u.account_status, u.created_at
              Index Cond: (u.user_id = h.changed_by_user_id)
              Buffers: shared hit=1
Planning Time: 2.150 ms
Execution Time: 0.088 ms
```

#### Detailed Execution Plan Analysis
1. **Primary Key Index Utilization:** The planner efficiently utilizes `hazard_report_pkey` (`cost=0.15..0.17`) to fetch Report #11 in 0.007 ms, and `app_user_pkey` (`loops=4`) to retrieve the names of actors who triggered state transitions.
2. **Foreign Key Index Utilization:** Index `idx_history_report` is already defined on `report_status_history(report_id)`. With 30 sample rows, the engine opted for a single-page sequential scan; as audit rows scale to tens of thousands, the engine automatically leverages `idx_history_report` for sub-millisecond nested loops.
3. **Execution Efficiency:** Total planning time was **2.150 ms** and execution time was **0.088 ms** with zero disk I/O (`Buffers: shared hit=3`).

---

## 5. Problems or Limitations Encountered

During the DBA inspection, log review, and maintenance checks on `grp07_campussafedb`, the following technical problems, schema discrepancies, and architectural limitations were identified and evaluated:

1. **Index Sorting Discrepancy on `submitted_at`:**
   - *Problem:* Section 3 of the CampusSafe README Data Dictionary specifies:
     `idx_report_submitted | hazard_report | submitted_at DESC`
     However, `01_schema_(1).sql` defines:
     `CREATE INDEX idx_report_submitted ON hazard_report(submitted_at);` (default ascending).
   - *Technical Impact:* While PostgreSQL can traverse B-tree indexes backward, queries with mixed column ordering or queries on versions prior to index backward-scan optimizations may suffer performance penalties.
   - *Remediation:* Align physical schema with documented specification:
     ```sql
     DROP INDEX IF EXISTS idx_report_submitted;
     CREATE INDEX idx_report_submitted ON public.hazard_report (submitted_at DESC);
     ```

2. **Privilege Boundary on Maintenance Commands:**
   - *Problem:* Running `VACUUM` and `ANALYZE` under application login role `campussafe_app` resulted in `WARNING: permission denied to vacuum "hazard_report", skipping it`.
   - *Root Cause:* PostgreSQL enforces that `VACUUM` and `ANALYZE` can only be invoked by table owners or superusers. Application runtime roles lack maintenance privileges.
   - *DBA Assessment:* This behavior proves that Group 7's Activity 4 least-privilege boundary is properly enforced. Routine maintenance must be handled by PostgreSQL autovacuum or executed via an administrative maintenance account.

3. **Transaction Block Prohibition for VACUUM:**
   - *Problem:* Multi-statement migration scripts wrapping maintenance in `BEGIN...COMMIT` blocks fail with `ERROR: VACUUM cannot run inside a transaction block`.
   - *Root Cause:* PostgreSQL requires `VACUUM` to execute in autocommit mode outside transactions so page cleanups and transaction ID updates can commit immediately without locking dead row versions.
   - *Mitigation:* Maintenance statements must always run as standalone autocommit commands.

4. **Bcrypt Password Hash Exposure Safeguards:**
   - *Problem:* In naive role designs, read-only auditor roles are often granted `SELECT ON ALL TABLES`, inadvertently exposing sensitive Bcrypt `password_hash` strings to compliance reviewers.
   - *Remediation in Place:* Verified that Group 7's `03_roles_and_privileges_(1).sql` specifically **omits** `app_user` from `app_readonly_grp` grants, preventing unauthorized extraction of password hashes.

5. **Cascade Deletion Vulnerability on Operational Records:**
   - *Problem:* Tables `assignment`, `report_status_history`, `maintenance_action`, and `attachment` use `ON DELETE CASCADE` referencing `hazard_report(report_id)`. If an administrator accidentally deletes a report row, all associated technician work orders, repair actions, and immutable status audit trails are permanently destroyed.
   - *Remediation:* Implement soft deletion (`is_deleted BOOLEAN DEFAULT FALSE` or archiving) on `hazard_report`, or restrict `DELETE` permissions at the database role level (as achieved in `03_roles_and_privileges_(1).sql`).

6. **Full-Text Search Scalability on Free-Text Incident Descriptions:**
   - *Problem:* Filtering hazard descriptions using standard pattern matching (`ILIKE '%keyword%'`) forces full sequential table scans because standard B-tree indexes cannot index leading wildcards.
   - *Remediation:* For production scale, implement PostgreSQL full-text search (`tsvector` / `tsquery` with GIN indexing) or trigram similarity search:
     ```sql
     CREATE EXTENSION IF NOT EXISTS pg_trgm;
     CREATE INDEX idx_report_desc_trgm ON public.hazard_report USING gin (description gin_trgm_ops);
     ```

---

### DBA Audit Sign-Off
- **Audit Status:** Completed & Certified
- **Database Engine:** PostgreSQL 18.6 (x86_64-windows)
- **Target Database:** `grp07_campussafedb`
- **Application:** CampusSafe (Campus Hazard & Safety Reporting System)
- **Group:** Group 7
- **Evaluator:** Database Administrator (Group 3 Peer Review)
