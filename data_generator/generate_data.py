"""
E-Commerce Synthetic Data Generator
Generates ~20M+ rows across 5 tables for Snowflake DWH project.
Uses numpy vectorized ops — fast enough for large scale without Faker slowness.

Output: /generated_data/*.parquet (chunked)
"""

import numpy as np
import pandas as pd
from datetime import datetime, timedelta
import os
import time

# ─── CONFIG ──────────────────────────────────────────────────────────────────
N_CUSTOMERS   = 500_000
N_PRODUCTS    = 50_000
N_ORDERS      = 5_000_000
AVG_ITEMS     = 2.4        # avg items per order → ~12M order_items
RETURN_RATE   = 0.10       # 10% of items returned → ~1.2M returns
CHUNK_SIZE    = 500_000
OUTPUT_DIR    = "generated_data"
SEED          = 42
START_DATE    = datetime(2022, 1, 1)
END_DATE      = datetime(2024, 12, 31)

np.random.seed(SEED)
os.makedirs(OUTPUT_DIR, exist_ok=True)

# ─── LOOKUP POOLS ─────────────────────────────────────────────────────────────
CITIES = [
    "Mumbai","Delhi","Bangalore","Hyderabad","Chennai","Kolkata","Pune","Ahmedabad",
    "Jaipur","Surat","Lucknow","Kanpur","Nagpur","Indore","Bhopal","Visakhapatnam",
    "New York","Los Angeles","Chicago","Houston","Phoenix","San Antonio","Dallas",
    "London","Manchester","Birmingham","Leeds","Glasgow","Edinburgh","Bristol"
]
STATES = [
    "Maharashtra","Delhi","Karnataka","Telangana","Tamil Nadu","West Bengal",
    "Rajasthan","Gujarat","Uttar Pradesh","Madhya Pradesh","California","Texas",
    "New York","Florida","Illinois","England","Scotland","Wales"
]
COUNTRIES    = ["India"] * 15 + ["USA"] * 8 + ["UK"] * 7
SEGMENTS     = ["B2C", "B2B", "Premium", "Budget"]
SEG_WEIGHTS  = [0.55, 0.20, 0.15, 0.10]

CATEGORIES = {
    "Electronics":    ["Smartphones","Laptops","Tablets","Headphones","Cameras","Smart Watches","Speakers"],
    "Fashion":        ["Men Clothing","Women Clothing","Footwear","Accessories","Bags","Sunglasses"],
    "Home & Kitchen": ["Furniture","Cookware","Appliances","Decor","Bedding","Storage"],
    "Sports":         ["Fitness Equipment","Outdoor Gear","Cycling","Swimming","Team Sports"],
    "Books":          ["Fiction","Non-Fiction","Technical","Children","Comics","Self-Help"],
    "Beauty":         ["Skincare","Haircare","Makeup","Fragrances","Personal Care"],
    "Grocery":        ["Snacks","Beverages","Dairy","Packaged Foods","Organic"],
}
BRANDS = [
    "Samsung","Apple","Nike","Adidas","Sony","LG","Philips","Boat","OnePlus","Xiaomi",
    "H&M","Zara","Ikea","Prestige","Hawkins","Puma","Reebok","WildCraft","Himalaya",
    "Nestle","Britannia","Amul","Generic","OEM Brand","House Brand"
]
CHANNELS        = ["Website","Mobile App","Marketplace","Retail Partner","WhatsApp Commerce"]
CHANNEL_WEIGHTS = [0.35, 0.30, 0.25, 0.07, 0.03]
PAYMENT_METHODS = ["Credit Card","Debit Card","UPI","Net Banking","Wallet","COD","EMI"]
PAY_WEIGHTS     = [0.22, 0.18, 0.25, 0.10, 0.10, 0.10, 0.05]
ORDER_STATUSES  = ["Delivered","Shipped","Processing","Cancelled","Refunded","Pending"]
ORD_WEIGHTS     = [0.70, 0.12, 0.05, 0.07, 0.04, 0.02]
RETURN_REASONS  = ["Defective","Wrong Item","Not As Described","Changed Mind","Better Price","Damaged In Transit"]


def random_dates(n, start=START_DATE, end=END_DATE):
    delta = (end - start).days
    offsets = np.random.randint(0, delta, size=n)
    return pd.to_datetime(start) + pd.to_timedelta(offsets, unit="D")


# ─── 1. CUSTOMERS ─────────────────────────────────────────────────────────────
def generate_customers():
    print(f"  Generating {N_CUSTOMERS:,} customers...")
    t = time.time()
    df = pd.DataFrame({
        "customer_id":    np.arange(1, N_CUSTOMERS + 1),
        "first_name":     [f"FirstName_{i}" for i in range(N_CUSTOMERS)],
        "last_name":      [f"LastName_{i}"  for i in range(N_CUSTOMERS)],
        "email":          [f"user_{i}@email.com" for i in range(N_CUSTOMERS)],
        "city":           np.random.choice(CITIES,   N_CUSTOMERS),
        "state":          np.random.choice(STATES,   N_CUSTOMERS),
        "country":        np.random.choice(COUNTRIES, N_CUSTOMERS),
        "segment":        np.random.choice(SEGMENTS, N_CUSTOMERS, p=SEG_WEIGHTS),
        "created_at":     random_dates(N_CUSTOMERS, START_DATE, END_DATE),
        "is_active":      np.random.choice([True, False], N_CUSTOMERS, p=[0.92, 0.08]),
        "lifetime_orders": np.random.randint(1, 80, N_CUSTOMERS),
    })
    path = f"{OUTPUT_DIR}/raw_customers.parquet"
    df.to_parquet(path, index=False)
    print(f"  ✓ customers done in {time.time()-t:.1f}s → {path}")
    return df["customer_id"].values


# ─── 2. PRODUCTS ──────────────────────────────────────────────────────────────
def generate_products():
    print(f"  Generating {N_PRODUCTS:,} products...")
    t = time.time()
    cats, subcats = [], []
    for cat, subs in CATEGORIES.items():
        for sub in subs:
            cats.append(cat)
            subcats.append(sub)
    cat_idx = np.random.randint(0, len(cats), N_PRODUCTS)

    unit_prices = np.round(np.random.lognormal(mean=4.5, sigma=1.2, size=N_PRODUCTS), 2)
    unit_prices = np.clip(unit_prices, 5, 150_000)
    cost_prices = np.round(unit_prices * np.random.uniform(0.40, 0.75, N_PRODUCTS), 2)

    df = pd.DataFrame({
        "product_id":     np.arange(1, N_PRODUCTS + 1),
        "product_name":   [f"Product_{i}_{subcats[cat_idx[i]]}" for i in range(N_PRODUCTS)],
        "category":       [cats[i] for i in cat_idx],
        "subcategory":    [subcats[i] for i in cat_idx],
        "brand":          np.random.choice(BRANDS, N_PRODUCTS),
        "unit_price":     unit_prices,
        "cost_price":     cost_prices,
        "stock_qty":      np.random.randint(0, 5000, N_PRODUCTS),
        "is_active":      np.random.choice([True, False], N_PRODUCTS, p=[0.88, 0.12]),
        "created_at":     random_dates(N_PRODUCTS, START_DATE, datetime(2022, 6, 1)),
    })
    path = f"{OUTPUT_DIR}/raw_products.parquet"
    df.to_parquet(path, index=False)
    print(f"  ✓ products done in {time.time()-t:.1f}s → {path}")
    return df["product_id"].values, df["unit_price"].values


# ─── 3. ORDERS (chunked) ──────────────────────────────────────────────────────
def generate_orders(customer_ids):
    print(f"  Generating {N_ORDERS:,} orders in chunks of {CHUNK_SIZE:,}...")
    t = time.time()
    total_chunks = (N_ORDERS + CHUNK_SIZE - 1) // CHUNK_SIZE
    order_id_counter = 1

    for chunk_i in range(total_chunks):
        n = min(CHUNK_SIZE, N_ORDERS - (chunk_i * CHUNK_SIZE))
        ids = np.arange(order_id_counter, order_id_counter + n)
        order_dates = random_dates(n)

        df = pd.DataFrame({
            "order_id":       ids,
            "customer_id":    np.random.choice(customer_ids, n),
            "order_date":     order_dates,
            "order_status":   np.random.choice(ORDER_STATUSES, n, p=ORD_WEIGHTS),
            "channel":        np.random.choice(CHANNELS, n, p=CHANNEL_WEIGHTS),
            "payment_method": np.random.choice(PAYMENT_METHODS, n, p=PAY_WEIGHTS),
            "city":           np.random.choice(CITIES, n),
            "state":          np.random.choice(STATES, n),
            "country":        np.random.choice(COUNTRIES, n),
            "is_gift":        np.random.choice([True, False], n, p=[0.08, 0.92]),
        })

        path = f"{OUTPUT_DIR}/raw_orders_chunk_{chunk_i:04d}.parquet"
        df.to_parquet(path, index=False)
        order_id_counter += n
        print(f"  chunk {chunk_i+1}/{total_chunks} done — {order_id_counter-1:,} orders written")

    print(f"  ✓ orders done in {time.time()-t:.1f}s")
    return np.arange(1, N_ORDERS + 1)


# ─── 4. ORDER ITEMS (chunked) ─────────────────────────────────────────────────
def generate_order_items(order_ids, product_ids, product_prices):
    """
    Randomly assign 1–5 items per order using a geometric-like distribution.
    Target: ~12M rows total.
    """
    print(f"  Generating order items (~{int(N_ORDERS * AVG_ITEMS / 1e6)}M rows)...")
    t = time.time()
    item_id_counter = 1
    chunk_orders = np.array_split(order_ids, len(order_ids) // CHUNK_SIZE + 1)

    for ci, order_chunk in enumerate(chunk_orders):
        # items per order: 1–5, weighted toward lower
        items_per_order = np.random.choice([1,2,3,4,5], len(order_chunk), p=[0.30,0.35,0.20,0.10,0.05])
        oids = np.repeat(order_chunk, items_per_order)
        n = len(oids)

        prod_idx     = np.random.randint(0, len(product_ids), n)
        unit_prices  = product_prices[prod_idx]
        discounts    = np.round(np.random.choice([0,0.05,0.10,0.15,0.20,0.25,0.30], n,
                                 p=[0.40,0.15,0.15,0.10,0.10,0.07,0.03]), 2)
        quantities   = np.random.randint(1, 6, n)
        totals       = np.round(unit_prices * quantities * (1 - discounts), 2)

        df = pd.DataFrame({
            "item_id":       np.arange(item_id_counter, item_id_counter + n),
            "order_id":      oids,
            "product_id":    product_ids[prod_idx],
            "quantity":      quantities,
            "unit_price":    np.round(unit_prices, 2),
            "discount_pct":  discounts,
            "total_amount":  totals,
        })

        path = f"{OUTPUT_DIR}/raw_order_items_chunk_{ci:04d}.parquet"
        df.to_parquet(path, index=False)
        item_id_counter += n
        print(f"  items chunk {ci+1}/{len(chunk_orders)} → {item_id_counter-1:,} items total")

    print(f"  ✓ order items done in {time.time()-t:.1f}s")
    return item_id_counter - 1


# ─── 5. RETURNS ───────────────────────────────────────────────────────────────
def generate_returns(total_items):
    n_returns = int(total_items * RETURN_RATE)
    print(f"  Generating {n_returns:,} returns...")
    t = time.time()

    # Sample return item_ids randomly
    return_item_ids = np.random.choice(total_items, n_returns, replace=False) + 1
    return_dates    = random_dates(n_returns, datetime(2022, 2, 1), END_DATE)

    df = pd.DataFrame({
        "return_id":     np.arange(1, n_returns + 1),
        "item_id":       return_item_ids,
        "return_date":   return_dates,
        "return_reason": np.random.choice(RETURN_REASONS, n_returns),
        "return_status": np.random.choice(["Approved","Rejected","Pending"], n_returns, p=[0.78,0.12,0.10]),
        "refund_amount": np.round(np.random.uniform(50, 15000, n_returns), 2),
    })

    path = f"{OUTPUT_DIR}/raw_returns.parquet"
    df.to_parquet(path, index=False)
    print(f"  ✓ returns done in {time.time()-t:.1f}s → {path}")


# ─── MAIN ─────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("\n=== E-Commerce Data Generator ===\n")
    overall = time.time()

    print("[1/5] Customers")
    customer_ids = generate_customers()

    print("\n[2/5] Products")
    product_ids, product_prices = generate_products()

    print("\n[3/5] Orders")
    order_ids = generate_orders(customer_ids)

    print("\n[4/5] Order Items")
    total_items = generate_order_items(order_ids, product_ids, product_prices)

    print("\n[5/5] Returns")
    generate_returns(total_items)

    print(f"\n=== Done in {(time.time()-overall)/60:.1f} minutes ===")
    print(f"Output: ./{OUTPUT_DIR}/")
    print("\nRow counts:")
    print(f"  customers:   {N_CUSTOMERS:>12,}")
    print(f"  products:    {N_PRODUCTS:>12,}")
    print(f"  orders:      {N_ORDERS:>12,}")
    print(f"  order_items: ~{int(N_ORDERS * AVG_ITEMS):>11,}")
    print(f"  returns:     ~{int(N_ORDERS * AVG_ITEMS * RETURN_RATE):>11,}")
    print(f"  TOTAL:       ~{N_CUSTOMERS + N_PRODUCTS + N_ORDERS + int(N_ORDERS*AVG_ITEMS) + int(N_ORDERS*AVG_ITEMS*RETURN_RATE):>11,}")
