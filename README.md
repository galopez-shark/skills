# skills

Claude Code skills for migrating legacy endpoints to Go (NovoPayment / Zinli Java → Golang),
for validating the Go that comes out of it, and for attending the feedback a PR receives.

## Skills

| Skill | Purpose |
|-------|---------|
| [`novo-legacy-migration-context`](legacy/novo-legacy-migration-context/SKILL.md) | Initializes `.migration-context.yaml`: source repos, properties, DB, auth, external services, full endpoint inventory. `ticket <endpoint>` generates a Jira-ready ticket for the PO. |
| [`novo-legacy-migration-endpoint`](legacy/novo-legacy-migration-endpoint/SKILL.md) | Migrates one endpoint to Go phase by phase on go-bricks, plus the subcommands listed below. |
| [`go-dev-technical`](legacy/go-dev-technical/SKILL.md) | Technical validator for go-bricks services: `review`, `scan` and `pr-fix` (below). |

### `/migrate` subcommands (`novo-legacy-migration-endpoint`)

| Subcommand | What it does |
|---|---|
| `/migrate <endpoint>` | Migrates the endpoint: domain → repository → service → handler → docs, one branch per phase, **stacked** with `gh stack` by default (serial when a phase must wait for certification or review). |
| `list` · `status <ep>` · `roadmap` | Inventory with status, phase-level detail, and the recommended wave order. |
| `verify-parity <ep>` (`simetria`) | Read-only Java↔Go business-logic symmetry report. |
| `parity-solve <ep> cases (…)` | Plans fixes for the selected parity divergences (≤300 lines / ≤10 files per phase). |
| `usecases <ep>` (`casos`) | Extracts the use-case / test-scenario list with `EST-NN` ids. |
| `techdoc <ep>` (`doc-tecnico`) | Technical doc with class / flow / data diagrams as images. |
| `migrate-ticket-plan <ep>` (`mtp`) | Plan de Desarrollo written into the **Jira ticket description**: parity flows, dependencies from the Java origin, and a DoD that lists what QA certifies. The update is protected: it reads the current description, backs it up, preserves non-plan content and asks you to approve the diff. |
| `migrate-doc-plan <ep>` (`mdp`) | Plan de Desarrollo as a **Word + PDF for QA / certificación** (comparativo or solo-certificación), built in approved sub-steps 6.1-6.8 with character caps, three diagram images and the Pruebas Unitarias table. Does not touch Jira. |
| `help` | Subcommands and key rules. |

`mtp` and `mdp` share one local, git-ignored file (`docs/modules/<module>/<endpoint>.plan-data.yaml`)
with the flows, dependencies and approved cases, so the `EST-NN` ids match in Jira and in the Word file.

### `/go-dev-technical` subcommands

| Subcommand | What it does |
|---|---|
| `review <PR_URL> [LANG]` | Runs the toolchain (build / vet / test -cover / golangci-lint / go fix) in an isolated worktree, then checks go-bricks usage, SQL safety, layer boundaries, bus contracts, runtime bugs, naming, design depth / DRY, and best-practice standards (check 22). On a re-review it also verifies that the author actually resolved our earlier comments (check 18c). |
| `scan <path> [LANG]` | Audits a codebase and emits a phased remediation roadmap sized to the merge caps. |
| `pr-fix [PR]` | Attends the feedback on a PR: PR health check (behind / conflicts / stack / size), reads what each reviewer and CodeRabbit wrote (in Spanish), validates each comment with you, fixes in a **separate commit** (no amend, no force-push), waits for green CI, replies and resolves threads in English after your approval, and re-requests review. |
| `help` | Subcommands and what each one catches. |

## Rules the skills enforce

- **go-bricks first**, Java parity as the spec, QueryBuilder over raw SQL, layer boundaries.
- **Phase caps:** ≤400 new production lines and ≤10 files per phase; tests do not count but must be business-scenario tests.
- **Every created unit ships with its use-case test** in the same phase, named after its `EST-NN`; a Phase END gate fails the phase if a changed function has no test.
- **Short comments:** explain the why, ≤100 characters per line.
- **Everything published is approved first.** Nothing is posted to GitHub or Jira without you approving the exact text or diff.

## Safeguards

Instructions alone get skipped, so the skills add mechanical checks:

- **Publish guard hook.** Each skill declares a `PreToolUse` hook (`hooks/pr-publish-guard.sh`) that forces a
  confirmation prompt showing the literal command for anything that publishes to GitHub (`gh pr create|comment|edit|close|review|merge`,
  thread replies, `resolveReviewThread`, non-GET `gh api`, `gh stack submit|sync|merge`). Read-only calls pass through.
  It needs `bash` and `python3`, is active from the moment a skill is invoked, and resolves its script with
  `${CLAUDE_SKILL_DIR}` falling back to `~/.claude/skills/<skill>`. Whether the prompt still appears in
  `bypassPermissions` mode is not documented — add a `permissions.ask` rule in `settings.json` if you need that guarantee.
- **Completion checklist.** Every skill ends by printing its mandatory steps with the evidence of each; a step with
  no evidence is `❌ NO EJECUTADO`.

## Install

Copy the **whole** skill folders (including `hooks/` and `references/`) into a Claude Code skills directory:

```bash
# user-level (available everywhere) — recommended, the hook fallback path assumes this
cp -R legacy/* ~/.claude/skills/

# or project-level (shared via the repo)
cp -R legacy/novo-legacy-migration-context  <repo>/.claude/skills/
cp -R legacy/novo-legacy-migration-endpoint <repo>/.claude/skills/
cp -R legacy/go-dev-technical               <repo>/.claude/skills/
```

Open a **new** Claude Code session afterwards: skills are loaded when a session starts.
Then invoke `/novo-legacy-migration-context`, `/migrate` and `/go-dev-technical`; `/migrate help` and
`/go-dev-technical help` list their subcommands.

**Requirements:** `gh` ≥ 2.90 with `gh extension install github/gh-stack` for stacked phases;
a valid `gh` login (an invalid `GITHUB_TOKEN` in the environment overrides the keyring login —
unset it or run `gh auth login`); `python3` and `bash` for the hook.

## How they fit together

`novo-legacy-migration-context` establishes what is being migrated,
`novo-legacy-migration-endpoint` migrates one endpoint at a time under the phase caps and documents it
for Jira (`mtp`) and QA (`mdp`), and `go-dev-technical` validates the result (`review`, `scan`) and
closes the loop on the feedback a PR receives (`pr-fix`). The `scan` roadmap reuses the same phase caps,
so remediation work merges through the same pipeline as the migration itself.
