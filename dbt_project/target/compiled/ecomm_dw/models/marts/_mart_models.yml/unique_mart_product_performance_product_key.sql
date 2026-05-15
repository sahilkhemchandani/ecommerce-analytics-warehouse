
    
    

select
    product_key as unique_field,
    count(*) as n_records

from ECOMM_DB.STAGING_marts.mart_product_performance
where product_key is not null
group by product_key
having count(*) > 1


