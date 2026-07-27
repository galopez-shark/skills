# skills

Claude Code skills for migrating legacy endpoints to Go (NovoPayment / Zinli Java → Golang)
and for validating the Go that comes out of it.

## Skills

| Skill | Purpose |
|-------|---------|
| [`novo-legacy-migration-context`](legacy/novo-legacy-migration-context/SKILL.md) | Initializes `.migration-context.yaml`: source repos, properties, DB, auth, external services, full endpoint inventory, and Jira ticket generation. |
| [`novo-legacy-migration-endpoint`](legacy/novo-legacy-migration-endpoint/SKILL.md) | Migrates a single endpoint to Go phase-by-phase (`list`, `roadmap`, `status`, and the full domain → repository → service → handler → docs flow). Built on go-bricks. |
| [`go-dev-technical`](legacy/go-dev-technical/SKILL.md) | Technical validator for go-bricks services. `review <PR_URL>` runs the toolchain (build / vet / test -cover / golangci-lint / go fix) in an isolated worktree, then validates go-bricks usage, SQL safety, layer boundaries, bus contracts, runtime bugs and naming. `scan <path>` audits a codebase and emits a phased remediation roadmap sized to the merge caps. |

## Install

Copy the skill folders into a Claude Code skills directory:

```bash
# project-level (shared via the repo)
cp -R legacy/novo-legacy-migration-context  <repo>/.claude/skills/
cp -R legacy/novo-legacy-migration-endpoint <repo>/.claude/skills/
cp -R legacy/go-dev-technical               <repo>/.claude/skills/

# or user-level (available everywhere)
cp -R legacy/* ~/.claude/skills/
```

Then invoke with `/novo-legacy-migration-context`, `/migrate` and `/go-dev-technical`.

Run `/go-dev-technical help` for its subcommands and what each one catches.

## How they fit together

`novo-legacy-migration-context` establishes what is being migrated,
`novo-legacy-migration-endpoint` migrates one endpoint at a time under a hard phase cap
(≤400 new lines / ≤10 files per phase, one branch per phase from `main`), and
`go-dev-technical` validates the result — its `scan` roadmap reuses the same phase caps,
so remediation work merges through the same pipeline as the migration itself.
