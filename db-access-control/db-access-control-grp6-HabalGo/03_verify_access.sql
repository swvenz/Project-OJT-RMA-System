

-- EXPECTED RESULT: SUCCESS (Staff can view bookings)
SELECT * FROM habalgo.booking;

-- EXPECTED RESULT: PERMISSION DENIED (Staff cannot drop tables)
DROP TABLE habalgo.vehicle;

-- EXPECTED RESULT: SUCCESS (Monitor can view payments)
SELECT * FROM habalgo.payment;

-- EXPECTED RESULT: PERMISSION DENIED (Monitor cannot modify bookings)
DELETE FROM habalgo.booking;