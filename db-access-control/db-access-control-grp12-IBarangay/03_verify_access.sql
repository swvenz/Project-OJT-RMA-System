-- Create a dedicated login account for the iBarangay application.
CREATE ROLE ibarangay_app WITH LOGIN PASSWORD 'CHANGE_THIS_PASSWORD';

-- Give the application account the permissions of the group role.
GRANT ibarangay_runtime_grp TO ibarangay_app;