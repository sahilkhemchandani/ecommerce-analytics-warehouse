
    
    

select
    return_id as unique_field,
    count(*) as n_records

from ECOMM_DB.RAW.raw_returns
where return_id is not null
group by return_id
having count(*) > 1


