-- 1. Creating customer table
CREATE TABLE customers (
	customer_id VARCHAR(50) PRIMARY KEY,
	customer_unique_id VARCHAR(50),
	customer_zip_code_prefix INTEGER,
	customer_city VARCHAR(100),
	customer_state VARCHAR(2)
);

SELECT COUNT(*)
FROM customers;

SELECT *
FROM customers
LIMIT 10;

-- 2. Creating orders table
CREATE TABLE orders (
	order_id VARCHAR(50) PRIMARY KEY,
	customer_id VARCHAR(50) REFERENCES customers(customer_id),
	order_status VARCHAR(50),
	order_purchase_timestamp TIMESTAMP,
	order_approved_at TIMESTAMP,
	order_delivered_carrier_date TIMESTAMP,
	order_delivered_customer_date TIMESTAMP,
	order_estimated_delivery_date TIMESTAMP
);

SELECT COUNT (*)
FROM orders;
 
SELECT *
FROM orders
LIMIT 10;

SELECT 
	COUNT (*) AS total_orders,
	COUNT(order_approved_at) AS approved,
	COUNT(order_delivered_carrier_date) AS sent_to_carrier,
	COUNT(order_delivered_customer_date) AS delivered
FROM orders;


-- 3. Creating Order items table
CREATE TABLE order_items (
	order_id VARCHAR(50) REFERENCES orders(order_id),
	order_item_id INTEGER,
	product_id VARCHAR(50),
	seller_id VARCHAR(50),
	shipping_limit_date TIMESTAMP,
	price NUMERIC(10,2),
	freight_value NUMERIC(10,2),
	PRIMARY KEY (order_id, order_item_id)
);


SELECT COUNT (*)
FROM order_items;

SELECT *
FROM order_items
LIMIT 10;

-- 4. Creating Order Payments table
CREATE TABLE order_payments (
	order_id VARCHAR(50) REFERENCES orders(order_id),
	payment_sequential INTEGER,
	payment_type VARCHAR(50),
	payment_installments INTEGER,
	payment_value NUMERIC(10,2),
	PRIMARY KEY (order_id, payment_sequential)
);

SELECT COUNT (*)
FROM order_payments;

SELECT *
FROM order_payments
LIMIT 10;

-- 5. Creating Order Reviews table
CREATE TABLE order_reviews (
	review_id VARCHAR(50),
	order_id VARCHAR(50) REFERENCES orders(order_id),
	review_score INTEGER,
	review_comment_title TEXT,
	review_comment_message TEXT,
	review_creation_date TIMESTAMP,
	review_answer_timestamp TIMESTAMP,
	PRIMARY KEY (order_id, review_id)
);

SELECT COUNT (*)
FROM order_reviews;

SELECT *
FROM order_reviews
LIMIT 10;


-- 6 Creating products table
CREATE TABLE products (
	product_id VARCHAR(50),
	product_category_name VARCHAR(100),
	product_name_lenght INTEGER,
	product_description_lenght INTEGER,
	product_photos_qty INTEGER,
	product_weight_g INTEGER,
	product_length_cm INTEGER,
	product_height_cm INTEGER,
	product_width_cm INTEGER,
	PRIMARY KEY (product_id)
);

SELECT COUNT (*)
FROM products;

SELECT *
FROM products
LIMIT 10;

ALTER TABLE order_items
ADD CONSTRAINT fk_order_items_product
FOREIGN KEY (product_id)
REFERENCES products(product_id);


--7. Creating sellers table
CREATE TABLE sellers (
	seller_id VARCHAR(50),
	seller_zip_code_prefix INTEGER,
	seller_city VARCHAR(100),
	seller_state VARCHAR(2),
	PRIMARY KEY (seller_id)
);

SELECT COUNT (*)
FROM sellers;

SELECT *
FROM sellers
LIMIT 10;

ALTER TABLE order_items
ADD CONSTRAINT fk_order_items_seller
FOREIGN KEY (seller_id)
REFERENCES sellers(seller_id);

--8. Creating product category name translation
-- NOTE: Olist is located in Brazil, thus using Portugese as their main language of business operations
CREATE TABLE product_category_name_translation (
	product_category_name VARCHAR(100) PRIMARY KEY,
	product_category_name_english VARCHAR(100)
);

SELECT COUNT (*)
FROM product_category_name_translation;

SELECT *
FROM product_category_name_translation
LIMIT 10;

-- 9. Creating geolocation table
CREATE TABLE geolocation (
	geolocation_zip_code_prefix INTEGER,
	geolocation_lat NUMERIC(18,15),
	geolocation_lng NUMERIC(18,15),
	geolocation_city VARCHAR(100),
	geolocation_state VARCHAR(2)
);

ALTER TABLE geolocation
ALTER COLUMN geolocation_lat TYPE DOUBLE PRECISION,
ALTER COLUMN geolocation_lng TYPE DOUBLE PRECISION;

SELECT COUNT (*)
FROM geolocation;

SELECT *
FROM geolocation
LIMIT 10;

--PHASE 1: DATA VALIDATION AND EXPLORATION

SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL
SELECT 'order_reviews', COUNT(*) FROM order_reviews
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL
SELECT 'product_category_name_translation', COUNT(*) FROM product_category_name_translation
UNION ALL
SELECT 'geolocation', COUNT(*) FROM geolocation;


-- PHASE 2: UNDERSTANDING ANALYTICAL GRAIN

SELECT
	COUNT(*) AS customet_rows,
	COUNT(DISTINCT customer_id) AS unique_customer_ids,
	COUNT(DISTINCT customer_unique_id) AS unique_people
FROM customers;

--finding: customer_id is an order-level customer identifier
--finding: customer_unique_id recognizes the same customer across different orders
-- Q: Which 10 customers have placed the most orders

SELECT 
	customer_unique_id,
	COUNT(customer_id) AS number_of_orders
FROM customers
GROUP BY customer_unique_id
ORDER BY number_of_orders DESC
LIMIT 10;

--finding: our top customer appears 17 times, the next 9 times and quickly falls to 7 and 6
-- this may suggest that repeat purchasing is relatively uncommom
-- Q. What percentage of customers purchases once versus multiple times

WITH customer_orders AS (
	SELECT
		customer_unique_id,
		COUNT(customer_id) AS number_of_orders
	FROM customers
	GROUP BY customer_unique_id
)
SELECT
	CASE
		WHEN number_of_orders = 1 THEN 'One-Time'
		ELSE 'Repeat'
	END AS customer_type,
	COUNT(*) AS number_of_customers,
	ROUND(
		COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
		2
	) AS percentage_of_customers
FROM customer_orders
GROUP BY
	CASE
		WHEN number_of_orders = 1 THEN 'One-Time'
		ELSE 'Repeat'
	END;

-- 96.88% customers are one-time purchasers

-- PHASE 3: BUSINESS PERFORMANCE
---PART A --> Customer repeat-purchase analysis
-- Q. How have monthly revenue and order volume changed over time?

SELECT
	DATE_TRUNC('month',o.order_purchase_timestamp) AS order_month,
	COUNT(DISTINCT o.order_id) AS total_orders,
	ROUND(SUM(oi.price), 2) AS total_revenue,
	ROUND(SUM(oi.price) / COUNT(DISTINCT o.order_id), 2) AS average_order_value
FROM orders AS o
JOIN order_items AS oi
	ON o.order_id = oi.order_id
WHERE o.order_purchase_timestamp >= '2017-01-01'
AND o.order_purchase_timestamp < '2018-09-01'
GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
ORDER BY order_month;

-- November's revenue growth was driven by higher order volume, not higher spending per order.
--Compared with October:
-- Orders increased by approximately 63.1%.
-- Revenue increased by approximately 52.1%.
-- AOV actually decreased by approximately 6.8%.
-- This suggests customers were placing substantially more orders, but spending slightly less per order.

-- Q. What exactly is driving the November spike?
-- Investigating Daily November Orders

SELECT
	DATE(o.order_purchase_timestamp) AS order_date,
	COUNT(DISTINCT o.order_id) AS total_orders,
	ROUND(SUM(oi.price), 2) AS total_revenue,
	ROUND(SUM(oi.price) / COUNT(DISTINCT o.order_id), 2) AS average_order_value	
FROM orders AS o
JOIN order_items AS oi
	ON o.order_id = oi.order_id
WHERE o.order_purchase_timestamp >= '2017-11-01'
AND o.order_purchase_timestamp < '2017-12-01'
GROUP BY DATE(o.order_purchase_timestamp)
ORDER BY order_date;

--Insight: Black Friday in 2017 generated the highest daily merchandise revenue in Nov
-- reaching $152,654. Compared with the previous day, order volume increased 321% 
-- while AOV declined by 18.9%.
-- This suggest the event's commercial success was driven by increased purchasing activity rather than higher transaction values/basket sizes

---Part B --> Customer segmentation
--- we know 3.12% of customers are repeat purchases


-- Total merchandise spending per customer (focus on top 10 customers)
SELECT
	c.customer_unique_id,
	COUNT(DISTINCT o.order_id) AS total_orders,
	ROUND(SUM(oi.price), 2) AS total_spend
FROM customers AS c
JOIN orders as o
	ON c.customer_id = o.customer_id
JOIN order_items AS oi
	ON o.order_id = oi.order_id
GROUP BY c.customer_unique_id
ORDER BY total_spend DESC
LIMIT 10;


-- what percentage of total merchandise revenue comes from repeat customers?

WITH customer_spending AS(
	SELECT 
		c.customer_unique_id,
		COUNT(DISTINCT o.order_id) AS total_orders,
		SUM(oi.price) AS total_spend
	FROM customers AS c
	JOIN orders AS o
		ON c.customer_id = o.customer_id
	JOIN order_items AS oi
		ON o.order_id = oi.order_id
	GROUP BY c.customer_unique_id
),

customer_segments AS (
	SELECT
		customer_unique_id,
		total_orders,
		total_spend,
		CASE
			WHEN total_orders = 1 THEN 'One-Time'
			ELSE 'Repeat'
		END AS customer_type
	FROM customer_spending
)
SELECT 
	customer_type,
	COUNT(*) AS number_of_customers,
	ROUND(SUM(total_spend), 2) AS total_revenue,
	ROUND(AVG(total_spend), 2) AS average_customer_spend,
	ROUND(SUM(total_spend) * 100.0 / SUM(SUM(total_spend))OVER (), 2) AS percentage_of_revenue
FROM customer_segments
GROUP BY customer_type;

-- Recency, Frequency & Monetary 
WITH customer_rfm AS (
	SELECT
		c.customer_unique_id,
		MAX(o.order_purchase_timestamp) AS last_purchase_date,
		COUNT(DISTINCT o.order_id) AS frequency,
		ROUND(SUM(oi.price), 2) AS monetary_value
	FROM customers AS c
	JOIN orders AS o
		ON c.customer_id = o.customer_id
	JOIN order_items AS oi
		ON o.order_id = oi.order_id
	WHERE o.order_purchase_timestamp < '2018-09-01'
	GROUP BY c.customer_unique_id
)
SELECT
	customer_unique_id,
	('2018-09-01'::DATE - last_purchase_date::DATE) AS recency_days,
	frequency,
	monetary_value
FROM customer_rfm
ORDER BY recency_days ASC
LIMIT 10;

-- Distribution of customers

WITH customer_rfm AS (
	SELECT
		c.customer_unique_id,
		MAX(o.order_purchase_timestamp) AS last_purchase_date,
		COUNT(DISTINCT o.order_id) AS frequency,
		SUM(oi.price) AS monetary_value
	FROM customers AS c
	JOIN orders AS o
		ON c.customer_id = o.customer_id
	JOIN order_items AS oi
		ON o.order_id = oi.order_id
	WHERE o.order_purchase_timestamp < '2018-09-01'
	GROUP BY c.customer_unique_id
),
rfm_metrics AS (
	SELECT
		customer_unique_id,
		'2018-09-01'::DATE - last_purchase_date::DATE AS recency_days,
		frequency,
		monetary_value
	FROM customer_rfm
)

SELECT
	COUNT(*) AS total_customers,
	
	ROUND(AVG(recency_days), 2) AS avg_recency,
	MIN(recency_days) AS min_recency,
	MAX(recency_days) AS max_recency,
	
	ROUND(AVG(frequency), 2) AS avg_frequency,
	MAX(frequency) AS max_frequency,

	ROUND(AVG(monetary_value), 2) AS avg_monetary,
	ROUND(MAX(monetary_value), 2) AS max_monetary

FROM rfm_metrics;


-- segmenting customers
-- recency using nTile 5
-- frequency split into either one-time versus repeat
-- monetary using nTile 5

WITH customer_rfm AS (
	SELECT
		c.customer_unique_id,
		MAX(o.order_purchase_timestamp) AS last_purchase_date,
		COUNT(DISTINCT o.order_id) AS frequency,
		SUM(oi.price) AS monetary_value
	FROM customers AS c
	JOIN orders AS o
		ON c.customer_id = o.customer_id
	JOIN order_items AS oi
		ON o.order_id = oi.order_id
	WHERE o.order_purchase_timestamp < '2018-09-01'
	GROUP BY c.customer_unique_id
),
rfm_metrics AS (
	SELECT
		customer_unique_id,
		'2018-09-01'::DATE - last_purchase_date::DATE AS recency_days,
		frequency,
		monetary_value
	FROM customer_rfm
)

SELECT
	customer_unique_id,
	recency_days,
	frequency,
	monetary_value,

	NTILE(5) OVER (ORDER BY recency_days DESC) AS recency_score,

	CASE
		WHEN frequency = 1 THEN 1
		ELSE 2
	END AS frequency_score,

	NTILE(5) OVER (ORDER BY monetary_value ASC) AS monetary_score

FROM rfm_metrics
ORDER BY customer_unique_id
LIMIT 10;


-- creating customer segments based on our analysis
-- Q. How can Olist group customers based in purchasing behaviour to develop more targeted retention and marketing strategies?

WITH customer_rfm AS (
	SELECT
		c.customer_unique_id,
		MAX(o.order_purchase_timestamp) AS last_purchase_date,
		COUNT(DISTINCT o.order_id) AS frequency,
		SUM(oi.price) AS monetary_value
	FROM customers AS c
	JOIN orders AS o
		ON c.customer_id = o.customer_id
	JOIN order_items AS oi
		ON o.order_id = oi.order_id
	WHERE o.order_purchase_timestamp < '2018-09-01'
	GROUP BY c.customer_unique_id
),
rfm_metrics AS (
	SELECT
		customer_unique_id,
		'2018-09-01'::DATE - last_purchase_date::DATE AS recency_days,
		frequency,
		monetary_value
	FROM customer_rfm
),
rfm_scores AS (
	SELECT 
		customer_unique_id,
		recency_days,
		frequency,
		monetary_value,
		
		NTILE(5) OVER(ORDER BY recency_days DESC) AS recency_score,

		CASE
			WHEN frequency = 1 THEN 1
			ELSE 2
		END AS frequency_score,
		
		NTILE(5) OVER(ORDER BY monetary_value ASC) AS monetary_score

	FROM rfm_metrics
),
customer_segments AS (
    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        monetary_value,
        recency_score,
        frequency_score,
        monetary_score,

        CASE
            WHEN recency_score >= 4
                 AND frequency_score = 1
                 AND monetary_score >= 4
                THEN 'Recent High-Value First-Time'

            WHEN recency_score >= 4
                 AND frequency_score = 2
                THEN 'Recent Repeat'

            WHEN recency_score <= 2
                 AND monetary_score >= 4
                THEN 'High-Value Inactive'

            ELSE 'Other Customers'
        END AS customer_segment

    FROM rfm_scores
)

SELECT
    customer_segment,
    COUNT(*) AS number_of_customers,
    ROUND(SUM(monetary_value), 2) AS total_revenue,
    ROUND(AVG(monetary_value), 2) AS average_customer_spend,
	ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage_of_customers,
	ROUND(SUM(monetary_value) * 100.0 / SUM(SUM(monetary_value)) OVER(), 2) AS percentage_of_revenue
FROM customer_segments
GROUP BY customer_segment
ORDER BY total_revenue DESC;


--first and last customer purchases (top 10 most frequent customers)
SELECT
    c.customer_unique_id,
    MIN(o.order_purchase_timestamp) AS first_purchase_date,
    MAX(o.order_purchase_timestamp) AS last_purchase_date,
    COUNT(DISTINCT o.order_id) AS total_orders
FROM customers c
JOIN orders o
    ON c.customer_id = o.customer_id
WHERE o.order_purchase_timestamp < '2018-09-01'
GROUP BY c.customer_unique_id
ORDER BY total_orders DESC
LIMIT 10;

--customer's first purchase month

WITH customer_cohorts AS (
    SELECT
        c.customer_unique_id,
        DATE_TRUNC(
            'month',
            MIN(o.order_purchase_timestamp)
        ) AS cohort_month
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    WHERE o.order_purchase_timestamp < '2018-09-01'
    GROUP BY c.customer_unique_id
),

customer_orders AS (
    SELECT
        c.customer_unique_id,
        cc.cohort_month,
        DATE_TRUNC('month',o.order_purchase_timestamp) AS order_month
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    JOIN customer_cohorts cc
        ON c.customer_unique_id = cc.customer_unique_id
    WHERE o.order_purchase_timestamp < '2018-09-01'
),
cohort_activity AS (
    SELECT
        customer_unique_id,
        cohort_month,
        (
            EXTRACT(YEAR FROM AGE(order_month, cohort_month)) * 12
            + EXTRACT(MONTH FROM AGE(order_month, cohort_month))
        )::INTEGER AS cohort_index
    FROM customer_orders
),
cohort_sizes AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT customer_unique_id) AS cohort_size
    FROM customer_cohorts
    GROUP BY cohort_month
),
cohort_retention AS (
    SELECT
        cohort_month,
        cohort_index,
        COUNT(DISTINCT customer_unique_id) AS active_customers
    FROM cohort_activity
    GROUP BY cohort_month, cohort_index
)

SELECT
    cr.cohort_month::DATE AS cohort_month,
    cs.cohort_size,

    ROUND(
        100.0 * MAX(CASE WHEN cr.cohort_index = 0
            THEN cr.active_customers END)
        / cs.cohort_size, 2
    ) AS month_0,

    ROUND(
        100.0 * COALESCE(MAX(CASE WHEN cr.cohort_index = 1
            THEN cr.active_customers END), 0)
        / cs.cohort_size, 2
    ) AS month_1,

    ROUND(
        100.0 * COALESCE(MAX(CASE WHEN cr.cohort_index = 2
            THEN cr.active_customers END), 0)
        / cs.cohort_size, 2
    ) AS month_2,

    ROUND(
        100.0 * COALESCE(MAX(CASE WHEN cr.cohort_index = 3
            THEN cr.active_customers END), 0)
        / cs.cohort_size, 2
    ) AS month_3

FROM cohort_retention cr
JOIN cohort_sizes cs
    ON cr.cohort_month = cs.cohort_month

WHERE cr.cohort_month < '2018-06-01'

GROUP BY cr.cohort_month, cs.cohort_size
HAVING cs.cohort_size >= 100
ORDER BY cr.cohort_month;

--Fixing methodological error
-- We want to ensure our ealier queries are only applied to delivered merchandize

CREATE OR REPLACE VIEW delivered_orders AS
SELECT *
FROM orders
WHERE order_status = 'delivered'
  AND order_purchase_timestamp < '2018-09-01';

  --FIX sub A: RFM Calculation


WITH customer_rfm AS (
    SELECT
        c.customer_unique_id,
        MAX(o.order_purchase_timestamp) AS last_purchase_date,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(oi.price::NUMERIC) AS monetary_value

    FROM customers AS c

    JOIN delivered_orders AS o
        ON c.customer_id = o.customer_id

    JOIN order_items AS oi
        ON o.order_id = oi.order_id

    GROUP BY c.customer_unique_id
),

rfm_metrics AS (
    SELECT
        customer_unique_id, 
		'2018-09-01'::DATE - last_purchase_date::DATE AS recency_days,
        frequency,
        monetary_value

    FROM customer_rfm
)

SELECT
    COUNT(*) AS total_customers,
    ROUND(AVG(recency_days), 2) AS avg_recency,
    MIN(recency_days) AS min_recency,
    MAX(recency_days) AS max_recency,
    ROUND(AVG(frequency), 2) AS avg_frequency,
    MAX(frequency) AS max_frequency,
    ROUND(AVG(monetary_value), 2) AS avg_monetary,
    ROUND(MAX(monetary_value), 2) AS max_monetary

FROM rfm_metrics;

--CORRECTED RFM CUSTOMER SEGMENTS

WITH customer_rfm AS (
    SELECT
        c.customer_unique_id,
        MAX(o.order_purchase_timestamp) AS last_purchase_date,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(oi.price::NUMERIC) AS monetary_value
    FROM customers AS c
    JOIN delivered_orders AS o
        ON c.customer_id = o.customer_id
    JOIN order_items AS oi
        ON o.order_id = oi.order_id
    GROUP BY c.customer_unique_id
),

rfm_metrics AS (
    SELECT
        customer_unique_id,
        '2018-09-01'::DATE - last_purchase_date::DATE AS recency_days,
        frequency,
        monetary_value
    FROM customer_rfm
),

rfm_scores AS (
    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        monetary_value,

        NTILE(5) OVER (ORDER BY recency_days DESC) AS recency_score,

        CASE
            WHEN frequency = 1 THEN 1
            ELSE 2
        END AS frequency_score,

        NTILE(5) OVER (ORDER BY monetary_value ASC) AS monetary_score

    FROM rfm_metrics
),

customer_segments AS (
    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        monetary_value,
        recency_score,
        frequency_score,
        monetary_score,

        CASE
            WHEN recency_score >= 4
                 AND frequency_score = 1
                 AND monetary_score >= 4
                THEN 'Recent High-Value First-Time'

            WHEN recency_score >= 4
                 AND frequency_score = 2
                THEN 'Recent Repeat'

            WHEN recency_score <= 2
                 AND monetary_score >= 4
                THEN 'High-Value Inactive'

            ELSE 'Other Customers'
        END AS customer_segment

    FROM rfm_scores
)

SELECT
    customer_segment,
    COUNT(*) AS number_of_customers,

    ROUND(SUM(monetary_value), 2) AS total_revenue,

    ROUND(AVG(monetary_value), 2) AS average_customer_spend,

    ROUND(
        COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (), 2
    ) AS percentage_of_customers,

    ROUND(
        SUM(monetary_value) * 100.0 /
        SUM(SUM(monetary_value)) OVER (), 2
    ) AS percentage_of_revenue

FROM customer_segments
GROUP BY customer_segment
ORDER BY total_revenue DESC;


-- CORRECTED CUSTOMER RETENTION
-- Includes delivered orders only
-- Analysis cutoff: September 1, 2018

WITH customer_cohorts AS (
-- Step 1: Identify each customer's first purchase month
    SELECT
        c.customer_unique_id,
        DATE_TRUNC('month', MIN(o.order_purchase_timestamp)) AS cohort_month
    FROM customers AS c
    JOIN delivered_orders AS o
        ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
),

customer_orders AS (
-- Step 2: Identify months when customers purchased
    SELECT
        c.customer_unique_id,
        cc.cohort_month,
        DATE_TRUNC('month',o.order_purchase_timestamp) AS order_month
    FROM customers AS c
    JOIN delivered_orders AS o
        ON c.customer_id = o.customer_id
    JOIN customer_cohorts AS cc
        ON c.customer_unique_id = cc.customer_unique_id
),

cohort_activity AS (
    -- Step 3: Calculate months since first purchase
    SELECT
        customer_unique_id,
        cohort_month,
        (EXTRACT(YEAR FROM AGE(order_month, cohort_month)) * 12 + EXTRACT(
                MONTH FROM AGE(order_month, cohort_month)))::INTEGER AS cohort_index
    FROM customer_orders
),

cohort_sizes AS (
    -- Step 4: Count customers in each acquisition cohort
    SELECT
        cohort_month,
        COUNT(DISTINCT customer_unique_id) AS cohort_size
    FROM customer_cohorts
    GROUP BY cohort_month
),

cohort_retention AS (
    -- Step 5: Count active customers by cohort and month
    SELECT
        cohort_month,
        cohort_index,
        COUNT(DISTINCT customer_unique_id) AS active_customers
    FROM cohort_activity
    GROUP BY cohort_month, cohort_index
)

-- Step 6: Calculate monthly retention percentages
SELECT
    cr.cohort_month::DATE AS cohort_month,
    cs.cohort_size,
    ROUND(
        100.0 * COALESCE(
            MAX(CASE WHEN cr.cohort_index = 0
                THEN cr.active_customers END), 0) / cs.cohort_size, 2) AS month_0,
    ROUND(
        100.0 * COALESCE(
            MAX(CASE WHEN cr.cohort_index = 1
                THEN cr.active_customers END), 0) / cs.cohort_size, 2) AS month_1,
    ROUND(
        100.0 * COALESCE(
            MAX(CASE WHEN cr.cohort_index = 2
                THEN cr.active_customers END), 0) / cs.cohort_size, 2) AS month_2,
    ROUND(
        100.0 * COALESCE(
            MAX(CASE WHEN cr.cohort_index = 3
                THEN cr.active_customers END), 0
        ) / cs.cohort_size, 2) AS month_3

FROM cohort_retention AS cr
JOIN cohort_sizes AS cs
    ON cr.cohort_month = cs.cohort_month

-- Include only cohorts with 3 months of follow-up
WHERE cr.cohort_month >= '2017-01-01'
  AND cr.cohort_month < '2018-06-01'

GROUP BY
    cr.cohort_month, cs.cohort_size
-- Exclude very small cohorts
HAVING cs.cohort_size >= 100
ORDER BY cr.cohort_month;




