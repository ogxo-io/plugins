# Go Performance Optimization

Deep-dive reference for profiling and optimizing Go applications.

## Profiling Tools

### pprof (Built-in)

```go
import (
    "net/http"
    _ "net/http/pprof"
)

func main() {
    // Enable pprof endpoints
    go func() {
        http.ListenAndServe("localhost:6060", nil)
    }()

    // Your application code
}
```

```bash
# CPU profile
go tool pprof http://localhost:6060/debug/pprof/profile?seconds=30

# Memory profile
go tool pprof http://localhost:6060/debug/pprof/heap

# Goroutine profile
go tool pprof http://localhost:6060/debug/pprof/goroutine

# Block profile (blocking operations)
go tool pprof http://localhost:6060/debug/pprof/block

# Mutex profile
go tool pprof http://localhost:6060/debug/pprof/mutex
```

### pprof Commands

```bash
# Interactive mode
go tool pprof cpu.prof

# Common commands:
# top       - Show top functions by CPU/memory
# top20     - Show top 20
# list fn   - Show source code for function
# web       - Open graph in browser
# png       - Generate PNG graph

# Generate flame graph
go tool pprof -http=:8080 cpu.prof
```

### Benchmarking

```go
// benchmark_test.go
func BenchmarkFunction(b *testing.B) {
    for i := 0; i < b.N; i++ {
        myFunction()
    }
}

// With setup
func BenchmarkWithSetup(b *testing.B) {
    data := setupData()
    b.ResetTimer()

    for i := 0; i < b.N; i++ {
        processData(data)
    }
}

// Memory allocation tracking
func BenchmarkAllocations(b *testing.B) {
    b.ReportAllocs()
    for i := 0; i < b.N; i++ {
        myFunction()
    }
}

// Sub-benchmarks
func BenchmarkSizes(b *testing.B) {
    sizes := []int{10, 100, 1000, 10000}
    for _, size := range sizes {
        b.Run(fmt.Sprintf("size_%d", size), func(b *testing.B) {
            for i := 0; i < b.N; i++ {
                processSize(size)
            }
        })
    }
}
```

```bash
# Run benchmarks
go test -bench=. -benchmem

# Compare benchmarks
go install golang.org/x/perf/cmd/benchstat@latest
go test -bench=. -count=10 > old.txt
# Make changes
go test -bench=. -count=10 > new.txt
benchstat old.txt new.txt
```

### Escape Analysis

```bash
# See what escapes to heap
go build -gcflags="-m" ./...
go build -gcflags="-m -m" ./...  # More verbose
```

```go
// Escapes to heap - allocated on heap
func escape() *int {
    x := 42
    return &x  // x escapes because returned
}

// Stays on stack - no allocation
func noEscape() int {
    x := 42
    return x
}
```

### Trace Tool

```go
import "runtime/trace"

func main() {
    f, _ := os.Create("trace.out")
    defer f.Close()

    trace.Start(f)
    defer trace.Stop()

    // Your code
}
```

```bash
go tool trace trace.out
# Opens web UI showing goroutine execution
```

## Memory Optimization

### Reduce Allocations

```go
// Bad: Allocates on each call
func join(strs []string) string {
    result := ""
    for _, s := range strs {
        result += s  // New allocation each iteration
    }
    return result
}

// Good: Use strings.Builder
func join(strs []string) string {
    var builder strings.Builder
    for _, s := range strs {
        builder.WriteString(s)
    }
    return builder.String()
}

// Even better: Preallocate capacity
func join(strs []string) string {
    total := 0
    for _, s := range strs {
        total += len(s)
    }

    var builder strings.Builder
    builder.Grow(total)
    for _, s := range strs {
        builder.WriteString(s)
    }
    return builder.String()
}
```

### Slice Preallocation

```go
// Bad: Slice grows multiple times
func collect(n int) []int {
    var result []int
    for i := 0; i < n; i++ {
        result = append(result, i)  // May reallocate
    }
    return result
}

// Good: Preallocate capacity
func collect(n int) []int {
    result := make([]int, 0, n)
    for i := 0; i < n; i++ {
        result = append(result, i)  // No reallocation
    }
    return result
}

// Or use exact size
func collect(n int) []int {
    result := make([]int, n)
    for i := 0; i < n; i++ {
        result[i] = i
    }
    return result
}
```

### sync.Pool for Object Reuse

```go
var bufferPool = sync.Pool{
    New: func() interface{} {
        return new(bytes.Buffer)
    },
}

func processRequest() {
    buf := bufferPool.Get().(*bytes.Buffer)
    defer func() {
        buf.Reset()
        bufferPool.Put(buf)
    }()

    // Use buffer
    buf.WriteString("data")
}
```

### Avoid Pointers for Small Structs

```go
// Bad: Pointer for small struct causes heap allocation
type Point struct {
    X, Y float64
}

func createPoints(n int) []*Point {
    points := make([]*Point, n)
    for i := 0; i < n; i++ {
        points[i] = &Point{X: float64(i), Y: float64(i)}  // Heap allocation
    }
    return points
}

// Good: Value types stay on stack/inline
func createPoints(n int) []Point {
    points := make([]Point, n)
    for i := 0; i < n; i++ {
        points[i] = Point{X: float64(i), Y: float64(i)}  // No heap allocation
    }
    return points
}
```

### String/Byte Conversion

```go
import "unsafe"

// Zero-copy string to bytes (read-only!)
func stringToBytes(s string) []byte {
    return unsafe.Slice(unsafe.StringData(s), len(s))
}

// Zero-copy bytes to string
func bytesToString(b []byte) string {
    return unsafe.String(unsafe.SliceData(b), len(b))
}

// Note: Only use when you're sure the data won't be modified
```

## Concurrency Optimization

### Worker Pool Pattern

```go
func workerPool(jobs <-chan Job, results chan<- Result, workers int) {
    var wg sync.WaitGroup

    for i := 0; i < workers; i++ {
        wg.Add(1)
        go func() {
            defer wg.Done()
            for job := range jobs {
                results <- process(job)
            }
        }()
    }

    wg.Wait()
    close(results)
}

// Usage
jobs := make(chan Job, 100)
results := make(chan Result, 100)

go workerPool(jobs, results, runtime.NumCPU())

// Send jobs
for _, job := range allJobs {
    jobs <- job
}
close(jobs)

// Collect results
for result := range results {
    // Handle result
}
```

### errgroup for Concurrent Tasks

```go
import "golang.org/x/sync/errgroup"

func fetchAll(urls []string) ([]Response, error) {
    g, ctx := errgroup.WithContext(context.Background())
    responses := make([]Response, len(urls))

    for i, url := range urls {
        i, url := i, url  // Capture loop variables
        g.Go(func() error {
            resp, err := fetch(ctx, url)
            if err != nil {
                return err
            }
            responses[i] = resp
            return nil
        })
    }

    if err := g.Wait(); err != nil {
        return nil, err
    }
    return responses, nil
}
```

### Channel Buffer Sizing

```go
// Unbuffered - blocks until receiver ready
ch := make(chan int)

// Buffered - blocks when buffer full
ch := make(chan int, 100)

// Guidelines:
// - Use unbuffered for synchronization
// - Buffer size = expected burst size
// - Monitor channel length in production

// Check buffer utilization
if len(ch) > cap(ch)*80/100 {
    // Channel is getting full, may indicate backpressure
    log.Warn("channel buffer >80% full")
}
```

### Reduce Lock Contention

```go
// Bad: Single lock for all operations
type Cache struct {
    mu    sync.RWMutex
    items map[string]Item
}

// Good: Sharded locks
type ShardedCache struct {
    shards [256]struct {
        mu    sync.RWMutex
        items map[string]Item
    }
}

func (c *ShardedCache) getShard(key string) *struct {
    mu    sync.RWMutex
    items map[string]Item
} {
    hash := fnv.New32a()
    hash.Write([]byte(key))
    return &c.shards[hash.Sum32()%256]
}

func (c *ShardedCache) Get(key string) (Item, bool) {
    shard := c.getShard(key)
    shard.mu.RLock()
    defer shard.mu.RUnlock()
    item, ok := shard.items[key]
    return item, ok
}
```

### atomic Operations

```go
import "sync/atomic"

// Bad: Lock for simple counter
type Counter struct {
    mu    sync.Mutex
    value int64
}

func (c *Counter) Inc() {
    c.mu.Lock()
    c.value++
    c.mu.Unlock()
}

// Good: Atomic operation
type Counter struct {
    value atomic.Int64
}

func (c *Counter) Inc() {
    c.value.Add(1)
}

func (c *Counter) Value() int64 {
    return c.value.Load()
}
```

## HTTP Performance

### Connection Pooling

```go
// Default client has connection pooling
client := &http.Client{
    Transport: &http.Transport{
        MaxIdleConns:        100,
        MaxIdleConnsPerHost: 100,
        IdleConnTimeout:     90 * time.Second,
    },
    Timeout: 30 * time.Second,
}

// Reuse the client across requests
resp, err := client.Get(url)
if err != nil {
    return err
}
defer resp.Body.Close()

// IMPORTANT: Always read and close body to reuse connection
io.Copy(io.Discard, resp.Body)
```

### Response Body Handling

```go
// Bad: Body not fully read - connection can't be reused
resp, _ := http.Get(url)
data := make([]byte, 100)
resp.Body.Read(data)  // Partial read
resp.Body.Close()

// Good: Read full body
resp, _ := http.Get(url)
defer resp.Body.Close()
body, _ := io.ReadAll(resp.Body)

// Good: Discard body if not needed
resp, _ := http.Get(url)
defer resp.Body.Close()
io.Copy(io.Discard, resp.Body)
```

### JSON Optimization

```go
import "github.com/json-iterator/go"

var json = jsoniter.ConfigCompatibleWithStandardLibrary

// Or for maximum performance
var json = jsoniter.ConfigFastest

// Use streaming for large JSON
func processLargeJSON(r io.Reader) error {
    decoder := json.NewDecoder(r)

    for decoder.More() {
        var item Item
        if err := decoder.Decode(&item); err != nil {
            return err
        }
        process(item)
    }
    return nil
}
```

## Database Optimization

### Connection Pooling

```go
db, err := sql.Open("postgres", connStr)
if err != nil {
    return err
}

// Configure pool
db.SetMaxOpenConns(25)
db.SetMaxIdleConns(25)
db.SetConnMaxLifetime(5 * time.Minute)
db.SetConnMaxIdleTime(5 * time.Minute)
```

### Prepared Statements

```go
// Prepare once, reuse many times
stmt, err := db.Prepare("SELECT * FROM users WHERE id = $1")
if err != nil {
    return err
}
defer stmt.Close()

// Execute multiple times
for _, id := range userIDs {
    row := stmt.QueryRow(id)
    // Process row
}
```

### Batch Operations

```go
// Bad: Individual inserts
for _, user := range users {
    _, err := db.Exec("INSERT INTO users (name) VALUES ($1)", user.Name)
}

// Good: Batch insert
valueStrings := make([]string, 0, len(users))
valueArgs := make([]interface{}, 0, len(users))

for i, user := range users {
    valueStrings = append(valueStrings, fmt.Sprintf("($%d)", i+1))
    valueArgs = append(valueArgs, user.Name)
}

stmt := fmt.Sprintf("INSERT INTO users (name) VALUES %s", strings.Join(valueStrings, ","))
_, err := db.Exec(stmt, valueArgs...)
```

## Compiler Optimizations

### Inlining

```go
// Small functions are automatically inlined
// Check with: go build -gcflags="-m"

// Hint to inline (Go 1.21+)
//go:noinline  // Prevent inlining
func noInline() {}
```

### Bounds Check Elimination

```go
// Bad: Bounds check on each access
func sum(s []int) int {
    total := 0
    for i := 0; i < len(s); i++ {
        total += s[i]  // Bounds check
    }
    return total
}

// Good: Range eliminates bounds checks
func sum(s []int) int {
    total := 0
    for _, v := range s {
        total += v  // No bounds check
    }
    return total
}

// Or prove bounds once
func sum(s []int) int {
    total := 0
    _ = s[len(s)-1]  // Prove bounds once
    for i := 0; i < len(s); i++ {
        total += s[i]  // No bounds check
    }
    return total
}
```

## Common Optimizations

### Map Preallocation

```go
// Bad: Map grows multiple times
m := make(map[string]int)
for _, item := range items {
    m[item.Key] = item.Value
}

// Good: Preallocate
m := make(map[string]int, len(items))
for _, item := range items {
    m[item.Key] = item.Value
}
```

### Avoid defer in Hot Loops

```go
// Bad: defer overhead in loop
func processFiles(files []string) error {
    for _, file := range files {
        f, err := os.Open(file)
        if err != nil {
            return err
        }
        defer f.Close()  // Defers accumulate
        process(f)
    }
    return nil
}

// Good: Extract to function or close explicitly
func processFiles(files []string) error {
    for _, file := range files {
        if err := processFile(file); err != nil {
            return err
        }
    }
    return nil
}

func processFile(file string) error {
    f, err := os.Open(file)
    if err != nil {
        return err
    }
    defer f.Close()  // Only one defer
    return process(f)
}
```

### Interface Assertions

```go
// Type switch is optimized
switch v := x.(type) {
case int:
    // Handle int
case string:
    // Handle string
}

// Single type assertion - use comma-ok
if s, ok := x.(string); ok {
    // Use s
}
```

## Monitoring

### Runtime Metrics

```go
import "runtime"

func printStats() {
    var m runtime.MemStats
    runtime.ReadMemStats(&m)

    fmt.Printf("Alloc = %v MiB\n", m.Alloc/1024/1024)
    fmt.Printf("TotalAlloc = %v MiB\n", m.TotalAlloc/1024/1024)
    fmt.Printf("Sys = %v MiB\n", m.Sys/1024/1024)
    fmt.Printf("NumGC = %v\n", m.NumGC)
    fmt.Printf("Goroutines = %v\n", runtime.NumGoroutine())
}
```

### expvar for Metrics

```go
import "expvar"

var (
    requests = expvar.NewInt("requests")
    errors   = expvar.NewInt("errors")
)

func handler(w http.ResponseWriter, r *http.Request) {
    requests.Add(1)
    // ...
}

// Metrics available at /debug/vars
```
