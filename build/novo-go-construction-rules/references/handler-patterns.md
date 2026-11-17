# Handler Patterns

> Shared construction rules, loaded on demand by `novo-legacy-migration-endpoint` and `novo-go-build`.
> Binding exactly as if they were inline. Where the text says Java, parity or `EST-NN`, see "Reading these rules" in `SKILL.md`.

### Plain body

```go
func (m *Handler) Foo(req *service.FooRequest, ctx server.HandlerContext) (server.Result[*service.FooResponse], server.IAPIError) {
    resp, appErr := m.Service.Foo(ctx.RequestContext(), req)
    if apiErr := m.ValidateError(appErr); apiErr != nil { return server.Result[*service.FooResponse]{}, apiErr }
    return server.NewResult(HTTPStatusFromRC(resp.Rc), resp), nil
}
```
- `ctx.Echo` no longer exists (ADR-034 — no `echo.*` on the consumer surface): use
  `ctx.RequestContext()` / `ctx.Request()`.
- The legacy contract has no `data`/`meta` envelope → register the route with
  `server.WithRawResponse()` (Raw Response Mode, go-bricks `wiki/handler_patterns.md`) so the
  handler's `R` is serialized as-is. `server.ResultWithMeta[R]` is only for adding entries to the
  enveloped `meta` map (it is dropped in raw mode).

### Encrypted body (pure module)

```go
type fooReq struct {
    TagPay string `param:"tagPay" validate:"required"`
    Data   string `json:"data"    validate:"required"`
}
```
- `authHeader` inline — no intermediate variable
- **The service holds `s.httpClient` as a field, set at construction — it is NOT a method
  parameter.** Same as the mixed module below: one convention, both cases

### Encrypted body (mixed module)

- Service already has `s.httpClient` → all methods use it
- Do NOT add `client` param to service method

### One transport convention, both module types (resolved)

Earlier versions of this skill told pure modules to pass `client httpclient.Client` as a
method parameter while telling mixed modules the opposite. **That contradiction is
resolved in favor of the field**, for both:

- The parameter is a seam that is never substituted — one adapter, threaded through
  several call levels, `nil` in essentially every test. Review check **19b** flags it as a
  hypothetical seam, and it is far cheaper to not create than to remove: taking it out
  later touches every test that passed it, so the ≤10-file cap splits the fix
- The field convention was already the majority in the reference codebases, so this aligns
  the two rules instead of keeping one of each
- The adapter also owns **outbound headers**, including the correlation id — a business
  service formatting transport headers is the DIP violation in the same check

If a project's own `CLAUDE.md` or ADR still mandates the parameter for pure modules, that
document wins for that repo — **follow it and say so in the PR**, citing this rule as the
counter-convention worth reopening. Never silently review or build against a rule the
project has not adopted.
