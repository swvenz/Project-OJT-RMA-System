

-- EXPECTED RESULT: SUCCESS (Staff can view properties and rooms)
SELECT * FROM property;

-- EXPECTED RESULT: PERMISSION DENIED (Staff cannot delete property records)
DELETE FROM property;


-- EXPECTED RESULT: SUCCESS (Tenant can view general property/room listings)
SELECT * FROM room;

-- EXPECTED RESULT: PERMISSION DENIED (Tenant cannot modify lease records)
DELETE FROM lease;