/*
Faaso Company Exploratory Data Analysis (EDA)

Skills used: CTE, Sub-Squery, Window Functions, Joins, Aggregate Functions, Data Cleaning, Converting Data Types

*/ /* Roll Metrics */ -- How many Rolls were ordered?

SELECT COUNT(roll_id) AS NumberOfRollsOrdered
FROM CustomerOrders 

-- How many unique customer orders were made?

SELECT COUNT(DISTINCT customer_id) AS NumberOfCustomers
FROM CustomerOrders 

-- How many successful orders were delivered by each of the drivers?

SELECT driver_id,
       COUNT(DISTINCT order_id) AS Orders
FROM DriverOrder
WHERE cancellation NOT IN ('Cancellation',
                           'Customer Cancellation')
GROUP BY driver_id 

-- How many of each type of Roll was delivered?

SELECT roll_id,
       COUNT(roll_id) NumberOfOrders
FROM CustomerOrders
WHERE order_id IN
    (SELECT order_id
     FROM
       (SELECT *,
               CASE
                   WHEN cancellation IN ('Cancellation',
                                         'Customer Cancellation') THEN 'Cancelled'
                   ELSE 'Not Cancelled'
               END AS OrderStatus
        FROM DriverOrder) A
     WHERE OrderStatus = 'Not Cancelled' )
GROUP BY roll_id 

-- How many Vegetable and Non Vegetable Rolls were ordered by each customer?

SELECT A.*,
       roll_name
FROM
  (SELECT customer_id,
          roll_id,
          COUNT(roll_id) AS Cnt
   FROM CustomerOrders
   GROUP BY customer_id,
            roll_id) A
JOIN Rolls B ON A.roll_id = B.roll_id 

-- What was the highest number of Rolls delivered in a single order?

SELECT *
FROM
  (SELECT *,
          RANK() OVER (
                       ORDER BY Cnt DESC) AS Rnk
   FROM
     (SELECT order_id,
             COUNT(roll_id) Cnt
      FROM
        (SELECT *
         FROM CustomerOrders
         WHERE order_id IN
             (SELECT order_id
              FROM
                (SELECT *,
                        CASE
                            WHEN cancellation IN ('Cancellation',
                                                  'Customer Cancellation') THEN 'Cancelled'
                            ELSE 'Not Cancelled'
                        END AS OrderStatus
                 FROM DriverOrder) A
              WHERE OrderStatus = 'Not Cancelled' ) ) B
      GROUP BY order_id) C) D
WHERE Rnk = 1 

-- For each customer, how many delivered Roll had atleast one change and how many had no changes?

 WITH CustomerOrdersCTE (order_id, customer_id, roll_id, not_include_items, extra_items_included, order_date) AS
    (SELECT order_id,
            customer_id,
            roll_id,
            CASE
                WHEN not_include_items IS NULL
                     OR not_include_items = ' ' THEN '0'
                ELSE not_include_items
            END AS new_not_include_items,
            CASE
                WHEN extra_items_included IS NULL
                     OR extra_items_included = ' '
                     OR extra_items_included = 'NaN' THEN '0'
                ELSE extra_items_included
            END AS new_extra_items_included,
            order_date
     FROM CustomerOrders) -------------------
,
      DriverOrdersCTE (order_id, driver_id, pickup_time, distance, duration, new_cancellation) AS
    (SELECT order_id,
            driver_id,
            pickup_time,
            distance,
            duration,
            CASE
                WHEN cancellation IN ('Cancellation',
                                      'Customer Cancellation') THEN 0
                ELSE 1
            END AS new_cancellation
     FROM DriverOrder)
  SELECT customer_id,
         ChangeOrNoChange,
         COUNT(order_id) AS Orders
  FROM
    (SELECT *,
            CASE
                WHEN not_include_items = '0'
                     AND extra_items_included = '0' THEN 'No change'
                ELSE 'Change'
            END AS ChangeOrNoChange
     FROM CustomerOrdersCTE
     WHERE order_id IN
         (SELECT order_id
          FROM DriverOrdersCTE
          WHERE new_cancellation != 0 ) ) A
GROUP BY customer_id,
         ChangeOrNoChange 
		 
-- How any Rolls were delivered that had both exclusions and extras?

 WITH CustomerOrdersCTE (order_id, customer_id, roll_id, not_include_items, extra_items_included, order_date) AS
  (SELECT order_id,
          customer_id,
          roll_id,
          CASE
              WHEN not_include_items IS NULL
                   OR not_include_items = ' ' THEN '0'
              ELSE not_include_items
          END AS new_not_include_items,
          CASE
              WHEN extra_items_included IS NULL
                   OR extra_items_included = ' '
                   OR extra_items_included = 'NaN' THEN '0'
              ELSE extra_items_included
          END AS new_extra_items_included,
          order_date
   FROM CustomerOrders) ----------
,
      DriverOrdersCTE (order_id, driver_id, pickup_time, distance, duration, new_cancellation) AS
  (SELECT order_id,
          driver_id,
          pickup_time,
          distance,
          duration,
          CASE
              WHEN cancellation IN ('Cancellation',
                                    'Customer Cancellation') THEN 0
              ELSE 1
          END AS new_cancellation
   FROM DriverOrder)
SELECT ChangeOrNoChange,
       COUNT(ChangeOrNoChange) AS Cnt
FROM
  (SELECT *,
          CASE
              WHEN not_include_items != '0'
                   AND extra_items_included != '0' THEN 'Both Inc Exc'
              ELSE 'Either 1 Inc or Exc'
          END AS ChangeOrNoChange
   FROM CustomerOrdersCTE
   WHERE order_id IN
       (SELECT order_id
        FROM DriverOrdersCTE
        WHERE new_cancellation != 0 ) ) A
GROUP BY ChangeOrNoChange 

-- What is the total number of Rolls ordered in each hour of the day?

SELECT hours_interval,
       COUNT(hours_interval) AS NumberOfRolls
FROM
  (SELECT *,
          CONCAT(CAST(DATEPART(HOUR, order_date) AS VARCHAR), '-', CAST(DATEPART(HOUR, order_date) + 1 AS VARCHAR)) AS hours_interval
   FROM CustomerOrders) A
GROUP BY hours_interval 

-- What is the number of orders for each day of the week?

SELECT DOW,
       COUNT(DISTINCT order_id) TotalOrders
FROM
  (SELECT *,
          DATENAME(DW, order_date) AS DOW
   FROM CustomerOrders) A
GROUP BY DOW 

/* Driver and Customer Experience */ 

-- What was the average time in minutes it took for each driver to arrive at the Faaso's Head Quarters to pick up the order?
 
SELECT driver_id, 
       SUM(MinutesDiff)/ COUNT(order_id) AS AveragePickupTime
FROM 
  (SELECT *
   FROM 
     (SELECT *, 
             ROW_NUMBER() OVER (PARTITION BY order_id
                                ORDER BY MinutesDiff) rnk
      FROM 
        (SELECT A.order_id, 
                A.customer_id, 
                A.roll_id, 
                A.not_include_items, 
                A.extra_items_included, 
                A.order_date, 
                B.driver_id, 
                B.pickup_time, 
                B.distance, 
                B.duration, 
                B.cancellation, 
                DATEDIFF(MINUTE, A.order_date, B.pickup_time) AS MinutesDiff
         FROM CustomerOrders A
         JOIN DriverOrder B ON A.order_id = B.order_id 
         WHERE B.pickup_time IS NOT NULL ) A) B 
   WHERE rnk = 1 ) C
GROUP BY driver_id 

-- Is there any relatioship between the number of Rolls and how long the order takes to prepare?
 
SELECT order_id, 
       COUNT(roll_id) AS Rolls, 
       SUM(MinutesDiff)/ COUNT(roll_id) AS TimeToPrepare
FROM 
  (SELECT A.order_id, 
          A.customer_id, 
          A.roll_id, 
          A.not_include_items, 
          A.extra_items_included, 
          A.order_date, 
          B.driver_id, 
          B.pickup_time, 
          B.distance, 
          B.duration, 
          B.cancellation, 
          DATEDIFF(MINUTE, A.order_date, B.pickup_time) AS MinutesDiff
   FROM CustomerOrders A
   JOIN DriverOrder B ON A.order_id = B.order_id 
   WHERE B.pickup_time IS NOT NULL ) A
GROUP BY order_id 

-- What is the average distance travelled for each customer that placed an order?
 
SELECT customer_id, 
       SUM(newdistance)/ COUNT(order_id) AS AvgDistance
FROM 
  (SELECT * 
   FROM 
     (SELECT *, 
             ROW_NUMBER() OVER (PARTITION BY order_id
                                ORDER BY MinutesDiff) AS RowNum 
      FROM 
        (SELECT A.order_id, 
                A.customer_id, 
                A.roll_id, 
                A.not_include_items, 
                A.extra_items_included, 
                A.order_date, 
                B.driver_id, 
                B.pickup_time, 
                CONVERT(FLOAT, TRIM(REPLACE(LOWER(B.distance), 'km', ' '))) AS newdistance, 
                B.duration, 
                B.cancellation, 
                DATEDIFF(MINUTE, A.order_date, B.pickup_time) AS MinutesDiff
         FROM CustomerOrders A
         JOIN DriverOrder B ON A.order_id = B.order_id 
         WHERE B.pickup_time IS NOT NULL ) A) B 
   WHERE RowNum = 1 ) C
GROUP BY customer_id 

-- What is the difference between the longest and the shortest delivery times for all the orders? 
 
SELECT MAX(newduration) - MIN(newduration) AS TimeDifference
FROM 
  (SELECT CAST(CASE 
                   WHEN duration LIKE '%min%' THEN LEFT(duration, CHARINDEX('m', duration) - 1) 
                   ELSE duration 
               END AS int) AS newduration
   FROM DriverOrder 
   WHERE duration IS NOT NULL ) A 
   
-- What was the average speed for each driver per delivery? Is there a trend in these values?
 
SELECT A.order_id, 
       A.driver_id, 
       A.newdistance/ A.newduration AS speed, 
       B.Cnt
FROM 
  (SELECT order_id, 
          driver_id, 
          CONVERT(FLOAT, TRIM(REPLACE(LOWER(distance), 'km', ' '))) AS newdistance, 
          CAST(CASE 
                   WHEN duration LIKE '%min%' THEN LEFT(duration, CHARINDEX('m', duration) - 1) 
                   ELSE duration 
               END AS int) AS newduration
   FROM DriverOrder 
   WHERE distance IS NOT NULL ) A
JOIN 
  (SELECT order_id, 
          COUNT(roll_id) AS Cnt
   FROM CustomerOrders
   GROUP BY order_id) B ON A.order_id = B.order_id 
   
-- What is the successful delivery percentage for each driver?
 
SELECT driver_id, 
       (SuccessfullyDeliveredOrders*1.0/ Pickups)*100 AS SuccessPercentage
FROM 
  (SELECT driver_id, 
          SUM(cancellIndicator) AS SuccessfullyDeliveredOrders, 
          COUNT(driver_id) AS Pickups
   FROM 
     (SELECT driver_id, 
             CASE 
                 WHEN LOWER(cancellation) LIKE '%cancell%' THEN 0
                 ELSE 1
             END AS cancellIndicator
      FROM DriverOrder) A
   GROUP BY driver_id) B