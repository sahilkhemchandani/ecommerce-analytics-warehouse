
  
    

create or replace transient table ECOMM_DB.STAGING_marts.mart_sales_daily
    
    
    
    as (-- models/marts/mart_sales_daily.sql
-- Incremental daily sales aggregation by channel and country.
-- Used as the primary BI source for the Power BI DirectQuery dashboard.



with  __dbt__cte__int_orders_enriched as (
-- models/intermediate/int_orders_enriched.sql
-- Joins orders + customers + aggregated item totals.
-- Ephemeral = compiled as CTE into downstream marts, no physical table.

with orders as (
    select * from ECOMM_DB.STAGING_staging.stg_orders
),

customers as (
    select
        customer_id,
        full_name,
        segment,
        country        as customer_country,
        city           as customer_city,
        customer_tenure_days
    from ECOMM_DB.STAGING_staging.stg_customers
),

order_item_agg as (
    select
        order_id,
        count(*)                        as item_count,
        sum(quantity)                   as total_units,
        sum(total_amount)               as order_revenue,
        avg(discount_pct)               as avg_discount_pct,
        max(discount_pct)               as max_discount_pct,
        sum(case when discount_pct > 0 then 1 else 0 end) as discounted_items
    from ECOMM_DB.STAGING_staging.stg_order_items
    group by order_id
),

enriched as (
    select
        o.order_id,
        o.customer_id,
        c.full_name                     as customer_name,
        c.segment                       as customer_segment,
        c.customer_tenure_days,
        o.order_date,
        o.order_year,
        o.order_month,
        o.order_quarter,
        o.order_day_of_week,
        o.order_status,
        o.order_status_group,
        o.channel,
        o.payment_method,
        o.country,
        o.state,
        o.city,
        o.is_gift,
        i.item_count,
        i.total_units,
        round(i.order_revenue, 2)       as order_revenue,
        round(i.avg_discount_pct, 4)    as avg_discount_pct,
        i.discounted_items
    from orders o
    left join customers c using (customer_id)
    left join order_item_agg i using (order_id)
)

select * from enriched
), orders as (
    select * from __dbt__cte__int_orders_enriched
    
),

daily_agg as (
    select
        order_date                              as date_day,
        order_year,
        order_month,
        order_quarter,
        channel,
        country,
        order_status_group,

        -- Volume metrics
        count(distinct order_id)                as total_orders,
        count(distinct customer_id)             as unique_customers,
        sum(item_count)                         as total_items,
        sum(total_units)                        as total_units_sold,

        -- Revenue metrics
        sum(order_revenue)                      as gross_revenue,
        sum(case when order_status_group = 'Cancelled'
            then order_revenue else 0 end)      as cancelled_revenue,
        sum(case when order_status_group = 'Completed'
            then order_revenue else 0 end)      as net_revenue,

        -- Discount metrics
        avg(avg_discount_pct)                   as avg_discount_pct,
        sum(case when avg_discount_pct > 0
            then 1 else 0 end)                  as discounted_orders,

        -- Basket metrics
        avg(order_revenue)                      as avg_order_value,
        avg(item_count)                         as avg_items_per_order,

        -- Gift orders
        sum(case when is_gift then 1 else 0 end) as gift_orders

    from orders
    group by
        order_date, order_year, order_month, order_quarter,
        channel, country, order_status_group
)

select
    md5(cast(coalesce(cast(date_day as TEXT), '_dbt_utils_surrogate_key_null_') || '-' || coalesce(cast(channel as TEXT), '_dbt_utils_surrogate_key_null_') || '-' || coalesce(cast(country as TEXT), '_dbt_utils_surrogate_key_null_') || '-' || coalesce(cast(order_status_group as TEXT), '_dbt_utils_surrogate_key_null_') as TEXT)) as sales_key,
    *,
    round(net_revenue / nullif(total_orders, 0), 2)         as avg_net_order_value,
    round(discounted_orders * 100.0 / nullif(total_orders, 0), 2) as discount_rate_pct
from daily_agg
    )
;


  