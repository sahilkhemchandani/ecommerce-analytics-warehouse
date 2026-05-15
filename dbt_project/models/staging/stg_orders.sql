-- models/staging/stg_orders.sql
-- Cleans order headers. Extracts year/month/quarter for partitioned analytics.

with source as (
    select * from {{ source('raw', 'raw_orders') }}
),

renamed as (
    select
        order_id::integer                                       as order_id,
        customer_id::integer                                    as customer_id,
        order_date::date                                        as order_date,
        year(order_date::date)                                  as order_year,
        month(order_date::date)                                 as order_month,
        quarter(order_date::date)                               as order_quarter,
        dayofweek(order_date::date)                             as order_day_of_week,
        trim(order_status)                                      as order_status,
        case
            when order_status in ('Delivered','Shipped')        then 'Completed'
            when order_status in ('Processing','Pending')       then 'In Progress'
            when order_status in ('Cancelled','Refunded')       then 'Cancelled'
            else 'Unknown'
        end                                                     as order_status_group,
        trim(channel)                                           as channel,
        trim(payment_method)                                    as payment_method,
        initcap(trim(city))                                     as city,
        initcap(trim(state))                                    as state,
        upper(trim(country))                                    as country,
        case when is_gift = 1 then true else false end          as is_gift
    from source
    where order_id is not null
      and customer_id is not null
      and order_date is not null
)

select * from renamed
