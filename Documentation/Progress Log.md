# OJT Record Management Application

**Project:** On-the-Job Training (OJT) Record Management Application
<br>**Group:** 3
<br>**Repository:** [swvenz/Project-OJT-RMA-System](https://github.com/swvenz/Project-OJT-RMA-System)

## Team

| Member | Role |
| --- | --- |
| Russell Shaun Simon | Project Manager |
| Niño De Dios | Front-End Developer |
| Jared Ramos | Quality Assurance |
| Rovi Dela Rosa | Back-End Developer |
| Andrei Sietereales | Technical Documentation |
| Mark Angelo Geraldez | Quality Assurance |

## Overview

The system replaces paper files and separate spreadsheets with a single PostgreSQL database for OJT records. It stores student profiles, OJT applications, requirements, company placements, attendance, training hours and evaluations, so records can be searched, updated and kept consistent. It implements the blueprint approved in Activity 2.

**In scope:** student and company records, application and requirement tracking, placement records, attendance monitoring, evaluation records, OJT status and record viewing.

**Out of scope:** recruitment and job matching, salary and financial transactions, built-in messaging.

### Main functions

| # | Function | Priority |
| --- | --- | --- |
| 1 | Register student information | High |
| 2 | Register company information | High |
| 3 | Track student attendance | High |
| 4 | Evaluate student | High |
| 5 | Track OJT placement | High |
| 6 | Track OJT requirements | Medium |
| 7 | Monitor OJT status | Medium |
| 8 | Help students with OJT application | Low |

## Tech stack

- **Application:** Java desktop app, built with Maven
- **Database:** PostgreSQL (12 tables in the `public` schema)

## User roles

The application has five user roles plus one system account. Application roles are stored in `users.role`; the runtime account is the only login the application uses to reach PostgreSQL.

| Application role | Responsibilities | Functions and data access | DB role |
| --- | --- | --- | --- |
| Administrator (`ADMIN`) | Manages accounts and views the audit log | Create an account (user and profile, all-or-nothing). Activate or deactivate accounts, but not their own. | `ojt_admin` |
| Student (`STUDENT`) | Applies for OJT, submits requirements, logs attendance | Read partner companies. Create one active application at a time. Create or update own requirement submissions. Create attendance for own active placement. Read own placement and evaluations. | `ojt_student` |
| Academic supervisor (`ACADEMIC_SUPERVISOR`) | Verifies requirements and attendance; closes placements | Verify or reject pending requirements. Verify attendance of own placements. Mark own placement Completed. Read placements and evaluations. | `ojt_academic_supervisor` |
| Company supervisor (`COMPANY_SUPERVISOR`) | Supervises interns on site and evaluates them | Read own interns. Verify attendance of own interns. Create evaluations for own placements. | `ojt_company_supervisor` |
| OJT coordinator (`OJT_COORDINATOR`) | Reviews applications; manages companies and placements | Approve an application (creates the placement, assigns supervisors, dates and hours) or reject it with a reason. Add companies. Read all placements. | `ojt_coordinator` |

## Database

The schema is created by `database/OJT Database.sql` in the repository. The ERD (exported from pgAdmin) matches the implemented schema.

| Table | Primary key | Foreign keys | Key constraints |
| --- | --- | --- | --- |
| `users` | `user_id` | none | Unique `username` and `email`; `role` limited to 5 values; `is_active` defaults to true |
| `audit_log` | `audit_id` | none | `details` stored as JSONB |
| `students` | `student_id` | `user_id` → users | Unique `user_id` and `student_number`; `year_level` > 0 |
| `companies` | `company_id` | none | Unique `company_name`; `is_partner` defaults to false |
| `academic_supervisors` | `academic_sup_id` | `user_id` → users | Unique `user_id` |
| `company_supervisors` | `company_sup_id` | `user_id` → users, `company_id` → companies | Unique `user_id` |
| `requirements` | `req_id` | none | Unique `title`; `is_mandatory` defaults to true |
| `ojt_applications` | `application_id` | `student_id` → students, `company_id` → companies | Status: Pending, Approved, Rejected, Withdrawn; unique (`application_id`, `student_id`, `company_id`) |
| `student_requirements` | `student_req_id` | `student_id`, `req_id`, `verified_by_sup_id` | Unique (`student_id`, `req_id`); status: Pending, Submitted, Approved, Rejected |
| `ojt_placements` | `placement_id` | `application_id`, `student_id`, `company_id`, `company_sup_id`, `academic_sup_id` | Unique `application_id`; `required_hours` > 0; `start_date` ≤ `end_date`; status: Pending, Active, Completed, Terminated |
| `attendance` | `attendance_id` | `placement_id` → ojt_placements | Unique (`placement_id`, `attendance_date`); `hours_rendered` ≥ 0; `time_out` ≥ `time_in` |
| `evaluations` | `evaluation_id` | `placement_id`, `company_sup_id` | `score` between 0 and 100 |

### Scripts and seed data

The repository holds the table-creation script, the five PostgreSQL login roles and their grants, and one placeholder account per application role. The placeholder password hash is **not valid for login**. Full seed data is still to be added.

### Design changes since Activity 2

| Change | Reason |
| --- | --- |
| Added a composite unique key on `ojt_applications` and a matching composite foreign key from `ojt_placements` | A placement's student and company must match the approved application it came from |
| Added `UNIQUE (placement_id, attendance_date)` on `attendance` | Enforces one attendance entry per placement per day (business rule 3) |
| Added `UNIQUE (student_id, req_id)` on `student_requirements` | A student submits each requirement once |
| Changed `attendance.time_in` and `time_out` from timestamp to time, and `hours_rendered` from numeric(4,2) to numeric(5,2) | The same date can be recorded for different placements, but duplicate attendance for the same placement and date is prevented |
| Dropped `employee_number`, `department` and `contact_number` from the supervisor tables | No longer needed |
| Added a `role` check limited to ADMIN, STUDENT, ACADEMIC_SUPERVISOR, COMPANY_SUPERVISOR and OJT_COORDINATOR | Matches the five application roles |

## Application screens

The Java desktop app runs against the database and shows role-specific screens.

| Role | Screens |
| --- | --- |
| All | Sign in |
| Student | Partner companies, My applications, My requirements, Attendance, My placement, My evaluations |
| Company supervisor | My interns, Attendance to verify, Evaluations |
| Academic supervisor | Requirements to review, Placements, Attendance to verify, Evaluations |
| OJT coordinator | Applications, Companies, Placements |
| Administrator | Accounts, Audit log |

## Testing

The group ran the CRUD tests below and all passed as expected.

| Test | Role | Operation | Result |
| --- | --- | --- | --- |
| Create an account | Administrator | Create | Account 11 appears in the list |
| Apply to a company | Student | Create | Passed |
| Submit a requirement | Student | Create / Update | Passed |
| Record attendance twice on one day | Student | Create | Passed |
| Approve an application | OJT coordinator | Update | Passed |
| Evaluate an intern | Company supervisor | Create | Passed |
| Deactivate an account | Administrator | Update | Passed |

## Status

- Schema, roles and grants are in place; full seed data is still to be added.
- Demo accounts exist for each role, but the placeholder password hash is not valid for login.

## AI usage declaration

| AI tool | Assistance | How the group validated or corrected it |
| --- | --- | --- |
| Claude | Produced a rough draft of the OJT application design, used as a basis for the group's own draft | The group reviewed the draft, then created and justified its own schema and database layout |
| Claude | Generated a draft architectural design flow from the group's prompted idea | A member reviewed it to build their own understanding of the architecture diagram |
| ChatGPT | Assisted with setting up Maven for Java | The group successfully set up Maven |
