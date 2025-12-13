----------------------------------------1-----------------------------------------
-- Q1
with shipper_usage as (
    select  o.ship_country as country,o.ship_via as shipper_id,count(*) as used_count
    from orders o
    where o.ship_via is not null
    group by o.ship_country, o.ship_via
),
ranked_shippers as (
    select country,shipper_id,used_count,RANK() OVER (partition by country order by used_count desc) as rnk
    from shipper_usage
)
select country,shipper_id,used_count
from ranked_shippers
where rnk = 1
order by used_count desc;

--or
with icu(shipper_id,country,used_count) as(
  select o.ship_via ,o.ship_country,count(distinct o.order_id)
  from orders o
  group by o.ship_country,o.ship_via)

select i.country,shipper_id,i.used_count
from icu,(
  select country,max(used_count) as used_count
  from icu
  group by country) as i
where icu.used_count=i.used_count and icu.country=i.country
order by used_count desc;


-- Q2
with order_item(order_is,country,items) as(
  select o.order_id,o.ship_country,sum(od.quantity) 
  from order_details od,orders o
  where o.order_id=od.order_id
  group by o.order_id,o.ship_country
)

select country,avg(items) as avg_items
from order_item 
group by country
having avg(items)>10
order by avg_items desc;


-- Q3
with pcr(product_id,country,revenue_c) as(
  select od.product_id,o.ship_country,sum((1-od.discount)*od.quantity*od.unit_price)
  from order_details od , orders o
  where  o.order_id = od.order_id
  group by o.ship_country,od.product_id
)
select p.country,product_id,p.revenue
from pcr,(
  select country,max(revenue_c) as revenue
  from pcr
  group by country) as p
where pcr.revenue_c=p.revenue and pcr.country=p.country
order by revenue desc;
--or
with product_revenue as (
    select o.ship_country as country,od.product_id,sum(od.unit_price * od.quantity * (1 - od.discount)) as revenue
    from orders o
    join order_details od on o.order_id = od.order_id
    group by o.ship_country, od.product_id
),
ranked_products as (
    select country,product_id,revenue,
        ROW_NUMBER() OVER (partition by country order by revenue desc) as rnk
    from product_revenue
)
select country,product_id,revenue
from ranked_products
where rnk = 1
order by revenue desc;


--Q4
select o.ship_country as country,o.employee_id,avg(o.shipped_date - o.order_date) as avg_days
from orders o
where o.shipped_date is not null
group by o.ship_country, o.employee_id
order by avg_days asc;

----------------------------------------2-----------------------------------------
--Q5
with ccp(customer_id,country,product_variety) as(
  select c.customer_id,c.country,count(distinct p.product_id) 
  from order_details od , orders o,customers c,products p
  where  o.order_id = od.order_id and c.customer_id =o.customer_id and p.product_id=od.product_id
  group by c.customer_id,c.country
),
rnk_customers as (
    select country,customer_id,product_variety,
        RANK() OVER (partition by country order by product_variety desc) as rnk
    from ccp
)
SELECT country,customer_id,product_variety
from rnk_customers
where rnk = 1
order by product_variety desc;

-- Q6
select o.employee_id, count(distinct p.category_id) category_count
from orders o
join order_details od on o.order_id = od.order_id
join products p on od.product_id = p.product_id
group by o.employee_id
order by category_count desc;

-- Q7
SELECT order_id, count(distinct product_id) as product_variety
from order_details
group by order_id
order by product_variety desc
limit 10;

--Q8
select p.category_id ,avg(od.quantity) as avg_items
from products p , order_details od
where p.product_id=od.product_id
group by p.category_id
order by avg_items desc;

----------------------------------------3-----------------------------------------
--Q9
with supplier_revenue as (
    select p.category_id,p.supplier_id,sum(od.unit_price * od.quantity * (1 - od.discount)) as total_revenue
    from products p
    join order_details od on p.product_id = od.product_id
    where p.supplier_id is not null
    group by p.category_id, p.supplier_id
),
rnk_suppliers as (
    select category_id,supplier_id,total_revenue,
        RANK() OVER (partition by category_id order by total_revenue desc) as rnk
    from supplier_revenue
)
select category_id,supplier_id,total_revenue
from rnk_suppliers
where rnk = 1
order by total_revenue desc;
--or
with spt(supplier_id,category_id,total_revenue) as (
  select p.supplier_id,p.category_id,sum((1-od.discount)*(od.unit_price * od.quantity))
  from products p,order_details od 
  where od.product_id = p.product_id
  group by p.supplier_id,p.category_id
)
select s.category_id,spt.supplier_id,s.total_revenue
from spt,(
  select category_id,max(total_revenue) as total_revenue
  from spt
  group by category_id) as s
where spt.total_revenue=s.total_revenue and spt.category_id=s.category_id
order by total_revenue desc;

-- Q10
with epr as (
    select o.employee_id,od.product_id,sum(od.unit_price * od.quantity * (1 - od.discount)) as revenue,
  ROW_NUMBER() OVER (partition by employee_id order by sum(od.unit_price * od.quantity * (1 - od.discount)) desc) as rnk
    from orders o
    join order_details od on o.order_id = od.order_id
    group by o.employee_id, od.product_id
)
select employee_id, product_id, revenue
from epr
where rnk = 1
order by revenue desc;

-- Q11
with supplier_country_revenue as (
    select  o.ship_country as country,p.supplier_id,sum(od.unit_price * od.quantity * (1 - od.discount)) as revenue
    from orders o
    join order_details od on o.order_id = od.order_id
    join products p on od.product_id = p.product_id
    where p.supplier_id is not null
    group by o.ship_country, p.supplier_id
),
rnk_suppliers as (
    select country,supplier_id,revenue,
        RANK() OVER (partition by country order by revenue desc) as rnk
    from supplier_country_revenue
)
select country,supplier_id,revenue
from rnk_suppliers
where rnk = 1
order by revenue desc;
--or
with supplier_country_revenue as (
    select s.country,p.supplier_id,sum(od.unit_price * od.quantity * (1 - od.discount)) as revenue
    from suppliers s
    join products p on s.supplier_id = p.supplier_id
    join order_details od on p.product_id = od.product_id
    group by s.country, p.supplier_id
),
rnk_suppliers as (
    select country,supplier_id,revenue,
        RANK() OVER (partition by country order by revenue desc) as rnk
    from supplier_country_revenue
)
select country,supplier_id,revenue
from rnk_suppliers
where rnk = 1
order by revenue desc;

-- -- Q12
with cco as (
    select p.category_id,o.ship_country as country,count(distinct o.order_id) as order_count,
  RANK() OVER (partition by p.category_id order by count(distinct o.order_id) desc) as rnk
    from orders o
    join order_details od on o.order_id = od.order_id
    join products p on od.product_id = p.product_id
    group by p.category_id, o.ship_country
)
select category_id,country,order_count
from cco
where rnk = 1
order by order_count desc;


-- Q13
with monthly_employee_revenue as (
    select extract(MONTH from o.order_date) as month,o.employee_id,
        sum(od.unit_price * od.quantity * (1 - od.discount)) as revenue
    from orders o
    join order_details od on o.order_id = od.order_id
    group by extract(MONTH from o.order_date), o.employee_id
),
rnk_employees as (
    select month,employee_id,revenue,
        ROW_NUMBER() OVER (partition by month order by revenue desc) as rnk
    from monthly_employee_revenue
)
select month,employee_id,revenue
from rnk_employees
where rnk = 1
order by revenue desc;
--or
with monthly_employee_revenue as (
    select to_char(o.order_date,'Month') as month,o.employee_id,
        sum(od.unit_price * od.quantity * (1 - od.discount)) as revenue
    from orders o
    join order_details od on o.order_id = od.order_id
    group by to_char(o.order_date,'Month'), o.employee_id
),
rnk_employees as (
    select month,employee_id,revenue,
        ROW_NUMBER() OVER (partition by month order by revenue desc) as rnk
    from monthly_employee_revenue
)
select month,employee_id,revenue
from rnk_employees
where rnk = 1
order by revenue desc;

-- Q14
with yearly_country_revenue as (
    select 
        EXTRACT(year from o.order_date) as year,
        o.ship_country as country,
        sum(od.unit_price * od.quantity * (1 - od.discount)) as revenue
    from orders o
    join order_details od on o.order_id = od.order_id
    group by extract(year from o.order_date), o.ship_country
),
rnk_countries as (
    select year, country, revenue,
        ROW_NUMBER() OVER (partition by year order by revenue desc) as rnk
    from yearly_country_revenue
)
select year,country,revenue
from rnk_countries
where rnk = 1
order by revenue desc;
----------------------------------------4-----------------------------------------
-- Q15
select p.supplier_id,max(p.unit_price) - min(p.unit_price) as price_range
FROM products p
where p.supplier_id is not null
group by p.supplier_id
having max(p.unit_price) - min(p.unit_price) > 50
order by price_range desc;
----------------------------------------------------------------------
-- Q16
with supplier_country_revenue as (
    select  o.ship_country as country,p.supplier_id,sum(od.unit_price * od.quantity * (1 - od.discount)) as revenue
    from orders o
    join order_details od on o.order_id = od.order_id
    join products p on od.product_id = p.product_id
    where p.supplier_id is not null
    group by o.ship_country, p.supplier_id
),
rnk_suppliers as (
    select country,supplier_id,revenue,
        RANK() OVER (partition by country order by revenue desc) as rnk
    from supplier_country_revenue
)
select country,supplier_id,revenue
from rnk_suppliers
where rnk = 1
order by revenue desc;
--or
with supplier_country_revenue as (
    select s.country,p.supplier_id,sum(od.unit_price * od.quantity * (1 - od.discount)) as revenue
    from suppliers s
    join products p on s.supplier_id = p.supplier_id
    join order_details od on p.product_id = od.product_id
    group by s.country, p.supplier_id
),
rnk_suppliers as (
    select country,supplier_id,revenue,
        RANK() OVER (partition by country order by revenue desc) as rnk
    from supplier_country_revenue
)
select country,supplier_id,revenue
from rnk_suppliers
where rnk = 1
order by revenue desc;

--------------------------------------5-----------------------------------------
-- Q17
with customer_max_price as (
    select o.customer_id,od.product_id,od.unit_price AS max_price,
        ROW_NUMBER() OVER (partition by o.customer_id order by od.unit_price desc) as rnk
    from orders o
    join order_details od on o.order_id = od.order_id
)
select customer_id,product_id,max_price
from customer_max_price
where rnk = 1
order by max_price desc;


-- Q18
select o.customer_id ,avg(od.discount) avg_discount
from orders o, order_details od
where o.order_id=od.order_id
group by o.customer_id
order by avg_discount desc
limit 10;

--Q19
with customer_sum_order as (
    select o.order_id,o.customer_id,sum(od.unit_price * od.quantity * (1 - od.discount)) as order_sum
    from orders o
    join order_details od on o.order_id = od.order_id
    group by o.customer_id,o.order_id
)
,avg_per_order as(
  select customer_id,avg(order_sum) as avg_order_sum
  from customer_sum_order
  group by customer_id
)
select customer_id,avg_order_sum,RANK() OVER (order by avg_order_sum desc) as rank
from avg_per_order
order by avg_order_sum desc;

--------------------------------------6-----------------------------------------
-- Q20
select p.category_id ,avg(od.discount)*100 as avg_discount
from order_details od , products p
where p.product_id= od.product_id
group by p.category_id
order by avg_discount desc;