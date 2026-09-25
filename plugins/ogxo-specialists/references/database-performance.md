# Database Performance Optimization

Deep-dive reference for profiling and optimizing database performance, with focus on PostgreSQL.

## Query Analysis

### EXPLAIN ANALYZE

```sql
-- Basic explain
EXPLAIN SELECT * FROM users WHERE email = 'test@example.com';

-- With execution statistics
EXPLAIN ANALYZE SELECT * FROM users WHERE email = 'test@example.com';

-- With buffer statistics
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM users WHERE email = 'test@example.com';

-- Full analysis
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM users WHERE email = 'test@example.com';

-- JSON format for tools
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT * FROM users WHERE email = 'test@example.com';
```

### Reading EXPLAIN Output

```
Seq Scan on users  (cost=0.00..1234.00 rows=1 width=100) (actual time=0.015..12.345 rows=1 loops=1)
  Filter: (email = 'test@example.com')
  Rows Removed by Filter: 99999
  Buffers: shared hit=500 read=100
```

Key metrics:
- **cost**: Estimated startup and total cost
- **rows**: Estimated vs actual rows returned
- **width**: Average row size in bytes
- **actual time**: Real execution time (ms)
- **Buffers**: Pages read from cache (hit) vs disk (read)

### Common Scan Types

| Scan Type | When Used | Performance |
|-----------|-----------|-------------|
| Seq Scan | Full table scan | Slow for large tables |
| Index Scan | Uses index, fetches rows | Good for selective queries |
| Index Only Scan | All data from index | Best - no table access |
| Bitmap Scan | Multiple index conditions | Good for OR conditions |

## Indexing Strategies

### Index Types

```sql
-- B-tree (default) - equality and range queries
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_orders_date ON orders(created_at);

-- Hash - equality only (rarely better than B-tree)
CREATE INDEX idx_users_id_hash ON users USING hash(id);

-- GIN - arrays, JSONB, full-text search
CREATE INDEX idx_products_tags ON products USING gin(tags);
CREATE INDEX idx_docs_content ON documents USING gin(to_tsvector('english', content));

-- GiST - geometric, full-text, range types
CREATE INDEX idx_locations_point ON locations USING gist(coordinates);

-- BRIN - large tables with natural ordering
CREATE INDEX idx_logs_created ON logs USING brin(created_at);
```

### Composite Indexes

```sql
-- Order matters! Left-to-right
CREATE INDEX idx_orders_user_date ON orders(user_id, created_at);

-- Good: Uses index
SELECT * FROM orders WHERE user_id = 1;
SELECT * FROM orders WHERE user_id = 1 AND created_at > '2024-01-01';

-- Bad: Can't use index (missing leading column)
SELECT * FROM orders WHERE created_at > '2024-01-01';
```

### Partial Indexes

```sql
-- Index only active users (smaller, faster)
CREATE INDEX idx_users_active ON users(email) WHERE status = 'active';

-- Index only recent orders
CREATE INDEX idx_orders_recent ON orders(user_id, created_at)
WHERE created_at > '2024-01-01';
```

### Covering Indexes (Index-Only Scans)

```sql
-- Include columns in index to avoid table lookup
CREATE INDEX idx_orders_covering ON orders(user_id) INCLUDE (total, status);

-- Query can be satisfied entirely from index
SELECT total, status FROM orders WHERE user_id = 1;
```

### Expression Indexes

```sql
-- Index on lowercase email
CREATE INDEX idx_users_email_lower ON users(lower(email));

-- Query must use same expression
SELECT * FROM users WHERE lower(email) = 'test@example.com';

-- Index on JSONB path
CREATE INDEX idx_data_name ON items((data->>'name'));
```

## Query Optimization

### N+1 Query Problem

```sql
-- Bad: N+1 queries
SELECT * FROM orders WHERE user_id = 1;
-- Then for each order:
SELECT * FROM order_items WHERE order_id = ?;

-- Good: Single query with JOIN
SELECT o.*, oi.*
FROM orders o
LEFT JOIN order_items oi ON oi.order_id = o.id
WHERE o.user_id = 1;

-- Or use lateral join for complex cases
SELECT o.*, items.*
FROM orders o
CROSS JOIN LATERAL (
    SELECT array_agg(oi.*) as items
    FROM order_items oi
    WHERE oi.order_id = o.id
) items
WHERE o.user_id = 1;
```

### Subquery vs JOIN

```sql
-- Subquery (sometimes slower)
SELECT * FROM orders
WHERE user_id IN (SELECT id FROM users WHERE status = 'active');

-- JOIN (often faster)
SELECT o.* FROM orders o
INNER JOIN users u ON o.user_id = u.id
WHERE u.status = 'active';

-- EXISTS (good for checking existence)
SELECT * FROM orders o
WHERE EXISTS (
    SELECT 1 FROM users u
    WHERE u.id = o.user_id AND u.status = 'active'
);
```

### Pagination

```sql
-- Bad: OFFSET gets slower as pages increase
SELECT * FROM orders ORDER BY created_at DESC LIMIT 20 OFFSET 10000;

-- Good: Keyset pagination (cursor-based)
SELECT * FROM orders
WHERE created_at < '2024-01-15 10:30:00'
ORDER BY created_at DESC
LIMIT 20;

-- With unique tiebreaker
SELECT * FROM orders
WHERE (created_at, id) < ('2024-01-15 10:30:00', 12345)
ORDER BY created_at DESC, id DESC
LIMIT 20;
```

### Aggregate Optimization

```sql
-- Bad: Count with complex query
SELECT COUNT(*) FROM orders WHERE status = 'pending' AND total > 100;

-- Good: Use approximate count for large tables
SELECT reltuples::bigint AS estimate
FROM pg_class WHERE relname = 'orders';

-- Good: Maintain count in separate table
-- Use triggers to keep in sync

-- Window functions instead of self-joins
SELECT id, total,
       SUM(total) OVER (ORDER BY created_at) as running_total,
       AVG(total) OVER (PARTITION BY user_id) as user_avg
FROM orders;
```

### DISTINCT Optimization

```sql
-- Bad: DISTINCT on large result set
SELECT DISTINCT user_id FROM orders;

-- Good: Use EXISTS or GROUP BY
SELECT user_id FROM orders GROUP BY user_id;

-- Better: If you have an index
SELECT DISTINCT ON (user_id) user_id, created_at
FROM orders
ORDER BY user_id, created_at DESC;
```

## Connection Pooling

### PgBouncer Configuration

```ini
; pgbouncer.ini
[databases]
mydb = host=localhost dbname=mydb

[pgbouncer]
listen_port = 6432
listen_addr = 127.0.0.1
auth_type = md5
auth_file = /etc/pgbouncer/userlist.txt

; Pool settings
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 25
min_pool_size = 5
reserve_pool_size = 5
reserve_pool_timeout = 3
```

Pool modes:
- **session**: Connection per session (like direct connection)
- **transaction**: Connection per transaction (recommended)
- **statement**: Connection per statement (limited use)

### Application-Level Pooling

```javascript
// Node.js with pg
const { Pool } = require('pg');

const pool = new Pool({
  max: 20,                // Maximum connections
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

// Use pool.query for single queries
const result = await pool.query('SELECT * FROM users WHERE id = $1', [1]);

// Use pool.connect for transactions
const client = await pool.connect();
try {
  await client.query('BEGIN');
  await client.query('UPDATE accounts SET balance = balance - $1 WHERE id = $2', [100, 1]);
  await client.query('UPDATE accounts SET balance = balance + $1 WHERE id = $2', [100, 2]);
  await client.query('COMMIT');
} catch (e) {
  await client.query('ROLLBACK');
  throw e;
} finally {
  client.release();
}
```

## PostgreSQL Configuration

### Memory Settings

```ini
# postgresql.conf

# Shared buffers - 25% of RAM for dedicated server
shared_buffers = 4GB

# Work memory - per operation, careful with many connections
work_mem = 256MB  # For complex queries
# work_mem = 64MB  # For many concurrent connections

# Maintenance work memory
maintenance_work_mem = 1GB

# Effective cache size - 75% of RAM
effective_cache_size = 12GB
```

### Query Planner

```ini
# Enable parallel queries
max_parallel_workers_per_gather = 4
max_parallel_workers = 8

# Planner cost settings (adjust based on hardware)
random_page_cost = 1.1        # SSD (default 4.0 for HDD)
effective_io_concurrency = 200 # SSD (default 1 for HDD)

# Statistics
default_statistics_target = 100  # Increase for complex queries
```

### Write Performance

```ini
# WAL settings
wal_buffers = 64MB
wal_level = replica
max_wal_size = 4GB
min_wal_size = 1GB

# Checkpoint tuning
checkpoint_completion_target = 0.9
checkpoint_timeout = 15min

# Synchronous commit (trade durability for speed)
synchronous_commit = off  # Risky but fast
```

## Monitoring Queries

### pg_stat_statements

```sql
-- Enable extension
CREATE EXTENSION pg_stat_statements;

-- Find slowest queries
SELECT
    calls,
    total_exec_time::numeric(10,2) as total_ms,
    mean_exec_time::numeric(10,2) as mean_ms,
    rows,
    query
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;

-- Find queries with most rows
SELECT
    calls,
    rows,
    rows / calls as rows_per_call,
    query
FROM pg_stat_statements
WHERE calls > 100
ORDER BY rows DESC
LIMIT 10;

-- Reset statistics
SELECT pg_stat_statements_reset();
```

### Index Usage

```sql
-- Find unused indexes
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
WHERE idx_scan = 0
ORDER BY pg_relation_size(indexrelid) DESC;

-- Find missing indexes (sequential scans on large tables)
SELECT
    schemaname,
    relname,
    seq_scan,
    seq_tup_read,
    idx_scan,
    idx_tup_fetch
FROM pg_stat_user_tables
WHERE seq_scan > 0
ORDER BY seq_tup_read DESC
LIMIT 20;
```

### Table Bloat

```sql
-- Check table bloat
SELECT
    tablename,
    pg_size_pretty(pg_total_relation_size(tablename::regclass)) as total_size,
    pg_size_pretty(pg_relation_size(tablename::regclass)) as table_size,
    pg_size_pretty(pg_indexes_size(tablename::regclass)) as index_size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(tablename::regclass) DESC;

-- Check dead tuples
SELECT
    relname,
    n_live_tup,
    n_dead_tup,
    n_dead_tup::float / nullif(n_live_tup, 0) as dead_ratio,
    last_vacuum,
    last_autovacuum
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;
```

### Lock Monitoring

```sql
-- View current locks
SELECT
    pid,
    pg_blocking_pids(pid) as blocked_by,
    query,
    state,
    wait_event_type,
    wait_event
FROM pg_stat_activity
WHERE state != 'idle';

-- Find blocking queries
SELECT
    blocked.pid AS blocked_pid,
    blocked.query AS blocked_query,
    blocking.pid AS blocking_pid,
    blocking.query AS blocking_query
FROM pg_stat_activity blocked
JOIN pg_stat_activity blocking ON blocking.pid = ANY(pg_blocking_pids(blocked.pid))
WHERE blocked.pid != blocking.pid;
```

## Batch Operations

### Bulk Insert

```sql
-- Bad: Individual inserts
INSERT INTO users (name) VALUES ('Alice');
INSERT INTO users (name) VALUES ('Bob');
-- ... 10000 more

-- Good: Multi-row insert
INSERT INTO users (name) VALUES
    ('Alice'),
    ('Bob'),
    ('Charlie');

-- Better: COPY for large datasets
COPY users (name, email) FROM '/path/to/data.csv' CSV HEADER;

-- From application
COPY users (name, email) FROM STDIN CSV;
```

### Bulk Update

```sql
-- Bad: Individual updates
UPDATE products SET price = price * 1.1 WHERE id = 1;
UPDATE products SET price = price * 1.1 WHERE id = 2;

-- Good: Single update
UPDATE products SET price = price * 1.1 WHERE id IN (1, 2, 3);

-- Better: Update from values
UPDATE products p
SET price = v.new_price
FROM (VALUES (1, 10.00), (2, 20.00), (3, 30.00)) AS v(id, new_price)
WHERE p.id = v.id;

-- Batch with limiting
UPDATE products
SET price = price * 1.1
WHERE id IN (
    SELECT id FROM products
    WHERE needs_update = true
    LIMIT 1000
);
```

### Bulk Delete

```sql
-- Bad: Delete all at once (locks table)
DELETE FROM logs WHERE created_at < '2023-01-01';

-- Good: Delete in batches
DO $$
DECLARE
    rows_deleted INTEGER;
BEGIN
    LOOP
        DELETE FROM logs
        WHERE id IN (
            SELECT id FROM logs
            WHERE created_at < '2023-01-01'
            LIMIT 10000
        );
        GET DIAGNOSTICS rows_deleted = ROW_COUNT;
        EXIT WHEN rows_deleted = 0;
        COMMIT;
    END LOOP;
END $$;

-- Or use partitioning and drop partition
ALTER TABLE logs DETACH PARTITION logs_2023_01;
DROP TABLE logs_2023_01;
```

## Partitioning

### Range Partitioning

```sql
-- Create partitioned table
CREATE TABLE orders (
    id SERIAL,
    user_id INTEGER,
    total DECIMAL(10,2),
    created_at TIMESTAMP
) PARTITION BY RANGE (created_at);

-- Create partitions
CREATE TABLE orders_2024_01 PARTITION OF orders
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

CREATE TABLE orders_2024_02 PARTITION OF orders
    FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');

-- Query benefits from partition pruning
EXPLAIN SELECT * FROM orders WHERE created_at = '2024-01-15';
-- Only scans orders_2024_01
```

### List Partitioning

```sql
CREATE TABLE orders (
    id SERIAL,
    region TEXT,
    total DECIMAL(10,2)
) PARTITION BY LIST (region);

CREATE TABLE orders_us PARTITION OF orders FOR VALUES IN ('US');
CREATE TABLE orders_eu PARTITION OF orders FOR VALUES IN ('EU', 'UK');
CREATE TABLE orders_asia PARTITION OF orders FOR VALUES IN ('JP', 'CN', 'KR');
```

### Hash Partitioning

```sql
CREATE TABLE sessions (
    id UUID,
    user_id INTEGER,
    data JSONB
) PARTITION BY HASH (user_id);

CREATE TABLE sessions_0 PARTITION OF sessions FOR VALUES WITH (MODULUS 4, REMAINDER 0);
CREATE TABLE sessions_1 PARTITION OF sessions FOR VALUES WITH (MODULUS 4, REMAINDER 1);
CREATE TABLE sessions_2 PARTITION OF sessions FOR VALUES WITH (MODULUS 4, REMAINDER 2);
CREATE TABLE sessions_3 PARTITION OF sessions FOR VALUES WITH (MODULUS 4, REMAINDER 3);
```

## JSONB Performance

### JSONB Indexing

```sql
-- GIN index for containment queries
CREATE INDEX idx_data_gin ON products USING gin(data);

-- Query uses index
SELECT * FROM products WHERE data @> '{"category": "electronics"}';

-- Index specific path
CREATE INDEX idx_data_category ON products USING btree((data->>'category'));

-- Query uses btree index
SELECT * FROM products WHERE data->>'category' = 'electronics';

-- GIN index for specific paths (smaller, faster)
CREATE INDEX idx_data_paths ON products USING gin(data jsonb_path_ops);
```

### JSONB Query Patterns

```sql
-- Containment (uses GIN index)
SELECT * FROM products WHERE data @> '{"active": true}';

-- Key existence
SELECT * FROM products WHERE data ? 'discount';

-- Path extraction
SELECT data->'pricing'->>'currency' FROM products;

-- Array operations
SELECT * FROM products WHERE data->'tags' ? 'sale';

-- JSONB aggregation
SELECT jsonb_agg(data) FROM products WHERE category = 'books';
```

## Caching Strategies

### Materialized Views

```sql
-- Create materialized view
CREATE MATERIALIZED VIEW product_stats AS
SELECT
    category,
    COUNT(*) as product_count,
    AVG(price) as avg_price,
    SUM(stock) as total_stock
FROM products
GROUP BY category;

-- Create index on materialized view
CREATE INDEX idx_product_stats_category ON product_stats(category);

-- Refresh (blocks reads)
REFRESH MATERIALIZED VIEW product_stats;

-- Refresh concurrently (requires unique index)
CREATE UNIQUE INDEX idx_product_stats_uniq ON product_stats(category);
REFRESH MATERIALIZED VIEW CONCURRENTLY product_stats;
```

### Application-Level Caching

```javascript
// Cache-aside pattern
async function getUser(id) {
    // Check cache
    const cached = await redis.get(`user:${id}`);
    if (cached) return JSON.parse(cached);

    // Query database
    const user = await db.query('SELECT * FROM users WHERE id = $1', [id]);

    // Cache result
    await redis.setex(`user:${id}`, 3600, JSON.stringify(user));

    return user;
}

// Cache invalidation
async function updateUser(id, data) {
    await db.query('UPDATE users SET ... WHERE id = $1', [id]);
    await redis.del(`user:${id}`);
}
```
