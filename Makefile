# Simple OpenTelemetry Collector Demo Makefile
# Convenient commands for the simplified telemetry stack

.PHONY: help setup start stop restart status logs validate clean build

# Default target
.DEFAULT_GOAL := help

# Variables
DOCKER_COMPOSE := docker-compose
ENV_FILE := .env

## Show this help message
help:
	@echo "Simple OpenTelemetry Collector Demo"
	@echo ""
	@echo "Available commands:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "Quick Start:"
	@echo "  1. Copy .env.example to .env and update with your API keys"
	@echo "  2. Run 'make setup' to start everything"
	@echo "  3. Check 'make status' for service health"

## Complete setup and start the stack
setup: check-env build start validate
	@echo "✅ Setup complete!"
	@echo ""
	@$(MAKE) status

## Build Docker images
build:
	@echo "🔨 Building images..."
	$(DOCKER_COMPOSE) build

## Start the stack
start: check-env
	@echo "🚀 Starting services..."
	$(DOCKER_COMPOSE) up -d
	@echo "⏳ Waiting for services to start..."
	@sleep 5

## Stop the stack
stop:
	@echo "🛑 Stopping services..."
	$(DOCKER_COMPOSE) down

## Restart the stack
restart:
	@echo "🔄 Restarting services..."
	$(DOCKER_COMPOSE) restart
	@sleep 3
	@$(MAKE) status

## Show service status
status:
	@echo "📊 Service Status:"
	@$(DOCKER_COMPOSE) ps
	@echo ""
	@echo "📋 Useful Info:"
	@echo "  Collector Health:  http://localhost:8888/"
	@echo "  Collector Metrics: http://localhost:8888/metrics"
	@echo "  OTLP gRPC:         localhost:4317"
	@echo "  OTLP HTTP:         localhost:4318"
	@echo ""
	@echo "📝 Commands:"
	@echo "  make logs          # View all logs"
	@echo "  make validate      # Check telemetry flow"

## Show logs from all services
logs:
	$(DOCKER_COMPOSE) logs -f

## Show collector logs only  
logs-collector:
	$(DOCKER_COMPOSE) logs -f collector

## Show sample app logs only
logs-apps:
	$(DOCKER_COMPOSE) logs -f sample-app

## Validate the setup
validate:
	@echo "🔍 Validating setup..."
	@echo -n "  Collector health: "
	@if curl -sf http://localhost:8888/ >/dev/null 2>&1; then \
		echo "✅ OK"; \
	else \
		echo "❌ Failed"; \
	fi
	@echo -n "  Telemetry data: "
	@if curl -s http://localhost:8888/metrics 2>/dev/null | grep -q "otelcol_receiver"; then \
		echo "✅ Receiving data"; \
	else \
		echo "⚠️  No data yet (may need time)"; \
	fi

## Clean up everything
clean:
	@echo "🧹 Cleaning up..."
	@read -p "Remove all containers and data? [y/N] " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		$(DOCKER_COMPOSE) down -v --remove-orphans; \
		docker system prune -f; \
		echo "✅ Cleanup complete"; \
	else \
		echo "❌ Cleanup cancelled"; \
	fi

## Test telemetry generation (send sample data)
test:
	@echo "🧪 Testing telemetry..."
	@echo "Check your Honeycomb and S3 for data in ~30 seconds"

## Show collector metrics
metrics:
	@echo "📊 Recent Collector Metrics:"
	@curl -s http://localhost:8888/metrics 2>/dev/null | grep -E "otelcol_(receiver|exporter).*total" | tail -10

## Check environment
check-env:
	@if [ ! -f $(ENV_FILE) ]; then \
		echo "❌ .env file missing. Please copy .env.example and update it:"; \
		echo "   cp .env.example .env"; \
		echo "   nano .env"; \
		exit 1; \
	fi

## Development: rebuild and restart with logs
dev: build restart logs