-- Table schema from https://8weeksqlchallenge.com/case-study-1/
CREATE SCHEMA dannys_diner;
SET search_path = dannys_diner;

CREATE TABLE sales (
  "customer_id" VARCHAR(1),
  "order_date" DATE,
  "product_id" INTEGER
);

INSERT INTO sales
  ("customer_id", "order_date", "product_id")
VALUES
  ('A', '2021-01-01', '1'),
  ('A', '2021-01-01', '2'),
  ('A', '2021-01-07', '2'),
  ('A', '2021-01-10', '3'),
  ('A', '2021-01-11', '3'),
  ('A', '2021-01-11', '3'),
  ('B', '2021-01-01', '2'),
  ('B', '2021-01-02', '2'),
  ('B', '2021-01-04', '1'),
  ('B', '2021-01-11', '1'),
  ('B', '2021-01-16', '3'),
  ('B', '2021-02-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-07', '3');
 

CREATE TABLE menu (
  "product_id" INTEGER,
  "product_name" VARCHAR(5),
  "price" INTEGER
);

INSERT INTO menu
  ("product_id", "product_name", "price")
VALUES
  ('1', 'sushi', '10'),
  ('2', 'curry', '15'),
  ('3', 'ramen', '12');
  

CREATE TABLE members (
  "customer_id" VARCHAR(1),
  "join_date" DATE
);

INSERT INTO members
  ("customer_id", "join_date")
VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');


-- 1. What is the total amount each customer spent at the restaurant? 
SELECT
	customer_id,
    SUM(price) as total_spent
FROM dannys_diner.sales s
LEFT JOIN dannys_diner.menu m
USING(product_id)
GROUP BY customer_id
ORDER BY customer_id;

-- 2. How many days has each customer visited the restaurant?
SELECT 
	customer_id,
    COUNT(DISTINCT order_date) as cnt_days
FROM dannys_diner.sales
GROUP BY customer_id;

-- 3. What was the first item from the menu purchased by each customer?
WITH fpd as (
    SELECT 
	customer_id,
    MIN(order_date) as first_purchase_date
    FROM dannys_diner.sales
    GROUP BY customer_id
    )
SELECT s.customer_id, m.product_name as first_item_purchased
FROM dannys_diner.sales s
JOIN dannys_diner.menu m
USING(product_id)
JOIN fpd
ON s.order_date=fpd.first_purchase_date AND s.customer_id=fpd.customer_id
ORDER BY s.customer_id;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
WITH mpi_id as  (
    SELECT id
    FROM (
    SELECT 
        product_id as id,
        COUNT(*) as cnt
    FROM dannys_diner.sales
    GROUP BY product_id
    ORDER BY cnt desc
    LIMIT 1) as mpi
) 
SELECT
    customer_id,
    COUNT(*)
FROM dannys_diner.sales
WHERE product_id in (SELECT * FROM mpi_id)
GROUP BY customer_id;

-- 5. Which item was the most popular for each customer?
WITH orders_ranked as (
    SELECT 
        customer_id,
        product_name,
        COUNT(*) as cnt_orders,
        RANK() OVER(PARTITION BY customer_id ORDER BY COUNT(*) DESC) as rank
    FROM dannys_diner.sales
    LEFT JOIN dannys_diner.menu
    USING(product_id)
    GROUP BY customer_id, product_name
    ORDER BY customer_id
)
SELECT
    customer_id,
    product_name
FROM orders_ranked
WHERE orders_ranked.rank = 1;

-- 6. Which item was purchased first by the customer after they became a member?
WITH sales_combined as (
    SELECT *
    FROM dannys_diner.sales
    LEFT JOIN dannys_diner.members
    USING(customer_id)
    LEFT JOIN dannys_diner.menu
    USING(product_id)
)
SELECT 
    customer_id,
    product_name
FROM sales_combined
WHERE (customer_id, order_date) in (
        SELECT
            customer_id,
            MIN(order_date)
        FROM sales_combined
        WHERE order_date >= join_date
        GROUP BY customer_id
        );


-- 7. Which item was purchased just before the customer became a member?
WITH sales_combined as (
    SELECT *
    FROM dannys_diner.sales
    LEFT JOIN dannys_diner.members
    USING(customer_id)
    LEFT JOIN dannys_diner.menu
    USING(product_id)
)
SELECT 
    customer_id,
    product_name
FROM sales_combined
WHERE (customer_id, order_date) in (
        SELECT
            customer_id,
            MAX(order_date)
        FROM sales_combined
        WHERE order_date < join_date
        GROUP BY customer_id
        );

-- 8. What is the total items and amount spent for each member before they became a member?
WITH sales_combined as (
    SELECT *
    FROM dannys_diner.sales
    LEFT JOIN dannys_diner.members
    USING(customer_id)
    LEFT JOIN dannys_diner.menu
    USING(product_id)
)
SELECT 
    customer_id,
    COUNT(*),
    SUM(price)
FROM sales_combined
WHERE order_date > join_date
GROUP BY customer_id
ORDER BY customer_id;

-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have? 
WITH sales_combined as (
    SELECT *
    FROM dannys_diner.sales
    LEFT JOIN dannys_diner.members
    USING(customer_id)
    LEFT JOIN dannys_diner.menu
    USING(product_id)
)
SELECT
    customer_id,
    SUM(CASE WHEN product_name='sushi' THEN price * 20
    ELSE price * 10 END) as points
FROM sales_combined
GROUP BY customer_id
ORDER BY customer_id;

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items,
--     not just sushi - how many points do customer A and B have at the end of January?
WITH sales_combined as (
    SELECT *
    FROM dannys_diner.sales
    LEFT JOIN dannys_diner.members
    USING(customer_id)
    LEFT JOIN dannys_diner.menu
    USING(product_id)
)
SELECT
    customer_id,
    SUM(CASE
        WHEN order_date <= join_date + INTERVAL '6 DAY' OR product_name = 'sushi' THEN price * 20
        ELSE price * 10 END) as points
FROM sales_combined
WHERE order_date BETWEEN join_date AND '2021-01-31'
GROUP BY customer_id
ORDER BY customer_id;


-- Proof for question 10
WITH sales_combined as (
    SELECT *
    FROM dannys_diner.sales
    LEFT JOIN dannys_diner.members
    USING(customer_id)
    LEFT JOIN dannys_diner.menu
    USING(product_id)
),
    points_table as (
    SELECT
        customer_id,
        product_name,
        price,
        order_date,
        join_date,
        CASE WHEN order_date <= join_date + INTERVAL '6 DAY' THEN 'Y' ELSE 'N' END AS first_week_order,
        CASE WHEN order_date <= join_date + INTERVAL '6 DAY' OR product_name = 'sushi' THEN 20 ELSE 10 END AS points
FROM sales_combined
WHERE order_date BETWEEN join_date AND '2021-01-31'
ORDER BY customer_id
    )
SELECT
    customer_id,
    SUM(points2) as points 
FROM (
    SELECT
        customer_id,
        product_name,
        price,
        first_week_order,
        points,
        price * points as points2
    FROM points_table) as t
GROUP BY customer_id;

-- Bonus question 1 – Join All The Things
WITH sales_combined as (
    SELECT *
    FROM dannys_diner.sales
    LEFT JOIN dannys_diner.members
    USING(customer_id)
    LEFT JOIN dannys_diner.menu
    USING(product_id)
)

SELECT
    customer_id,
    order_date,
    product_name,
    price,
    CASE WHEN order_date < join_date THEN 'N' ELSE 'Y' END AS member
FROM sales_combined
ORDER BY customer_id, order_date, product_name;

-- Bonus question 2 – Rank All The Things (no info what to rank or what to rank by)
WITH sales_combined as (
    SELECT *
    FROM dannys_diner.sales
    LEFT JOIN dannys_diner.members
    USING(customer_id)
    LEFT JOIN dannys_diner.menu
    USING(product_id)
)

SELECT
    customer_id,
    order_date,
    product_name,
    price,
    CASE WHEN order_date < join_date THEN 'N' ELSE 'Y' END AS member,

FROM sales_combined
ORDER BY customer_id, order_date, product_name;
