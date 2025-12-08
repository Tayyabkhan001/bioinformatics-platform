#!/bin/bash

# Bioinformatics Platform - Complete Infrastructure Setup
# Usage: ./setup-infrastructure.sh [region]
# Default: me-south-1 (Bahrain)

set -e  # Exit on any error

# Configuration
REGION=${1:-"me-south-1"}
PROJECT_NAME="bioinformatics-platform"
TIMESTAMP=$(date +%s)

echo "Bioinformatics Platform - AWS Infrastructure Setup"
echo "======================================================"
echo "Region: $REGION"
echo "User Location: Islamabad, Pakistan"
echo "Estimated Latency: 20-40ms"
echo "======================================================"

# Validate region
echo "Validating region $REGION..."
REGION_INFO=$(aws ec2 describe-regions --region-names $REGION --query 'Regions[0]' --output json 2>/dev/null || echo "{}")

if [ "$REGION_INFO" = "{}" ]; then
    echo "Region $REGION not available or access denied"
    echo "Trying fallback region: ap-south-1 (Mumbai)"
    REGION="ap-south-1"
fi

echo "Using region: $REGION"

# Create S3 Buckets
echo ""
echo "Step 1: Creating S3 Buckets..."
UPLOADS_BUCKET="${PROJECT_NAME}-uploads-${TIMESTAMP}"
RESULTS_BUCKET="${PROJECT_NAME}-results-${TIMESTAMP}"

for BUCKET in $UPLOADS_BUCKET $RESULTS_BUCKET; do
    if [ "$REGION" = "us-east-1" ]; then
        aws s3api create-bucket \
            --bucket $BUCKET \
            --region $REGION
    else
        aws s3api create-bucket \
            --bucket $BUCKET \
            --region $REGION \
            --create-bucket-configuration LocationConstraint=$REGION
    fi
    echo "   Created: $BUCKET"
done

# Create DynamoDB Table
echo ""
echo "Step 2: Creating DynamoDB Table..."
aws dynamodb create-table \
    --table-name BioinformaticsJobs \
    --attribute-definitions \
        AttributeName=jobId,AttributeType=S \
    --key-schema \
        AttributeName=jobId,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region $REGION

echo "   Waiting for table to be active..."
aws dynamodb wait table-exists --table-name BioinformaticsJobs --region $REGION
echo "   Table created: BioinformaticsJobs"

# Create IAM Roles
echo ""
echo "Step 3: Creating IAM Roles..."
./infrastructure/create-iam-roles.sh $REGION

# Create API Gateway
echo ""
echo "Step 4: Creating API Gateway..."
API_ID=$(aws apigateway create-rest-api \
    --name "${PROJECT_NAME}-api" \
    --description "Bioinformatics Analysis Platform API - $REGION" \
    --region $REGION \
    --query 'id' \
    --output text)

echo "   API Gateway created: $API_ID"

# Save Configuration
echo ""
echo "Step 5: Saving Configuration..."
cat > backend/config.json << EOL
{
    "region": "$REGION",
    "project": "$PROJECT_NAME",
    "timestamp": "$TIMESTAMP",
    "buckets": {
        "uploads": "$UPLOADS_BUCKET",
        "results": "$RESULTS_BUCKET"
    },
    "dynamodb": {
        "jobsTable": "BioinformaticsJobs"
    },
    "apiGateway": {
        "apiId": "$API_ID",
        "region": "$REGION"
    },
    "metadata": {
        "userLocation": "Islamabad, Pakistan",
        "awsRegion": "$REGION",
        "estimatedLatency": "20-40ms",
        "setupDate": "$(date -Iseconds)"
    }
}
EOL

# Final Output
echo ""
echo "INFRASTRUCTURE SETUP COMPLETE!"
echo "======================================================"
echo "Deployment Summary:"
echo "   Region: $REGION"
echo "   S3 Uploads: $UPLOADS_BUCKET"
echo "   S3 Results: $RESULTS_BUCKET"
echo "   DynamoDB: BioinformaticsJobs"
echo "   API Gateway: $API_ID"
echo "   Estimated Latency: 20-40ms"
echo ""
echo "Next steps:"
echo "   1. Run: ./infrastructure/verify-setup.sh"
echo "   2. Deploy Lambda functions"
echo "   3. Connect API Gateway"
echo "======================================================"
