#!/bin/bash

# AWS Data Pipeline - Quick Start Deployment Script
# This script automates the deployment of the entire data pipeline

set -e  # Exit on error

echo "=================================================="
echo "  AWS Data Pipeline - Quick Start Deployment"
echo "=================================================="
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI not found. Please install it first.${NC}"
    exit 1
fi

# Check if AWS credentials are configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}❌ AWS credentials not configured. Run 'aws configure' first.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ AWS CLI configured${NC}"

# Get AWS Account ID and Region
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=$(aws configure get region)

echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo "AWS Region: $AWS_REGION"
echo

# Load environment variables
if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs)
    echo -e "${GREEN}✅ Environment variables loaded${NC}"
else
    echo -e "${YELLOW}⚠️  .env file not found. Using defaults.${NC}"
fi
echo

# Function to check if CloudFormation stack exists
stack_exists() {
    aws cloudformation describe-stacks --stack-name $1 &> /dev/null
}

# Step 1: Deploy S3 Buckets
echo "Step 1: Deploying S3 Buckets..."
if stack_exists "data-pipeline-s3-buckets"; then
    echo -e "${YELLOW}Stack already exists. Skipping...${NC}"
else
    aws cloudformation create-stack \
        --stack-name data-pipeline-s3-buckets \
        --template-body file://infrastructure/cloudformation/s3-buckets.yaml \
        --parameters \
            ParameterKey=Environment,ParameterValue=dev \
            ParameterKey=ProjectName,ParameterValue=aws-data-pipeline \
        --tags \
            Key=Project,Value=DataPipeline \
            Key=Environment,Value=dev \
            Key=ManagedBy,Value=CloudFormation
    
    echo "Waiting for stack creation..."
    aws cloudformation wait stack-create-complete --stack-name data-pipeline-s3-buckets
    echo -e "${GREEN}✅ S3 Buckets created${NC}"
fi
echo

# Step 2: Upload Sample Data
echo "Step 2: Uploading sample data to S3..."
YEAR=$(date +%Y)
MONTH=$(date +%m)
DAY=$(date +%d)

aws s3 cp sample_data/sales_data.csv \
    s3://data-lake-raw-zone-${AWS_ACCOUNT_ID}/sales/year=${YEAR}/month=${MONTH}/day=${DAY}/

aws s3 cp sample_data/customers_data.json \
    s3://data-lake-raw-zone-${AWS_ACCOUNT_ID}/customers/year=${YEAR}/month=${MONTH}/day=${DAY}/

aws s3 cp sample_data/products_data.json \
    s3://data-lake-raw-zone-${AWS_ACCOUNT_ID}/products/year=${YEAR}/month=${MONTH}/day=${DAY}/

echo -e "${GREEN}✅ Sample data uploaded${NC}"
echo

# Step 3: Create IAM Role for Lambda
echo "Step 3: Creating IAM Role for Lambda..."
if aws iam get-role --role-name DataIngestionLambdaRole &> /dev/null; then
    echo -e "${YELLOW}Role already exists. Skipping...${NC}"
else
    cat > /tmp/lambda-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "lambda.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}
EOF

    aws iam create-role \
        --role-name DataIngestionLambdaRole \
        --assume-role-policy-document file:///tmp/lambda-trust-policy.json \
        --description "Execution role for data ingestion Lambda"

    cat > /tmp/lambda-permissions.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:PutObject", "s3:GetObject"],
      "Resource": "arn:aws:s3:::data-lake-*-${AWS_ACCOUNT_ID}/*"
    },
    {
      "Effect": "Allow",
      "Action": ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
      "Resource": "arn:aws:logs:*:*:*"
    },
    {
      "Effect": "Allow",
      "Action": ["cloudwatch:PutMetricData"],
      "Resource": "*"
    }
  ]
}
EOF

    aws iam put-role-policy \
        --role-name DataIngestionLambdaRole \
        --policy-name DataIngestionPolicy \
        --policy-document file:///tmp/lambda-permissions.json

    echo "Waiting for role to be available..."
    sleep 10
    echo -e "${GREEN}✅ IAM Role created${NC}"
fi
echo

# Step 4: Package and Deploy Lambda
echo "Step 4: Deploying Lambda function..."
if [ -d "lambda/ingestion" ]; then
    cd lambda/ingestion
    
    # Create package if not exists
    if [ ! -f "function.zip" ]; then
        mkdir -p package
        pip install -r requirements.txt -t package/ -q
        cp handler.py package/
        cd package
        zip -r ../function.zip . > /dev/null
        cd ..
        rm -rf package
    fi
    
    cd ../..
    
    # Get role ARN
    ROLE_ARN=$(aws iam get-role --role-name DataIngestionLambdaRole --query 'Role.Arn' --output text)
    
    # Check if function exists
    if aws lambda get-function --function-name data-ingestion-function &> /dev/null; then
        echo -e "${YELLOW}Lambda function already exists. Updating code...${NC}"
        aws lambda update-function-code \
            --function-name data-ingestion-function \
            --zip-file fileb://lambda/ingestion/function.zip > /dev/null
    else
        aws lambda create-function \
            --function-name data-ingestion-function \
            --runtime python3.11 \
            --role $ROLE_ARN \
            --handler handler.lambda_handler \
            --zip-file fileb://lambda/ingestion/function.zip \
            --timeout 300 \
            --memory-size 512 \
            --environment "Variables={RAW_BUCKET=data-lake-raw-zone-${AWS_ACCOUNT_ID},SOURCE_NAME=sales}" \
            --description "Ingests sales data" \
            --tags Project=DataPipeline > /dev/null
    fi
    
    echo -e "${GREEN}✅ Lambda function deployed${NC}"
else
    echo -e "${YELLOW}⚠️  Lambda code not found. Skipping...${NC}"
fi
echo

# Step 5: Create EventBridge Rule
echo "Step 5: Creating EventBridge schedule..."
if aws events describe-rule --name daily-sales-ingestion &> /dev/null; then
    echo -e "${YELLOW}Rule already exists. Skipping...${NC}"
else
    aws events put-rule \
        --name daily-sales-ingestion \
        --schedule-expression "cron(0 2 * * ? *)" \
        --state ENABLED \
        --description "Daily sales data ingestion"
    
    aws events put-targets \
        --rule daily-sales-ingestion \
        --targets "Id"="1","Arn"="arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:data-ingestion-function","Input"='{"format":"json","num_records":100}'
    
    aws lambda add-permission \
        --function-name data-ingestion-function \
        --statement-id eventbridge-daily-trigger \
        --action lambda:InvokeFunction \
        --principal events.amazonaws.com \
        --source-arn arn:aws:events:${AWS_REGION}:${AWS_ACCOUNT_ID}:rule/daily-sales-ingestion &> /dev/null || true
    
    echo -e "${GREEN}✅ EventBridge rule created${NC}"
fi
echo

# Summary
echo "=================================================="
echo "  Deployment Complete!"
echo "=================================================="
echo
echo "Resources Created:"
echo "  ✅ S3 Buckets (5)"
echo "  ✅ IAM Role for Lambda"
echo "  ✅ Lambda Function"
echo "  ✅ EventBridge Rule"
echo "  ✅ Sample Data Uploaded"
echo
echo "Next Steps:"
echo "  1. Test Lambda: ./scripts/test_ingestion.sh"
echo "  2. View logs: aws logs tail /aws/lambda/data-ingestion-function --follow"
echo "  3. Continue to Module 4 for Glue ETL setup"
echo
echo "Useful Commands:"
echo "  - List buckets: aws s3 ls | grep data-lake"
echo "  - Invoke Lambda: aws lambda invoke --function-name data-ingestion-function --payload '{\"format\":\"json\",\"num_records\":20}' /tmp/output.json"
echo "  - View S3 data: aws s3 ls s3://data-lake-raw-zone-${AWS_ACCOUNT_ID}/sales/ --recursive"
echo
echo "Cost Estimate: < \$1/day for development usage"
echo
