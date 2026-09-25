# Python Performance Optimization

Deep-dive reference for profiling and optimizing Python applications.

## Profiling Tools

### cProfile (Built-in)

```bash
# Run profiler from command line
python -m cProfile -s cumulative app.py
python -m cProfile -o profile.stats app.py

# Analyze results
python -m pstats profile.stats
```

```python
import cProfile
import pstats
from io import StringIO

def profile_function(func):
    """Decorator to profile a function"""
    def wrapper(*args, **kwargs):
        profiler = cProfile.Profile()
        profiler.enable()
        result = func(*args, **kwargs)
        profiler.disable()

        stream = StringIO()
        stats = pstats.Stats(profiler, stream=stream)
        stats.sort_stats('cumulative')
        stats.print_stats(20)
        print(stream.getvalue())

        return result
    return wrapper

@profile_function
def my_function():
    # Code to profile
    pass
```

### py-spy (Sampling Profiler)

```bash
# Install
pip install py-spy

# Profile running process
py-spy top --pid 12345

# Generate flame graph
py-spy record -o profile.svg -- python app.py

# Dump current stack traces
py-spy dump --pid 12345
```

### line_profiler

```bash
pip install line_profiler
```

```python
# Add @profile decorator to functions
@profile
def slow_function():
    result = []
    for i in range(10000):
        result.append(i ** 2)
    return result

# Run with kernprof
# kernprof -l -v script.py
```

### memory_profiler

```bash
pip install memory_profiler
```

```python
from memory_profiler import profile

@profile
def memory_intensive():
    large_list = [i ** 2 for i in range(1000000)]
    return sum(large_list)

# Run: python -m memory_profiler script.py
```

### scalene (CPU + Memory + GPU)

```bash
pip install scalene

# Profile with detailed output
scalene script.py

# Profile specific function
scalene --cpu --memory --gpu script.py
```

## Data Structure Optimization

### Lists vs Generators

```python
# Bad: Creates entire list in memory
def get_squares_list(n):
    return [x ** 2 for x in range(n)]

# Good: Generates values on demand
def get_squares_gen(n):
    return (x ** 2 for x in range(n))

# Memory comparison for n=10_000_000
# List: ~400 MB
# Generator: ~120 bytes
```

### collections Module

```python
from collections import deque, defaultdict, Counter, namedtuple

# deque - O(1) append/pop from both ends
queue = deque(maxlen=1000)
queue.append(item)      # O(1)
queue.appendleft(item)  # O(1)
queue.pop()             # O(1)
queue.popleft()         # O(1)

# defaultdict - no KeyError checks
word_count = defaultdict(int)
for word in words:
    word_count[word] += 1  # No if/else needed

# Counter - optimized counting
word_count = Counter(words)
top_10 = word_count.most_common(10)

# namedtuple - memory-efficient records
Point = namedtuple('Point', ['x', 'y', 'z'])
p = Point(1, 2, 3)  # Smaller than dict, immutable
```

### __slots__ for Memory Efficiency

```python
# Regular class - uses __dict__
class PointRegular:
    def __init__(self, x, y, z):
        self.x = x
        self.y = y
        self.z = z
# Memory per instance: ~300 bytes

# With __slots__ - no __dict__
class PointSlots:
    __slots__ = ['x', 'y', 'z']

    def __init__(self, x, y, z):
        self.x = x
        self.y = y
        self.z = z
# Memory per instance: ~64 bytes
```

### NumPy for Numeric Operations

```python
import numpy as np

# Bad: Pure Python loop
def sum_squares_python(n):
    total = 0
    for i in range(n):
        total += i ** 2
    return total
# 1M iterations: ~150ms

# Good: NumPy vectorized
def sum_squares_numpy(n):
    arr = np.arange(n)
    return np.sum(arr ** 2)
# 1M iterations: ~5ms (30x faster)

# Vectorized operations
arr = np.array([1, 2, 3, 4, 5])
arr * 2           # Vectorized multiply
np.sqrt(arr)      # Vectorized sqrt
arr[arr > 2]      # Boolean indexing
```

## String Optimization

### String Joining

```python
# Bad: String concatenation in loop
def concat_bad(strings):
    result = ""
    for s in strings:
        result += s  # O(n²) - creates new string each time
    return result

# Good: join()
def concat_good(strings):
    return "".join(strings)  # O(n)

# With separator
", ".join(strings)
```

### f-strings vs format() vs %

```python
import timeit

name = "Alice"
age = 30

# f-strings (fastest)
f"Name: {name}, Age: {age}"

# .format()
"Name: {}, Age: {}".format(name, age)

# % formatting (slowest)
"Name: %s, Age: %d" % (name, age)

# f-strings are typically 20-30% faster
```

### String Interning

```python
import sys

# Python automatically interns small strings
a = "hello"
b = "hello"
a is b  # True - same object

# Manually intern strings for memory savings
large_string = sys.intern("frequently_used_string")
```

## Function Optimization

### Local Variable Access

```python
# Bad: Global lookup in loop
import math

def calculate_bad(values):
    return [math.sqrt(v) for v in values]

# Good: Local reference
def calculate_good(values):
    sqrt = math.sqrt  # Local lookup is faster
    return [sqrt(v) for v in values]
# ~15% faster for large loops
```

### functools.lru_cache

```python
from functools import lru_cache

@lru_cache(maxsize=128)
def fibonacci(n):
    if n < 2:
        return n
    return fibonacci(n - 1) + fibonacci(n - 2)

# Without cache: O(2^n)
# With cache: O(n)

# Check cache stats
fibonacci.cache_info()
# CacheInfo(hits=28, misses=31, maxsize=128, currsize=31)

# Clear cache if needed
fibonacci.cache_clear()
```

### Avoid Repeated Attribute Access

```python
# Bad: Multiple attribute lookups
def process_bad(obj):
    for i in range(1000):
        obj.data.items.append(i)  # 3 lookups per iteration

# Good: Cache the reference
def process_good(obj):
    items = obj.data.items
    append = items.append
    for i in range(1000):
        append(i)  # Direct call
```

## Async Optimization

### asyncio Patterns

```python
import asyncio
import aiohttp

# Bad: Sequential async calls
async def fetch_sequential(urls):
    results = []
    async with aiohttp.ClientSession() as session:
        for url in urls:
            async with session.get(url) as response:
                results.append(await response.text())
    return results

# Good: Concurrent async calls
async def fetch_concurrent(urls):
    async with aiohttp.ClientSession() as session:
        tasks = [fetch_one(session, url) for url in urls]
        return await asyncio.gather(*tasks)

async def fetch_one(session, url):
    async with session.get(url) as response:
        return await response.text()
```

### Semaphore for Rate Limiting

```python
import asyncio

async def fetch_with_limit(urls, max_concurrent=10):
    semaphore = asyncio.Semaphore(max_concurrent)

    async def fetch_one(url):
        async with semaphore:
            async with aiohttp.ClientSession() as session:
                async with session.get(url) as response:
                    return await response.text()

    tasks = [fetch_one(url) for url in urls]
    return await asyncio.gather(*tasks)
```

### Connection Pooling

```python
import aiohttp

# Reuse session for connection pooling
async def main():
    connector = aiohttp.TCPConnector(
        limit=100,           # Total connection limit
        limit_per_host=30,   # Per-host limit
        keepalive_timeout=30,
    )

    async with aiohttp.ClientSession(connector=connector) as session:
        # All requests share the connection pool
        tasks = [fetch(session, url) for url in urls]
        results = await asyncio.gather(*tasks)
```

## Multiprocessing

### Process Pool for CPU-bound Tasks

```python
from multiprocessing import Pool, cpu_count
from concurrent.futures import ProcessPoolExecutor

# Using Pool
def process_item(item):
    return expensive_computation(item)

with Pool(processes=cpu_count()) as pool:
    results = pool.map(process_item, items)

# Using ProcessPoolExecutor
with ProcessPoolExecutor(max_workers=cpu_count()) as executor:
    results = list(executor.map(process_item, items))
```

### Shared Memory for Large Data

```python
from multiprocessing import shared_memory
import numpy as np

# Create shared memory
data = np.array([1, 2, 3, 4, 5], dtype=np.float64)
shm = shared_memory.SharedMemory(create=True, size=data.nbytes)
shared_array = np.ndarray(data.shape, dtype=data.dtype, buffer=shm.buf)
shared_array[:] = data[:]

# In worker process
existing_shm = shared_memory.SharedMemory(name=shm.name)
shared_array = np.ndarray(data.shape, dtype=data.dtype, buffer=existing_shm.buf)

# Cleanup
shm.close()
shm.unlink()
```

## Cython for Performance-Critical Code

```python
# example.pyx
cimport cython
from libc.math cimport sqrt

@cython.boundscheck(False)
@cython.wraparound(False)
def fast_distance(double[:] x, double[:] y):
    cdef int i, n = x.shape[0]
    cdef double total = 0.0

    for i in range(n):
        total += (x[i] - y[i]) ** 2

    return sqrt(total)
```

```python
# setup.py
from setuptools import setup
from Cython.Build import cythonize

setup(
    ext_modules=cythonize("example.pyx")
)
```

## Benchmarking

### timeit Module

```python
import timeit

# Command line
# python -m timeit "'-'.join(str(n) for n in range(100))"

# In code
setup = "data = list(range(1000))"
stmt = "sum(data)"
time = timeit.timeit(stmt, setup, number=10000)
print(f"{time:.4f} seconds")

# Compare implementations
def benchmark(funcs, args, number=1000):
    for func in funcs:
        time = timeit.timeit(lambda: func(*args), number=number)
        print(f"{func.__name__}: {time:.4f}s")
```

### pytest-benchmark

```bash
pip install pytest-benchmark
```

```python
# test_performance.py
def test_my_function(benchmark):
    result = benchmark(my_function, arg1, arg2)
    assert result == expected

# Run with
# pytest test_performance.py --benchmark-only
```

## Common Optimizations

### Dictionary Comprehensions

```python
# Bad: Loop with assignment
result = {}
for key, value in items:
    result[key] = transform(value)

# Good: Dictionary comprehension
result = {key: transform(value) for key, value in items}
```

### Set Operations

```python
# Bad: Nested loops for intersection
common = []
for item in list1:
    if item in list2:  # O(n) lookup
        common.append(item)
# O(n * m)

# Good: Set intersection
common = set(list1) & set(list2)
# O(n + m)

# Set membership is O(1)
lookup_set = set(large_list)
if item in lookup_set:  # O(1) vs O(n) for list
    pass
```

### Early Returns and Short-Circuit

```python
# Bad: Nested conditions
def validate(data):
    if data:
        if data.get('required_field'):
            if len(data['items']) > 0:
                return True
    return False

# Good: Early returns
def validate(data):
    if not data:
        return False
    if not data.get('required_field'):
        return False
    if len(data.get('items', [])) == 0:
        return False
    return True

# Short-circuit evaluation
if expensive_check_1() and expensive_check_2():
    # expensive_check_2 only runs if expensive_check_1 is True
    pass
```

### Avoid Creating Unnecessary Objects

```python
# Bad: Creates tuple on each iteration
for i in range(1000):
    if i in (1, 2, 3):  # New tuple each time
        pass

# Good: Create once outside loop
SPECIAL_VALUES = (1, 2, 3)
for i in range(1000):
    if i in SPECIAL_VALUES:
        pass
```

## Monitoring in Production

### Memory Tracking

```python
import tracemalloc

tracemalloc.start()

# Your code here

snapshot = tracemalloc.take_snapshot()
top_stats = snapshot.statistics('lineno')

print("Top 10 memory allocations:")
for stat in top_stats[:10]:
    print(stat)
```

### APM Integration

```python
# Datadog
from ddtrace import tracer

@tracer.wrap()
def my_function():
    pass

# New Relic
import newrelic.agent
newrelic.agent.initialize('newrelic.ini')

# OpenTelemetry
from opentelemetry import trace
tracer = trace.get_tracer(__name__)

with tracer.start_as_current_span("my_operation"):
    pass
```
