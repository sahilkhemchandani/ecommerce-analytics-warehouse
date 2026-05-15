-- models/marts/mart_sales_daily.sql
-- Incremental daily sales aggregation by channel and country.
-- Used as the primary BI source for the Power BI DirectQuery dashboard.

{{
    config(
        materialized   = 'incremental',
        unique_key     = "date_day || '|' || channel || '|' || country",
        on_schema_change = 'sync_all_columns'
    )
}}

with orders as (
    select * from {{ ref('int_orders_enriched') }}
    {% if is_incremental() %}
        -- Only process new dates since last run
        where order_date > (select max(date_day) from {{ this }})
    {% endif %}
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
    {{ dbt_utils.generate_surrogate_key(['date_day','channel','country','order_status_group']) }} as sales_key,
    *,
    round(net_revenue / nullif(total_orders, 0), 2)         as avg_net_order_value,
    round(discounted_orders * 100.0 / nullif(total_orders, 0), 2) as discount_rate_pct
from daily_agg
