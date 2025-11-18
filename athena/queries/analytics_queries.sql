-- ==========================================
-- Amazon Athena Analytics Queries
-- Data Pipeline Sample Queries
-- ==========================================

-- Query 1: Revenue by Region and Payment Method
SELECT 
    region,
    payment_method,
    COUNT(*) as transaction_count,
    SUM(total_amount) as total_revenue,
    ROUND(AVG(total_amount), 2) as avg_transaction_value,
    MIN(total_amount) as min_transaction,
    MAX(total_amount) as max_transaction
FROM data_pipeline_catalog.sales_enriched_transactions
WHERE year = '2025' AND month = '11' AND day = '18'
GROUP BY region, payment_method
ORDER BY total_revenue DESC;

-- Query 2: Weekend vs Weekday Sales Analysis
SELECT 
    is_weekend,
    CASE 
        WHEN is_weekend = true THEN 'Weekend'
        ELSE 'Weekday'
    END as day_type,
    COUNT(*) as transactions,
    SUM(total_amount) as revenue,
    ROUND(AVG(total_amount), 2) as avg_value
FROM data_pipeline_catalog.sales_enriched_transactions
WHERE year = '2025' AND month = '11' AND day = '18'
GROUP BY is_weekend
ORDER BY is_weekend;

-- Query 3: Revenue Category Distribution
SELECT 
    revenue_category,
    COUNT(*) as transaction_count,
    SUM(total_amount) as total_revenue,
    ROUND(AVG(total_amount), 2) as avg_transaction,
    ROUND(SUM(total_amount) * 100.0 / SUM(SUM(total_amount)) OVER(), 2) as revenue_percentage
FROM data_pipeline_catalog.sales_enriched_transactions
WHERE year = '2025' AND month = '11' AND day = '18'
GROUP BY revenue_category
ORDER BY total_revenue DESC;

-- Query 4: Order Size Analysis
SELECT 
    order_size,
    COUNT(*) as order_count,
    SUM(quantity) as total_units_sold,
    SUM(total_amount) as total_revenue,
    ROUND(AVG(quantity), 2) as avg_quantity_per_order,
    ROUND(AVG(total_amount), 2) as avg_revenue_per_order
FROM data_pipeline_catalog.sales_enriched_transactions
WHERE year = '2025' AND month = '11' AND day = '18'
GROUP BY order_size
ORDER BY 
    CASE order_size
        WHEN 'single' THEN 1
        WHEN 'small' THEN 2
        WHEN 'medium' THEN 3
        WHEN 'bulk' THEN 4
    END;

-- Query 5: Discount Analysis
SELECT 
    COUNT(*) as total_transactions,
    COUNT(CASE WHEN discount_amount > 0 THEN 1 END) as discounted_transactions,
    ROUND(COUNT(CASE WHEN discount_amount > 0 THEN 1 END) * 100.0 / COUNT(*), 2) as discount_rate_pct,
    ROUND(AVG(discount_amount), 2) as avg_discount,
    ROUND(AVG(discount_percentage), 2) as avg_discount_pct,
    ROUND(SUM(discount_amount), 2) as total_discounts_given
FROM data_pipeline_catalog.sales_enriched_transactions
WHERE year = '2025' AND month = '11' AND day = '18';

-- Query 6: Top Customers by Revenue
SELECT 
    customer_id,
    COUNT(*) as purchase_count,
    SUM(total_amount) as total_spent,
    ROUND(AVG(total_amount), 2) as avg_order_value,
    SUM(quantity) as total_items_purchased,
    MAX(day_of_week) as last_purchase_day
FROM data_pipeline_catalog.sales_enriched_transactions
WHERE year = '2025' AND month = '11' AND day = '18'
GROUP BY customer_id
ORDER BY total_spent DESC
LIMIT 5;

-- Query 7: Product Performance
SELECT 
    product_id,
    COUNT(*) as times_sold,
    SUM(quantity) as total_units,
    SUM(total_amount) as total_revenue,
    ROUND(AVG(unit_price), 2) as avg_unit_price,
    ROUND(AVG(total_amount), 2) as avg_transaction_value
FROM data_pipeline_catalog.sales_enriched_transactions
WHERE year = '2025' AND month = '11' AND day = '18'
GROUP BY product_id
ORDER BY total_revenue DESC;

-- Query 8: Data Quality Check - Amount Validation
SELECT 
    amount_validation,
    COUNT(*) as transaction_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
FROM data_pipeline_catalog.sales_enriched_transactions
WHERE year = '2025' AND month = '11' AND day = '18'
GROUP BY amount_validation;

-- Query 9: Day of Week Sales Pattern
SELECT 
    day_of_week,
    COUNT(*) as transactions,
    SUM(total_amount) as revenue,
    ROUND(AVG(total_amount), 2) as avg_transaction_value,
    SUM(quantity) as total_units_sold
FROM data_pipeline_catalog.sales_enriched_transactions
WHERE year = '2025' AND month = '11' AND day = '18'
GROUP BY day_of_week
ORDER BY revenue DESC;

-- Query 10: Cross-Region Payment Method Preferences
SELECT 
    region,
    payment_method,
    COUNT(*) as usage_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(PARTITION BY region), 2) as pct_in_region
FROM data_pipeline_catalog.sales_enriched_transactions
WHERE year = '2025' AND month = '11' AND day = '18'
GROUP BY region, payment_method
ORDER BY region, usage_count DESC;
