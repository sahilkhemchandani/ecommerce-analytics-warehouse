-- models/marts/mart_customer_360.sql
-- Full customer-level analytics: RFM scores, revenue, returns, channel preference.
-- One row per customer.

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
    where order_status_group = 'Completed'
),

customers as (
    select * from ECOMM_DB.STAGING_staging.stg_customers
),

returns as (
    select
        oi.order_id,
        count(r.return_id)          as return_count,
        sum(r.refund_amount)        as total_refunded
    from ECOMM_DB.STAGING_staging.stg_order_items oi
    left join ECOMM_DB.STAGING_staging.stg_returns r using (item_id)
    group by oi.order_id
),

customer_orders as (
    select
        o.customer_id,

        -- Recency
        max(o.order_date)                                       as last_order_date,
        datediff('day', max(o.order_date), current_date)        as days_since_last_order,

        -- Frequency
        count(distinct o.order_id)                              as total_orders,
        count(distinct o.order_month || '-' || o.order_year)    as active_months,

        -- Monetary
        sum(o.order_revenue)                                    as lifetime_revenue,
        avg(o.order_revenue)                                    as avg_order_value,
        max(o.order_revenue)                                    as max_order_value,

        -- Channel preference
        mode(o.channel)                                         as preferred_channel,
        mode(o.payment_method)                                  as preferred_payment,

        -- Returns
        sum(coalesce(r.return_count, 0))                        as total_returns,
        sum(coalesce(r.total_refunded, 0))                      as total_refunded,

        -- Units
        sum(o.total_units)                                      as total_units_purchased,
        avg(o.item_count)                                       as avg_items_per_order

    from orders o
    left join returns r using (order_id)
    group by o.customer_id
),

rfm_scored as (
    select
        *,
        -- RFM Quintile scoring (1=worst, 5=best)
        ntile(5) over (order by days_since_last_order desc)     as r_score,
        ntile(5) over (order by total_orders)                   as f_score,
        ntile(5) over (order by lifetime_revenue)               as m_score
    from customer_orders
),

final as (
    select
        c.customer_id,
        c.full_name,
        c.email,
        c.segment,
        c.city,
        c.state,
        c.country,
        c.created_at                                            as customer_since,
        c.is_active,
        c.customer_tenure_days,

        -- Order metrics
        coalesce(rf.total_orders, 0)                            as total_orders,
        coalesce(rf.lifetime_revenue, 0)                        as lifetime_revenue,
        coalesce(rf.avg_order_value, 0)                         as avg_order_value,
        coalesce(rf.max_order_value, 0)                         as max_order_value,
        rf.last_order_date,
        coalesce(rf.days_since_last_order, c.customer_tenure_days) as days_since_last_order,
        coalesce(rf.preferred_channel, 'Never Ordered')         as preferred_channel,
        coalesce(rf.preferred_payment, 'N/A')                   as preferred_payment,

        -- Returns
        coalesce(rf.total_returns, 0)                           as total_returns,
        coalesce(rf.total_refunded, 0)                          as total_refunded,
        round(
            coalesce(rf.total_returns, 0) * 100.0
            / nullif(coalesce(rf.total_units_purchased, 0), 0), 2
        )                                                       as return_rate_pct,

        -- RFM
        coalesce(rf.r_score, 1)                                 as r_score,
        coalesce(rf.f_score, 1)                                 as f_score,
        coalesce(rf.m_score, 1)                                 as m_score,
        coalesce(rf.r_score, 1)
            + coalesce(rf.f_score, 1)
            + coalesce(rf.m_score, 1)                           as rfm_total_score,

        -- Customer tier
        case
            when coalesce(rf.r_score,1) + coalesce(rf.f_score,1) + coalesce(rf.m_score,1) >= 13
                then 'Champions'
            when coalesce(rf.r_score,1) + coalesce(rf.f_score,1) + coalesce(rf.m_score,1) >= 10
                then 'Loyal'
            when coalesce(rf.r_score,1) + coalesce(rf.f_score,1) + coalesce(rf.m_score,1) >= 7
                then 'Potential Loyalist'
            when coalesce(rf.days_since_last_order, 999) > 180
                then 'At Risk / Churned'
            else 'Needs Attention'
        end                                                     as customer_tier

    from customers c
    left join rfm_scored rf using (customer_id)
)

select * from final