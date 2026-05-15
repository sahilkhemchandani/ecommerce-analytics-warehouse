-- models/marts/mart_returns_analysis.sql
-- Returns analytics: reasons, rates by category/channel, financial impact.

with returns as (
    select * from {{ ref('stg_returns') }}
),

items as (
    select * from {{ ref('stg_order_items') }}
),

orders as (
    select order_id, order_date, order_year, order_month,
           channel, country, customer_id
    from {{ ref('stg_orders') }}
),

products as (
    select product_id, product_name, category, subcategory, brand
    from {{ ref('stg_products') }}
),

enriched as (
    select
        r.return_id,
        r.item_id,
        r.return_date,
        r.return_reason,
        r.return_status,
        r.is_approved,
        r.refund_amount,

        i.order_id,
        i.product_id,
        i.quantity,
        i.total_amount          as original_sale_amount,
        i.discount_pct,
        i.discount_tier,

        o.order_date,
        o.order_year,
        o.order_month,
        o.channel,
        o.country,
        o.customer_id,

        p.product_name,
        p.category,
        p.subcategory,
        p.brand,

        datediff('day', o.order_date, r.return_date)   as days_to_return

    from returns r
    join items   i using (item_id)
    join orders  o using (order_id)
    join products p using (product_id)
)

select
    {{ dbt_utils.generate_surrogate_key(['return_id']) }}   as return_key,
    *,
    case
        when days_to_return <= 7  then '0–7 days'
        when days_to_return <= 30 then '8–30 days'
        when days_to_return <= 60 then '31–60 days'
        else                           '60+ days'
    end                                                     as return_window
from enriched
