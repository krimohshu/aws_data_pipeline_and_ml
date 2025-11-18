#!/bin/bash

# Clean up all AWS resources created by the data pipeline

set -e

echo "=================================================="
echo "  AWS Data Pipeline - Cleanup Script"
echo "=================================================="
echo
echo "⚠️  WARNING: This will delete all pipeline resources!"
echo "Press Ctrl+C to cancel, or Enter to continue..."
read

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=$(aws configure get region)

echo "Account: $AWS_ACCOUNT_ID"
echo "Region: $AWS_REGION"
echo

# Delete Lambda functions
echo "Deleting Lambda functions..."
aws lambda delete-function --function-name data-ingestion-function 2>/dev/null || echo "  Function not found"
aws lambda delete-function --function-name customer-ingestion-function 2>/dev/null || echo "  Function not found"
echo -e "${GREEN}✅ Lambda functions deleted${NC}"

# Delete EventBridge rules
echo "Deleting EventBridge rules..."
aws events remove-targets --rule daily-sales-ingestion --ids 1 2>/dev/null || true
aws events delete-rule --name daily-sales-ingestion 2>/dev/null || echo "  Rule not found"
echo -e "${GREEN}✅ EventBridge rules deleted${NC}"

# Delete IAM roles
echo "Deleting IAM roles..."
aws iam delete-role-policy --role-name DataIngestionLambdaRole --policy-name DataIngestionPolicy 2>/dev/null || true
aws iam delete-role --role-name DataIngestionLambdaRole 2>/dev/null || echo "  Role not found"
echo -e "${GREEN}✅ IAM roles deleted${NC}"

# Empty and delete S3 buckets
echo "Emptying and deleting S3 buckets..."
BUCKETS=(
    "data-lake-raw-zone-${AWS_ACCOUNT_ID}"
    "data-lake-processed-zone-${AWS_ACCOUNT_ID}"
    "data-lake-curated-zone-${AWS_ACCOUNT_ID}"
    "data-lake-scripts-${AWS_ACCOUNT_ID}"
    "data-lake-query-results-${AWS_ACCOUNT_ID}"
)

for bucket in "${BUCKETS[@]}"; do
    if aws s3 ls "s3://${bucket}" 2>/dev/null; then
        echo "  Emptying ${bucket}..."
        aws s3 rm "s3://${bucket}" --recursive
        echo "  Deleting ${bucket}..."
        aws s3 rb "s3://${bucket}"
    fi
done
echo -e "${GREEN}✅ S3 buckets deleted${NC}"

# Delete CloudFormation stacks
echo "Deleting CloudFormation stacks..."
aws cloudformation delete-stack --stack-name data-pipeline-s3-buckets 2>/dev/null || echo "  Stack not found"
echo -e "${GREEN}✅ CloudFormation stacks deleted${NC}"

# Delete CloudWatch dashboards
echo "Deleting CloudWatch dashboards..."
aws cloudwatch delete-dashboards --dashboard-names DataPipeline-Ingestion 2>/dev/null || echo "  Dashboard not found"
echo -e "${GREEN}✅ CloudWatch dashboards deleted${NC}"

echo
echo "=================================================="
echo "  Cleanup Complete!"
echo "=================================================="
echo
echo "All pipeline resources have been removed."
echo
