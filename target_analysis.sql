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

-- 4.3 Total & Average freight value per state
SELECT customer_state,
       ROUND(AVG(TT.freight_sum), 1) AS avg_freight_val,
       ROUND(SUM(TT.freight_sum), 1) AS total_freight_val
FROM (
    SELECT O.order_id, C.customer_state, 
           ROUND(SUM(F.freight_value), 2) AS freight_sum
    FROM `Target.orders` AS O
    INNER JOIN `Target.customers` AS C 
        ON O.customer_id = C.customer_id
    INNER JOIN `Target.order_items` AS F 
        ON O.order_id = F.order_id
    GROUP BY 1,2
) AS TT
GROUP BY 1
ORDER BY 3 DESC;


---------------------------------------------------------
-- 5. Delivery & Logistics
---------------------------------------------------------

-- 5.1 Delivery time and difference from estimated date
SELECT order_id,
       DATE_DIFF(order_delivered_customer_date, order_purchase_timestamp, DAY) AS time_to_deliver,
       DATE_DIFF(order_estimated_delivery_date, order_delivered_customer_date, DAY) AS diff_estimated_delivery
FROM `Target.orders`;

-- 5.2 Top 5 states with highest average freight value
SELECT customer_state, ROUND(AVG(TT.freight_sum), 1) AS avg_freight_val
FROM (
    SELECT O.order_id, C.customer_state,
           ROUND(SUM(F.freight_value), 2) AS freight_sum
    FROM `Target.orders` AS O
    INNER JOIN `Target.customers` AS C ON O.customer_id = C.customer_id
    INNER JOIN `Target.order_items` AS F ON O.order_id = F.order_id
    GROUP BY 1,2
) AS TT
GROUP BY 1
ORDER BY 2 DESC
LIMIT 5;

-- 5.2b Top 5 states with lowest average freight value
SELECT customer_state, ROUND(AVG(TT.freight_sum), 1) AS avg_freight_val
FROM (
    SELECT O.order_id, C.customer_state,
           ROUND(SUM(F.freight_value), 2) AS freight_sum
    FROM `Target.orders` AS O
    INNER JOIN `Target.customers` AS C ON O.customer_id = C.customer_id
    INNER JOIN `Target.order_items` AS F ON O.order_id = F.order_id
    GROUP BY 1,2
) AS TT
GROUP BY 1
ORDER BY 2 ASC
LIMIT 5;

-- 5.3 Top 5 states with the lowest average delivery time
SELECT customer_state, ROUND(AVG(T.time_to_deliver), 1) AS average_delivery_time
FROM (
    SELECT O.order_id, C.customer_state,
           DATE_DIFF(O.order_delivered_customer_date, O.order_purchase_timestamp, DAY) AS time_to_deliver
    FROM `Target.orders` AS O
    INNER JOIN `Target.customers` AS C ON O.customer_id = C.customer_id
) AS T
GROUP BY 1
ORDER BY 2
LIMIT 5;

-- 5.3b Top 5 states with the highest average delivery time
SELECT customer_state, ROUND(AVG(T.time_to_deliver), 1) AS average_delivery_time
FROM (
    SELECT O.order_id, C.customer_state,
           DATE_DIFF(O.order_delivered_customer_date, O.order_purchase_timestamp, DAY) AS time_to_deliver
    FROM `Target.orders` AS O
    INNER JOIN `Target.customers` AS C ON O.customer_id = C.customer_id
) AS T
GROUP BY 1
ORDER BY 2 DESC
LIMIT 5;

-- 5.4 Top 5 states where delivery is faster than estimated
SELECT TT.customer_state,
       ROUND(TT.avg_estimated - TT.avg_actual, 1) AS avg_diff_days
FROM (
    SELECT C.customer_state,
           ROUND(AVG(DATE_DIFF(O.order_delivered_customer_date, O.order_purchase_timestamp, DAY)), 1) AS avg_actual,
           ROUND(AVG(DATE_DIFF(O.order_estimated_delivery_date, O.order_purchase_timestamp, DAY)), 1) AS avg_estimated
    FROM `Target.orders` AS O
    INNER JOIN `Target.customers` AS C ON O.customer_id = C.customer_id
    GROUP BY 1
) AS TT
ORDER BY avg_diff_days DESC
LIMIT 5;


---------------------------------------------------------
-- 6. Payments Analysis
---------------------------------------------------------

-- 6.1 Month-on-month orders by payment type
SELECT payment_type, yearmonth, COUNT(order_id) AS no_of_orders,
       CONCAT(ROUND(((no_of_orders - LAG(no_of_orders) OVER (PARTITION BY payment_type ORDER BY yearmonth)) * 100.0 / 
                     LAG(no_of_orders) OVER (PARTITION BY payment_type ORDER BY yearmonth)), 2), "%") AS growth
FROM (
    SELECT P.payment_type,
           FORMAT_DATE("%Y-%m", O.order_purchase_timestamp) AS yearmonth,
           COUNT(O.order_id) AS no_of_orders
    FROM `Target.orders` AS O
    INNER JOIN `Target.payments` AS P ON O.order_id = P.order_id
    GROUP BY 1,2
) AS T
ORDER BY 1,2;

-- 6.2 Orders by payment installments
SELECT P.payment_installments, COUNT(O.order_id) AS no_of_orders
FROM `Target.orders` AS O
INNER JOIN `Target.payments` AS P ON O.order_id = P.order_id
GROUP BY 1
ORDER BY 1;

-- ======================================================
------------------------ END ----------------------------
-- ======================================================

