-- Run connected to the application database as canteen_admin or a PostgreSQL
-- administrator. Review output rather than treating this script as a pass/fail test.
\du+
\l+
\dn+
\dp public.*
\ddp

SELECT rolname, rolsuper, rolcreatedb, rolcreaterole, rolreplication,
       rolbypassrls, rolinherit
FROM pg_roles
WHERE rolname IN (
    'canteen_admin', 'canteen_app', 'canteen_readonly',
    'canteen_app_grp', 'canteen_readonly_grp')
ORDER BY rolname;

SELECT member.rolname AS member, parent.rolname AS granted_role
FROM pg_auth_members m
JOIN pg_roles member ON member.oid = m.member
JOIN pg_roles parent ON parent.oid = m.roleid
WHERE member.rolname IN ('canteen_admin', 'canteen_app', 'canteen_readonly')
ORDER BY member.rolname, parent.rolname;

SELECT current_database() AS database_name,
       has_database_privilege('canteen_admin', current_database(), 'CONNECT') AS admin_connect,
       has_database_privilege('canteen_app', current_database(), 'CONNECT') AS app_connect,
       has_database_privilege('canteen_app', current_database(), 'CREATE') AS app_create_schema,
       has_database_privilege('canteen_readonly', current_database(), 'CONNECT') AS readonly_connect;

SELECT n.nspname AS schema_name, r.rolname AS role_name,
       has_schema_privilege(r.rolname, n.oid, 'USAGE') AS can_use,
       has_schema_privilege(r.rolname, n.oid, 'CREATE') AS can_create
FROM pg_namespace n
CROSS JOIN pg_roles r
WHERE n.nspname = 'public'
  AND r.rolname IN ('canteen_admin', 'canteen_app', 'canteen_readonly');

SELECT c.relname AS table_name,
       pg_get_userbyid(c.relowner) AS owner,
       has_table_privilege('canteen_app', c.oid, 'SELECT') AS app_select,
       has_table_privilege('canteen_app', c.oid, 'INSERT') AS app_insert,
       has_table_privilege('canteen_app', c.oid, 'UPDATE') AS app_update,
       has_table_privilege('canteen_app', c.oid, 'DELETE') AS app_delete,
       has_table_privilege('canteen_app', c.oid, 'TRUNCATE') AS app_truncate,
       has_table_privilege('canteen_readonly', c.oid, 'SELECT') AS readonly_full_table_select,
       has_table_privilege('canteen_readonly', c.oid, 'INSERT') AS readonly_insert,
       has_table_privilege('canteen_readonly', c.oid, 'UPDATE') AS readonly_update,
       has_table_privilege('canteen_readonly', c.oid, 'DELETE') AS readonly_delete,
       has_table_privilege('canteen_readonly', c.oid, 'TRUNCATE') AS readonly_truncate
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relkind IN ('r', 'p')
ORDER BY c.relname;

SELECT table_name, column_name,
       has_column_privilege('canteen_readonly', format('public.%I', table_name),
                            column_name, 'SELECT') AS readonly_column_select
FROM (VALUES
    ('menu_item', 'item_id'), ('menu_item', 'item_name'),
    ('menu_item', 'price'), ('customer_order', 'order_id'),
    ('customer_order', 'status'), ('order_item', 'item_id'),
    ('order_item', 'quantity'), ('vendor', 'vendor_name'),
    ('vendor', 'email'), ('student', 'email')
) AS approved(table_name, column_name)
ORDER BY table_name, column_name;

SELECT c.relname AS sequence_name,
       pg_get_userbyid(c.relowner) AS owner,
       has_sequence_privilege('canteen_app', c.oid, 'USAGE') AS app_usage,
       has_sequence_privilege('canteen_app', c.oid, 'SELECT') AS app_select,
       has_sequence_privilege('canteen_app', c.oid, 'UPDATE') AS app_update,
       has_sequence_privilege('canteen_readonly', c.oid, 'USAGE') AS readonly_usage
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relkind = 'S'
ORDER BY c.relname;

SELECT has_database_privilege('canteen_app', 'postgres', 'CONNECT')
    AS app_can_connect_to_postgres_database;
