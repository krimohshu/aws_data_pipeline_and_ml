# EMR Spark Customer Segmentation Job

## Quick Reference

### Cluster Information
- **Cluster ID**: Check with `aws emr list-clusters --active`
- **Instance Type**: m5.xlarge (4 vCPU, 16 GB RAM)
- **Nodes**: 1 master + 2 core (3 total)
- **Pricing**: Spot instances (~70% discount)
- **Auto-terminate**: Yes (terminates after job completion)

### Submit Spark Job

```bash
# Set your cluster ID
CLUSTER_ID="j-XXXXXXXXXXXXX"

# Submit the customer segmentation job
aws emr add-steps \
  --cluster-id $CLUSTER_ID \
  --steps Type=Spark,Name="Customer Segmentation",\
ActionOnFailure=CONTINUE,\
Args=[--deploy-mode,cluster,--master,yarn,\
s3://data-lake-scripts-616129051451/emr/jobs/customer_segmentation.py]
```

### Monitor Job

```bash
# Check cluster status
aws emr describe-cluster --cluster-id $CLUSTER_ID \
  --query 'Cluster.Status.State' --output text

# List all steps
aws emr list-steps --cluster-id $CLUSTER_ID \
  --query 'Steps[].[Name,State,Id]' --output table

# Get specific step status
aws emr describe-step --cluster-id $CLUSTER_ID \
  --step-id s-XXXXXXXXXXXXX \
  --query 'Step.Status.[State,StateChangeReason]' --output table
```

### View Logs

```bash
# Spark application logs
aws s3 ls s3://data-lake-scripts-616129051451/emr/logs/$CLUSTER_ID/steps/

# Download logs
aws s3 cp s3://data-lake-scripts-616129051451/emr/logs/$CLUSTER_ID/ ./emr-logs/ --recursive
```

### Check Output

```bash
# View customer segments in curated zone
aws s3 ls s3://data-lake-curated-zone-616129051451/customer-segments/ --recursive --human-readable

# Download sample output
aws s3 cp s3://data-lake-curated-zone-616129051451/customer-segments/segment=0/ ./segment-0/ --recursive
```

### Terminate Cluster (if not auto-terminating)

```bash
aws emr terminate-clusters --cluster-ids $CLUSTER_ID
```

## What the Job Does

### Input
- **Sales data** from processed zone (Parquet)
- **Customer data** from raw zone (Parquet)
- **Products data** from raw zone (Parquet)

### Processing Steps
1. **Feature Engineering**: Calculate RFM metrics
   - Recency: Days since last purchase
   - Frequency: Number of purchases
   - Monetary: Total amount spent

2. **Data Preparation**:
   - Vectorize features
   - Normalize with StandardScaler
   - Handle missing values

3. **K-Means Clustering**:
   - k=4 segments
   - Silhouette score evaluation
   - Cluster center analysis

4. **Business Labeling**:
   - Segment 0: High-Value Frequent
   - Segment 1: At-Risk
   - Segment 2: New/Low-Spend
   - Segment 3: Moderate

### Output
- **Location**: `s3://curated-zone/customer-segments/`
- **Format**: Parquet (partitioned by segment)
- **Columns**: 
  - customer_id
  - segment (0-3)
  - segment_label
  - total_spent
  - purchase_count
  - days_since_purchase
  - primary_region
  - preferred_payment

## Cost Estimation

### Cluster Cost (Spot Instances)
- m5.xlarge spot: ~$0.058/hour per instance
- 3 instances × $0.058 = $0.174/hour
- 15-minute job = ~$0.04

### Cluster Cost (On-Demand)
- m5.xlarge on-demand: $0.192/hour per instance
- 3 instances × $0.192 = $0.576/hour
- 15-minute job = ~$0.14

### Storage Cost
- S3 storage: Negligible for curated output (~100 KB)

## Troubleshooting

### Cluster Stuck in STARTING
- Check AWS Service Health Dashboard
- Verify spot instance availability
- Try switching to on-demand instances

### Job Fails
- Check step logs in S3
- Verify input data exists in processed zone
- Check IAM permissions for S3 access

### Out of Memory
- Increase instance type (e.g., m5.2xlarge)
- Increase number of core nodes
- Optimize Spark partitioning

## Next Steps

After customer segmentation completes:
1. Query segments with Athena
2. Visualize in QuickSight
3. Use segments for personalized marketing
4. Train ML models in SageMaker using segment features
