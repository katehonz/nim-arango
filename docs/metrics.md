# Observability

Prometheus-compatible metrics, structured logging, and circuit breaker.

## Metrics

The driver provides a lightweight Prometheus-compatible metrics registry with Counter, Gauge, and Histogram types.

### Initialization

```nim
import nim_arango

# Metrics are auto-initialized on first use.
# Optionally, initialize explicitly:
initMetrics()
```

### Creating and Using Metrics

```nim
# Get or create a counter (idempotent)
let requests = getOrCreateCounter("http_requests_total")
requests.inc()              # +1
requests.inc(amount = 5)    # +5

# Get or create a gauge
let activeConnections = getOrCreateGauge("db_connections_active")
activeConnections.set(42.0)
activeConnections.inc(1.0)
activeConnections.dec(2.0)

# Get or create a histogram (with bucket boundaries)
let duration = getOrCreateHistogram(
  "request_duration_seconds",
  buckets = @[0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0],
)
duration.observe(0.047)
```

### Rendering

```nim
echo renderMetrics()
# # TYPE nim_arango_requests_total counter
# nim_arango_requests_total 42
# # TYPE request_duration_seconds histogram
# request_duration_seconds_bucket{le="0.005"} 0
# request_duration_seconds_bucket{le="0.01"} 5
# ...
```

### Baked-in HTTP Transport Metrics

The HTTP transport automatically tracks:

| Metric                        | Type      | Description                          |
|-------------------------------|-----------|--------------------------------------|
| `nim_arango_requests_total`   | Counter   | Total HTTP requests to ArangoDB      |
| `nim_arango_request_duration_seconds` | Histogram | Request latency distribution   |
| `nim_arango_connection_pool_active` | Gauge | Active connections in pool       |
| `nim_arango_request_errors_total` | Counter | Failed requests                 |

### Retry Metrics

| Metric                          | Type    | Description                     |
|---------------------------------|---------|---------------------------------|
| `nim_arango_retries_total`      | Counter | Total retry attempts            |

## Metric Types

```nim
type
  Counter* = ref object
    name*: string
    value*: int64
    labels*: Table[string, string]

  Gauge* = ref object
    name*: string
    value*: float64
    labels*: Table[string, string]

  Histogram* = ref object
    name*: string
    buckets*: seq[float]
    counts*: seq[int64]
    sum*: float64
    labels*: Table[string, string]

  MetricsRegistry* = ref object
    counters*: Table[string, Counter]
    gauges*: Table[string, Gauge]
    histograms*: Table[string, Histogram]
```

## Circuit Breaker

Wraps the transport layer to prevent cascading failures:

```nim
import nim_arango

let innerTransport = newHttpTransport(@["http://localhost:8529"], 30_000, "my-app")
let cbTransport = newCircuitBreakerTransport(
  inner = innerTransport,
  cfg = CircuitBreakerConfig(
    failureThreshold: 5,
    successThreshold: 3,
    timeout: initDuration(seconds = 30),
  ),
)
```

### CircuitBreakerConfig

```nim
type
  CircuitBreakerConfig* = object
    failureThreshold*: int = 5      # failures before opening
    successThreshold*: int = 3      # successes to close (half-open)
    timeout*: Duration = 30.seconds # wait before half-open
```

### States

```nim
type
  CircuitState* = enum
    csClosed     # Normal operation
    csOpen       # Rejecting requests
    csHalfOpen   # Testing recovery
```

## Structured Logging

```nim
# Log requests (auto-called by HTTP transport)
logRequest("GET", "/_api/version", 200, 15, "localhost:8529", retryCount = 0)

# Custom log messages
logInfo("database migration complete")
logDebug("connection pool expanded to 10")
logError("failed to connect to DBServer1")

# Set log level
setLogLevel(lvlDebug)
```

## Public API

```nim
# Metrics lifecycle
proc initMetrics*()

# Metric constructors (direct)
proc newCounter*(name: string, labels: Table[string, string] = ...): Counter
proc newGauge*(name: string, labels: Table[string, string] = ...): Gauge
proc newHistogram*(name: string, buckets: seq[float], labels: Table[string, string] = ...): Histogram

# Counter operations
proc inc*(c: Counter, amount: int64 = 1)

# Gauge operations
proc set*(g: Gauge, value: float64)
proc inc*(g: Gauge, amount: float64 = 1.0)
proc dec*(g: Gauge, amount: float64 = 1.0)

# Histogram operations
proc observe*(h: Histogram, value: float64)

# Registry (auto-initialized on first getOrCreate)
proc getOrCreateCounter*(name: string, labels: Table[string, string] = ...): Counter
proc getOrCreateGauge*(name: string, labels: Table[string, string] = ...): Gauge
proc getOrCreateHistogram*(name: string, buckets: seq[float], labels: Table[string, string] = ...): Histogram

# Rendering
proc renderMetrics*(): string

# Circuit breaker
proc newCircuitBreakerTransport*(inner: Transport, cfg: CircuitBreakerConfig): CircuitBreakerTransport

# Logging
proc initArangoLogger*()
proc logRequest*(verb, path: string, statusCode: int, durationMs: int64, endpoint: string, retryCount: int = 0)
proc logError*(msg: string)
proc logInfo*(msg: string)
proc logDebug*(msg: string)
proc setLogLevel*(level: Level)
```
