#!/bin/bash

echo "🔍 COMPREHENSIVE S3 & LAMBDA DEBUG SCRIPT"
echo "=========================================="

# Set region explicitly
export AWS_DEFAULT_REGION=me-south-1
export AWS_REGION=me-south-1

echo ""
echo "1. 📋 CHECKING AWS CONFIGURATION"
echo "================================"
aws configure list
echo "Current region: $AWS_DEFAULT_REGION"

echo ""
echo "2. 📦 CHECKING S3 BUCKETS"
echo "========================"
echo "Uploads bucket:"
aws s3 ls s3://bioinformatics-platform-uploads-1761318731/ --recursive --human-readable | head -10

echo ""
echo "Results bucket:"
aws s3 ls s3://bioinformatics-platform-results-1761318731/ --recursive --human-readable | head -10

echo ""
echo "3. 🔧 TESTING S3 ACCESS MANUALLY"
echo "================================"

# Create a test file
echo "This is a test file for S3 debugging" > test_debug.txt

# Upload to test access
echo "Uploading test file..."
aws s3 cp test_debug.txt s3://bioinformatics-platform-results-1761318731/debug-test/upload_test.txt

# List to verify upload
echo "Checking upload:"
aws s3 ls s3://bioinformatics-platform-results-1761318731/debug-test/

echo ""
echo "4. 🔗 TESTING PRE-SIGNED URL GENERATION"
echo "======================================"

# Generate pre-signed URL manually
echo "Generating pre-signed URL..."
PRESIGNED_URL=$(aws s3 presign s3://bioinformatics-platform-results-1761318731/debug-test/upload_test.txt --expires-in 300 --region me-south-1)

echo "Generated URL: $PRESIGNED_URL"

echo ""
echo "5. 🌐 TESTING URL ACCESS"
echo "========================"

# Test if URL works
echo "Testing URL access..."
curl -I "$PRESIGNED_URL"

echo ""
echo "6. 📊 CHECKING LAMBDA FUNCTION"
echo "=============================="

# Get Lambda function details
aws lambda get-function --function-name file-upload-handler --region me-south-1 --query 'Configuration.{FunctionName:FunctionName, Runtime:Runtime, Timeout:Timeout, Region:LastModified}' --output table

echo ""
echo "7. 🔍 CHECKING LAMBDA EXECUTION ROLE"
echo "===================================="

# Get Lambda role (we'll need to infer from function config)
LAMBDA_ARN=$(aws lambda get-function --function-name file-upload-handler --region me-south-1 --query 'Configuration.Role' --output text)
echo "Lambda Role: $LAMBDA_ARN"

echo ""
echo "8. 🧪 TESTING API GATEWAY ENDPOINT"
echo "=================================="

# Test the download endpoint directly
echo "Testing API Gateway download endpoint..."
API_URL="https://kqtg3kkrdf.execute-api.me-south-1.amazonaws.com/prod/download?fileKey=debug-test/upload_test.txt"
curl -v "$API_URL"

echo ""
echo "9. 📝 CHECKING BUCKET REGION"
echo "============================"

# Get bucket location
echo "Uploads bucket location:"
aws s3api get-bucket-location --bucket bioinformatics-platform-uploads-1761318731 --region me-south-1

echo "Results bucket location:"
aws s3api get-bucket-location --bucket bioinformatics-platform-results-1761318731 --region me-south-1

echo ""
echo "10. 🛠️ CHECKING S3 BUCKET POLICIES"
echo "=================================="

# Check if buckets have policies
echo "Uploads bucket policy:"
aws s3api get-bucket-policy --bucket bioinformatics-platform-uploads-1761318731 --region me-south-1 2>/dev/null || echo "No bucket policy"

echo "Results bucket policy:"
aws s3api get-bucket-policy --bucket bioinformatics-platform-results-1761318731 --region me-south-1 2>/dev/null || echo "No bucket policy"

# Cleanup
rm test_debug.txt

echo ""
echo "✅ DEBUGGING COMPLETE"


