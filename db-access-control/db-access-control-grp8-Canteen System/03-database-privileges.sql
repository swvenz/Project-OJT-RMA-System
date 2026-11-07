-- Run connected to the application database as a superuser or database owner.
-- CONNECT is granted separately from schema and table privileges.
DO $$
BEGIN
    EXECUTE format('REVOKE ALL ON DATABASE %I FROM PUBLIC', current_database());
    EXECUTE format(
        'REVOKE ALL ON DATABASE %I FROM canteen_app, canteen_readonly, canteen_app_grp, canteen_readonly_grp',
        current_database());
    EXECUTE format(
        'REVOKE CREATE, TEMPORARY ON DATABASE %I FROM canteen_app, canteen_readonly',
        current_database());
    EXECUTE format(
        'GRANT CONNECT ON DATABASE %I TO canteen_admin, canteen_app, canteen_readonly',
        current_database());
END
$$;
