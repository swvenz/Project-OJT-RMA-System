GRANT boardtrack_admin_grp TO boardtrack_admin;
GRANT boardtrack_staff_grp TO boardtrack_staff;
GRANT boardtrack_readonly_grp TO boardtrack_tenant;

GRANT CONNECT ON DATABASE boardtrack_db TO boardtrack_admin_grp, boardtrack_staff_grp, boardtrack_readonly_grp;
GRANT USAGE ON SCHEMA public TO boardtrack_admin_grp, boardtrack_staff_grp, boardtrack_readonly_grp;

-- Admin full control
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO boardtrack_admin_grp;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO boardtrack_admin_grp;

-- Staff operational control (No delete)
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO boardtrack_staff_grp;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO boardtrack_staff_grp;

-- Tenant read-only control
GRANT SELECT ON ALL TABLES IN SCHEMA public TO boardtrack_readonly_grp;

REVOKE ALL ON SCHEMA public FROM PUBLIC;