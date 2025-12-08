#!/bin/bash
# setup-api-gateway.sh

API_NAME="bioinformatics-platform-api"
REGION="me-south-1"
LAMBDA_FUNCTION="BioinformaticsPlatformAPI"

echo "🚀 Setting up API Gateway automatically..."

# Create REST API
API_ID=$(aws apigateway create-rest-api \
    --name "$API_NAME" \
    --description "Bioinformatics Platform API" \
    --region $REGION \
    --query 'id' \
    --output text)

echo "✅ Created API: $API_ID"

# Get the root resource ID
ROOT_RESOURCE_ID=$(aws apigateway get-resources \
    --rest-api-id $API_ID \
    --region $REGION \
    --query 'items[0].id' \
    --output text)

echo "✅ Root resource ID: $ROOT_RESOURCE_ID"

# Create resources
UPLOAD_RESOURCE_ID=$(aws apigateway create-resource \
    --rest-api-id $API_ID \
    --parent-id $ROOT_RESOURCE_ID \
    --path-part "upload" \
    --region $REGION \
    --query 'id' \
    --output text)

JOBS_RESOURCE_ID=$(aws apigateway create-resource \
    --rest-api-id $API_ID \
    --parent-id $ROOT_RESOURCE_ID \
    --path-part "jobs" \
    --region $REGION \
    --query 'id' \
    --output text)

JOB_ID_RESOURCE_ID=$(aws apigateway create-resource \
    --rest-api-id $API_ID \
    --parent-id $JOBS_RESOURCE_ID \
    --path-part "{id}" \
    --region $REGION \
    --query 'id' \
    --output text)

DOWNLOAD_RESOURCE_ID=$(aws apigateway create-resource \
    --rest-api-id $API_ID \
    --parent-id $ROOT_RESOURCE_ID \
    --path-part "download" \
    --region $REGION \
    --query 'id' \
    --output text)

DEBUG_S3_RESOURCE_ID=$(aws apigateway create-resource \
    --rest-api-id $API_ID \
    --parent-id $ROOT_RESOURCE_ID \
    --path-part "debug-s3" \
    --region $REGION \
    --query 'id' \
    --output text)

DEBUG_FILES_RESOURCE_ID=$(aws apigateway create-resource \
    --rest-api-id $API_ID \
    --parent-id $ROOT_RESOURCE_ID \
    --path-part "debug-files" \
    --region $REGION \
    --query 'id' \
    --output text)

echo "✅ Created all resources"

# Give API Gateway permission to invoke Lambda
aws lambda add-permission \
    --function-name $LAMBDA_FUNCTION \
    --statement-id api-gateway-invoke \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:$REGION:*:$API_ID/*" \
    --region $REGION

echo "✅ Added Lambda permission"

# Create methods
create_method() {
    local resource_id=$1
    local method=$2
    local path=$3
    
    aws apigateway put-method \
        --rest-api-id $API_ID \
        --resource-id $resource_id \
        --http-method $method \
        --authorization-type "NONE" \
        --region $REGION
    
    aws apigateway put-integration \
        --rest-api-id $API_ID \
        --resource-id $resource_id \
        --http-method $method \
        --type AWS_PROXY \
        --integration-http-method POST \
        --uri "arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/arn:aws:lambda:$REGION:$(aws sts get-caller-identity --query Account --output text):function:$LAMBDA_FUNCTION/invocations" \
        --region $REGION
    
    aws apigateway put-method-response \
        --rest-api-id $API_ID \
        --resource-id $resource_id \
        --http-method $method \
        --status-code 200 \
        --response-parameters '{"method.response.header.Access-Control-Allow-Origin": true}' \
        --region $REGION
    
    echo "✅ Created $method $path"
}

# Create all methods
create_method $UPLOAD_RESOURCE_ID "POST" "/upload"
create_method $UPLOAD_RESOURCE_ID "OPTIONS" "/upload"

create_method $JOB_ID_RESOURCE_ID "GET" "/jobs/{id}"
create_method $JOB_ID_RESOURCE_ID "OPTIONS" "/jobs/{id}"

create_method $DOWNLOAD_RESOURCE_ID "GET" "/download"
create_method $DOWNLOAD_RESOURCE_ID "OPTIONS" "/download"

create_method $DEBUG_S3_RESOURCE_ID "GET" "/debug-s3"
create_method $DEBUG_S3_RESOURCE_ID "OPTIONS" "/debug-s3"

create_method $DEBUG_FILES_RESOURCE_ID "GET" "/debug-files"
create_method $DEBUG_FILES_RESOURCE_ID "OPTIONS" "/debug-files"

# Deploy API
aws apigateway create-deployment \
    --rest-api-id $API_ID \
    --stage-name "prod" \
    --region $REGION

echo "✅ Deployed API to prod stage"

# Get the invoke URL
INVOKE_URL="https://$API_ID.execute-api.$REGION.amazonaws.com/prod"
echo "🎯 API Gateway URL: $INVOKE_URL"

echo "🚀 API Gateway setup complete!"
echo "📝 Update your frontend with this URL: $INVOKE_URL"
