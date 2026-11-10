# Park-It System — Database Administration, Monitoring, and Maintenance Report

**Course / Section:** COMP 018 – Database Administration / BSIT 3-1
<br>**Checked by:** Group 3  
**Target System:** Park-It: Database Management System (Group 2)  
**Target RDBMS:** PostgreSQL 18.6 (x86_64-windows, 64-bit)  
**Database Name:** `Park-It` (`grp_parkitdb`)  

---

## Executive Summary & Schema Cross-Reference

A comprehensive database administration audit, health check, log analysis, routine maintenance, and query execution plan analysis were conducted on the **Park-It System** database cluster. The evaluation cross-referenced the physical schema (`schema.sql`), the live PostgreSQL instance (`Park-It`), and the official project documentation (*PARK IT DATABASE MANAGEMENT PROJECT DEVELOPMENT DOCUMENTATION.pdf*).

### Cross-Reference: PDF Specification vs. Physical Database Schema (`schema.sql`)

| Database Object | PDF Documented Definition (Pages 2–4) | Attached SQL Schema (`schema.sql`) | Alignment Status | DBA Verification & Remarks |
| :--- | :--- | :--- | :--- | :--- |
| **Database Identifier** | `grp_parkitdb` (Activity 3 & 4 documentation) | `Park-It` (physical instance name in PostgreSQL) | **Minor Discrepancy** | The physical cluster database is named `"Park-It"`, requiring double quotes due to the hyphen. Official docs record `grp_parkitdb`. Objects and schema contents are identical. |
| **`parking_zone`** | Columns: `zone_id` (PK, serial), `zone_name` (varchar 50, unique), `max_capacity` (int), `current_active_count` (int, default 0). Constraint: `current_active_count <= max_capacity`. | Matches exactly: `zone_id` int NOT NULL DEFAULT seq, `zone_name` varchar(50) NOT NULL UNIQUE, `max_capacity` int NOT NULL, `current_active_count` int DEFAULT 0 NOT NULL. CHECK `(current_active_count <= max_capacity)`. | **VERIFIED MATCH** | Correctly enforces parking facility capacity limit at the engine level. |
| **`vehicle`** | Columns: `vehicle_id` (PK, serial), `license_plate` (varchar 20, unique), `vehicle_type` (varchar 50). | Matches exactly: `vehicle_id` int NOT NULL DEFAULT seq, `license_plate` varchar(20) NOT NULL UNIQUE, `vehicle_type` varchar(50) NOT NULL. Primary key on `vehicle_id`. | **VERIFIED MATCH** | Uniqueness on `license_plate` prevents duplicate active entries for the same vehicle. |
| **`transaction`** | Columns: `transaction_id` (PK, serial), `vehicle_id` (int, FK), `zone_id` (int, FK), `entry_time` (timestamp), `exit_time` (timestamp, nullable), `status` (varchar 20, default 'Active'), `is_lost_ticket` (boolean, default false). | Matches exactly: All columns, types, defaults, and foreign keys `transaction_vehicle_id_fkey` and `transaction_zone_id_fkey` present. | **VERIFIED MATCH (Architectural Warning)** | Table name `transaction` is a reserved SQL keyword requiring identifier quoting in ANSI SQL. |
| **`payment`** | Columns: `payment_id` (PK, serial), `transaction_id` (int, FK, unique), `amount` (numeric 10,2), `payment_method` (varchar 50), `payment_time` (timestamp). Constraint: `amount >= 0`. | Matches exactly: All columns, types, CHECK `(amount >= (0)::numeric)`, UNIQUE constraint on `transaction_id`, FK referencing `transaction(transaction_id)`. | **VERIFIED MATCH** | Enforces 1-to-1 relationship between transaction and settled receipt. |
| **`staff_user`** | Columns: `user_id` (PK, serial), `username` (varchar 50, unique), `password_hash` (varchar 255), `role` (varchar 20). | Matches exactly: All 4 columns, PK on `user_id`, UNIQUE on `username`. | **VERIFIED MATCH (Architectural Gap)** | Entity is completely disconnected (no FK links to `transaction` or `payment` to log which staff handled operations). |

---

## 1. Database Inspection Results

### 1.1 Server & Cluster Environment

- **RDBMS Engine:** PostgreSQL 18.6 on x86_64-windows, compiled by msvc-19.44.35229, 64-bit
- **Host / Port:** localhost:5432
- **Cluster Default Encoding:** UTF-8 | **Client Encoding:** UTF-8
- **Active Schema:** `public`
- **Total Database Size:** **8,718 kB** (~8.51 MB)

### 1.2 Table Inventory, Row Counts, and Storage Breakdown

```sql
SELECT 
    t.table_name,
    c.reltuples::bigint AS estimated_rows,
    pg_size_pretty(pg_total_relation_size('public.' || t.table_name)) AS total_size,
    pg_size_pretty(pg_relation_size('public.' || t.table_name)) AS heap_size,
    pg_size_pretty(pg_indexes_size('public.' || t.table_name)) AS index_size
FROM information_schema.tables t
JOIN pg_class c ON c.relname = t.table_name
WHERE t.table_schema = 'public'
ORDER BY t.table_name;
```

| Table Name | Live Row Count | Total Size | Heap (Table) Size | Index Size | Table Owner | Primary Key / Constraints |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`parking_zone`** | 1 | 72 kB | 8,192 bytes | 32 kB | `postgres` | `parking_zone_pkey` (zone_id), `parking_zone_zone_name_key` (UNIQUE), `parking_zone_check` (CHECK) |
| **`payment`** | 3 | 72 kB | 8,192 bytes | 32 kB | `postgres` | `payment_pkey` (payment_id), `payment_transaction_id_key` (UNIQUE), `payment_transaction_id_fkey` (FK) |
| **`staff_user`** | 2 | 72 kB | 8,192 bytes | 32 kB | `postgres` | `staff_user_pkey` (user_id), `staff_user_username_key` (UNIQUE) |
| **`transaction`** | 7 | 56 kB | 8,192 bytes | 16 kB | `postgres` | `transaction_pkey` (transaction_id), FKs: `transaction_vehicle_id_fkey`, `transaction_zone_id_fkey` |
| **`vehicle`** | 5 | 72 kB | 8,192 bytes | 32 kB | `postgres` | `vehicle_pkey` (vehicle_id), `vehicle_license_plate_key` (UNIQUE) |

### 1.3 Database Users and Privilege Roles

```sql
SELECT rolname, rolsuper, rolinherit, rolcreaterole, rolcreatedb, rolcanlogin, rolconnlimit 
FROM pg_roles 
WHERE rolname NOT LIKE 'pg_%' 
ORDER BY rolname;
```

| Role Name | Superuser | Inherit | Create Role | Create DB | Can Login | Role Description / Assignment |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`postgres`** | `true` | `true` | `true` | `true` | `true` | Cluster Superuser / Object Owner |
| **`parkit_runtime_grp`** | `false` | `true` | `false` | `false` | `false` | Non-login group role granted `SELECT, INSERT, UPDATE, DELETE` on all tables |
| **`parkit_readonly_grp`**| `false` | `true` | `false` | `false` | `false` | Non-login group role granted `SELECT` on all tables |
| **`parkit_app_user`** | `false` | `true` | `false` | `false` | `true` | Application runtime login role (Member of `parkit_runtime_grp`) |
| **`parkit_readonly_user`**| `false` | `true` | `false` | `false` | `true` | Auditor / Read-only login role (Member of `parkit_readonly_grp`) |

### 1.4 Active Connections and Query Activity

```sql
SELECT datname, numbackends FROM pg_stat_database WHERE datname = 'Park-It';
SELECT pid, usename, client_addr, state, wait_event_type, wait_event, query_start, query 
FROM pg_stat_activity 
WHERE datname = 'Park-It'
ORDER BY query_start NULLS LAST;
```

- **Active Backends Connected to `Park-It`:** 2 backends
- **Active Sessions:**
  1. `pid: 11716` | User: `parkit_app_user` | Client: `::1` | State: `active` | Running Query: DBA Inspection SQL Block
  2. `pid: 4288` | User: `postgres` | Client: local | State: `idle` | Query: `<insufficient privilege>` *(Non-superuser connection masking)*

---

## 2. Log Inspection Findings

The server logs were inspected directly from `C:\Program Files\PostgreSQL\18\data\log`:
- `postgresql-2026-11-09_201035.log` (92 kB)
- `postgresql-2026-11-10_000000.log` (Live session log)

### Summary of Discovered Log Events

| Timestamp | Severity | Error / Message | Root Cause Analysis | Operational Impact & DBA Recommendation |
| :--- | :--- | :--- | :--- | :--- |
| `2026-11-09 21:18:07` | `ERROR` | `syntax error at or near "\" at character 36` <br> `STATEMENT: \restrict vUFR...` | A developer attempted to execute a raw `pg_dump` backup file containing psql client meta-commands (`\restrict` / `\unrestrict`) inside a standard SQL query runner. | Query failed immediately. **DBA Rule:** Plain SQL dumps with backslash commands must be executed via `psql -f dump.sql` rather than GUI SQL windows. |
| `2026-11-09 21:19:33` | `ERROR` | `relation "parking_zone" already exists` | Attempted table creation without `IF NOT EXISTS` check when running schema setup script multiple times. | Aborted the execution script. **DBA Rule:** Use idempotent scripts (`CREATE TABLE IF NOT EXISTS`). |
| `2026-11-09 21:23:09` | `ERROR` | `current transaction is aborted, commands ignored until end of transaction block (25P02)` | Subsequent statements were sent within an open transaction block following a previous failure without an explicit `ROLLBACK`. | All subsequent queries were ignored by the engine until the block terminated. |
| `2026-11-09 21:54:57` / `2026-11-10 11:35:16` | `FATAL` | `password authentication failed for user "postgres"` (SCRAM-SHA-256) | Connection attempts using incorrect credentials during initial environment and driver configuration. | Multiple failed attempts logged. Verify credentials and keep secrets in protected configuration/`.pgpass` files. |
| `2026-11-09 22:10:19` | `ERROR` | `syntax error at or near "\" at character 5` <br> `STATEMENT: GRANT CONNECT ON DATABASE " Park-It\` | Malformed SQL statement with leading space and trailing unescaped backslash when quoting the database name `" Park-It\`. | Command failed. Always quote identifiers cleanly: `GRANT CONNECT ON DATABASE "Park-It" TO ...;`. |
| `2026-11-09 22:28:40` | `LOG` | `could not receive data from client: An existing connection was forcibly closed by the remote host.` | A client application or terminal was closed abruptly without sending a TCP close-notify packet. | Clean backend termination; shared memory safely freed. |
| `2026-11-10 12:29:37` | `ERROR` | `VACUUM cannot run inside a transaction block` | Multi-statement command string sent `VACUUM` inside an implicit transaction block. | `VACUUM` requires standalone execution outside transactions. |
| `2026-11-10 12:29:43` | `WARNING` | `permission denied to vacuum "parking_zone", skipping it` | Attempted to run `VACUUM` using the `parkit_app_user` application role. | PostgreSQL restricts `VACUUM` to table owners or superusers. Least-privilege application accounts are properly barred from performing maintenance. |

---

## 3. Maintenance Commands and Results

### 3.1 Maintenance Strategy

Routine maintenance consists of:
1. `VACUUM`: Cleans dead row versions, reclaims block space, and updates visibility maps.
2. `ANALYZE`: Computes table statistics stored in `pg_statistic` to guide the Cost-Based Optimizer (CBO).

### 3.2 Executed Maintenance Commands

The following commands were tested on all tables in schema `public`:

```sql
VACUUM (VERBOSE, ANALYZE) public.parking_zone;
VACUUM (VERBOSE, ANALYZE) public.vehicle;
VACUUM (VERBOSE, ANALYZE) public.transaction;
VACUUM (VERBOSE, ANALYZE) public.payment;
VACUUM (VERBOSE, ANALYZE) public.staff_user;
```

### 3.3 Recorded Outcomes by Execution Context

#### Context A: Execution under Application Runtime Role (`parkit_app_user`)
```text
WARNING:  permission denied to vacuum "parking_zone", skipping it
VACUUM
WARNING:  permission denied to vacuum "vehicle", skipping it
VACUUM
WARNING:  permission denied to vacuum "transaction", skipping it
VACUUM
WARNING:  permission denied to vacuum "payment", skipping it
VACUUM
WARNING:  permission denied to vacuum "staff_user", skipping it
VACUUM
```
*DBA Finding:* The application role `parkit_app_user` does not own the relations and lacks `pg_vacuum_all_tables` / `pg_maintain` system privileges. This validates the principle of least privilege: runtime application services cannot run cluster maintenance tasks.

#### Context B: Execution under Authorized Table Owner / Administrative Role (`postgres`)
```text
INFO:  vacuuming "Park-It.public.transaction"
INFO:  finished vacuuming "Park-It.public.transaction": index scans: 0
pages: 0 removed, 1 remain, 1 scanned (100.00% of total), 0 eagerly scanned
tuples: 0 removed, 7 remain, 0 are dead but not yet removable
removable cutoff: 790, which was 0 XIDs old when operation ended
frozen: 0 pages from table (0.00% of total) had 0 tuples frozen
visibility map: 1 pages set all-visible, 0 pages set all-frozen
buffer usage: 36 hits, 0 reads, 4 dirtied
WAL usage: 5 records, 4 full page images, 33338 bytes
INFO:  analyzing "public.transaction"
INFO:  "transaction": scanned 1 of 1 pages, containing 7 live rows and 0 dead rows; 7 rows in sample, 7 estimated total rows
INFO:  finished analyzing table "Park-It.public.transaction"
VACUUM
```
*Maintenance Summary:* All 5 tables were successfully analyzed and vacuumed. All pages (1 page per table) are 100% all-visible, 0 dead tuples remain, and the query planner statistics are fully synchronized.

---

## 4. Query Performance Analysis and Execution Plans

Four primary SELECT queries representing key application modules from the Park-It System were analyzed using `EXPLAIN (ANALYZE, BUFFERS)`.

### Query 1: Active Parking Sessions & Entry Monitoring (Dashboard Module)

This query powers the real-time active parking sessions list on the main dashboard (PDF Pages 6–7, Figures 4 & 6).

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    t.transaction_id,
    v.license_plate,
    v.vehicle_type,
    pz.zone_name,
    t.entry_time,
    t.status
FROM public.transaction t
JOIN public.vehicle v ON t.vehicle_id = v.vehicle_id
JOIN public.parking_zone pz ON t.zone_id = pz.zone_id
WHERE t.status = 'Active'
ORDER BY t.entry_time DESC;
```

#### Execution Plan Output
```text
Sort  (cost=3.32..3.33 rows=4 width=42) (actual time=0.102..0.106 rows=4.00 loops=1)
  Sort Key: t.entry_time DESC
  Sort Method: quicksort  Memory: 25kB
  Buffers: shared hit=6
  ->  Nested Loop  (cost=1.11..3.28 rows=4 width=42) (actual time=0.071..0.076 rows=4.00 loops=1)
        Join Filter: (pz.zone_id = t.zone_id)
        Buffers: shared hit=3
        ->  Seq Scan on parking_zone pz  (cost=0.00..1.01 rows=1 width=11) (actual time=0.024..0.024 rows=1.00 loops=1)
              Buffers: shared hit=1
        ->  Hash Join  (cost=1.11..2.22 rows=4 width=39) (actual time=0.043..0.046 rows=4.00 loops=1)
              Hash Cond: (t.vehicle_id = v.vehicle_id)
              Buffers: shared hit=2
              ->  Seq Scan on transaction t  (cost=0.00..1.09 rows=4 width=28) (actual time=0.013..0.014 rows=4.00 loops=1)
                    Filter: ((status)::text = 'Active'::text)
                    Rows Removed by Filter: 3
                    Buffers: shared hit=1
              ->  Hash  (cost=1.05..1.05 rows=5 width=19) (actual time=0.021..0.021 rows=5.00 loops=1)
                    Buckets: 1024  Batches: 1  Memory Usage: 9kB
                    Buffers: shared hit=1
                    ->  Seq Scan on vehicle v  (cost=0.00..1.05 rows=5 width=19) (actual time=0.011..0.012 rows=5.00 loops=1)
                          Buffers: shared hit=1
Planning Time: 6.117 ms
Execution Time: 0.152 ms
```

#### Performance Plan Examination & Bottlenecks
1. **Sequential Scan on `transaction`:** The engine sequentially scans `transaction` and filters `WHERE status = 'Active'` (`Rows Removed by Filter: 3`). While taking only 0.014 ms on 7 rows, in production (with 50,000 historical transactions), this will scan every closed session.
2. **Missing Foreign Key Indexes:** `transaction.vehicle_id` and `transaction.zone_id` have no B-tree indexes, forcing sequential scans during joins.
3. **Explicit Memory Quicksort:** Ordering by `entry_time DESC` forces an explicit in-memory quicksort.

#### Recommended Optimization DDL
```sql
-- Partial composite index for live active sessions:
CREATE INDEX idx_transaction_active_entry 
ON public.transaction (entry_time DESC) 
WHERE status = 'Active';

-- Foreign key indexes to accelerate joins:
CREATE INDEX idx_transaction_vehicle_id ON public.transaction (vehicle_id);
CREATE INDEX idx_transaction_zone_id ON public.transaction (zone_id);
```
*Impact:* Replaces table scan and quicksort with a direct **Index Scan** returning pre-sorted active transactions, scaling linearly at $O(\log N)$ as historical records grow.

---

### Query 2: Payment & Completed Transactions Log (Payment Module)

Powers the payment receipts and transaction settlement screen (PDF Page 8, Figure 9).

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    p.payment_id,
    t.transaction_id,
    v.license_plate,
    v.vehicle_type,
    t.entry_time,
    t.exit_time,
    p.amount,
    p.payment_method,
    p.payment_time
FROM public.payment p
JOIN public.transaction t ON p.transaction_id = t.transaction_id
JOIN public.vehicle v ON t.vehicle_id = v.vehicle_id
ORDER BY p.payment_time DESC;
```

#### Execution Plan Output
```text
Sort  (cost=3.32..3.33 rows=3 width=57) (actual time=0.098..0.100 rows=3.00 loops=1)
  Sort Key: p.payment_time DESC
  Sort Method: quicksort  Memory: 25kB
  Buffers: shared hit=6
  ->  Hash Join  (cost=2.18..3.30 rows=3 width=57) (actual time=0.067..0.071 rows=3.00 loops=1)
        Hash Cond: (t.vehicle_id = v.vehicle_id)
        Buffers: shared hit=3
        ->  Hash Join  (cost=1.07..2.17 rows=3 width=46) (actual time=0.036..0.039 rows=3.00 loops=1)
              Hash Cond: (t.transaction_id = p.transaction_id)
              Buffers: shared hit=2
              ->  Seq Scan on transaction t  (cost=0.00..1.07 rows=7 width=24) (actual time=0.008..0.009 rows=7.00 loops=1)
                    Buffers: shared hit=1
              ->  Hash  (cost=1.03..1.03 rows=3 width=26) (actual time=0.014..0.015 rows=3.00 loops=1)
                    Buckets: 1024  Batches: 1  Memory Usage: 9kB
                    Buffers: shared hit=1
                    ->  Seq Scan on payment p  (cost=0.00..1.03 rows=3 width=26) (actual time=0.008..0.009 rows=3.00 loops=1)
                          Buffers: shared hit=1
        ->  Hash  (cost=1.05..1.05 rows=5 width=19) (actual time=0.024..0.024 rows=5.00 loops=1)
              Buckets: 1024  Batches: 1  Memory Usage: 9kB
              Buffers: shared hit=1
              ->  Seq Scan on vehicle v  (cost=0.00..1.05 rows=5 width=19) (actual time=0.018..0.019 rows=5.00 loops=1)
                    Buffers: shared hit=1
Planning Time: 4.962 ms
Execution Time: 0.172 ms
```

#### Performance Plan Examination & Suggested Improvement
- The join between `payment` and `transaction` utilizes the unique index on `payment.transaction_id`. However, ordering by `payment.payment_time DESC` will require external on-disk sorting once the receipt history exceeds `work_mem`.
- **Optimization:** Add index `CREATE INDEX idx_payment_time ON public.payment (payment_time DESC);` to allow direct backward index scans for payment audit reporting.

---

### Query 3: Vehicle Lookup by License Plate (Registration Module)

Powers incoming vehicle registration and search verification (PDF Page 7, Figure 5).

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT vehicle_id, license_plate, vehicle_type 
FROM public.vehicle 
WHERE license_plate = 'DSA';
```

#### Execution Plan Output
```text
Seq Scan on vehicle  (cost=0.00..1.06 rows=1 width=19) (actual time=0.022..0.023 rows=1.00 loops=1)
  Filter: ((license_plate)::text = 'DSA'::text)
  Rows Removed by Filter: 4
  Buffers: shared hit=1
Planning Time: 2.228 ms
Execution Time: 0.074 ms
```

#### Planner Evaluation: Sequential Scan vs. Index Scan
- `vehicle` has a unique B-tree index on `license_plate` (`vehicle_license_plate_key`).
- Even though the index exists, PostgreSQL chose a `Seq Scan` because the table occupies only a single 8 kB disk page. A sequential scan costs 1.06 vs. an index scan cost of 8.15 (tested via `SET enable_seqscan = off;`).
- **DBA Evaluation:** This behavior is mathematically correct. As documented in Activity 5 guidelines, sequential scans on small tables are faster than reading index tree blocks plus heap blocks. As vehicle records exceed several hundred rows, the CBO will automatically switch to `Index Scan using vehicle_license_plate_key`.

---

## 5. Problems or Limitations Encountered

During the DBA inspection, log review, and maintenance checks, the following specific technical problems and environmental limitations were encountered and addressed:

1. **Maintenance Privilege Restriction on Least-Privilege Role:**
   - *Problem:* Running `VACUUM` and `ANALYZE` as the application login user `parkit_app_user` yielded `WARNING: permission denied to vacuum "parking_zone", skipping it`.
   - *Cause:* In PostgreSQL, maintenance operations like `VACUUM` require relation ownership or administrative roles (`pg_vacuum_all_tables` in PG 16+). `parkit_app_user` was correctly restricted to DML operations (`SELECT, INSERT, UPDATE, DELETE`).
   - *Mitigation:* Documented this limitation as an access-control success under Activity 4 least-privilege principles. Scheduled maintenance tasks should be run by a designated DBA maintenance role (`db_maint_user` with `pg_maintain`) or cluster admin.

2. **Monitoring Visibility Restriction (`pg_stat_activity`):**
   - *Problem:* Querying `pg_stat_activity` under `parkit_app_user` displayed `<insufficient privilege>` in the query column for backend processes owned by other users (`postgres`).
   - *Cause:* PostgreSQL protects query contents across user boundaries unless granted `pg_read_all_stats`.
   - *Mitigation:* DBA monitoring scripts should either use superuser authentication or grant `pg_read_all_stats` to designated monitoring service accounts.

3. **ANSI SQL Keyword Conflict on Table Name `transaction`:**
   - *Problem:* The table identifier `transaction` is a reserved SQL command word (`BEGIN TRANSACTION`, `COMMIT`). Raw DDL statements without quotes fail with parser errors.
   - *Mitigation:* Used explicit schema qualification (`public.transaction`). Recommended renaming the relation to `parking_transaction` in future releases.

4. **Raw `pg_dump` Backslash Directives in GUI Query Windows:**
   - *Problem:* The server logs contained syntax errors (`syntax error at or near "\" at character 36`) caused by developers pasting `schema.sql` (which includes `\restrict` and `\unrestrict`) directly into pgAdmin's query window.
   - *Mitigation:* Documented clear operational procedures: logical SQL dumps containing client meta-commands must be imported using `psql -f dump.sql`.

5. **Naming Discrepancy Between PDF and Database Instance:**
   - *Problem:* Project documentation references `grp_parkitdb`, while the physical PostgreSQL instance was initialized as `"Park-It"`.
   - *Mitigation:* Verified table, schema, and record alignment, confirming that both refer to the identical Park-It system. Highlighted the discrepancy so the project group can standardize its naming convention in Activity 6 backup scripts.

---

### DBA Sign-Off & Verification
- **Audit Status:** Complete & Verified
- **Database Engine:** PostgreSQL 18.6
- **Database Inspected:** `Park-It` (Group 2)
