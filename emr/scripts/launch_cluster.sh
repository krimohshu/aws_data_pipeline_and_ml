#!/bin/bash
# EMR Cluster Launch Script
# Creates a development EMR cluster for data processing

set -e

echo "=========================================="
echo "AWS EMR Cluster Launcher"
echo "=========================================="

# Configuration
CLUSTER_NAME="data-pipeline-dev-cluster"
REGION="eu-west-2"
LOG_URI="s3://data-lake-scripts-616129051451/emr-logs/"
SUBNET_ID=""  # Optional: Add your subnet ID for VPC deployment
KEY_NAME=""   # Optional: Add your EC2 key pair name for SSH access

# Cluster specifications
INSTANCE_TYPE="m5.xlarge"
INSTANCE_COUNT=3  # 1 master + 2 core nodes
EMR_RELEASE="emr-6.15.0"

echo ""
echo "Cluster Configuration:"
echo "  Name: $CLUSTER_NAME"
echo "  Region: $REGION"
echo "  Instance Type: $INSTANCE_TYPE"
echo "  Node Count: $INSTANCE_COUNT"
echo "  EMR Release: $EMR_RELEASE"
echo ""

# Build the create-cluster command
CMD="aws emr create-cluster \
  --name '$CLUSTER_NAME' \
  --release-label $EMR_RELEASE \
  --applications Name=Spark Name=Hadoop Name=Hive Name=Livy Name=JupyterEnterpriseGateway \
  --instance-type $INSTANCE_TYPE \
  --instance-count $INSTANCE_COUNT \
  --use-default-roles \
  --log-uri $LOG_URI \
  --enable-debugging \
  --region $REGION"

# Add optional parameters if provided
if [ -n "$SUBNET_ID" ]; then
  CMD="$CMD --ec2-attributes SubnetId=$SUBNET_ID"
  if [ -n "$KEY_NAME" ]; then
    CMD="$CMD,KeyName=$KEY_NAME"
  fi
elif [ -n "$KEY_NAME" ]; then
  CMD="$CMD --ec2-attributes KeyName=$KEY_NAME"
fi

echo "🚀 Launching EMR cluster..."
echo ""

# Execute command
CLUSTER_ID=$(eval $CMD --query 'ClusterId' --output text)

if [ -z "$CLUSTER_ID" ]; then
  echo "❌ Failed to create cluster"
  exit 1
fi

echo "✅ Cluster created successfully!"
echo ""
echo "Cluster ID: $CLUSTER_ID"
echo ""
echo "📊 Monitoring cluster startup (this takes 5-10 minutes)..."
echo ""

# Wait for cluster to be ready
aws emr wait cluster-running --cluster-id $CLUSTER_ID --region $REGION

echo ""
echo "=========================================="
echo "✅ EMR Cluster is READY!"
echo "=========================================="
echo ""
echo "Cluster ID: $CLUSTER_ID"
echo ""
echo "Next steps:"
echo "  1. View cluster in AWS Console:"
echo "     https://console.aws.amazon.com/emr/home?region=$REGION#/clusters/$CLUSTER_ID"
echo ""
echo "  2. Submit Spark job:"
echo "     ./emr/scripts/submit_job.sh $CLUSTER_ID"
echo ""
echo "  3. Access Spark UI (if key pair configured):"
echo "     ssh -i ~/.ssh/your-key.pem -N -L 18080:localhost:18080 hadoop@<master-public-dns>"
echo "     Open: http://localhost:18080"
echo ""
echo "  4. Terminate cluster when done:"
echo "     aws emr terminate-clusters --cluster-ids $CLUSTER_ID"
echo ""
echo "💰 Estimated cost: ~\$0.75/hour"
echo "=========================================="
