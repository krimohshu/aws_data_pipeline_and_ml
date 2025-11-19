# AWS Resource Cleanup Guide

## 🗑️ Complete Resource Cleanup - Cost Elimination

This guide will help you delete ALL AWS resources to prevent further charges.

---

## ⚡ Quick Cleanup (Automated Script)

### **Option 1: Run Automated Cleanup Script**

```bash
cd /Users/krishanshukla/Documents/pers/learning/AWS_Data_Science/aws_data_pipeline

# Run the cleanup script
./scripts/cleanup_all_resources.sh
```

**What it does:**
1. ✅ Stops and deletes SageMaker notebook instance
2. ✅ Terminates all EMR clusters
3. ✅ Deletes Glue ETL jobs
4. ✅ Deletes Glue crawlers
5. ✅ Deletes Glue database and tables
6. ✅ Removes EventBridge rules
7. ✅ Deletes Lambda functions
8. ✅ Empties and deletes all S3 buckets
9. ✅ Deletes CloudFormation stacks
10. ✅ Removes IAM roles

**Time:** ~5-10 minutes

---

## 🔧 Manual Cleanup (If Script Fails)

### **1. Stop SageMaker Notebook (IMPORTANT - $0.05/hour)**

```bash
# Stop the notebook
aws sagemaker stop-notebook-instance \
  --notebook-instance-name data-pipeline-ml-notebook \
  --region eu-west-2

# Wait for it to stop
aws sagemaker wait notebook-instance-stopped \
  --notebook-instance-name data-pipeline-ml-notebook \
  --region eu-west-2

# Delete the notebook
aws sagemaker delete-notebook-instance \
  --notebook-instance-name data-pipeline-ml-notebook \
  --region eu-west-2
```

**Cost Impact:** Saves $0.05/hour = $36/month

---

### **2. Terminate EMR Clusters (IMPORTANT - $20+/month if running)**

```bash
# List active clusters
aws emr list-clusters --region eu-west-2 --active

# Terminate each cluster (replace CLUSTER_ID)
aws emr terminate-clusters --cluster-ids j-XXXXXXXXXXXXX --region eu-west-2
```

**Cost Impact:** EMR costs ~$1-2/hour when running

---

### **3. Delete Glue Resources (Minor cost)**

```bash
# Delete Glue jobs
aws glue delete-job --job-name sales-data-transformation --region eu-west-2

# Delete crawlers
aws glue delete-crawler --name sales-crawler --region eu-west-2
aws glue delete-crawler --name customers-crawler --region eu-west-2
aws glue delete-crawler --name products-crawler --region eu-west-2
aws glue delete-crawler --name automated-ingestion-crawler --region eu-west-2

# Delete database
aws glue delete-database --name data_pipeline_catalog --region eu-west-2
```

**Cost Impact:** Minimal (pay per run)

---

### **4. Delete Lambda Functions (Free tier, minimal cost)**

```bash
# Delete Lambda function
aws lambda delete-function \
  --function-name data-ingestion-function \
  --region eu-west-2
```

**Cost Impact:** Usually free tier

---

### **5. Delete EventBridge Rules (Free)**

```bash
# List rules
aws events list-rules --region eu-west-2

# Remove targets first
aws events remove-targets \
  --rule daily-sales-ingestion \
  --ids 1 \
  --region eu-west-2

# Delete rule
aws events delete-rule \
  --name daily-sales-ingestion \
  --region eu-west-2
```

**Cost Impact:** Free

---

### **6. Empty and Delete S3 Buckets (IMPORTANT - Storage costs)**

```bash
# Get your account ID
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Empty and delete each bucket
aws s3 rm s3://data-lake-raw-zone-${AWS_ACCOUNT_ID} --recursive
aws s3 rb s3://data-lake-raw-zone-${AWS_ACCOUNT_ID} --force

aws s3 rm s3://data-lake-processed-zone-${AWS_ACCOUNT_ID} --recursive
aws s3 rb s3://data-lake-processed-zone-${AWS_ACCOUNT_ID} --force

aws s3 rm s3://data-lake-curated-zone-${AWS_ACCOUNT_ID} --recursive
aws s3 rb s3://data-lake-curated-zone-${AWS_ACCOUNT_ID} --force

aws s3 rm s3://data-lake-scripts-${AWS_ACCOUNT_ID} --recursive
aws s3 rb s3://data-lake-scripts-${AWS_ACCOUNT_ID} --force

aws s3 rm s3://data-lake-query-results-${AWS_ACCOUNT_ID} --recursive
aws s3 rb s3://data-lake-query-results-${AWS_ACCOUNT_ID} --force
```

**Cost Impact:** Saves $0.023/GB/month storage

---

### **7. Delete CloudFormation Stacks**

```bash
# List stacks
aws cloudformation list-stacks --region eu-west-2

# Delete stack (if you used CloudFormation)
aws cloudformation delete-stack \
  --stack-name data-pipeline-s3-buckets \
  --region eu-west-2
```

---

### **8. Delete IAM Roles**

```bash
# Detach policies and delete roles
aws iam detach-role-policy \
  --role-name LambdaDataIngestionRole \
  --policy-arn arn:aws:iam::aws:policy/AWSLambdaBasicExecutionRole

aws iam delete-role --role-name LambdaDataIngestionRole

# Repeat for other roles:
# - GlueServiceRole
# - SageMakerExecutionRole
# - EMR_DefaultRole
# - EMR_EC2_DefaultRole
```

---

### **9. Cancel QuickSight Subscription (IMPORTANT - $9/month)**

**⚠️ MANUAL STEP REQUIRED:**

1. Go to: https://eu-west-2.quicksight.aws.amazon.com/
2. Click your username (top-right)
3. Select "Manage QuickSight"
4. Go to "Account settings"
5. Scroll down and click "Unsubscribe"
6. Confirm cancellation

**Cost Impact:** Saves $9/month (Standard edition)

**Note:** You'll be charged for the current billing cycle.

---

## 💰 Cost Breakdown After Cleanup

| Service | Before Cleanup | After Cleanup |
|---------|----------------|---------------|
| SageMaker | $36/month | $0 |
| QuickSight | $9/month | $0 |
| S3 Storage | $0.50/month | $0 |
| Lambda | $0 (free tier) | $0 |
| Glue | $0 (pay per run) | $0 |
| Athena | $0 (pay per query) | $0 |
| EMR | $0 (terminated) | $0 |
| **TOTAL** | **~$45/month** | **$0/month** |

---

## ✅ Verification Checklist

After cleanup, verify all resources are deleted:

### **Check SageMaker:**
```bash
aws sagemaker list-notebook-instances --region eu-west-2
```
**Expected:** Empty list

### **Check EMR:**
```bash
aws emr list-clusters --region eu-west-2 --active
```
**Expected:** No active clusters

### **Check S3:**
```bash
aws s3 ls | grep data-lake
```
**Expected:** No buckets found

### **Check Lambda:**
```bash
aws lambda list-functions --region eu-west-2 | grep data-ingestion
```
**Expected:** No functions found

### **Check Glue:**
```bash
aws glue get-databases --region eu-west-2
```
**Expected:** No data_pipeline_catalog

### **Check QuickSight:**
- Visit: https://eu-west-2.quicksight.aws.amazon.com/
- Should show "No subscription" or prompt to sign up

---

## 🎯 Final Cost Verification

**Check AWS Billing Dashboard:**

1. Go to: https://console.aws.amazon.com/billing/
2. Click "Bills" (left sidebar)
3. Check current month charges
4. Filter by service to verify:
   - SageMaker: $0
   - QuickSight: $0 (after cancellation)
   - S3: $0
   - EMR: $0

**Set up billing alert** (optional):
```bash
# Create billing alarm for $1
aws cloudwatch put-metric-alarm \
  --alarm-name billing-alarm-1-dollar \
  --alarm-description "Alert when charges exceed $1" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 21600 \
  --threshold 1 \
  --comparison-operator GreaterThanThreshold \
  --region us-east-1
```

---

## 📋 Cleanup Summary

After running cleanup:
- ✅ **SageMaker notebook:** Stopped and deleted
- ✅ **EMR clusters:** Terminated
- ✅ **Lambda functions:** Deleted
- ✅ **S3 buckets:** Emptied and removed
- ✅ **Glue resources:** All deleted
- ✅ **EventBridge rules:** Removed
- ✅ **IAM roles:** Deleted
- ⚠️ **QuickSight:** Requires manual cancellation

**Result:** $0/month ongoing cost (after QuickSight cancellation)

---

## 🚨 Important Notes

1. **Data Loss:** All data will be permanently deleted. Cannot be recovered.
2. **QuickSight:** Must cancel manually - script cannot do this.
3. **Billing Cycle:** QuickSight charges for remainder of current month.
4. **Free Tier:** Some services remain in free tier (Lambda, Athena pay-per-use).
5. **CloudTrail Logs:** May have small storage costs if enabled.

---

## 🆘 Need Help?

If cleanup fails:
1. Check AWS Console manually for remaining resources
2. Verify IAM permissions for delete operations
3. Look for CloudFormation protection settings
4. Check for resource dependencies

**Force delete S3 bucket:**
```bash
aws s3 rb s3://bucket-name --force
```

**Force terminate EMR cluster:**
```bash
aws emr terminate-clusters --cluster-ids j-XXXXX --region eu-west-2
```

---

**Ready to proceed?** Run the automated script:

```bash
./scripts/cleanup_all_resources.sh
```

Type **DELETE** when prompted to confirm.
