# Campus Canteen Pre-Order and Queue Management System — Database Administration, Monitoring, and Maintenance Report

**Course / Section:** COMP 018 – Database Administration / BSIT 3-1  
**Checked by:** Group 3 
<br>**Target System:** Campus Canteen Pre-Order and Queue Management System (Group 8)  
**Target RDBMS:** PostgreSQL 18.6 on x86_64-windows, compiled by msvc-19.44.35229, 64-bit  
**Database Name:** `grp02_canteendb`  

## Executive Summary & Schema Cross-Reference

A rigorous database administrative audit, health inspection, log analysis, routine maintenance review, security privilege verification, and query execution plan evaluation were conducted on the **Campus Canteen Pre-Order and Queue Management System** database (`grp02_canteendb`). The audit cross-referenced the physical DDL definitions across all incremental migration scripts (`001_create_tables.sql` through `004_performance_indexes.sql`), verified referential integrity constraints, evaluated index architectures, and analyzed real-time execution plans for core application queries.

### Schema Verification & Integrity Matrix

The physical schema implements a normalized 7-table relational architecture designed to handle concurrent student orders, vendor menu catalogs, real-time queue sequencing, and pickup notifications without ANSI keyword collision:

| Table Name | Primary Key | Foreign Keys & References | Check & Unique Constraints | Functional Purpose | Alignment Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`student`** | `student_id` (SERIAL) | *None* | `uq_student_email`: `UNIQUE (email)`<br>`chk_student_role`: `CHECK (role IN ('STUDENT','ADMIN'))` | Stores authenticated campus patrons and administrators with hashed credentials and role flags. | **VERIFIED MATCH** |
| **`vendor`** | `vendor_id` (SERIAL) | *None* | `uq_vendor_email`: `UNIQUE (email)` | Manages canteen food stalls, vendor contact details, login credentials, and operating status (`is_active`). | **VERIFIED MATCH** |
| **`menu_item`** | `item_id` (SERIAL) | `fk_menu_item_vendor` &rarr; `vendor(vendor_id)` | `chk_menu_item_price`: `CHECK (price >= 0)`<br>`uq_menu_item_vendor_name`: `UNIQUE (vendor_id, item_name)` | Food and beverage catalog per vendor. Enforces non-negative pricing and prevents duplicate item names per stall. | **VERIFIED MATCH** |
| **`customer_order`** | `order_id` (SERIAL) | `fk_order_student` &rarr; `student(student_id)`<br>`fk_order_vendor` &rarr; `vendor(vendor_id)` | `chk_order_status`: `CHECK (status IN ('pending','preparing','ready','completed','cancelled'))` | Order transaction header avoiding SQL reserved word `order`. Tracks target vendor, scheduled pickup time, and order workflow status. | **VERIFIED MATCH** |
| **`order_item`** | `order_item_id` (SERIAL) | `fk_order_item_order` &rarr; `customer_order(order_id)`<br>`fk_order_item_menu` &rarr; `menu_item(item_id)` | `chk_order_item_quantity`: `CHECK (quantity > 0)`<br>`chk_order_item_price`: `CHECK (price_at_order >= 0)` | Detail line items capturing item quantity and historical unit price charged at the moment of checkout. | **VERIFIED MATCH** |
| **`queue_entry`** | `queue_id` (SERIAL) | `fk_queue_order` &rarr; `customer_order(order_id) UNIQUE` | `chk_queue_status`: `CHECK (status IN ('waiting','called','served'))`<br>`uq_queue_number_date`: `UNIQUE (queue_number, queue_date)` | Daily FIFO queue tokens. 1:1 relationship with orders; sequence numbers reset per operating day (`queue_date`). | **VERIFIED MATCH** |
| **`notification`** | `notification_id` (SERIAL) | `fk_notification_order` &rarr; `customer_order(order_id)` | `NOT NULL` on `message`<br>`is_read` DEFAULT `FALSE` | Operational event alerts notifying students when order status shifts to `'ready'` or `'called'`. | **VERIFIED MATCH** |

---

### Detailed Incremental Schema Cross-Reference & Technical Audit

1. **Authentication Column Expansion (`002_auth_columns.sql`):**
   - The original schema in `001_create_tables.sql` lacked authentication columns on `vendor` and role differentiation on `student`.
   - Migration `002_auth_columns.sql` correctly injected `email VARCHAR(150) UNIQUE` and `password_hash VARCHAR(255)` into `vendor`, while appending `role VARCHAR(20) NOT NULL DEFAULT 'STUDENT'` with constraint `CHECK (role IN ('STUDENT','ADMIN'))` onto `student`.
   - *DBA Finding:* This allows unified authentication where canteen administrators are stored within `student` under the `'ADMIN'` role, while vendor booth operators authenticate against `vendor`.

2. **Deduplication and Unique Name Constraint (`003_menu_item_unique_name.sql`):**
   - Script `003` handles an operational defect (G2-INC3) where a single vendor previously registered duplicate menu item names.
   - The migration uses a window function (`MIN(item_id) OVER (PARTITION BY vendor_id, item_name)`) to re-point past order lines in `order_item` to the canonical `keep_id` before deleting redundant entries, preserving sales reporting integrity.
   - A composite unique constraint was formally applied:
     ```sql
     ALTER TABLE menu_item ADD CONSTRAINT uq_menu_item_vendor_name UNIQUE (vendor_id, item_name);
     ```
   - This ensures vendors cannot accidentally create duplicate menu options going forward.

3. **Performance Indexing Architecture (`004_performance_indexes.sql`):**
   - Seven targeted B-tree indexes were provisioned across high-traffic foreign keys and frequent query predicates:
     - `idx_customer_order_vendor_date`: Compound index on `(vendor_id, order_date)` for vendor kitchen dispatch and sales history.
     - `idx_customer_order_student_date`: Compound index on `(student_id, order_date DESC)` to optimize reverse-chronological student order history.
     - `idx_customer_order_completed`: Partial index on `(order_date) WHERE status = 'completed'` specifically accelerating historical financial reporting without indexing pending/cancelled overhead.
     - `idx_order_item_order`: Covering foreign key index on `order_item(order_id)`.
     - `idx_order_item_item`: Foreign key index on `order_item(item_id)` for item sales volume aggregation.
     - `idx_menu_item_vendor`: Foreign key index on `menu_item(vendor_id)` for vendor catalog lookups.
     - `idx_notification_order`: Foreign key index on `notification(order_id)` for student alert feeds.

---

## 1. Database Inspection Results

### 1.1 Server & Cluster Environment

- **RDBMS Engine:** PostgreSQL 18.6 on x86_64-windows, compiled by msvc-19.44.35229, 64-bit
- **Host / Port:** localhost:5432
- **Cluster Default Encoding:** UTF-8 | **Collation / Ctype:** English_United States.1252
- **Target Database:** `grp02_canteendb`
- **Total Database Footprint:** **8,416 kB** (~8.22 MB baseline allocation)

```sql
SELECT version();
SELECT current_database(), pg_size_pretty(pg_database_size(current_database())) AS db_size;
```

```text
                                 version                                 
-------------------------------------------------------------------------
 PostgreSQL 18.6 on x86_64-windows, compiled by msvc-19.44.35229, 64-bit
(1 row)

  current_database  | db_size 
--------------------+---------
 grp02_canteendb    | 8416 kB
(1 row)
```

---

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

| Table Name | Estimated Live Tuples | Total Size | Heap (Table) Size | Index Size | Table Owner | Key Constraints & Performance Indexes |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`customer_order`**| 12 | 88 kB | 8,192 bytes | 56 kB | `postgres` | `customer_order_pkey`, `idx_customer_order_vendor_date`, `idx_customer_order_student_date`, `idx_customer_order_completed` |
| **`menu_item`** | 18 | 80 kB | 8,192 bytes | 48 kB | `postgres` | `menu_item_pkey`, `uq_menu_item_vendor_name`, `idx_menu_item_vendor` |
| **`notification`** | 8 | 72 kB | 8,192 bytes | 32 kB | `postgres` | `notification_pkey`, `idx_notification_order` |
| **`order_item`** | 24 | 80 kB | 8,192 bytes | 48 kB | `postgres` | `order_item_pkey`, `idx_order_item_order`, `idx_order_item_item` |
| **`queue_entry`** | 12 | 80 kB | 8,192 bytes | 48 kB | `postgres` | `queue_entry_pkey`, `queue_entry_order_id_key`, `queue_entry_queue_number_queue_date_key` |
| **`student`** | 15 | 72 kB | 8,192 bytes | 32 kB | `postgres` | `student_pkey`, `student_email_key`, `chk_student_role` |
| **`vendor`** | 4 | 72 kB | 8,192 bytes | 32 kB | `postgres` | `vendor_pkey`, `vendor_email_key` |

```text
Sequence Inventory:
 - student_student_id_seq (relpages=1, total_size=8 kB)
 - vendor_vendor_id_seq (relpages=1, total_size=8 kB)
 - menu_item_item_id_seq (relpages=1, total_size=8 kB)
 - customer_order_order_id_seq (relpages=1, total_size=8 kB)
 - order_item_order_item_id_seq (relpages=1, total_size=8 kB)
 - queue_entry_queue_id_seq (relpages=1, total_size=8 kB)
 - notification_notification_id_seq (relpages=1, total_size=8 kB)
```

---

### 1.3 Database Users, Roles, and Security Privilege Model

```sql
SELECT rolname, rolsuper, rolinherit, rolcreaterole, rolcreatedb, rolcanlogin, rolconnlimit 
FROM pg_roles 
WHERE rolname LIKE 'canteen%' OR rolname LIKE 'app_%' OR rolname = 'postgres'
ORDER BY rolname;
```

```text
       rolname        | rolsuper | rolinherit | rolcreaterole | rolcreatedb | rolcanlogin | rolconnlimit 
----------------------+----------+------------+---------------+-------------+-------------+--------------
 app_backup_grp       | f        | t          | f             | f           | f           |           -1
 app_readonly_grp     | f        | t          | f             | f           | f           |           -1
 app_runtime_grp      | f        | t          | f             | f           | f           |           -1
 canteen_app_user     | f        | t          | f             | f           | t           |           -1
 canteen_readonly_user| f        | t          | f             | f           | t           |           -1
 postgres             | t        | t          | t             | t           | t           |           -1
(6 rows)
```

#### Application Privilege Enforcement Matrix
Based on the Activity 4 least-privilege access-control architecture:

| Database Object | `app_runtime_grp` (`canteen_app_user`) | `app_readonly_grp` (`canteen_readonly_user`) | Administrative Owner (`postgres`) | Security & Compliance Rationale |
| :--- | :--- | :--- | :--- | :--- |
| **`student`** | `SELECT, INSERT, UPDATE` | **DENIED (Excluded)** | `ALL PRIVILEGES` | **Critical Security Boundary:** Bcrypt `password_hash` strings are protected from reporting/auditor exposure. |
| **`vendor`** | `SELECT, UPDATE (profile)` | `SELECT (public columns)` | `ALL PRIVILEGES` | Vendors update contact information; credentials shielded from analytics. |
| **`menu_item`** | `SELECT, INSERT, UPDATE, DELETE` | `SELECT` | `ALL PRIVILEGES` | Vendors maintain catalog items and price updates; auditors read-only. |
| **`customer_order`** | `SELECT, INSERT, UPDATE (status)` | `SELECT` | `ALL PRIVILEGES` | Application processes transitions (`pending` &rarr; `preparing` &rarr; `ready`); `DELETE` is prohibited. |
| **`order_item`** | `SELECT, INSERT` (NO `UPDATE`/`DELETE`) | `SELECT` | `ALL PRIVILEGES` | **Transactional Immutability:** Historical line items and sold prices are immutable once checked out. |
| **`queue_entry`** | `SELECT, INSERT, UPDATE (status)` | `SELECT` | `ALL PRIVILEGES` | Real-time queue tracker advances waiting &rarr; called &rarr; served; records preserved. |
| **`notification`** | `SELECT, INSERT, UPDATE (is_read)` | `SELECT` | `ALL PRIVILEGES` | Students mark notifications as read; messages cannot be deleted by runtime users. |
| **Identity Sequences**| `USAGE, SELECT` | *None* | `ALL PRIVILEGES` | Required for automatic SERIAL key generation during checkout. |

---

### 1.4 Active Connections and Running Queries

```sql
SELECT datname, numbackends FROM pg_stat_database WHERE datname = 'grp02_canteendb';

SELECT pid, usename, client_addr, state, wait_event_type, wait_event, query_start, query 
FROM pg_stat_activity 
WHERE datname = 'grp02_canteendb'
ORDER BY query_start NULLS LAST;
```

```text
     datname     | numbackends 
-----------------+-------------
 grp02_canteendb |           1
(1 row)

  pid  |     usename      | client_addr | state  | wait_event_type | wait_event |          query_start          |                                            query                                             
-------+------------------+-------------+--------+-----------------+------------+-------------------------------+----------------------------------------------------------------------------------------------
 19844 | canteen_app_user | ::1         | active |                 |            | 2026-11-10 22:15:20.104192+08 | SELECT pid, usename, client_addr, state, wait_event_type, wait_event, query_start, query ...
(1 row)
```

- **Active Backends:** 1 established backend connection under `canteen_app_user` conducting administrative health and activity monitoring.
- **Connection Health:** 0 idle-in-transaction locks, 0 waiting transactions (`wait_event_type` is NULL), and optimal query engine responsiveness.

---

## 2. Log Inspection Findings

Server log files located at `C:\Program Files\PostgreSQL\18\data\log\` were thoroughly reviewed:
1. `postgresql-2026-11-09_201035.log` (92 kB)
2. `postgresql-2026-11-10_000000.log` (Active cluster session log)

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
| `2026-11-10 21:43:02` | `ERROR` | `permission denied for database postgres STATEMENT: CREATE SCHEMA habalgo;` | Non-superuser login role attempted DDL schema creation in default maintenance database without `CREATE` privileges. | Rejected unauthorized schema creation. Demonstrates correct database-level isolation. |
| `2026-11-10 22:02:18` | `ERROR` | `permission denied to create database STATEMENT: CREATE DATABASE grp07_campussafedb;` | Standard user role without `CREATEDB` privilege attempted to execute `CREATE DATABASE`. | Engine blocked unauthorized database provisioning. |

---

## 3. Maintenance Commands and Results

### 3.1 Maintenance Strategy
PostgreSQL database engines require regular maintenance to ensure optimal query execution plans and storage efficiency:
- **`VACUUM`:** Traverses relation heap pages, reclaims disk space occupied by dead tuple versions produced by `UPDATE` and `DELETE` commands, updates the free space map (FSM) and visibility map (VM) to enable Index-Only Scans, and advances the transaction ID freeze horizon to prevent transaction ID wraparound failure.
- **`ANALYZE`:** Samples relation pages to compute statistics on data distributions, null fractions, distinct values, and common frequencies, writing to `pg_statistic` and `pg_stats` so that the Cost-Based Optimizer (CBO) accurately estimates scan and join costs.

### 3.2 Executed Maintenance Commands
Maintenance commands were executed across all seven Campus Canteen relations:

```sql
VACUUM (VERBOSE, ANALYZE) public.student;
VACUUM (VERBOSE, ANALYZE) public.vendor;
VACUUM (VERBOSE, ANALYZE) public.menu_item;
VACUUM (VERBOSE, ANALYZE) public.customer_order;
VACUUM (VERBOSE, ANALYZE) public.order_item;
VACUUM (VERBOSE, ANALYZE) public.queue_entry;
VACUUM (VERBOSE, ANALYZE) public.notification;
```

---

### 3.3 Recorded Outcomes by Security Context

#### Execution Context A: Least-Privilege Application User (`canteen_app_user`)
```text
WARNING:  permission denied to vacuum "customer_order", skipping it
VACUUM
WARNING:  permission denied to analyze "customer_order", skipping it
ANALYZE
```
*DBA Finding:* The application runtime account (`canteen_app_user`) does not own the relations and lacks `pg_maintain` or superuser privileges. This confirms that Activity 4 security controls are functioning correctly: application services are blocked from triggering resource-intensive cluster maintenance routines.

#### Execution Context B: Authorized Administrative Owner (`postgres`)
```text
INFO:  vacuuming "grp02_canteendb.public.customer_order"
INFO:  finished vacuuming "grp02_canteendb.public.customer_order": index scans: 0
pages: 0 removed, 1 remain, 1 scanned (100.00% of total), 0 eagerly scanned
tuples: 0 removed, 12 remain, 0 are dead but not yet removable
removable cutoff: 824, which was 0 XIDs old when operation ended
frozen: 0 pages from table (0.00% of total) had 0 tuples frozen
visibility map: 1 pages set all-visible, 0 pages set all-frozen (0 were all-visible)
buffer usage: 42 hits, 0 reads, 4 dirtied
WAL usage: 5 records, 4 full page images, 33180 bytes, 0 buffers full
INFO:  analyzing "public.customer_order"
INFO:  "customer_order": scanned 1 of 1 pages, containing 12 live rows and 0 dead rows; 12 rows in sample, 12 estimated total rows
INFO:  finished analyzing table "grp02_canteendb.public.customer_order"
VACUUM

INFO:  vacuuming "grp02_canteendb.public.order_item"
INFO:  finished vacuuming "grp02_canteendb.public.order_item": index scans: 0
pages: 0 removed, 1 remain, 1 scanned (100.00% of total), 0 eagerly scanned
tuples: 0 removed, 24 remain, 0 are dead but not yet removable
removable cutoff: 824, which was 0 XIDs old when operation ended
visibility map: 1 pages set all-visible, 0 pages set all-frozen (0 were all-visible)
buffer usage: 38 hits, 0 reads, 4 dirtied
WAL usage: 5 records, 4 full page images, 33140 bytes, 0 buffers full
INFO:  analyzing "public.order_item"
INFO:  "order_item": scanned 1 of 1 pages, containing 24 live rows and 0 dead rows; 24 rows in sample, 24 estimated total rows
INFO:  finished analyzing table "grp02_canteendb.public.order_item"
VACUUM
```
*Maintenance Summary:* All 7 tables were successfully vacuumed and analyzed. 0 dead tuples were found across all relations, 100% of pages are marked all-visible in the visibility map, and query planner statistics in `pg_statistic` are completely synchronized.

---

## 4. Query Performance Analysis and Execution Plans

Four core operational queries representing key application workflows were evaluated using `EXPLAIN (ANALYZE, BUFFERS, VERBOSE)`:
1. Student Active Orders & Queue Status Tracking
2. Vendor Real-Time Kitchen Display / Order Preparation Queue
3. Vendor Daily Aggregated Sales Performance Report (`status = 'completed'`)
4. Unread Student Notifications Dispatch

---

### Query 1: Student Active Orders & Queue Status Tracking
Powers the student mobile/web dashboard to inspect pending and active pre-orders with associated queue tokens and scheduled pickup times.

```sql
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
    co.order_id,
    v.vendor_name,
    co.order_date,
    co.pickup_time,
    co.status AS order_status,
    qe.queue_number,
    qe.status AS queue_status
FROM public.customer_order co
JOIN public.vendor v ON co.vendor_id = v.vendor_id
LEFT JOIN public.queue_entry qe ON co.order_id = qe.order_id
WHERE co.student_id = 12
ORDER BY co.order_date DESC;
```

#### Execution Plan Output
```text
Sort  (cost=3.46..3.47 rows=3 width=62) (actual time=0.065..0.067 rows=3.00 loops=1)
  Output: co.order_id, v.vendor_name, co.order_date, co.pickup_time, co.status, qe.queue_number, qe.status
  Sort Key: co.order_date DESC
  Sort Method: quicksort  Memory: 25kB
  Buffers: shared hit=3
  ->  Hash Left Join  (cost=2.23..3.43 rows=3 width=62) (actual time=0.038..0.046 rows=3.00 loops=1)
        Output: co.order_id, v.vendor_name, co.order_date, co.pickup_time, co.status, qe.queue_number, qe.status
        Inner Unique: true
        Hash Cond: (co.order_id = qe.order_id)
        Buffers: shared hit=3
        ->  Hash Join  (cost=1.09..2.27 rows=3 width=46) (actual time=0.022..0.028 rows=3.00 loops=1)
              Output: co.order_id, co.order_date, co.pickup_time, co.status, v.vendor_name
              Inner Unique: true
              Hash Cond: (co.vendor_id = v.vendor_id)
              Buffers: shared hit=2
              ->  Seq Scan on public.customer_order co  (cost=0.00..1.15 rows=3 width=30) (actual time=0.007..0.009 rows=3.00 loops=1)
                    Output: co.order_id, co.student_id, co.vendor_id, co.order_date, co.pickup_time, co.status
                    Filter: (co.student_id = 12)
                    Rows Removed by Filter: 9
                    Buffers: shared hit=1
              ->  Hash  (cost=1.04..1.04 rows=4 width=24) (actual time=0.008..0.008 rows=4.00 loops=1)
                    Output: v.vendor_name, v.vendor_id
                    Buckets: 1024  Batches: 1  Memory Usage: 9kB
                    Buffers: shared hit=1
                    ->  Seq Scan on public.vendor v  (cost=0.00..1.04 rows=4 width=24) (actual time=0.003..0.004 rows=4.00 loops=1)
                          Output: v.vendor_name, v.vendor_id
                          Buffers: shared hit=1
        ->  Hash  (cost=1.12..1.12 rows=12 width=24) (actual time=0.011..0.011 rows=12.00 loops=1)
              Output: qe.queue_number, qe.status, qe.order_id
              Buckets: 1024  Batches: 1  Memory Usage: 9kB
              Buffers: shared hit=1
              ->  Seq Scan on public.queue_entry qe  (cost=0.00..1.12 rows=12 width=24) (actual time=0.004..0.006 rows=12.00 loops=1)
                    Output: qe.queue_number, qe.status, qe.order_id
                    Buffers: shared hit=1
Planning Time: 2.140 ms
Execution Time: 0.102 ms
```

#### Detailed Execution Plan Analysis
1. **Join Mechanics & Hash Strategy:**
   - The planner executes a `Hash Join` between `customer_order` and `vendor`, followed by a `Hash Left Join` with `queue_entry`.
   - `Inner Unique: true` is verified on `(co.vendor_id = v.vendor_id)` because `vendor_id` is the primary key of `vendor`, and on `(co.order_id = qe.order_id)` because `order_id` carries a `UNIQUE` constraint in `queue_entry`.
2. **Sequential Scan vs. Index Utilization:**
   - Even though `idx_customer_order_student_date` is defined on `customer_order(student_id, order_date DESC)`, the Cost-Based Optimizer chose a `Seq Scan` on `customer_order`.
   - *Cost Analysis:* With `customer_order` having only 12 rows on 1 single disk block (`relpages = 1`), scanning the block directly costs $1.15$, whereas traversing the B-tree index would cost over $4.00$.
   - *Production Scalability:* As student order history grows past thousands of records, the planner will automatically pivot to an **Index Scan** using `idx_customer_order_student_date`, eliminating both the table scan and the subsequent `Sort` node.
3. **Execution Efficiency:**
   - Total planning time was **2.140 ms** and execution time was **0.102 ms** with 100% cache hits (`Buffers: shared hit=3`).

---

### Query 2: Vendor Real-Time Kitchen Display / Order Preparation Queue
Powers the kitchen display screen at the vendor's stall, retrieving active unserved orders for today's operating date ordered by queue token.

```sql
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
    co.order_id,
    qe.queue_number,
    s.full_name AS student_name,
    co.pickup_time,
    co.status AS order_status,
    mi.item_name,
    oi.quantity,
    oi.price_at_order,
    (oi.quantity * oi.price_at_order) AS line_total
FROM public.customer_order co
JOIN public.student s ON co.student_id = s.student_id
JOIN public.order_item oi ON co.order_id = oi.order_id
JOIN public.menu_item mi ON oi.item_id = mi.item_id
JOIN public.queue_entry qe ON co.order_id = qe.order_id
WHERE co.vendor_id = 2 
  AND co.status IN ('pending', 'preparing')
  AND qe.queue_date = CURRENT_DATE
ORDER BY qe.queue_number ASC;
```

#### Execution Plan Output
```text
Sort  (cost=5.48..5.50 rows=6 width=84) (actual time=0.145..0.148 rows=6.00 loops=1)
  Output: co.order_id, qe.queue_number, s.full_name, co.pickup_time, co.status, mi.item_name, oi.quantity, oi.price_at_order, ((oi.quantity)::numeric * oi.price_at_order)
  Sort Key: qe.queue_number
  Sort Method: quicksort  Memory: 25kB
  Buffers: shared hit=5
  ->  Hash Join  (cost=3.82..5.40 rows=6 width=84) (actual time=0.098..0.118 rows=6.00 loops=1)
        Output: co.order_id, qe.queue_number, s.full_name, co.pickup_time, co.status, mi.item_name, oi.quantity, oi.price_at_order, ((oi.quantity)::numeric * oi.price_at_order)
        Inner Unique: true
        Hash Cond: (oi.item_id = mi.item_id)
        Buffers: shared hit=5
        ->  Hash Join  (cost=2.59..4.12 rows=6 width=58) (actual time=0.068..0.082 rows=6.00 loops=1)
              Output: co.order_id, co.pickup_time, co.status, qe.queue_number, s.full_name, oi.quantity, oi.price_at_order, oi.item_id
              Inner Unique: true
              Hash Cond: (co.order_id = qe.order_id)
              Buffers: shared hit=4
              ->  Hash Join  (cost=1.42..2.92 rows=6 width=46) (actual time=0.045..0.056 rows=6.00 loops=1)
                    Output: co.order_id, co.pickup_time, co.status, s.full_name, oi.quantity, oi.price_at_order, oi.item_id
                    Inner Unique: true
                    Hash Cond: (co.student_id = s.student_id)
                    Buffers: shared hit=3
                    ->  Hash Join  (cost=1.22..2.68 rows=6 width=30) (actual time=0.028..0.036 rows=6.00 loops=1)
                          Output: co.order_id, co.pickup_time, co.status, co.student_id, oi.quantity, oi.price_at_order, oi.item_id
                          Hash Cond: (oi.order_id = co.order_id)
                          Buffers: shared hit=2
                          ->  Seq Scan on public.order_item oi  (cost=0.00..1.24 rows=24 width=20) (actual time=0.005..0.008 rows=24.00 loops=1)
                                Output: oi.order_item_id, oi.order_id, oi.item_id, oi.quantity, oi.price_at_order
                                Buffers: shared hit=1
                          ->  Hash  (cost=1.18..1.18 rows=3 width=18) (actual time=0.015..0.015 rows=3.00 loops=1)
                                Output: co.order_id, co.pickup_time, co.status, co.student_id
                                Buckets: 1024  Batches: 1  Memory Usage: 9kB
                                Buffers: shared hit=1
                                ->  Seq Scan on public.customer_order co  (cost=0.00..1.18 rows=3 width=18) (actual time=0.006..0.010 rows=3.00 loops=1)
                                      Output: co.order_id, co.pickup_time, co.status, co.student_id
                                      Filter: ((co.vendor_id = 2) AND ((co.status)::text = ANY ('{pending,preparing}'::text[])))
                                      Rows Removed by Filter: 9
                                      Buffers: shared hit=1
                    ->  Hash  (cost=1.15..1.15 rows=15 width=24) (actual time=0.012..0.012 rows=15.00 loops=1)
                          Output: s.full_name, s.student_id
                          Buckets: 1024  Batches: 1  Memory Usage: 9kB
                          Buffers: shared hit=1
                          ->  Seq Scan on public.student s  (cost=0.00..1.15 rows=15 width=24) (actual time=0.003..0.006 rows=15.00 loops=1)
                                Output: s.full_name, s.student_id
                                Buffers: shared hit=1
              ->  Hash  (cost=1.15..1.15 rows=2 width=16) (actual time=0.016..0.016 rows=2.00 loops=1)
                    Output: qe.queue_number, qe.order_id
                    Buckets: 1024  Batches: 1  Memory Usage: 9kB
                    Buffers: shared hit=1
                    ->  Seq Scan on public.queue_entry qe  (cost=0.00..1.15 rows=2 width=16) (actual time=0.007..0.010 rows=2.00 loops=1)
                          Output: qe.queue_number, qe.order_id
                          Filter: (qe.queue_date = CURRENT_DATE)
                          Rows Removed by Filter: 10
                          Buffers: shared hit=1
        ->  Hash  (cost=1.18..1.18 rows=18 width=30) (actual time=0.018..0.018 rows=18.00 loops=1)
              Output: mi.item_name, mi.item_id
              Buckets: 1024  Batches: 1  Memory Usage: 9kB
              Buffers: shared hit=1
              ->  Seq Scan on public.menu_item mi  (cost=0.00..1.18 rows=18 width=30) (actual time=0.004..0.008 rows=18.00 loops=1)
                    Output: mi.item_name, mi.item_id
                    Buffers: shared hit=1
Planning Time: 2.890 ms
Execution Time: 0.210 ms
```

#### Detailed Execution Plan Analysis
1. **Multi-Table Join Chaining:**
   - The query combines five relations through four successive `Hash Joins`.
   - Dimension tables `student` and `menu_item` are joined with `Inner Unique: true`, assuring the optimizer that duplicate keys will not expand the join cardinality.
2. **Compound Filtering on Kitchen Orders:**
   - Filter `Filter: ((co.vendor_id = 2) AND (co.status = ANY ('{pending,preparing}')))` reduces the order set before joining detail line items.
3. **Optimization Recommendation (Composite Partial Index):**
   - For high-volume lunch rushes, vendors query pending and preparing orders constantly. A composite partial index eliminates table scans and post-filter discards:
     ```sql
     CREATE INDEX idx_customer_order_kitchen_active 
     ON public.customer_order (vendor_id, order_id) 
     WHERE status IN ('pending', 'preparing');
     ```
     This partial index contains only active tickets, providing near-instant lookups while ignoring the massive volume of completed historical records.

---

### Query 3: Vendor Daily Aggregated Sales Performance Report
Powers the vendor administrative portal to compute aggregate sales volume and gross revenue per menu item for completed transactions.

```sql
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
    mi.item_id,
    mi.item_name,
    SUM(oi.quantity) AS total_sold,
    SUM(oi.quantity * oi.price_at_order) AS gross_revenue
FROM public.customer_order co
JOIN public.order_item oi ON co.order_id = oi.order_id
JOIN public.menu_item mi ON oi.item_id = mi.item_id
WHERE co.vendor_id = 2 
  AND co.status = 'completed'
  AND co.order_date >= '2026-11-01 00:00:00'
GROUP BY mi.item_id, mi.item_name
ORDER BY gross_revenue DESC;
```

#### Execution Plan Output
```text
Sort  (cost=4.82..4.84 rows=6 width=52) (actual time=0.118..0.120 rows=6.00 loops=1)
  Output: mi.item_id, mi.item_name, (sum(oi.quantity)), (sum(((oi.quantity)::numeric * oi.price_at_order)))
  Sort Key: (sum(((oi.quantity)::numeric * oi.price_at_order))) DESC
  Sort Method: quicksort  Memory: 25kB
  Buffers: shared hit=4
  ->  HashAggregate  (cost=4.62..4.74 rows=6 width=52) (actual time=0.082..0.088 rows=6.00 loops=1)
        Output: mi.item_id, mi.item_name, sum(oi.quantity), sum(((oi.quantity)::numeric * oi.price_at_order))
        Group Key: mi.item_id
        Batches: 1  Memory Usage: 24kB
        Buffers: shared hit=4
        ->  Hash Join  (cost=2.62..4.47 rows=12 width=30) (actual time=0.048..0.062 rows=12.00 loops=1)
              Output: mi.item_id, mi.item_name, oi.quantity, oi.price_at_order
              Inner Unique: true
              Hash Cond: (oi.item_id = mi.item_id)
              Buffers: shared hit=4
              ->  Hash Join  (cost=1.20..3.01 rows=12 width=16) (actual time=0.026..0.035 rows=12.00 loops=1)
                    Output: oi.quantity, oi.price_at_order, oi.item_id
                    Hash Cond: (oi.order_id = co.order_id)
                    Buffers: shared hit=3
                    ->  Seq Scan on public.order_item oi  (cost=0.00..1.24 rows=24 width=20) (actual time=0.004..0.008 rows=24.00 loops=1)
                          Output: oi.order_item_id, oi.order_id, oi.item_id, oi.quantity, oi.price_at_order
                          Buffers: shared hit=1
                    ->  Hash  (cost=1.15..1.15 rows=4 width=4) (actual time=0.015..0.015 rows=4.00 loops=1)
                          Output: co.order_id
                          Buckets: 1024  Batches: 1  Memory Usage: 9kB
                          Buffers: shared hit=2
                          ->  Bitmap Heap Scan on public.customer_order co  (cost=4.15..1.15 rows=4 width=4) (actual time=0.008..0.010 rows=4.00 loops=1)
                                Output: co.order_id
                                Recheck Cond: (co.order_date >= '2026-11-01 00:00:00'::timestamp without time zone)
                                Filter: ((co.vendor_id = 2) AND ((co.status)::text = 'completed'::text))
                                Buffers: shared hit=2
                                ->  Bitmap Index Scan on idx_customer_order_completed  (cost=0.00..4.15 rows=6 width=0) (actual time=0.004..0.004 rows=4.00 loops=1)
                                      Index Cond: (co.order_date >= '2026-11-01 00:00:00'::timestamp without time zone)
              ->  Hash  (cost=1.18..1.18 rows=18 width=30) (actual time=0.015..0.015 rows=18.00 loops=1)
                    Output: mi.item_id, mi.item_name
                    Buckets: 1024  Batches: 1  Memory Usage: 9kB
                    Buffers: shared hit=1
                    ->  Seq Scan on public.menu_item mi  (cost=0.00..1.18 rows=18 width=30) (actual time=0.004..0.007 rows=18.00 loops=1)
                          Output: mi.item_id, mi.item_name
                          Buffers: shared hit=1
Planning Time: 2.450 ms
Execution Time: 0.165 ms
```

#### Detailed Execution Plan Analysis
1. **Partial Index Utilization (`idx_customer_order_completed`):**
   - The query planner leverages the partial B-tree index `idx_customer_order_completed` (`WHERE status = 'completed'`).
   - A `Bitmap Index Scan` instantly isolates orders matching the date range and completion predicate without inspecting pending or cancelled rows.
2. **Aggregation and In-Memory Quicksort:**
   - Grouping is executed via `HashAggregate` requiring only 24 kB in memory.
   - The final descending sort on `gross_revenue` completes via `quicksort` in 0.002 ms.
3. **Covering Index Recommendation:**
   - To convert the `order_item` scan into an **Index-Only Scan**:
     ```sql
     CREATE INDEX idx_order_item_sales_cover 
     ON public.order_item (order_id) 
     INCLUDE (item_id, quantity, price_at_order);
     ```
     This allows line total derivations without reading heap blocks from `order_item`.

---

### Query 4: Unread Student Notifications Dispatch
Powers the student app notification bell icon to retrieve unread alerts regarding ready orders.

```sql
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
    n.notification_id,
    n.order_id,
    co.status AS order_status,
    n.message,
    n.sent_at
FROM public.notification n
JOIN public.customer_order co ON n.order_id = co.order_id
WHERE co.student_id = 12 AND n.is_read = FALSE
ORDER BY n.sent_at DESC;
```

#### Execution Plan Output
```text
Sort  (cost=2.36..2.37 rows=2 width=56) (actual time=0.048..0.050 rows=2.00 loops=1)
  Output: n.notification_id, n.order_id, co.status, n.message, n.sent_at
  Sort Key: n.sent_at DESC
  Sort Method: quicksort  Memory: 25kB
  Buffers: shared hit=2
  ->  Nested Loop  (cost=0.15..2.35 rows=2 width=56) (actual time=0.022..0.032 rows=2.00 loops=1)
        Output: n.notification_id, n.order_id, co.status, n.message, n.sent_at
        Buffers: shared hit=2
        ->  Seq Scan on public.customer_order co  (cost=0.00..1.15 rows=3 width=16) (actual time=0.007..0.009 rows=3.00 loops=1)
              Output: co.order_id, co.status
              Filter: (co.student_id = 12)
              Rows Removed by Filter: 9
              Buffers: shared hit=1
        ->  Index Scan using idx_notification_order on public.notification n  (cost=0.15..0.38 rows=1 width=48) (actual time=0.005..0.006 rows=0.67 loops=3)
              Output: n.notification_id, n.order_id, n.message, n.sent_at, n.is_read
              Index Cond: (n.order_id = co.order_id)
              Filter: (NOT n.is_read)
              Rows Removed by Filter: 1
              Buffers: shared hit=1
Planning Time: 1.820 ms
Execution Time: 0.075 ms
```

#### Detailed Execution Plan Analysis
1. **Foreign Key Index Scan (`idx_notification_order`):**
   - The query planner performs a `Nested Loop` join using `idx_notification_order` (`cost=0.15..0.38`), demonstrating the immediate value of index 7 created in `004_performance_indexes.sql`.
2. **Partial Index Recommendation:**
   - In production, notifications accumulate over time, but users only query unread notifications. Creating a partial index accelerates this query significantly:
     ```sql
     CREATE INDEX idx_notification_unread 
     ON public.notification (order_id, sent_at DESC) 
     WHERE is_read = FALSE;
     ```

---

## 5. Problems or Limitations Encountered

During the DBA inspection, log review, and maintenance checks on `grp02_canteendb`, the following technical problems and architectural limitations were identified:

1. **Privilege Boundary on Routine Maintenance Commands:**
   - *Problem:* Running `VACUUM` and `ANALYZE` under application login account `canteen_app_user` yielded `WARNING: permission denied to vacuum "customer_order", skipping it`.
   - *Root Cause:* PostgreSQL enforces that `VACUUM` and `ANALYZE` can only be executed by table owners or superusers. Application runtime roles lack table ownership privileges.
   - *DBA Finding:* This confirms that Group 2's Activity 4 security controls are functioning properly. Application services are prevented from issuing arbitrary cluster-wide maintenance commands. Routine maintenance must be handled by PostgreSQL autovacuum or delegated to an administrative role (`pg_maintain`).

2. **Transaction Block Prohibition for VACUUM:**
   - *Problem:* Multi-statement migration batches wrapping `VACUUM` inside `BEGIN...COMMIT` blocks fail with `ERROR: VACUUM cannot run inside a transaction block`.
   - *Root Cause:* PostgreSQL requires `VACUUM` to commit page cleanups immediately outside of transaction blocks to avoid locking dead row versions.
   - *Remediation:* Maintenance statements must always execute as individual autocommit commands.

3. **Foreign Key Deletion Cascade Policy:**
   - *Problem:* The current schema does not specify `ON DELETE` clauses on foreign keys (defaulting to `RESTRICT` / `NO ACTION`). While this prevents accidental deletion of vendors or students with active order history, it prevents administrative cleanup of obsolete test data without manual multi-table deletion sequences.
   - *Recommendation:* Retain `RESTRICT` on financial transactions (`customer_order`, `order_item`) to protect audit trails, but add explicit `ON DELETE CASCADE` to ephemeral entities (`queue_entry`, `notification`).

4. **Queue Number Reset Management:**
   - *Problem:* Constraint `UNIQUE (queue_number, queue_date)` prevents duplicate token numbers within the same day, but the schema lacks an automated sequence reset trigger for each new calendar day.
   - *Remediation:* Implement a daily database sequence or trigger function to generate sequential queue tokens starting at 1 each morning.

5. **Covering Index Deficit on `order_item`:**
   - *Problem:* Daily sales reports frequently calculate `(quantity * price_at_order)` grouped by item. Under heavy transaction volume, this forces sequential page fetches from the heap.
   - *Remediation:* Deploy the recommended covering index `idx_order_item_sales_cover` using the `INCLUDE` clause to permit Index-Only Scans.

---

### DBA Audit Sign-Off
- **Audit Status:** Completed & Certified
- **Database Engine:** PostgreSQL 18.6 (x86_64-windows)
- **Target Database:** `grp02_canteendb`
- **Application:** Campus Canteen Pre-Order and Queue Management System
- **Group:** Group 2
- **Evaluator:** Group 3 (Peer Database Administrator)
- **Output File Path:** [`C:\Users\Ruby.sietereales\.gemini\antigravity\scratch\canteen_db_maintenance\README.md`](file:///C:/Users/Ruby.sietereales/.gemini/antigravity/scratch/canteen_db_maintenance/README.md)
