
    
    

with all_values as (

    select
        order_status as value_field,
        count(*) as n_records

    from ECOMM_DB.RAW.raw_orders
    group by order_status

)

select *
from all_values
where value_field not in (
    'Delivered','Shipped','Processing','Cancelled','Refunded','Pending'
)


