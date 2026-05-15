-- models/intermediate/int_orders_enriched.sql
-- Joins orders + customers + aggregated item totals.
-- Ephemeral = compiled as CTE into downstream marts, no physical table.

with orders as (
    select * from {{ ref('stg_orders') }}
),

customers as (
    select
        customer_id,
        full_name,
        segment,
        country        as customer_country,
        city           as customer_city,
        customer_tenure_days
    from {{ ref('stg_customers') }}
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
    from {{ ref('stg_order_items') }}
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
