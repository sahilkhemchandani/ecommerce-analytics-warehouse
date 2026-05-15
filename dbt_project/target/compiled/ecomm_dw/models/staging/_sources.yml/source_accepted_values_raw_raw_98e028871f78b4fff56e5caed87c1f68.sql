
    
    

with all_values as (

    select
        segment as value_field,
        count(*) as n_records

    from ECOMM_DB.RAW.raw_customers
    group by segment

)

select *
from all_values
where value_field not in (
    'B2C','B2B','Premium','Budget'
)


