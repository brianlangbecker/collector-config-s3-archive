#!/usr/bin/env python3
"""
Simple OpenTelemetry Sample Application
Generates logs, metrics, and traces using only OpenTelemetry SDK
"""

import os
import time
import random
import logging
from typing import Dict

# OpenTelemetry imports
from opentelemetry import trace, metrics
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry._logs import set_logger_provider
from opentelemetry.exporter.otlp.proto.grpc._log_exporter import OTLPLogExporter
from opentelemetry.sdk._logs import LoggerProvider, LoggingHandler
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.resources import Resource
from opentelemetry.semconv.resource import ResourceAttributes


class SimpleApp:
    """Simple application that generates all three telemetry signals"""
    
    def __init__(self):
        self.setup_telemetry()
        self.create_instruments()
        
        # Sample data for realistic scenarios
        self.users = ["alice", "bob", "charlie", "diana"]
        self.operations = ["login", "search", "purchase", "update"]
        
    def setup_telemetry(self):
        """Configure OpenTelemetry SDK"""
        
        # Get collector endpoint
        endpoint = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://collector:4317")
        
        # Service information
        resource = Resource.create({
            ResourceAttributes.SERVICE_NAME: os.getenv("OTEL_SERVICE_NAME", "sample-app"),
            ResourceAttributes.SERVICE_VERSION: os.getenv("OTEL_SERVICE_VERSION", "1.0.0"),
            ResourceAttributes.SERVICE_INSTANCE_ID: os.getenv("OTEL_SERVICE_INSTANCE_ID", "instance-1"),
        })
        
        # Setup tracing
        trace_exporter = OTLPSpanExporter(endpoint=endpoint, insecure=True)
        trace_provider = TracerProvider(resource=resource)
        trace_provider.add_span_processor(BatchSpanProcessor(trace_exporter))
        trace.set_tracer_provider(trace_provider)
        self.tracer = trace.get_tracer(__name__)
        
        # Setup metrics
        metric_exporter = OTLPMetricExporter(endpoint=endpoint, insecure=True)
        metric_reader = PeriodicExportingMetricReader(exporter=metric_exporter, export_interval_millis=5000)
        metrics_provider = MeterProvider(resource=resource, metric_readers=[metric_reader])
        metrics.set_meter_provider(metrics_provider)
        self.meter = metrics.get_meter(__name__)
        
        # Setup logging with recursion protection
        log_exporter = OTLPLogExporter(endpoint=endpoint, insecure=True)
        logger_provider = LoggerProvider(resource=resource)
        logger_provider.add_log_record_processor(BatchLogRecordProcessor(log_exporter))
        set_logger_provider(logger_provider)
        
        # Configure Python logging with specific logger to avoid recursion
        otel_handler = LoggingHandler(level=logging.INFO, logger_provider=logger_provider)
        
        # Create app-specific logger to avoid OpenTelemetry internal logging recursion
        self.logger = logging.getLogger("sample_app")
        self.logger.setLevel(logging.INFO)
        self.logger.addHandler(otel_handler)
        
        # Prevent propagation to root logger to avoid recursion
        self.logger.propagate = False
        
        # Disable OpenTelemetry internal logging to prevent recursion
        logging.getLogger("opentelemetry").setLevel(logging.ERROR)
        
    def create_instruments(self):
        """Create OpenTelemetry metric instruments"""
        
        # Request counter
        self.request_counter = self.meter.create_counter(
            name="requests_total",
            description="Total requests processed",
            unit="1"
        )
        
        # Request duration
        self.request_duration = self.meter.create_histogram(
            name="request_duration_seconds", 
            description="Request processing time",
            unit="s"
        )
        
        # Active users
        self.active_users = self.meter.create_up_down_counter(
            name="active_users",
            description="Currently active users",
            unit="1"
        )
        
        # Error counter
        self.error_counter = self.meter.create_counter(
            name="errors_total",
            description="Total errors",
            unit="1"
        )
        
    def simulate_request(self) -> Dict:
        """Simulate a user request"""
        
        user = random.choice(self.users)
        operation = random.choice(self.operations)
        
        # Start trace
        with self.tracer.start_as_current_span(f"handle_{operation}") as span:
            
            # Add span attributes
            span.set_attribute("user.id", user)
            span.set_attribute("operation.name", operation)
            span.set_attribute("request.id", f"req_{random.randint(1000, 9999)}")
            
            # Simulate processing time
            duration = random.uniform(0.1, 1.5)
            time.sleep(duration)
            
            # Record metrics
            self.request_counter.add(1, {"operation": operation, "user": user})
            self.request_duration.record(duration, {"operation": operation})
            
            # User activity
            if random.random() < 0.3:  # 30% chance of user change
                change = random.choice([-1, 1])
                self.active_users.add(change, {"operation": operation})
            
            # Log the request (with console output for visibility)
            log_msg = f"Processed {operation} request for {user} in {duration:.2f}s"
            print(f"📊 {log_msg}")
            
            self.logger.info(
                log_msg,
                extra={
                    "user_id": user,
                    "operation": operation,
                    "duration": duration,
                    "status": "success"
                }
            )
            
            # Simulate errors (15% chance)
            if random.random() < 0.15:
                error_type = random.choice(["timeout", "validation_error", "network_error"])
                
                # Mark span as error
                span.set_status(trace.Status(trace.StatusCode.ERROR, f"{error_type} occurred"))
                span.set_attribute("error.type", error_type)
                
                # Record error metric
                self.error_counter.add(1, {"operation": operation, "error_type": error_type})
                
                # Log error (with console output for visibility)
                error_msg = f"Request failed: {error_type} for {user}"
                print(f"❌ {error_msg}")
                
                self.logger.error(
                    error_msg,
                    extra={
                        "user_id": user,
                        "operation": operation,
                        "error_type": error_type,
                        "duration": duration
                    }
                )
                
                return {"status": "error", "error_type": error_type}
            
            return {"status": "success", "duration": duration}
    
    def background_task(self):
        """Simulate a background task"""
        
        task_type = random.choice(["cleanup", "sync", "backup"])
        
        with self.tracer.start_as_current_span(f"background_{task_type}") as span:
            span.set_attribute("task.type", task_type)
            span.set_attribute("task.scheduled", True)
            
            # Background tasks take longer
            duration = random.uniform(2.0, 5.0)
            time.sleep(duration)
            
            # Log completion (with console output for visibility)  
            bg_msg = f"Background task {task_type} completed in {duration:.2f}s"
            print(f"🔄 {bg_msg}")
            
            self.logger.info(
                bg_msg,
                extra={
                    "task_type": task_type,
                    "duration": duration,
                    "scheduled": True
                }
            )
            
            # Record metrics
            self.request_counter.add(1, {"operation": f"background_{task_type}"})
            self.request_duration.record(duration, {"operation": f"background_{task_type}"})
    
    def run(self):
        """Run the simulation"""
        
        print("🚀 Starting Simple OpenTelemetry Demo")
        print(f"📡 Endpoint: {os.getenv('OTEL_EXPORTER_OTLP_ENDPOINT', 'http://collector:4317')}")
        print(f"🏷️  Service: {os.getenv('OTEL_SERVICE_NAME', 'sample-app')}")
        print("📊 Generating traces, metrics, and logs...")
        print("⏹️  Press Ctrl+C to stop\n")
        
        iteration = 0
        
        try:
            while True:
                iteration += 1
                
                # Simulate user requests
                for _ in range(random.randint(2, 5)):
                    self.simulate_request()
                    time.sleep(random.uniform(0.5, 2.0))
                
                # Occasional background task
                if iteration % 15 == 0:
                    self.background_task()
                
                # Status update
                if iteration % 10 == 0:
                    print(f"✅ Iteration {iteration}: Generated ~{iteration * 3} requests and telemetry")
                
                time.sleep(1)
                
        except KeyboardInterrupt:
            print("\n🛑 Stopping application")
            print("📤 Flushing telemetry data...")
            time.sleep(3)
            print("✅ Done")


if __name__ == "__main__":
    app = SimpleApp()
    app.run()