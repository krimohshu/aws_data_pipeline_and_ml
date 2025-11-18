# Amazon Athena Query Setup - Quick Reference

## Workgroup Configuration
- **Name**: `data-pipeline-workgroup`
- **Result Location**: `s3://data-lake-query-results-616129051451/athena-results/`
- **Features**: CloudWatch metrics enabled, workgroup enforcement enabled

## Available Tables

### 1. Raw Data Tables (From Glue Crawlers)
- `data_pipeline_catalog.sales` - Raw sales transactions (Parquet)
- `data_pipeline_catalog.customers` - Customer data (Parquet)
- `data_pipeline_catalog.products` - Product catalog (Parquet)
- `data_pipeline_catalog.automated_ingestion` - Lambda-generated data (JSON)

### 2. Processed Data Tables (From Glue ETL)
- `data_pipeline_catalog.sales_enriched_transactions` - Enriched sales with 21 columns
  - Original fields: transaction_id, date, customer_id, product_id, quantity, unit_price, total_amount, region, payment_method
  - Enriched fields: day_of_week, is_weekend, revenue_category, order_size, discount_amount, discount_percentage, amount_validation
  - Metadata: processing_timestamp, processing_date, transaction_date
  - Partitioned by: year, month, day

## Query Examples

### Basic Queries
```sql
-- View all sales
SELECT * FROM data_pipeline_catalog.sales LIMIT 10;

-- View enriched sales with calculated fields
SELECT transaction_id, total_amount, revenue_category, day_of_week, is_weekend 
FROM data_pipeline_catalog.sales_enriched_transactions 
LIMIT 10;
```

### Analytics Queries
See `analytics_queries.sql` for 10 pre-built analytical queries including:
1. Revenue by Region and Payment Method
2. Weekend vs Weekday Sales Analysis
3. Revenue Category Distribution
4. Order Size Analysis
5. Discount Analysis
6. Top Customers by Revenue
7. Product Performance
8. Data Quality Checks
9. Day of Week Sales Pattern
10. Cross-Region Payment Method Preferences

## Sample Query Results

### Revenue by Region (Query Result)
```
Region    | Payment Method | Transactions | Total Revenue | Avg Transaction
----------|----------------|--------------|---------------|----------------
US-EAST   | credit_card    | 5            | $349.91       | $69.98
EU-WEST   | credit_card    | 1            | $199.99       | $199.99
EU-WEST   | debit_card     | 2            | $169.91       | $84.96
US-WEST   | debit_card     | 1            | $159.98       | $159.98
US-WEST   | credit_card    | 1            | $129.99       | $129.99
```

### Revenue Category Distribution
```
Category  | Transactions | Total Revenue | Avg Transaction
----------|--------------|---------------|----------------
medium    | 10           | $1,069.79     | $106.98
low       | 5            | $201.87       | $40.37
```

## Performance & Cost

### Parquet Benefits
- **10-100x faster** than JSON queries
- **10x cheaper** - only scans needed columns
- **Compression**: Snappy compression reduces storage & scan costs

### Cost Calculation
- **Pricing**: $5 per TB of data scanned
- **Example**: Scanning 7 KB Parquet file = $0.000000035 (~$0.00)
- **Monthly estimate**: 1000 queries × 7 KB avg = $0.04/month

### Optimization Tips
1. **Use partitions**: `WHERE year=2025 AND month=11` - scans only that partition
2. **Select specific columns**: Don't use `SELECT *` 
3. **Use Parquet format**: 10x smaller than JSON
4. **Compress data**: Snappy/Gzip reduces scans
5. **Use LIMIT**: For testing queries

## How to Run Queries

### Method 1: AWS Console
1. Open Athena console
2. Select `data-pipeline-workgroup`
3. Paste SQL query
4. Click "Run query"

### Method 2: AWS CLI
```bash
# Start query
QUERY_ID=$(aws athena start-query-execution \
  --query-string "SELECT * FROM sales LIMIT 10" \
  --query-execution-context Database=data_pipeline_catalog \
  --result-configuration OutputLocation=s3://data-lake-query-results-616129051451/athena-results/ \
  --work-group data-pipeline-workgroup \
  --query 'QueryExecutionId' \
  --output text)

# Get results
aws athena get-query-results --query-execution-id $QUERY_ID
```

### Method 3: Python (boto3)
```python
import boto3

athena = boto3.client('athena')

response = athena.start_query_execution(
    QueryString='SELECT * FROM sales LIMIT 10',
    QueryExecutionContext={'Database': 'data_pipeline_catalog'},
    ResultConfiguration={'OutputLocation': 's3://...'},
    WorkGroup='data-pipeline-workgroup'
)
```

## Next Steps
- **Phase 8**: EMR Spark Processing for complex ML feature engineering
- **Phase 9**: SageMaker for ML model training
- **Phase 10**: QuickSight dashboards connected to Athena
