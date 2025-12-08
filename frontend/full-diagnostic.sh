#!/bin/bash
echo "🔍 FULL DIAGNOSTIC CHECK"
echo "========================"

echo ""
echo "📋 CHECKING BATCH JOB:"
aws batch describe-jobs \
  --jobs 7559f7a1-dcb4-4d95-bf75-3457fa87972e \
  --region me-south-1 \
  --query 'jobs[0].{status: status, statusReason: statusReason, container: container}' \
  --output table

echo ""
echo "📋 CHECKING CLOUDWATCH LOG GROUPS:"
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/batch" \
  --region me-south-1 \
  --query 'logGroups[].logGroupName' \
  --output table

echo ""
echo "📋 CHECKING COMPUTE ENVIRONMENT:"
aws batch describe-compute-environments \
  --compute-environments bioinformatics-compute \
  --region me-south-1 \
  --query 'computeEnvironments[0].{status: status, type: type, computeResources: computeResources}' \
  --output table

echo ""
echo "📋 CHECKING S3 FOR ANY NEW FILES:"
aws s3 ls s3://bioinformatics-platform-results-1761318731/ --recursive --region me-south-1
