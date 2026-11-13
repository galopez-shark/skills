# Subcommand: `/migrate scan-all [module|ids]` (alias `audit`)

> Loaded on demand from `SKILL.md`. Everything here is binding exactly as if it were inline.

Project-wide, **READ-ONLY** audit of the migration: one table that answers, for every endpoint
already built, "is it really done and ready for QA?". It writes nothing — not the yml, not Jira,
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
4. **Collect the cheap evidence in the main agent (read-only):**
   - **Jira + CDSI + assignee:** exactly as `/migrate list` steps 2-3 (one
     `searchJiraIssuesUsingJql`, `fields: ["status","issuelinks","assignee"]`). Connector not
     authorized → those columns are `n/d`; say so on the first line.
   - **Untested units, per module:**
     ```bash
     go test ./internal/modules/<module>/... -coverprofile=/tmp/scan-all-<module>.cover >/dev/null
     go tool cover -func=/tmp/scan-all-<module>.cover | awk '$NF=="0.0%"'
     ```
     Count each `0.0%` function that is not a DTO, constant, generated code or module wiring. If
     the tests do not build, the cell is `n/d`, never `0`.
5. **Parity per endpoint, in sub-agents.** Launch one sub-agent per endpoint, **4 concurrent at
   most**, each with a fresh context. Brief for each one:
   - "Read `references/verify-parity.md` in full and run `verify-parity` for `<endpoint>` against
     `main`. READ-ONLY: do not edit, commit, checkout or write any file."
   - "Return only: counts of 🔴 Discrepancia de paridad, ⚠️ and ⚪ cases; one line per 🔴 (`#`,
     the rule, Java vs Go outcome); and whether any 🔴 touches money, reversal, balance or
     authorization. Under 150 words."
   A sub-agent that fails or returns nothing → that endpoint's parity cell is `n/d` with the
   reason. Never infer a count; never reuse a report from an earlier session.
6. **Verdict per endpoint** (rule-based, printed with its reason):
   - ✅ **Listo para QA**: no 🔴, no untested non-exempt function on the money path, CDSI for TEST
     and UAT present.
   - ⚠️ **Con pendientes**: no 🔴 on the money path but something above is missing (untested
     units elsewhere, CDSI missing, parity `n/d`).
   - ❌ **No listo**: any 🔴, or an untested function that decides money, reversal, balance or
     authorization.

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
| Coverage run per module | the command, and the `0.0%` count per module |
| Parity run per endpoint | one sub-agent per endpoint; `n/d` listed with its reason |
| Nothing written anywhere | no commit, no yml edit, no Jira or GitHub call that writes |

A step with no evidence is `❌ NO EJECUTADO`; never omitted, never `✅`.
