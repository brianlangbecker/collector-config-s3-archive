# Virtual Environment Setup for Direct Honeycomb Testing

This guide shows how to run the sample app directly to Honeycomb using a Python virtual environment, bypassing the OpenTelemetry Collector.

## Quick Reference

| Task | Command |
|------|---------|
| **Setup & Test** | `export HONEYCOMB_API_KEY="your_key" && ./test-venv-setup-auto.sh` |
| **Run App** | `source venv/bin/activate && ./run-direct-test.sh` |
| **Cleanup** | `./cleanup.sh` |
| **Interactive Test** | `export HONEYCOMB_API_KEY="your_key" && ./test-venv-setup.sh` |

## Prerequisites

- Python 3.8+
- Honeycomb account with API key
- pip and venv

## Quick Start

### 1. Get Your Honeycomb API Key

Get your API key from: https://ui.honeycomb.io/account

### 2. Automated Setup (Recommended)

For the fastest setup, use the automated test script:

```bash
# Set your API key
export HONEYCOMB_API_KEY="your_actual_honeycomb_api_key_here"

# Run automated setup and test
./test-venv-setup-auto.sh
```

This will:
- ✅ Create virtual environment
- ✅ Install dependencies  
- ✅ Test OpenTelemetry imports
- ✅ Validate API connectivity
- ✅ Create production run script
- ✅ Test the sample app

### 3. Manual Setup

If you prefer to set up manually:

```bash
# Navigate to the sample app directory
cd sample-app

# Create virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

### 3. Configure Direct Honeycomb Export

Set environment variables for direct Honeycomb export:

```bash
# Required: Your Honeycomb API key
export HONEYCOMB_API_KEY="your_actual_honeycomb_api_key_here"

# Required: Honeycomb endpoint (direct to Honeycomb, not collector)
export OTEL_EXPORTER_OTLP_ENDPOINT="https://api.honeycomb.io:443"

# Required: Add Honeycomb API key as header
export OTEL_EXPORTER_OTLP_HEADERS="x-honeycomb-team=$HONEYCOMB_API_KEY"

# Optional: Service information
export OTEL_SERVICE_NAME="sample-app-direct"
export OTEL_SERVICE_VERSION="1.0.0"
export OTEL_SERVICE_INSTANCE_ID="local-test"
```

### 4. Run the Sample App

```bash
python app.py
```

You should see output like:
```
🚀 Starting Simple OpenTelemetry Demo
📡 Endpoint: https://api.honeycomb.io:443
🏷️  Service: sample-app-direct
📊 Generating traces, metrics, and logs...
⏹️  Press Ctrl+C to stop

✅ Generated 90 requests and telemetry
```

### 5. View Data in Honeycomb

1. Go to https://ui.honeycomb.io/
2. Look for a dataset named `sample-app-direct` (or your OTEL_SERVICE_NAME)
3. You should see:
   - **Traces** with operations like `handle_login`, `handle_search`
   - **Logs** with structured data from the application
   - **No Metrics** (Honeycomb's OTLP endpoint doesn't accept metrics directly)

## Environment Variables Reference

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `HONEYCOMB_API_KEY` | Yes | Honeycomb team API key | `your_honeycomb_api_key` |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | Yes | Direct Honeycomb endpoint | `https://api.honeycomb.io:443` |
| `OTEL_EXPORTER_OTLP_HEADERS` | Yes | API key header | `x-honeycomb-team=$HONEYCOMB_API_KEY` |
| `OTEL_SERVICE_NAME` | No | Service name in Honeycomb | `sample-app-direct` |
| `OTEL_SERVICE_VERSION` | No | Service version | `1.0.0` |
| `OTEL_SERVICE_INSTANCE_ID` | No | Instance identifier | `local-test` |

## Convenience Script

Create a script to make this easier:

```bash
# Create run-direct.sh
cat > run-direct.sh << 'EOF'
#!/bin/bash

# Check if API key is provided
if [ -z "$HONEYCOMB_API_KEY" ]; then
    echo "Error: HONEYCOMB_API_KEY environment variable is required"
    echo "Get your API key from: https://ui.honeycomb.io/account"
    exit 1
fi

# Activate virtual environment
source venv/bin/activate

# Set Honeycomb configuration
export OTEL_EXPORTER_OTLP_ENDPOINT="https://api.honeycomb.io:443"
export OTEL_EXPORTER_OTLP_HEADERS="x-honeycomb-team=$HONEYCOMB_API_KEY"
export OTEL_SERVICE_NAME="sample-app-direct"
export OTEL_SERVICE_VERSION="1.0.0"
export OTEL_SERVICE_INSTANCE_ID="local-test"

echo "🍯 Sending telemetry directly to Honeycomb"
echo "📡 Endpoint: $OTEL_EXPORTER_OTLP_ENDPOINT"
echo "🏷️  Service: $OTEL_SERVICE_NAME"
echo ""

# Run the app
python app.py
EOF

# Make it executable
chmod +x run-direct.sh
```

Then run with:
```bash
export HONEYCOMB_API_KEY="your_api_key_here"
./run-direct.sh
```

## What You'll See in Honeycomb

### Traces
- **Operation names**: `handle_login`, `handle_search`, `handle_purchase`, etc.
- **Attributes**: `user.id`, `operation.name`, `request.id`, `error.type`
- **Duration**: 0.1-1.5 seconds for requests, 2-5 seconds for background tasks
- **Errors**: ~15% error rate with different error types

### Logs
- **Structured logs** with user context
- **Log levels**: INFO for successful operations, ERROR for failures
- **Fields**: `user_id`, `operation`, `duration`, `status`, `error_type`

### Metrics
**Note**: Honeycomb's direct OTLP endpoint doesn't accept metrics. For metrics, you need:
1. Use the OpenTelemetry Collector (see main README)
2. Or use Honeycomb's metrics API directly
3. Or send metrics to a different destination

## Troubleshooting

### No Data Appearing in Honeycomb

1. **Check API key**: Verify it's correct and has proper permissions
   ```bash
   curl -H "X-Honeycomb-Team: $HONEYCOMB_API_KEY" https://api.honeycomb.io/1/auth
   ```

2. **Check headers**: Ensure the header format is correct
   ```bash
   echo $OTEL_EXPORTER_OTLP_HEADERS
   # Should output: x-honeycomb-team=your_api_key
   ```

3. **Check network**: Test connectivity to Honeycomb
   ```bash
   curl -v https://api.honeycomb.io:443
   ```

### SSL/TLS Issues

If you see SSL errors, try:
```bash
# Use insecure connection (testing only)
export OTEL_EXPORTER_OTLP_INSECURE=true
```

### Application Errors

1. **Import errors**: Make sure virtual environment is activated and dependencies installed
2. **Permission errors**: Check file permissions in the sample-app directory
3. **Port conflicts**: The app doesn't use any ports, so this shouldn't be an issue

## Cleanup

### Automated Cleanup (Recommended)

Use the provided cleanup script to remove all generated files:

```bash
# Clean up everything (venv, generated scripts, cache files)
./cleanup.sh
```

This will remove:
- Virtual environment (`venv/`)
- Generated scripts (`run-direct.sh`, `run-direct-test.sh`)
- Python cache files (`__pycache__/`, `*.pyc`)
- Test directories created during testing

### Manual Cleanup

If you prefer to clean up manually:

```bash
# Deactivate virtual environment (if active)
deactivate

# Remove virtual environment
rm -rf venv

# Remove generated scripts
rm -f run-direct.sh run-direct-test.sh

# Remove Python cache
rm -rf __pycache__
find . -name "*.pyc" -delete
```

### Files Included

The sample-app directory contains these files:

**Core Files (keep these):**
- `app.py` - Sample application
- `requirements.txt` - Dependencies
- `README.md` - This documentation
- `Dockerfile` - Container setup

**Test Scripts (keep these):**
- `test-venv-setup.sh` - Interactive test script
- `test-venv-setup-auto.sh` - Automated test script
- `cleanup.sh` - Cleanup script

**Generated Files (cleaned by scripts):**
- `venv/` - Virtual environment
- `run-direct.sh` - Generated run script
- `run-direct-test.sh` - Generated test script
- `__pycache__/` - Python cache

## Differences from Collector Setup

| Aspect | Collector Setup | Direct Setup |
|--------|----------------|--------------|
| **Endpoint** | `http://collector:4317` | `https://api.honeycomb.io:443` |
| **Headers** | None (collector handles) | `x-honeycomb-team=API_KEY` |
| **Metrics** | ✅ Supported | ❌ Not supported |
| **S3 Archive** | ✅ Available | ❌ Not available |
| **Processing** | ✅ Filtering, batching | ❌ Raw data only |
| **Complexity** | Higher (Docker, config) | Lower (just Python) |

## Next Steps

- **Add custom metrics**: Implement custom metric collection and send to a metrics backend
- **Add more telemetry**: Extend the app with more operations and attributes
- **Production setup**: Use the full collector setup for production workloads
- **Custom datasets**: Configure different Honeycomb datasets for different services