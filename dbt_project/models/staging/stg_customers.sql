-- models/staging/stg_customers.sql
-- Cleans and types raw customer data.
-- Derives: full_name, is_active flag as boolean, customer tenure in days.

with source as (
    select * from {{ source('raw', 'raw_customers') }}
),

renamed as (
    select
        customer_id::integer                                    as customer_id,
        trim(first_name)                                        as first_name,
        trim(last_name)                                         as last_name,
        trim(first_name) || ' ' || trim(last_name)             as full_name,
        lower(trim(email))                                      as email,
        initcap(trim(city))                                     as city,
        initcap(trim(state))                                    as state,
        upper(trim(country))                                    as country,
        segment,
        created_at::date                                        as created_at,
        case when is_active = 1 then true else false end        as is_active,
        lifetime_orders::integer                                as lifetime_orders,
        datediff('day', created_at::date, current_date)        as customer_tenure_days
    from source
    where customer_id is not null
)

select * from renamed
