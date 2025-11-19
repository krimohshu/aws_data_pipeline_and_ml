# Phase 3: Lambda Data Ingestion

## Overview
Implement serverless Lambda functions to ingest data from various sources into your S3 data lake with support for multiple data formats, comprehensive error handling, and EventBridge triggers.

## Objectives
- Create Lambda functions for data ingestion
- Handle multiple data formats (JSON, CSV, API responses)
- Implement error handling and logging
- Configure IAM roles for Lambda
- Set up EventBridge triggers

## Architecture

```
EventBridge Schedule → Lambda Function → S3 Raw Zone
                            ↓
                     CloudWatch Logs
                            ↓
                     SNS Notifications (on error)
```

## Step 1: Create IAM Role for Lambda

### 1.1 Create Lambda Execution Role

```bash
# Create trust policy
cat > /tmp/lambda-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create the role
aws iam create-role \
  --role-name DataIngestionLambdaRole \
  --assume-role-policy-document file:///tmp/lambda-trust-policy.json \
  --description "Execution role for data ingestion Lambda functions"

# Create permissions policy
cat > /tmp/lambda-permissions-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:PutObjectAcl",
        "s3:GetObject"
      ],
      "Resource": [
        "arn:aws:s3:::data-lake-raw-zone-${AWS_ACCOUNT_ID}/*",
        "arn:aws:s3:::data-lake-scripts-${AWS_ACCOUNT_ID}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "cloudwatch:PutMetricData"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# Attach the policy
aws iam put-role-policy \
  --role-name DataIngestionLambdaRole \
  --policy-name DataIngestionPolicy \
  --policy-document file:///tmp/lambda-permissions-policy.json

echo "IAM role created successfully!"
```

## Step 2: Create Lambda Function Code

### 2.1 Sales Data Ingestion Function

```bash
mkdir -p lambda/ingestion
cd lambda/ingestion

# Create the Lambda handler
cat > handler.py << 'EOF'
import json
import boto3
import os
import csv
from datetime import datetime
from io import StringIO
import logging
import random

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
s3 = boto3.client('s3')
cloudwatch = boto3.client('cloudwatch')

# Environment variables
RAW_BUCKET = os.environ.get('RAW_BUCKET')
SOURCE_NAME = os.environ.get('SOURCE_NAME', 'sales')

def generate_sample_sales_data(num_records=10):
    """Generate sample sales data for demonstration"""
    products = ['PROD101', 'PROD102', 'PROD103', 'PROD104', 'PROD105']
    customers = ['CUST001', 'CUST002', 'CUST003', 'CUST004', 'CUST005']
    regions = ['US-EAST', 'US-WEST', 'EU-WEST', 'AP-SOUTH']
    payment_methods = ['credit_card', 'paypal', 'debit_card']
    
    sales_data = []
    for i in range(num_records):
        product_id = random.choice(products)
        quantity = random.randint(1, 5)
        unit_price = round(random.uniform(9.99, 129.99), 2)
        total = round(quantity * unit_price, 2)
        
        transaction = {
            'transaction_id': f'TXN{str(i+1).zfill(6)}',
            'date': datetime.now().strftime('%Y-%m-%d'),
            'timestamp': datetime.now().isoformat(),
            'customer_id': random.choice(customers),
            'product_id': product_id,
            'quantity': quantity,
            'unit_price': unit_price,
            'total_amount': total,
            'region': random.choice(regions),
            'payment_method': random.choice(payment_methods)
        }
        sales_data.append(transaction)
    
    return sales_data

def convert_to_csv(data):
    """Convert JSON data to CSV format"""
    if not data:
        return ""
    
    output = StringIO()
    writer = csv.DictWriter(output, fieldnames=data[0].keys())
    writer.writeheader()
    writer.writerows(data)
    
    return output.getvalue()

def upload_to_s3(data, file_format='json'):
    """Upload data to S3 with partitioning"""
    now = datetime.now()
    
    # Create partition path
    partition_path = f"{SOURCE_NAME}/year={now.year}/month={now.month:02d}/day={now.day:02d}/"
    
    # Create filename
    timestamp = now.strftime('%Y%m%d_%H%M%S')
    filename = f"{SOURCE_NAME}_{timestamp}.{file_format}"
    
    # Full S3 key
    s3_key = f"{partition_path}{filename}"
    
    # Prepare data
    if file_format == 'json':
        body = json.dumps(data, indent=2)
        content_type = 'application/json'
    elif file_format == 'csv':
        body = convert_to_csv(data)
        content_type = 'text/csv'
    else:
        raise ValueError(f"Unsupported format: {file_format}")
    
    # Upload to S3
    try:
        s3.put_object(
            Bucket=RAW_BUCKET,
            Key=s3_key,
            Body=body,
            ContentType=content_type,
            Metadata={
                'source': SOURCE_NAME,
                'ingestion_time': now.isoformat(),
                'record_count': str(len(data))
            }
        )
        
        logger.info(f"Successfully uploaded {len(data)} records to s3://{RAW_BUCKET}/{s3_key}")
        return s3_key
        
    except Exception as e:
        logger.error(f"Error uploading to S3: {str(e)}")
        raise

def publish_metrics(record_count, success=True):
    """Publish custom metrics to CloudWatch"""
    try:
        cloudwatch.put_metric_data(
            Namespace='DataPipeline/Ingestion',
            MetricData=[
                {
                    'MetricName': 'RecordsIngested',
                    'Value': record_count,
                    'Unit': 'Count',
                    'Dimensions': [
                        {'Name': 'Source', 'Value': SOURCE_NAME},
                        {'Name': 'Status', 'Value': 'Success' if success else 'Failed'}
                    ]
                }
            ]
        )
    except Exception as e:
        logger.warning(f"Failed to publish metrics: {str(e)}")

def lambda_handler(event, context):
    """
    Main Lambda handler for data ingestion
    
    Event structure:
    {
        "source": "sales",
        "format": "json",  # or "csv"
        "num_records": 100
    }
    """
    try:
        logger.info(f"Starting data ingestion: {json.dumps(event)}")
        
        # Parse event parameters
        file_format = event.get('format', 'json')
        num_records = event.get('num_records', 10)
        
        # Generate sample data (in production, fetch from actual source)
        logger.info(f"Generating {num_records} sample records...")
        data = generate_sample_sales_data(num_records)
        
        # Upload to S3
        s3_key = upload_to_s3(data, file_format)
        
        # Publish metrics
        publish_metrics(len(data), success=True)
        
        # Return success response
        response = {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Data ingestion successful',
                'records_processed': len(data),
                's3_location': f"s3://{RAW_BUCKET}/{s3_key}",
                'timestamp': datetime.now().isoformat()
            })
        }
        
        logger.info(f"Ingestion completed successfully")
        return response
        
    except Exception as e:
        logger.error(f"Error in data ingestion: {str(e)}", exc_info=True)
        
        # Publish failure metrics
        publish_metrics(0, success=False)
        
        # Return error response
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': 'Data ingestion failed',
                'error': str(e),
                'timestamp': datetime.now().isoformat()
            })
        }
EOF

# Create requirements file
cat > requirements.txt << 'EOF'
boto3>=1.28.0
EOF

# Create README
cat > README.md << 'EOF'
# Lambda Data Ingestion Function

This Lambda function ingests data from various sources and stores it in the S3 raw zone.

## Features
- Generate sample sales data
- Support JSON and CSV formats
- Automatic S3 partitioning by date
- CloudWatch metrics and logging
- Error handling and retry logic

## Environment Variables
- `RAW_BUCKET`: S3 bucket for raw data
- `SOURCE_NAME`: Name of the data source

## Testing Locally
```bash
python3 -c "
import handler
event = {'format': 'json', 'num_records': 10}
handler.lambda_handler(event, None)
"
```
EOF

echo "Lambda function code created!"
cd ../..
```

## Step 3: Package and Deploy Lambda Function

### 3.1 Package the Function

```bash
cd lambda/ingestion

# Create deployment package
mkdir -p package
pip install -r requirements.txt -t package/
cp handler.py package/
cd package
zip -r ../function.zip .
cd ..

echo "Lambda package created: lambda/ingestion/function.zip"
cd ../..
```

### 3.2 Deploy Lambda Function

```bash
# Get the role ARN
ROLE_ARN=$(aws iam get-role --role-name DataIngestionLambdaRole --query 'Role.Arn' --output text)

# Create Lambda function
aws lambda create-function \
  --function-name data-ingestion-function \
  --runtime python3.11 \
  --role $ROLE_ARN \
  --handler handler.lambda_handler \
  --zip-file fileb://lambda/ingestion/function.zip \
  --timeout 300 \
  --memory-size 512 \
  --environment "Variables={RAW_BUCKET=data-lake-raw-zone-${AWS_ACCOUNT_ID},SOURCE_NAME=sales}" \
  --description "Ingests sales data into S3 raw zone" \
  --tags Project=DataPipeline,Environment=dev,ManagedBy=CLI

echo "Lambda function deployed successfully!"
```

### 3.3 Grant S3 Permissions to Lambda

```bash
# Add permission for S3 to invoke Lambda (for event notifications)
aws lambda add-permission \
  --function-name data-ingestion-function \
  --statement-id s3-trigger-permission \
  --action lambda:InvokeFunction \
  --principal s3.amazonaws.com \
  --source-arn arn:aws:s3:::data-lake-raw-zone-${AWS_ACCOUNT_ID}
```

## Step 4: Test Lambda Function

### 4.1 Test with AWS CLI

```bash
# Create test event
cat > /tmp/test-event.json << 'EOF'
{
  "format": "json",
  "num_records": 20
}
EOF

# Invoke Lambda function
aws lambda invoke \
  --function-name data-ingestion-function \
  --payload file:///tmp/test-event.json \
  --cli-binary-format raw-in-base64-out \
  /tmp/lambda-output.json

# View response
cat /tmp/lambda-output.json | jq .

# Check CloudWatch Logs
aws logs tail /aws/lambda/data-ingestion-function --follow
```

### 4.2 Verify Data in S3

```bash
# List uploaded files
aws s3 ls s3://data-lake-raw-zone-${AWS_ACCOUNT_ID}/sales/ --recursive

# Download and view a file
YEAR=$(date +%Y)
MONTH=$(date +%m)
DAY=$(date +%d)

# Find the latest file
LATEST_FILE=$(aws s3 ls s3://data-lake-raw-zone-${AWS_ACCOUNT_ID}/sales/year=${YEAR}/month=${MONTH}/day=${DAY}/ | tail -1 | awk '{print $4}')

# Download and view
aws s3 cp s3://data-lake-raw-zone-${AWS_ACCOUNT_ID}/sales/year=${YEAR}/month=${MONTH}/day=${DAY}/${LATEST_FILE} - | jq .
```

## Step 5: Create EventBridge Rule for Automation

### 5.1 Create Scheduled Rule

```bash
# Create rule for daily ingestion at 2 AM UTC
aws events put-rule \
  --name daily-sales-ingestion \
  --schedule-expression "cron(0 2 * * ? *)" \
  --state ENABLED \
  --description "Trigger sales data ingestion daily at 2 AM UTC"

# Add Lambda as target
aws events put-targets \
  --rule daily-sales-ingestion \
  --targets "Id"="1","Arn"="arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:data-ingestion-function","Input"='{"format":"json","num_records":100}'

# Grant EventBridge permission to invoke Lambda
aws lambda add-permission \
  --function-name data-ingestion-function \
  --statement-id eventbridge-daily-trigger \
  --action lambda:InvokeFunction \
  --principal events.amazonaws.com \
  --source-arn arn:aws:events:${AWS_REGION}:${AWS_ACCOUNT_ID}:rule/daily-sales-ingestion

echo "EventBridge rule created successfully!"
```

### 5.2 Create On-Demand Trigger

```bash
# Create rule for manual triggers
aws events put-rule \
  --name on-demand-sales-ingestion \
  --event-pattern '{"source":["custom.datapipeline"],"detail-type":["ManualIngestion"]}' \
  --state ENABLED \
  --description "Manual trigger for sales data ingestion"

# Add Lambda as target
aws events put-targets \
  --rule on-demand-sales-ingestion \
  --targets "Id"="1","Arn"="arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:data-ingestion-function"
```

## Step 6: Create Monitoring Dashboard

### 6.1 CloudWatch Dashboard

```bash
cat > /tmp/dashboard.json << EOF
{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["DataPipeline/Ingestion", "RecordsIngested", {"stat": "Sum"}]
        ],
        "period": 300,
        "stat": "Sum",
        "region": "${AWS_REGION}",
        "title": "Records Ingested",
        "yAxis": {
          "left": {
            "min": 0
          }
        }
      }
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/Lambda", "Invocations", {"stat": "Sum", "dimensions": {"FunctionName": "data-ingestion-function"}}],
          [".", "Errors", {"stat": "Sum", "dimensions": {"FunctionName": "data-ingestion-function"}}]
        ],
        "period": 300,
        "stat": "Sum",
        "region": "${AWS_REGION}",
        "title": "Lambda Invocations & Errors"
      }
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/Lambda", "Duration", {"stat": "Average", "dimensions": {"FunctionName": "data-ingestion-function"}}]
        ],
        "period": 300,
        "stat": "Average",
        "region": "${AWS_REGION}",
        "title": "Lambda Duration (ms)"
      }
    }
  ]
}
EOF

# Create dashboard
aws cloudwatch put-dashboard \
  --dashboard-name DataPipeline-Ingestion \
  --dashboard-body file:///tmp/dashboard.json

echo "CloudWatch dashboard created!"
```

## Step 7: Create Additional Ingestion Functions

### 7.1 Customer Data Ingestion

```bash
# Copy and modify for customer data
cp -r lambda/ingestion lambda/customer_ingestion

# Modify for customer data
cat > lambda/customer_ingestion/handler.py << 'EOF'
import json
import boto3
import os
from datetime import datetime
import logging
import random

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client('s3')
RAW_BUCKET = os.environ.get('RAW_BUCKET')

def generate_customer_data(num_records=10):
    """Generate sample customer data"""
    countries = ['USA', 'UK', 'Canada', 'Australia', 'Germany']
    
    customers = []
    for i in range(num_records):
        customer = {
            'customer_id': f'CUST{str(i+1).zfill(5)}',
            'name': f'Customer {i+1}',
            'email': f'customer{i+1}@example.com',
            'country': random.choice(countries),
            'signup_date': datetime.now().strftime('%Y-%m-%d'),
            'created_at': datetime.now().isoformat()
        }
        customers.append(customer)
    
    return customers

def lambda_handler(event, context):
    try:
        num_records = event.get('num_records', 10)
        data = generate_customer_data(num_records)
        
        now = datetime.now()
        s3_key = f"customers/year={now.year}/month={now.month:02d}/day={now.day:02d}/customers_{now.strftime('%Y%m%d_%H%M%S')}.json"
        
        s3.put_object(
            Bucket=RAW_BUCKET,
            Key=s3_key,
            Body=json.dumps(data, indent=2),
            ContentType='application/json'
        )
        
        logger.info(f"Uploaded {len(data)} customer records to {s3_key}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Success', 'records': len(data)})
        }
    except Exception as e:
        logger.error(f"Error: {str(e)}")
        return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}
EOF

# Package and deploy
cd lambda/customer_ingestion
zip -r function.zip handler.py
cd ../..

aws lambda create-function \
  --function-name customer-ingestion-function \
  --runtime python3.11 \
  --role $ROLE_ARN \
  --handler handler.lambda_handler \
  --zip-file fileb://lambda/customer_ingestion/function.zip \
  --timeout 300 \
  --memory-size 512 \
  --environment "Variables={RAW_BUCKET=data-lake-raw-zone-${AWS_ACCOUNT_ID}}" \
  --description "Ingests customer data" \
  --tags Project=DataPipeline

echo "Customer ingestion function deployed!"
```

## Step 8: Testing and Validation

### 8.1 Create Test Script

```bash
cat > scripts/test_ingestion.sh << 'EOF'
#!/bin/bash

echo "=== Testing Lambda Data Ingestion ==="
echo

# Test sales ingestion
echo "1. Testing sales ingestion..."
aws lambda invoke \
  --function-name data-ingestion-function \
  --payload '{"format":"json","num_records":50}' \
  --cli-binary-format raw-in-base64-out \
  /tmp/sales-output.json > /dev/null

cat /tmp/sales-output.json | jq .
echo

# Test customer ingestion
echo "2. Testing customer ingestion..."
aws lambda invoke \
  --function-name customer-ingestion-function \
  --payload '{"num_records":25}' \
  --cli-binary-format raw-in-base64-out \
  /tmp/customer-output.json > /dev/null

cat /tmp/customer-output.json | jq .
echo

# Verify S3 uploads
echo "3. Verifying S3 uploads..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Sales data:"
aws s3 ls s3://data-lake-raw-zone-${ACCOUNT_ID}/sales/ --recursive | tail -3
echo
echo "Customer data:"
aws s3 ls s3://data-lake-raw-zone-${ACCOUNT_ID}/customers/ --recursive | tail -3

echo
echo "✅ Testing complete!"
EOF

chmod +x scripts/test_ingestion.sh
./scripts/test_ingestion.sh
```

## Best Practices Implemented

✅ **Error Handling**: Try-catch blocks with proper logging
✅ **Monitoring**: CloudWatch metrics and logs
✅ **Security**: IAM roles with least privilege
✅ **Partitioning**: Date-based S3 partitioning
✅ **Metadata**: S3 object metadata for tracking
✅ **Idempotency**: Unique filenames with timestamps

## Troubleshooting

### Issue: Lambda times out
**Solution**: Increase timeout or reduce batch size

### Issue: Permission denied writing to S3
**Solution**: Verify IAM role has s3:PutObject permission

### Issue: Function not triggered by EventBridge
**Solution**: Check EventBridge rule status and Lambda permissions

## Checklist

- [ ] IAM role created with proper permissions
- [ ] Lambda function code written and packaged
- [ ] Function deployed to AWS
- [ ] Manual test successful
- [ ] EventBridge rule configured
- [ ] CloudWatch dashboard created
- [ ] S3 data verified
- [ ] Customer ingestion function deployed

## Cost Estimate

- **Lambda**: Free tier includes 1M requests/month
- **CloudWatch Logs**: $0.50 per GB ingested
- **EventBridge**: $1 per million events
- **Estimated**: < $1/month for development

## Next Steps

✅ **Lambda Ingestion Complete!**

Proceed to [Module 4: AWS Glue ETL](./04-glue-etl.md) to transform and process your raw data.

---

**Module Status**: ✅ Complete
**Previous**: [← S3 Configuration](./02-s3-configuration.md)
**Next**: [AWS Glue ETL →](./04-glue-etl.md)
