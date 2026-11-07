-- HIGH IMPACT: run only after reviewing every database on this PostgreSQL
-- cluster. Removing PUBLIC CONNECT changes access for all databases; grant
-- CONNECT back to other legitimate users/applications before deploying.
-- Run as a PostgreSQL superuser, connected to postgres, and supply:
--   psql ... -v target_db=canteen_db -f 07-security-restrictions.sql

DO $$
DECLARE
    db_name name;
BEGIN
    FOR db_name IN SELECT datname FROM pg_database WHERE datallowconn LOOP
        EXECUTE format('REVOKE CONNECT ON DATABASE %I FROM PUBLIC', db_name);
        EXECUTE format(
            'REVOKE CONNECT ON DATABASE %I FROM canteen_app, canteen_readonly, canteen_app_grp, canteen_readonly_grp',
            db_name);
    END LOOP;
END
$$;

SELECT format(
    'GRANT CONNECT ON DATABASE %I TO canteen_admin, canteen_app, canteen_readonly',
    :'target_db') \gexec
