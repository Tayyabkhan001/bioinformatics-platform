#!/bin/bash

echo "🔍 Bioinformatics Platform - Simple Verification"
echo "================================================"

REGION="me-south-1"
UPLOADS_BUCKET="bioinformatics-platform-uploads-1761318731"
RESULTS_BUCKET="bioinformatics-platform-results-1761318731"
API_ID="bs1gcg6hs0"

echo "📍 Region: $REGION"
echo ""

# Verify S3 Buckets
echo "📦 Verifying S3 Buckets..."
aws s3 ls s3://$UPLOADS_BUCKET --region $REGION >/dev/null 2>&1 && echo "   ✅ Uploads Bucket: Accessible" || echo "   ❌ Uploads Bucket: Not accessible"
aws s3 ls s3://$RESULTS_BUCKET --region $REGION >/dev/null 2>&1 && echo "   ✅ Results Bucket: Accessible" || echo "   ❌ Results Bucket: Not accessible"

# Verify DynamoDB Table
echo ""
echo "🗄️ Verifying DynamoDB Table..."
aws dynamodb describe-table --table-name BioinformaticsJobs --region $REGION --query 'Table.TableStatus' --output text 2>/dev/null | grep -q "ACTIVE" && echo "   ✅ DynamoDB Table: Active" || echo "   ❌ DynamoDB Table: Not active"

# Verify IAM Roles
echo ""
echo "👮 Verifying IAM Roles..."
aws iam get-role --role-name BioinformaticsLambdaRole --query 'Role.RoleName' --output text >/dev/null 2>&1 && echo "   ✅ Lambda Role: Exists" || echo "   ❌ Lambda Role: Missing"
aws iam get-role --role-name BioinformaticsBatchRole --query 'Role.RoleName' --output text >/dev/null 2>&1 && echo "   ✅ Batch Role: Exists" || echo "   ❌ Batch Role: Missing"

# Verify API Gateway
echo ""
echo "🌐 Verifying API Gateway..."
aws apigateway get-rest-api --rest-api-id $API_ID --region $REGION --query 'name' --output text >/dev/null 2>&1 && echo "   ✅ API Gateway: Exists" || echo "   ❌ API Gateway: Not found"

echo ""
echo "✅ Verification complete!"