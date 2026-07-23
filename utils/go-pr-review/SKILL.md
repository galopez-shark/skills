---
name: go-pr-review
description: "Go PR review for go-bricks services — extends the standard NKH1 pr-review with go-bricks framework validation, reuse checks, and layer discipline. Catches reinvented types, raw DB/HTTP usage, wrong layer boundaries, and missing go-bricks patterns. Usage: /go-pr-review <PR_URL>"
license: MIT
metadata:
  author: galopez-shark
  version: "1.2.0"
  domain: review
  triggers: go-pr-review, go pr review, review go pr, go-bricks review
  role: specialist
  scope: code-review
  output-format: report
  related-skills: novo-legacy-migration-endpoint, go-bricks-modules
---

# Go PR Review (go-bricks)

Extends the standard NKH1 `common:pr-review` with go-bricks framework validation.
Run BOTH — NKH1 first, then go-bricks checks.

## Usage

```
/go-pr-review <PR_URL> [LANG]
```

- `LANG` is an optional ISO language code: `EN`, `ES`, `PT`, etc.
- **Default language is Spanish (`ES`)** — if no `LANG` is provided, the entire
  report (headings, descriptions, fix suggestions, verdict) MUST be written in Spanish.
- When `LANG=EN` is passed, write the report in English.
- Section titles in the markdown template (## Bloqueadores, ## Debe corregirse, etc.)
  and the go-bricks gate table header labels MUST also be translated to the target language.
- Code snippets, Go identifiers, and file paths are always in English (they are code).

Examples:
- `/go-pr-review https://github.com/novopayment/multitenant-banking-api-be-go/pull/27` → report in **Spanish**
- `/go-pr-review https://github.com/novopayment/multitenant-banking-api-be-go/pull/27 EN` → report in **English**

The `<PR_URL>` is the GitHub pull request URL. The skill will:
1. Fetch the PR diff
2. Run NKH1 standard review
3. Run go-bricks validation checks
4. Report combined findings in the requested language

## How to get the diff (MANDATORY — never guess the branch)

The PR URL is the source of truth. You MUST resolve the actual PR branch before
reviewing — never assume which branch a PR number corresponds to.

**Step 1 — Resolve the PR ref locally** (works even without `gh` auth):
```bash
# Always works on any repo you can fetch from:
git fetch origin refs/pull/<PR_NUMBER>/head:pr-<PR_NUMBER>
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

### Phase 2 — go-bricks validation (this skill adds)

After the NKH1 review, run the go-bricks checks below. These are
**blockers** — a PR that reinvents a go-bricks type or breaks layer
boundaries is not ready to merge regardless of NKH1 compliance.

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

---

## Reporting — Markdown output

The final report MUST be formatted as **inline markdown** delivered directly to the user
(never create a file). The report language depends on the `LANG` parameter:

- **No `LANG` or `ES`** → Spanish (default)
- **`EN`** → English
- Other codes → use that language

All prose (headings, descriptions, issue explanations, fix suggestions, verdict)
MUST be in the target language. Code snippets, Go identifiers, file paths, and
go-bricks type names stay in English (they are code).

### Template — Spanish (default)

```markdown
# Revisión PR: #{number} — {title}

**Repo**: {org/repo}
**Rama**: {branch} → main
**Archivos**: {count} | **Líneas**: +{added} / -{removed}

---

## Bloqueadores

### 1. [NKH1] {título corto}
**Archivo**: `path/to/file.go:42`
**Problema**: {qué está mal}
**Corrección**:
\`\`\`go
// corrección sugerida
\`\`\`

### 2. [go-bricks] {título corto}
...

---

## Debe corregirse

### 1. [go-bricks] {título corto}
...

---

## Nombres y convenciones

| # | Archivo | Actual | Sugerido | Regla |
|---|---------|--------|----------|-------|
| 1 | `domain/dto.go:5` | `BlockTypeId` | `BlockTypeID` | Convención de acrónimos |
| 2 | `service/cards.go:1` | `CardsService` | `Service` | Sin tartamudeo |

---

## Observaciones menores

- `file.go:10` — {descripción}

---

## Resumen de validación go-bricks

| Verificación | Estado | Notas |
|-------------|--------|-------|
| Sin tipos reinventados | ✅/❌ | |
| Límites de capa correctos | ✅/❌ | |
| Cableado de módulo correcto | ✅/N/A | |
| Patrones de BD seguidos | ✅/N/A | |
| Patrones de handler correctos | ✅/N/A | |
| Llamadas externas vía httpclient | ✅/N/A | |
| Patrones de test correctos | ✅/N/A | |
| Sin código duplicado | ✅/❌ | |
| Nombres y convenciones | ✅/❌ | |
| Config completa | ✅/N/A | |

**Veredicto**: ✅ Aprobado / ❌ {N} bloqueadores pendientes
```

### Template — English (when `LANG=EN`)

```markdown
# PR Review: #{number} — {title}

**Repo**: {org/repo}
**Branch**: {branch} → main
**Files**: {count} | **Lines**: +{added} / -{removed}

---

## Blockers

### 1. [NKH1] {short title}
**File**: `path/to/file.go:42`
**Issue**: {what's wrong}
**Fix**:
\`\`\`go
// suggested fix
\`\`\`

### 2. [go-bricks] {short title}
...

---

## Should-fix

### 1. [go-bricks] {short title}
...

---

## Naming & conventions

| # | File | Current | Suggested | Rule |
|---|------|---------|-----------|------|
| 1 | `domain/dto.go:5` | `BlockTypeId` | `BlockTypeID` | Acronym convention |
| 2 | `service/cards.go:1` | `CardsService` | `Service` | No stuttering |

---

## Nits

- `file.go:10` — {nit description}

---

## go-bricks gate summary

| Check | Status | Notes |
|-------|--------|-------|
| No reinvented types | ✅/❌ | |
| Layer boundaries clean | ✅/❌ | |
| Module wiring correct | ✅/N/A | |
| DB patterns followed | ✅/N/A | |
| Handler patterns correct | ✅/N/A | |
| External calls via httpclient | ✅/N/A | |
| Test patterns correct | ✅/N/A | |
| No duplicate code | ✅/❌ | |
| Naming & conventions | ✅/❌ | |
| Config complete | ✅/N/A | |

**Verdict**: ✅ Approve / ❌ {N} blockers remain
```

Mark checks as N/A when the PR doesn't touch that layer (e.g., domain-only
PR → DB patterns, handler patterns, external calls are all N/A).

The **Naming & conventions** table is always present — even if all names are
correct, show the table with a "Todas las convenciones seguidas ✅" (ES) /
"All naming conventions followed ✅" (EN) row.
