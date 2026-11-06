-- 1. Assign Login Accounts to the Groups
GRANT parkit_admin_grp TO parkit_admin;
GRANT parkit_staff_grp TO parkit_staff;
GRANT parkit_readonly_grp TO parkit_monitor;

-- 2. Grant Database and Schema Access
GRANT CONNECT ON DATABASE grp_parkitdb TO parkit_admin_grp, parkit_staff_grp, parkit_readonly_grp;
GRANT USAGE ON SCHEMA public TO parkit_admin_grp, parkit_staff_grp, parkit_readonly_grp;

-- 3. Grant Specific Table Privileges
-- Admin gets full control
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO parkit_admin_grp;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO parkit_admin_grp;

-- Staff gets daily operations, but NO access to staff_user passwords
GRANT SELECT, INSERT, UPDATE ON vehicle, transaction, payment, parking_zone TO parkit_staff_grp;
GRANT USAGE, SELECT, UPDATE ON vehicle_vehicle_id_seq, transaction_transaction_id_seq, payment_payment_id_seq, parking_zone_zone_id_seq TO parkit_staff_grp;

-- Monitor gets ONLY SELECT (viewing) privileges
GRANT SELECT ON parking_zone, vehicle, transaction TO parkit_readonly_grp;

-- 4. Lock down the PUBLIC group
REVOKE ALL ON SCHEMA public FROM PUBLIC;