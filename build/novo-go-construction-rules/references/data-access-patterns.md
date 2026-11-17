# Reference — Data-access & repository patterns (project-agnostic)

> Moved out of `SKILL.md` to save context. Everything here is binding exactly as if it were inline.

Apply these when writing or refactoring any repository layer. They are framework-level (go-bricks)
and NOT tied to any one migration project.

### 0. Reuse the shared reader before you write a new repository (do this FIRST)

**Generic rule.** Before adding a module repository to read a domain table, check whether a
**shared, cross-cutting reader already reads it** — a reader that lives outside any single module
(in the project's shared/platform package) and that the already-migrated modules reuse. Do not fork
a parallel data-access stack.

- **Look first** in the project's shared/platform package for a reader over the tables you need,
  plus any helper that locates one item inside the returned aggregate. Reuse it.
- **Before reusing it, classify what it actually is** — a "shared/platform" reader can mean two
  different things, and treating both the same is how a domain concept ends up living where no
  module owns it:
  - **Generic mechanics** (query builder wrappers, connection/executor, pagination helpers) —
    belongs in `platform`/`plataform`, no question.
  - **A real domain concept** (Customer, Card, Account) that several modules happen to consume —
    this is not infrastructure, it is **cross-module consumption of a business concept**. Route it
    through rule 0b's second branch (consume via a local interface, or plan its own module) instead
    of defaulting to "it's already in platform, so reuse it as-is." If it is already sitting under
    `platform` today, that is a placement debt to name in the phase plan, not a reason to keep
    extending it as if it were generic.

  **Classifying it as a domain concept is never a licence to fork your own reader.** The
  classification changes *how you consume it* — through a local interface instead of reaching for
  its DTO — never *whether you duplicate it*. A parallel data-access stack over the same tables is
  a check 8a finding regardless of how the existing reader is classified.
- **If it lacks a column** the new flow needs, the answer depends on **whose knowledge that
  column is** — decide before writing it, because `go-dev-technical` check 8a enforces both
  directions:
  - **A genuine attribute of the entity the reader models** (Customer gains a Customer field) →
    **extend the shared query + the shared DTO.** The change is additive and every consumer
    benefits. Do NOT build a new `sql_repository.go` + Row struct + `ScanColumns` + `mapper.go` +
    a local DTO to re-read the same tables. Well-built duplication is still duplication.
  - **Only meaningful to THIS consumer**, and to none of the others already reusing that reader →
    **do not extend it.** The field goes behind an adapter/translator in your own module. Bolting
    it on turns the shared reader into a grab-bag accumulating knowledge from every module that
    ever touched it — review check 8a reports that as `[reuse-leak]`, so extending it here costs a
    review round.

  The test, in one question: *if another consumer of this reader read that field, would it mean
  anything to them?* Yes → it belongs to the entity, extend. No → it is your module's knowledge,
  adapt it locally.
- **A new dedicated reader is justified only** when it returns data the shared reader structurally
  cannot (a genuinely different aggregate) — not merely a couple of extra columns or a filter a
  consumer can apply on the returned aggregate.
- This is the authoring side of `go-dev-technical` check 8a — build it right here and the review is
  clean. Record the reuse in the PR ("reused without duplicating: …").

*Example (zinli-business-be-go)*: the shared reader is
`internal/plataform/repository/customer.GetCustomer(tagPay, cardToken)` (customer + cards) with
`cardutils.FindCard(customer, token, activeOnly)`, reused by accounts/operations/funds_transfer. A
`setCardPin` migration needing `SEQUENCE_NUMBER`/`CARD_PROGRAM` extends that shared query+DTO — it
must not fork a parallel card reader.

*Honest caveat on that same example*: `customer.GetCustomer` is exactly the second case above —
a domain concept (Customer) sitting under `plataform` rather than owned by its own module. It is
documented here as the reader that already exists in the real repo, not endorsed as where a new
one like it should be placed going forward. New readers over a business entity default to their
own module (rule 0b); only genuine infrastructure defaults to `plataform`.

### 0b. The endpoint needs data it does not own — decide WHERE it comes from (do this before any repository)

Rule 0 answers one case: a shared/platform reader already reads the table. A migrated endpoint
hits three other cases, and picking wrong produces code that reviews badly and couples two
domains permanently. Answer this at **STEP 0**, before the phase plan:

```
El endpoint necesita un dato que no es suyo. ¿Quién lo posee?
│
├── Un reader compartido/plataforma ya lo lee
│      → Clasifícalo primero (regla 0): ¿mecánica genérica, o un concepto de
│        dominio que solo da la casualidad de vivir ahí?
│      → MECÁNICA GENÉRICA: REUSARLO. Extender su query + DTO solo si la
│        columna es atributo genuino de la entidad (regla 0)
│      → CONCEPTO DE DOMINIO, y ya existe bajo platform: consumirlo igual —
│        es lo que hay hoy— pero declarando una interfaz local en TU módulo,
│        no acoplándote a su DTO. Registrar la deuda de ubicación en el plan
│        de fases. NO forkear un reader paralelo
│      → CONCEPTO DE DOMINIO que todavía no existe: no lo crees en platform;
│        va en el módulo que lo posee (rama de abajo)
│
├── Otro MÓDULO DE NEGOCIO lo posee (cards, accounts, …)
│      → Declarar la interfaz MÍNIMA acá, en el consumidor, y que el service
│        de ese módulo la satisfaga (structural typing, sin import cruzado).
│        Se inyecta en main.go. NUNCA su Repository, structs internos, ni su DB
│
├── Es transversal de verdad — no es propiedad de ningún módulo
│      → Modelarlo en shared/ (no resolverlo entrando al repo de otro)
│
└── Lo posee ESTE módulo
       → Repositorio propio, con las reglas 1-5 de abajo
```

**The base patterns — interface injection for domain services, provider interface
(`app.OutboxProvider`, `app.KeyStoreProvider`) only for framework-managed cross-cutting
infrastructure — belong to the `go-bricks-modules` skill. Do not restate them here; read it
when wiring.** What follows is only what changes *during a migration*.

#### Why never the other module's repository or DB

Three reasons, and the first is the one that bites in production:

- **`deps.DB(ctx)` resolves the connection per tenant, per request.** Holding or reusing
  another module's repository or `*sql.DB` breaks multi-tenant isolation — and it breaks it
  silently, serving one tenant's data under another's request
- **`Repository` is an internal layer, not an exported contract.** Coupling to it ties the
  consumer to the other module's schema, so a new table, a cache or a partition change breaks
  the consumer with no compiler warning
- **`service.go` is explicitly what other modules consume** in the go-bricks standard; the
  repository is not

**This holds even for a single column.** "It's just one query" is the most common way this
rule gets broken during a migration: the legacy Java method read six tables inline, and the
naive port writes one repository over all six. The mechanism does not change with size — only
the size of the method you add to the provider's interface does.

#### The interface goes on the CONSUMER side — that is what kills the import cycle

Depend on the **narrowest** interface, and declare it **in the consuming package**, not in
the provider. This is the Go idiom "accept interfaces, return structs", and it buys two
things a provider-side interface does not:

- **The consumer declares only what it uses** — one or two methods, not the provider's whole
  public contract. Interface segregation decided by whoever *consumes*, not whoever provides
- **It structurally eliminates the import-cycle risk between business modules.** `accounts`
  never needs `import ".../cards"` to name the type: Go's **structural typing** means the
  provider's concrete struct satisfies it implicitly. The only package importing both is
  `main.go`, the composition root, which already does the wiring

```go
// accounts/service.go — la interfaz vive del lado del CONSUMIDOR
type CardsReader interface {
    GetCardBIN(ctx context.Context, cardID string) (string, error)  // solo lo que accounts usa
}

// accounts/module.go
type Module struct {
    Cards CardsReader   // interfaz local — NO cards.Reader, no hay import de cards
}
```

```go
// cards/service.go — el proveedor NO sabe que accounts existe.
// Satisface accounts.CardsReader implícitamente, sin import cruzado.
func (s *service) GetCardBIN(ctx context.Context, cardID string) (string, error) { … }
```

```go
// main.go — único lugar que importa ambos paquetes
accountsMod := &accounts.Module{Cards: cardsMod.Service()}
app.RegisterModules(cardsMod, accountsMod)   // proveedor primero
```

A side benefit worth stating: when the provider later adds or removes business methods the
consumer never used, **the consumer does not even notice** — it only breaks if one of the
one or two methods it actually declared changes.

**Where the interface still belongs to the provider** — the distinction is *who consumes it*:

| Contract | Interface lives in | Why |
|---|---|---|
| Another **module** consuming cross-module (`accounts` → `cards`) | **the consumer** (`accounts.CardsReader`) | least privilege, no cross import, no cycle |
| The module's **own** handler → its service (`Actions`, `Service`) | the **provider** | it is internal to that module, not a cross-module contract |
| **Several modules** consuming the exact same subset | the provider (`cards.Reader`) | one versioned contract beats the same local interface copy-pasted into each consumer |

**What this does NOT fix.** Consumer-side interfaces remove the *import* cycle; they do not
remove a **real bidirectional dependency**. If `cards` also genuinely needs something from
`accounts`, no interface placement saves you — that is a design signal: the shared piece
probably belongs in a third module or `shared/`, or the direction should be inverted with an
event instead of a direct call. Say so in the roadmap rather than wiring both directions.

Either way this is `go-dev-technical` check 19b — an interface carrying more than the
consumer uses — applied before the code exists rather than found in review.

**Two constraints on anything exposed cross-module:**

- **Return domain types, never HTTP request/response DTOs.** Those belong to the `handler`;
  crossing a module boundary with one drags a transport contract into a domain dependency
- **No side effects in a cross-module read** — no bus publish, no outbox write. A read that
  emits events turns every consumer into an accidental producer

#### What this does to the phase plan (the part that is migration-specific)

If the endpoint needs a read that the provider module does not expose yet, **adding that
method is a change in the PROVIDER module, not in this one**. Plan it accordingly:

- It is **its own phase and its own PR** — a different module, different owner, possibly a
  different reviewer
- In **stacked** mode it is the **bottom of the stack**: every later phase depends on it
  compiling. `gh stack add` the consuming phases on top of it
- In **serial** mode it merges first
- Say it out loud in the roadmap, because it is the one phase the user may not expect:
  > Fase 1 — `cards`: exponer `GetCardBIN` en su service (~40 líneas, módulo ajeno)
  > Fase 2 — `operations`: repositorio propio (sobre fase 1)

**Wiring rules that decide whether it even starts** (details in `go-bricks-modules`):

- **Registration order in `main.go` is load-bearing**: the provider must be registered before
  the consumer. Get it wrong and the dependency arrives `nil` — **at runtime, on the first
  request that path serves**. No linter catches it
- **`Init()` fails fast**: if a required dependency was not injected, `return error` with the
  module name. A module that constructs itself half-wired defers the failure to production
- **Never expose internal HTTP between modules of the same binary.** This is in-process
  interface injection, not a network call — an internal endpoint to serve a sibling module is
  a latency, auth and observability problem invented to avoid a struct field

### 1. The query builder is the default — raw SQL is an exception you must justify

**Not a preference, a default with a burden of proof.** Every query this skill writes goes
through the go-bricks query builder unless the builder **provably cannot express it**, and
"provably" means the empirical test in section 2, not an opinion.

The severity is not ours to soften — `go-dev-technical` **check 1b** owns it and will apply
it to the PR:

| What you wrote | Review verdict |
|---|---|
| `fmt.Sprintf` / `Fprintf` / `+` concatenation / `strings.Replace` into SQL | **BLOCKER — injection vector.** No exceptions, not even for a one-off admin query |
| Raw SQL `const` the builder *could* express | SHOULD-FIX — migrate it |
| Raw SQL `const` the builder cannot express, **with its `// SECURITY: Manual SQL review completed - …` annotation** | ✅ Justified, and check 18b honors that justification instead of re-flagging it |
| Raw SQL `const` the builder cannot express, **with no annotation** | SHOULD-FIX — go-bricks requires the annotation at every raw call site |

**Two rules that follow, and they are the whole point of doing this at construction time:**

1. **Raw does NOT mean interpolated.** A raw statement still binds every value as a
   parameter — positional `:1..n` (Oracle; the builder generates them, and `database.Raw(sql,
   args...)` takes positional args) or `$N` (PostgreSQL). The escape hatch is from the
   *builder*, never from parameterization. A raw query with a value pasted into the string
   is the BLOCKER above, and being raw does not excuse it
2. **Write the SECURITY annotation now, in the same commit.** go-bricks requires
   `// SECURITY: Manual SQL review completed - <what was verified>` on the line above every
   `f.Raw`, `jf.Raw`, `database.Raw`, `SetExpr`, string `Having(...)`, `qb.Expr`/`qb.MustExpr`
   and `RawExpression{}` call site — naming the construct the builder cannot express (`WITH`,
   an optimizer hint) and the property checked (value-side parameterization, no user-input
   concatenation). It costs seconds while the reason is in your head, and it converts a review
   finding into a justified exception. Reconstructing it later costs a review round trip


- Model each table as a typed descriptor `Entity[T]{ Name, Columns }` and build queries with the
  go-bricks query builder (`qb.Select/Insert/Update/Delete`, `dbtypes.MustTable`, `qb.Filter()`,
  `qb.JoinFilter()`, `OrderBy`, `qb.MustExpr`) instead of hand-written SQL strings.
- Aliased joins: qualify columns as `"a."+e.Columns.Field`; `From(MustTable(e.Name).MustAs("a"))`,
  `LeftJoinOn(MustTable(x.Name).MustAs("b"), jf.EqColumn("a.col","b.col"))`.
- Replace the optional-filter trick `(:x IS NULL OR col = :x)` with a **conditional filter**:
  `where := f.Eq(col, id); if x != "" { where = f.And(where, f.Eq(tokCol, x)) }` — cleaner, no
  `*string` nil param, and it reads as intent.
- Match the existing schema-qualification convention: if the module's already-migrated SELECTs use
  UNqualified table names (relying on the connection's default schema), migrate writes the same way
  (drop the `SCHEMA.` prefix) so both paths target one name. Flag the change in the PR.

### 2. When a query CANNOT use the builder (keep it raw — parameterized, and documented)

- **A DB-side function in `INSERT VALUES` / `UPDATE SET` is NOT raw SQL — use `qb.Expr`.** go-bricks
  splices a `RawExpression` verbatim into the value positions (`Set`, `SetMap`, `SetExpr`, `Values`,
  `BuildUpsert`) with no placeholder and no arg, so `SEQ.NEXTVAL`, `SYSDATE`, `NVL()` / `||` in a
  `SET` target and a correlated scalar subquery in `SET` all go through the builder:
  `Values(id, qb.Expr("SYSDATE"), name)` → `VALUES (:1,SYSDATE,:2)`. Confirm with `ToSQL()` for your
  vendor. The `f.*` WHERE doors refuse an expression (`ErrExpressionInFilter`) — a WHERE-side
  expression uses `f.Raw`. Every `qb.Expr` / `SetExpr` call site carries the SECURITY annotation.
  For an expression with bound args on UPDATE use
  `SetExpr("lease_until", qb.MustExpr("NOW() + (? * INTERVAL '1 second')"), secs)`. Prefer
  the vendor-aware `BuildCurrentTimestamp()` / `BuildUUIDGeneration()` over a hardcoded `SYSDATE`
  wherever the value — not the expression — is what you need.
- **Joins, subqueries, grouping, paging and locking are all expressible** — `InnerJoinOn` /
  `LeftJoinOn` / `RightJoinOn` / `CrossJoinOn` with `JoinFilter`, `Exists` / `NotExists` /
  `InSubquery` / `SubqueryColumn`, `GroupBy` / `Having`, `Limit` / `Offset` / `Paginate` (which
  replaces `ROWNUM` tricks), and `ForUpdate` / `ForUpdateNoWait`. Also `BuildUpsert`,
  `Insert(...).Select(...)`, and `Prefix` / `Suffix` for `RETURNING` / `ON CONFLICT`. None of these
  justifies raw SQL.
- **The genuinely absent constructs — the accepted reasons to keep a `const` raw — are `UNION`,
  `WITH` / CTE, and vendor optimizer hints** (re-derive against your pinned go-bricks with the
  script below). Stored
  procedures are also absent, but they are banned outright by review check 1d: a proc is a separate
  blocker, never a justification.
- **Re-derive the list instead of trusting this one** — the builder grows every release:
  ```bash
  GB=$(ls -d "$(go env GOMODCACHE)"/github.com/gaborage/go-bricks@* | sort -V | tail -1)
  grep -hE '^\s+[A-Z][A-Za-z0-9]*\(' $GB/database/types/*.go | grep -v '^\s*//' | sed 's/^\s*//' | sort -u
  ```
- **Verify empirically before classifying** a query as migratable: write a throwaway test that prints
  `ToSQL()` and confirm no value silently became a bind (e.g. a `RawExpression` struct as an arg).
  A paper audit of "migratable vs hard" is frequently wrong — the generated SQL is ground truth.
- **The list above is the closed set of accepted reasons.** "The legacy Java had it as a string",
  "it is faster to copy", "it is only one query" and "it is internal, not user input" are **not**
  reasons — the last one especially: today's internal caller is tomorrow's endpoint parameter.
  A construct not in that list and not demonstrated by `ToSQL()` means the builder can express it,
  so use it.
- **Every raw statement carries its `// SECURITY: Manual SQL review completed - <what was
  verified>` annotation** on the line above, and the phase's PR body repeats the list of raw
  queries with their reason. That is what the reviewer reads instead of re-deriving it (review
  check 18b), and what the rawQuery audit table of a future `scan` will consume.

### 3. Centralize the exec/error boilerplate — go-bricks `database.Execute*` helpers

Every repo repeats the same `ToSQL → Query/Exec → Scan/RowsAffected → wrap` flow. go-bricks
already ships it — do **not** write a local `executor.go`:

- `database.ExecuteQuerySingle(ctx, exec, q, op, dest...)` / `ExecuteQueryMany(ctx, exec, q, op,
  scan)` / `ExecuteUpdate(ctx, exec, q, op) (int64, error)` (any count, 0 included, is not an
  error) / `ExecuteUpdateOne(ctx, exec, q, op)` (0 rows → `ErrNoRows`, >1 → `*ExecError`) /
  `ExecuteInsert(ctx, exec, q, op)`.
- `database.Executor` (`Query`/`Exec`) is satisfied by both `database.Interface` and `database.Tx`
  → the same call runs inside or outside a transaction.
- `database.Raw(sql, args...)` adapts keep-raw SQL (UNION, CTE, hints) to the same helpers; it
  needs the SECURITY annotation like any other raw site.
- Errors: zero rows → wrapped `database.ErrNoRows`; infra failures → `*database.ExecError{Op,
  Stage, Err}`. The **repository maps `database.IsNotFound(err)` to the domain not-found error** so
  business codes reach the handler; everything else is wrapped as infra (500) with the `op` label.

### 4. Correctness details

- **Fixed-width `CHAR(n)` columns** return space-padded values — `strings.TrimSpace` before comparing
  or using them (else `status == ACTIVE` silently never matches).
- **NULL ≠ empty**: scan into `sql.Null*` and treat NULL as "unavailable", distinct from `""`.
- **SELECT column order is load-bearing** whenever a manual positional scan (`ScanColumns`) is used —
  pin the exact ordered column list with a regression test asserting the generated SELECT.
- **Best-effort audit writes**: do NOT discard the error. Return it separately (e.g.
  `(auditErr, err error)`) so the service can log it (repositories don't log); the main operation
  still commits. Test both the success and the audit-failure-still-commits paths.
- **Deterministic audit values**: normalize the actor (e.g. upper-case) and use a fixed timezone for
  audit timestamps.

### 5. Testing gotchas

- **testify `mock.Anything` shadowing**: `mock.Anything` also matches MISSING arguments, so a wider
  expectation registered first (`On("Exec", anyN(16))`) will match and shadow a narrower call
  (`anyN(5)`), returning the wrong stub. Disambiguate by pinning a discriminating argument — e.g. the
  query constant: `On("Exec", append([]any{mock.Anything, query}, anyN(n)...)...)`.
- Centralize error scenarios in shared table-driven helpers; always include the NULL case and any
  actor/time fallback case.
- Add a `ToSQL()`-pinning regression test for every builder-generated query, and keep per-package
  coverage at target.
