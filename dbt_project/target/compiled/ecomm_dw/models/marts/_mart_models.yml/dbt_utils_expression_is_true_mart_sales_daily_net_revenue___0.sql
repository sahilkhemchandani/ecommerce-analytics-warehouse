



select
    1
from ECOMM_DB.STAGING_marts.mart_sales_daily

where not(net_revenue >= 0)

