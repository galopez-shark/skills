---
name: novo-legacy-migration-endpoint
description: "Migrates a single legacy endpoint to Go using the context from novo-legacy-migration-context. Supports subcommands: /migrate list (all endpoints + status), /migrate status <name> (phase detail), /migrate roadmap (full migration roadmap with priorities). Uses go-bricks as the mandatory architectural foundation. Encodes 50+ battle-tested rules from real production migrations, and builds to the go-dev-technical review standard so generated code passes review on the first pass: a self-review gate closes every phase, and the seven decisions that are cheap at construction time (response funnel, no parallel code/message lists, adapter-owned transport, shared-reader reuse, shared bootstrap, copied bus contract names, QueryBuilder always) are taken before the first line is written. Phases are STACKED by default with gh-stack — phase N+1 branches off phase N without waiting for its merge, so the whole stack reviews in parallel — falling back to serial for phases gated on TEST certification, unverified money-path parity, a design that depends on the previous review, or a merge queue."
license: MIT
metadata:
  author: galopez-shark
  version: "4.31.0"
  domain: migration
  triggers: migration-endpoint, migrate, novo-migrate, migrar endpoint, migrate endpoint, migrate list, migrate status, migrate roadmap, migrate scan, migrate scan-all, scan-all, audit, migrate migrate-ticket-plan, mtp, migrate migrate-doc-plan, mdp, migrate devplan, plan-dev, plandoc, docx plan de desarrollo
  role: specialist
  scope: implementation
  output-format: code
  related-skills: novo-legacy-migration-context, go-dev-technical, go-bricks-modules, golang-pro, golang-testing, openapi-spec-generation
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: 'bash "${CLAUDE_SKILL_DIR:-$HOME/.claude/skills/novo-legacy-migration-endpoint}/hooks/pr-publish-guard.sh"'
---

# Migrate Endpoint

Migrates a single legacy endpoint to an idiomatic Go microservice. Requires `.migration-context.yaml` from `novo-legacy-migration-context`.

**Depends on `novo-go-construction-rules`** (installed beside this skill): the phase flow, the build-to-review standard,
implementation, testing, handler and data-access rules live there and are read on demand at the points marked MANDATORY.
If that skill is not installed, stop and tell the user to install it (`build/novo-go-construction-rules`).

**Supports subcommands:**
- `/migrate` or `/migrate <endpoint>` — migrate a specific endpoint (default behavior)
- `/migrate list` — list all endpoints with code status **and live Jira status** (mismatches flagged ⚠️)
- `/migrate status <endpoint>` — show phase-level detail for one endpoint
- `/migrate roadmap` — show the full migration roadmap with priorities and estimates
- `/migrate scan <endpoint>` — READ-ONLY audit of ONE built endpoint: parity with Java, untested units on its call chain, Jira, CDSI and a ready-for-QA verdict
- `/migrate scan-all [module|ids]` (alias `audit`) — project-wide READ-ONLY audit of every built endpoint: parity with Java, untested units, Jira, CDSI and a ready-for-QA verdict
- `/migrate verify-parity <endpoint>` (alias `simetria`) — validate Java↔Go business-logic symmetry for one endpoint (read-only report)
- `/migrate parity-solve <endpoint> cases (<ids>)` (alias `solve-parity`) — plan fixes for the selected verify-parity divergences (≤300 new lines / ≤10 files per phase)
- `/migrate usecases <endpoint>` (alias `casos`) — extract the Java use-case / test-scenario list (testRigor-style, con IDs `EST-NN`) — QA testing del Go + base de la tabla de escenarios del Plan de Desarrollo
- `/migrate techdoc <endpoint>` (alias `doc-tecnico`) — generate the technical doc (scope, glossary, structure, construction) + class/flow/data diagrams as images (asks for the output folder)
- `/migrate migrate-ticket-plan <endpoint>` (alias `mtp`) — generate the Jira development plan (Plan de Desarrollo) for an endpoint: context, technical description, files, acceptance criteria, DoD, technical notes — formatted for direct update to Jira ticket description
- `/migrate migrate-doc-plan <endpoint>` (alias `mdp`) — generate the formal Plan de Desarrollo **Word/PDF document for QA / certificación** (comparativo or solo-certificación; does not touch Jira)
- `/migrate help` (alias `?`) — show available subcommands, usage, and key rules

---

## When NOT to use this skill

- No `.migration-context.yaml` or the endpoint is not in the inventory → run
  `/novo-legacy-migration-context` first.
- A new endpoint with no Java origin: there is no parity to protect; this skill's parity rules
  do not apply.
- Fixing a defect in the legacy Java service itself.
- Reviewing someone else's PR → `/go-dev-technical review`; attending its feedback →
  `/go-dev-technical pr-fix`.

---

## Subcommand: `/migrate help` (alias `?`)

Print the help card below. Trigger when the user types `/migrate help`, `/migrate ?`, or asks
"what can this do / what commands does it have / how do I use it".

```text
migrate — migrate ONE legacy endpoint to Go (go-bricks), phase by phase.

SUBCOMMANDS
  /migrate <endpoint>          Migrate an endpoint (default). Reads Java, plans phases, executes
                               domain → repository → service → handler → docs, one branch per phase,
                               apiladas con gh-stack por defecto (sin esperar merges).
  /migrate list                Table of every endpoint: code status + live Jira status (⚠️ on mismatch).
  /migrate roadmap             Recommended wave order + effort estimates.
  /migrate scan <endpoint>     Read-only audit of ONE endpoint: parity, tests, Jira, CDSI, QA verdict.
  /migrate scan-all [module]   Project-wide read-only audit: parity, tests, Jira, CDSI, QA verdict (alias: audit).
  /migrate status <endpoint>   Phase-level detail for one endpoint.
  /migrate verify-parity <ep>  Read-only Java↔Go business-logic symmetry report (alias: simetria).
  /migrate parity-solve <ep> cases (1,2,3)
                               Plan fixes for the SELECTED verify-parity cases. Roadmap respects a
                               STRICTER cap: ≤300 new lines / ≤10 files per phase (alias: solve-parity).
  /migrate usecases <ep>       Extract the Java use-case / test-scenario list (happy + negative + edge
                               + external + auth), testRigor-style con IDs EST-NN — QA del Go +
                               base de la tabla de escenarios del Plan de Desarrollo (alias: casos).
  /migrate techdoc <ep>        Technical doc (scope, glossary, structure, construction) + class/flow/
                               data diagrams as images. ASKS for the output folder (alias: doc-tecnico).
  /migrate migrate-ticket-plan <ep>
                               Jira development plan (Plan de Desarrollo, SOLO Jira): context, tech description,
                               files, acceptance criteria, DoD, tech notes. Updates Jira ticket
                               description directly (alias: mtp).
  /migrate migrate-doc-plan <ep>
                               Formal Plan de Desarrollo as Word + PDF for QA / certificacion (tabla de
                               Pruebas Unitarias comparativa o solo-Go, diagramas, certificacion). NO
                               toca Jira (alias: mdp).
  /migrate help                This help (alias: ?).

REQUIRES  .migration-context.yaml — run /migration-context first to create it.

KEY RULES
  • FASES APILADAS por defecto (gh-stack): la fase N+1 arranca sobre la rama de la N sin esperar
    el merge, y todas se revisan en paralelo. Serial sólo cuando toca: fase que necesita
    certificación en TEST, fase de dinero con paridad sin verificar, fase cuyo diseño depende
    del review de la anterior, o repo con merge queue. El modo se propone en el roadmap (STEP 1).
    Requiere `gh extension install github/gh-stack` (gh ≥ 2.90.0); si no está, avisa y va serial.
  • gh stack sync después de CADA merge y de cada cambio de review en un PR de abajo — si no,
    el diff que ve el reviewer está mal. El merge es todo-o-nada hasta el PR elegido.
  • Una fase apilada es `en review` (con su base: PR #124 → #123), NO `merged`, hasta que el
    stack aterrice.
  • ≤400 new lines / ≤10 files per phase; bump version each phase. Apilar NO relaja estos caps.
  • go-bricks is mandatory. Canonical reference: github.com/novopayment/mdw-welcome-project-go.
  • If run from the legacy repo, ask for the Go target repo (git) before doing anything.
  • Parity: error codes/messages/flows must match Java (flag bugs, don't replicate).
  • verify-parity always checks out main first.
  • The route-enabling phase adds the endpoint to the Postman collection.
  • PR title: `feat: <desc lowercase>` ≤72 chars (NKH1), NO ticket in title — put `Refs: CEB-XXXX`
    in the body. No commit without explicit approval.
```

After printing, ask what the user wants to do next (list / roadmap / migrate / verify-parity).

---

## Subcommand: `/migrate list`

Table with the **code status** (from the yml), the **live Jira status** of every ticket, and the
**CDSI redirect tickets for TEST and UAT** linked to it.
`list` only reads `.migration-context.yaml` and Jira; it never writes to either. Run the Jira
read (step 2) on **every** call — never print the table from the file alone, and never reuse a
Jira status from an earlier call.

1. **Read the inventory** (`endpoint_inventory`): id, module, endpoint, HTTP method, `status`,
   `ticket`, `current_phase`, `current_branch`, `complexity`. If the file doesn't exist, tell the
   user to run `/novo-legacy-migration-context` first.
2. **Read the Jira status of every ticket** with the Atlassian connector (never a stored API
   token): one `searchJiraIssuesUsingJql` with `key in (<tickets>)` and
   `fields: ["status", "issuelinks", "assignee"]`. An unrestricted search blows the token limit.
   **CDSI tickets**: from the same response, take the issue links whose linked key starts with
   `CDSI-` (no extra call). Classify each one as TEST or UAT by the environment named in its
   summary; if it names neither or both, show the key with `?` and say it is unclassified.
   Never infer a CDSI from the endpoint name; a missing link is reported as missing.
   **Asignado (migración)**: from the same response, the migration endpoint ticket's
   `assignee.displayName`, or `sin asignar` when empty. It is the CEB ticket's assignee, not the CDSI's. If the connector is not authorized or the call
   fails, print the table with the Jira column as `n/d`, say so on the first line, and do not
   guess a status.
3. **Columns**: `#` · Endpoint · HTTP · Code status (yml) · Jira status · Ticket ·
   Asignado (migración) · CDSI redirect TEST · CDSI redirect UAT · Phase / PR · Complexity. Each CDSI cell is `CDSI-NNN (status)`,
   `❌` when no ticket is linked, or `—` when the endpoint has not started. Group rows by module with a `n/m done` header.
4. **Flag every mismatch** between code status and Jira status with a `⚠️` row note (e.g. code
   `done` but Jira `Abierta`, or code `in_progress` but Jira `Finalizada`). Also flag with `⚠️`
   an endpoint that is `done`, or whose Jira status is Ready For QA / QA IN PROGRESS / Finalizada,
   and has no CDSI for TEST or for UAT: the redirect cannot be requested without it. Report the
   mismatches; never edit Jira or the yml to hide them.
5. **Show QA follow-up in the Phase column** when a QA bug fix is in review (e.g.
   `fix CEB-6842 · #386 → #387`): the yml tracks migration phases, not QA bugs, so a `done`
   endpoint can still have work in flight.
6. **Summary line**: counts by code status (done / in progress / not started / blocked), by
   Jira status (Finalizada, Ready For QA, QA IN PROGRESS, En curso, Abierta), and how many
   endpoints lack a CDSI for TEST and for UAT.

**Output format — Markdown, never box-drawing.** Print the result as plain Markdown (NOT inside a
code fence) so the UI renders real tables: a `###` heading per module with its `n/m done`, then
one pipe table per module with the same header row. Emoji and accents break the alignment of
ASCII boxes, so do not draw `┌ │ └` borders. Pad each cell to the width of the longest cell in its
column so the raw text also lines up, and keep one row per endpoint. Warnings go in a `Notas`
list under the summary, not inside the cells. Example:

### accounts — 3/4 done ✅

| #  | Endpoint        | HTTP | Code       | Jira         | Ticket   | Asignado    | CDSI redirect TEST | CDSI redirect UAT | Phase / PR |
|----|-----------------|------|------------|--------------|----------|-------------|--------------------|-------------------|------------|
| 1  | getBalance      | GET  | ✅ done    | Finalizada   | CEB-5479 | Ana Pérez   | CDSI-101 (OK)      | CDSI-102 (OK)     | —          |
| 2  | getCardHolder   | GET  | ✅ done    | Ready For QA | CEB-5479 | Ana Pérez   | CDSI-103 (OK)      | ❌ ⚠️             | —          |
| 3  | getCVV2         | GET  | ✅ done    | Abierta ⚠️   | CEB-5480 | sin asignar | ❌ ⚠️              | ❌ ⚠️             | fix #386   |
| 4  | preventiveBlock | PUT  | 🔄 phase 2 | En curso     | CEB-5602 | Luis Gómez  | —                  | —                 | #95 → #96  |

**Resumen** — Code: ✅ 3 · 🔄 1 · ❌ 0 · 🚫 0 · Jira: Finalizada 1 · Ready For QA 1 · Abierta 1 ·
En curso 1 · Sin CDSI redirect: TEST 1, UAT 2

**Notas**
- ⚠️ #2 getCardHolder: Ready For QA without CDSI redirect for UAT
- ⚠️ #3 getCVV2: code `done` but Jira `Abierta`; no CDSI redirect for TEST or UAT

**Keeping the yml current** is a separate, explicit step: `/migrate status <endpoint>` updates
it only when a phase changed; anything else (QA state, open PRs, notes) is edited by hand. After
the table, if there are mismatches, offer to reconcile — and **ask before editing** the yml.

**Jira facts to respect**: a `Finalizada` ticket has no transitions and cannot be reopened
through the connector; moving a parent to `Ready For QA` is transition `2` ("Listo para QA");
bug subtasks of type `Bug QA` start with transition `2` ("Empezar").

**After displaying**: ask if the user wants to:
1. Start migrating a specific endpoint
2. Reconcile the yml with the mismatches shown (asks before writing)
3. View the roadmap

---

## Subcommand: `/migrate status <endpoint>`

Show phase-level detail for a specific endpoint. Accept endpoint by name, number, or Java method name.

```
┌──────────────────────────────────────────────────────────────────┐
│ ENDPOINT: cancelCard (#8)                                        │
│ Module: cards │ HTTP: PUT /user/:tag/card/:token/cancel          │
│ Java: CardResource.java → doOnCancelledCard                      │
│ Ticket: CEB-5650 │ Complexity: ★★★★☆ medium                     │
├──────────────────────────────────────────────────────────────────┤
│ MIGRATION PHASES                                                 │
│                                                                  │
│ Phase 1 — Domain + Repository                                    │
│   Branch: feature/CEB-5650-domain-repository                     │
│   Status: ✅ merged (PR #95, 2026-05-10)                         │
│   Files: 6 │ Lines: 320                                          │
│                                                                  │
│ Phase 2 — Service                                                │
│   Branch: feature/CEB-5650-service                               │
│   Status: 🔄 in_progress (started 2026-05-12)                   │
│   Files: 4 │ Lines: ~280 (estimated)                             │
│                                                                  │
│ Phase 3 — Handler                                                │
│   Status: ⏳ pending (blocked by Phase 2)                        │
│                                                                  │
│ Phase 4 — Docs                                                   │
│   Status: ⏳ pending (blocked by Phase 3 + TEST cert)            │
├──────────────────────────────────────────────────────────────────┤
│ DEPENDENCIES                                                     │
│ External calls: card_issuer (SGC), payment_connector             │
│ DB tables: CARDS, CARDS_TOKEN, CARD_STATUS_HISTORY               │
│ Encryption: JWE request + response                               │
│ go-bricks: server.HandlerContext, cryptoutil, httpclient.Client  │
├──────────────────────────────────────────────────────────────────┤
│ NOTES                                                            │
│ - Shares card lookup with accounts module (cardutils.FindCard)   │
│ - Uses compensation pattern (like preventiveBlock)               │
└──────────────────────────────────────────────────────────────────┘
```

**If the endpoint has no phases yet** (status=not_started), show the analysis from STEP 0 instead:
- Read Java source automatically
- Present the endpoint summary table
- Ask if the user wants to start the migration

**Update `.migration-context.yaml`** after showing status if any phase changed.

**In stacked mode the status box changes two things** (the example above is the serial
shape): each submitted phase carries its PR and base, and `pending` says what it really
waits for — the previous phase *submitted*, not merged:

```
│ Phase 2 — Repository                                             │
│   Branch: feature/CEB-5650-repository                            │
│   Status: 🔄 en review — PR #124 → #123                          │
│                                                                  │
│ Phase 3 — Handler                                                │
│   Status: ⏳ pending (sobre #124, arranca sin esperar su merge)  │
```

Run `gh stack view` before printing the box and reconcile it with the file — the stack on
disk is the authority, `.migration-context.yaml` is the convenience. If they disagree, say
so instead of printing the file's version.

---

## Subcommand: `/migrate roadmap`

Show the full migration roadmap with recommended order and effort estimates.

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                      MIGRATION ROADMAP                                          │
├──────────────────────────────────────────────────────────────────────────────────┤
│ PRIORITY ORDER (recommended — simple first, build up patterns)                  │
│                                                                                 │
│ Wave 1 — Quick wins (simple endpoints, establish module patterns)               │
│ ┌───┬──────────────────────┬────────────┬────────────┬───────────────┐          │
│ │ # │ Endpoint             │ Module     │ Complexity │ Est. Phases   │          │
│ ├───┼──────────────────────┼────────────┼────────────┼───────────────┤          │
│ │ 1 │ getCardInfo          │ cards      │ ★★☆ simple │ 3-4 phases    │          │
│ │ 2 │ getLastCardToken     │ enrolls    │ ★★☆ simple │ 3-4 phases    │          │
│ └───┴──────────────────────┴────────────┴────────────┴───────────────┘          │
│                                                                                 │
│ Wave 2 — Medium complexity (reuse patterns from Wave 1)                         │
│ ┌───┬──────────────────────┬────────────┬────────────┬───────────────┐          │
│ │ # │ Endpoint             │ Module     │ Complexity │ Est. Phases   │          │
│ ├───┼──────────────────────┼────────────┼────────────┼───────────────┤          │
│ │ 3 │ cancelCard           │ cards      │ ★★★★ med  │ 4-5 phases    │          │
│ │ 4 │ setCardPin           │ cards      │ ★★★☆ med  │ 4 phases      │          │
│ │ 5 │ changePin            │ cards      │ ★★★☆ med  │ 4 phases      │          │
│ │ 6 │ enrollmentUpdate     │ enrolls    │ ★★★☆ med  │ 4 phases      │          │
│ │ 7 │ enrollmentDelete     │ enrolls    │ ★★★☆ med  │ 4 phases      │          │
│ └───┴──────────────────────┴────────────┴────────────┴───────────────┘          │
│                                                                                 │
│ Wave 3 — Complex (external calls, transactions, multi-table)                    │
│ ┌───┬──────────────────────┬────────────┬────────────┬───────────────┐          │
│ │ # │ Endpoint             │ Module     │ Complexity │ Est. Phases   │          │
│ ├───┼──────────────────────┼────────────┼────────────┼───────────────┤          │
│ │ 8 │ physicalCardAssign   │ cards      │ ★★★★★ cpx │ 5-7 phases    │          │
│ │ 9 │ cardReissue          │ cards      │ ★★★★★ cpx │ 5-7 phases    │          │
│ │10 │ enrollment           │ enrolls    │ ★★★★★ cpx │ 5-7 phases    │          │
│ │11 │ enrollAndIssue       │ enrolls    │ ★★★★★ cpx │ 6-8 phases    │          │
│ └───┴──────────────────────┴────────────┴────────────┴───────────────┘          │
├──────────────────────────────────────────────────────────────────────────────────┤
│ TOTALS                                                                          │
│ Endpoints remaining: 11                                                         │
│ Est. total phases: 47-62                                                        │
│ Modules to create: cards (new), enrolls (new)                                   │
│                                                                                 │
│ DEPENDENCIES BETWEEN ENDPOINTS                                                  │
│ - cards module: cancelCard should go first (establishes card patterns)           │
│ - enrolls module: getLastCardToken first (simplest, sets up module structure)    │
│ - enrollAndIssue depends on enrollment (shares validation + DB writes)           │
│                                                                                 │
│ go-bricks COMPONENTS NEEDED                                                     │
│ All waves: server.HandlerContext, database.Interface, logger.Logger              │
│ Wave 2+: cryptoutil (JWE), httpclient.Client                                    │
│ Wave 3: db.Begin/tx.Commit (transactions), mocks.MockTx (tests)                 │
└──────────────────────────────────────────────────────────────────────────────────┘
```

**After displaying**: Ask if the user wants to:
1. Start migrating the next recommended endpoint
2. Change the priority order
3. Create Jira tickets for a wave

---

## Subcommand: `/migrate scan <endpoint>`

**MANDATORY:** when this subcommand runs, read `references/scan-endpoint.md` **in full** BEFORE doing
anything else — it holds every step and rule of the subcommand. Never run it from memory or from
this summary. If the file cannot be read, stop and tell the user.

---

## Subcommand: `/migrate scan-all [module|ids]` (alias `audit`)

**MANDATORY:** when this subcommand runs, read `references/scan-all.md` **in full** BEFORE doing
anything else — it holds every step and rule of the subcommand. Never run it from memory or from
this summary. If the file cannot be read, stop and tell the user.

---

## Subcommand: `/migrate verify-parity <endpoint>` (alias `simetria`)

**MANDATORY:** when this subcommand runs, read `references/verify-parity.md` **in full** (158 lines) BEFORE
doing anything else — it holds every step and rule of the subcommand. Never run it from memory or
from this summary. If the file cannot be read, stop and tell the user.

---

## Subcommand: `/migrate parity-solve <endpoint> cases (<ids>)` (alias `solve-parity`)

**MANDATORY:** when this subcommand runs, read `references/parity-solve.md` **in full** (56 lines) BEFORE
doing anything else — it holds every step and rule of the subcommand. Never run it from memory or
from this summary. If the file cannot be read, stop and tell the user.

---

## Subcommand: `/migrate usecases <endpoint>` (alias `casos`)

**MANDATORY:** when this subcommand runs, read `references/usecases.md` **in full** (168 lines) BEFORE
doing anything else — it holds every step and rule of the subcommand. Never run it from memory or
from this summary. If the file cannot be read, stop and tell the user.

---


### Question protocol (shared by `mtp`, `mdp` and `usecases`)

Ask in **rounds**, not one long form:
1. **Read before asking.** Anything answerable from `.migration-context.yaml`, the Java origin, the
   Go repo or Jira is read, never asked. Ask only what only the user knows.
2. **Frontier only.** A round holds every question whose prerequisites are already answered
   (max 4, with a recommended option first). Never ask a question that depends on an answer you
   do not have yet; it goes to the next round.
3. **"I don't know" is an answer.** Record the item as `pendiente`, look it up if it can be read,
   and do not invent a value to move on.
4. **Stop when the frontier is empty.** Then print what was decided (one line per item) and ask
   for a single confirmation before writing or publishing anything.
5. **Do not re-ask** a decision the user already made in this session.

## Subcommand: `/migrate migrate-ticket-plan <endpoint>` (alias `mtp`; legacy: `devplan`, `plan-dev`)

**MANDATORY:** when this subcommand runs, read `references/migrate-ticket-plan.md` **in full** (257 lines) BEFORE
doing anything else — it holds every step and rule of the subcommand. Never run it from memory or
from this summary. If the file cannot be read, stop and tell the user.

---

## Subcommand: `/migrate migrate-doc-plan <endpoint>` (alias `mdp`; legacy: `plandoc`, `plan-doc`, `docx`)

**MANDATORY:** when this subcommand runs, read `references/migrate-doc-plan.md` **in full** (276 lines) BEFORE
doing anything else — it holds every step and rule of the subcommand. Never run it from memory or
from this summary. If the file cannot be read, stop and tell the user.

---

## Default: `/migrate` or `/migrate <endpoint>` — Migrate an Endpoint

### Pre-flight

#### 0. Confirm the working repo (legacy vs Go target)

If the skill is invoked from the **legacy source repo** (e.g. `mftech_version_2.0`) — or from any
repo that is NOT the Go target — **STOP and ask the user which Go repository to migrate into**:
request the **git URL or local path**, then `cd`/clone to it before doing anything else. NEVER
write Go code inside the legacy repo.

**Canonical Go reference (ALWAYS):** treat
[`novopayment/mdw-welcome-project-go`](https://github.com/novopayment/mdw-welcome-project-go) as the
source of truth for **go-bricks usage and the target Go architecture** (module layout, layering,
`server`/`database`/`httpclient`/`cryptoutil`/`logger` wiring, config injection, testing). When
`.migration-context.yaml` or the target repo lacks a pattern, defer to this reference project — never
to memory or guesswork. Record it as `target.reference_repo` in the context file.

#### 1. Load context

Read `.migration-context.yaml` from the target repo root. If it does not exist:

> Context file not found. Run `/novo-legacy-migration-context` (or `/migration-context`) first to initialize the project context.

**Stop here — do not proceed without context.**

#### 2. Collect endpoint-specific inputs

```
Q1: Endpoint name?
    (e.g. "getAccountBalance", "cancelCard")

Q2: Which handler file/method in the source?
    (e.g. Resource.java → getAccountBalanceForMonth)
    Or paste the source code directly.

Q3: Ticket number?
    (e.g. PROJ-123)

Q4: Target module in Go?
    (existing module name, or "new: module_name")
```

#### 3. Verify go-bricks version

```bash
grep 'go-bricks' go.mod
```

If behind latest → create update branch FIRST, then come back.

#### 4. Check go-bricks for reusable types (MANDATORY)

Before ANY code, grep go-bricks for:
- `database.Interface`, `fixtures.NewMockRows`, `mocks.MockDatabase`
- `server.HandlerContext`, `server.Result`, `server.IAPIError`
- `httpclient.Client`, `cryptoutil.DecryptJWE`
- `logger.Logger`, `deps.Config.InjectInto`
- `mocks.MockTx` (if transactional)

Also check `gobricks_mapping` from `.migration-context.yaml` — it lists every go-bricks component and when to use it.

**Rule**: If it exists in go-bricks, use it. Never reinvent.

---

## STEP 0 — Analyze Source Code (MANDATORY BEFORE ANY CODE)

### Read the files listed in context

Using `source.paths` from `.migration-context.yaml`:

1. **Handler/Resource** → HTTP method, path, `@PathParam` vs `@QueryParam`, request validation
2. **Service** → business logic, validation ORDER, external calls, catch blocks, defaults
3. **DAO/Repository** → SQL queries, table names, JOINs, WHERE clauses
4. **Properties files** → error codes and messages (IMMUTABLE — must match exactly)

### Extract and present summary

| Item | Value |
|------|-------|
| HTTP Method + Path | |
| Path Params | |
| Query Params | |
| Request body | none / plain JSON / encrypted (JWE) |
| Response shape | |
| Error codes | (with exact messages from properties) |
| SQL tables | |
| External calls | |
| Date parsing | |
| Defaults | |
| Catch blocks | |
| go-bricks components | (which go-bricks types this endpoint needs) |

**Do NOT proceed until the user approves this analysis.**

---

## STEP 0b — Reprocessing / rule-consolidation review (MANDATORY)

Right after the source analysis (and before the roadmap), identify EVERY place the legacy code
**repeats a read or re-validates the same data across layers** (reprocessing). Present a Java→Go
side-by-side and **ask the user to confirm the consolidation** before planning any phase.

> Mira: **en Java esto se hace así (reproceso) → en Go queda consolidado así (mismo resultado, sin
> reproceso).** ¿Confirmas la consolidación?

| Regla / dato | Java (dónde + nº de accesos) | Go (consolidado) | Reproceso evitado |
|--------------|------------------------------|------------------|-------------------|
| {ej. Card details} | `getUserData` + `isCardStatusValidation` + `isCardExpiryDateValidation` → 3× `getCardDetails` | 1× `GetCustomer`, checks en orden | 2 lecturas DB |
| {ej. …} | … | … | … |

Rules for this step:
- **Preserve the business OUTCOME and the order of precedence** — the check that fires first in Java
  must fire first in Go (same winning code/message). If a consolidation would change WHICH error wins,
  it is a 🔴 divergence — flag it and do NOT consolidate without explicit approval.
- If the source does NOT repeat reads/validations, state "sin reprocesos detectados" and move on.
- **Wait for the user to confirm** the consolidation table before STEP 1. The confirmed consolidations
  are then reflected in the phase plan and called out in the PR.

---

## Reference — Data-access & repository patterns (project-agnostic)

**MANDATORY:** before writing or refactoring ANY repository layer (phase `repository`, shared readers,
QueryBuilder, transactions), read `~/.claude/skills/novo-go-construction-rules/references/data-access-patterns.md`
**in full**. Do not start repository code from memory. If it cannot be read, stop and tell the user.

---

## STEP 1 — Present Phase Roadmap (MANDATORY — show BEFORE any code)

**MANDATORY:** read `~/.claude/skills/novo-go-construction-rules/references/phase-planning.md` **in full** (178 lines) at this
point of the flow — it is the rule set of the `novo-go-construction-rules` skill (call the Skill tool with
`novo-go-construction-rules` if the path is not readable). Never apply it from memory or from this summary.
If it cannot be read, stop and tell the user.

---

## STEP 2 — Execute Phase by Phase (stacked by default, serial when it must be)

**MANDATORY:** read `~/.claude/skills/novo-go-construction-rules/references/phase-execution.md` **in full** (358 lines) at this
point of the flow — it is the rule set of the `novo-go-construction-rules` skill (call the Skill tool with
`novo-go-construction-rules` if the path is not readable). Never apply it from memory or from this summary.
If it cannot be read, stop and tell the user.

---

## Build to the review standard (shift-left)

**MANDATORY:** read `~/.claude/skills/novo-go-construction-rules/references/build-to-review-standard.md` **in full** (73 lines) at this
point of the flow — it is the rule set of the `novo-go-construction-rules` skill (call the Skill tool with
`novo-go-construction-rules` if the path is not readable). Never apply it from memory or from this summary.
If it cannot be read, stop and tell the user.

---

## Implementation Rules

**MANDATORY:** read `~/.claude/skills/novo-go-construction-rules/references/implementation-rules.md` **in full** (177 lines) at this
point of the flow — it is the rule set of the `novo-go-construction-rules` skill (call the Skill tool with
`novo-go-construction-rules` if the path is not readable). Never apply it from memory or from this summary.
If it cannot be read, stop and tell the user.

---

## Testing Patterns

**MANDATORY:** read `~/.claude/skills/novo-go-construction-rules/references/testing-patterns.md` **in full** (58 lines) at this
point of the flow — it is the rule set of the `novo-go-construction-rules` skill (call the Skill tool with
`novo-go-construction-rules` if the path is not readable). Never apply it from memory or from this summary.
If it cannot be read, stop and tell the user.

---

## Handler Patterns

**MANDATORY:** read `~/.claude/skills/novo-go-construction-rules/references/handler-patterns.md` **in full** (54 lines) at this
point of the flow — it is the rule set of the `novo-go-construction-rules` skill (call the Skill tool with
`novo-go-construction-rules` if the path is not readable). Never apply it from memory or from this summary.
If it cannot be read, stop and tell the user.

---

## Docs Phase (LAST — after TEST cert)

1. `{endpoint}-flow.md` — layer-by-layer, error tables, examples
2. `{endpoint}-flow.plantuml` — activity diagram, no internal bypass details
3. Update `overview.md` — endpoint table, params, model, errors
4. Update `openapi.yaml` (root) + `{module}.yaml` (module spec)
5. Bump version

---

## SDLC — NovoPayment standard (org-wide alignment)

**MANDATORY:** read `~/.claude/skills/novo-go-construction-rules/references/sdlc.md` **in full** (46 lines) at this
point of the flow — it is the rule set of the `novo-go-construction-rules` skill (call the Skill tool with
`novo-go-construction-rules` if the path is not readable). Never apply it from memory or from this summary.
If it cannot be read, stop and tell the user.

---

## PR Template

**MANDATORY:** read `~/.claude/skills/novo-go-construction-rules/references/pr-template.md` **in full** (24 lines) at this
point of the flow — it is the rule set of the `novo-go-construction-rules` skill (call the Skill tool with
`novo-go-construction-rules` if the path is not readable). Never apply it from memory or from this summary.
If it cannot be read, stop and tell the user.

---

## Anti-Patterns

**MANDATORY:** read `~/.claude/skills/novo-go-construction-rules/references/anti-patterns.md` **in full** (42 lines) at this
point of the flow — it is the rule set of the `novo-go-construction-rules` skill (call the Skill tool with
`novo-go-construction-rules` if the path is not readable). Never apply it from memory or from this summary.
If it cannot be read, stop and tell the user.

---

## Completion checklist (MANDATORY — print before finishing)

Before reporting done, print every step this skill marks MANDATORY/required/always, each with
its **evidence** (command run, file written, answer the user gave). A step with no evidence
is shown as `❌ NO EJECUTADO` — never omitted, never `✅`. Judging a step "redundant for this
case" is the user's call: ask, do not drop it silently. Approving a plan is not approving
anything that gets published or committed — those need the exact text/diff approved.

## Working if (how the user can tell the run went well)

- Parity decisions and the seams were printed and approved **before** the first line of code.
- Each phase stayed within the caps and ended with the Phase END gates, not just a green build.
- Every created unit has a row in the use-case coverage matrix, with an independent expected value.
- Nothing was published, committed or written to Jira without the exact text/diff approved.
- The completion checklist was printed with evidence; gaps read `❌ NO EJECUTADO`.
