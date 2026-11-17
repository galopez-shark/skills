# Build to the review standard (shift-left)

> Shared construction rules, loaded on demand by `novo-legacy-migration-endpoint` and `novo-go-build`.
> Binding exactly as if they were inline. Where the text says Java, parity or `EST-NN`, see "Reading these rules" in `SKILL.md`.

Every line this skill writes will be reviewed by **`go-dev-technical`** — 36 checks across
go-bricks usage, SQL safety, layer boundaries, bus contracts, error handling, concurrency,
resource leaks, naming, module depth, DRY and Go idioms. Code that ignores them is not
"done and pending review"; it is **rework already scheduled**.

**`go-dev-technical` is the single source of truth for those standards. This skill does not
restate them.** Two hand-synced copies of the same rule set is precisely the check-20b
violation that skill reports in other people's code — parallel structures with nothing
validating that they stay in sync. So the contract between the two skills is:

| Skill | Owns |
|---|---|
| `go-dev-technical` | **What** the standard is, and how to detect a violation |
| this skill | **How to build it right the first time**, and when to run the check |

What follows is only the delta: the decisions that are cheap while writing and expensive
once written.

### The seven that are far cheaper at construction time

Ordered by what they cost to retrofit. Each names the review check that will catch it, so
the mapping stays traceable instead of duplicated.

| # | Build it this way | Retrofit cost | Review check |
|---|---|---|---|
| 1 | **Return the response through the existing funnel.** Never re-assemble the tail (rc→status, observe, encrypt, write) in a new handler. Find who owns it and call it; the handler method is one line of business plus one return | Every handler added meanwhile inherits the leak | 19a, 19c |
| 2 | **Never create a second parallel list.** A new business code and its message go in the **same** table keyed by rc — never a constant in `codes.go` plus a matching constant in `messages.go` paired by naming convention | Grows to N call sites pairing by hand; drift is invisible until production | 20b |
| 3 | **The adapter owns its client and outbound headers** at construction. Do not thread `httpclient.Client` or an auth header through the service signature | Touches every test that passed the param; the file cap splits the fix, not the line cap | 19b |
| 4 | **Reuse the shared reader before writing a repository** (Rule 0 below). Extend the shared query and DTO when a column is missing | A parallel stack — Row, scanColumns, mapper, DTO, interface — all of it well-built and all of it duplicate | 8a |
| 5 | **Use the shared module bootstrap.** Do not copy another module's `Init` block | Six identical error strings; the module that skips it loses telemetry silently | 20c |
| 6 | **Bus contract names come from the counterpart, copy-pasted, never retyped.** Exchange, queue, routing key and `EventType` must match the other side character for character | Publishes fine, routes nowhere, no error anywhere. The most expensive defect this repo can ship | 6b |
| 7 | **QueryBuilder, always — raw SQL only when the builder truly cannot express it.** `fmt.Sprintf` into SQL is a blocker, not a shortcut, even for a one-off admin query. `RawExpression` (`qb.Expr`/`MustExpr`) is spliced inline in INSERT VALUES / UPDATE SET (`Set`/`SetMap`/`SetExpr`/`Values`/`BuildUpsert`), so `SEQ.NEXTVAL`, `SYSDATE`, `NVL()`/`\|\|` in a SET target and a correlated scalar subquery in SET all go through `qb.Insert/Update` with `qb.Expr` (confirm with `ToSQL()`). The **only** legitimate raw-SQL holdouts (`database.Raw`) are `UNION`, `WITH`/CTE and optimizer hints. Every other statement — even a `ROWNUM = 1` guard (`f.Raw("ROWNUM = 1")`) — goes through `qb.Select/Insert/Update`. Every `f.Raw`/`jf.Raw`/`database.Raw`/`SetExpr`/string `Having`/`qb.Expr`/`MustExpr`/`RawExpression{}` site carries `// SECURITY: Manual SQL review completed - <what was verified>` on the line above, not a blanket "stays raw" comment over the whole file | Security finding on a merged branch, or a phase later needing to retrofit builder calls one query at a time | 1b, 4b |

### Design decisions taken once, at STEP 0 — not discovered in review

Before the first phase, answer these in the STEP 0 analysis. They shape the phase plan, so
getting them wrong costs a re-plan, not an edit:

- [ ] **Which existing module owns each decision this endpoint needs?** rc→status mapping,
      customer/card resolution, response assembly, error rendering. If one exists, this
      endpoint **calls** it. If none exists and this is the third site that needs it, say so
      in the roadmap — do not quietly add site three
- [ ] **Does a shared reader already cover these tables?** (Rule 0.) Answer before planning
      a repository phase, because the answer can delete the phase
- [ ] **For every piece of data this endpoint needs, who owns it?** Run the rule 0b tree:
      shared reader → reuse it; another business module → declare a **local** interface in
      **this** module with only the methods needed and have that module's service satisfy it,
      never its repository; truly cross-cutting → `shared/`; this module → its own repository.
      A read the provider does not expose yet becomes **its own phase in the provider module**,
      and in stacked mode it is the bottom of the stack
- [ ] **Is this endpoint plaintext or encrypted?** Declare it. A module that opts out of
      encryption must not silently opt out of telemetry
- [ ] **Does anything here touch money?** If the flow decides whether funds moved, reversed,
      or are in doubt, its rules are parity-verified branch by branch and never consolidated
      as a mechanical refactor
- [ ] **What varies between this endpoint and its siblings?** If it is a near-copy of an
      existing flow, the variation goes in a **descriptor**, not in a second copy of the
      execution path. Two hand-copied flows mean every future fix lands twice

### Phase-level guardrails that mirror the review

The phase caps (≤400 prod lines, ≤10 files) already match the review's sizing gate. Two
consequences worth stating, because they change how a phase is planned rather than how it
is written:

- **Tests do not consume the 400-line budget, but they must earn the exemption.** They are
  business-scenario tests — money moved or not, reversal applied or not, in-doubt resolved,
  error paths that change the response. Coverage-padding fails review check 15 whether or
  not it was free
- **A rename that touches more than 10 files is split by the file cap, not the line cap.**
  Count files before promising a phase
