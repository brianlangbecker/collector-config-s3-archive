#!/bin/bash
set -euo pipefail

# Simple OpenTelemetry Collector Setup Script
# Simplified version for the basic telemetry stack

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"
EXAMPLE_ENV_FILE="${SCRIPT_DIR}/.env.example"

# Print functions
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

# Check if Docker and Docker Compose are available
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    if ! command -v docker >/dev/null 2>&1; then
        print_error "Docker is required but not installed"
        echo "Install Docker: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    if ! command -v docker-compose >/dev/null 2>&1; then
        print_error "Docker Compose is required but not installed"
        echo "Install Docker Compose: https://docs.docker.com/compose/install/"
        exit 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker daemon is not running"
        exit 1
    fi
    
    print_success "Prerequisites OK"
}

# Setup environment file
setup_environment() {
    print_info "Setting up environment..."
    
    if [ ! -f "$ENV_FILE" ]; then
        if [ -f "$EXAMPLE_ENV_FILE" ]; then
            cp "$EXAMPLE_ENV_FILE" "$ENV_FILE"
            print_success "Created .env file from template"
        else
            print_error ".env.example file not found"
            exit 1
        fi
    fi
    
    # Check required variables
    source "$ENV_FILE" 2>/dev/null || true
    
    local missing_vars=()
    
    if [ -z "${HONEYCOMB_API_KEY:-}" ] || [ "$HONEYCOMB_API_KEY" = "your_honeycomb_api_key_here" ]; then
        missing_vars+=("HONEYCOMB_API_KEY")
    fi
    
    if [ -z "${AWS_ACCESS_KEY_ID:-}" ] || [ "$AWS_ACCESS_KEY_ID" = "your_aws_access_key_id" ]; then
        missing_vars+=("AWS_ACCESS_KEY_ID")
    fi
    
    if [ -z "${AWS_SECRET_ACCESS_KEY:-}" ] || [ "$AWS_SECRET_ACCESS_KEY" = "your_aws_secret_access_key" ]; then
        missing_vars+=("AWS_SECRET_ACCESS_KEY")
    fi
    
    if [ ${#missing_vars[@]} -ne 0 ]; then
        print_error "Please update these variables in .env file:"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        echo ""
        echo "Edit the file: nano $ENV_FILE"
        exit 1
    fi
    
    print_success "Environment configuration OK"
}

# Build and start services
start_stack() {
    print_info "Building and starting services..."
    
    cd "$SCRIPT_DIR"
    
    # Build images
    docker-compose build
    
    # Start services
    docker-compose up -d
    
    print_success "Services started"
    
    # Wait for health check
    print_info "Waiting for services to be ready..."
    sleep 10
    
    # Check collector health
    if curl -sf http://localhost:8888/ >/dev/null 2>&1; then
        print_success "Collector is healthy"
    else
        print_warning "Collector may need more time to start"
    fi
}

# Validate the setup
validate_setup() {
    print_info "Validating setup..."
    
    # Check collector metrics
    if curl -s http://localhost:8888/metrics 2>/dev/null | grep -q "otelcol_receiver"; then
        print_success "Collector is receiving telemetry data"
    else
        print_warning "No telemetry data yet (normal for first few seconds)"
    fi
    
    # Check container status
    local unhealthy=$(docker-compose ps -q --filter "health=unhealthy" | wc -l)
    if [ "$unhealthy" -gt 0 ]; then
        print_warning "Some containers may be unhealthy"
    else
        print_success "All containers running normally"
    fi
}

# Show final status
show_status() {
    echo ""
    print_info "🚀 Setup Complete!"
    echo ""
    echo "Services:"
    docker-compose ps
    echo ""
    echo "📋 Access Points:"
    echo "  Collector Health:  http://localhost:8888/"  
    echo "  Collector Metrics: http://localhost:8888/metrics"
    echo "  OTLP Endpoints:    localhost:4317 (gRPC), localhost:4318 (HTTP)"
    echo ""
    echo "📝 Useful Commands:"
    echo "  make logs          # View logs"
    echo "  make status        # Check status"
    echo "  make stop          # Stop services"
    echo "  make validate      # Validate telemetry"
    echo ""
    print_success "Check Honeycomb and S3 for your telemetry data!"
}

# Main function
main() {
    local command="${1:-setup}"
    
    case "$command" in
        "setup")
            print_info "🚀 Starting OpenTelemetry setup..."
            check_prerequisites
            setup_environment
            start_stack
            validate_setup
            show_status
            ;;
        "start")
            check_prerequisites
            start_stack
            show_status
            ;;
        "stop")
            print_info "Stopping services..."
            docker-compose down
            print_success "Services stopped"
            ;;
        "status")
            docker-compose ps
            ;;
        "logs")
            docker-compose logs -f
            ;;
        "validate")
            validate_setup
            ;;
        "clean")
            print_warning "This will remove all containers and data"
            read -p "Are you sure? (y/N) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                docker-compose down -v --remove-orphans
                docker system prune -f
                print_success "Cleanup complete"
            fi
            ;;
        "help"|"-h"|"--help")
            echo "Simple OpenTelemetry Collector Setup"
            echo ""
            echo "Usage: $0 [COMMAND]"
            echo ""
            echo "Commands:"
            echo "  setup       Setup and start everything (default)"
            echo "  start       Start services"
            echo "  stop        Stop services" 
            echo "  status      Show status"
            echo "  logs        Show logs"
            echo "  validate    Validate setup"
            echo "  clean       Clean up everything"
            echo "  help        Show this help"
            ;;
        *)
            print_error "Unknown command: $command"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"