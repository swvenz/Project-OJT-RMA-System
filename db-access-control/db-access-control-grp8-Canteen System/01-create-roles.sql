-- Run with psql as a PostgreSQL superuser. Passwords are entered interactively
-- by \password and are never stored in this file or passed on a command line.

SELECT format('CREATE ROLE %I NOLOGIN', 'canteen_admin')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'canteen_admin') \gexec
SELECT format('CREATE ROLE %I NOLOGIN', 'canteen_app_grp')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'canteen_app_grp') \gexec
SELECT format('CREATE ROLE %I NOLOGIN', 'canteen_readonly_grp')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'canteen_readonly_grp') \gexec
SELECT format('CREATE ROLE %I NOLOGIN', 'canteen_app')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'canteen_app') \gexec
SELECT format('CREATE ROLE %I NOLOGIN', 'canteen_readonly')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'canteen_readonly') \gexec

ALTER ROLE canteen_admin LOGIN CREATEROLE NOCREATEDB NOSUPERUSER
    NOREPLICATION NOBYPASSRLS INHERIT;
ALTER ROLE canteen_app LOGIN NOCREATEROLE NOCREATEDB NOSUPERUSER
    NOREPLICATION NOBYPASSRLS INHERIT;
ALTER ROLE canteen_readonly LOGIN NOCREATEROLE NOCREATEDB NOSUPERUSER
    NOREPLICATION NOBYPASSRLS INHERIT;
ALTER ROLE canteen_app_grp NOLOGIN NOCREATEROLE NOCREATEDB NOSUPERUSER
    NOREPLICATION NOBYPASSRLS;
ALTER ROLE canteen_readonly_grp NOLOGIN NOCREATEROLE NOCREATEDB NOSUPERUSER
    NOREPLICATION NOBYPASSRLS;

-- Each command securely prompts twice. Enter the matching value from local .env.
\password canteen_admin
\password canteen_app
\password canteen_readonly
