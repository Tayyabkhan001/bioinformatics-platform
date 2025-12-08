#!/bin/bash

echo "🐳 Setting up ECR Repositories for Bioinformatics Tools..."
echo "=========================================================="

REGION="me-south-1"
ACCOUNT_ID="480421269735"

# Create ECR repositories
echo "📦 Creating ECR repositories..."
aws ecr create-repository \
    --repository-name bioinformatics-fastqc \
    --region $REGION

aws ecr create-repository \
    --repository-name bioinformatics-blast \
    --region $REGION

echo "✅ ECR repositories created"

# Get ECR login token
echo "🔐 Getting ECR login token..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

# Build and push FastQC image
echo "🔨 Building FastQC Docker image..."
cd docker
docker build -t bioinformatics-fastqc -f Dockerfile.fastqc .

# Tag and push
docker tag bioinformatics-fastqc:latest $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/bioinformatics-fastqc:latest
docker push $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/bioinformatics-fastqc:latest

# Build and push BLAST image
echo "🔨 Building BLAST Docker image..."
docker build -t bioinformatics-blast -f Dockerfile.blast .

# Tag and push
docker tag bioinformatics-blast:latest $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/bioinformatics-blast:latest
docker push $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/bioinformatics-blast:latest

echo "🎉 Docker images pushed to ECR!"
echo "📦 FastQC: $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/bioinformatics-fastqc:latest"
echo "📦 BLAST: $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/bioinformatics-blast:latest"