# Structured Logging & Analysis Commands

Best-practice logging guidance to recommend, and command recipes for mining logs. Read this when recommending logging improvements or running statistics.

## Essential Fields for Every Log Entry

| Field | Purpose | Example |
|-------|---------|---------|
| `timestamp` | When (ISO 8601 + timezone) | `2024-01-12T12:00:00.123Z` |
| `level` | Severity | `error`, `warn`, `info`, `debug` |
| `message` | Human-readable description | `Failed to process order` |
| `service` | Which service | `order-service` |
| `request_id` | Request correlation | `req_abc123` |
| `trace_id` | Distributed trace | `4bf92f3577b34da6` |
| `user_id` | Who triggered it | `user_42` |
| `duration_ms` | How long | `150` |
| `error.type` | Exception class | `ConnectionError` |
| `error.stack` | Stack trace | (full trace) |

## Log Level Guidelines

| Level | When to use | Example |
|-------|-------------|---------|
| `FATAL` | System cannot continue | `Database unavailable, shutting down` |
| `ERROR` | Operation failed, needs attention | `Failed to charge payment: card declined` |
| `WARN` | Unexpected but handled | `Retry 2/3 for external API call` |
| `INFO` | Normal operations, key events | `Order #123 created successfully` |
| `DEBUG` | Detailed diagnostic info | `Cache miss for key user:42:profile` |
| `TRACE` | Very detailed, high volume | `Entering processItem with args...` |

## Structured Logging Examples

**Node.js (pino/winston):**
```javascript
logger.error({
  msg: 'Failed to process order',
  orderId: '123', userId: 'user_42',
  requestId: req.headers['x-request-id'],
  error: { type: err.name, message: err.message, stack: err.stack },
  durationMs: Date.now() - startTime
});
```

**Python (structlog):**
```python
logger.error(
    "Failed to process order",
    order_id="123", user_id="user_42",
    request_id=request.headers.get("x-request-id"),
    error_type=type(exc).__name__,
    duration_ms=time.time() - start_time,
    exc_info=True,
)
```

**Go (slog/zerolog):**
```go
slog.Error("Failed to process order",
    "orderId", "123", "userId", "user_42",
    "requestId", r.Header.Get("X-Request-ID"),
    "error", err.Error(),
    "durationMs", time.Since(start).Milliseconds(),
)
```

## Correlation ID Propagation

```
Client -> API Gateway -> Service A -> Service B -> Database
          [generates]    [passes]     [passes]     [logs]
          req_abc123     req_abc123   req_abc123   req_abc123
```

Every service should: extract the correlation ID from incoming headers, include it in every log line, pass it to downstream calls, and return it in response headers for client-side debugging.

## Analysis Commands

### Statistics

```bash
# Error count by hour
grep -i error <logfile> | cut -d'T' -f1-2 | cut -d':' -f1 | sort | uniq -c

# Top 10 error signatures (strip UUIDs so like errors group)
grep -i error <logfile> | sed 's/[0-9a-f\-]\{36\}//g' | sort | uniq -c | sort -rn | head -10

# Error rate (% of all lines)
echo "scale=2; $(grep -c -i error <logfile>) * 100 / $(wc -l < <logfile>)" | bc

# Unique error types in JSON logs
grep '"level":"error"' <logfile> | jq -r '.error.type // .msg' | sort | uniq -c | sort -rn
```

### Performance extraction

```bash
# Slow requests (> 1000ms) from JSON logs
grep '"level":"info"' <logfile> | jq 'select(.durationMs > 1000) | {ts: .timestamp, path: .path, ms: .durationMs}'

# P50/P95/P99 from duration logs
grep -o 'duration_ms=[0-9]*' <logfile> | cut -d= -f2 | sort -n | awk '
  { a[NR] = $1; sum += $1 }
  END { print "p50:", a[int(NR*0.5)], "p95:", a[int(NR*0.95)], "p99:", a[int(NR*0.99)], "avg:", sum/NR }'
```
