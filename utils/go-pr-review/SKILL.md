---
name: go-pr-review
description: "Go PR review for go-bricks services — extends the standard NKH1 pr-review with go-bricks framework validation, reuse checks, and layer discipline. Catches reinvented types, raw DB/HTTP usage, wrong layer boundaries, and missing go-bricks patterns. Usage: /go-pr-review <PR_URL>"
license: MIT
metadata:
  author: galopez-shark
  version: "1.0.0"
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
/go-pr-review <PR_URL>
```

Example: `/go-pr-review https://github.com/novopayment/multitenant-banking-api-be-go/pull/27`

The `<PR_URL>` is the GitHub pull request URL. The skill will:
1. Fetch the PR diff
2. Run NKH1 standard review
3. Run go-bricks validation checks
4. Report combined findings

## How to get the diff

```bash
# Extract org/repo and PR number from the URL
# e.g. https://github.com/novopayment/multitenant-banking-api-be-go/pull/27
gh pr diff <PR_NUMBER> --repo <ORG/REPO>
# Fallback if gh auth fails:
git diff origin/main...origin/<branch-name>
```

If `gh` auth fails, identify the PR branch from `gh pr view` or the URL, then use `git diff` locally.

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

### 9. Config completeness (NIT)

If the PR adds config consumption (`config:` tags or `deps.Config`):

- [ ] Key exists in both `config.yml` (env vars) and `config.yaml` (local values)
- [ ] New config key follows existing naming convention
- [ ] Sensitive values use env var placeholders, not hardcoded

---

## Reporting

Combine NKH1 and go-bricks findings in a single report, grouped by severity:

1. **Blocker** — NKH1 blockers + go-bricks checks #1 (reinvented types) and #2 (layer boundaries)
2. **Should-fix** — NKH1 should-fix + go-bricks checks #3-#8
3. **Nit** — NKH1 nits + go-bricks check #9

For each finding:
- Cite `file:line`
- State what's wrong
- Give a concrete fix (code snippet or command)
- Tag it as `[NKH1]` or `[go-bricks]` so the developer knows which standard applies

End with a **go-bricks gate summary**:

```
┌──────────────────────────────────────────────────┐
│          go-bricks VALIDATION — PR #{N}          │
├──────────────────────────────────────────────────┤
│ CHECK                    │ STATUS │ NOTES        │
│──────────────────────────│────────│──────────────│
│ No reinvented types      │ ✅/❌  │              │
│ Layer boundaries clean   │ ✅/❌  │              │
│ Module wiring correct    │ ✅/N/A │              │
│ DB patterns followed     │ ✅/N/A │              │
│ Handler patterns correct │ ✅/N/A │              │
│ External calls via hc    │ ✅/N/A │              │
│ Test patterns correct    │ ✅/N/A │              │
│ No duplicate code        │ ✅/❌  │              │
│ Config complete          │ ✅/N/A │              │
└──────────────────────────────────────────────────┘
```

Mark checks as N/A when the PR doesn't touch that layer (e.g., domain-only
PR → DB patterns, handler patterns, external calls are all N/A).
