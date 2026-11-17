# PR Template

> Shared construction rules, loaded on demand by `novo-legacy-migration-endpoint` and `novo-go-build`.
> Binding exactly as if they were inline. Where the text says Java, parity or `EST-NN`, see "Reading these rules" in `SKILL.md`.

```markdown
**Title:** `feat: {description, lowercase}`
(no scope in parentheses after the type; description in lowercase — no capitals except proper
nouns/acronyms; **NO Jira ticket in the title** — it goes in the body as `Refs:` — e.g.
`feat: add getLastCardToken domain + service`)
**Keep the title ≤ 72 chars (NKH1 standard).** Put extra detail (and the ticket) in the body.
A title over 72 chars (e.g. ~120) is a nit, not a blocker — but trim scope words to fit.

**Body:**

## Summary
- Bullet 1
- Bump version X → Y

## Test plan
- [x] N test cases
- [x] Test command passes — 0 issues, coverage X% (floor 70%, goal 85%)

Refs: {TICKET}

Generated with [Claude Code](https://claude.com/claude-code)
```
