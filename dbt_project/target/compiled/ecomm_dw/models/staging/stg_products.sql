-- models/staging/stg_products.sql
-- Cleans product catalog. Derives gross margin %.

with source as (
    select * from ECOMM_DB.RAW.raw_products
),

renamed as (
    select
        product_id::integer                                                     as product_id,
        trim(product_name)                                                      as product_name,
        trim(category)                                                          as category,
        trim(subcategory)                                                       as subcategory,
        trim(brand)                                                             as brand,
        round(unit_price::float, 2)                                             as unit_price,
        round(cost_price::float, 2)                                             as cost_price,
        round(
            case
                when unit_price > 0
                then ((unit_price - cost_price) / unit_price) * 100
                else null
            end, 2
        )                                                                       as gross_margin_pct,
        stock_qty::integer                                                      as stock_qty,
        case when is_active = 1 then true else false end                        as is_active,
        created_at::date                                                        as created_at
    from source
    where product_id is not null
      and unit_price > 0
)

select * from renamed