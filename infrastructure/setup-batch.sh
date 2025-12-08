#!/bin/bash

echo "⚡ Setting up AWS Batch for Bioinformatics Processing..."
echo "========================================================"

REGION="me-south-1"
ACCOUNT_ID="480421269735"

# Create Compute Environment
echo "🖥️ Creating Compute Environment..."
aws batch create-compute-environment \
    --compute-environment-name bioinformatics-compute \
    --type MANAGED \
    --state ENABLED \
    --service-role arn:aws:iam::$ACCOUNT_ID:role/BioinformaticsBatchRole \
    --compute-resources type=FARGATE,subnets=subnet-EXAMPLE1,subnet-EXAMPLE2,securityGroups=sg-EXAMPLE \
    --region $REGION

# Create Job Queue
echo "📋 Creating Job Queue..."
aws batch create-job-queue \
    --job-queue-name bioinformatics-queue \
    --state ENABLED \
    --priority 1 \
    --compute-environment-order order=1,computeEnvironment=bioinformatics-compute \
    --region $REGION

# Register Job Definitions
echo "📝 Registering Job Definitions..."

# FastQC Job Definition
aws batch register-job-definition \
    --job-definition-name fastqc-job \
    --type container \
    --platform-capabilities FARGATE \
    --container-properties '{
        "image": "'$ACCOUNT_ID'.dkr.ecr.'$REGION'.amazonaws.com/bioinformatics-fastqc:latest",
        "resourceRequirements": [
            {"type": "VCPU", "value": "1"},
            {"type": "MEMORY", "value": "2048"}
        ],
        "executionRoleArn": "arn:aws:iam::'$ACCOUNT_ID':role/BioinformaticsBatchRole",
        "jobRoleArn": "arn:aws:iam::'$ACCOUNT_ID':role/BioinformaticsBatchRole"
    }' \
    --region $REGION

# BLAST Job Definition
aws batch register-job-definition \
    --job-definition-name blast-job \
    --type container \
    --platform-capabilities FARGATE \
    --container-properties '{
        "image": "'$ACCOUNT_ID'.dkr.ecr.'$REGION'.amazonaws.com/bioinformatics-blast:latest",
        "resourceRequirements": [
            {"type": "VCPU", "value": "2"},
            {"type": "MEMORY", "value": "4096"}
        ],
        "executionRoleArn": "arn:aws:iam::'$ACCOUNT_ID':role/BioinformaticsBatchRole",
        "jobRoleArn": "arn:aws:iam::'$ACCOUNT_ID':role/BioinformaticsBatchRole"
    }' \
    --region $REGION

echo "🎉 AWS Batch setup complete!"