#!/bin/bash
# Submit PySpark job to EMR cluster

set -e

if [ -z "$1" ]; then
  echo "Usage: ./submit_job.sh <cluster-id> [job-file]"
  echo "Example: ./submit_job.sh j-XXXXXXXXXXXXX customer_segmentation.py"
  exit 1
fi

CLUSTER_ID=$1
JOB_FILE=${2:-"customer_segmentation.py"}
REGION="eu-west-2"
SCRIPTS_BUCKET="data-lake-scripts-616129051451"

echo "=========================================="
echo "EMR Spark Job Submission"
echo "=========================================="
echo ""
echo "Cluster ID: $CLUSTER_ID"
echo "Job File: $JOB_FILE"
echo ""

# Upload job to S3
echo "📤 Uploading job to S3..."
aws s3 cp ../jobs/$JOB_FILE s3://$SCRIPTS_BUCKET/emr/jobs/$JOB_FILE

# Submit step to EMR
echo "🚀 Submitting Spark job to cluster..."
STEP_ID=$(aws emr add-steps \
  --cluster-id $CLUSTER_ID \
  --region $REGION \
  --steps Type=Spark,Name="Customer Segmentation",ActionOnFailure=CONTINUE,Args=[--deploy-mode,cluster,--master,yarn,--conf,spark.yarn.submit.waitAppCompletion=true,s3://$SCRIPTS_BUCKET/emr/jobs/$JOB_FILE] \
  --query 'StepIds[0]' \
  --output text)

echo "✅ Job submitted!"
echo ""
echo "Step ID: $STEP_ID"
echo ""
echo "📊 Monitoring job execution..."
echo ""

# Monitor step status
while true; do
  STATUS=$(aws emr describe-step \
    --cluster-id $CLUSTER_ID \
    --step-id $STEP_ID \
    --region $REGION \
    --query 'Step.Status.State' \
    --output text)
  
  echo "Status: $STATUS"
  
  if [ "$STATUS" == "COMPLETED" ]; then
    echo ""
    echo "=========================================="
    echo "✅ Spark Job COMPLETED Successfully!"
    echo "=========================================="
    echo ""
    echo "View output:"
    echo "  aws s3 ls s3://data-lake-curated-zone-616129051451/customer-segments/"
    echo ""
    echo "View logs:"
    echo "  aws s3 ls s3://$SCRIPTS_BUCKET/emr-logs/$CLUSTER_ID/steps/$STEP_ID/"
    break
  elif [ "$STATUS" == "FAILED" ] || [ "$STATUS" == "CANCELLED" ]; then
    echo ""
    echo "❌ Job $STATUS"
    echo ""
    echo "Check logs:"
    echo "  aws s3 ls s3://$SCRIPTS_BUCKET/emr-logs/$CLUSTER_ID/steps/$STEP_ID/"
    exit 1
  fi
  
  sleep 10
done
