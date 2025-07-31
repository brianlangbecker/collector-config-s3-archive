#!/bin/bash

# Test S3 access using the same credentials as the collector
# Replace these with your actual values from .env file
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-AKIA...your_access_key_here}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-your_secret_access_key_here}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
export S3_BUCKET_NAME="${S3_BUCKET_NAME:-your-bucket-name}"

echo "Testing AWS S3 access with collector credentials..."
echo "Bucket: $S3_BUCKET_NAME"
echo "Region: $AWS_DEFAULT_REGION"
echo ""

echo "1. Testing AWS credentials..."
aws sts get-caller-identity

echo -e "\n2. Testing S3 bucket access..."
aws s3 ls s3://$S3_BUCKET_NAME/

echo -e "\n3. Testing S3 write access..."
echo "test-$(date)" | aws s3 cp - s3://$S3_BUCKET_NAME/test-collector-access.txt

echo -e "\n4. Checking for otel/ directory structure..."
aws s3 ls s3://$S3_BUCKET_NAME/otel/ --recursive

echo -e "\n5. Checking for any pre-otel files..."
aws s3 ls s3://$S3_BUCKET_NAME/ --recursive | grep -i "pre-otel" || echo "No pre-otel files found"

echo -e "\n6. Listing all files in bucket..."
aws s3 ls s3://$S3_BUCKET_NAME/ --recursive | head -20