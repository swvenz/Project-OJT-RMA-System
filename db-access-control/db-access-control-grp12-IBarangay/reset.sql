-- =========================================================
-- iBarangay Database Reset Script (Drop, Re-create, Re-seed)
-- COMP 018 - Database Administration | Activity 3
-- CAUTION: Drops all existing tables in schema public!
-- =========================================================

DROP TABLE IF EXISTS public.request_status_history CASCADE;
DROP TABLE IF EXISTS public.document_requests CASCADE;
DROP TABLE IF EXISTS public.document_type_requirements CASCADE;
DROP TABLE IF EXISTS public.requirements CASCADE;
DROP TABLE IF EXISTS public.document_types CASCADE;
DROP TABLE IF EXISTS public.citizens CASCADE;
DROP TABLE IF EXISTS public.admins CASCADE;
DROP TABLE IF EXISTS public.flyway_schema_history CASCADE;

-- Load schema and seed
\i schema.sql
\i seed.sql
