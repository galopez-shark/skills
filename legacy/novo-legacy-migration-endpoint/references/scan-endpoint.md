# Subcommand: `/migrate scan <endpoint>`

> Loaded on demand from `SKILL.md`. Everything here is binding exactly as if it were inline.

**READ-ONLY** audit of ONE built endpoint: "is it really done and ready for QA?". It writes nothing
— not the yml, not Jira, not GitHub, not code. Fixes go through the normal flow (`parity-solve`,
`/migrate <endpoint>`). `/migrate scan-all` runs the *Evidence* steps below once per endpoint and
prints one row each, so the rules live here and nowhere else.

It does not replace `/go-dev-technical scan <path>`, which audits Go **code quality**. Say so in the
last line of the report.

Accept the endpoint by name, number, or Java method name.

## Workflow

> **ALWAYS checkout main first:** `git checkout main && git pull`. Parity and coverage are judged
> against the canonical code in `main`, never a feature branch. If the working tree is dirty, stop
> and ask; do not stash silently.

1. **Load `.migration-context.yaml`.** If missing, tell the user to run
   `/novo-legacy-migration-context` first. Stop.
2. **Resolve the endpoint** in `endpoint_inventory`. `status: not_started` → there is no Go side to
   audit; say so and suggest `/migrate <endpoint>`. Stop.
3. **Jira, assignee and CDSI** (skip when `scan-all` already collected them): one
   `searchJiraIssuesUsingJql` with `key in (<ticket>)` and `fields: ["status","issuelinks","assignee"]`
   through the Atlassian connector, classifying the `CDSI-` links as TEST / UAT exactly as
   `/migrate list` does. Connector not authorized → `n/d`, said on the first line.

### Evidence (what `scan-all` also runs per endpoint)

4. **Parity.** Read `references/verify-parity.md` in full and run `verify-parity` for the endpoint
   against `main`. Keep: counts of 🔴 Discrepancia de paridad, ⚠️ and ⚪; one line per 🔴 (`#`, the
   rule, Java vs Go outcome); and whether any 🔴 touches money, reversal, balance or authorization.
5. **Untested units on THIS endpoint's call chain.** Trace, read-only, from the route to the handler
   function, then every service method and repository method it calls (Go side only). Then:
   ```bash
   go test ./internal/modules/<module>/... -coverprofile=/tmp/scan-<endpoint>.cover >/dev/null
   go tool cover -func=/tmp/scan-<endpoint>.cover | awk '$NF=="0.0%"'
   ```
   Keep only the `0.0%` functions that are on the traced chain and are not a DTO, constant,
   generated code or module wiring. Mark each as money-path or not (it decides a money movement,
   reversal, balance or authorization). If the tests do not build or the chain cannot be traced, the
   cell is `n/d` with the reason, never `0`.
6. **Verdict** (rule-based, printed with its reason):
   - ✅ **Listo para QA**: no 🔴, no untested non-exempt function on the money path, CDSI for TEST
     and UAT present.
   - ⚠️ **Con pendientes**: no 🔴 on the money path but something above is missing (untested units
     elsewhere on the chain, CDSI missing, any `n/d`).
   - ❌ **No listo**: any 🔴, or an untested function that decides money, reversal, balance or
     authorization.

A failed or empty step is `n/d` with the reason. Never infer a count; never reuse a report from an
earlier session.

## Output (Markdown, never box-drawing, never in a code fence)

A `###` heading with the endpoint, ticket and verdict, then one pipe table with the same columns as
`/migrate scan-all` and a single row, then:

- **Parity**: every 🔴 as `#n — rule — Java vs Go`.
- **Sin test**: each traced untested function as `file:func` with the scenario that should pin it
  (the `EST-NN` when a case list exists) and whether it is money-path.
- **CDSI**: the TEST and UAT tickets with status, or `❌ no enlazado`.
- **Siguiente paso**: `/migrate parity-solve <endpoint> cases (<ids>)` or the test to write; and
  `/go-dev-technical scan <path>` for the code-quality side.

Do not save the report in the repo. Offer to save it to a path the user names.

## Completion checklist (print with evidence)

| Step | Evidence |
|---|---|
| `main` checked out and up to date | `git rev-parse --short HEAD` |
| Endpoint resolved, status not `not_started` | the inventory entry |
| Jira / CDSI / assignee read | the JQL used, or `n/d` with the reason |
| Parity run | the `verify-parity` counts |
| Call chain traced and coverage run | the chain (handler → service → repo) and the command |
| Nothing written anywhere | no commit, no yml edit, no write call to Jira or GitHub |

A step with no evidence is `❌ NO EJECUTADO`; never omitted, never `✅`.
