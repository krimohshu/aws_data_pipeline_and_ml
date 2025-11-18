# Parquet vs CSV/JSON in Data Pipelines

## ✅ Why Use Parquet?

### 1. **Columnar Storage**
- Parquet stores data in columns, not rows
- Only read columns you need (not entire rows)
- Perfect for analytics queries

```sql
-- Only reads 'total_amount' column, not all 9 columns
SELECT SUM(total_amount) FROM sales;
```

### 2. **Better Compression**
- Built-in compression (Snappy, Gzip, LZ4)
- Typically 75-90% smaller than CSV
- Faster network transfer

### 3. **Schema Preservation**
- Stores data types (int, float, date, etc.)
- No need to infer schema every time
- Prevents type conversion errors

### 4. **Performance**
- 10-100x faster queries in Athena/Spark
- Predicate pushdown optimization
- Automatic statistics for query planning

### 5. **AWS Native Support**
- Glue natively reads/writes Parquet
- Athena optimized for Parquet
- EMR Spark prefers Parquet
- SageMaker works great with Parquet

## 📊 File Comparison (Our Data)

| Format | Sales File | Customers File | Products File |
|--------|-----------|----------------|---------------|
| CSV/JSON | 1.1 KB | 1.6 KB | 1.4 KB |
| Parquet | 6.0 KB | 4.4 KB | 4.0 KB |

**Note**: Small files show overhead. With 1M+ rows, Parquet is much smaller!

## 🎯 When to Use Each Format

### Use Parquet for:
- ✅ **Processed Zone** - Analytics-ready data
- ✅ **Curated Zone** - Dashboard data
- ✅ **Athena queries** - Fast columnar scans
- ✅ **EMR processing** - Spark native format
- ✅ **Large datasets** - 1GB+ files

### Use CSV/JSON for:
- ✅ **Raw Zone** - Original data ingestion
- ✅ **Human readable** - Quick inspection
- ✅ **External systems** - API responses
- ✅ **Small files** - <1MB

## 📁 Recommended Data Lake Structure

```
S3 Data Lake:
├── Raw Zone (Original formats: CSV, JSON, XML)
│   └── sales/year=2025/month=11/day=16/
│       ├── sales_20251116.csv         ← As received
│       └── sales_20251116.json        ← As received
│
├── Processed Zone (Parquet, cleaned)
│   └── sales_clean/year=2025/month=11/day=16/
│       └── part-00000.parquet         ← Glue output
│
└── Curated Zone (Parquet, aggregated)
    └── sales_by_region/
        └── data.parquet               ← Analytics-ready
```

## 🔄 Conversion Workflow

```python
# 1. Ingest as CSV/JSON (Raw Zone)
Lambda → S3 Raw Zone (CSV/JSON)

# 2. Convert to Parquet (Processed Zone)
Glue ETL Job:
  - Read CSV/JSON from Raw
  - Clean and transform
  - Write Parquet to Processed
  
# 3. Query with Athena
SELECT * FROM processed.sales
WHERE date >= '2025-11-01'
```

## 💻 Working with Parquet Files

### Read Parquet in Python
```python
import pandas as pd

# Read Parquet
df = pd.read_parquet('sales_data.parquet')

# Read specific columns only
df = pd.read_parquet('sales_data.parquet', 
                     columns=['date', 'total_amount'])
```

### Read Parquet with PySpark
```python
from pyspark.sql import SparkSession
spark = SparkSession.builder.getOrCreate()

# Read Parquet
df = spark.read.parquet('s3://bucket/sales/*.parquet')

# Auto-discovery of partitions
df = spark.read.parquet('s3://bucket/sales/year=2025/month=11/')
```

### Query Parquet with Athena
```sql
CREATE EXTERNAL TABLE sales (
  transaction_id STRING,
  date DATE,
  customer_id STRING,
  total_amount DOUBLE
)
STORED AS PARQUET
LOCATION 's3://bucket/processed/sales/'
PARTITIONED BY (year INT, month INT, day INT);
```

## 🚀 Convert Script

We've created `scripts/convert_to_parquet.py` that:
- ✅ Converts CSV → Parquet
- ✅ Converts JSON → Parquet
- ✅ Preserves data types
- ✅ Uses Snappy compression
- ✅ Shows file sizes

### Usage:
```bash
# Convert all sample data
python scripts/convert_to_parquet.py

# Output:
# - sales_data.parquet
# - customers_data.parquet
# - products_data.parquet
```

## 📈 Performance Comparison

### Athena Query Cost (1TB dataset)

| Format | Data Scanned | Cost | Speed |
|--------|-------------|------|-------|
| CSV | 1 TB | $5.00 | 60s |
| Parquet | 100 GB | $0.50 | 6s |

**Savings: 90% cost reduction, 10x faster!**

### EMR Processing Time (1 billion rows)

| Format | Processing Time | Cost |
|--------|----------------|------|
| CSV | 45 minutes | $15 |
| Parquet | 5 minutes | $2 |

## 🎓 Best Practices

1. **Raw → Processed Pipeline**
   - Ingest as CSV/JSON (flexibility)
   - Convert to Parquet immediately (performance)
   - Keep raw for audit/reprocessing

2. **Partitioning**
   ```
   /sales/year=2025/month=11/day=16/data.parquet
   ```
   - Athena scans only needed partitions
   - Huge cost savings

3. **File Sizes**
   - Target 100-200 MB per Parquet file
   - Too small = overhead
   - Too large = less parallelism

4. **Compression**
   - Snappy: Fast, good compression
   - Gzip: Better compression, slower
   - Use Snappy for most cases

5. **Schema Evolution**
   - Parquet handles new columns gracefully
   - Old readers ignore new columns
   - Plan schema changes carefully

## 📦 Our Implementation

### Current Setup:
✅ Sample data in both CSV/JSON and Parquet
✅ Conversion script ready
✅ S3 structure for both formats
✅ Ready for Glue ETL (next module)

### Next Steps:
1. Create Glue Crawler (Module 4)
2. Set up ETL job: CSV → Parquet
3. Query with Athena
4. Build dashboards in QuickSight

## 🔗 Resources

- [Apache Parquet Documentation](https://parquet.apache.org/docs/)
- [AWS Big Data Blog on Parquet](https://aws.amazon.com/blogs/big-data/tag/parquet/)
- [Athena Performance Tuning](https://docs.aws.amazon.com/athena/latest/ug/performance-tuning.html)
- [Pandas Parquet Guide](https://pandas.pydata.org/docs/reference/api/pandas.DataFrame.to_parquet.html)

---

**Key Takeaway**: Use CSV/JSON for ingestion (Raw Zone), convert to Parquet for analytics (Processed/Curated Zones). This gives you flexibility + performance!
