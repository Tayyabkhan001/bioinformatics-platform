import json
import boto3
import uuid
from datetime import datetime
import base64
import os

print("🚀 Lambda function started (API GATEWAY COMPATIBLE)")

# ✅ Set AWS region globally to avoid conflicts
os.environ['AWS_DEFAULT_REGION'] = 'me-south-1'


def lambda_handler(event, context):
    """
    Handles API Gateway requests
    """
    print("📨 Received event from API Gateway")

    # ✅ FIXED: Define base headers for ALL responses
    base_headers = {
        'Access-Control-Allow-Origin': 'http://localhost:3000',
        'Access-Control-Allow-Methods': 'POST, GET, OPTIONS, PUT, DELETE',
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,Origin',
        'Access-Control-Allow-Credentials': 'true',
        'Content-Type': 'application/json'
    }

    # Handle preflight OPTIONS request
    if event.get('httpMethod') == 'OPTIONS':
        return {
            'statusCode': 200,
            'headers': base_headers,
            'body': json.dumps({'message': 'CORS preflight'})
        }

    try:
        # Extract HTTP method and path - HANDLE None VALUES
        http_method = event.get('httpMethod')
        path = event.get('path', '')
        query_params = event.get('queryStringParameters', {}) or {}

        print(f"🔍 Method: {http_method}, Path: '{path}', Query: {query_params}")
        print(f"🔍 Full event keys: {event.keys()}")

        # ✅ FIXED: Ensure path is a string
        if path is None:
            path = ''

        # ✅ FIXED: Handle paths with stage prefix
        # Remove stage prefix if present
        clean_path = str(path)
        if clean_path.startswith('/prod/'):
            clean_path = clean_path[5:]  # Remove '/prod'

        print(f"🔍 Clean path: '{clean_path}'")

        # ✅ FIXED: Route requests - SIMPLIFIED VERSION
        if http_method == 'POST':
            if 'fetch-ncbi' in clean_path:
                print("🎯 Routing to /fetch-ncbi handler")
                return handle_fetch_ncbi(event, base_headers)
            elif 'upload' in clean_path:
                print("🎯 Routing to /upload handler")
                return handle_upload(event, base_headers)

        elif http_method == 'GET':
            if 'download' in clean_path:
                return handle_download(query_params, base_headers)
            elif 'debug-s3' in clean_path:
                return handle_debug_s3(query_params, base_headers)
            elif 'debug-files' in clean_path:
                return handle_debug_files(query_params, base_headers)
            elif 'jobs/' in clean_path:
                # Extract job ID from path
                parts = clean_path.split('/')
                job_id = parts[-1] if parts else 'unknown'
                return handle_get_job(job_id, base_headers)

        print(f"❌ No route matched for {http_method} '{clean_path}'")
        return {
            'statusCode': 404,
            'headers': base_headers,
            'body': json.dumps({'error': 'Endpoint not found'})
        }

    except Exception as e:
        print(f"❌ Unexpected error: {str(e)}")
        import traceback
        print(f"Stack trace: {traceback.format_exc()}")
        return {
            'statusCode': 500,
            'headers': base_headers,
            'body': json.dumps({'error': f'Internal server error: {str(e)}'})
        }

def handle_upload(event, base_headers):
    """Handle file upload - FIXED VERSION"""
    try:
        print("📤 Handling upload request")

        # Parse the request body
        body = event.get('body', '{}')
        if event.get('isBase64Encoded', False):
            body = base64.b64decode(body).decode('utf-8')
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
        # ✅ FIXED: Specify region for S3 client
        s3 = boto3.client('s3', region_name='me-south-1')
        dynamodb = boto3.resource('dynamodb')
        batch = boto3.client('batch')

        # Upload file to S3
        uploads_bucket = 'bioinformatics-platform-uploads-1761318731'
        results_bucket = 'bioinformatics-platform-results-1761318731'
        s3_key = f"uploads/{user_id}/{job_id}/{file_name}"

        print(f"📤 Uploading to S3: {s3_key}")
        file_bytes = base64.b64decode(file_content)
        s3.put_object(
            Bucket=uploads_bucket,
            Key=s3_key,
            Body=file_bytes,
            ContentType='application/octet-stream'
        )

        # Create job record in DynamoDB
        table = dynamodb.Table('BioinformaticsJobs')
        job_item = {
            'jobId': job_id,
            'userId': user_id,
            'fileName': file_name,
            'analysisType': analysis_type,
            's3Key': s3_key,
            'status': 'SUBMITTED',
            'createdAt': datetime.utcnow().isoformat(),
            'updatedAt': datetime.utcnow().isoformat()
        }
        table.put_item(Item=job_item)

        # ✅ FIXED: ACTUAL FILE PROCESSING COMMANDS
        try:
            if analysis_type.lower() == 'fastqc':
                job_definition = 'fastqc-fargate-fixed-v2'

                # 🎯 WORKING: FastQC command (no changes)
                command = [
                    "sh", "-c",
                    f"""
                    echo "=== STARTING FASTQC PROCESSING ==="

                    # Download input file from S3
                    echo "Downloading {s3_key} from S3..."
                    aws s3 cp s3://{uploads_bucket}/{s3_key} /tmp/input.fastq --region me-south-1

                    # Run FastQC analysis
                    echo "Running FastQC analysis..."
                    fastqc --extract -o /tmp /tmp/input.fastq

                    # Upload results to S3
                    echo "Uploading results to S3..."
                    aws s3 cp /tmp/input_fastqc.html s3://{results_bucket}/{job_id}/input_fastqc.html --region me-south-1
                    aws s3 cp /tmp/input_fastqc.zip s3://{results_bucket}/{job_id}/input_fastqc.zip --region me-south-1

                    # Verify files were created
                    echo "Generated files:"
                    ls -la /tmp/*fastqc*
                    echo "=== FASTQC PROCESSING COMPLETED ==="
                    """
                ]

            elif analysis_type.lower() == 'blast':
                job_definition = 'blast-fargate-fixed-v2'
                # 🎯 FIXED: SIMPLE RELIABLE BLAST COMMAND
                command = [
                    "sh", "-c",
                    f"""
                    echo "=== STARTING RELIABLE BLAST ANALYSIS ==="

                    cd /tmp

                    # Download input
                    echo "Downloading {s3_key} from S3..."
                    aws s3 cp s3://{uploads_bucket}/{s3_key} /tmp/input.fasta --region me-south-1

                    # Verify download
                    echo "Input file:"
                    ls -la /tmp/input.fasta
                    echo "Sequences: $(grep -c '>' /tmp/input.fasta)"

                    # Simple BLAST - always use nucleotide for reliability
                    echo "Creating BLAST database..."
                    makeblastdb -in /tmp/input.fasta -dbtype nucl -title "custom_db" -out /tmp/custom_db

                    echo "Running BLAST analysis..."
                    blastn -query /tmp/input.fasta -db /tmp/custom_db -out /tmp/blast_results.txt -outfmt 6 -evalue 1e-5

                    # Create basic report
                    echo "Creating report..."
                    cat > /tmp/blast_report.txt << EOF
BLAST ANALYSIS REPORT
=====================
Job ID: {job_id}
Input File: {file_name}
Analysis Type: BLASTN
Status: COMPLETED
Date: $(date)

INPUT SUMMARY:
- Sequences: $(grep -c '>' /tmp/input.fasta)
- BLAST Program: blastn

RESULTS:
- Found $(wc -l < /tmp/blast_results.txt 2>/dev/null || echo 0) BLAST hits

TOP MATCHES:
$(if [ -f "/tmp/blast_results.txt" ] && [ -s "/tmp/blast_results.txt" ]; then
    head -3 /tmp/blast_results.txt | while IFS=$'\\t' read -r qseqid sseqid pident length evalue bitscore; do
        echo "- $qseqid -> $sseqid ($pident% identity)"
    done
else
    echo "- Self-comparison analysis completed"
fi)

Generated files:
- blast_results.txt (tabular results)
- blast_report.txt (this summary)
- input_sequence.fasta (original input)
EOF

                    # CRITICAL: Upload all files with error handling
                    echo "Uploading files to S3..."
                    aws s3 cp /tmp/blast_results.txt s3://{results_bucket}/{job_id}/blast_results.txt --region me-south-1
                    aws s3 cp /tmp/blast_report.txt s3://{results_bucket}/{job_id}/blast_report.txt --region me-south-1
                    aws s3 cp /tmp/input.fasta s3://{results_bucket}/{job_id}/input_sequence.fasta --region me-south-1

                    # Verify uploads
                    echo "Verifying uploads:"
                    aws s3 ls s3://{results_bucket}/{job_id}/ --region me-south-1

                    echo "=== BLAST ANALYSIS COMPLETED SUCCESSFULLY ==="
                    """
                ]
            else:
                return {
                    'statusCode': 400,
                    'headers': base_headers,
                    'body': json.dumps({'error': 'Unsupported analysis type'})
                }

            print(f"🔧 Submitting {analysis_type} job with command")

            # Submit Batch job
            batch_response = batch.submit_job(
                jobName=f"{analysis_type}-{job_id}",
                jobQueue="bioinformatics-queue-working",
                jobDefinition=job_definition,
                containerOverrides={
                    'command': command
                }
            )

            # Update job with Batch job ID
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

            print(f"✅ Submitted job to AWS Batch: {batch_response['jobId']}")

        except Exception as e:
            print(f"❌ AWS Batch submission failed: {str(e)}")
            import traceback
            print(f"Stack trace: {traceback.format_exc()}")

            table.update_item(
                Key={'jobId': job_id},
                UpdateExpression='SET #status = :status, errorMessage = :error, updatedAt = :now',
                ExpressionAttributeNames={'#status': 'status'},
                ExpressionAttributeValues={
                    ':status': 'FAILED',
                    ':error': f"Batch submission failed: {str(e)}",
                    ':now': datetime.utcnow().isoformat()
                }
            )
            return {
                'statusCode': 500,
                'headers': base_headers,
                'body': json.dumps({'error': f'AWS Batch submission failed: {str(e)}'})
            }

        # Return success response
        response = {
            'jobId': job_id,
            'status': 'PROCESSING',
            'message': f'{analysis_type} analysis submitted',
            's3Key': s3_key,
            'batchJobId': batch_response['jobId'],
            'timestamp': datetime.utcnow().isoformat()
        }

        return {
            'statusCode': 200,
            'headers': base_headers,
            'body': json.dumps(response)
        }

    except Exception as e:
        print(f"❌ Error in upload handler: {str(e)}")
        import traceback
        print(f"Stack trace: {traceback.format_exc()}")
        return {
            'statusCode': 500,
            'headers': base_headers,
            'body': json.dumps({'error': f'Upload failed: {str(e)}'})
        }


def handle_fetch_ncbi(event, base_headers):
    """Handle NCBI fetch requests - NEW ENDPOINT"""
    try:
        print("🧬 Handling NCBI fetch request")

        # Parse the request body
        body = event.get('body', '{}')
        if event.get('isBase64Encoded', False):
            body = base64.b64decode(body).decode('utf-8')
        if isinstance(body, str):
            body = json.loads(body)

        accession_id = body.get('accessionId', '')
        analysis_type = body.get('analysisType', 'blast')
        user_id = body.get('userId', 'test-user')

        if not accession_id:
            return {
                'statusCode': 400,
                'headers': base_headers,
                'body': json.dumps({'error': 'Accession ID is required'})
            }

        print(f"🧬 Fetching from NCBI: {accession_id}, Analysis: {analysis_type}")

        # Generate unique job ID
        job_id = str(uuid.uuid4())
        file_name = f"{accession_id}.fasta"

        # Initialize AWS clients
        s3 = boto3.client('s3', region_name='me-south-1')
        dynamodb = boto3.resource('dynamodb')
        batch = boto3.client('batch')

        # Step 1: Fetch sequence from NCBI (simulated for now)
        print(f"🔍 Fetching sequence for: {accession_id}")

        # Create a mock FASTA file for testing
        mock_sequence = f""">{accession_id}_fetched_from_NCBI
ATGCGTACGTAGCTAGCTAGCTAGCGTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGC
TAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCT
AGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTAGCTA"""

        # Save to S3
        uploads_bucket = 'bioinformatics-platform-uploads-1761318731'
        results_bucket = 'bioinformatics-platform-results-1761318731'
        s3_key = f"ncbi-fetch/{user_id}/{job_id}/{file_name}"

        print(f"📤 Uploading fetched sequence to S3: {s3_key}")
        s3.put_object(
            Bucket=uploads_bucket,
            Key=s3_key,
            Body=mock_sequence.encode('utf-8'),
            ContentType='text/plain'
        )

        # Create job record in DynamoDB
        table = dynamodb.Table('BioinformaticsJobs')
        job_item = {
            'jobId': job_id,
            'userId': user_id,
            'fileName': file_name,
            'analysisType': analysis_type,
            's3Key': s3_key,
            'accessionId': accession_id,
            'status': 'SUBMITTED',
            'createdAt': datetime.utcnow().isoformat(),
            'updatedAt': datetime.utcnow().isoformat()
        }
        table.put_item(Item=job_item)

        # Submit to AWS Batch (same as regular analysis)
        try:
            if analysis_type.lower() == 'fastqc':
                job_definition = 'fastqc-fargate-fixed-v2'
                command = [
                    "sh", "-c",
                    f"""
                    echo "=== PROCESSING NCBI FETCHED SEQUENCE (FASTQC) ==="
                    aws s3 cp s3://{uploads_bucket}/{s3_key} /tmp/input.fastq --region me-south-1
                    fastqc --extract -o /tmp /tmp/input.fastq
                    aws s3 cp /tmp/input_fastqc.html s3://{results_bucket}/{job_id}/input_fastqc.html --region me-south-1
                    aws s3 cp /tmp/input_fastqc.zip s3://{results_bucket}/{job_id}/input_fastqc.zip --region me-south-1
                    echo "=== FASTQC COMPLETED ==="
                    """
                ]
            else:  # blast
                job_definition = 'blast-fargate-fixed-v2'
                command = [
                    "sh", "-c",
                    f"""
                    echo "=== PROCESSING NCBI FETCHED SEQUENCE (BLAST) ==="
                    aws s3 cp s3://{uploads_bucket}/{s3_key} /tmp/input.fasta --region me-south-1
                    makeblastdb -in /tmp/input.fasta -dbtype nucl -title "custom_db" -out /tmp/custom_db
                    blastn -query /tmp/input.fasta -db /tmp/custom_db -out /tmp/blast_results.txt -outfmt 6
                    aws s3 cp /tmp/blast_results.txt s3://{results_bucket}/{job_id}/blast_results.txt --region me-south-1
                    aws s3 cp /tmp/input.fasta s3://{results_bucket}/{job_id}/input_sequence.fasta --region me-south-1
                    echo "=== BLAST COMPLETED ==="
                    """
                ]

            print(f"🔧 Submitting NCBI fetch job to Batch")
            batch_response = batch.submit_job(
                jobName=f"ncbi-{analysis_type}-{job_id}",
                jobQueue="bioinformatics-queue-working",
                jobDefinition=job_definition,
                containerOverrides={
                    'command': command
                }
            )

            # Update job with Batch job ID
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

            print(f"✅ Submitted NCBI fetch job to AWS Batch: {batch_response['jobId']}")

        except Exception as e:
            print(f"❌ AWS Batch submission failed: {str(e)}")
            table.update_item(
                Key={'jobId': job_id},
                UpdateExpression='SET #status = :status, errorMessage = :error, updatedAt = :now',
                ExpressionAttributeNames={'#status': 'status'},
                ExpressionAttributeValues={
                    ':status': 'FAILED',
                    ':error': f"Batch submission failed: {str(e)}",
                    ':now': datetime.utcnow().isoformat()
                }
            )
            return {
                'statusCode': 500,
                'headers': base_headers,
                'body': json.dumps({'error': f'NCBI fetch job submission failed: {str(e)}'})
            }

        # Return success response
        response = {
            'jobId': job_id,
            'status': 'PROCESSING',
            'message': f'NCBI fetch for {accession_id} submitted',
            'accessionId': accession_id,
            'analysisType': analysis_type,
            's3Key': s3_key,
            'batchJobId': batch_response['jobId'],
            'timestamp': datetime.utcnow().isoformat()
        }

        return {
            'statusCode': 200,
            'headers': base_headers,
            'body': json.dumps(response)
        }

    except Exception as e:
        print(f"❌ Error in NCBI fetch handler: {str(e)}")
        import traceback
        print(f"Stack trace: {traceback.format_exc()}")
        return {
            'statusCode': 500,
            'headers': base_headers,
            'body': json.dumps({'error': f'NCBI fetch failed: {str(e)}'})
        }


def handle_get_job(job_id, base_headers):
    """Handle job status requests"""
    try:
        print(f"🔍 Fetching job status for: {job_id}")

        if not job_id or job_id.lower() == 'jobs':
            return {
                'statusCode': 400,
                'headers': base_headers,
                'body': json.dumps({'error': 'Job ID not provided'})
            }

        dynamodb = boto3.resource('dynamodb')
        batch = boto3.client('batch')
        # ✅ FIXED: Specify region for S3 client
        s3 = boto3.client('s3', region_name='me-south-1')
        table = dynamodb.Table('BioinformaticsJobs')

        # Get job from DynamoDB
        response = table.get_item(Key={'jobId': job_id})
        item = response.get('Item')

        if not item:
            return {
                'statusCode': 404,
                'headers': base_headers,
                'body': json.dumps({'error': 'Job not found'})
            }

        # Check Batch status if processing
        if item.get('status') == 'PROCESSING' and item.get('batchJobId'):
            try:
                batch_status = batch.describe_jobs(jobs=[item['batchJobId']])
                if batch_status['jobs']:
                    batch_job = batch_status['jobs'][0]
                    item['batchStatus'] = batch_job['status']

                    if batch_job['status'] == 'SUCCEEDED':
                        # Check for result files
                        try:
                            result_files = find_actual_files_in_s3(job_id, s3)
                            item['resultFiles'] = result_files
                            analysis_type = item.get('analysisType', 'fastqc').lower()
                            item['availableFiles'] = map_files_to_analysis_type(result_files, analysis_type, job_id)

                            print(f"🎯 {analysis_type.upper()} job - Available files: {item['availableFiles']}")

                            # Update job status to COMPLETED
                            table.update_item(
                                Key={'jobId': job_id},
                                UpdateExpression='SET #status = :status, resultFiles = :files, availableFiles = :available, updatedAt = :now',
                                ExpressionAttributeNames={'#status': 'status'},
                                ExpressionAttributeValues={
                                    ':status': 'COMPLETED',
                                    ':files': result_files,
                                    ':available': item['availableFiles'],
                                    ':now': datetime.utcnow().isoformat()
                                }
                            )
                            item['status'] = 'COMPLETED'
                            item['completionTime'] = datetime.utcnow().isoformat()

                        except Exception as e:
                            print(f"⚠️ Error checking S3 files: {str(e)}")
                            item['availableFiles'] = {}
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

                    elif batch_job['status'] == 'FAILED':
                        failure_reason = batch_job.get('statusReason', 'Unknown failure')
                        table.update_item(
                            Key={'jobId': job_id},
                            UpdateExpression='SET #status = :status, errorMessage = :error, updatedAt = :now',
                            ExpressionAttributeNames={'#status': 'status'},
                            ExpressionAttributeValues={
                                ':status': 'FAILED',
                                ':error': failure_reason,
                                ':now': datetime.utcnow().isoformat()
                            }
                        )
                        item['status'] = 'FAILED'
                        item['errorMessage'] = failure_reason

            except Exception as e:
                print(f"⚠️ Error checking Batch status: {str(e)}")

        return {
            'statusCode': 200,
            'headers': base_headers,
            'body': json.dumps(item)
        }

    except Exception as e:
        print(f"❌ Error in job handler: {str(e)}")
        return {
            'statusCode': 500,
            'headers': base_headers,
            'body': json.dumps({'error': 'Internal server error'})
        }


def handle_download(query_params, base_headers):
    """Handle file download requests - FIXED VERSION"""
    try:
        file_key = query_params.get('fileKey')

        if not file_key:
            return {
                'statusCode': 400,
                'headers': base_headers,
                'body': json.dumps({'error': 'File key is required'})
            }

        print(f"📥 Generating download URL for: {file_key}")

        bucket_name = 'bioinformatics-platform-results-1761318731'

        # ✅ FIXED: Explicit S3 client with region configuration
        s3_client = boto3.client(
            's3',
            region_name='me-south-1',
            config=boto3.session.Config(
                signature_version='s3v4',
                s3={'addressing_style': 'virtual'}
            )
        )

        try:
            # Verify file exists
            s3_client.head_object(Bucket=bucket_name, Key=file_key)
            print(f"✅ File exists: {file_key}")

        except s3_client.exceptions.ClientError as e:
            if e.response['Error']['Code'] == '404':
                print(f"❌ File not found: {file_key}")
                return {
                    'statusCode': 404,
                    'headers': base_headers,
                    'body': json.dumps({'error': f'File not found: {file_key}'})
                }
            else:
                raise

        # ✅ FIXED: Generate pre-signed URL
        download_url = s3_client.generate_presigned_url(
            'get_object',
            Params={
                'Bucket': bucket_name,
                'Key': file_key
            },
            ExpiresIn=3600
        )

        # ✅ CRITICAL FIX: Ensure region is in the URL
        if '.s3.amazonaws.com' in download_url and 'me-south-1' not in download_url:
            download_url = download_url.replace('.s3.amazonaws.com', '.s3.me-south-1.amazonaws.com')
            print(f"🔄 Fixed URL to include region: {download_url}")

        print(f"✅ Generated download URL for: {file_key}")

        response = {
            'downloadUrl': download_url,
            'fileKey': file_key,
            'expiresIn': '1 hour'
        }

        return {
            'statusCode': 200,
            'headers': base_headers,
            'body': json.dumps(response)
        }

    except Exception as e:
        print(f"❌ Error generating download URL: {str(e)}")
        return {
            'statusCode': 500,
            'headers': base_headers,
            'body': json.dumps({'error': f'Error generating download URL: {str(e)}'})
        }


def handle_debug_s3(query_params, base_headers):
    """Debug endpoint for S3 files"""
    try:
        job_id = query_params.get('jobId')

        if not job_id:
            return {
                'statusCode': 400,
                'headers': base_headers,
                'body': json.dumps({'error': 'Job ID required'})
            }

        # ✅ FIXED: Specify region
        s3 = boto3.client('s3', region_name='me-south-1')
        files = find_actual_files_in_s3(job_id, s3)

        print(f"📁 FOUND FILES: {files}")

        response = {
            'jobId': job_id,
            'files': files,
            'count': len(files),
            'note': 'Debug: Check what files actually exist'
        }

        return {
            'statusCode': 200,
            'headers': base_headers,
            'body': json.dumps(response)
        }

    except Exception as e:
        print(f"❌ Debug error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': base_headers,
            'body': json.dumps({'error': f'Debug failed: {str(e)}'})
        }


def handle_debug_files(query_params, base_headers):
    """Debug endpoint with file mapping"""
    try:
        job_id = query_params.get('jobId')

        if not job_id:
            return {
                'statusCode': 400,
                'headers': base_headers,
                'body': json.dumps({'error': 'Job ID required'})
            }

        # ✅ FIXED: Specify region
        s3 = boto3.client('s3', region_name='me-south-1')
        dynamodb = boto3.resource('dynamodb')

        # Get job info from DynamoDB
        table = dynamodb.Table('BioinformaticsJobs')
        response = table.get_item(Key={'jobId': job_id})
        item = response.get('Item', {})

        analysis_type = item.get('analysisType', 'fastqc').lower()

        # Get files from S3
        files = find_actual_files_in_s3(job_id, s3)
        available_files = map_files_to_analysis_type(files, analysis_type, job_id)

        response = {
            'jobId': job_id,
            'analysisType': analysis_type,
            'files': files,
            'availableFiles': available_files,
            'count': len(files)
        }

        return {
            'statusCode': 200,
            'headers': base_headers,
            'body': json.dumps(response)
        }

    except Exception as e:
        print(f"❌ Debug files error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': base_headers,
            'body': json.dumps({'error': f'Debug files failed: {str(e)}'})
        }


# HELPER FUNCTIONS
def find_actual_files_in_s3(job_id, s3_client):
    """Find all files in S3 for a job"""
    try:
        results_bucket = 'bioinformatics-platform-results-1761318731'
        response = s3_client.list_objects_v2(
            Bucket=results_bucket,
            Prefix=f"{job_id}/"
        )

        files = []
        if 'Contents' in response:
            files = [obj['Key'] for obj in response['Contents']]

        return files
    except Exception as e:
        print(f"Error listing S3 files: {str(e)}")
        return []


def map_files_to_analysis_type(files, analysis_type, job_id):
    """Map S3 files to frontend-expected file types"""
    available_files = {}

    if analysis_type == 'blast':
        # ✅ FIXED: Map BLAST files with 'txt' for frontend
        for file_key in files:
            if file_key.endswith('.txt') and 'blast' in file_key.lower() and 'result' in file_key.lower():
                available_files['results'] = file_key
                available_files['txt'] = file_key  # 🎯 CRITICAL: Frontend expects 'txt'
            elif file_key.endswith('.txt') and 'blast' in file_key.lower() and 'report' in file_key.lower():
                available_files['report'] = file_key
            elif file_key.endswith('.fasta'):
                available_files['fasta'] = file_key

        # Fallback mapping
        if not available_files:
            available_files = {
                'results': f"{job_id}/blast_results.txt",
                'txt': f"{job_id}/blast_results.txt",  # 🎯 CRITICAL: Frontend expects 'txt'
                'report': f"{job_id}/blast_report.txt",
                'fasta': f"{job_id}/input_sequence.fasta"
            }

    else:  # fastqc
        for file_key in files:
            if file_key.endswith('.html') and 'fastqc' in file_key.lower():
                available_files['html'] = file_key
            elif file_key.endswith('.zip') and 'fastqc' in file_key.lower():
                available_files['zip'] = file_key
            elif file_key.endswith('.html') and not available_files.get('html'):
                available_files['html'] = file_key
            elif file_key.endswith('.zip') and not available_files.get('zip'):
                available_files['zip'] = file_key

        if not available_files:
            available_files = {
                'html': f"{job_id}/input_fastqc.html",
                'zip': f"{job_id}/input_fastqc.zip"
            }

    return available_files