GRANT habalgo_admin_grp TO habalgo_admin;
GRANT habalgo_staff_grp TO habalgo_staff;
GRANT habalgo_readonly_grp TO habalgo_monitor;

GRANT CONNECT ON DATABASE grp00_habalgodb TO habalgo_admin_grp, habalgo_staff_grp, habalgo_readonly_grp;
GRANT USAGE ON SCHEMA habalgo TO habalgo_admin_grp, habalgo_staff_grp, habalgo_readonly_grp;

-- Admin full control
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA habalgo TO habalgo_admin_grp;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA habalgo TO habalgo_admin_grp;

-- Staff operational control
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA habalgo TO habalgo_staff_grp;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA habalgo TO habalgo_staff_grp;

-- Monitor read-only control
GRANT SELECT ON ALL TABLES IN SCHEMA habalgo TO habalgo_readonly_grp;

REVOKE ALL ON SCHEMA habalgo FROM PUBLIC;