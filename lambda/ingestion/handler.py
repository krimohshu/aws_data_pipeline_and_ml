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
