# AWS Data Pipeline - Quick Start Guide

Welcome! This guide will get you up and running with the AWS data pipeline in **30 minutes**.

## 🚀 Quick Setup (3 Steps)

### Step 1: Prerequisites (5 minutes)

```bash
# 1. Install AWS CLI (if not installed)
brew install awscli  # macOS

# 2. Configure AWS credentials
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Default region: us-east-1
# Default output: json

# 3. Verify access
aws sts get-caller-identity

# 4. Clone/Navigate to project
cd ~/Documents/pers/learning/AWS_Data_Science/aws_data_pipeline

# 5. Set up Python environment
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### Step 2: Deploy Infrastructure (10 minutes)

```bash
# Make deploy script executable
chmod +x scripts/deploy.sh

# Run automated deployment
./scripts/deploy.sh
```

This script will:
- ✅ Create 5 S3 buckets (raw, processed, curated, scripts, query-results)
- ✅ Deploy Lambda function for data ingestion
- ✅ Set up EventBridge for daily automation
- ✅ Upload sample data
- ✅ Configure IAM roles and permissions

### Step 3: Test the Pipeline (5 minutes)

```bash
# Test Lambda function
aws lambda invoke \
  --function-name data-ingestion-function \
  --payload '{"format":"json","num_records":50}' \
  /tmp/output.json

# View the output
cat /tmp/output.json | jq .

# Check S3 for data
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws s3 ls s3://data-lake-raw-zone-${AWS_ACCOUNT_ID}/sales/ --recursive

# View CloudWatch logs
aws logs tail /aws/lambda/data-ingestion-function --follow
```

## 📊 What You've Built

Your data pipeline now includes:

```
EventBridge (Daily 2AM) → Lambda → S3 Raw Zone
                             ↓
                      CloudWatch Logs
```

**Resources Created:**
- 5 S3 buckets with encryption & lifecycle policies
- 1 Lambda function for data ingestion
- 1 EventBridge rule for automation
- IAM roles with proper permissions
- Sample sales, customer, and product data

## 📚 Tutorial Mode - Learn Step by Step

Want to understand each component? Follow the tutorials:

1. **[Module 1: Setup & Prerequisites](docs/01-setup.md)** ← Start here
2. **[Module 2: S3 Data Lake](docs/02-s3-configuration.md)** - Storage layer
3. **[Module 3: Lambda Ingestion](docs/03-lambda-ingestion.md)** - Data collection
4. **Module 4: Glue ETL** - Transform data
5. **Module 5: Athena** - Query data
6. **Module 6: EMR** - Big data processing
7. **Module 7: SageMaker** - Machine learning
8. **Module 8: QuickSight** - Visualizations
9. **Module 9: EventBridge** - Automation
10. **Module 10: Testing** - Validation

## 🎯 Next Steps

### Option A: Continue with Glue (Recommended)
Set up AWS Glue for data transformation:
```bash
# Coming in Module 4
# - Create Glue Crawler
# - Build ETL jobs
# - Transform raw → processed data
```

### Option B: Explore Current Setup
```bash
# View all buckets
aws s3 ls | grep data-lake

# Test different formats
aws lambda invoke \
  --function-name data-ingestion-function \
  --payload '{"format":"csv","num_records":100}' \
  /tmp/output.json

# Download and view data
aws s3 cp s3://data-lake-raw-zone-${AWS_ACCOUNT_ID}/sales/... - | jq .
```

### Option C: Manual Testing
Use AWS Console to:
1. View S3 buckets and data
2. Check Lambda function logs
3. Review EventBridge rules
4. Monitor CloudWatch metrics

## 💰 Cost Tracking

**Current Usage (with sample data):**
- S3 Storage: < $0.01/month
- Lambda: Free tier (1M requests/month)
- EventBridge: Free tier (1M events/month)
- **Total: ~$0/month** (within free tier)

Monitor costs:
```bash
# Check S3 usage
aws s3 ls s3://data-lake-raw-zone-${AWS_ACCOUNT_ID} \
  --recursive --summarize --human-readable

# View billing
aws ce get-cost-and-usage \
  --time-period Start=2024-11-01,End=2024-11-30 \
  --granularity MONTHLY \
  --metrics BlendedCost
```

## 🔧 Common Commands

```bash
# Invoke Lambda manually
aws lambda invoke \
  --function-name data-ingestion-function \
  --payload '{"num_records":20}' \
  /tmp/out.json

# List S3 contents
aws s3 ls s3://data-lake-raw-zone-${AWS_ACCOUNT_ID}/ --recursive

# View Lambda logs
aws logs tail /aws/lambda/data-ingestion-function --follow

# Update Lambda code
cd lambda/ingestion
zip -r function.zip handler.py
aws lambda update-function-code \
  --function-name data-ingestion-function \
  --zip-file fileb://function.zip

# Trigger EventBridge rule manually
aws events put-events \
  --entries '[{"Source":"custom.datapipeline","DetailType":"ManualIngestion","Detail":"{}"}]'
```

## 🧹 Cleanup (Delete Everything)

When you're done experimenting:

```bash
chmod +x scripts/cleanup.sh
./scripts/cleanup.sh
```

This removes:
- All S3 buckets and data
- Lambda functions
- EventBridge rules
- IAM roles
- CloudWatch dashboards

**⚠️ Warning:** This is permanent and cannot be undone!

## 🐛 Troubleshooting

### Issue: "Role not found"
Wait 10 seconds after creating IAM role for it to propagate.

### Issue: "Bucket already exists"
Bucket names must be globally unique. The script uses your account ID to ensure uniqueness.

### Issue: "Access Denied"
Check that your IAM user has sufficient permissions. Attach `PowerUserAccess` policy for testing.

### Issue: Lambda timeout
Increase timeout in Lambda configuration:
```bash
aws lambda update-function-configuration \
  --function-name data-ingestion-function \
  --timeout 300
```

## 📖 Architecture Overview

```
┌─────────────┐
│ EventBridge │ Schedule: Daily 2 AM
└──────┬──────┘
       ↓
┌─────────────┐
│   Lambda    │ Ingest data from sources
└──────┬──────┘
       ↓
┌─────────────────────────────────┐
│        S3 Data Lake             │
│  ┌──────────────────────────┐  │
│  │ Raw Zone                 │  │
│  │ /sales/year/month/day/   │  │
│  └──────────────────────────┘  │
└─────────────────────────────────┘
```

**Full Architecture** includes (coming in later modules):
- Glue ETL for transformations
- Athena for SQL queries
- EMR for big data processing
- SageMaker for ML models
- QuickSight for dashboards

## 📞 Support

- **Documentation**: Check `docs/` folder for detailed guides
- **Architecture**: See `architecture/architecture.md`
- **Sample Code**: Explore `lambda/`, `glue/`, `emr/` folders
- **AWS Docs**: https://docs.aws.amazon.com/

## 🎓 Learning Resources

- [AWS Data Analytics](https://aws.amazon.com/big-data/datalakes-and-analytics/)
- [Lambda Developer Guide](https://docs.aws.amazon.com/lambda/)
- [S3 Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/best-practices.html)
- [EventBridge Patterns](https://docs.aws.amazon.com/eventbridge/)

## ✅ Checklist

- [ ] AWS CLI configured
- [ ] Infrastructure deployed (`./scripts/deploy.sh`)
- [ ] Lambda tested successfully
- [ ] Data visible in S3
- [ ] CloudWatch logs working
- [ ] EventBridge rule created
- [ ] Ready for Module 4 (Glue ETL)

---

**Status**: ✅ Core infrastructure ready!
**Time to complete**: ~20 minutes
**Next**: Continue with [Module 4: AWS Glue ETL](docs/04-glue-etl.md)
