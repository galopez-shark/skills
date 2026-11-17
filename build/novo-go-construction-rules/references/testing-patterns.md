# Testing Patterns

> Shared construction rules, loaded on demand by `novo-legacy-migration-endpoint` and `novo-go-build`.
> Binding exactly as if they were inline. Where the text says Java, parity or `EST-NN`, see "Reading these rules" in `SKILL.md`.

> **Rule:** every unit created or changed has a use-case test in the same phase (see
> "Every created unit ships with its use-case test"). The coverage tables below say *which cases*
> each layer needs; the Phase END gate (3b) proves that none was skipped.

### File structure

```
domain/        dto.go                (no tests)
repository/    sql_repository.go     → sql_repository_test.go
service/       service.go            → service_test.go + service_xxx_test.go
handlers/      handler.go            → handler_test.go
```

### Mock pattern

```go
type mockRepo struct {
    mock.Mock
    repo.Interface
}
func (m *mockRepo) Method(ctx context.Context, ...) (Result, error) {
    args := m.Called(ctx, ...)
    if v := args.Get(0); v != nil { return v.(Result), args.Error(1) }
    return nil, args.Error(1)
}
```

**Always `mock.AssertExpectations(t)` at end.**

### Repository coverage

| # | Case |
|---|------|
| 1 | getDB error |
| 2 | Query error |
| 3 | Empty rows → ErrNotFound |
| 4 | Scan error (fewer cols) |
| 5 | rows.Err() via sqlmock |
| 6 | Success 1 row |
| 7 | Success 2+ rows |

Transactional methods ADD: Begin error, Exec error, Zero rows, Commit error, Rollback mocking.

### Service coverage (table-driven)

Cover: parse errors, customer 404, customer DB error, card not found, repo 404, repo DB error, success variants.

### Handler coverage (table-driven)

Cover: success, each business error code → HTTP status, service 500, service 502.

### Lint gotchas

- `unused-parameter`: `_ *testing.T` in setup funcs
- `rowserrcheck`: `assert.NoError(t, rows.Err())` after `fixtures.NewMockRows`
- `sqlmock.Rows` has no `.Err()` — only `*sql.Rows` from `rowsFromSqlmock`
