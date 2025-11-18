"""
Fix Parquet Files - Convert INT64 timestamps to compatible format
This script reads the problematic Parquet files and rewrites them with compatible timestamps
"""

import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq
import boto3
from io import BytesIO
from datetime import datetime

# Initialize S3 client
s3 = boto3.client('s3')

# Configuration
RAW_BUCKET = 'data-lake-raw-zone-616129051451'
PREFIXES = [
    'sales/year=2025/month=11/day=18/',
    'customers/year=2025/month=11/day=18/',
    'products/year=2025/month=11/day=18/'
]

def fix_parquet_file(bucket, key):
    """Download, fix timestamp, and re-upload Parquet file"""
    print(f"\nProcessing: s3://{bucket}/{key}")
    
    # Download file
    obj = s3.get_object(Bucket=bucket, Key=key)
    df = pd.read_parquet(BytesIO(obj['Body'].read()))
    
    print(f"  Records: {len(df)}")
    print(f"  Columns: {list(df.columns)}")
    
    # Convert all datetime columns to strings
    for col in df.columns:
        if pd.api.types.is_datetime64_any_dtype(df[col]):
            print(f"  Converting '{col}' column from {df[col].dtype} to string")
            df[col] = df[col].dt.strftime('%Y-%m-%d')
    
    # Write back with compatible schema
    buffer = BytesIO()
    
    # Create PyArrow table with explicit schema
    schema_fields = []
    for col in df.columns:
        if df[col].dtype == 'object':
            schema_fields.append(pa.field(col, pa.string()))
        elif df[col].dtype == 'int64':
            schema_fields.append(pa.field(col, pa.int64()))
        elif df[col].dtype == 'float64':
            schema_fields.append(pa.field(col, pa.float64()))
        elif df[col].dtype == 'bool':
            schema_fields.append(pa.field(col, pa.bool_()))
        else:
            # Convert everything else to string
            df[col] = df[col].astype(str)
            schema_fields.append(pa.field(col, pa.string()))
    
    schema = pa.schema(schema_fields)
    table = pa.Table.from_pandas(df, schema=schema, preserve_index=False)
    
    pq.write_table(table, buffer, compression='snappy')
    
    # Upload back to S3
    buffer.seek(0)
    s3.put_object(Bucket=bucket, Key=key, Body=buffer.getvalue())
    print(f"  ✅ Fixed and uploaded")

# Process all files
for prefix in PREFIXES:
    response = s3.list_objects_v2(Bucket=RAW_BUCKET, Prefix=prefix)
    
    if 'Contents' in response:
        for obj in response['Contents']:
            if obj['Key'].endswith('.parquet'):
                try:
                    fix_parquet_file(RAW_BUCKET, obj['Key'])
                except Exception as e:
                    print(f"  ❌ Error: {e}")

print("\n✅ All files processed!")
