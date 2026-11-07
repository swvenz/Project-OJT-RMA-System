-- Check created roles
SELECT rolname
FROM pg_roles
WHERE rolname IN (
    'restaurant_admin',
    'restaurant_staff',
    'restaurant_customer'
);

-- Check database permissions
SELECT grantee, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee IN (
    'restaurant_admin',
    'restaurant_staff',
    'restaurant_customer'
)
ORDER BY grantee, table_name;