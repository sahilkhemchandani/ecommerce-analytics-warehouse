# Snowflake + dbt E-Commerce Analytics Warehouse

**Stack:** Python · Snowflake · dbt Core · Airflow · Power BI DirectQuery  
**Scale:** ~20M+ rows across 5 tables  
**Domain:** E-Commerce (orders, customers, products, returns)

---

## Architecture

```
[Python Generator]
       │  20M+ synthetic rows
       ▼
[Snowflake RAW schema]
  raw_customers / raw_products / raw_orders / raw_order_items / raw_returns
       │
       ▼  dbt run (orchestrated by Airflow)
[STAGING schema]  ← views, clean + typed
  stg_customers / stg_products / stg_orders / stg_order_items / stg_returns
       │
       ▼  ephemeral CTEs
[INTERMEDIATE]
  int_orders_enriched / int_product_metrics
       │
       ▼  physical tables + incremental model
[MARTS schema]
  mart_sales_daily          ← incremental, primary BI source
  mart_customer_360         ← RFM scoring, LTV, churn risk
  mart_product_performance  ← revenue, margin, return rates
  mart_returns_analysis     ← return reasons, financial impact
       │
       ▼  DirectQuery
[Power BI Dashboard]
```

---

## Prerequisites

```bash
pip install snowflake-connector-python pandas pyarrow numpy
pip install dbt-snowflake
pip install apache-airflow                    # only if running Airflow locally
```

---

## Step 1: Snowflake Free Trial Setup

1. Sign up at https://signup.snowflake.com (30-day free trial, no credit card)
2. Choose **AWS** as cloud provider, **us-east-1** or closest region
3. Note your **account identifier** — format: `abc12345.us-east-1`
4. Open **Snowflake Worksheets** and run `snowflake/setup.sql` top to bottom

---

## Step 2: Generate Synthetic Data

```bash
cd ecommerce_dw/data_generator
pip install numpy pandas pyarrow

python generate_data.py
```

Expected output in `./generated_data/`:
- `raw_customers.parquet`            — 500K rows
- `raw_products.parquet`             — 50K rows
- `raw_orders_chunk_*.parquet`       — 5M rows total (10 chunks)
- `raw_order_items_chunk_*.parquet`  — ~12M rows total
- `raw_returns.parquet`              — ~1.2M rows

Runtime: ~5–10 minutes on standard laptop.

---

## Step 3: Upload to Snowflake

```bash
# Set credentials as environment variables (never hardcode passwords)
export SNOWFLAKE_ACCOUNT="your_account_identifier"
export SNOWFLAKE_USER="your_username"
export SNOWFLAKE_PASSWORD="your_password"

python upload_to_snowflake.py
```

Verify in Snowflake Worksheet:
```sql
USE DATABASE ECOMM_DB;
SELECT 'RAW_ORDERS', COUNT(*) FROM RAW.RAW_ORDERS
UNION ALL SELECT 'RAW_ORDER_ITEMS', COUNT(*) FROM RAW.RAW_ORDER_ITEMS;
-- Should return ~5M and ~12M
```

---

## Step 4: dbt Setup

```bash
cd ecommerce_dw/dbt_project

# Install dbt-snowflake
pip install dbt-snowflake

# Copy profiles.yml to ~/.dbt/
cp profiles.yml ~/.dbt/profiles.yml

# Edit ~/.dbt/profiles.yml — fill in your Snowflake credentials
# OR keep env vars set from Step 3

# Install dbt packages (dbt_utils)
dbt deps

# Test connection
dbt debug

# Run source tests (validate raw data)
dbt test --select source:raw

# Run all models
dbt run

# Run all tests
dbt test

# Generate + serve docs locally
dbt docs generate
dbt docs serve           # opens browser at localhost:8080
```

### dbt run order (automatic via refs):
```
stg_* (views) → int_* (ephemeral CTEs) → mart_* (tables)
```

### Selective runs:
```bash
dbt run --select staging                  # only staging layer
dbt run --select marts.mart_sales_daily  # only one mart
dbt run --select +mart_customer_360      # mart + all upstream
dbt run --select tag:marts               # all marts
```

---

## Step 5: Airflow Setup (Local)

```bash
pip install apache-airflow

export AIRFLOW_HOME=~/airflow
airflow db init

# Copy DAG
cp ecommerce_dw/airflow/dags/ecommerce_dbt_pipeline.py ~/airflow/dags/

# Set Airflow Variables
airflow variables set dbt_project_dir   /path/to/ecommerce_dw/dbt_project
airflow variables set dbt_profiles_dir  ~/.dbt
airflow variables set dbt_target        dev

# Start scheduler + webserver
airflow scheduler &
airflow webserver --port 8090 &

# Open http://localhost:8090 → enable ecommerce_dbt_pipeline → trigger manually
```

---

## Step 6: Power BI DirectQuery Setup

1. Open Power BI Desktop → **Get Data** → **Snowflake**
2. Server: `your_account.snowflakecomputing.com`
3. Warehouse: `ECOMM_WH`
4. Database: `ECOMM_DB`
5. Schema: `MARTS`
6. **Select DirectQuery mode** (not Import — critical for live data)
7. Load tables: `MART_SALES_DAILY`, `MART_CUSTOMER_360`, `MART_PRODUCT_PERFORMANCE`, `MART_RETURNS_ANALYSIS`

### Suggested Dashboard Pages:
| Page | Primary Table | Key Visuals |
|------|--------------|-------------|
| Executive Summary | mart_sales_daily | Revenue trend, MoM growth, AOV |
| Customer Analytics | mart_customer_360 | RFM tier distribution, churn risk |
| Product Performance | mart_product_performance | Revenue by category, margin heatmap |
| Returns Intelligence | mart_returns_analysis | Return reason breakdown, return window |

### DirectQuery optimization tips:
- Use **Aggregation tables** in Power BI for very large queries
- Set **query reduction** options in Power BI options
- Pre-aggregate in Snowflake (mart_sales_daily already daily aggregated)
- Add **cluster keys** in Snowflake on `order_date` for mart_sales_daily

---

## Project Structure

```
ecommerce_dw/
├── data_generator/
│   ├── generate_data.py          ← synthetic data (20M+ rows)
│   └── upload_to_snowflake.py    ← bulk load to Snowflake RAW
├── snowflake/
│   └── setup.sql                 ← DDL: DB, schemas, tables, streams
├── dbt_project/
│   ├── dbt_project.yml
│   ├── profiles.yml
│   ├── packages.yml
│   └── models/
│       ├── staging/              ← views: clean + type raw data
│       ├── intermediate/         ← ephemeral CTEs: joins + logic
│       └── marts/                ← tables: BI-ready aggregates
│           ├── mart_sales_daily      (incremental)
│           ├── mart_customer_360
│           ├── mart_product_performance
│           └── mart_returns_analysis
├── airflow/
│   └── dags/
│       └── ecommerce_dbt_pipeline.py
└── README.md
```

---

## Resume Bullet Points (copy-paste ready)

```
• Engineered a production-grade e-commerce analytics warehouse on Snowflake
  ingesting 20M+ synthetic records across orders, customers, products, and
  returns; built dbt incremental models across staging and mart layers with
  automated data quality tests, orchestrated via Apache Airflow DAGs.

• Designed a star-schema dimensional model in dbt with 4 mart tables
  (sales_daily, customer_360, product_performance, returns_analysis) featuring
  RFM scoring, LTV metrics, and gross margin analytics connected to Power BI
  via DirectQuery for live operational dashboards.
```

---

## Key Concepts Demonstrated

| Concept | Where |
|---------|-------|
| Snowflake Streams | setup.sql — CDC tracking on raw tables |
| dbt incremental models | mart_sales_daily.sql |
| dbt ephemeral CTEs | int_orders_enriched.sql |
| dbt source tests | _sources.yml — uniqueness, FK, accepted values |
| dbt custom tests | tests/assert_positive_revenue.sql |
| dbt surrogate keys | dbt_utils.generate_surrogate_key in mart models |
| Airflow DAG with retry logic | ecommerce_dbt_pipeline.py |
| Power BI DirectQuery | Step 6 above |
| RFM scoring in SQL | mart_customer_360.sql — NTILE window functions |
| Large-scale data generation | generate_data.py — vectorized numpy, chunked write |
