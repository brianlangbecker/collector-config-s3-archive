#!/bin/bash

# OTLP HTTP Test Script
# Sends sample metrics, logs, and traces to OpenTelemetry Collector
# Usage: ./test-otlp.sh [collector-host:port]

set -e

# Configuration
COLLECTOR_ENDPOINT="${1:-localhost:4318}"
OTLP_BASE_URL="http://${COLLECTOR_ENDPOINT}/v1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to send OTLP data
send_otlp() {
    local signal_type="$1"
    local payload="$2"
    local endpoint="${OTLP_BASE_URL}/${signal_type}"
    
    print_status "Sending ${signal_type} to ${endpoint}..."
    
    local response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$endpoint")
    
    local http_status=$(echo "$response" | tail -n1 | cut -d: -f2)
    local response_body=$(echo "$response" | sed '$d')
    
    if [ "$http_status" -eq 200 ] || [ "$http_status" -eq 202 ]; then
        print_success "${signal_type} sent successfully (HTTP $http_status)"
    else
        print_error "${signal_type} failed (HTTP $http_status)"
        if [ -n "$response_body" ]; then
            echo "Response: $response_body"
        fi
        return 1
    fi
}

echo "🧪 OTLP HTTP Test Script"
echo "========================"
echo "Collector endpoint: ${COLLECTOR_ENDPOINT}"
echo "Testing OTLP HTTP endpoints..."
echo

# Test 1: Send Metrics
print_status "Test 1: Sending sample metrics..."
METRICS_PAYLOAD='{
  "resourceMetrics": [
    {
      "resource": {
        "attributes": [
          {
            "key": "service.name",
            "value": {
              "stringValue": "test-curl-service"
            }
          },
          {
            "key": "service.version",
            "value": {
              "stringValue": "1.0.0"
            }
          }
        ]
      },
      "scopeMetrics": [
        {
          "scope": {
            "name": "curl-test-metrics",
            "version": "1.0.0"
          },
          "metrics": [
            {
              "name": "test_counter",
              "description": "A test counter metric",
              "unit": "1",
              "sum": {
                "dataPoints": [
                  {
                    "attributes": [
                      {
                        "key": "method",
                        "value": {
                          "stringValue": "GET"
                        }
                      }
                    ],
                    "timeUnixNano": "'$(($(date +%s) * 1000000000))'",
                    "asInt": "42"
                  }
                ],
                "aggregationTemporality": 2,
                "isMonotonic": true
              }
            },
            {
              "name": "test_gauge",
              "description": "A test gauge metric",
              "unit": "ms",
              "gauge": {
                "dataPoints": [
                  {
                    "attributes": [
                      {
                        "key": "status",
                        "value": {
                          "stringValue": "ok"
                        }
                      }
                    ],
                    "timeUnixNano": "'$(($(date +%s) * 1000000000))'",
                    "asDouble": 123.45
                  }
                ]
              }
            }
          ]
        }
      ]
    }
  ]
}'

send_otlp "metrics" "$METRICS_PAYLOAD"
echo

# Test 2: Send Logs
print_status "Test 2: Sending sample logs..."
LOGS_PAYLOAD='{
  "resourceLogs": [
    {
      "resource": {
        "attributes": [
          {
            "key": "service.name",
            "value": {
              "stringValue": "test-curl-service"
            }
          }
        ]
      },
      "scopeLogs": [
        {
          "scope": {
            "name": "curl-test-logs"
          },
          "logRecords": [
            {
              "timeUnixNano": "'$(($(date +%s) * 1000000000))'",
              "severityNumber": 9,
              "severityText": "INFO",
              "body": {
                "stringValue": "This is a test log message from curl"
              },
              "attributes": [
                {
                  "key": "log.level",
                  "value": {
                    "stringValue": "info"
                  }
                },
                {
                  "key": "user.id",
                  "value": {
                    "stringValue": "test-user"
                  }
                },
                {
                  "key": "request.id",
                  "value": {
                    "stringValue": "req-123"
                  }
                }
              ]
            },
            {
              "timeUnixNano": "'$(($(date +%s) * 1000000000))'",
              "severityNumber": 17,
              "severityText": "ERROR",
              "body": {
                "stringValue": "This is a test error log from curl"
              },
              "attributes": [
                {
                  "key": "log.level",
                  "value": {
                    "stringValue": "error"
                  }
                },
                {
                  "key": "error.type",
                  "value": {
                    "stringValue": "TestError"
                  }
                }
              ]
            }
          ]
        }
      ]
    }
  ]
}'

send_otlp "logs" "$LOGS_PAYLOAD"
echo

# Test 3: Send Traces
print_status "Test 3: Sending sample traces..."
TRACE_ID=$(openssl rand -hex 16)
SPAN_ID=$(openssl rand -hex 8)
PARENT_SPAN_ID=$(openssl rand -hex 8)

TRACES_PAYLOAD='{
  "resourceSpans": [
    {
      "resource": {
        "attributes": [
          {
            "key": "service.name",
            "value": {
              "stringValue": "test-curl-service"
            }
          },
          {
            "key": "service.version",
            "value": {
              "stringValue": "1.0.0"
            }
          }
        ]
      },
      "scopeSpans": [
        {
          "scope": {
            "name": "curl-test-traces",
            "version": "1.0.0"
          },
          "spans": [
            {
              "traceId": "'$TRACE_ID'",
              "spanId": "'$SPAN_ID'",
              "parentSpanId": "'$PARENT_SPAN_ID'",
              "name": "test-operation",
              "kind": 1,
              "startTimeUnixNano": "'$(($(date +%s) * 1000000000 - 1000000000))'",
              "endTimeUnixNano": "'$(($(date +%s) * 1000000000))'",
              "attributes": [
                {
                  "key": "http.method",
                  "value": {
                    "stringValue": "GET"
                  }
                },
                {
                  "key": "http.url",
                  "value": {
                    "stringValue": "https://api.example.com/test"
                  }
                },
                {
                  "key": "http.status_code",
                  "value": {
                    "intValue": "200"
                  }
                },
                {
                  "key": "user.id",
                  "value": {
                    "stringValue": "test-user"
                  }
                }
              ],
              "status": {
                "code": 1,
                "message": "OK"
              }
            },
            {
              "traceId": "'$TRACE_ID'",
              "spanId": "'$PARENT_SPAN_ID'",
              "name": "parent-operation",
              "kind": 2,
              "startTimeUnixNano": "'$(($(date +%s) * 1000000000 - 2000000000))'",
              "endTimeUnixNano": "'$(($(date +%s) * 1000000000))'",
              "attributes": [
                {
                  "key": "operation.name",
                  "value": {
                    "stringValue": "test-workflow"
                  }
                }
              ],
              "status": {
                "code": 1,
                "message": "OK"
              }
            }
          ]
        }
      ]
    }
  ]
}'

send_otlp "traces" "$TRACES_PAYLOAD"
echo

print_success "🎉 All OTLP tests completed!"
echo
print_status "Summary:"
print_status "- ✅ Metrics: Counter and gauge sent"
print_status "- ✅ Logs: Info and error logs sent"
print_status "- ✅ Traces: Parent-child span relationship sent"
echo
print_status "Check your collector logs and Honeycomb dashboard for the data!"
print_status "Collector health: http://${COLLECTOR_ENDPOINT%:*}:8888/"
echo