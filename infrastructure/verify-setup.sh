#!/bin/bash

# Verify complete infrastructure setup

echo "Bioinformatics Platform - Infrastructure Verification"
echo "======================================================"

# Check if config exists
if [ ! -f "backend/config.json" ]; then
    echo "No configuration found. Run setup-infrastructure.sh first."
    exit 1
fi

# Load configuration
REGION=$(jq -r '.region' backend/config.json)
UPLOADS_BUCKET=$(jq -r '.buckets.uploads' backend/config.json)
RESULTS_BUCKET=$(jq -r '.buckets.results' backend/config.json)

echo "Region: $REGION"
echo ""

# Verify S3 Buckets
echo "Verifying S3 Buckets..."
aws s3 ls $UPLOADS_BUCKET --region $REGION >/dev/null 2>&1 && echo "   Uploads Bucket: Accessible" || echo "   Uploads Bucket: Not accessible"
aws s3 ls $RESULTS_BUCKET --region $REGION >/dev/null 2>&1 && echo "   Results Bucket: Accessible" || echo "   Results Bucket: Not accessible"

# Verify DynamoDB Table
echo ""
echo "Verifying DynamoDB Table..."
aws dynamodb describe-table --table-name BioinformaticsJobs --region $REGION --query 'Table.TableStatus' --output text 2>/dev/null | grep -q "ACTIVE" && echo "   DynamoDB Table: Active" || echo "   DynamoDB Table: Not active"

# Verify IAM Roles
echo ""
echo "Verifying IAM Roles..."
aws iam get-role --role-name BioinformaticsLambdaRole --query 'Role.RoleName' --output text >/dev/null 2>&1 && echo "   Lambda Role: Exists" || echo "   Lambda Role: Missing"
aws iam get-role --role-name BioinformaticsBatchRole --query 'Role.RoleName' --output text >/dev/null 2>&1 && echo "   Batch Role: Exists" || echo "   Batch Role: Missing"

# Verify API Gateway
echo ""
echo "Verifying API Gateway..."
API_ID=$(jq -r '.apiGateway.apiId' backend/config.json 2>/dev/null)
if [ "$API_ID" != "null" ] && [ ! -z "$API_ID" ]; then
    aws apigateway get-rest-api --rest-api-id $API_ID --region $REGION --query 'name' --output text >/dev/null 2>&1 && echo "   API Gateway: Exists" || echo "   API Gateway: Not found"
else
    echo "   API Gateway: No API ID in config"
fi

echo ""
echo "Verification complete!"
