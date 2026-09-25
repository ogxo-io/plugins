# Architectural Patterns Comparison

Detailed comparison tables and guidance for choosing between system architecture styles, communication patterns, data storage options, and application architecture patterns.

## System Architecture Styles

| Pattern | Best For | Team Size | Complexity | Operational Cost |
|---------|----------|-----------|------------|-----------------|
| **Monolith** | Small teams, early-stage products, simple domains | 1-8 devs | Low | Low |
| **Modular Monolith** | Medium teams, complex domains, need for future decomposition | 4-20 devs | Medium | Low-Medium |
| **Microservices** | Large teams, independent deployment needs, diverse tech stacks | 20+ devs | High | High |
| **Serverless** | Event-driven workloads, variable traffic, rapid prototyping | Any | Medium | Pay-per-use |
| **Event-Driven** | Async workflows, decoupled systems, audit trails | 8+ devs | High | Medium-High |

**Monolith vs Modular Monolith vs Microservices:**

- **Monolith**: Single deployable unit. Start here unless you have a proven reason not to. Simplest to develop, test, deploy, and debug. Risk: becomes tangled as it grows.
- **Modular Monolith**: Single deployable unit with strict internal module boundaries. Modules communicate through defined interfaces, not direct database access. Gives most microservice benefits without distributed system complexity. Best stepping stone toward microservices if needed later.
- **Microservices**: Independently deployable services with separate data stores. Required only when you need independent deployment, polyglot persistence, or team autonomy at scale. Brings distributed system complexity: network failures, eventual consistency, distributed tracing, service discovery.

## Communication Patterns

| Pattern | Latency | Coupling | Complexity | Use When |
|---------|---------|----------|------------|----------|
| **REST (Synchronous)** | Low | Medium | Low | CRUD operations, simple request-response |
| **GraphQL** | Low | Low | Medium | Multiple clients with different data needs, reducing over-fetching |
| **gRPC** | Very Low | Medium | Medium | Internal service-to-service, performance-critical, streaming |
| **Message Queue (Async)** | Higher | Very Low | Medium | Decoupled workflows, reliable delivery, load leveling |
| **Event Streaming** | Higher | Very Low | High | Event sourcing, real-time analytics, audit trails |

**REST vs GraphQL vs gRPC:**

- **REST**: Use for public APIs, simple CRUD, when HTTP caching matters. Widely understood, excellent tooling. Risk: over-fetching, API versioning challenges.
- **GraphQL**: Use when clients need flexible queries, multiple platforms consume the same API, or you want to reduce round trips. Risk: N+1 queries, complex authorization, caching difficulty.
- **gRPC**: Use for internal service-to-service calls where performance matters. Strongly typed contracts via Protobuf, supports streaming. Risk: not browser-native, requires HTTP/2.

## Data Storage Patterns

| Pattern | Consistency | Scale | Query Flexibility | Use When |
|---------|------------|-------|-------------------|----------|
| **SQL (PostgreSQL, MySQL)** | Strong (ACID) | Vertical + Read Replicas | High (SQL) | Structured data, complex queries, transactions |
| **Document (MongoDB)** | Tunable | Horizontal | Medium | Flexible schema, document-oriented data, rapid iteration |
| **Key-Value (Redis, DynamoDB)** | Tunable | Horizontal | Low | Caching, sessions, high-throughput simple lookups |
| **Column-Family (Cassandra)** | Eventual | Horizontal | Low-Medium | Time-series, write-heavy workloads, massive scale |
| **Graph (Neo4j)** | Strong | Limited | High (Graph) | Relationship-heavy data, social networks, recommendations |
| **NewSQL (CockroachDB, Spanner)** | Strong (ACID) | Horizontal | High (SQL) | Need SQL semantics with horizontal scale |

**SQL vs NoSQL vs NewSQL:**

- **SQL**: Default choice for most applications. ACID transactions, mature tooling, flexible queries. Scale with read replicas, connection pooling, and query optimization before considering alternatives.
- **NoSQL**: Use when your data model genuinely does not fit relational (document, graph, time-series) or when horizontal write scaling is a proven requirement. Do not choose NoSQL to avoid learning SQL.
- **NewSQL**: Use when you need both SQL semantics and horizontal write scaling. Higher operational complexity than traditional SQL.

## Application Architecture Patterns

| Pattern | Separation | Testability | Complexity | Use When |
|---------|-----------|-------------|------------|----------|
| **Layered** | By technical concern | Medium | Low | Simple CRUD apps, small teams |
| **Hexagonal (Ports & Adapters)** | By dependency direction | High | Medium | Domain logic isolation, multiple integrations |
| **Clean Architecture** | By dependency rule | High | Medium-High | Complex business rules, long-lived systems |
| **CQRS** | Read vs write models | High | High | Different read/write patterns, event sourcing |
| **Event Sourcing** | By state derivation | Very High | Very High | Audit requirements, temporal queries, complex domains |

**Layered vs Hexagonal vs Clean Architecture:**

- **Layered**: Presentation -> Business Logic -> Data Access. Simple and well-understood. Risk: business logic leaks into layers, tight coupling to database.
- **Hexagonal**: Domain core with ports (interfaces) and adapters (implementations). Business logic has zero dependency on infrastructure. Best balance of isolation and pragmatism.
- **Clean Architecture**: Strict dependency rule -- inner layers never know about outer layers. Entities -> Use Cases -> Interface Adapters -> Frameworks. More ceremony than hexagonal but stronger guarantees.
