-- ============================================================
-- schema.sql
-- Core "ERP-style" operations schema: customers, products, orders
-- Designed to mirror a typical ERP sales/operations data model
-- (this is the pattern used regardless of vendor: SAP, NetSuite,
-- Odoo, Dynamics all reduce to variations of this shape).
-- ============================================================

CREATE TABLE IF NOT EXISTS customers (
    customer_id     SERIAL PRIMARY KEY,
    customer_name   VARCHAR(120) NOT NULL,
    region          VARCHAR(50)  NOT NULL,   -- e.g. 'North', 'South', 'East', 'West', 'Central'
    segment         VARCHAR(50)  NOT NULL,   -- e.g. 'Enterprise', 'SMB', 'Retail'
    created_at      DATE NOT NULL DEFAULT CURRENT_DATE
);

CREATE TABLE IF NOT EXISTS products (
    product_id      SERIAL PRIMARY KEY,
    product_name    VARCHAR(120) NOT NULL,
    category        VARCHAR(60)  NOT NULL,
    unit_price      NUMERIC(10,2) NOT NULL CHECK (unit_price >= 0)
);

CREATE TABLE IF NOT EXISTS orders (
    order_id        SERIAL PRIMARY KEY,
    customer_id     INTEGER NOT NULL REFERENCES customers(customer_id),
    order_date      DATE NOT NULL,
    status          VARCHAR(30) NOT NULL DEFAULT 'completed'  -- completed | pending | cancelled
);

CREATE TABLE IF NOT EXISTS order_items (
    order_item_id   SERIAL PRIMARY KEY,
    order_id        INTEGER NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    product_id      INTEGER NOT NULL REFERENCES products(product_id),
    quantity        INTEGER NOT NULL CHECK (quantity > 0),
    unit_price      NUMERIC(10,2) NOT NULL   -- price at time of sale (snapshot, not FK to products.unit_price)
);

-- Helpful indexes for reporting queries
CREATE INDEX IF NOT EXISTS idx_orders_date       ON orders(order_date);
CREATE INDEX IF NOT EXISTS idx_orders_customer    ON orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_order_items_order   ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product ON order_items(product_id);
