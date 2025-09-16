# Danny's Diner Loyalty Program Analysis

## Introduction

Danny is a passionate fan of Japanese cuisine. In December 2021, he opened a restaurant serving his three favorite dishes: sushi, curry, and ramen.

As the business grew, Danny began collecting customer data to better understand purchasing behavior and improve the dining experience. He also launched a loyalty program to reward repeat customers.

## Problem Statement

Danny has access to customer data but lacks the analytical tools to extract meaningful insights. He seeks answers to the following questions:

1. What is the total amount each customer spent at the restaurant?  
2. How many days has each customer visited the restaurant?  
3. What was the first item from the menu purchased by each customer?  
4. What is the most purchased item on the menu and how many times was it purchased by all customers?  
5. Which item was the most popular for each customer?  
6. Which item was purchased first by the customer after they became a member?  
7. Which item was purchased just before the customer became a member?  
8. What is the total items and amount spent for each member before they became a member?  
9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier, how many points would each customer have?  
10. In the first week after a customer joins the program (including their join date), they earn 2x points on all items. How many points do customer A and B have at the end of January?  
11. Create a table with customer_id, order_date, product_name, member (y/n) to show membership status at time of purchase.  
12. Add ranking of purchases for members only. Non-members should have NULL ranking.

## Dataset Overview

The database consists of three tables:

### sales
| Column      | Type       | Description                  |
|-------------|------------|------------------------------|
| customer_id | VARCHAR(1) | Unique ID for each customer  |
| order_date  | DATE       | Date of the order            |
| product_id  | INTEGER    | ID of the ordered product    |

### members
| Column      | Type       | Description                        |
|-------------|------------|------------------------------------|
| customer_id | VARCHAR(1) | Unique ID for each customer        |
| join_date   | TIMESTAMP  | Date the customer joined loyalty   |

### menu
| Column       | Type       | Description                  |
|--------------|------------|------------------------------|
| product_id   | INTEGER    | Unique ID for each menu item |
| product_name | VARCHAR(5) | Name of the menu item        |
| price        | INTEGER    | Price of the item            |

## Resources

- **Dataset:** [customer-behavior-dataset.sql](https://github.com/AkillerKavinda/customer-behavior-dataset.sql)  
- **SQL Analysis File:** [customer-behavior-analysis.sql](https://github.com/AkillerKavinda/customer-behavior-analysis.sql)  
- **Query Results:** [Query-Results](https://github.com/AkillerKavinda/Query-Results)  

## SQL Analysis

-- 1. What is the total amount each customer spent at the restaurant?
```sql
SELECT s.customer_id, SUM(m.price) AS tot_amount_spent
FROM sales s
LEFT JOIN menu m USING(product_id)
GROUP BY s.customer_id;
```

-- 2. How many days has each customer visited the restaurant?
```sql
SELECT customer_id, COUNT(DISTINCT order_date) AS days_visited
FROM sales
GROUP BY customer_id;
```

-- 3. What was the first item from the menu purchased by each customer?
```sql
WITH firstItem AS (
  SELECT *, RANK() OVER(PARTITION BY customer_id ORDER BY order_date) AS rn
  FROM sales s
  LEFT JOIN menu m USING(product_id)
)
SELECT customer_id, product_name AS firstItem
FROM firstItem
WHERE rn = 1;
```

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
```sql
WITH bestitem AS (
  SELECT product_id, COUNT(product_id) AS count
  FROM sales
  GROUP BY product_id
  ORDER BY count DESC
  LIMIT 1
)
SELECT DISTINCT s.product_id, product_name
FROM menu
LEFT JOIN sales s USING(product_id)
WHERE product_id IN (SELECT product_id FROM bestitem);
```

-- Alternative version:
```sql
SELECT m.product_name, COUNT(*) AS count
FROM sales s
LEFT JOIN menu m USING(product_id)
GROUP BY m.product_name
ORDER BY count DESC
LIMIT 1;
```

-- 5. Which item was the most popular for each customer?
```sql
WITH customer_popularity AS (
  SELECT s.customer_id, m.product_name, COUNT(*) AS purchase_count,
         DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY COUNT(*) DESC) AS rk
  FROM sales s
  JOIN menu m ON s.product_id = m.product_id
  GROUP BY s.customer_id, m.product_name
)
SELECT * FROM customer_popularity
WHERE rk = 1;
```

-- 6. Which item was purchased first by the customer after they became a member?
```sql
WITH cte AS (
  SELECT s.customer_id, s.product_id, order_date,
         ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY order_date) AS rk
  FROM sales s
  WHERE order_date >= (
    SELECT join_date FROM members m WHERE m.customer_id = s.customer_id
  )
)
SELECT customer_id, order_date, product_id, product_name
FROM cte
LEFT JOIN menu USING(product_id)
WHERE rk = 1;
```

-- 7. Which item was purchased just before the customer became a member?
```sql
WITH cte AS (
  SELECT s.customer_id, s.product_id, order_date,
         DENSE_RANK() OVER(PARTITION BY customer_id ORDER BY order_date DESC) AS rk
  FROM sales s
  WHERE order_date < (
    SELECT join_date FROM members m WHERE m.customer_id = s.customer_id
  )
)
SELECT customer_id, order_date, product_id, product_name
FROM cte
LEFT JOIN menu USING(product_id)
WHERE rk = 1;
```

-- 8. What is the total items and amount spent for each member before they became a member?
```sql
SELECT s.customer_id,
       COUNT(s.product_id) AS num_of_products_bought,
       SUM(m.price) AS total_price_spent
FROM sales s
INNER JOIN menu m USING(product_id)
WHERE s.order_date < (
  SELECT join_date FROM members m WHERE s.customer_id = m.customer_id
)
GROUP BY customer_id;
```

-- 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier, how many points would each customer have?
```sql
SELECT s.customer_id,
       SUM(CASE
             WHEN m.product_name = 'sushi' THEN price * 20
             ELSE price * 10
           END) AS points
FROM sales s
JOIN menu m USING(product_id)
GROUP BY s.customer_id;
```

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items.
-- How many points do customer A and B have at the end of January?
```sql
SELECT m.customer_id,
       SUM(CASE
             WHEN s.order_date >= m.join_date AND s.order_date <= DATE_ADD(m.join_date, INTERVAL 7 DAY) THEN mn.price * 20
             WHEN mn.product_name = 'sushi' THEN price * 20
             ELSE mn.price * 10
           END) AS points_after_joining
FROM members m
LEFT JOIN sales s USING(customer_id)
INNER JOIN menu mn ON s.product_id = mn.product_id
WHERE s.order_date <= '2021-01-31'
GROUP BY m.customer_id;
```

-- 11. Create a table with customer_id, order_date, product_name, member (y/n) to show membership status at time of purchase.
```sql
SELECT s.customer_id, s.order_date, m.product_name, m.price,
       CASE
         WHEN s.customer_id IN (SELECT customer_id FROM members) AND s.order_date >= mn.join_date THEN 'y'
         ELSE 'n'
       END AS member
FROM sales s
LEFT JOIN menu m ON s.product_id = m.product_id
LEFT JOIN members mn ON s.customer_id = mn.customer_id
ORDER BY s.customer_id, s.order_date;
```

-- 12. Danny requires further information about the ranking of products.
-- He does not need the ranking of non-member purchases, so expects NULL ranking values for customers who are not yet part of the loyalty program.
```sql
WITH cte AS (
  SELECT s.customer_id, s.order_date, m.product_name, m.price,
         CASE
           WHEN s.customer_id IN (SELECT customer_id FROM members) AND s.order_date >= mn.join_date THEN 'y'
           ELSE 'n'
         END AS member
  FROM sales s
  LEFT JOIN menu m ON s.product_id = m.product_id
  LEFT JOIN members mn ON s.customer_id = mn.customer_id
  ORDER BY s.customer_id, s.order_date
)
SELECT *,
       CASE
         WHEN member = 'n' THEN NULL
         WHEN member = 'y' THEN RANK() OVER(PARTITION BY customer_id, member ORDER BY order_date)
       END AS ranking
FROM cte;
```
## Summary of Findings

1. **Total Amount Spent:**  
   - Customer A: 76  
   - Customer B: 74  
   - Customer C: 36  

2. **Number of Days Visited:**  
   - Customer A: 4 days  
   - Customer B: 6 days  
   - Customer C: 2 days  

3. **First Item Purchased:**  
   - Customer A: Sushi and Curry  
   - Customer B: Curry  
   - Customer C: Ramen  

4. **Most Purchased Item Overall:**  
   - Ramen (purchased 8 times)  

5. **Most Popular Item per Customer:**  
   - Customer A: Ramen  
   - Customer B: Curry, Sushi, and Ramen  
   - Customer C: Ramen  

6. **First Item Purchased After Becoming a Member:**  
   - Customer A: Curry  
   - Customer B: Sushi  

7. **Item Purchased Just Before Becoming a Member:**  
   - Customer A: Sushi and Curry  
   - Customer B: Sushi  

8. **Total Items and Amount Spent Before Membership:**  
   - Customer A: 2 products, spent 25  
   - Customer B: 2 products, spent 40  

9. **Points Earned (10 points per $1, sushi 2x multiplier):**  
   - Customer A: 860 points  
   - Customer B: 940 points  
   - Customer C: 360 points  

10. **Points Earned in First Week After Joining (2x points for all items):**  
    - Customer A: 1370 points  
    - Customer B: 940 points  

11. **Membership Status Table (Q11):**  
    - [Q11 Table](https://github.com/AkillerKavinda/Customer-Behavior-Analysis-Project/blob/main/Query-Results/Q11.csv)  

12. **Purchase Ranking Table for Members (Q12):**  
    - [Q12 Table](https://github.com/AkillerKavinda/Customer-Behavior-Analysis-Project/blob/main/Query-Results/Q12.csv)  


