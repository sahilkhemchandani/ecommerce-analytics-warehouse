
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select return_key
from ECOMM_DB.STAGING_marts.mart_returns_analysis
where return_key is null



  
  
      
    ) dbt_internal_test