
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select item_id
from ECOMM_DB.RAW.raw_order_items
where item_id is null



  
  
      
    ) dbt_internal_test