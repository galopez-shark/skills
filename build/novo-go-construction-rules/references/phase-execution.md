# STEP 2 — Execute Phase by Phase (stacked by default, serial when it must be)

> Shared construction rules, loaded on demand by `novo-legacy-migration-endpoint` and `novo-go-build`.
> Binding exactly as if they were inline. Where the text says Java, parity or `EST-NN`, see "Reading these rules" in `SKILL.md`.

> Before any `repository` phase code, `references/data-access-patterns.md` must already have been read in full (it is in this same folder).

### CRITICAL: one concern per phase — and never move on without a signal

```
Phase 1 → PR (base: main)              → submitted (stacked) / merged (serial) ✓
                                     ↓
Phase 2 → PR (base: phase 1 | main)    → submitted (stacked) / merged (serial) ✓
                                     ↓
  ...repeat for each phase...
                                     ↓
Phase N (docs) → PR → stack merged / merged to main → done ✓
```

The number of phases varies per endpoint (3 to 7+). Two things never change:

1. **One concern per phase**, within the ≤400 prod lines / ≤10 files caps.
2. **Never start the next phase on your own initiative.** The signal you wait for depends on
   the mode chosen at STEP 1 — see "Phase sequencing" below:
   - **Serial** — the signal is the user confirming the previous phase **merged to main**;
     each phase branches from `main`
   - **Stacked** — the signal is the previous phase's PR being **submitted** (`gh stack
     submit`) and the user agreeing to continue. The phase is still open in review; you build
     on its branch, not on `main`

**In neither mode do you start a phase because the previous one "looks finished".** What is
forbidden is inventing the signal, not the waiting itself — and stacking exists precisely so
the waiting stops being the bottleneck.

### Phase sequencing — stacked by default, serial when it must be

The cost of this skill's phase discipline was never the phase size, it was the **waiting**:
a phase could not start until the previous one merged. Stacked PRs remove that wait without
relaxing a single gate — each PR still holds one concern, still caps at ≤400 prod lines and
≤10 files, still bumps its version, still passes its self-review gate.

**Stacked (default).** Phase N+1 branches off phase N's branch and its PR targets that
branch, so GitHub shows only the incremental diff. Reviews run in parallel; the stack lands
in one operation when approved:

```
main ──┬── feature/CEB-XXXX-domain      PR #1 → main        ┐
       └──┬─ feature/CEB-XXXX-repository PR #2 → PR #1      │ all three in review
          └── feature/CEB-XXXX-service   PR #3 → PR #2      ┘ at the same time
```

**Serial (the old flow).** Phase N+1 starts from `main` only after phase N merges. Still the
right mode in the cases listed under "When NOT to stack" below.

#### Prerequisites — verify once, before proposing the stacked mode

```bash
gh --version            # needs >= 2.90.0
git --version           # needs >= 2.20
gh extension install github/gh-stack
gh extension list | grep stack
```

If `gh` is older or the extension is unavailable (offline, restricted runner), **say so and
run serial** — never half-stack by hand-setting base branches, which produces a stack GitHub
tracks but `gh stack` does not.

#### Commands mapped to the phase workflow

| Moment in the phase | Serial | Stacked |
|---|---|---|
| First phase of the endpoint | `git checkout main && git pull`, `git checkout -b feature/{ticket}-{phase}` | `gh stack init -b main`, then rename/create the first branch with the same NKH1 name |
| Start a later phase | wait for merge, then branch from `main` | `gh stack add feature/{ticket}-{phase}` — **no waiting** |
| Commit + branch in one step | — | `gh stack add -Am "type: subject"` |
| Publish the phase | `git push -u origin <branch>` | `gh stack push` |
| Open / update the PRs | `gh pr create` | `gh stack submit` (add `--open` to mark ready for review) |
| See where you are | `git log --oneline` | `gh stack view` |
| Trunk moved, or a lower PR took review changes | `git rebase main` | `gh stack sync` — fetches, fast-forwards trunk, cascades the rebase, pushes, and re-syncs the PRs |
| Conflict during that rebase | resolve, `git rebase --continue` | resolve, `git add`, `gh stack rebase --continue` (or `--abort` to restore every branch) |
| Land it | merge PR, confirm, next phase | `gh stack merge --merge-method squash` |

Branch names do **not** change: the NKH1 convention (`feature/CEB-XXXX-service`, from the
`### Branching` rules) applies identically. Stacking changes each PR's *base*, not its name.

#### The four rules that make a stack safe

1. **`gh stack sync` after every merge and after every review change to a lower PR.** A stack
   whose parent moved is stale, and the diff GitHub shows a reviewer is then wrong. This is
   the one habit the whole mode depends on.
2. **Merging is all-or-nothing up to the PR you pick.** `gh stack merge` lands every PR from
   the trunk up to your choice in a single operation — if any one of them cannot merge, none
   do. So merge *up to the last approved phase*, never "the top one" out of habit.
3. **Review order still runs bottom-up.** A reviewer approving phase 3 is implicitly trusting
   phases 1 and 2. If phase 1 changes after phase 3 was approved, phase 3's approval is stale —
   `gh stack sync` and say so in the PR.
4. **One concern per PR, unchanged.** Stacking makes the ≤400-line cap *easier* to honor, not
   optional. A stack of three oversized PRs is three review problems, not one solved.

#### When NOT to stack — run serial instead

- **The phase must be certified in a real environment before the next one is written.** Any
  phase gated on a TEST/UAT result (typically the route-enabling phase and anything the
  migration context marks as requiring certification) — the next phase's design depends on an
  answer that does not exist yet
- **A money-touching phase whose parity is still unverified.** If the branch decides whether
  funds moved, reversed, or are in doubt, the parity check against the legacy source has to
  land before anything is built on top. Building three phases on an unverified money branch
  means a parity fix cascades a rebase through all of them
- **The next phase's design genuinely depends on the previous phase's review.** If you expect
  the reviewer to change the shape of phase N (an interface, a Row struct, an error contract),
  stacking on it buys speed and pays it back with interest in cascaded rework
- **The repository uses a merge queue for this target.** The stack enters the queue rather
  than merging directly and may land in separate groups — workable, but confirm the ordering
  with whoever owns the queue before relying on it

#### Bookkeeping that changes

- **`.migration-context.yaml`**: `current_branch` is the branch you are *on*; add the stack's
  branch order so a resumed session can reconstruct it (`gh stack view` is the source of
  truth — the file is a convenience, not an authority)
- **Version bumps**: each phase still bumps `app.version` in `config.yml`. Sequential bumps
  inside one stack do not conflict, but **if a lower phase changes its bump after review,
  every phase above it conflicts on that same line** — expect it, resolve it once, and
  `gh stack sync`
- **Roadmap progress**: a phase is "in review", not "done", until the stack actually merges.
  Report both — `Fase 2 — Repository [PR #124, en review, sobre #123]` — so the user is never
  told a phase landed when it is only stacked

#### What to ask the user, and when

At **STEP 1** (phase roadmap), propose the mode explicitly with the reason, and let the user
choose: *"Son 5 fases; propongo stack (fases 1-3) + serial para la fase de ruta, que necesita
certificación en TEST. ¿Lo hago así?"* Do not silently switch a migration already running in
serial mode to stacked — finish the current phase, then propose it for the remainder.

### Phase START sequence (EVERY phase)

1. **Confirm the signal for the active mode** — serial: *"¿La fase N ya está en main?"*;
   stacked: *"La fase N quedó en PR #X; ¿arranco la N+1 sobre esa rama?"*
2. **Resolve the Jira ticket** — if the work's ticket is not known, ASK the user for the ticket or
   epic. **If the user gives an EPIC (not a specific ticket), search Jira under that epic for the
   child ticket whose summary matches this endpoint** (by its `java_method`/name), present the best
   candidate (`KEY — summary`), and **ask the user to confirm it's the right ticket BEFORE creating
   the branch**. If nothing matches, ask for the ticket number or whether to create one. Never branch
   without a confirmed ticket reference.

   ```bash
   # search the epic's children for the endpoint
   curl -s -G "https://{jira_host}/rest/api/3/search" \
     --data-urlencode "jql=parent={EPIC} AND summary ~ \"{endpoint_or_java_method}\"" \
     -H "Authorization: Basic ${AUTH}"
   ```
3. **Position the base** (stash/commit a dirty tree first):
   - serial → `git checkout main && git pull` — the branch starts from `main`
   - stacked → stay on the previous phase's branch; `gh stack sync` first if trunk moved or the
     lower PR took review changes
4. Verify go-bricks version — if outdated, update branch FIRST
5. **Create the branch** (do create it, don't skip) — same NKH1 name in both modes:
   - serial → `git checkout -b {branch_prefix}{ticket}-{phase}` from `main`
   - stacked → `gh stack add {branch_prefix}{ticket}-{phase}` on top of the previous phase
6. Explore existing modules for reusable code
7. **Check go-bricks** for any new helpers relevant to this phase
8. Announce what this phase implements — get confirmation
9. **go-bricks VALIDATION GATE** — run the checklist below before writing any code

#### go-bricks Validation Gate (MANDATORY — runs at end of every Phase START)

Before writing the first line of code in any phase, validate ALL applicable items:

```
┌──────────────────────────────────────────────────────────────────┐
│          go-bricks VALIDATION GATE — Phase {N}: {name}          │
├──────────────────────────────────────────────────────────────────┤
│ CHECK                          │ STATUS │ NOTES                 │
│────────────────────────────────│────────│───────────────────────│
│ go-bricks version up to date   │ ✅/❌  │ v{current} vs v{latest}│
│                                │        │                       │
│ — REPOSITORY PHASE —           │        │                       │
│ database.Interface used        │ ✅/N/A │ never inject raw DB   │
│ getDB func pattern             │ ✅/N/A │ func(ctx) (db, err)   │
│ Positional placeholders        │ ✅/N/A │ Oracle :1..n, PG $N   │
│ Raw/Expr sites annotated       │ ✅/N/A │ // SECURITY: Manual…  │
│ database.Execute* helpers      │ ✅/N/A │ IsNotFound → domain   │
│ fixtures.NewMockRows for tests │ ✅/N/A │ not custom mock rows  │
│ mocks.MockDatabase for tests   │ ✅/N/A │ &mocks.MockDatabase{} │
│ mocks.MockTx if transactional  │ ✅/N/A │ from go-bricks/testing│
│ SQL in queries.go, not inline  │ ✅/N/A │ separate file         │
│                                │        │                       │
│ — SERVICE PHASE —              │        │                       │
│ logger.Logger interface used   │ ✅/N/A │ zerolog via go-bricks │
│ httpclient.Client for ext calls│ ✅/N/A │ not raw http.Client   │
│ cryptoutil for JWE ops         │ ✅/N/A │ DecryptJWE/EncryptJWE │
│ apperrors.AppError for errors  │ ✅/N/A │ structured errors     │
│ No reinvented types            │ ✅/N/A │ grep go-bricks first  │
│                                │        │                       │
│ — HANDLER PHASE —              │        │                       │
│ server.HandlerContext binding   │ ✅/N/A │ not raw echo.Context  │
│ server.IAPIError for errors    │ ✅/N/A │ ValidateError pattern │
│ server.NewResult for response  │ ✅/N/A │ status + body         │
│ app.Module interface           │ ✅/N/A │ Init + RegisterRoutes │
│ Flat binding struct (if JWE)   │ ✅/N/A │ param: + json:"data"  │
│ deps.Config.InjectInto         │ ✅/N/A │ config injection      │
│                                │        │                       │
│ — ALL PHASES —                 │        │                       │
│ Existing helpers reused        │ ✅/N/A │ cardutils, external/* │
│ No duplicate of existing code  │ ✅/N/A │ extend before add     │
│ Config in both yml + yaml      │ ✅/N/A │ env vars + local vals │
│ New PAN/CVV/expiry/token fields│ ✅/N/A │ log.sensitivefields or│
│   masked in logs               │        │ RedactedForLog()      │
└──────────────────────────────────────────────────────────────────┘
```

**How to run the gate:**
1. Mark each check as ✅ (will use), ❌ (violation found — fix before proceeding), or N/A (not applicable to this phase)
2. If ANY check is ❌ → fix it BEFORE writing code
3. Present the filled gate to the user as part of the phase start announcement
4. The gate is a **hard blocker** — no code until all applicable checks pass

**Phase-specific rules:**
- **Domain phase**: Most checks are N/A — domain has no go-bricks deps. Only check: "No reinvented types" and "Existing helpers reused"
- **Repository phase**: DB checks are mandatory. Test checks are mandatory.
- **Service phase**: Logger, httpclient, cryptoutil, apperrors checks are mandatory.
- **Handler phase**: All server.* checks are mandatory. Module registration checks are mandatory.
- **Docs phase**: No go-bricks gate needed — skip entirely.

### Phase END sequence (EVERY phase)

1. **LINE COUNT CHECK** — verify the phase stays within limits. **Measure against this
   branch's BASE, never against `main`.** In a stack, phase 3's diff against `main` also
   contains phases 1 and 2, so measuring from `main` would fail a phase that is perfectly
   sized — the cap is per branch, i.e. per PR, i.e. per unit of review:
   ```bash
   # The base: the parent phase's branch when stacked, main when serial
   BASE=$(gh stack view --json 2>/dev/null | grep -o '"parent":"[^"]*"' | head -1 | cut -d'"' -f4)
   BASE=${BASE:-main}
   echo "midiendo contra: $BASE"

   git diff --stat "$BASE"...HEAD          # implementación + tests de ESTA fase
   # > 400 líneas nuevas o > 10 archivos → STOP y partir la fase
   ```
   If `gh stack view` is unavailable, the base is whatever the PR targets — read it from the
   PR, do not assume `main`. **A cap measured against the wrong base is worse than no cap**:
   it either splits phases that did not need splitting, or silently lets one through.
   If over 400 lines: **do NOT proceed** with make check or PR. Remove excess code, move it to a TODO for the next phase, and re-check.
2. Run test command from context (`make check`, etc.) — 0 issues. Must satisfy the NovoPayment Go
   quality gates: **staticcheck · go vet · gosec · gocyclo · ineffassign · `go test -cover`**.
3. Verify coverage — NKH1 **floor 70%** on changed code, **goal 85%**; keep per-package ~85%.
3b. **USE-CASE TEST GATE (MANDATORY)** — every unit created or changed in this phase has its
   use-case test (see "Every created unit ships with its use-case test"). Mechanical check first,
   then the matrix:
   ```bash
   go test -coverprofile=/tmp/phase.cover ./internal/modules/{module}/... >/dev/null
   CHANGED=$(git diff --name-only "$BASE"...HEAD -- '*.go' ':(exclude)*_test.go')
   go tool cover -func=/tmp/phase.cover | grep -F "$CHANGED" | awk '$NF=="0.0%"'   # any line = a unit with NO test
   ```
   Any `0.0%` function in a changed file → write its test now (or justify it as exempt in one
   line: DTO / constant / generated / wiring). Then print the **use-case coverage matrix**:

   | Unit (file:func) | Test(s) | EST-NN / scenario | Observable outcome asserted | Expected value from |
   |---|---|---|---|---|

   `Expected value from` names the oracle (Java line, `RESPONSE_CODES` entry, approved case). A
   row whose expected value is computed by the code under test is a tautology: rewrite the test.

   A unit with no row fails closed, same as a BLOCKER: do not proceed to the self-review gate.
4. Bump version in versioning file
5. `grep -rn` for source-language references — 0 matches
6. `grep -rn "log.Printf\|fmt.Println"` — 0 debug logs
7. **SELF-REVIEW GATE (MANDATORY)** — review your own phase before anyone else does.
   Reviewing your own diff costs minutes; a review round trip costs a day.

   **Preferred:** run the reviewer itself against the phase branch —
   `/go-dev-technical review <PR_URL>` once the PR exists, or apply its Phase 0 evidence
   sweep locally before opening it. That skill owns the standards; do not re-derive them
   here.

   **Minimum, when the PR does not exist yet** — the sweep from `go-dev-technical`
   Step 0.7, scoped to what this phase touched:
   ```bash
   SCOPE="internal/modules/{module}/"
   OUT=/tmp/phase-sweep.txt; : > $OUT
   s(){ printf '\n##### %s\n' "$1" >> $OUT; shift; grep -rnE "$@" $SCOPE --include='*.go' 2>/dev/null | grep -v '_test\.go' >> $OUT || true; }
   s SQL-INJECTION    'fmt\.(Sprintf|Fprintf)\(.*(SELECT|INSERT|UPDATE|DELETE|FROM|WHERE)|"[^"]*(SELECT|WHERE)[^"]*" *\+'
   s REINVENTED       'sql\.(DB|Open|Conn)|http\.(Client|Get|Post)\{?|echo\.Context|log\.(Printf|Println)|fmt\.Print'
   s LAYER-BREAK      'modules/[a-z_]+/service/.*"(net/http|github.com/labstack)|modules/[a-z_]+/handlers/.*/database"'
   s ERR-SWALLOWED    '_ = .*[Ee]rr|fmt\.Errorf\([^)]*%v[^)]*err'
   s IDIOM-BLOCKER    'panic\(|os\.Exit|log\.Fatal|^func init\(\)'
   s TIME-AS-INT      '(Timeout|TTL|Interval|Delay|ExpiresIn) +(int|int64|string)'
   s RAW-NO-SECURITY  'f\.Raw\(|jf\.Raw\(|database\.Raw\(|SetExpr\(|Having\(|MustExpr\(|[.]Expr\(|RawExpression\{'
   cat $OUT
   ```
   Every hit is **opened and read** before it is dismissed — the sweep locates, it never
   concludes. Each `RAW-NO-SECURITY` hit must carry
   `// SECURITY: Manual SQL review completed - <what was verified>` on the line above it; a hit
   without it is fixed in this phase. A legitimate hit gets a one-line justification in the PR body so the reviewer
   does not re-litigate it (review check 18b honors prior justifications; an unexplained
   escape hatch gets flagged again).

   **Then the design questions the sweep cannot answer** — the ones from "Build to the
   review standard" above:
   - Did this phase **re-assemble the response tail** instead of calling the funnel?
   - Did it add a **second parallel list** of codes and messages?
   - Did it **thread a transport param** through a service signature?
   - Did it write a repository over tables a **shared reader** already covers?
   - Did it **copy an Init block** instead of using the bootstrap?
   - Did it **hand-copy an existing flow** instead of parameterizing a descriptor?

   **Fail closed:** any BLOCKER-class hit (injection, reinvented type, layer break,
   swallowed error, `panic`/`os.Exit` in a request path) → **fix it in this phase**. Do not
   open the PR and do not proceed to step 8. A phase that ships a known blocker has not
   ended.
8. **POSTMAN COLLECTION (handler/route phase only)** — if this phase registers the route
   (i.e. the endpoint becomes reachable), the endpoint MUST be added to the Postman
   collection in the same phase. Add a request with: method, full `/core/<module>/v1/...`
   path (path params as `{{var}}`), required headers (`Authorization`, `switch`), and a
   sample JWE/plain body where applicable. Ask the user where the collection lives if
   unknown (repo file vs Postman cloud via the Postman MCP). Skip for domain/repository/
   service/docs phases — only the phase that enables the route touches the collection.
9. Present PR text with ticket link
10. **Publish the phase** for the active mode:
    - serial → push the branch and open the PR as usual
    - stacked → `gh stack push` then `gh stack submit --open`, and report the PR **with its
      base**: `PR #124 → #123`. Run `gh stack view` and paste it so the user sees the shape
11. **Update roadmap** — mark the phase `merged` (serial) or `en review` (stacked). A stacked
    phase is **not** done until the stack merges; never report it as landed
12. **Update `.migration-context.yaml`** — `current_phase`, `current_branch`, and in stacked
    mode the branch order of the stack
13. **WAIT for approval** before committing

### Between phases — show progress (adapt to actual phase count)

In **stacked** mode the same list carries the PR and its base, and distinguishes
`en review` from `merged` — a stacked phase that is only submitted has not landed:

```
Fase 1 — Domain        [PR #123 → main]  en review
Fase 2 — Repository    [PR #124 → #123]  en review
Fase 3 — Service       [PR #125 → #124]  ← acá vamos
Fase 4 — Handler/ruta  serial, espera certificación en TEST
```

In **serial** mode:

```
Phase 1 — Domain                   [x] merged
Phase 2 — Repository               [x] merged
Phase 3 — Service                  [ ] starting now
Phase 4 — Handler                  [ ] blocked by Phase 3
Phase 5 — Docs                     [ ] blocked by Phase 4 + TEST cert
```

The number of phases is dynamic — always show ALL of them.

### After LAST phase merges

Update `.migration-context.yaml`:
```yaml
status: "done"  # or "certified" after TEST
current_phase: ""
current_branch: ""
```
