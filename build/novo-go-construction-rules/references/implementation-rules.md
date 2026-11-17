# Implementation Rules

> Shared construction rules, loaded on demand by `novo-legacy-migration-endpoint` and `novo-go-build`.
> Binding exactly as if they were inline. Where the text says Java, parity or `EST-NN`, see "Reading these rules" in `SKILL.md`.

### go-bricks First (NON-NEGOTIABLE)

Before writing ANY code in any phase:
1. Check `gobricks_mapping` in `.migration-context.yaml`
2. Cross-reference [`novopayment/mdw-welcome-project-go`](https://github.com/novopayment/mdw-welcome-project-go)
   — the canonical reference for go-bricks usage and Go architecture; follow its module/layer/wiring patterns
3. Grep go-bricks source for the types you need
4. If go-bricks has it → use it directly
5. If go-bricks doesn't have it → implement it, but follow go-bricks + welcome-project patterns

**go-bricks provides:**
- HTTP server, routing, handler context → `server.*`
- DB access, transactions → `database.Interface`, `db.Begin`
- HTTP client for external calls → `httpclient.Client`
- JWE encryption/decryption → `cryptoutil.*`
- Logging → `logger.Logger` (zerolog-based)
- Config injection → `deps.Config.InjectInto`
- Module system → `app.Module` interface
- Test helpers → `fixtures.NewMockRows`, `mocks.MockDatabase`, `mocks.MockTx`

### Parity (NON-NEGOTIABLE)

- **Java business rules ARE the spec — always respected.** Migrate the decision exactly: codes,
  messages, validation precedence, response shape. Default = replicate the Java behavior.
- Error codes and messages are **IMMUTABLE** — match source exactly
- Validation order / precedence must match source
- Response structure (field names, nesting, null behavior) must match
- **Critical bug** (data corruption, security, wrong outcome/amount, money loss) → the ONLY exception:
  **REPORT it** with `⚠️ Bug Java detectado:` (severity · impact · Java location · proposed Go
  mitigation) and **DECIDE WITH THE USER** whether to mitigate in Go or replicate as-is. Never
  silently fix, never silently replicate a critical bug. This is *parity, but for bugs*: report → decide → act.
- **Non-critical bug** → fix in Go, mention the deviation explicitly.

### Rule consolidation & performance parity (efficiency without breaking the decision)

Legacy code often **scatters and REPEATS** the same business rules across layers (resource + service
+ dao) and **re-fetches the same data multiple times** (e.g. cashin: `getUserData`, then
`isCardStatusValidation` and `isCardExpiryDateValidation` each re-query `getCardDetails` — 3 DB reads
of the same card). When migrating to Go:

- **Consolidate** repeated reads/validations into ONE efficient pass (single DB fetch, checks
  evaluated in order). Do NOT replicate the source's redundant re-queries / re-validations.
- **Preserve the business OUTCOME exactly**: the same code/message must win, in the same **order of
  precedence** (the check that fires first in the source must still fire first in Go). Parity is
  about the *decision*, not the number of round-trips.
- **Always flag the consolidation** in the STEP 0 analysis and the PR: list which source steps were
  merged and why it's outcome-equivalent (this is the "flow improvement — mention the deviation" rule).
- Net effect = **performance parity**: identical rules, fewer DB hits, no reprocessing.

In `verify-parity`, a Go consolidation of repeated source checks is **🟢 mejora intencional** (NOT a
divergence) — *as long as* the firing order and resulting code/message match. If the consolidation
changes WHICH error wins or its precedence, that IS a 🔴 divergence.

### Every created unit ships with its use-case test (NON-NEGOTIABLE)

Everything this skill creates or changes — handler, service method, repository method, mapper,
validator, helper with logic — **must have a unit test of its use case, in the same phase and the
same PR**. Never "tests in the next phase", never "covered indirectly by a bigger test".

- **Use-case test, not coverage padding.** Each test pins a business scenario and asserts the
  **observable outcome**: the rc/HTTP returned, the rows written or not, the external call made or
  not, the error that wins. A test that only executes lines fails review check 15.
- **Named after the scenario, traceable to the use-case list.** When `/migrate usecases` has
  produced the `EST-NN` list (or `plan-data.yaml` has the approved cases), name the test after it:
  `TestService_Foo_EST03_PanNotRegistered`. The case ids are the same ones QA certifies, so a test
  that matches no case is either a missing case in the list or noise.
- **Every branch that changes the response is a case:** each business error code, each validation
  precedence, success variants, the repository/DB error and the not-found path. Money-path
  decisions are tested branch by branch.
- **Written with the code, in the same phase.** Test-first is welcome. A phase with production code
  and no test for it has not ended.
- **Exempt (no logic to validate):** plain DTO/struct declarations, constants, generated code and
  module wiring (`module.go` route registration is covered by the handler test that hits the route).
  Anything with a branch, a computation or a side effect is NOT exempt.
- **Tests exercise the real unit with mocks at its boundary** (go-bricks `mocks.MockDatabase`,
  `fixtures.NewMockRows`, mocked repo/service), per "Testing Patterns" below.
- **Name the seams before writing the tests.** List, in the phase plan the user already approves,
  the public boundary each unit is tested at (handler HTTP, service method, repository method)
  and what is mocked there. A test at a seam that is not in the plan needs the user's OK first.
- **Expected values come from outside the code under test.** The oracle is the Java behavior, a
  literal from `RESPONSE_CODES`, or an approved `EST-NN` case — never a value computed with the
  same function, constant or query the unit uses (a tautological test passes whatever the code
  does). A hand-written literal beats `want := svc.Compute(in)`.
- **Mock only the boundary.** Mock the collaborator below the unit (DB through go-bricks mocks,
  external HTTP client, clock, randomness, the repo/service interface). Never mock the unit under
  test or its private helpers, and never assert only that a mock was called: assert the outcome.
- **Name tests by capability and scenario** (`TestService_Foo_EST03_PanNotRegistered`), not by
  internals (`TestService_Foo_CallsRepoTwice`), so a refactor does not rename them.

**Gate (checked at Phase END, step 3b):** build the use-case coverage matrix — one row per unit
created or changed in this phase, with its test(s) and `EST-NN`. A unit without a row, or a
`0.0%` function in a changed file, fails closed: write the test before the phase ends.

### Code Quality

| Rule | Details |
|------|---------|
| **No source-language refs in comments** | Never mention Java, Jackson, Spring, etc. Check: `grep -rn "Java\|Jackson\|parity\|Spring"` |
| **Max 7 params** | Group into struct |
| **Complexity ≤ 15** | Extract helpers |
| **Comments: short, clear, WHY not WHAT** | No lengthy comments — one or two concise lines explaining the *why*. **≤100 chars per line, no exceptions.** If it needs a paragraph, the code or the name is the problem: rename/extract instead. No narrating the code, no history, no ticket stories |
| **Extend before add** | Same table → extend existing method |
| **Constants stay local** | Unexported if single-package use |

### Architecture

| Rule | Details |
|------|---------|
| **getDB func pattern** | Never inject raw DB |
| **SQL in queries.go** | Never inline SQL |
| **Positional placeholders** | builder generates `:1..n` Oracle, `$N` PostgreSQL; `database.Raw(sql, args...)` takes positional args |
| **External clients in shared pkg** | Not in service/ |
| **Filtering in SQL** | Never in-memory |
| **Config in both files** | Env placeholders + local values |

### Security

| Rule | Details |
|------|---------|
| **New PAN/CVV/expiry/cardToken fields masked in logs** | Add the field names to `log.sensitivefields` (YAML, additive to the defaults — bare `pan`/`card` are not default needles) or implement `RedactedForLog() any` (`logger.Redactor`, ADR-110, value receiver) on the DTO |
| **Never log the decrypted request** | Do not pass the decrypted request/DTO to `logger.Interface`/`WithFields` unless it implements `logger.Redactor` |
| **`LoggerFilterConfig` in code** | `app.Options.LoggerFilterConfig` replaces the whole config — start from `logger.DefaultFilterConfig()` and append, never a bare struct literal |
| **Raw SQL annotation** | `// SECURITY: Manual SQL review completed - <what was verified>` above every raw/Expr site (see "When a query CANNOT use the builder") |

### Tenant Config Sections

Before adding a new `mapstructure:"<name>"` section to a module's own tenant-config struct
(`tenantCustom` or equivalent), check whether **another module already declares a top-level
section with that same name** (e.g. `params`, `processing`). If one does, the unexpanded-`${VAR}`
placeholder warning each module emits at startup can start reporting the OTHER module's own
switches as if they were yours.

Why: that warning filters by section NAME at the section's own nesting level, not by which module
owns a leaf underneath it. Two modules both declaring `params` means either one's warning walks
the WHOLE `params.*` subtree, sibling module's business switches included.

Fix: exclude the sibling's subtree explicitly (e.g. a shared `UnexpandedKeysExcept(custom,
skip...)` helper next to whatever draws `UnexpandedKeysFor`) BEFORE the new section ships — not
after a reviewer catches the noise in a real PR. Caught on an embossCard migration (CEB-5935,
2026-09-30): adding `params.emboss` to `cards`' own tenant config made its startup warning list
`accounts`' `params.card`/`params.account`/`params.customer` switches too, since both modules
declare `params`.

### Date Handling

| Pattern | Go |
|---------|-----|
| `MM/YYYY` | Normalize, `time.Parse("01/2006", s)` |
| `YYYY-MM-DD` | `time.Parse("2006-01-02", s[:10])` |
| `dd/MM/yyyy` | `time.Parse("02/01/2006", s)` |
| Last day | `firstOfNext.AddDate(0, 0, -1)` |
| Query upper bound | `dateTo.AddDate(0, 0, 1)` |
| Echo trailing slash | Trim before parsing |
| Test assertions | `time.Date()` + `.Truncate(24h)` |

### JSON Parity

| Issue | Fix |
|-------|-----|
| `float64(0)` → `0` | Custom type with `MarshalJSON` |
| Null fields | `omitempty` tag |
| String or number field | Custom `UnmarshalJSON` |

### Compensation Pattern

When external call succeeds but DB write fails:
1. Best-effort compensation call to reverse — on `context.WithoutCancel(ctx)` (keeps trace/tenant
   values; the request ctx is already cancelled if the failure was a timeout), never
   `context.Background()`
2. Log attempt
3. Return original error
4. Test both: compensation succeeds + fails

If the side effect is **publishing an event** (not an HTTP call), don't compensate: write it with
the go-bricks outbox in the same DB transaction (`outbox.Publish(ctx, tx, …)` before `tx.Commit`).
