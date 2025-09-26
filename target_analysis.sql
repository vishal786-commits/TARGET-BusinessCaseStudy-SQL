-- ======================================================
-- Target Brazil E-Commerce SQL Analysis (2016–2018)
-- Author: Vishal Gopalkrishna
-- Description: Business case analysis using SQL
-- ======================================================

---------------------------------------------------------
-- 1. Exploratory Analysis
---------------------------------------------------------

-- 1.1 Data types of columns in customers table
SELECT column_name, data_type
FROM `Target.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = 'customers';

-- 1.2 Time range of orders
SELECT 
    MIN(order_purchase_timestamp) AS min_time_range,
    MAX(order_purchase_timestamp) AS max_time_range
FROM `Target.orders`;

-- 1.3 Count distinct cities and states of customers
SELECT 
    COUNT(DISTINCT customer_city) AS no_of_cities,
    COUNT(DISTINCT customer_state) AS no_of_states
FROM `Target.customers`;


---------------------------------------------------------
-- 2. Orders and Trends
---------------------------------------------------------

-- 2.1 Growth trend in orders over months
SELECT *,
       CONCAT(ROUND(((next_order-no_of_orders)*100/no_of_orders), 1), "%") AS Growth
FROM (
    SELECT *,
           LEAD(no_of_orders) OVER (ORDER BY yearmonth) AS next_order
    FROM (
        SELECT FORMAT_DATE("%Y-%m", order_purchase_timestamp) AS yearmonth,
               COUNT(order_id) AS no_of_orders
        FROM `Target.orders`
        GROUP BY yearmonth
        ORDER BY yearmonth
    ) AS T
) AS TT;

-- 2.2 Seasonality check (monthly)
SELECT FORMAT_DATE("%m", order_purchase_timestamp) AS month,
       COUNT(order_id) AS no_of_orders
FROM `Target.orders`
GROUP BY month
ORDER BY month;

-- 2.3 Orders by time of day
SELECT TT.time_of_day, COUNT(TT.order_id) AS no_of_orders
FROM (
    SELECT *,
           CASE
               WHEN TIME(order_purchase_timestamp) BETWEEN "00:00:00" AND "07:00:00" THEN "Dawn"
               WHEN TIME(order_purchase_timestamp) BETWEEN "07:00:00" AND "13:00:00" THEN "Morning"
               WHEN TIME(order_purchase_timestamp) BETWEEN "13:00:00" AND "19:00:00" THEN "Afternoon"
               ELSE "Night"
           END AS time_of_day
    FROM `Target.orders`
) AS TT
GROUP BY 1
ORDER BY 2 DESC;


---------------------------------------------------------
-- 3. Customer and State Analysis
---------------------------------------------------------

-- 3.1 Month-on-month orders per state
SELECT customer_state, yearmonth, COUNT(order_id) AS no_of_orders
FROM (
    SELECT O.order_id, O.customer_id, C.customer_state,
           FORMAT_DATE("%Y-%m", O.order_purchase_timestamp) AS yearmonth
    FROM `Target.orders` AS O
    INNER JOIN `Target.customers` AS C
    ON O.customer_id = C.customer_id
) AS T
GROUP BY 1,2
ORDER BY 1,2;

-- 3.2 Customer distribution across states
SELECT customer_state, COUNT(DISTINCT customer_id) AS no_of_customers
FROM (
    SELECT O.order_id, O.customer_id, C.customer_state
    FROM `Target.orders` AS O
    INNER JOIN `Target.customers` AS C
    ON O.customer_id = C.customer_id
) AS T
GROUP BY 1
ORDER BY 2 DESC;


---------------------------------------------------------
-- 4. Economy and Payments
---------------------------------------------------------

-- 4.1 % increase in order cost (2017 vs 2018, Jan–Aug)
WITH base AS (
    SELECT yearmonth,
           ROUND(SUM(payment_value), 2) AS sum_pay_val,
           LEAD(ROUND(SUM(payment_value), 2), 12) OVER (ORDER BY yearmonth) AS next_year_pay
    FROM (
        SELECT O.order_id,
               FORMAT_DATE("%Y-%m", O.order_purchase_timestamp) AS yearmonth,
               P.payment_value
        FROM `Target.orders` AS O
        INNER JOIN `Target.payments` AS P
        ON O.order_id = P.order_id
    ) AS T
    WHERE yearmonth BETWEEN "2017-01" AND "2018-08"
    GROUP BY 1
)
SELECT ROUND(SUM(sum_pay_val), 1) AS total_2017,
       ROUND(SUM(next_year_pay), 1) AS total_2018,
       CONCAT(ROUND(((SUM(next_year_pay)-SUM(sum_pay_val))*100/SUM(sum_pay_val)),1), "%") AS increase_percent
FROM base
WHERE yearmonth < "2017-09";

-- 4.2 Total & Average order price per state
SELECT customer_state,
       ROUND(AVG(payment_value),1) AS avg_order_price,
       ROUND(SUM(payment_value),1) AS total_order_price
FROM (
    SELECT O.order_id, C.customer_state, P.payment_value
    FROM `Target.orders` AS O
    INNER JOIN `Target.customers` AS C ON O.customer_id = C.customer_id
    INNER JOIN `Target.payments` AS P ON O.order_id = P.order_id
) AS TT
GROUP BY 1
ORDER BY 2 DESC;

-- (etc. – continue adding freight, delivery time, and payment type queries similarly)
