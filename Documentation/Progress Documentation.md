# OJT Management System 
Progress Documentation

|      Terms         |   Information  | 
| ------------- |------------- | 
| <b> Group no.     |<b> 3      | 
| System Name          | `On-the-Job Training (OJT) Record Management Application`         | 
| Members           | Russell Shaun Simon <br> Niño De Dios <br> Jared Ramos <br> Rovi Dela Rosa <br> Andrei Sietereales <br> Mark Angelo Geraldez | 
| Repository           | https://github.com/swvenz/Project-OJT-RMA-System.git     | 

<br><br>

## 1. System Overview 
### Purpose:<br>
The main purpose of the proposed OJT Management System is to eliminate the need for paper files and separate spreadsheet files by providing an organized database for OJT-related data storage. 
This database will be utilized for the efficient management of student profiles, OJT applications, company assignments, attendance records, requirements, training hours, and evaluations. 
By organizing this information in a database and enabling its easy access, update, and modification, the OJT management system will reduce human errors that are likely to occur when maintaining several documents. 
In addition, it will offer a more convenient way of storing, retrieving, updating, and managing information about OJT students. 

### Scope:<br>
- The system will cover the student & company information management, OJT applications & document tracking, OJT placement records, monitoring of attendance, student evaluation records, OJT statuses, and record viewing.
- <b>Account management:</b> an administrator creates login accounts together with the matching role profile (student, academic supervisor, company supervisor) in one transaction, and activates or deactivates accounts.
- <b>Applications:</b> students apply to partner companies; the OJT coordinator approves or rejects with a reason.
- <b>Requirements:</b> students submit required documents; academic supervisors verify or reject them. Approval of an application is blocked until all mandatory requirements are verified.
- <b>Placements:</b> approval creates a placement with assigned company and academic supervisors, dates, and required hours.
- <b>Attendance:</b> students record time in and out; supervisors verify entries. Only verified hours count toward the required total.
- <b>Evaluations:</b> company supervisors score interns. A placement is marked Completed only when verified hours reach the required hours and a passing evaluation exists.
- <b>Audit log:</b> the administrator can view the latest audit records.

<br>

## 2. User Roles
|     <b> Application Role         |  <b> Responsibilities  |   <b> Functions and Data Access  | 
| :---:  |------------- | ------------- | 
| <b> Administrator (ADMIN)     |Manages accounts and views the audit log. | Create an account (user + profile, all-or-nothing).Activate / deactivate accounts (not their own).     | 
| <b> Student (STUDENT)    |Applies for OJT, submits requirements, logs attendance.      | Read partner companies. Create one active application at a time. Create/update own requirement submissions. Create attendance for your own active placement. Read your own placement and evaluations. | 
| <b> Academic supervisor (ACADEMIC_SUPERVISOR)    |Verifies requirements and attendance; closes placements. |Verify/reject pending requirements. Verify attendance of your own placements. Mark own placement Completed. Read placements and evaluations.      | 
| <b> Company supervisor (COMPANY_SUPERVISOR)   |Supervises interns on site and evaluates them.      | Read my own interns. Verify attendance of your own interns. Create evaluations for your own placements.      | 
| <b> OJT coordinator (OJT_COORDINATOR)     |Reviews applications and manages companies and placements.      | Approve (creates placement, assigns supervisors, dates, hours) or reject with reason.Add companies. Read all placements. | 
| <b> Application runtime (system account)   |The account the application uses to connect to PostgreSQL.      | Only the operations the application code needs.      | 
