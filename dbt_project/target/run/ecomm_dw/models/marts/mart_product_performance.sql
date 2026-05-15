
  
    

create or replace transient table ECOMM_DB.STAGING_marts.mart_product_performance
    
    
    
    as (-- models/marts/mart_product_performance.sql
-- Product-level sales performance with profitability metrics.

with items as (
    select * from ECOMM_DB.STAGING_staging.stg_order_items
),

orders as (
    select order_id, order_date, order_year, order_month,
           order_quarter, channel, country, order_status_group
    from ECOMM_DB.STAGING_staging.stg_orders
),

products as (
    select * from ECOMM_DB.STAGING_staging.stg_products
),

returns as (
    select item_id, return_status, refund_amount
    from ECOMM_DB.STAGING_staging.stg_returns
    where is_approved = true
),

joined as (
    select
        i.product_id,
        p.product_name,
        p.category,
        p.subcategory,
        p.brand,
        p.unit_price                                        as list_price,
        p.cost_price,
        p.gross_margin_pct,
        p.is_active,

        o.order_date,
        o.order_year,
        o.order_month,
        o.order_quarter,
        o.channel,
        o.country,
        o.order_status_group,

        i.item_id,
        i.quantity,
        i.total_amount,
        i.discount_pct,
        i.discount_tier,

        r.return_status,
        coalesce(r.refund_amount, 0)                        as refund_amount,
        case when r.item_id is not null then 1 else 0 end   as is_returned

    from items i
    join orders   o using (order_id)
    join products p using (product_id)
    left join returns r using (item_id)
),

agg as (
    select
        product_id,
        product_name,
        category,
        subcategory,
        brand,
        list_price,
        cost_price,
        gross_margin_pct,
        is_active,

        count(item_id)                                      as total_line_items,
        sum(quantity)                                       as units_sold,
        sum(total_amount)                                   as gross_revenue,
        sum(total_amount) - sum(refund_amount)              as net_revenue,
        sum(total_amount - (cost_price * quantity))         as gross_profit,

        avg(discount_pct)                                   as avg_discount_pct,
        sum(is_returned)                                    as return_count,
        sum(refund_amount)                                   as total_refunds,

        count(distinct case when order_status_group = 'Completed' then item_id end) as completed_items,
        count(distinct case when order_status_group = 'Cancelled' then item_id end) as cancelled_items,

        min(order_date)                                     as first_sale_date,
        max(order_date)                                     as last_sale_date

    from joined
    group by
        product_id, product_name, category, subcategory, brand,
        list_price, cost_price, gross_margin_pct, is_active
)

select
    md5(cast(coalesce(cast(product_id as TEXT), '_dbt_utils_surrogate_key_null_') as TEXT))  as product_key,
    *,
    round(return_count * 100.0 / nullif(units_sold, 0), 2) as return_rate_pct,
    round(gross_profit / nullif(gross_revenue, 0) * 100, 2) as actual_margin_pct,
    dense_rank() over (partition by category order by net_revenue desc) as rank_in_category
from agg
    )
;


  