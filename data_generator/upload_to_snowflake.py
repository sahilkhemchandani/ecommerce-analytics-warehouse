"""
Upload generated parquet files to Snowflake internal stage → COPY INTO raw tables.
Run AFTER generate_data.py.

Prerequisites:
    pip install snowflake-connector-python pandas pyarrow

Set env vars (or fill in constants below):
    SNOWFLAKE_ACCOUNT, SNOWFLAKE_USER, SNOWFLAKE_PASSWORD
"""

import os
import glob
import snowflake.connector
from snowflake.connector.pandas_tools import write_pandas
import pandas as pd
import time

# ─── CONFIG ── fill these or set as env vars ──────────────────────────────────
ACCOUNT   = os.getenv("SNOWFLAKE_ACCOUNT",  "your_account_identifier")   # e.g. abc12345.us-east-1
USER      = os.getenv("SNOWFLAKE_USER",     "your_username")
PASSWORD  = os.getenv("SNOWFLAKE_PASSWORD", "your_password")
WAREHOUSE = "ECOMM_WH"
DATABASE  = "ECOMM_DB"
RAW_SCHEMA = "RAW"
DATA_DIR   = "generated_data"

# ─── CONNECTION ───────────────────────────────────────────────────────────────
def get_conn():
    return snowflake.connector.connect(
        account=ACCOUNT,
        user=USER,
        password=PASSWORD,
        warehouse=WAREHOUSE,
        database=DATABASE,
        schema=RAW_SCHEMA,
    )


def load_table(conn, table_name: str, pattern: str, chunk_msg: str = ""):
    files = sorted(glob.glob(f"{DATA_DIR}/{pattern}"))
    print(f"\nLoading {table_name} — {len(files)} file(s) {chunk_msg}")
    t = time.time()
    total_rows = 0

    for i, fpath in enumerate(files):
        df = pd.read_parquet(fpath)

        # Normalize column names to uppercase for Snowflake
        df.columns = [c.upper() for c in df.columns]

        # Convert bool → int (Snowflake BOOLEAN via write_pandas can be finicky)
        for col in df.select_dtypes(include="bool").columns:
            df[col] = df[col].astype(int)

        # Convert datetime to string (Snowflake handles parsing)
        for col in df.select_dtypes(include=["datetime64"]).columns:
            df[col] = df[col].dt.strftime("%Y-%m-%d")

        success, nchunks, nrows, output = write_pandas(
            conn,
            df,
            table_name=table_name,
            auto_create_table=False,
            overwrite=(i == 0),   # overwrite only on first chunk, append rest
            quote_identifiers=False,
        )
        total_rows += nrows
        print(f"  [{i+1}/{len(files)}] {fpath} → {nrows:,} rows loaded")

    print(f"  ✓ {table_name} complete: {total_rows:,} rows in {time.time()-t:.1f}s")


def main():
    print("Connecting to Snowflake...")
    conn = get_conn()
    print(f"Connected → {DATABASE}.{RAW_SCHEMA} on {WAREHOUSE}")

    # Load in dependency order
    load_table(conn, "RAW_CUSTOMERS",    "raw_customers.parquet")
    load_table(conn, "RAW_PRODUCTS",     "raw_products.parquet")
    load_table(conn, "RAW_ORDERS",       "raw_orders_chunk_*.parquet",      "(chunked)")
    load_table(conn, "RAW_ORDER_ITEMS",  "raw_order_items_chunk_*.parquet", "(chunked)")
    load_table(conn, "RAW_RETURNS",      "raw_returns.parquet")

    conn.close()
    print("\n=== All tables loaded successfully ===")


if __name__ == "__main__":
    main()
