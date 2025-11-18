"""
Glue ETL Job: Transform Sales Data (Fixed for Parquet compatibility)
- Reads Parquet using Spark DataFrame directly
- Performs data quality checks and transformations
- Writes optimized Parquet to processed zone
"""

import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql import functions as F

# Initialize Glue context
args = getResolvedOptions(sys.argv, ['JOB_NAME'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# S3 bucket names
RAW_BUCKET = "data-lake-raw-zone-616129051451"
PROCESSED_BUCKET = "data-lake-processed-zone-616129051451"

print("=== Starting ETL Job: Transform Sales Data ===")

# Read Parquet files using specific path
input_path = f"s3://{RAW_BUCKET}/sales/year=2025/month=11/day=16/sales_20251116.parquet"
print(f"Reading sales Parquet data from: {input_path}")

sales_df = spark.read.parquet(input_path)

print(f"Total records read: {sales_df.count()}")
print("Schema:")
sales_df.printSchema()

# Data Transformations
print("Applying transformations...")

# 1. Convert date to string to avoid timestamp issues
sales_df = sales_df.withColumn("date_str", F.col("date").cast("string"))

# 2. Add date partitions
sales_df = sales_df.withColumn("processing_year", F.lit(2025))
sales_df = sales_df.withColumn("processing_month", F.lit(11))
sales_df = sales_df.withColumn("processing_day", F.lit(16))

# 3. Add metadata
sales_df = sales_df.withColumn("processed_date", F.current_date().cast("string"))
sales_df = sales_df.withColumn("data_source", F.lit("raw_sales_parquet"))

# 4. Data quality filters
sales_df = sales_df.filter(
    (F.col("transaction_id").isNotNull()) & 
    (F.col("total_amount") > 0)
)

# 5. Calculate business metrics
sales_df = sales_df.withColumn(
    "revenue_category",
    F.when(F.col("total_amount") < 100, "low")
     .when(F.col("total_amount") < 500, "medium")
     .otherwise("high")
)

sales_df = sales_df.withColumn(
    "avg_unit_price",
    F.col("total_amount") / F.col("quantity")
)

print(f"Records after transformations: {sales_df.count()}")

# Write to processed zone
output_path = f"s3://{PROCESSED_BUCKET}/sales/"

print(f"Writing transformed data to: {output_path}")

sales_df.write \
    .mode("overwrite") \
    .partitionBy("processing_year", "processing_month", "processing_day") \
    .option("compression", "snappy") \
    .parquet(output_path)

print("=== ETL Job Completed Successfully ===")
print(f"Output location: {output_path}")

sales_df.select("transaction_id", "customer_id", "total_amount", "revenue_category").show(5, truncate=False)

job.commit()
