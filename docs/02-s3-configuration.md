# Phase 2: S3 Data Lake Configuration

## Overview
Set up a multi-tier S3 data lake with raw, processed, and curated zones. Implement proper security, lifecycle policies, and partitioning strategies.

## Objectives
- Implement data lake architecture
- Create S3 buckets with proper configuration
- Implement lifecycle policies
- Set up bucket notifications
- Configure security and encryption

## Architecture

```
S3 Data Lake Structure:
├── data-lake-raw-zone-{account-id}
│   ├── /sales/year=2024/month=11/day=16/
│   ├── /customers/year=2024/month=11/day=16/
│   └── /products/year=2024/month=11/day=16/
├── data-lake-processed-zone-{account-id}
│   ├── /sales_clean/year=2024/month=11/day=16/
│   ├── /customer_enriched/year=2024/month=11/day=16/
│   └── /product_catalog/year=2024/month=11/day=16/
├── data-lake-curated-zone-{account-id}
│   ├── /sales_analytics/
│   ├── /customer_segments/
│   └── /product_performance/
├── data-lake-scripts-{account-id}
│   ├── /glue_jobs/
│   ├── /emr_jobs/
│   └── /lambda_functions/
└── data-lake-query-results-{account-id}
    └── /athena/
```

## Step 1: Create S3 Buckets Using CloudFormation

### 1.1 Create CloudFormation Template

Navigate to the infrastructure directory and create the template:

```bash
cd ~/aws_data_pipeline
```

The CloudFormation template is already created at `infrastructure/cloudformation/s3-buckets.yaml`

### 1.2 Review the Template

The template includes:
- ✅ 5 S3 buckets (Raw, Processed, Curated, Scripts, Query Results)
- ✅ Encryption enabled (SSE-S3)
- ✅ Versioning enabled on critical buckets
- ✅ Lifecycle policies for cost optimization
- ✅ Public access blocked
- ✅ Bucket policies for secure access
- ✅ Tags for resource management

### 1.3 Deploy the CloudFormation Stack

```bash
# Load environment variables
source scripts/load_env.sh

# Get your AWS Account ID
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Deploy the stack
aws cloudformation create-stack \
  --stack-name data-pipeline-s3-buckets \
  --template-body file://infrastructure/cloudformation/s3-buckets.yaml \
  --parameters \
    ParameterKey=Environment,ParameterValue=dev \
    ParameterKey=ProjectName,ParameterValue=aws-data-pipeline \
  --capabilities CAPABILITY_NAMED_IAM \
  --tags \
    Key=Project,Value=DataPipeline \
    Key=Environment,Value=dev \
    Key=ManagedBy,Value=CloudFormation

# Monitor stack creation
aws cloudformation wait stack-create-complete \
  --stack-name data-pipeline-s3-buckets

echo "Stack created successfully!"
```

### 1.4 Verify Bucket Creation

```bash
# List all buckets
aws s3 ls | grep data-lake

# Expected output:
# data-lake-raw-zone-123456789012
# data-lake-processed-zone-123456789012
# data-lake-curated-zone-123456789012
# data-lake-scripts-123456789012
# data-lake-query-results-123456789012
```

## Step 2: Configure Bucket Policies

### 2.1 Raw Zone Bucket Policy

```bash
# Create bucket policy for raw zone
cat > /tmp/raw-zone-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowLambdaIngestion",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": [
        "s3:PutObject",
        "s3:PutObjectAcl"
      ],
      "Resource": "arn:aws:s3:::data-lake-raw-zone-${AWS_ACCOUNT_ID}/*"
    },
    {
      "Sid": "AllowGlueCrawler",
      "Effect": "Allow",
      "Principal": {
        "Service": "glue.amazonaws.com"
      },
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::data-lake-raw-zone-${AWS_ACCOUNT_ID}",
        "arn:aws:s3:::data-lake-raw-zone-${AWS_ACCOUNT_ID}/*"
      ]
    }
  ]
}
EOF

# Apply bucket policy
aws s3api put-bucket-policy \
  --bucket data-lake-raw-zone-${AWS_ACCOUNT_ID} \
  --policy file:///tmp/raw-zone-policy.json
```

## Step 3: Create Folder Structure

### 3.1 Create Sample Folder Structure

```bash
# Raw Zone structure
aws s3api put-object \
  --bucket data-lake-raw-zone-${AWS_ACCOUNT_ID} \
  --key sales/ \
  --content-length 0

aws s3api put-object \
  --bucket data-lake-raw-zone-${AWS_ACCOUNT_ID} \
  --key customers/ \
  --content-length 0

aws s3api put-object \
  --bucket data-lake-raw-zone-${AWS_ACCOUNT_ID} \
  --key products/ \
  --content-length 0

# Verify structure
aws s3 ls s3://data-lake-raw-zone-${AWS_ACCOUNT_ID}/
```

## Step 4: Set Up Lifecycle Policies

Lifecycle policies are already configured in the CloudFormation template:

### Raw Zone Lifecycle
- **Day 30**: Transition to Intelligent-Tiering
- **Day 90**: Transition to Glacier
- **Day 365**: Transition to Deep Archive

### Processed Zone Lifecycle
- **Day 90**: Transition to Intelligent-Tiering
- **Day 365**: Transition to Glacier

### Query Results Lifecycle
- **Day 30**: Delete old query results

### 4.1 Verify Lifecycle Rules

```bash
# Check lifecycle configuration for raw zone
aws s3api get-bucket-lifecycle-configuration \
  --bucket data-lake-raw-zone-${AWS_ACCOUNT_ID} | jq .

# Check processed zone
aws s3api get-bucket-lifecycle-configuration \
  --bucket data-lake-processed-zone-${AWS_ACCOUNT_ID} | jq .
```

## Step 5: Enable Bucket Notifications

### 5.1 Configure S3 Event Notifications

```bash
# Create notification configuration
cat > /tmp/s3-notifications.json << EOF
{
  "LambdaFunctionConfigurations": [
    {
      "Id": "NewDataNotification",
      "LambdaFunctionArn": "arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:data-ingestion-function",
      "Events": ["s3:ObjectCreated:*"],
      "Filter": {
        "Key": {
          "FilterRules": [
            {
              "Name": "suffix",
              "Value": ".json"
            }
          ]
        }
      }
    }
  ]
}
EOF

# Note: We'll apply this in the Lambda module
echo "Notification configuration prepared for Lambda module"
```

## Step 6: Upload Sample Data

### 6.1 Create Sample Sales Data

```bash
# Create sample data directory
mkdir -p sample_data

# Create sample CSV data
cat > sample_data/sales_data.csv << 'EOF'
transaction_id,date,customer_id,product_id,quantity,unit_price,total_amount,region,payment_method
TXN001,2024-11-16,CUST001,PROD101,2,29.99,59.98,US-EAST,credit_card
TXN002,2024-11-16,CUST002,PROD102,1,49.99,49.99,US-WEST,paypal
TXN003,2024-11-16,CUST003,PROD103,5,9.99,49.95,EU-WEST,debit_card
TXN004,2024-11-16,CUST001,PROD101,1,29.99,29.99,US-EAST,credit_card
TXN005,2024-11-16,CUST004,PROD104,3,19.99,59.97,AP-SOUTH,credit_card
TXN006,2024-11-16,CUST005,PROD105,2,39.99,79.98,US-WEST,paypal
TXN007,2024-11-16,CUST006,PROD101,4,29.99,119.96,EU-WEST,debit_card
TXN008,2024-11-16,CUST007,PROD106,1,99.99,99.99,US-EAST,credit_card
TXN009,2024-11-16,CUST008,PROD107,2,15.99,31.98,AP-SOUTH,paypal
TXN010,2024-11-16,CUST009,PROD108,1,129.99,129.99,US-WEST,credit_card
EOF

# Create sample JSON data
cat > sample_data/customers_data.json << 'EOF'
[
  {"customer_id": "CUST001", "name": "John Doe", "email": "john@example.com", "country": "USA", "signup_date": "2023-01-15"},
  {"customer_id": "CUST002", "name": "Jane Smith", "email": "jane@example.com", "country": "USA", "signup_date": "2023-02-20"},
  {"customer_id": "CUST003", "name": "Bob Wilson", "email": "bob@example.com", "country": "UK", "signup_date": "2023-03-10"},
  {"customer_id": "CUST004", "name": "Alice Brown", "email": "alice@example.com", "country": "USA", "signup_date": "2023-04-05"},
  {"customer_id": "CUST005", "name": "Charlie Davis", "email": "charlie@example.com", "country": "USA", "signup_date": "2023-05-12"}
]
EOF

# Create product data
cat > sample_data/products_data.json << 'EOF'
[
  {"product_id": "PROD101", "name": "Widget A", "category": "Electronics", "price": 29.99, "in_stock": true},
  {"product_id": "PROD102", "name": "Widget B", "category": "Electronics", "price": 49.99, "in_stock": true},
  {"product_id": "PROD103", "name": "Gadget X", "category": "Accessories", "price": 9.99, "in_stock": true},
  {"product_id": "PROD104", "name": "Device Y", "category": "Electronics", "price": 19.99, "in_stock": false},
  {"product_id": "PROD105", "name": "Tool Z", "category": "Hardware", "price": 39.99, "in_stock": true}
]
EOF
```

### 6.2 Upload Sample Data to S3

```bash
# Get current date for partitioning
YEAR=$(date +%Y)
MONTH=$(date +%m)
DAY=$(date +%d)

# Upload sales data with partitioning
aws s3 cp sample_data/sales_data.csv \
  s3://data-lake-raw-zone-${AWS_ACCOUNT_ID}/sales/year=${YEAR}/month=${MONTH}/day=${DAY}/sales_${YEAR}${MONTH}${DAY}.csv

# Upload customer data
aws s3 cp sample_data/customers_data.json \
  s3://data-lake-raw-zone-${AWS_ACCOUNT_ID}/customers/year=${YEAR}/month=${MONTH}/day=${DAY}/customers_${YEAR}${MONTH}${DAY}.json

# Upload product data
aws s3 cp sample_data/products_data.json \
  s3://data-lake-raw-zone-${AWS_ACCOUNT_ID}/products/year=${YEAR}/month=${MONTH}/day=${DAY}/products_${YEAR}${MONTH}${DAY}.json

# Verify uploads
aws s3 ls s3://data-lake-raw-zone-${AWS_ACCOUNT_ID}/sales/year=${YEAR}/month=${MONTH}/day=${DAY}/
aws s3 ls s3://data-lake-raw-zone-${AWS_ACCOUNT_ID}/customers/year=${YEAR}/month=${MONTH}/day=${DAY}/
aws s3 ls s3://data-lake-raw-zone-${AWS_ACCOUNT_ID}/products/year=${YEAR}/month=${MONTH}/day=${DAY}/
```

## Step 7: Test S3 Operations with Python

### 7.1 Create Python Script to Interact with S3

```bash
cat > scripts/test_s3.py << 'EOF'
#!/usr/bin/env python3
import boto3
import os
from datetime import datetime

# Initialize S3 client
s3 = boto3.client('s3')
account_id = boto3.client('sts').get_caller_identity()['Account']

# Define bucket names
raw_bucket = f"data-lake-raw-zone-{account_id}"
processed_bucket = f"data-lake-processed-zone-{account_id}"

def list_buckets():
    """List all data lake buckets"""
    print("\n=== Data Lake Buckets ===")
    response = s3.list_buckets()
    for bucket in response['Buckets']:
        if 'data-lake' in bucket['Name']:
            print(f"  ✓ {bucket['Name']}")

def list_files_in_bucket(bucket_name, prefix=''):
    """List files in a bucket"""
    print(f"\n=== Files in {bucket_name}/{prefix} ===")
    try:
        response = s3.list_objects_v2(Bucket=bucket_name, Prefix=prefix)
        if 'Contents' in response:
            for obj in response['Contents']:
                size_kb = obj['Size'] / 1024
                print(f"  📄 {obj['Key']} ({size_kb:.2f} KB)")
        else:
            print("  (empty)")
    except Exception as e:
        print(f"  ❌ Error: {e}")

def get_bucket_size(bucket_name):
    """Calculate total bucket size"""
    try:
        response = s3.list_objects_v2(Bucket=bucket_name)
        total_size = 0
        if 'Contents' in response:
            total_size = sum(obj['Size'] for obj in response['Contents'])
        size_mb = total_size / (1024 * 1024)
        print(f"  Total size: {size_mb:.2f} MB")
        return total_size
    except Exception as e:
        print(f"  ❌ Error: {e}")
        return 0

if __name__ == "__main__":
    print("=" * 50)
    print("S3 Data Lake Test Script")
    print("=" * 50)
    
    # List all buckets
    list_buckets()
    
    # List files in raw zone
    today = datetime.now()
    prefix = f"sales/year={today.year}/month={today.month:02d}/day={today.day:02d}/"
    list_files_in_bucket(raw_bucket, prefix)
    
    # Get bucket sizes
    print(f"\n=== Bucket Sizes ===")
    print(f"Raw Zone:")
    get_bucket_size(raw_bucket)
    print(f"Processed Zone:")
    get_bucket_size(processed_bucket)
    
    print("\n✅ Test complete!")
EOF

chmod +x scripts/test_s3.py

# Run the test
python3 scripts/test_s3.py
```

## Step 8: Create Data Partitioning Helper Script

```bash
cat > scripts/partition_helper.py << 'EOF'
#!/usr/bin/env python3
"""Helper script to generate S3 partition paths"""
from datetime import datetime, timedelta
import argparse

def generate_partition_path(date, source_name, prefix=''):
    """Generate S3 partition path"""
    path = f"{prefix}{source_name}/year={date.year}/month={date.month:02d}/day={date.day:02d}/"
    return path

def generate_date_range_partitions(start_date, end_date, source_name):
    """Generate partitions for a date range"""
    current_date = start_date
    partitions = []
    
    while current_date <= end_date:
        path = generate_partition_path(current_date, source_name)
        partitions.append(path)
        current_date += timedelta(days=1)
    
    return partitions

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Generate S3 partition paths')
    parser.add_argument('--source', required=True, help='Source name (e.g., sales, customers)')
    parser.add_argument('--date', help='Date (YYYY-MM-DD), default: today')
    parser.add_argument('--start-date', help='Start date for range (YYYY-MM-DD)')
    parser.add_argument('--end-date', help='End date for range (YYYY-MM-DD)')
    
    args = parser.parse_args()
    
    if args.start_date and args.end_date:
        start = datetime.strptime(args.start_date, '%Y-%m-%d')
        end = datetime.strptime(args.end_date, '%Y-%m-%d')
        partitions = generate_date_range_partitions(start, end, args.source)
        print("\n".join(partitions))
    else:
        date = datetime.strptime(args.date, '%Y-%m-%d') if args.date else datetime.now()
        print(generate_partition_path(date, args.source))
EOF

chmod +x scripts/partition_helper.py

# Test the script
python3 scripts/partition_helper.py --source sales
python3 scripts/partition_helper.py --source sales --date 2024-11-16
```

## Step 9: Monitor S3 Costs

### 9.1 Create Cost Monitoring Script

```bash
cat > scripts/monitor_s3_costs.sh << 'EOF'
#!/bin/bash

echo "=== S3 Storage Metrics ==="
echo

# Get account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Define buckets
BUCKETS=(
  "data-lake-raw-zone-${ACCOUNT_ID}"
  "data-lake-processed-zone-${ACCOUNT_ID}"
  "data-lake-curated-zone-${ACCOUNT_ID}"
  "data-lake-scripts-${ACCOUNT_ID}"
  "data-lake-query-results-${ACCOUNT_ID}"
)

# Calculate storage for each bucket
for bucket in "${BUCKETS[@]}"; do
  echo "Bucket: $bucket"
  
  # Get bucket size using AWS CLI
  total_size=$(aws s3 ls s3://${bucket} --recursive --summarize | \
    grep "Total Size" | \
    awk '{print $3}')
  
  if [ -n "$total_size" ]; then
    size_mb=$(echo "scale=2; $total_size / 1024 / 1024" | bc)
    size_gb=$(echo "scale=4; $total_size / 1024 / 1024 / 1024" | bc)
    
    # Estimate cost (Standard storage: $0.023 per GB)
    cost=$(echo "scale=4; $size_gb * 0.023" | bc)
    
    echo "  Size: ${size_mb} MB (${size_gb} GB)"
    echo "  Estimated monthly cost: \$${cost}"
  else
    echo "  Size: 0 MB"
    echo "  Estimated monthly cost: \$0"
  fi
  echo
done

echo "Note: Costs are estimates for Standard storage only."
echo "Actual costs include requests, data transfer, and other fees."
EOF

chmod +x scripts/monitor_s3_costs.sh
./scripts/monitor_s3_costs.sh
```

## Best Practices Implemented

✅ **Security**
- Block public access
- Enable encryption at rest
- Versioning for critical data
- Bucket policies with least privilege

✅ **Cost Optimization**
- Lifecycle policies for archival
- Intelligent-Tiering for variable access
- Delete old query results

✅ **Performance**
- Partitioning by date
- Parquet format for processed data
- Separate buckets for different zones

✅ **Data Governance**
- Clear naming conventions
- Consistent tagging strategy
- Audit logging ready

## Troubleshooting

### Issue: Bucket Already Exists
**Solution**: Bucket names must be globally unique. Add a suffix or use account ID.

### Issue: Access Denied
**Solution**: Check IAM permissions. User needs s3:CreateBucket, s3:PutBucketPolicy.

### Issue: CloudFormation Failed
**Solution**: Check CloudFormation console for detailed error messages. Delete stack and retry.

## Checklist

- [ ] CloudFormation stack deployed successfully
- [ ] All 5 buckets created
- [ ] Versioning enabled on critical buckets
- [ ] Lifecycle policies configured
- [ ] Sample data uploaded
- [ ] Bucket structure verified
- [ ] Python S3 test script works
- [ ] Cost monitoring setup

## Cost Estimate for This Module

- **S3 Storage**: $0.023 per GB/month (Standard)
- **Requests**: $0.0004 per 1,000 PUT requests
- **Data Transfer**: Free within same region
- **With sample data**: < $0.01/month

## Next Steps

✅ **S3 Configuration Complete!**

Proceed to [Module 3: Lambda Data Ingestion](./03-lambda-ingestion.md) to create automated data ingestion functions.

## Additional Resources

- [S3 Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/best-practices.html)
- [S3 Lifecycle Management](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lifecycle-mgmt.html)
- [S3 Security Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)
- [Data Lake on AWS](https://aws.amazon.com/big-data/datalakes-and-analytics/)

---

**Module Status**: ✅ Complete
**Previous Module**: [← Setup & Prerequisites](./01-setup.md)
**Next Module**: [Lambda Data Ingestion →](./03-lambda-ingestion.md)
