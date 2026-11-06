-- 1. Group Roles
CREATE ROLE lostandfound_admin_grp NOLOGIN;
CREATE ROLE lostandfound_staff_grp NOLOGIN;
CREATE ROLE lostandfound_readonly_grp NOLOGIN;

-- 2. Login Accounts
CREATE ROLE lostandfound_admin LOGIN PASSWORD 'admin-secure-pass';
CREATE ROLE lostandfound_app LOGIN PASSWORD 'staff-secure-pass';
CREATE ROLE lostandfound_public LOGIN PASSWORD 'public-secure-pass';