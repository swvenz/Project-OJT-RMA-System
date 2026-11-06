# OJT Management System
### Overview
A desktop (Swing) application for managing On-the-Job Training: user accounts, student applications, requirements, placements, attendance and evaluations. 
The main purpose of the proposed OJT Management System is to eliminate the need for paper files and separate spreadsheet files by providing an organized database for OJT-related data storage. 
This database will be utilized for the efficient management of student profiles, OJT applications, company assignments, attendance records, requirements, training hours, and evaluations. 
By organizing this information in a database and enabling its easy access, update, and modification, the OJT management system will reduce human errors that are likely to occur when maintaining several documents. 
In addition, it will offer a more convenient way of storing, retrieving, updating, and managing information about OJT students. 

**Tech stack:** Java SE 17 · Apache Maven · PostgreSQL · JDBC · Visual Studio Code

## 1. Prerequisites

- [JDK 17](https://adoptium.net/) (`java -version`)
- [Apache Maven](https://maven.apache.org/download.cgi) (`mvn -v` should report Java 17)
- [PostgreSQL](https://www.postgresql.org/download/), latest version, with `psql` on your PATH
- [Visual Studio Code](https://code.visualstudio.com/) with the **Extension Pack for Java** and **Maven for Java** extensions

## 2. Environment Variables (placeholders only)

Replace every `<...>` value with your own. Never commit real credentials.

| Variable | Description |
|----------|-------------|
| `DB_URL` | `jdbc:postgresql://localhost:5432/ojt_management` |
| `DB_USER` | `<owner_db_user>` (owner-level user, e.g. `postgres`) |
| `DB_PASSWORD` | `<owner_db_password>` |
| `OJT_ADMIN_PW` | `<admin_role_password>` |
| `OJT_STUDENT_PW` | `<student_role_password>` |
| `OJT_ACAD_SUP_PW` | `<academic_sup_role_password>` |
| `OJT_COMP_SUP_PW` | `<company_sup_role_password>` |
| `OJT_COORD_PW` | `<coordinator_role_password>` |

**Windows (PowerShell):**

```powershell
setx DB_URL "jdbc:postgresql://localhost:5432/ojt_management"
setx DB_USER "<owner_db_user>"
setx DB_PASSWORD "<owner_db_password>"
setx OJT_ADMIN_PW "<admin_role_password>"
setx OJT_STUDENT_PW "<student_role_password>"
setx OJT_ACAD_SUP_PW "<academic_sup_role_password>"
setx OJT_COMP_SUP_PW "<company_sup_role_password>"
setx OJT_COORD_PW "<coordinator_role_password>"
```

**macOS / Linux** (add to `~/.bashrc` or `~/.zshrc`):

```bash
export DB_URL="jdbc:postgresql://localhost:5432/ojt_management"
export DB_USER="<owner_db_user>"
export DB_PASSWORD="<owner_db_password>"
export OJT_ADMIN_PW="<admin_role_password>"
export OJT_STUDENT_PW="<student_role_password>"
export OJT_ACAD_SUP_PW="<academic_sup_role_password>"
export OJT_COMP_SUP_PW="<company_sup_role_password>"
export OJT_COORD_PW="<coordinator_role_password>"
```

Restart your terminal and VS Code after setting them.

## 3. Database and Role Setup

Create the database:

```bash
psql -U postgres -c "CREATE DATABASE ojt_management;"
```

Run the table-creation script (Part 1 of the SQL file) in `ojt_management`, then create the login roles with passwords (as a database administrator):

```sql
CREATE ROLE ojt_admin               LOGIN PASSWORD '<admin_role_password>';
CREATE ROLE ojt_student             LOGIN PASSWORD '<student_role_password>';
CREATE ROLE ojt_academic_supervisor LOGIN PASSWORD '<academic_sup_role_password>';
CREATE ROLE ojt_company_supervisor  LOGIN PASSWORD '<company_sup_role_password>';
CREATE ROLE ojt_coordinator         LOGIN PASSWORD '<coordinator_role_password>';
```

Then run the remaining `GRANT` statements (database `CONNECT`, schema `USAGE`, table, column and sequence privileges) from Part 2 of the SQL file.

> **Notes**
> - The SQL grants `CONNECT` on `ojt_management`. If you use a different database name, update that line and `DB_URL` to match.
> - Skip the sample `INSERT INTO users` block. The app seeds its own demo accounts, and the placeholder hashes cannot log in.
> - The application connects with a single owner-level account (`DB_USER`) because it seeds demo data at startup. The `ojt_*` roles are provisioned for per-role connections.

## 4. Configure the Application

Open the `ojt-console` folder in VS Code. Connection settings live in `src/main/resources/db.properties`:

```properties
url=jdbc:postgresql://localhost:5432/ojt_management
user=<owner_db_user>
password=<owner_db_password>
```

To read the environment variables instead, update the connection line in `Db.init()` (`src/main/java/ojt/Db.java`):

```java
String url  = System.getenv().getOrDefault("DB_URL", p.getProperty("url"));
String user = System.getenv().getOrDefault("DB_USER", p.getProperty("user"));
String pass = System.getenv().getOrDefault("DB_PASSWORD", p.getProperty("password"));
c = DriverManager.getConnection(url, user, pass);
```

## 5. Run

From the `ojt-console` folder:

```bash
mvn -q compile exec:java
```

## Demo Accounts

Created automatically on first launch. Password for all: `password123` (change after setup).

`demo_admin` · `demo_student` · `demo_academic_supervisor` · `demo_company_supervisor` · `demo_ojt_coordinator`

## Troubleshooting

| Problem | Fix |
|---------|-----|
| "Could not connect to the database" | Confirm PostgreSQL is running and `DB_URL`, `DB_USER`, `DB_PASSWORD` are correct |
| `database "..." does not exist` | Database name in `DB_URL` must match the one you created |
| `permission denied` at startup | `DB_USER` must be an owner-level user, not a restricted `ojt_*` role |
| Syntax errors running the SQL | Check for line-break artifacts if copied from PDF (e.g. `NOT NULLCHECK`, `IS NULLOR`, a stray `);`) |
| `mvn` uses the wrong Java | Set `JAVA_HOME` to your JDK 17 installation |

