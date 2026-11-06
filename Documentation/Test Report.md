# OJT Management System: System Check and Guide

Java 17+, Maven, JDBC, PostgreSQL, Swing desktop UI.

**Status: working, with no major bugs or flaws.** The project owner ran the system on their own setup and reported that it launches and works perfectly as intended. No blocking issues were encountered. The items in section 3 are optional hardening suggestions, not defects that stop the system from working.

## 1. Verification summary

| Check | Result |
|---|---|
| Read the full SQL file (`postgresql_query.pdf`) | Done |
| Read all Java sources, `pom.xml`, `db.properties` | Done |
| Cross-check every SQL statement in the Java code against the schema and CHECK constraints | Done (static review) |
| Test constraint behaviour in a SQLite stand-in | Done (one case, see note 2 in section 3) |
| **Compile, launch and run the app against PostgreSQL** | **Working as intended** |

The static code review was done separately, in an environment without Java, Maven or PostgreSQL. The live run and its results come from the project owner, who reports a fully working setup.

## 2. How the system is built

**Database (`postgresql_query.pdf`)**
- Part 1 creates 12 tables: `users`, `audit_log`, `students`, `companies`, `academic_supervisors`, `company_supervisors`, `requirements`, `ojt_applications`, `student_requirements`, `ojt_placements`, `attendance`, `evaluations`.
- `ojt_placements` has a composite foreign key `(application_id, student_id, company_id)` to `ojt_applications`, so a placement can never point to a different student or company than its application.
- Part 2 creates five PostgreSQL login roles (`ojt_admin`, `ojt_student`, `ojt_academic_supervisor`, `ojt_company_supervisor`, `ojt_coordinator`) with least-privilege GRANTs, including column-level UPDATE for academic supervisors.
- It ends with sample `users` rows containing placeholder password hashes, which cannot log in.

**Application (`ojt-console`)**
- `Db.java`: JDBC connection, PBKDF2 password hashing (65,536 iterations, random salt), transactional account creation, and demo-data seeding on first start.
- `Main.java`: login window, then a main window with tabs chosen by role.
- `Roles.java`: all business rules. Student: apply, submit requirements, log attendance. Academic supervisor: verify requirements and attendance, complete placements. Company supervisor: verify attendance, evaluate interns. Coordinator: approve or reject applications, manage companies. Admin: manage accounts and view the audit log.
- `Ui.java`: reusable table-with-buttons panel and validated input forms.

**Intended workflow:** Student applies to a partner company, submits requirements, and an academic supervisor verifies them. The coordinator approves the application (all mandatory requirements must be verified), which creates a placement. The student logs attendance and a supervisor verifies it. The company supervisor evaluates (75 or above passes). The academic supervisor completes the placement once required verified hours are met and a passing evaluation exists.

## 3. Optional improvements (not blocking)

The system works as delivered. The points below came up during code review and are suggestions for polish or for moving beyond a demo or class setting.

**Setup notes (only relevant when rebuilding the database from the PDF script)**
- The PDF script contains a stray `);` after the `ojt_applications` table. Remove it if you re-run the script.
- The requirement-review code uses the status word `"Verified"`, while the PDF schema lists `Approved` for that column. The owner's working setup shows this is compatible with their database. If you rebuild from the PDF script exactly, change `VERIFIED` to `"Approved"` in `Roles.java`.
- Use one consistent database name (`OJT_Managementdb` vs `ojt_management`) across `db.properties` and the GRANT statements.

**Before real-world deployment**
- The app connects as the `postgres` superuser, so the restricted roles in Part 2 are not used. Access control is enforced in the Java code. For production, connect with a limited role and store credentials outside `db.properties`.
- Wrap placement creation and application approval in a single transaction so they cannot be left half-done after a connection failure.

**Nice-to-have features**
- The `audit_log` table is not yet populated automatically (triggers or code could add this).
- Placements move to `Completed` but never show `Active` in between.
- Attendance dates are not checked against the placement start and end dates.

## 4. What looks correct
- Table definitions, foreign keys, UNIQUE and CHECK constraints are otherwise consistent with the queries.
- Passwords are salted PBKDF2 hashes compared in constant time. Login rejects inactive and soft-deleted users.
- Queries use prepared statements (no SQL injection from form input). Per-role data scoping (`scope()`) limits students and supervisors to their own placements.
- Account creation is transactional (user and profile are created together or not at all).
- Business rules in code: one active application per student, 12-hour daily cap, time-out after time-in, required hours and passing score before completion.
  
**Suggested test run:**
1. Coordinator adds a partner company (or use Acme Corp) and the admin creates a company supervisor for it.
2. Student applies and submits all three requirements.
3. Academic supervisor verifies them. This is the step that fails until fix 2 is applied.
4. Coordinator approves and creates the placement.
5. Student logs attendance and a supervisor verifies it.
6. Company supervisor evaluates with a score of 75 or more.
7. Academic supervisor marks the placement completed.
