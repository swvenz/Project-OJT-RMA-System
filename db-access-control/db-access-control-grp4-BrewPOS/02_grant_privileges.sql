GRANT brewpos_admin_grp TO brewpos_admin;
GRANT brewpos_staff_grp TO brewpos_staff;
GRANT brewpos_readonly_grp TO brewpos_monitor;

GRANT CONNECT ON DATABASE grp_brewposdb TO brewpos_admin_grp, brewpos_staff_grp, brewpos_readonly_grp;
GRANT USAGE ON SCHEMA public TO brewpos_admin_grp, brewpos_staff_grp, brewpos_readonly_grp;

-- Admin gets full control
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO brewpos_admin_grp;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO brewpos_admin_grp;

-- Staff gets daily operations (Cashier duties)
GRANT SELECT, INSERT, UPDATE ON staff, menu_category, menu_item, order_ticket, order_line_item TO brewpos_staff_grp;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO brewpos_staff_grp;

-- Monitor gets ONLY SELECT (viewing) privileges
GRANT SELECT ON ALL TABLES IN SCHEMA public TO brewpos_readonly_grp;

REVOKE ALL ON SCHEMA public FROM PUBLIC;