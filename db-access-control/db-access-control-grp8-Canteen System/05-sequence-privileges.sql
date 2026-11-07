-- Run connected to the application database as a superuser or object owner.
-- SERIAL-backed identity generation requires sequence USAGE; SELECT permits currval.
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public
    FROM canteen_app, canteen_readonly, canteen_app_grp, canteen_readonly_grp;
ALTER SEQUENCE public.student_student_id_seq OWNER TO canteen_admin;
ALTER SEQUENCE public.vendor_vendor_id_seq OWNER TO canteen_admin;
ALTER SEQUENCE public.menu_item_item_id_seq OWNER TO canteen_admin;
ALTER SEQUENCE public.customer_order_order_id_seq OWNER TO canteen_admin;
ALTER SEQUENCE public.order_item_order_item_id_seq OWNER TO canteen_admin;
ALTER SEQUENCE public.queue_entry_queue_id_seq OWNER TO canteen_admin;
ALTER SEQUENCE public.notification_notification_id_seq OWNER TO canteen_admin;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO canteen_app_grp;
