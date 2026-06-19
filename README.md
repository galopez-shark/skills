# skills

Claude Code skills for migrating legacy endpoints to Go (NovoPayment / Zinli Java → Golang).

## Skills

| Skill | Purpose |
|-------|---------|
| [`novo-legacy-migration-context`](legacy/novo-legacy-migration-context/SKILL.md) | Initializes `.migration-context.yaml`: source repos, properties, DB, auth, external services, full endpoint inventory, and Jira ticket generation. |
| [`novo-legacy-migration-endpoint`](legacy/novo-legacy-migration-endpoint/SKILL.md) | Migrates a single endpoint to Go phase-by-phase (`list`, `roadmap`, `status`, and the full domain → repository → service → handler → docs flow). Built on go-bricks. |

## Install

Copy the skill folders into a Claude Code skills directory:

```bash
# project-level (shared via the repo)
cp -R legacy/novo-legacy-migration-context  <repo>/.claude/skills/
cp -R legacy/novo-legacy-migration-endpoint <repo>/.claude/skills/

# or user-level (available everywhere)
cp -R legacy/novo-legacy-migration-* ~/.claude/skills/
```

Then invoke with `/novo-legacy-migration-context` and `/migrate`.
