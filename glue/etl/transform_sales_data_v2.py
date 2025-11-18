"""
AWS Glue ETL Job: Transform Sales Data (Production-Ready Version)

This job performs comprehensive ETL operations:
1. Reads sales data from Glue Data Catalog
2. Applies data quality checks and filters
3. Enriches data with calculated fields
4. Aggregates daily summaries
5. Writes optimized Parquet to processed zone

Author: Data Pipeline Team
Version: 2.0
"""

import sys
from datetime import datetime
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.dynamicframe import DynamicFrame
from pyspark.sql import functions as F
from pyspark.sql.window import Window

# ============================================================================
# INITIALIZATION
# ============================================================================

# Parse job arguments
args = getResolvedOptions(sys.argv, [
    'JOB_NAME',
    'DATABASE_NAME',
    'TABLE_NAME',
    'OUTPUT_BUCKET',
    'OUTPUT_PATH'
])

# Initialize Glue context
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# Configuration
DATABASE_NAME = args['DATABASE_NAME']
TABLE_NAME = args['TABLE_NAME']
OUTPUT_BUCKET = args['OUTPUT_BUCKET']
OUTPUT_PATH = args['OUTPUT_PATH']

print(f"""
{'='*80}
AWS Glue ETL Job Started
{'='*80}
Job Name:      {args['JOB_NAME']}
Database:      {DATABASE_NAME}
Table:         {TABLE_NAME}
Output Bucket: {OUTPUT_BUCKET}
Output Path:   {OUTPUT_PATH}
Start Time:    {datetime.now().isoformat()}
{'='*80}
""")

# ============================================================================
# DATA EXTRACTION
# ============================================================================

print("\n[STEP 1/5] Reading data from Glue Data Catalog...")

# Read Parquet files directly from S3 with schema inference disabled for problematic types
# Construct S3 path from table name
raw_bucket = "data-lake-raw-zone-616129051451"
table_path = f"s3://{raw_bucket}/{TABLE_NAME}/"

print(f"Reading Parquet data from: {table_path}")

# Read with mergeSchema to handle different parquet schemas
df = spark.read \
    .option("mergeSchema", "true") \
    .option("timestampFormat", "yyyy-MM-dd HH:mm:ss") \
    .parquet(table_path)

# Convert date column immediately to avoid timestamp issues
if 'date' in df.columns:
    df = df.withColumn('date', F.col('date').cast('string'))

initial_count = df.count()
print(f"✅ Successfully read {initial_count:,} records from {table_path}")
print("\n📋 Input Schema:")
df.printSchema()

# ============================================================================
# DATA QUALITY CHECKS
# ============================================================================

print("\n[STEP 2/5] Applying data quality checks...")

# Quality metrics before filtering
quality_metrics = {
    'total_records': initial_count,
    'null_transaction_ids': df.filter(F.col('transaction_id').isNull()).count(),
    'null_amounts': df.filter(F.col('total_amount').isNull()).count(),
    'negative_amounts': df.filter(F.col('total_amount') < 0).count(),
    'zero_quantities': df.filter(F.col('quantity') <= 0).count()
}

print("📊 Data Quality Report (Before Cleaning):")
for metric, value in quality_metrics.items():
    print(f"  • {metric}: {value:,}")

# Apply quality filters
df_clean = df.filter(
    (F.col('transaction_id').isNotNull()) &
    (F.col('customer_id').isNotNull()) &
    (F.col('product_id').isNotNull()) &
    (F.col('total_amount').isNotNull()) &
    (F.col('total_amount') > 0) &
    (F.col('quantity').isNotNull()) &
    (F.col('quantity') > 0) &
    (F.col('unit_price').isNotNull()) &
    (F.col('unit_price') > 0)
)

clean_count = df_clean.count()
rejected_count = initial_count - clean_count
print(f"\n✅ Data quality checks complete:")
print(f"  • Accepted: {clean_count:,} records ({(clean_count/initial_count)*100:.2f}%)")
print(f"  • Rejected: {rejected_count:,} records ({(rejected_count/initial_count)*100:.2f}%)")

# ============================================================================
# DATA ENRICHMENT
# ============================================================================

print("\n[STEP 3/5] Enriching data with calculated fields...")

# Add processing timestamp
df_enriched = df_clean.withColumn(
    'processing_timestamp',
    F.current_timestamp().cast('string')
)

# Add processing date for partitioning
df_enriched = df_enriched.withColumn(
    'processing_date',
    F.current_date().cast('string')
)

# Extract date components from transaction date (date is already string)
df_enriched = df_enriched.withColumn(
    'transaction_date',
    F.to_date(F.col('date'), 'yyyy-MM-dd')
)

df_enriched = df_enriched.withColumn(
    'day_of_week',
    F.date_format(F.col('transaction_date'), 'EEEE')
)

df_enriched = df_enriched.withColumn(
    'is_weekend',
    F.when(F.dayofweek(F.col('transaction_date')).isin([1, 7]), True).otherwise(False)
)

df_enriched = df_enriched.withColumn(
    'month_name',
    F.date_format(F.col('transaction_date'), 'MMMM')
)

# Calculate derived metrics
df_enriched = df_enriched.withColumn(
    'calculated_total',
    F.round(F.col('quantity') * F.col('unit_price'), 2)
)

df_enriched = df_enriched.withColumn(
    'amount_validation',
    F.when(
        F.abs(F.col('total_amount') - F.col('calculated_total')) < 0.01,
        'VALID'
    ).otherwise('MISMATCH')
)

# Categorize revenue
df_enriched = df_enriched.withColumn(
    'revenue_category',
    F.when(F.col('total_amount') < 50, 'low')
     .when(F.col('total_amount') < 200, 'medium')
     .when(F.col('total_amount') < 500, 'high')
     .otherwise('premium')
)

# Categorize quantity
df_enriched = df_enriched.withColumn(
    'order_size',
    F.when(F.col('quantity') == 1, 'single')
     .when(F.col('quantity') <= 3, 'small')
     .when(F.col('quantity') <= 5, 'medium')
     .otherwise('bulk')
)

# Calculate discount (if unit_price * quantity != total_amount)
df_enriched = df_enriched.withColumn(
    'discount_amount',
    F.round(F.col('calculated_total') - F.col('total_amount'), 2)
)

df_enriched = df_enriched.withColumn(
    'discount_percentage',
    F.when(
        F.col('calculated_total') > 0,
        F.round((F.col('discount_amount') / F.col('calculated_total')) * 100, 2)
    ).otherwise(0)
)

# Add row number for duplicate detection
window_spec = Window.partitionBy('transaction_id').orderBy('transaction_date')
df_enriched = df_enriched.withColumn(
    'row_number',
    F.row_number().over(window_spec)
)

# Keep only first occurrence of each transaction_id
df_enriched = df_enriched.filter(F.col('row_number') == 1).drop('row_number')

print(f"✅ Enrichment complete: Added 13 calculated fields")
print("\n📋 Sample enriched data:")
df_enriched.select(
    'transaction_id',
    'customer_id',
    'total_amount',
    'revenue_category',
    'day_of_week',
    'is_weekend',
    'discount_percentage'
).show(5, truncate=False)

# ============================================================================
# AGGREGATIONS (Optional Daily Summary)
# ============================================================================

print("\n[STEP 4/5] Creating daily summary aggregations...")

daily_summary = df_enriched.groupBy(
    F.col('year'),
    F.col('month'),
    F.col('day'),
    F.col('region')
).agg(
    F.count('transaction_id').alias('total_transactions'),
    F.sum('total_amount').alias('total_revenue'),
    F.avg('total_amount').alias('avg_transaction_value'),
    F.min('total_amount').alias('min_transaction'),
    F.max('total_amount').alias('max_transaction'),
    F.sum('quantity').alias('total_units_sold'),
    F.countDistinct('customer_id').alias('unique_customers'),
    F.countDistinct('product_id').alias('unique_products'),
    F.count(F.when(F.col('is_weekend') == True, 1)).alias('weekend_transactions'),
    F.sum(F.when(F.col('payment_method') == 'credit_card', 1).otherwise(0)).alias('credit_card_count'),
    F.sum(F.when(F.col('payment_method') == 'paypal', 1).otherwise(0)).alias('paypal_count'),
    F.sum(F.when(F.col('payment_method') == 'debit_card', 1).otherwise(0)).alias('debit_card_count')
).withColumn(
    'processing_date',
    F.current_date()
)

print(f"✅ Daily summary created")
print("\n📊 Summary Statistics by Region:")
daily_summary.show(20, truncate=False)

# ============================================================================
# DATA LOAD (Write to S3)
# ============================================================================

print("\n[STEP 5/5] Writing transformed data to S3...")

# Write detailed transactions to processed zone
detail_output_path = f"s3://{OUTPUT_BUCKET}/{OUTPUT_PATH}/transactions/"
print(f"\n📝 Writing detailed transactions to: {detail_output_path}")

df_enriched.write \
    .mode('overwrite') \
    .partitionBy('year', 'month', 'day') \
    .option('compression', 'snappy') \
    .parquet(detail_output_path)

detail_record_count = df_enriched.count()
print(f"✅ Successfully wrote {detail_record_count:,} records")

# Write daily summary to aggregated zone
summary_output_path = f"s3://{OUTPUT_BUCKET}/{OUTPUT_PATH}/daily_summary/"
print(f"\n📝 Writing daily summary to: {summary_output_path}")

daily_summary.write \
    .mode('overwrite') \
    .partitionBy('year', 'month', 'day') \
    .option('compression', 'snappy') \
    .parquet(summary_output_path)

summary_record_count = daily_summary.count()
print(f"✅ Successfully wrote {summary_record_count:,} summary records")

# ============================================================================
# JOB COMPLETION
# ============================================================================

end_time = datetime.now()
print(f"""
{'='*80}
AWS Glue ETL Job Completed Successfully
{'='*80}
Processing Summary:
  • Input Records:      {initial_count:,}
  • Rejected Records:   {rejected_count:,}
  • Output Records:     {detail_record_count:,}
  • Summary Records:    {summary_record_count:,}
  
Output Locations:
  • Transactions: {detail_output_path}
  • Summary:      {summary_output_path}

End Time: {end_time.isoformat()}
{'='*80}
""")

# Commit job
job.commit()
