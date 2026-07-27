---
name: go-dev-technical
description: "Go technical quality for go-bricks services — two subcommands: (1) /go-dev-technical review <PR_URL> [LANG] for PR review with go-bricks validation, rawQuery/SQL safety, reuse checks, and layer discipline; (2) /go-dev-technical scan <path> [LANG] for project-wide anti-pattern scan, unused go-bricks features, and rawQuery audit. Catches reinvented types, raw DB/HTTP usage, wrong layer boundaries, SQL injection risks (Raw/Expr/fmt.Sprintf), error handling bugs, resource leaks, concurrency bugs, and missing go-bricks patterns."
license: MIT
metadata:
  author: galopez-shark
  version: "2.0.0"
  domain: review
  triggers: go-dev-technical, go dev technical, go technical review, go-bricks review, go-bricks scan
  role: specialist
  scope: code-review
  output-format: report
  related-skills: novo-legacy-migration-endpoint, go-bricks-modules
---

# Go Dev Technical (go-bricks)

Technical quality skill for Go services built on go-bricks. Two modes:
- **review** — extends NKH1 `common:pr-review` with go-bricks framework validation + rawQuery safety
- **scan** — project-wide audit for anti-patterns, unused go-bricks features, and SQL safety

## Usage

### Subcommands

This skill supports two subcommands:

#### 1. `/go-dev-technical review <PR_URL> [LANG]` — Full PR review

Reviews a GitHub pull request for go-bricks compliance, security, and code quality.

- `LANG` is an optional ISO language code: `EN`, `ES`, `PT`, etc.
- **Default language is Spanish (`ES`)** — if no `LANG` is provided, the entire
  report (headings, descriptions, fix suggestions, verdict) MUST be written in Spanish.
- When `LANG=EN` is passed, write the report in English.
- Section titles in the markdown template (## Bloqueadores, ## Debe corregirse, etc.)
  and the go-bricks gate table header labels MUST also be translated to the target language.
- Code snippets, Go identifiers, and file paths are always in English (they are code).

Examples:
- `/go-dev-technical review https://github.com/novopayment/multitenant-banking-api-be-go/pull/27` → report in **Spanish**
- `/go-dev-technical review https://github.com/novopayment/multitenant-banking-api-be-go/pull/27 EN` → report in **English**

The `<PR_URL>` is the GitHub pull request URL. The skill will:
1. Fetch the PR diff
2. Run NKH1 standard review
3. Run go-bricks validation checks (including rawQuery/SQL safety)
4. Report combined findings in the requested language

#### 2. `/go-dev-technical scan <path> [LANG]` — Project anti-pattern & go-bricks audit

Scans a local codebase for anti-patterns, rawQuery safety issues, and unused go-bricks features.

- `path` is the local directory to scan (absolute or relative path)
- `LANG` is an optional ISO language code: `EN`, `ES`, `PT`, etc. (default: `ES`)

**Scan covers three categories:**

**A. Anti-patterns** (things that should use go-bricks but don't):
- Raw DB usage: `sql.DB`, `sql.Open`, `sql.Conn` → should use `database.Interface`
- Raw HTTP client: `http.Client`, `http.Get`, `http.Post` → should use `httpclient.Client`
- Raw echo context: `echo.Context` in handlers → should use `server.HandlerContext`
- Raw logging: `log.Printf`, `fmt.Printf` → should use `logger.Logger`
- Raw JSON response: `c.JSON`, `c.String` → should use `server.NewResult`
- Layer boundary violations: service importing server, handler importing database
- Error handling bugs: ignored errors, lost error chain, shadowed err
- Resource leaks: unclosed HTTP bodies, SQL rows, file handles
- Concurrency bugs: goroutines without context, shared state without mutex

**B. rawQuery / SQL safety audit** (security-critical):
- `fmt.Sprintf` with SQL keywords → SQL injection risk
- String concatenation into SQL → SQL injection risk
- `f.Raw()` / `jf.Raw()` without parameterized args → unsafe escape hatch
- `qb.Expr()` / `MustExpr()` with interpolated user input → injection vector
- Dynamic identifiers (table/column names) without allowlist → injection vector
- Raw SQL `const` without documenting WHY the builder can't express it

**C. Unused go-bricks features** (leveraging the framework fully):
- QueryBuilder available but queries still use raw `const` SQL
- `Entity[T]` defined but not used (dead scaffolding)
- `httpclient` features not used (retry, error classification)
- `mocks.MockDatabase` / `fixtures.NewMockRows` not used in tests
- `server.NewResult` / error types not used in handlers
- Transaction helpers not used (`db.Begin`, `MockTx`)
- `f.Exists()`, `f.InSubquery()` for subqueries instead of raw SQL
- `InnerJoinOn` / `LeftJoinOn` + `JoinFilter` for JOINs instead of raw SQL

Examples:
- `/go-dev-technical scan internal/modules/accounts` → scan accounts module, report in **Spanish**
- `/go-dev-technical scan . EN` → scan entire project, report in **English**

The scan will:
1. Search for anti-patterns and rawQuery risks using grep patterns
2. Explore go-bricks source to find unused features applicable to the scanned code
3. Report findings with file:line evidence, categorized by severity
4. Suggest migration to go-bricks patterns where applicable

#### 3. `/go-dev-technical help` — Help card

```text
go-dev-technical — Technical quality for Go go-bricks services.

SUBCOMMANDS
  /go-dev-technical review <PR_URL> [LANG]
      Full PR review: NKH1 standard + go-bricks validation + rawQuery safety + bug hunting.
      Default language: Spanish (ES). Pass EN for English.

  /go-dev-technical scan <path> [LANG]
      Project-wide audit: rawQuery safety, unused go-bricks features, anti-patterns, layer
      violations, error handling bugs, resource leaks. Reports with file:line evidence.

  /go-dev-technical help
      This help card.

KEY RULES
  - go-bricks is always the priority: if the framework provides it, use it.
  - rawQuery/Raw()/Expr() are escape hatches, not defaults — flag every usage.
  - SQL safety is a BLOCKER: fmt.Sprintf+SQL, string concat+SQL, Raw() without params.
  - All findings must have file:line evidence and concrete failure scenario.
```

## How to get the diff (MANDATORY — never guess the branch)

The PR URL is the source of truth. You MUST resolve the actual PR branch before
reviewing — never assume which branch a PR number corresponds to.

**CRITICAL: ALWAYS re-fetch the PR ref** — even if `pr-<N>` already exists locally.
The author may have pushed new commits since the last fetch. A stale ref means
reviewing old code and missing fixes. Use `--force` to overwrite the local ref.

**Step 1 — Resolve the PR ref locally** (works even without `gh` auth):
```bash
# ALWAYS force-fetch to get the latest commits — never skip this step
git fetch origin refs/pull/<PR_NUMBER>/head:pr-<PR_NUMBER> --force
# Now pr-<PR_NUMBER> is a local ref pointing to the exact PR HEAD
```

**Step 2 — Get the diff against the base branch**:
```bash
git diff origin/main...pr-<PR_NUMBER> --stat
git diff origin/main...pr-<PR_NUMBER>
```

**Step 3 — Read full files from the PR branch** (for context):
```bash
git show pr-<PR_NUMBER>:<file_path>
```

**Alternative** (only if `gh` auth works):
```bash
gh pr view <PR_NUMBER> --json title,headRefName,additions,deletions,changedFiles
gh pr diff <PR_NUMBER>
```

**RULE**: Never use `git branch -r` to guess which branch a PR belongs to. Always
use `git fetch origin refs/pull/<N>/head` or `gh pr view` to resolve the exact ref.
A wrong branch means a wrong review — this is a hard rule, not a suggestion.

---

## Anti-racionalización (NO saltar pasos)

Antes de empezar, rechazar estos atajos mentales:

| Racionalización | Por qué está mal | Acción requerida |
|-----------------|-------------------|------------------|
| "PR pequeño, revisión rápida" | Heartbleed fueron 2 líneas | Clasificar por RIESGO, no por tamaño |
| "Solo es un refactor, no hay impacto" | Los refactors rompen invariantes | Analizar como riesgo ALTO hasta probar lo contrario |
| "Los tests pasan, está bien" | Los tests pueden ser tautológicos o cubrir solo el happy path | Verificar que los tests fallarían sin el cambio |
| "Conozco este codebase" | La familiaridad crea puntos ciegos | Seguir el checklist de todas formas |
| "El autor es experimentado" | Revisar el código, no la reputación | Aplicar los mismos criterios siempre |

---

## Review order

### Phase 1 — NKH1 standard (common:pr-review)

Run the full NKH1 review first:
1. **Sizing**: ≤400 LOC, ≤10 files, one problem per PR
2. **Title**: Conventional Commit, ≤72 chars, no Jira ID in title
3. **Security & PCI**: no secrets, PAN, CVV in code/logs/tests; tenant isolation
4. **Correctness**: edge cases, error paths, money math (integer minor units)
5. **Contracts**: API compatibility, response codes, DB migration safety
6. **Tests**: ≥70% coverage on changed code, error paths covered
7. **Style**: defer to linters (golangci-lint, gofmt, staticcheck)

### Phase 2 — Bug hunting & code smells (Go-specific)

Analyze the diff for common Go bugs and code smells. These are correctness
issues that linters often miss. Run BEFORE go-bricks checks.

### Phase 3 — go-bricks validation (this skill adds)

Two sub-phases:
- **3a — Anti-patterns**: check that the PR doesn't reinvent go-bricks types
  or break layer boundaries (blockers).
- **3b — Discovery**: actively explore go-bricks source to find utilities,
  helpers, or patterns that the PR COULD be using but isn't. This is not about
  blocking — it's about leveraging go-bricks' full potential.

### Phase 4 — Scope & evidence verification

After all checks, verify scope containment and evidence quality.

---

## Bug hunting & code smells (Phase 2)

These checks target correctness bugs and code smells that linters often miss.
Every finding MUST cite file:line and a concrete failure scenario.

**Developer-explicit findings**: When reporting bugs and should-fix items, write
them as a developer would explain to another developer in a PR comment. Include:
- The exact code that's wrong (quote the line)
- What happens at runtime (e.g., "this panics with nil pointer dereference when...")
- The fix as a concrete code diff (before → after)
- Why the fix is correct (e.g., "because `%w` preserves the error chain for `errors.Is()`")

Bad: "Error handling could be improved"
Good: "`sql_repository.go:45` — `fmt.Errorf("failed: %s", err)` loses the error
chain. Callers using `errors.Is(err, ErrNotFound)` will get `false` because `%s`
stringifies instead of wrapping. Fix: `fmt.Errorf("failed: %w", err)`"

### 11. Error handling bugs (BLOCKER)

```bash
# Ignored errors — the returned error is assigned to _ or not checked
grep -n "_ = .*\.\(Do\|Query\|Exec\|Close\|Scan\|Decode\|Unmarshal\)" <changed-files> --include="*.go" | grep -v _test.go

# Error checked but original error lost (wrapped without %w)
grep -n 'fmt\.Errorf.*[^%]"' <changed-files> --include="*.go" | grep -v "%w" | grep -v _test.go

# Shadowed err in nested scope (re-declares err with := inside an if/for that already has err)
# Manual inspection: look for `err :=` inside a block that has an outer `err`
```

Flag:
- **Swallowed errors**: `_ = rows.Close()` — an error during Close can mask data loss
- **Lost error chain**: `fmt.Errorf("failed: %s", err)` instead of `%w` — breaks `errors.Is/As`
- **Shadowed err**: inner `:=` silently discards outer err; use `=` instead
- **Nil pointer after error check**: `if err != nil { ... }` followed by using the value without checking `nil`
- **Deferred Close without error check**: `defer resp.Body.Close()` — should check or log the error

### 12. Concurrency bugs (BLOCKER)

```bash
# Goroutine leaks — goroutine started without cancellation path
grep -n "go func\|go .*(" <changed-files> --include="*.go" | grep -v _test.go

# Missing mutex for shared state
grep -n "sync\.Mutex\|sync\.RWMutex" <changed-files> --include="*.go"
```

Flag:
- **Goroutine without context**: `go func()` that doesn't receive `ctx` or a done channel
- **Shared state without sync**: struct fields accessed from multiple goroutines without mutex
- **Channel not closed**: producer goroutine that never closes the channel (consumer blocks forever)
- **Race-prone map**: concurrent `map` read/write without `sync.Mutex` or `sync.Map`

### 13. Resource leaks (BLOCKER)

```bash
# HTTP response body not closed
grep -n "\.Do(\|\.Get(\|\.Post(" <changed-files> --include="*.go" | grep -v _test.go
# Then verify each has a defer res.Body.Close() nearby

# SQL rows not closed
grep -n "\.Query\|\.QueryRow\|\.QueryContext" <changed-files> --include="*.go" | grep -v _test.go
# Then verify each has defer rows.Close()

# File handles not closed
grep -n "os\.Open\|os\.Create" <changed-files> --include="*.go" | grep -v _test.go
```

Flag:
- **Response body leak**: `http.Do()` result without `defer res.Body.Close()`
- **SQL rows leak**: `db.Query()` without `defer rows.Close()`
- **File handle leak**: `os.Open()` without `defer f.Close()`

### 14. Fail-closed validation (SHOULD-FIX)

When an operation fails (network timeout, parse failure, API error), the code
must deny/fail safely, not silently proceed with stale or empty data.

Flag:
- **Silent fallback**: catch block returns empty/default data instead of propagating the error
- **Missing validation on external response**: external API response parsed without checking status
- **Stale cache on error**: cache miss + fetch error → returns stale value without logging

### 15. Test quality (SHOULD-FIX)

Go beyond "tests exist" — verify tests are meaningful:

- [ ] **Regression value**: would the test FAIL if the production code it targets were removed?
- [ ] **No mock-only assertions**: test asserts on real behavior, not just that a mock was called
- [ ] **Error paths covered**: not just happy path — test what happens when the DB is down, API returns 500, input is malformed
- [ ] **No tautological assertions**: `assert.Equal(t, result, result)` or asserting the mock's return value
- [ ] **Complete mocks**: mock objects mirror the full shape of the real object, not just the fields the author expected
- [ ] **No weakened assertions**: existing assertions not removed or relaxed to make tests pass

```bash
# Check if tests were weakened — removed assertions
git diff origin/main...pr-<N> -- "*_test.go" | grep "^-.*assert\|^-.*require" | grep -v "^---"
```

---

## go-bricks checks

### 1. No reinvented types (BLOCKER)

If go-bricks provides it, use it. Grep the diff for these anti-patterns:

```bash
# Raw DB (should use database.Interface)
grep -rn "sql\.DB\|sql\.Open\|sql\.Conn" <changed-files> --include="*.go" | grep -v _test.go

# Raw HTTP client (should use httpclient.Client)
grep -rn "http\.Client\|http\.Get\|http\.Post\|http\.NewRequest" <changed-files> --include="*.go" | grep -v _test.go

# Raw echo context (should use server.HandlerContext)
grep -rn "echo\.Context" <changed-files>/handlers/ --include="*.go" | grep -v _test.go

# Raw fmt/log (should use logger.Logger via zerolog)
grep -rn "log\.Printf\|log\.Println\|fmt\.Printf\|fmt\.Println" <changed-files> --include="*.go" | grep -v _test.go

# Raw JSON response (should use server.NewResult / plataform.NovoResult)
grep -rn "c\.JSON\|c\.String" <changed-files>/handlers/ --include="*.go" | grep -v _test.go

# Custom mock DB (should use mocks.MockDatabase / mocks.MockTx)
grep -rn "type Mock.*Database\|type mock.*DB\|type fake.*DB" <changed-files> --include="*_test.go"

# Custom mock rows (should use fixtures.NewMockRows)
grep -rn "type Mock.*Rows\|type mock.*Rows\|type fake.*Rows" <changed-files> --include="*_test.go"
```

All must return **0 matches** (except legitimate type assertions in tests).

**Finding format**: "Raw `X` used — replace with go-bricks `Y`" → BLOCKER.

### 1b. rawQuery / SQL safety (BLOCKER)

**CRITICAL SECURITY** — SQL injection (CWE-89, OWASP Top 10). go-bricks provides
QueryBuilder with parameterized queries as the DEFAULT. Any escape from that path
(Raw, Expr, raw const) requires justification and safe patterns.

#### Tier 1 — BLOCKER (SQL injection risk)

```bash
# fmt.Sprintf / Fprintf with SQL keywords — INJECTION VECTOR
grep -rn "fmt\.Sprintf.*\(SELECT\|INSERT\|UPDATE\|DELETE\|WHERE\|FROM\|JOIN\)" <path> --include="*.go" | grep -v _test.go

# String concatenation into SQL — INJECTION VECTOR
grep -rn '".*SELECT.*".*+\|".*INSERT.*".*+\|".*UPDATE.*".*+\|".*DELETE.*".*+' <path> --include="*.go" | grep -v _test.go

# strings.Replace / ReplaceAll on SQL templates — INJECTION VECTOR
grep -rn "strings\.Replace.*\(SELECT\|INSERT\|UPDATE\|DELETE\|WHERE\)" <path> --include="*.go" | grep -v _test.go

# Raw() and Expr() usages — manual verification needed
grep -rn "\.Raw(\|\.Expr(\|MustExpr(" <path> --include="*.go" | grep -v _test.go
```

For every `Raw()` / `Expr()` / `MustExpr()` hit, verify:
1. The SQL string is a **constant** or developer-controlled → SAFE
2. Any dynamic values go through `args ...any` (placeholders) → SAFE
3. A variable touches the SQL string itself (`fmt.Sprintf`, `+`, etc.) → **BLOCKER**

**BAD (SQL injection vulnerable):**
```go
// BLOCKER: fmt.Sprintf with user input in SQL
query := fmt.Sprintf("SELECT * FROM users WHERE id = %s", userID)

// BLOCKER: string concatenation
query := "SELECT * FROM users WHERE name = '" + userName + "'"

// BLOCKER: variable in Raw() SQL string
f.Raw(fmt.Sprintf("UPPER(%s) = ?", columnName), value)

// BLOCKER: unparameterized Raw()
f.Raw("status = '" + status + "'")

// BLOCKER: strings.Replace on SQL template
query := strings.ReplaceAll(tmpl, "{{status}}", status)
```

#### Tier 2 — SHOULD-FIX (unnecessary escape hatch)

Raw SQL `const` or `Raw()`/`Expr()` that the QueryBuilder CAN express:
```bash
# Raw SQL const in repository — check if builder can express it
grep -rn "const.*=.*\"SELECT\|const.*=.*\"INSERT\|const.*=.*\"UPDATE" <path>/repository/ --include="*.go"
```

For each, compare against QueryBuilder capabilities (see decision tree below).

#### Tier 3 — NIT (missing documentation)

Every `Raw()` / `Expr()` / raw SQL `const` SHOULD have a comment explaining WHY
the QueryBuilder cannot express the query. Missing comment = NIT.

#### go-bricks QueryBuilder: the safe default

**Use QueryBuilder BEFORE reaching for Raw()/Expr()/raw const:**

| Need | QueryBuilder method | Escape hatch |
|------|--------------------|------------------------------------|
| Simple CRUD | `Select`, `Insert`, `Update`, `Delete` | — |
| WHERE conditions | `f.Eq()`, `f.In()`, `f.Like()`, `f.Between()`, `f.And()`, `f.Or()`, `f.Not()` | `f.Raw(condition, args...)` |
| JOINs | `InnerJoinOn()`, `LeftJoinOn()`, `RightJoinOn()` + `jf.EqColumn()`, `jf.Eq()` | `jf.Raw(condition, args...)` |
| Complex expressions | `qb.Expr("COUNT(*)", "alias")`, `qb.MustExpr(...)` | — |
| Table aliases | `dbtypes.MustTable(name).MustAs("alias")` | — |
| Pagination | `Paginate(page, size)` | — |
| Subqueries | `f.Exists(subquery)`, `f.InSubquery(col, subquery)` | — |
| UNION / CTE / PL/SQL | — (not supported) | Raw SQL `const` + `sql.Named()` |

**Safe usage of Raw() (when builder can't express it):**
```go
// GOOD: Raw() with parameterized args — values never in SQL string
f.Raw("UPPER(name) = ?", nameValue)
f.Raw("ST_Distance(location, ?) < 1000", point)
jf.Raw("users.id = profiles.user_id AND profiles.type = ?", "primary")

// GOOD: Expr() for static SQL expressions (no user input)
qb.Expr("COUNT(*)", "total")
qb.MustExpr("TO_CHAR(created_at, 'YYYY-MM-DD')", "date_str")

// GOOD: raw const for UNION (builder doesn't support it)
// QueryBuilder does not support UNION — raw SQL with named params
const queryUnion = `SELECT id FROM active_users WHERE status = :status
UNION ALL
SELECT id FROM archived_users WHERE status = :status`
```

**GOOD (safe with go-bricks QueryBuilder):**
```go
qb := database.NewQueryBuilder(db.DatabaseType())
f := qb.Filter()

sql, args, _ := qb.Select("id", "name", "email").
    From("users").
    Where(f.Eq("id", userID)).
    ToSQL()

rows, err := db.Query(ctx, sql, args...)
```

**go-bricks QueryBuilder advantages:**
- Vendor-aware: auto-handles placeholder differences (`:1` vs `$1` vs `?`)
- Reserved word quoting: Oracle keywords like `NUMBER`, `DATE` auto-quoted
- Composable: Filter, JoinFilter, OrderBy, Paginate, Subquery
- No string formatting: values passed as separate args, never interpolated
- JOINs built-in: `InnerJoinOn` + `JoinFilter` — NOT a valid excuse for raw const

#### Dynamic identifiers (table/column names)

Bind parameters (`?`, `:1`, `sql.Named`) protect **values only**, not identifiers.
If a table or column name must vary at runtime, use an **allowlist**:
```go
allowed := map[string]bool{"name": true, "email": true, "phone": true}
if !allowed[col] {
    return fmt.Errorf("invalid column: %s", col)
}
query := fmt.Sprintf("SELECT %s FROM users WHERE id = :1", col)
```

Without an allowlist, dynamic identifiers are a BLOCKER (identifier injection).

#### Decision tree for every SQL usage

```
Is the query expressible with QueryBuilder?
├── YES → Use QueryBuilder + Entity[T] (DEFAULT — no exceptions)
└── NO → Is it a WHERE/JOIN condition the builder can't express?
    ├── YES → f.Raw(condition, args...) or jf.Raw(condition, args...)
    │         ALL dynamic values as args (placeholders, never in SQL string)
    │         + comment: WHY builder can't express it
    └── NO → Is it UNION/CTE/PL/SQL/DDL?
        ├── YES → Raw SQL const + sql.Named() for params
        │         + comment: "QueryBuilder does not support X"
        └── NO → Builder probably CAN express it — try harder
```

#### rawQuery audit table (for scan reports)

When running `/go-dev-technical scan`, include a rawQuery audit table:

| # | File | Type | Risk | Detail |
|---|------|------|------|--------|
| 1 | `repo/queries.go:15` | `f.Raw()` | ✅ Safe | Args parameterized, static SQL |
| 2 | `repo/legacy.go:30` | `fmt.Sprintf+SQL` | ❌ BLOCKER | SQL injection — user input in SQL string |
| 3 | `repo/queries.go:45` | raw const | ⚠️ Migratable | Builder can express this JOIN |
| 4 | `repo/queries.go:80` | raw const UNION | ✅ Justified | Builder doesn't support UNION |
| 5 | `repo/search.go:20` | `qb.Expr()` | ✅ Safe | Static expression, no user input |

### 2. Layer boundaries (BLOCKER)

go-bricks modules enforce strict layering. Check the imports:

| Layer | MUST NOT import | Why |
|-------|----------------|-----|
| **domain/** (dto, errors, constants) | `server`, `database`, `echo`, `httpclient` | Domain is framework-free |
| **repository/** | `server`, `echo`, `httpclient` | Repository only knows DB |
| **service/** | `server`, `echo`, `IAPIError` | Service is HTTP-unaware |
| **handlers/** | `database`, SQL packages | Handlers don't touch DB directly |

```bash
# Service importing server/echo (wrong)
grep -rn "\".*server\"\|\".*echo\"" <module>/service/ --include="*.go" | grep -v _test.go

# Handler importing database (wrong)
grep -rn "\".*database\"\|\"database/sql\"" <module>/handlers/ --include="*.go" | grep -v _test.go

# Domain importing framework types (wrong)
grep -rn "\".*server\"\|\".*echo\"\|\".*database\"\|\".*httpclient\"" <module>/domain/ --include="*.go"
```

**Finding format**: "`service/X.go` imports `server` — service layer must not know about HTTP" → BLOCKER.

### 3. Module wiring (SHOULD-FIX)

Check `module.go` if it's in the diff:

- [ ] Implements `app.Module` interface (`Name()`, `Init()`, `Shutdown()`)
- [ ] `Init()` only wires dependencies — no business logic, no HTTP parsing, no SQL
- [ ] Route registration uses `server.HandlerContext` wrapper, not raw echo handlers
- [ ] Config injection via `deps.Config.InjectInto` or `config:` struct tags
- [ ] Provider modules initialized before consumer modules (check `Init` order)
- [ ] Cross-module deps via interface injection, not concrete imports

### 4. Database patterns (SHOULD-FIX — repository phase)

When the diff touches repository code:

- [ ] Uses `database.Interface` (injected), never creates DB connections
- [ ] SQL queries in `queries.go` as `const`, not inline strings
- [ ] Named placeholders for Oracle (`:param_name`), not positional (`$1`)
- [ ] `fixtures.NewMockRows` for test data, not custom mock structs
- [ ] `mocks.MockDatabase` / `mocks.MockTx` for DB mocks in tests
- [ ] No `sql.NullString` in domain types — convert at the repository boundary
- [ ] Mapper functions in `mapper.go`, not scattered in repository methods

### 4b. Entity/Row mapping pattern (SHOULD-FIX — repository phase)

The project follows the **zinli-business-be-go** entity mapping convention.
When the diff adds DB read/write structs, verify it follows this pattern:

#### Three struct types at different layers

| Struct | Package | Purpose | `sql.Null*`? | Tags |
|--------|---------|---------|-------------|------|
| **Row struct** (`{Name}Row`) | `repository/` | Flat representation of a SELECT result. One field per column. | YES — for nullable cols | None (no tags) |
| **Entity struct** (`{Name}Entity`) | `domain/` | Represents a table row for INSERTs/UPDATEs. Plain types. | NO | None (no tags) |
| **DTO struct** | `domain/` | Clean business object for service/handler layers. | NO | `json:"..."` on API-facing |

#### `ScanColumns()` helper (MANDATORY for multi-column queries)

Every Row struct with more than 3-4 columns MUST have a `ScanColumns()` function
in `repository/mapper.go` that returns `[]any` of pointers:

```go
// mapper.go
type CardRow struct {
    CardID     string         // NOT NULL → plain type
    BlockType  sql.NullString // nullable → sql.Null*
    CreatedAt  sql.NullTime
}

func ScanColumns(row *CardRow) []any {
    return []any{
        &row.CardID,
        &row.BlockType,
        &row.CreatedAt,
    }
}
```

Usage in repository:
```go
var row CardRow
if err = rows.Scan(ScanColumns(&row)...); err != nil { ... }
```

**Why**: `ScanColumns()` keeps the scan-order contract in ONE place. When a query
adds a column, you update `ScanColumns()` and the compiler catches mismatches.
Inline `rows.Scan(&a, &b, &c, ...)` with 20+ args is error-prone and hard to diff.

#### Mapper functions (MANDATORY)

Mappers live in `repository/mapper.go` and convert Row → DTO:

```go
// mapper.go
func (m *CardMapper) ToCardDTO(row *CardRow) *domain.CardDTO {
    return &domain.CardDTO{
        ID:        row.CardID,
        BlockType: row.BlockType.String, // unwrap sql.Null* here
    }
}
```

**Rules**:
- `sql.Null*` unwrapping happens ONLY in the mapper, never in domain or service
- Check `.Valid` when NULL vs empty has business meaning (e.g., nil card = no card)
- Mapper file also holds `ClassifyX()` helpers if the query JOINs multi-type rows

#### Column metadata via `plataform.Entity[T]` (SHOULD-FIX when Entity[T] exists)

**Before writing column constants**, check if `plataform.Entity[T]` exists:
```bash
grep -rn "type Entity\[" internal/plataform/ --include="*.go"
```

If `plataform.Entity[T]` exists in the project, column constants MUST use it
instead of loose `const` strings. Loose constants lose table-grouping and
don't integrate type-safely with the QueryBuilder.

**Wrong** (loose constants in `queries.go`):
```go
const (
    cardTable          = "CARD"
    cardIDColumn       = "CARD_ID"
    cardStatusIDColumn = "CARD_STATUS_ID"
    // 20+ more scattered constants...
)
```

**Correct** (`plataform.Entity[T]` in `domain/entity.go`):
```go
type CardEntityColumns struct {
    CardID    string
    BlockType string
    StatusID  string
}

var CardEntity = plataform.Entity[CardEntityColumns]{
    Name: "CARD",
    Columns: CardEntityColumns{
        CardID:    "CARD_ID",
        BlockType: "BLOCK_TYPE_ID",
        StatusID:  "CARD_STATUS_ID",
    },
}
```

Usage with QueryBuilder:
```go
sql, args, _ := r.qb.Update(domain.CardEntity.Name).
    Set(domain.CardEntity.Columns.StatusID, statusID).
    Where(r.qb.Filter().Eq(domain.CardEntity.Columns.CardID, cardID)).
    ToSQL()
```

**Why**: `Entity[T]` groups columns by table (not scattered across a file),
gives IDE autocomplete (`domain.CardEntity.Columns.` → all CARD columns),
and prevents typos in column name strings. When the project already has the
generic type, not using it is an anti-pattern.

#### What to flag

```bash
# sql.Null* in domain (should only be in repository Row structs)
grep -rn "sql\.Null" <module>/domain/ --include="*.go"

# Inline scan with 5+ fields and no ScanColumns helper
# Manual: look for rows.Scan(&a, &b, &c, &d, &e, ...) in repository without a ScanColumns()

# Missing mapper.go when repository has Row struct
ls <module>/repository/mapper.go 2>/dev/null || echo "MISSING"
```

Flag:
- **`sql.Null*` in domain**: `domain/dto.go` has `sql.NullString` → move to `repository/` Row struct, unwrap in mapper
- **No `ScanColumns()`**: repository scans 10+ columns inline → extract to `ScanColumns()` in `mapper.go`
- **No mapper file**: Row → DTO conversion is inline in `sql_repository.go` → extract to `mapper.go`
- **Scan order mismatch**: `ScanColumns()` field order doesn't match the SELECT column order in `queries.go`
- **Loose column constants**: `queries.go` has 20+ `const cardXColumn = "X"` when `plataform.Entity[T]` exists → refactor to `Entity[T]` grouped by table in `domain/entity.go`

#### 4c. Query construction: QueryBuilder + `Entity[T]` vs raw SQL `const`

`plataform.Entity[T]` + the go-bricks QueryBuilder is the **DEFAULT** for building
queries — **including JOINs**. Follow zinli-business-be-go: table/column identifiers
come from `Entity[T]` metadata and the QueryBuilder assembles the statement.

**The builder DOES cover JOINs** — this is the most common review mistake: do NOT
wave a JOIN through as "must stay a raw const". The builder supports:

- `InnerJoinOn(dbtypes.MustTable(e.Name).MustAs("alias"), jf.EqColumn(...))`
- `LeftJoinOn` / `RightJoinOn` for outer joins
- `jf := qb.JoinFilter()` + `jf.EqColumn("a.col", "b.col")` for join predicates
- `qb.MustExpr("CASE WHEN ... END", "ALIAS")` for CASE / functions / computed columns
- `dbtypes.MustTable(e.Name).MustAs("at")` for table aliases
- `OrderBy`, `Paginate`, `Where(qb.Filter().Eq(e.Columns.X, v))`

Reference: zinli `auth/repository` `GetToken` builds a 3-table INNER JOIN with a
`to_char(...)` expression via `MustExpr`, every identifier from `Entity[T]` metadata.

**Decision tree:**

| Query shape | How to build it |
|-------------|-----------------|
| Single-table CRUD, **or** JOINs (INNER/LEFT/RIGHT), CASE, functions, ORDER BY, pagination | **QueryBuilder + `Entity[T]`** — the default |
| Set operations with no native builder support (`UNION [ALL]`, recursive CTE, vendor PL/SQL) | **Raw SQL `const` + `sql.Named`** — documented as the exception |

**DO flag (SHOULD-FIX):**
- A JOIN query hand-written as a raw `const` when the builder can express it →
  migrate to builder + `Entity[T]`. **A multi-JOIN is NOT an automatic exception.**
- **Two+ `const` queries identical except for the `WHERE`** → collapse into one
  builder construction (shared SELECT + JOINs) that varies only `.Where(...)`.
  Duplicated ~40-line SELECT bodies are a maintenance trap (e.g. a `ByCustomer`
  and a `ByID` variant of the same lookup).
- Table/column name string literals inline when an `Entity[T]` for that table
  exists (or should exist).

**Legitimately keep as `const`**: `UNION ALL`, set-ops, and constructs the builder
cannot emit — note WHY in a comment above the const so the exception is explicit.

#### 4d. Dead shared scaffolding (SHOULD-FIX)

A shared generic/abstraction that exists but is never used is debt, not
infrastructure — and it misleads future authors into thinking a pattern is "in
use" when it is not.

```bash
# Entity[T] defined but never instantiated anywhere → dead scaffolding
grep -rn "type Entity\[" internal/plataform/ --include="*.go"
grep -rln "plataform.Entity\[" internal/ --include="*.go" | grep -v _test.go  # 0 hits = dead
```

Flag:
- **`Entity[T]` defined, zero usages**: the generic exists but no
  `XxxEntityColumnsMetadata` is declared and no query uses it → either **seed** the
  pattern (define metadata for at least the tables the touched module queries, and
  build with it) or **delete** the dead type. SHOULD-FIX, not a blocker.
- Same for any `internal/plataform/` helper/type with no callers.

### 5. HTTP/handler patterns (SHOULD-FIX — handler phase)

When the diff touches handler code:

- [ ] Uses `server.HandlerContext` binding, not raw `echo.Context`
- [ ] Binding struct with `param:`, `query:`, `json:` tags as appropriate
- [ ] Error response via `server.IAPIError` / `apperrors.AppError`, not manual JSON
- [ ] Response via `server.NewResult` or `plataform.NovoResult`, not `c.JSON`
- [ ] Route registered in `module.go`, not self-registered in handler
- [ ] JWE endpoints: flat binding struct with `param:` + `json:"data"` pattern

### 6. External calls (SHOULD-FIX — service phase)

When the diff touches HTTP calls to external services:

- [ ] Uses `httpclient.Client` from go-bricks, not `net/http` directly
- [ ] Timeout configured via config, not hardcoded
- [ ] Context propagated (`ctx` passed through)
- [ ] Response parsed and errors handled (don't ignore non-2xx)
- [ ] Retry logic delegated to httpclient, not custom loops

### 7. Test patterns (SHOULD-FIX)

- [ ] `mocks.MockDatabase` for repository tests, not a real DB or custom mock
- [ ] `fixtures.NewMockRows` to build expected result sets
- [ ] Table-driven tests for service logic (multiple error paths)
- [ ] Handler tests use `httptest.NewRecorder` + echo test context
- [ ] No `time.Sleep` in tests — use channels or deterministic sync
- [ ] Testdata in `testdata_test.go` or `testdata/` directory

### 8. Reuse check (SHOULD-FIX)

Before adding new code, check if it already exists:

```bash
# Check for duplicate error sentinels (same rc code, different name)
grep -rn "Code.*=.*\"-XX\"" internal/plataform/bussines/codes.go
grep -rn "Code.*=.*\"-XX\"" internal/modules/*/domain/errors.go

# Check for duplicate queries (same table, same operation)
grep -rn "FROM.*TABLE_NAME" internal/modules/*/repository/queries.go

# Check for duplicate DTOs (same JSON shape)
grep -rn "type.*struct" internal/modules/*/domain/dto.go
```

Flag if:
- A new error sentinel has the same rc code as an existing one (without justification)
- A new SQL query duplicates an existing one in another module
- A new DTO duplicates fields from an existing shared type
- A helper function reimplements something in `internal/plataform/`

### 8b. File & struct placement (SHOULD-FIX)

Every struct, type, and file must live in the folder that matches its responsibility.
Misplaced types create confusing imports and break the module's layering contract.

**Rules**:

| Type | Belongs in | NOT in |
|------|-----------|--------|
| DTOs for API request/response (`json:` tags) | `domain/dto.go` | `repository/`, `service/`, `handlers/` |
| DTOs for repository input params (write args) | `repository/dto.go` if repo-only; `domain/dto.go` if service also uses it | `repository/interface.go` (mixed with interface def) |
| Row structs for DB scan (`sql.Null*`) | `repository/mapper.go` | `domain/`, `service/` |
| Entity structs for DB writes (column metadata) | `domain/entity.go` | `repository/` (unless repo-internal only) |
| Error sentinels (`ErrNotFound`, `ErrInvalid*`) | `domain/errors.go` | `repository/`, `service/` |
| Business constants (status codes, block types) | `domain/constants.go` | `repository/`, `handlers/` |
| SQL queries as `const` | `repository/queries.go` | inline in `sql_repository.go` |
| Mapper functions (Row → DTO) | `repository/mapper.go` | scattered in `sql_repository.go` |
| Interface definitions | `repository/interface.go`, `service/interface.go` | `domain/` (domain has no interfaces) |

**Why this matters**: When `service/` needs to pass params to `repository/`, it should
import from `domain/` (shared by both layers), not from `repository/` directly. A
`repository.UpdateCardStatusParams` imported by `service/` means service depends on
repository — violating the dependency rule (service → domain ← repository).

**What to flag**:
```bash
# DTOs in repository/ that service/ imports (wrong direction)
grep -rn "repository\." <module>/service/ --include="*.go" | grep -v _test.go | grep -v "CardRepository"

# Structs in wrong package — look for types that don't match their folder's role
grep -rn "type.*Params\|type.*Request\|type.*Response" <module>/repository/ --include="*.go" | grep -v _test.go
```

Flag:
- **DTO in wrong file**: `repository/interface.go` has `UpdateCardStatusParams` mixed with the interface → move to `repository/dto.go` (repo-only params) or `domain/dto.go` (if service needs it too)
- **Query inline**: SQL string built inside `sql_repository.go` → extract to `queries.go` as `const`
- **Mapper scattered**: Row → DTO conversion in `sql_repository.go` → extract to `mapper.go`
- **Error in wrong layer**: error sentinel defined in `repository/` → move to `domain/errors.go`

### 9. Go naming & conventions (SHOULD-FIX)

Check all new identifiers against Go and project conventions:

**Variables & fields:**
- [ ] camelCase for unexported, PascalCase for exported — no snake_case
- [ ] Avoid stuttering: `domain.DomainError` → `domain.Error`; `cards.CardsService` → `cards.Service`
- [ ] Acronyms fully capitalized: `ID` not `Id`, `HTTP` not `Http`, `URL` not `Url`, `SQL` not `Sql`
- [ ] Boolean vars/fields start with `is`, `has`, `can`, `should` — or are adjectives: `valid`, `active`, `blocked`
- [ ] Receiver names: 1-2 letter abbreviation of the type (`s` for Service, `r` for Repository, `h` for Handler) — consistent within the file

**Functions & methods:**
- [ ] Exported functions start with a verb: `Get`, `Create`, `Validate`, `Parse`, `Build`
- [ ] Constructors follow `New{Type}` pattern: `NewService`, `NewRepository`, `NewHandler`
- [ ] Interface methods describe the action: `FindByID`, `Store`, `Delete` — not `DoFind`, `ProcessStore`
- [ ] Error-returning functions: last return is `error`, not mixed in the middle
- [ ] Context is always the first parameter: `func (s *Service) GetCard(ctx context.Context, ...)`

**Types & interfaces:**
- [ ] Interfaces named by behavior (suffix `-er`): `Reader`, `Writer`, `Validator` — or by role: `Repository`, `Service`
- [ ] Single-method interfaces preferred over large ones
- [ ] Structs named as nouns: `Card`, `Account`, `BlockRequest` — not `CardData`, `AccountInfo`
- [ ] Error sentinel vars: `Err` prefix → `ErrNotFound`, `ErrInvalidBlockType`
- [ ] Constants: PascalCase for exported, camelCase for unexported — no `ALL_CAPS` (that's Java/Python)

**Package names:**
- [ ] Short, lowercase, single-word: `domain`, `service`, `handlers` — not `cardService`, `card_handlers`
- [ ] No underscores, no mixedCaps
- [ ] Import alias only when two packages collide

**Files:**
- [ ] snake_case for file names: `block_request.go`, `card_service.go` — not `blockRequest.go`
- [ ] `_test.go` suffix for test files in the same package
- [ ] One primary type per file preferred (small types can share a file like `dto.go`, `errors.go`)

Flag naming violations with a concrete suggestion:

> `[go-bricks]` **Naming**: `cards.CardsService` stutters — rename to `cards.Service`
> `[go-bricks]` **Naming**: Field `BlockTypeId` should be `BlockTypeID` (Go acronym convention)

### 10. Config completeness (NIT)

If the PR adds config consumption (`config:` tags or `deps.Config`):

- [ ] Key exists in both `config.yml` (env vars) and `config.yaml` (local values)
- [ ] New config key follows existing naming convention
- [ ] Sensitive values use env var placeholders, not hardcoded

### 10b. Semantic version bump in config.yml (SHOULD-FIX — REQUIRED on every PR)

**Every PR MUST bump `app.version` in `config.yml` by exactly one patch** (e.g.
`1.7.18` → `1.7.19`), regardless of change type — feat / fix / refactor / docs all
do +1 patch. This is the project's mandatory "semantic up"; the immutable build
that gets promoted `main → DEV → UAT → PRD` is identified by this version, so a PR
without a bump ships the same version twice. `config.yaml` keeps a placeholder
(e.g. `v1.0.0`) and is NOT bumped — only `config.yml` carries the live version.

```bash
# The PR MUST change app.version in config.yml — one patch above main's current value
git diff origin/main...pr-<N> -- config.yml | grep -E '^\+\s*version:'
# Cross-check the base so the bump isn't stale after a rebase/merge:
git show origin/main:config.yml | grep -E '^\s*version:'
```

Flag as ❌ when:
- **No bump**: `app.version` unchanged in the PR → require a +1 patch bump.
- **Stale / wrong increment**: the new value is not exactly one patch above
  `origin/main`'s current `app.version` (common after a rebase or a main merge —
  the version conflict must resolve to `main` + 1, not the branch's old number).
- **Bumped the wrong file**: `config.yaml` changed instead of `config.yml`.

---

## go-bricks discovery (Phase 3b — SHOULD-FIX)

Phase 3a (checks 1-10) catches anti-patterns. Phase 3b actively explores what
go-bricks offers that the PR could leverage. The goal is to maximize the
framework's value — not to block, but to suggest better implementations.

### How to discover

**Step 1 — Identify what the PR is doing** (from the diff):
- Adding HTTP calls? → explore `httpclient` package
- Adding DB queries? → explore `database` package
- Adding error responses? → explore `server` error types
- Adding config? → explore `config` injection
- Adding tests? → explore `mocks`, `fixtures`, `testutil`
- Adding middleware? → explore `server` middleware
- Adding crypto/JWE? → explore `cryptoutil`

**Step 2 — Read go-bricks source for that area**:
```bash
# Find go-bricks module cache path
BRICKS=$(go env GOMODCACHE)/github.com/gaborage/go-bricks@$(grep go-bricks go.mod | awk '{print $2}')

# List all exported types/functions in a package
grep -rn "^func \|^type " $BRICKS/<package>/*.go | grep -v _test.go

# Example: what does httpclient offer?
grep -rn "^func \|^type " $BRICKS/httpclient/*.go | grep -v _test.go

# Example: what error types does server provide?
grep -rn "^func New.*Error\|^type .*Error" $BRICKS/server/*.go | grep -v _test.go

# Example: what test helpers exist?
grep -rn "^func \|^type " $BRICKS/mocks/*.go
grep -rn "^func \|^type " $BRICKS/fixtures/*.go
```

**Step 3 — Compare with what the PR implements**:

For each piece of custom code in the PR, ask:
- Does go-bricks already have a function/type that does this?
- Does go-bricks have a pattern for this that's different from what the PR does?
- Is the PR using a go-bricks type but missing features it offers? (e.g. using
  `httpclient.Client` but not its retry config, or using `database.Interface`
  but not its transaction helpers)

### What to look for (common missed go-bricks features)

| Code is doing... | go-bricks offers... | Where to check |
|-------------------|---------------------|----------------|
| Custom HTTP error wrapping | `httpclient.IsErrorType`, `httpclient.HTTPError`, `httpclient.NetworkError` | `$BRICKS/httpclient/errors.go` |
| Manual retry loops | `httpclient` built-in retry with `MaxRetries` config | `$BRICKS/httpclient/config.go` |
| Custom request building | `httpclient.Request` with Headers, Body, URL | `$BRICKS/httpclient/types.go` |
| Manual JSON response | `server.NewResult`, `server.NewErrorResult` | `$BRICKS/server/result.go` |
| Custom error codes | `server.NewBadRequestError`, `server.NewNotFoundError`, etc. | `$BRICKS/server/errors.go` |
| Manual DB transaction | `database.Interface.Begin()`, `tx.Commit()`, `tx.Rollback()` | `$BRICKS/database/` |
| Custom test DB setup | `mocks.MockDatabase`, `mocks.MockTx`, `fixtures.NewMockRows` | `$BRICKS/mocks/`, `$BRICKS/fixtures/` |
| Manual config reading | `config.InjectInto` with struct tags | `$BRICKS/config/` |
| Custom logging setup | `logger.New`, `logger.Logger` interface | `$BRICKS/logger/` |
| Manual context propagation | go-bricks `httpclient.Do` auto-propagates context | `$BRICKS/httpclient/client.go` |
| Custom health check | `server.HealthCheck` handler | `$BRICKS/server/health.go` |
| Custom middleware | `server.Middleware` interface | `$BRICKS/server/middleware.go` |
| Raw SQL JOIN as const | `InnerJoinOn()`, `LeftJoinOn()` + `JoinFilter` (`jf.EqColumn()`, `jf.Eq()`) | `$BRICKS/database/types/interfaces.go` |
| Raw SQL WHERE with complex conditions | `f.Raw(condition, args...)` with parameterized values | `$BRICKS/database/internal/builder/filter.go` |
| Raw SQL expressions (COUNT, TO_CHAR, CASE) | `qb.Expr(sql, alias)`, `qb.MustExpr(sql, alias)` | `$BRICKS/database/types/expression.go` |
| Raw SQL subquery in WHERE | `f.Exists(subquery)`, `f.InSubquery(col, subquery)` | `$BRICKS/database/types/interfaces.go` |
| Raw SQL table alias | `dbtypes.MustTable(name).MustAs("alias")` | `$BRICKS/database/types/` |

### Reporting go-bricks discovery findings

Use tag `[go-bricks-oportunidad]` (ES) / `[go-bricks-opportunity]` (EN):

> `[go-bricks-oportunidad]` El PR implementa retry manual con `for` loop en
> `client.go:45` — go-bricks `httpclient` ya tiene retry built-in configurable
> vía `MaxRetries`. Usar la configuración nativa simplifica el código y garantiza
> backoff exponencial.

These are **SHOULD-FIX**, not blockers — the code works, but it's not using
the framework's full potential. Exception: if the custom implementation has a
bug that go-bricks' version doesn't (e.g. missing backoff, no jitter), elevate
to **BLOCKER** because the fix is "use go-bricks".

### go-bricks version check (MANDATORY at start)

Before any review, verify go-bricks is on the latest version:
```bash
# Current version in the project
grep 'go-bricks' go.mod

# Latest available (check go proxy)
GOPROXY=https://proxy.golang.org go list -m -versions github.com/gaborage/go-bricks 2>/dev/null | awk '{print $NF}'
```

If the project is behind, note it as a **improvement comment** (not a blocker,
not a should-fix). Include it in the "Comentarios de mejora" section of the report
as context for a future upgrade — never block the PR for a version bump alone.

---

## Scope & evidence verification (Phase 4)

### 16. Scope containment (SHOULD-FIX)

Verify the PR touches only one logical scope. A PR that mixes concerns is
harder to review, test, and revert.

```bash
# List all modules touched by the PR
git diff origin/main...pr-<N> --stat | grep "internal/modules/" | sed 's|internal/modules/\([^/]*\)/.*|\1|' | sort -u

# List all layers touched per module
git diff origin/main...pr-<N> --stat | grep "internal/modules/" | sed 's|internal/modules/[^/]*/\([^/]*\)/.*|\1|' | sort -u
```

Flag:
- **Multi-module PR**: touches `accounts/` AND `cards/` without shared-infra justification
- **Multi-layer PR**: touches `domain/` AND `handlers/` in the same module (should be separate phases)
- **Unrelated changes**: config bump + new feature + test fix in one PR

Exception: changes in `internal/plataform/` (shared infra) that are consumed by the module
changes are acceptable.

### 17. Evidence-based findings (MANDATORY)

Every finding in the report MUST include:
- **Archivo/File**: exact `path/to/file.go:line`
- **Evidencia/Evidence**: the command or code snippet that proves the finding
- **Escenario de fallo/Failure scenario**: concrete inputs → wrong output/crash

A finding without evidence is speculation, not a review finding. If a check
cannot be verified (e.g. tests can't be run, file not accessible), use the
ternary verdict ⚠️ `NO VERIFICADO` instead of guessing.

### Verdict system (ternary)

Each check in the gate summary table uses three states:

| Estado | Significado |
|--------|-------------|
| ✅ | Verificado y correcto |
| ❌ | Verificado y con problemas — citar evidencia |
| ⚠️ | No se pudo verificar — explicar por qué (ej: sin acceso a tests, archivo no accesible) |

A ⚠️ is NOT a pass — it means the reviewer acknowledges a gap. The PR author
should provide evidence or the reviewer should re-check in a follow-up.

---

## Reporting — Markdown output file (in a MACHINE temp dir, never the repo)

The final report MUST be written to a `.md` file so the user can open it and
copy-paste the contents into a GitHub PR comment. **The file goes in a temporary
directory ON THE MACHINE — NEVER inside the reviewed repository** (not `docs/reviews/`,
not anywhere under the repo working tree), so it can never be accidentally committed
and never pollutes the repo's git status.

Target path (in order of preference):
1. The session **scratchpad** directory if one is provided in the environment
   (e.g. `.../scratchpad/pr-{PR_NUMBER}-review.md`) — preferred.
2. Otherwise the OS temp dir: `${TMPDIR:-/tmp}/pr-{PR_NUMBER}-review.md`.

**Steps**:
1. Resolve the temp dir (scratchpad if available, else `$TMPDIR`/`/tmp`).
2. Write the full GFM report to `<tempdir>/pr-{PR_NUMBER}-review.md`.
3. Give the user an OPENABLE reference, not just the raw path: a clickable
   `file://<abs-path>` markdown link AND an open command — `code "<abs-path>"`
   (VS Code) or `open "<abs-path>"` (macOS) — so they can open it in one click.

**Never** write review files inside the reviewed repo, and never `git add`/commit
them. (This is distinct from PR *description* text, which is delivered inline in
chat — see the user's PR-format preference.)

The report language depends on the `LANG` parameter:

- **No `LANG` or `ES`** → Spanish (default)
- **`EN`** → English
- Other codes → use that language

All prose (headings, descriptions, issue explanations, fix suggestions, verdict)
MUST be in the target language. Code snippets, Go identifiers, file paths, and
go-bricks type names stay in English (they are code).

### Template — Spanish (default)

The entire output is ONE markdown block the user can copy-paste into a GitHub
PR comment. It MUST render correctly in GitHub-Flavored Markdown (GFM):
- Use `##` for top sections, `###` for sub-findings
- Use `<details><summary>` to collapse verbose sections (validation table, nits)
- Use task lists (`- [ ]` / `- [x]`) for actionable items
- Use fenced code blocks with language hint (\`\`\`go, \`\`\`bash)
- Tables must have a header separator row (`|---|---|`)
- No raw HTML except `<details>`, `<summary>`, `<br>`
- Emoji are OK for status: ✅ ❌ ⚠️ 🔧 💡

```markdown
## Revisión PR #{number} — {title}

📋 **{count} archivos** | **+{added} / -{removed} líneas** | **Riesgo**: {ALTO/MEDIO/BAJO} | **go-bricks**: v{version}

### ❌ Bloqueadores

> Ninguno / o lista:

**1. `[tag]` {título corto}**
📁 `path/to/file.go:42`
```go
// código problemático (copiado del diff)
```
**Problema**: {explicación en lenguaje developer — qué pasa en runtime}
**Fix**:
```go
// código corregido
```

---

### 🔧 Debe corregirse

- [ ] **`path/to/file.go:42`** — `[tag]` {descripción developer-friendly: qué está mal, qué pasa en runtime, cómo corregir}
- [ ] **`path/to/file.go:80`** — `[tag]` {descripción}

---

### 💡 Oportunidades go-bricks

- [ ] **`path/to/file.go:45`** — `[go-bricks]` {lo que el PR hace manualmente} → usar `{go-bricks type/function}` ({beneficio concreto})

---

### 🔒 Auditoría rawQuery / SQL

| # | Archivo | Tipo | Riesgo | Detalle |
|---|---------|------|--------|---------|
| 1 | `repo/queries.go:15` | `f.Raw()` | ✅ Safe | Args parametrizados |
| 2 | `repo/legacy.go:30` | `fmt.Sprintf+SQL` | ❌ BLOCKER | Inyección SQL |
| 3 | `repo/queries.go:45` | raw const | ⚠️ Migrable | Builder puede expresarlo |

---

### 📌 Para el próximo commit

- {item 1 — forward-looking, no bloquea este PR}
- {item 2}
- go-bricks v{current} → v{latest} disponible

<details>
<summary>📊 Resumen de validación (click para expandir)</summary>

| Verificación | Estado | Notas |
|:--|:--:|:--|
| **go-bricks** | | |
| Sin tipos reinventados | ✅/❌/⚠️ | |
| rawQuery / SQL safety | ✅/❌/⚠️ | |
| Límites de capa correctos | ✅/❌/⚠️ | |
| Cableado de módulo | ✅/N/A | |
| Patrones de BD | ✅/N/A | |
| Entity/Row mapping | ✅/N/A | |
| Construcción queries (builder+Entity vs const) | ✅/❌/N/A | |
| Sin andamiaje muerto (Entity[T] usado) | ✅/❌/N/A | |
| Ubicación archivos/structs | ✅/N/A | |
| Patrones handler | ✅/N/A | |
| Llamadas externas httpclient | ✅/N/A | |
| Patrones de test | ✅/N/A | |
| Sin código duplicado | ✅/❌ | |
| Nombres y convenciones | ✅/❌ | |
| Config completa | ✅/N/A | |
| Version bump en config.yml (+1 patch) | ✅/❌ | |
| **Bugs & code smells** | | |
| Manejo de errores | ✅/❌/⚠️ | |
| Sin bugs de concurrencia | ✅/N/A | |
| Sin resource leaks | ✅/❌/⚠️ | |
| Fail-closed en fallos | ✅/N/A | |
| Calidad de tests | ✅/❌/⚠️ | |
| **go-bricks discovery** | | |
| Versión go-bricks | ⚠️/✅ | |
| Oportunidades go-bricks | ✅/❌ | {N} encontradas |
| **Scope** | | |
| Scope contenido | ✅/❌ | |

</details>

<details>
<summary>📝 Nombres y convenciones</summary>

| # | Archivo | Actual | Sugerido | Regla |
|---|---------|--------|----------|-------|
| — | — | Todas las convenciones seguidas ✅ | — | — |

</details>

**Veredicto**: ✅ Aprobado / ⚠️ No verificado ({razón}) / ❌ {N} bloqueadores pendientes
```

### Template — English (when `LANG=EN`)

```markdown
## PR Review #{number} — {title}

📋 **{count} files** | **+{added} / -{removed} lines** | **Risk**: {HIGH/MEDIUM/LOW} | **go-bricks**: v{version}

### ❌ Blockers

> None / or list:

**1. `[tag]` {short title}**
📁 `path/to/file.go:42`
```go
// problematic code (copied from diff)
```
**Issue**: {developer-language explanation — what happens at runtime}
**Fix**:
```go
// corrected code
```

---

### 🔧 Should fix

- [ ] **`path/to/file.go:42`** — `[tag]` {developer-friendly description: what's wrong, runtime impact, how to fix}
- [ ] **`path/to/file.go:80`** — `[tag]` {description}

---

### 💡 go-bricks opportunities

- [ ] **`path/to/file.go:45`** — `[go-bricks]` {what the PR does manually} → use `{go-bricks type/function}` ({concrete benefit})

---

### 🔒 rawQuery / SQL audit

| # | File | Type | Risk | Detail |
|---|------|------|------|--------|
| 1 | `repo/queries.go:15` | `f.Raw()` | ✅ Safe | Args parameterized |
| 2 | `repo/legacy.go:30` | `fmt.Sprintf+SQL` | ❌ BLOCKER | SQL injection |
| 3 | `repo/queries.go:45` | raw const | ⚠️ Migratable | Builder can express it |

---

### 📌 For the next commit

- {item 1 — forward-looking, doesn't block this PR}
- {item 2}
- go-bricks v{current} → v{latest} available

<details>
<summary>📊 Validation summary (click to expand)</summary>

| Check | Status | Notes |
|:--|:--:|:--|
| **go-bricks** | | |
| No reinvented types | ✅/❌/⚠️ | |
| rawQuery / SQL safety | ✅/❌/⚠️ | |
| Layer boundaries | ✅/❌/⚠️ | |
| Module wiring | ✅/N/A | |
| DB patterns | ✅/N/A | |
| Entity/Row mapping | ✅/N/A | |
| Query construction (builder+Entity vs const) | ✅/❌/N/A | |
| No dead scaffolding (Entity[T] used) | ✅/❌/N/A | |
| File/struct placement | ✅/N/A | |
| Handler patterns | ✅/N/A | |
| External calls httpclient | ✅/N/A | |
| Test patterns | ✅/N/A | |
| No duplicate code | ✅/❌ | |
| Naming & conventions | ✅/❌ | |
| Config complete | ✅/N/A | |
| Version bump in config.yml (+1 patch) | ✅/❌ | |
| **Bugs & code smells** | | |
| Error handling | ✅/❌/⚠️ | |
| No concurrency bugs | ✅/N/A | |
| No resource leaks | ✅/❌/⚠️ | |
| Fail-closed on errors | ✅/N/A | |
| Test quality | ✅/❌/⚠️ | |
| **go-bricks discovery** | | |
| go-bricks version | ⚠️/✅ | |
| go-bricks opportunities | ✅/❌ | {N} found |
| **Scope** | | |
| Scope contained | ✅/❌ | |

</details>

<details>
<summary>📝 Naming & conventions</summary>

| # | File | Current | Suggested | Rule |
|---|------|---------|-----------|------|
| — | — | All conventions followed ✅ | — | — |

</details>

**Verdict**: ✅ Approve / ⚠️ Not verified ({reason}) / ❌ {N} blockers remain
```

Mark checks as N/A when the PR doesn't touch that layer (e.g., domain-only
PR → DB patterns, handler patterns, external calls are all N/A).

The **Naming & conventions** table is always present — even if all names are
correct, show the table with a "Todas las convenciones seguidas ✅" (ES) /
"All naming conventions followed ✅" (EN) row.

File name: `pr-{PR_NUMBER}-review.md` (review) or `scan-{path-slug}-audit.md` (scan).

---

## Scan-specific workflow (scan subcommand)

When running `/go-dev-technical scan <path>`, follow this order:

### Step 1 — Discover go-bricks version and features

```bash
grep 'go-bricks' go.mod
BRICKS=$(go env GOMODCACHE)/github.com/gaborage/go-bricks@$(grep go-bricks go.mod | awk '{print $2}')
```

### Step 2 — Run all anti-pattern checks

Run every grep from sections 1, 1b, 2, 4, 5, 6, 7, 8, 11, 12, 13 against `<path>`.
Replace `<changed-files>` with `<path>` and `<module>` with each module under `<path>`.

### Step 3 — rawQuery deep audit

For every file in `<path>/**/repository/`:

1. Find all raw SQL (`const`, `var`, or inline strings with SQL keywords)
2. Find all `Raw()`, `Expr()`, `MustExpr()` usages
3. For each, determine:
   - Can QueryBuilder express this? (check JOIN, subquery, expression support)
   - Are all dynamic values parameterized (in `args`, never in SQL string)?
   - Is there a comment explaining WHY the builder can't express it?
4. Categorize: ❌ BLOCKER (injection risk) / ⚠️ SHOULD-FIX (builder can replace) / ✅ OK (justified)
5. Build the rawQuery audit table for the report

### Step 4 — Unused go-bricks feature sweep

Compare what the scanned code uses vs what go-bricks provides:

```bash
# What go-bricks packages are imported?
grep -rn "go-bricks" <path> --include="*.go" | grep import | sort -u

# What QueryBuilder features are used?
grep -rn "\.Select\|\.Insert\|\.Update\|\.Delete\|\.InnerJoinOn\|\.LeftJoinOn\|\.Expr\|\.Raw\|\.Paginate\|\.Exists\|\.InSubquery" <path> --include="*.go" | sort -u

# What go-bricks test helpers are used?
grep -rn "MockDatabase\|MockTx\|NewMockRows\|fixtures\." <path> --include="*_test.go" | sort -u

# What go-bricks error types are used?
grep -rn "server\.New.*Error\|NewAppError\|NewBusinessLogicError" <path> --include="*.go" | sort -u
```

For each unused go-bricks feature that applies to the scanned code:
- Identify WHERE in the code it could be used (file:line)
- Explain WHAT go-bricks feature replaces it
- Explain WHY the go-bricks version is better (safety, consistency, less code)

### Step 5 — Report

Use the same template as review but:
- Replace `## Revisión PR #{number}` with `## Auditoría técnica — {path}`
- Remove PR-specific sections (sizing, title, diff, scope containment)
- Include the rawQuery audit table
- Include the unused go-bricks features section
- Include all anti-pattern findings with file:line evidence
