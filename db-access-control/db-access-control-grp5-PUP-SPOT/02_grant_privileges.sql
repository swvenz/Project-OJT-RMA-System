-- 1. Assign Roles
GRANT lostandfound_admin_grp TO lostandfound_admin;
GRANT lostandfound_staff_grp TO lostandfound_app;
GRANT lostandfound_readonly_grp TO lostandfound_public;

-- 2. Database & Schema Access
GRANT CONNECT ON DATABASE grp05_lostandfounddb TO lostandfound_admin_grp, lostandfound_staff_grp, lostandfound_readonly_grp;
GRANT USAGE ON SCHEMA public TO lostandfound_admin_grp, lostandfound_staff_grp, lostandfound_readonly_grp;

-- 3. Admin Privileges (Full Access)
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO lostandfound_admin_grp;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO lostandfound_admin_grp;

-- 4. App / Staff Privileges
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO lostandfound_staff_grp;
GRANT DELETE ON potential_matches, item_images, lost_report_images, claim_images TO lostandfound_staff_grp;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO lostandfound_staff_grp;

-- 5. Public Role Privileges (Restricted Guest Access)
GRANT SELECT ON categories, items, lost_reports, claims, potential_matches, item_images, lost_report_images TO lostandfound_readonly_grp;
GRANT INSERT ON lost_reports, claims, potential_matches, lost_report_images, claim_images TO lostandfound_readonly_grp;
GRANT UPDATE (status) ON lost_reports TO lostandfound_readonly_grp;
GRANT DELETE ON potential_matches TO lostandfound_readonly_grp;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO lostandfound_readonly_grp;

-- 6. Lock down Public Schema
REVOKE ALL ON SCHEMA public FROM PUBLIC;