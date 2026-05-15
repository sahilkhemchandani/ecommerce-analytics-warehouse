
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select unit_price
from ECOMM_DB.RAW.raw_products
where unit_price is null



  
  
      
    ) dbt_internal_test