CREATE ROLE brewpos_admin_grp NOLOGIN;
CREATE ROLE brewpos_staff_grp NOLOGIN;
CREATE ROLE brewpos_readonly_grp NOLOGIN;

CREATE ROLE brewpos_admin LOGIN PASSWORD 'admin-secure-pass';
CREATE ROLE brewpos_staff LOGIN PASSWORD 'staff-secure-pass';
CREATE ROLE brewpos_monitor LOGIN PASSWORD 'monitor-secure-pass';