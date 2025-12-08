#!/bin/bash

echo "🚀 Deploying Lambda Function with Batch Processing..."
echo "======================================================"

REGION="me-south-1"
UPLOADS_BUCKET="bioinformatics-platform-uploads-1761318731"
RESULTS_BUCKET="bioinformatics-platform-results-1761318731"
JOBS_TABLE="BioinformaticsJobs"

# Create deployment package
echo "📦 Creating deployment package..."

# Use your existing file-upload-handler.py which already has download support
cp file-upload-handler.py lambda_function.py

# Create zip file
zip -r lambda-deployment.zip lambda_function.py

echo "✅ Created lambda-deployment.zip"

# Update Lambda function configuration
echo "🔧 Updating Lambda function..."
aws lambda update-function-code \
    --function-name file-upload-handler \
    --zip-file fileb://lambda-deployment.zip \
    --region $REGION

# Wait for update to complete
echo "⏳ Waiting for Lambda update to complete..."
sleep 5

# Update environment variables
aws lambda update-function-configuration \
    --function-name file-upload-handler \
    --environment Variables="{UPLOADS_BUCKET=$UPLOADS_BUCKET,JOBS_TABLE=$JOBS_TABLE,RESULTS_BUCKET=$RESULTS_BUCKET}" \
    --region $REGION

# Update the handler to use the correct file name (THIS IS THE KEY FIX)
aws lambda update-function-configuration \
    --function-name file-upload-handler \
    --handler "lambda_function.lambda_handler" \
    --region $REGION

echo "✅ Lambda function updated with download support!"
echo "🔗 Lambda Function URL: https://daae47urm6mnpblg4mnf6ock5e0phuoh.lambda-url.me-south-1.on.aws"
echo ""
echo "📋 Test commands:"
echo "curl \"https://daae47urm6mnpblg4mnf6ock5e0phuoh.lambda-url.me-south-1.on.aws/download?fileKey=results/local-test/summary.json\""
echo "curl \"https://daae47urm6mnpblg4mnf6ock5e0phuoh.lambda-url.me-south-1.on.aws/jobs/some-job-id\""
