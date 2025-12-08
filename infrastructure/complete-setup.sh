#!/bin/bash

echo "🔧 Completing Bioinformatics Platform Setup"
echo "==========================================="

REGION="me-south-1"
PROJECT_NAME="bioinformatics-platform"
TIMESTAMP="1761318731"  # From your S3 bucket name

# Check DynamoDB table status
echo "📋 Step 1: Checking DynamoDB table..."
TABLE_STATUS=$(aws dynamodb describe-table --table-name BioinformaticsJobs --region $REGION --query 'Table.TableStatus' --output text 2>/dev/null)

if [ "$TABLE_STATUS" = "ACTIVE" ]; then
    echo "   ✅ DynamoDB table is ACTIVE"
else
    echo "   ⏳ Waiting for DynamoDB table to become active..."
    aws dynamodb wait table-exists --table-name BioinformaticsJobs --region $REGION
    echo "   ✅ DynamoDB table is now ACTIVE"
fi

# Create IAM Roles
echo ""
echo "👮 Step 2: Creating IAM Roles..."
./infrastructure/create-iam-roles.sh $REGION

# Create API Gateway
echo ""
echo "🌐 Step 3: Creating API Gateway..."
API_ID=$(aws apigateway create-rest-api \
    --name "${PROJECT_NAME}-api" \
    --description "Bioinformatics Analysis Platform API - $REGION" \
    --region $REGION \
    --query 'id' \
    --output text)

echo "   ✅ API Gateway created: $API_ID"

# Save Configuration
echo ""
echo "💾 Step 4: Saving Configuration..."
cat > backend/config.json << EOL
{
    "region": "$REGION",
    "project": "$PROJECT_NAME",
    "timestamp": "$TIMESTAMP",
    "buckets": {
        "uploads": "${PROJECT_NAME}-uploads-${TIMESTAMP}",
        "results": "${PROJECT_NAME}-results-${TIMESTAMP}"
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

echo "   ✅ Configuration saved to backend/config.json"

# Final Verification
echo ""
echo "🔍 Step 5: Final Verification..."
./infrastructure/verify-setup.sh