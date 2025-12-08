#!/bin/bash
echo "🔍 COMPLETE DEBUGGING SESSION"
echo "============================="

echo ""
echo "📋 LATEST COMPLETED JOBS:"
aws dynamodb scan \
    --table-name BioinformaticsJobs \
    --region me-south-1 \
    --query "Items[?status.S=='COMPLETED'].[jobId.S, batchJobId.S, createdAt.S]" \
    --output table

echo ""
echo "📋 ALL LOG STREAMS AVAILABLE:"
aws logs describe-log-streams \
  --log-group-name /aws/batch/job \
  --region me-south-1 \
  --query 'logStreams[].logStreamName' \
  --output table | head -10

echo ""
echo "📋 S3 BUCKET CONTENTS:"
aws s3 ls s3://bioinformatics-platform-results-1761318731/ --recursive --region me-south-1

echo ""
echo "📋 LATEST LAMBDA LOGS:"
# Get latest Lambda log stream
LATEST_LAMBDA_STREAM=$(aws logs describe-log-streams \
  --log-group-name "/aws/lambda/file-upload-handler" \
  --region me-south-1 \
  --query 'logStreams | sort_by(@, &lastEventTimestamp) | [-1].logStreamName' \
  --output text 2>/dev/null || echo "No Lambda logs")

if [ "$LATEST_LAMBDA_STREAM" != "No Lambda logs" ]; then
  echo "Latest Lambda stream: $LATEST_LAMBDA_STREAM"
  aws logs get-log-events \
    --log-group-name "/aws/lambda/file-upload-handler" \
    --log-stream-name "$LATEST_LAMBDA_STREAM" \
    --region me-south-1 \
    --query 'events[*].message' \
    --output text | tail -10
fi
