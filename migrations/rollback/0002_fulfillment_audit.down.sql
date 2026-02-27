-- Rollback for fulfillment and audit baseline

DROP TABLE IF EXISTS audit_logs;
DROP TABLE IF EXISTS notification_events;
DROP TABLE IF EXISTS refunds;
DROP TABLE IF EXISTS shipments;
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS order_items;
