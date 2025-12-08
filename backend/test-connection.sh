#!/bin/bash

echo "🧪 Testing API Gateway Connection..."
echo "===================================="

API_URL="https://bs1gcg6hs0.execute-api.me-south-1.amazonaws.com/prod/upload"

# Test CORS preflight (OPTIONS request)
echo "1. Testing CORS preflight..."
curl -X OPTIONS $API_URL \
  -H "Origin: http://localhost:3000" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: Content-Type" \
  -v

echo ""
echo "2. Testing actual POST request..."
# Create a test file
echo "test sequence data" > test.fastq
FILE_CONTENT=$(base64 test.fastq | tr -d '\n')

# Test POST request
curl -X POST $API_URL \
  -H "Content-Type: application/json" \
  -H "Origin: http://localhost:3000" \
  -d "{
    \"fileName\": \"test.fastq\",
    \"fileContent\": \"$FILE_CONTENT\",
    \"analysisType\": \"fastqc\",
    \"userId\": \"test-user-123\"
  }" \
  -v

# Cleanup
rm test.fastq

echo ""
echo "✅ Test completed!"