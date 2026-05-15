-- models/staging/stg_returns.sql

with source as (
    select * from {{ source('raw', 'raw_returns') }}
),

renamed as (
    select
        return_id::integer                  as return_id,
        item_id::integer                    as item_id,
        return_date::date                   as return_date,
        trim(return_reason)                 as return_reason,
        trim(return_status)                 as return_status,
        round(refund_amount::float, 2)      as refund_amount,
        case
            when return_status = 'Approved' then true
            else false
        end                                 as is_approved
    from source
    where return_id is not null
      and item_id is not null
)

select * from renamed
