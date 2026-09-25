# Diagram Examples

Thirteen complete, working Mermaid examples covering all supported diagram types plus architecture-specific patterns. Each includes context on when to use it. The domains and content are illustrative — build diagrams from the user's request or codebase, not from these examples.

## 1. Flowchart -- User Registration Process

**When to use:** Processes with decisions, branching logic, step-by-step workflows.

```mermaid
graph TD
    A[User visits signup page] --> B[Fill registration form]
    B --> C{Valid input?}
    C -->|No| D[Show validation errors]
    D --> B
    C -->|Yes| E[Check email uniqueness]
    E --> F{Email exists?}
    F -->|Yes| G[Show duplicate error]
    G --> B
    F -->|No| H[Create account]
    H --> I[Send verification email]
    I --> J[Show success page]
    J --> K{User clicks verify link?}
    K -->|Yes| L[Activate account]
    K -->|No, expired| M[Resend verification]
    M --> K
    L --> N[Redirect to dashboard]
```

## 2. Sequence Diagram -- REST API Authentication Flow

**When to use:** Interactions between components over time, request/response flows, API call chains.

```mermaid
sequenceDiagram
    autonumber
    actor U as User
    participant C as Client App
    participant A as Auth Server
    participant R as Resource API
    participant DB as Database

    U->>C: Enter credentials
    C->>A: POST /auth/login
    A->>DB: Query user by email
    DB-->>A: User record

    alt Invalid credentials
        A-->>C: 401 Unauthorized
        C-->>U: Show error message
    else Valid credentials
        A->>A: Generate JWT tokens
        A-->>C: 200 OK {accessToken, refreshToken}
        C->>C: Store tokens

        U->>C: Request protected resource
        C->>R: GET /api/data (Authorization: Bearer token)
        R->>R: Validate JWT
        R->>DB: Fetch data
        DB-->>R: Data records
        R-->>C: 200 OK {data}
        C-->>U: Display data
    end
```

## 3. Class Diagram -- E-commerce Domain Model

**When to use:** Object-oriented structures, interfaces, inheritance hierarchies, type relationships.

```mermaid
classDiagram
    class User {
        +String id
        +String email
        +String name
        +Address[] addresses
        +register() void
        +login() Session
    }

    class Order {
        +String id
        +Date createdAt
        +OrderStatus status
        +LineItem[] items
        +calculateTotal() Decimal
        +cancel() void
    }

    class LineItem {
        +String productId
        +int quantity
        +Decimal unitPrice
        +subtotal() Decimal
    }

    class Product {
        +String id
        +String name
        +Decimal price
        +int stock
        +isAvailable() bool
    }

    class Payment {
        +String id
        +Decimal amount
        +PaymentMethod method
        +PaymentStatus status
        +process() bool
        +refund() bool
    }

    class OrderStatus {
        <<enumeration>>
        PENDING
        CONFIRMED
        SHIPPED
        DELIVERED
        CANCELLED
    }

    User "1" --> "*" Order : places
    Order "1" *-- "1..*" LineItem : contains
    LineItem "*" --> "1" Product : references
    Order "1" --> "0..1" Payment : has
```

## 4. ER Diagram -- Blog Platform Database

**When to use:** Database schemas, data models, table relationships with cardinality.

```mermaid
erDiagram
    USER {
        uuid id PK
        varchar email UK
        varchar username UK
        varchar password_hash
        varchar display_name
        text bio
        timestamp created_at
        timestamp updated_at
    }

    POST {
        uuid id PK
        uuid author_id FK
        varchar title
        varchar slug UK
        text content
        varchar status
        timestamp published_at
        timestamp created_at
    }

    CATEGORY {
        uuid id PK
        varchar name UK
        varchar slug UK
        text description
    }

    TAG {
        uuid id PK
        varchar name UK
        varchar slug UK
    }

    COMMENT {
        uuid id PK
        uuid post_id FK
        uuid author_id FK
        uuid parent_id FK
        text content
        timestamp created_at
    }

    POST_TAG {
        uuid post_id FK
        uuid tag_id FK
    }

    POST_CATEGORY {
        uuid post_id FK
        uuid category_id FK
    }

    USER ||--o{ POST : writes
    USER ||--o{ COMMENT : writes
    POST ||--o{ COMMENT : has
    COMMENT ||--o{ COMMENT : "replies to"
    POST ||--o{ POST_TAG : ""
    TAG ||--o{ POST_TAG : ""
    POST ||--o{ POST_CATEGORY : ""
    CATEGORY ||--o{ POST_CATEGORY : ""
```

## 5. State Diagram -- Order Lifecycle

**When to use:** State machines, object lifecycles, status transitions with triggers.

```mermaid
stateDiagram-v2
    [*] --> Draft : create order

    Draft --> Pending : submit
    Draft --> Cancelled : cancel

    Pending --> Confirmed : payment received
    Pending --> Cancelled : timeout / cancel

    state Confirmed {
        [*] --> Processing
        Processing --> Packed : items packed
        Packed --> ReadyToShip : label printed
    }

    Confirmed --> Shipped : dispatch
    Confirmed --> Cancelled : cancel (with refund)

    Shipped --> InTransit : picked up
    InTransit --> Delivered : delivered

    Delivered --> Returned : return requested
    Returned --> Refunded : refund processed

    Cancelled --> [*]
    Refunded --> [*]
    Delivered --> [*]
```

## 6. Gantt Chart -- Sprint Planning

**When to use:** Project timelines, task scheduling, milestones, team workload visualization.

```mermaid
gantt
    title Sprint 14 - User Profile Features
    dateFormat YYYY-MM-DD
    excludes weekends

    section Backend
    Profile API endpoints     :b1, 2024-03-04, 3d
    Avatar upload service     :b2, after b1, 2d
    Profile validation        :b3, after b1, 2d
    Database migrations       :b4, 2024-03-04, 1d

    section Frontend
    Profile page layout       :f1, 2024-03-04, 2d
    Avatar component          :f2, after f1, 3d
    Edit profile form         :f3, after f1, 3d
    Settings page             :f4, after f3, 2d

    section QA
    API testing               :q1, after b3, 2d
    UI testing                :q2, after f4, 2d
    Integration testing       :q3, after q1, 2d

    section Milestones
    Sprint review             :milestone, m1, 2024-03-15, 0d
```

## 7. Mindmap -- Microservices Architecture

**When to use:** Hierarchical overviews, brainstorming, concept mapping, technology landscapes.

```mermaid
mindmap
    root((E-Commerce Platform))
        API Gateway
            Rate Limiting
            Authentication
            Request Routing
            Load Balancing
        User Service
            Registration
            Authentication
            Profile Management
            Preferences
        Product Service
            Catalog
            Search
            Inventory
            Pricing
        Order Service
            Cart Management
            Checkout
            Order Tracking
            Returns
        Payment Service
            Credit Card
            PayPal
            Crypto
            Refunds
        Notification Service
            Email
            SMS
            Push
            Webhooks
        Infrastructure
            PostgreSQL
            Redis Cache
            RabbitMQ
            S3 Storage
```

## 8. Pie Chart -- Code Language Distribution

**When to use:** Proportional breakdowns, composition analysis, distribution visualization.

```mermaid
pie showData title Repository Language Distribution
    "TypeScript" : 45
    "JavaScript" : 20
    "CSS/SCSS" : 15
    "Go" : 10
    "Shell" : 5
    "Other" : 5
```

## 9. Git Graph -- Release Branching Strategy

**When to use:** Git workflows, branching strategies, release processes, merge patterns.

```mermaid
gitGraph
    commit id: "init"
    branch develop
    checkout develop
    commit id: "setup"

    branch feature/auth
    checkout feature/auth
    commit id: "login"
    commit id: "signup"
    checkout develop
    merge feature/auth id: "merge-auth"

    branch feature/dashboard
    checkout feature/dashboard
    commit id: "layout"
    commit id: "widgets"

    checkout develop
    commit id: "hotfix"
    merge feature/dashboard id: "merge-dash"

    checkout main
    merge develop id: "release" tag: "v1.0.0"

    checkout develop
    commit id: "next"

    branch feature/settings
    commit id: "prefs"
    checkout develop
    merge feature/settings id: "merge-settings"

    checkout main
    merge develop id: "v1.1" tag: "v1.1.0"
```

## 10. C4 Context Diagram -- SaaS Application

**When to use:** High-level system architecture, external integrations, system boundaries.

```mermaid
C4Context
    title System Context - SaaS Analytics Platform

    Person(analyst, "Data Analyst", "Reviews dashboards and creates reports")
    Person(admin, "Admin", "Manages users and configuration")

    System(platform, "Analytics Platform", "Core SaaS application for data visualization and reporting")

    System_Ext(auth0, "Auth0", "Identity and access management")
    System_Ext(stripe, "Stripe", "Payment processing and subscriptions")
    System_Ext(sendgrid, "SendGrid", "Transactional email delivery")
    System_Ext(s3, "AWS S3", "File and report storage")
    SystemDb_Ext(warehouse, "Data Warehouse", "Customer data sources (Snowflake, BigQuery)")

    Rel(analyst, platform, "Views dashboards, creates reports", "HTTPS")
    Rel(admin, platform, "Manages settings", "HTTPS")
    Rel(platform, auth0, "Authenticates users", "OAuth 2.0")
    Rel(platform, stripe, "Processes payments", "HTTPS/API")
    Rel(platform, sendgrid, "Sends notifications", "SMTP/API")
    Rel(platform, s3, "Stores exports", "HTTPS/SDK")
    Rel(platform, warehouse, "Queries data", "SQL/API")
```

## 11. Architecture Diagram -- Clean Microservices Architecture

**When to use:** System-level architecture with multiple services, layered grouping, and color-coded components. Demonstrates subgraph organization, edge labeling, and legend inclusion.

```mermaid
graph TD
    subgraph Clients
        WEB[Web App]:::client
        MOB[Mobile App]:::client
    end

    subgraph API Layer
        GW[API Gateway]:::api
        AUTH[Auth Service]:::api
    end

    subgraph Services
        USR[User Service]:::service
        ORD[Order Service]:::service
        PAY[Payment Service]:::service
        INV[Inventory Service]:::service
    end

    subgraph Data Layer
        PG[(PostgreSQL)]:::storage
        RD[(Redis Cache)]:::storage
        S3[(S3 Storage)]:::storage
    end

    subgraph Messaging
        MQ[RabbitMQ]:::queue
    end

    subgraph External
        STRIPE[Stripe API]:::external
        SEND[SendGrid]:::external
    end

    subgraph Legend
        direction LR
        L1[Client]:::client ~~~ L2[API]:::api ~~~ L3[Service]:::service
        L4[Storage]:::storage ~~~ L5[Queue]:::queue ~~~ L6[External]:::external
    end

    %% Edges defined outside subgraphs for better layout
    WEB -->|HTTPS| GW
    MOB -->|HTTPS| GW
    GW -->|validate| AUTH
    GW -->|route| USR
    GW -->|route| ORD
    ORD -->|check stock| INV
    ORD -->|charge| PAY
    PAY -->|process| STRIPE
    ORD -->|events| MQ
    MQ -->|notify| SEND
    USR -->|read/write| PG
    ORD -->|read/write| PG
    INV -->|read/write| PG
    PAY -->|read/write| PG
    GW -->|cache| RD
    USR -->|avatars| S3

    classDef client fill:#5E81AC,stroke:#2E3440,color:#ECEFF4,stroke-width:2px
    classDef api fill:#81A1C1,stroke:#2E3440,color:#ECEFF4,stroke-width:2px
    classDef service fill:#88C0D0,stroke:#2E3440,color:#2E3440,stroke-width:1px
    classDef storage fill:#A3BE8C,stroke:#2E3440,color:#2E3440,stroke-width:1px
    classDef queue fill:#EBCB8B,stroke:#2E3440,color:#2E3440,stroke-width:1px
    classDef external fill:#B48EAD,stroke:#2E3440,color:#ECEFF4,stroke-width:1px,stroke-dasharray:5 5

    style Clients fill:#E5E9F0,stroke:#4C566A,stroke-width:1px
    style API Layer fill:#ECEFF4,stroke:#4C566A,stroke-width:1px
    style Services fill:#E5E9F0,stroke:#4C566A,stroke-width:1px
    style Data Layer fill:#ECEFF4,stroke:#4C566A,stroke-width:1px
    style Messaging fill:#E5E9F0,stroke:#4C566A,stroke-width:1px
    style External fill:#ECEFF4,stroke:#4C566A,stroke-width:1px
```

**Techniques demonstrated:**
- 16 nodes organized into 6 subgraphs (3-4 nodes each)
- Color-coded components with `classDef` classes
- Edges defined outside subgraphs for optimal layout
- Short edge labels (1-2 words)
- Legend subgraph for color reference
- Alternating subgraph fill colors for layer distinction

## 12. Anti-Pattern vs Clean Pattern -- Same System, Two Approaches

**When to use:** Reference this example to understand what makes architecture diagrams cluttered and how to fix them. Shows the same e-commerce system drawn two ways.

### Anti-Pattern: Flat, Unorganized (21 nodes, no grouping)

```mermaid
graph TD
    WebApp --> APIGateway
    MobileApp --> APIGateway
    APIGateway --> AuthService
    APIGateway --> UserService
    APIGateway --> OrderService
    APIGateway --> ProductService
    APIGateway --> PaymentService
    APIGateway --> NotificationService
    APIGateway --> InventoryService
    UserService --> PostgreSQL
    OrderService --> PostgreSQL
    ProductService --> PostgreSQL
    PaymentService --> PostgreSQL
    InventoryService --> PostgreSQL
    NotificationService --> PostgreSQL
    OrderService --> Redis
    ProductService --> Redis
    PaymentService --> StripeAPI
    NotificationService --> SendGridAPI
    OrderService --> RabbitMQ
    RabbitMQ --> NotificationService
```

**Problems with this approach:**
- 21 nodes with no subgraph grouping -- flat layout with many edge crossings
- No color coding -- all nodes look identical, hard to distinguish component types
- No edge labels -- relationships are ambiguous (what does the arrow mean?)
- Every service connects directly to PostgreSQL -- 5 crossing edges to one node
- No visual hierarchy -- clients, services, and databases all at the same level

### Clean Pattern: Organized, Color-Coded (14 nodes, grouped)

```mermaid
graph TD
    subgraph Clients
        WEB[Web App]:::client
        MOB[Mobile App]:::client
    end

    subgraph Gateway
        GW[API Gateway]:::api
    end

    subgraph coreServices [Core Services]
        USR[User Service]:::service
        ORD[Order Service]:::service
        PRD[Product Service]:::service
        PAY[Payment Service]:::service
    end

    subgraph Data
        PG[(PostgreSQL)]:::storage
        RD[(Redis)]:::storage
        MQ[RabbitMQ]:::queue
    end

    subgraph External
        STRIPE[Stripe]:::external
        SEND[SendGrid]:::external
    end

    WEB -->|HTTPS| GW
    MOB -->|HTTPS| GW
    GW -->|auth + route| USR
    GW -->|auth + route| ORD
    GW -->|auth + route| PRD
    ORD -->|charge| PAY
    PAY -->|process| STRIPE
    ORD -->|events| MQ
    MQ -->|notify| SEND
    coreServices -->|queries| PG
    GW -->|cache| RD

    classDef client fill:#5E81AC,stroke:#2E3440,color:#ECEFF4,stroke-width:2px
    classDef api fill:#81A1C1,stroke:#2E3440,color:#ECEFF4,stroke-width:2px
    classDef service fill:#88C0D0,stroke:#2E3440,color:#2E3440,stroke-width:1px
    classDef storage fill:#A3BE8C,stroke:#2E3440,color:#2E3440,stroke-width:1px
    classDef queue fill:#EBCB8B,stroke:#2E3440,color:#2E3440,stroke-width:1px
    classDef external fill:#B48EAD,stroke:#2E3440,color:#ECEFF4,stroke-width:1px,stroke-dasharray:5 5

    style Clients fill:#E5E9F0,stroke:#4C566A,stroke-width:1px
    style Gateway fill:#ECEFF4,stroke:#4C566A,stroke-width:1px
    style coreServices fill:#E5E9F0,stroke:#4C566A,stroke-width:1px
    style Data fill:#ECEFF4,stroke:#4C566A,stroke-width:1px
    style External fill:#E5E9F0,stroke:#4C566A,stroke-width:1px
```

**What changed and why:**
- **Reduced from 21 to 14 nodes** -- Merged NotificationService and InventoryService into core services (they are implementation details at this zoom level)
- **Grouped into 5 subgraphs** -- Clear layers: Clients, Gateway, Core Services, Data, External
- **Color-coded by type** -- Instantly distinguishable: blue clients, teal services, green storage, purple external
- **Labeled edges** -- Every arrow tells you what the connection does
- **Eliminated redundant DB connections** -- One `Core Services --> PG` edge replaces 5 individual connections
- **Subgraph styling** -- Light alternating backgrounds separate layers visually

## 13. Component Decomposition -- Overview + Detail Diagrams

**When to use:** Systems where one or more blocks have significant internal complexity. Instead of cramming everything into one diagram, show a collapsed overview and separate detail diagrams for each complex block.

### Overview Diagram (System Level)

The Order Service and Payment Service are complex internally, so they appear as single `«detail»` nodes here. The overview stays clean at 12 nodes.

```mermaid
graph TD
    subgraph Clients
        WEB[Web App]:::client
        MOB[Mobile App]:::client
    end

    subgraph Gateway
        GW[API Gateway]:::api
    end

    subgraph Services
        USR[User Service]:::service
        ORD["Order Service «detail»"]:::service
        PAY["Payment Service «detail»"]:::service
    end

    subgraph Data
        PG[(PostgreSQL)]:::storage
        RD[(Redis)]:::storage
    end

    subgraph External
        STRIPE[Stripe]:::external
        SEND[SendGrid]:::external
    end

    WEB -->|HTTPS| GW
    MOB -->|HTTPS| GW
    GW -->|auth + route| USR
    GW -->|auth + route| ORD
    ORD -->|charge| PAY
    PAY -->|process| STRIPE
    ORD -->|notify| SEND
    Services -->|queries| PG
    GW -->|cache| RD

    classDef client fill:#5E81AC,stroke:#2E3440,color:#ECEFF4,stroke-width:2px
    classDef api fill:#81A1C1,stroke:#2E3440,color:#ECEFF4,stroke-width:2px
    classDef service fill:#88C0D0,stroke:#2E3440,color:#2E3440,stroke-width:1px
    classDef storage fill:#A3BE8C,stroke:#2E3440,color:#2E3440,stroke-width:1px
    classDef external fill:#B48EAD,stroke:#2E3440,color:#ECEFF4,stroke-width:1px,stroke-dasharray:5 5

    style Clients fill:#E5E9F0,stroke:#4C566A,stroke-width:1px
    style Gateway fill:#ECEFF4,stroke:#4C566A,stroke-width:1px
    style Services fill:#E5E9F0,stroke:#4C566A,stroke-width:1px
    style Data fill:#ECEFF4,stroke:#4C566A,stroke-width:1px
    style External fill:#E5E9F0,stroke:#4C566A,stroke-width:1px
```

### Detail Diagram: Order Service Internals

This expands the `Order Service «detail»` node from the overview. Uses the same teal `service` color to maintain visual continuity.

```mermaid
graph TD
    subgraph Order Service
        API[Order API]:::api
        VAL[Input Validator]:::service
        CART[Cart Manager]:::service
        PROC[Order Processor]:::service
        TRACK[Order Tracker]:::service
        REPO[(Order DB)]:::storage
        EVT[Event Publisher]:::queue
    end

    API -->|validate| VAL
    VAL -->|manage cart| CART
    CART -->|submit| PROC
    PROC -->|persist| REPO
    PROC -->|emit events| EVT
    TRACK -->|read| REPO
    API -->|status| TRACK

    classDef api fill:#81A1C1,stroke:#2E3440,color:#ECEFF4,stroke-width:2px
    classDef service fill:#88C0D0,stroke:#2E3440,color:#2E3440,stroke-width:1px
    classDef storage fill:#A3BE8C,stroke:#2E3440,color:#2E3440,stroke-width:1px
    classDef queue fill:#EBCB8B,stroke:#2E3440,color:#2E3440,stroke-width:1px

    style Order Service fill:#E5E9F0,stroke:#4C566A,stroke-width:1px
```

### Detail Diagram: Payment Service Internals

This expands the `Payment Service «detail»` node from the overview.

```mermaid
graph TD
    subgraph Payment Service
        PAPI[Payment API]:::api
        PVAL[Payment Validator]:::service
        CHRG[Charge Processor]:::service
        RFND[Refund Handler]:::service
        LEDG[(Ledger DB)]:::storage
    end

    PAPI -->|validate| PVAL
    PVAL -->|charge| CHRG
    PVAL -->|refund| RFND
    CHRG -->|record| LEDG
    RFND -->|record| LEDG

    classDef api fill:#81A1C1,stroke:#2E3440,color:#ECEFF4,stroke-width:2px
    classDef service fill:#88C0D0,stroke:#2E3440,color:#2E3440,stroke-width:1px
    classDef storage fill:#A3BE8C,stroke:#2E3440,color:#2E3440,stroke-width:1px

    style Payment Service fill:#E5E9F0,stroke:#4C566A,stroke-width:1px
```

**Techniques demonstrated:**
- Overview stays at 12 nodes by collapsing complex services to single `«detail»` nodes
- Each detail diagram is self-contained with 5-7 nodes
- Same `classDef` colors used across all diagrams for visual continuity
- `«detail»` label signals to readers that a drill-down exists
- Readers get the full system picture (overview) and can dive into any block (detail)

## Usage Tips

- **Start simple** - Begin with the most basic version, then add detail
- **One diagram per concern** - Don't combine class and sequence in one diagram
- **Label edges** - Unlabeled arrows are ambiguous; always add relationship labels
- **Use subgraphs/groups** - Group related nodes to reduce visual clutter
- **Mind the node count** - Refer to type-specific limits in `output-formatting.md`
- **Test rendering** - Preview in your target platform before finalizing
- **Always use the clean pattern for architecture** - See Example 12; never create flat architecture diagrams
- **Color code all architecture diagrams** - Use the standard palette from `output-formatting.md` when there are 3+ component types
- **Include legends** - Add a legend subgraph to every color-coded diagram
- **Decompose complex blocks** - Use the overview + detail pattern (Example 13) instead of cramming internal details into the main diagram
