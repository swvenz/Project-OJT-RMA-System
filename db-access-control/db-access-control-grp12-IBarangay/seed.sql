-- =========================================================
-- iBarangay Standalone Seed Data (PostgreSQL DML)
-- COMP 018 - Database Administration | Activity 3
-- Database: PPGG_projectdb
-- Schema: public
-- =========================================================

-- 1. SEED ADMINISTRATORS
INSERT INTO public.admins (full_name, username, role, is_active, created_at)
VALUES 
    ('Capt. Juan Dela Cruz', 'admin', 'ADMIN', true, CURRENT_TIMESTAMP),
    ('Secretary Maria Clara', 'sec_maria', 'STAFF', true, CURRENT_TIMESTAMP),
    ('Auditor Felipe Salvador', 'auditor_felipe', 'AUDITOR', true, CURRENT_TIMESTAMP)
ON CONFLICT (username) DO NOTHING;

-- 2. SEED DOCUMENT TYPES
INSERT INTO public.document_types (name, description, processing_days, fee, is_active)
VALUES 
    ('Barangay Clearance', 'General purpose clearance certifying good community standing, required for employment and official applications.', 1, 50.00, true),
    ('Certificate of Indigency', 'Official certification issued for low-income residents for medical, educational, and government financial assistance.', 1, 0.00, true),
    ('Certificate of Residency', 'Proof of bona fide residency within the barangay jurisdiction for at least six (6) months.', 1, 50.00, true),
    ('Barangay Business Clearance', 'Clearance permit required for operating commercial establishments, retail stores, or services in the barangay.', 2, 150.00, true)
ON CONFLICT (name) DO NOTHING;

-- 3. SEED REQUIREMENTS
INSERT INTO public.requirements (name, description, is_active)
VALUES 
    ('Valid Government-Issued ID', 'Passport, PhilSys National ID, UMID, Driver License, or Voter ID showing current address.', true),
    ('Proof of Residency', 'Recent utility bill (electric/water), lease agreement, or Homeowner Association (HOA) certificate.', true),
    ('Community Tax Certificate (Cedula)', 'Current tax year CTC / Cedula issued by the local city or municipal treasurer.', true),
    ('2x2 Recent ID Photo', 'Colored photograph with white background taken within the past six months.', true),
    ('DTI / SEC Business Registration', 'Certificate of business name registration issued by DTI or SEC for commercial entities.', true)
ON CONFLICT (name) DO NOTHING;

-- 4. LINK DOCUMENT TYPES TO REQUIREMENTS
INSERT INTO public.document_type_requirements (document_type_id, requirement_id, is_required)
SELECT dt.document_type_id, r.requirement_id, true
FROM public.document_types dt, public.requirements r
WHERE dt.name = 'Barangay Clearance' 
  AND r.name IN ('Valid Government-Issued ID', 'Community Tax Certificate (Cedula)', '2x2 Recent ID Photo')
ON CONFLICT (document_type_id, requirement_id) DO NOTHING;

INSERT INTO public.document_type_requirements (document_type_id, requirement_id, is_required)
SELECT dt.document_type_id, r.requirement_id, true
FROM public.document_types dt, public.requirements r
WHERE dt.name = 'Certificate of Indigency' 
  AND r.name IN ('Valid Government-Issued ID', 'Proof of Residency')
ON CONFLICT (document_type_id, requirement_id) DO NOTHING;

INSERT INTO public.document_type_requirements (document_type_id, requirement_id, is_required)
SELECT dt.document_type_id, r.requirement_id, true
FROM public.document_types dt, public.requirements r
WHERE dt.name = 'Certificate of Residency' 
  AND r.name IN ('Valid Government-Issued ID', 'Proof of Residency', 'Community Tax Certificate (Cedula)')
ON CONFLICT (document_type_id, requirement_id) DO NOTHING;

INSERT INTO public.document_type_requirements (document_type_id, requirement_id, is_required)
SELECT dt.document_type_id, r.requirement_id, true
FROM public.document_types dt, public.requirements r
WHERE dt.name = 'Barangay Business Clearance' 
  AND r.name IN ('DTI / SEC Business Registration', 'Community Tax Certificate (Cedula)', 'Valid Government-Issued ID')
ON CONFLICT (document_type_id, requirement_id) DO NOTHING;

-- 5. SEED CITIZENS
INSERT INTO public.citizens (first_name, middle_name, last_name, date_of_birth, address, contact_no, email, created_at)
VALUES 
    ('Jose', 'Protacio', 'Rizal', '1995-06-19', 'Block 1 Lot 2, Mabini Street, Barangay Central', '09171234567', 'jose.rizal@example.com', CURRENT_TIMESTAMP),
    ('Maria', 'Santos', 'Dela Cruz', '1998-03-25', '124 Katipunan Avenue, Barangay Central', '09289876543', 'maria.santos@example.com', CURRENT_TIMESTAMP),
    ('Andres', 'Castro', 'Bonifacio', '1992-11-30', '45 Balintawak Road, Barangay Central', '09395551234', 'andres.bonifacio@example.com', CURRENT_TIMESTAMP),
    ('Gabriela', 'Cariño', 'Silang', '1996-03-19', '78 Burgos Extension, Barangay Central', '09187778899', 'gabriela.silang@example.com', CURRENT_TIMESTAMP)
ON CONFLICT (email) DO NOTHING;

-- 6. SEED SAMPLE DOCUMENT REQUESTS
INSERT INTO public.document_requests (citizen_id, document_type_id, request_date, purpose, status, remarks, approved_by, processed_at)
SELECT c.citizen_id, dt.document_type_id, CURRENT_TIMESTAMP - INTERVAL '1 day', 'Employment Application', 'PENDING', 'Documents submitted online. Pending staff review.', NULL, NULL
FROM public.citizens c, public.document_types dt
WHERE c.email = 'jose.rizal@example.com' AND dt.name = 'Barangay Clearance'
LIMIT 1;

INSERT INTO public.document_requests (citizen_id, document_type_id, request_date, purpose, status, remarks, approved_by, processed_at)
SELECT c.citizen_id, dt.document_type_id, CURRENT_TIMESTAMP - INTERVAL '2 days', 'Educational Assistance', 'PROCESSING', 'Indigency assessment verified by social services.', a.admin_id, CURRENT_TIMESTAMP - INTERVAL '1 day'
FROM public.citizens c, public.document_types dt, public.admins a
WHERE c.email = 'maria.santos@example.com' AND dt.name = 'Certificate of Indigency' AND a.username = 'sec_maria'
LIMIT 1;

INSERT INTO public.document_requests (citizen_id, document_type_id, request_date, purpose, status, remarks, approved_by, processed_at)
SELECT c.citizen_id, dt.document_type_id, CURRENT_TIMESTAMP - INTERVAL '3 days', 'Retail Store Permit', 'APPROVED', 'Approved by Barangay Captain. Awaiting fee collection and physical pickup.', a.admin_id, CURRENT_TIMESTAMP - INTERVAL '1 day'
FROM public.citizens c, public.document_types dt, public.admins a
WHERE c.email = 'andres.bonifacio@example.com' AND dt.name = 'Barangay Business Clearance' AND a.username = 'admin'
LIMIT 1;

INSERT INTO public.document_requests (citizen_id, document_type_id, request_date, purpose, status, remarks, approved_by, processed_at, released_at)
SELECT c.citizen_id, dt.document_type_id, CURRENT_TIMESTAMP - INTERVAL '4 days', 'Bank Account Opening', 'RELEASED', 'Signed certification released to applicant.', a.admin_id, CURRENT_TIMESTAMP - INTERVAL '2 days', CURRENT_TIMESTAMP - INTERVAL '1 day'
FROM public.citizens c, public.document_types dt, public.admins a
WHERE c.email = 'gabriela.silang@example.com' AND dt.name = 'Certificate of Residency' AND a.username = 'admin'
LIMIT 1;

-- 7. SEED AUDIT TRAIL / STATUS HISTORY
INSERT INTO public.request_status_history (request_id, admin_id, old_status, new_status, changed_at, remarks)
SELECT r.request_id, a.admin_id, 'PENDING', 'PROCESSING', CURRENT_TIMESTAMP - INTERVAL '1 day', 'Staff validated applicant community standing.'
FROM public.document_requests r, public.admins a
WHERE r.status IN ('PROCESSING', 'APPROVED', 'RELEASED') AND a.username = 'sec_maria'
LIMIT 1;

INSERT INTO public.request_status_history (request_id, admin_id, old_status, new_status, changed_at, remarks)
SELECT r.request_id, a.admin_id, 'PROCESSING', 'APPROVED', CURRENT_TIMESTAMP - INTERVAL '1 day', 'Official clearance approved and sealed.'
FROM public.document_requests r, public.admins a
WHERE r.status IN ('APPROVED', 'RELEASED') AND a.username = 'admin'
LIMIT 1;
