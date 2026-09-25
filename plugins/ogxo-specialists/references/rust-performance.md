# Rust Performance Optimization

Deep-dive reference for profiling and optimizing Rust applications.

## Profiling Tools

### cargo flamegraph

```bash
# Install
cargo install flamegraph

# Generate flame graph (Linux - uses perf)
cargo flamegraph --bin myapp

# On macOS (uses dtrace)
sudo cargo flamegraph --bin myapp

# With release optimizations
cargo flamegraph --release --bin myapp
```

### perf (Linux)

```bash
# Build with debug symbols
cargo build --release
# In Cargo.toml: [profile.release] debug = true

# Record
perf record -g target/release/myapp

# Analyze
perf report
perf annotate

# Generate flame graph
perf script | stackcollapse-perf.pl | flamegraph.pl > flame.svg
```

### Instruments (macOS)

```bash
# Build with debug symbols
cargo build --release

# Run with Instruments
xcrun xctrace record --template "Time Profiler" --launch target/release/myapp
```

### criterion for Benchmarking

```toml
# Cargo.toml
[dev-dependencies]
criterion = "0.5"

[[bench]]
name = "my_benchmark"
harness = false
```

```rust
// benches/my_benchmark.rs
use criterion::{black_box, criterion_group, criterion_main, Criterion};

fn fibonacci(n: u64) -> u64 {
    match n {
        0 => 1,
        1 => 1,
        n => fibonacci(n - 1) + fibonacci(n - 2),
    }
}

fn criterion_benchmark(c: &mut Criterion) {
    c.bench_function("fib 20", |b| b.iter(|| fibonacci(black_box(20))));
}

criterion_group!(benches, criterion_benchmark);
criterion_main!(benches);
```

```bash
# Run benchmarks
cargo bench

# Compare with baseline
cargo bench -- --save-baseline before
# Make changes
cargo bench -- --baseline before
```

### Miri for Undefined Behavior

```bash
# Install
rustup +nightly component add miri

# Run
cargo +nightly miri run
cargo +nightly miri test
```

## Memory Optimization

### Stack vs Heap

```rust
// Stack allocated - fast
let array: [i32; 100] = [0; 100];

// Heap allocated - flexible size
let vector: Vec<i32> = vec![0; 100];

// Box for single heap allocation
let boxed: Box<LargeStruct> = Box::new(LargeStruct::default());
```

### Avoid Unnecessary Clones

```rust
// Bad: Unnecessary clone
fn process(data: &String) {
    let owned = data.clone();  // Allocation!
    do_something(owned);
}

// Good: Borrow when possible
fn process(data: &str) {
    do_something(data);
}

// Good: Take ownership if you need it
fn process(data: String) {
    do_something(data);
}

// Use Cow for conditional ownership
use std::borrow::Cow;

fn process(data: Cow<str>) {
    if needs_modification() {
        let owned = data.into_owned();
        // Modify owned
    } else {
        // Use borrowed data directly
    }
}
```

### SmallVec for Small Collections

```toml
[dependencies]
smallvec = "1.11"
```

```rust
use smallvec::SmallVec;

// Stack allocated for up to 8 elements
let mut vec: SmallVec<[i32; 8]> = SmallVec::new();
vec.push(1);  // Still on stack

// Spills to heap if exceeded
for i in 0..100 {
    vec.push(i);  // Heap after 8 elements
}
```

### String Optimization

```rust
// Use &str instead of String when possible
fn greet(name: &str) {
    println!("Hello, {name}!");
}

// Avoid format! for simple concatenation
// Bad
let s = format!("{}{}", a, b);

// Good
let s = [a, b].concat();

// Or use String::with_capacity
let mut s = String::with_capacity(a.len() + b.len());
s.push_str(a);
s.push_str(b);
```

### Rc/Arc Usage

```rust
use std::rc::Rc;
use std::sync::Arc;

// Rc for single-threaded sharing
let data = Rc::new(expensive_data());
let clone1 = Rc::clone(&data);  // Cheap reference count increment
let clone2 = Rc::clone(&data);

// Arc for multi-threaded sharing
let data = Arc::new(expensive_data());
let clone = Arc::clone(&data);
std::thread::spawn(move || {
    // Use clone in thread
});
```

## Iterator Optimization

### Lazy Evaluation

```rust
// Iterators are lazy - no intermediate collections
let sum: i32 = (0..1000000)
    .filter(|x| x % 2 == 0)
    .map(|x| x * 2)
    .sum();

// Collect only when needed
let evens: Vec<i32> = (0..1000)
    .filter(|x| x % 2 == 0)
    .collect();
```

### Avoid Collect When Possible

```rust
// Bad: Unnecessary collect
let doubled: Vec<i32> = numbers.iter()
    .map(|x| x * 2)
    .collect();
let sum: i32 = doubled.iter().sum();

// Good: Chain without collecting
let sum: i32 = numbers.iter()
    .map(|x| x * 2)
    .sum();
```

### Use for_each for Side Effects

```rust
// for_each can be faster than for loop
items.iter()
    .filter(|x| x.is_valid())
    .for_each(|x| process(x));
```

### Parallel Iterators with Rayon

```toml
[dependencies]
rayon = "1.8"
```

```rust
use rayon::prelude::*;

// Parallel iteration
let sum: i32 = data.par_iter()
    .map(|x| expensive_computation(x))
    .sum();

// Parallel sort
let mut data = vec![3, 1, 4, 1, 5, 9];
data.par_sort();

// Control parallelism
rayon::ThreadPoolBuilder::new()
    .num_threads(4)
    .build_global()
    .unwrap();
```

## Concurrency Optimization

### Channels

```rust
use std::sync::mpsc;

// Unbounded channel
let (tx, rx) = mpsc::channel();

// Bounded channel (backpressure)
let (tx, rx) = mpsc::sync_channel(100);

// Crossbeam for better performance
use crossbeam_channel::{bounded, unbounded};
let (tx, rx) = bounded(100);
```

### Lock-Free Data Structures

```rust
use crossbeam::queue::ArrayQueue;
use crossbeam::deque::{Worker, Stealer};

// Lock-free queue
let queue = ArrayQueue::new(100);
queue.push(1).unwrap();
let item = queue.pop();

// Work-stealing deque
let worker = Worker::new_fifo();
let stealer = worker.stealer();
worker.push(task);
```

### Atomics

```rust
use std::sync::atomic::{AtomicUsize, Ordering};

static COUNTER: AtomicUsize = AtomicUsize::new(0);

fn increment() {
    COUNTER.fetch_add(1, Ordering::Relaxed);
}

fn get() -> usize {
    COUNTER.load(Ordering::Relaxed)
}

// Ordering guide:
// Relaxed - no ordering guarantees, fastest
// Acquire/Release - synchronize with paired operation
// SeqCst - full sequential consistency, slowest
```

### RwLock vs Mutex

```rust
use std::sync::{Mutex, RwLock};

// Mutex - exclusive access
let data = Mutex::new(vec![1, 2, 3]);
{
    let mut guard = data.lock().unwrap();
    guard.push(4);
}

// RwLock - multiple readers OR one writer
let data = RwLock::new(vec![1, 2, 3]);

// Multiple readers can access simultaneously
{
    let guard = data.read().unwrap();
    println!("{:?}", *guard);
}

// Writer gets exclusive access
{
    let mut guard = data.write().unwrap();
    guard.push(4);
}
```

### parking_lot for Faster Locks

```toml
[dependencies]
parking_lot = "0.12"
```

```rust
use parking_lot::{Mutex, RwLock};

// Same API, better performance
let data = Mutex::new(0);
*data.lock() += 1;

// No poisoning, smaller size, faster
```

## SIMD Optimization

### Portable SIMD (Nightly)

```rust
#![feature(portable_simd)]
use std::simd::*;

fn sum_simd(data: &[f32]) -> f32 {
    let chunks = data.chunks_exact(4);
    let remainder = chunks.remainder();

    let mut sum = f32x4::splat(0.0);
    for chunk in chunks {
        let v = f32x4::from_slice(chunk);
        sum += v;
    }

    sum.reduce_sum() + remainder.iter().sum::<f32>()
}
```

### Using packed_simd

```toml
[dependencies]
wide = "0.7"
```

```rust
use wide::*;

fn dot_product(a: &[f32], b: &[f32]) -> f32 {
    let mut sum = f32x4::ZERO;

    for (chunk_a, chunk_b) in a.chunks_exact(4).zip(b.chunks_exact(4)) {
        let va = f32x4::from(chunk_a);
        let vb = f32x4::from(chunk_b);
        sum += va * vb;
    }

    sum.reduce_add()
}
```

## Compile-Time Optimization

### const fn

```rust
// Compute at compile time
const fn factorial(n: u64) -> u64 {
    match n {
        0 | 1 => 1,
        _ => n * factorial(n - 1),
    }
}

const FACT_10: u64 = factorial(10);  // Computed at compile time
```

### Inline Hints

```rust
// Suggest inlining
#[inline]
fn small_function() -> i32 {
    42
}

// Force inlining
#[inline(always)]
fn critical_path() -> i32 {
    expensive_calculation()
}

// Prevent inlining
#[inline(never)]
fn cold_path() {
    // Rarely called code
}
```

### Link-Time Optimization

```toml
# Cargo.toml
[profile.release]
lto = true           # Full LTO
# lto = "thin"       # Faster compile, slightly less optimization
codegen-units = 1    # Better optimization, slower compile
```

## Build Optimization

### Release Profile

```toml
# Cargo.toml
[profile.release]
opt-level = 3        # Maximum optimization
lto = true           # Link-time optimization
codegen-units = 1    # Single codegen unit
panic = "abort"      # Smaller binary, no unwinding
strip = true         # Strip symbols

# For benchmarks
[profile.bench]
debug = true         # Debug symbols for profiling
```

### Target-Specific Optimization

```bash
# Build for native CPU
RUSTFLAGS="-C target-cpu=native" cargo build --release

# Check available CPU features
rustc --print target-features
```

### Profile-Guided Optimization

```bash
# Build with instrumentation
RUSTFLAGS="-Cprofile-generate=/tmp/pgo-data" cargo build --release

# Run workload to generate profile data
./target/release/myapp

# Merge profile data
llvm-profdata merge -o /tmp/pgo-data/merged.profdata /tmp/pgo-data

# Build with profile data
RUSTFLAGS="-Cprofile-use=/tmp/pgo-data/merged.profdata" cargo build --release
```

## Common Optimizations

### Avoid Bounds Checks

```rust
// Bad: Bounds check on each access
fn sum(slice: &[i32]) -> i32 {
    let mut total = 0;
    for i in 0..slice.len() {
        total += slice[i];  // Bounds check
    }
    total
}

// Good: Iterator eliminates bounds checks
fn sum(slice: &[i32]) -> i32 {
    slice.iter().sum()
}

// Or use get_unchecked (unsafe)
fn sum_unchecked(slice: &[i32]) -> i32 {
    let mut total = 0;
    for i in 0..slice.len() {
        // SAFETY: i is always in bounds
        total += unsafe { *slice.get_unchecked(i) };
    }
    total
}
```

### Pre-compute Hash Keys

```rust
use std::collections::HashMap;
use std::hash::{BuildHasher, Hash, Hasher};

// Compute hash once, use multiple times
fn lookup_multiple<K, V, S>(map: &HashMap<K, V, S>, key: &K) -> Option<&V>
where
    K: Hash + Eq,
    S: BuildHasher,
{
    let mut hasher = map.hasher().build_hasher();
    key.hash(&mut hasher);
    let hash = hasher.finish();

    // Use raw entry API with precomputed hash
    map.raw_entry().from_key_hashed_nocheck(hash, key).map(|(_, v)| v)
}
```

### Use Entry API for Maps

```rust
use std::collections::HashMap;

// Bad: Double lookup
if !map.contains_key(&key) {
    map.insert(key, compute_value());
}

// Good: Single lookup
map.entry(key).or_insert_with(|| compute_value());

// With modification
map.entry(key)
    .and_modify(|v| *v += 1)
    .or_insert(1);
```

### Batch Processing

```rust
// Bad: Process one at a time
for item in items {
    process(item);
    flush_to_disk();  // I/O on each item
}

// Good: Batch processing
for chunk in items.chunks(100) {
    for item in chunk {
        process(item);
    }
    flush_to_disk();  // I/O per batch
}
```

## Async Optimization

### tokio Runtime Configuration

```rust
#[tokio::main(flavor = "multi_thread", worker_threads = 4)]
async fn main() {
    // Application code
}

// Or build manually
let runtime = tokio::runtime::Builder::new_multi_thread()
    .worker_threads(4)
    .enable_all()
    .build()
    .unwrap();
```

### Avoid Blocking in Async

```rust
// Bad: Blocking in async context
async fn process() {
    std::thread::sleep(Duration::from_secs(1));  // Blocks worker!
}

// Good: Use async sleep
async fn process() {
    tokio::time::sleep(Duration::from_secs(1)).await;
}

// Good: Spawn blocking for CPU-intensive work
async fn process() {
    let result = tokio::task::spawn_blocking(|| {
        expensive_computation()
    }).await.unwrap();
}
```

### Connection Pooling

```rust
use bb8::{Pool, ManageConnection};
use bb8_postgres::PostgresConnectionManager;

let manager = PostgresConnectionManager::new(config, NoTls);
let pool = Pool::builder()
    .max_size(15)
    .build(manager)
    .await?;

// Get connection from pool
let conn = pool.get().await?;
```

## Monitoring

### tracing for Instrumentation

```rust
use tracing::{info, instrument, span, Level};

#[instrument]
fn process_item(id: u64) {
    info!("Processing item");
    // Function automatically creates span
}

// Manual spans
fn complex_operation() {
    let span = span!(Level::INFO, "complex_op");
    let _guard = span.enter();

    // Work here is traced
}
```

### metrics Crate

```rust
use metrics::{counter, gauge, histogram};

fn handle_request() {
    counter!("requests_total").increment(1);

    let start = Instant::now();
    // Process request
    histogram!("request_duration_seconds").record(start.elapsed().as_secs_f64());
}
```
