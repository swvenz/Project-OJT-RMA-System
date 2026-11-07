-- Create database roles

CREATE ROLE restaurant_admin LOGIN
PASSWORD 'Admin123!';

CREATE ROLE restaurant_staff LOGIN
PASSWORD 'Staff123!';

CREATE ROLE restaurant_customer LOGIN
PASSWORD 'Customer123!';