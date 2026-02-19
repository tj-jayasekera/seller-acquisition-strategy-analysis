/*
Project: Seller Acquisition Strategy & Performance Analysis

Objective:
Build a multi-layer (Bronze → Silver → Gold) data model to evaluate
acquisition channel performance across revenue, activation efficiency,
customer experience, and lifecycle duration.

Author: Theekshana Jayasekera
*/

create schema bronze;
create schema silver;
create schema gold;

select current_database();

-- Importing raw data from the Kaggle datasets to form the bronze layer

alter table bronze.olist_order_items_dataset
rename to order_items;

select count(*) from bronze.order_items;

alter table bronze.olist_orders_dataset
rename to orders;

select count(*) from bronze.orders;

alter table bronze.olist_order_payments_dataset
rename to order_payments;

select count(*) from bronze.order_payments;

alter table bronze.olist_order_reviews_dataset
rename to order_reviews;

select count(*) from bronze.order_reviews;

alter table bronze.olist_sellers_dataset
rename to sellers;

select count(*) from bronze.sellers;

alter table bronze.olist_marketing_qualified_leads_dataset
rename to mql;

select count(*) from bronze.mql;

alter table bronze.olist_closed_deals_dataset
rename to closed_deals;

select count(*) from bronze.closed_deals;

/* Now that the bronze layer has been created, silver layer tables can be created - getting rid of null values, pre-processing
 * and formatting data, and including only the necessary fields
 */

create view silver.orders as
select
    order_id,
    customer_id,
    order_status,
    nullif(order_purchase_timestamp, '')::timestamp as order_purchase_ts,
    nullif(order_delivered_customer_date, '')::timestamp as delivered_ts,
    nullif(order_estimated_delivery_date, '')::timestamp as estimated_delivery_ts,
    case
        when nullif(order_delivered_customer_date, '')::timestamp is not null
         and nullif(order_estimated_delivery_date, '')::timestamp is not null
         and nullif(order_delivered_customer_date, '')::timestamp
             > nullif(order_estimated_delivery_date, '')::timestamp
        then 1 else 0
    end as is_late_delivery
from bronze.orders;

create view silver.order_items as
select
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date::timestamp as shipping_limit_ts,
    price::numeric(10,2) as price,
    freight_value::numeric(10,2) as freight_value
from bronze.order_items;

create view silver.order_reviews as
select
    order_id,
    review_score::int as review_score,
    review_creation_date::timestamp as review_creation_ts,
    review_answer_timestamp::timestamp as review_answer_ts
from bronze.order_reviews;

create view silver.closed_deals as
select
    mql_id,
    seller_id,
    won_date::timestamp as won_ts,
    business_segment,
    lead_type,
    lead_behaviour_profile,
    business_type,
    declared_monthly_revenue::numeric
from bronze.closed_deals;

create view silver.mql as
select
    mql_id,
    first_contact_date::timestamp as first_contact_ts,
    origin
from bronze.mql;

/* Now the silver layer tables can be joined to form gold layer tables, consolidating and matching data across
 * several datasets 
 */

create table gold.seller_sales_summary as
select
    oi.seller_id,
    count(distinct oi.order_id) as total_orders,
    count(*) as total_items,
    sum(oi.price) as total_item_revenue,
    sum(oi.freight_value) as total_freight,
    sum(oi.price + oi.freight_value) as total_revenue,
    min(o.order_purchase_ts) as first_sale_ts
from silver.order_items oi
join silver.orders o
  on o.order_id = oi.order_id
group by oi.seller_id;

create table gold.seller_experience_summary as
select
    oi.seller_id,
    avg(r.review_score) as avg_review_score,
    count(r.review_score) as review_count,
    avg(o.is_late_delivery::int) as late_delivery_rate
from silver.order_items oi
join silver.orders o
  on o.order_id = oi.order_id
left join silver.order_reviews r
  on r.order_id = oi.order_id
group by oi.seller_id;

create table gold.seller_master as
select
    cd.seller_id,
    m.origin as acquisition_channel,
    m.first_contact_ts,
    cd.won_ts,
    cd.business_segment,
    cd.lead_type,
    cd.business_type,
    cd.declared_monthly_revenue,
    sss.total_orders,
    sss.total_items,
    sss.total_revenue,
    sss.first_sale_ts,
    ses.avg_review_score,
    ses.review_count,
    ses.late_delivery_rate,
    (sss.first_sale_ts::date - cd.won_ts::date) as days_from_won_to_first_sale,
    (cd.won_ts::date - m.first_contact_ts::date) as days_from_contact_to_won
from silver.closed_deals cd
join silver.mql m
  on m.mql_id = cd.mql_id
left join gold.seller_sales_summary sss
  on sss.seller_id = cd.seller_id
left join gold.seller_experience_summary ses
  on ses.seller_id = cd.seller_id;

--  Processing the gold seller master table further to exclude certain channels

create or replace table gold.cleaned_seller_master as
select *
from gold.seller_master
where acquisition_channel is not null
  and acquisition_channel not in (
      'unknown',
      'other',
      'other_publicities'
  );

/* Now the channel scorecard can be created - using consolidated data from the other gold layer tables, providing insights for 
 * each channel - my analysis is carried out solely on this table*/

create table gold.channel_scorecard as
select
    acquisition_channel,
    count(*) as sellers_acquired,
    count(*) filter (
        where total_orders is not null 
          and total_orders > 0
    ) as sellers_with_sales,
    sum(total_revenue) as total_revenue,
    avg(total_revenue) as avg_revenue_per_seller,
    percentile_cont(0.5) 
        within group (order by total_revenue) 
        as median_revenue_per_seller,
    avg(avg_review_score) as avg_review_score,
    avg(late_delivery_rate) as avg_late_delivery_rate,
    avg(days_from_contact_to_won) as avg_days_contact_to_won,
    avg(days_from_won_to_first_sale) as avg_days_won_to_first_sale
from gold.cleaned_seller_master
group by acquisition_channel
order by total_revenue desc;

-- 0) quick check - what channels exist now after cleaning? 

select acquisition_channel
from gold.channel_scorecard
order by sellers_acquired desc;

/* this confirms that organic search, paid search, social, direct traffic, referral, email 
   and display are the only channels remaining */

-- 1) Which channels have the most sellers? Which ones make the highest revenue?
 
select acquisition_channel, sellers_acquired, sellers_with_sales
from gold.channel_scorecard
order by sellers_acquired desc;

select acquisition_channel, total_revenue
from gold.channel_scorecard
order by total_revenue desc;

/* A) Organic search and paid search have the most sellers, and the most sellers with sales.
 * They also have the highest revenue - with organic search having the highest
 */ 

-- 2) What % of sellers are actually making sales?

select
    acquisition_channel,
    round(
        sellers_with_sales::numeric 
        / nullif(sellers_acquired, 0),
        4
    ) as activation_rate
from gold.channel_scorecard
order by activation_rate desc;

/* A) The activation rate is calculated as the proportion of sellers that are actually making sales
 * Direct Traffic has the highest proportion of active sellers, cloesly followed by paid search. */

-- 3) Which channels have the highest avg revenue per seller?

select acquisition_channel, avg_revenue_per_seller
from gold.channel_scorecard
order by avg_revenue_per_seller desc;

-- A) Referral has the highest avg revenue per seller, followed closely by organic search

-- 4) Which channel has the fastest lifecycle? - time it takes for a seller to be approached, signed and make a sale

select acquisition_channel,
	   sellers_with_sales,
       avg_days_contact_to_won,
       avg_days_won_to_first_sale
from gold.channel_scorecard
order by (avg_days_contact_to_won + avg_days_won_to_first_sale) asc;

/* A) Referral has the fastest lifecycle, it takes the shortest time to win over a seller and for the 
 * seller to make a sale - Display has an incredibly fast winover rate for sellers, but it takes the 
 * sellers much longer on average to make their first sale - this could be skewed as there are only 2 sellers
 */

-- 5) Which channel has the lowest late delivery rate?

select
    acquisition_channel,
    sellers_with_sales,
    avg_late_delivery_rate
from gold.channel_scorecard
order by avg_late_delivery_rate asc;

-- A) Email has the lowest late delivery rate (6 sellers), social (31 sellers) and display (2 sellers) are tied for the highest 

-- 6) Which channels have the highest review scores?

select
    acquisition_channel,
    sellers_with_sales,
    avg_review_score
from gold.channel_scorecard
order by avg_review_score desc;

-- A) Email has the highest avg review score - but with a seller count of only 6, with social coming in close second with 31 sellers

-- 7) Are the channels that provide the highest revenue also the highest quality in terms of customer experience?

select
    acquisition_channel,
    rank() over (order by total_revenue desc) as revenue_rank,
    rank() over (order by avg_review_score desc) as review_rank,
    rank() over (order by avg_late_delivery_rate asc) as delivery_rank
from gold.channel_scorecard
order by revenue_rank;

/* A) The channels with the highest revenues tend to have lower average review scores and slower delivery dates.
 * Email (highest review score) contributes very little revenue (second lowest total revenue), and organic search 
 * (highest revenue) has a relatively low review score. 
 */

-- 8) Is the average revenue per seller for certain channels skewed by highly performing individuals?

select
    acquisition_channel,
    round(
        (
            (avg_revenue_per_seller - median_revenue_per_seller)
            / nullif(avg_revenue_per_seller, 0)
        )::numeric * 100,
        4
    ) as revenue_skew_ratio
from gold.channel_scorecard
order by revenue_skew_ratio desc;

/* A) The skew % is calculated by subtracting the median revenue from the average revenue for each channel then dividing by the mean.
 * Email is 71.5% skewed, meaning its high average seller revenue is being heavily inflated by certain outliers
 * Referral has a low skew % as the channel with the highest revenue per seller - the revenue is indeed evenly spread and quite high 
 * across sellers, the average revenue is accurate
 * Organic search is skewed by 63.7%, suggesting that revenue is not evenly split amongst sellers despite having a high average seller
 * revenue
 */

/*
Final Summary:

Paid Search is the only channel balancing:
- High revenue
- High activation rate
- Moderate lifecycle duration

Organic Search scales revenue but with lower activation efficiency.

Referral produces high revenue per seller with low skew, suggesting consistent performance.

Email and Display show high quality signals but lack scale.

Business Implication:
Channel strategy should prioritise Paid Search scaling while optimising
Organic Search onboarding to improve activation efficiency.
*/
