package ojt;

import javax.swing.*;
import javax.swing.border.EmptyBorder;
import javax.swing.table.DefaultTableModel;
import java.awt.*;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.*;
import java.util.List;
import java.util.function.Consumer;
import java.util.function.Supplier;

/** Reusable Swing pieces: data tables with action buttons, and validated input forms. */
final class Ui {
    static Component owner;

    static void info(String m) { JOptionPane.showMessageDialog(owner, m, "OJT Management System", JOptionPane.INFORMATION_MESSAGE); }
    static void error(String m) { JOptionPane.showMessageDialog(owner, m, "OJT Management System", JOptionPane.ERROR_MESSAGE); }
    static int id(Map<String, Object> r, String k) { return ((Number) r.get(k)).intValue(); }
    static String cell(Object o) { return o == null ? "" : o instanceof Boolean b ? (b ? "Yes" : "No") : o.toString(); }
    static String pretty(String s) { s = s.replace('_', ' '); return Character.toUpperCase(s.charAt(0)) + s.substring(1); }

    record Item(int id, String label) { public String toString() { return label; } }

    record Field(String key, String label, String kind, Object[] opts) {
        static Field text(String k, String l) { return new Field(k, l, "text", null); }
        static Field opt(String k, String l) { return new Field(k, l + " (optional)", "opt", null); }
        static Field pass(String k, String l) { return new Field(k, l, "pass", null); }
        static Field num(String k, String l) { return new Field(k, l, "num", null); }
        static Field date(String k, String l) { return new Field(k, l + " (YYYY-MM-DD)", "date", null); }
        static Field time(String k, String l) { return new Field(k, l + " (HH:mm)", "time", null); }
        static Field choice(String k, String l, String... o) { return new Field(k, l, "choice", o); }
        /** Dropdown from query rows: first column is the id, the other columns make the label. */
        static Field pick(String k, String l, List<Map<String, Object>> rows) {
            Item[] items = rows.stream().map(r -> {
                var v = new ArrayList<>(r.values());
                StringBuilder sb = new StringBuilder();
                for (int i = 1; i < v.size(); i++) sb.append(i > 1 ? " - " : "").append(cell(v.get(i)));
                return new Item(((Number) v.get(0)).intValue(), sb.length() == 0 ? String.valueOf(v.get(0)) : sb.toString());
            }).toArray(Item[]::new);
            return new Field(k, l, "pick", items);
        }

        JComponent make() {
            return switch (kind) {
                case "pass" -> new JPasswordField(20);
                case "pick", "choice" -> new JComboBox<>(opts);
                case "date" -> new JTextField(LocalDate.now().toString(), 20);
                default -> new JTextField(20);
            };
        }

        Object read(JComponent c) {
            if (c instanceof JComboBox<?> b) {
                Object o = b.getSelectedItem();
                if (o == null) throw new IllegalArgumentException();
                return o instanceof Item i ? (Object) i.id() : o;
            }
            String t = c instanceof JPasswordField p ? new String(p.getPassword()) : ((JTextField) c).getText().trim();
            if (kind.equals("opt")) return t.isEmpty() ? null : t;
            if (t.isEmpty()) throw new IllegalArgumentException();
            return switch (kind) {
                case "num" -> Double.parseDouble(t);
                case "date" -> java.sql.Date.valueOf(LocalDate.parse(t));
                case "time" -> LocalTime.parse(t);
                default -> t;
            };
        }
    }

    /** Shows a form dialog. Returns the values by key, or null if cancelled. */
    static Map<String, Object> form(String title, Field... fs) {
        JPanel p = new JPanel(new GridLayout(0, 2, 8, 8));
        var comps = new LinkedHashMap<String, JComponent>();
        for (Field f : fs) { p.add(new JLabel(f.label())); JComponent c = f.make(); comps.put(f.key(), c); p.add(c); }
        while (true) {
            if (JOptionPane.showConfirmDialog(owner, p, title, JOptionPane.OK_CANCEL_OPTION, JOptionPane.PLAIN_MESSAGE) != JOptionPane.OK_OPTION) return null;
            var out = new HashMap<String, Object>();
            String bad = null;
            for (Field f : fs) {
                try { out.put(f.key(), f.read(comps.get(f.key()))); } catch (RuntimeException e) { bad = f.label(); break; }
            }
            if (bad == null) return out;
            error("Please enter a valid value for: " + bad);
        }
    }

    record Btn(String label, boolean needsRow, Consumer<Map<String, Object>> act) {
        static Btn row(String label, Consumer<Map<String, Object>> a) { return new Btn(label, true, a); }
        static Btn free(String label, Runnable a) { return new Btn(label, false, r -> a.run()); }
    }

    /** A table filled by a query, with a button bar. Reloads on Refresh, after any action, and when its tab is opened. */
    static class DataPanel extends JPanel {
        final Supplier<List<Map<String, Object>>> loader;
        final JTable table = new JTable();
        List<Map<String, Object>> rows = List.of();

        DataPanel(Supplier<List<Map<String, Object>>> loader, Btn... btns) {
            super(new BorderLayout(8, 8));
            this.loader = loader;
            setBorder(new EmptyBorder(10, 10, 10, 10));
            table.setRowHeight(26);
            table.setFillsViewportHeight(true);
            JPanel bar = new JPanel(new FlowLayout(FlowLayout.LEFT));
            for (Btn b : btns) {
                JButton j = new JButton(b.label());
                j.addActionListener(e -> {
                    int i = table.getSelectedRow();
                    if (b.needsRow() && (i < 0 || i >= rows.size())) { info("Select a row in the table first."); return; }
                    try { b.act().accept(b.needsRow() ? rows.get(i) : null); }
                    catch (RuntimeException ex) { error("Could not complete that: " + ex.getMessage()); }
                    refresh();
                });
                bar.add(j);
            }
            JButton r = new JButton("Refresh");
            r.addActionListener(e -> refresh());
            bar.add(r);
            add(bar, BorderLayout.NORTH);
            add(new JScrollPane(table), BorderLayout.CENTER);
            refresh();
        }

        void refresh() {
            try { rows = loader.get(); } catch (RuntimeException e) { rows = List.of(); error("Could not load data: " + e.getMessage()); }
            DefaultTableModel m;
            if (rows.isEmpty()) {
                m = new DefaultTableModel(new Object[]{"Status"}, 0);
                m.addRow(new Object[]{"Nothing here yet."});
            } else {
                m = new DefaultTableModel(rows.get(0).keySet().stream().map(Ui::pretty).toArray(), 0);
                for (var r : rows) m.addRow(r.values().stream().map(Ui::cell).toArray());
            }
            table.setModel(new DefaultTableModel(m.getDataVector(), columnNames(m)) {
                public boolean isCellEditable(int r, int c) { return false; }
            });
        }

        static Vector<Object> columnNames(DefaultTableModel m) {
            var v = new Vector<Object>();
            for (int i = 0; i < m.getColumnCount(); i++) v.add(m.getColumnName(i));
            return v;
        }
    }
}
