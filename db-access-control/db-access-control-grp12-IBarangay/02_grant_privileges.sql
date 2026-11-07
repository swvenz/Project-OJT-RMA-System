-- Allow the application group to connect to the database
-- and use the public schema.
GRANT CONNECT ON DATABASE "PPGG_projectdb" TO ibarangay_runtime_grp;
GRANT USAGE ON SCHEMA public TO ibarangay_runtime_grp;

-- Read the records needed by the application.
GRANT SELECT ON
    public.citizens,
    public.admins,
    public.document_types,
    public.requirements,
    public.document_type_requirements,
    public.document_requests,
    public.request_status_history
TO ibarangay_runtime_grp;

-- Create resident and document-request records.
GRANT INSERT ON
    public.citizens,
    public.document_requests
TO ibarangay_runtime_grp;

-- Update resident and request information when required
-- by the application's authorized workflows.
GRANT UPDATE ON
    public.citizens,
    public.document_requests
TO ibarangay_runtime_grp;

-- Record request status changes.
GRANT INSERT ON
    public.request_status_history
TO ibarangay_runtime_grp;