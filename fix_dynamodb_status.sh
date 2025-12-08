#!/bin/bash
REGION="me-south-1"
TIMESTAMP="2025-10-31T10:26:24.000Z"

echo "=== UPDATING DYNAMODB JOB STATUS ==="

# FastQC job
echo "Updating FastQC job..."
aws dynamodb update-item \
    --table-name BioinformaticsJobs \
    --key '{"jobId": {"S": "41f9428e-02ac-462c-a79d-50f29642a2d2"}}' \
    --update-expression 'SET #status = :status, updatedAt = :now, resultFiles = :files' \
    --expression-attribute-names '{"#status": "status"}' \
    --expression-attribute-values "{
        \":status\": {\"S\": \"COMPLETED\"},
        \":now\": {\"S\": \"$TIMESTAMP\"},
        \":files\": {\"L\": [
            {\"S\": \"41f9428e-02ac-462c-a79d-50f29642a2d2/input_fastqc.html\"},
            {\"S\": \"41f9428e-02ac-462c-a79d-50f29642a2d2/input_fastqc.zip\"}
        ]}
    }" \
    --region $REGION

# BLAST job - check if files exist first
echo "Checking BLAST files..."
BLAST_FILES=$(aws s3 ls s3://bioinformatics-platform-results-1761318731/7262367c-868f-499f-8ddc-db0f8debe16b/ --region $REGION)
echo "BLAST files found: $BLAST_FILES"

echo "Updating BLAST job..."
aws dynamodb update-item \
    --table-name BioinformaticsJobs \
    --key '{"jobId": {"S": "7262367c-868f-499f-8ddc-db0f8debe16b"}}' \
    --update-expression 'SET #status = :status, updatedAt = :now' \
    --expression-attribute-names '{"#status": "status"}' \
    --expression-attribute-values "{
        \":status\": {\"S\": \"COMPLETED\"},
        \":now\": {\"S\": \"$TIMESTAMP\"}
    }" \
    --region $REGION

echo "=== STATUS UPDATES COMPLETED ==="
