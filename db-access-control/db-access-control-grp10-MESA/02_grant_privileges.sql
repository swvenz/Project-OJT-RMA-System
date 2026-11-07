-- Allow database connections
GRANT CONNECT ON DATABASE mesa_db
TO restaurant_admin, restaurant_staff, restaurant_customer;

-- Allow schema access
GRANT USAGE ON SCHEMA public
TO restaurant_admin, restaurant_staff, restaurant_customer;

-- Admin permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public
TO restaurant_admin;

GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public
TO restaurant_admin;

-- Staff permissions
GRANT SELECT, INSERT, UPDATE
ON ALL TABLES IN SCHEMA public
TO restaurant_staff;

-- Customer permissions
GRANT SELECT, INSERT
ON ALL TABLES IN SCHEMA public
TO restaurant_customer;