-- ============================================================
-- reporting_query.sql
-- The report this pipeline automates: "Weekly revenue by region,
-- week-over-week % change, and top 5 products" — a request that,
-- without automation, would normally go: department -> IT ->
-- manual SQL pull -> spreadsheet -> email, taking hours or days.
-- ============================================================

-- PART 1: Weekly revenue by region with week-over-week % change
WITH weekly_revenue AS (
    SELECT
        c.region,
        date_trunc('week', o.order_date)::date AS week_start,
        SUM(oi.quantity * oi.unit_price)        AS revenue
    FROM orders o
    JOIN customers c        ON c.customer_id = o.customer_id
    JOIN order_items oi     ON oi.order_id = o.order_id
    WHERE o.status = 'completed'
    GROUP BY c.region, date_trunc('week', o.order_date)
)
SELECT
    region,
    week_start,
    ROUND(revenue, 2) AS revenue,
    ROUND(
        100.0 * (revenue - LAG(revenue) OVER (PARTITION BY region ORDER BY week_start))
        / NULLIF(LAG(revenue) OVER (PARTITION BY region ORDER BY week_start), 0)
    , 1) AS wow_pct_change
FROM weekly_revenue
ORDER BY region, week_start;


-- PART 2: Top 5 products by revenue, most recent completed week
WITH latest_week AS (
    SELECT date_trunc('week', MAX(order_date))::date AS week_start
    FROM orders
    WHERE status = 'completed'
)
SELECT
    p.product_name,
    p.category,
    SUM(oi.quantity)                    AS units_sold,
    ROUND(SUM(oi.quantity * oi.unit_price), 2) AS revenue
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p     ON p.product_id = oi.product_id
JOIN latest_week lw ON date_trunc('week', o.order_date)::date = lw.week_start
WHERE o.status = 'completed'
GROUP BY p.product_name, p.category
ORDER BY revenue DESC
LIMIT 5;


-- PART 3: Company-wide summary (feeds the AI summarization step)
-- Returns one row of headline numbers the automation passes to the
-- AI step to turn into a plain-language weekly digest.
WITH latest_week AS (
    SELECT date_trunc('week', MAX(order_date))::date AS week_start
    FROM orders WHERE status = 'completed'
),
this_week AS (
    SELECT ROUND(SUM(oi.quantity * oi.unit_price), 2) AS revenue,
           COUNT(DISTINCT o.order_id) AS order_count
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    JOIN latest_week lw ON date_trunc('week', o.order_date)::date = lw.week_start
    WHERE o.status = 'completed'
),
prior_week AS (
    SELECT ROUND(SUM(oi.quantity * oi.unit_price), 2) AS revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    JOIN latest_week lw ON date_trunc('week', o.order_date)::date = lw.week_start - INTERVAL '7 days'
    WHERE o.status = 'completed'
)
SELECT
    tw.revenue                          AS this_week_revenue,
    tw.order_count                      AS this_week_orders,
    pw.revenue                          AS prior_week_revenue,
    ROUND(100.0 * (tw.revenue - pw.revenue) / NULLIF(pw.revenue, 0), 1) AS wow_pct_change
FROM this_week tw, prior_week pw;
