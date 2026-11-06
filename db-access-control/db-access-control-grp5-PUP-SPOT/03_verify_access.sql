-- Run while logged in as lostandfound_app

-- EXPECTED RESULT: SUCCESS (App is allowed to view items)
SELECT * FROM items;

-- EXPECTED RESULT: PERMISSION DENIED (App cannot drop tables)
DROP TABLE categories;


-- Run while logged in as lostandfound_public

-- EXPECTED RESULT: SUCCESS (Public is allowed to view categories)
SELECT * FROM categories;

-- EXPECTED RESULT: PERMISSION DENIED (Public cannot delete main items)
DELETE FROM items;