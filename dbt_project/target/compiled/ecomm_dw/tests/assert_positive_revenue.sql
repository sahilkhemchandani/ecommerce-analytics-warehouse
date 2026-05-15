-- tests/assert_positive_revenue.sql
-- Custom singular test: no mart_sales_daily row should have negative net_revenue.
-- dbt test will fail if this query returns any rows.

select
    date_day,
    channel,
    country,
    net_revenue
from ECOMM_DB.STAGING_marts.mart_sales_daily
where net_revenue < 0