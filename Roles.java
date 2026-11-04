package ojt;

import ojt.Ui.Btn;
import ojt.Ui.Field;

import javax.swing.JTabbedPane;
import java.time.LocalTime;
import java.util.*;
import java.util.function.Supplier;

/** Builds the tabs each role sees, following the flowchart. */
final class Roles {
    // Status words stored in the database. Change here if your CHECK constraints use different words.
    static final String PENDING = "Pending", APPROVED = "Approved", REJECTED = "Rejected", VERIFIED = "Approved", COMPLETED = "Completed";
    static final double PASS_SCORE = 75;

    static final String NAME_S = "s.first_name||' '||s.last_name";
    static final String HOURS = "(select coalesce(sum(t.hours_rendered),0) from attendance t where t.placement_id=p.placement_id and t.is_verified)";
    static final String COMPANIES = "select company_id, company_name, industry, address, is_partner from companies where deleted_at is null order by company_id";
    static final String PARTNERS = "select company_id, company_name, industry, address from companies where deleted_at is null and is_partner order by company_id";
    static final String ACADEMICS = "select academic_sup_id, first_name||' '||last_name as name from academic_supervisors where deleted_at is null order by academic_sup_id";
    static final String MY_REQS = "select r.req_id, r.title, r.is_mandatory, coalesce(sr.status,'Not submitted') status, sr.remarks "
            + "from requirements r left join student_requirements sr on sr.req_id=r.req_id and sr.student_id=? order by r.req_id";
    static final String APPS = "select a.application_id, " + NAME_S + " student, co.company_name company, a.application_date, a.status, a.remarks from ojt_applications a "
            + "join students s on s.student_id=a.student_id join companies co on co.company_id=a.company_id where a.deleted_at is null ";

    static String scope(User u) {
        return switch (u.role()) {
            case "STUDENT" -> "p.student_id=" + u.pid();
            case "COMPANY_SUPERVISOR" -> "p.company_sup_id=" + u.pid();
            case "ACADEMIC_SUPERVISOR" -> "p.academic_sup_id=" + u.pid();
            default -> "true";
        };
    }

    static List<Map<String, Object>> placements(User u) {
        return Db.rows("select p.placement_id, " + NAME_S + " student, c.company_name company, p.status, " + HOURS + " verified_hours, "
                + "p.required_hours, p.start_date, p.end_date from ojt_placements p "
                + "join students s on s.student_id=p.student_id join companies c on c.company_id=p.company_id "
                + "where p.deleted_at is null and " + scope(u) + " order by p.placement_id desc");
    }

    static List<Map<String, Object>> attendance(User u, boolean unverifiedOnly) {
        return Db.rows("select t.attendance_id, t.placement_id, " + NAME_S + " student, t.attendance_date, t.time_in, t.time_out, t.hours_rendered, t.is_verified "
                + "from attendance t join ojt_placements p on p.placement_id=t.placement_id join students s on s.student_id=p.student_id "
                + "where " + scope(u) + (unverifiedOnly ? " and not t.is_verified" : "") + " order by t.attendance_id desc");
    }

    static List<Map<String, Object>> evals(User u) {
        return Db.rows("select e.evaluation_id, e.placement_id, " + NAME_S + " student, e.score, (e.score>=" + PASS_SCORE + ") passed, e.feedback, e.evaluation_date "
                + "from evaluations e join ojt_placements p on p.placement_id=e.placement_id join students s on s.student_id=p.student_id "
                + "where " + scope(u) + " order by e.evaluation_id desc");
    }

    static void add(JTabbedPane t, String title, Supplier<List<Map<String, Object>>> q, Btn... b) { t.addTab(title, new Ui.DataPanel(q, b)); }

    static JTabbedPane tabs(User u) {
        var t = new JTabbedPane();
        int pid = u.pid();
        switch (u.role()) {
            case "ADMIN" -> {
                add(t, "Accounts", () -> Db.rows("select user_id, username, email, role, is_active from users where deleted_at is null order by user_id"),
                        Btn.free("Create account", Roles::createAccount),
                        Btn.row("Activate / deactivate", r -> {
                            int n = Db.update("update users set is_active=not is_active, updated_at=now() where user_id=? and user_id<>? and deleted_at is null", Ui.id(r, "user_id"), u.uid());
                            Ui.info(n == 1 ? "Account updated." : "You cannot deactivate your own account.");
                        }));
                add(t, "Audit log", () -> Db.rows("select audit_id, table_name, action, row_id, action_time from audit_log order by audit_id desc limit 100"));
            }
            case "STUDENT" -> {
                add(t, "Partner companies", () -> Db.rows(PARTNERS), Btn.row("Apply to selected company", r -> {
                    if (Db.count("select count(*) from ojt_applications where student_id=? and status in (?,?) and deleted_at is null", pid, PENDING, APPROVED) > 0) {
                        Ui.error("You already have an active application or placement."); return;
                    }
                    int n = Db.update("insert into ojt_applications(student_id,company_id) select ?, company_id from companies where company_id=? and is_partner and deleted_at is null", pid, Ui.id(r, "company_id"));
                    Ui.info(n == 1 ? "Application submitted. The coordinator will review it." : "That is not a partner company.");
                }));
                add(t, "My applications", () -> Db.rows("select a.application_id, c.company_name company, a.application_date, a.status, a.remarks from ojt_applications a "
                        + "join companies c on c.company_id=a.company_id where a.student_id=? and a.deleted_at is null order by a.application_id desc", pid));
                add(t, "My requirements", () -> Db.rows(MY_REQS, pid), Btn.row("Submit selected requirement", r -> {
                    var m = Ui.form("Submit requirement", Field.opt("file", "File name or link"));
                    if (m == null) return;
                    int rid = Ui.id(r, "req_id");
                    String fp = (String) m.get("file");
                    int n = Db.update("update student_requirements set status=?, file_path=?, submission_date=now(), remarks=null, verified_by_sup_id=null, verified_at=null "
                            + "where student_id=? and req_id=? and status<>?", PENDING, fp, pid, rid, VERIFIED);
                    if (n == 0 && Db.count("select count(*) from student_requirements where student_id=? and req_id=?", pid, rid) == 0)
                        n = Db.update("insert into student_requirements(student_id,req_id,file_path,submission_date) select ?, req_id, ?, now() from requirements where req_id=?", pid, fp, rid);
                    Ui.info(n == 1 ? "Submitted for review." : "This requirement is already verified.");
                }));
                add(t, "Attendance", () -> attendance(u, false), Btn.free("Record attendance", () -> recordAttendance(pid)));
                add(t, "My placement", () -> placements(u));
                add(t, "My evaluations", () -> evals(u));
            }
            case "ACADEMIC_SUPERVISOR" -> {
                add(t, "Requirements to review", () -> Db.rows("select sr.student_req_id, " + NAME_S + " student, r.title requirement, sr.file_path, sr.submission_date from student_requirements sr "
                        + "join students s on s.student_id=sr.student_id join requirements r on r.req_id=sr.req_id "
                        + "where sr.status=? and sr.submission_date is not null order by sr.student_req_id", PENDING),
                        Btn.row("Verify selected", r -> review(u, r, VERIFIED, null)),
                        Btn.row("Reject selected", r -> {
                            var m = Ui.form("Reject requirement", Field.opt("why", "Reason"));
                            if (m != null) review(u, r, REJECTED, (String) m.get("why"));
                        }));
                add(t, "Placements", () -> placements(u), Btn.row("Mark selected completed", r -> complete(u, r)));
                add(t, "Attendance to verify", () -> attendance(u, true), Btn.row("Verify selected", r -> verify(u, r)));
                add(t, "Evaluations", () -> evals(u));
            }
            case "COMPANY_SUPERVISOR" -> {
                add(t, "My interns", () -> placements(u), Btn.row("Evaluate selected intern", r -> {
                    var m = Ui.form("Evaluate intern", Field.num("score", "Score (0-100, " + (int) PASS_SCORE + " passes)"), Field.opt("fb", "Feedback"));
                    if (m == null) return;
                    double score = (Double) m.get("score");
                    if (score < 0 || score > 100) { Ui.error("Score must be between 0 and 100."); return; }
                    int n = Db.update("insert into evaluations(placement_id,company_sup_id,score,feedback) "
                            + "select placement_id, ?, ?, ? from ojt_placements where placement_id=? and company_sup_id=? and deleted_at is null",
                            pid, score, m.get("fb"), Ui.id(r, "placement_id"), pid);
                    Ui.info(n == 1 ? "Evaluation saved. The academic supervisor can now see it." : "That placement is not assigned to you.");
                }));
                add(t, "Attendance to verify", () -> attendance(u, true), Btn.row("Verify selected", r -> verify(u, r)));
                add(t, "Evaluations", () -> evals(u));
            }
            case "OJT_COORDINATOR" -> {
                add(t, "Applications", () -> Db.rows(APPS + "order by a.application_id desc"),
                        Btn.row("Approve selected", Roles::approve),
                        Btn.row("Reject selected", r -> {
                            if (!PENDING.equals(r.get("status"))) { Ui.error("Only pending applications can be rejected."); return; }
                            var m = Ui.form("Reject application", Field.text("why", "Reason for rejection"));
                            if (m == null) return;
                            Db.update("update ojt_applications set status=?, remarks=? where application_id=? and status=?", REJECTED, m.get("why"), Ui.id(r, "application_id"), PENDING);
                            Ui.info("Rejected. The student can see the reason.");
                        }));
                add(t, "Companies", () -> Db.rows(COMPANIES), Btn.free("Add company", () -> {
                    var m = Ui.form("Add company", Field.text("n", "Company name"), Field.text("i", "Industry"), Field.text("a", "Address"),
                            Field.text("c", "Contact number"), Field.text("e", "Email"), Field.choice("p", "Partner company", "Yes", "No"));
                    if (m == null) return;
                    Db.update("insert into companies(company_name,industry,address,contact_number,email,is_partner) values(?,?,?,?,?,?)",
                            m.get("n"), m.get("i"), m.get("a"), m.get("c"), m.get("e"), "Yes".equals(m.get("p")));
                    Ui.info("Company added.");
                }));
                add(t, "Placements", () -> placements(u));
            }
            default -> { }
        }
        return t;
    }

    // ---------------- actions ----------------
    static void createAccount() {
        var m = Ui.form("Create account", Field.choice("role", "Role", "STUDENT", "ACADEMIC_SUPERVISOR", "COMPANY_SUPERVISOR", "OJT_COORDINATOR", "ADMIN"),
                Field.text("un", "Username"), Field.text("em", "Email"), Field.pass("pw", "Password (8+ characters)"),
                Field.text("first", "First name"), Field.text("last", "Last name"));
        if (m == null) return;
        String role = (String) m.get("role"), pw = (String) m.get("pw");
        if (pw.length() < 8) { Ui.error("Password needs at least 8 characters."); return; }
        Map<String, Object> x = new HashMap<>();
        if (role.equals("STUDENT")) {
            var s = Ui.form("Student details", Field.text("student_number", "Student number"), Field.text("course", "Course"),
                    Field.num("year_level", "Year level"), Field.text("contact_number", "Contact number"));
            if (s == null) return;
            x.putAll(s);
            x.put("year_level", ((Double) s.get("year_level")).intValue());
        } else if (role.equals("COMPANY_SUPERVISOR")) {
            var s = Ui.form("Supervisor details", Field.pick("company_id", "Company", Db.rows("select company_id, company_name from companies where deleted_at is null order by company_id")),
        Field.text("position", "Position"), Field.text("department", "Department"), Field.text("contact_number", "Contact number"));            if (s == null) return;
            x.putAll(s);
          } else if (role.equals("COMPANY_SUPERVISOR")) {
            var s = Ui.form("Supervisor details", Field.pick("company_id", "Company", Db.rows("select company_id, company_name from companies where deleted_at is null order by company_id")),
                    Field.text("position", "Position"), Field.text("department", "Department"), Field.text("contact_number", "Contact number"));
            if (s == null) return;
            x.putAll(s);
        } else if (role.equals("ACADEMIC_SUPERVISOR")) {
            var s = Ui.form("Academic supervisor details", Field.text("employee_number", "Employee number"),
                    Field.text("department", "Department"), Field.text("contact_number", "Contact number"));
            if (s == null) return;
            x.putAll(s);
        }
        Db.createUser((String) m.get("un"), (String) m.get("em"), pw, role, (String) m.get("first"), (String) m.get("last"), x);
        Ui.info("Account created.");
    }

    static void recordAttendance(int pid) {
        var m = Ui.form("Record attendance",
                Field.pick("pl", "Placement", Db.rows("select p.placement_id, c.company_name from ojt_placements p join companies c on c.company_id=p.company_id "
                        + "where p.student_id=? and p.status<>? and p.deleted_at is null order by p.placement_id", pid, COMPLETED)),
                Field.date("date", "Date worked"), Field.time("in", "Time in"), Field.time("out", "Time out"));
        if (m == null) return;
        LocalTime tin = (LocalTime) m.get("in"), tout = (LocalTime) m.get("out");
        if (!tout.isAfter(tin)) { Ui.error("Time out must be after time in."); return; }
        double h = Math.round(java.time.Duration.between(tin, tout).toMinutes() / 60.0 * 100) / 100.0;
        if (h > 12) { Ui.error("A single day cannot exceed 12 hours."); return; }
        int n = Db.update("insert into attendance(placement_id,attendance_date,time_in,time_out,hours_rendered) "
                + "select placement_id, ?::date, ?::time, ?::time, ?::numeric from ojt_placements "
                + "where placement_id=? and student_id=? and status<>? and deleted_at is null",
                m.get("date"), java.sql.Time.valueOf(tin), java.sql.Time.valueOf(tout), h, m.get("pl"), pid, COMPLETED);
        Ui.info(n == 1 ? "Attendance recorded (" + h + " hours). Waiting for supervisor verification." : "No active placement of yours matches.");
    }

    static void verify(User u, Map<String, Object> r) {
        int n = Db.update("update attendance set is_verified=true where attendance_id=? and placement_id in "
                + "(select p.placement_id from ojt_placements p where " + scope(u) + ")", Ui.id(r, "attendance_id"));
        Ui.info(n == 1 ? "Attendance verified." : "No such record among your placements.");
    }

    static void review(User u, Map<String, Object> r, String status, String remarks) {
        int n = Db.update("update student_requirements set status=?, verified_by_sup_id=?, verified_at=now(), remarks=? where student_req_id=? and status=?",
                status, u.pid(), remarks, Ui.id(r, "student_req_id"), PENDING);
        Ui.info(n == 1 ? "Requirement updated." : "This requirement is no longer pending.");
    }

    static void complete(User u, Map<String, Object> r) {
        int id = Ui.id(r, "placement_id");
        var q = Db.rows("select p.required_hours, " + HOURS + " vh, exists(select 1 from evaluations e where e.placement_id=p.placement_id and e.score>=" + PASS_SCORE + ") ev "
                + "from ojt_placements p where p.placement_id=? and p.academic_sup_id=? and p.status<>? and p.deleted_at is null", id, u.pid(), COMPLETED);
        if (q.isEmpty()) { Ui.error("This placement is not open or not assigned to you."); return; }
        var row = q.get(0);
        if (((Number) row.get("vh")).doubleValue() < ((Number) row.get("required_hours")).doubleValue()) { Ui.error("Required hours are not yet completed and verified."); return; }
        if (!(Boolean) row.get("ev")) { Ui.error("No passing evaluation yet. The placement stays open (pending)."); return; }
        Db.update("update ojt_placements set status=? where placement_id=?", COMPLETED, id);
        Ui.info("Placement marked " + COMPLETED + ".");
    }

    static void approve(Map<String, Object> r) {
        if (!PENDING.equals(r.get("status"))) { Ui.error("Only pending applications can be approved."); return; }
        int id = Ui.id(r, "application_id");
        var a = Db.rows("select student_id, company_id from ojt_applications where application_id=? and status=? and deleted_at is null", id, PENDING);
        if (a.isEmpty()) { Ui.error("This application is no longer pending."); return; }
        int sid = Ui.id(a.get(0), "student_id"), cid = Ui.id(a.get(0), "company_id");
        long missing = Db.count("select count(*) from requirements r where r.is_mandatory and not exists (select 1 from student_requirements sr "
                + "where sr.student_id=? and sr.req_id=r.req_id and sr.status=?)", sid, VERIFIED);
        if (missing > 0) { Ui.error(missing + " mandatory requirement(s) are not yet verified by an academic supervisor."); return; }
        var sups = Db.rows("select company_sup_id, first_name||' '||last_name as name from company_supervisors where company_id=? and deleted_at is null order by company_sup_id", cid);
        if (sups.isEmpty()) { Ui.error("This company has no supervisor yet. Ask the admin to create one."); return; }
        var m = Ui.form("Approve application", Field.pick("cs", "Company supervisor", sups), Field.pick("acad", "Academic supervisor", Db.rows(ACADEMICS)),
                Field.date("start", "OJT start date"), Field.date("end", "OJT end date"), Field.num("hrs", "Required hours"));
        if (m == null) return;
        var start = (java.sql.Date) m.get("start");
        var end = (java.sql.Date) m.get("end");
        if (end.before(start)) { Ui.error("End date must be after the start date."); return; }
        Db.update("insert into ojt_placements(application_id,student_id,company_id,company_sup_id,academic_sup_id,start_date,end_date,required_hours) values(?,?,?,?,?,?,?,?)",
                id, sid, cid, m.get("cs"), m.get("acad"), start, end, m.get("hrs"));
        Db.update("update ojt_applications set status=? where application_id=?", APPROVED, id);
        Ui.info("Approved. Placement created and supervisors assigned.");
    }
}
