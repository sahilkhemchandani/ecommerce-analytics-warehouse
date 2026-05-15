-- models/staging/stg_order_items.sql
-- Cleans order line items. Computes effective unit price after discount.

with source as (
    select * from ECOMM_DB.RAW.raw_order_items
),

renamed as (
    select
        item_id::integer                                        as item_id,
        order_id::integer                                       as order_id,
        product_id::integer                                     as product_id,
        quantity::integer                                       as quantity,
        round(unit_price::float, 2)                             as unit_price,
        round(discount_pct::float, 4)                           as discount_pct,
        round(unit_price::float * (1 - discount_pct::float), 2) as effective_unit_price,
        round(total_amount::float, 2)                           as total_amount,
        case
            when discount_pct = 0      then 'No Discount'
            when discount_pct <= 0.10  then 'Low (≤10%)'
            when discount_pct <= 0.20  then 'Medium (11–20%)'
            else                            'High (>20%)'
        end                                                     as discount_tier
    from source
    where item_id is not null
      and order_id is not null
      and product_id is not null
      and quantity > 0
      and total_amount >= 0
)

select * from renamed