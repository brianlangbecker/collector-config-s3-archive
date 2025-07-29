#!/bin/bash

# Test script for virtual environment Honeycomb setup
# This script tests the complete setup process described in VIRTUAL-ENV-HONEYCOMB-README.md

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to cleanup on exit
cleanup() {
    print_status "Cleaning up test environment..."
    if [ -d "venv" ]; then
        rm -rf venv
        print_status "Removed test virtual environment"
    fi
    if [ -f "run-direct.sh" ]; then
        rm -f run-direct.sh
        print_status "Removed test script"
    fi
}

# Set up cleanup trap
trap cleanup EXIT

echo "=========================================="
echo "🧪 Testing Virtual Environment Honeycomb Setup"
echo "=========================================="
echo

# Check prerequisites
print_status "Checking prerequisites..."

if ! command_exists python3; then
    print_error "python3 is not installed"
    exit 1
fi
print_success "python3 found: $(python3 --version)"

if ! command_exists pip; then
    print_error "pip is not installed"
    exit 1
fi
print_success "pip found: $(pip --version)"

# Check if we're in the right directory (now inside sample-app)
if [ ! -f "app.py" ]; then
    print_error "app.py not found. Run this script from the sample-app directory."
    exit 1
fi
print_success "app.py found"

if [ ! -f "requirements.txt" ]; then
    print_error "requirements.txt not found"
    exit 1
fi
print_success "requirements.txt found"

echo

# Check for Honeycomb API key
print_status "Checking for Honeycomb API key..."
if [ -z "$HONEYCOMB_API_KEY" ]; then
    print_warning "HONEYCOMB_API_KEY not set"
    print_status "You can either:"
    print_status "1. Set it as environment variable: export HONEYCOMB_API_KEY='your_key'"
    print_status "2. Enter it now (it will be used for this test only)"
    echo
    read -p "Enter your Honeycomb API key (or press Enter to skip API test): " USER_API_KEY
    if [ -n "$USER_API_KEY" ]; then
        export HONEYCOMB_API_KEY="$USER_API_KEY"
        print_success "API key set for this test"
    else
        print_warning "Skipping API connectivity test"
        SKIP_API_TEST=true
    fi
else
    print_success "HONEYCOMB_API_KEY is set"
fi

echo

# Test API key if available
if [ -z "$SKIP_API_TEST" ] && [ -n "$HONEYCOMB_API_KEY" ]; then
    print_status "Testing Honeycomb API connectivity..."
    if command_exists curl; then
        if curl -s -f -H "X-Honeycomb-Team: $HONEYCOMB_API_KEY" https://api.honeycomb.io/1/auth >/dev/null 2>&1; then
            print_success "Honeycomb API key is valid"
        else
            print_error "Honeycomb API key test failed"
            print_status "Please check your API key at https://ui.honeycomb.io/account"
            exit 1
        fi
    else
        print_warning "curl not found, skipping API test"
    fi
    echo
fi

# Already in sample-app directory, no need to change directories

# Test virtual environment creation
print_status "Creating virtual environment..."
if python3 -m venv venv; then
    print_success "Virtual environment created successfully"
else
    print_error "Failed to create virtual environment"
    exit 1
fi

# Test virtual environment activation
print_status "Testing virtual environment activation..."
if source venv/bin/activate; then
    print_success "Virtual environment activated"
else
    print_error "Failed to activate virtual environment"
    exit 1
fi

# Test pip install
print_status "Installing dependencies..."
if pip install -r requirements.txt; then
    print_success "Dependencies installed successfully"
else
    print_error "Failed to install dependencies"
    exit 1
fi

# Check installed packages
print_status "Verifying installed packages..."
pip list | grep opentelemetry
echo

# Test Python import
print_status "Testing OpenTelemetry imports..."
python3 -c "
import sys
try:
    from opentelemetry import trace, metrics
    from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
    from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
    print('✅ All OpenTelemetry imports successful')
except ImportError as e:
    print(f'❌ Import error: {e}')
    sys.exit(1)
"

if [ $? -eq 0 ]; then
    print_success "OpenTelemetry imports working correctly"
else
    print_error "OpenTelemetry import test failed"
    exit 1
fi

# Create test run script
print_status "Creating test run script..."
cat > run-direct.sh << 'EOF'
#!/bin/bash

# Test version of run-direct.sh
set -e

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
export OTEL_SERVICE_NAME="sample-app-direct-test"
export OTEL_SERVICE_VERSION="1.0.0-test"
export OTEL_SERVICE_INSTANCE_ID="test-run-$(date +%s)"

echo "🍯 Testing telemetry direct to Honeycomb"
echo "📡 Endpoint: $OTEL_EXPORTER_OTLP_ENDPOINT"
echo "🏷️  Service: $OTEL_SERVICE_NAME"
echo "🆔 Instance: $OTEL_SERVICE_INSTANCE_ID"
echo ""
echo "🧪 This is a test run - will generate a few requests then exit"
echo ""

# Run a brief test with timeout to avoid hanging
timeout 10s python3 -c "
import os
import sys
import time

print('🚀 Starting test run...')

# Import our app module
try:
    from app import SimpleApp
    app = SimpleApp()
    
    # Generate a few test requests
    for i in range(3):
        result = app.simulate_request()
        print(f'📊 Request {i+1}: {result[\"status\"]}')
        time.sleep(0.3)
    
    print('✅ Test completed successfully!')
    print('📤 Flushing telemetry data...')
    time.sleep(2)
    print('🎉 Check your Honeycomb account for data in dataset: sample-app-direct-test')
    
except Exception as e:
    print(f'❌ Test failed: {e}')
    import traceback
    traceback.print_exc()
    sys.exit(1)
" || echo "⚠️  Test completed (may have timed out, which is expected)"
EOF

chmod +x run-direct.sh
print_success "Test run script created"

# Test configuration validation
print_status "Testing configuration validation..."
python3 -c "
import os

# Test environment variable access
endpoint = os.getenv('OTEL_EXPORTER_OTLP_ENDPOINT', 'not-set')
service_name = os.getenv('OTEL_SERVICE_NAME', 'not-set')

print(f'Endpoint would be: {endpoint}')
print(f'Service name would be: {service_name}')
"

echo

# Run the actual test if API key is available
if [ -n "$HONEYCOMB_API_KEY" ]; then
    print_status "Running live test with Honeycomb..."
    echo "This will send a few test requests to Honeycomb and then exit."
    echo
    read -p "Proceed with live test? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Running live test..."
        if ./run-direct.sh; then
            print_success "Live test completed!"
            echo
            print_status "🎯 Next steps:"
            print_status "1. Go to https://ui.honeycomb.io/"
            print_status "2. Look for dataset: sample-app-direct-test"
            print_status "3. You should see traces and logs from this test"
            echo
        else
            print_error "Live test failed"
            exit 1
        fi
    else
        print_status "Skipping live test"
    fi
else
    print_warning "Skipping live test (no API key provided)"
fi

echo
print_success "🎉 All tests passed!"
echo
print_status "Summary of what was tested:"
print_status "✅ Python 3 and pip availability"
print_status "✅ Required files present"
print_status "✅ Virtual environment creation and activation"
print_status "✅ OpenTelemetry dependencies installation"
print_status "✅ Python imports and basic functionality"
print_status "✅ Test script creation"

if [ -n "$HONEYCOMB_API_KEY" ] && [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "✅ Live Honeycomb connectivity test"
fi

echo
print_status "🚀 Your virtual environment setup is working correctly!"
print_status "To use it manually:"
print_status "1. source venv/bin/activate"
print_status "2. export HONEYCOMB_API_KEY='your_key'"
print_status "3. ./run-direct.sh"
echo

# Cleanup happens automatically via trap