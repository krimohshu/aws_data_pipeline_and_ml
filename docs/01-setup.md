# Module 1: Setup & Prerequisites

## Overview
This module covers the initial setup required to build the AWS data pipeline. We'll configure AWS CLI, set up IAM permissions, and prepare your development environment.

## Learning Objectives
- Configure AWS CLI and credentials
- Understand IAM roles and permissions
- Set up Python environment
- Install required tools

## Prerequisites
- AWS Account (Free tier eligible)
- Basic knowledge of Python
- Terminal/Command line familiarity

## Step 1: AWS Account Setup

### 1.1 Create AWS Account
If you don't have an AWS account:
1. Go to https://aws.amazon.com/
2. Click "Create an AWS Account"
3. Follow the registration process
4. Add payment method (many services have free tier)

### 1.2 Enable MFA (Multi-Factor Authentication)
Security best practice:
1. Go to IAM Console → Your Security Credentials
2. Enable MFA on root account
3. Use Google Authenticator or similar app

## Step 2: Install AWS CLI

### macOS (using Homebrew)
```bash
brew install awscli
```

### Verify Installation
```bash
aws --version
# Expected output: aws-cli/2.x.x Python/3.x.x Darwin/xx.x.x
```

## Step 3: Configure AWS CLI

### 3.1 Create IAM User for Development
1. Go to IAM Console → Users → Add User
2. Username: `data-pipeline-developer`
3. Access type: ✅ Programmatic access
4. Permissions: Attach policies:
   - `AmazonS3FullAccess`
   - `AWSGlueConsoleFullAccess`
   - `AmazonAthenaFullAccess`
   - `AWSLambda_FullAccess`
   - `AmazonEventBridgeFullAccess`
   - `IAMFullAccess` (for role creation)
   - `CloudWatchLogsFullAccess`
5. Download credentials CSV (keep it secure!)

### 3.2 Configure Credentials
```bash
aws configure
```

Enter your credentials:
```
AWS Access Key ID: [Your Access Key]
AWS Secret Access Key: [Your Secret Key]
Default region name: us-east-1  # or your preferred region
Default output format: json
```

### 3.3 Verify Configuration
```bash
# Test AWS CLI
aws sts get-caller-identity

# Expected output:
{
    "UserId": "AIDASAMPLEUSERID",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/data-pipeline-developer"
}
```

## Step 4: Install Python and Dependencies

### 4.1 Install Python 3.9+
```bash
# Check Python version
python3 --version

# Should be 3.9 or higher
```

### 4.2 Create Virtual Environment
```bash
cd ~/Documents/pers/learning/AWS_Data_Science/aws_data_pipeline

# Create virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate  # macOS/Linux
```

### 4.3 Install Required Packages
```bash
pip install --upgrade pip

# Install AWS SDK and data tools
pip install boto3 pandas pyarrow awscli-local
pip install jupyter notebook  # For SageMaker local testing

# Save dependencies
pip freeze > requirements.txt
```

## Step 5: Install Additional Tools

### 5.1 Install Terraform (Optional - for Infrastructure as Code)
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# Verify
terraform --version
```

### 5.2 Install jq (JSON processor)
```bash
brew install jq

# Verify
echo '{"test":"value"}' | jq .
```

## Step 6: Set Up Project Environment Variables

Create a `.env` file for local development:

```bash
cat > .env << 'EOF'
# AWS Configuration
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=your-account-id

# S3 Bucket Names (update these with your bucket names)
S3_RAW_BUCKET=data-lake-raw-zone-${AWS_ACCOUNT_ID}
S3_PROCESSED_BUCKET=data-lake-processed-zone-${AWS_ACCOUNT_ID}
S3_CURATED_BUCKET=data-lake-curated-zone-${AWS_ACCOUNT_ID}
S3_SCRIPTS_BUCKET=data-lake-scripts-${AWS_ACCOUNT_ID}
S3_QUERY_RESULTS_BUCKET=data-lake-query-results-${AWS_ACCOUNT_ID}

# Glue Configuration
GLUE_DATABASE_NAME=data_lake_db
GLUE_CRAWLER_NAME=raw_zone_crawler

# Lambda Configuration
LAMBDA_INGESTION_FUNCTION=data-ingestion-function
LAMBDA_RUNTIME=python3.11

# EMR Configuration
EMR_CLUSTER_NAME=data-pipeline-cluster
EMR_KEY_PAIR_NAME=your-key-pair-name

# SageMaker Configuration
SAGEMAKER_ROLE_NAME=SageMakerExecutionRole
SAGEMAKER_NOTEBOOK_INSTANCE=data-pipeline-notebook

# EventBridge Configuration
EVENT_RULE_NAME=daily-ingestion-trigger

# QuickSight Configuration
QUICKSIGHT_USER=your-quicksight-user

# Tags
PROJECT_NAME=aws-data-pipeline
ENVIRONMENT=dev
OWNER=your-name
EOF
```

### Load Environment Variables
```bash
# Create a script to load environment
cat > scripts/load_env.sh << 'EOF'
#!/bin/bash
export $(cat .env | grep -v '^#' | xargs)
echo "Environment variables loaded"
EOF

chmod +x scripts/load_env.sh
source scripts/load_env.sh
```

## Step 7: Verify AWS Service Access

Create a verification script:

```bash
cat > scripts/verify_aws_access.sh << 'EOF'
#!/bin/bash

echo "Verifying AWS Service Access..."
echo "================================"

# Check S3
echo -n "S3 Access: "
aws s3 ls > /dev/null 2>&1 && echo "✅ OK" || echo "❌ FAILED"

# Check Lambda
echo -n "Lambda Access: "
aws lambda list-functions --max-items 1 > /dev/null 2>&1 && echo "✅ OK" || echo "❌ FAILED"

# Check Glue
echo -n "Glue Access: "
aws glue list-databases --max-results 1 > /dev/null 2>&1 && echo "✅ OK" || echo "❌ FAILED"

# Check Athena
echo -n "Athena Access: "
aws athena list-work-groups --max-results 1 > /dev/null 2>&1 && echo "✅ OK" || echo "❌ FAILED"

# Check EMR
echo -n "EMR Access: "
aws emr list-clusters --max-items 1 > /dev/null 2>&1 && echo "✅ OK" || echo "❌ FAILED"

# Check SageMaker
echo -n "SageMaker Access: "
aws sagemaker list-notebook-instances --max-results 1 > /dev/null 2>&1 && echo "✅ OK" || echo "❌ FAILED"

# Check EventBridge
echo -n "EventBridge Access: "
aws events list-rules --max-results 1 > /dev/null 2>&1 && echo "✅ OK" || echo "❌ FAILED"

# Check IAM
echo -n "IAM Access: "
aws iam get-user > /dev/null 2>&1 && echo "✅ OK" || echo "❌ FAILED"

echo "================================"
echo "Verification complete!"
EOF

chmod +x scripts/verify_aws_access.sh
./scripts/verify_aws_access.sh
```

## Step 8: Cost Monitoring Setup

### 8.1 Enable AWS Cost Explorer
1. Go to AWS Billing Console
2. Enable Cost Explorer
3. Set up billing alerts

### 8.2 Create Budget Alert
```bash
# Create a budget for $50/month
aws budgets create-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget file://scripts/budget.json \
  --notifications-with-subscribers file://scripts/budget-notifications.json
```

Create budget configuration:
```bash
cat > scripts/budget.json << 'EOF'
{
  "BudgetName": "DataPipelineMonthlyBudget",
  "BudgetLimit": {
    "Amount": "50",
    "Unit": "USD"
  },
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST"
}
EOF
```

## Step 9: Project Structure Verification

Verify your project structure:

```bash
tree -L 2 aws_data_pipeline/
```

Expected structure:
```
aws_data_pipeline/
├── README.md
├── architecture/
│   └── architecture.md
├── docs/
│   ├── 01-setup.md (this file)
│   ├── 02-s3-configuration.md
│   └── ... (other tutorials)
├── scripts/
│   ├── load_env.sh
│   └── verify_aws_access.sh
├── .env
├── requirements.txt
└── venv/
```

## Common Issues & Troubleshooting

### Issue 1: AWS CLI Not Found
**Solution**: Reinstall AWS CLI or add to PATH

### Issue 2: Permission Denied
**Solution**: Check IAM user has required policies attached

### Issue 3: Region Not Available
**Solution**: Some services not available in all regions. Use us-east-1 or us-west-2

### Issue 4: Credential Errors
**Solution**: Run `aws configure` again and verify credentials

## Best Practices

1. **Never commit credentials** to Git
   ```bash
   echo ".env" >> .gitignore
   echo "venv/" >> .gitignore
   echo "*.pem" >> .gitignore
   ```

2. **Use IAM roles** instead of access keys when possible

3. **Enable MFA** on all accounts

4. **Rotate credentials** regularly

5. **Use least privilege** principle for IAM policies

## Checklist

Before moving to the next module, ensure:

- [ ] AWS CLI installed and configured
- [ ] IAM user created with necessary permissions
- [ ] Python 3.9+ installed
- [ ] Virtual environment created and activated
- [ ] All required packages installed
- [ ] Environment variables configured
- [ ] AWS service access verified
- [ ] Cost monitoring enabled
- [ ] Project structure created

## Cost Estimate for This Module

- **IAM User**: Free
- **AWS CLI**: Free
- **Verification commands**: < $0.01

## Next Steps

✅ **Setup Complete!** 

Proceed to [Module 2: S3 Data Lake Configuration](./02-s3-configuration.md) to create your data lake infrastructure.

## Additional Resources

- [AWS CLI Documentation](https://docs.aws.amazon.com/cli/)
- [IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [AWS Free Tier](https://aws.amazon.com/free/)
- [Boto3 Documentation](https://boto3.amazonaws.com/v1/documentation/api/latest/index.html)

## Questions?

Common questions for beginners:
- **Q: Do I need a credit card?** A: Yes, but many services have free tier
- **Q: Will this cost money?** A: Minimal cost if you stay within free tier and clean up resources
- **Q: Can I use existing AWS account?** A: Yes, just create a new IAM user
- **Q: What region should I use?** A: us-east-1 or us-west-2 for best service availability

---

**Module Status**: ✅ Complete
**Next Module**: [S3 Data Lake Configuration →](./02-s3-configuration.md)
