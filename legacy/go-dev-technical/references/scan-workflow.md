# Scan workflow — `go-dev-technical scan <path> [LANG]`

Loaded on demand when the **scan** subcommand runs. A `review` never needs this file.

Everything in SKILL.md still applies — Phase 0's triage and evidence sweep, the checks, and
the Phase 3b gate. This file adds only what is specific to auditing an existing codebase
instead of a diff: checking out `main` first, the deep rawQuery audit, the unused-feature
sweep, and the phased remediation roadmap.

## Scan-specific workflow (scan subcommand)

When running `/go-dev-technical scan <path>`, follow this order:

### Step 0 — Check out `main` before scanning (MANDATORY)

**The scan runs on `main`, never on a feature branch.** Checking out the latest
`main` is a required precondition, not an option — a scan of a stale or feature
checkout reports findings already fixed upstream and misses ones just merged. Do
this first, every time, before any grep runs:

```bash
git fetch origin
git checkout main
git pull --ff-only origin main
git rev-parse --short HEAD    # record the audited commit for the report header
```

This is the default and expected path: whenever the working tree is **clean**,
switch to `main` and pull — even if the user is currently on a feature branch (a
clean checkout is restored trivially with `git checkout -`).

**Only exception — a dirty working tree.** If (and only if) there are uncommitted
changes that a checkout would clobber, do NOT switch branches. Instead check out the
latest `main` in an isolated worktree, exactly like the review flow (Step 0.1), and
run the scan there:
  ```bash
  git fetch origin
  WT="<scratchpad>/scan-main"
  git worktree add --detach "$WT" origin/main
  cd "$WT"          # run the scan here; <path> is relative to this worktree
  ```
  Remove it when done (from the repo root, never from inside the worktree):
  ```bash
  cd <repo-root> && git worktree remove --force "$WT" && git worktree prune
  ```

Report which commit of `main` the audit ran against (`git rev-parse --short HEAD`)
in the scan header, so the findings are reproducible.

### Step 1 — Discover go-bricks version and features

```bash
grep 'go-bricks' go.mod
BRICKS=$(go env GOMODCACHE)/github.com/gaborage/go-bricks@$(grep go-bricks go.mod | awk '{print $2}')
```

### Step 2 — Run all anti-pattern checks

Run every grep from checks 1, 1b, 2, 4, 5, 6, 7, 8, 9, 11, 12, 12b, 13, **19, 20, 21**
against `<path>`. Replace `<changed-files>` with `<path>` and `<module>` with each module
under `<path>`.

**Phase 3b on a scan is where it pays most** — a PR diff shows one site of a leak, a scan
sees all N. Run it repo-wide, not per-module: the whole point of check 19 is the count
across modules, and check 20b/20c only show up when you compare siblings.

- Do a full **19.0 loop** for each cross-cutting concern the codebase has (response
  assembly, error rendering, auth exit, business-code construction, customer/entity
  resolution, module bootstrap) — those are where leaks live
- Build the **depth table** (19f) and both **duplication tables** (20) as first-class scan
  artifacts, next to the rawQuery audit table
- Apply the **20e over-application guard** to every DRY candidate before it reaches the
  roadmap, and list what you deliberately tolerated. A scan that proposes consolidating
  everything it saw is a scan nobody will execute

**The Phase 3b gate applies here verbatim** — all 8 strictness rules, including both
mandatory labels per check-19 finding and the written 20e answer. A scan report whose
design/duplication tables are absent, or present but countless, is incomplete: emit the
tables with their "sin fugas detectadas ✅" / "sin duplicación de conocimiento ✅" rows
rather than dropping them, so the reader can tell *checked and clean* from *not checked*.

### Step 3 — rawQuery deep audit

For every file in `<path>/**/repository/`:

1. Find all raw SQL (`const`, `var`, or inline strings with SQL keywords)
2. Find all `Raw()`, `Expr()`, `MustExpr()` usages
3. For each, determine:
   - Can QueryBuilder express this? (check JOIN, subquery, expression support)
   - Are all dynamic values parameterized (in `args`, never in SQL string)?
   - Is there a comment explaining WHY the builder can't express it?
4. Categorize: ❌ BLOCKER (injection risk) / ⚠️ SHOULD-FIX (builder can replace) / ✅ OK (justified)
5. Build the rawQuery audit table for the report

### Step 4 — Unused go-bricks feature sweep

Compare what the scanned code uses vs what go-bricks provides:

```bash
# What go-bricks packages are imported?
grep -rn "go-bricks" <path> --include="*.go" | grep import | sort -u

# What QueryBuilder features are used?
grep -rn "\.Select\|\.Insert\|\.Update\|\.Delete\|\.InnerJoinOn\|\.LeftJoinOn\|\.Expr\|\.Raw\|\.Paginate\|\.Exists\|\.InSubquery" <path> --include="*.go" | sort -u

# What go-bricks test helpers are used?
grep -rn "MockDatabase\|MockTx\|NewMockRows\|fixtures\." <path> --include="*_test.go" | sort -u

# What go-bricks error types are used?
grep -rn "server\.New.*Error\|NewAppError\|NewBusinessLogicError" <path> --include="*.go" | sort -u
```

For each unused go-bricks feature that applies to the scanned code:
- Identify WHERE in the code it could be used (file:line)
- Explain WHAT go-bricks feature replaces it
- Explain WHY the go-bricks version is better (safety, consistency, less code)

### Step 5 — Report

Beyond the rawQuery audit table, a scan report MUST carry the three Phase 3b tables
(depth 19f, and both duplication tables from check 20) as first-class artifacts, plus the
line naming what duplication was deliberately tolerated per 20e.

Use the same template as review but:
- Replace `## Revisión PR #{number}` with `## Auditoría técnica — {path}`
- Remove PR-specific sections (sizing, title, diff, scope containment)
- Include the rawQuery audit table
- Include the unused go-bricks features section
- Include all anti-pattern findings with file:line evidence
- **Include the remediation roadmap (Step 6)** — a scan without a plan is a list of
  complaints

### Step 6 — Remediation roadmap (MANDATORY for `scan`)

A list of 40 findings is not actionable. The deliverable of `scan` is **an ordered,
sized execution plan**: what to fix, in what order, and split into phases a developer
can actually merge. Same phase discipline as `/migrate` (see
`novo-legacy-migration-endpoint`), because these fixes travel through the same
pipeline.

#### 6.1 Hard constraints per phase (inherited from `/migrate`)

| Constraint | Value | Source |
|---|---|---|
| Max new lines per phase (impl + tests) | **≤400** | NKH1 sizing / `/migrate` |
| Max files per phase | **≤10** | NKH1 sizing / `/migrate` |
| Branch | `feature/{TICKET}-{slug}-{n}`, **always from `main`** | `/migrate` |
| Per phase | tests + `make check` (0 issues) + **semantic version bump** (minor `feat` / patch `fix`·`refactor`) | `/migrate` |
| Merge order | one phase merged before the next starts | `/migrate` |
| Security fixes (SQL injection, PCI) | **≤300 lines**, surgical, first in the queue | stricter, as `parity-solve` |

If a fix does not fit, **split it** — never widen a phase. A "phase" that touches
three modules is two phases.

#### 6.2 Prioritization

Order by **risk × blast radius**, not by how easy it is:

| Prio | What goes here | Why first |
|:--:|---|---|
| **P0** | SQL injection, PCI leaks (PAN/CVV in logs), tenant-isolation breaks, resource leaks in hot paths | Exploitable or already leaking |
| **P1** | Correctness: swallowed errors, lost error chain, goroutine leaks, fail-open branches | Silent wrong behavior in production |
| **P2** | Layer violations, raw `net/http` / `sql.DB` instead of go-bricks, duplicated clients | Structural debt that multiplies with each new module |
| **P3** | rawQuery migratable to QueryBuilder, dead scaffolding, duplicated constants/types, **leaked decisions (19a) and DRY flavor-B violations (20b/20c) rated `strong`** | Maintenance cost, no runtime risk — but every new module inherits the leak |
| **P4** | Naming, missing docs, modernization (`go fix`), Go style/perf idioms (21c) | Readability; batch them, never a phase of their own |

Two sequencing rules that override raw priority:

1. **Enablers first.** If five P3 findings all disappear once one shared helper
   exists, that helper is phase 1 even though it is P3 — it converts five phases
   into one.
2. **Never mix priorities in one phase.** A P0 phase must be reviewable in ten
   minutes; padding it with renames destroys that.
3. **Close the leak before you build on it.** A `strong` check-19 finding whose fix makes
   two or three other findings shrink or vanish is an enabler by rule 1 — schedule it
   early even at P3. Say which findings it shrinks. Conversely, a check-19 finding whose
   destination does not exist yet is not a phase, it is a design task: keep it out of the
   roadmap until the owner is decided.
4. **Money-path consolidation is never a mechanical phase.** Any 19/20 finding on a flow
   that decides whether funds moved, reversed, or are in doubt carries a per-branch parity
   verification against the legacy source as part of its own phase estimate. If that
   verification cannot be scheduled, the finding is deferred, not sized.
5. **`speculative` findings never enter the roadmap.** They go in the deferred list with
   the unresolved tension written out.

#### 6.3 Estimating a phase

For each finding, estimate `~N líneas` = impl + tests. Rules of thumb, stated as
estimates and never as fact:

| Fix type | Typical |
|---|---|
| Constant/alias rename (mechanical, IDE-assisted) | ~5-20 líneas, muchos archivos → cuidado con el cap de 10 files |
| Wrapping an error / adding `%w` + test | ~10-25 líneas |
| Adding a missing error-path test | ~20-40 líneas |
| Migrating one raw `const` query to QueryBuilder + test | ~40-80 líneas |
| Replacing a raw `net/http` client with the connector + tests | ~120-200 líneas |
| Extracting a shared helper consumed by N call sites | ~80-150 líneas + N × ~5 |
| Cerrar una fuga de decisión (funnel único) + migrar N sitios | ~120-200 líneas + N × ~8, **borra** el bloque repetido en cada sitio → el neto puede ser negativo; decirlo |
| Quitar un param pass-through de una interfaz de N métodos (local-substitutable) | ~40-80 líneas impl, pero toca **muchos** archivos de test → el cap de **10 files** es el que parte la fase, no el de líneas. Contar los archivos ANTES de estimar |
| Mover una política detrás de un port (ports & adapters) | ~100-180 líneas; los adaptadores ya existen — el costo real es la verificación de paridad de la política que se mueve |
| Colapsar dos clones en un path + descriptor | ~60-120 líneas, **menos** las ~N copiadas que se borran |
| Tabla rc→mensaje + constructor + test de tabla | ~80-140 líneas + N × ~2 en call sites |
| Bootstrap común de módulos + 1 test | ~60-100 líneas, borra ~18 × M en los M módulos |

When a rename touches more than 10 files, the file cap — not the line cap — is what
splits it. Say so explicitly in the roadmap.

#### 6.4 Roadmap output format

```
Roadmap de remediación — {path}
Hallazgos: {N} (P0:{a} P1:{b} P2:{c} P3:{d} P4:{e})   ·   Fases estimadas: {F}

Fase 1 · P0 · feature/{TICKET}-sqlsafe-1          ~{X} líneas · {n} files
  ├─ repo/legacy.go:30   fmt.Sprintf+SQL → QueryBuilder            ~60
  └─ repo/legacy.go:78   f.Raw() sin parametrizar → f.Raw(cond,?)  ~20
  Desbloquea: nada · Bloqueado por: nada

Fase 2 · P1 · feature/{TICKET}-errchain-1         ~{Y} líneas · {n} files
  └─ service/card.go:112  %s → %w (rompe errors.Is en 3 callers)   ~15
  Desbloquea: Fase 5 (tests de error path)

Fase 3 · P2 · feature/{TICKET}-connector-1        ~{Z} líneas · {n} files
  └─ cards/processing → platform/connector (elimina net/http crudo) ~180
  Enabler: colapsa las fases 6 y 7 en una

...

Diferido (no entra en fases):
  · {hallazgo}  — {por qué no ahora: bloqueado por X / requiere decisión de producto}

Batch final · P4 · feature/{TICKET}-naming-1      ~{W} líneas · {n} files
  └─ 12 renombrados (tabla de nombres) — mecánico, un solo commit
```

Rules for the roadmap:

- **Every phase states `~líneas` and `files`** and both must be under the cap. If
  a row exceeds it, it is already split in the output — do not emit an over-cap phase
  and add "habría que dividirlo".
- **Declare dependencies** (`Bloqueado por` / `Desbloquea`) so the order is not
  arbitrary. A phase with no dependencies can be parallelized by another developer;
  say which ones those are.
- **`Diferido` is a first-class section.** Findings that need a product decision, or
  that depend on work outside the scanned path, go here with the reason — not
  silently dropped, not padded into a phase.
- **Total estimate at the top**, and the honest caveat that line counts are
  estimates from static reading, not measurements.
- **Present the roadmap and stop.** `scan` never creates branches and never edits
  code — it produces the plan. Branch creation follows the `/migrate` flow (ask for
  the Jira ticket, `git checkout main && git pull`, one branch per phase).

File name: `scan-{path-slug}-audit.md` — same temp-dir rule as the review report.

---
