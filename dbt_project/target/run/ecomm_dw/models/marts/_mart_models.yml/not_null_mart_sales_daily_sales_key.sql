
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select sales_key
from ECOMM_DB.STAGING_marts.mart_sales_daily
where sales_key is null



  
  
      
    ) dbt_internal_test