#!/bin/bash

# IAM Roles Setup - Accepts region as parameter
REGION=${1:-"me-south-1"}

echo "Creating IAM roles for region: $REGION..."

# Check if roles already exist
EXISTING_LAMBDA_ROLE=$(aws iam get-role --role-name BioinformaticsLambdaRole 2>/dev/null || echo "{}")
EXISTING_BATCH_ROLE=$(aws iam get-role --role-name BioinformaticsBatchRole 2>/dev/null || echo "{}")

# Create Lambda execution role if it doesn't exist
if [ "$EXISTING_LAMBDA_ROLE" = "{}" ]; then
    aws iam create-role \
        --role-name BioinformaticsLambdaRole \
        --assume-role-policy-document '{
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": {
                        "Service": "lambda.amazonaws.com"
                    },
                    "Action": "sts:AssumeRole"
                }
            ]
        }'
    echo "   Created: BioinformaticsLambdaRole"
else
    echo "   Already exists: BioinformaticsLambdaRole"
fi

# Create Batch execution role if it doesn't exist
if [ "$EXISTING_BATCH_ROLE" = "{}" ]; then
    aws iam create-role \
        --role-name BioinformaticsBatchRole \
        --assume-role-policy-document '{
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": {
                        "Service": "batch.amazonaws.com"
                    },
                    "Action": "sts:AssumeRole"
                }
            ]
        }'
    echo "   Created: BioinformaticsBatchRole"
else
    echo "   Already exists: BioinformaticsBatchRole"
fi

# Attach policies (idempotent - safe to run multiple times)
echo "   Attaching policies..."
aws iam attach-role-policy \
    --role-name BioinformaticsLambdaRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

aws iam attach-role-policy \
    --role-name BioinformaticsLambdaRole \
    --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

aws iam attach-role-policy \
    --role-name BioinformaticsLambdaRole \
    --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess

aws iam attach-role-policy \
    --role-name BioinformaticsLambdaRole \
    --policy-arn arn:aws:iam::aws:policy/AWSBatchFullAccess

echo "IAM roles setup complete for region: $REGION"
