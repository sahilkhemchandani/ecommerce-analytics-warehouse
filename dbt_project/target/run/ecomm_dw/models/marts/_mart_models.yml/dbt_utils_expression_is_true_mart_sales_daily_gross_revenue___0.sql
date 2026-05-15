
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  



select
    1
from ECOMM_DB.STAGING_marts.mart_sales_daily

where not(gross_revenue >= 0)


  
  
      
    ) dbt_internal_test