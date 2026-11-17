# Anti-Patterns

> Shared construction rules, loaded on demand by `novo-legacy-migration-endpoint` and `novo-go-build`.
> Binding exactly as if they were inline. Where the text says Java, parity or `EST-NN`, see "Reading these rules" in `SKILL.md`.

| Don't | Do |
|-------|-----|
| Invent error codes | Read properties files |
| Filter in service | Filter in SQL |
| Inline SQL | Use queries.go |
| New method for same table | Extend existing |
| `NewMockDatabase(t)` | `&mocks.MockDatabase{}` |
| `.Day()+1` in tests | `time.Date()` + `.Truncate()` |
| `param:` on service structs | Only handler binding |
| Commit without test check | Always run full check |
| PR without version bump | Bump EVERY phase |
| Debug logs in code | Remove before done |
| Skip AssertExpectations | Always at end |
| Reinvent go-bricks types | Use existing go-bricks components |
| Skip go-bricks check | ALWAYS check go-bricks FIRST |
| Re-assemble the response tail in a new handler | Call the funnel that owns it (review 19a) |
| New code constant + matching message constant | One table keyed by rc (review 20b) |
| Thread `httpclient.Client` through the service | Adapter owns client + headers (review 19b) |
| Copy another module's `Init` block | Use the shared bootstrap (review 20c) |
| Retype a bus exchange/queue/routing key | Copy-paste from the counterpart (review 6b) |
| Hand-copy a sibling flow | Parameterize a descriptor (review 20a) |
| `fmt.Sprintf` into SQL "just this once" | QueryBuilder — it is a blocker (review 1b) |
| "this statement stays raw" as a blanket comment over a whole query file | Convert every query that is not UNION/CTE/hint (NEXTVAL/SYSDATE/NVL/\|\|/correlated subquery in VALUES or SET use `qb.Expr`); annotate each remaining raw/Expr site with its own `// SECURITY: Manual SQL review completed - …` line |
| Open the PR with a known blocker | Fail closed: fix it in the phase (self-review gate) |
| Start the next phase because the previous "looks done" | Wait for the mode's signal: merge (serial) or submitted PR + user go-ahead (stacked) |
| Report a stacked phase as `merged` when it is only submitted | `en review` until the stack actually lands |
| Build a stack on an unverified money-path branch | Verify parity first — a later fix cascades a rebase through every phase above it |
| Hand-set a PR's base branch to fake a stack | `gh stack add` / `submit`, or run serial. A hand-made stack is one `gh stack` cannot sync |
| Let a lower PR take review changes without re-syncing | `gh stack sync` — otherwise every diff above it is wrong |
| `gh stack merge` on the top PR out of habit | Merge up to the **last approved** phase; it is all-or-nothing |
| Write a repository over tables another module owns | Declare a local interface here and let that module's service satisfy it (rule 0b) |
| Reach into another module's `Repository`, internal structs or DB | Only its exported interface — `deps.DB(ctx)` is per-tenant, per-request |
| "Es una sola query, la leo directo" | Same mechanism regardless of size: add the method to the provider's `Reader` |
| Inject the full `Service` when only reads are needed | Declare a local interface with the 1-2 methods used — least privilege, review 19b sees the real coupling |
| Declare the cross-module interface in the PROVIDER and import it | Declare it in the CONSUMER — structural typing satisfies it with no cross import, so no import cycle is even possible |
| Wire `cards → accounts` and `accounts → cards` both ways | A real bidirectional dependency is a design signal: third module, `shared/`, or an event — interface placement does not fix it |
| Return an HTTP DTO across a module boundary | Domain types only; DTOs belong to the handler |
| A cross-module read that publishes to the bus or writes the outbox | Reads have no side effects, or every consumer becomes a producer |
| An internal HTTP endpoint to serve a sibling module | In-process interface injection — same binary, no network |
| Register the consumer before the provider in `main.go` | Provider first, or the dependency is `nil` at runtime and no linter catches it |
