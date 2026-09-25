# Node.js Performance Optimization

Deep-dive reference for profiling and optimizing Node.js applications.

## Profiling Tools

### Built-in Profiler

```bash
# CPU profiling with V8 profiler
node --prof app.js
# Process the log file
node --prof-process isolate-*.log > profile.txt

# Inspect mode for Chrome DevTools
node --inspect app.js
node --inspect-brk app.js  # Break on first line
```

### Clinic.js Suite

```bash
# Install
npm install -g clinic

# Doctor - overall health check
clinic doctor -- node app.js

# Flame - CPU flame graphs
clinic flame -- node app.js

# Bubbleprof - async operations
clinic bubbleprof -- node app.js

# HeapProfiler - memory analysis
clinic heapprofiler -- node app.js
```

### 0x Flame Graphs

```bash
npm install -g 0x
0x app.js
# Opens flame graph in browser
```

## Event Loop Optimization

### Understanding the Event Loop

```
   ┌───────────────────────────┐
┌─>│           timers          │  setTimeout, setInterval
│  └─────────────┬─────────────┘
│  ┌─────────────┴─────────────┐
│  │     pending callbacks     │  I/O callbacks
│  └─────────────┬─────────────┘
│  ┌─────────────┴─────────────┐
│  │       idle, prepare       │  internal
│  └─────────────┬─────────────┘
│  ┌─────────────┴─────────────┐
│  │           poll            │  retrieve new I/O events
│  └─────────────┬─────────────┘
│  ┌─────────────┴─────────────┐
│  │           check           │  setImmediate
│  └─────────────┬─────────────┘
│  ┌─────────────┴─────────────┐
└──┤      close callbacks      │  socket.on('close')
   └───────────────────────────┘
```

### Event Loop Blocking Detection

```javascript
// Detect long-running synchronous operations
const start = process.hrtime.bigint();

// Your operation here

const end = process.hrtime.bigint();
const duration = Number(end - start) / 1e6; // ms
if (duration > 100) {
  console.warn(`Event loop blocked for ${duration}ms`);
}
```

### Breaking Up CPU-Intensive Work

```javascript
// Before: Blocks event loop
function processLargeArray(items) {
  return items.map(item => expensiveOperation(item));
}

// After: Yields to event loop
async function processLargeArray(items, chunkSize = 100) {
  const results = [];
  for (let i = 0; i < items.length; i += chunkSize) {
    const chunk = items.slice(i, i + chunkSize);
    results.push(...chunk.map(item => expensiveOperation(item)));

    // Yield to event loop
    await new Promise(resolve => setImmediate(resolve));
  }
  return results;
}
```

### Worker Threads for CPU-Intensive Tasks

```javascript
// main.js
const { Worker } = require('worker_threads');

function runWorker(data) {
  return new Promise((resolve, reject) => {
    const worker = new Worker('./worker.js', { workerData: data });
    worker.on('message', resolve);
    worker.on('error', reject);
  });
}

// worker.js
const { parentPort, workerData } = require('worker_threads');

const result = expensiveComputation(workerData);
parentPort.postMessage(result);
```

## Memory Optimization

### Heap Snapshot Analysis

```javascript
// Take heap snapshot programmatically
const v8 = require('v8');
const fs = require('fs');

function takeHeapSnapshot() {
  const snapshotFile = `heap-${Date.now()}.heapsnapshot`;
  const snapshotStream = v8.writeHeapSnapshot(snapshotFile);
  console.log(`Heap snapshot written to ${snapshotFile}`);
}

// Trigger on memory pressure
process.on('warning', (warning) => {
  if (warning.name === 'HeapSizeWarning') {
    takeHeapSnapshot();
  }
});
```

### Memory Leak Detection

```javascript
// Track memory usage over time
const used = process.memoryUsage();
console.log({
  rss: `${Math.round(used.rss / 1024 / 1024)} MB`,      // Resident Set Size
  heapTotal: `${Math.round(used.heapTotal / 1024 / 1024)} MB`,
  heapUsed: `${Math.round(used.heapUsed / 1024 / 1024)} MB`,
  external: `${Math.round(used.external / 1024 / 1024)} MB`,
});

// Common leak patterns to avoid:
// 1. Global variables accumulating data
// 2. Closures holding references
// 3. Event listeners not removed
// 4. Timers not cleared
// 5. Caches without eviction
```

### Efficient Buffer Usage

```javascript
// Before: Creates many small buffers
function processChunks(chunks) {
  let result = Buffer.alloc(0);
  for (const chunk of chunks) {
    result = Buffer.concat([result, chunk]); // O(n²)
  }
  return result;
}

// After: Pre-allocate and copy
function processChunks(chunks) {
  const totalLength = chunks.reduce((sum, c) => sum + c.length, 0);
  const result = Buffer.allocUnsafe(totalLength);
  let offset = 0;
  for (const chunk of chunks) {
    chunk.copy(result, offset);
    offset += chunk.length;
  }
  return result;
}
```

## Stream Processing

### Transform Streams for Large Data

```javascript
const { Transform } = require('stream');
const { pipeline } = require('stream/promises');

class JsonLineTransform extends Transform {
  constructor() {
    super({ objectMode: true });
  }

  _transform(chunk, encoding, callback) {
    try {
      const obj = JSON.parse(chunk);
      const processed = processItem(obj);
      callback(null, JSON.stringify(processed) + '\n');
    } catch (err) {
      callback(err);
    }
  }
}

// Process large file without loading into memory
await pipeline(
  fs.createReadStream('large-file.jsonl'),
  split2(),  // Split by newlines
  new JsonLineTransform(),
  fs.createWriteStream('output.jsonl')
);
```

### Backpressure Handling

```javascript
const writable = fs.createWriteStream('output.txt');

async function writeData(items) {
  for (const item of items) {
    const canContinue = writable.write(item);
    if (!canContinue) {
      // Wait for drain event
      await new Promise(resolve => writable.once('drain', resolve));
    }
  }
}
```

## HTTP Performance

### Keep-Alive Connections

```javascript
const http = require('http');
const https = require('https');

// Reuse connections
const httpAgent = new http.Agent({
  keepAlive: true,
  maxSockets: 100,
  maxFreeSockets: 10,
  timeout: 60000,
});

const httpsAgent = new https.Agent({
  keepAlive: true,
  maxSockets: 100,
});

// Use with fetch or axios
const response = await fetch(url, { agent: httpsAgent });
```

### Response Compression

```javascript
const compression = require('compression');
const express = require('express');

const app = express();

// Enable gzip compression
app.use(compression({
  filter: (req, res) => {
    if (req.headers['x-no-compression']) return false;
    return compression.filter(req, res);
  },
  threshold: 1024, // Only compress responses > 1KB
}));
```

### Connection Pooling with undici

```javascript
const { Pool } = require('undici');

const pool = new Pool('http://api.example.com', {
  connections: 100,
  pipelining: 10,
});

const { statusCode, body } = await pool.request({
  path: '/endpoint',
  method: 'GET',
});
```

## Benchmarking

### autocannon for HTTP Load Testing

```bash
npm install -g autocannon

# Basic load test
autocannon -c 100 -d 30 http://localhost:3000/api

# With specific request
autocannon -c 100 -d 30 -m POST -H "Content-Type: application/json" \
  -b '{"key":"value"}' http://localhost:3000/api
```

### Benchmark.js for Microbenchmarks

```javascript
const Benchmark = require('benchmark');
const suite = new Benchmark.Suite();

suite
  .add('Array.push', function() {
    const arr = [];
    for (let i = 0; i < 1000; i++) arr.push(i);
  })
  .add('Array.from', function() {
    Array.from({ length: 1000 }, (_, i) => i);
  })
  .on('cycle', function(event) {
    console.log(String(event.target));
  })
  .on('complete', function() {
    console.log('Fastest is ' + this.filter('fastest').map('name'));
  })
  .run({ async: true });
```

## Common Optimizations

### Object Pooling

```javascript
class ObjectPool {
  constructor(factory, reset, initialSize = 10) {
    this.factory = factory;
    this.reset = reset;
    this.pool = Array.from({ length: initialSize }, factory);
  }

  acquire() {
    return this.pool.pop() || this.factory();
  }

  release(obj) {
    this.reset(obj);
    this.pool.push(obj);
  }
}

// Usage
const bufferPool = new ObjectPool(
  () => Buffer.allocUnsafe(1024),
  (buf) => buf.fill(0)
);

const buf = bufferPool.acquire();
// Use buffer...
bufferPool.release(buf);
```

### Memoization

```javascript
function memoize(fn, keyResolver = (...args) => JSON.stringify(args)) {
  const cache = new Map();

  return function(...args) {
    const key = keyResolver(...args);
    if (cache.has(key)) return cache.get(key);

    const result = fn.apply(this, args);
    cache.set(key, result);
    return result;
  };
}

// With LRU eviction
const LRU = require('lru-cache');

function memoizeLRU(fn, options = { max: 500 }) {
  const cache = new LRU(options);

  return function(...args) {
    const key = JSON.stringify(args);
    if (cache.has(key)) return cache.get(key);

    const result = fn.apply(this, args);
    cache.set(key, result);
    return result;
  };
}
```

### Lazy Loading

```javascript
// Lazy require - only load when needed
let heavyModule;
function getHeavyModule() {
  if (!heavyModule) {
    heavyModule = require('heavy-module');
  }
  return heavyModule;
}

// ES modules dynamic import
async function loadWhenNeeded() {
  const { heavyFunction } = await import('./heavy-module.js');
  return heavyFunction();
}
```

## V8 Optimization Tips

### Monomorphic Functions

```javascript
// Bad: Polymorphic - different object shapes
function process(obj) {
  return obj.value * 2;
}
process({ value: 1 });           // Shape A
process({ value: 2, extra: 3 }); // Shape B - deoptimizes!

// Good: Consistent object shapes
class DataPoint {
  constructor(value) {
    this.value = value;
  }
}
process(new DataPoint(1));
process(new DataPoint(2));
```

### Avoid Hidden Class Changes

```javascript
// Bad: Properties added in different order
function Point(x, y) {
  this.x = x;
  this.y = y;
}
const p1 = new Point(1, 2);
p1.z = 3;  // Changes hidden class

const p2 = new Point(3, 4);
p2.w = 5;  // Different hidden class!

// Good: Initialize all properties upfront
function Point(x, y, z = 0) {
  this.x = x;
  this.y = y;
  this.z = z;
}
```

### Use TypedArrays for Numeric Data

```javascript
// Regular array - boxed numbers, slow
const regularArray = [1.1, 2.2, 3.3, 4.4];

// TypedArray - unboxed, fast
const typedArray = new Float64Array([1.1, 2.2, 3.3, 4.4]);

// Significant performance difference for numeric operations
function sum(arr) {
  let total = 0;
  for (let i = 0; i < arr.length; i++) {
    total += arr[i];
  }
  return total;
}
```

## Monitoring in Production

### Process Metrics

```javascript
const prometheus = require('prom-client');

// Collect default metrics
prometheus.collectDefaultMetrics();

// Custom metrics
const httpRequestDuration = new prometheus.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status'],
  buckets: [0.1, 0.3, 0.5, 1, 3, 5, 10],
});

// Middleware to track
app.use((req, res, next) => {
  const end = httpRequestDuration.startTimer();
  res.on('finish', () => {
    end({ method: req.method, route: req.route?.path, status: res.statusCode });
  });
  next();
});
```

### APM Integration

```javascript
// New Relic
require('newrelic');

// Datadog
const tracer = require('dd-trace').init();

// OpenTelemetry
const { NodeTracerProvider } = require('@opentelemetry/sdk-trace-node');
const provider = new NodeTracerProvider();
provider.register();
```
