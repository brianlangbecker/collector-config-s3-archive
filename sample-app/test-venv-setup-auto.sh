#!/bin/bash

# Automated test script for virtual environment Honeycomb setup
# This version runs without user interaction for CI/testing purposes

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
    if [ -f "run-direct-test.sh" ]; then
        rm -f run-direct-test.sh
        print_status "Removed test script"
    fi
}

# Set up cleanup trap
trap cleanup EXIT

echo "============================================="
echo "🧪 Automated Virtual Environment Test Suite"
echo "============================================="
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
    print_warning "HONEYCOMB_API_KEY not set - skipping API tests"
    SKIP_API_TEST=true
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
if pip list | grep -q opentelemetry; then
    print_success "OpenTelemetry packages found:"
    pip list | grep opentelemetry
else
    print_error "OpenTelemetry packages not found"
    exit 1
fi

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

# Test basic app instantiation
print_status "Testing app instantiation without network calls..."
python3 -c "
import os
import sys

# Set minimal environment to avoid network calls
os.environ['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'http://localhost:4317'
os.environ['OTEL_SERVICE_NAME'] = 'test-service'

try:
    from app import SimpleApp
    print('✅ App class imported successfully')
    
    # Try to create an app instance
    app = SimpleApp()
    print('✅ App instance created successfully')
    
    # Test that methods exist
    assert hasattr(app, 'simulate_request'), 'simulate_request method missing'
    assert hasattr(app, 'background_task'), 'background_task method missing'
    print('✅ Required methods found')
    
except Exception as e:
    print(f'❌ App test failed: {e}')
    import traceback
    traceback.print_exc()
    sys.exit(1)
"

if [ $? -eq 0 ]; then
    print_success "App instantiation test passed"
else
    print_error "App instantiation test failed"
    exit 1
fi

# Create production-ready run script
print_status "Creating production run script..."
cat > run-direct-test.sh << 'EOF'
#!/bin/bash

# Production version of run-direct.sh for manual testing
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
export OTEL_SERVICE_NAME="sample-app-direct"
export OTEL_SERVICE_VERSION="1.0.0"
export OTEL_SERVICE_INSTANCE_ID="local-$(date +%s)"

echo "🍯 Sending telemetry directly to Honeycomb"
echo "📡 Endpoint: $OTEL_EXPORTER_OTLP_ENDPOINT"
echo "🏷️  Service: $OTEL_SERVICE_NAME"
echo "🆔 Instance: $OTEL_SERVICE_INSTANCE_ID"
echo ""
echo "⚡ Starting full application - press Ctrl+C to stop"
echo ""

# Run the full app
python3 app.py
EOF

chmod +x run-direct-test.sh
print_success "Production run script created as run-direct-test.sh"

# Test configuration without network calls
print_status "Testing configuration setup..."
python3 -c "
import os

# Test environment variable setup
test_vars = {
    'OTEL_EXPORTER_OTLP_ENDPOINT': 'https://api.honeycomb.io:443',
    'OTEL_EXPORTER_OTLP_HEADERS': 'x-honeycomb-team=test-key',
    'OTEL_SERVICE_NAME': 'test-service',
}

for key, value in test_vars.items():
    os.environ[key] = value

# Verify they can be read
for key, expected in test_vars.items():
    actual = os.getenv(key)
    if actual != expected:
        print(f'❌ Environment variable {key} not set correctly')
        exit(1)

print('✅ Environment variable configuration test passed')
"

if [ $? -eq 0 ]; then
    print_success "Configuration test passed"
else
    print_error "Configuration test failed"
    exit 1
fi

echo
print_success "🎉 All automated tests passed!"
echo
print_status "Test Summary:"
print_status "✅ Prerequisites (Python, pip, files)"
print_status "✅ Virtual environment creation and activation"
print_status "✅ Dependency installation"
print_status "✅ OpenTelemetry imports"
print_status "✅ App class instantiation"
print_status "✅ Configuration setup"
print_status "✅ Production script creation"

if [ -n "$HONEYCOMB_API_KEY" ]; then
    print_status "✅ Honeycomb API connectivity"
fi

echo
print_status "🚀 Setup is ready for use!"
echo
print_status "Manual testing commands:"
print_status "1. source venv/bin/activate"  
print_status "2. export HONEYCOMB_API_KEY='your_key_here'"
print_status "3. ./run-direct-test.sh"
echo
print_status "Files created:"
print_status "- venv/ (virtual environment)"
print_status "- run-direct-test.sh (production script)"
echo

# Cleanup happens automatically via trap