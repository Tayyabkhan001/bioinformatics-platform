#!/bin/bash

echo "⚡ Setting up AWS Batch for Bioinformatics Processing..."
echo "========================================================"

REGION="me-south-1"
ACCOUNT_ID="480421269735"

# Get default VPC
echo "🌐 Getting network configuration..."
VPC_ID=$(aws ec2 describe-vpcs --region $REGION --filters "Name=isDefault,Values=true" --query 'Vpcs[0].VpcId' --output text)
echo "   VPC ID: $VPC_ID"

# Get default subnets
SUBNETS=$(aws ec2 describe-subnets --region $REGION --filters "Name=default-for-az,Values=true" --query 'Subnets[*].SubnetId' --output text)
SUBNET_IDS=$(echo $SUBNETS | tr ' ' ',')

# Get default security group
SG_ID=$(aws ec2 describe-security-groups --region $REGION --filters "Name=group-name,Values=default" "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[0].GroupId' --output text)
echo "   Subnets: $SUBNET_IDS"
echo "   Security Group: $SG_ID"

# Delete existing compute environment if exists
EXISTING_CE=$(aws batch describe-compute-environments --compute-environments bioinformatics-compute --region $REGION --query 'computeEnvironments[0].computeEnvironmentName' --output text 2>/dev/null)
if [ "$EXISTING_CE" == "bioinformatics-compute" ]; then
    echo "⚠️ Existing compute environment found. Disabling and deleting..."
    aws batch update-compute-environment --compute-environment bioinformatics-compute --state DISABLED --region $REGION
    echo "⏳ Waiting for environment to be DISABLED..."
    sleep 20
    aws batch delete-compute-environment --compute-environment bioinformatics-compute --region $REGION
    echo "✅ Deleted old compute environment"
fi

# Delete existing job queue if exists
EXISTING_JQ=$(aws batch describe-job-queues --job-queues bioinformatics-queue --region $REGION --query 'jobQueues[0].jobQueueName' --output text 2>/dev/null)
if [ "$EXISTING_JQ" == "bioinformatics-queue" ]; then
    echo "⚠️ Existing job queue found. Deleting..."
    aws batch update-job-queue --job-queue bioinformatics-queue --state DISABLED --region $REGION
    sleep 10
    aws batch delete-job-queue --job-queue bioinformatics-queue --region $REGION
    echo "✅ Deleted old job queue"
fi

# Create Compute Environment
echo "🖥️ Creating Compute Environment (Fargate)..."
aws batch create-compute-environment \
    --compute-environment-name bioinformatics-compute \
    --type MANAGED \
    --state ENABLED \
    --service-role arn:aws:iam::$ACCOUNT_ID:role/AWSBatchServiceRole \
    --compute-resources type=FARGATE,maxvCpus=16,subnets=$SUBNET_IDS,securityGroupIds=$SG_ID \
    --region $REGION

echo "⏳ Waiting 40s for compute environment to initialize..."
sleep 40

# Create Job Queue
echo "📋 Creating Job Queue..."
aws batch create-job-queue \
    --job-queue-name bioinformatics-queue \
    --state ENABLED \
    --priority 1 \
    --compute-environment-order order=1,computeEnvironment=bioinformatics-compute \
    --region $REGION

echo "⏳ Waiting 20s for job queue to initialize..."
sleep 20

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
        "environment": [
            {"name": "AWS_DEFAULT_REGION", "value": "'$REGION'"}
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
        "environment": [
            {"name": "AWS_DEFAULT_REGION", "value": "'$REGION'"}
        ],
        "executionRoleArn": "arn:aws:iam::'$ACCOUNT_ID':role/BioinformaticsBatchRole",
        "jobRoleArn": "arn:aws:iam::'$ACCOUNT_ID':role/BioinformaticsBatchRole"
    }' \
    --region $REGION

echo "🎉 AWS Batch setup complete!"
echo "📊 Job Queue: bioinformatics-queue"
echo "🔧 Compute Environment: bioinformatics-compute"
echo "🐳 Job Definitions: fastqc-job, blast-job"
