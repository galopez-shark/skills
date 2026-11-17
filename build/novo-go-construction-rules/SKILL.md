---
name: novo-go-construction-rules
description: "NovoPayment's shared construction rules for Go services on go-bricks: phase planning and execution (stacked PRs, size caps, Phase END gates), the build-to-review standard, implementation rules, testing, handler and data-access patterns, SDLC and the PR template. Read by /migrate and /build; use it when writing or reviewing code that must meet these standards."
license: MIT
metadata:
  author: galopez-shark
  version: "1.0.0"
  domain: engineering
  triggers: construction rules, go-bricks rules, build standard, phase gates, implementation rules, testing patterns
  role: reference
  scope: standards
  output-format: rules
  related-skills: novo-legacy-migration-endpoint, novo-go-build, go-dev-technical
---

# Go construction rules (shared)

The single source of the rules for **how code is built** in NovoPayment's Go services. Two skills
apply them and do not carry their own copy:

- `novo-legacy-migration-endpoint` (`/migrate`) — builds a legacy Java endpoint in Go.
- `novo-go-build` (`/build`) — builds something new from a Jira ticket.

`go-dev-technical` reviews code against the same standard.

This skill has no steps of its own. The calling skill tells you **when** to read each file; read it
**in full** at that point, never from memory.

## Files (all under `references/`)

| File | Read it when |
|---|---|
| `phase-planning.md` | Presenting the phase roadmap, before any code |
| `phase-execution.md` | Executing phase by phase: branches, stacked PRs, Phase START / END gates |
| `build-to-review-standard.md` | Before the first line of a phase, and at the self-review gate |
| `implementation-rules.md` | While writing any code |
| `data-access-patterns.md` | Before any repository layer or database code |
| `testing-patterns.md` | Writing or checking tests (every unit ships with its use-case test) |
| `handler-patterns.md` | Writing a handler |
| `sdlc.md` | Branches, commits, PR size, coverage and promotion gates |
| `pr-template.md` | Writing a PR description |
| `anti-patterns.md` | Before a phase closes |

## Reading these rules

The files were written for migrations first. When the caller is `/build` (nothing to migrate):

- **Java, properties files, parity** → there is no legacy source. Skip those bullets; the ticket's
  acceptance criteria are the specification.
- **`EST-NN`** → read it as `CA-NN`, the numbered acceptance criteria approved in the plan. Test
  names, the coverage matrix and the QA document use the same ids.
- **STEP 0 / 0b (analysis of the Java)** → replaced by the caller's own analysis of the ticket.

Everything else (go-bricks first, QueryBuilder, response funnel, phase caps of ≤400 new production
lines and ≤10 files, one use-case test per unit, the self-review gate) applies unchanged.
