# Phase 8: EMR Spark Processing

## Overview
Amazon EMR (Elastic MapReduce) provides managed Hadoop/Spark clusters for large-scale data processing that goes beyond what Glue can handle.

## When to Use EMR in This Pipeline

### 1. **Complex Feature Engineering for ML**
```python
# Example: Advanced feature engineering with Spark MLlib
from pyspark.ml.feature import VectorAssembler, StandardScaler
from pyspark.ml.stat import Correlation

# Read processed data from S3
sales_df = spark.read.parquet("s3://data-lake-processed-zone/sales/")
customers_df = spark.read.parquet("s3://data-lake-processed-zone/customers/")

# Complex join + aggregation (billion+ rows)
features_df = sales_df \
    .join(customers_df, "customer_id") \
    .groupBy("customer_id", "region") \
    .agg(
        F.sum("total_amount").alias("lifetime_value"),
        F.count("transaction_id").alias("purchase_frequency"),
        F.avg("quantity").alias("avg_basket_size"),
        F.stddev("total_amount").alias("spend_volatility")
    )

# ML feature vectorization
assembler = VectorAssembler(
    inputCols=["lifetime_value", "purchase_frequency", "avg_basket_size"],
    outputCol="features"
)
features_vector = assembler.transform(features_df)

# Correlation analysis
correlation_matrix = Correlation.corr(features_vector, "features").head()[0]
```

**Why EMR?**
- Distributed processing across 10+ worker nodes
- Spark MLlib operations (correlation, PCA, feature selection)
- Handles billions of rows efficiently

---

### 2. **Time-Series Aggregations**
```python
# Rolling window calculations for forecasting
from pyspark.sql.window import Window

# 30-day rolling average sales by region
window_spec = Window \
    .partitionBy("region") \
    .orderBy(F.col("date").cast("timestamp").cast("long")) \
    .rangeBetween(-30*86400, 0)  # 30 days in seconds

sales_with_trends = sales_df \
    .withColumn("rolling_avg_30d", 
                F.avg("total_amount").over(window_spec)) \
    .withColumn("rolling_sum_30d", 
                F.sum("total_amount").over(window_spec))
```

**Why EMR?**
- Window functions over large time ranges are memory-intensive
- EMR can allocate 100s of GB RAM across cluster
- Spill to disk if needed (YARN memory management)

---

### 3. **Graph Processing (Customer Networks)**
```python
# Analyze customer referral networks with GraphFrames
from graphframes import GraphFrame

# Vertices = customers, Edges = referrals
vertices = customers_df.select("customer_id", "region", "join_date")
edges = referrals_df.select(
    F.col("referrer_id").alias("src"),
    F.col("referred_id").alias("dst"),
    F.col("referral_date")
)

# Create graph
graph = GraphFrame(vertices, edges)

# PageRank to find influential customers
influencers = graph.pageRank(resetProbability=0.15, maxIter=10)

# Community detection
communities = graph.labelPropagation(maxIter=5)
```

**Why EMR?**
- GraphFrames requires Spark with graph processing libraries
- Not available in Glue
- Iterative algorithms benefit from cluster caching

---

### 4. **Streaming Data Processing**
```python
# Real-time clickstream processing with Spark Streaming
from pyspark.streaming import StreamingContext

ssc = StreamingContext(spark.sparkContext, batchInterval=10)

# Read from Kinesis stream
kinesis_stream = ssc \
    .kinesis(
        streamName="user-clickstream",
        endpointUrl="kinesis.eu-west-2.amazonaws.com",
        regionName="eu-west-2"
    )

# Process micro-batches
clickstream = kinesis_stream \
    .map(lambda x: json.loads(x)) \
    .filter(lambda event: event['page'] == 'checkout') \
    .map(lambda event: (event['user_id'], 1)) \
    .reduceByKey(lambda a, b: a + b)

# Write to S3 every 60 seconds
clickstream.saveAsTextFiles("s3://data-lake-raw-zone/clickstream/")

ssc.start()
ssc.awaitTermination()
```

**Why EMR?**
- Long-running streaming jobs (hours/days)
- Glue is batch-only
- EMR supports Spark Streaming, Flink, Kafka

---

## EMR Cluster Configuration for This Project

### **Development Cluster (Small)**
```bash
aws emr create-cluster \
  --name "data-pipeline-dev-cluster" \
  --release-label emr-6.15.0 \
  --applications Name=Spark Name=Hadoop Name=Hive Name=Livy \
  --instance-type m5.xlarge \
  --instance-count 3 \
  --ec2-attributes KeyName=my-key,SubnetId=subnet-xxx \
  --use-default-roles \
  --log-uri s3://data-lake-scripts-616129051451/emr-logs/
```

**Specs:**
- 1 Master: m5.xlarge (4 vCPU, 16 GB RAM)
- 2 Workers: m5.xlarge each
- Total: 12 vCPU, 48 GB RAM
- **Cost:** ~$0.75/hour

---

### **Production Cluster (Large)**
```bash
aws emr create-cluster \
  --name "data-pipeline-prod-cluster" \
  --release-label emr-6.15.0 \
  --applications Name=Spark Name=Hadoop Name=Hive Name=Presto \
  --instance-groups \
    InstanceGroupType=MASTER,InstanceType=m5.2xlarge,InstanceCount=1 \
    InstanceGroupType=CORE,InstanceType=r5.4xlarge,InstanceCount=5 \
    InstanceGroupType=TASK,InstanceType=c5.4xlarge,InstanceCount=10,BidPrice=OnDemandPrice \
  --auto-scaling-role EMR_AutoScaling_DefaultRole \
  --ec2-attributes KeyName=my-key,SubnetId=subnet-xxx \
  --use-default-roles \
  --log-uri s3://data-lake-scripts-616129051451/emr-logs/
```

**Specs:**
- 1 Master: m5.2xlarge (8 vCPU, 32 GB RAM)
- 5 Core: r5.4xlarge (16 vCPU, 128 GB RAM each) - memory-optimized
- 10 Task: c5.4xlarge (16 vCPU, 32 GB RAM each) - compute-optimized, Spot instances
- Total: 248 vCPU, 992 GB RAM
- **Cost:** ~$15-20/hour (with Spot savings)

---

## Data Flow: Glue → EMR → SageMaker

```
S3 Processed Zone (Glue output)
    ↓
[100 GB - 10 TB clean Parquet files]
    ↓
EMR Spark Jobs
    ├─ Feature engineering
    ├─ Time-series aggregations
    ├─ Graph analytics
    └─ Dimensionality reduction (PCA)
    ↓
S3 Curated Zone (ML-ready)
    ↓
[Feature vectors in optimized Parquet]
    ↓
SageMaker Training
    └─ XGBoost, RandomForest, Neural Nets
```

---

## Cost Comparison: Glue vs EMR

### **Scenario: Transform 1 TB of data**

**Glue (Serverless):**
- 10 DPU × 20 minutes = 3.33 DPU-hours
- Cost: 3.33 × $0.44 = **$1.47**
- Best for: Infrequent jobs

**EMR (m5.xlarge cluster, 3 nodes):**
- Cluster runtime: 30 minutes
- Cost: 3 × $0.192 × 0.5 = **$0.29**
- Best for: Continuous processing

**EMR Savings:**
- ✅ 80% cheaper if cluster runs 24/7
- ❌ Must manage cluster lifecycle
- ✅ Faster execution (no cold start)

---

## Hadoop vs Spark in EMR

### **Hadoop (MapReduce)**
```java
// Old-school Java MapReduce (rarely used now)
public class SalesAggregator extends Mapper<...> {
    public void map(Text key, Text value, Context context) {
        // Disk-based processing
    }
}
```
- Disk-based processing (slower)
- Fault-tolerant (writes intermediate results to HDFS)
- Good for: Extremely large datasets that don't fit in RAM

### **Spark (In-Memory)**
```python
# Modern Spark (what we'll use)
sales_df = spark.read.parquet("s3://...")
result = sales_df.groupBy("region").sum("total_amount")
```
- In-memory processing (100x faster)
- Lazy evaluation (optimizes query plan)
- Good for: 99% of use cases

**Verdict:** We'll use Spark exclusively. Hadoop (MapReduce) is legacy.

---

## Sample PySpark Job for EMR

```python
# File: emr/jobs/customer_segmentation.py

from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.ml.feature import VectorAssembler
from pyspark.ml.clustering import KMeans

# Initialize Spark session
spark = SparkSession.builder \
    .appName("CustomerSegmentation") \
    .getOrCreate()

# Read processed data
sales = spark.read.parquet("s3://data-lake-processed-zone/sales/")
customers = spark.read.parquet("s3://data-lake-processed-zone/customers/")

# Feature engineering
customer_features = sales \
    .groupBy("customer_id") \
    .agg(
        F.sum("total_amount").alias("total_spent"),
        F.count("transaction_id").alias("num_purchases"),
        F.avg("quantity").alias("avg_basket_size"),
        F.max("date").alias("last_purchase_date")
    ) \
    .join(customers, "customer_id")

# Recency calculation
customer_features = customer_features.withColumn(
    "days_since_purchase",
    F.datediff(F.current_date(), F.col("last_purchase_date"))
)

# Assemble features for K-Means
assembler = VectorAssembler(
    inputCols=["total_spent", "num_purchases", "days_since_purchase"],
    outputCol="features"
)
features_df = assembler.transform(customer_features)

# K-Means clustering (3 segments)
kmeans = KMeans(k=3, seed=42)
model = kmeans.fit(features_df)
predictions = model.transform(features_df)

# Save results
predictions.write \
    .mode("overwrite") \
    .partitionBy("prediction") \
    .parquet("s3://data-lake-curated-zone/customer-segments/")

print(f"✅ Clustered {predictions.count()} customers into 3 segments")
spark.stop()
```

---

## Summary: Glue vs EMR Decision Tree

```
Start
  │
  ├─ Data < 10 TB? ──Yes──→ Use Glue (serverless)
  │                          │
  │                          └─ Job < 15 min? ──Yes──→ Glue ✅
  │                                              │
  │                                              No
  │                                              │
  │                                              └─→ Consider EMR
  │
  └─ Data > 10 TB? ──Yes──→ Use EMR (cluster)
                             │
                             ├─ Need Spark Streaming? ──Yes──→ EMR ✅
                             ├─ Need GraphFrames? ──Yes──→ EMR ✅
                             ├─ Need Presto/Hive? ──Yes──→ EMR ✅
                             └─ Simple ETL? ──Yes──→ Try Glue first
```

---

## Next Steps

In Phase 8, we'll:
1. Launch a dev EMR cluster (3 nodes)
2. Submit the customer segmentation PySpark job
3. Monitor via Spark UI (port 18080)
4. Query results with Athena
5. Shut down cluster to save costs

**Cost for this tutorial:** ~$1-2 (30 minutes of EMR runtime)
