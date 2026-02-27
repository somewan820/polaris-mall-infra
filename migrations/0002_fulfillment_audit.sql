-- Fulfillment and audit baseline for Polaris Mall MVP

CREATE TABLE IF NOT EXISTS order_items (
    id BIGSERIAL PRIMARY KEY,
    order_id VARCHAR(32) NOT NULL,
    product_id VARCHAR(32) NOT NULL,
    product_name VARCHAR(255) NOT NULL,
    price_cents INTEGER NOT NULL CHECK (price_cents >= 0),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    line_total_cents INTEGER NOT NULL CHECK (line_total_cents >= 0),
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS payments (
    id VARCHAR(32) PRIMARY KEY,
    order_id VARCHAR(32) NOT NULL UNIQUE,
    user_id VARCHAR(32) NOT NULL,
    provider VARCHAR(32) NOT NULL,
    status VARCHAR(32) NOT NULL,
    amount_cents INTEGER NOT NULL CHECK (amount_cents >= 0),
    external_txn_id VARCHAR(128) NOT NULL DEFAULT '',
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS shipments (
    order_id VARCHAR(32) PRIMARY KEY,
    tracking_no VARCHAR(128) NOT NULL,
    carrier VARCHAR(64) NOT NULL,
    status VARCHAR(32) NOT NULL,
    shipped_at TIMESTAMP NOT NULL,
    delivered_at TIMESTAMP NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS refunds (
    id VARCHAR(32) PRIMARY KEY,
    order_id VARCHAR(32) NOT NULL UNIQUE,
    user_id VARCHAR(32) NOT NULL,
    amount_cents INTEGER NOT NULL CHECK (amount_cents > 0),
    reason VARCHAR(255) NOT NULL,
    status VARCHAR(32) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS notification_events (
    id BIGSERIAL PRIMARY KEY,
    event_type VARCHAR(64) NOT NULL,
    order_id VARCHAR(32) NOT NULL,
    payload_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS audit_logs (
    id BIGSERIAL PRIMARY KEY,
    actor_user_id VARCHAR(32) NOT NULL,
    actor_role VARCHAR(32) NOT NULL,
    action VARCHAR(64) NOT NULL,
    target_type VARCHAR(32) NOT NULL,
    target_id VARCHAR(64) NOT NULL,
    detail_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items (order_id);
CREATE INDEX IF NOT EXISTS idx_payments_user_id ON payments (user_id);
CREATE INDEX IF NOT EXISTS idx_refunds_user_id ON refunds (user_id);
CREATE INDEX IF NOT EXISTS idx_notification_events_order_id ON notification_events (order_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_target ON audit_logs (target_type, target_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs (created_at);
