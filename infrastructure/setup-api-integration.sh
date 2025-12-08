#!/bin/bash

echo "🔗 Connecting API Gateway to Lambda with CORS support..."
echo "========================================================"

REGION="me-south-1"
API_ID="bs1gcg6hs0"
LAMBDA_ARN="arn:aws:lambda:me-south-1:480421269735:function:file-upload-handler"

echo "📋 API ID: $API_ID"
echo "🔗 Lambda ARN: $LAMBDA_ARN"

# Get the root resource ID
ROOT_ID=$(aws apigateway get-resources \
    --rest-api-id $API_ID \
    --region $REGION \
    --query 'items[0].id' \
    --output text)

echo "📋 Root resource ID: $ROOT_ID"

# Delete existing resources if they exist
echo "🗑️ Cleaning up existing resources..."
RESOURCES=$(aws apigateway get-resources --rest-api-id $API_ID --region $REGION --query 'items[*].{id:id, path:path}' --output json)

# Delete upload resource if exists
UPLOAD_RESOURCE=$(echo $RESOURCES | jq -r '.[] | select(.path == "/upload") | .id')
if [ ! -z "$UPLOAD_RESOURCE" ] && [ "$UPLOAD_RESOURCE" != "null" ]; then
    echo "Deleting existing upload resource: $UPLOAD_RESOURCE"
    aws apigateway delete-resource --rest-api-id $API_ID --resource-id $UPLOAD_RESOURCE --region $REGION
    sleep 2
fi

# Delete jobs resource if exists
JOBS_RESOURCE=$(echo $RESOURCES | jq -r '.[] | select(.path == "/jobs") | .id')
if [ ! -z "$JOBS_RESOURCE" ] && [ "$JOBS_RESOURCE" != "null" ]; then
    echo "Deleting existing jobs resource: $JOBS_RESOURCE"
    aws apigateway delete-resource --rest-api-id $API_ID --resource-id $JOBS_RESOURCE --region $REGION
    sleep 2
fi

# Create upload resource
echo "📝 Creating upload resource..."
UPLOAD_ID=$(aws apigateway create-resource \
    --rest-api-id $API_ID \
    --parent-id $ROOT_ID \
    --path-part "upload" \
    --region $REGION \
    --query 'id' \
    --output text)

if [ -z "$UPLOAD_ID" ] || [ "$UPLOAD_ID" == "null" ]; then
    echo "❌ Failed to create upload resource!"
    exit 1
fi
echo "✅ Created upload resource: $UPLOAD_ID"

# Create jobs resource
echo "📝 Creating jobs resource..."
JOBS_ID=$(aws apigateway create-resource \
    --rest-api-id $API_ID \
    --parent-id $ROOT_ID \
    --path-part "jobs" \
    --region $REGION \
    --query 'id' \
    --output text)

if [ -z "$JOBS_ID" ] || [ "$JOBS_ID" == "null" ]; then
    echo "❌ Failed to create jobs resource!"
    exit 1
fi
echo "✅ Created jobs resource: $JOBS_ID"

# Create jobs/{jobId} resource
echo "📝 Creating jobs/{jobId} resource..."
JOBS_JOB_ID=$(aws apigateway create-resource \
    --rest-api-id $API_ID \
    --parent-id $JOBS_ID \
    --path-part "{jobId}" \
    --region $REGION \
    --query 'id' \
    --output text)

if [ -z "$JOBS_JOB_ID" ] || [ "$JOBS_JOB_ID" == "null" ]; then
    echo "❌ Failed to create jobs/{jobId} resource!"
    exit 1
fi
echo "✅ Created jobs/{jobId} resource: $JOBS_JOB_ID"

# Setup OPTIONS method for upload (CORS preflight)
echo "🛬 Setting up OPTIONS method for upload..."
aws apigateway put-method \
    --rest-api-id $API_ID \
    --resource-id $UPLOAD_ID \
    --http-method OPTIONS \
    --authorization-type NONE \
    --region $REGION

aws apigateway put-integration \
    --rest-api-id $API_ID \
    --resource-id $UPLOAD_ID \
    --http-method OPTIONS \
    --type MOCK \
    --request-templates '{"application/json": "{\"statusCode\": 200}"}' \
    --region $REGION

aws apigateway put-method-response \
    --rest-api-id $API_ID \
    --resource-id $UPLOAD_ID \
    --http-method OPTIONS \
    --status-code 200 \
    --response-parameters '{
        "method.response.header.Access-Control-Allow-Origin": true,
        "method.response.header.Access-Control-Allow-Methods": true,
        "method.response.header.Access-Control-Allow-Headers": true
    }' \
    --region $REGION

aws apigateway put-integration-response \
    --rest-api-id $API_ID \
    --resource-id $UPLOAD_ID \
    --http-method OPTIONS \
    --status-code 200 \
    --response-parameters '{
        "method.response.header.Access-Control-Allow-Origin": "'\''*'\''",
        "method.response.header.Access-Control-Allow-Methods": "'\''POST,OPTIONS,GET'\''",
        "method.response.header.Access-Control-Allow-Headers": "'\''Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'\''"
    }' \
    --region $REGION

echo "✅ OPTIONS method configured for upload"

# Setup OPTIONS method for jobs/{jobId} (CORS preflight)
echo "🛬 Setting up OPTIONS method for jobs/{jobId}..."
aws apigateway put-method \
    --rest-api-id $API_ID \
    --resource-id $JOBS_JOB_ID \
    --http-method OPTIONS \
    --authorization-type NONE \
    --region $REGION

aws apigateway put-integration \
    --rest-api-id $API_ID \
    --resource-id $JOBS_JOB_ID \
    --http-method OPTIONS \
    --type MOCK \
    --request-templates '{"application/json": "{\"statusCode\": 200}"}' \
    --region $REGION

aws apigateway put-method-response \
    --rest-api-id $API_ID \
    --resource-id $JOBS_JOB_ID \
    --http-method OPTIONS \
    --status-code 200 \
    --response-parameters '{
        "method.response.header.Access-Control-Allow-Origin": true,
        "method.response.header.Access-Control-Allow-Methods": true,
        "method.response.header.Access-Control-Allow-Headers": true
    }' \
    --region $REGION

aws apigateway put-integration-response \
    --rest-api-id $API_ID \
    --resource-id $JOBS_JOB_ID \
    --http-method OPTIONS \
    --status-code 200 \
    --response-parameters '{
        "method.response.header.Access-Control-Allow-Origin": "'\''*'\''",
        "method.response.header.Access-Control-Allow-Methods": "'\''GET,OPTIONS'\''",
        "method.response.header.Access-Control-Allow-Headers": "'\''Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'\''"
    }' \
    --region $REGION

echo "✅ OPTIONS method configured for jobs/{jobId}"

# Add POST method to upload resource
aws apigateway put-method \
    --rest-api-id $API_ID \
    --resource-id $UPLOAD_ID \
    --http-method POST \
    --authorization-type NONE \
    --region $REGION

echo "✅ Added POST method to upload"

# Set up Lambda integration for upload
aws apigateway put-integration \
    --rest-api-id $API_ID \
    --resource-id $UPLOAD_ID \
    --http-method POST \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri "arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${LAMBDA_ARN}/invocations" \
    --region $REGION

echo "✅ Configured Lambda integration for upload"

# Add GET method to jobs/{jobId} resource
aws apigateway put-method \
    --rest-api-id $API_ID \
    --resource-id $JOBS_JOB_ID \
    --http-method GET \
    --authorization-type NONE \
    --region $REGION

echo "✅ Added GET method to jobs/{jobId}"

# Set up Lambda integration for jobs/{jobId} (we'll use the same Lambda for now)
aws apigateway put-integration \
    --rest-api-id $API_ID \
    --resource-id $JOBS_JOB_ID \
    --http-method GET \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri "arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${LAMBDA_ARN}/invocations" \
    --region $REGION

echo "✅ Configured Lambda integration for jobs/{jobId}"

# Create deployment
DEPLOYMENT_ID=$(aws apigateway create-deployment \
    --rest-api-id $API_ID \
    --stage-name prod \
    --region $REGION \
    --query 'id' \
    --output text)

echo "✅ Created deployment: $DEPLOYMENT_ID"

# Add Lambda permissions for both endpoints
aws lambda add-permission \
    --function-name file-upload-handler \
    --statement-id api-gateway-upload-$(date +%s) \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:${REGION}:480421269735:${API_ID}/*/POST/upload" \
    --region $REGION

aws lambda add-permission \
    --function-name file-upload-handler \
    --statement-id api-gateway-jobs-$(date +%s) \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:${REGION}:480421269735:${API_ID}/*/GET/jobs/*" \
    --region $REGION

echo "✅ Added Lambda permissions"

echo ""
echo "🎉 API Gateway Integration Complete!"
echo "===================================="
echo "🌐 Upload URL: https://${API_ID}.execute-api.${REGION}.amazonaws.com/prod/upload"
echo "🌐 Jobs URL: https://${API_ID}.execute-api.${REGION}.amazonaws.com/prod/jobs/{jobId}"
echo "🔗 Frontend (localhost:3000) can now call both endpoints"
echo "🛡️ CORS enabled for all endpoints"

# Test CORS for both endpoints
echo ""
echo "🧪 Testing CORS configuration..."
sleep 5
echo "Testing upload CORS:"
curl -X OPTIONS https://${API_ID}.execute-api.${REGION}.amazonaws.com/prod/upload \
  -H "Origin: http://localhost:3000" \
  -H "Access-Control-Request-Method: POST" \
  -s -o /dev/null -w "Status: %{http_code}\n"

echo "Testing jobs CORS:"
curl -X OPTIONS https://${API_ID}.execute-api.${REGION}.amazonaws.com/prod/jobs/test \
  -H "Origin: http://localhost:3000" \
  -H "Access-Control-Request-Method: GET" \
  -s -o /dev/null -w "Status: %{http_code}\n"