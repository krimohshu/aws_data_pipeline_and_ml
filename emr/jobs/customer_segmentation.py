"""
EMR Spark Job: Customer Segmentation using K-Means Clustering
--------------------------------------------------------------
This job demonstrates advanced Spark ML capabilities on EMR:
- Feature engineering from multiple data sources
- ML clustering (K-Means)
- Distributed processing across cluster nodes
- Optimized Parquet output with partitioning
"""

from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import IntegerType
from pyspark.ml.feature import VectorAssembler, StandardScaler
from pyspark.ml.clustering import KMeans
from pyspark.ml.evaluation import ClusteringEvaluator
import sys

def main():
    # Initialize Spark Session with EMR-optimized config
    spark = SparkSession.builder \
        .appName("CustomerSegmentation") \
        .config("spark.sql.adaptive.enabled", "true") \
        .config("spark.sql.adaptive.coalescePartitions.enabled", "true") \
        .getOrCreate()
    
    print("=" * 70)
    print("EMR Spark Job: Customer Segmentation")
    print("=" * 70)
    
    # S3 paths (change account ID as needed)
    PROCESSED_BUCKET = "data-lake-processed-zone-616129051451"
    CURATED_BUCKET = "data-lake-curated-zone-616129051451"
    
    # Read processed data from S3
    print("\n[1/6] Reading sales data from S3...")
    sales_df = spark.read.parquet(f"s3://{PROCESSED_BUCKET}/sales_enriched/transactions/")
    print(f"   → Loaded {sales_df.count():,} sales transactions")
    
    print("\n[2/6] Aggregating customer features...")
    # Feature Engineering: RFM (Recency, Frequency, Monetary)
    customer_features = sales_df.groupBy("customer_id").agg(
        # Monetary: Total amount spent
        F.sum("total_amount").alias("total_spent"),
        
        # Frequency: Number of purchases
        F.count("transaction_id").alias("purchase_count"),
        
        # Average basket metrics
        F.avg("quantity").alias("avg_basket_size"),
        F.avg("total_amount").alias("avg_transaction_value"),
        
        # Recency: Days since last purchase
        F.max(F.col("transaction_date")).alias("last_purchase_date"),
        
        # Region (mode)
        F.first("region").alias("primary_region"),
        
        # Payment method preference
        F.first("payment_method").alias("preferred_payment")
    )
    
    # Calculate recency (days since last purchase)
    customer_features = customer_features.withColumn(
        "days_since_purchase",
        F.datediff(F.current_date(), F.col("last_purchase_date").cast("date"))
    )
    
    # Add derived metrics
    customer_features = customer_features.withColumn(
        "avg_days_between_purchases",
        F.col("days_since_purchase") / F.col("purchase_count")
    )
    
    print(f"   → Engineered features for {customer_features.count():,} customers")
    
    # Show sample data
    print("\n[3/6] Sample customer features:")
    customer_features.select(
        "customer_id", "total_spent", "purchase_count", 
        "days_since_purchase", "primary_region"
    ).show(5, truncate=False)
    
    # Prepare features for ML
    print("\n[4/6] Preparing ML features...")
    feature_cols = [
        "total_spent",
        "purchase_count", 
        "avg_basket_size",
        "days_since_purchase"
    ]
    
    # Assemble feature vector
    assembler = VectorAssembler(
        inputCols=feature_cols,
        outputCol="features_raw"
    )
    assembled_df = assembler.transform(customer_features)
    
    # Scale features (important for K-Means)
    scaler = StandardScaler(
        inputCol="features_raw",
        outputCol="features",
        withStd=True,
        withMean=True
    )
    scaler_model = scaler.fit(assembled_df)
    scaled_df = scaler_model.transform(assembled_df)
    
    print("   → Features scaled and vectorized")
    
    # K-Means Clustering
    print("\n[5/6] Running K-Means clustering (k=4)...")
    kmeans = KMeans(
        k=4,  # 4 customer segments
        seed=42,
        maxIter=20,
        featuresCol="features",
        predictionCol="segment"
    )
    
    model = kmeans.fit(scaled_df)
    predictions = model.transform(scaled_df)
    
    # Evaluate clustering quality
    evaluator = ClusteringEvaluator(
        featuresCol="features",
        predictionCol="segment",
        metricName="silhouette"
    )
    silhouette = evaluator.evaluate(predictions)
    print(f"   → Silhouette score: {silhouette:.4f}")
    print(f"   → Cluster centers computed")
    
    # Analyze segments
    print("\n[6/6] Customer segment analysis:")
    segment_stats = predictions.groupBy("segment").agg(
        F.count("customer_id").alias("customer_count"),
        F.avg("total_spent").alias("avg_spent"),
        F.avg("purchase_count").alias("avg_purchases"),
        F.avg("days_since_purchase").alias("avg_recency")
    ).orderBy("segment")
    
    segment_stats.show()
    
    # Add business labels to segments
    predictions = predictions.withColumn(
        "segment_label",
        F.when(F.col("segment") == 0, "High-Value Frequent")
         .when(F.col("segment") == 1, "At-Risk")
         .when(F.col("segment") == 2, "New/Low-Spend")
         .otherwise("Moderate")
    )
    
    # Write results to S3 curated zone
    output_path = f"s3://{CURATED_BUCKET}/customer-segments/"
    print(f"\n📤 Writing results to: {output_path}")
    
    predictions.select(
        "customer_id",
        "segment",
        "segment_label",
        "total_spent",
        "purchase_count",
        "days_since_purchase",
        "primary_region",
        "preferred_payment"
    ).write \
        .mode("overwrite") \
        .partitionBy("segment") \
        .parquet(output_path)
    
    print("\n" + "=" * 70)
    print("✅ EMR Spark Job Completed Successfully!")
    print(f"   • Customers segmented: {predictions.count():,}")
    print(f"   • Segments created: 4")
    print(f"   • Output: {output_path}")
    print("=" * 70)
    
    spark.stop()

if __name__ == "__main__":
    main()
