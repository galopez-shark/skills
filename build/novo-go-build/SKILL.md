---
name: novo-go-build
description: "Builds something NEW in a Go service on go-bricks from a Jira ticket whose acceptance criteria, integrations and test cases are clear and approved (it asks about anything unclear, never assumes), using the same construction rules as the legacy migrations (phased, stacked PRs, QueryBuilder, response funnel, one use-case test per unit, self-review gate at every phase end). The ticket is the gate: text, documents or an interview are only context. Subcommands: /build <ticket> (default: full flow), /build doc <ticket> (Word/PDF for QA), /build status [ticket], /build help. Reads Jira, never writes to it. Use for a new feature or endpoint with no Java behind it; for a legacy endpoint use /migrate."
license: MIT
metadata:
  author: galopez-shark
  version: "1.1.0"
  domain: engineering
  triggers: build, novo-go-build, /build, new feature, nuevo requerimiento, construir, build ticket, build doc, build status
  role: specialist
  scope: implementation
  output-format: code
  related-skills: novo-go-construction-rules, novo-legacy-migration-endpoint, go-dev-technical, golang-pro
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: 'bash "${CLAUDE_SKILL_DIR:-$HOME/.claude/skills/novo-go-build}/hooks/pr-publish-guard.sh"'
---

# Build (new work in Go / go-bricks)

Turns a Jira ticket with acceptance criteria into working Go code, built to the **same standard as
the legacy migrations**. There is no Java behind it: the ticket's acceptance criteria are the
specification, and everything else (go-bricks first, phase caps, stacked PRs, tests, review gate)
is identical.

**Depends on `novo-go-construction-rules`** (installed beside this skill) for every construction
rule, and on `novo-legacy-migration-endpoint` only for the Word/PDF template of `/build doc`. If a
needed skill is missing, stop and tell the user which folder to install (`build/` or `legacy/`).

**Supports subcommands:**
- `/build <ticket>` — the full flow (default): gate → understand → clarify → plan → build → close
- `/build doc <ticket>` — Plan de Desarrollo Word/PDF for QA, for what was built
- `/build status [ticket]` — phases, PRs and acceptance-criteria coverage (read-only)
- `/build help` (alias `?`) — this card

**Jira is read-only here.** This skill reads tickets and linked pages through the Atlassian
connector (`getJiraIssue`, `getConfluencePage`); it never edits, comments on, transitions or
creates anything in Jira. If the connector needs authorization, tell the user; never ask for or
handle a password or token.

---

## When NOT to use this skill

- A legacy Java endpoint being ported → `/migrate` (parity with Java is its whole point).
- Reviewing a PR → `/go-dev-technical review`; attending its feedback → `/go-dev-technical pr-fix`.
- No Jira ticket with acceptance criteria yet → the gate below stops; this skill does not invent a
  specification and does not create tickets.
- Not a Go service on go-bricks (no `go-bricks` in `go.mod`) → stop and say so.

---

## Subcommand: `/build help` (alias `?`)

```text
build — build something NEW in Go (go-bricks) from a Jira ticket, to the migration standard.

  /build <ticket>        Full flow. Gate on the ticket's acceptance criteria, clarify in rounds,
                         approved plan, phased code with stacked PRs and one use-case test per unit.
  /build doc <ticket>    Word/PDF Plan de Desarrollo for QA (solo certificación, no Java).
  /build status [ticket] Phases, PRs and CA-NN coverage. Read-only.
  /build help            This card.

KEY RULES
  • The spec is three approved, clear things: acceptance criteria (CA-NN), integrations (IN-NN) and
    test cases (TC-NN). Any of them missing or unclear → it asks; nothing is assumed. No approval → no code.
  • Text, documents and questions are context; they never replace the ticket.
  • Jira is read-only. DDL is drafted and flagged for a CDPP ticket, never executed.
  • Same construction rules as /migrate (novo-go-construction-rules): ≤400 new lines / ≤10 files per
    phase, stacked PRs, QueryBuilder, response funnel, a test per unit, review gate per phase.
  • Nothing is published (PR, push, comment) without the exact text approved.
```

After printing, ask what the user wants to do next.

---

## Question protocol (applies to every question this skill asks)

Ask in **rounds**, not one long form:
1. **Read before asking.** Anything answerable from the ticket, its links, the repo or the docs is
   read, never asked. Ask only what only the user knows.
2. **Frontier only.** A round holds every question whose prerequisites are already answered (max 4,
   recommended option first). Never ask what depends on an answer you do not have yet.
3. **"I don't know" is an answer.** Record the item as `pendiente`, look it up if it can be read,
   and do not invent a value to move on.
4. **Stop when the frontier is empty.** Print what was decided (one line per item) and ask for a
   single confirmation before writing or publishing anything.
5. **Do not re-ask** a decision already made in this session.

---

## Default: `/build <ticket>`

Accept the ticket as a key (`CEB-1234`) or a Jira URL. Anything else the user adds (free text, a
Word/PDF/Confluence page, answers to questions) is **context for this ticket**.

### STEP 0 — Gate: criteria, integrations and test cases, clear and approved (MANDATORY)

Reading the ticket is not enough. **No code, design or plan starts until three things exist, are
clear and are approved by the user:** (A) acceptance criteria, (B) integrations, (C) test cases.
**If anything is unclear, missing or ambiguous, ASK. Never assume, never infer, never fill a gap
with a "reasonable default".** Questions follow the Question protocol, but the gate itself is not
optional and "the task looks small" is not a reason to skip a question.

1. If no ticket was given, ask for it. Free text alone is not enough to start building.
2. Read it with `getJiraIssue`: summary, description, issue type, status, assignee, linked issues,
   subtasks, attachment names and, when linked, the Confluence pages (`getConfluencePage`).
3. Find the **acceptance criteria** (a section titled *Criterios de aceptación* / *Acceptance
   Criteria*, or the criteria list in the description). Number them **`CA-01`, `CA-02`, …**, one per
   criterion, **verbatim**; split a criterion only when it clearly holds two independent outcomes and
   say so.
4. **No criteria found → STOP.** Print: "El ticket {TICKET} no tiene criterios de aceptación. Agrégalos
   al ticket (el skill no escribe en Jira) y vuelve a ejecutar `/build {TICKET}`." Offer to draft
   criteria text **in the chat** for the user to paste into Jira; do not continue to code.
5. Print the numbered `CA-NN` list and the ticket facts, and confirm the list is the ticket's.
6. **(B) Integrations — clear.** Extract every integration the work touches from the ticket, its
   links and its Confluence pages: external services/APIs (name, endpoint or operation, request and
   response contract, auth, timeouts and failure behavior), messaging (exchange/queue/routing key/
   event type), databases and tables, files, and other modules. Print them as a table
   (`IN-01`, `IN-02`, …: integration, direction, contract source, failure behavior). A row with a
   blank, vague ("el servicio de X") or contradictory cell is **unclear → ask**. No integration at
   all is a valid answer only when the user says so; record "sin integraciones (confirmado)".
7. **(C) Test cases — clear.** Extract the test cases from the ticket (a *Casos de prueba* section,
   scenarios, QA subtasks, Gherkin). Number them `TC-01`, `TC-02`, … **verbatim** and map each to the
   `CA-NN` it proves. Rules: every `CA-NN` has at least one `TC-NN` covering its success path **and**
   its failure path; a test case with no stated input/expected outcome is **unclear → ask**; a
   `CA-NN` with no test case is a gap → ask for it (the skill may propose cases in the chat, they
   count only once the user approves them).
8. **Ask until clear.** Every unclear or missing item from (A), (B) and (C) goes into question
   rounds (Question protocol: read first, frontier only, max 4 per round, recommended option first).
   An answer the user gives in chat is recorded as **"confirmado por el usuario (no está en el
   ticket)"**, and the skill tells them to add it to the ticket (it never writes to Jira). "No sé"
   leaves the item `pendiente` and **the gate stays closed**: say exactly what is missing and who
   can supply it, and stop. Do not move to STEP 1 with a `pendiente` in A, B or C.
9. **Approval.** Print one summary — the `CA-NN`, `IN-NN` and `TC-NN` lists, the Jira status of the
   ticket, and the items confirmed by the user outside the ticket — and ask for a single explicit
   "aprobado". Silence, "ok" to something else, or approving only part of it is not approval.
   Record the approval (and its date) in the build-plan file once it exists.

### STEP 1 — Understand the target (read-only)

- Confirm Go and `go-bricks` in `go.mod`; note the go-bricks version.
- Read the repo's own conventions: `CLAUDE.md`/`AGENTS.md`, `internal/modules/*`, the response-code
  table, config structs, how an existing endpoint of the same kind is wired. **Find one similar
  endpoint and use it as the template**; new code follows it unless the ticket says otherwise.
- Read the context the user supplied (text, documents). It informs; it never overrides the ticket.
- Run `git checkout main && git pull`; stop and ask if the working tree is dirty.

### STEP 2 — Clarify in rounds (Question protocol)

STEP 0 closed A, B and C. Here, list every *remaining* gap (design-level) and ask only what only the
user knows: error cases and their
response codes/messages, validation order, authentication and authorization, idempotency, money-path
decisions (movement, reversal, balance), external services and their failure behavior, data that must
persist. Each answer becomes either a clarification of a `CA-NN` or a numbered **assumption `S-NN`**
recorded in the plan and in the PR description. A gap on the money path is never assumed: ask.

If the answers show the ticket is incomplete, say what to add to the ticket (the user edits Jira).

### STEP 3 — Design and phase plan (MANDATORY — before any code)

Present, and get approved as **exact text**:
1. **Design:** module placement, layers and files, the response-code table (rc/message), config,
   external calls, and the data model. Each `CA-NN` maps to the layer/file that satisfies it.
2. **Database changes, if any:** draft the DDL following the NovoPayment database standard (call
   the Skill tool with `common:database-design-and-naming`), save it under
   `docs/builds/{TICKET}/ddl/` (git-ignored), and state clearly **"requiere ticket CDPP"**
   (the user creates it, e.g. with `backend:db-prod-task-creation`). The DDL is **never executed**;
   the code is built against that schema and the PR says it depends on it.
3. **Phase roadmap:** read `~/.claude/skills/novo-go-construction-rules/references/phase-planning.md`
   **in full** and produce the roadmap it requires (caps, one branch per phase, stacked).
4. **Coverage table:** `CA-NN` → `TC-NN` → phase → test(s) planned, plus every `IN-NN` → the layer
   that calls it and the test that fakes it at the boundary. A criterion with no planned test, a test
   case with no planned test, or an integration with no boundary test blocks the plan.

Write the approved plan to `docs/builds/{TICKET}.build-plan.yaml` (local, git-ignored via
`.git/info/exclude`, verified with `git check-ignore`): ticket, `CA-NN` list, `S-NN` assumptions, design
summary, `IN-NN` integrations, `TC-NN` test cases, the gate approval (date and what was confirmed
outside the ticket), phases (name, branch, PR, status), DDL files, DDL ticket (CDPP) once the user gives it.

### STEP 4 — Build phase by phase (stacked by default)

Before the first line of code, read **in full**, from
`~/.claude/skills/novo-go-construction-rules/references/`:
`phase-execution.md`, `build-to-review-standard.md`, `implementation-rules.md`, `testing-patterns.md`,
`anti-patterns.md`, plus `handler-patterns.md` for a handler, `data-access-patterns.md` for any repository
or database code, and `sdlc.md` / `pr-template.md` for branches, commits and the PR. They govern the
phases exactly as in `/migrate`; read them there, not from memory.

Differences from a migration (see "Reading these rules" in `novo-go-construction-rules`):
- No Java, properties or parity steps. The spec is the numbered `CA-NN` plus the approved `S-NN`.
- Tests are named after the criterion: `TestService_Foo_CA03_PanNotRegistered`; the **use-case coverage
  matrix** at Phase END uses `CA-NN` where migration uses `EST-NN`.
- Commit and PR titles: `type: description`, ≤72 chars, **no ticket in the title**; `Refs: {TICKET}` in
  the body. Branch name per `sdlc.md`.
- Every PR description lists the `CA-NN` it delivers and the `S-NN` assumptions it relies on.

Update the phase status in the build-plan file as each phase ends. Nothing is pushed, opened or
commented on GitHub without the exact text/command approved (the publish guard hook enforces it).

### STEP 5 — Close

1. **Acceptance coverage gate (MANDATORY):** print the `CA-NN` table — criterion → `TC-NN` → test(s) →
   observable outcome asserted — and the `IN-NN` table — integration → boundary test (success and
   failure). A `CA-NN` or `TC-NN` with no test, an integration with no boundary test, or a test that
   only executes lines, fails closed: write it before declaring the work done.
2. Print the PRs of the stack, the `S-NN` assumptions, and the DDL / CDPP dependency if any.
3. Suggest `/go-dev-technical review <PR_URL>` on each PR and `/build doc {TICKET}`.
4. Print the completion checklist.

---

## Subcommand: `/build doc <ticket>`

Generates the **Plan de Desarrollo Word + PDF for QA** of what was built. It reuses the `/migrate
migrate-doc-plan` process and template, in its **solo certificación** shape (a new endpoint with no
legacy behind it: the unit-test table shows only the Go response).

1. Read `~/.claude/skills/novo-legacy-migration-endpoint/references/migrate-doc-plan.md` **in full**
   and follow it, with these overrides:
   - **Skip step 5** (comparativo or not): it is always *solo certificación*.
   - **Source of truth:** `docs/builds/{TICKET}.build-plan.yaml` replaces
     `.migration-context.yaml` and the `plan-data.yaml`. If it is missing, ask the user to run
     `/build {TICKET}` first, or to supply the approved criteria.
   - **No Java:** read only the Go side. Where it says `EST-NN`, use `CA-NN`.
   - **6.7 Pruebas Unitarias:** the cases are the approved `CA-NN` (with their `S-NN` assumptions as
     notes), proposed for QA inclusion with the same include/exclude rule; do **not** run
     `/migrate usecases`, which needs Java.
   - **6.6 Ajustes realizados:** from this ticket's PRs and commits and the `go.mod` diff.
2. Template and base file come from `novo-legacy-migration-endpoint/assets/`. Output folder, character
   caps, the three diagram images and the "no capturadas" response images follow the reference.

---

## Subcommand: `/build status [ticket]`

Read-only. With no ticket, list `docs/builds/*.build-plan.yaml`; with one, show it.

- Read the build-plan file, `gh stack view` and `gh pr list --search "{TICKET} in:title,body"`.
- Print a Markdown table of phases (name, branch, PR, state, CI) and a table of `CA-NN` → test →
  covered ✅ / ❌. Mark anything that cannot be read as `n/d`; never infer a state.
- Jira status of the ticket only if the connector is authorized; otherwise `n/d`.

---

## Completion checklist (MANDATORY — print before finishing)

Print every step this skill marks MANDATORY, each with its **evidence** (command run, file written,
answer the user gave). A step with no evidence is `❌ NO EJECUTADO` — never omitted, never `✅`.
Judging a step "redundant for this case" is the user's call: ask, do not drop it. Approving a plan is
not approving anything that gets published or committed — those need the exact text/diff approved.

| Step | Evidence |
|---|---|
| Ticket read and criteria numbered `CA-NN` | the ticket key and the `CA-NN` list |
| Gate A: criteria exist and are clear | the section found in the ticket, or the stop message |
| Gate B: integrations listed and clear | the `IN-NN` table, or "sin integraciones (confirmado)" |
| Gate C: test cases listed, every `CA-NN` covered, clear | the `TC-NN` → `CA-NN` map |
| Unclear items asked, none left `pendiente` | the questions asked and the answers; items outside the ticket |
| Gate approved by the user | the explicit "aprobado" and its date |
| Repo conventions read, similar endpoint chosen | the endpoint used as template |
| Gaps asked in rounds, `S-NN` recorded | the decisions list the user confirmed |
| Design, DDL (if any) and roadmap approved as exact text | the user's approval |
| Construction rules read per phase | the files read from `novo-go-construction-rules` |
| Each phase closed with its gates | self-review result and the use-case matrix |
| Acceptance coverage gate | the `CA-NN` → `TC-NN` → test table and the `IN-NN` → boundary test table |
| Nothing written to Jira; nothing published unapproved | the commands the guard let through |

## Working if (how the user can tell the run went well)

- It stopped at the gate when the ticket had no criteria, integrations or test cases that were clear,
  and asked about each gap instead of assuming or building from free text.
- It printed the `CA-NN`, `IN-NN` and `TC-NN` lists and waited for an explicit "aprobado".
- The plan, the DDL flag and every `S-NN` assumption were approved **before** the first line of code.
- Each phase stayed within the caps and ended with its gates; the stack reviews in parallel.
- Every `CA-NN` has a test that asserts an observable outcome.
- The completion checklist printed with evidence; gaps read `❌ NO EJECUTADO`.
