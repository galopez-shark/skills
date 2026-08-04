---
name: go-dev-technical
description: "Technical validator for Go services on go-bricks — stops broken integrations and bad names from reaching production. Two subcommands: (1) /go-dev-technical review <PR_URL> [LANG] runs the toolchain (build/vet/test-cover/golangci-lint/go fix) in an isolated worktree, then validates go-bricks usage, SQL safety, layer boundaries, messaging/bus contracts, error handling, concurrency, resource leaks and naming — proposing a concrete replacement for every bad name; (2) /go-dev-technical scan <path> [LANG] audits an existing codebase and emits a phased remediation roadmap sized to the merge constraints (<=400 lines / <=10 files per phase, one branch per phase from main). Catches silent bus-contract mismatches (exchange/queue/routing-key/EventType typos that publish fine and route nowhere), AutoAck message loss, missing DLQ, non-idempotent consumers, dual-write without outbox, SQL injection (Raw/Expr/fmt.Sprintf), reinvented types, raw net/http and sql.DB, wrong layer boundaries, swallowed errors, goroutine and resource leaks, and stuttering/noise-word/misleading identifiers."
license: MIT
metadata:
  author: galopez-shark
  version: "2.7.0"
  domain: review
  triggers: go-dev-technical, go dev technical, go technical review, go-bricks review, go-bricks scan, validar nombres go, revisar integracion bus, roadmap de remediacion go
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

Scans a local codebase for anti-patterns, rawQuery safety issues, and unused go-bricks
features, and produces a **phased remediation roadmap** (Step 6) sized to the project's
merge constraints — ≤400 new lines and ≤10 files per phase, one branch per phase from
`main`, same discipline as `/migrate`.

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
go-dev-technical — Validador tecnico para servicios Go sobre go-bricks.
Objetivo: que no llegue a produccion una integracion rota (HTTP o bus) ni un
nombre que mienta sobre lo que hace.

SUBCOMANDOS
  /go-dev-technical review <PR_URL> [LANG]
      Revision completa de un PR. Idioma por defecto: ES (pasar EN para ingles).
      Fase 0  Base de evidencia   build + vet + test -cover + golangci-lint + go fix
                                  worktree aislado, comparado contra origin/main
      Fase 1  NKH1                tamano, titulo, PCI/secretos, bump de version
      Fase 2  go-bricks           tipos reinventados, SQL safety, capas, BUS,
                                  patrones DB/handler, reuso, ubicacion de archivos
      Fase 3  Correctitud         errores, concurrencia+tiempo, leaks, fail-closed,
                                  calidad de tests, NOMBRES, firmas, modernizacion
      Fase 4  Descubrimiento      que ofrece go-bricks que el PR no esta usando
      Fase 5  Scope y evidencia   un solo concern, todo hallazgo con file:line
      Salida: <tmp>/pr-<N>-review.md  (markdown pegable en el PR)

  /go-dev-technical scan <path> [LANG]
      Auditoria del codigo existente + ROADMAP de remediacion ejecutable.
      SIEMPRE baja main primero (fetch + checkout/pull, o worktree si hay WIP)
      para auditar contra el ultimo main; reporta el commit de main auditado.
      Mismos checks que review, sin lo especifico de PR, mas:
        - tabla de auditoria rawQuery (safe / migrable / BLOCKER)
        - features de go-bricks sin usar, con donde aplicarlas
        - roadmap por fases: <=400 lineas y <=10 files por fase, una rama por
          fase desde main, prioridad P0..P4, dependencias y diferidos
      Salida: <tmp>/scan-<path>-audit.md

  /go-dev-technical help
      Esta tarjeta.

QUE ATRAPA (los que duelen)
  BUS       nombre de exchange/queue/routing-key/EventType que no matchea con la
            contraparte: publica ok, no enruta, nadie recibe, NO hay error.
            AutoAck, sin DLQ, sin idempotencia (inbox), dual-write sin outbox.
  SQL       fmt.Sprintf/concat en SQL, Raw()/Expr() sin parametrizar, identificadores
            dinamicos sin allowlist.
  NOMBRES   no solo marca el mal nombre: PROPONE el reemplazo en una tabla
            Actual -> Propuesto -> Razon. Sin propuesta no es hallazgo.
  RUNTIME   errores tragados, %s en vez de %w, goroutine leaks, resource leaks,
            fail-open, tests tautologicos, ramas de error sin cubrir.
  CAPAS     service que importa server, handler que toca database, net/http o
            sql.DB crudos en vez de go-bricks.

REGLAS DURAS
  - Fase 0 SIEMPRE: no se opina sobre un diff sin compilarlo y correrle los tests.
  - go-bricks manda: si el framework lo provee, se usa.
  - Todo hallazgo lleva file:line + escenario de fallo concreto + fix.
  - Lo que no se pudo verificar es (warn) NO VERIFICADO, nunca (ok).
  - Paridad legacy gana sobre estetica: un nombre que replica el contrato Java
    se respeta y se documenta, no se reporta.
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
| "Con leer el diff alcanza" | El diff no compila, no corre tests y no mide cobertura | Phase 0 SIEMPRE: build + vet + test + lint antes de opinar |
| "El lint pasa" | `golangci-lint` cachea entre worktrees y reporta rutas que ya no existen | `golangci-lint cache clean` y comparar contra `origin/main` |
| "Tiene 95% de cobertura" | El % no dice QUÉ rama falta, y suele faltar la de error | `go tool cover -func` + bloques con 0 hits |
| "`gh` falló, salto ese check" | Un check no verificable es ⚠️, nunca ✅ | Fallback a `git log` y marcar ⚠️ con la razón |
| "El nombre es cuestión de gusto" | Un nombre equivocado propaga un modelo mental equivocado | Google Go Style Guide es el árbitro, no la preferencia |

---

## Review order

### Phase 0 — Build the evidence base (MANDATORY, run FIRST)

Do not read the diff and reason about it. **Run the toolchain and let it tell you
what is broken** — then reason about what the toolchain cannot see. See
"Phase 0 — Evidence base" below for the exact commands.

### Phase 1 — NKH1 standard (common:pr-review)

1. **Sizing**: ≤400 LOC, ≤10 files, one problem per PR
2. **Title**: Conventional Commit, ≤72 chars, no Jira ID in title
3. **Security & PCI**: no secrets, PAN, CVV in code/logs/tests; tenant isolation
4. **Correctness**: edge cases, error paths, money math (integer minor units)
5. **Contracts**: API compatibility, response codes, DB migration safety
6. **Tests**: ≥70% coverage on changed code, error paths covered
7. **Style**: defer to linters (golangci-lint, gofmt, staticcheck)

### Phase 2 — go-bricks validation (checks 1-10)

Anti-patterns: the PR must not reinvent go-bricks types, break layer boundaries,
or escape the QueryBuilder unsafely.

### Phase 3 — Correctness, runtime & naming (checks 9, 11-16)

Correctness bugs and code smells linters miss, plus API/naming design.

### Phase 4 — go-bricks discovery

Actively explore go-bricks source for utilities the PR COULD use but doesn't.
Not about blocking — about leveraging the framework's full potential.

### Phase 5 — Scope & evidence verification (checks 17-18)

### Check index

| # | Check | Phase | Severity |
|---|-------|:-----:|----------|
| 1 | No reinvented types | 2 | BLOCKER |
| 1b | rawQuery / SQL safety | 2 | BLOCKER |
| 1c | Vendor adapter over `sql.DB` (unsupported vendor) | 2 | SHOULD-FIX |
| 2 | Layer boundaries | 2 | BLOCKER |
| 3 | Module wiring | 2 | SHOULD-FIX |
| 4 / 4b / 4c / 4d | DB patterns, Entity/Row mapping, query construction, dead scaffolding | 2 | SHOULD-FIX |
| 5 | HTTP/handler patterns | 2 | SHOULD-FIX |
| 6 | External calls | 2 | SHOULD-FIX |
| 6b | Messaging / bus integration | 2 | BLOCKER |
| 7 | Test patterns | 2 | SHOULD-FIX |
| 8 / 8b / 8c | Reuse check, file & struct placement, file cohesion & minimalism | 2 | SHOULD-FIX |
| 9 / 9b | Naming & API design, signature design | 3 | SHOULD-FIX |
| 10 / 10b | Config completeness, version bump | 2 | NIT / SHOULD-FIX |
| 11 | Error handling bugs | 3 | BLOCKER |
| 12 | Concurrency & time bugs | 3 | BLOCKER |
| 13 | Resource leaks | 3 | BLOCKER |
| 14 | Fail-closed validation | 3 | SHOULD-FIX |
| 15 | Test quality | 3 | SHOULD-FIX |
| 16 | Modernization (`go fix`) | 3 | NIT |
| 17 | Scope containment | 5 | SHOULD-FIX |
| 18 | Evidence-based findings | 5 | MANDATORY |

---

## Phase 0 — Evidence base (MANDATORY)

A review that only reads the diff reports what the reviewer *imagines* the code
does. Compile it, run it, measure it — **then** review what the tools can't see.
Findings produced this way carry a reproducible command, which is what makes them
survive an argument with the author.

### Step 0.1 — Isolated worktree (never dirty the user's checkout)

The user may have work in progress. Never `git checkout` the PR branch in their
working directory. Use a detached worktree in the scratchpad:

```bash
WT="<scratchpad>/pr<N>"
git worktree add --detach "$WT" pr-<N>
cd "$WT"
```

**Always remove it when done** (from the repo root, not from inside the worktree —
deleting your own CWD breaks the shell):

```bash
cd <repo-root> && git worktree remove --force "$WT" && git worktree prune
```

### Step 0.2 — Run the toolchain

```bash
go build ./...                 # must be clean
go vet ./...                   # must be clean
go test ./... -cover           # all green + per-package coverage
golangci-lint run ./...        # the project's own gate (.golangci.yml)
go fix -diff ./...             # check 16 — modernization, exits non-zero if any
```

**Compare against the base**, never in absolute terms. A pre-existing lint issue
is not this PR's fault; an issue the PR *introduces* is. When `golangci-lint`
reports anything, re-run on `origin/main` to attribute it:

```bash
golangci-lint cache clean && golangci-lint run ./...
```

> `golangci-lint` caches across worktrees and will happily report issues against a
> worktree you already deleted. If paths in the output don't exist, clean the cache
> and re-run before believing the result.

### Step 0.3 — Per-branch coverage, not per-package

"97.6% coverage" is not a finding. **Which branch is uncovered** is:

```bash
go test ./<changed-pkg>/... -coverprofile=/tmp/c.out
go tool cover -func=/tmp/c.out | grep -v "100.0%"     # which functions
grep -v "^mode" /tmp/c.out | awk '$NF==0'             # exact uncovered blocks: file:startLine.col,endLine.col
```

Map each uncovered block back to a line and ask: *is this the error path that will
actually happen in production?* An uncovered transport-failure branch matters more
than an uncovered getter.

### Step 0.4 — Race detector on concurrent code

If the diff touches goroutines, channels, or shared state:

```bash
go test ./... -race
```

### Step 0.5 — When `gh` is unavailable

`gh` frequently lacks repo scope on NovoPayment repos and fails with
`Could not resolve to a Repository`. That is **not** a reason to skip the PR title
check — fall back to the commit subjects and mark the check ⚠️:

```bash
git log origin/main..pr-<N> --oneline
```

Report it as: *"⚠️ `gh` sin scope de repo — no pude leer el título real; el commit
`<subject>` son N chars y cumple"*. Never silently claim ✅ on something you
could not read.

### Phase 0 gate

Report these in the summary table as their own rows. If any command could not be
run (no toolchain, no network), that row is ⚠️ `NO VERIFICADO` with the reason —
never ✅.

---

## go-bricks checks (Phase 2 — checks 1-10)

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
- Vendor-aware: auto-handles placeholder differences (Oracle `:1`, Postgres `$1`, MySQL `?`)
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

### 1c. Vendor adapter over `sql.DB` — justified escape from check 1 (SHOULD-FIX)

Check 1 flags raw `sql.DB` as an anti-pattern because go-bricks provides `database.Interface`.
**Exception**: go-bricks ships only **PostgreSQL and Oracle** vendors. When a module must reach a
vendor go-bricks does not support (SQL Server, MySQL, etc.), wrapping `sql.DB` in an **adapter that
implements `database/types.Interface`** is the correct, sanctioned pattern — NOT a check-1
violation. Do not flag the `sql.DB` itself; instead validate the adapter against the baseline below.

```bash
# Adapter packages that wrap an unsupported vendor
grep -rln "types.Interface\|database/types" <path> --include="*.go" | grep -iE "sqlserver|mysql|mssql"
```

When you see such an adapter package (e.g. `repository/sqlserver/adapter.go`), verify:

- [ ] **Implements `types.Interface` with a compile-time assertion**: `var _ types.Interface = (*Adapter)(nil)`.
- [ ] **Read-only intent is enforced, not implied**: write/tx paths (`Exec`, `Begin`, `BeginTx`,
      `Prepare`, `CreateMigrationTable`) return a package sentinel `ErrReadOnly`
      (`errors.Is`-comparable), never a silent `nil`/no-op. A read-only adapter that lets `Exec`
      through is a data-integrity risk.
- [ ] **`New(db *sql.DB)` constructor separate from `Open(cfg)`** — so tests inject `sqlmock`
      without a live server. An adapter that only has `Open` is untestable offline.
- [ ] **DSN built with `net/url` + `url.UserPassword`**, never string concatenation — escaping is
      automatic and the password is carried structurally, not interpolated.
- [ ] **TLS explicit**: `encrypt=true` in the DSN; `TrustServerCertificate` (or equivalent) is a
      per-environment **config field**, never hardcoded `true`.
- [ ] **No credential leak**: `Config.String()` omits password AND user (renders only
      host/port/database); `Open` wraps errors with `%s`(String()), never the raw DSN. The DSN
      string must never reach a log or error.
- [ ] **Driver name is deliberate and documented — it decides the placeholder dialect, and the SQL
      must match**. This is a silent-runtime-break gotcha (no compile error):
      - `mssql` (denisenkom) → positional `?`
      - `sqlserver` (denisenkom / microsoft) → named `@p1` / `@name`
      Flag any adapter whose driver name and query placeholders disagree, and any without a comment
      explaining the choice. Prefer the maintained `github.com/microsoft/go-mssqldb` over the
      archived `github.com/denisenkom/go-mssqldb`.
- [ ] **Pool sized explicitly with rationale** (`SetMaxOpenConns`, `SetMaxIdleConns`,
      `SetConnMaxLifetime`): a periodic/telemetry sweep sizes small (e.g. 2/1); a request-path pool
      sizes to its load. A pool with no limits on a tenant DB is a finding.
- [ ] **`Health(ctx)` with a bounded timeout** (`context.WithTimeout` + `PingContext`) and
      **`Stats()`** exposing pool metrics.
- [ ] **Package doc comment** states why the adapter exists (go-bricks lacks the vendor) and what is
      functional vs `ErrReadOnly`.
- [ ] Error messages in **English**, consistent with the rest of the codebase (no mixed-language
      strings like `"abrir conexión a"`).

**Reference baseline** — a read-only SQL Server adapter satisfying `types.Interface`: `Adapter`
over `New`/`Open`, net/url DSN with `url.UserPassword`, `ErrReadOnly` sentinel on every write path,
bounded `Health`, credential-safe `String()`, and a documented driver/placeholder choice. If the PR
under review diverges (mixes languages, leaks the DSN, hardcodes `TrustServerCertificate`, omits
`SetMaxIdleConns`, or picks a driver whose placeholders don't match the query), flag the specific
gap against this baseline — it is a SHOULD-FIX, not a blocker, unless a credential leaks (BLOCKER)
or `Exec` is not disabled on a read-only adapter (BLOCKER).

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
- [ ] Named placeholders for Oracle (`:param_name`), not Postgres-style positional (`$1`)
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

### 6b. Messaging / bus integration (BLOCKER)

**This is the check that prevents a broken integration from reaching production.**
An HTTP contract breaks loudly — a 404, a failing test. A bus contract breaks
**silently**: a routing key with a typo publishes successfully, the broker routes it
nowhere, and the consumer simply never receives anything. Nothing fails, nothing
logs an error, and the bug surfaces days later as missing data.

Apply whenever the diff touches `go-bricks/messaging`, `outbox`, `inbox`, AMQP, or
declares an exchange / queue / binding / publisher / consumer.

#### 6b.1 Contract names are the integration (BLOCKER)

Exchange names, queue names, routing keys and `EventType` are a **cross-service
contract**. The compiler does not check them; the broker does not reject them.
A single wrong character = an integration that never works.

- [ ] **Every name verified character-by-character against the counterpart**, not
      "it looks right". The counterpart is the producer repo, the consumer repo, the
      infra declaration, or the legacy service being migrated. Quote the source:
      ```bash
      grep -rn "<routing.key>" --include="*.go" --include="*.yml" --include="*.yaml" .
      grep -rn "RegisterConsumer\|RegisterPublisher\|RegisterBinding" --include="*.go" internal/
      ```
      If the counterpart is not in this repo and cannot be read, the check is
      ⚠️ `NO VERIFICADO` — **never ✅**. Say exactly which name could not be confirmed.
- [ ] **Names come from a shared constant**, never a string literal at the call site.
      A literal repeated in publisher and consumer drifts on the first rename
- [ ] **Naming consistent with the topology already in the repo**: same separator,
      same casing, same segment order (`domain.entity.action` vs
      `service_entity_action` — pick the one already in use and never mix)
- [ ] `EventType` and `Description` are populated on every publisher/consumer
      declaration — they are the documentation of the topology
- [ ] `Declarations.Validate()` catches a consumer/publisher/binding pointing at a
      queue or exchange that was never declared. Verify the module actually declares
      **all four**: exchange, queue, binding, and the consumer/publisher. A consumer
      declared without its binding compiles, starts, and receives nothing

#### 6b.2 Delivery guarantees (BLOCKER)

- [ ] **`AutoAck: false`** on any consumer carrying business events. `AutoAck: true`
      acknowledges on delivery, so a handler that panics or errors **loses the
      message permanently** — no retry, no DLQ, no trace
- [ ] **`Durable: true`** on queues and exchanges that carry business events —
      otherwise a broker restart discards them
- [ ] **DLQ configured**: `QueueDeclaration.Args` carries `x-dead-letter-exchange`
      (and its DLX/DLQ are themselves declared). Without it, a poison message either
      loops forever or vanishes
- [ ] **No infinite requeue**: a handler that nacks with `requeue=true` on a
      permanent error (malformed payload, unknown id) re-delivers the same message
      forever and burns the consumer. Permanent errors go to the DLQ; only transient
      ones requeue
- [ ] **Idempotent consumer**: AMQP is **at-least-once**, so redelivery is normal,
      not exceptional. The handler either wraps in `deps.Inbox.ProcessOnce` (with the
      id from `outbox.EventIDFromHeaders`) or is provably idempotent by construction.
      A consumer that inserts a row without an idempotency key WILL duplicate it
- [ ] **No dual write**: publishing inside a DB transaction that may still roll back
      (or committing then publishing) loses or invents events on any crash between
      the two. Use the transactional **outbox** — that is what it is for

#### 6b.3 Payload contract

- [ ] Producer struct and consumer struct agree **field by field, tag by tag**.
      Compare the JSON tags, not the Go field names
- [ ] Unknown fields tolerated on the consumer side (forward compatibility): adding
      a field to the producer must not break existing consumers
- [ ] A schema change is additive, or the event type is versioned. Renaming or
      removing a field in place breaks every deployed consumer at once
- [ ] Payload carries no PAN/CVV/track data (PCI) and no secrets — a queue is
      persisted storage
- [ ] The event id used for idempotency travels in a **header**, and both sides read
      the same header name

#### 6b.4 Consumer runtime

- [ ] Handler receives and honors `ctx` (shutdown must drain, not truncate)
- [ ] Handler cannot panic out — a panic in a consumer goroutine takes down the
      process or silently kills the consumer depending on the recovery wiring
- [ ] `Workers` / `PrefetchCount` are deliberate: `0` means auto (`NumCPU*4`, prefetch
      `Workers*10` capped at 500). For a handler that writes to a DB with a small
      pool, auto-scaling to 4×CPU workers exhausts the pool — set both explicitly and
      say why
- [ ] Uses go-bricks `messaging` (`Registry` / `Declarations` / `AMQPClient`), never
      `amqp091-go` directly:
      ```bash
      grep -rn "amqp091\|streadway/amqp" --include="*.go" internal/ | grep -v _test.go
      ```

#### 6b.5 Tests

- [ ] There is a test that pins the **contract**: exchange, routing key, event type
      and the serialized payload. That test is what catches a rename before the broker
      silently swallows it
- [ ] Redelivery is tested: the same message twice produces one effect
- [ ] The handler's error path is tested (does it DLQ, requeue, or swallow?)

**Report format** — for bus findings, always state the silent-failure scenario
explicitly, because it is what makes the severity land:

> `[bus]` `module.go:44` — el consumer declara la queue `card.block.v1` pero el
> binding usa `card.blocked.v1`. Publica correcto, el broker enruta a ninguna cola y
> el consumer nunca recibe: **no hay error, no hay log, no hay test rojo**. La
> integración queda muerta en silencio. Fix: constante compartida
> `QueueCardBlocked = "card.blocked.v1"` usada en la declaración y en el binding.

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

### 8c. File cohesion & minimalism (SHOULD-FIX)

The goal is the **fewest `.go` files that still separate concerns**: each concern
(mappers, constants, DTOs, errors, queries, wiring, shared utilities) lives in **one
cohesive file per layer**, not scattered across micro-files. Fragmentation and
junk-drawer files are both findings — one because it hides the concern across many
files, the other because it hides many concerns in one file.

**One canonical file per concern, per layer**:

| Concern | Cohesive file | Layer |
|---|---|---|
| Domain model | `<entity>.go` | `domain/` |
| Table metadata (`Entity[T]`) | `<entity>_entity.go` | `domain/` |
| Error sentinels | `errors.go` | `domain/` |
| Business constants | `constants.go` (or inside the domain file) | `domain/` |
| Repository interface | `repository.go` | `repository/` |
| SQL implementation | `sql_repository.go` | `repository/` |
| Row→DTO mappers | `mapper.go` | `repository/` |
| SQL as `const` (when the module separates them) | `queries.go` | `repository/` |
| Business logic | `service.go` | `service/` |
| Service / handler DTOs | `dto.go` | `service/`, `handlers/` |
| HTTP handlers | `http.go` (+ `health.go`) | `handlers/` |
| AMQP consumer | `<event>_handler.go` | `amqp/` |
| Module wiring | `module.go` | module root |
| Test data / mocks / helpers | `testdata_test.go` / `mocks_test.go` / `testing_helpers_test.go` | per layer |
| Cross-cutting utility | `internal/plataform/` or `shared/<concern>/` named by the concern | shared |

Both `queries.go`/`constants.go` (separate files) and inlining queries/constants into
`sql_repository.go`/the domain file are valid — either is cohesive. Do not force one
over the other.

**What to flag (SHOULD-FIX)**:
- **Fragmentation**: one concern spread over several files → consolidate. Constants in
  4 files → `constants.go`; two mapper files → `mapper.go`; one tiny type per file when
  they cohere → merge into the layer's canonical file.
- **Junk-drawer names**: `utils.go`, `helpers.go`, `common.go`, `misc.go`, `base.go`,
  a generic `handler.go` → rename to the file named after its one responsibility
  (`http.go`, `mapper.go`, `response.go`, …). Same rule for `shared/`: a folder per
  concern (`shared/errors`, `shared/pagination`), never `shared/utils`.
- **Concern outside its layer**: a mapper living in `service/`, a DTO in
  `repository/interface.go` (overlaps 8b).

```bash
# junk-drawer file names in the diff
git diff origin/main...pr-<N> --stat | grep -E '/(utils|helpers|common|misc|base|handler)\.go'
# same concern fragmented — e.g. several *mapper*/*const* files in one layer
git diff origin/main...pr-<N> --name-only | grep -E '/(repository|service|handlers)/' \
  | grep -iE 'map|const|dto|error' | sort
```

**How to report** — phrase the finding as the convention itself; **never name a
reference project** in the finding. Say *what* file the concern belongs in and *why*
(cohesion / one concern per file), not "matches project X".

- File **rename / move** → a `git mv` command (GitHub's ```suggestion block applies to
  line content, not file paths):
  ```bash
  git mv internal/modules/cards/handlers/handler.go \
         internal/modules/cards/handlers/http.go
  ```
- **Consolidation** (many → one) → list the source files and the destination, with the
  `git mv` for the rename and a note to move the remaining content in.
- **Content misplaced inside a file** (a type in the wrong file, not the file itself) →
  a ```suggestion block as in checks 8b / 9.

Example finding (note: no reference-project name):

> - [ ] **`internal/modules/cards/repository/card_mappers.go`** — `[layout]` sugerencia:
>   los mappers Row→DTO se consolidan en `mapper.go` (un concern, un archivo por capa).
>   Seguir una organización más cohesiva y minimalista. *(sugerencia, no bloquea)*
>   ```bash
>   git mv internal/modules/cards/repository/card_mappers.go \
>          internal/modules/cards/repository/mapper.go
>   ```

### 9. Naming & API design (SHOULD-FIX)

Naming is not cosmetics — a wrong name is a wrong mental model that every future
reader inherits. Baseline is the **Google Go Style Guide** (`google.github.io/styleguide/go`),
which supersedes personal preference. Rules below are the checkable subset.

#### 9.0 Procedure — enumerate, judge, propose (MANDATORY)

This check is **not** "read the diff and see if something looks odd". It is a
sweep: every identifier the PR introduces gets judged, and every bad one leaves
with a **concrete replacement name**. A finding that says "el nombre es poco
descriptivo" without proposing the new name is not a finding, it is a complaint.

**Step 1 — Enumerate every new identifier.** Only added lines (`^+`):

```bash
D="git diff origin/main...pr-<N> -- *.go"

# types, funcs, methods, interfaces
$D | grep "^+" | grep -oE "^\+(type|func) [A-Za-z_][A-Za-z0-9_]*" | sort -u
$D | grep "^+" | grep -oE "^\+func \([a-z]+ \*?[A-Za-z]+\) [A-Za-z_][A-Za-z0-9_]*" | sort -u

# struct fields
$D | grep "^+" | grep -oE "^\+\s+[A-Z][A-Za-z0-9_]*\s+[a-z*\[]" | sort -u

# constants and package-level vars
$D | grep "^+" | grep -oE "^\+\s*(const|var)?\s*[A-Za-z_][A-Za-z0-9_]*\s*=" | sort -u

# import aliases (must match the rest of the repo — see 9.5)
$D | grep "^+" | grep -oE '^\+\s+[a-z][a-zA-Z0-9]* "' | sort -u
```

**Step 2 — Judge each one against 9.1-9.5 and the smell catalog below.**

**Step 3 — For every violation, produce a row** in the rename table (9.6). The
proposed name must be: intention-revealing, pronounceable, greppable, in the
project's domain language, and consistent with what the repo already calls that
concept — check before inventing:

```bash
grep -rn "<concepto>" internal/ --include="*.go" | head    # ¿cómo se llama ya?
```

#### 9.0b Smell catalog — what to hunt and what to propose

*"The name should tell you why it exists, what it does, and how it is used. If a
name requires a comment, the name does not reveal its intent."* (Clean Code, cap. 2)

| Smell | Ejemplo detectado | Propuesta | Por qué |
|---|---|---|---|
| **Palabra ruido** (`Data`, `Info`, `Object`, `Value`, `Item`, `Record`) | `CardData`, `AccountInfo` | `Card`, `Account` | `Data` no distingue nada: todo es datos |
| **Sufijo cajón** (`Manager`, `Processor`, `Helper`, `Util`, `Handler` fuera de HTTP) | `CardManager` | `CardBlocker` / `CardStatusUpdater` | Un `Manager` "gestiona" = no tiene una responsabilidad |
| **Verbo vacío** (`process`, `handle`, `doX`, `execute`, `perform`) | `processCard()` | `blockCard()`, `formatAmount()` | Nombrar el efecto, no el hecho de que haya código |
| **Abreviatura no estándar** | `custId`, `blkTp`, `respCd`, `acctNum` | `customerID`, `blockType`, `responseCode`, `accountNumber` | Sólo se abrevian términos universales (`ctx`, `db`, `tx`, `req`, `resp`, `err`, `id`, `url`, `cfg`) |
| **Nombre desinformativo** | `list` sobre un `map`; `cardList []Card` que trae bines | `byID map[...]`, `binGroups` | Un nombre que miente cuesta más que uno vago |
| **Serie numérica / ruido diferenciador** | `card1`, `card2`, `cardCopy`, `cardTmp` | `source`, `updated` / nombres por rol | Si dos nombres deben diferir, deben *significar* distinto |
| **Tipo en el nombre** | `cardSlice`, `errString`, `idToNameMap` | `cards`, `reason`, `namesByID` | El tipo ya lo dice el compilador |
| **Booleano negado o ambiguo** | `notFound`, `disabled`, `flag` | `found`, `enabled`, `skipUsernameLookup` | `!notFound` obliga a doble negación mental |
| **Constante que se nombra a sí misma** | `PB = "PB"`, `Code40 = "-40"` | `BlockTypeTemporary`, `ErrCodeAccountNotFound` | La constante debe decir qué *denota*, no qué *vale* |
| **Genérico de un solo uso** | `result`, `res`, `out`, `temp` en scope de 20+ líneas | `balances`, `issuance`, `formatted` | Largo proporcional al scope (9.1) |
| **Inconsistencia de léxico** | `Fetch…`, `Get…`, `Retrieve…` para lo mismo | elegir UNO por repo | *"Un lexicón consistente es un gran beneficio"* |
| **Stuttering** | `cards.CardsService`, `connector.ConnectorClient` | `cards.Service`, `connector.Client` | El paquete es la mitad del identificador |
| **Acrónimo mal capitalizado** | `CardId`, `HttpClient`, `panHash`→`PanHash` | `CardID`, `HTTPClient`, `PANHash` | Convención de Go, no opinión |

**Excepción que manda sobre todas**: en una migración, un nombre que replica el
contrato legacy (`GetCardDetail`, `holdResponseCode`, `pvki`, `rc`) **se respeta**
aunque viole el catálogo — la paridad vale más que la estética. Cuando detectes
uno, no lo reportes como hallazgo: menciónalo como decisión verificada.

#### 9.1 The two rules that decide most arguments

1. **Name length is proportional to scope.** *"The length of a name should be
   proportional to the size of its scope and inversely proportional to the number
   of times it is used within that scope."* A 3-line closure may use `c`; a
   package-level var may not. Conversely, `customerIdentifierValue` inside a
   5-line loop is noise.

   | Scope | Acceptable |
   |---|---|
   | 1-7 lines | single letters (`i`, `r`, `w`, `c`, `tt`) |
   | 8-15 lines | short words (`card`, `row`, `resp`) |
   | 15+ lines / package-level | full descriptive names |

2. **Omit what context already says.** Inside package `cards`, a type is `Service`,
   not `CardsService`; a method on `Card` returns `count`, not `cardCount`. The
   caller reads `cards.Service` — the package name is half the identifier.

#### 9.2 Variables & fields

- [ ] camelCase unexported / PascalCase exported — **never** snake_case, never `ALL_CAPS`
- [ ] Initialisms keep uniform case: `ID`, `URL`, `HTTP`, `SQL`, `API`, `RC`, `PAN` —
      `cardID` / `CardID`, never `cardId` / `CardId`
- [ ] No stuttering: `domain.DomainError` → `domain.Error`; `cards.CardsService` → `cards.Service`
- [ ] No type-in-name: `users` not `userSlice`; `byID` not `idToUserMap`
- [ ] Booleans read as assertions: `isActive`, `hasBalance`, `canBlock`, `shouldRetry`,
      or bare adjectives (`valid`, `blocked`). Never negated names — `notReady`
      forces the reader to parse `!notReady`
- [ ] No underscores, except in `_test.go` function names
- [ ] Receiver: 1-2 letters abbreviating the type, **identical across every method
      of that type** (`s` Service, `r` Repository, `h` Handler, `c` Client). Never
      `self`, `this`, or `_` with a body that uses it

#### 9.3 Functions & methods

- [ ] **No `Get` prefix** on accessors: *"Prefer starting the name with the noun
      directly"* — `Balance()` not `GetBalance()`. **Exception**: the underlying
      concept is a get (HTTP GET, `GetCardDetail` mirroring a legacy endpoint,
      SQL `GET_BLOCK_TYPE_BY_ID`). In a migration, legacy-parity names WIN — say so
      in the review instead of flagging them
- [ ] Mutating/acting functions start with a verb: `Create`, `Validate`, `Parse`, `Build`, `Resolve`
- [ ] Constructors are `New{Type}` — `NewService`; in a single-type package just `New`
- [ ] Interface methods name the action, not the plumbing: `FindByID`, `Store` —
      not `DoFind`, `ProcessStore`, `HandleStore`
- [ ] Test names: `TestXxx`, subtests describe the *case*, not the number —
      `t.Run("missing tenant", …)` not `t.Run("case3", …)`

#### 9.4 Types, interfaces & errors

- [ ] Interfaces by behavior (`-er`: `Reader`, `Validator`, `CardUpdater`) or by
      role (`Repository`, `Service`). Small interfaces beat large ones
- [ ] **Interfaces are declared by the consumer**, not shipped with the
      implementation — the package that *calls* defines what it needs
- [ ] Structs are nouns: `Card`, `BlockRequest` — not `CardData`, `AccountInfo`,
      `CardManager` (a `Manager` suffix usually means the type has no single job)
- [ ] Error sentinels: `Err` prefix (`ErrNotFound`); error *types*: `Error` suffix
      (`AppError`, `ValidationError`)
- [ ] Constants explain what the value **denotes**, not what it **is**:
      `BlockTypeTemporary = "PB"` ✅ — `PB = "PB"` or `StringPB` ❌

#### 9.5 Packages & files

- [ ] Package name: short, lowercase, one word, no underscores, no mixedCaps
- [ ] **Banned package names**: `util`, `utils`, `common`, `helpers`, `misc`, `shared`,
      `base` — they attract unrelated code and force import aliases. A package named
      after what it *is for* (`connector`, `apperrors`, `external`) stays coherent.
      Same rule for files: a `helpers.go` becomes a junk drawer — name it after its
      one type (`handler.go`, `response.go`)
- [ ] Package name is not repeated by its contents (`connector.Client`, not `connector.ConnectorClient`)
- [ ] Import aliases: **one alias per package, repo-wide**. Two files aliasing the
      same import differently (`platdomain` vs `platformdomain`) is a real finding —
      grep before accepting a new alias:
      ```bash
      grep -rn '"<module>/internal/platform/domain"' --include="*.go" internal/ | sed 's/.*  *\([a-z]*\) "/\1/' | sort -u
      ```
- [ ] Files snake_case (`block_request.go`); one primary type per file, except
      deliberate collections (`dto.go`, `errors.go`, `constants.go`)

#### 9.6 How to report — the rename table is MANDATORY

The output of check 9 is a **table of concrete rename proposals**, always present
in the report (inside the `<details>` block), even when everything passes.

| # | Archivo | Actual | **Propuesto** | Razón |
|---|---------|--------|---------------|-------|
| 1 | `cards/service.go:24` | `cards.CardsService` | `cards.Service` | Stuttering: el paquete ya dice `cards` |
| 2 | `cards/domain/dto.go:31` | `BlockTypeId` | `BlockTypeID` | Acrónimo: `ID` va en mayúsculas |
| 3 | `repository/sql_repository.go:13` | alias `platformdomain` | `platdomain` | 4 archivos del repo ya usan `platdomain` |
| 4 | `external/processingcore.go:88` | `processCard()` | `blockCard()` | Verbo vacío: nombrar el efecto |

Rules for the table:

- **Cada fila lleva una propuesta.** Ninguna fila puede decir "mejorar el nombre",
  "poco descriptivo" o "revisar". Si no se te ocurre el nombre correcto, el hallazgo
  no está listo — busca cómo llama el repo a ese concepto y propón eso.
- **`Razón` en una línea**, citando la regla (stuttering / acrónimo / palabra ruido /
  scope / léxico inconsistente), no un párrafo.
- **Cuando todo pasa**, la tabla lleva una fila
  `— | — | Todas las convenciones seguidas ✅ | — | —` **y debajo una línea de lo
  que sí verificaste**: receptores, `ctx` primero, `error` último, acrónimos,
  stuttering, alias de import, palabras ruido. Así el autor sabe que el check corrió
  y no se saltó.
- **Renombres masivos**: si la propuesta toca >10 sitios, no la conviertas en
  bloqueante del PR — proponla y márcala como trabajo de seguimiento, indicando el
  comando: `gofmt -r 'oldName -> newName' -w ./...` o el rename del IDE (que además
  actualiza referencias en tests).

**Ruteo de los hallazgos de nombres (IMPORTANTE)**: cuando la tabla tenga
**al menos una fila real** de renombrado (algo distinto de la fila "todas las
convenciones seguidas ✅"), esos hallazgos deben aparecer **también en la sección
`Debe corregirse`** como un ítem de **sugerencia** — no quedarse enterrados en el
`<details>`. La redacción es de recomendación, no de bloqueo: *"seguir una
nomenclatura más clara y diciente"*, con la propuesta concreta. El `<details>` con
la tabla completa se mantiene como el registro del barrido (incluye la verificación
y los renombres masivos diferidos); la sección `Debe corregirse` lleva el resumen
accionable para que el autor lo vea sin expandir nada.

Formato del ítem en `Debe corregirse` — cada hallazgo lleva su **propuesta como
bloque `suggestion` de GitHub**, para que al pegarlo como comentario inline salga el
botón *"Apply suggestion"* y el autor lo aplique con un click:

````markdown
- [ ] **`path/file.go:24`** — `[naming]` sugerencia: renombrar `{actual}` → `{propuesto}`
  ({regla en una línea, p. ej. stuttering / acrónimo / palabra ruido}). Seguir una
  nomenclatura más clara y diciente. *(sugerencia, no bloquea el merge)*
  ```suggestion
  {la línea path/file.go:24 completa, ya con el nombre corregido}
  ```
````

Reglas del bloque `suggestion`:
- El contenido es la **línea (o líneas) exacta(s) del diff ya corregida(s)** — GitHub
  reemplaza la(s) línea(s) comentada(s) por lo que va dentro del bloque. Debe compilar
  tal cual: copiá la línea original y cambiá sólo el identificador.
- Sólo se convierte en botón *"Apply"* cuando el comentario se postea **inline sobre
  esa línea** del PR; en un comentario general del PR se ve como bloque de código
  normal. Indicá el `path:line` para que el revisor sepa dónde anclarlo.
- **Renombre de un solo sitio** (una declaración local, un campo, un alias en un
  archivo) → `suggestion` directo. **Renombre multi-sitio** (un tipo/función usado en
  N archivos) → NO uses `suggestion` (arreglaría sólo la declaración y dejaría las
  referencias rotas): dejalo en la tabla del `<details>` como seguimiento con el
  comando `gofmt -r '{actual} -> {propuesto}' -w ./...`, y decilo explícito en el bullet.

Los nombres cuyo impacto **excede el estilo** — un nombre que **miente** sobre lo que
el valor contiene, o una inconsistencia de léxico que se va a propagar a los próximos
PRs — van igual en `Debe corregirse` pero con el fraseo reforzado (no como mera
sugerencia estética), con el mismo formato de propuesta:

> `[naming]` `external/processingcore.go:41` — el campo `HoldResponseCode` recibe el
> `blockTypeKey`, no un código de respuesta: el nombre miente sobre el contenido.
> El comentario `// blockTypeKey` es la prueba de que el nombre no se explica solo.
> **Propuesta**: `BlockTypeKey`, y si el JSON del proveedor exige `holdResponseCode`,
> que la diferencia viva sólo en el tag: `BlockTypeKey string \`json:"holdResponseCode"\``.

The **Naming & conventions** table is ALWAYS present in the report, even when
everything passes (with a "todas las convenciones seguidas ✅" row). When it
passes, list in one line what you actually checked — receivers, `ctx` first,
`error` last, acronyms, stuttering, aliases — so the author knows it wasn't skipped.
When it does NOT pass, the `<details>` table still carries every row, **and** each
real finding is surfaced up in `Debe corregirse` / `Should fix` as a `[naming]`
suggestion per the routing rule above.

#### 9b. Function & method signature design (SHOULD-FIX)

Naming says what it is called; the signature says how it can be misused.

- [ ] `ctx context.Context` is the **first** parameter, always, and named `ctx`.
      Never stored in a struct field
- [ ] `error` is the **last** return value
- [ ] **No boolean parameters**: `Block(ctx, card, true)` is unreadable at the call
      site. Use a named type or two methods (`Block` / `Unblock`)
- [ ] More than 4-5 parameters, or 2+ adjacent params of the same type
      (`f(customerID, accountID, cardID string)` — swappable, compiler-silent) →
      take a params struct
- [ ] **Accept interfaces, return concrete types** — a constructor returning an
      interface hides fields and blocks the caller from extending
- [ ] Pointer vs value in returns is deliberate: `*Card` when nil is a meaningful
      "absent"; `Card` when it is always present. `(*Card, error)` where the pointer
      is never nil on success is a nil-check the caller pays for on every call
- [ ] Every exported symbol has a doc comment starting with its own name
- [ ] Struct literals crossing package boundaries use **keyed fields**
      (`Endpoint{URL: u, Path: p}`) — positional literals break silently when a
      field is added

### 10. Config completeness (NIT)

If the PR adds config consumption (`config:` tags or `deps.Config`):

- [ ] Key exists in both `config.yml` (env vars) and `config.yaml` (local values)
- [ ] New config key follows existing naming convention
- [ ] Sensitive values use env var placeholders, not hardcoded
- [ ] **App-specific keys live under `custom:`** (see 10a) — anything go-bricks does
      not natively map MUST be nested under `custom.*`, never at the config root

#### 10a. Application config belongs under `custom:` (SHOULD-FIX)

go-bricks owns a **fixed set of top-level config sections** and binds them into its
own structs: `app`, `server`, `observability`, `log`, `database`, `databases`,
`keystore`, `messaging`, `source`, `multitenant` (and their documented children).
Any key **outside** that set is application config and MUST be nested under the
**`custom:`** object — that is the namespace go-bricks reserves for service-specific
values and exposes via `config:"custom.xxx.yyy"` struct tags / `InjectInto`.

A service-specific block placed at the config **root** (a sibling of `server:` /
`database:`) is a finding: it is not a value go-bricks maps, so it either fails to
bind or silently relies on a non-standard read path, and it pollutes the namespace
go-bricks controls (a future framework key could collide with it).

**Rule of thumb**: *"is this a value go-bricks already knows how to map?"*
- **YES** (a DB pool size, a server timeout, an observability endpoint) → it goes in
  its native section (`database:`, `server:`, `observability:`), never under `custom:`.
- **NO** (an external service URL, a downstream host/credentials, a feature flag, an
  operation id, a SQL Server Core connection) → it goes under `custom:`.

```yaml
# ❌ WRONG — service-specific block at the root, sibling of server/database
corepostilion:
  host: "${CUSTOM_COREPOSTILION_HOST}"

# ✅ CORRECT — nested under custom:, mapped via config:"custom.corepostilion.host"
custom:
  corepostilion:
    host: "${CUSTOM_COREPOSTILION_HOST}"
```

```bash
# Any new top-level key in config.yml that is NOT a go-bricks-owned section
git diff origin/main...pr-<N> -- config.yml | grep -E '^\+[a-z_]+:' \
  | grep -vE '^\+(app|server|observability|log|database|databases|keystore|messaging|source|multitenant|custom):'
# Non-empty output → an app key escaped the custom: namespace → SHOULD-FIX
```

Flag as SHOULD-FIX: *"`config.yml:<line>` — el bloque `<key>` es config de la
aplicación (go-bricks no lo mapea nativamente) y está en la raíz; debe anidarse bajo
`custom:` y consumirse con `config:\"custom.<key>...\"`."* The exception is a genuine
go-bricks-owned section — if in doubt, grep the go-bricks `config` package for the
key before flagging:
```bash
BRICKS=$(go env GOMODCACHE)/github.com/gaborage/go-bricks@$(grep go-bricks go.mod | awk '{print $2}')
grep -rn 'koanf:"<key>"\|mapstructure:"<key>"' "$BRICKS/config"/*.go
```

### 10b. Semantic version bump in config.yml (SHOULD-FIX — REQUIRED on every PR)

**Every PR MUST bump `app.version` in `config.yml` semantically**: **minor** for a
new feature (`feat`), **patch** for a fix / refactor / docs / test (`fix`, `hotfix`,
`refactor`, `docs`, `test`). Example: a `feat` takes `1.49.0` → `1.50.0`; a
`refactor` takes `1.50.0` → `1.50.1`. This is the project's mandatory version step;
the immutable build that gets promoted `main → DEV → UAT → PRD` is identified by
this version, so a PR without a bump ships the same version twice. `config.yaml`
keeps a placeholder (e.g. `v1.0.0`) and is NOT bumped — only `config.yml` carries
the live version.

```bash
# The PR MUST change app.version in config.yml
git diff origin/main...pr-<N> -- config.yml | grep -E '^\+\s*version:'
# Cross-check the base so the bump isn't stale after a rebase/merge:
git show origin/main:config.yml | grep -E '^\s*version:'
```

Flag as ❌ when:
- **No bump**: `app.version` unchanged in the PR → require a semantic bump.
- **Wrong segment**: a `feat` bumped patch instead of minor, or a `fix`/`refactor`
  bumped minor instead of patch — match the increment to the Conventional Commit type.
- **Stale increment**: the new value is not exactly one step above `origin/main`'s
  current `app.version` (common after a rebase or a main merge — the version
  conflict must resolve to `main` + 1 step, not the branch's old number).
- **Bumped the wrong file**: `config.yaml` changed instead of `config.yml`.

---

## Correctness, runtime & code smells (Phase 3 — checks 11-15)

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

#### 12b. The bugs that actually reach production

Most production concurrency incidents are **not** data races — the race detector
already catches those. They are goroutine leaks, unbounded growth and blocked
waits. Check these explicitly:

- [ ] **Every goroutine has a termination path.** It selects on `ctx.Done()`, reads
      from a channel that is guaranteed to close, or is bounded by a `WaitGroup` the
      caller waits on. A `go func()` whose only exit is "the work finishes" leaks
      when the work never finishes
- [ ] **`select` without `default` or a timeout case** blocks forever if the
      upstream goroutine dies before sending. Either `case <-ctx.Done():` or
      `case <-time.After(d):` must be present
- [ ] **`time.Ticker` stopped**: `defer tick.Stop()` — a ticker without it leaks its
      runtime timer for the process lifetime
- [ ] **`time.Time` compared with `Equal()`**, never `==` (`==` also compares the
      monotonic reading and the location pointer, so two equal instants can differ)
- [ ] **`sync.Map` compound operations**: never `Store`/`Delete` based on a previous
      `Load` — use `LoadOrStore` / `LoadAndDelete`. The read-then-write pair is not atomic
- [ ] **`sync.RWMutex` only with a benchmark that proves it wins.** For a couple of
      short reads it is slower than `Mutex`
- [ ] **Zero-capacity channel** (`make(chan T)`) — verify the rendezvous is intentional
      and not an accidental deadlock
- [ ] **`defer` inside a loop**: the deferred call runs at function exit, not at
      iteration end — N iterations hold N resources open
- [ ] **`errgroup`**: `g.Wait()` is actually called and its error is checked; the
      group is created with `errgroup.WithContext` when siblings must cancel

#### 12c. Verifying it (Go 1.25+)

```bash
go test ./... -race                    # mandatory when the diff touches concurrency
```

- [ ] Concurrency tests use **`testing/synctest`** (stdlib since Go 1.25) rather than
      `time.Sleep` to synchronize: a bubble with a fake clock makes the test both
      deterministic and instant. A `time.Sleep` in a test is a flake with a delay fuse
- [ ] Tests use **`t.Context()`** instead of `context.Background()` — it is cancelled
      on test cleanup, so a leaked goroutine fails the test instead of outliving it
- [ ] Code under test receives its `ctx` from the caller; a function that calls
      `context.Background()` internally cannot be tested for cancellation at all

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

Also verify **what the tests pin**. A test that only asserts "no error" documents
nothing. The valuable ones pin the *contract*: the exact wire body sent, the exact
header, the exact error code returned. When a PR adds that kind of test, say so —
it is the difference between a test and a regression guard.

### 16. Modernization — `go fix` (NIT)

Since Go 1.26 `go fix` runs the analysis framework with ~20 "modernizers" that
propose **safe, mechanical** rewrites. It is deterministic and free, so run it:

```bash
go fix -diff ./...       # non-empty diff → exit code != 0
go tool fix help         # list the registered analyzers
```

Relevant fixers: `any` (`interface{}` → `any`), `rangeint` (3-clause loop →
`for range n`), `slicescontains`, `slicessort`, `minmax`, `mapsloop`, `fmtappendf`,
`omitzero` (`omitempty` → `omitzero` on structs), `forvar` (redundant loop-var
re-declaration, obsolete since Go 1.22), plus two real correctness checks:
`hostport` (malformed `net.Dial` addresses) and `buildtag`.

Report as **NIT** — with two exceptions promoted to SHOULD-FIX:
- `hostport` or `buildtag` findings — those are bugs, not style
- `omitzero` on a struct field with `omitempty`: `omitempty` **does not omit an
  empty struct**, so the JSON contract already differs from what the author expects

Check `go.mod` first: these fixers assume the module's Go version supports the
target construct.

---

## go-bricks discovery (Phase 4 — SHOULD-FIX)

Phase 2 (checks 1-10) catches anti-patterns. Phase 4 actively explores what
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

## Scope & evidence verification (Phase 5 — checks 17-18)

### 17. Scope containment (SHOULD-FIX)

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

### 18. Evidence-based findings (MANDATORY)

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
- [ ] **`path/to/file.go:24`** — `[naming]` sugerencia: renombrar `{actual}` → `{propuesto}` ({regla}). Seguir una nomenclatura más clara y diciente. *(sugerencia, no bloquea)*
  ```suggestion
  {la línea file.go:24 completa, ya con el nombre corregido}
  ```
  _(un bullet por cada fila real de la tabla de nombres; `suggestion` sólo para renombres de un solo sitio — multi-sitio va a la tabla con `gofmt -r`)_

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
| **Base de evidencia (Phase 0)** | | |
| `go build ./...` | ✅/❌/⚠️ | |
| `go vet ./...` | ✅/❌/⚠️ | |
| `go test ./...` | ✅/❌/⚠️ | cobertura por paquete tocado |
| `golangci-lint run ./...` | ✅/❌/⚠️ | comparado contra `origin/main` |
| `go test -race` | ✅/N/A | sólo si el diff toca concurrencia |
| Modernización (`go fix -diff`) | ✅/❌/N/A | |
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
| Cohesión y minimalismo de archivos | ✅/❌/N/A | |
| Patrones handler | ✅/N/A | |
| Llamadas externas httpclient | ✅/N/A | |
| Integración bus (nombres, AutoAck, DLQ, idempotencia) | ✅/❌/⚠️/N/A | |
| Patrones de test | ✅/N/A | |
| Sin código duplicado | ✅/❌ | |
| Nombres y convenciones | ✅/❌ | |
| Diseño de firmas (ctx/error/params) | ✅/❌ | |
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
<summary>📝 Nombres — propuestas de renombrado</summary>

| # | Archivo | Actual | **Propuesto** | Razón |
|---|---------|--------|---------------|-------|
| 1 | `path/file.go:24` | `{nombre actual}` | `{nombre propuesto}` | {regla en una línea} |
| — | — | Todas las convenciones seguidas ✅ | — | — |

Verificado: receptores, `ctx` primero, `error` último, acrónimos (`ID`/`URL`/`HTTP`),
stuttering, alias de import, palabras ruido (`Data`/`Info`/`Manager`), verbos vacíos,
constantes autodescriptivas.

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
- [ ] **`path/to/file.go:24`** — `[naming]` suggestion: rename `{current}` → `{proposed}` ({rule}). Follow a clearer, more meaningful nomenclature. *(suggestion, non-blocking)*
  ```suggestion
  {the full file.go:24 line, already with the corrected name}
  ```
  _(one bullet per real row of the naming table; `suggestion` only for single-site renames — multi-site goes to the table with `gofmt -r`)_

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
| **Evidence base (Phase 0)** | | |
| `go build ./...` | ✅/❌/⚠️ | |
| `go vet ./...` | ✅/❌/⚠️ | |
| `go test ./...` | ✅/❌/⚠️ | coverage per touched package |
| `golangci-lint run ./...` | ✅/❌/⚠️ | compared against `origin/main` |
| `go test -race` | ✅/N/A | only if the diff touches concurrency |
| Modernization (`go fix -diff`) | ✅/❌/N/A | |
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
| File cohesion & minimalism | ✅/❌/N/A | |
| Handler patterns | ✅/N/A | |
| External calls httpclient | ✅/N/A | |
| Bus integration (names, AutoAck, DLQ, idempotency) | ✅/❌/⚠️/N/A | |
| Test patterns | ✅/N/A | |
| No duplicate code | ✅/❌ | |
| Naming & conventions | ✅/❌ | |
| Signature design (ctx/error/params) | ✅/❌ | |
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
<summary>📝 Naming — rename proposals</summary>

| # | File | Current | **Proposed** | Reason |
|---|------|---------|--------------|--------|
| 1 | `path/file.go:24` | `{current name}` | `{proposed name}` | {rule, one line} |
| — | — | All conventions followed ✅ | — | — |

Checked: receivers, `ctx` first, `error` last, initialisms (`ID`/`URL`/`HTTP`),
stuttering, import aliases, noise words (`Data`/`Info`/`Manager`), empty verbs,
self-describing constants.

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

### Step 0 — Check out `main` before scanning (MANDATORY)

**The scan runs on `main`, never on a feature branch.** Checking out the latest
`main` is a required precondition, not an option — a scan of a stale or feature
checkout reports findings already fixed upstream and misses ones just merged. Do
this first, every time, before any grep runs:

```bash
git fetch origin
git checkout main
git pull --ff-only origin main
git rev-parse --short HEAD    # record the audited commit for the report header
```

This is the default and expected path: whenever the working tree is **clean**,
switch to `main` and pull — even if the user is currently on a feature branch (a
clean checkout is restored trivially with `git checkout -`).

**Only exception — a dirty working tree.** If (and only if) there are uncommitted
changes that a checkout would clobber, do NOT switch branches. Instead check out the
latest `main` in an isolated worktree, exactly like the review flow (Step 0.1), and
run the scan there:
  ```bash
  git fetch origin
  WT="<scratchpad>/scan-main"
  git worktree add --detach "$WT" origin/main
  cd "$WT"          # run the scan here; <path> is relative to this worktree
  ```
  Remove it when done (from the repo root, never from inside the worktree):
  ```bash
  cd <repo-root> && git worktree remove --force "$WT" && git worktree prune
  ```

Report which commit of `main` the audit ran against (`git rev-parse --short HEAD`)
in the scan header, so the findings are reproducible.

### Step 1 — Discover go-bricks version and features

```bash
grep 'go-bricks' go.mod
BRICKS=$(go env GOMODCACHE)/github.com/gaborage/go-bricks@$(grep go-bricks go.mod | awk '{print $2}')
```

### Step 2 — Run all anti-pattern checks

Run every grep from checks 1, 1b, 2, 4, 5, 6, 7, 8, 9, 11, 12, 12b, 13 against `<path>`.
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
- **Include the remediation roadmap (Step 6)** — a scan without a plan is a list of
  complaints

### Step 6 — Remediation roadmap (MANDATORY for `scan`)

A list of 40 findings is not actionable. The deliverable of `scan` is **an ordered,
sized execution plan**: what to fix, in what order, and split into phases a developer
can actually merge. Same phase discipline as `/migrate` (see
`novo-legacy-migration-endpoint`), because these fixes travel through the same
pipeline.

#### 6.1 Hard constraints per phase (inherited from `/migrate`)

| Constraint | Value | Source |
|---|---|---|
| Max new lines per phase (impl + tests) | **≤400** | NKH1 sizing / `/migrate` |
| Max files per phase | **≤10** | NKH1 sizing / `/migrate` |
| Branch | `feature/{TICKET}-{slug}-{n}`, **always from `main`** | `/migrate` |
| Per phase | tests + `make check` (0 issues) + **semantic version bump** (minor `feat` / patch `fix`·`refactor`) | `/migrate` |
| Merge order | one phase merged before the next starts | `/migrate` |
| Security fixes (SQL injection, PCI) | **≤300 lines**, surgical, first in the queue | stricter, as `parity-solve` |

If a fix does not fit, **split it** — never widen a phase. A "phase" that touches
three modules is two phases.

#### 6.2 Prioritization

Order by **risk × blast radius**, not by how easy it is:

| Prio | What goes here | Why first |
|:--:|---|---|
| **P0** | SQL injection, PCI leaks (PAN/CVV in logs), tenant-isolation breaks, resource leaks in hot paths | Exploitable or already leaking |
| **P1** | Correctness: swallowed errors, lost error chain, goroutine leaks, fail-open branches | Silent wrong behavior in production |
| **P2** | Layer violations, raw `net/http` / `sql.DB` instead of go-bricks, duplicated clients | Structural debt that multiplies with each new module |
| **P3** | rawQuery migratable to QueryBuilder, dead scaffolding, duplicated constants/types | Maintenance cost, no runtime risk |
| **P4** | Naming, missing docs, modernization (`go fix`) | Readability; batch them, never a phase of their own |

Two sequencing rules that override raw priority:

1. **Enablers first.** If five P3 findings all disappear once one shared helper
   exists, that helper is phase 1 even though it is P3 — it converts five phases
   into one.
2. **Never mix priorities in one phase.** A P0 phase must be reviewable in ten
   minutes; padding it with renames destroys that.

#### 6.3 Estimating a phase

For each finding, estimate `~N líneas` = impl + tests. Rules of thumb, stated as
estimates and never as fact:

| Fix type | Typical |
|---|---|
| Constant/alias rename (mechanical, IDE-assisted) | ~5-20 líneas, muchos archivos → cuidado con el cap de 10 files |
| Wrapping an error / adding `%w` + test | ~10-25 líneas |
| Adding a missing error-path test | ~20-40 líneas |
| Migrating one raw `const` query to QueryBuilder + test | ~40-80 líneas |
| Replacing a raw `net/http` client with the connector + tests | ~120-200 líneas |
| Extracting a shared helper consumed by N call sites | ~80-150 líneas + N × ~5 |

When a rename touches more than 10 files, the file cap — not the line cap — is what
splits it. Say so explicitly in the roadmap.

#### 6.4 Roadmap output format

```
Roadmap de remediación — {path}
Hallazgos: {N} (P0:{a} P1:{b} P2:{c} P3:{d} P4:{e})   ·   Fases estimadas: {F}

Fase 1 · P0 · feature/{TICKET}-sqlsafe-1          ~{X} líneas · {n} files
  ├─ repo/legacy.go:30   fmt.Sprintf+SQL → QueryBuilder            ~60
  └─ repo/legacy.go:78   f.Raw() sin parametrizar → f.Raw(cond,?)  ~20
  Desbloquea: nada · Bloqueado por: nada

Fase 2 · P1 · feature/{TICKET}-errchain-1         ~{Y} líneas · {n} files
  └─ service/card.go:112  %s → %w (rompe errors.Is en 3 callers)   ~15
  Desbloquea: Fase 5 (tests de error path)

Fase 3 · P2 · feature/{TICKET}-connector-1        ~{Z} líneas · {n} files
  └─ cards/processing → platform/connector (elimina net/http crudo) ~180
  Enabler: colapsa las fases 6 y 7 en una

...

Diferido (no entra en fases):
  · {hallazgo}  — {por qué no ahora: bloqueado por X / requiere decisión de producto}

Batch final · P4 · feature/{TICKET}-naming-1      ~{W} líneas · {n} files
  └─ 12 renombrados (tabla de nombres) — mecánico, un solo commit
```

Rules for the roadmap:

- **Every phase states `~líneas` and `files`** and both must be under the cap. If
  a row exceeds it, it is already split in the output — do not emit an over-cap phase
  and add "habría que dividirlo".
- **Declare dependencies** (`Bloqueado por` / `Desbloquea`) so the order is not
  arbitrary. A phase with no dependencies can be parallelized by another developer;
  say which ones those are.
- **`Diferido` is a first-class section.** Findings that need a product decision, or
  that depend on work outside the scanned path, go here with the reason — not
  silently dropped, not padded into a phase.
- **Total estimate at the top**, and the honest caveat that line counts are
  estimates from static reading, not measurements.
- **Present the roadmap and stop.** `scan` never creates branches and never edits
  code — it produces the plan. Branch creation follows the `/migrate` flow (ask for
  the Jira ticket, `git checkout main && git pull`, one branch per phase).

File name: `scan-{path-slug}-audit.md` — same temp-dir rule as the review report.

---

## References

The rules in this skill are grounded in these sources — cite them when an author
pushes back on a naming or concurrency finding:

- [Google Go Style Guide — Decisions](https://google.github.io/styleguide/go/decisions) — naming, receivers, scope-proportional length, getters, initialisms (check 9)
- [Go Concurrency review checklist](https://github.com/code-review-checklists/go-concurrency) — goroutine lifecycle, `time.Ticker`, `sync.Map`, `RWMutex` (check 12b)
- [Testing concurrent code with testing/synctest](https://go.dev/blog/synctest) — deterministic concurrency tests, stdlib since Go 1.25 (check 12c)
- [Go 1.26 release notes](https://go.dev/doc/go1.26) — `go fix` modernizers, Green Tea GC, `goroutineleak` pprof profile (check 16)
- [golangci-lint v2 docs](https://golangci-lint.run/docs/linters/) — `linters.default` replaced `enable-all`/`disable-all` (Phase 0)
- [Clean Code, cap. 2 — Meaningful Names](https://www.cs.hmc.edu/cs70/homework/homework-03/pdfs/stylemartin.pdf) — intention-revealing names, noise words, consistent lexicon (check 9.0b)
- go-bricks `messaging` / `outbox` / `inbox` packages — `Declarations.Validate()`, `ConsumerDeclaration`, `EventIDFromHeaders`, `Inbox.ProcessOnce` (check 6b). Read them in `$(go env GOMODCACHE)/github.com/gaborage/go-bricks@<ver>/`
- NKH1 `common:pr-review` — sizing, title, coverage floor, promotion gates (Phase 1)
- `novo-legacy-migration-endpoint` (`/migrate`) — phase caps (≤400 líneas / ≤10 files), branch-per-phase from `main`, version bump per phase (scan Step 6)

**Keep this list honest**: when a rule here stops matching the linked source
(a Go release changes a default, the style guide is revised), update the rule —
do not let the skill drift into folklore.
