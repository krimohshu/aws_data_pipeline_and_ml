# AWS Data Pipeline Architecture - Detailed Design

## Architecture Diagram

```
                                    AWS CLOUD
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                      EVENT & ORCHESTRATION LAYER                     │    │
│  │                                                                       │    │
│  │   ┌──────────────────┐         ┌──────────────────┐                │    │
│  │   │  EventBridge     │         │  Step Functions  │                │    │
│  │   │  Rules           │         │  (Optional)      │                │    │
│  │   │                  │         │                  │                │    │
│  │   │  • Scheduled     │         │  • Workflow      │                │    │
│  │   │  • Event-driven  │         │  • Orchestration │                │    │
│  │   └────────┬─────────┘         └──────────────────┘                │    │
│  └────────────┼──────────────────────────────────────────────────────┘    │
│               │                                                              │
│               ▼                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                         INGESTION LAYER                              │    │
│  │                                                                       │    │
│  │   ┌──────────────────┐         ┌──────────────────┐                │    │
│  │   │  Lambda          │         │  API Gateway     │                │    │
│  │   │  Ingestion       │         │  (Optional)      │                │    │
│  │   │                  │         │                  │                │    │
│  │   │  • Data fetch    │         │  • REST API      │                │    │
│  │   │  • Validation    │         │  • Webhooks      │                │    │
│  │   │  • S3 upload     │         │                  │                │    │
│  │   └────────┬─────────┘         └──────────────────┘                │    │
│  └────────────┼──────────────────────────────────────────────────────┘    │
│               │                                                              │
│               ▼                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                         STORAGE LAYER (S3)                           │    │
│  │                                                                       │    │
│  │   ┌───────────────────────────────────────────────────────────────┐ │    │
│  │   │  S3 BUCKET: data-lake-raw-zone                                │ │    │
│  │   │                                                                │ │    │
│  │   │  Structure:                                                    │ │    │
│  │   │    /source_name/                                               │ │    │
│  │   │      /year=YYYY/                                               │ │    │
│  │   │        /month=MM/                                              │ │    │
│  │   │          /day=DD/                                              │ │    │
│  │   │            - file_timestamp.json                               │ │    │
│  │   │            - file_timestamp.csv                                │ │    │
│  │   │                                                                │ │    │
│  │   │  Lifecycle: Transition to Glacier after 90 days               │ │    │
│  │   └───────────────────────────────────────────────────────────────┘ │    │
│  │                                                                       │    │
│  │   ┌───────────────────────────────────────────────────────────────┐ │    │
│  │   │  S3 BUCKET: data-lake-processed-zone                          │ │    │
│  │   │                                                                │ │    │
│  │   │  Structure:                                                    │ │    │
│  │   │    /table_name/                                                │ │    │
│  │   │      /year=YYYY/                                               │ │    │
│  │   │        /month=MM/                                              │ │    │
│  │   │          /day=DD/                                              │ │    │
│  │   │            - part-00000.parquet                                │ │    │
│  │   │                                                                │ │    │
│  │   │  Format: Parquet (columnar, compressed)                       │ │    │
│  │   └───────────────────────────────────────────────────────────────┘ │    │
│  │                                                                       │    │
│  │   ┌───────────────────────────────────────────────────────────────┐ │    │
│  │   │  S3 BUCKET: data-lake-curated-zone                            │ │    │
│  │   │                                                                │ │    │
│  │   │  Analytics-ready datasets                                      │ │    │
│  │   │  Aggregations, joined tables                                   │ │    │
│  │   └───────────────────────────────────────────────────────────────┘ │    │
│  │                                                                       │    │
│  │   ┌───────────────────────────────────────────────────────────────┐ │    │
│  │   │  S3 BUCKET: data-lake-scripts                                 │ │    │
│  │   │  ETL scripts, configs, artifacts                              │ │    │
│  │   └───────────────────────────────────────────────────────────────┘ │    │
│  └────────────────────────┬──────────────────────────────────────────┘    │
│                           │                                                  │
│                           ▼                                                  │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    METADATA & CATALOG LAYER                          │    │
│  │                                                                       │    │
│  │   ┌──────────────────┐         ┌──────────────────┐                │    │
│  │   │  Glue Crawler    │────────►│  Glue Data       │                │    │
│  │   │                  │         │  Catalog         │                │    │
│  │   │  • Schema        │         │                  │                │    │
│  │   │    discovery     │         │  • Metadata      │                │    │
│  │   │  • Partitions    │         │  • Schemas       │                │    │
│  │   │  • Schedule      │         │  • Tables        │                │    │
│  │   └──────────────────┘         └──────────────────┘                │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                           │                                                  │
│                           ▼                                                  │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    TRANSFORMATION LAYER                              │    │
│  │                                                                       │    │
│  │   ┌──────────────────────────────────────────────────────────┐      │    │
│  │   │  AWS Glue ETL Jobs                                       │      │    │
│  │   │                                                           │      │    │
│  │   │  ┌────────────────┐  ┌────────────────┐  ┌───────────┐ │      │    │
│  │   │  │ Data Cleaning  │  │ Transformation │  │ Partition │ │      │    │
│  │   │  │                │  │                │  │           │ │      │    │
│  │   │  │ • Dedup        │  │ • Join         │  │ • Date    │ │      │    │
│  │   │  │ • Validate     │  │ • Aggregate    │  │ • Region  │ │      │    │
│  │   │  │ • Format       │  │ • Enrich       │  │ • Type    │ │      │    │
│  │   │  └────────────────┘  └────────────────┘  └───────────┘ │      │    │
│  │   │                                                           │      │    │
│  │   │  Language: Python/PySpark                                │      │    │
│  │   │  DPU: 2-10 (configurable)                                │      │    │
│  │   └──────────────────────────────────────────────────────────┘      │    │
│  │                                                                       │    │
│  │   ┌──────────────────────────────────────────────────────────┐      │    │
│  │   │  Amazon EMR (Elastic MapReduce)                          │      │    │
│  │   │                                                           │      │    │
│  │   │  ┌────────────────┐  ┌────────────────┐  ┌───────────┐ │      │    │
│  │   │  │ Spark Jobs     │  │ ML Feature     │  │ Complex   │ │      │    │
│  │   │  │                │  │ Engineering    │  │ Analytics │ │      │    │
│  │   │  │ • Large ETL    │  │                │  │           │ │      │    │
│  │   │  │ • Streaming    │  │ • Scaling      │  │ • Joins   │ │      │    │
│  │   │  │ • Batch        │  │ • Encoding     │  │ • Agg     │ │      │    │
│  │   │  └────────────────┘  └────────────────┘  └───────────┘ │      │    │
│  │   │                                                           │      │    │
│  │   │  Instance: m5.xlarge (master), m5.large (core/task)     │      │    │
│  │   └──────────────────────────────────────────────────────────┘      │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                           │                                                  │
│                           ▼                                                  │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    ANALYTICS & ML LAYER                              │    │
│  │                                                                       │    │
│  │   ┌──────────────────────────────────────────────────────────┐      │    │
│  │   │  Amazon Athena                                           │      │    │
│  │   │                                                           │      │    │
│  │   │  • Serverless SQL queries                                │      │    │
│  │   │  • Query S3 directly                                     │      │    │
│  │   │  • ANSI SQL support                                      │      │    │
│  │   │  • Results to S3                                         │      │    │
│  │   │                                                           │      │    │
│  │   │  Workgroups: primary, analytics, ml_data                 │      │    │
│  │   └──────────────────────────────────────────────────────────┘      │    │
│  │                                                                       │    │
│  │   ┌──────────────────────────────────────────────────────────┐      │    │
│  │   │  Amazon SageMaker                                        │      │    │
│  │   │                                                           │      │    │
│  │   │  ┌────────────┐  ┌────────────┐  ┌──────────────────┐  │      │    │
│  │   │  │ Notebooks  │  │ Training   │  │ Endpoints        │  │      │    │
│  │   │  │            │  │            │  │                  │  │      │    │
│  │   │  │ • Jupyter  │  │ • AutoML   │  │ • Real-time      │  │      │    │
│  │   │  │ • Studio   │  │ • Custom   │  │ • Batch          │  │      │    │
│  │   │  │ • R/Python │  │ • Pipeline │  │ • Serverless     │  │      │    │
│  │   │  └────────────┘  └────────────┘  └──────────────────┘  │      │    │
│  │   └──────────────────────────────────────────────────────────┘      │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                           │                                                  │
│                           ▼                                                  │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    VISUALIZATION LAYER                               │    │
│  │                                                                       │    │
│  │   ┌──────────────────────────────────────────────────────────┐      │    │
│  │   │  Amazon QuickSight                                       │      │    │
│  │   │                                                           │      │    │
│  │   │  ┌────────────┐  ┌────────────┐  ┌──────────────────┐  │      │    │
│  │   │  │ Dashboards │  │ Reports    │  │ Alerts           │  │      │    │
│  │   │  │            │  │            │  │                  │  │      │    │
│  │   │  │ • KPIs     │  │ • Schedule │  │ • Thresholds     │  │      │    │
│  │   │  │ • Charts   │  │ • Export   │  │ • Email          │  │      │    │
│  │   │  │ • Filters  │  │ • Share    │  │ • SNS            │  │      │    │
│  │   │  └────────────┘  └────────────┘  └──────────────────┘  │      │    │
│  │   │                                                           │      │    │
│  │   │  Data Sources: Athena, S3, SageMaker                    │      │    │
│  │   └──────────────────────────────────────────────────────────┘      │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    MONITORING & SECURITY                             │    │
│  │                                                                       │    │
│  │   ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐     │    │
│  │   │ CloudWatch   │  │ CloudTrail   │  │ IAM Roles/Policies   │     │    │
│  │   │ • Logs       │  │ • Audit      │  │ • Least privilege    │     │    │
│  │   │ • Metrics    │  │ • Compliance │  │ • Service roles      │     │    │
│  │   │ • Alarms     │  │              │  │                      │     │    │
│  │   └──────────────┘  └──────────────┘  └──────────────────────┘     │    │
│  │                                                                       │    │
│  │   ┌──────────────┐  ┌──────────────┐                                │    │
│  │   │ KMS          │  │ S3 Encryption│                                │    │
│  │   │ • Keys       │  │ • SSE-S3     │                                │    │
│  │   │ • Rotation   │  │ • SSE-KMS    │                                │    │
│  │   └──────────────┘  └──────────────┘                                │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                               │
└───────────────────────────────────────────────────────────────────────────────┘
```

## Data Flow Sequence

### 1. Ingestion Flow
```
EventBridge (Scheduled: Daily 2 AM UTC)
    │
    ▼
Lambda Trigger
    │
    ├─► Fetch data from source (API/Database/File)
    ├─► Validate data format
    ├─► Add metadata (timestamp, source)
    ├─► Compress (gzip)
    └─► Upload to S3 Raw Zone
            │
            └─► s3://data-lake-raw-zone/sales/year=2024/month=11/day=16/
                    sales_20241116_020000.json.gz
```

### 2. Cataloging Flow
```
S3 Event Notification (New file in Raw Zone)
    │
    ▼
Trigger Glue Crawler
    │
    ├─► Scan S3 location
    ├─► Infer schema
    ├─► Detect partitions
    └─► Update Glue Data Catalog
            │
            └─► Table: raw_sales
                Columns: [id, date, amount, customer_id, product_id]
                Partitions: year, month, day
```

### 3. Transformation Flow (Option A - Glue)
```
EventBridge (After crawler completes) / Manual trigger
    │
    ▼
Glue ETL Job
    │
    ├─► Read from Glue Catalog (raw_sales)
    ├─► Data Quality Checks
    │   ├─► Remove nulls
    │   ├─► Deduplicate
    │   └─► Validate ranges
    ├─► Transformations
    │   ├─► Type conversions
    │   ├─► Add derived columns
    │   └─► Join with reference data
    ├─► Convert to Parquet
    └─► Write to S3 Processed Zone (partitioned)
            │
            └─► s3://data-lake-processed-zone/sales_clean/
                    year=2024/month=11/day=16/part-00000.parquet
```

### 4. Transformation Flow (Option B - EMR)
```
Manual trigger / Scheduled
    │
    ▼
Launch EMR Cluster
    │
    ├─► Bootstrap (install dependencies)
    ├─► Submit Spark Job
    │       │
    │       ├─► Read from S3 Raw Zone
    │       ├─► Complex transformations
    │       ├─► ML feature engineering
    │       └─► Write to S3 Processed/Curated Zone
    │
    └─► Terminate cluster (optional)
```

### 5. Analytics Flow
```
User Query via Athena Console / QuickSight
    │
    ▼
Athena SQL Query
    │
    ├─► Read metadata from Glue Catalog
    ├─► Scan S3 Processed Zone
    ├─► Execute SQL (Presto engine)
    └─► Return results
            │
            ├─► To S3 query results bucket
            └─► To QuickSight for visualization
```

### 6. ML Flow
```
SageMaker Notebook
    │
    ├─► Query data via Athena
    ├─► Feature engineering
    ├─► Train model
    │       │
    │       └─► Save model to S3
    │
    ├─► Deploy model to endpoint
    └─► Batch transform / Real-time inference
            │
            └─► Save predictions to S3 Curated Zone
```

## Component Details

### S3 Bucket Configuration

#### Raw Zone
- **Purpose**: Store original, immutable data
- **Format**: JSON, CSV, Parquet (as received)
- **Partitioning**: /source/year=YYYY/month=MM/day=DD/
- **Retention**: 90 days (then Glacier)
- **Versioning**: Enabled
- **Encryption**: SSE-S3

#### Processed Zone
- **Purpose**: Store cleaned, transformed data
- **Format**: Parquet (columnar, Snappy compression)
- **Partitioning**: /table/year=YYYY/month=MM/day=DD/
- **Retention**: 365 days
- **Versioning**: Enabled
- **Encryption**: SSE-KMS

#### Curated Zone
- **Purpose**: Analytics-ready aggregated data
- **Format**: Parquet
- **Partitioning**: By business logic
- **Retention**: Indefinite
- **Access**: Read-only for analysts

### Lambda Configuration

#### Ingestion Function
- **Runtime**: Python 3.11
- **Memory**: 512 MB
- **Timeout**: 5 minutes
- **Concurrency**: 10
- **Environment Variables**:
  - S3_RAW_BUCKET
  - SOURCE_API_ENDPOINT
  - LOG_LEVEL

### Glue Configuration

#### Crawler
- **Schedule**: After ingestion completes
- **Targets**: S3 Raw and Processed zones
- **Classifiers**: JSON, CSV, Parquet
- **Schema Change**: Update catalog

#### ETL Job
- **Type**: Spark ETL
- **Glue Version**: 4.0
- **DPU**: 2-10 (Auto-scaling)
- **Language**: Python 3
- **Max Retries**: 1

### EMR Configuration

#### Cluster
- **Release**: emr-6.10.0
- **Applications**: Spark, Hadoop, Hive, Livy
- **Master**: m5.xlarge (1 instance)
- **Core**: m5.large (2-5 instances, auto-scaling)
- **Task**: Spot instances (cost optimization)

### Athena Configuration

#### Workgroups
- **primary**: Default queries
- **analytics**: Analytics team
- **ml_data**: ML data preparation

#### Query Result Location
- s3://data-lake-query-results/

### SageMaker Configuration

#### Notebook Instance
- **Type**: ml.t3.medium (development)
- **Volume**: 20 GB
- **IAM Role**: SageMakerExecutionRole

#### Training Job
- **Instance**: ml.m5.xlarge
- **Spot training**: Enabled (70% cost savings)

### QuickSight Configuration

#### Data Source
- **Type**: Athena
- **Database**: data_lake_db
- **Tables**: sales_clean, customer_aggregates

#### Refresh Schedule
- **Frequency**: Daily at 6 AM UTC
- **Type**: Incremental (based on date partitions)

## Cost Optimization Strategies

1. **S3 Lifecycle Policies**: Move to Glacier/Deep Archive
2. **EMR Auto-scaling**: Scale core nodes based on YARN metrics
3. **Spot Instances**: Use for EMR task nodes
4. **Glue Job Bookmarks**: Process only new data
5. **Athena Partitioning**: Reduce data scanned
6. **SageMaker Spot Training**: 70% cost reduction
7. **QuickSight SPICE**: Cache frequently accessed data

## Security Architecture

### Network
- VPC with private subnets for EMR/SageMaker
- VPC Endpoints for S3, Glue, Athena
- Security Groups: Restrict access

### IAM Roles
- LambdaExecutionRole: S3, CloudWatch
- GlueServiceRole: S3, Glue Catalog, CloudWatch
- EMRServiceRole: EC2, S3, CloudWatch
- SageMakerExecutionRole: S3, ECR, CloudWatch

### Encryption
- S3: SSE-KMS with customer managed keys
- EBS: Encrypted volumes for EMR
- Data in transit: TLS 1.2+

### Audit
- CloudTrail: All API calls logged
- S3 Access Logs: Enabled
- VPC Flow Logs: Monitor network traffic

## Monitoring & Alerting

### CloudWatch Metrics
- Lambda invocations, errors, duration
- Glue job success/failure, DPU utilization
- EMR cluster metrics, node health
- Athena queries scanned data
- S3 bucket size, request count

### Alarms
- Lambda error rate > 5%
- Glue job failure
- EMR cluster unhealthy nodes
- S3 bucket size > threshold
- Athena query scan cost > $100/day

### Dashboards
- Pipeline health overview
- Cost metrics by service
- Data quality metrics
- Query performance

## Disaster Recovery

### Backup Strategy
- S3 Cross-Region Replication: Critical data
- Glue Catalog backup: Export to S3
- Code versioning: Git repositories
- Configuration backup: Infrastructure as Code

### RTO/RPO
- **RPO**: < 24 hours (daily incremental)
- **RTO**: < 4 hours (automated recovery)

## Next Steps

Proceed to implementation tutorials:
1. [Setup & Prerequisites](../docs/01-setup.md)
2. [S3 Configuration](../docs/02-s3-configuration.md)
3. Continue with remaining modules...
