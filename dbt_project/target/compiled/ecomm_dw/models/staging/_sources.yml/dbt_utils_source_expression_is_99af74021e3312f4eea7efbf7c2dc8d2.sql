



select
    1
from ECOMM_DB.RAW.raw_order_items

where not(total_amount >= 0)

