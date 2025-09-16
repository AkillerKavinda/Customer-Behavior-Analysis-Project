-- 1. What is the total amount each customer spent at the restaurant?

select s.customer_id, sum(m.price) as tot_amount_spent
from sales s
left join menu m
using(product_id)
group by s.customer_id;	

-- 2. How many days has each customer visited the restaurant?

select customer_id, count(distinct order_date) as days_visited
from sales
group by customer_id;


-- 3. What was the first item from the menu purchased by each customer?

with firstItem as (select *, rank() over(partition by customer_id order by order_date) as rn
from sales s
left join menu m
using(product_id)
)

select customer_id, product_name as firstItem from firstItem
where rn = 1;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?

select * from sales;

with bestitem as(
select product_id, count(product_id) as count
from sales s
group by product_id
order by count desc
limit 1)

select distinct s.product_id, product_name from menu
left join sales s
using(product_id)
where product_id in (select product_id from bestitem);

select  m.product_name, count(*) count
from sales s
left join menu m
using(product_id)
group by m.product_name
order by count desc
limit 1;

-- 5. Which item was the most popular for each customer?

select * from sales;

select customer_id, product_id, count(*) as count
from sales
group by customer_id, product_id
order by customer_id, count desc;

with customer_popularity as (select s.customer_id, m.product_name, count(*) as purchase_count, 
dense_rank() over(partition by s.customer_id order by count(*) desc) as rk
from sales s
join menu m
on s.product_id = m.product_id
group by s.customer_id, m.product_name)

select * from customer_popularity
where rk = 1;

-- step 1

select *,
       dense_rank() over (partition by customer_id order by purchase_count desc) as rk
from (
    select 
        s.customer_id,
        m.product_name,
        count(*) as purchase_count
    from sales s
    join menu m 
        on s.product_id = m.product_id
    group by s.customer_id, m.product_name
) t;

-- step 2 

select *
from (
    select *,
           dense_rank() over (partition by customer_id order by purchase_count desc) as rk
    from (
        select 
            s.customer_id,
            m.product_name,
            count(*) as purchase_count
        from sales s
        join menu m 
            on s.product_id = m.product_id
        group by s.customer_id, m.product_name
    ) t
) t2
where rk = 1;

-- 6. Which item was purchased first by the customer after they became a member?
select * from members;

select * from sales;

with cte as (
select s.customer_id, s.product_id, order_date, row_number() over(partition by customer_id order by order_date) as rk
from sales s
where order_date >= (select join_date from members m
						where m.customer_id = s.customer_id)
)

select customer_id, order_date, product_id, product_name from cte
left join menu 
using(product_id)
where rk  = 1;

-- 7. Which item was purchased just before the customer became a member?

with cte as (
select s.customer_id, s.product_id, order_date, dense_rank() over(partition by customer_id order by order_date desc) as rk
from sales s
where order_date < (select join_date from members m
						where m.customer_id = s.customer_id)
)

select customer_id, order_date, product_id, product_name from cte
left join menu 
using(product_id)
where rk  = 1;


-- 8. What is the total items and amount spent for each member before they became a member?

select * from sales;
select * from members;

select s.customer_id, count(s.product_id) num_of_products_bought, sum(m.price) total_price_spent
from sales s
inner join menu m
using(product_id)
where s.order_date < (select join_date from members m where s.customer_id = m.customer_id)
group by customer_id;

-- 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

select * from sales;
select * from menu;

select  s.customer_id, sum(
	case 
		when m.product_name = 'sushi' then price * 20 else price * 10 
	end) as points
from sales s
join menu m
using(product_id)
group by s.customer_id;



/* 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - 
how many points do customer A and B have at the end of January?*/

select * from sales;
select * from members;


select *
from members m
left join sales
using(customer_id);

select m.customer_id, 
	sum(case
		when s.order_date >= m.join_date  and s.order_date <= date_add(m.join_date, interval 7 day) then mn.price * 20
        when mn.product_name = 'sushi' then price * 20
        else mn.price * 10
	end) as points_after_joining
from members m
left join sales s
using(customer_id)
inner join menu mn
on s.product_id = mn.product_id
where s.order_date <= '2021-01-31'
group by m.customer_id;

-- 11. Danny needs you to create basic data tables that his team can use to gain insights without needing to write SQL. 
-- Recreate the table output using the following columns - customer_id, order_date, product_name, member
--  Member should say if the customer is a member at the time of purchase. 
-- Denote the member by y or n.

select s.customer_id, s.order_date, m.product_name, m.price, 
	case
		when s.customer_id in (select customer_id from members) and s.order_date >= mn.join_date then 'y' else 'n'
	end as 	member
from sales s
left join menu m
on s.product_id = m.product_id
left join members mn
on s.customer_id = mn.customer_id
order by s.customer_id, s.order_date;

-- 12. Danny requires further information about the ranking of products. He purosely does not need the ranking of non member purchases 
-- so he expects NULL ranking values for customers who are not yet part of the loyalty program. 
-- Include the columns customer_id, order_date, product_name, price, member, ranking where ranking says the rank of the purchase. 

with cte as (select s.customer_id, s.order_date, m.product_name, m.price, 
	case
		when s.customer_id in (select customer_id from members) and s.order_date >= mn.join_date then 'y' else 'n'
	end as 	member
from sales s
left join menu m
on s.product_id = m.product_id
left join members mn
on s.customer_id = mn.customer_id
order by s.customer_id, s.order_date)

select * ,
    case 
		when member = 'n' then null
		when member = 'y' then rank() over(partition by customer_id, member order by order_date) 
	end as ranking
from cte;
