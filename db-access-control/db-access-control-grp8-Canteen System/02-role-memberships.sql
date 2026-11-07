-- Run as a PostgreSQL administrator after 01-create-roles.sql.
-- Remove unexpected inherited memberships from these five security roles.
DO $$
DECLARE
    membership record;
BEGIN
    FOR membership IN
        SELECT member.rolname AS member_name, granted.rolname AS granted_name
        FROM pg_auth_members m
        JOIN pg_roles member ON member.oid = m.member
        JOIN pg_roles granted ON granted.oid = m.roleid
        WHERE (member.rolname IN (
                   'canteen_admin', 'canteen_app', 'canteen_readonly',
                   'canteen_app_grp', 'canteen_readonly_grp')
               OR granted.rolname IN (
                   'canteen_admin', 'canteen_app_grp', 'canteen_readonly_grp'))
          AND NOT (
              (member.rolname = 'canteen_app' AND granted.rolname = 'canteen_app_grp')
              OR (member.rolname = 'canteen_readonly'
                  AND granted.rolname = 'canteen_readonly_grp'))
    LOOP
        EXECUTE format('REVOKE %I FROM %I',
                       membership.granted_name, membership.member_name);
    END LOOP;
END
$$;

GRANT canteen_app_grp TO canteen_app
    WITH INHERIT TRUE, SET TRUE, ADMIN FALSE;
GRANT canteen_readonly_grp TO canteen_readonly
    WITH INHERIT TRUE, SET TRUE, ADMIN FALSE;
