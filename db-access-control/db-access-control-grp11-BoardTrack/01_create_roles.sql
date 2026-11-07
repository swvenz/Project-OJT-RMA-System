CREATE ROLE boardtrack_admin_grp NOLOGIN;
CREATE ROLE boardtrack_staff_grp NOLOGIN;
CREATE ROLE boardtrack_readonly_grp NOLOGIN;

CREATE ROLE boardtrack_admin LOGIN PASSWORD 'admin-secure-pass';
CREATE ROLE boardtrack_staff LOGIN PASSWORD 'staff-secure-pass';
CREATE ROLE boardtrack_tenant LOGIN PASSWORD 'tenant-secure-pass';