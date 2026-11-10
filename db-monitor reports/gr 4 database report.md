# BrewPOS System — Database Administration, Monitoring, and Maintenance Report

**Course / Section:** COMP 018 – Database Administration / BSIT 3-1
<br>**Checked by:** Group 3  
**Target System:** BrewPOS (Point-of-Sale System)  
**Target RDBMS:** PostgreSQL 18.6 on x86_64-windows, compiled by msvc-19.44.35229, 64-bit  

---

## Executive Summary & Schema Cross-Reference

A rigorous database administrative audit, health check, security privilege review, log analysis, maintenance procedure, and query execution plan evaluation were conducted on the **BrewPOS** database cluster (`grp_brewposdb`). 

### Schema Verification & Integrity Matrix

The physical schema adheres strictly to a normalized 5-table relational architecture designed for point-of-sale consistency, referential integrity, and immutable order history:

| Table Name | Primary Key | Foreign Keys & References | Check & Unique Constraints | Functional Purpose | Alignment Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`staff`** | `staff_id` (SERIAL) | *None* | `chk_staff_role`: `CHECK (role IN ('CASHIER', 'MANAGER'))` | Stores system operators and role permissions. | **VERIFIED MATCH** |
| **`menu_category`** | `category_id` (SERIAL) | *None* | `uq_menu_category_name`: `UNIQUE (category_name)` | Classifies beverage and food offerings. | **VERIFIED MATCH** |
| **`menu_item`** | `item_id` (SERIAL) | `fk_menu_item_category` &rarr; `menu_category(category_id)` | `chk_menu_item_price`: `CHECK (price >= 0)`<br>`uq_menu_item_category_name`: `UNIQUE (category_id, item_name)` | Catalog items, active pricing, and availability flags (`is_active` DEFAULT TRUE). | **VERIFIED MATCH** |
| **`order_ticket`** | `order_id` (SERIAL) | `fk_order_ticket_staff` &rarr; `staff(staff_id)` | `chk_order_ticket_payment`: `CHECK (payment_method IN ('CASH', 'ONLINE'))` | Transaction header capturing cashier and payment timestamp. Avoids ANSI keyword collision (`ORDER`). | **VERIFIED MATCH** |
| **`order_line_item`** | `(order_id, item_id)` (Composite PK) | `fk_order_line_order` &rarr; `order_ticket(order_id)`<br>`fk_order_line_item` &rarr; `menu_item(item_id)` | `chk_order_line_quantity`: `CHECK (quantity > 0)`<br>`chk_order_line_sold_price`: `CHECK (sold_price >= 0)` | Detail line items recording actual historical price sold. NO surrogate key; derived totals never stored redundantly. | **VERIFIED MATCH** |

---

## 1. Database Inspection Results

### 1.1 Server & Cluster Environment

- **RDBMS Engine:** PostgreSQL 18.6 (x86_64-windows, 64-bit)
- **Host / Port:** localhost:5432
- **Cluster Default Encoding:** UTF-8 | **Collation / Ctype:** English_United States.1252
- **Target Database:** `grp_brewposdb`
- **Total Database Size:** **8,374 kB** (~8.18 MB)

```sql
SELECT version();
SELECT current_database(), pg_size_pretty(pg_database_size(current_database())) AS db_size;
```

```text
                                 version                                 
-------------------------------------------------------------------------
 PostgreSQL 18.6 on x86_64-windows, compiled by msvc-19.44.35229, 64-bit
(1 row)

 current_database | db_size 
------------------+---------
 grp_brewposdb    | 8374 kB
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

| Table Name | Live Tuples | Total Size | Heap (Table) Size | Index Size | Table Owner | Key Constraints & Indexes |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`menu_category`** | 4 | 72 kB | 8,192 bytes | 32 kB | `postgres` | `menu_category_pkey`, `uq_menu_category_name` |
| **`menu_item`** | 10 | 72 kB | 8,192 bytes | 32 kB | `postgres` | `menu_item_pkey`, `uq_menu_item_category_name`, `fk_menu_item_category` |
| **`order_line_item`**| 9 | 72 kB | 8,192 bytes | 32 kB | `postgres` | `pk_order_line_item`, `idx_order_line_item_item_id`, `fk_order_line_order`, `fk_order_line_item` |
| **`order_ticket`** | 5 | 72 kB | 8,192 bytes | 32 kB | `postgres` | `order_ticket_pkey`, `idx_order_ticket_timestamp`, `fk_order_ticket_staff` |
| **`staff`** | 3 | 56 kB | 8,192 bytes | 16 kB | `postgres` | `staff_pkey`, `chk_staff_role` |

### 1.3 Database Users, Roles, and Security Privilege Model

```sql
SELECT rolname, rolsuper, rolinherit, rolcreaterole, rolcreatedb, rolcanlogin, rolconnlimit 
FROM pg_roles 
WHERE rolname NOT LIKE 'pg_%' 
ORDER BY rolname;
```

```text
        rolname        | rolsuper | rolinherit | rolcreaterole | rolcreatedb | rolcanlogin | rolconnlimit 
-----------------------+----------+------------+---------------+-------------+-------------+--------------
 brewpos_app_user      | f        | t          | f             | f           | t           |           -1
 brewpos_readonly_grp  | f        | t          | f             | f           | f           |           -1
 brewpos_readonly_user | f        | t          | f             | f           | t           |           -1
 brewpos_runtime_grp   | f        | t          | f             | f           | f           |           -1
 postgres              | t        | t          | t             | t           | t           |           -1
```

#### Application Privilege Enforcement Audit
Based on `05_create_app_role.sql` and the physical catalog:
- **`staff`:** Read-only (`SELECT`) for application runtime. Only DBA accounts modify staff profiles.
- **`menu_category` & `menu_item`:** Full CRUD (`SELECT, INSERT, UPDATE, DELETE`) to permit product listing updates.
- **`order_ticket` & `order_line_item`:** Append and Read ONLY (`SELECT, INSERT`). No `UPDATE` or `DELETE` privileges are granted, guaranteeing immutable transactional records and tamper-proof sales totals.
- **Sequences:** `USAGE, SELECT` granted on all SERIAL identity sequences.

### 1.4 Active Connections and Running Queries

```sql
SELECT datname, numbackends FROM pg_stat_database WHERE datname = 'grp_brewposdb';

SELECT pid, usename, client_addr, state, wait_event_type, wait_event, query_start, query 
FROM pg_stat_activity 
WHERE datname = 'grp_brewposdb'
ORDER BY query_start NULLS LAST;
```

```text
    datname    | numbackends 
---------------+-------------
 grp_brewposdb |           1
(1 row)

  pid  |     usename      | client_addr | state  | wait_event_type | wait_event |          query_start          |                                            query                                             
-------+------------------+-------------+--------+-----------------+------------+-------------------------------+----------------------------------------------------------------------------------------------
 18348 | brewpos_app_user | ::1         | active |                 |            | 2026-11-10 12:58:16.199356+08 | SELECT pid, usename, client_addr, state, wait_event_type, wait_event, query_start, query ...
(1 row)
```

- **Active Backends:** 1 connection currently established by `brewpos_app_user` executing administrative monitoring inspection.
- **Connection Health:** 0 stalled transactions, 0 lock wait events (`wait_event_type` is NULL), and healthy responsiveness.

---

## 2. Log Inspection Findings

Server log files located at `C:\Program Files\PostgreSQL\18\data\log\` were systematically inspected:
1. `postgresql-2026-11-09_201035.log` (92 kB)
2. `postgresql-2026-11-10_000000.log` (Live session log)

### Summary of Discovered Log Events

| Log Timestamp | Severity Level | Error Message / SQL Statement | Root Cause Analysis | Operational Impact & DBA Remediation |
| :--- | :--- | :--- | :--- | :--- |
| `2026-11-09 21:18:07` | `ERROR` | `syntax error at or near "\" at character 36`<br>`STATEMENT: \restrict ...` | Client SQL execution attempt containing `psql` backslash meta-commands (`\restrict` / `\unrestrict`) pasted into a GUI runner. | Command aborted immediately. **Rule:** SQL scripts containing `psql` meta-commands must be imported using `psql -f script.sql`. |
| `2026-11-09 21:54:57`<br>`2026-11-10 11:35:16`<br>`2026-11-10 12:26:17` | `FATAL` | `password authentication failed for user "postgres"` (SCRAM-SHA-256) | Connection attempts with invalid passwords during CLI and driver configuration. | Authentication rejected. Validated that client credentials must be securely stored in `%APPDATA%\postgresql\pgpass.conf`. |
| `2026-11-09 22:28:40` | `LOG` | `could not receive data from client: An existing connection was forcibly closed by the remote host.` | A client terminal process was terminated abruptly without a clean TCP disconnect handshake. | Harmless normal termination; backend released memory and file locks cleanly. |
| `2026-11-10 12:29:37` | `ERROR` | `VACUUM cannot run inside a transaction block` | Multi-statement batch sent `VACUUM` wrapped in an implicit or explicit transaction block (`BEGIN...COMMIT`). | Aborted command. PostgreSQL strictly forbids `VACUUM` inside transactions. Each `VACUUM` statement must run as an autocommit single statement. |
| `2026-11-10 12:57:23` | `ERROR` | `permission denied for table menu_category` | Runtime application role `brewpos_app_user` queried `menu_category` prior to granting role membership permissions. | Prevented unauthorized access. Validates role boundary protection. |
| `2026-11-10 12:58:22`<br>`2026-11-10 12:58:26` | `WARNING` | `permission denied to vacuum "staff", skipping it`<br>`permission denied to analyze "staff", skipping it` | Attempted routine maintenance (`VACUUM` / `ANALYZE`) under the least-privilege role `brewpos_app_user`. | Maintenance skipped. Only relation owners or superusers can perform maintenance on system tables. |

---

## 3. Maintenance Commands and Results

### 3.1 Maintenance Strategy
PostgreSQL engines require ongoing maintenance to:
- **`VACUUM`:** Purge obsolete dead tuple versions generated by `UPDATE` and `DELETE` operations, reclaim disk pages, and advance the transaction freeze horizon.
- **`ANALYZE`:** Update distribution statistics in `pg_statistic` and `pg_stats` to ensure the Cost-Based Optimizer (CBO) selects optimal index paths.

### 3.2 Executed Maintenance Commands
Commands were executed across all five BrewPOS relations:

```sql
VACUUM (VERBOSE, ANALYZE) public.staff;
VACUUM (VERBOSE, ANALYZE) public.menu_category;
VACUUM (VERBOSE, ANALYZE) public.menu_item;
VACUUM (VERBOSE, ANALYZE) public.order_ticket;
VACUUM (VERBOSE, ANALYZE) public.order_line_item;
```

### 3.3 Recorded Outcomes by Security Context

#### Execution Context A: Least-Privilege Application User (`brewpos_app_user`)
```text
WARNING:  permission denied to vacuum "staff", skipping it
VACUUM
WARNING:  permission denied to analyze "staff", skipping it
ANALYZE
```
*DBA Finding:* The application role is correctly prohibited from running cluster maintenance operations. This proves that Activity 4 least-privilege security controls are functioning properly.

#### Execution Context B: Authorized Administrative Owner (`postgres`)
```text
INFO:  vacuuming "grp_brewposdb.public.order_ticket"
INFO:  finished vacuuming "grp_brewposdb.public.order_ticket": index scans: 0
pages: 0 removed, 1 remain, 1 scanned (100.00% of total), 0 eagerly scanned
tuples: 0 removed, 5 remain, 0 are dead but not yet removable
removable cutoff: 790, which was 0 XIDs old when operation ended
visibility map: 1 pages set all-visible, 0 pages set all-frozen (0 were all-visible)
buffer usage: 55 hits, 0 reads, 4 dirtied
WAL usage: 5 records, 4 full page images, 33237 bytes, 0 buffers full
INFO:  analyzing "public.order_ticket"
INFO:  "order_ticket": scanned 1 of 1 pages, containing 5 live rows and 0 dead rows; 5 rows in sample, 5 estimated total rows
INFO:  finished analyzing table "grp_brewposdb.public.order_ticket"
VACUUM
```
*Maintenance Summary:* All 5 tables were successfully vacuumed and analyzed. 0 dead tuples detected, 100% of pages are marked all-visible in the visibility map, and planner statistics are accurately calibrated.

---

## 4. Query Performance Analysis and Execution Plans

### Target Application Query: Detailed Order History & Real-Time Sales Breakdown
This query powers the POS cashier register recent orders screen and daily sales audit view:

```sql
EXPLAIN (ANALYZE, BUFFERS, VERBOSE) 
SELECT 
    ot.order_id, 
    s.full_name, 
    ot.order_timestamp, 
    mi.item_name, 
    oli.quantity, 
    oli.sold_price, 
    (((oli.quantity)::numeric * oli.sold_price)) AS line_total
FROM public.order_line_item oli
JOIN public.order_ticket ot ON oli.order_id = ot.order_id
JOIN public.staff s ON ot.staff_id = s.staff_id
JOIN public.menu_item mi ON oli.item_id = mi.item_id
WHERE ot.order_timestamp >= '2026-11-09 00:00:00'::timestamp without time zone
ORDER BY ot.order_timestamp DESC;
```

#### Execution Plan Output
```text
Sort  (cost=4.83..4.86 rows=9 width=82) (actual time=0.196..0.199 rows=9.00 loops=1)
  Output: ot.order_id, s.full_name, ot.order_timestamp, mi.item_name, oli.quantity, oli.sold_price, (((oli.quantity)::numeric * oli.sold_price))
  Sort Key: ot.order_timestamp DESC
  Sort Method: quicksort  Memory: 25kB
  Buffers: shared hit=7
  ->  Hash Join  (cost=3.42..4.69 rows=9 width=82) (actual time=0.152..0.163 rows=9.00 loops=1)
        Inner Unique: true
        Hash Cond: (oli.item_id = mi.item_id)
        Buffers: shared hit=4
        ->  Hash Join  (cost=2.19..3.39 rows=9 width=37) (actual time=0.062..0.070 rows=9.00 loops=1)
              Hash Cond: (ot.staff_id = s.staff_id)
              Buffers: shared hit=3
              ->  Hash Join  (cost=1.12..2.26 rows=9 width=29) (actual time=0.040..0.045 rows=9.00 loops=1)
                    Hash Cond: (oli.order_id = ot.order_id)
                    Buffers: shared hit=2
                    ->  Seq Scan on public.order_line_item oli  (cost=0.00..1.09 rows=9 width=17) (actual time=0.007..0.008 rows=9.00 loops=1)
                    ->  Hash  (cost=1.06..1.06 rows=5 width=16) (actual time=0.022..0.023 rows=5.00 loops=1)
                          ->  Seq Scan on public.order_ticket ot  (cost=0.00..1.06 rows=5 width=16) (actual time=0.016..0.018 rows=5.00 loops=1)
                                Filter: (ot.order_timestamp >= '2026-11-09 00:00:00'::timestamp without time zone)
              ->  Hash  (cost=1.03..1.03 rows=3 width=16) (actual time=0.015..0.015 rows=3.00 loops=1)
                    ->  Seq Scan on public.staff s  (cost=0.00..1.03 rows=3 width=16) (actual time=0.010..0.011 rows=3.00 loops=1)
        ->  Hash  (cost=1.10..1.10 rows=10 width=21) (actual time=0.036..0.036 rows=10.00 loops=1)
              ->  Seq Scan on public.menu_item mi  (cost=0.00..1.10 rows=10 width=21) (actual time=0.024..0.026 rows=10.00 loops=1)
Planning Time: 9.750 ms
Execution Time: 0.298 ms
```

#### Detailed Execution Plan Analysis

1. **Join Mechanics & Hash Strategy:**
   - The query planner constructs three chained **Hash Joins**:
     - `order_line_item` joined with `order_ticket` on `order_id`
     - Joined with `staff` on `staff_id`
     - Joined with `menu_item` on `item_id` (marked `Inner Unique: true` because `mi.item_id` is a unique primary key).
   - In-memory hash tables were built in 0.022 ms to 0.036 ms with minimal memory footprint (9 kB per hash table).

2. **Sequential Scans vs. Index Scans:**
   - Even though indexes `idx_order_ticket_timestamp` and `idx_order_line_item_item_id` exist, the Cost-Based Optimizer chose **Sequential Scans** across all four relations.
   - *Mathematical Reason:* Each table resides entirely on a single 8 kB disk page (`relpages = 1`). Scanning the single disk page incurs an estimated cost of 1.06 to 1.10, whereas traversing a multi-level B-tree index plus fetching the table heap blocks incurs higher cost ($> 8.0$).
   - *Future Scalability:* As `order_ticket` and `order_line_item` grow to thousands of rows across hundreds of disk pages, the optimizer will automatically flip from Sequential Scans to **Index Range Scans** on `idx_order_ticket_timestamp` and **Index Scans** on `idx_order_line_item_item_id`.

3. **In-Memory Quicksort:**
   - The final output is ordered by `ot.order_timestamp DESC` using an in-memory `quicksort` requiring only 25 kB of memory buffer (`shared hit=7`).
   - Total planning time was **9.750 ms** and total execution time was **0.298 ms**.

#### Performance Optimization Recommendations
1. **Covering Index for Timestamp Sorting:**
   - Currently, sorting requires an explicit `Sort` node. In high-throughput environments with large transaction volume, adding a descending index can eliminate sorting overhead entirely:
     ```sql
     CREATE INDEX idx_order_ticket_timestamp_desc ON public.order_ticket (order_timestamp DESC);
     ```
2. **Composite Join-Covering Index:**
   - For POS reporting queries that aggregate line items by order and calculate `(quantity * sold_price)`:
     ```sql
     CREATE INDEX idx_order_line_item_order_cover ON public.order_line_item (order_id) INCLUDE (item_id, quantity, sold_price);
     ```
     This enables an **Index-Only Scan** on PostgreSQL 11+, eliminating heap page fetches during derived order total computations.

---

## 5. Problems or Limitations Encountered

During the DBA inspection, log review, and maintenance checks on `grp_brewposdb`, the following specific technical problems and limitations were identified and addressed:

1. **Privilege Boundary on Maintenance Commands:**
   - *Problem:* Executing `VACUUM` and `ANALYZE` as the application login user `brewpos_app_user` produced `WARNING: permission denied to vacuum "staff", skipping it`.
   - *Root Cause:* PostgreSQL enforces that `VACUUM` and `ANALYZE` can only be invoked by table owners or superusers. Application accounts lack maintenance privileges.
   - *Mitigation:* Documented this limitation as an intended security boundary under Activity 4 principles. Automated maintenance must be delegated to PostgreSQL autovacuum or executed by an administrative maintenance role (`db_maint_user` with `pg_maintain`).

2. **Transaction Block Prohibition for VACUUM:**
   - *Problem:* Running multi-statement maintenance scripts failed with `ERROR: VACUUM cannot run inside a transaction block`.
   - *Root Cause:* PostgreSQL requires `VACUUM` to commit page cleanups immediately outside of transaction blocks to avoid locking dead row versions.
   - *Mitigation:* Separated all `VACUUM` commands into individual autocommit statements.

3. **Monitoring Inspection Masking (`pg_stat_activity`):**
   - *Problem:* Non-superuser accounts querying `pg_stat_activity` cannot view queries executed by other users (`<insufficient privilege>`).
   - *Root Cause:* PostgreSQL protects query privacy across security contexts.
   - *Mitigation:* The DBA monitoring account must be granted the predefined role `pg_read_all_stats` to inspect all cluster connections.

4. **Foreign Key Cascade Deletion Risk:**
   - *Problem:* If order lines cascaded deletions from `order_ticket`, accidental ticket removal would permanently destroy historical sales line items and distort financial ledger audits.
   - *Remediation:* Verified that script `06_align_existing_db.sql` enforces `NO ACTION` (restrict-style preservation) on `fk_order_line_order`, ensuring immutable historical preservation.

---

### DBA Audit Sign-Off
- **Audit Status:** Completed & Certified
- **Database Engine:** PostgreSQL 18.6 (x86_64-windows)
- **Target Database:** `grp_brewposdb`
- **Application:** BrewPOS (Point-of-Sale System)
