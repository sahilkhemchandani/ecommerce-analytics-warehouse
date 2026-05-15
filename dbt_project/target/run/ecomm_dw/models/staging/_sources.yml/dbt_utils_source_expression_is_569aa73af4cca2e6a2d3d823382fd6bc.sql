
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  



select
    1
from ECOMM_DB.RAW.raw_products

where not(unit_price > 0)


  
  
      
    ) dbt_internal_test