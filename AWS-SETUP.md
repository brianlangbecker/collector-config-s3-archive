# AWS Setup Guide for OpenTelemetry Collector Demo

This guide shows you how to set up AWS S3 bucket and credentials for the OpenTelemetry Collector S3 archival feature.

## Table of Contents

- [S3 Bucket Setup](#s3-bucket-setup)
- [Quick Setup (Testing/Demo)](#quick-setup-testingdemo)
- [Production Setup (IAM Roles)](#production-setup-iam-roles)
- [AWS CLI Setup](#aws-cli-setup)
- [Troubleshooting](#troubleshooting)

---

## S3 Bucket Setup

First, you need to create an S3 bucket to store your telemetry data archives.

### Step 1: Create S3 Bucket

1. **Go to AWS Console → S3**
2. **Click "Create bucket"**
3. **Configure bucket settings:**

**Basic Configuration:**

- **Bucket name:** `your-company-telemetry-archive` (must be globally unique)
- **AWS Region:** Choose region closest to your collector (e.g., `us-west-2`)

**Object Ownership:**

- **For Secret Keys/IAM Users:** ACLs disabled (Bucket owner enforced) ✅
- **For IAM Roles:** ACLs disabled (Bucket owner enforced) ✅
- **Note:** Both authentication methods work with ACLs disabled

**Block Public Access:**

- ✅ **Block all public access** (recommended for security)
- ✅ Check all four options:
  - Block public access to buckets and objects granted through new access control lists
  - Block public access to buckets and objects granted through any access control lists
  - Block public access to buckets and objects granted through new public bucket or access point policies
  - Block public access to buckets and objects granted through any public bucket or access point policies

**Bucket Versioning:**

- **Recommended:** Enable versioning for data protection
- This allows recovery of accidentally overwritten telemetry files

**Server-side Encryption:**

- **Recommended:** Server-side encryption with Amazon S3 managed keys (SSE-S3)
- **Bucket Key:** Enable (reduces costs)

### Step 2: Configure Lifecycle Management (Optional but Recommended)

To manage storage costs for long-term telemetry data:

4. **After bucket creation, go to bucket → Management tab**
5. **Click "Create lifecycle rule"**
6. **Lifecycle rule configuration:**
   - **Rule name:** `telemetry-archive-lifecycle`
   - **Status:** Enabled
   - **Rule scope:** Apply to all objects
7. **Lifecycle rule actions:**
   - **Transition current versions:** After 30 days → Standard-IA
   - **Delete incomplete multipart uploads:** After 7 days
   - **Note:** Glacier storage classes are not supported at this time

### Step 3: Collector Authentication Methods

The OpenTelemetry Collector can access S3 using either method:

**Option A: Secret Keys (Testing/Development)**

- Uses AWS Access Key ID + Secret Access Key
- Configured in `.env` file or environment variables
- Collector authenticates as IAM user

**Option B: IAM Roles (Production)**

- Uses IAM roles attached to EC2/EKS/ECS instances
- No credentials in config files (more secure)
- Collector inherits permissions from instance role

**Both methods work with the S3 bucket settings above.** The key requirements:

- ✅ Collector needs `s3:PutObject` permission on the bucket
- ✅ Collector needs `s3:PutObjectAcl` permission (if ACLs enabled)
- ✅ Collector needs `s3:PutObjectDestination`
- ✅ Regional access (collector and bucket in same region = faster uploads)

### Step 4: Update Environment Variables

Update your `.env` file with the bucket name:

```bash
# Replace with your actual bucket name
S3_BUCKET_NAME=your-company-telemetry-archive
AWS_DEFAULT_REGION=us-west-2  # Match your bucket region

# For Secret Key method (development/testing):
AWS_ACCESS_KEY_ID=your_access_key_here
AWS_SECRET_ACCESS_KEY=your_secret_key_here

# For IAM Role method (production):
# No AWS credentials needed - remove AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY
```

---

## Docker Development with IAM Roles

Use this approach when developing locally with Docker but want to test IAM role-based authentication (similar to production).

### Prerequisites

- AWS CLI configured with a user that can assume roles
- Docker and Docker Compose installed

### Step 1: Create IAM Role for Testing

1. **Create the role (if not already created):**
   ```bash
   aws iam create-role --role-name otel-s3-collector-dev-role --assume-role-policy-document '{
     "Version": "2012-10-17",
     "Statement": [{
       "Effect": "Allow",
       "Principal": {"AWS": "arn:aws:iam::YOUR-ACCOUNT:user/otel-collector-s3-user"},
       "Action": "sts:AssumeRole"
     }]
   }'
   ```

2. **Attach S3 policy to role:**
   ```bash
   aws iam attach-role-policy \
     --role-name otel-s3-collector-dev-role \
     --policy-arn arn:aws:iam::YOUR-ACCOUNT:policy/OTelS3CollectorWriteAccess
   ```

### Step 2: Give Your User AssumeRole Permission

Add this policy to your existing IAM user (`otel-collector-s3-user`):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::YOUR-ACCOUNT:role/otel-s3-collector-dev-role"
    }
  ]
}
```

### Step 3: Configure AWS CLI Profile

Edit `~/.aws/config`:

```ini
[profile otel-s3-dev-role]
role_arn = arn:aws:iam::YOUR-ACCOUNT:role/otel-s3-collector-dev-role
source_profile = otel-collector-s3-user
region = us-east-1
```

### Step 4: Test Role Access

```bash
# Test the role assumption
aws sts get-caller-identity --profile otel-s3-dev-role

# Should show the role ARN, not your user ARN
```

### Step 5: Configure Environment

```bash
# Copy IAM role environment template
cp .env.iam-role-example .env

# Edit with your values (no AWS keys needed)
nano .env
```

### Step 6: Run with Role

```bash
# Set AWS profile and run
export AWS_PROFILE=otel-s3-dev-role
docker-compose up -d

# Test S3 access
./test-s3-access.sh
```

### Troubleshooting Docker + IAM Roles

**Problem:** Role not being used in container

**Solution:** Make sure AWS profile is exported and accessible:
```bash
# Check profile is set
echo $AWS_PROFILE

# Test role outside container
aws sts get-caller-identity --profile $AWS_PROFILE

# Pass profile to container (update docker-compose.yml if needed)
docker-compose config | grep AWS_PROFILE
```

---

## Quick Setup (Testing/Demo)

Use this approach for local testing and demos. It uses IAM user access keys.

### Step 1: Create IAM User

1. **Go to AWS Console → IAM → Users**
2. **Click "Create user"**
3. **User name:** `otel-collector-s3-user`
4. **Click "Next"**

### Step 2: Create S3 Policy

5. **Select "Attach policies directly"**
6. **Click "Create policy"** (opens new tab)
7. **Switch to JSON tab and paste:**

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:PutObjectAcl",
                "s3:PutObjectRetention"
            ],
                "arn:aws:s3:::your-telemetry-bucket",
                "arn:aws:s3:::your-telemetry-bucket/*"
        }
    ]
}
```

8. **Policy name:** `OTelS3CollectorWriteAccess`
9. **Description:** `Allows OpenTelemetry Collector to write to any S3 bucket`
10. **Click "Create policy"**

### Step 3: Attach Policy to User

11. **Go back to the user creation tab**
12. **Click refresh and search for `OTelS3WriteAccess`**
13. **Select the policy**
14. **Click "Next" → "Create user"**

### Step 4: Generate Access Keys

15. **Click on your new user name**
16. **Go to "Security credentials" tab**
17. **Click "Create access key"**
18. **Select "Local code" or "Other"**
19. **Description (optional):** `OpenTelemetry Collector Demo`
20. **Click "Next" → "Create access key"**
21. **⚠️ COPY BOTH KEYS IMMEDIATELY** (you can't see the secret key again!)

### Step 5: Create S3 Bucket (Optional)

If you don't have an S3 bucket, create one:

```bash
# Replace with a unique name
aws s3 mb s3://your-unique-otel-demo-bucket-12345
```

### Step 6: Use in Demo

Add the keys to your `.env` file:

```bash
HONEYCOMB_API_KEY=your_honeycomb_key_here
AWS_ACCESS_KEY_ID=AKIA...your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key_here
AWS_DEFAULT_REGION=us-east-1
```

---

## Production Setup (IAM Roles)

Use this approach for production deployments. No access keys needed!

### Step 1: Create IAM Role

1. **Go to AWS Console → IAM → Roles**
2. **Click "Create role"**
3. **Select your compute service:**
   - **EC2** for EC2 instances
   - **EKS - EKS service account** for Kubernetes
   - **Elastic Container Service Task** for ECS

### Step 2: Attach S3 Policy

4. **Search for and select `OTelS3CollectorWriteAccess`** (created above)
5. **Or create a more restrictive policy for specific buckets:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:PutObject", "s3:PutObjectAcl","s3:PutObjectRetention"
"],
      "arn:aws:s3:::your-telemetry-bucket",
      "arn:aws:s3:::your-telemetry-bucket/*"
    }
  ]
}
```

### Step 3: Platform-Specific Setup

#### For EC2 Instances

6. **Role name:** `otel-collector-ec2-role`
7. **Attach role to EC2 instance:**

   - Go to EC2 → Instances
   - Select instance → Actions → Security → Modify IAM role
   - Select `otel-collector-ec2-role`

8. **Remove AWS credentials from environment:**

```bash
# Only set these:
export HONEYCOMB_API_KEY=your_key
# Do NOT set AWS_ACCESS_KEY_ID or AWS_SECRET_ACCESS_KEY
```

#### For EKS (Kubernetes)

6. **Role name:** `otel-collector-eks-role`
7. **Set up IRSA (IAM Roles for Service Accounts):**

```bash
# Associate IAM role with Kubernetes service account
eksctl create iamserviceaccount \
  --name otel-collector \
  --namespace default \
  --cluster your-cluster-name \
  --attach-role-arn arn:aws:iam::YOUR-ACCOUNT:role/otel-collector-eks-role \
  --approve
```

8. **Use in Kubernetes deployment:**

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: otel-collector
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::YOUR-ACCOUNT:role/otel-collector-eks-role
```

#### For ECS

6. **Role name:** `otel-collector-task-role`
7. **Use in ECS task definition:**

```json
{
  "taskRoleArn": "arn:aws:iam::YOUR-ACCOUNT:role/otel-collector-task-role",
  "containerDefinitions": [
    {
      "name": "otel-collector",
      "environment": [
        {
          "name": "HONEYCOMB_API_KEY",
          "value": "your_key"
        }
      ]
    }
  ]
}
```

---

## AWS CLI Setup

### Install AWS CLI

**macOS:**

```bash
brew install awscli
```

**Linux:**

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

**Windows:**
Download from: https://aws.amazon.com/cli/

### Configure AWS CLI

**For Testing (using access keys):**

```bash
aws configure
# Enter your Access Key ID
# Enter your Secret Access Key
# Enter region (e.g., us-west-2)
# Enter output format (json)
```

**For Production (using IAM roles):**

```bash
# No configuration needed if running on AWS with IAM roles
# CLI automatically uses instance/task/pod credentials
```

### Verify Setup

```bash
# Test AWS access
aws sts get-caller-identity

# Test S3 access
aws s3 ls

# Create test bucket
aws s3 mb s3://your-test-bucket-12345

# Test write access
echo "test" | aws s3 cp - s3://your-test-bucket-12345/test.txt
```

---

## Troubleshooting

### Access Denied Errors

**Problem:** `AccessDenied` when collector tries to write to S3

**Solutions:**

1. **Check IAM permissions:**

   ```bash
   aws iam simulate-principal-policy \
     --policy-source-arn arn:aws:iam::ACCOUNT:user/otel-collector-s3-user \
     --action-names s3:PutObject \
     --resource-arns arn:aws:s3:::your-bucket/*
   ```

2. **Verify bucket exists:**

   ```bash
   aws s3 ls s3://your-bucket/
   ```

3. **Check region configuration:**
   - Ensure bucket and credentials are in the same region
   - Set `AWS_DEFAULT_REGION` environment variable

### Invalid Credentials

**Problem:** `InvalidAccessKeyId` or `SignatureDoesNotMatch`

**Solutions:**

1. **Regenerate access keys:**

   - Go to IAM → Users → Security credentials
   - Deactivate old keys, create new ones

2. **Check environment variables:**
   ```bash
   echo $AWS_ACCESS_KEY_ID
   echo $AWS_SECRET_ACCESS_KEY
   # Make sure they match your IAM user keys
   ```

### Bucket Permission Issues

**Problem:** Can list buckets but can't write objects

**Solutions:**

1. **Update IAM policy to be more specific:**

   ```json
   {
     "Resource": ["arn:aws:s3:::your-bucket", "arn:aws:s3:::your-bucket/*"]
   }
   ```

2. **Check bucket policy doesn't block access**
3. **Verify bucket ownership**

### CLI Not Working

**Problem:** `aws` command not found or not working

**Solutions:**

1. **Check installation:**

   ```bash
   which aws
   aws --version
   ```

2. **Update PATH:**

   ```bash
   export PATH=$PATH:/usr/local/bin
   ```

3. **Reinstall AWS CLI** using steps above

### IAM Role Not Working

**Problem:** Role attached but collector still gets access denied

**Solutions:**

1. **Wait 5-10 minutes** for role propagation
2. **Restart your compute resource** (EC2, ECS task, etc.)
3. **Check trust policy** allows your service to assume the role
4. **Verify role has the right permissions policy attached**

---

## Security Best Practices

### For Testing/Demo

- ✅ Use dedicated IAM user for demos
- ✅ Use minimal permissions (only S3 PutObject)
- ✅ Rotate access keys regularly
- ❌ Don't commit keys to git repositories
- ❌ Don't use in production

### For Production

- ✅ Use IAM roles instead of access keys
- ✅ Follow principle of least privilege
- ✅ Use specific bucket ARNs in policies
- ✅ Enable CloudTrail for audit logging
- ✅ Monitor unusual API activity
- ❌ Don't use wildcard permissions in production

---

## Quick Reference

### Commands for Testing Setup

```bash
# Configure AWS CLI
aws configure

# Create S3 bucket
aws s3 mb s3://my-otel-demo-bucket

# Test collector access
aws s3 cp test.txt s3://my-otel-demo-bucket/

# Check collector can write
curl http://localhost:8888/metrics | grep s3
```

### Environment Variables

```bash
# For testing (access keys)
export AWS_ACCESS_KEY_ID="AKIA..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_DEFAULT_REGION="us-west-2"

# For production (IAM roles)
export AWS_DEFAULT_REGION="us-west-2"
# No access keys needed
```

### Useful AWS CLI Commands

```bash
# Check current identity
aws sts get-caller-identity

# List S3 buckets
aws s3 ls

# Check IAM user permissions
aws iam list-attached-user-policies --user-name otel-collector-s3-user

# Check IAM role permissions
aws iam list-attached-role-policies --role-name otel-collector-role
```
