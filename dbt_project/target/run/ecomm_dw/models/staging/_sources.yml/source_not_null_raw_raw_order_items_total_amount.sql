
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select total_amount
from ECOMM_DB.RAW.raw_order_items
where total_amount is null



  
  
      
    ) dbt_internal_test