package ojt;

import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.PBEKeySpec;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.sql.*;
import java.util.*;

/** JDBC access, demo data and password hashing. Uses the existing OJT_Managementdb tables as they are. */
final class Db {
    static Connection c;

    static void init() throws Exception {
        Properties p = new Properties();
        try (var in = Db.class.getResourceAsStream("/db.properties")) { p.load(in); }
        c = DriverManager.getConnection(p.getProperty("url"), p.getProperty("user"), p.getProperty("password"));
        seed();
    }

    static PreparedStatement prep(String sql, Object... p) throws SQLException {
        var ps = c.prepareStatement(sql);
        for (int i = 0; i < p.length; i++) ps.setObject(i + 1, p[i]);
        return ps;
    }

    static List<Map<String, Object>> rows(String sql, Object... p) {
        try (var ps = prep(sql, p); var rs = ps.executeQuery()) {
            var md = rs.getMetaData();
            var out = new ArrayList<Map<String, Object>>();
            while (rs.next()) {
                var m = new LinkedHashMap<String, Object>();
                for (int i = 1; i <= md.getColumnCount(); i++) m.put(md.getColumnLabel(i), rs.getObject(i));
                out.add(m);
            }
            return out;
        } catch (SQLException e) { throw new RuntimeException(e.getMessage(), e); }
    }

    static int update(String sql, Object... p) {
        try (var ps = prep(sql, p)) { return ps.executeUpdate(); }
        catch (SQLException e) { throw new RuntimeException(e.getMessage(), e); }
    }

    static long count(String sql, Object... p) { return ((Number) rows(sql, p).get(0).values().iterator().next()).longValue(); }

    /** Creates the login account and its role profile together (all or nothing). */
    static void createUser(String un, String em, String pw, String role, String first, String last, Map<String, Object> x) {
        try {
            c.setAutoCommit(false);
            int uid = ((Number) rows("insert into users(username,email,password_hash,role) values(?,?,?,?) returning user_id",
                    un, em, hash(pw), role).get(0).get("user_id")).intValue();
            switch (role) {
                case "STUDENT" -> update("insert into students(user_id,student_number,first_name,last_name,course,year_level,contact_number) values(?,?,?,?,?,?,?)",
                        uid, x.get("student_number"), first, last, x.get("course"), x.get("year_level"), x.get("contact_number"));
case "ACADEMIC_SUPERVISOR" -> update("insert into academic_supervisors(user_id,first_name,last_name,employee_number,department,contact_number) values(?,?,?,?,?,?)",
        uid, first, last, x.get("employee_number"), x.get("department"), x.get("contact_number"));case "COMPANY_SUPERVISOR" -> update("insert into company_supervisors(user_id,company_id,first_name,last_name,position,department,contact_number) values(?,?,?,?,?,?,?)",
        uid, x.get("company_id"), first, last, x.get("position"), x.get("department"), x.get("contact_number"));
                default -> { }
            }
            c.commit();
        } catch (SQLException | RuntimeException e) {
            try { c.rollback(); } catch (SQLException ignored) { }
            throw new RuntimeException("Could not create the account: " + e.getMessage(), e);
        } finally {
            try { c.setAutoCommit(true); } catch (SQLException ignored) { }
        }
    }

    /** Adds one demo account per role (password123) the first time, plus starter requirements if the table is empty. */
    static void seed() {
        if (count("select count(*) from requirements") == 0)
            for (String t : new String[]{"Resume", "Parent consent", "Medical certificate"}) update("insert into requirements(title) values(?)", t);
        if (count("select count(*) from users where username='demo_admin'") > 0) return;
        int cid = ((Number) rows("insert into companies(company_name,industry,address,contact_number,email,is_partner) "
                + "values('Acme Corp','Technology','Manila','0917-000-0000','hr@acme.test',true) returning company_id").get(0).get("company_id")).intValue();
        String pw = "password123";
        createUser("demo_admin", "admin@demo.local", pw, "ADMIN", "Demo", "Admin", Map.of());
        createUser("demo_student", "student@demo.local", pw, "STUDENT", "Demo", "Student",
                Map.of("student_number", "2026-0001", "course", "BSIT", "year_level", 3, "contact_number", "0917-111-1111"));
createUser("demo_academic_supervisor", "academic@demo.local", pw, "ACADEMIC_SUPERVISOR", "Demo", "Adviser",
        Map.of("employee_number", "EMP-0001", "department", "IT", "contact_number", "0917-333-3333"));        createUser("demo_company_supervisor", "company@demo.local", pw, "COMPANY_SUPERVISOR", "Demo", "Mentor",
        Map.of("company_id", cid, "position", "IT Manager", "department", "IT", "contact_number", "0917-222-2222"));        createUser("demo_ojt_coordinator", "coordinator@demo.local", pw, "OJT_COORDINATOR", "Demo", "Coordinator", Map.of());
    }

    // PBKDF2 password hashing (built into the JDK, no extra library)
    static byte[] pbkdf2(String pw, byte[] salt) {
        try { return SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(new PBEKeySpec(pw.toCharArray(), salt, 65536, 256)).getEncoded(); }
        catch (Exception e) { throw new RuntimeException(e); }
    }

    static String hash(String pw) {
        byte[] salt = new byte[16];
        new SecureRandom().nextBytes(salt);
        return Base64.getEncoder().encodeToString(salt) + ":" + Base64.getEncoder().encodeToString(pbkdf2(pw, salt));
    }

    static boolean check(String pw, String stored) {
        String[] s = stored.split(":");
        try {
            return s.length == 2 && MessageDigest.isEqual(pbkdf2(pw, Base64.getDecoder().decode(s[0])), Base64.getDecoder().decode(s[1]));
        } catch (IllegalArgumentException e) { return false; }
    }
}
