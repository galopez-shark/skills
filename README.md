# NovoPayment Legacy Migration Skills

A set of [Claude Code](https://claude.com/claude-code) skills that take a legacy Java endpoint to production Go
on **go-bricks**, validate the result against a documented engineering standard, and close the loop on the
feedback a pull request receives.

- **Migrate** one endpoint at a time, in small, reviewable, stackable phases.
- **Document** the work for developers (Jira) and for QA (Word / PDF) from a single source of truth.
- **Validate** Go services and pull requests with a reproducible, evidence-based review.
- **Attend** reviewer, CodeRabbit and CI feedback without skipping a step.

---

## Contents

1. [Skills at a glance](#skills-at-a-glance)
2. [Typical workflow](#typical-workflow)
3. [Quick start](#quick-start)
4. [Command reference](#command-reference)
5. [Engineering standards enforced](#engineering-standards-enforced)
6. [Safeguards](#safeguards)
7. [Installation](#installation)
8. [Requirements](#requirements)
9. [Troubleshooting](#troubleshooting)
10. [Repository layout](#repository-layout)
11. [Contributing](#contributing)

---

## Skills at a glance

| Skill | Role | Entry point |
|---|---|---|
| [`novo-legacy-migration-context`](legacy/novo-legacy-migration-context/SKILL.md) | Establishes **what** is being migrated: source repositories, properties, database, authentication, external services and the complete endpoint inventory (`.migration-context.yaml`). | `/novo-legacy-migration-context` |
| [`novo-legacy-migration-endpoint`](legacy/novo-legacy-migration-endpoint/SKILL.md) | Migrates **one endpoint** to Go phase by phase, and produces its Jira and QA documentation. | `/migrate` |
| [`go-dev-technical`](legacy/go-dev-technical/SKILL.md) | **Validates** go-bricks services and pull requests, and attends PR feedback. | `/go-dev-technical` |

Each skill declares its own version in the `metadata.version` field of its `SKILL.md`.

## Typical workflow

```
 /novo-legacy-migration-context        define source, inventory, go-bricks mapping
              │
              ▼
 /migrate migrate-ticket-plan <ep>     plan + DoD written into the Jira ticket
              │
              ▼
 /migrate <ep>                         migrate in stacked phases (code + use-case tests)
              │
              ▼
 /go-dev-technical review <PR_URL>     evidence-based review of each phase
              │
              ▼
 /go-dev-technical pr-fix <PR>         attend CodeRabbit / reviewer / CI feedback
              │
              ▼
 /migrate migrate-doc-plan <ep>        Word + PDF Plan de Desarrollo for QA certification
```

The steps are independent: any command can be run on its own once `.migration-context.yaml` exists.

## Quick start

```bash
# 1. Install (user level) and open a NEW Claude Code session
cp -R legacy/* ~/.claude/skills/

# 2. In the Go target repository
/novo-legacy-migration-context            # one-time project context
/migrate list                             # endpoints and their status
/migrate <endpoint>                       # migrate one endpoint

# 3. Review and feedback loop
/go-dev-technical review https://github.com/<org>/<repo>/pull/<N>
/go-dev-technical pr-fix https://github.com/<org>/<repo>/pull/<N>
```

`/migrate help` and `/go-dev-technical help` print each skill's subcommands and key rules.

---

## Command reference

### `/migrate` — `novo-legacy-migration-endpoint`

| Subcommand | Alias | Description |
|---|---|---|
| `<endpoint>` | | Migrates the endpoint: domain → repository → service → handler → docs, one branch per phase. Phases are **stacked** with `gh stack` by default and fall back to serial when a phase must wait for certification or review. |
| `list` | | Every endpoint with its code status **and live Jira status** (read through the Atlassian connector on every call). It also shows the linked **CDSI tickets for TEST and UAT** (the redirect) and flags endpoints that lack one. Mismatches are flagged with `⚠️`; it never edits Jira or the yml. |
| `status <endpoint>` | | Phase-level detail for one endpoint. |
| `roadmap` | | Recommended wave order and effort estimates. |
| `verify-parity <endpoint>` | `simetria` | Read-only Java ↔ Go business-logic symmetry report. |
| `parity-solve <endpoint> cases (…)` | `solve-parity` | Plans fixes for the selected parity divergences (≤300 lines / ≤10 files per phase). |
| `usecases <endpoint>` | `casos` | Extracts the use-case and test-scenario list, with `EST-NN` identifiers. |
| `techdoc <endpoint>` | `doc-tecnico` | Technical document with class, flow and data diagrams as images. |
| `migrate-ticket-plan <endpoint>` | `mtp` | Writes the Plan de Desarrollo into the **Jira ticket description**: parity flows, dependencies taken from the Java origin, and a Definition of Done that lists what QA certifies. |
| `migrate-doc-plan <endpoint>` | `mdp` | Produces the Plan de Desarrollo as a **Word + PDF** for QA / certification, in approved sub-steps (6.1 – 6.8) with character caps, three diagram images and the unit-test table. Does not touch Jira. |
| `help` | `?` | Subcommands and key rules. |

**Plan data shared by `mtp` and `mdp`.** Both subcommands read and write one local, git-ignored file,
`docs/modules/<module>/<endpoint>.plan-data.yaml`, holding the parity flows, dependencies and the user-approved
test cases. The `EST-NN` identifiers are therefore identical in Jira and in the Word document.

**Protected Jira update.** `mtp` reads the current description, stores a backup, preserves any content that is not
part of the plan, shows the diff and writes only after that diff is approved. A second run replaces the plan block
instead of duplicating it.

### `/go-dev-technical` — `go-dev-technical`

| Subcommand | Description |
|---|---|
| `review <PR_URL> [LANG]` | Runs the toolchain (build, vet, test with coverage, golangci-lint, `go fix`) in an isolated worktree, then verifies go-bricks usage, SQL safety, layer boundaries, bus contracts, runtime defects, naming, design depth and DRY, and the best-practice standards (check 22). On a re-review it also verifies that the author actually resolved the reviewer's earlier comments (check 18c). Default report language is Spanish; pass `EN` for English. |
| `scan <path> [LANG]` | Audits an existing codebase and emits a phased remediation roadmap sized to the merge caps. |
| `pr-fix [PR]` | Attends the feedback on a pull request. See below. |
| `help` | Subcommands and what each one catches. |

**`pr-fix` flow**

| Step | Action | Gate |
|---|---|---|
| 0 / 0b | Resolve the PR; read-only health check (behind base, conflicts, stack state, size, title, version bump) | Rebase is never silent |
| 1 – 2 | Collect every source; report in Spanish what each reviewer and CodeRabbit wrote, with the author's reply | — |
| 3 | Validate every comment with the user, against project memory and code | User verdict per item |
| 4 | Fix in a **separate commit** — no amend, no force-push | Diff approved |
| 5 | Push and watch CI for 15 – 20 minutes | CI green |
| 6 | Draft replies in Spanish, publish in English, resolve threads | Text approved |
| 7 | Re-request review; trigger CodeRabbit only if it did not re-review on its own | — |

---

## Engineering standards enforced

| Standard | Detail |
|---|---|
| **go-bricks first** | The framework's types, helpers and test utilities are used instead of re-implementing them. |
| **Java parity** | Business rules, error codes, messages and validation precedence of the legacy service are the specification. A critical legacy defect is reported and decided with the user, never silently changed. |
| **Phase caps** | ≤ 400 new production lines and ≤ 10 files per phase. Tests do not count against the budget, but must be business-scenario tests. |
| **Use-case test per unit** | Every handler, service, repository method, mapper or helper with logic ships with a test in the same phase, named after its `EST-NN`. A Phase END gate fails the phase when a changed function has no test. |
| **SQL safety** | QueryBuilder by default; raw SQL only where the builder cannot express the statement, each site annotated with its manual review. |
| **Short comments** | Explain the *why*, in one or two lines of at most 100 characters. |
| **Commit and PR conventions** | `type: description` in lowercase, subject ≤ 72 characters, no ticket in the title; the ticket goes in the body as `Refs: <TICKET>`. |
| **Sensitive data** | PANs, account numbers, expiration dates, security codes, passwords and key material never appear in generated documents, comments or commit messages. |

---

## Safeguards

Written instructions alone are not enough to guarantee that every step runs, so the skills add mechanical controls.

**Publish guard.** Each skill declares a `PreToolUse` hook (`hooks/pr-publish-guard.sh`) that forces a confirmation
prompt, showing the literal command, for anything that publishes to GitHub: `gh pr create|comment|edit|close|review|merge`,
thread replies, `resolveReviewThread`, non-GET `gh api` calls and `gh stack submit|sync|merge`. Read-only calls pass through.

**Completion checklist.** Every skill ends by printing its mandatory steps together with the evidence for each.
A step without evidence is reported as `NO EJECUTADO`; it is never omitted and never marked as done.

**Approval of exact content.** Approving a plan is not approving the text that will be published. Replies, Jira
descriptions and commits are approved as the literal text or diff.

> **Note.** The hook is active from the moment a skill is invoked and for the rest of that session. Whether the
> prompt still appears under `bypassPermissions` mode is not documented by Claude Code; add a `permissions.ask`
> rule in `settings.json` if that guarantee is required.

---

## Installation

Copy the **complete** skill folders, including `hooks/`, `references/` and `assets/`, into a Claude Code skills directory.

```bash
# User level — recommended (the hook's fallback path assumes this location)
cp -R legacy/* ~/.claude/skills/

# Project level — shared through the target repository
cp -R legacy/novo-legacy-migration-context  <repo>/.claude/skills/
cp -R legacy/novo-legacy-migration-endpoint <repo>/.claude/skills/
cp -R legacy/go-dev-technical               <repo>/.claude/skills/
```

Open a **new** Claude Code session afterwards. Skills are loaded when a session starts; an already open session keeps
the version it loaded.

**Updating.** Pull `main`, then re-run the copy. To remove files that were deleted upstream, mirror each folder:

```bash
rsync -a --delete legacy/<skill>/ ~/.claude/skills/<skill>/
```

## Requirements

| Requirement | Used for |
|---|---|
| Claude Code | Running the skills |
| `gh` ≥ 2.90 and the `github/gh-stack` extension (`gh extension install github/gh-stack`) | Stacked phases and PR operations |
| A valid `gh` login | Reading and updating pull requests |
| `bash` and `python3` | The publish guard hook |
| Go toolchain, `golangci-lint` | `review` Phase 0 evidence |

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `gh` returns `HTTP 401: Bad credentials` | An invalid `GITHUB_TOKEN` in the environment overrides the keyring login. Unset it, or run `gh auth login`. |
| A new subcommand does not appear | The session predates the installation. Open a new session and check `/migrate help`. |
| The publish guard does not prompt | The skill has not been invoked in this session, or the permission mode bypasses prompts. See the note under [Safeguards](#safeguards). |
| `gh stack` is not found | Install the extension: `gh extension install github/gh-stack` (requires `gh` ≥ 2.90). |
| `plan-data.yaml` is missing on a fresh clone | Expected: the file is local and git-ignored. `mtp` / `mdp` rebuild it and ask for the test cases again. |

## Repository layout

```
legacy/
├── novo-legacy-migration-context/    SKILL.md, hooks/
├── novo-legacy-migration-endpoint/   SKILL.md, hooks/, assets/ (Plan de Desarrollo template and guide)
└── go-dev-technical/                 SKILL.md, hooks/, references/ (report template, glossary, scan workflow, pr-fix workflow)
```

## Contributing

1. Branch from `main` using `feat/`, `fix/` or `docs/` and a short description.
2. Keep each pull request to one concern; for larger changes use a stack (`gh stack`).
3. Bump `metadata.version` in the `SKILL.md` you change (minor for a new capability, patch for a fix).
4. Write the commit title as `type: description` (≤ 72 characters, lowercase, no ticket) and the PR description with a summary and a test plan.
5. After merge, refresh your installed copy (see [Updating](#installation)) and verify in a new session.
