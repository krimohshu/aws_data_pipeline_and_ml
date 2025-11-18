#!/usr/bin/env python3
"""
Convert CSV and JSON sample data to Parquet format
Parquet is columnar, compressed, and optimized for analytics
"""
import pandas as pd
import json
from pathlib import Path

# Define paths
base_dir = Path(__file__).parent.parent
sample_data_dir = base_dir / "sample_data"

print("Converting sample data to Parquet format...")
print("=" * 50)

# 1. Convert sales CSV to Parquet
print("\n1. Converting sales_data.csv to Parquet...")
sales_df = pd.read_csv(sample_data_dir / "sales_data.csv")
print(f"   Loaded {len(sales_df)} sales records")

# Convert date column to datetime
sales_df['date'] = pd.to_datetime(sales_df['date'])

# Save as Parquet with compression
sales_parquet_path = sample_data_dir / "sales_data.parquet"
sales_df.to_parquet(sales_parquet_path, compression='snappy', index=False)
print(f"   ✅ Saved to: {sales_parquet_path}")

# Show file sizes
csv_size = (sample_data_dir / "sales_data.csv").stat().st_size
parquet_size = sales_parquet_path.stat().st_size
compression_ratio = (1 - parquet_size / csv_size) * 100
print(f"   CSV size: {csv_size:,} bytes")
print(f"   Parquet size: {parquet_size:,} bytes")
print(f"   Compression: {compression_ratio:.1f}% reduction")

# 2. Convert customers JSON to Parquet
print("\n2. Converting customers_data.json to Parquet...")
with open(sample_data_dir / "customers_data.json", 'r') as f:
    customers_data = json.load(f)
customers_df = pd.DataFrame(customers_data)
print(f"   Loaded {len(customers_df)} customer records")

# Convert date column
customers_df['signup_date'] = pd.to_datetime(customers_df['signup_date'])

customers_parquet_path = sample_data_dir / "customers_data.parquet"
customers_df.to_parquet(customers_parquet_path, compression='snappy', index=False)
print(f"   ✅ Saved to: {customers_parquet_path}")

json_size = (sample_data_dir / "customers_data.json").stat().st_size
parquet_size = customers_parquet_path.stat().st_size
compression_ratio = (1 - parquet_size / json_size) * 100
print(f"   JSON size: {json_size:,} bytes")
print(f"   Parquet size: {parquet_size:,} bytes")
print(f"   Compression: {compression_ratio:.1f}% reduction")

# 3. Convert products JSON to Parquet
print("\n3. Converting products_data.json to Parquet...")
with open(sample_data_dir / "products_data.json", 'r') as f:
    products_data = json.load(f)
products_df = pd.DataFrame(products_data)
print(f"   Loaded {len(products_df)} product records")

products_parquet_path = sample_data_dir / "products_data.parquet"
products_df.to_parquet(products_parquet_path, compression='snappy', index=False)
print(f"   ✅ Saved to: {products_parquet_path}")

json_size = (sample_data_dir / "products_data.json").stat().st_size
parquet_size = products_parquet_path.stat().st_size
compression_ratio = (1 - parquet_size / json_size) * 100
print(f"   JSON size: {json_size:,} bytes")
print(f"   Parquet size: {parquet_size:,} bytes")
print(f"   Compression: {compression_ratio:.1f}% reduction")

# Display schema information
print("\n" + "=" * 50)
print("Parquet Schema Information:")
print("=" * 50)

print("\nSales Data Schema:")
print(sales_df.dtypes)

print("\nCustomers Data Schema:")
print(customers_df.dtypes)

print("\nProducts Data Schema:")
print(products_df.dtypes)

print("\n✅ All conversions complete!")
print("\nParquet files created:")
print(f"  - {sales_parquet_path}")
print(f"  - {customers_parquet_path}")
print(f"  - {products_parquet_path}")
