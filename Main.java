package ojt;

import javax.swing.*;
import javax.swing.border.EmptyBorder;
import java.awt.*;

record User(int uid, int pid, String role, String name) { }

public class Main {
    public static void main(String[] args) {
        SwingUtilities.invokeLater(() -> {
            try { for (var i : UIManager.getInstalledLookAndFeels()) if (i.getName().equals("Nimbus")) UIManager.setLookAndFeel(i.getClassName()); }
            catch (Exception ignored) { }
            try { Db.init(); }
            catch (Exception e) {
                JOptionPane.showMessageDialog(null, "Could not connect to the database:\n" + e.getMessage()
                        + "\n\nCheck db.properties and that PostgreSQL is running.", "OJT Management System", JOptionPane.ERROR_MESSAGE);
                System.exit(1);
            }
            showLogin();
        });
    }

    static void showLogin() {
        JFrame f = new JFrame("OJT Management System - Sign in");
        f.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        Ui.owner = f;
        JTextField un = new JTextField(20);
        JPasswordField pw = new JPasswordField(20);
        JButton go = new JButton("Sign in");
        JLabel title = new JLabel("OJT Management System");
        title.setFont(title.getFont().deriveFont(Font.BOLD, 24f));
        JLabel hint = new JLabel("<html><small>Demo accounts (password: password123):<br>demo_admin, demo_student, demo_academic_supervisor,<br>"
                + "demo_company_supervisor, demo_ojt_coordinator</small></html>");
        JPanel p = new JPanel(new GridLayout(0, 1, 6, 6));
        p.setBorder(new EmptyBorder(24, 32, 24, 32));
        p.add(title); p.add(new JLabel("Username")); p.add(un); p.add(new JLabel("Password")); p.add(pw); p.add(go); p.add(hint);
        go.addActionListener(e -> {
            try {
                User u = login(un.getText().trim(), new String(pw.getPassword()));
                if (u == null) { Ui.error("Wrong username or password."); return; }
                f.dispose();
                showMain(u);
            } catch (RuntimeException ex) { Ui.error(ex.getMessage()); }
        });
        f.getRootPane().setDefaultButton(go);
        f.add(p);
        f.pack();
        f.setLocationRelativeTo(null);
        f.setVisible(true);
    }

    static void showMain(User u) {
        JFrame f = new JFrame("OJT Management System");
        f.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        Ui.owner = f;
        JLabel who = new JLabel(u.name() + "  (" + u.role().replace('_', ' ').toLowerCase() + ")");
        who.setFont(who.getFont().deriveFont(Font.BOLD, 16f));
        JButton out = new JButton("Sign out");
        out.addActionListener(e -> { f.dispose(); showLogin(); });
        JPanel top = new JPanel(new BorderLayout());
        top.setBorder(new EmptyBorder(10, 14, 6, 14));
        top.add(who, BorderLayout.WEST);
        top.add(out, BorderLayout.EAST);
        JTabbedPane tabs = Roles.tabs(u);
        tabs.addChangeListener(e -> { if (tabs.getSelectedComponent() instanceof Ui.DataPanel d) d.refresh(); });
        f.add(top, BorderLayout.NORTH);
        f.add(tabs, BorderLayout.CENTER);
        f.setSize(1050, 640);
        f.setLocationRelativeTo(null);
        f.setVisible(true);
    }

    static User login(String un, String pw) {
        var r = Db.rows("select user_id, password_hash, role from users where username=? and is_active and deleted_at is null", un);
        if (r.isEmpty() || !Db.check(pw, (String) r.get(0).get("password_hash"))) return null;
        int uid = ((Number) r.get(0).get("user_id")).intValue();
        String role = (String) r.get(0).get("role");
        String q = switch (role) {
            case "STUDENT" -> "select student_id, first_name||' '||last_name from students where user_id=? and deleted_at is null";
            case "ACADEMIC_SUPERVISOR" -> "select academic_sup_id, first_name||' '||last_name from academic_supervisors where user_id=? and deleted_at is null";
            case "COMPANY_SUPERVISOR" -> "select company_sup_id, first_name||' '||last_name from company_supervisors where user_id=? and deleted_at is null";
            default -> null;
        };
        if (q == null) return new User(uid, uid, role, un);
        var p = Db.rows(q, uid);
        if (p.isEmpty()) throw new RuntimeException("This account has no profile yet. Ask an admin.");
        var it = p.get(0).values().iterator();
        int pid = ((Number) it.next()).intValue();
        return new User(uid, pid, role, (String) it.next());
    }
}
