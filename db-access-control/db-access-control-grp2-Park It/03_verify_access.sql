-- Run these one by one while logged in as parkit_staff 

-- EXPECTED RESULT: SUCCESS (Staff is allowed to view vehicles)
SELECT * FROM vehicle;

-- EXPECTED RESULT: PERMISSION DENIED (Staff cannot view employee passwords)
SELECT * FROM staff_user;

-- EXPECTED RESULT: PERMISSION DENIED (Staff cannot delete payments)
DELETE FROM payment;


-- Run these one by one while logged in as parkit_monitor

-- EXPECTED RESULT: SUCCESS (Monitor is allowed to view parking zones)
SELECT * FROM parking_zone;

-- EXPECTED RESULT: PERMISSION DENIED (Monitor cannot add new vehicles)
INSERT INTO vehicle (license_plate, vehicle_type) VALUES ('TEST-123', 'Car');