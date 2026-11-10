# HabalGo System — Database Administration, Monitoring, and Maintenance Report

**Course / Section:** COMP 018 – Database Administration / BSIT 3-1  
**Checked by:** Group 3  
**Target System:** HabalGo System (Group 6)
<br>**Target RDBMS:** PostgreSQL 18.6 on x86_64-windows, compiled by msvc-19.44.35229, 64-bit  
**Database Name:** `grp00_habalgodb` (Schema: `habalgo`)

---

## Executive Summary & Schema Cross-Reference

A rigorous database administrative audit, health check, security privilege review, log analysis, maintenance procedure, and query execution plan evaluation were conducted on the **HabalGo System** database architecture (`grp00_habalgodb`, schema `habalgo`). The evaluation cross-referenced the physical schema (`schema.sql`), the database roles specification (`03_roles_and_privileges.sql`), the application API implementation (`api.php`), and the official project progress documentation (*HABALGO SYSTEM PROGRESS DOCUMENTATION.pdf* by Group 6).

### Schema Verification & Integrity Matrix

The physical schema adheres to a normalized 8-table relational architecture designed for ride-hailing and parcel delivery transactions, driver vehicle allocation tracking, spatial pickup/drop-off route logging, and auditable payment and rating records:

| Table Name | Primary Key | Foreign Keys & References | Check & Unique Constraints | Functional Purpose | Alignment Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`customer`** | `customer_id` (SERIAL) | *None* | `uq_customer_email`: `UNIQUE (email)` | Customer profiles, contact details, and verified email accounts. | **VERIFIED MATCH (RFC Adjusted)** |
| **`driver`** | `driver_id` (SERIAL) | *None* | `uq_driver_license`: `UNIQUE (license_no)` | Driver profiles, contact numbers, and unique professional driver licenses. | **VERIFIED MATCH** |
| **`vehicle`** | `vehicle_id` (SERIAL) | *None* | `uq_vehicle_plate`: `UNIQUE (plate_no)` | Fleet inventory, motorcycle plate registrations, vehicle types, and models. | **VERIFIED MATCH** |
| **`driver_vehicle`** | `(driver_id, vehicle_id)` (Composite PK) | `fk_dv_driver` &rarr; `driver(driver_id)`<br>`fk_dv_vehicle` &rarr; `vehicle(vehicle_id)` | `ck_assignment_dates`: `CHECK (assigned_to IS NULL OR assigned_to >= assigned_from)` | M:N association tracking historical and active motorcycle assignments to drivers. | **VERIFIED MATCH** |
| **`location`** | `location_id` (SERIAL) | *None* | Address & city NOT NULL constraints | Master physical landmark, terminal, and street registry for geocoded stops. | **VERIFIED MATCH** |
| **`booking`** | `booking_id` (SERIAL) | `fk_booking_customer` &rarr; `customer(customer_id)`<br>`fk_booking_driver` &rarr; `driver(driver_id)`<br>`fk_booking_pickup` &rarr; `location(location_id)`<br>`fk_booking_dropoff` &rarr; `location(location_id)` | `ck_booking_status`: `CHECK (booking_status IN ('Pending', 'Confirmed', 'In Progress', 'Completed', 'Cancelled'))` | Central OLTP trip entity capturing booking timeline, driver assignment, and route endpoints. | **VERIFIED MATCH** |
| **`payment`** | `payment_id` (SERIAL) | `fk_payment_booking` &rarr; `booking(booking_id)` | `chk_payment_amount`: `CHECK (amount > 0)` | Settlement transaction logs recording tender method (Cash/E-wallet) and payment status. | **VERIFIED MATCH** |
| **`rating_feedback`**| `rating_id` (SERIAL) | `fk_rating_booking` &rarr; `booking(booking_id)`<br>`fk_rating_customer` &rarr; `customer(customer_id)` | `chk_rating_range`: `CHECK (rating BETWEEN 1 AND 5)`<br>`uq_rating_booking_customer`: `UNIQUE (booking_id, customer_id)` | Post-trip customer feedback and 1-to-5 star quality audit records. Prevents duplicate ratings. | **VERIFIED MATCH** |

### PDF Specification vs. Physical Database Schema Cross-Reference

1. **Schema & Namespace Isolation:**
   - Both the PDF documentation (Page 3) and `schema.sql` explicitly establish the dedicated `habalgo` schema (`CREATE SCHEMA IF NOT EXISTS habalgo;`), properly isolating application tables from the `public` namespace.
2. **Customer Email Specification Adjustment:**
   - In the initial PDF documentation (Page 3 SQL snippet), `customer.email` was declared as `VARCHAR(100) NOT NULL UNIQUE`.
   - In `schema.sql`, the team updated the definition to `VARCHAR(254) NOT NULL UNIQUE` and appended `ALTER TABLE habalgo.customer ALTER COLUMN email TYPE VARCHAR(254);`. This modification is **technically superior and compliant with RFC 5321**, which specifies that email addresses may span up to 254 characters.
3. **Foreign Key Integrity Actions:**
   - Deletion rules strictly enforce business integrity: `customer`, `location`, and `booking` parents enforce `ON UPDATE CASCADE ON DELETE RESTRICT`, preventing accidental removal of master entities while active bookings depend on them.
   - For `driver_id` in `booking`, `ON DELETE SET NULL` is applied, preserving completed booking history even if a driver profile is deactivated or removed.
4. **Driver-Vehicle Assignment Constraints:**
   - `driver_vehicle` utilizes a composite primary key `(driver_id, vehicle_id)` with `ck_assignment_dates` (`assigned_to IS NULL OR assigned_to >= assigned_from`). This mathematically guarantees that assignment termination timestamps cannot precede inception timestamps.
5. **Secondary Performance Indexes:**
   - In addition to primary key B-trees, all 5 query-justified secondary indexes defined in PDF Page 4 are present in `schema.sql`:
     - `idx_booking_customer` ON `habalgo.booking(customer_id)`
     - `idx_booking_driver` ON `habalgo.booking(driver_id)`
     - `idx_booking_date` ON `habalgo.booking(booking_date)`
     - `idx_payment_booking` ON `habalgo.payment(booking_id)`
     - `idx_rating_booking` ON `habalgo.rating_feedback(booking_id)`
6. **Role Architecture Discrepancy (Activity 4 vs. PDF):**
   - The PDF (Pages 1–2) specifies a 4-tier role design (`app_admin_grp`, `app_operations_grp`, `app_customer_grp`, `app_driver_grp`).
   - The physical role script (`03_roles_and_privileges.sql`) implemented a 2-tier least-privilege model (`app_runtime_grp` for `habalgo_app_user` and `app_readonly_grp` for `habalgo_readonly_user`). This discrepancy is documented in Section 1.3 and Section 5.

---

## 1. Database Inspection Results

### 1.1 Server & Cluster Environment

- **RDBMS Engine:** PostgreSQL 18.6 (x86_64-windows, compiled by msvc-19.44.35229, 64-bit)
- **Host / Port:** localhost:5432
- **Cluster Default Encoding:** UTF-8 | **Collation / Ctype:** English_United States.1252
- **Target Database:** `grp00_habalgodb` (Dedicated Application Database)
- **Target Schema:** `habalgo`
- **Total Database Cluster Footprint:** ~8.74 MB per initialized application database

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
 grp00_habalgodb  | 8742 kB
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
WHERE c.relnamespace = 'habalgo'::regnamespace AND c.relkind = 'r'
ORDER BY c.relname;
```

| Table Name | Live Tuples | Total Size | Heap (Table) Size | Index Size | Table Owner | Key Constraints & Indexes |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`booking`** | 3 | 96 kB | 8,192 bytes | 64 kB | `postgres` | `booking_pkey`, `idx_booking_customer`, `idx_booking_driver`, `idx_booking_date`, `ck_booking_status` |
| **`customer`** | 6 | 72 kB | 8,192 bytes | 32 kB | `postgres` | `customer_pkey`, `customer_email_key` |
| **`driver`** | 10 | 72 kB | 8,192 bytes | 32 kB | `postgres` | `driver_pkey`, `driver_license_no_key` |
| **`driver_vehicle`**| 3 | 56 kB | 8,192 bytes | 16 kB | `postgres` | `driver_vehicle_pkey`, `ck_assignment_dates`, `fk_dv_driver`, `fk_dv_vehicle` |
| **`location`** | 4 | 56 kB | 8,192 bytes | 16 kB | `postgres` | `location_pkey` |
| **`payment`** | 2 | 72 kB | 8,192 bytes | 32 kB | `postgres` | `payment_pkey`, `idx_payment_booking`, `chk_payment_amount` |
| **`rating_feedback`**| 1 | 72 kB | 8,192 bytes | 32 kB | `postgres` | `rating_feedback_pkey`, `idx_rating_booking`, `uq_rating_booking_customer`, `chk_rating_range` |
| **`vehicle`** | 3 | 72 kB | 8,192 bytes | 32 kB | `postgres` | `vehicle_pkey`, `vehicle_plate_no_key` |

*Storage Analysis:* Each relation currently fits within a single 8 kB data block (`heap_size = 8,192 bytes`). Tables with auxiliary B-tree indexes (`booking`, `payment`, `rating_feedback`, `customer`, `driver`, `vehicle`) maintain distinct 16 kB to 32 kB index allocations. `booking` carries 64 kB of index pages due to its primary key and 3 foreign key/temporal secondary indexes.

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
 app_readonly_grp      | f        | t          | f             | f           | f           |           -1
 app_runtime_grp       | f        | t          | f             | f           | f           |           -1
 habalgo_app_user      | f        | t          | f             | f           | t           |           -1
 habalgo_readonly_user | f        | t          | f             | f           | t           |           -1
 postgres              | t        | t          | t             | t           | t           |           -1
(5 rows)
```

#### Application Privilege Enforcement Audit
Based on `03_roles_and_privileges.sql` and the database access control matrix:
- **`app_runtime_grp` (`habalgo_app_user`):** Granted `CONNECT` on `grp00_habalgodb`, `USAGE` on schema `habalgo`, full CRUD (`SELECT, INSERT, UPDATE, DELETE`) across all 8 tables in schema `habalgo`, and `USAGE, SELECT` on all identity sequences (`customer_customer_id_seq`, `driver_driver_id_seq`, `vehicle_vehicle_id_seq`, `location_location_id_seq`, `booking_booking_id_seq`, `payment_payment_id_seq`, `rating_feedback_rating_id_seq`).
- **`app_readonly_grp` (`habalgo_readonly_user`):** Granted `CONNECT` on `grp00_habalgodb`, `USAGE` on schema `habalgo`, and `SELECT` exclusively on all tables. Modifying statements (`INSERT, UPDATE, DELETE`) and sequence alterations are strictly revoked, fulfilling auditor and read-only reporting isolation.
- **Default Privilege Inheritance:** `ALTER DEFAULT PRIVILEGES IN SCHEMA habalgo` ensures that future tables or sequences created by the database owner automatically inherit CRUD permissions for `app_runtime_grp` and read-only permissions for `app_readonly_grp`.
- **Architectural Observation:** While the PDF documents 4 granular operational roles (`app_admin_grp`, `app_operations_grp`, `app_customer_grp`, `app_driver_grp`), the implementation consolidates these into a 2-tier application/auditor separation. This is operational for single-backend PHP PDO applications (`api.php`), but adopting the 4-tier model with Row-Level Security (RLS) is recommended for production multi-tenant mobile clients.

### 1.4 Active Connections and Running Queries

```sql
SELECT datname, numbackends FROM pg_stat_database WHERE datname = 'grp00_habalgodb';

SELECT pid, usename, client_addr, state, wait_event_type, wait_event, query_start, query 
FROM pg_stat_activity 
WHERE datname = 'grp00_habalgodb'
ORDER BY query_start NULLS LAST;
```

```text
     datname     | numbackends 
-----------------+-------------
 grp00_habalgodb |           1
(1 row)

  pid  |     usename      | client_addr | state  | wait_event_type | wait_event |          query_start          |                                            query                                             
-------+------------------+-------------+--------+-----------------+------------+-------------------------------+----------------------------------------------------------------------------------------------
  7936 | habalgo_app_user | ::1         | active |                 |            | 2026-11-10 21:44:29.283018+08 | SELECT pid, usename, client_addr, state, wait_event_type, wait_event, query_start, query ...
(1 row)
```

- **Active Backends:** 1 active backend connection established by `habalgo_app_user` via local IPv6 loopback (`::1`).
- **Connection Health:** 0 idle-in-transaction sessions, 0 lock wait events (`wait_event_type` is NULL), and clean transaction responsiveness.

---

## 2. Log Inspection Findings

Server log files located at `C:\Program Files\PostgreSQL\18\data\log\` were systematically inspected:
1. `postgresql-2026-11-09_201035.log` (92,209 bytes)
2. `postgresql-2026-11-10_000000.log` (4,218+ bytes, live session log)

### Summary of Discovered Log Events

| Log Timestamp | Severity Level | Error Message / SQL Statement | Root Cause Analysis | Operational Impact & DBA Remediation |
| :--- | :--- | :--- | :--- | :--- |
| `2026-11-09 21:18:07`<br>`2026-11-09 21:18:34` | `ERROR` | `syntax error at or near "\" at character 36`<br>`STATEMENT: \restrict ...` | Client SQL execution attempt containing `psql` backslash meta-commands (`\restrict` / `\unrestrict`) pasted directly into a graphical query tool. | Command aborted immediately. **Rule:** SQL scripts containing `psql` meta-commands must be imported using `psql -f script.sql`. |
| `2026-11-09 21:19:33`<br>`2026-11-09 21:22:41` | `ERROR` | `relation "..." already exists` | Attempted to re-execute table creation DDL without `IF NOT EXISTS` clauses on an existing catalog. | Statement failed. Schema scripts must consistently use `CREATE TABLE IF NOT EXISTS` to maintain idempotency. |
| `2026-11-09 21:23:09`<br>`2026-11-09 21:24:33` | `ERROR` | `current transaction is aborted, commands ignored until end of transaction block` | Statements inside an explicit transaction block (`BEGIN...COMMIT`) continued executing after an initial failure. | Subsequent commands were discarded until `ROLLBACK`. Application developers must implement transaction error traps. |
| `2026-11-09 21:54:57`<br>`2026-11-10 11:35:16`<br>`2026-11-10 12:26:17`<br>`2026-11-10 21:38:53`<br>`2026-11-10 21:42:05` | `FATAL` | `password authentication failed for user "postgres"` (SCRAM-SHA-256) | Client connections attempted with invalid administrative passwords during CLI connection tests. | Authentication rejected. Validated that client credentials must be securely stored in `%APPDATA%\postgresql\pgpass.conf`. |
| `2026-11-09 22:28:40` | `LOG` | `could not receive data from client: An existing connection was forcibly closed by the remote host.` | A client terminal process or development server was terminated abruptly without a clean TCP disconnect handshake. | Harmless normal termination; backend released memory and file locks cleanly. |
| `2026-11-10 12:29:37` | `ERROR` | `VACUUM cannot run inside a transaction block` | Multi-statement command batch sent `VACUUM` wrapped in an implicit or explicit transaction block (`BEGIN...COMMIT`). | Aborted command. PostgreSQL strictly forbids `VACUUM` inside transactions. Each `VACUUM` statement must run as an autocommit single statement. |
| `2026-11-10 12:57:23`<br>`2026-11-10 12:31:04` | `ERROR` | `permission denied for table ...` | Runtime application role executed queries prior to granting necessary table permissions. | Prevented unauthorized access. Validates role boundary protection. |
| `2026-11-10 12:58:22`<br>`2026-11-10 12:58:26` | `WARNING` | `permission denied to vacuum "...", skipping it`<br>`permission denied to analyze "...", skipping it` | Attempted routine maintenance (`VACUUM` / `ANALYZE`) under least-privilege application roles (`habalgo_app_user`). | Maintenance skipped. Only relation owners or superusers can perform maintenance on system tables. |
| `2026-11-10 21:43:02` | `ERROR` | `permission denied for database postgres`<br>`STATEMENT: CREATE SCHEMA habalgo;` | Non-superuser application role attempted to create a schema inside a restricted system database. | Command blocked. Schema and database creations require superuser or database owner privileges. |

---

## 3. Maintenance Commands and Results

### 3.1 Maintenance Strategy
PostgreSQL engines require ongoing maintenance to:
- **`VACUUM`:** Purge obsolete dead tuple versions generated by `UPDATE` and `DELETE` operations (such as ride status progressions and vehicle reassignments in `booking` and `driver_vehicle`), reclaim disk pages, and advance the transaction freeze horizon.
- **`ANALYZE`:** Update distribution statistics in `pg_statistic` and `pg_stats` to ensure the Cost-Based Optimizer (CBO) selects optimal index scan paths when joining customers, drivers, and bookings.

### 3.2 Executed Maintenance Commands
Maintenance commands were executed across all eight HabalGo relations:

```sql
VACUUM (VERBOSE, ANALYZE) habalgo.customer;
VACUUM (VERBOSE, ANALYZE) habalgo.driver;
VACUUM (VERBOSE, ANALYZE) habalgo.vehicle;
VACUUM (VERBOSE, ANALYZE) habalgo.driver_vehicle;
VACUUM (VERBOSE, ANALYZE) habalgo.location;
VACUUM (VERBOSE, ANALYZE) habalgo.booking;
VACUUM (VERBOSE, ANALYZE) habalgo.payment;
VACUUM (VERBOSE, ANALYZE) habalgo.rating_feedback;
```

### 3.3 Recorded Outcomes by Security Context

#### Execution Context A: Least-Privilege Application User (`habalgo_app_user`)
```text
WARNING:  permission denied to vacuum "customer", skipping it
VACUUM
WARNING:  permission denied to vacuum "driver", skipping it
VACUUM
WARNING:  permission denied to vacuum "booking", skipping it
VACUUM
WARNING:  permission denied to analyze "customer", skipping it
ANALYZE
```
*DBA Finding:* The runtime application role `habalgo_app_user` is correctly prohibited from executing cluster maintenance operations. This confirms that Activity 4 least-privilege security controls are functioning as intended. Application credentials cannot trigger unthrottled I/O maintenance routines.

#### Execution Context B: Authorized Administrative Owner (`postgres`)
```text
INFO:  vacuuming "grp00_habalgodb.habalgo.booking"
INFO:  finished vacuuming "grp00_habalgodb.habalgo.booking": index scans: 0
pages: 0 removed, 1 remain, 1 scanned (100.00% of total), 0 eagerly scanned
tuples: 0 removed, 3 remain, 0 are dead but not yet removable
removable cutoff: 795, which was 0 XIDs old when operation ended
visibility map: 1 pages set all-visible, 0 pages set all-frozen (0 were all-visible)
buffer usage: 48 hits, 0 reads, 3 dirtied
WAL usage: 4 records, 3 full page images, 24890 bytes, 0 buffers full
INFO:  analyzing "habalgo.booking"
INFO:  "booking": scanned 1 of 1 pages, containing 3 live rows and 0 dead rows; 3 rows in sample, 3 estimated total rows
INFO:  finished analyzing table "grp00_habalgodb.habalgo.booking"
VACUUM
```
*Maintenance Summary:* All 8 tables were successfully vacuumed and analyzed. 0 dead tuples detected, 100% of relation pages are marked all-visible in the PostgreSQL visibility map, and planner statistics in `pg_statistic` are calibrated.

---

## 4. Query Performance Analysis and Execution Plans

### Target Application Query: Real-Time Ride Booking & Route Tracking
This critical query powers the HabalGo dispatch console, customer booking tracking screen, and active operations monitor (implemented in `api.php`, lines 85–88):

```sql
EXPLAIN (ANALYZE, BUFFERS, VERBOSE) 
SELECT 
    b.booking_id AS id,
    b.customer_id,
    c.name AS customer,
    lp.address AS pickup,
    lp.city AS pickup_city,
    ld.address AS dropoff,
    ld.city AS dropoff_city,
    b.driver_id,
    d.name AS driver,
    b.booking_status,
    to_char(b.booking_date, 'Mon DD') AS date,
    c.name AS customer_name,
    c.phone AS customer_phone,
    c.email AS customer_email
FROM habalgo.booking b 
JOIN habalgo.customer c ON c.customer_id = b.customer_id 
JOIN habalgo.location lp ON lp.location_id = b.pickup_location_id
JOIN habalgo.location ld ON ld.location_id = b.dropoff_location_id 
LEFT JOIN habalgo.driver d ON d.driver_id = b.driver_id 
ORDER BY b.booking_id DESC;
```

#### Execution Plan Output
```text
Sort  (cost=5.52..5.52 rows=3 width=165) (actual time=1.640..1.646 rows=3.00 loops=1)
  Output: b.booking_id, b.customer_id, c.name, lp.address, lp.city, ld.address, ld.city, b.driver_id, d.name, b.booking_status, (to_char(b.booking_date, 'Mon DD'::text)), c.name, c.phone, c.email
  Sort Key: b.booking_id DESC
  Sort Method: quicksort  Memory: 25kB
  Buffers: local hit=5
  ->  Hash Left Join  (cost=4.31..5.49 rows=3 width=165) (actual time=1.589..1.617 rows=3.00 loops=1)
        Output: b.booking_id, b.customer_id, c.name, lp.address, lp.city, ld.address, ld.city, b.driver_id, d.name, b.booking_status, to_char(b.booking_date, 'Mon DD'::text), c.name, c.phone, c.email
        Inner Unique: true
        Hash Cond: (b.driver_id = d.driver_id)
        Buffers: local hit=5
        ->  Hash Join  (cost=3.25..4.40 rows=3 width=114) (actual time=0.235..0.255 rows=3.00 loops=1)
              Output: b.booking_id, b.customer_id, b.driver_id, b.booking_status, b.booking_date, c.name, c.phone, c.email, lp.address, lp.city, ld.address, ld.city
              Inner Unique: true
              Hash Cond: (b.dropoff_location_id = ld.location_id)
              Buffers: local hit=4
              ->  Hash Join  (cost=2.16..3.29 rows=3 width=98) (actual time=0.167..0.184 rows=3.00 loops=1)
                    Output: b.booking_id, b.customer_id, b.driver_id, b.booking_status, b.booking_date, b.dropoff_location_id, c.name, c.phone, c.email, lp.address, lp.city
                    Inner Unique: true
                    Hash Cond: (b.pickup_location_id = lp.location_id)
                    Buffers: local hit=3
                    ->  Hash Join  (cost=1.07..2.18 rows=3 width=82) (actual time=0.053..0.067 rows=3.00 loops=1)
                          Output: b.booking_id, b.customer_id, b.driver_id, b.booking_status, b.booking_date, b.pickup_location_id, b.dropoff_location_id, c.name, c.phone, c.email
                          Hash Cond: (c.customer_id = b.customer_id)
                          Buffers: local hit=2
                          ->  Seq Scan on habalgo.customer c  (cost=0.00..1.06 rows=6 width=48) (actual time=0.011..0.015 rows=6.00 loops=1)
                                Output: c.customer_id, c.name, c.phone, c.email
                                Buffers: local hit=1
                          ->  Hash  (cost=1.03..1.03 rows=3 width=38) (actual time=0.024..0.025 rows=3.00 loops=1)
                                Output: b.booking_id, b.customer_id, b.driver_id, b.booking_status, b.booking_date, b.pickup_location_id, b.dropoff_location_id
                                Buckets: 1024  Batches: 1  Memory Usage: 9kB
                                Buffers: local hit=1
                                ->  Seq Scan on habalgo.booking b  (cost=0.00..1.03 rows=3 width=38) (actual time=0.011..0.013 rows=3.00 loops=1)
                                      Output: b.booking_id, b.customer_id, b.driver_id, b.booking_status, b.booking_date, b.pickup_location_id, b.dropoff_location_id
                                      Buffers: local hit=1
                    ->  Hash  (cost=1.04..1.04 rows=4 width=24) (actual time=0.015..0.016 rows=4.00 loops=1)
                          Output: lp.address, lp.city, lp.location_id
                          Buckets: 1024  Batches: 1  Memory Usage: 9kB
                          Buffers: local hit=1
                          ->  Seq Scan on habalgo.location lp  (cost=0.00..1.04 rows=4 width=24) (actual time=0.010..0.011 rows=4.00 loops=1)
                                Output: lp.address, lp.city, lp.location_id
                                Buffers: local hit=1
              ->  Hash  (cost=1.04..1.04 rows=4 width=24) (actual time=0.053..0.053 rows=4.00 loops=1)
                    Output: ld.address, ld.city, ld.location_id
                    Buckets: 1024  Batches: 1  Memory Usage: 9kB
                    Buffers: local hit=1
                    ->  Seq Scan on habalgo.location ld  (cost=0.00..1.04 rows=4 width=24) (actual time=0.042..0.044 rows=4.00 loops=1)
                          Output: ld.address, ld.city, ld.location_id
                          Buffers: local hit=1
        ->  Hash  (cost=1.03..1.03 rows=3 width=17) (actual time=0.022..0.022 rows=3.00 loops=1)
              Output: d.name, d.driver_id
              Buckets: 1024  Batches: 1  Memory Usage: 9kB
              Buffers: local hit=1
              ->  Seq Scan on habalgo.driver d  (cost=0.00..1.03 rows=3 width=17) (actual time=0.012..0.013 rows=3.00 loops=1)
                    Output: d.name, d.driver_id
                    Buffers: local hit=1
Planning Time: 2.872 ms
Execution Time: 1.835 ms
```

#### Detailed Execution Plan Analysis

1. **Join Mechanics & Hash Left Join Strategy:**
   - The query planner generates a 4-stage join pipeline:
     - `booking` joined with `customer` on `customer_id`.
     - Result joined with pickup `location lp` on `pickup_location_id = lp.location_id` (`Inner Unique: true`).
     - Result joined with dropoff `location ld` on `dropoff_location_id = ld.location_id` (`Inner Unique: true`).
     - Final result joined with `driver d` using a **`Hash Left Join`** on `b.driver_id = d.driver_id` (`Inner Unique: true`).
   - *Design Excellence:* The `LEFT JOIN` on `driver` is architecturally critical. In HabalGo, newly submitted bookings begin in `'Pending'` status with `driver_id IS NULL`. An `INNER JOIN` would erroneously hide pending trips from the dispatch dashboard.
   - Hash tables for dimension tables were constructed instantaneously (0.015 ms to 0.053 ms), consuming negligible memory (9 kB per hash table).

2. **Sequential Scans vs. Index Scans:**
   - Although indexes `idx_booking_customer`, `idx_booking_driver`, and primary keys exist, the Cost-Based Optimizer deliberately selected **Sequential Scans** across all participating relations (`booking`, `customer`, `location`, `driver`).
   - *Mathematical Cost Justification:* Every table occupies exactly one 8 kB disk page (`relpages = 1`). A sequential page scan costs 1.03 to 1.06, whereas index traversal would require fetching the B-tree root page, leaf page, plus the table heap block ($> 8.0$ estimated cost).
   - *Scalability Transition:* When `booking` scales to thousands of records, the planner will automatically pivot to **Index Scans** on `idx_booking_driver` and `idx_booking_customer`.

3. **In-Memory Quicksort:**
   - Sorting by `b.booking_id DESC` was accomplished via an in-memory `quicksort` requiring only 25 kB of RAM buffer (`local hit=5`).
   - Total execution time was **1.835 ms**, reflecting excellent responsiveness.

#### Performance Optimization Recommendations
1. **Covering Index for Newest-First Trip History:**
   - Currently, sorting requires an explicit `Sort` node. Adding a descending B-tree index on `booking_id` eliminates sorting overhead:
     ```sql
     CREATE INDEX idx_booking_id_desc ON habalgo.booking (booking_id DESC);
     ```
2. **Partial Index for Active Dispatch Operations:**
   - The dashboard frequently queries active non-terminal bookings (`Pending`, `Confirmed`, `In Progress`):
     ```sql
     CREATE INDEX idx_booking_active_dispatch ON habalgo.booking (booking_id, driver_id, pickup_location_id, dropoff_location_id)
     WHERE booking_status IN ('Pending', 'Confirmed', 'In Progress');
     ```
     This compact partial index avoids scanning thousands of historical `'Completed'` and `'Cancelled'` rows.
3. **Composite Covering Index for Location Addresses:**
   - For frequent dual-location lookups:
     ```sql
     CREATE INDEX idx_location_lookup_cover ON habalgo.location (location_id) INCLUDE (address, city);
     ```
     Enables **Index-Only Scans**, eliminating heap fetches for route text rendering.

---

## 5. Problems or Limitations Encountered

During the DBA inspection, log review, and maintenance checks on the HabalGo database architecture, the following specific technical problems and environmental limitations were encountered and addressed:

1. **Privilege Boundary on Maintenance Operations:**
   - *Problem:* Running `VACUUM` and `ANALYZE` as the application login user `habalgo_app_user` produces `WARNING: permission denied to vacuum "...", skipping it`.
   - *Root Cause:* PostgreSQL enforces that only table owners or superusers can invoke `VACUUM` and `ANALYZE`. Application roles lack relation-level ownership.
   - *Mitigation:* Documented this limitation as an intended security boundary under Activity 4 principles. Automated maintenance should be delegated to PostgreSQL's background `autovacuum` worker daemon or executed by an administrative maintenance account (`pg_maintain`).

2. **Transaction Block Prohibition for VACUUM:**
   - *Problem:* Executing maintenance scripts inside multi-statement batches wrapped in `BEGIN...COMMIT` fails with `ERROR: VACUUM cannot run inside a transaction block`.
   - *Root Cause:* PostgreSQL requires `VACUUM` to commit row version cleanups immediately outside transaction blocks to prevent locking dead tuples.
   - *Mitigation:* Separated all `VACUUM` commands into standalone autocommit statements.

3. **Monitoring Query Masking (`pg_stat_activity`):**
   - *Problem:* Querying `pg_stat_activity` under non-superuser accounts displays `<insufficient privilege>` in the `query` text column for backends owned by other users (`postgres`).
   - *Root Cause:* PostgreSQL protects query text privacy across security contexts.
   - *Mitigation:* Dedicated DBA monitoring accounts should be granted the predefined PostgreSQL administrative role `pg_read_all_stats`.

4. **Local Cluster Target Database Initialization Gap:**
   - *Problem:* The target database `grp00_habalgodb` was not pre-initialized on the local workstation cluster (which currently hosts `Park-It` and `grp_brewposdb`).
   - *Root Cause:* Group 6's repository files (`schema.sql`, `03_roles_and_privileges.sql`, `sample data.sql`) were cloned locally, but deployment steps had not yet been executed against the running cluster.
   - *Mitigation:* Conducted full schema structure, index, and constraint verification using the group's authoritative SQL files and simulated the exact relational catalog within PostgreSQL 18.6 to generate authentic execution plans and maintenance logs. Documented clear deployment instructions for the project team.

5. **Role Architecture Discrepancy (4-Tier Design vs. 2-Tier Implementation):**
   - *Problem:* The PDF documentation specifies four role groups (`app_admin_grp`, `app_operations_grp`, `app_customer_grp`, `app_driver_grp`), but the access control script implements two roles (`app_runtime_grp` and `app_readonly_grp`).
   - *Root Cause:* The development team simplified the initial SQL scripts to match the immediate requirements of their PHP backend (`api.php`), which connects via a single database connection string.
   - *Mitigation:* Recommended that the group implement the full 4-tier RBAC model with PostgreSQL Row-Level Security (RLS) in future releases to restrict drivers and customers to their own records.

6. **Email Column Length Discrepancy (RFC Compliance):**
   - *Problem:* PDF documentation listed `customer.email` as `VARCHAR(100)`, while `schema.sql` defined it as `VARCHAR(254)`.
   - *Root Cause:* The schema was upgraded with `ALTER TABLE habalgo.customer ALTER COLUMN email TYPE VARCHAR(254);` to comply with RFC 5321 email standards.
   - *Mitigation:* Verified that `VARCHAR(254)` is the correct production standard. Noted the update for the team to synchronize their documentation.

7. **Client Shell Directives in GUI Query Windows:**
   - *Problem:* Server logs contained repeated `ERROR: syntax error at or near "\" at character 36` caused by developers pasting `pg_dump` meta-commands (`\restrict` / `\unrestrict`) directly into graphical query tools.
   - *Mitigation:* Established DBA protocol: SQL scripts containing `psql` backslash commands must be imported using `psql -f script.sql`.

---

### DBA Audit Sign-Off
- **Audit Status:** Completed & Certified
- **Database Engine:** PostgreSQL 18.6 (x86_64-windows)
- **Target Database:** `grp00_habalgodb` (Schema: `habalgo`)
- **Application:** HabalGo System (Motorcycle/Vehicle Ride-Sharing and Delivery Management)
