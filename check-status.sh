#!/bin/bash

echo "🔍 Checking Bioinformatics Platform Status..."
echo "=============================================="

# Check Lambda status
echo "1. Lambda Function Status:"
LAMBDA_STATE=$(aws lambda get-function --function-name file-upload-handler --region me-south-1 --query 'Configuration.State' --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$LAMBDA_STATE" = "Active" ]; then
    echo "   ✅ Lambda is ACTIVE"
elif [ "$LAMBDA_STATE" = "Pending" ]; then
    echo "   ⏳ Lambda is PENDING - wait a few seconds"
else
    echo "   ❌ Lambda not found or error"
fi

# Check if permission exists
echo ""
echo "2. API Gateway Permission:"
aws lambda get-policy --function-name file-upload-handler --region me-south-1 --query 'Policy' --output text 2>/dev/null | grep -q "api-gateway-invoke" && echo "   ✅ Permission exists" || echo "   ❌ Permission missing"

# Test API Gateway
echo ""
echo "3. Testing API Gateway..."
curl -s -X OPTIONS https://bs1gcg6hs0.execute-api.me-south-1.amazonaws.com/prod/upload \
  -H "Origin: http://localhost:3000" \
  --max-time 10 >/dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "   ✅ API Gateway is accessible"
else
    echo "   ❌ API Gateway not accessible"
fi

echo ""
echo "✅ Status check complete!"