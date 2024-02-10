/*
Bike Store Exploration 

Skills used: Joins, Convert Data Types, Partition, Aggregate Functions, CTE's, Temp Tables, Create Views

*/

------------------------------------------------------------------------------------------------------------------
---- 1. Data Cleaning

-- Customers Table
SELECT *
FROM BikeStore..customers
ORDER BY len(customer_id), customer_id

-- Order Items Table
SELECT *
FROM BikeStore..order_items
ORDER BY len(order_id), order_id, item_id

-- Orders Table
SELECT *
FROM BikeStore..orders
ORDER BY len(order_id), order_id

ALTER TABLE BikeStore..orders
ADD OrderDateConverted Date

UPDATE BikeStore..orders
SET OrderDateConverted = CONVERT(Date, order_date)

ALTER TABLE BikeStore..orders
ADD RequiredDateConverted Date

UPDATE BikeStore..orders
SET RequiredDateConverted = CONVERT(Date, required_date)

ALTER TABLE BikeStore..orders
ADD ShippedDateConverted Date

UPDATE BikeStore..orders
SET ShippedDateConverted = CONVERT(Date, shipped_date)

ALTER TABLE BikeStore..orders
DROP COLUMN order_date, required_date, shipped_date

-- Products Table
SELECT *
FROM BikeStore..Products
ORDER BY len(product_id), product_id

-- Staffs Table
SELECT *
FROM BikeStore..Staffs
ORDER BY len(staff_id), staff_id

-- Stocks Table
SELECT *
FROM BikeStore..Stocks
ORDER BY store_id, len(product_id), product_id

------------------------------------------------------------------------------------------------------------------
---- 2. Data Queries

-- How many total customers are in each state?
SELECT COUNT(*) AS CustomerInState, state
FROM BikeStore..customers
GROUP BY state
ORDER BY 1 DESC

-- How many total products have been sold per product and what is the best selling product?
SELECT prod.product_id, prod.product_name, isnull(SUM(ord.quantity), 0) TotalQuantity
FROM BikeStore..products prod
LEFT JOIN BikeStore..order_items ord
ON prod.product_id = ord.product_id
GROUP BY prod.product_id, prod.product_name
ORDER BY TotalQuantity DESC

-- List all orders where final sale price is within $10000 - $20000.
SELECT order_id, ROUND(SUM(quantity * list_price * (1 -discount)), 2) AS Final_Price
FROM BikeStore..order_items
GROUP BY order_id
HAVING ROUND(SUM(quantity * list_price * (1 -discount)), 2) < 20000 
  AND  ROUND(SUM(quantity * list_price * (1 -discount)), 2) > 10000
ORDER BY Final_Price DESC

-- Which category through all the years generated the most revenue, include total units sold and orders.
SELECT 
c.category_id,
c.category_name, 
ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS every_year_total_revenue,
SUM(oi.quantity) AS units_sold,
COUNT(DISTINCT oi.order_id) AS total_orders
FROM BikeStore..order_items oi
LEFT JOIN BikeStore..products p
ON oi.product_id = p.product_id
INNER JOIN BikeStore..categories c
ON p.category_id = c.category_id
GROUP BY c.category_id, c.category_name
ORDER BY every_year_total_revenue DESC

-- Find which staff members have sold the most amount in quantity at each store location.
DROP TABLE IF EXISTS #StaffPerformance
CREATE TABLE #StaffPerformance
(
staff_name nvarchar(255),
staff_id int,
store_id int, 
amount_sold_quantity int
)

INSERT INTO #StaffPerformance
SELECT
sta.first_name + ' ' + sta.last_name staff_name, 
sta.staff_id, 
sta.store_id, 
COUNT(ord.order_id) AS amount_sold_quantity
FROM BikeStore..orders ord
LEFT JOIN BikeStore..staffs sta
ON ord.staff_id = sta.staff_id
GROUP BY sta.staff_id, sta.store_id, sta.first_name + ' ' + sta.last_name
ORDER BY amount_sold_quantity

WITH RankedSales AS 
(
SELECT
    store_id,
    staff_name,
    amount_sold_quantity,
    ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY amount_sold_quantity DESC) AS rn
FROM #StaffPerformance
)
SELECT store_id, staff_name, amount_sold_quantity
FROM RankedSales
WHERE rn = 1;

-- What month generated the most revenue?
WITH monthly_sold_quantity AS 
(
SELECT YEAR(OrderDateConverted) AS year,
        MONTH(OrderDateConverted) AS month,
        product_id,
        SUM(quantity) AS units_sold,
		discount
FROM BikeStore..orders o
INNER JOIN BikeStore..order_items oi
ON o.order_id = oi.order_id
GROUP BY YEAR(OrderDateConverted), MONTH(OrderDateConverted), product_id, discount
)

SELECT year, month, ROUND(SUM(units_sold * list_price * (1 - discount)), 2) AS total_month_revenue
FROM monthly_sold_quantity msq
LEFT JOIN BikeStore..products p
ON msq.product_id = p.product_id
GROUP BY year, month
ORDER BY year, month

-- Create View for potential visualizations
CREATE VIEW CategoryRevenue AS
SELECT 
c.category_id,
c.category_name, 
ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS every_year_total_revenue,
SUM(oi.quantity) AS units_sold,
COUNT(DISTINCT oi.order_id) AS total_orders
FROM BikeStore..order_items oi
LEFT JOIN BikeStore..products p
ON oi.product_id = p.product_id
INNER JOIN BikeStore..categories c
ON p.category_id = c.category_id
GROUP BY c.category_id, c.category_name
