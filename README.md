# AWS End-to-End Data Pipeline

A comprehensive serverless data pipeline demonstrating AWS best practices for data ingestion, processing, analytics, and visualization.

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           AWS DATA PIPELINE ARCHITECTURE                     │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────────┐
│  EventBridge     │ ──► Scheduled/Event-driven triggers
│  Rules           │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐         ┌─────────────────────────────────────┐
│  Lambda          │         │         S3 Data Lake                │
│  Ingestion       │────────►│                                     │
│  Function        │         │  ┌─────────────────────────────┐   │
└──────────────────┘         │  │  RAW ZONE                   │   │
         │                   │  │  - Landing area             │   │
         │                   │  │  - Original data formats    │   │
         │                   │  │  - Unprocessed files        │   │
         │                   │  └─────────────────────────────┘   │
         │                   │                                     │
         │                   │  ┌─────────────────────────────┐   │
         │                   │  │  PROCESSED ZONE             │   │
         │                   │  │  - Cleaned data             │   │
         │                   │  │  - Parquet format           │   │
         │                   │  │  - Partitioned by date      │   │
         │                   │  └─────────────────────────────┘   │
         │                   │                                     │
         │                   │  ┌─────────────────────────────┐   │
         │                   │  │  CURATED ZONE (Optional)    │   │
         │                   │  │  - Analytics-ready          │   │
         │                   │  │  - Aggregated datasets      │   │
         │                   │  └─────────────────────────────┘   │
         │                   └─────────────────────────────────────┘
         │                                    │
         │                                    │
         ▼                                    ▼
┌──────────────────┐              ┌─────────────────────┐
│  AWS Glue        │◄─────────────│  Glue Crawler       │
│  ETL Jobs        │              │  (Schema Discovery) │
│                  │              └─────────────────────┘
│  - Transform     │                         │
│  - Clean         │                         ▼
│  - Enrich        │              ┌─────────────────────┐
│  - Partition     │              │  Glue Data Catalog  │
└────────┬─────────┘              │  (Metadata Store)   │
         │                        └─────────────────────┘
         │                                    │
         ▼                                    │
┌──────────────────┐                         │
│  Amazon EMR      │                         │
│  (Spark Jobs)    │                         │
│                  │                         │
│  - Big data      │                         │
│    processing    │                         │
│  - ML at scale   │                         │
└────────┬─────────┘                         │
         │                                    │
         │                                    │
         ▼                                    ▼
┌──────────────────┐              ┌─────────────────────┐
│  SageMaker       │              │  Amazon Athena      │
│                  │              │  (SQL Analytics)    │
│  - Training      │              │                     │
│  - Inference     │              │  - Query S3 data    │
│  - Notebooks     │              │  - Serverless       │
└────────┬─────────┘              └──────────┬──────────┘
         │                                    │
         │                                    │
         └────────────┬───────────────────────┘
                      │
                      ▼
              ┌─────────────────────┐
              │  Amazon QuickSight  │
              │  (Visualization)    │
              │                     │
              │  - Dashboards       │
              │  - Reports          │
              │  - BI Analytics     │
              └─────────────────────┘
```

## 📋 Components

### 1. **Data Ingestion Layer**
- **EventBridge**: Schedule-based or event-driven triggers
- **Lambda**: Serverless data ingestion from various sources
- **S3 Raw Zone**: Landing area for raw data

### 2. **Data Lake (S3)**
- **Raw Zone**: Original, unprocessed data
- **Processed Zone**: Cleaned and transformed data (Parquet format)
- **Curated Zone**: Analytics-ready, aggregated datasets

### 3. **Data Processing Layer**
- **AWS Glue**: ETL jobs for data transformation
- **Glue Crawler**: Automatic schema discovery
- **Glue Data Catalog**: Central metadata repository
- **Amazon EMR**: Big data processing with Apache Spark

### 4. **Analytics Layer**
- **Amazon Athena**: SQL queries on S3 data
- **SageMaker**: ML model training and inference

### 5. **Visualization Layer**
- **Amazon QuickSight**: Interactive dashboards and reports

## 🎯 Data Flow

1. **Ingestion**: EventBridge triggers Lambda to ingest data → S3 Raw Zone
2. **Cataloging**: Glue Crawler scans raw data → Updates Glue Data Catalog
3. **Transformation**: Glue ETL jobs transform data → S3 Processed Zone
4. **Big Data Processing**: EMR Spark jobs for complex transformations
5. **ML Processing**: SageMaker trains models on processed data
6. **Analytics**: Athena queries processed data using Glue Catalog
7. **Visualization**: QuickSight creates dashboards from Athena queries

## 📁 Project Structure

```
aws_data_pipeline/
├── README.md
├── architecture/
│   └── architecture.md
├── infrastructure/
│   ├── cloudformation/
│   │   ├── s3-buckets.yaml
│   │   ├── glue-resources.yaml
│   │   ├── lambda-functions.yaml
│   │   ├── eventbridge-rules.yaml
│   │   └── emr-cluster.yaml
│   └── terraform/ (alternative)
├── lambda/
│   ├── ingestion/
│   │   ├── handler.py
│   │   ├── requirements.txt
│   │   └── README.md
│   └── transformation/
├── glue/
│   ├── jobs/
│   │   ├── raw_to_processed.py
│   │   ├── data_quality_check.py
│   │   └── aggregation_job.py
│   └── crawlers/
│       └── crawler_config.json
├── emr/
│   ├── spark_jobs/
│   │   ├── data_transformation.py
│   │   └── ml_feature_engineering.py
│   └── bootstrap/
│       └── bootstrap.sh
├── sagemaker/
│   ├── notebooks/
│   │   └── model_training.ipynb
│   ├── scripts/
│   │   ├── train.py
│   │   └── inference.py
│   └── requirements.txt
├── athena/
│   ├── queries/
│   │   ├── create_views.sql
│   │   └── sample_queries.sql
│   └── workgroups/
│       └── config.json
├── quicksight/
│   ├── datasets/
│   └── dashboards/
│       └── dashboard_config.json
├── sample_data/
│   └── sales_data.csv
├── scripts/
│   ├── deploy.sh
│   ├── setup_environment.sh
│   └── test_pipeline.sh
└── docs/
    ├── 01-setup.md
    ├── 02-s3-configuration.md
    ├── 03-lambda-ingestion.md
    ├── 04-glue-etl.md
    ├── 05-athena-queries.md
    ├── 06-emr-processing.md
    ├── 07-sagemaker-ml.md
    ├── 08-quicksight-viz.md
    ├── 09-eventbridge-automation.md
    └── 10-testing.md
```

## 🚀 Getting Started

### Prerequisites
- AWS Account with appropriate permissions
- AWS CLI configured
- Python 3.9+
- Terraform or CloudFormation knowledge (optional)

### Quick Start
```bash
# Clone and navigate to project
cd aws_data_pipeline

# Set up AWS credentials
aws configure

# Deploy infrastructure
./scripts/deploy.sh

# Test the pipeline
./scripts/test_pipeline.sh
```

## 📚 Tutorial Modules

Each module builds on the previous one:

1. **[Setup & Prerequisites](docs/01-setup.md)**
2. **[S3 Data Lake Configuration](docs/02-s3-configuration.md)**
3. **[Lambda Data Ingestion](docs/03-lambda-ingestion.md)**
4. **[AWS Glue ETL](docs/04-glue-etl.md)**
5. **[Athena Analytics](docs/05-athena-queries.md)**
6. **[EMR Big Data Processing](docs/06-emr-processing.md)**
7. **[SageMaker ML Integration](docs/07-sagemaker-ml.md)**
8. **[QuickSight Visualization](docs/08-quicksight-viz.md)**
9. **[EventBridge Automation](docs/09-eventbridge-automation.md)**
10. **[Testing & Validation](docs/10-testing.md)**

## 💰 Cost Considerations

- **S3**: Pay per GB stored and requests
- **Lambda**: First 1M requests/month free
- **Glue**: Pay per DPU-hour for ETL jobs
- **Athena**: $5 per TB scanned
- **EMR**: Pay per instance-hour
- **SageMaker**: Pay per instance-hour
- **QuickSight**: $9-$24/user/month

**Estimated Monthly Cost**: $50-$200 (varies based on data volume)

## 🔒 Security Best Practices

- ✅ Enable S3 bucket encryption
- ✅ Use IAM roles with least privilege
- ✅ Enable CloudTrail logging
- ✅ Implement VPC endpoints for private access
- ✅ Enable versioning on S3 buckets
- ✅ Use KMS for encryption keys

## 📊 Sample Use Case

This pipeline demonstrates a **Sales Analytics Platform**:
- Ingest daily sales transactions
- Transform and clean data
- Generate customer insights
- Train ML models for sales forecasting
- Visualize KPIs in QuickSight

## 🤝 Contributing

Feel free to extend this pipeline for your specific use case!

## 📄 License

MIT License - Feel free to use for learning and production.

---

**Next Steps**: Start with [Module 1: Setup & Prerequisites](docs/01-setup.md)
