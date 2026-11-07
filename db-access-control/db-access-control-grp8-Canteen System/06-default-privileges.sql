-- Run as a superuser or canteen_admin. Default ACLs apply only to objects
-- subsequently created by canteen_admin in public.
ALTER DEFAULT PRIVILEGES FOR ROLE canteen_admin IN SCHEMA public
    REVOKE ALL ON TABLES FROM PUBLIC, canteen_app_grp, canteen_readonly_grp;
ALTER DEFAULT PRIVILEGES FOR ROLE canteen_admin IN SCHEMA public
    REVOKE ALL ON SEQUENCES FROM PUBLIC, canteen_app_grp, canteen_readonly_grp;

ALTER DEFAULT PRIVILEGES FOR ROLE canteen_admin
    REVOKE ALL ON TABLES FROM PUBLIC, canteen_app_grp, canteen_readonly_grp;
ALTER DEFAULT PRIVILEGES FOR ROLE canteen_admin
    REVOKE ALL ON SEQUENCES FROM PUBLIC, canteen_app_grp, canteen_readonly_grp;

ALTER DEFAULT PRIVILEGES FOR ROLE canteen_admin IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE ON TABLES TO canteen_app_grp;
ALTER DEFAULT PRIVILEGES FOR ROLE canteen_admin IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO canteen_app_grp;

-- Read-only access is granted explicitly per approved table/column in script 04.
