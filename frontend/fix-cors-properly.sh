#!/bin/bash
echo "🔧 Properly fixing CORS for all endpoints..."

# Delete existing OPTIONS method if it exists (clean slate)
aws apigateway delete-method \
  --rest-api-id kqtg3kkrdf \
  --resource-id eqz7w7 \
  --http-method OPTIONS \
  --region me-south-1 2>/dev/null || echo "No existing OPTIONS method to delete"

# Create OPTIONS method for /upload
aws apigateway put-method \
  --rest-api-id kqtg3kkrdf \
  --resource-id eqz7w7 \
  --http-method OPTIONS \
  --authorization-type NONE \
  --region me-south-1

# Create mock integration for OPTIONS
aws apigateway put-integration \
  --rest-api-id kqtg3kkrdf \
  --resource-id eqz7w7 \
  --http-method OPTIONS \
  --type MOCK \
  --request-templates '{"application/json":"{\"statusCode\": 200}"}' \
  --region me-south-1

# Create method response for OPTIONS
aws apigateway put-method-response \
  --rest-api-id kqtg3kkrdf \
  --resource-id eqz7w7 \
  --http-method OPTIONS \
  --status-code 200 \
  --response-parameters '{
    "method.response.header.Access-Control-Allow-Headers": true,
    "method.response.header.Access-Control-Allow-Methods": true,
    "method.response.header.Access-Control-Allow-Origin": true
  }' \
  --region me-south-1

# Create integration response for OPTIONS
aws apigateway put-integration-response \
  --rest-api-id kqtg3kkrdf \
  --resource-id eqz7w7 \
  --http-method OPTIONS \
  --status-code 200 \
  --response-parameters '{
    "method.response.header.Access-Control-Allow-Headers": "'\''Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'\''",
    "method.response.header.Access-Control-Allow-Methods": "'\''POST,OPTIONS,GET'\''",
    "method.response.header.Access-Control-Allow-Origin": "'\''http://localhost:3000'\''"
  }' \
  --response-templates '{"application/json": ""}' \
  --region me-south-1

# Update existing POST method response to include CORS headers
aws apigateway update-method-response \
  --rest-api-id kqtg3kkrdf \
  --resource-id eqz7w7 \
  --http-method POST \
  --status-code 200 \
  --patch-operations '[
    {"op": "add", "path": "/responseParameters/method.response.header.Access-Control-Allow-Origin", "value": "true"},
    {"op": "add", "path": "/responseParameters/method.response.header.Access-Control-Allow-Methods", "value": "true"},
    {"op": "add", "path": "/responseParameters/method.response.header.Access-Control-Allow-Headers", "value": "true"}
  ]' \
  --region me-south-1

# Update existing POST integration response
aws apigateway update-integration-response \
  --rest-api-id kqtg3kkrdf \
  --resource-id eqz7w7 \
  --http-method POST \
  --status-code 200 \
  --patch-operations '[
    {"op": "add", "path": "/responseParameters/method.response.header.Access-Control-Allow-Origin", "value": "'\''http://localhost:3000'\''"},
    {"op": "add", "path": "/responseParameters/method.response.header.Access-Control-Allow-Methods", "value": "'\''POST,OPTIONS,GET'\''"},
    {"op": "add", "path": "/responseParameters/method.response.header.Access-Control-Allow-Headers", "value": "'\''Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'\''"}
  ]' \
  --region me-south-1

# Deploy the changes
aws apigateway create-deployment \
  --rest-api-id kqtg3kkrdf \
  --stage-name prod \
  --region me-south-1

echo "✅ CORS properly configured! Try uploading now."
