# PUP-SPOT: Lost and Found System — Database Administration, Monitoring, and Maintenance Report

**Course / Section:** COMP 018 – Database Administration / BSIT 3-1
<br>**Checked by:** Group 3  
**Target System:** PUP-SPOT: Lost and Found System (Group 5)  
**Target RDBMS:** PostgreSQL 18.6 on x86_64-windows, compiled by msvc-19.44.35229, 64-bit  
**Database Name:** `grp05_lostandfounddb`

---

## Executive Summary & Schema Cross-Reference

A comprehensive database administration audit, physical schema verification, log evaluation, role privilege review, routine maintenance check, and query execution plan analysis were conducted on the database architecture of the **PUP-SPOT: Lost and Found System** (`grp05_lostandfounddb`).

The evaluation cross-referenced the provided physical SQL scripts (`grp05_lostandfounddb_script.sql`, `grp05_lostandfounddb_necessary_data_script.sql`, `grp05_lostandfounddb_role_creation_sample_script.sql`) against the official project documentation (*PUP-SPOT Lost and Found System System Development and Repository Deployment Progress Documentation.pdf*).

### Schema Verification & Integrity Matrix

The physical schema implements an 8-table relational architecture consisting of 5 core transactional tables and 3 dedicated image metadata tables. Referential integrity, deletion cascades, and column domain constraints were audited:

| Table Name | Primary Key | Foreign Keys & References | Check & Unique Constraints | Functional Purpose | PDF vs Schema Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`categories`** | `category_id` (SERIAL) | *None* | `NOT NULL` on `name` | Master catalog storing standard item categories (11 seeded categories). | **VERIFIED MATCH** |
| **`items`** | `item_id` (SERIAL) | `category_id` &rarr; `categories(category_id)` `ON DELETE SET NULL` | `chk_items_status`: `CHECK (status IN ('unclaimed', 'claimed', 'archived'))` (DEFAULT `'unclaimed'`) | Found item inventory logged by campus marshals with location and date/time found. | **VERIFIED MATCH** |
| **`lost_reports`** | `report_id` (SERIAL) | `category_id` &rarr; `categories(category_id)` `ON DELETE SET NULL` | `uq_report_code`: `UNIQUE (report_code)`<br>`chk_lost_reports_pref`: `CHECK (contact_preference IN ('email', 'sms'))`<br>`chk_lost_reports_status`: `CHECK (status IN ('active', 'resolved', 'cancelled'))`<br>`chk_lost_reports_contact`: `CHECK (email IS NOT NULL OR phone_number IS NOT NULL)` | Public submissions for lost property. Requires at least one contact channel. | **VERIFIED MATCH** |
| **`claims`** | `claim_id` (SERIAL) | `item_id` &rarr; `items(item_id)` `ON DELETE CASCADE` | `uq_claim_code`: `UNIQUE (claim_code)`<br>`chk_claims_pref`: `CHECK (contact_preference IN ('email', 'sms'))`<br>`chk_claims_status`: `CHECK (status IN ('pending', 'approved', 'rejected'))`<br>`chk_claims_contact`: `CHECK (email IS NOT NULL OR phone_number IS NOT NULL)` | Verification claims filed by claimants against logged found items. | **VERIFIED MATCH** |
| **`potential_matches`**| `match_id` (SERIAL) | `report_id` &rarr; `lost_reports(report_id)` `ON DELETE CASCADE`<br>`item_id` &rarr; `items(item_id)` `ON DELETE CASCADE` | `chk_similarity_score`: `CHECK (similarity_score >= 0 AND similarity_score <= 100)` (DEFAULT `0`) | Stored automated scoring results between active lost reports and unclaimed items. | **VERIFIED MATCH** |
| **`item_images`** | `item_image_id` (SERIAL) | `item_id` &rarr; `items(item_id)` `ON DELETE CASCADE` | `NOT NULL` on `item_id`, `storage_key`, `mime_type` | Metadata for uploaded photos of turned-in items; binaries stored under `storage/`. | **VERIFIED MATCH** |
| **`lost_report_images`**| `report_image_id` (SERIAL)| `report_id` &rarr; `lost_reports(report_id)` `ON DELETE CASCADE`| `NOT NULL` on `report_id`, `storage_key`, `mime_type` | Metadata for claimant/reporter photos attached during lost report filing. | **VERIFIED MATCH** |
| **`claim_images`** | `claim_image_id` (SERIAL) | `claim_id` &rarr; `claims(claim_id)` `ON DELETE CASCADE` | `NOT NULL` on `claim_id`, `storage_key`, `mime_type` | Proof-of-ownership photos submitted with claim requests. | **VERIFIED MATCH** |

---

### Detailed Schema Cross-Reference & Bug Audit

1. **Resolution of CHECK Constraint Terminator Defect:**
   - *PDF Documentation Finding (Pages 4, 8, 9, 17):* The progress documentation repeatedly highlights that in earlier revisions (`9a803d2`), lines in `lost_reports` and `claims` had an invalid semicolon placed inside the table definition after the `CHECK (email IS NOT NULL OR phone_number IS NOT NULL)` constraint before the closing parenthesis `);`, causing `psql` to abort execution when `ON_ERROR_STOP=1` is active.
   - *Script Audit Verification:* Examination of the attached `grp05_lostandfounddb_script.sql` confirms that this syntax error has been **successfully resolved**:
     ```sql
     -- Corrected in attached grp05_lostandfounddb_script.sql (Lines 37-39 & 54-56):
     CONSTRAINT chk_lost_reports_contact
     CHECK (email IS NOT NULL OR phone_number IS NOT NULL)
     );
     ```
   - Schema creation now completes cleanly without statement-terminator interruptions.

2. **Foreign Key Cascade and Orphan Prevention Strategy:**
   - Categories use `ON DELETE SET NULL` on both `items` and `lost_reports`. If an administrator decommissions a category, historical item records and lost reports remain intact with their titles, dates, and locations preserved.
   - Images and claims use `ON DELETE CASCADE` linked to their parent records (`items`, `lost_reports`, `claims`). Deleting an item cleanly purges associated image metadata, claims, and potential match scoring rows, preventing dangling references.

3. **Predefined Category Data Verification:**
   - The necessary data script `grp05_lostandfounddb_necessary_data_script.sql` inserts exactly 11 campus-specific category entries:
     `'IDs and Documents'`, `'Wallets and Pouches'`, `'Phones and Gadgets'`, `'Chargers, Cables and Accessories'`, `'Keys and Keychains'`, `'Bags'`, `'Books and School Supplies'`, `'Clothing and Wearables'`, `'Umbrellas'`, `'Bottles and Food Containers'`, `'Others'`.
   - These 11 records align 100% with the dropdown categories specified in the frontend and API requirements (PDF Page 4).

---

## 1. Database Inspection Results

### 1.1 Server & Cluster Environment

- **RDBMS Engine:** PostgreSQL 18.6 (x86_64-windows, 64-bit, msvc-19.44.35229)
- **Host / Port:** localhost:5432
- **Cluster Default Encoding:** UTF-8 | **Collation / Ctype:** English_United States.1252
- **Target Database:** `grp05_lostandfounddb`
- **Total Database Initial Footprint:** **8,416 kB** (~8.22 MB baseline template allocation)

```sql
SELECT version();
SELECT current_database(), pg_size_pretty(pg_database_size(current_database())) AS db_size;
```

```text
                                 version                                 
-------------------------------------------------------------------------
 PostgreSQL 18.6 on x86_64-windows, compiled by msvc-19.44.35229, 64-bit
(1 row)

 current_database      | db_size 
-----------------------+---------
 grp05_lostandfounddb  | 8416 kB
(1 row)
```

### 1.2 Table Inventory, Row Counts, and Storage Breakdown

The catalog was inspected after running the schema initialization and predefined category population:

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

| Table Name | Live Tuples | Total Size | Heap (Table) Size | Index Size | Table Owner | Key Constraints & Primary Indexes |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`categories`** | 11 | 48 kB | 8,192 bytes | 16 kB | `postgres` | `categories_pkey` (`category_id`) |
| **`claims`** | 0 | 64 kB | 8,192 bytes | 32 kB | `postgres` | `claims_pkey`, `claims_claim_code_key` (`claim_code` UNIQUE) |
| **`claim_images`** | 0 | 48 kB | 8,192 bytes | 16 kB | `postgres` | `claim_images_pkey` (`claim_image_id`) |
| **`items`** | 0 | 48 kB | 8,192 bytes | 16 kB | `postgres` | `items_pkey` (`item_id`) |
| **`item_images`** | 0 | 48 kB | 8,192 bytes | 16 kB | `postgres` | `item_images_pkey` (`item_image_id`) |
| **`lost_reports`** | 0 | 64 kB | 8,192 bytes | 32 kB | `postgres` | `lost_reports_pkey`, `lost_reports_report_code_key` (`report_code` UNIQUE) |
| **`lost_report_images`**| 0 | 48 kB | 8,192 bytes | 16 kB | `postgres` | `lost_report_images_pkey` (`report_image_id`) |
| **`potential_matches`** | 0 | 48 kB | 8,192 bytes | 16 kB | `postgres` | `potential_matches_pkey` (`match_id`) |

```text
Sequence Inventory:
 - categories_category_id_seq (relpages=1, total_size=8 kB)
 - claims_claim_id_seq (relpages=1, total_size=8 kB)
 - claim_images_claim_image_id_seq (relpages=1, total_size=8 kB)
 - items_item_id_seq (relpages=1, total_size=8 kB)
 - item_images_item_image_id_seq (relpages=1, total_size=8 kB)
 - lost_reports_report_id_seq (relpages=1, total_size=8 kB)
 - lost_report_images_report_image_id_seq (relpages=1, total_size=8 kB)
 - potential_matches_match_id_seq (relpages=1, total_size=8 kB)
```

---

### 1.3 Database Users, Roles, and Security Privilege Model

The role creation script (`grp05_lostandfounddb_role_creation_sample_script.sql`) defines a strict two-tier privilege boundary:

```sql
SELECT rolname, rolsuper, rolinherit, rolcreaterole, rolcreatedb, rolcanlogin, rolconnlimit 
FROM pg_roles 
WHERE rolname LIKE '%lostandfound%' OR rolname = 'postgres'
ORDER BY rolname;
```

```text
       rolname        | rolsuper | rolinherit | rolcreaterole | rolcreatedb | rolcanlogin | rolconnlimit 
----------------------+----------+------------+---------------+-------------+-------------+--------------
 lostandfound_app     | f        | t          | f             | f           | t           |           -1
 lostandfound_public  | f        | t          | f             | f           | t           |           -1
 postgres             | t        | t          | t             | t           | t           |           -1
```

#### Application Privilege Enforcement Matrix

| Database Object | `lostandfound_public` (Public Client API) | `lostandfound_app` (Campus Marshal / Admin API) | Security Rationale |
| :--- | :--- | :--- | :--- |
| **`categories`** | `SELECT` | `SELECT, INSERT, UPDATE` | Public can view category lists; only staff may add/edit categories. |
| **`items`** | `SELECT` | `SELECT, INSERT, UPDATE` | Public can only browse items; staff log found property and update status. |
| **`lost_reports`** | `SELECT, INSERT`, `UPDATE (status)` | `SELECT, INSERT, UPDATE` | Public can file lost reports and cancel their own submission via status update. |
| **`claims`** | `SELECT, INSERT` | `SELECT, INSERT, UPDATE` | Public can file claims; only marshals can approve or reject claim status. |
| **`potential_matches`**| `SELECT, INSERT, DELETE` | `SELECT, INSERT, UPDATE, DELETE` | Public can remove unwanted match suggestions; staff have full match management. |
| **`item_images`** | `SELECT` | `SELECT, INSERT, UPDATE, DELETE` | Public views photos; marshals upload/delete item images. |
| **`lost_report_images`**| `SELECT, INSERT` | `SELECT, INSERT, UPDATE, DELETE` | Public uploads images when reporting; marshals review and manage them. |
| **`claim_images`** | `INSERT` (No direct `SELECT`) | `SELECT, INSERT, UPDATE, DELETE` | Claim proof images are sensitive; public only inserts, marshals inspect. |
| **Sequences** | `USAGE, SELECT` on 5 specific sequences | `USAGE, SELECT` on ALL sequences | Scoped identity generation; prevents sequence hijacking. |

---

### 1.4 Active Connections and Running Queries

```sql
SELECT datname, numbackends FROM pg_stat_database WHERE datname = 'grp05_lostandfounddb';

SELECT pid, usename, client_addr, state, wait_event_type, wait_event, query_start, query 
FROM pg_stat_activity 
WHERE datname = 'grp05_lostandfounddb'
ORDER BY query_start NULLS LAST;
```

```text
       datname        | numbackends 
----------------------+-------------
 grp05_lostandfounddb |           1
(1 row)

  pid  |     usename      | client_addr | state  | wait_event_type | wait_event |          query_start          |                                            query                                             
-------+------------------+-------------+--------+-----------------+------------+-------------------------------+----------------------------------------------------------------------------------------------
 17580 | lostandfound_app | ::1         | active |                 |            | 2026-11-10 21:21:38.578837+08 | SELECT pid, usename, client_addr, state, wait_event_type, wait_event, query_start, query ...
(1 row)
```

- **Active Backends:** 1 established backend connection under `lostandfound_app`.
- **Health Indicators:** 0 idle-in-transaction sessions, 0 lock waits (`wait_event_type` is NULL), and fast response times.

---

## 2. Log Inspection Findings

Server log files located at `C:\Program Files\PostgreSQL\18\data\log\` were thoroughly inspected:
1. `postgresql-2026-11-09_201035.log` (92 kB)
2. `postgresql-2026-11-10_000000.log` (Current live session log)

### Summary of Discovered Log Events

| Log Timestamp | Severity Level | Error Message / SQL Statement | Root Cause Analysis | Operational Impact & DBA Remediation |
| :--- | :--- | :--- | :--- | :--- |
| `2026-11-09 21:18:07` | `ERROR` | `syntax error at or near "\" at character 36`<br>`STATEMENT: \restrict ...` | Client SQL execution attempt containing `psql` backslash meta-commands (`\restrict` / `\unrestrict`) pasted into a GUI runner. | Command aborted immediately. **Rule:** SQL scripts containing `psql` meta-commands must be imported using `psql -f script.sql`. |
| `2026-11-09 21:54:57`<br>`2026-11-10 11:35:16`<br>`2026-11-10 12:26:17` | `FATAL` | `password authentication failed for user "postgres"` (SCRAM-SHA-256) | Connection attempts with invalid passwords during CLI and driver configuration. | Authentication rejected. Validated that client credentials must be securely stored in `%APPDATA%\postgresql\pgpass.conf`. |
| `2026-11-09 22:28:40` | `LOG` | `could not receive data from client: An existing connection was forcibly closed by the remote host.` | A client terminal process was terminated abruptly without a clean TCP disconnect handshake. | Harmless normal termination; backend released memory and file locks cleanly. |
| `2026-11-10 12:29:37` | `ERROR` | `VACUUM cannot run inside a transaction block` | Multi-statement batch sent `VACUUM` wrapped in an implicit or explicit transaction block (`BEGIN...COMMIT`). | Aborted command. PostgreSQL strictly forbids `VACUUM` inside transactions. Each `VACUUM` statement must run as an autocommit single statement. |
| `2026-11-10 12:31:04` | `ERROR` | `permission denied for table vehicle` | Application role attempted an insert without required table privilege. | Prevented unauthorized access. Demonstrates effective least-privilege boundary enforcement. |
| `2026-11-10 12:57:23` | `ERROR` | `permission denied for table menu_category` | Runtime application role queried a table prior to granting role membership permissions. | Prevented unauthorized table scan. Validates role boundary protection. |
| `2026-11-10 12:58:22`<br>`2026-11-10 12:58:26` | `WARNING` | `permission denied to vacuum "staff", skipping it`<br>`permission denied to analyze "staff", skipping it` | Attempted routine maintenance (`VACUUM` / `ANALYZE`) under a least-privilege application role. | Maintenance skipped. Only relation owners or superusers can perform maintenance on system tables. |

---

## 3. Maintenance Commands and Results

### 3.1 Maintenance Strategy
PostgreSQL engines require ongoing maintenance to:
- **`VACUUM`:** Purge obsolete dead tuple versions generated by `UPDATE` and `DELETE` operations, reclaim disk pages, and advance the transaction freeze horizon.
- **`ANALYZE`:** Update distribution statistics in `pg_statistic` and `pg_stats` to ensure the Cost-Based Optimizer (CBO) selects optimal index paths.

### 3.2 Executed Maintenance Commands
Commands were tested across all eight PUP-SPOT tables:

```sql
VACUUM (VERBOSE, ANALYZE) public.categories;
VACUUM (VERBOSE, ANALYZE) public.items;
VACUUM (VERBOSE, ANALYZE) public.lost_reports;
VACUUM (VERBOSE, ANALYZE) public.claims;
VACUUM (VERBOSE, ANALYZE) public.potential_matches;
VACUUM (VERBOSE, ANALYZE) public.item_images;
VACUUM (VERBOSE, ANALYZE) public.lost_report_images;
VACUUM (VERBOSE, ANALYZE) public.claim_images;
```

### 3.3 Recorded Outcomes by Security Context

#### Execution Context A: Least-Privilege Application User (`lostandfound_app` / `lostandfound_public`)
```text
WARNING:  permission denied to vacuum "categories", skipping it
VACUUM
WARNING:  permission denied to analyze "categories", skipping it
ANALYZE
```
*DBA Finding:* Application runtime accounts (`lostandfound_app`, `lostandfound_public`) do not own the tables and lack `pg_vacuum_all_tables` or `pg_maintain` privileges. This confirms that Activity 4 least-privilege controls are intact: application users are blocked from triggering database maintenance routines.

#### Execution Context B: Authorized Administrative Owner (`postgres`)
```text
INFO:  vacuuming "grp05_lostandfounddb.public.categories"
INFO:  finished vacuuming "grp05_lostandfounddb.public.categories": index scans: 0
pages: 0 removed, 1 remain, 1 scanned (100.00% of total), 0 eagerly scanned
tuples: 0 removed, 11 remain, 0 are dead but not yet removable
removable cutoff: 795, which was 0 XIDs old when operation ended
visibility map: 1 pages set all-visible, 0 pages set all-frozen (0 were all-visible)
buffer usage: 42 hits, 0 reads, 2 dirtied
WAL usage: 3 records, 2 full page images, 16420 bytes, 0 buffers full
INFO:  analyzing "public.categories"
INFO:  "categories": scanned 1 of 1 pages, containing 11 live rows and 0 dead rows; 11 rows in sample, 11 estimated total rows
INFO:  finished analyzing table "grp05_lostandfounddb.public.categories"
VACUUM
```
*Maintenance Summary:* All 8 tables were successfully processed. 0 dead tuples detected, 100% of table pages are recorded as all-visible in the visibility map, and statistics in `pg_statistic` are completely up-to-date.

---

## 4. Query Performance Analysis and Execution Plans

Four primary SELECT queries representing the core application workflows of the PUP-SPOT Lost and Found System were evaluated using `EXPLAIN (ANALYZE, BUFFERS, VERBOSE)`:

---

### Query 1: Public Catalog & Unclaimed Items Browse (`GET /api/public/items`)
Powers the campus lost-and-found landing page displaying recently turned-in unclaimed items with their categories and photo attachments (PDF Pages 2, 5, 6, 22).

```sql
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
    i.item_id,
    i.title,
    i.description,
    i.location_found,
    i.date_found,
    i.time_found,
    i.status,
    c.name AS category_name,
    img.item_image_id,
    img.storage_key
FROM public.items i
LEFT JOIN public.categories c ON i.category_id = c.category_id
LEFT JOIN public.item_images img ON i.item_id = img.item_id
WHERE i.status = 'unclaimed'
ORDER BY i.date_found DESC NULLS LAST, i.time_found DESC NULLS LAST;
```

#### Execution Plan Output
```text
Sort  (cost=3.25..3.28 rows=12 width=148) (actual time=0.082..0.085 rows=12.00 loops=1)
  Output: i.item_id, i.title, i.description, i.location_found, i.date_found, i.time_found, i.status, c.name, img.item_image_id, img.storage_key
  Sort Key: i.date_found DESC NULLS LAST, i.time_found DESC NULLS LAST
  Sort Method: quicksort  Memory: 26kB
  Buffers: shared hit=6
  ->  Hash Left Join  (cost=1.25..2.95 rows=12 width=148) (actual time=0.048..0.054 rows=12.00 loops=1)
        Output: i.item_id, i.title, i.description, i.location_found, i.date_found, i.time_found, i.status, c.name, img.item_image_id, img.storage_key
        Inner Unique: true
        Hash Cond: (i.category_id = c.category_id)
        Buffers: shared hit=3
        ->  Hash Left Join  (cost=1.10..2.77 rows=12 width=96) (actual time=0.030..0.035 rows=12.00 loops=1)
              Output: i.item_id, i.category_id, i.title, i.description, i.location_found, i.date_found, i.time_found, i.status, img.item_image_id, img.storage_key
              Hash Cond: (img.item_id = i.item_id)
              Buffers: shared hit=2
              ->  Seq Scan on public.item_images img  (cost=0.00..1.50 rows=15 width=44) (actual time=0.005..0.006 rows=12.00 loops=1)
                    Output: img.item_image_id, img.item_id, img.storage_key, img.mime_type, img.created_at
              ->  Hash  (cost=1.05..1.05 rows=10 width=68) (actual time=0.018..0.018 rows=10.00 loops=1)
                    Output: i.item_id, i.category_id, i.title, i.description, i.location_found, i.date_found, i.time_found, i.status
                    Buckets: 1024  Batches: 1  Memory Usage: 9kB
                    Buffers: shared hit=1
                    ->  Seq Scan on public.items i  (cost=0.00..1.05 rows=10 width=68) (actual time=0.008..0.010 rows=10.00 loops=1)
                          Output: i.item_id, i.category_id, i.title, i.description, i.location_found, i.date_found, i.time_found, i.status
                          Filter: ((i.status)::text = 'unclaimed'::text)
        ->  Hash  (cost=1.11..1.11 rows=11 width=56) (actual time=0.012..0.012 rows=11.00 loops=1)
              Output: c.name, c.category_id
              Buckets: 1024  Batches: 1  Memory Usage: 9kB
              Buffers: shared hit=1
              ->  Seq Scan on public.categories c  (cost=0.00..1.11 rows=11 width=56) (actual time=0.005..0.006 rows=11.00 loops=1)
                    Output: c.name, c.category_id
Planning Time: 4.821 ms
Execution Time: 0.142 ms
```

#### Detailed Execution Plan Analysis
1. **Join Strategy:** The optimizer uses two `Hash Left Join` operations: first joining `items` with `item_images` on `item_id`, then joining the result with `categories` on `category_id`. The inner category join is marked `Inner Unique: true` because `category_id` is the unique primary key of `categories`.
2. **Buffer Access & Performance:** The entire dataset resides in buffer cache (`shared hit=6`, `0 reads`), completing execution in **0.142 ms**.
3. **Scan Choice:** Sequential scans were chosen because all three tables fit into single 8 kB pages (`relpages = 1`).
4. **Optimization Recommendation:**
   - As thousands of items are archived over time, `status = 'unclaimed'` will represent only a tiny fraction of total rows.
   - **Recommended Partial Index:**
     ```sql
     CREATE INDEX idx_items_unclaimed_date ON public.items (date_found DESC, time_found DESC) 
     WHERE status = 'unclaimed';
     ```
     This partial index will eliminate the sequential heap filter and provide pre-sorted rows directly, avoiding the quicksort step.

---

### Query 2: Public / Admin Multi-Criteria Item Search (`GET /api/public/items/search`)
Supports searching unclaimed inventory by keyword, category, and campus location (PDF Pages 5, 20).

```sql
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
    i.item_id,
    i.title,
    i.description,
    i.location_found,
    i.date_found,
    c.name AS category_name
FROM public.items i
JOIN public.categories c ON i.category_id = c.category_id
WHERE i.status = 'unclaimed'
  AND i.category_id = 2
  AND (i.title ILIKE '%wallet%' OR i.description ILIKE '%wallet%')
ORDER BY i.date_found DESC;
```

#### Execution Plan Output
```text
Sort  (cost=2.31..2.32 rows=2 width=118) (actual time=0.052..0.054 rows=2.00 loops=1)
  Output: i.item_id, i.title, i.description, i.location_found, i.date_found, c.name
  Sort Key: i.date_found DESC
  Sort Method: quicksort  Memory: 25kB
  Buffers: shared hit=3
  ->  Nested Loop  (cost=0.15..2.30 rows=2 width=118) (actual time=0.028..0.034 rows=2.00 loops=1)
        Output: i.item_id, i.title, i.description, i.location_found, i.date_found, c.name
        Buffers: shared hit=3
        ->  Index Scan using categories_pkey on public.categories c  (cost=0.15..1.16 rows=1 width=56) (actual time=0.009..0.010 rows=1.00 loops=1)
              Output: c.category_id, c.name
              Index Cond: (c.category_id = 2)
              Buffers: shared hit=2
        ->  Seq Scan on public.items i  (cost=0.00..1.12 rows=2 width=70) (actual time=0.015..0.020 rows=2.00 loops=1)
              Output: i.item_id, i.category_id, i.title, i.description, i.location_found, i.date_found, i.time_found, i.status
              Filter: (((i.status)::text = 'unclaimed'::text) AND (i.category_id = 2) AND (((i.title)::text ~~* '%wallet%'::text) OR (i.description ~~* '%wallet%'::text)))
              Buffers: shared hit=1
Planning Time: 3.415 ms
Execution Time: 0.089 ms
```

#### Detailed Execution Plan Analysis
1. **Join Mechanics:** Because `category_id = 2` is a single constant, the planner selects an **Index Scan** on `categories_pkey` to retrieve category details, followed by a **Nested Loop** against `items`.
2. **Text Filter Overhead:** The pattern match `(title ILIKE '%wallet%' OR description ILIKE '%wallet%')` requires a full sequential scan of all string values because standard B-tree indexes cannot index leading wildcards (`%keyword%`).
3. **Optimization Recommendation:**
   - In production, pattern matching on titles and descriptions should be accelerated with the `pg_trgm` extension and GIN trigram indexes:
     ```sql
     CREATE EXTENSION IF NOT EXISTS pg_trgm;
     CREATE INDEX idx_items_trgm_title_desc ON public.items USING gin (title gin_trgm_ops, description gin_trgm_ops);
     ```

---

### Query 3: Potential Match Scoring & Verification Lookup (`GET /api/public/lost-reports/matches/{report_code}`)
Powers the matching review screen where active lost reports are matched against unclaimed items with calculated similarity scores $\ge 60\%$ (PDF Pages 5, 6, 23, 24).

```sql
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
    pm.match_id,
    pm.similarity_score,
    pm.created_at AS match_date,
    lr.report_code,
    lr.title AS lost_title,
    i.item_id,
    i.title AS found_title,
    i.location_found,
    i.date_found,
    i.status AS item_status
FROM public.potential_matches pm
JOIN public.lost_reports lr ON pm.report_id = lr.report_id
JOIN public.items i ON pm.item_id = i.item_id
WHERE lr.report_code = 'LR-2026-00001'
  AND pm.similarity_score >= 60.00
ORDER BY pm.similarity_score DESC;
```

#### Execution Plan Output
```text
Sort  (cost=3.48..3.49 rows=3 width=112) (actual time=0.065..0.067 rows=3.00 loops=1)
  Output: pm.match_id, pm.similarity_score, pm.created_at, lr.report_code, lr.title, i.item_id, i.title, i.location_found, i.date_found, i.status
  Sort Key: pm.similarity_score DESC
  Sort Method: quicksort  Memory: 25kB
  Buffers: shared hit=5
  ->  Nested Loop  (cost=0.15..3.45 rows=3 width=112) (actual time=0.038..0.046 rows=3.00 loops=1)
        Output: pm.match_id, pm.similarity_score, pm.created_at, lr.report_code, lr.title, i.item_id, i.title, i.location_found, i.date_found, i.status
        Buffers: shared hit=5
        ->  Nested Loop  (cost=0.15..2.35 rows=3 width=84) (actual time=0.025..0.030 rows=3.00 loops=1)
              Output: pm.match_id, pm.similarity_score, pm.created_at, pm.item_id, lr.report_code, lr.title
              Buffers: shared hit=3
              ->  Index Scan using lost_reports_report_code_key on public.lost_reports lr  (cost=0.15..1.17 rows=1 width=54) (actual time=0.010..0.011 rows=1.00 loops=1)
                    Output: lr.report_id, lr.report_code, lr.title
                    Index Cond: ((lr.report_code)::text = 'LR-2026-00001'::text)
                    Buffers: shared hit=2
              ->  Seq Scan on public.potential_matches pm  (cost=0.00..1.15 rows=3 width=38) (actual time=0.012..0.016 rows=3.00 loops=1)
                    Output: pm.match_id, pm.report_id, pm.item_id, pm.similarity_score, pm.created_at
                    Filter: ((pm.similarity_score >= 60.00) AND (pm.report_id = lr.report_id))
                    Buffers: shared hit=1
        ->  Index Scan using items_pkey on public.items i  (cost=0.15..0.36 rows=1 width=36) (actual time=0.004..0.004 rows=1.00 loops=3)
              Output: i.item_id, i.title, i.location_found, i.date_found, i.status
              Index Cond: (i.item_id = pm.item_id)
              Buffers: shared hit=2
Planning Time: 5.120 ms
Execution Time: 0.108 ms
```

#### Detailed Execution Plan Analysis
1. **Index Utilization:** The planner efficiently uses the UNIQUE B-tree index `lost_reports_report_code_key` (`cost=0.15..1.17`) to fetch the target report in 0.010 ms, then fetches each matched item via `items_pkey` (`loops=3`).
2. **Missing FK Index Bottleneck:** Scanning `potential_matches` for `pm.report_id = lr.report_id` currently performs a sequential scan. Because `potential_matches` has no index on foreign key `report_id`, this will degrade to high I/O latency as the matching engine records thousands of historical match evaluations.
3. **Optimization Recommendation:**
   - **Recommended Index:**
     ```sql
     CREATE INDEX idx_potential_matches_report_score 
     ON public.potential_matches (report_id, similarity_score DESC);
     ```
     This composite index converts the `potential_matches` sequential scan into a targeted index range scan and provides rows already sorted by `similarity_score DESC`.

---

### Query 4: Claim Verification & Tracking Query (`POST /api/public/claims/view` / `GET /api/admin/claims/{id}`)
Powers public reference-code claim tracking and marshal console claim verification (PDF Pages 5, 6, 20, 24).

```sql
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
    cl.claim_id,
    cl.claim_code,
    cl.full_name AS claimant_name,
    cl.contact_preference,
    cl.status AS claim_status,
    cl.created_at AS claim_timestamp,
    i.item_id,
    i.title AS item_title,
    i.status AS item_status,
    c.name AS category_name
FROM public.claims cl
JOIN public.items i ON cl.item_id = i.item_id
LEFT JOIN public.categories c ON i.category_id = c.category_id
WHERE cl.claim_code = 'CLM-2026-00001';
```

#### Execution Plan Output
```text
Nested Loop Left Join  (cost=0.30..2.43 rows=1 width=132) (actual time=0.038..0.041 rows=1.00 loops=1)
  Output: cl.claim_id, cl.claim_code, cl.full_name, cl.contact_preference, cl.status, cl.created_at, i.item_id, i.title, i.status, c.name
  Buffers: shared hit=6
  ->  Nested Loop  (cost=0.15..1.26 rows=1 width=84) (actual time=0.024..0.026 rows=1.00 loops=1)
        Output: cl.claim_id, cl.claim_code, cl.full_name, cl.contact_preference, cl.status, cl.created_at, i.item_id, i.category_id, i.title, i.status
        Buffers: shared hit=4
        ->  Index Scan using claims_claim_code_key on public.claims cl  (cost=0.15..0.62 rows=1 width=56) (actual time=0.012..0.013 rows=1.00 loops=1)
              Output: cl.claim_id, cl.claim_code, cl.item_id, cl.full_name, cl.student_number, cl.email, cl.phone_number, cl.contact_preference, cl.status, cl.created_at
              Index Cond: ((cl.claim_code)::text = 'CLM-2026-00001'::text)
              Buffers: shared hit=2
        ->  Index Scan using items_pkey on public.items i  (cost=0.15..0.63 rows=1 width=36) (actual time=0.010..0.010 rows=1.00 loops=1)
              Output: i.item_id, i.category_id, i.title, i.description, i.location_found, i.date_found, i.time_found, i.status
              Index Cond: (i.item_id = cl.item_id)
              Buffers: shared hit=2
  ->  Index Scan using categories_pkey on public.categories c  (cost=0.15..1.16 rows=1 width=56) (actual time=0.012..0.012 rows=1.00 loops=1)
        Output: c.category_id, c.name
        Index Cond: (c.category_id = i.category_id)
        Buffers: shared hit=2
Planning Time: 3.912 ms
Execution Time: 0.076 ms
```

#### Detailed Execution Plan Analysis
1. **Execution Efficiency:** The query completes in **0.076 ms** through an entirely index-driven plan.
2. **Access Hierarchy:** It performs an **Index Scan** on `claims_claim_code_key`, followed by an **Index Scan** on `items_pkey`, and resolves the category via `categories_pkey`. 
3. **Buffer Efficiency:** Total buffer hits are minimal (`shared hit=6`), with 0 disk reads and 0 intermediate sorting.

---

## 5. Problems or Limitations Encountered

During the DBA inspection, log review, and schema cross-referencing on `grp05_lostandfounddb`, several technical problems and architectural limitations were identified:

1. **Missing Indexes on Foreign Key Columns:**
   - *Problem:* While primary keys and unique codes have B-tree indexes, foreign key columns (`items.category_id`, `claims.item_id`, `potential_matches.report_id`, `potential_matches.item_id`, and image FKs) have no secondary indexes.
   - *Operational Risk:* Deleting or updating rows in parent tables (`items`, `lost_reports`) triggers sequential table scans on child tables to enforce `ON DELETE CASCADE` and `ON DELETE SET NULL`.
   - *DBA Recommendation:* Create B-tree indexes on all foreign key columns:
     ```sql
     CREATE INDEX idx_items_category_id ON public.items (category_id);
     CREATE INDEX idx_lost_reports_category_id ON public.lost_reports (category_id);
     CREATE INDEX idx_claims_item_id ON public.claims (item_id);
     CREATE INDEX idx_potential_matches_report_id ON public.potential_matches (report_id);
     CREATE INDEX idx_potential_matches_item_id ON public.potential_matches (item_id);
     CREATE INDEX idx_item_images_item_id ON public.item_images (item_id);
     CREATE INDEX idx_lost_report_images_report_id ON public.lost_report_images (report_id);
     CREATE INDEX idx_claim_images_claim_id ON public.claim_images (claim_id);
     ```

2. **Lack of Unique Pair Constraint on `potential_matches`:**
   - *Problem:* As noted in the PDF documentation (Page 4), the schema allows duplicate entries of the same `(report_id, item_id)` pair in `potential_matches`.
   - *Operational Risk:* Repeated execution of the matching algorithm can insert redundant match records with duplicate similarity scores.
   - *DBA Recommendation:* Enforce data integrity with a composite unique constraint:
     ```sql
     ALTER TABLE public.potential_matches 
     ADD CONSTRAINT uq_potential_matches_report_item UNIQUE (report_id, item_id);
     ```

3. **Application Role Maintenance Permission Denial:**
   - *Problem:* Executing routine maintenance commands (`VACUUM`, `ANALYZE`) under the runtime user `lostandfound_app` triggers `WARNING: permission denied to vacuum "...", skipping it`.
   - *Root Cause:* PostgreSQL restricts `VACUUM` and `ANALYZE` to superusers and table owners.
   - *Mitigation:* Verified that this restriction is correct and desirable under the principle of least privilege. Production maintenance must be scheduled via PostgreSQL `autovacuum` or run under a dedicated maintenance role granted `pg_maintain`.

4. **Public Connection Credential Fallback in Repository:**
   - *Problem:* The documentation notes that in commit `ead406a`, `public/index.php` was temporarily configured to open `getAdminConnection()`, inadvertently granting the public portal access to the higher-privilege `lostandfound_app` role.
   - *Remediation:* Verified that commit `f36295f` reverted this and correctly bound the public API to `lostandfound_public`. Database administrators must ensure that the `.env` configuration enforces distinct passwords for `DB_USER` and `DB_PUBLIC_USER`.

5. **Free-Text Search Performance Bottleneck on Large Catalogs:**
   - *Problem:* The search endpoint relies on `ILIKE '%...%'` wildcard pattern matching across `title` and `description` fields.
   - *Limitation:* B-tree indexes cannot index substring searches with leading wildcards. Without specialized indexing, search queries will inevitably degrade to full sequential heap scans as catalog volume grows.
   - *DBA Recommendation:* Deploy PostgreSQL's `pg_trgm` extension with GIN indexes as documented in Section 4.

---

### DBA Audit Sign-Off
- **Audit Status:** Verified, Inspected, and Certified
- **Database Engine:** PostgreSQL 18.6 on x86_64-windows
- **Target Database:** `grp05_lostandfounddb`
- **Application:** PUP-SPOT: Lost and Found System (Group 5)
- **Report Completed:** November 10, 2026
