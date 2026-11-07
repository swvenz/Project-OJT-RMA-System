-- Run connected to the application database as a superuser or object owner.
-- Keep public usable only by the explicitly approved application groups.
REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public
    FROM canteen_app, canteen_readonly, canteen_app_grp, canteen_readonly_grp;
GRANT USAGE ON SCHEMA public TO canteen_app_grp, canteen_readonly_grp;

-- This schema contains the seven application tables; do not inherit old PUBLIC grants.
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA public
    FROM canteen_app, canteen_readonly, canteen_app_grp, canteen_readonly_grp;

ALTER TABLE public.student OWNER TO canteen_admin;
ALTER TABLE public.vendor OWNER TO canteen_admin;
ALTER TABLE public.menu_item OWNER TO canteen_admin;
ALTER TABLE public.customer_order OWNER TO canteen_admin;
ALTER TABLE public.order_item OWNER TO canteen_admin;
ALTER TABLE public.queue_entry OWNER TO canteen_admin;
ALTER TABLE public.notification OWNER TO canteen_admin;

GRANT SELECT, INSERT ON public.student TO canteen_app_grp;
GRANT SELECT, INSERT, UPDATE ON public.vendor TO canteen_app_grp;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.menu_item TO canteen_app_grp;
GRANT SELECT, INSERT, UPDATE ON public.customer_order TO canteen_app_grp;
GRANT SELECT, INSERT ON public.order_item TO canteen_app_grp;
GRANT SELECT, INSERT, UPDATE ON public.queue_entry TO canteen_app_grp;
GRANT SELECT, INSERT, UPDATE ON public.notification TO canteen_app_grp;

-- Reporting needs only sales data and public vendor/menu fields. Authentication
-- hashes, student data, notifications, and queue entries are deliberately excluded.
GRANT SELECT (item_id, vendor_id, item_name, price, is_available)
    ON public.menu_item TO canteen_readonly_grp;
GRANT SELECT (order_id, vendor_id, order_date, status)
    ON public.customer_order TO canteen_readonly_grp;
GRANT SELECT (order_id, item_id, quantity, price_at_order)
    ON public.order_item TO canteen_readonly_grp;
GRANT SELECT (vendor_id, vendor_name)
    ON public.vendor TO canteen_readonly_grp;
