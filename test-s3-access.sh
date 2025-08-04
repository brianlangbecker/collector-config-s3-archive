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

echo -e "\n2. Testing S3 write access (collector's primary function)..."
echo "test-$(date)" | aws s3 cp - s3://$S3_BUCKET_NAME/test-collector-access.txt
if [ $? -eq 0 ]; then
    echo "✅ S3 write access: SUCCESS - Collector can archive telemetry data"
else
    echo "❌ S3 write access: FAILED - Check IAM permissions for s3:PutObject"
fi

echo -e "\n3. Testing S3 bucket listing (optional for collector)..."
echo "Note: s3:ListBucket permission is not required for collector operation"
echo "The collector only needs s3:PutObject to write telemetry archives"
echo ""
aws s3 ls s3://$S3_BUCKET_NAME/ 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✅ S3 list access: Available"
else
    echo "ℹ️  S3 list access: Not available (this is normal for write-only collector access)"
    echo "    To enable listing, add 's3:ListBucket' to your IAM policy"
fi

echo -e "\n4. Manual verification steps (when listing is not available):"
echo "To verify collector S3 archival without s3:ListBucket permission:"
echo ""
echo "a) Check collector debug logs for successful data flow:"
echo "   docker logs otel-collector 2>&1 | grep -E 'info.*(Traces|Metrics|Logs).*resource' | tail -5"
echo ""
echo "b) Look for duplicate debug entries (confirms dual-export to S3 + Honeycomb):"
echo "   Each signal type should appear twice in debug output"
echo ""
echo "c) Expected S3 structure (if you have s3:ListBucket permission):"
echo "   s3://$S3_BUCKET_NAME/otel/year=YYYY/month=MM/day=DD/hour=HH/minute=MM/"
echo "   └── Contains: logs_*.binpb.gz, metrics_*.binpb.gz, traces_*.binpb.gz"
echo ""
echo "d) Verify collector health:"
echo "   curl -s http://localhost:8889/ | jq"

echo -e "\n5. Optional: Advanced verification (if you have broader S3 permissions)..."
if aws s3 ls s3://$S3_BUCKET_NAME/otel/ --recursive >/dev/null 2>&1; then
    echo "✅ Found otel/ directory with telemetry archives:"
    aws s3 ls s3://$S3_BUCKET_NAME/otel/ --recursive | head -10
else
    echo "ℹ️  Cannot list otel/ directory (requires s3:ListBucket permission)"
    echo "    This doesn't affect collector functionality - it can still write data"
fi