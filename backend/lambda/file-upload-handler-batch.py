import json
import boto3
import uuid
from datetime import datetime
import base64
import time
import threading

print("🚀 Lambda function started (With Job Status Support + Batch Integration)")

def lambda_handler(event, context):
    """
    Handles file uploads (POST), job status checks (GET), and file downloads
    """
    print("📨 Received event")
    print(f"HTTP Method: {event.get('httpMethod')}")
    print(f"Path: {event.get('path')}")

    # CORS headers
    headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS, GET',
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'
    }

    try:
        # Handle preflight OPTIONS request
        if event.get('httpMethod') == 'OPTIONS':
            return {
                'statusCode': 200,
                'headers': headers,
                'body': json.dumps({'message': 'CORS preflight'})
            }

        # Handle GET request for job status
        if event.get('httpMethod') == 'GET' and '/jobs/' in event.get('path', ''):
            return handle_get_job(event, headers)

        # Handle GET request for file download
        if event.get('httpMethod') == 'GET' and '/download' in event.get('path', ''):
            return handle_download(event, headers)

        # Handle POST request for file upload
        if event.get('httpMethod') == 'POST' and '/upload' in event.get('path', ''):
            return handle_post_upload(event, headers)

        # If no matching route
        return error_response("Method not allowed", headers, 405)

    except Exception as e:
        print(f"❌ Unexpected error: {str(e)}")
        return error_response(f"Internal server error: {str(e)}", headers, 500)


def handle_post_upload(event, headers):
    """Handle file upload POST requests with real AWS Batch processing"""
    # Parse the request body
    body = event.get('body', '{}')
    if isinstance(body, str):
        body = json.loads(body)

    file_name = body.get('fileName', 'test.fastq')
    file_content = body.get('fileContent', 'dGVzdA==')
    analysis_type = body.get('analysisType', 'fastqc')
    user_id = body.get('userId', 'test-user')

    print(f"📄 Processing: {file_name}, Type: {analysis_type}")

    # Generate unique job ID
    job_id = str(uuid.uuid4())

    # Initialize AWS clients
    s3 = boto3.client('s3')
    dynamodb = boto3.resource('dynamodb')
    batch = boto3.client('batch', region_name='me-south-1')

    # Upload file to S3
    uploads_bucket = 'bioinformatics-platform-uploads-1761318731'
    s3_key = f"uploads/{user_id}/{job_id}/{file_name}"

    print(f"📤 Uploading to S3: {s3_key}")
    file_bytes = base64.b64decode(file_content)
    s3.put_object(
        Bucket=uploads_bucket,
        Key=s3_key,
        Body=file_bytes,
        ContentType='application/octet-stream'
    )

    # Create job record in DynamoDB - Start as SUBMITTED
    table = dynamodb.Table('BioinformaticsJobs')
    job_item = {
        'jobId': job_id,
        'userId': user_id,
        'fileName': file_name,
        'analysisType': analysis_type,
        's3Key': s3_key,
        'status': 'SUBMITTED',  # Start as submitted
        'createdAt': datetime.utcnow().isoformat(),
        'updatedAt': datetime.utcnow().isoformat()
    }
    table.put_item(Item=job_item)

    # Submit to AWS Batch for real processing
    try:
        # Determine job definition based on analysis type
        if analysis_type.lower() == 'fastqc':
            job_definition = 'fastqc-fargate:1'
        else:
            job_definition = 'blast-job:7'

        # Submit Batch job
        batch_response = batch.submit_job(
            jobName=f"biojob-{job_id}",
            jobQueue="bioinformatics-queue",
            jobDefinition=job_definition,
            containerOverrides={
                'environment': [
                    {'name': 'JOB_ID', 'value': job_id},
                    {'name': 'S3_KEY', 'value': s3_key},
                    {'name': 'UPLOADS_BUCKET', 'value': 'bioinformatics-platform-uploads-1761318731'},
                    {'name': 'RESULTS_BUCKET', 'value': 'bioinformatics-platform-results-1761318731'}
                ]
            }
        )

        # Update job with Batch job ID and status
        table.update_item(
            Key={'jobId': job_id},
            UpdateExpression='SET #status = :status, batchJobId = :batchId, updatedAt = :now',
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues={
                ':status': 'PROCESSING',
                ':batchId': batch_response['jobId'],
                ':now': datetime.utcnow().isoformat()
            }
        )

        print(f"✅ Submitted to AWS Batch: {batch_response['jobId']}")

    except Exception as e:
        print(f"❌ AWS Batch submission failed: {str(e)}")
        # Fallback to simulated processing
        table.update_item(
            Key={'jobId': job_id},
            UpdateExpression='SET #status = :status, updatedAt = :now',
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues={
                ':status': 'FAILED',
                ':now': datetime.utcnow().isoformat()
            }
        )

    # Return immediate response
    response = {
        'jobId': job_id,
        'status': 'PROCESSING',
        'message': f'{analysis_type.upper()} analysis submitted to AWS Batch',
        's3Key': s3_key,
        'timestamp': datetime.utcnow().isoformat()
    }

    return {
        'statusCode': 200,
        'headers': headers,
        'body': json.dumps(response)
    }


def handle_get_job(event, headers):
    """Handle job status GET requests with AWS Batch status checking"""
    path = event.get('path', '')
    job_id = path.split('/')[-1]

    print(f"🔍 Fetching job status for: {job_id}")

    if not job_id or job_id.lower() == 'jobs':
        return error_response("Job ID not provided", headers, 400)

    dynamodb = boto3.resource('dynamodb')
    batch = boto3.client('batch', region_name='me-south-1')
    s3 = boto3.client('s3')
    table = dynamodb.Table('BioinformaticsJobs')

    try:
        # Get job from DynamoDB
        response = table.get_item(Key={'jobId': job_id}, ConsistentRead=True)
        item = response.get('Item')
        
        if not item:
            return error_response("Job not found", headers, 404)

        # If job is processing and has Batch job ID, check Batch status
        if item.get('status') == 'PROCESSING' and item.get('batchJobId'):
            try:
                batch_status = batch.describe_jobs(jobs=[item['batchJobId']])
                if batch_status['jobs']:
                    batch_job = batch_status['jobs'][0]
                    
                    if batch_job['status'] == 'SUCCEEDED':
                        # Update job status to COMPLETED
                        table.update_item(
                            Key={'jobId': job_id},
                            UpdateExpression='SET #status = :status, updatedAt = :now',
                            ExpressionAttributeNames={'#status': 'status'},
                            ExpressionAttributeValues={
                                ':status': 'COMPLETED',
                                ':now': datetime.utcnow().isoformat()
                            }
                        )
                        item['status'] = 'COMPLETED'
                        
                        # Try to get results summary
                        try:
                            summary = s3.get_object(
                                Bucket='bioinformatics-platform-results-1761318731',
                                Key=f"results/{job_id}/summary.json"
                            )
                            item['results'] = json.loads(summary['Body'].read())
                        except Exception as e:
                            print(f"⚠️ No results summary found: {str(e)}")
                            item['results'] = None
                            
                    elif batch_job['status'] == 'FAILED':
                        table.update_item(
                            Key={'jobId': job_id},
                            UpdateExpression='SET #status = :status, updatedAt = :now',
                            ExpressionAttributeNames={'#status': 'status'},
                            ExpressionAttributeValues={
                                ':status': 'FAILED',
                                ':now': datetime.utcnow().isoformat()
                            }
                        )
                        item['status'] = 'FAILED'
                        
            except Exception as e:
                print(f"⚠️ Error checking Batch status: {str(e)}")

        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps(item)
        }

    except Exception as e:
        print(f"❌ Error fetching job: {str(e)}")
        return error_response("Error fetching job status", headers, 500)


def handle_download(event, headers):
    """Handle file download requests with pre-signed URLs"""
    try:
        # Get query parameters
        query_params = event.get('queryStringParameters', {})
        file_key = query_params.get('fileKey')
        
        if not file_key:
            return error_response("File key is required", headers, 400)

        print(f"📥 Generating download URL for: {file_key}")

        s3 = boto3.client('s3')
        
        # Generate pre-signed URL for secure download (valid for 1 hour)
        download_url = s3.generate_presigned_url(
            'get_object',
            Params={
                'Bucket': 'bioinformatics-platform-results-1761318731',
                'Key': file_key
            },
            ExpiresIn=3600  # 1 hour
        )

        response = {
            'downloadUrl': download_url,
            'fileKey': file_key,
            'expiresIn': '1 hour'
        }

        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps(response)
        }

    except Exception as e:
        print(f"❌ Error generating download URL: {str(e)}")
        return error_response("Error generating download URL", headers, 500)


def error_response(message, headers, status_code=500):
    """Return standardized error response"""
    return {
        'statusCode': status_code,
        'headers': headers,
        'body': json.dumps({'error': message})
    }
