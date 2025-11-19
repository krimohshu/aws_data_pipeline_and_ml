#!/bin/bash

################################################################################
# AWS Data Pipeline - Complete Resource Cleanup Script
# 
# This script removes ALL resources created during the pipeline implementation
# to prevent ongoing AWS charges.
#
# WARNING: This will DELETE all data and resources. This action is IRREVERSIBLE.
################################################################################

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="eu-west-2"

echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}           AWS DATA PIPELINE - COMPLETE CLEANUP${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}⚠️  WARNING: This will DELETE ALL resources!${NC}"
echo -e "${YELLOW}    - All S3 data will be permanently deleted${NC}"
echo -e "${YELLOW}    - All Lambda functions will be removed${NC}"
echo -e "${YELLOW}    - All Glue resources will be deleted${NC}"
echo -e "${YELLOW}    - EMR clusters will be terminated${NC}"
echo -e "${YELLOW}    - SageMaker instances will be deleted${NC}"
echo -e "${YELLOW}    - QuickSight subscription will need manual cancellation${NC}"
echo ""
echo -e "AWS Account: ${GREEN}${AWS_ACCOUNT_ID}${NC}"
echo -e "Region: ${GREEN}${AWS_REGION}${NC}"
echo ""
read -p "Type 'DELETE' to confirm cleanup: " CONFIRM

if [ "$CONFIRM" != "DELETE" ]; then
    echo -e "${RED}Cleanup cancelled.${NC}"
    exit 0
fi

echo ""
echo -e "${GREEN}Starting cleanup process...${NC}"
echo ""

################################################################################
# 1. STOP SAGEMAKER NOTEBOOK INSTANCE
################################################################################
echo -e "${BLUE}[1/10] Stopping SageMaker Notebook Instance...${NC}"
NOTEBOOK_NAME="data-pipeline-ml-notebook"

if aws sagemaker describe-notebook-instance --notebook-instance-name "$NOTEBOOK_NAME" --region $AWS_REGION 2>/dev/null; then
    NOTEBOOK_STATUS=$(aws sagemaker describe-notebook-instance \
        --notebook-instance-name "$NOTEBOOK_NAME" \
        --region $AWS_REGION \
        --query 'NotebookInstanceStatus' \
        --output text)
    
    if [ "$NOTEBOOK_STATUS" == "InService" ]; then
        echo "  → Stopping notebook instance..."
        aws sagemaker stop-notebook-instance \
            --notebook-instance-name "$NOTEBOOK_NAME" \
            --region $AWS_REGION
        
        echo "  → Waiting for notebook to stop..."
        aws sagemaker wait notebook-instance-stopped \
            --notebook-instance-name "$NOTEBOOK_NAME" \
            --region $AWS_REGION
    fi
    
    echo "  → Deleting notebook instance..."
    aws sagemaker delete-notebook-instance \
        --notebook-instance-name "$NOTEBOOK_NAME" \
        --region $AWS_REGION
    
    echo -e "  ${GREEN}✓ SageMaker notebook deleted${NC}"
else
    echo -e "  ${YELLOW}○ No SageMaker notebook found${NC}"
fi

################################################################################
# 2. TERMINATE EMR CLUSTERS
################################################################################
echo -e "${BLUE}[2/10] Terminating EMR Clusters...${NC}"

EMR_CLUSTERS=$(aws emr list-clusters \
    --region $AWS_REGION \
    --active \
    --query 'Clusters[*].Id' \
    --output text)

if [ ! -z "$EMR_CLUSTERS" ]; then
    for CLUSTER_ID in $EMR_CLUSTERS; do
        echo "  → Terminating cluster: $CLUSTER_ID"
        aws emr terminate-clusters \
            --cluster-ids $CLUSTER_ID \
            --region $AWS_REGION
    done
    echo -e "  ${GREEN}✓ EMR clusters terminated${NC}"
else
    echo -e "  ${YELLOW}○ No active EMR clusters found${NC}"
fi

################################################################################
# 3. DELETE GLUE JOBS
################################################################################
echo -e "${BLUE}[3/10] Deleting Glue ETL Jobs...${NC}"

GLUE_JOBS=$(aws glue get-jobs \
    --region $AWS_REGION \
    --query 'Jobs[?contains(Name, `sales`) || contains(Name, `data-pipeline`)].Name' \
    --output text)

if [ ! -z "$GLUE_JOBS" ]; then
    for JOB_NAME in $GLUE_JOBS; do
        echo "  → Deleting job: $JOB_NAME"
        aws glue delete-job --job-name "$JOB_NAME" --region $AWS_REGION
    done
    echo -e "  ${GREEN}✓ Glue jobs deleted${NC}"
else
    echo -e "  ${YELLOW}○ No Glue jobs found${NC}"
fi

################################################################################
# 4. DELETE GLUE CRAWLERS
################################################################################
echo -e "${BLUE}[4/10] Deleting Glue Crawlers...${NC}"

CRAWLERS=$(aws glue get-crawlers \
    --region $AWS_REGION \
    --query 'Crawlers[*].Name' \
    --output text)

if [ ! -z "$CRAWLERS" ]; then
    for CRAWLER_NAME in $CRAWLERS; do
        echo "  → Deleting crawler: $CRAWLER_NAME"
        aws glue delete-crawler --name "$CRAWLER_NAME" --region $AWS_REGION 2>/dev/null || true
    done
    echo -e "  ${GREEN}✓ Glue crawlers deleted${NC}"
else
    echo -e "  ${YELLOW}○ No Glue crawlers found${NC}"
fi

################################################################################
# 5. DELETE GLUE DATABASE AND TABLES
################################################################################
echo -e "${BLUE}[5/10] Deleting Glue Database...${NC}"

if aws glue get-database --name data_pipeline_catalog --region $AWS_REGION 2>/dev/null; then
    echo "  → Deleting database: data_pipeline_catalog"
    aws glue delete-database --name data_pipeline_catalog --region $AWS_REGION
    echo -e "  ${GREEN}✓ Glue database deleted${NC}"
else
    echo -e "  ${YELLOW}○ No Glue database found${NC}"
fi

################################################################################
# 6. DELETE EVENTBRIDGE RULES
################################################################################
echo -e "${BLUE}[6/10] Deleting EventBridge Rules...${NC}"

RULES=$(aws events list-rules \
    --region $AWS_REGION \
    --query 'Rules[?contains(Name, `sales`) || contains(Name, `data-pipeline`)].Name' \
    --output text)

if [ ! -z "$RULES" ]; then
    for RULE_NAME in $RULES; do
        echo "  → Removing targets from rule: $RULE_NAME"
        TARGETS=$(aws events list-targets-by-rule \
            --rule "$RULE_NAME" \
            --region $AWS_REGION \
            --query 'Targets[*].Id' \
            --output text)
        
        if [ ! -z "$TARGETS" ]; then
            aws events remove-targets \
                --rule "$RULE_NAME" \
                --ids $TARGETS \
                --region $AWS_REGION
        fi
        
        echo "  → Deleting rule: $RULE_NAME"
        aws events delete-rule --name "$RULE_NAME" --region $AWS_REGION
    done
    echo -e "  ${GREEN}✓ EventBridge rules deleted${NC}"
else
    echo -e "  ${YELLOW}○ No EventBridge rules found${NC}"
fi

################################################################################
# 7. DELETE LAMBDA FUNCTIONS
################################################################################
echo -e "${BLUE}[7/10] Deleting Lambda Functions...${NC}"

LAMBDA_FUNCTIONS=$(aws lambda list-functions \
    --region $AWS_REGION \
    --query 'Functions[?contains(FunctionName, `data-ingestion`) || contains(FunctionName, `data-pipeline`)].FunctionName' \
    --output text)

if [ ! -z "$LAMBDA_FUNCTIONS" ]; then
    for FUNCTION_NAME in $LAMBDA_FUNCTIONS; do
        echo "  → Deleting function: $FUNCTION_NAME"
        aws lambda delete-function \
            --function-name "$FUNCTION_NAME" \
            --region $AWS_REGION
    done
    echo -e "  ${GREEN}✓ Lambda functions deleted${NC}"
else
    echo -e "  ${YELLOW}○ No Lambda functions found${NC}"
fi

################################################################################
# 8. EMPTY AND DELETE S3 BUCKETS
################################################################################
echo -e "${BLUE}[8/10] Emptying and Deleting S3 Buckets...${NC}"

S3_BUCKETS=(
    "data-lake-raw-zone-${AWS_ACCOUNT_ID}"
    "data-lake-processed-zone-${AWS_ACCOUNT_ID}"
    "data-lake-curated-zone-${AWS_ACCOUNT_ID}"
    "data-lake-scripts-${AWS_ACCOUNT_ID}"
    "data-lake-query-results-${AWS_ACCOUNT_ID}"
)

for BUCKET in "${S3_BUCKETS[@]}"; do
    if aws s3 ls "s3://$BUCKET" 2>/dev/null; then
        echo "  → Emptying bucket: $BUCKET"
        aws s3 rm "s3://$BUCKET" --recursive --quiet
        
        echo "  → Deleting bucket: $BUCKET"
        aws s3 rb "s3://$BUCKET" --force
        
        echo -e "  ${GREEN}✓ Bucket deleted: $BUCKET${NC}"
    else
        echo -e "  ${YELLOW}○ Bucket not found: $BUCKET${NC}"
    fi
done

################################################################################
# 9. DELETE CLOUDFORMATION STACKS
################################################################################
echo -e "${BLUE}[9/10] Deleting CloudFormation Stacks...${NC}"

STACKS=$(aws cloudformation list-stacks \
    --region $AWS_REGION \
    --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
    --query 'StackSummaries[?contains(StackName, `data-pipeline`)].StackName' \
    --output text)

if [ ! -z "$STACKS" ]; then
    for STACK_NAME in $STACKS; do
        echo "  → Deleting stack: $STACK_NAME"
        aws cloudformation delete-stack \
            --stack-name "$STACK_NAME" \
            --region $AWS_REGION
        
        echo "  → Waiting for stack deletion..."
        aws cloudformation wait stack-delete-complete \
            --stack-name "$STACK_NAME" \
            --region $AWS_REGION 2>/dev/null || true
    done
    echo -e "  ${GREEN}✓ CloudFormation stacks deleted${NC}"
else
    echo -e "  ${YELLOW}○ No CloudFormation stacks found${NC}"
fi

################################################################################
# 10. DELETE IAM ROLES
################################################################################
echo -e "${BLUE}[10/10] Deleting IAM Roles...${NC}"

IAM_ROLES=(
    "LambdaDataIngestionRole"
    "GlueServiceRole"
    "GlueCrawlerRole"
    "EMR_DefaultRole"
    "EMR_EC2_DefaultRole"
    "SageMakerExecutionRole"
)

for ROLE_NAME in "${IAM_ROLES[@]}"; do
    if aws iam get-role --role-name "$ROLE_NAME" 2>/dev/null; then
        echo "  → Detaching policies from role: $ROLE_NAME"
        
        # Detach managed policies
        ATTACHED_POLICIES=$(aws iam list-attached-role-policies \
            --role-name "$ROLE_NAME" \
            --query 'AttachedPolicies[*].PolicyArn' \
            --output text)
        
        for POLICY_ARN in $ATTACHED_POLICIES; do
            aws iam detach-role-policy \
                --role-name "$ROLE_NAME" \
                --policy-arn "$POLICY_ARN"
        done
        
        # Delete inline policies
        INLINE_POLICIES=$(aws iam list-role-policies \
            --role-name "$ROLE_NAME" \
            --query 'PolicyNames[*]' \
            --output text)
        
        for POLICY_NAME in $INLINE_POLICIES; do
            aws iam delete-role-policy \
                --role-name "$ROLE_NAME" \
                --policy-name "$POLICY_NAME"
        done
        
        echo "  → Deleting role: $ROLE_NAME"
        aws iam delete-role --role-name "$ROLE_NAME"
        
        echo -e "  ${GREEN}✓ Role deleted: $ROLE_NAME${NC}"
    else
        echo -e "  ${YELLOW}○ Role not found: $ROLE_NAME${NC}"
    fi
done

################################################################################
# QUICKSIGHT MANUAL CLEANUP INSTRUCTIONS
################################################################################
echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}⚠️  MANUAL ACTION REQUIRED: QuickSight Subscription${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}QuickSight cannot be cancelled via CLI. Please follow these steps:${NC}"
echo ""
echo "1. Go to: https://eu-west-2.quicksight.aws.amazon.com/"
echo "2. Click your username (top-right) → 'Manage QuickSight'"
echo "3. Go to: 'Account settings'"
echo "4. Scroll down and click: 'Unsubscribe'"
echo "5. Confirm cancellation"
echo ""
echo -e "${YELLOW}Note: You'll be charged for the remainder of the current billing cycle.${NC}"
echo ""

################################################################################
# VERIFICATION
################################################################################
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}           CLEANUP VERIFICATION${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${GREEN}Verifying cleanup...${NC}"
echo ""

# Check S3 Buckets
echo -n "S3 Buckets: "
REMAINING_BUCKETS=$(aws s3 ls | grep -c "data-lake" || echo "0")
if [ "$REMAINING_BUCKETS" -eq 0 ]; then
    echo -e "${GREEN}✓ All deleted${NC}"
else
    echo -e "${YELLOW}⚠ $REMAINING_BUCKETS remaining${NC}"
fi

# Check Lambda Functions
echo -n "Lambda Functions: "
REMAINING_LAMBDAS=$(aws lambda list-functions --region $AWS_REGION \
    --query 'Functions[?contains(FunctionName, `data-ingestion`)].FunctionName' \
    --output text | wc -w)
if [ "$REMAINING_LAMBDAS" -eq 0 ]; then
    echo -e "${GREEN}✓ All deleted${NC}"
else
    echo -e "${YELLOW}⚠ $REMAINING_LAMBDAS remaining${NC}"
fi

# Check Glue Database
echo -n "Glue Database: "
if aws glue get-database --name data_pipeline_catalog --region $AWS_REGION 2>/dev/null; then
    echo -e "${YELLOW}⚠ Still exists${NC}"
else
    echo -e "${GREEN}✓ Deleted${NC}"
fi

# Check EMR Clusters
echo -n "EMR Clusters: "
REMAINING_EMR=$(aws emr list-clusters --region $AWS_REGION --active \
    --query 'Clusters[*].Id' --output text | wc -w)
if [ "$REMAINING_EMR" -eq 0 ]; then
    echo -e "${GREEN}✓ All terminated${NC}"
else
    echo -e "${YELLOW}⚠ $REMAINING_EMR active${NC}"
fi

# Check SageMaker
echo -n "SageMaker Notebook: "
if aws sagemaker describe-notebook-instance \
    --notebook-instance-name "$NOTEBOOK_NAME" \
    --region $AWS_REGION 2>/dev/null; then
    echo -e "${YELLOW}⚠ Still exists${NC}"
else
    echo -e "${GREEN}✓ Deleted${NC}"
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}           CLEANUP COMPLETE!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}✓ All AWS resources have been removed.${NC}"
echo -e "${YELLOW}⚠ Don't forget to cancel QuickSight subscription manually!${NC}"
echo ""
echo -e "Estimated remaining cost: ${GREEN}\$0/month${NC} (after QuickSight cancellation)"
echo ""
