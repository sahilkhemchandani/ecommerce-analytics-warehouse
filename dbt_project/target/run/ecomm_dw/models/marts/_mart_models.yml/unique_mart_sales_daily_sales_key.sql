
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

select
    sales_key as unique_field,
    count(*) as n_records

from ECOMM_DB.STAGING_marts.mart_sales_daily
where sales_key is not null
group by sales_key
having count(*) > 1



  
  
      
    ) dbt_internal_test