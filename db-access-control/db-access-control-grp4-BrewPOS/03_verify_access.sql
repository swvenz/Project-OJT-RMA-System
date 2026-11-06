

-- EXPECTED RESULT: SUCCESS (Staff is allowed to view the menu)
SELECT * FROM menu_item;

-- EXPECTED RESULT: PERMISSION DENIED (Staff cannot delete completed orders)
DELETE FROM order_ticket;



-- EXPECTED RESULT: SUCCESS (Monitor is allowed to view receipts)
SELECT * FROM order_line_item;

-- EXPECTED RESULT: PERMISSION DENIED (Monitor cannot add new categories)
INSERT INTO menu_category (category_name) VALUES ('Secret Menu');