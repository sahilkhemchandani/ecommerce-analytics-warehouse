
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  



select
    1
from ECOMM_DB.RAW.raw_order_items

where not(total_amount >= 0)


  
  
      
    ) dbt_internal_test