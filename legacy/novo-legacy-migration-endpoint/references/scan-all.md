# Subcommand: `/migrate scan-all [module|ids]` (alias `audit`)

> Loaded on demand from `SKILL.md`. Everything here is binding exactly as if it were inline.

Project-wide, **READ-ONLY** audit of the migration: one table that answers, for every endpoint
already built (the same audit as `/migrate scan <endpoint>`, once per endpoint), "is it really done and ready for QA?". It writes nothing — not the yml, not Jira,
not GitHub, not code. Fixes go through the normal flow (`parity-solve`, `/migrate <endpoint>`).

It does not replace `/go-dev-technical scan <path>`, which audits the **Go code quality** of the
repo. `scan-all` audits the **migration** (parity with Java, tests, Jira, CDSI). Run both for a
full picture, and say so in the final line.

## Workflow

> **ALWAYS checkout main first:** `git checkout main && git pull`. Parity and coverage are
> judged against the canonical code in `main`, never a feature branch. If the working tree is
> dirty, stop and ask; do not stash silently.

1. **Load `.migration-context.yaml`.** If missing, tell the user to run
   `/novo-legacy-migration-context` first. Stop.
2. **Pick the scope.** Default: every endpoint with `status` `done`, `certified` or `in_progress`
   (`not_started` has no Go side and is only counted). An argument narrows it: a module name or a
   list of ids. Print the scope and the number of endpoints.
3. **Confirm the cost once** when the scope has more than 3 endpoints: parity needs one sub-agent
   per endpoint reading Java and Go. Say "N endpoints → N sub-agents, 4 at a time. Continue?" and
   wait. Follow the Question protocol of `SKILL.md`; ask nothing that can be read.
4. **Collect Jira + CDSI + assignee once, in the main agent (read-only):** exactly as
   `/migrate list` steps 2-3 (one `searchJiraIssuesUsingJql` for all tickets,
   `fields: ["status","issuelinks","assignee"]`). Connector not authorized → those columns are
   `n/d`; say so on the first line.
5. **Per-endpoint evidence, in sub-agents.** The audit of one endpoint is defined in
   `references/scan-endpoint.md` (Evidence steps 4-6: parity, untested units on the traced call
   chain, verdict). Do not restate those rules here. Launch one sub-agent per endpoint, **4
   concurrent at most**, each with a fresh context. Brief for each one:
   - "Read `references/scan-endpoint.md` in full and run its Evidence steps 4, 5 and 6 for
     `<endpoint>` against `main`. Jira, assignee and CDSI are already collected: skip step 3.
     READ-ONLY: do not edit, commit, checkout or write any file."
   - "Return only: counts of 🔴 / ⚠️ / ⚪; one line per 🔴 (`#`, rule, Java vs Go); the traced
     untested functions as `file:func` with money-path yes/no; and the verdict step 6 would give
     before CDSI. Under 200 words."
   A sub-agent that fails or returns nothing → that endpoint's parity and test cells are `n/d` with
   the reason.
6. **Verdict per endpoint:** apply step 6 of `references/scan-endpoint.md` using the sub-agent's
   evidence plus the CDSI collected in step 4, and print it with its reason.

## Output (Markdown, never box-drawing, never in a code fence)

Same rules as `/migrate list`: a `###` heading per module with `n/m` ready, one pipe table per
module with cells padded to the widest cell, warnings in a `Notas` list, not inside cells.

| # | Endpoint | Code | Jira | Asignado | Parity 🔴 / ⚠️ / ⚪ | Sin test | CDSI TEST | CDSI UAT | Veredicto |
|---|---|---|---|---|---|---|---|---|---|

Then:
- **Resumen**: endpoints scanned, ✅ / ⚠️ / ❌ counts, total 🔴, total untested units, endpoints
  without CDSI for TEST and for UAT, and how many cells are `n/d`.
- **Notas**, ordered by severity: every 🔴 (`endpoint #n — rule — Java vs Go`), then money-path
  untested units, then missing CDSI.
- **Siguiente paso** per ❌ endpoint: `/migrate parity-solve <endpoint> cases (<ids>)` or the
  test to write. Suggest `/go-dev-technical scan <path>` for the code-quality side.

Do not save the report in the repo. Offer to save it to a path the user names.

## Completion checklist (print with evidence)

| Step | Evidence |
|---|---|
| `main` checked out and up to date | `git rev-parse --short HEAD` |
| Scope printed and cost confirmed | endpoint count + the user's "continue" |
| Jira / CDSI / assignee read | the JQL used, or `n/d` with the reason |
| Untested units traced per endpoint | the call chain and the traced `0.0%` functions per endpoint |
| Evidence run per endpoint | one sub-agent per endpoint following `scan-endpoint.md`; `n/d` listed with its reason |
| Nothing written anywhere | no commit, no yml edit, no Jira or GitHub call that writes |

A step with no evidence is `❌ NO EJECUTADO`; never omitted, never `✅`.
