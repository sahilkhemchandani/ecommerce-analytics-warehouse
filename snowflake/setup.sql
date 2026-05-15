-- ============================================================
-- SNOWFLAKE SETUP
-- Run these statements in order in Snowflake Worksheets
-- ============================================================

-- ─── 1. WAREHOUSE ────────────────────────────────────────────
CREATE WAREHOUSE IF NOT EXISTS ECOMM_WH
    WAREHOUSE_SIZE    = 'X-SMALL'
    AUTO_SUSPEND      = 120          -- suspend after 2 min idle (save credits)
    AUTO_RESUME       = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'E-Commerce Analytics DWH Warehouse';

-- ─── 2. DATABASE & SCHEMAS ───────────────────────────────────
CREATE DATABASE IF NOT EXISTS ECOMM_DB
    COMMENT = 'E-Commerce Analytics Data Warehouse';

USE DATABASE ECOMM_DB;

CREATE SCHEMA IF NOT EXISTS RAW     COMMENT = 'Raw ingested data from source';
CREATE SCHEMA IF NOT EXISTS STAGING COMMENT = 'dbt staging layer — cleaned & typed';
CREATE SCHEMA IF NOT EXISTS MARTS   COMMENT = 'dbt mart layer — business-ready aggregates';

-- ─── 3. RAW TABLES ───────────────────────────────────────────
USE SCHEMA RAW;

CREATE TABLE IF NOT EXISTS RAW_CUSTOMERS (
    CUSTOMER_ID      NUMBER        NOT NULL,
    FIRST_NAME       VARCHAR(100),
    LAST_NAME        VARCHAR(100),
    EMAIL            VARCHAR(200),
    CITY             VARCHAR(100),
    STATE            VARCHAR(100),
    COUNTRY          VARCHAR(100),
    SEGMENT          VARCHAR(50),
    CREATED_AT       DATE,
    IS_ACTIVE        NUMBER(1),     -- 1/0 (bool stored as int for compatibility)
    LIFETIME_ORDERS  NUMBER
);

CREATE TABLE IF NOT EXISTS RAW_PRODUCTS (
    PRODUCT_ID    NUMBER        NOT NULL,
    PRODUCT_NAME  VARCHAR(300),
    CATEGORY      VARCHAR(100),
    SUBCATEGORY   VARCHAR(100),
    BRAND         VARCHAR(100),
    UNIT_PRICE    FLOAT,
    COST_PRICE    FLOAT,
    STOCK_QTY     NUMBER,
    IS_ACTIVE     NUMBER(1),
    CREATED_AT    DATE
);

CREATE TABLE IF NOT EXISTS RAW_ORDERS (
    ORDER_ID        NUMBER        NOT NULL,
    CUSTOMER_ID     NUMBER,
    ORDER_DATE      DATE,
    ORDER_STATUS    VARCHAR(50),
    CHANNEL         VARCHAR(100),
    PAYMENT_METHOD  VARCHAR(100),
    CITY            VARCHAR(100),
    STATE           VARCHAR(100),
    COUNTRY         VARCHAR(100),
    IS_GIFT         NUMBER(1)
);

CREATE TABLE IF NOT EXISTS RAW_ORDER_ITEMS (
    ITEM_ID       NUMBER    NOT NULL,
    ORDER_ID      NUMBER,
    PRODUCT_ID    NUMBER,
    QUANTITY      NUMBER,
    UNIT_PRICE    FLOAT,
    DISCOUNT_PCT  FLOAT,
    TOTAL_AMOUNT  FLOAT
);

CREATE TABLE IF NOT EXISTS RAW_RETURNS (
    RETURN_ID      NUMBER       NOT NULL,
    ITEM_ID        NUMBER,
    RETURN_DATE    DATE,
    RETURN_REASON  VARCHAR(200),
    RETURN_STATUS  VARCHAR(50),
    REFUND_AMOUNT  FLOAT
);

-- ─── 4. VERIFY LOAD (run after upload_to_snowflake.py) ───────
SELECT 'RAW_CUSTOMERS'   AS tbl, COUNT(*) AS row_count FROM RAW_CUSTOMERS   UNION ALL
SELECT 'RAW_PRODUCTS',          COUNT(*)               FROM RAW_PRODUCTS    UNION ALL
SELECT 'RAW_ORDERS',            COUNT(*)               FROM RAW_ORDERS      UNION ALL
SELECT 'RAW_ORDER_ITEMS',       COUNT(*)               FROM RAW_ORDER_ITEMS UNION ALL
SELECT 'RAW_RETURNS',           COUNT(*)               FROM RAW_RETURNS
ORDER BY tbl;

-- ─── 5. STREAMS (for CDC tracking into marts) ─────────────────
USE SCHEMA RAW;

CREATE STREAM IF NOT EXISTS STREAM_ORDERS
    ON TABLE RAW_ORDERS
    APPEND_ONLY = TRUE
    COMMENT = 'Tracks new orders for incremental dbt runs';

CREATE STREAM IF NOT EXISTS STREAM_ORDER_ITEMS
    ON TABLE RAW_ORDER_ITEMS
    APPEND_ONLY = TRUE
    COMMENT = 'Tracks new order items for incremental dbt runs';

-- ─── 6. FILE FORMAT (for Snowpipe / future streaming ingest) ──
CREATE FILE FORMAT IF NOT EXISTS ECOMM_PARQUET_FORMAT
    TYPE = 'PARQUET'
    SNAPPY_COMPRESSION = TRUE;

CREATE FILE FORMAT IF NOT EXISTS ECOMM_CSV_FORMAT
    TYPE             = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER      = 1
    NULL_IF          = ('NULL','null','')
    EMPTY_FIELD_AS_NULL = TRUE;

-- ─── 7. INTERNAL STAGE (optional bulk load alternative) ───────
CREATE STAGE IF NOT EXISTS ECOMM_RAW_STAGE
    FILE_FORMAT = ECOMM_PARQUET_FORMAT
    COMMENT     = 'Internal stage for bulk parquet loads';

-- PUT file://./generated_data/raw_customers.parquet @ECOMM_RAW_STAGE;
-- COPY INTO RAW_CUSTOMERS FROM @ECOMM_RAW_STAGE/raw_customers.parquet
--     FILE_FORMAT = ECOMM_PARQUET_FORMAT
--     MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;
