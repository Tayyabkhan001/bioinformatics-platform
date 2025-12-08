#!/bin/bash

echo "=== AWS BATCH DEBUG INFORMATION ==="
echo ""

echo "1. COMPUTE ENVIRONMENTS:"
aws batch describe-compute-environments --query 'computeEnvironments[*].{name:computeEnvironmentName, status:status, state:state, type:type}' --output table

echo ""
echo "2. JOB QUEUES:"
aws batch describe-job-queues --query 'jobQueues[*].{name:jobQueueName, status:status, state:state, computeEnvironment:computeEnvironments[0]}' --output table

echo ""
echo "3. RECENT JOBS:"
aws batch list-jobs --job-queue bioinformatics-queue --query 'jobSummaryList[*].{id:jobId, name:jobName, status:status, createdAt:createdAt}' --output table

echo ""
echo "4. SPECIFIC JOB DETAILS:"
for job_id in 8963ec1f-a6d1-4023-82d9-aa0dbba70b80 a375c8db-cefe-48bf-8d7a-ad0528bff6d4; do
    echo "Job: $job_id"
    aws batch describe-jobs --jobs $job_id --query 'jobs[0].{status:status, statusReason:statusReason, createdAt:createdAt, startedAt:startedAt, container:container}' --output table
    echo ""
done

echo "5. ECR REPOSITORIES:"
aws ecr describe-repositories --query 'repositories[*].{name:repositoryName, uri:repositoryUri}' --output table

