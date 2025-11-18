# Lambda Data Ingestion Function

This Lambda function ingests data from various sources and stores it in the S3 raw zone.

## Features
- Generate sample sales data
- Support JSON and CSV formats
- Automatic S3 partitioning by date
- CloudWatch metrics and logging
- Error handling and retry logic

## Environment Variables
- `RAW_BUCKET`: S3 bucket for raw data
- `SOURCE_NAME`: Name of the data source

## Testing Locally
```bash
python3 -c "
import handler
event = {'format': 'json', 'num_records': 10}
handler.lambda_handler(event, None)
"
```

## Deploy
```bash
cd lambda/ingestion
pip install -r requirements.txt -t package/
cp handler.py package/
cd package
zip -r ../function.zip .
```
