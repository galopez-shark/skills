---
name: novo-legacy-migration-context
description: "Initializes or updates the migration context for a legacy-to-Go project. Collects source repos, properties files, error codes, DB type, framework, auth, encryption, and a FULL endpoint inventory with migration status. Supports subcommands: /migration-context ticket <endpoint> generates a Jira-ready MD ticket for the PO. Saves .migration-context.yaml for novo-legacy-migration-endpoint."
license: MIT
metadata:
  author: galopez-shark
  version: "3.2.0"
  domain: migration
  triggers: migration-context, init-migration, novo-context, migration context, inicializar migracion, migration-context ticket
  role: specialist
  scope: configuration
  output-format: config
  related-skills: novo-legacy-migration-endpoint, golang-pro
---

# Migration Context Initialization

Collects all project-level information needed to migrate endpoints from a legacy service to Go. Saves the context so that `novo-legacy-migration-endpoint` can use it repeatedly without re-asking.

**Supports two modes:**
- **First run**: Collects everything from scratch
- **Re-invoke**: Loads existing `.migration-context.yaml` and asks what to add/update

---

## Subcommand: `/migration-context help` (alias `?`)

Print the help card below when the user types `/migration-context help`, `/migration-context ?`, or
asks "what does this do / what commands / how do I use it".

```text
migration-context — set up & maintain the project migration context (.migration-context.yaml).

USAGE
  /migration-context                     First run: collect source repos, properties, DB, auth,
                                         encryption, external services, full endpoint inventory.
                                         Re-invoke: add/update a section or manage the inventory.
  /migration-context ticket <endpoint>   Generate a Jira-ready MD ticket for the endpoint
                                         (docs/tickets/<endpoint>_migration.md) for the PO.
  /migration-context help                This help (alias: ?).

PRODUCES  .migration-context.yaml — consumed by the `/migrate` skill.

NOTES
  • If run from the legacy repo, it asks for the Go target repo (git URL/path) — never assumes it.
  • Records github.com/novopayment/mdw-welcome-project-go as the canonical go-bricks/architecture reference.
  • go-bricks is the mandatory target framework.

NEXT  after setup, use `/migrate list`, `/migrate roadmap`, or `/migrate <endpoint>`.
```

---

## Workflow

### 0. Check for existing context

Look for `.migration-context.yaml` in the current directory or target repo.

**If it EXISTS** → load it and ask:

> Existing migration context found. What would you like to do?
> 1. **Add** a new source repo
> 2. **Add** more properties/config files
> 3. **Add** more external services
> 4. **Update** an existing section
> 5. **View** current context summary
> 6. **Manage endpoint inventory** (add, update status, view)
> 7. **Start fresh** (overwrite)

Then jump to the relevant section below. After each addition, ask:
> **Want to add anything else?** (yes/no)

**If it DOES NOT exist** → start from Step 1 (full collection).

---

### 1. Source Repositories

The project may have MULTIPLE source repos. Collect each one.

```
Q: Path to a legacy source repository?
   (e.g. ../legacy-service, ../auth-service, ../commons-lib)
```

For EACH repo provided, ask:

```
For repo: {repo_path}

  Q: What language/framework?
     (e.g. Java/JAX-RS, Java/Spring Boot, Python/Flask, Node/Express)

  Q: Where are the endpoint handlers/controllers?
     (list ALL files — one line per file)

  Q: Where are the service/business logic classes?
     (list ALL files)

  Q: Where are the DAO/repository classes?
     (list ALL files)
```

After each repo is collected:

> **Want to add another source repo?** (yes/no)

Keep asking until the user says no.

---

### 1b. Library Viability Analysis (AUTOMATIC)

After ALL source repos are collected, analyze their dependencies to validate the migration is viable.

**Read dependency files**: `pom.xml`/`build.gradle` (Java), `package.json` (Node), `requirements.txt` (Python).

For each dependency, classify:

| Category | Action |
|----------|--------|
| **Go equivalent in target framework** | Map it (e.g. JAX-RS → go-bricks/server) |
| **Go equivalent as OSS lib** | Note it (e.g. Jackson → encoding/json) |
| **No direct equivalent, replaceable** | Flag — custom impl needed |
| **No equivalent — BLOCKER** | Flag as RISK |

Present the viability report:

```
┌──────────────────────────────────────────────────┐
│          LIBRARY VIABILITY ANALYSIS              │
├──────────────────────────────────────────────────┤
│ ✅ Viable                                        │
│   JAX-RS/Jersey    → go-bricks/server (Echo)     │
│   JPA/Hibernate    → database/sql + raw SQL      │
│   Jackson          → encoding/json               │
│   Log4j/SLF4J      → zerolog (via go-bricks)     │
│   JUnit/Mockito    → testify                     │
│   EJB @Stateless   → plain Go structs            │
│   CDI @Inject      → manual DI in module.go      │
│   SimpleDateFormat → time.Parse                  │
│   javax.crypto     → crypto/rsa + go-jose (JWE)  │
├──────────────────────────────────────────────────┤
│ ⚠️  Custom impl needed                           │
│   Custom annotations → Go middleware/handlers    │
├──────────────────────────────────────────────────┤
│ ❌ BLOCKERS                                       │
│   (none found)                                   │
└──────────────────────────────────────────────────┘
Verdict: ✅ Migration is VIABLE
```

If BLOCKERS exist:

> ⚠️ **{N} blockers found.** These libraries have no Go equivalent. Review before proceeding.

> **Migration viable? Proceed?** (yes/no)

---

### 2. Properties & Configuration Files

These are CRITICAL — error codes, constants, URLs live here.

```
Q: List ALL properties/config files that contain error codes,
   messages, operation IDs, URLs, or business constants.
   (one per line — give the full path from any source repo)
```

Examples:
- `../legacy-service/src/main/resources/RESPONSE_CODES.properties`
- `../legacy-service/src/main/resources/application.properties`
- `../commons-lib/src/main/resources/MFTECH_CONFIGURATIONS.properties`

After each file or batch:

> **Want to add more properties/config files?** (yes/no)

Then ask about files that are NOT in git:

```
Q: Are there config files that exist ONLY at runtime?
   (e.g. TomEE server properties, environment-only configs,
   secret managers, consul/vault keys)
   If yes, describe them — the user must provide values manually
   during migration.
```

> **Want to add more runtime-only configs?** (yes/no)

---

### 3. Database

```
Q: What database engine(s) does the source use?
   (Oracle, PostgreSQL, MySQL, SQL Server, etc.)
   List ALL if there are multiple (e.g. main DB + auth DB).

Q: Schema/owner prefix used in queries?
   (e.g. "mftechpa.", "public.", or none)

Q: Stored procedures or inline SQL?
```

> **Want to add another database?** (yes/no)

---

### 4. Authentication & Encryption

```
Q: How does the source handle authentication?
   (JWT Bearer, API key, session, OAuth2, etc.)
   Is auth handled by middleware/filter or per-endpoint?

Q: Does ANY endpoint use request/response body encryption?
   (JWE, AES, PGP, etc.)
   If yes: which scheme? which endpoints?
```

> **Want to add more auth or encryption details?** (yes/no)

---

### 5. External Services

Collect ALL external HTTP services the source calls.

```
Q: Name of external service?
   (e.g. payment connector, KYC validator, card issuer)

Q: Config key for its base URL?
   (e.g. custom.orchestrator.host)

Q: HTTP methods used?
   (GET, POST, PUT)

Q: Purpose?
   (e.g. balance inquiry, card issuance, risk validation)
```

After each service:

> **Want to add another external service?** (yes/no)

---

### 6. Target Go Project

> **If this skill is being run from the legacy source repo** (not the Go target), you cannot assume
> the target — **ASK the user which Go repository to use and request its git URL or local path**
> before continuing. Never treat the legacy repo as the target.
>
> **Canonical Go reference (ALWAYS):** record
> [`novopayment/mdw-welcome-project-go`](https://github.com/novopayment/mdw-welcome-project-go) as
> `target.reference_repo`. It defines the mandatory go-bricks usage and Go architecture; every
> migration defers to it when a pattern is unclear.

```
Q: Path to the target Go repository?
   (if running from the legacy repo, ask for the git URL or local path — do not assume)

Q: What Go framework is the target built on?
   (go-bricks, standard library, Echo, Gin, Fiber, etc.)

Q: Module structure convention?
   (e.g. internal/modules/{name}/ with domain/repository/service/handlers)

Q: Where does the target store:
   - Shared error types/codes? (e.g. internal/plataform/bussines/)
   - Shared business constants?
   - External HTTP clients? (e.g. internal/plataform/external/)
   - Config files? (list both env-placeholder and local-values files)

Q: Test command? (e.g. make check, go test ./...)

Q: Branching convention? (e.g. feature/{ticket}-{description})

Q: Version file and bump strategy?
   (e.g. config.yml → app.version, semver per branch)

Q: Ticket system?
   (e.g. Jira at jira.example.com, project prefix PROJ)
```

> **Want to add anything else about the target project?** (yes/no)

---

### 7. Endpoint Inventory (NEW — MANDATORY)

This section builds a **complete inventory** of ALL endpoints in the source project and tracks their migration status.

#### 7a. Auto-discovery

For EACH source repo, read ALL handler/controller files listed in `source_repos[].paths.handlers` and extract:

- HTTP method (GET, POST, PUT, DELETE)
- URL path
- Java method name
- Brief description (from method name or annotations)
- Whether the endpoint uses encryption (JWE)
- External services it calls

Present the discovered endpoints grouped by module:

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                         ENDPOINT INVENTORY                                      │
├──────────────────────────────────────────────────────────────────────────────────┤
│ Module: accounts (Java: api-mftech-core-accounts / Resource.java)               │
│                                                                                 │
│  #  │ HTTP │ Path                              │ Method            │ Encryption │
│  1  │ GET  │ /user/:tag/balance/:token          │ getBalance        │ Resp JWE   │
│  2  │ GET  │ /user/:tag/card/:token              │ getCardHolder     │ Resp JWE   │
│  3  │ GET  │ /user/:tag/card/:token/cvv          │ getCVV2           │ None       │
│  4  │ PUT  │ /user/:tag/card/:token/block        │ changeBlockStatus │ None       │
│ ... │      │                                     │                   │            │
├──────────────────────────────────────────────────────────────────────────────────┤
│ Module: cards (Java: api-mftech-core-cards / CardResource.java)                 │
│                                                                                 │
│  #  │ HTTP │ Path                              │ Method            │ Encryption │
│  5  │ PUT  │ /user/:tag/card/:token/cancel       │ doOnCancelledCard │ Req+Resp   │
│ ... │      │                                     │                   │            │
└──────────────────────────────────────────────────────────────────────────────────┘

Total: {N} endpoints discovered
```

Ask the user:

> **Is this list complete? Want to add or remove any endpoints?** (yes/no)

#### 7b. Set initial migration status

For each endpoint, ask or auto-detect:

```
Q: Which endpoints are ALREADY migrated to Go?
   (list by number or name — I'll mark them as "done")
```

Migration statuses:
| Status | Meaning |
|--------|---------|
| `not_started` | Not yet migrated — no Go code exists |
| `in_progress` | Migration started — indicate current phase |
| `done` | Fully migrated and merged to main |
| `certified` | Migrated AND certified in TEST environment |
| `blocked` | Migration blocked — note the reason |

For endpoints marked `in_progress`, ask:

```
Q: What phase is {endpoint} in?
   (domain, repository, service, handler, docs)
   Branch name? Ticket number?
```

#### 7c. Complexity estimation

For each `not_started` endpoint, auto-estimate complexity:

| Factor | Points |
|--------|--------|
| Simple CRUD (1 table, no external calls) | 1 |
| Multiple tables / JOINs | +1 |
| External HTTP call(s) | +1 per call |
| Encryption (JWE) | +1 |
| DB transaction (multi-write) | +1 |
| Complex validation logic | +1 |

Classify:
- **1-2 points**: Simple (3-4 phases)
- **3-4 points**: Medium (4-5 phases)
- **5+ points**: Complex (5-7+ phases)

Present the summary:

```
┌──────────────────────────────────────────────────────────────────┐
│                 MIGRATION STATUS SUMMARY                        │
├──────────────────────────────────────────────────────────────────┤
│ ✅ Done/Certified:  13 endpoints                                │
│ 🔄 In Progress:      1 endpoint (transactions_history Phase 2)  │
│ ❌ Not Started:      11 endpoints                               │
│ 🚫 Blocked:          0 endpoints                                │
├──────────────────────────────────────────────────────────────────┤
│ Complexity Breakdown (not_started only):                        │
│   Simple:   3 endpoints (~12-16 phases total)                   │
│   Medium:   5 endpoints (~20-25 phases total)                   │
│   Complex:  3 endpoints (~15-21 phases total)                   │
│   Est. total remaining phases: ~47-62                           │
└──────────────────────────────────────────────────────────────────┘
```

---

### 8. go-bricks Mapping (MANDATORY)

**Every migration MUST use go-bricks as the architectural foundation.** Before saving, map how go-bricks covers each layer:

```
┌──────────────────────────────────────────────────────────────────┐
│               go-bricks FRAMEWORK MAPPING                       │
├──────────────────────────────────────────────────────────────────┤
│ Layer          │ go-bricks Component         │ Import Path       │
│────────────────│─────────────────────────────│───────────────────│
│ HTTP Server    │ server.Echo                 │ go-bricks/server  │
│ Route Binding  │ server.HandlerContext       │ go-bricks/server  │
│ Request Valid. │ validate:"required" tags    │ Echo validator     │
│ DB Access      │ database.Interface          │ go-bricks/db      │
│ DB Transactions│ db.Begin / tx.Commit        │ go-bricks/db      │
│ HTTP Client    │ httpclient.Client           │ go-bricks/http    │
│ JWE Encryption │ cryptoutil.DecryptJWE       │ go-bricks/crypto  │
│ Logging        │ logger.Logger (zerolog)     │ go-bricks/logger  │
│ Config Inject  │ deps.Config.InjectInto      │ go-bricks/config  │
│ Module System  │ app.Module interface        │ go-bricks/app     │
│ Error Response │ server.IAPIError            │ go-bricks/server  │
│ Test Fixtures  │ fixtures.NewMockRows        │ go-bricks/testing │
│ Test DB Mocks  │ mocks.MockDatabase          │ go-bricks/testing │
│ Test Tx Mocks  │ mocks.MockTx               │ go-bricks/testing │
└──────────────────────────────────────────────────────────────────┘

Rule: If go-bricks provides it, USE IT. Never reinvent.
```

Save this mapping in the context file so every endpoint migration references it.

---

### 9. Validate & Save

Present the FULL context summary (including endpoint inventory):

```
┌──────────────────────────────────────────────────┐
│           MIGRATION CONTEXT SUMMARY              │
├──────────────────────────────────────────────────┤
│ Source Repos ({count})                           │
│   1. ../legacy-service (Java/JAX-RS)             │
│      Handlers: Resource.java, CardResource.java  │
│      Services: impl/*.java                       │
│      DAOs:     impl/*.java                       │
│   2. ../commons-lib (Java)                       │
│      Shared DTOs and utilities                   │
├──────────────────────────────────────────────────┤
│ Properties Files ({count})                       │
│   - RESPONSE_CODES.properties                    │
│   - MFTECH_CONFIGURATIONS.properties             │
│   - application.properties                       │
│   ⚠ Runtime-only: TomEE RESPONSE_CODES          │
├──────────────────────────────────────────────────┤
│ Database                                         │
│   Engine: Oracle | Schema: mftechpa              │
│   Auth DB: Oracle (separate connection)          │
├──────────────────────────────────────────────────┤
│ Auth: JWT Bearer (middleware)                    │
│ Encryption: JWE/RSA (5 endpoints)               │
├──────────────────────────────────────────────────┤
│ External Services ({count})                      │
│   - payment_connector (balance, transfers)       │
│   - kyc_validator (OFAC checks)                  │
│   - card_issuer (SGC issuance)                   │
├──────────────────────────────────────────────────┤
│ Endpoint Inventory                               │
│   Total: {N} | Done: {X} | In Progress: {Y}     │
│   Not Started: {Z} | Blocked: {W}               │
├──────────────────────────────────────────────────┤
│ go-bricks: v{version} (MANDATORY framework)      │
├──────────────────────────────────────────────────┤
│ Target: ./my-go-service (go-bricks v0.30.0)      │
│   Modules: internal/modules/{name}/              │
│   Tests: make check | Branch: feature/{t}-{p}    │
│   Version: config.yml → app.version              │
└──────────────────────────────────────────────────┘
```

Ask:

> **Is this correct? Want to change or add anything?** (yes/no)

If yes → go back to the relevant section.
If no → save.

### Save the context file

Write `.migration-context.yaml` to the target repo root:

```yaml
# Migration Context — generated by novo-legacy-migration-context
# Used by novo-legacy-migration-endpoint for each endpoint migration
# Re-invoke /migration-context to add or update entries

source_repos:
  - path: "../legacy-service"
    language: "Java/JAX-RS"
    paths:
      handlers:
        - "src/main/java/.../resource/Resource.java"
        - "src/main/java/.../resource/CardResource.java"
      services:
        - "src/main/java/.../service/impl/*.java"
      daos:
        - "src/main/java/.../dao/impl/*.java"

  - path: "../commons-lib"
    language: "Java"
    paths:
      handlers: []
      services:
        - "src/main/java/.../service/impl/*.java"
      daos:
        - "src/main/java/.../dao/impl/*.java"

properties_files:
  in_git:
    - repo: "../legacy-service"
      path: "src/main/resources/RESPONSE_CODES.properties"
      contains: "error codes and messages"
    - repo: "../legacy-service"
      path: "src/main/resources/application.properties"
      contains: "external service URLs, operation IDs"
    - repo: "../commons-lib"
      path: "src/main/resources/MFTECH_CONFIGURATIONS.properties"
      contains: "business constants, timeouts, validation patterns"
  runtime_only:
    - name: "TomEE RESPONSE_CODES.properties"
      description: "Additional error codes loaded at runtime, not in git"
      action: "User must provide values manually during migration"

databases:
  - name: "main"
    engine: "oracle"
    schema_prefix: "mftechpa."
    stored_procedures: false
  - name: "auth"
    engine: "oracle"
    schema_prefix: ""
    stored_procedures: false

auth:
  type: "jwt_bearer"
  handled_by: "middleware"

encryption:
  scheme: "JWE_RSA"
  endpoints:
    - "createDebitCard"
    - "cashIn"
    - "cashOut"
    - "p2p"
    - "blockUnblock"

external_services:
  - name: "payment_connector"
    config_key: "custom.orchestrator.host"
    methods: ["POST"]
    purpose: "Balance, CashIn, CashOut, P2P, Block operations"
  - name: "kyc_validator"
    config_key: "custom.kyc.path"
    methods: ["GET", "POST"]
    purpose: "KYC/OFAC check for card issuance"
  - name: "card_issuer"
    config_key: "custom.sgc.issuance"
    methods: ["POST"]
    purpose: "Virtual card issuance via SGC"

target:
  repo: "./my-go-service"
  framework: "go-bricks"
  framework_version: "v0.30.0"
  framework_rule: "MANDATORY — if go-bricks provides it, use it. Never reinvent."
  reference_repo: "https://github.com/novopayment/mdw-welcome-project-go"  # canonical go-bricks + architecture reference
  gobricks_mapping:
    http_server: "server.Echo"
    route_binding: "server.HandlerContext"
    db_access: "database.Interface"
    db_transactions: "db.Begin / tx.Commit / mocks.MockTx"
    http_client: "httpclient.Client"
    jwe_encryption: "cryptoutil.DecryptJWE / cryptoutil.EncryptJWE"
    logging: "logger.Logger (zerolog)"
    config_inject: "deps.Config.InjectInto"
    module_system: "app.Module interface"
    error_response: "server.IAPIError / server.NewNotFoundError"
    test_fixtures: "fixtures.NewMockRows"
    test_db_mocks: "mocks.MockDatabase"
    test_tx_mocks: "mocks.MockTx"
  structure:
    modules: "internal/modules/{name}/"
    layers: ["domain", "repository", "service", "handlers"]
    shared_errors: "internal/plataform/bussines/"
    shared_constants: "internal/plataform/bussines/"
    external_clients: "internal/plataform/external/"
    config_files:
      with_env_vars: "config.yml"
      with_local_values: "config.yaml"
  commands:
    test: "make check"
    lint: "make lint"
    build: "go build ./..."
  git:
    branch_prefix: "feature/"
    branch_pattern: "feature/{ticket}-{phase}"
    commit_language: "english"
  versioning:
    file: "config.yml"
    field: "app.version"
    strategy: "semver_per_branch"
  tickets:
    system: "jira"
    host: "jira.example.com"
    project_prefix: "PROJ"

# ── ENDPOINT INVENTORY ──────────────────────────────────
# Status values: not_started | in_progress | done | certified | blocked
# Phase values: domain | repository | service | handler | docs
endpoint_inventory:
  - id: 1
    module: "accounts"
    http_method: "GET"
    path: "/user/:tagpay/balance/:cardToken"
    java_method: "getAccountBalanceForMonth"
    java_file: "Resource.java"
    description: "Get account balance"
    encryption: "response"
    external_calls: ["payment_connector"]
    complexity: 3  # medium
    status: "done"
    go_module: "accounts"
    ticket: "CEB-XXXX"

  # ... more endpoints ...

  - id: 15
    module: "cards"
    http_method: "PUT"
    path: "/user/:tagpay/card/:cardToken/cancel"
    java_method: "doOnCancelledCard"
    java_file: "CardResource.java"
    description: "Cancel card"
    encryption: "request_response"
    external_calls: ["card_issuer"]
    complexity: 4  # medium
    status: "not_started"
    go_module: "cards"  # target module in Go
    ticket: ""
    current_phase: ""
    current_branch: ""
    notes: ""

checklist_per_endpoint:
  - "Read handler class for HTTP method, path, @PathParam vs @QueryParam"
  - "Read service class for business logic, validation order, catch blocks"
  - "Read DAO class for SQL queries, table names, JOIN chains"
  - "Read ALL properties files for error codes and messages"
  - "Check if endpoint uses encryption (JWE)"
  - "Check if endpoint calls external services"
  - "Identify ALL error codes returned (they are IMMUTABLE)"
  - "Check go-bricks for reusable types BEFORE writing any code"
```

Tell the user:

> Context saved to `.migration-context.yaml`.
>
> You can now use:
> - `/migrate` — migrate an endpoint
> - `/migrate list` — view all endpoints and their status
> - `/migrate status <endpoint>` — view phase details for an endpoint
> - `/migrate roadmap` — view the full migration roadmap
> - `/migration-context ticket <endpoint>` — generate a Jira-ready MD ticket
>
> To add more repos, files, services, or update endpoint status, run `/migration-context` again.

---

## Subcommand: `/migration-context ticket <endpoint>`

Generates a **Jira-ready Markdown ticket** (Historia de Usuario) for a specific endpoint migration. Then checks Jira: if the ticket exists, updates the description and creates subtasks for each phase. If it doesn't exist, just delivers the MD for the PO.

Accept endpoint by name, number, or Java method name.

### Workflow

1. **Load `.migration-context.yaml`** — if missing, tell user to run `/migration-context` first
2. **Find the endpoint** in `endpoint_inventory` by name, id, or java_method
3. **Read the Java source** automatically:
   - Handler/Resource file → HTTP method, path, params, annotations
   - Service file → business logic, validations, catch blocks
   - DAO file → SQL queries, tables, JOINs
   - Properties files → error codes and messages (IMMUTABLE)
4. **Identify external calls** and their purpose
5. **Check what Go infrastructure already exists** (modules, helpers, external clients)
6. **Generate the ticket MD** following the template below
7. **WRITE THE FILE** (Step 8 — MANDATORY, do this BEFORE anything else)
8. **Ask the user about Jira** (Step 10)

### Step 8 — Write the MD file (MANDATORY — ALWAYS do this)

**This step is NON-NEGOTIABLE.** You MUST use the Write tool to create the file on disk. Do NOT just show the content in chat.

```
Target path: docs/tickets/{endpoint_name}_migration.md
```

If the `docs/tickets/` directory does not exist, create it first:
```bash
mkdir -p docs/tickets
```

Then use the **Write tool** to write the full MD content to the file. After writing, confirm to the user:

```
✅ MD guardado en: docs/tickets/{endpoint_name}_migration.md
```

**Rules for this step:**
- ALWAYS write the file FIRST, before asking about Jira
- ALWAYS use the Write tool — never just print the content and say "it's above"
- ALWAYS create the directory if it doesn't exist
- The file must contain the COMPLETE ticket template filled in — not a summary, not a partial version
- If the file already exists, ask before overwriting

**After the file is written**, proceed to Step 9 (search Jira) and Step 10 (ask user).

### Step 9 — Search Jira for existing ticket

After generating and saving the MD, search Jira for the ticket:

**Option A — ticket number in YAML**: If `endpoint_inventory[].ticket` has a value (e.g. `CEB-5650`), use it directly.

**Option B — search by name**: If no ticket in YAML, search Jira:
```bash
# Search for the endpoint name in the epic
curl -s -G "https://jira4novo.atlassian.net/rest/api/3/search" \
  --data-urlencode "jql=project=CEB AND \"Epic Link\"=CEB-5392 AND summary ~ \"{endpoint_name}\"" \
  -H "Authorization: Basic ${AUTH}" \
  -H "Content-Type: application/json"
```

### Step 10 — Ask the user what to do

Present the MD location and ask. **NEVER touch Jira without explicit user approval.**

```
┌──────────────────────────────────────────────────────────────────┐
│ MD GENERADO — {endpoint_name}                                   │
├──────────────────────────────────────────────────────────────────┤
│ Guardado en: docs/tickets/{endpoint}_migration.md ✅             │
│                                                                  │
│ ¿Quieres que busque/actualice el ticket en Jira?  (sí/no)       │
└──────────────────────────────────────────────────────────────────┘
```

#### If user says NO → done

> MD guardado en `docs/tickets/{endpoint}_migration.md`. Compártelo con tu PO.

**Stop here — no Jira interaction.**

#### If user says YES → ask for the ticket number

```
Q: ¿Cuál es el número del ticket? (e.g. CEB-5650)
   Si no lo sabes, dime y busco en el epic CEB-5392.
```

**Option A — user gives a ticket number**: Use it directly.
**Option B — user says "no sé" / "búscalo"**: Search Jira:
```bash
curl -s -G "https://jira4novo.atlassian.net/rest/api/3/search" \
  --data-urlencode "jql=project=CEB AND \"Epic Link\"=CEB-5392 AND summary ~ \"{endpoint_name}\"" \
  -H "Authorization: Basic ${AUTH}" \
  -H "Content-Type: application/json"
```

### Step 10b — Fetch ticket and confirm actions

Fetch the ticket details from Jira and show them:

```bash
curl -s "https://jira4novo.atlassian.net/rest/api/3/issue/{TICKET_KEY}" \
  -H "Authorization: Basic ${AUTH}"
```

Present what was found:

```
┌──────────────────────────────────────────────────────────────────┐
│ TICKET ENCONTRADO — {TICKET_KEY}                                │
├──────────────────────────────────────────────────────────────────┤
│ Summary: {current summary}                                       │
│ Status:  {current status}                                        │
│ Assignee: {current assignee or "Sin asignar"}                    │
│ Subtasks: {count existing subtasks}                              │
├──────────────────────────────────────────────────────────────────┤
│ ¿Qué quieres hacer?                                             │
│                                                                  │
│ 1. Actualizar descripción con el MD + crear subtareas por fase   │
│ 2. Solo actualizar descripción (sin subtareas)                   │
│ 3. Solo crear subtareas (sin tocar descripción)                  │
│ 4. Nada — ya vi lo que necesitaba                                │
│                                                                  │
│ ¿A quién se le asigna el ticket y las subtareas?                 │
│   (email o nombre en Jira, o "sin asignar")                      │
└──────────────────────────────────────────────────────────────────┘
```

**If user picks 4** → done
**If user picks 1, 2, or 3** → proceed to Step 11 with the selected actions
**Assignee** → use the Jira accountId lookup:

```bash
# Find accountId by email
curl -s -G "https://jira4novo.atlassian.net/rest/api/3/user/search" \
  --data-urlencode "query={email_or_name}" \
  -H "Authorization: Basic ${AUTH}"
```

### Step 10c — If ticket NOT found in Jira

```
┌──────────────────────────────────────────────────────────────────┐
│ TICKET NO ENCONTRADO — {TICKET_KEY or search term}              │
├──────────────────────────────────────────────────────────────────┤
│ No encontré ese ticket en Jira.                                  │
│                                                                  │
│ ¿Qué quieres hacer?                                             │
│ 1. Crear el ticket en Jira (con la HU del MD) + subtareas       │
│ 2. Nada — solo quiero el MD para dárselo al PO                   │
│                                                                  │
│ Si eliges 1:                                                     │
│ ¿A quién se le asigna? (email o nombre, o "sin asignar")         │
└──────────────────────────────────────────────────────────────────┘
```

**If user picks 2** → done:
> MD guardado en `docs/tickets/{endpoint}_migration.md`. Compártelo con tu PO para que cree el ticket.

**If user picks 1** → proceed to Step 11 (create + subtasks)

### Step 11 — Jira Integration (only after user approval)

**NEVER touch Jira without explicit user approval from Step 10.**

If the user provided an assignee, resolve their accountId first:
```bash
curl -s -G "https://jira4novo.atlassian.net/rest/api/3/user/search" \
  --data-urlencode "query={email_or_name}" \
  -H "Authorization: Basic ${AUTH}"
```
Use the `accountId` from the response. If "sin asignar" → omit the `assignee` field.

#### 11a. If ticket exists → Update description (and optionally assignee)

```bash
curl -s -X PUT \
  "https://jira4novo.atlassian.net/rest/api/3/issue/{TICKET_KEY}" \
  -H "Authorization: Basic ${AUTH}" \
  -H "Content-Type: application/json" \
  --data '{
    "fields": {
      "description": {
        "type": "doc",
        "version": 1,
        "content": [ ... ADF content from generated MD ... ]
      },
      "assignee": {"accountId": "{resolved_account_id}"}
    }
  }'
```

#### 11b. If ticket does NOT exist → Create it

```bash
curl -s -X POST \
  "https://jira4novo.atlassian.net/rest/api/3/issue" \
  -H "Authorization: Basic ${AUTH}" \
  -H "Content-Type: application/json" \
  --data '{
    "fields": {
      "project": {"key": "CEB"},
      "issuetype": {"id": "10001"},
      "summary": "Migración: {endpoint_name} (Java → Go)",
      "description": { ... ADF content from generated MD ... },
      "assignee": {"accountId": "{resolved_account_id}"},
      "customfield_10014": "CEB-5392",
      "customfield_10350": [{"id": "b9569885-e595-4937-a457-571b3bca30b1:24"}],
      "customfield_10627": {"id": "11854"},
      "customfield_10495": [{"id": "11672"}],
      "customfield_10189": {"id": "11388"},
      "customfield_12489": {"id": "13836"},
      "customfield_10726": {"id": "11962"},
      "customfield_12389": {"id": "13661"},
      "customfield_10370": "Zinli"
    }
  }'
```

#### 11c. Create subtasks (if user chose option with subtasks)

First, check for existing subtasks to avoid duplicates:

```bash
curl -s -G "https://jira4novo.atlassian.net/rest/api/3/search" \
  --data-urlencode "jql=parent={TICKET_KEY} AND issuetype=Sub-tarea" \
  -H "Authorization: Basic ${AUTH}"
```

- If subtasks already exist with `[Phase N]` prefix → **skip**, report which exist
- If some phases are missing → **create only the missing ones**
- If no subtasks exist → **create all**

Subtask title format:
```
[Phase {N}] {phase_name} — {endpoint_name}
```

Examples:
- `[Phase 1] Domain + Repository — cancelCard`
- `[Phase 2] Service — cancelCard`
- `[Phase 3] Handler + Module Registration — cancelCard`
- `[Phase 4] Docs — cancelCard`

```bash
curl -s -X POST \
  "https://jira4novo.atlassian.net/rest/api/3/issue" \
  -H "Authorization: Basic ${AUTH}" \
  -H "Content-Type: application/json" \
  --data '{
    "fields": {
      "project": {"key": "CEB"},
      "parent": {"key": "{PARENT_TICKET_KEY}"},
      "issuetype": {"name": "Sub-tarea"},
      "summary": "[Phase {N}] {phase_name} — {endpoint_name}",
      "assignee": {"accountId": "{resolved_account_id}"},
      "customfield_10350": [{"id": "b9569885-e595-4937-a457-571b3bca30b1:24"}],
      "customfield_10627": {"id": "11854"},
      "customfield_10495": [{"id": "11672"}],
      "customfield_10189": {"id": "11388"},
      "customfield_12489": {"id": "13836"},
      "customfield_10726": {"id": "11962"},
      "customfield_12389": {"id": "13661"},
      "customfield_10370": "Zinli"
    }
  }'
```

#### 11d. Present results

```
┌──────────────────────────────────────────────────────────────────┐
│ JIRA INTEGRATION — {endpoint_name}                              │
├──────────────────────────────────────────────────────────────────┤
│ Parent ticket: {TICKET_KEY} ✅ {created|updated}                │
│                                                                  │
│ Subtasks:                                                        │
│   CEB-5651 [Phase 1] Domain + Repository — cancelCard  ✅ created│
│   CEB-5652 [Phase 2] Service — cancelCard              ✅ created│
│   CEB-5653 [Phase 3] Handler — cancelCard              ✅ created│
│   CEB-5654 [Phase 4] Docs — cancelCard                 ✅ created│
│                                                                  │
│ MD saved to: docs/tickets/cancelCard_migration.md                │
└──────────────────────────────────────────────────────────────────┘
```

#### 11e. Update .migration-context.yaml

After Jira integration, update the endpoint entry:
```yaml
ticket: "CEB-5650"
subtasks:
  - key: "CEB-5651"
    phase: "domain-repository"
    status: "open"
  - key: "CEB-5652"
    phase: "service"
    status: "open"
  - key: "CEB-5653"
    phase: "handler"
    status: "open"
  - key: "CEB-5654"
    phase: "docs"
    status: "open"
```

---

### Ticket Template

The generated MD MUST follow this exact structure (in Spanish — Jira audience is Spanish-speaking):

```markdown
# Migración: {endpoint_name}

**Epic:** CEB-5392 (Migración Zinli Java → Golang)
**Tipo:** Historia
**Módulo Go destino:** {go_module}
**Complejidad estimada:** {simple|medium|complex} ({N} fases estimadas)

---

## Contexto / Motivación

{Qué operación es, en qué servicio Java vive, qué infraestructura Go ya existe
y qué hay que agregar. Si es simétrico a un endpoint ya migrado, mencionarlo.}

---

## Descripción técnica

### Ruta y método

```
{HTTP_METHOD} /core/{module}/v1/{path}
```

{Si usa JWE:}
Body: `{"data": "<JWE compact>"}` — cifrado con RSA-OAEP / RSA-OAEP-256.

{Si es plain:}
Parámetros de ruta: `{list params}`

### Flujo (Java parity — `{JavaClass}.{javaMethod}`)

1. {Paso 1 — validación, consulta, llamada externa, etc.}
2. {Paso 2}
   - Si falla → error `{code}`: "{message}"
3. {Paso N}

### Request {(body JWE-descifrado) si aplica}

| Campo | Tipo | Requerido | Default | Notas |
|-------|------|-----------|---------|-------|
| {field} | {type} | {Sí/No} | {default} | {notas} |

### Response {(JWE cifrado) si aplica}

```json
{
  "rc": "0",
  "msg": "PROCESS OK",
  ...
}
```

### Errores de negocio

| Código | Condición | Mensaje |
|--------|-----------|---------|
| {code} | {when it fires} | {exact message from properties} |

### Tablas Oracle involucradas

| Tabla | Operación | Campos clave |
|-------|-----------|--------------|
| {TABLE} | {SELECT/INSERT/UPDATE} | {key columns} |

### Servicios externos

| Servicio | Método | Path | Propósito |
|----------|--------|------|-----------|
| {name} | {POST/GET} | {path} | {purpose} |

---

## Archivos a crear / modificar

```
internal/modules/{module}/
  domain/dto.go           ← {descripción}
  repository/queries.go   ← {descripción}
  repository/sql_repo.go  ← {descripción}
  service/service.go      ← {descripción}
  handlers/handler.go     ← {descripción}
  module.go               ← {descripción}
```

**Reutilizar (NO duplicar):**
- {Lista de helpers, clients, utils que ya existen en Go}

---

## Fases estimadas

| Fase | Branch | Entrega | Est. archivos | Est. líneas |
|------|--------|---------|---------------|-------------|
| 1 | feature/CEB-XXXX-domain-repository | DTOs + SQL + tests | ~{N} | ~{N} |
| 2 | feature/CEB-XXXX-service | Business logic + tests | ~{N} | ~{N} |
| 3 | feature/CEB-XXXX-handler | HTTP binding + route + tests | ~{N} | ~{N} |
| 4 | feature/CEB-XXXX-docs | Flow docs + PlantUML | ~{N} | ~{N} |

---

## Criterios de aceptación

- [ ] Ruta acepta {request type} y retorna {response type}
- [ ] Cada validación de entrada retorna su código de error exacto
- [ ] {Criterio específico del endpoint — estados de tarjeta, montos, etc.}
- [ ] {Criterio sobre servicios externos}
- [ ] {Criterio sobre estado en Oracle tras éxito/rechazo}
- [ ] `make check` limpio; cobertura ≥ 85%

## Definition of Done

- [ ] PR revisado y aprobado por fase
- [ ] `make check` limpio (0 lint issues, 0 race conditions, cobertura ≥ 85%)
- [ ] Códigos de error verificados contra `RESPONSE_CODES.properties` de Java
- [ ] Sin duplicación de lógica ya existente
- [ ] go-bricks utilizado en cada capa (no reinventar)
- [ ] Ticket de QA creado con flujo completo (happy path + tabla de errores)

## Notas técnicas / Dependencias

- {Helpers/utils ya existentes que se reutilizan}
- {Constantes nuevas a agregar}
- {Comportamientos fuera de scope}
- {Advertencias o puntos a confirmar ⚠️}
```

### Rules for ticket generation

- **Read Java source FIRST** — never guess constants, URLs, field names, error messages
- **Error messages are IMMUTABLE** — copy them exactly from properties files
- **Identify what exists in Go** — list what to reuse, not recreate
- **Estimate phases realistically** — based on 400 lines / 10 files per phase limit
- **All Go code must use go-bricks** — mention this in the DoD
- **Write in Spanish** — the PO and Jira audience reads Spanish
- **ALWAYS write the file with Write tool** — NEVER just show content in chat and say "copy it". The MD MUST be saved to `docs/tickets/{endpoint}_migration.md` using the Write tool BEFORE doing anything else. This is a HARD REQUIREMENT.
- **Save to `docs/tickets/`** — create the directory if it doesn't exist (`mkdir -p docs/tickets`)
- **Never create duplicate subtasks** — always check existing children first
- **Subtask titles are just the phase name** — no description body needed, devs use `/migrate`
- **Update .migration-context.yaml** — always sync ticket and subtask keys back to YAML

---

## Rules

- **NEVER guess file paths** — always ask the user
- **NEVER skip properties files** — error codes and messages live there
- **After EVERY answer, ask "Want to add more?"** — the user may have multiple items
- **If "I don't know"** → mark as `TBD` and flag as risk
- **The context file should be gitignored** — add to `.gitignore` if not already
- **This skill does NOT write Go code** — it only collects and saves context
- **Preserve existing entries on re-invoke** — only add/update, never remove unless asked
- **go-bricks is MANDATORY** — every migration must use go-bricks patterns; the mapping section is required
- **Endpoint inventory must be complete** — every endpoint in the source must be listed, even if not yet planned for migration
