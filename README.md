# OpenTelemetry Collector Dual-Export Demo

A production-ready OpenTelemetry Collector setup that demonstrates dual-export capabilities: real-time monitoring with Honeycomb and long-term archival storage with S3. Successfully tested with live telemetry data from multiple application types.

> **📚 Additional Setup**: Once your S3 archival is configured and working, consider enhancing your telemetry pipeline with Honeycomb's advanced features. See the [Honeycomb Telemetry Pipeline Enhancement Guide](https://docs.honeycomb.io/send-data/telemetry-pipeline/enhance/) for sampling strategies, data transformation, and optimization techniques.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Architecture](#architecture)
- [Configuration](#configuration)
- [Management](#management)
- [Troubleshooting](#troubleshooting)

## Overview

This is a **production-ready, dual-export** setup that demonstrates enterprise telemetry data management:

- 📦 **S3 Archive** - Complete telemetry data archival for compliance and long-term storage (✅ **VERIFIED WORKING**)
- ⚡ **Direct to Honeycomb** - Real-time analysis and alerting for all signal types (✅ **VERIFIED WORKING**)
- 🔍 **Refinery Support** - Ready for smart sampling when needed (commented out by default)
- 📊 **Sample Applications** - Multiple app types: Python SDK, OTLP external apps, FluentBit non-OTLP sources

### What's Included

- ✅ **Complete Docker stack** - Collector + sample apps in one command
- ✅ **Real telemetry generation** - Traces, metrics, logs using OpenTelemetry
- ✅ **Environment-based config** - Secure API key management
- ✅ **Simple management** - Easy start/stop/logs commands

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Sample App    │    │   External      │    │   FluentBit     │
│  (Python SDK)   │    │  Applications   │    │  Applications   │
│     OTLP        │    │    (OTLP)       │    │  (Non-OTLP)     │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          │ :4317/4318          │ :4317/4318          │ :8006
          └──────────────────────┼──────────────────────┘
                                 v
                    ┌─────────────────────┐
                    │  OpenTelemetry      │
                    │    Collector        │
                    │  (Multi-Pipeline)   │
                    └──────────┬──────────┘
                               │
                    ┌──────────┼──────────┐
                    │          │          │
                    v          v          v
        ┌─────────────────┐    │    ┌──────────────┐
        │   S3 Archive    │    │    │  Honeycomb   │
        │ ✅ VERIFIED     │    │    │   Direct     │
        │   WORKING       │    │    │✅ VERIFIED   │
        │                 │    │    │  WORKING     │
        │ otel/year=YYYY/ │    │    │              │
        │ month=MM/day=DD/│    │    │ Enhanced:    │
        │ hour=HH/min=MM/ │    │    │ • Queuing    │
        │                 │    │    │ • Retries    │
        │ Enhanced:       │    │    │ • Dataset    │
        │ • Proto marshal │    │    │   routing    │
        │ • Queuing       │    │    │ • Auto-named │
        │ • Batch tuning  │    │    │   services   │
        └─────────────────┘    │    └──────────────┘
                               │
                               v
                    ┌─────────────────┐
                    │   Refinery      │
                    │ (Optional -     │
                    │  Currently      │
                    │ Commented Out)  │
                    │       ↓         │
                    │   Honeycomb     │
                    └─────────────────┘
```

### Data Flow Summary

1. **S3 Archive Path**: `OTLP → Batch Processor → S3 Export` (✅ **ACTIVE** - all signal types, enhanced with Proto marshaling, queuing, and batch tuning)
2. **Honeycomb Direct Path**: `OTLP → Batch Processor → Honeycomb` (✅ **ACTIVE** - all signal types with dedicated datasets for logs/metrics, auto-named services for traces)
3. **FluentBit Path**: `FluentForward → Log Processors → Both S3 & Honeycomb` (✅ **READY**)
4. **Refinery Path**: `OTLP → Processors → Refinery → Honeycomb` (💤 **READY** - currently commented out)

## Prerequisites

### Required Components

- **OpenTelemetry Collector** (v0.88.0+)
- **AWS S3 bucket** for archival storage
- **Honeycomb account** with team API key
- **Refinery instance** (optional, for sampling)

### Required AWS Permissions

Create an IAM policy with S3 write permissions:

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
            "Resource": [
                "arn:aws:s3:::your-telemetry-bucket",
                "arn:aws:s3:::your-telemetry-bucket/*"
            ]
        }
    ]
}
```

> **📋 For detailed AWS setup instructions**, including S3 bucket creation, IAM role configuration, and troubleshooting, see [AWS-SETUP.md](./AWS-SETUP.md).

**For Testing/Demo:**

- Attach this policy to an IAM user
- Create access keys for the user
- Use the access keys in your `.env` file

**For Production:**

- Attach this policy to an IAM role
- Assign the role to your compute resources (EC2, EKS, ECS)
- Remove AWS credentials from environment variables

## Quick Start

### 1. Get Your API Keys

You need:

- **Honeycomb API key** (from https://ui.honeycomb.io/account)
- **AWS credentials** with S3 write access (see [AWS-SETUP.md](./AWS-SETUP.md) for detailed setup)

#### AWS Credentials Options

**For Testing/Demo (Easy):**

- Use AWS access keys from IAM user with S3 permissions
- Get them from AWS Console → IAM → Users → Security credentials

**For Production (Recommended):**

- Use IAM roles attached to your compute resources (EC2, EKS, ECS)
- No credential management needed - automatic authentication

### 2. Clone and Configure

```bash
# Clone the repository
git clone <repository-url>
cd collector-config-s3-archive

# Copy environment template and edit it
cp .env.example .env
nano .env
```

Update the required values in `.env`:

**For Testing/Demo:**

```bash
HONEYCOMB_API_KEY=your_actual_honeycomb_api_key_here
AWS_ACCESS_KEY_ID=your_aws_access_key_id
AWS_SECRET_ACCESS_KEY=your_aws_secret_access_key
```

**For Production (using IAM roles):**

```bash
HONEYCOMB_API_KEY=your_actual_honeycomb_api_key_here
# Remove AWS credentials - IAM role will provide them automatically
# AWS_ACCESS_KEY_ID=    # Comment out or remove
# AWS_SECRET_ACCESS_KEY=  # Comment out or remove
```

### 3. Start Everything

```bash
# One command to rule them all
make setup
```

That's it! This will:

- ✅ Check prerequisites (Docker, Docker Compose)
- ✅ Build the sample application images
- ✅ Start collector + 2 sample apps
- ✅ Validate the setup
- ✅ Show you the status and useful URLs

### 4. Verify It's Working

```bash
# Check status
make status

# Watch the logs
make logs

# Validate telemetry flow
make validate
```

You should see:

- **Collector health check** at http://localhost:8889/ (JSON status)
- **Telemetry data** flowing to your Honeycomb account ✅ **VERIFIED WORKING**
- **S3 objects** being created in your bucket ✅ **VERIFIED WORKING**

**Quick verification commands**:

```bash
# Check S3 export (replace with your bucket name)
aws s3 ls s3://your-bucket-name/otel/ --recursive | head -10

# Check collector debug output for data flow
docker logs otel-collector 2>&1 | grep -E "info.*(Traces|Metrics|Logs).*resource" | tail -5

# Check collector health
curl -s http://localhost:8889/ | jq
```

## Configuration

### Environment Variables

| Variable                | Required | Description                   | Example               |
| ----------------------- | -------- | ----------------------------- | --------------------- |
| `HONEYCOMB_API_KEY`     | Yes      | Honeycomb team API key        | `abc123...`           |
| `AWS_ACCESS_KEY_ID`     | Yes      | AWS access key for S3         | `your_aws_access_key` |
| `AWS_SECRET_ACCESS_KEY` | Yes      | AWS secret key for S3         | `wJalrXUtnFEMI/...`   |
| `AWS_REGION`            | No       | AWS region (if not in config) | `us-west-2`           |

### Key Configuration Sections

#### Receivers

```yaml
otlp/main:
  protocols:
    grpc:
      endpoint: 0.0.0.0:4317 # Standard OTLP gRPC port
    http:
      endpoint: 0.0.0.0:4318 # Standard OTLP HTTP port
```

#### Processors

- **`batch/main`**: High-throughput batching (100,000 items, 60s timeout)
- **`removeemptyvalues/*`**: Cleanup empty strings, nulls, and empty collections
- **`transform/*`**: Log timestamp parsing and cleanup

#### Exporters

- **`awss3/bulk_storage`**: Compressed S3 archival with time partitioning
- **`otlp/honeycomb_*`**: Refinery-based export (traces/logs only)
- **`otlp/honeycomb_direct_*`**: Direct Honeycomb export (all signal types)

### Pipeline Configuration

The configuration defines 8 pipelines across 3 data paths:

#### S3 Archival Pipelines

- `logs/bulk_storage`
- `metrics/bulk_storage`
- `traces/bulk_storage`

#### Refinery Pipelines

- `logs/honeycomb` (via Refinery)
- `traces/honeycomb` (via Refinery)

#### Direct Honeycomb Pipelines

- `logs/honeycomb_direct`
- `metrics/honeycomb_direct` (Required - Refinery doesn't support metrics)
- `traces/honeycomb_direct`

## Data Flows

### Signal Type Routing

| Signal Type | S3 Archive | Refinery | Direct Honeycomb |
| ----------- | ---------- | -------- | ---------------- |
| **Logs**    | ✅ Yes     | ✅ Yes   | ✅ Yes           |
| **Metrics** | ✅ Yes     | ❌ No\*  | ✅ Yes           |
| **Traces**  | ✅ Yes     | ✅ Yes   | ✅ Yes           |

\*Refinery doesn't support metrics - they must go directly to Honeycomb

### Processing Steps

1. **Data Ingestion**: Applications send OTLP data to collector
2. **Data Cleanup**: Remove empty values and normalize data
3. **Log Processing**: Parse timestamps and clean up log bodies
4. **Batching**: Group data for efficient export
5. **Multi-destination Export**: Send to S3, Refinery, and/or Honeycomb

### S3 Storage Structure

```
your-bucket/
├── otel/
│   ├── year=2024/
│   │   ├── month=01/
│   │   │   ├── day=15/
│   │   │   │   ├── hour=14/
│   │   │   │   │   ├── minute=30/  # Minute-based partitioning
│   │   │   │   │   │   ├── logs_*.json.gz
│   │   │   │   │   │   ├── metrics_*.json.gz
│   │   │   │   │   │   └── traces_*.json.gz
```

## Monitoring

### Collector Metrics

The collector exposes metrics on `http://localhost:8888/metrics` including:

- **Receiver metrics**: `otelcol_receiver_*`
- **Processor metrics**: `otelcol_processor_*`
- **Exporter metrics**: `otelcol_exporter_*`
- **Queue metrics**: `otelcol_exporter_queue_*`

### Key Metrics to Monitor

```bash
# Successful exports
otelcol_exporter_sent_spans_total
otelcol_exporter_sent_logs_total
otelcol_exporter_sent_metric_points_total

# Failed exports
otelcol_exporter_send_failed_spans_total
otelcol_exporter_send_failed_logs_total
otelcol_exporter_send_failed_metric_points_total

# Queue depth
otelcol_exporter_queue_size
```

### Health Checks

```bash
# Basic health check
curl -f http://localhost:8888/metrics > /dev/null

# Pipeline-specific health
curl http://localhost:8888/metrics | grep otelcol_exporter_sent

# Docker stack health check
make status

# Validate complete setup
make validate
```

## Management

### Available Commands

```bash
# Setup and management
make setup          # Complete setup and start everything
make start          # Start all services
make stop           # Stop all services
make restart        # Restart all services
make status         # Show service status

# Monitoring and debugging
make logs           # View all logs
make logs-collector # View collector logs only
make logs-apps      # View sample app logs only
make validate       # Check telemetry flow
make metrics        # Show collector metrics

# Maintenance
make build          # Rebuild Docker images
make clean          # Remove everything
```

### What's Running

| Service            | Purpose                                |
| ------------------ | -------------------------------------- |
| **otel-collector** | Multi-destination telemetry processing |
| **sample-app**     | Python app generating telemetry        |

### Sample Application

The Python sample app generates realistic telemetry:

- **📊 Traces**: User requests (`handle_login`, `handle_search`, etc.) with attributes
- **📈 Metrics**: Request counters, duration histograms, error counts, active users
- **📝 Logs**: Structured logs with user context and request details
- **❌ Errors**: 15% error rate with different error types
- **⏰ Background tasks**: Periodic cleanup/sync/backup jobs

All using pure **OpenTelemetry SDK** - no external dependencies for metrics or logging!

## Troubleshooting

### Common Issues

#### 1. S3 Export Failures

**Symptoms**: `otelcol_exporter_send_failed_*` metrics increasing

**Solutions**:

```bash
# Check AWS credentials
aws sts get-caller-identity

# Verify S3 bucket access
aws s3 ls s3://your-telemetry-archive-bucket

# Check IAM permissions
aws iam get-user-policy --user-name your-user --policy-name your-policy
```

#### 2. Honeycomb Connection Issues

**Symptoms**: Honeycomb exporters showing connection errors

**Solutions**:

```bash
# Verify API key
curl -H "X-Honeycomb-Team: $HONEYCOMB_API_KEY" https://api.honeycomb.io/1/auth

# Test direct connection
curl -v https://api.honeycomb.io:443

# Check Refinery endpoint
curl -v https://your-refinery.example.com:443
```

#### 3. High Memory Usage

**Symptoms**: Collector consuming excessive memory

**Solutions**:

- Reduce `send_batch_size` in batch processor
- Disable queues by setting `enabled: false` in sending_queue
- Increase export frequency by reducing `timeout` in batch processor

#### 4. Data Loss

**Symptoms**: Missing telemetry data in destinations

**Solutions**:

```yaml
# Enable persistent queues (requires file storage)
sending_queue:
  enabled: true
  storage: file_storage/persistent
```

#### 5. API Key Authentication Errors

**Symptoms**:

- Collector logs show: `attempted to use disabled API key`
- Collector logs show: `unknown API key - check your credentials, region, and API URL`
- HTTP 200 responses from test scripts but no data in Honeycomb dashboard

**Root Cause**: Docker containers may cache old environment variables even after updating `.env` file

**Solutions**:

1. **Full container recreation** (recommended):

   ```bash
   # Stop and remove containers
   docker-compose down

   # Clean up cached containers and images
   docker system prune -f

   # Restart with fresh environment
   docker-compose up -d
   ```

2. **Verify API key is working**:

   ```bash
   # Test direct API access
   curl -H "X-Honeycomb-Team: YOUR_API_KEY" https://api.honeycomb.io/1/auth

   # Test direct OTLP endpoint
   curl -X POST \
     -H "Content-Type: application/json" \
     -H "x-honeycomb-team: YOUR_API_KEY" \
     -H "x-honeycomb-dataset: test-dataset" \
     -d '{"resourceMetrics":[...]}' \
     https://api.honeycomb.io/v1/metrics
   ```

3. **Check API key format**: Ensure key starts with `hcaik_` and is complete (typically 70+ characters)

#### 6. S3 Export Verification and Common Issues

**Symptoms**:

- No data appearing in S3 bucket despite collector running
- S3 console shows "PRE otel/" but unsure if data is actually being written
- Alpha component warnings in logs

**Diagnostic Steps**:

1. **Verify S3 export is working**:

   ```bash
   # Test S3 access with collector's exact credentials
   export AWS_ACCESS_KEY_ID="your_collector_access_key"
   export AWS_SECRET_ACCESS_KEY="your_collector_secret"
   export AWS_DEFAULT_REGION="us-east-1"
   export S3_BUCKET_NAME="your_bucket_name"

   # List S3 contents to verify data
   aws s3 ls s3://$S3_BUCKET_NAME/otel/ --recursive
   ```

2. **Check debug exporter output**:

   ```bash
   # Look for telemetry flowing through S3 pipelines
   docker logs otel-collector 2>&1 | grep -E "info.*(Traces|Metrics|Logs).*resource"

   # You should see duplicate entries - one for each pipeline (Honeycomb + S3)
   ```

3. **Expected S3 structure**:
   ```
   your-bucket/
   └── otel/
       └── year=2025/
           └── month=07/
               └── day=31/
                   └── hour=21/
                       └── minute=30/  # Minute-based partitioning
                           ├── logs_*.json.gz
                           ├── metrics_*.json.gz
                           └── traces_*.json.gz
   ```

**Common Fixes**:

- **S3 exporter is Alpha**: This is expected - the component works but may have some instability
- **"PRE otel/" in S3 console**: This just means there's an `otel/` directory - this is correct
- **Silent failures**: Check AWS credentials and bucket permissions with the test script above

### Debug Configuration

```yaml
service:
  telemetry:
    logs:
      level: debug # Enable debug logging
    metrics:
      level: detailed # Detailed metrics
      address: 0.0.0.0:8888
```

### Log Analysis

```bash
# Search for errors
docker logs collector-container 2>&1 | grep -i error

# Monitor export rates
docker logs collector-container 2>&1 | grep "successfully sent"

# Check configuration validation
docker logs collector-container 2>&1 | grep -i "config"
```

## Production Considerations

### Performance Tuning

#### High-Throughput Settings

```yaml
processors:
  batch/main:
    send_batch_size: 100000 # Large batches
    send_batch_max_size: 0 # No size limit
    timeout: 30s # Frequent exports

receivers:
  otlp/main:
    protocols:
      grpc:
        max_recv_msg_size_mib: 32 # Larger messages
```

#### Memory Management

- Monitor collector memory usage with system metrics
- Set appropriate container memory limits
- Consider using multiple collector instances for horizontal scaling

### Security Best Practices

1. **Environment Variables**: Never hardcode API keys in configuration
2. **Network Security**: Use TLS for all external connections
3. **Access Control**: Limit IAM permissions to minimum required
4. **Secrets Management**: Use AWS Secrets Manager or similar for production

### Reliability

#### Retry Configuration

```yaml
retry_on_failure:
  enabled: true
  initial_interval: 5s
  max_elapsed_time: 300s # 5 minutes total retry time
  max_interval: 30s
```

#### Queue Configuration

```yaml
sending_queue:
  enabled: false # Disabled for simplicity
  num_consumers: 10 # Parallel export workers
  queue_size: 5000 # Buffer size
```

### Scaling Considerations

#### Horizontal Scaling

- Deploy multiple collector instances behind a load balancer
- Use consistent hashing for stateful processing
- Consider collector clustering for coordination

#### Vertical Scaling

- Increase batch sizes for higher throughput
- Add more CPU cores for processing-intensive workloads
- Increase memory for larger queues and batches

### Quick Fixes

**No data in Honeycomb?**

- Check `make validate` - collector should show "Receiving data"
- Verify your `HONEYCOMB_API_KEY` in `.env`
- Check `make logs-collector` for errors

**S3 errors?**

- Update `collector-config.yaml` with your actual S3 bucket name
- Verify AWS credentials have S3 write permissions
- Check `make logs-collector` for S3 export errors

**Services won't start?**

- Run `make clean` then `make setup` to reset everything
- Check Docker is running: `docker info`
- Verify `.env` file exists with required values

**Want more/less telemetry?**

- Edit the Python apps in `sample-app/app.py`
- Adjust sleep times, error rates, or add more operations
- Restart with `make restart`

## Next Steps

This demo shows the **basics**. For production:

1. **Use IAM roles** - Remove access keys, use roles attached to compute resources
2. **Secure your secrets** - Use AWS Secrets Manager, HashiCorp Vault, etc.
3. **Configure S3 lifecycle** - Set up automatic archival to Glacier for cost savings
4. **Monitor the collector** - Set up alerts on collector metrics and health
5. **Scale horizontally** - Run multiple collector instances behind a load balancer
6. **Add sampling** - Configure Refinery sampling rules for high-volume traces

### Production Deployment Examples

**On EKS (Kubernetes):**

```yaml
# Use IAM Roles for Service Accounts (IRSA)
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/otel-collector-role
```

**On EC2:**

```bash
# Attach IAM role to EC2 instance, remove AWS credentials from environment
export HONEYCOMB_API_KEY=your_key
# AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY not needed
docker-compose up -d
```

**On ECS:**

```json
{
  "taskRoleArn": "arn:aws:iam::ACCOUNT:role/otel-collector-task-role",
  "executionRoleArn": "arn:aws:iam::ACCOUNT:role/ecsTaskExecutionRole"
}
```

## Resources

- [OpenTelemetry Collector docs](https://opentelemetry.io/docs/collector/)
- [Honeycomb documentation](https://docs.honeycomb.io/)
- [Refinery (sampling) docs](https://github.com/honeycombio/refinery)
