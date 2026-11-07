CREATE ROLE habalgo_admin_grp NOLOGIN;
CREATE ROLE habalgo_staff_grp NOLOGIN;
CREATE ROLE habalgo_readonly_grp NOLOGIN;

CREATE ROLE habalgo_admin LOGIN PASSWORD 'admin-secure-pass';
CREATE ROLE habalgo_staff LOGIN PASSWORD 'staff-secure-pass';
CREATE ROLE habalgo_monitor LOGIN PASSWORD 'monitor-secure-pass';