-- 1. Create the Group Roles (Ranks)
CREATE ROLE parkit_admin_grp NOLOGIN;
CREATE ROLE parkit_staff_grp NOLOGIN;
CREATE ROLE parkit_readonly_grp NOLOGIN;

-- 2. Create the Login Accounts (Players)
CREATE ROLE parkit_admin LOGIN PASSWORD 'admin-secure-pass';
CREATE ROLE parkit_staff LOGIN PASSWORD 'staff-secure-pass';
CREATE ROLE parkit_monitor LOGIN PASSWORD 'monitor-secure-pass';