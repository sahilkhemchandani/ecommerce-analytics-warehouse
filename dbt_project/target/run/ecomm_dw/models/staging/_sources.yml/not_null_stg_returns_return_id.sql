
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select return_id
from ECOMM_DB.STAGING_staging.stg_returns
where return_id is null



  
  
      
    ) dbt_internal_test