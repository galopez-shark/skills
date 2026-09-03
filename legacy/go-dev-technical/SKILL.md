---
name: go-dev-technical
description: "Technical validator for Go services on go-bricks — stops broken integrations and bad names from reaching production. Two subcommands: (1) /go-dev-technical review <PR_URL> [LANG] runs the toolchain (build/vet/test-cover/golangci-lint/go fix) in an isolated worktree, then validates go-bricks usage, SQL safety, layer boundaries, messaging/bus contracts, error handling, concurrency, resource leaks and naming — proposing a concrete replacement for every bad name — and then reviews design depth: leaked decisions re-decided at N sites, shallow interfaces carrying pass-through params, DRY violations with no single source of truth, and Uber-Go-Style-Guide idiom breaks the linters miss; (2) /go-dev-technical scan <path> [LANG] audits an existing codebase and emits a phased remediation roadmap sized to the merge constraints (<=400 lines / <=10 files per phase, one branch per phase from main). Catches silent bus-contract mismatches (exchange/queue/routing-key/EventType typos that publish fine and route nowhere), AutoAck message loss, missing DLQ, non-idempotent consumers, dual-write without outbox, SQL injection (Raw/Expr/fmt.Sprintf), reinvented types, raw net/http and sql.DB, wrong layer boundaries, swallowed errors, goroutine and resource leaks, stuttering/noise-word/misleading identifiers, information leakage (one decision with N homes and M authorities), hypothetical seams (a param nil in every test), hand-synced parallel constant lists, copy-pasted module bootstrap, and unsafe Go idioms (mutex copied by value, panic in a request path, os.Exit outside main)."
license: MIT
metadata:
  author: galopez-shark
  version: "2.12.0"
  domain: review
  triggers: go-dev-technical, go dev technical, go technical review, go-bricks review, go-bricks scan, validar nombres go, revisar integracion bus, roadmap de remediacion go, deep vs shallow modules, fuga de informacion, revisar duplicacion go, DRY go, idioms go uber
  role: specialist
  scope: code-review
  output-format: report
  related-skills: novo-legacy-migration-endpoint, go-bricks-modules
---

# Go Dev Technical (go-bricks)

Technical quality skill for Go services built on go-bricks. Two modes:
- **review** — extends NKH1 `common:pr-review` with go-bricks framework validation + rawQuery safety
- **scan** — project-wide audit for anti-patterns, unused go-bricks features, and SQL safety

## Fast path — the whole review on one screen

Read this first; the rest of the file is the detail behind each line. Order is chosen so the
cheapest, most decisive evidence lands first and nothing expensive runs on a diff that
cannot need it.

| # | Step | Cost | Why here |
|---|---|---|---|
| 1 | Resolve the PR ref (`git fetch origin refs/pull/<N>/head`) | seconds | A wrong branch means a wrong review. Never guess |
| 2 | **Phase 0** — worktree, `build` / `vet` / `test -cover` / `golangci-lint` / `go fix` | minutes | The toolchain finds what reading cannot. Never opine on an uncompiled diff |
| 3 | **Step 0.6 triage** — what does the diff actually contain? | 5 s | Marks whole check families N/A *with a reason*, so nothing expensive runs pointlessly |
| 4 | **Step 0.7 sweep** — one pass, all deterministic patterns → `/tmp/rv-sweep.txt` | one tree walk | Replaces ~83 separate greps. Every later check reads this file instead of re-scanning |
| 5 | **Blockers** from the sweep: SQL injection → stored procs → layer breaks → error/leak/concurrency → 21a idioms | minutes | Fail fast. If it must never merge, say so before spending effort on style |
| 6 | **Phase 1** NKH1 — size, title, PCI, coverage, version bump | minutes | Cheap, mechanical, and gates the PR regardless of what the code does |
| 7 | **Phase 2** go-bricks (checks 1-10) + **Phase 3** correctness & naming (9, 11-16) | the bulk | Judgment work, now aimed by the sweep rather than searching blind |
| 8 | **Phase 3b** design depth, DRY, Go idioms (19-21) | judgment | Runs on every review and scan. **No count, no finding** |
| 9 | **Phase 4** go-bricks discovery · **Phase 5** scope & evidence (17-18) | minutes | What the PR could have used; then verify every finding carries `file:line` |
| 10 | Write the report — read `references/report-template.md` **now**, not earlier | minutes | Loading the template before the findings exist only costs context |

**Five rules that override anything below.** They are the ones that fail a review when broken:

1. **Phase 0 always.** A review that never compiled the diff reports what the reviewer imagined.
2. **Every finding carries `file:line` + a concrete failure scenario + a fix.** No exceptions.
3. **Unverifiable is ⚠️ NO VERIFICADO, never ✅.** A gap acknowledged beats a gap hidden.
4. **Every SHOULD-FIX carries its concrete proposal** — the exact name, the `git mv` destination, the before→after diff, or (Phase 3b) the count plus the proposed owner. Without it the item is not ready and is not emitted.
5. **Legacy parity beats aesthetics.** A name or a code that replicates the Java contract is documented, not reported.

**On-demand files** (never loaded until the step that needs them):
`references/report-template.md` + `references/report-glossary.md` at report-writing time;
`references/scan-workflow.md` only for the `scan` subcommand.

---

## Usage

### Subcommands

This skill supports two subcommands:

#### 1. `/go-dev-technical review <PR_URL> [LANG]` — Full PR review

Reviews a GitHub pull request for go-bricks compliance, security, and code quality.

- `LANG` is an optional ISO language code: `EN`, `ES`, `PT`, etc.
- **Default language is Spanish (`ES`)** — if no `LANG` is provided, the entire
  report (headings, descriptions, fix suggestions, verdict) MUST be written in Spanish.
- When `LANG=EN` is passed, write the report in English.
- Section titles in the markdown template (## Bloqueadores, ## Debe corregirse, etc.)
  and the go-bricks gate table header labels MUST also be translated to the target language.
- Code snippets, Go identifiers, and file paths are always in English (they are code).

Examples:
- `/go-dev-technical review https://github.com/novopayment/multitenant-banking-api-be-go/pull/27` → report in **Spanish**
- `/go-dev-technical review https://github.com/novopayment/multitenant-banking-api-be-go/pull/27 EN` → report in **English**

The `<PR_URL>` is the GitHub pull request URL. The skill will:
1. Fetch the PR diff
2. Run NKH1 standard review
3. Run go-bricks validation checks (including rawQuery/SQL safety)
4. Report combined findings in the requested language

#### 2. `/go-dev-technical scan <path> [LANG]` — Project anti-pattern & go-bricks audit

Scans a local codebase for anti-patterns, rawQuery safety issues, and unused go-bricks
features, and produces a **phased remediation roadmap** (Step 6) sized to the project's
merge constraints — ≤400 new lines and ≤10 files per phase, one branch per phase from
`main`, same discipline as `/migrate`.

- `path` is the local directory to scan (absolute or relative path)
- `LANG` is an optional ISO language code: `EN`, `ES`, `PT`, etc. (default: `ES`)

**Scan covers three categories:**

**A. Anti-patterns** (things that should use go-bricks but don't):
- Raw DB usage: `sql.DB`, `sql.Open`, `sql.Conn` → should use `database.Interface`
- Raw HTTP client: `http.Client`, `http.Get`, `http.Post` → should use `httpclient.Client`
- Raw echo context: `echo.Context` in handlers → should use `server.HandlerContext`
- Raw logging: `log.Printf`, `fmt.Printf` → should use `logger.Logger`
- Raw JSON response: `c.JSON`, `c.String` → should use `server.NewResult`
- Layer boundary violations: service importing server, handler importing database
- Error handling bugs: ignored errors, lost error chain, shadowed err
- Resource leaks: unclosed HTTP bodies, SQL rows, file handles
- Concurrency bugs: goroutines without context, shared state without mutex

**B. rawQuery / SQL safety audit** (security-critical):
- `fmt.Sprintf` with SQL keywords → SQL injection risk
- String concatenation into SQL → SQL injection risk
- `f.Raw()` / `jf.Raw()` without parameterized args → unsafe escape hatch
- `qb.Expr()` / `MustExpr()` with interpolated user input → injection vector
- Dynamic identifiers (table/column names) without allowlist → injection vector
- Raw SQL `const` without documenting WHY the builder can't express it

**C. Unused go-bricks features** (leveraging the framework fully):
- QueryBuilder available but queries still use raw `const` SQL
- `Entity[T]` defined but not used (dead scaffolding)
- `httpclient` features not used (retry, error classification)
- `mocks.MockDatabase` / `fixtures.NewMockRows` not used in tests
- `server.NewResult` / error types not used in handlers
- Transaction helpers not used (`db.Begin`, `MockTx`)
- `f.Exists()`, `f.InSubquery()` for subqueries instead of raw SQL
- `InnerJoinOn` / `LeftJoinOn` + `JoinFilter` for JOINs instead of raw SQL

Examples:
- `/go-dev-technical scan internal/modules/accounts` → scan accounts module, report in **Spanish**
- `/go-dev-technical scan . EN` → scan entire project, report in **English**

The scan will:
1. Search for anti-patterns and rawQuery risks using grep patterns
2. Explore go-bricks source to find unused features applicable to the scanned code
3. Report findings with file:line evidence, categorized by severity
4. Suggest migration to go-bricks patterns where applicable

#### 3. `/go-dev-technical help` — Help card

```text
go-dev-technical — Validador tecnico para servicios Go sobre go-bricks.
Objetivo: que no llegue a produccion una integracion rota (HTTP o bus) ni un
nombre que mienta sobre lo que hace.

SUBCOMANDOS
  /go-dev-technical review <PR_URL> [LANG]
      Revision completa de un PR. Idioma por defecto: ES (pasar EN para ingles).
      Fase 0  Base de evidencia   build + vet + test -cover + golangci-lint + go fix
                                  worktree aislado, comparado contra origin/main
      Fase 1  NKH1                tamano, titulo, PCI/secretos, bump de version
      Fase 2  go-bricks           tipos reinventados, SQL safety, capas, BUS,
                                  patrones DB/handler, reuso, ubicacion de archivos
      Fase 3  Correctitud         errores, concurrencia+tiempo, leaks, fail-closed,
                                  calidad de tests, NOMBRES, firmas, modernizacion
      Fase 3b Diseno y DRY        modulos shallow, fugas de decision, params
                                  pass-through, duplicacion sin fuente de verdad,
                                  idioms de Go (Uber). Todo hallazgo LLEVA CONTEO.
      Fase 4  Descubrimiento      que ofrece go-bricks que el PR no esta usando
      Fase 5  Scope y evidencia   un solo concern, todo hallazgo con file:line
      Salida: <tmp>/pr-<N>-review.md  (markdown pegable en el PR)

  /go-dev-technical scan <path> [LANG]
      Auditoria del codigo existente + ROADMAP de remediacion ejecutable.
      SIEMPRE baja main primero (fetch + checkout/pull, o worktree si hay WIP)
      para auditar contra el ultimo main; reporta el commit de main auditado.
      Mismos checks que review, sin lo especifico de PR, mas:
        - tabla de auditoria rawQuery (safe / migrable / BLOCKER)
        - features de go-bricks sin usar, con donde aplicarlas
        - roadmap por fases: <=400 lineas y <=10 files por fase, una rama por
          fase desde main, prioridad P0..P4, dependencias y diferidos
      Salida: <tmp>/scan-<path>-audit.md

  /go-dev-technical help
      Esta tarjeta.

QUE ATRAPA (los que duelen)
  BUS       nombre de exchange/queue/routing-key/EventType que no matchea con la
            contraparte: publica ok, no enruta, nadie recibe, NO hay error.
            AutoAck, sin DLQ, sin idempotencia (inbox), dual-write sin outbox.
  SQL       fmt.Sprintf/concat en SQL, Raw()/Expr() sin parametrizar, identificadores
            dinamicos sin allowlist.
  NOMBRES   no solo marca el mal nombre: PROPONE el reemplazo en una tabla
            Actual -> Propuesto -> Razon. Sin propuesta no es hallazgo.
  RUNTIME   errores tragados, %s en vez de %w, goroutine leaks, resource leaks,
            fail-open, tests tautologicos, ramas de error sin cubrir.
  CAPAS     service que importa server, handler que toca database, net/http o
            sql.DB crudos en vez de go-bricks.
  DISENO    una misma decision resuelta en N sitios con M autoridades distintas
            (cambiarla obliga a tocar los N); seam hipotetico: parametro enhebrado
            por 4 niveles y nil en 128 tests; concerns fusionados (telemetria solo
            alcanzable via cifrado -> quien no cifra pierde metricas, sin fallar).
  DRY       clones justo por debajo del threshold de dupl (verde no prueba nada);
            dos listas paralelas sincronizadas a mano (55 codigos vs 44 mensajes);
            bootstrap de modulo copiado con el mismo string de error 6 veces.

REGLAS DURAS
  - Fase 0 SIEMPRE: no se opina sobre un diff sin compilarlo y correrle los tests.
  - go-bricks manda: si el framework lo provee, se usa.
  - Todo hallazgo lleva file:line + escenario de fallo concreto + fix.
  - Lo que no se pudo verificar es (warn) NO VERIFICADO, nunca (ok).
  - Paridad legacy gana sobre estetica: un nombre que replica el contrato Java
    se respeta y se documenta, no se reporta.
  - Fase 3b sin numeros no existe: un hallazgo de diseno sin conteo de sitios /
    autoridades / evidencia de costo en git es opinion, y no se emite.
  - "Duplication is far cheaper than the wrong abstraction": duplicacion chica y
    local se puede TOLERAR, y decirlo es un resultado valido de la revision.
```

## How to get the diff (MANDATORY — never guess the branch)

The PR URL is the source of truth. You MUST resolve the actual PR branch before
reviewing — never assume which branch a PR number corresponds to.

**CRITICAL: ALWAYS re-fetch the PR ref** — even if `pr-<N>` already exists locally.
The author may have pushed new commits since the last fetch. A stale ref means
reviewing old code and missing fixes. Use `--force` to overwrite the local ref.

**Step 1 — Resolve the PR ref locally** (works even without `gh` auth):
```bash
# ALWAYS force-fetch to get the latest commits — never skip this step
git fetch origin refs/pull/<PR_NUMBER>/head:pr-<PR_NUMBER> --force
# Now pr-<PR_NUMBER> is a local ref pointing to the exact PR HEAD
```

**Step 2 — Get the diff against the base branch**:
```bash
git diff origin/main...pr-<PR_NUMBER> --stat
git diff origin/main...pr-<PR_NUMBER>
```

**Step 3 — Read full files from the PR branch** (for context):
```bash
git show pr-<PR_NUMBER>:<file_path>
```

**Alternative** (only if `gh` auth works):
```bash
gh pr view <PR_NUMBER> --json title,headRefName,additions,deletions,changedFiles
gh pr diff <PR_NUMBER>
```

**RULE**: Never use `git branch -r` to guess which branch a PR belongs to. Always
use `git fetch origin refs/pull/<N>/head` or `gh pr view` to resolve the exact ref.
A wrong branch means a wrong review — this is a hard rule, not a suggestion.

---

## Anti-racionalización (NO saltar pasos)

Antes de empezar, rechazar estos atajos mentales:

| Racionalización | Por qué está mal | Acción requerida |
|-----------------|-------------------|------------------|
| "PR pequeño, revisión rápida" | Heartbleed fueron 2 líneas | Clasificar por RIESGO, no por tamaño |
| "Solo es un refactor, no hay impacto" | Los refactors rompen invariantes | Analizar como riesgo ALTO hasta probar lo contrario |
| "Los tests pasan, está bien" | Los tests pueden ser tautológicos o cubrir solo el happy path | Verificar que los tests fallarían sin el cambio |
| "Conozco este codebase" | La familiaridad crea puntos ciegos | Seguir el checklist de todas formas |
| "El autor es experimentado" | Revisar el código, no la reputación | Aplicar los mismos criterios siempre |
| "Con leer el diff alcanza" | El diff no compila, no corre tests y no mide cobertura | Phase 0 SIEMPRE: build + vet + test + lint antes de opinar |
| "El lint pasa" | `golangci-lint` cachea entre worktrees y reporta rutas que ya no existen | `golangci-lint cache clean` y comparar contra `origin/main` |
| "Tiene 95% de cobertura" | El % no dice QUÉ rama falta, y suele faltar la de error | `go tool cover -func` + bloques con 0 hits |
| "`gh` falló, salto ese check" | Un check no verificable es ⚠️, nunca ✅ | Fallback a `git log` y marcar ⚠️ con la razón |
| "El nombre es cuestión de gusto" | Un nombre equivocado propaga un modelo mental equivocado | Google Go Style Guide es el árbitro, no la preferencia |
| "El diseño es subjetivo, no lo toco" | Una decisión con 11 sitios y 3 autoridades es un hecho medible, no una opinión | Fase 3b: contar sitios y autoridades (19.0) antes de opinar o de callarse |
| "`dupl` pasó en verde" | Los clones hechos a mano quedan justo por debajo del threshold configurado | Re-correr `dupl -threshold 40` y comparar con el threshold del repo |
| "Esto está duplicado, hay que abstraerlo" | La abstracción equivocada es más cara que la duplicación | Guard 20e: ¿misma razón de cambio? ¿la abstracción ya existe? Si no → tolerar y decirlo |
| "Es un módulo grande, hay que partirlo" | Tamaño ≠ shallow; una interfaz de 3 métodos sobre 1800 líneas es el objetivo | Medir la interfaz contra lo que esconde, no las líneas (19e) |
| "Consolido el flujo de dinero, es solo refactor" | Certeza, reversa y resolución de estado son reglas de negocio, no forma | Verificación de paridad rama por rama contra el legacy, o se difiere |

---

## Review order

### Phase 0 — Build the evidence base (MANDATORY, run FIRST)

Do not read the diff and reason about it. **Run the toolchain and let it tell you
what is broken** — then reason about what the toolchain cannot see. See
"Phase 0 — Evidence base" below for the exact commands.

### Phase 1 — NKH1 standard (common:pr-review)

1. **Sizing**: ≤400 new LOC, ≤10 files, one problem per PR. **Count only new lines in
   production `.go` files — exclude `_test.go` files from the 400-line budget** (tests
   don't consume the size budget). Compute it explicitly, never eyeball the diff stat:
   ```bash
   # New production LOC (excludes tests) — this is what the ≤400 rule measures
   git diff origin/main...pr-<N> --numstat -- '*.go' ':(exclude)*_test.go' | awk '{a+=$1} END{print a" new prod LOC"}'
   # Test LOC (reported separately, NOT counted against 400)
   git diff origin/main...pr-<N> --numstat -- '*_test.go' | awk '{a+=$1} END{print a" test LOC"}'
   ```
   Report both numbers in the header (e.g. "+180 prod / +420 test"). The ≤400 gate is on
   the prod number.
   **But tests being budget-free is NOT a license to pad**: the excluded tests must be
   **business-scenario tests** (real cases: money moved / not moved, reversal applied /
   not, in-doubt resolved, error paths that change the response) — NOT tests written only
   to lift the coverage %. A PR that hides 400 lines of tautological coverage-padding
   under the "tests don't count" rule fails check 15 (test quality). Tests earn their
   exclusion by pinning a business contract; coverage-only tests do not.
2. **Title**: Conventional Commit, ≤72 chars, no Jira ID in title
3. **Security & PCI**: no secrets, PAN, CVV in code/logs/tests; tenant isolation
4. **Correctness**: edge cases, error paths, money math (integer minor units)
5. **Contracts**: API compatibility, response codes, DB migration safety
6. **Tests**: ≥70% coverage on changed code, error paths covered
7. **Style**: defer to linters (golangci-lint, gofmt, staticcheck)

### Phase 2 — go-bricks validation (checks 1-10)

Anti-patterns: the PR must not reinvent go-bricks types, break layer boundaries,
or escape the QueryBuilder unsafely.

### Phase 3 — Correctness, runtime & naming (checks 9, 11-16)

Correctness bugs and code smells linters miss, plus API/naming design.

### Phase 3b — Design depth & duplication (checks 19-21)

What Phases 2-3 cannot see: code that compiles and passes but is expensive to own —
a decision with N homes (19), a fact with no single source of truth (20), a non-idiomatic
Go construct that survived the linters (21). **Every finding here needs a count**, or it
is an opinion, not a finding.

### Phase 4 — go-bricks discovery

Actively explore go-bricks source for utilities the PR COULD use but doesn't.
Not about blocking — about leveraging the framework's full potential.

### Phase 5 — Scope & evidence verification (checks 17-18)

### Check index

| # | Check | Phase | Severity |
|---|-------|:-----:|----------|
| 1 | No reinvented types | 2 | BLOCKER |
| 1b | rawQuery / SQL safety | 2 | BLOCKER |
| 1c | Vendor adapter over `sql.DB` (unsupported vendor) | 2 | SHOULD-FIX |
| 1d | No stored procedure calls | 2 | BLOCKER |
| 2 | Layer boundaries | 2 | BLOCKER |
| 3 | Module wiring | 2 | SHOULD-FIX |
| 4 / 4b / 4c / 4d | DB patterns, Entity/Row mapping, query construction, dead scaffolding | 2 | SHOULD-FIX |
| 5 | HTTP/handler patterns | 2 | SHOULD-FIX |
| 6 | External calls | 2 | SHOULD-FIX |
| 6b | Messaging / bus integration | 2 | BLOCKER |
| 7 | Test patterns | 2 | SHOULD-FIX |
| 8 / 8a / 8b / 8c / 8d | Reuse check, shared-reader reuse, file & struct placement, file cohesion, file content matches responsibility | 2 | SHOULD-FIX |
| 9 / 9b | Naming & API design, signature design | 3 | SHOULD-FIX |
| 10 / 10b | Config completeness, version bump | 2 | NIT / SHOULD-FIX |
| 11 | Error handling bugs | 3 | BLOCKER |
| 12 | Concurrency & time bugs | 3 | BLOCKER |
| 13 | Resource leaks | 3 | BLOCKER |
| 14 | Fail-closed validation | 3 | SHOULD-FIX |
| 15 | Test quality | 3 | SHOULD-FIX |
| 16 | Modernization (`go fix`) | 3 | NIT |
| 17 | Scope containment | 5 | SHOULD-FIX |
| 18 | Evidence-based findings | 5 | MANDATORY |
| 18b | Honor author's prior justifications | 5 | MANDATORY |
| 19 / 19a-19f | Module depth & information leakage (leaked decision, shallow interface & pass-through params, temporal decomposition, fused concerns) | 3b | SHOULD-FIX |
| 20 / 20a-20f | DRY — one authoritative representation (code clones, parallel lists, copy-pasted bootstrap, cost evidence, over-application guard) | 3b | SHOULD-FIX |
| 21 / 21a-21c | Go idiom safety net (Uber Go Style Guide) | 3b | BLOCKER / SHOULD-FIX / NIT |

---

## Phase 0 — Evidence base (MANDATORY)

A review that only reads the diff reports what the reviewer *imagines* the code
does. Compile it, run it, measure it — **then** review what the tools can't see.
Findings produced this way carry a reproducible command, which is what makes them
survive an argument with the author.

### Step 0.1 — Isolated worktree (never dirty the user's checkout)

The user may have work in progress. Never `git checkout` the PR branch in their
working directory. Use a detached worktree in the scratchpad:

```bash
WT="<scratchpad>/pr<N>"
git worktree add --detach "$WT" pr-<N>
cd "$WT"
```

**Always remove it when done** (from the repo root, not from inside the worktree —
deleting your own CWD breaks the shell):

```bash
cd <repo-root> && git worktree remove --force "$WT" && git worktree prune
```

### Step 0.2 — Run the toolchain

```bash
go build ./...                 # must be clean
go vet ./...                   # must be clean
go test ./... -cover           # all green + per-package coverage
golangci-lint run ./...        # the project's own gate (.golangci.yml)
go fix -diff ./...             # check 16 — modernization, exits non-zero if any
```

**Compare against the base**, never in absolute terms. A pre-existing lint issue
is not this PR's fault; an issue the PR *introduces* is. When `golangci-lint`
reports anything, re-run on `origin/main` to attribute it:

```bash
golangci-lint cache clean && golangci-lint run ./...
```

> `golangci-lint` caches across worktrees and will happily report issues against a
> worktree you already deleted. If paths in the output don't exist, clean the cache
> and re-run before believing the result.

### Step 0.3 — Per-branch coverage, not per-package

"97.6% coverage" is not a finding. **Which branch is uncovered** is:

```bash
go test ./<changed-pkg>/... -coverprofile=/tmp/c.out
go tool cover -func=/tmp/c.out | grep -v "100.0%"     # which functions
grep -v "^mode" /tmp/c.out | awk '$NF==0'             # exact uncovered blocks: file:startLine.col,endLine.col
```

Map each uncovered block back to a line and ask: *is this the error path that will
actually happen in production?* An uncovered transport-failure branch matters more
than an uncovered getter.

### Step 0.4 — Race detector on concurrent code

If the diff touches goroutines, channels, or shared state:

```bash
go test ./... -race
```

### Step 0.5 — When `gh` is unavailable

`gh` frequently lacks repo scope on NovoPayment repos and fails with
`Could not resolve to a Repository`. That is **not** a reason to skip the PR title
check — fall back to the commit subjects and mark the check ⚠️:

```bash
git log origin/main..pr-<N> --oneline
```

Report it as: *"⚠️ `gh` sin scope de repo — no pude leer el título real; el commit
`<subject>` son N chars y cumple"*. Never silently claim ✅ on something you
could not read.

### Step 0.6 — Triage: decide which check families can apply (MANDATORY, 5 seconds)

Before running anything expensive, classify what the diff actually contains. A check
family that cannot apply is **N/A with the reason**, never ✅ and never silently skipped.
This is what keeps a 3-file config PR from being reviewed as if it were a payments engine.

```bash
D="origin/main...pr-<N>"                       # scan: replace with the paths under <path>
git diff $D --name-only > /tmp/rv-files.txt
c(){ grep -cE "$1" /tmp/rv-files.txt; }
printf 'go-prod:%s go-test:%s sql:%s cfg:%s docs:%s\n' \
  "$(grep -E '\.go$' /tmp/rv-files.txt | grep -vc _test.go)" "$(c '_test\.go$')" \
  "$(c '\.sql$|migration')" "$(c '\.ya?ml$')" "$(c '\.md$')"
```

| If the diff has… | Run | Mark N/A |
|---|---|---|
| no `.go` files at all | 1b (SQL in any file), 10/10a/10b, 18 | 1, 2, 4-9, 11-16, 19-21 |
| no `repository/` files | everything else | 4, 4b, 4c, 4d, 1b (unless SQL appears elsewhere) |
| no `handlers/` or `middleware/` | everything else | 5, and the response-tail hunt in 19a |
| no messaging imports | everything else | 6b and all its subchecks |
| no goroutine / `sync` / `chan` | everything else | 12, 12b, 12c, `-race` |
| fewer than 3 `.go` files touched | everything else | 19a and 19c **as diff findings** — but still run them repo-wide on a `scan` |

**The trap to avoid:** N/A is a claim about the *diff*, not about the repo. A PR that
touches one handler still inherits a repo-wide response-tail leak — that is reported as
"this PR adds site N+1" (Phase 3b gate, rule 5), not as N/A.

### Step 0.7 — One evidence sweep, not 83 greps (MANDATORY)

Every deterministic pattern in this skill scans the same tree. Running them check by check
walks the repo dozens of times and makes the review slow for no added precision. **Run the
sweep once, write it to a file, and have every check read that file.** Only judgment checks
(naming 9, design 19-20, discovery Phase 4) still need targeted reading.

```bash
SCOPE="internal/ cmd/"          # review: narrow to the changed dirs · scan: the <path>
OUT=/tmp/rv-sweep.txt; : > $OUT
s(){ printf '\n##### %s\n' "$1" >> $OUT; shift; grep -rnE "$@" $SCOPE --include='*.go' 2>/dev/null | grep -v '_test\.go' >> $OUT || true; }

# --- BLOCKERS first: fail fast on the things that must never merge ---
s SQL-INJECTION      'fmt\.(Sprintf|Fprintf)\(.*(SELECT|INSERT|UPDATE|DELETE|FROM|WHERE)|"[^"]*(SELECT|WHERE)[^"]*" *\+|strings\.(Replace|ReplaceAll)\(.*(SELECT|WHERE)'
s SQL-RAW-ESCAPE     '\.(Raw|Expr|MustExpr)\('
s STORED-PROC        'CALL |EXECUTE |BEGIN.*END;|[a-z_]+\.[a-z_]+\.[a-z_]+\('
s REINVENTED-TYPES   'sql\.(DB|Open|Conn)|http\.(Client|Get|Post)\{?|echo\.Context|log\.(Printf|Println)|fmt\.Print'
s LAYER-BREAK        'modules/[a-z_]+/service/.*"(net/http|github.com/labstack)|modules/[a-z_]+/handlers/.*/database"'
s ERR-SWALLOWED      '_ = .*[Ee]rr|_, _ =|catch|recover\(\)'
s ERR-NO-WRAP        'fmt\.Errorf\([^)]*%v[^)]*err'
s LEAK-BODY-ROWS     '\.Do\(|\.Query\(|os\.Open\('
s CONCURRENCY        'go func|make\(chan|sync\.(Mutex|RWMutex|WaitGroup|Map)|time\.(Sleep|Ticker)'
s IDIOM-21A          'panic\(|os\.Exit|log\.Fatal|^func init\(\)|^var [a-z]'

# --- SHOULD-FIX / NIT ---
s BUS-CONTRACT       'Exchange|RoutingKey|QueueName|EventType|AutoAck'
s IDIOM-21B          'make\(chan [^)]*, *[2-9]|interface\{\}|\.\(\*?[A-Za-z]'
s NAMING-SUSPECTS    'type [A-Z][A-Za-z]*(Data|Info|Manager|Helper|Util|Handler2)|func (Get|Do|Process|Handle)[A-Z]'
s TIME-AS-INT        '(Timeout|TTL|Interval|Delay|ExpiresIn) +(int|int64|string)'

wc -l $OUT && grep -c '^#####' $OUT   # one pass done; every check now reads $OUT
```

**How each check consumes it** — `grep -A30 '^##### SQL-INJECTION' /tmp/rv-sweep.txt`, then
**verify each hit by opening the file at that line**. The sweep *locates*; it never
concludes. A sweep hit is a candidate, and check 18 still requires you to read the code
before it becomes a finding — several patterns above (`ERR-SWALLOWED`, `LEAK-BODY-ROWS`,
`IDIOM-21A`'s `^var [a-z]`) are deliberately over-broad because a false positive you
discard costs seconds while a miss ships.

**Empty section ≠ pass.** If `SCOPE` was wrong or the tree moved, every section is empty
and the review looks clean. Sanity-check: `REINVENTED-TYPES` and `CONCURRENCY` are almost
never both empty in a real go-bricks service. If they are, your `SCOPE` is wrong — fix it
before reporting anything as ✅.

### Phase 0 gate

Report these in the summary table as their own rows. If any command could not be
run (no toolchain, no network), that row is ⚠️ `NO VERIFICADO` with the reason —
never ✅.

---

## go-bricks checks (Phase 2 — checks 1-10)

### 1. No reinvented types (BLOCKER)

If go-bricks provides it, use it. Grep the diff for these anti-patterns:

```bash
# Raw DB (should use database.Interface)
grep -rn "sql\.DB\|sql\.Open\|sql\.Conn" <changed-files> --include="*.go" | grep -v _test.go

# Raw HTTP client (should use httpclient.Client)
grep -rn "http\.Client\|http\.Get\|http\.Post\|http\.NewRequest" <changed-files> --include="*.go" | grep -v _test.go

# Raw echo context (should use server.HandlerContext)
grep -rn "echo\.Context" <changed-files>/handlers/ --include="*.go" | grep -v _test.go

# Raw fmt/log (should use logger.Logger via zerolog)
grep -rn "log\.Printf\|log\.Println\|fmt\.Printf\|fmt\.Println" <changed-files> --include="*.go" | grep -v _test.go

# Raw JSON response (should use server.NewResult / plataform.NovoResult)
grep -rn "c\.JSON\|c\.String" <changed-files>/handlers/ --include="*.go" | grep -v _test.go

# Custom mock DB (should use mocks.MockDatabase / mocks.MockTx)
grep -rn "type Mock.*Database\|type mock.*DB\|type fake.*DB" <changed-files> --include="*_test.go"

# Custom mock rows (should use fixtures.NewMockRows)
grep -rn "type Mock.*Rows\|type mock.*Rows\|type fake.*Rows" <changed-files> --include="*_test.go"
```

All must return **0 matches** (except legitimate type assertions in tests).

**Finding format**: "Raw `X` used — replace with go-bricks `Y`" → BLOCKER.

### 1b. rawQuery / SQL safety (BLOCKER)

**CRITICAL SECURITY** — SQL injection (CWE-89, OWASP Top 10). go-bricks provides
QueryBuilder with parameterized queries as the DEFAULT. Any escape from that path
(Raw, Expr, raw const) requires justification and safe patterns.

#### Tier 1 — BLOCKER (SQL injection risk)

```bash
# fmt.Sprintf / Fprintf with SQL keywords — INJECTION VECTOR
grep -rn "fmt\.Sprintf.*\(SELECT\|INSERT\|UPDATE\|DELETE\|WHERE\|FROM\|JOIN\)" <path> --include="*.go" | grep -v _test.go

# String concatenation into SQL — INJECTION VECTOR
grep -rn '".*SELECT.*".*+\|".*INSERT.*".*+\|".*UPDATE.*".*+\|".*DELETE.*".*+' <path> --include="*.go" | grep -v _test.go

# strings.Replace / ReplaceAll on SQL templates — INJECTION VECTOR
grep -rn "strings\.Replace.*\(SELECT\|INSERT\|UPDATE\|DELETE\|WHERE\)" <path> --include="*.go" | grep -v _test.go

# Raw() and Expr() usages — manual verification needed
grep -rn "\.Raw(\|\.Expr(\|MustExpr(" <path> --include="*.go" | grep -v _test.go
```

For every `Raw()` / `Expr()` / `MustExpr()` hit, verify:
1. The SQL string is a **constant** or developer-controlled → SAFE
2. Any dynamic values go through `args ...any` (placeholders) → SAFE
3. A variable touches the SQL string itself (`fmt.Sprintf`, `+`, etc.) → **BLOCKER**

**BAD (SQL injection vulnerable):**
```go
// BLOCKER: fmt.Sprintf with user input in SQL
query := fmt.Sprintf("SELECT * FROM users WHERE id = %s", userID)

// BLOCKER: string concatenation
query := "SELECT * FROM users WHERE name = '" + userName + "'"

// BLOCKER: variable in Raw() SQL string
f.Raw(fmt.Sprintf("UPPER(%s) = ?", columnName), value)

// BLOCKER: unparameterized Raw()
f.Raw("status = '" + status + "'")

// BLOCKER: strings.Replace on SQL template
query := strings.ReplaceAll(tmpl, "{{status}}", status)
```

#### Tier 2 — SHOULD-FIX (unnecessary escape hatch)

Raw SQL `const` or `Raw()`/`Expr()` that the QueryBuilder CAN express:
```bash
# Raw SQL const in repository — check if builder can express it
grep -rn "const.*=.*\"SELECT\|const.*=.*\"INSERT\|const.*=.*\"UPDATE" <path>/repository/ --include="*.go"
```

For each, compare against QueryBuilder capabilities (see decision tree below).

#### Tier 3 — NIT (missing documentation)

Every `Raw()` / `Expr()` / raw SQL `const` SHOULD have a comment explaining WHY
the QueryBuilder cannot express the query. Missing comment = NIT.

#### go-bricks QueryBuilder: the safe default

**Use QueryBuilder BEFORE reaching for Raw()/Expr()/raw const:**

| Need | QueryBuilder method | Escape hatch |
|------|--------------------|------------------------------------|
| Simple CRUD | `Select`, `Insert`, `Update`, `Delete` | — |
| WHERE conditions | `f.Eq()`, `f.In()`, `f.Like()`, `f.Between()`, `f.And()`, `f.Or()`, `f.Not()` | `f.Raw(condition, args...)` |
| JOINs | `InnerJoinOn()`, `LeftJoinOn()`, `RightJoinOn()` + `jf.EqColumn()`, `jf.Eq()` | `jf.Raw(condition, args...)` |
| Complex expressions | `qb.Expr("COUNT(*)", "alias")`, `qb.MustExpr(...)` | — |
| Table aliases | `dbtypes.MustTable(name).MustAs("alias")` | — |
| Pagination | `Paginate(page, size)` | — |
| Subqueries | `f.Exists(subquery)`, `f.InSubquery(col, subquery)` | — |
| UNION / CTE / PL/SQL | — (not supported) | Raw SQL `const` + `sql.Named()` |

**Safe usage of Raw() (when builder can't express it):**
```go
// GOOD: Raw() with parameterized args — values never in SQL string
f.Raw("UPPER(name) = ?", nameValue)
f.Raw("ST_Distance(location, ?) < 1000", point)
jf.Raw("users.id = profiles.user_id AND profiles.type = ?", "primary")

// GOOD: Expr() for static SQL expressions (no user input)
qb.Expr("COUNT(*)", "total")
qb.MustExpr("TO_CHAR(created_at, 'YYYY-MM-DD')", "date_str")

// GOOD: raw const for UNION (builder doesn't support it)
// QueryBuilder does not support UNION — raw SQL with named params
const queryUnion = `SELECT id FROM active_users WHERE status = :status
UNION ALL
SELECT id FROM archived_users WHERE status = :status`
```

**GOOD (safe with go-bricks QueryBuilder):**
```go
qb := database.NewQueryBuilder(db.DatabaseType())
f := qb.Filter()

sql, args, _ := qb.Select("id", "name", "email").
    From("users").
    Where(f.Eq("id", userID)).
    ToSQL()

rows, err := db.Query(ctx, sql, args...)
```

**go-bricks QueryBuilder advantages:**
- Vendor-aware: auto-handles placeholder differences (Oracle `:1`, Postgres `$1`, MySQL `?`)
- Reserved word quoting: Oracle keywords like `NUMBER`, `DATE` auto-quoted
- Composable: Filter, JoinFilter, OrderBy, Paginate, Subquery
- No string formatting: values passed as separate args, never interpolated
- JOINs built-in: `InnerJoinOn` + `JoinFilter` — NOT a valid excuse for raw const

#### Dynamic identifiers (table/column names)

Bind parameters (`?`, `:1`, `sql.Named`) protect **values only**, not identifiers.
If a table or column name must vary at runtime, use an **allowlist**:
```go
allowed := map[string]bool{"name": true, "email": true, "phone": true}
if !allowed[col] {
    return fmt.Errorf("invalid column: %s", col)
}
query := fmt.Sprintf("SELECT %s FROM users WHERE id = :1", col)
```

Without an allowlist, dynamic identifiers are a BLOCKER (identifier injection).

#### Decision tree for every SQL usage

```
Is the query expressible with QueryBuilder?
├── YES → Use QueryBuilder + Entity[T] (DEFAULT — no exceptions)
└── NO → Is it a WHERE/JOIN condition the builder can't express?
    ├── YES → f.Raw(condition, args...) or jf.Raw(condition, args...)
    │         ALL dynamic values as args (placeholders, never in SQL string)
    │         + comment: WHY builder can't express it
    └── NO → Is it UNION/CTE/PL/SQL/DDL?
        ├── YES → Raw SQL const + sql.Named() for params
        │         + comment: "QueryBuilder does not support X"
        └── NO → Builder probably CAN express it — try harder
```

#### rawQuery audit table (for scan reports)

When running `/go-dev-technical scan`, include a rawQuery audit table:

| # | File | Type | Risk | Detail |
|---|------|------|------|--------|
| 1 | `repo/queries.go:15` | `f.Raw()` | ✅ Safe | Args parameterized, static SQL |
| 2 | `repo/legacy.go:30` | `fmt.Sprintf+SQL` | ❌ BLOCKER | SQL injection — user input in SQL string |
| 3 | `repo/queries.go:45` | raw const | ⚠️ Migratable | Builder can express this JOIN |
| 4 | `repo/queries.go:80` | raw const UNION | ✅ Justified | Builder doesn't support UNION |
| 5 | `repo/search.go:20` | `qb.Expr()` | ✅ Safe | Static expression, no user input |

### 1c. Vendor adapter over `sql.DB` — justified escape from check 1 (SHOULD-FIX)

Check 1 flags raw `sql.DB` as an anti-pattern because go-bricks provides `database.Interface`.
**Exception**: go-bricks ships only **PostgreSQL and Oracle** vendors. When a module must reach a
vendor go-bricks does not support (SQL Server, MySQL, etc.), wrapping `sql.DB` in an **adapter that
implements `database/types.Interface`** is the correct, sanctioned pattern — NOT a check-1
violation. Do not flag the `sql.DB` itself; instead validate the adapter against the baseline below.

```bash
# Adapter packages that wrap an unsupported vendor
grep -rln "types.Interface\|database/types" <path> --include="*.go" | grep -iE "sqlserver|mysql|mssql"
```

When you see such an adapter package (e.g. `repository/sqlserver/adapter.go`), verify:

- [ ] **Implements `types.Interface` with a compile-time assertion**: `var _ types.Interface = (*Adapter)(nil)`.
- [ ] **Read-only intent is enforced, not implied**: write/tx paths (`Exec`, `Begin`, `BeginTx`,
      `Prepare`, `CreateMigrationTable`) return a package sentinel `ErrReadOnly`
      (`errors.Is`-comparable), never a silent `nil`/no-op. A read-only adapter that lets `Exec`
      through is a data-integrity risk.
- [ ] **`New(db *sql.DB)` constructor separate from `Open(cfg)`** — so tests inject `sqlmock`
      without a live server. An adapter that only has `Open` is untestable offline.
- [ ] **DSN built with `net/url` + `url.UserPassword`**, never string concatenation — escaping is
      automatic and the password is carried structurally, not interpolated.
- [ ] **TLS explicit**: `encrypt=true` in the DSN; `TrustServerCertificate` (or equivalent) is a
      per-environment **config field**, never hardcoded `true`.
- [ ] **No credential leak**: `Config.String()` omits password AND user (renders only
      host/port/database); `Open` wraps errors with `%s`(String()), never the raw DSN. The DSN
      string must never reach a log or error.
- [ ] **Driver name is deliberate and documented — it decides the placeholder dialect, and the SQL
      must match**. This is a silent-runtime-break gotcha (no compile error):
      - `mssql` (denisenkom) → positional `?`
      - `sqlserver` (denisenkom / microsoft) → named `@p1` / `@name`
      Flag any adapter whose driver name and query placeholders disagree, and any without a comment
      explaining the choice. Prefer the maintained `github.com/microsoft/go-mssqldb` over the
      archived `github.com/denisenkom/go-mssqldb`.
- [ ] **Pool sized explicitly with rationale** (`SetMaxOpenConns`, `SetMaxIdleConns`,
      `SetConnMaxLifetime`): a periodic/telemetry sweep sizes small (e.g. 2/1); a request-path pool
      sizes to its load. A pool with no limits on a tenant DB is a finding.
- [ ] **`Health(ctx)` with a bounded timeout** (`context.WithTimeout` + `PingContext`) and
      **`Stats()`** exposing pool metrics.
- [ ] **Package doc comment** states why the adapter exists (go-bricks lacks the vendor) and what is
      functional vs `ErrReadOnly`.
- [ ] Error messages in **English**, consistent with the rest of the codebase (no mixed-language
      strings like `"abrir conexión a"`).

**Reference baseline** — a read-only SQL Server adapter satisfying `types.Interface`: `Adapter`
over `New`/`Open`, net/url DSN with `url.UserPassword`, `ErrReadOnly` sentinel on every write path,
bounded `Health`, credential-safe `String()`, and a documented driver/placeholder choice. If the PR
under review diverges (mixes languages, leaks the DSN, hardcodes `TrustServerCertificate`, omits
`SetMaxIdleConns`, or picks a driver whose placeholders don't match the query), flag the specific
gap against this baseline — it is a SHOULD-FIX, not a blocker, unless a credential leaks (BLOCKER)
or `Exec` is not disabled on a read-only adapter (BLOCKER).

### 1d. No stored procedure calls (BLOCKER)

**Do not approve a PR that calls a stored procedure / PL/SQL block.** Business logic
belongs in the Go service layer, not in the database. A stored-procedure call:

- **Cannot be reviewed** — the proc body lives in the database, not in the diff, so the
  reviewer approves logic they cannot see.
- **Cannot be tested** with go-bricks — `mocks.MockDatabase` / `sqlmock` exercise the
  call, never the procedure's internal logic; the real behavior is unverifiable in CI.
- **Is unversioned by this repo** — the proc drifts from the code, deploys out of band,
  and breaks the immutable-build promotion contract (`main → DEV → UAT → PRD`).
- **Bypasses** the QueryBuilder + `Entity[T]` safety and the layer boundaries — the DB
  becomes a second, hidden service layer.

```bash
# PL/SQL block, CALL, EXEC/EXECUTE, or OUT params (typical of proc invocations)
grep -rniE "\bBEGIN\b.*\bEND;|\bCALL[[:space:]]+[A-Za-z0-9_.]+\(|\bEXEC(UTE)?[[:space:]]" <path> --include="*.go" | grep -v _test.go
grep -rn "sql\.Out\b\|\.Out{" <path> --include="*.go" | grep -v _test.go
# package.procedure or schema.package.procedure inside a query string
grep -rniE "[A-Z0-9_]+\.[A-Z0-9_]+\(" <path>/**/repository/ --include="*.go" | grep -viE "\.(Columns|Table|Filter|Query|Exec|Named)\("
```

For every hit, confirm it is really a procedure/function invocation (a PL/SQL
`BEGIN…END;`, `CALL pkg.proc(...)`, `EXEC`, an `OUT`/`sql.Out` parameter, or a
`SCHEMA.PACKAGE.PROC(...)` in the SQL string) and not a plain `SELECT/INSERT/UPDATE`.

**Verdict: BLOCKER — do not approve.** Fix = move the logic into the Go service layer
and build the data access with the QueryBuilder / parametrized SQL over `Entity[T]`.

**Narrow exception (still ❌, escalated to a human — never a silent ✅)**: a
legacy-parity migration where the Java source itself calls the stored procedure **and**
moving the logic to Go is explicitly out of the phase's scope. Even then require, or the
finding stands: (a) a comment citing the parity reason, (b) a follow-up ticket to
migrate the logic out of the DB, and (c) the report marks it **❌ BLOCKER — decisión
humana**, not approved by the skill.

**Report format**:

> `[sp]` `repository/x.go:40` — la query invoca el stored procedure `PKG_X.DO_Y(...)`.
> La lógica de negocio vive en la DB: no se puede revisar (el cuerpo no está en el diff),
> no se testea con go-bricks y rompe la capa. **BLOCKER: no aprobar.** Mover la lógica al
> service + repository con QueryBuilder / SQL parametrizado. Excepción solo con paridad
> legacy documentada + ticket de migración (y aun así queda a decisión humana).

### 2. Layer boundaries (BLOCKER)

go-bricks modules enforce strict layering. Check the imports:

| Layer | MUST NOT import | Why |
|-------|----------------|-----|
| **domain/** (dto, errors, constants) | `server`, `database`, `echo`, `httpclient` | Domain is framework-free |
| **repository/** | `server`, `echo`, `httpclient` | Repository only knows DB |
| **service/** | `server`, `echo`, `IAPIError` | Service is HTTP-unaware |
| **handlers/** | `database`, SQL packages | Handlers don't touch DB directly |

```bash
# Service importing server/echo (wrong)
grep -rn "\".*server\"\|\".*echo\"" <module>/service/ --include="*.go" | grep -v _test.go

# Handler importing database (wrong)
grep -rn "\".*database\"\|\"database/sql\"" <module>/handlers/ --include="*.go" | grep -v _test.go

# Domain importing framework types (wrong)
grep -rn "\".*server\"\|\".*echo\"\|\".*database\"\|\".*httpclient\"" <module>/domain/ --include="*.go"
```

**Finding format**: "`service/X.go` imports `server` — service layer must not know about HTTP" → BLOCKER.

### 3. Module wiring (SHOULD-FIX)

Check `module.go` if it's in the diff:

- [ ] Implements `app.Module` interface (`Name()`, `Init()`, `Shutdown()`)
- [ ] `Init()` only wires dependencies — no business logic, no HTTP parsing, no SQL
- [ ] Route registration uses `server.HandlerContext` wrapper, not raw echo handlers
- [ ] Config injection via `deps.Config.InjectInto` or `config:` struct tags
- [ ] Provider modules initialized before consumer modules (check `Init` order)
- [ ] Cross-module deps via interface injection, not concrete imports

### 4. Database patterns (SHOULD-FIX — repository phase)

When the diff touches repository code:

- [ ] Uses `database.Interface` (injected), never creates DB connections
- [ ] SQL queries in `queries.go` as `const`, not inline strings
- [ ] Named placeholders for Oracle (`:param_name`), not Postgres-style positional (`$1`)
- [ ] `fixtures.NewMockRows` for test data, not custom mock structs
- [ ] `mocks.MockDatabase` / `mocks.MockTx` for DB mocks in tests
- [ ] No `sql.NullString` in domain types — convert at the repository boundary
- [ ] Mapper functions in `mapper.go`, not scattered in repository methods

### 4b. Entity/Row mapping pattern (SHOULD-FIX — repository phase)

The project follows the **zinli-business-be-go** entity mapping convention.
When the diff adds DB read/write structs, verify it follows this pattern:

#### Three struct types at different layers

| Struct | Package | Purpose | `sql.Null*`? | Tags |
|--------|---------|---------|-------------|------|
| **Row struct** (`{Name}Row`) | `repository/` | Flat representation of a SELECT result. One field per column. | YES — for nullable cols | None (no tags) |
| **Entity struct** (`{Name}Entity`) | `domain/` | Represents a table row for INSERTs/UPDATEs. Plain types. | NO | None (no tags) |
| **DTO struct** | `domain/` | Clean business object for service/handler layers. | NO | `json:"..."` on API-facing |

#### `ScanColumns()` helper (MANDATORY for multi-column queries)

Every Row struct with more than 3-4 columns MUST have a `ScanColumns()` function
in `repository/mapper.go` that returns `[]any` of pointers:

```go
// mapper.go
type CardRow struct {
    CardID     string         // NOT NULL → plain type
    BlockType  sql.NullString // nullable → sql.Null*
    CreatedAt  sql.NullTime
}

func ScanColumns(row *CardRow) []any {
    return []any{
        &row.CardID,
        &row.BlockType,
        &row.CreatedAt,
    }
}
```

Usage in repository:
```go
var row CardRow
if err = rows.Scan(ScanColumns(&row)...); err != nil { ... }
```

**Why**: `ScanColumns()` keeps the scan-order contract in ONE place. When a query
adds a column, you update `ScanColumns()` and the compiler catches mismatches.
Inline `rows.Scan(&a, &b, &c, ...)` with 20+ args is error-prone and hard to diff.

#### Mapper functions (MANDATORY)

Mappers live in `repository/mapper.go` and convert Row → DTO:

```go
// mapper.go
func (m *CardMapper) ToCardDTO(row *CardRow) *domain.CardDTO {
    return &domain.CardDTO{
        ID:        row.CardID,
        BlockType: row.BlockType.String, // unwrap sql.Null* here
    }
}
```

**Rules**:
- `sql.Null*` unwrapping happens ONLY in the mapper, never in domain or service
- Check `.Valid` when NULL vs empty has business meaning (e.g., nil card = no card)
- Mapper file also holds `ClassifyX()` helpers if the query JOINs multi-type rows

#### Column metadata via `plataform.Entity[T]` (SHOULD-FIX when Entity[T] exists)

**Before writing column constants**, check if `plataform.Entity[T]` exists:
```bash
grep -rn "type Entity\[" internal/plataform/ --include="*.go"
```

If `plataform.Entity[T]` exists in the project, column constants MUST use it
instead of loose `const` strings. Loose constants lose table-grouping and
don't integrate type-safely with the QueryBuilder.

**Wrong** (loose constants in `queries.go`):
```go
const (
    cardTable          = "CARD"
    cardIDColumn       = "CARD_ID"
    cardStatusIDColumn = "CARD_STATUS_ID"
    // 20+ more scattered constants...
)
```

**Correct** (`plataform.Entity[T]` in `domain/entity.go`):
```go
type CardEntityColumns struct {
    CardID    string
    BlockType string
    StatusID  string
}

var CardEntity = plataform.Entity[CardEntityColumns]{
    Name: "CARD",
    Columns: CardEntityColumns{
        CardID:    "CARD_ID",
        BlockType: "BLOCK_TYPE_ID",
        StatusID:  "CARD_STATUS_ID",
    },
}
```

Usage with QueryBuilder:
```go
sql, args, _ := r.qb.Update(domain.CardEntity.Name).
    Set(domain.CardEntity.Columns.StatusID, statusID).
    Where(r.qb.Filter().Eq(domain.CardEntity.Columns.CardID, cardID)).
    ToSQL()
```

**Why**: `Entity[T]` groups columns by table (not scattered across a file),
gives IDE autocomplete (`domain.CardEntity.Columns.` → all CARD columns),
and prevents typos in column name strings. When the project already has the
generic type, not using it is an anti-pattern.

#### What to flag

```bash
# sql.Null* in domain (should only be in repository Row structs)
grep -rn "sql\.Null" <module>/domain/ --include="*.go"

# Inline scan with 5+ fields and no ScanColumns helper
# Manual: look for rows.Scan(&a, &b, &c, &d, &e, ...) in repository without a ScanColumns()

# Missing mapper.go when repository has Row struct
ls <module>/repository/mapper.go 2>/dev/null || echo "MISSING"
```

Flag:
- **`sql.Null*` in domain**: `domain/dto.go` has `sql.NullString` → move to `repository/` Row struct, unwrap in mapper
- **No `ScanColumns()`**: repository scans 10+ columns inline → extract to `ScanColumns()` in `mapper.go`
- **No mapper file**: Row → DTO conversion is inline in `sql_repository.go` → extract to `mapper.go`
- **Scan order mismatch**: `ScanColumns()` field order doesn't match the SELECT column order in `queries.go`
- **Loose column constants**: `queries.go` has 20+ `const cardXColumn = "X"` when `plataform.Entity[T]` exists → refactor to `Entity[T]` grouped by table in `domain/entity.go`

#### 4c. Query construction: QueryBuilder + `Entity[T]` vs raw SQL `const`

`plataform.Entity[T]` + the go-bricks QueryBuilder is the **DEFAULT** for building
queries — **including JOINs**. Follow zinli-business-be-go: table/column identifiers
come from `Entity[T]` metadata and the QueryBuilder assembles the statement.

**The builder DOES cover JOINs** — this is the most common review mistake: do NOT
wave a JOIN through as "must stay a raw const". The builder supports:

- `InnerJoinOn(dbtypes.MustTable(e.Name).MustAs("alias"), jf.EqColumn(...))`
- `LeftJoinOn` / `RightJoinOn` for outer joins
- `jf := qb.JoinFilter()` + `jf.EqColumn("a.col", "b.col")` for join predicates
- `qb.MustExpr("CASE WHEN ... END", "ALIAS")` for CASE / functions / computed columns
- `dbtypes.MustTable(e.Name).MustAs("at")` for table aliases
- `OrderBy`, `Paginate`, `Where(qb.Filter().Eq(e.Columns.X, v))`

Reference: zinli `auth/repository` `GetToken` builds a 3-table INNER JOIN with a
`to_char(...)` expression via `MustExpr`, every identifier from `Entity[T]` metadata.

**Decision tree:**

| Query shape | How to build it |
|-------------|-----------------|
| Single-table CRUD, **or** JOINs (INNER/LEFT/RIGHT), CASE, functions, ORDER BY, pagination | **QueryBuilder + `Entity[T]`** — the default |
| Set operations with no native builder support (`UNION [ALL]`, recursive CTE, vendor PL/SQL) | **Raw SQL `const` + `sql.Named`** — documented as the exception |

**DO flag (SHOULD-FIX):**
- A JOIN query hand-written as a raw `const` when the builder can express it →
  migrate to builder + `Entity[T]`. **A multi-JOIN is NOT an automatic exception.**
- **Two+ `const` queries identical except for the `WHERE`** → collapse into one
  builder construction (shared SELECT + JOINs) that varies only `.Where(...)`.
  Duplicated ~40-line SELECT bodies are a maintenance trap (e.g. a `ByCustomer`
  and a `ByID` variant of the same lookup).
- Table/column name string literals inline when an `Entity[T]` for that table
  exists (or should exist).

**Legitimately keep as `const`**: `UNION ALL`, set-ops, and constructs the builder
cannot emit — note WHY in a comment above the const so the exception is explicit.

#### 4d. Dead shared scaffolding (SHOULD-FIX)

A shared generic/abstraction that exists but is never used is debt, not
infrastructure — and it misleads future authors into thinking a pattern is "in
use" when it is not.

```bash
# Entity[T] defined but never instantiated anywhere → dead scaffolding
grep -rn "type Entity\[" internal/plataform/ --include="*.go"
grep -rln "plataform.Entity\[" internal/ --include="*.go" | grep -v _test.go  # 0 hits = dead
```

Flag:
- **`Entity[T]` defined, zero usages**: the generic exists but no
  `XxxEntityColumnsMetadata` is declared and no query uses it → either **seed** the
  pattern (define metadata for at least the tables the touched module queries, and
  build with it) or **delete** the dead type. SHOULD-FIX, not a blocker.
- Same for any `internal/plataform/` helper/type with no callers.

### 5. HTTP/handler patterns (SHOULD-FIX — handler phase)

When the diff touches handler code:

- [ ] Uses `server.HandlerContext` binding, not raw `echo.Context`
- [ ] Binding struct with `param:`, `query:`, `json:` tags as appropriate
- [ ] Error response via `server.IAPIError` / `apperrors.AppError`, not manual JSON
- [ ] Response via `server.NewResult` or `plataform.NovoResult`, not `c.JSON`
- [ ] Route registered in `module.go`, not self-registered in handler
- [ ] JWE endpoints: flat binding struct with `param:` + `json:"data"` pattern

### 6. External calls (SHOULD-FIX — service phase)

When the diff touches HTTP calls to external services:

- [ ] Uses `httpclient.Client` from go-bricks, not `net/http` directly
- [ ] Timeout configured via config, not hardcoded
- [ ] Context propagated (`ctx` passed through)
- [ ] Response parsed and errors handled (don't ignore non-2xx)
- [ ] Retry logic delegated to httpclient, not custom loops

### 6b. Messaging / bus integration (BLOCKER)

**This is the check that prevents a broken integration from reaching production.**
An HTTP contract breaks loudly — a 404, a failing test. A bus contract breaks
**silently**: a routing key with a typo publishes successfully, the broker routes it
nowhere, and the consumer simply never receives anything. Nothing fails, nothing
logs an error, and the bug surfaces days later as missing data.

Apply whenever the diff touches `go-bricks/messaging`, `outbox`, `inbox`, AMQP, or
declares an exchange / queue / binding / publisher / consumer.

#### 6b.1 Contract names are the integration (BLOCKER)

Exchange names, queue names, routing keys and `EventType` are a **cross-service
contract**. The compiler does not check them; the broker does not reject them.
A single wrong character = an integration that never works.

- [ ] **Every name verified character-by-character against the counterpart**, not
      "it looks right". The counterpart is the producer repo, the consumer repo, the
      infra declaration, or the legacy service being migrated. Quote the source:
      ```bash
      grep -rn "<routing.key>" --include="*.go" --include="*.yml" --include="*.yaml" .
      grep -rn "RegisterConsumer\|RegisterPublisher\|RegisterBinding" --include="*.go" internal/
      ```
      If the counterpart is not in this repo and cannot be read, the check is
      ⚠️ `NO VERIFICADO` — **never ✅**. Say exactly which name could not be confirmed.
- [ ] **Names come from a shared constant**, never a string literal at the call site.
      A literal repeated in publisher and consumer drifts on the first rename
- [ ] **Naming consistent with the topology already in the repo**: same separator,
      same casing, same segment order (`domain.entity.action` vs
      `service_entity_action` — pick the one already in use and never mix)
- [ ] `EventType` and `Description` are populated on every publisher/consumer
      declaration — they are the documentation of the topology
- [ ] `Declarations.Validate()` catches a consumer/publisher/binding pointing at a
      queue or exchange that was never declared. Verify the module actually declares
      **all four**: exchange, queue, binding, and the consumer/publisher. A consumer
      declared without its binding compiles, starts, and receives nothing

#### 6b.2 Delivery guarantees (BLOCKER)

- [ ] **`AutoAck: false`** on any consumer carrying business events. `AutoAck: true`
      acknowledges on delivery, so a handler that panics or errors **loses the
      message permanently** — no retry, no DLQ, no trace
- [ ] **`Durable: true`** on queues and exchanges that carry business events —
      otherwise a broker restart discards them
- [ ] **DLQ configured**: `QueueDeclaration.Args` carries `x-dead-letter-exchange`
      (and its DLX/DLQ are themselves declared). Without it, a poison message either
      loops forever or vanishes
- [ ] **No infinite requeue**: a handler that nacks with `requeue=true` on a
      permanent error (malformed payload, unknown id) re-delivers the same message
      forever and burns the consumer. Permanent errors go to the DLQ; only transient
      ones requeue
- [ ] **Idempotent consumer**: AMQP is **at-least-once**, so redelivery is normal,
      not exceptional. The handler either wraps in `deps.Inbox.ProcessOnce` (with the
      id from `outbox.EventIDFromHeaders`) or is provably idempotent by construction.
      A consumer that inserts a row without an idempotency key WILL duplicate it
- [ ] **No dual write**: publishing inside a DB transaction that may still roll back
      (or committing then publishing) loses or invents events on any crash between
      the two. Use the transactional **outbox** — that is what it is for

#### 6b.3 Payload contract

- [ ] Producer struct and consumer struct agree **field by field, tag by tag**.
      Compare the JSON tags, not the Go field names
- [ ] Unknown fields tolerated on the consumer side (forward compatibility): adding
      a field to the producer must not break existing consumers
- [ ] A schema change is additive, or the event type is versioned. Renaming or
      removing a field in place breaks every deployed consumer at once
- [ ] Payload carries no PAN/CVV/track data (PCI) and no secrets — a queue is
      persisted storage
- [ ] The event id used for idempotency travels in a **header**, and both sides read
      the same header name

#### 6b.4 Consumer runtime

- [ ] Handler receives and honors `ctx` (shutdown must drain, not truncate)
- [ ] Handler cannot panic out — a panic in a consumer goroutine takes down the
      process or silently kills the consumer depending on the recovery wiring
- [ ] `Workers` / `PrefetchCount` are deliberate: `0` means auto (`NumCPU*4`, prefetch
      `Workers*10` capped at 500). For a handler that writes to a DB with a small
      pool, auto-scaling to 4×CPU workers exhausts the pool — set both explicitly and
      say why
- [ ] Uses go-bricks `messaging` (`Registry` / `Declarations` / `AMQPClient`), never
      `amqp091-go` directly:
      ```bash
      grep -rn "amqp091\|streadway/amqp" --include="*.go" internal/ | grep -v _test.go
      ```

#### 6b.5 Tests

- [ ] There is a test that pins the **contract**: exchange, routing key, event type
      and the serialized payload. That test is what catches a rename before the broker
      silently swallows it
- [ ] Redelivery is tested: the same message twice produces one effect
- [ ] The handler's error path is tested (does it DLQ, requeue, or swallow?)

**Report format** — for bus findings, always state the silent-failure scenario
explicitly, because it is what makes the severity land:

> `[bus]` `module.go:44` — el consumer declara la queue `card.block.v1` pero el
> binding usa `card.blocked.v1`. Publica correcto, el broker enruta a ninguna cola y
> el consumer nunca recibe: **no hay error, no hay log, no hay test rojo**. La
> integración queda muerta en silencio. Fix: constante compartida
> `QueueCardBlocked = "card.blocked.v1"` usada en la declaración y en el binding.

### 7. Test patterns (SHOULD-FIX)

- [ ] `mocks.MockDatabase` for repository tests, not a real DB or custom mock
- [ ] `fixtures.NewMockRows` to build expected result sets
- [ ] Table-driven tests for service logic (multiple error paths)
- [ ] Handler tests use `httptest.NewRecorder` + echo test context
- [ ] No `time.Sleep` in tests — use channels or deterministic sync
- [ ] Testdata in `testdata_test.go` or `testdata/` directory

### 8. Reuse check (SHOULD-FIX)

Before adding new code, check if it already exists:

```bash
# Check for duplicate error sentinels (same rc code, different name)
grep -rn "Code.*=.*\"-XX\"" internal/plataform/bussines/codes.go
grep -rn "Code.*=.*\"-XX\"" internal/modules/*/domain/errors.go

# Check for duplicate queries (same table, same operation)
grep -rn "FROM.*TABLE_NAME" internal/modules/*/repository/queries.go

# Check for duplicate DTOs (same JSON shape)
grep -rn "type.*struct" internal/modules/*/domain/dto.go
```

Flag if:
- A new error sentinel has the same rc code as an existing one (without justification)
- A new SQL query duplicates an existing one in another module
- A new DTO duplicates fields from an existing shared type
- A helper function reimplements something in `internal/plataform/`

#### 8a. Shared reader repositories — reuse before you fork (SHOULD-FIX, strong)

**Generic rule.** A go-bricks service usually keeps **cross-cutting reader repositories in a
shared/platform package** (a package outside any single module — its location is
project-specific and its **name should follow check 9.5**: prefer a `platform` package or one
named by concern, NOT a package literally named `shared`/`common`/`util`. The reference
`mdw-welcome-project-go` groups helpers under the directory `internal/modules/shared/` with the
real packages named by concern underneath (`pagination`, `tenants`, `errors`); zinli uses
`internal/plataform/` — a misspelling of `platform`, pending a refactor — precisely to avoid a
`shared`-named package flagged by lint. Prefer the correctly-spelled `platform`) that several
modules reuse
instead of each one re-reading the same domain tables. Before a module adds its **own**
repository to read a domain table, verify whether a shared reader already covers that table and
reuse it — together with any shared "locate/select from the returned aggregate" helper.

Building a parallel stack — a new `sql_repository.go` + Row struct + `scanColumns()` +
`mapper.go` + a local DTO + a new reader interface — to read tables a shared reader already
covers is a **reuse violation**, even when each piece is individually well-written (correct
QueryBuilder, fully tested). Well-built duplication is still duplication.

**When the shared reader lacks a column** the new flow needs: **extend the shared query + the
shared DTO** — the change is additive and every consumer benefits — then reuse the shared
reader. Do NOT fork. This is the "extend before add" rule: same tables → extend the existing
reader; a new reader is justified only when it returns data the shared one structurally cannot.

```bash
# Shared readers available to reuse — point at the project's platform/shared repository package
grep -rnE "func .*\)(Get|Find|Read|List)[A-Za-z]*\(|New[A-Za-z]*Repository\(" <shared-repo-pkg> --include="*.go" | grep -v _test.go
# A module re-reading a shared domain table in its OWN repository → candidate reuse violation
grep -rln "<SHARED_TABLE_NAME>" internal/modules/*/repository/ --include="*.go" | grep -v _test.go
```

**Example (zinli-business-be-go)** — the rule in the concrete project: the shared reader is
`internal/plataform/repository/customer.GetCustomer(tagPay, cardToken)` returning a
`CustomerDTO` with its cards, plus `cardutils.FindCard(customer, token, activeOnly)`; it reads
the `ADMCONS_*` tables and is reused by accounts/operations/funds_transfer/core_transactions_history.
PR #166 forked a parallel `cardRow`/`scanColumns`/`mapper`/`CardDTO` instead of extending the
shared `CardDTO` with the two missing columns — a reuse violation.

**Report format** (generic):

> `[reuse]` `modules/<m>/repository/sql_repository.go` — reimplementa una lectura que ya provee
> el reader compartido `<shared>.Get<X>` (mismas tablas, ya reusado por otros módulos). Reusar
> el reader compartido; si faltan columnas, **extender** el query y el DTO compartidos, nunca
> forkear un `Row`/`scanColumns`/`mapper`/`DTO` paralelos.

### 8b. File & struct placement (SHOULD-FIX)

Every struct, type, and file must live in the folder that matches its responsibility.
Misplaced types create confusing imports and break the module's layering contract.

**Rules**:

| Type | Belongs in | NOT in |
|------|-----------|--------|
| HTTP binding / edge DTOs (request binding `param:`/`query:`/`json:`, response envelopes) | the handlers layer's DTO file (`handlers/dto.go`) | `domain/`, `service/` |
| Service request/response DTOs (the in/out of a service method) | the service layer's DTO file — **file name is project-specific**: `service/dto.go` in the canonical `mdw-welcome-project-go`; `service/in_out.go` in some services (zinli). Grep a reference module to confirm | `domain/` |
| Pure domain entities / business models (framework-free) | the domain layer — `domain/<entity>.go` in the reference; `domain/dto.go` in some services | `service/`, `repository/`, `handlers/` |
| DTOs for repository input params (write args) | `repository/dto.go` if repo-only; `domain/dto.go` if service also uses it | `repository/interface.go` (mixed with interface def) |
| Row structs for DB scan (`sql.Null*`) | `repository/mapper.go` | `domain/`, `service/` |
| Entity structs for DB writes (column metadata) | `domain/entity.go` | `repository/` (unless repo-internal only) |
| Error sentinels (`ErrNotFound`, `ErrInvalid*`) | `domain/errors.go` | `repository/`, `service/` |
| Business constants (status codes, block types) | `domain/constants.go` | `repository/`, `handlers/` |
| SQL queries as `const` | `repository/queries.go` | inline in `sql_repository.go` |
| Mapper functions (Row → DTO) | `repository/mapper.go` | scattered in `sql_repository.go` |
| Interface definitions | `repository/interface.go`, `service/interface.go` | `domain/` (domain has no interfaces) |

**Why this matters**: When `service/` needs to pass params to `repository/`, it should
import from `domain/` (shared by both layers), not from `repository/` directly. A
`repository.UpdateCardStatusParams` imported by `service/` means service depends on
repository — violating the dependency rule (service → domain ← repository).

**What to flag**:
```bash
# DTOs in repository/ that service/ imports (wrong direction)
grep -rn "repository\." <module>/service/ --include="*.go" | grep -v _test.go | grep -v "CardRepository"

# Structs in wrong package — look for types that don't match their folder's role
grep -rn "type.*Params\|type.*Request\|type.*Response" <module>/repository/ --include="*.go" | grep -v _test.go
```

Flag:
- **DTO in wrong file**: `repository/interface.go` has `UpdateCardStatusParams` mixed with the interface → move to `repository/dto.go` (repo-only params) or `domain/dto.go` (if service needs it too)
- **Request/response in the wrong layer**: the rule is about the **layer, not the file name**. A service request/response (in/out of a service method) or an HTTP binding struct (`param:`/`query:`/`json:`/`validate:`) defined under `domain/` is misplaced — request/response and edge DTOs belong in the **service and handlers layers**, `domain/` stays framework-free (business entities, DB entity metadata, errors, constants only). Whether that file is called `dto.go` or `in_out.go` is irrelevant; what matters is that it is **not in `domain/`**. *Example (zinli): `SetPinRequest` lives in `domain/dto.go` → move to the service layer (as `accounts` does).*
- **Query inline**: SQL string built inside `sql_repository.go` → extract to `queries.go` as `const`
- **Mapper scattered**: Row → DTO conversion in `sql_repository.go` → extract to `mapper.go`
- **Error in wrong layer**: error sentinel defined in `repository/` → move to `domain/errors.go`
- **Module directory name against convention**: a new module whose directory name deviates from the naming pattern of its sibling domain modules (an inconsistent prefix/suffix). Grep the existing `internal/modules/*` names and match the dominant convention; flag the deviation with the corrective `git mv`. *Example (zinli): `core_cards` should be `cards` to match `accounts`/`enrolls`/`operations`; `core_transactions_history` is a lone legacy exception, not the rule.*

### 8c. File cohesion & minimalism (SHOULD-FIX)

The goal is the **fewest `.go` files that still separate concerns**: each concern
(mappers, constants, DTOs, errors, queries, wiring, shared utilities) lives in **one
cohesive file per layer**, not scattered across micro-files. Fragmentation and
junk-drawer files are both findings — one because it hides the concern across many
files, the other because it hides many concerns in one file.

**One canonical file per concern, per layer**:

| Concern | Cohesive file | Layer |
|---|---|---|
| Domain model | `<entity>.go` | `domain/` |
| Table metadata (`Entity[T]`) | `<entity>_entity.go` | `domain/` |
| Error sentinels | `errors.go` | `domain/` |
| Business constants | `constants.go` (or inside the domain file) | `domain/` |
| Repository interface | `repository.go` | `repository/` |
| SQL implementation | `sql_repository.go` | `repository/` |
| Row→DTO mappers | `mapper.go` | `repository/` |
| SQL as `const` (when the module separates them) | `queries.go` | `repository/` |
| Business logic | `service.go` | `service/` |
| Service / handler DTOs | `dto.go` | `service/`, `handlers/` |
| HTTP handlers | `http.go` (+ `health.go`) | `handlers/` |
| AMQP consumer | `<event>_handler.go` | `amqp/` |
| Module wiring | `module.go` | module root |
| Test data / mocks / helpers | `testdata_test.go` / `mocks_test.go` / `testing_helpers_test.go` | per layer |
| Cross-cutting utility | `internal/plataform/` or `shared/<concern>/` named by the concern | shared |

Both `queries.go`/`constants.go` (separate files) and inlining queries/constants into
`sql_repository.go`/the domain file are valid — either is cohesive. Do not force one
over the other.

**What to flag (SHOULD-FIX)**:
- **Fragmentation**: one concern spread over several files → consolidate. Constants in
  4 files → `constants.go`; two mapper files → `mapper.go`; one tiny type per file when
  they cohere → merge into the layer's canonical file.
- **Junk-drawer names**: `utils.go`, `helpers.go`, `common.go`, `misc.go`, `base.go`,
  a generic `handler.go` → rename to the file named after its one responsibility
  (`http.go`, `mapper.go`, `response.go`, …). Same rule for `shared/`: a folder per
  concern (`shared/errors`, `shared/pagination`), never `shared/utils`.
- **Concern outside its layer**: a mapper living in `service/`, a DTO in
  `repository/interface.go` (overlaps 8b).

```bash
# junk-drawer file names in the diff
git diff origin/main...pr-<N> --stat | grep -E '/(utils|helpers|common|misc|base|handler)\.go'
# same concern fragmented — e.g. several *mapper*/*const* files in one layer
git diff origin/main...pr-<N> --name-only | grep -E '/(repository|service|handlers)/' \
  | grep -iE 'map|const|dto|error' | sort
```

**How to report** — phrase the finding as the convention itself; **never name a
reference project** in the finding. Say *what* file the concern belongs in and *why*
(cohesion / one concern per file), not "matches project X".

- File **rename / move** → a `git mv` command (GitHub's ```suggestion block applies to
  line content, not file paths):
  ```bash
  git mv internal/modules/cards/handlers/handler.go \
         internal/modules/cards/handlers/http.go
  ```
- **Consolidation** (many → one) → list the source files and the destination, with the
  `git mv` for the rename and a note to move the remaining content in.
- **Content misplaced inside a file** (a type in the wrong file, not the file itself) →
  a ```suggestion block as in checks 8b / 9.

Example finding (note: no reference-project name):

> - [ ] **`internal/modules/cards/repository/card_mappers.go`** — `[layout]` sugerencia:
>   los mappers Row→DTO se consolidan en `mapper.go` (un concern, un archivo por capa).
>   Seguir una organización más cohesiva y minimalista. *(sugerencia, no bloquea)*
>   ```bash
>   git mv internal/modules/cards/repository/card_mappers.go \
>          internal/modules/cards/repository/mapper.go
>   ```

### 8d. File content matches its declared responsibility (SHOULD-FIX)

8b checks the **folder/layer**, 8c checks **cohesion + file name**. 8d closes the loop:
**a file name is a contract about its content** — open every `.go` file the PR touches and
verify what is inside is what the name promises. Content that does not belong is misplaced
even when the file itself is well-written and its neighbours are correct. (This is the check
that catches a mapper, a query, a business rule or a request struct that each individually
"looks fine" but sits in the wrong file.)

**Generic responsibility manifest** — names are per project (confirm against a reference
module); the *responsibility* is the invariant:

| File (canonical) | MUST contain only | MUST NOT contain |
|---|---|---|
| `domain/<entity>.go` / `dto.go` | business entities/models, framework-free | request/response DTOs, HTTP binding structs, SQL, `sql.Null*`, framework imports |
| `domain/<entity>_entity.go` | `Entity[T]` column metadata for one table | logic, mappers, DTOs |
| `domain/errors.go` | error sentinels/types | logic, DTOs |
| `domain/constants.go` | business constants | logic, SQL |
| `repository/repository.go` | the repository interface(s) | impl, SQL, structs with tags |
| `repository/sql_repository.go` | the repository impl + query assembly | Row→DTO mappers, business rules, HTTP |
| `repository/mapper.go` | Row structs + `scanColumns` + Row→DTO mappers | SQL text, business logic |
| `repository/queries.go` (if used) | SQL as `const` | Go logic, mapping |
| `service/service.go` | business logic | HTTP binding, raw SQL, `server`/`echo` imports |
| `service/<dto|in_out>.go` | service request/response DTOs | business logic, DB Row structs |
| `handlers/http.go` | HTTP binding → service delegation | business rules, SQL, DB access |
| `handlers/<dto>.go` | HTTP binding / edge DTOs | business logic, domain entities |
| `module.go` | dependency wiring + route/consumer registration | business logic, HTTP parsing, SQL |

**Procedure** — for each `.go` file in the diff:
```bash
for f in $(git diff origin/main...pr-<N> --name-only -- '*.go' | grep -v _test.go); do
  echo "== $f =="; git show pr-<N>:"$f" | grep -nE '^func |^type |^const |^var ' | head -40
done
```
Classify each top-level declaration and ask: *does this belong in a file with this name/role?*
Flag the mismatch with the concrete move (```suggestion``` for content inside a file, `git mv`
for a whole misnamed file — same as 8b/8c).

**What to flag (examples of content-in-wrong-file):**
- A `SetPinRequest` (service in/out) sitting in `domain/…` → belongs in the service layer's DTO file.
- A Row→DTO mapper or `scanColumns` defined inside `sql_repository.go` → `mapper.go`.
- A raw SQL string built inside `service.go` → repository (`queries.go` / builder in `sql_repository.go`).
- Business branching inside `handlers/http.go` or `module.go` → service layer.
- `sql.Null*` fields on a struct in `domain/` → the Row struct in `repository/mapper.go`.

**Report format**:

> `[content]` `service/service.go:88` — arma un `SELECT ...` inline en la capa service; el SQL
> vive en el repository (`queries.go`/builder en `sql_repository.go`). El archivo `service.go`
> debe contener solo lógica de negocio.

This composes with 8a: a file whose content **duplicates a shared reader** is both an 8a reuse
violation and an 8d misplacement — report it once, under 8a, with the reuse fix.

### 9. Naming & API design (SHOULD-FIX)

Naming is not cosmetics — a wrong name is a wrong mental model that every future
reader inherits. Baseline is the **Google Go Style Guide** (`google.github.io/styleguide/go`),
which supersedes personal preference. Rules below are the checkable subset.

#### 9.0 Procedure — enumerate, judge, propose (MANDATORY)

This check is **not** "read the diff and see if something looks odd". It is a
sweep: every identifier the PR introduces gets judged, and every bad one leaves
with a **concrete replacement name**. A finding that says "el nombre es poco
descriptivo" without proposing the new name is not a finding, it is a complaint.

**Step 1 — Enumerate every new identifier.** Only added lines (`^+`):

```bash
D="git diff origin/main...pr-<N> -- *.go"

# types, funcs, methods, interfaces
$D | grep "^+" | grep -oE "^\+(type|func) [A-Za-z_][A-Za-z0-9_]*" | sort -u
$D | grep "^+" | grep -oE "^\+func \([a-z]+ \*?[A-Za-z]+\) [A-Za-z_][A-Za-z0-9_]*" | sort -u

# struct fields
$D | grep "^+" | grep -oE "^\+\s+[A-Z][A-Za-z0-9_]*\s+[a-z*\[]" | sort -u

# constants and package-level vars
$D | grep "^+" | grep -oE "^\+\s*(const|var)?\s*[A-Za-z_][A-Za-z0-9_]*\s*=" | sort -u

# import aliases (must match the rest of the repo — see 9.5)
$D | grep "^+" | grep -oE '^\+\s+[a-z][a-zA-Z0-9]* "' | sort -u
```

**Step 2 — Judge each one against 9.1-9.5 and the smell catalog below.**

**Step 3 — For every violation, produce a row** in the rename table (9.6). The
proposed name must be: intention-revealing, pronounceable, greppable, in the
project's domain language, and consistent with what the repo already calls that
concept — check before inventing:

```bash
grep -rn "<concepto>" internal/ --include="*.go" | head    # ¿cómo se llama ya?
```

#### 9.0b Smell catalog — what to hunt and what to propose

*"The name should tell you why it exists, what it does, and how it is used. If a
name requires a comment, the name does not reveal its intent."* (Clean Code, cap. 2)

| Smell | Ejemplo detectado | Propuesta | Por qué |
|---|---|---|---|
| **Palabra ruido** (`Data`, `Info`, `Object`, `Value`, `Item`, `Record`) | `CardData`, `AccountInfo` | `Card`, `Account` | `Data` no distingue nada: todo es datos |
| **Sufijo cajón** (`Manager`, `Processor`, `Helper`, `Util`, `Handler` fuera de HTTP) | `CardManager` | `CardBlocker` / `CardStatusUpdater` | Un `Manager` "gestiona" = no tiene una responsabilidad |
| **Verbo vacío** (`process`, `handle`, `doX`, `execute`, `perform`) | `processCard()` | `blockCard()`, `formatAmount()` | Nombrar el efecto, no el hecho de que haya código |
| **Abreviatura no estándar** | `custId`, `blkTp`, `respCd`, `acctNum` | `customerID`, `blockType`, `responseCode`, `accountNumber` | Sólo se abrevian términos universales (`ctx`, `db`, `tx`, `req`, `resp`, `err`, `id`, `url`, `cfg`) |
| **Nombre desinformativo** | `list` sobre un `map`; `cardList []Card` que trae bines | `byID map[...]`, `binGroups` | Un nombre que miente cuesta más que uno vago |
| **Serie numérica / ruido diferenciador** | `card1`, `card2`, `cardCopy`, `cardTmp` | `source`, `updated` / nombres por rol | Si dos nombres deben diferir, deben *significar* distinto |
| **Tipo en el nombre** | `cardSlice`, `errString`, `idToNameMap` | `cards`, `reason`, `namesByID` | El tipo ya lo dice el compilador |
| **Booleano negado o ambiguo** | `notFound`, `disabled`, `flag` | `found`, `enabled`, `skipUsernameLookup` | `!notFound` obliga a doble negación mental |
| **Constante que se nombra a sí misma** | `PB = "PB"`, `Code40 = "-40"` | `BlockTypeTemporary`, `ErrCodeAccountNotFound` | La constante debe decir qué *denota*, no qué *vale* |
| **Genérico de un solo uso** | `result`, `res`, `out`, `temp` en scope de 20+ líneas | `balances`, `issuance`, `formatted` | Largo proporcional al scope (9.1) |
| **Inconsistencia de léxico** | `Fetch…`, `Get…`, `Retrieve…` para lo mismo | elegir UNO por repo | *"Un lexicón consistente es un gran beneficio"* |
| **Stuttering** | `cards.CardsService`, `connector.ConnectorClient` | `cards.Service`, `connector.Client` | El paquete es la mitad del identificador |
| **Acrónimo mal capitalizado** | `CardId`, `HttpClient`, `panHash`→`PanHash` | `CardID`, `HTTPClient`, `PANHash` | Convención de Go, no opinión |

**Excepción que manda sobre todas**: en una migración, un nombre que replica el
contrato legacy (`GetCardDetail`, `holdResponseCode`, `pvki`, `rc`) **se respeta**
aunque viole el catálogo — la paridad vale más que la estética. Cuando detectes
uno, no lo reportes como hallazgo: menciónalo como decisión verificada.

#### 9.1 The two rules that decide most arguments

1. **Name length is proportional to scope.** *"The length of a name should be
   proportional to the size of its scope and inversely proportional to the number
   of times it is used within that scope."* A 3-line closure may use `c`; a
   package-level var may not. Conversely, `customerIdentifierValue` inside a
   5-line loop is noise.

   | Scope | Acceptable |
   |---|---|
   | 1-7 lines | single letters (`i`, `r`, `w`, `c`, `tt`) |
   | 8-15 lines | short words (`card`, `row`, `resp`) |
   | 15+ lines / package-level | full descriptive names |

2. **Omit what context already says.** Inside package `cards`, a type is `Service`,
   not `CardsService`; a method on `Card` returns `count`, not `cardCount`. The
   caller reads `cards.Service` — the package name is half the identifier.

#### 9.2 Variables & fields

- [ ] camelCase unexported / PascalCase exported — **never** snake_case, never `ALL_CAPS`
- [ ] Initialisms keep uniform case: `ID`, `URL`, `HTTP`, `SQL`, `API`, `RC`, `PAN` —
      `cardID` / `CardID`, never `cardId` / `CardId`
- [ ] No stuttering: `domain.DomainError` → `domain.Error`; `cards.CardsService` → `cards.Service`
- [ ] No type-in-name: `users` not `userSlice`; `byID` not `idToUserMap`
- [ ] Booleans read as assertions: `isActive`, `hasBalance`, `canBlock`, `shouldRetry`,
      or bare adjectives (`valid`, `blocked`). Never negated names — `notReady`
      forces the reader to parse `!notReady`
- [ ] No underscores, except in `_test.go` function names
- [ ] Receiver: 1-2 letters abbreviating the type, **identical across every method
      of that type** (`s` Service, `r` Repository, `h` Handler, `c` Client). Never
      `self`, `this`, or `_` with a body that uses it

#### 9.3 Functions & methods

- [ ] **No `Get` prefix** on accessors: *"Prefer starting the name with the noun
      directly"* — `Balance()` not `GetBalance()`. **Exception**: the underlying
      concept is a get (HTTP GET, `GetCardDetail` mirroring a legacy endpoint,
      SQL `GET_BLOCK_TYPE_BY_ID`). In a migration, legacy-parity names WIN — say so
      in the review instead of flagging them
- [ ] Mutating/acting functions start with a verb: `Create`, `Validate`, `Parse`, `Build`, `Resolve`
- [ ] Constructors are `New{Type}` — `NewService`; in a single-type package just `New`
- [ ] Interface methods name the action, not the plumbing: `FindByID`, `Store` —
      not `DoFind`, `ProcessStore`, `HandleStore`
- [ ] Test names: `TestXxx`, subtests describe the *case*, not the number —
      `t.Run("missing tenant", …)` not `t.Run("case3", …)`

#### 9.4 Types, interfaces & errors

- [ ] Interfaces by behavior (`-er`: `Reader`, `Validator`, `CardUpdater`) or by
      role (`Repository`, `Service`). Small interfaces beat large ones
- [ ] **Interfaces are declared by the consumer**, not shipped with the
      implementation — the package that *calls* defines what it needs
- [ ] Structs are nouns: `Card`, `BlockRequest` — not `CardData`, `AccountInfo`,
      `CardManager` (a `Manager` suffix usually means the type has no single job)
- [ ] Error sentinels: `Err` prefix (`ErrNotFound`); error *types*: `Error` suffix
      (`AppError`, `ValidationError`)
- [ ] Constants explain what the value **denotes**, not what it **is**:
      `BlockTypeTemporary = "PB"` ✅ — `PB = "PB"` or `StringPB` ❌

#### 9.5 Packages & files

- [ ] Package name: short, lowercase, one word, no underscores, no mixedCaps
- [ ] **Banned package names**: `util`, `utils`, `common`, `helpers`, `misc`, `shared`,
      `base` — they attract unrelated code and force import aliases. A package named
      after what it *is for* (`connector`, `apperrors`, `external`) stays coherent.
      Same rule for files: a `helpers.go` becomes a junk drawer — name it after its
      one type (`handler.go`, `response.go`)
- [ ] Package name is not repeated by its contents (`connector.Client`, not `connector.ConnectorClient`)
- [ ] Import aliases: **one alias per package, repo-wide**. Two files aliasing the
      same import differently (`platdomain` vs `platformdomain`) is a real finding —
      grep before accepting a new alias:
      ```bash
      grep -rn '"<module>/internal/platform/domain"' --include="*.go" internal/ | sed 's/.*  *\([a-z]*\) "/\1/' | sort -u
      ```
- [ ] Files snake_case (`block_request.go`); one primary type per file, except
      deliberate collections (`dto.go`, `errors.go`, `constants.go`)

#### 9.6 How to report — the rename table is MANDATORY

The output of check 9 is a **table of concrete rename proposals**, always present
in the report (inside the `<details>` block), even when everything passes.

| # | Archivo | Actual | **Propuesto** | Razón |
|---|---------|--------|---------------|-------|
| 1 | `cards/service.go:24` | `cards.CardsService` | `cards.Service` | Stuttering: el paquete ya dice `cards` |
| 2 | `cards/domain/dto.go:31` | `BlockTypeId` | `BlockTypeID` | Acrónimo: `ID` va en mayúsculas |
| 3 | `repository/sql_repository.go:13` | alias `platformdomain` | `platdomain` | 4 archivos del repo ya usan `platdomain` |
| 4 | `external/processingcore.go:88` | `processCard()` | `blockCard()` | Verbo vacío: nombrar el efecto |

Rules for the table:

- **Cada fila lleva una propuesta.** Ninguna fila puede decir "mejorar el nombre",
  "poco descriptivo" o "revisar". Si no se te ocurre el nombre correcto, el hallazgo
  no está listo — busca cómo llama el repo a ese concepto y propón eso.
- **`Razón` en una línea**, citando la regla (stuttering / acrónimo / palabra ruido /
  scope / léxico inconsistente), no un párrafo.
- **Cuando todo pasa**, la tabla lleva una fila
  `— | — | Todas las convenciones seguidas ✅ | — | —` **y debajo una línea de lo
  que sí verificaste**: receptores, `ctx` primero, `error` último, acrónimos,
  stuttering, alias de import, palabras ruido. Así el autor sabe que el check corrió
  y no se saltó.
- **Renombres masivos**: si la propuesta toca >10 sitios, no la conviertas en
  bloqueante del PR — proponla y márcala como trabajo de seguimiento, indicando el
  comando: `gofmt -r 'oldName -> newName' -w ./...` o el rename del IDE (que además
  actualiza referencias en tests).

**Ruteo de los hallazgos de nombres (IMPORTANTE)**: cuando la tabla tenga
**al menos una fila real** de renombrado (algo distinto de la fila "todas las
convenciones seguidas ✅"), esos hallazgos deben aparecer **también en la sección
`Debe corregirse`** como un ítem de **sugerencia** — no quedarse enterrados en el
`<details>`. La redacción es de recomendación, no de bloqueo: *"seguir una
nomenclatura más clara y diciente"*, con la propuesta concreta. El `<details>` con
la tabla completa se mantiene como el registro del barrido (incluye la verificación
y los renombres masivos diferidos); la sección `Debe corregirse` lleva el resumen
accionable para que el autor lo vea sin expandir nada.

Formato del ítem en `Debe corregirse` — cada hallazgo lleva su **propuesta como
bloque `suggestion` de GitHub**, para que al pegarlo como comentario inline salga el
botón *"Apply suggestion"* y el autor lo aplique con un click:

````markdown
- [ ] **`path/file.go:24`** — `[naming]` sugerencia: renombrar `{actual}` → `{propuesto}`
  ({regla en una línea, p. ej. stuttering / acrónimo / palabra ruido}). Seguir una
  nomenclatura más clara y diciente. *(sugerencia, no bloquea el merge)*
  ```suggestion
  {la línea path/file.go:24 completa, ya con el nombre corregido}
  ```
````

Reglas del bloque `suggestion`:
- El contenido es la **línea (o líneas) exacta(s) del diff ya corregida(s)** — GitHub
  reemplaza la(s) línea(s) comentada(s) por lo que va dentro del bloque. Debe compilar
  tal cual: copiá la línea original y cambiá sólo el identificador.
- Sólo se convierte en botón *"Apply"* cuando el comentario se postea **inline sobre
  esa línea** del PR; en un comentario general del PR se ve como bloque de código
  normal. Indicá el `path:line` para que el revisor sepa dónde anclarlo.
- **Renombre de un solo sitio** (una declaración local, un campo, un alias en un
  archivo) → `suggestion` directo. **Renombre multi-sitio** (un tipo/función usado en
  N archivos) → NO uses `suggestion` (arreglaría sólo la declaración y dejaría las
  referencias rotas): dejalo en la tabla del `<details>` como seguimiento con el
  comando `gofmt -r '{actual} -> {propuesto}' -w ./...`, y decilo explícito en el bullet.

Los nombres cuyo impacto **excede el estilo** — un nombre que **miente** sobre lo que
el valor contiene, o una inconsistencia de léxico que se va a propagar a los próximos
PRs — van igual en `Debe corregirse` pero con el fraseo reforzado (no como mera
sugerencia estética), con el mismo formato de propuesta:

> `[naming]` `external/processingcore.go:41` — el campo `HoldResponseCode` recibe el
> `blockTypeKey`, no un código de respuesta: el nombre miente sobre el contenido.
> El comentario `// blockTypeKey` es la prueba de que el nombre no se explica solo.
> **Propuesta**: `BlockTypeKey`, y si el JSON del proveedor exige `holdResponseCode`,
> que la diferencia viva sólo en el tag: `BlockTypeKey string \`json:"holdResponseCode"\``.

The **Naming & conventions** table is ALWAYS present in the report, even when
everything passes (with a "todas las convenciones seguidas ✅" row). When it
passes, list in one line what you actually checked — receivers, `ctx` first,
`error` last, acronyms, stuttering, aliases — so the author knows it wasn't skipped.
When it does NOT pass, the `<details>` table still carries every row, **and** each
real finding is surfaced up in `Debe corregirse` / `Should fix` as a `[naming]`
suggestion per the routing rule above.

#### 9b. Function & method signature design (SHOULD-FIX)

Naming says what it is called; the signature says how it can be misused.

- [ ] `ctx context.Context` is the **first** parameter, always, and named `ctx`.
      Never stored in a struct field
- [ ] `error` is the **last** return value
- [ ] **No boolean parameters**: `Block(ctx, card, true)` is unreadable at the call
      site. Use a named type or two methods (`Block` / `Unblock`)
- [ ] More than 4-5 parameters, or 2+ adjacent params of the same type
      (`f(customerID, accountID, cardID string)` — swappable, compiler-silent) →
      take a params struct
- [ ] **Accept interfaces, return concrete types** — a constructor returning an
      interface hides fields and blocks the caller from extending
- [ ] Pointer vs value in returns is deliberate: `*Card` when nil is a meaningful
      "absent"; `Card` when it is always present. `(*Card, error)` where the pointer
      is never nil on success is a nil-check the caller pays for on every call
- [ ] Every exported symbol has a doc comment starting with its own name
- [ ] Struct literals crossing package boundaries use **keyed fields**
      (`Endpoint{URL: u, Path: p}`) — positional literals break silently when a
      field is added

### 10. Config completeness (NIT)

If the PR adds config consumption (`config:` tags or `deps.Config`):

- [ ] Key exists in both `config.yml` (env vars) and `config.yaml` (local values)
- [ ] New config key follows existing naming convention
- [ ] Sensitive values use env var placeholders, not hardcoded
- [ ] **App-specific keys live under `custom:`** (see 10a) — anything go-bricks does
      not natively map MUST be nested under `custom.*`, never at the config root

#### 10a. Application config belongs under `custom:` (SHOULD-FIX)

go-bricks owns a **fixed set of top-level config sections** and binds them into its
own structs: `app`, `server`, `observability`, `log`, `database`, `databases`,
`keystore`, `messaging`, `source`, `multitenant` (and their documented children).
Any key **outside** that set is application config and MUST be nested under the
**`custom:`** object — that is the namespace go-bricks reserves for service-specific
values and exposes via `config:"custom.xxx.yyy"` struct tags / `InjectInto`.

A service-specific block placed at the config **root** (a sibling of `server:` /
`database:`) is a finding: it is not a value go-bricks maps, so it either fails to
bind or silently relies on a non-standard read path, and it pollutes the namespace
go-bricks controls (a future framework key could collide with it).

**Rule of thumb**: *"is this a value go-bricks already knows how to map?"*
- **YES** (a DB pool size, a server timeout, an observability endpoint) → it goes in
  its native section (`database:`, `server:`, `observability:`), never under `custom:`.
- **NO** (an external service URL, a downstream host/credentials, a feature flag, an
  operation id, a SQL Server Core connection) → it goes under `custom:`.

```yaml
# ❌ WRONG — service-specific block at the root, sibling of server/database
corepostilion:
  host: "${CUSTOM_COREPOSTILION_HOST}"

# ✅ CORRECT — nested under custom:, mapped via config:"custom.corepostilion.host"
custom:
  corepostilion:
    host: "${CUSTOM_COREPOSTILION_HOST}"
```

```bash
# Any new top-level key in config.yml that is NOT a go-bricks-owned section
git diff origin/main...pr-<N> -- config.yml | grep -E '^\+[a-z_]+:' \
  | grep -vE '^\+(app|server|observability|log|database|databases|keystore|messaging|source|multitenant|custom):'
# Non-empty output → an app key escaped the custom: namespace → SHOULD-FIX
```

Flag as SHOULD-FIX: *"`config.yml:<line>` — el bloque `<key>` es config de la
aplicación (go-bricks no lo mapea nativamente) y está en la raíz; debe anidarse bajo
`custom:` y consumirse con `config:\"custom.<key>...\"`."* The exception is a genuine
go-bricks-owned section — if in doubt, grep the go-bricks `config` package for the
key before flagging:
```bash
BRICKS=$(go env GOMODCACHE)/github.com/gaborage/go-bricks@$(grep go-bricks go.mod | awk '{print $2}')
grep -rn 'koanf:"<key>"\|mapstructure:"<key>"' "$BRICKS/config"/*.go
```

### 10b. Semantic version bump in config.yml (SHOULD-FIX — REQUIRED on every PR)

**Every PR MUST bump `app.version` in `config.yml` semantically**: **minor** for a
new feature (`feat`), **patch** for a fix / refactor / docs / test (`fix`, `hotfix`,
`refactor`, `docs`, `test`). Example: a `feat` takes `1.49.0` → `1.50.0`; a
`refactor` takes `1.50.0` → `1.50.1`. This is the project's mandatory version step;
the immutable build that gets promoted `main → DEV → UAT → PRD` is identified by
this version, so a PR without a bump ships the same version twice. `config.yaml`
keeps a placeholder (e.g. `v1.0.0`) and is NOT bumped — only `config.yml` carries
the live version.

```bash
# The PR MUST change app.version in config.yml
git diff origin/main...pr-<N> -- config.yml | grep -E '^\+\s*version:'
# Cross-check the base so the bump isn't stale after a rebase/merge:
git show origin/main:config.yml | grep -E '^\s*version:'
```

Flag as ❌ when:
- **No bump**: `app.version` unchanged in the PR → require a semantic bump.
- **Wrong segment**: a `feat` bumped patch instead of minor, or a `fix`/`refactor`
  bumped minor instead of patch — match the increment to the Conventional Commit type.
- **Stale increment**: the new value is not exactly one step above `origin/main`'s
  current `app.version` (common after a rebase or a main merge — the version
  conflict must resolve to `main` + 1 step, not the branch's old number).
- **Bumped the wrong file**: `config.yaml` changed instead of `config.yml`.

---

## Correctness, runtime & code smells (Phase 3 — checks 11-15)

These checks target correctness bugs and code smells that linters often miss.
Every finding MUST cite file:line and a concrete failure scenario.

**Developer-explicit findings**: When reporting bugs and should-fix items, write
them as a developer would explain to another developer in a PR comment. Include:
- The exact code that's wrong (quote the line)
- What happens at runtime (e.g., "this panics with nil pointer dereference when...")
- The fix as a concrete code diff (before → after)
- Why the fix is correct (e.g., "because `%w` preserves the error chain for `errors.Is()`")

Bad: "Error handling could be improved"
Good: "`sql_repository.go:45` — `fmt.Errorf("failed: %s", err)` loses the error
chain. Callers using `errors.Is(err, ErrNotFound)` will get `false` because `%s`
stringifies instead of wrapping. Fix: `fmt.Errorf("failed: %w", err)`"

### 11. Error handling bugs (BLOCKER)

```bash
# Ignored errors — the returned error is assigned to _ or not checked
grep -n "_ = .*\.\(Do\|Query\|Exec\|Close\|Scan\|Decode\|Unmarshal\)" <changed-files> --include="*.go" | grep -v _test.go

# Error checked but original error lost (wrapped without %w)
grep -n 'fmt\.Errorf.*[^%]"' <changed-files> --include="*.go" | grep -v "%w" | grep -v _test.go

# Shadowed err in nested scope (re-declares err with := inside an if/for that already has err)
# Manual inspection: look for `err :=` inside a block that has an outer `err`
```

Flag:
- **Swallowed errors**: `_ = rows.Close()` — an error during Close can mask data loss
- **Lost error chain**: `fmt.Errorf("failed: %s", err)` instead of `%w` — breaks `errors.Is/As`
- **Shadowed err**: inner `:=` silently discards outer err; use `=` instead
- **Nil pointer after error check**: `if err != nil { ... }` followed by using the value without checking `nil`
- **Deferred Close without error check**: `defer resp.Body.Close()` — should check or log the error

### 12. Concurrency bugs (BLOCKER)

```bash
# Goroutine leaks — goroutine started without cancellation path
grep -n "go func\|go .*(" <changed-files> --include="*.go" | grep -v _test.go

# Missing mutex for shared state
grep -n "sync\.Mutex\|sync\.RWMutex" <changed-files> --include="*.go"
```

Flag:
- **Goroutine without context**: `go func()` that doesn't receive `ctx` or a done channel
- **Shared state without sync**: struct fields accessed from multiple goroutines without mutex
- **Channel not closed**: producer goroutine that never closes the channel (consumer blocks forever)
- **Race-prone map**: concurrent `map` read/write without `sync.Mutex` or `sync.Map`

#### 12b. The bugs that actually reach production

Most production concurrency incidents are **not** data races — the race detector
already catches those. They are goroutine leaks, unbounded growth and blocked
waits. Check these explicitly:

- [ ] **Every goroutine has a termination path.** It selects on `ctx.Done()`, reads
      from a channel that is guaranteed to close, or is bounded by a `WaitGroup` the
      caller waits on. A `go func()` whose only exit is "the work finishes" leaks
      when the work never finishes
- [ ] **`select` without `default` or a timeout case** blocks forever if the
      upstream goroutine dies before sending. Either `case <-ctx.Done():` or
      `case <-time.After(d):` must be present
- [ ] **`time.Ticker` stopped**: `defer tick.Stop()` — a ticker without it leaks its
      runtime timer for the process lifetime
- [ ] **`time.Time` compared with `Equal()`**, never `==` (`==` also compares the
      monotonic reading and the location pointer, so two equal instants can differ)
- [ ] **`sync.Map` compound operations**: never `Store`/`Delete` based on a previous
      `Load` — use `LoadOrStore` / `LoadAndDelete`. The read-then-write pair is not atomic
- [ ] **`sync.RWMutex` only with a benchmark that proves it wins.** For a couple of
      short reads it is slower than `Mutex`
- [ ] **Zero-capacity channel** (`make(chan T)`) — verify the rendezvous is intentional
      and not an accidental deadlock
- [ ] **`defer` inside a loop**: the deferred call runs at function exit, not at
      iteration end — N iterations hold N resources open
- [ ] **`errgroup`**: `g.Wait()` is actually called and its error is checked; the
      group is created with `errgroup.WithContext` when siblings must cancel

#### 12c. Verifying it (Go 1.25+)

```bash
go test ./... -race                    # mandatory when the diff touches concurrency
```

- [ ] Concurrency tests use **`testing/synctest`** (stdlib since Go 1.25) rather than
      `time.Sleep` to synchronize: a bubble with a fake clock makes the test both
      deterministic and instant. A `time.Sleep` in a test is a flake with a delay fuse
- [ ] Tests use **`t.Context()`** instead of `context.Background()` — it is cancelled
      on test cleanup, so a leaked goroutine fails the test instead of outliving it
- [ ] Code under test receives its `ctx` from the caller; a function that calls
      `context.Background()` internally cannot be tested for cancellation at all

### 13. Resource leaks (BLOCKER)

```bash
# HTTP response body not closed
grep -n "\.Do(\|\.Get(\|\.Post(" <changed-files> --include="*.go" | grep -v _test.go
# Then verify each has a defer res.Body.Close() nearby

# SQL rows not closed
grep -n "\.Query\|\.QueryRow\|\.QueryContext" <changed-files> --include="*.go" | grep -v _test.go
# Then verify each has defer rows.Close()

# File handles not closed
grep -n "os\.Open\|os\.Create" <changed-files> --include="*.go" | grep -v _test.go
```

Flag:
- **Response body leak**: `http.Do()` result without `defer res.Body.Close()`
- **SQL rows leak**: `db.Query()` without `defer rows.Close()`
- **File handle leak**: `os.Open()` without `defer f.Close()`

### 14. Fail-closed validation (SHOULD-FIX)

When an operation fails (network timeout, parse failure, API error), the code
must deny/fail safely, not silently proceed with stale or empty data.

Flag:
- **Silent fallback**: catch block returns empty/default data instead of propagating the error
- **Missing validation on external response**: external API response parsed without checking status
- **Stale cache on error**: cache miss + fetch error → returns stale value without logging

### 15. Test quality (SHOULD-FIX)

Go beyond "tests exist" — verify tests are meaningful:

- [ ] **Business-scenario tests, not coverage padding**: each test pins a real business
      case (money moved / not moved, reversal applied / not, in-doubt resolved, an error
      path that changes the response) — not a test written only to lift the coverage %.
      This is the quality bar that earns tests their exclusion from the ≤400-line budget
      (Phase 1 sizing): budget-free tests must document a business contract. Flag tests
      that exist only to touch a line without asserting a meaningful outcome.
- [ ] **Regression value**: would the test FAIL if the production code it targets were removed?
- [ ] **No mock-only assertions**: test asserts on real behavior, not just that a mock was called
- [ ] **Error paths covered**: not just happy path — test what happens when the DB is down, API returns 500, input is malformed
- [ ] **No tautological assertions**: `assert.Equal(t, result, result)` or asserting the mock's return value
- [ ] **Complete mocks**: mock objects mirror the full shape of the real object, not just the fields the author expected
- [ ] **No weakened assertions**: existing assertions not removed or relaxed to make tests pass

```bash
# Check if tests were weakened — removed assertions
git diff origin/main...pr-<N> -- "*_test.go" | grep "^-.*assert\|^-.*require" | grep -v "^---"
```

Also verify **what the tests pin**. A test that only asserts "no error" documents
nothing. The valuable ones pin the *contract*: the exact wire body sent, the exact
header, the exact error code returned. When a PR adds that kind of test, say so —
it is the difference between a test and a regression guard.

### 16. Modernization — `go fix` (NIT)

Since Go 1.26 `go fix` runs the analysis framework with ~20 "modernizers" that
propose **safe, mechanical** rewrites. It is deterministic and free, so run it:

```bash
go fix -diff ./...       # non-empty diff → exit code != 0
go tool fix help         # list the registered analyzers
```

Relevant fixers: `any` (`interface{}` → `any`), `rangeint` (3-clause loop →
`for range n`), `slicescontains`, `slicessort`, `minmax`, `mapsloop`, `fmtappendf`,
`omitzero` (`omitempty` → `omitzero` on structs), `forvar` (redundant loop-var
re-declaration, obsolete since Go 1.22), plus two real correctness checks:
`hostport` (malformed `net.Dial` addresses) and `buildtag`.

Report as **NIT** — with two exceptions promoted to SHOULD-FIX:
- `hostport` or `buildtag` findings — those are bugs, not style
- `omitzero` on a struct field with `omitempty`: `omitempty` **does not omit an
  empty struct**, so the JSON contract already differs from what the author expects

Check `go.mod` first: these fixers assume the module's Go version supports the
target construct.

---

## Design depth & duplication (Phase 3b — checks 19-21)

Phases 2 and 3 catch code that is **wrong**: an injection vector, a swallowed error, a
leaked goroutine. Phase 3b catches code that compiles, passes, and is still **expensive
to own** — a decision that lives in nine places, a fact with no single source of truth,
an interface that hides nothing. These are the findings that make the *next* PR slow.

Three lenses, deliberately kept separate because the fix differs:

| Check | Lens | Question it asks |
|---|---|---|
| 19 | Deep vs. shallow modules (Ousterhout) | Does this interface reduce what the caller must know — and does this decision live in one place? |
| 20 | DRY (Hunt & Thomas) | Does this **fact** have one authoritative representation? |
| 21 | Uber Go Style Guide | Is this idiomatic, safe Go at the function/struct level? |

**They are not a hierarchy and they do not substitute for each other.** A module can be
deep and still copy a `sync.Mutex` by value (19 ✅ / 21 ❌). A module can have zero
duplicated lines and still leak one decision into eleven sites (20 ✅ / 19 ❌). Report a
finding under the lens that names its actual cause, once — never the same finding three
times under three vocabularies.

**Evidence rule (inherited from check 18, non-negotiable here).** Phase 3b is the easiest
phase in this skill to fill with taste. A design finding without a **count** is an
opinion:

- 19 needs the **number of sites** that re-decide the thing, and the **number of distinct
  authorities** among them.
- 20 needs the **cost already paid** — a fix that landed twice, two counters that don't
  match, a module that silently skipped the block.
- 21 needs `file:line` and the concrete runtime consequence.

No count, no finding. And per the Should-fix rule, every Phase 3b item carries a concrete
proposal: **which file/module should own it**, not "consider consolidating".

---

### 19. Module depth & information leakage (SHOULD-FIX)

A module is **deep** when its interface is small relative to the complexity it hides —
Unix `open`/`read`/`write`/`close` over tens of thousands of lines of kernel. It is
**shallow** when the interface is nearly as tall as the implementation: the caller must
understand almost as much to *use* it as to *rewrite* it. Depth is measured against the
caller's cognitive load, not against how much the author wrote.

#### 19.0 Procedure — name the decision, then count its homes (MANDATORY)

For each concern the diff touches, run this loop. It is cheap and it is what separates a
finding from a vibe:

1. **Name the decision in one question.** "What HTTP status does this business code map
   to?" · "Did the money move?" · "Is this customer's card eligible?" · "What must every
   module initialize?"
2. **Grep for its authorities** — the symbols that answer it:
   ```bash
   # every symbol that decides the thing, across the repo (not just the diff)
   grep -rn "HTTPStatusFromRC\|appErr\.Code\|http\.Status[A-Z]" --include='*.go' internal/ \
     | grep -v _test.go
   ```
3. **Count**: how many **sites** answer it, and how many **distinct authorities** they
   use. One site → fine. N sites, one authority → acceptable duplication of a *call*.
   **N sites, 2+ authorities → leak**: nothing enforces which one wins.
4. **Ask the deletion test**: if this helper vanished, would a caller have to re-derive
   the decision, or just re-type a call? Re-derive → the module was load-bearing and
   should be one funnel. Re-type → it is a shallow helper, and consolidating it buys
   little (do not report).
5. **Name the destination** — the package/file that should own it (`internal/plataform/`,
   a new module, an existing deep function). No destination → not ready to emit.

#### 19a. Leaked decision — one question answered at N sites (SHOULD-FIX, strong)

The load-bearing form of this check. **Information leakage** is one design decision spread
across modules that should be independent, so a single conceptual change forces N edits.
Note the trap: there may be **no duplicated block a linter would catch** — the duplication
is of *decision*, re-spelled slightly differently at each site.

Flag when **all three** hold:

- [ ] The same question is answered at **≥3 sites**, and at least **2 distinct
      authorities** exist for it (e.g. a mapper function at one site, a hardcoded literal
      at another, a struct field at a third)
- [ ] Changing the rule once requires touching every site — and there is git evidence it
      already had to (see 20d)
- [ ] A destination exists that could own the whole sequence end-to-end and return a
      finished result

Highest-yield shapes to look for in a go-bricks service:

```bash
# 1. The response tail: is it assembled per-handler, or owned by one funnel?
grep -rn "NewResult\|ctx.JSON\|c.JSON" --include='*.go' internal/modules/*/handlers/ \
  internal/modules/*/middleware/ | wc -l
# Count DISTINCT exit conventions — 2+ (Result and ctx.JSON) means middlewares bypass
# whatever the handlers agreed on.

# 2. Error rendering: how many functions turn an error into a response body?
grep -rn "func.*Error.*Response\|func Write.*Error\|func.*ErrorResponse" \
  --include='*.go' internal/ | grep -v _test.go

# 3. Business-code construction outside the layer that owns business rules
grep -rn "SuccessCode\|Code:.*bussines\.\|Message:.*bussines\." \
  --include='*.go' internal/modules/*/repository/
# A repository building business rc/message = the persistence layer deciding business
# outcome. Leak, and a layer-boundary smell (check 2) at the same time.
```

**How to phrase it.** Not "this is duplicated" (that is check 20) but: *"the decision
`X` has N homes and M authorities; the rule cannot be changed in one place"*. The fix is
never "extract a helper" — it is **one module that owns the sequence and returns the
finished thing**, so the caller's job shrinks to one line of business plus one return.

#### 19b. Shallow interface & pass-through parameters (SHOULD-FIX)

A parameter, field or method that is only **forwarded** — it never decides anything at the
level that declares it — makes its module shallower than it looks: the interface grew to
serve another layer's needs, not its own.

**The nil-in-tests test — the single most decisive heuristic in this check.** A seam that
exists for substitutability but is never substituted is not a seam; it is a tax every
reader pays. Quantify it:

```bash
# Pick the suspicious param type (e.g. httpclient.Client, a *sql.DB, a logger passed per call)
T='httpclient.Client'
grep -rn "$T" --include='*.go' internal/ | grep -v _test.go | wc -l   # non-test mentions
grep -rn "$T" --include='*.go' internal/ | grep -c "func "            # signatures carrying it
# Real constructions of the thing (adapters that could differ):
grep -rn "$T *=\|New.*$T\|$T{" --include='*.go' internal/ | grep -v _test.go
# Call sites that pass nil for it (tests that never exercise the seam):
grep -rn ", *nil)" --include='*_test.go' internal/ | wc -l
```

Verdict table:

| Non-test mentions | Real implementations | `nil` at call sites | Verdict |
|---:|---:|---:|---|
| many | **1** | many | **Hypothetical seam** → SHOULD-FIX: adapter owns it at construction |
| many | 2+ (prod + mock, both exercised) | few | Real seam → leave alone |
| few | 1 | 0 | Not worth a finding |

Also flag:

- [ ] **Threaded through ≥3 call levels** without any level inspecting it (handler holds
      it only to forward to service, service only to forward to client)
- [ ] A **string parameter nobody validates** on the way down (`authHeader string` passed
      four levels and never parsed) — either the adapter owns it or a type should
- [ ] **Transport policy inside a business service** — a service formatting HTTP headers,
      picking hosts, or building correlation IDs. That belongs to the adapter that owns
      the transport detail. This is also the DIP violation: the high-level module depends
      on the concrete client instead of a domain abstraction it defines
- [ ] **Two conventions coexisting in one repo** for the same thing (one service holds the
      client as a field, another takes it as a per-call param). Report the *inconsistency*
      and name which convention wins — the repo already voted with the majority
- [ ] **Interface height vs implementation depth**: an interface whose parameter list
      encodes wiring rather than intent, over an implementation of many hundreds of lines.
      Shrinking it is not a move, it is a **deletion**: name the count of arguments and
      mentions that disappear

**Conflict rule.** If a project `CLAUDE.md`, ADR, or migration checklist *mandates* the
pass-through (some parity-driven checklists do), **do not report it as a defect**. Report
it as a documented friction: cite the rule, cite the counter-evidence (the nil count, the
majority convention), and recommend reopening the rule. Never silently review against a
rule the repo does not have — and never silently against the repo's own rule either.

#### 19c. Temporal decomposition — split by *when*, not by *what*

The usual root cause behind 19a. Modules carved along the runtime timeline ("first
validate, then encrypt, then observe, then write") instead of along the knowledge each
piece owns. Each step becomes a mini-helper, and because the *sequence* is what actually
carries the knowledge, every entry point replays it.

Symptom to grep for — the same ordered call chain appearing at many sites:

```bash
# Take the 3-4 call sequence you saw in one handler and count how many places replay it
grep -rn -A4 "ValidateError(" --include='*.go' internal/modules/*/handlers/ \
  | grep -c "EncryptedResponse"
```

- [ ] ≥3 sites replay the same ordered sequence of ≥3 calls → the sequence, not its steps,
      is the module. Propose one entry point that runs it internally
- [ ] Helper names that describe **phases** (`validate*`, `prepare*`, `finalize*`,
      `postProcess*`) rather than knowledge, each called in fixed order by every caller

#### 19d. Fused concerns — one switch turns off two things

A specific, high-yield leak: two independent concerns welded into one function, so a
module that legitimately opts out of concern A silently loses concern B.

```bash
# Is observability reachable only through some other concern?
grep -rn "func observe\|func.*Metric\|func.*Telemetry" --include='*.go' internal/plataform/
# For each, find its callers — if there is exactly ONE and it is an unrelated concern
# (encryption, serialization, auth), the concerns are fused.
grep -rn "observeResponse\|recordMetric" --include='*.go' internal/ | grep -v _test.go
```

- [ ] A cross-cutting concern (metric, span, audit log) reachable **only** through an
      unrelated one (encryption, caching, serialization)
- [ ] Any module that skips the wrapper therefore skips the cross-cutting concern — and
      **nothing fails** when it does. Name the endpoints currently flying blind
- [ ] A primitive speaking a vocabulary from a layer above it (a crypto helper minting
      *business* error codes, a repository minting business messages). The primitive
      should return its own typed failure; the layer that owns the vocabulary translates

#### 19e. When NOT to report (read before emitting anything from 19)

Deleting a seam is cheap to propose and expensive to be wrong about. Do **not** report:

- **A module that is already deep** — small interface, large hidden implementation, even
  if the implementation is long. Length is not shallowness. A 3-method interface over
  1800 well-factored lines is the *goal*
- **A seam with two genuinely exercised adapters** (prod + mock, or two vendors) — that is
  ports & adapters working as intended
- **Variation mandated by legacy parity** — when the same semantic condition legitimately
  yields different codes per endpoint because a Java contract says so, that variation must
  survive as a **parameter**. Say so: the resulting interface will not be tiny, and that
  is the honest outcome, not a failed refactor. Findings like this are **speculative** —
  mark them as such rather than dressing them up
- **Money-touching consolidation without parity verification.** If the sequence decides
  whether funds moved, reversed, or are in doubt, the finding must carry the instruction
  to verify each branch against the legacy source before moving it. Never propose a
  money-path consolidation as a mechanical refactor
- **Anything you could not count.** Went to grep, got noise, moved on → it is not a
  finding, and it is not a `(warn)` either. Silence

Confidence label is **mandatory** on every 19 finding, and it gates severity:

| Label | Meaning | Severity |
|---|---|---|
| **strong** | Sites and authorities counted; destination exists; zero business-rule change | SHOULD-FIX |
| **worth exploring** | Pattern real, benefit clear, exact shape of the fix still open | SHOULD-FIX (phrased as a proposal to validate) |
| **speculative** | Diagnosis solid, but an unresolved tension (parity variation, money path) means the fix may not shrink the interface | "Para el próximo commit" — never a Should-fix bullet |

**Seam type is the second mandatory label**, and it is not decoration: it says what kind of
work the fix actually is, which is what makes the roadmap estimate honest. Confidence says
*how sure*; seam type says *what shape*.

| Seam type | What it means | Shape of the fix | Cost driver |
|---|---|---|---|
| **in-process** | The substitution point lives inside the same process/package; no external contract moves | Extract or consolidate code into an owner | Line count. Usually **net-negative** — the repeated block dies at every site |
| **ports & adapters** | A domain core with ports behind which adapters are swappable (prod + mock, or two vendors) | Define the port, move policy behind it, keep the adapters | Test surface. The adapters already exist — the risk is in the policy that moves |
| **local-substitutable** | The interface is already mockable but drags parameters that are not its business | **Shrink the interface** — the param does not move, it vanishes | **File count, not lines.** It touches every test that passed the param → the ≤10-file cap is what splits the phase, not the ≤400-line one |

Rules that follow from the label:

- **in-process** findings are the safe default: no contract changes, so `strong` + in-process
  is the combination to schedule first
- **ports & adapters** on a money path is never mechanical — it carries the per-branch
  parity verification from 19e
- **local-substitutable** must state the file count up front. A finding that says "~60
  lines" and then touches 40 test files is a roadmap that will not survive contact

#### 19f. How to report — the depth table is MANDATORY

Any 19 finding goes into this table in the report (collapsed in `<details>`), and each row
gets a matching Should-fix bullet with its destination:

| # | Decisión / interfaz | Sitios | Autoridades | Confianza | Tipo de seam | **Dueño propuesto** |
|---|---|---:|---:|---|---|---|
| 1 | `path/file.go:73` — "¿qué status corresponde a este rc?" | 11 | 3 | strong | in-process | `internal/plataform/response.go` (funnel único) |
| 2 | `path/file.go:29` — param de transporte en la interfaz | 53 menciones / 128 `nil` | 1 impl | strong | local-substitutable | adaptador, en el constructor (~{N} archivos de test) |
| 3 | `path/file.go:460` — "¿se movió el dinero?" | 6 | 4 | worth exploring | ports & adapters | módulo de outcome, resolvers como ports |
| — | — | — | — | — | — | Sin fugas detectadas ✅ |

---

### 20. DRY — one authoritative representation per fact (SHOULD-FIX)

> "Every piece of knowledge must have a single, unambiguous, authoritative representation
> within a system." — Hunt & Thomas, *The Pragmatic Programmer*

**Check 8 asks "does this already exist?"** (before you add code). **Check 20 asks "does
this fact live in exactly one place?"** (given the code that exists). And DRY is **not**
SRP: SRP asks whether a module has one reason to change; DRY asks whether a fact has one
home. A module can pass one and fail the other — keep the vocabularies apart in the report.

Two blocks of identical code can be an *acceptable* DRY violation if they encode different
facts that coincide today. Two *different-looking* blocks can violate DRY badly if both
encode the same business rule.

#### 20.0 The two flavors — the fix is not the same

| Flavor | What it is | Fix |
|---|---|---|
| **A. Duplicated code** | Same behavior written twice with cosmetic variation (names, constants) | Extract, or parameterize by a descriptor |
| **B. Duplicated data/structure with no source of truth** | Two structures — or a structure and an implicit convention — that must be hand-synced, with nothing in the build enforcing it | A **type or table that binds them**, plus one test that proves the binding. *Not* a function |

Misdiagnosing B as A is the common failure: extracting a helper over two parallel constant
lists leaves the lists — and the drift — exactly where they were.

#### 20a. Flavor A — code clones under the `dupl` radar

Clone detectors are threshold-based, and hand-copied clones tend to sit **just below** the
configured threshold. A green `dupl` run proves nothing.

```bash
# What threshold does the repo actually enforce?
grep -rn "dupl" .golangci.yml .golangci.yaml 2>/dev/null
# Re-run well below it — clones hiding under the project threshold surface immediately
dupl -threshold 40 -plumbing ./... 2>/dev/null | sort -u | head -40
```

Flag when:

- [ ] Two functions share the same **shape** (same ordered steps) and differ only in
      constants, names, or one extra participant
- [ ] Sibling pairs exist across the whole chain — `doX`/`doXVariant`,
      `registerX`/`registerXVariant`, `resolveA`/`resolveAVariant` — i.e. the clone was
      taken at the top and dragged its callees along
- [ ] Blocks that are **byte-identical modulo constants** (duplicate-detection block,
      retry/reversal window, validation preamble)
- [ ] A **variance table already exists** (a config struct, a descriptor, a map of
      per-operation values) that describes some of the variants while another variant
      hardcodes the same values inline. That descriptor is the fix — it is already written

Proposal shape for flavor A: **one execution path parameterized by a descriptor**, with
the variant-only parts (an extra participant, a different amount rule) carried as
descriptor fields. State explicitly that the public interface does not change — this is
implementation depth, not a contract change.

#### 20b. Flavor B — parallel lists with nothing enforcing the pairing

The highest-value catch in check 20, because the compiler is silent and review catches it
only by luck.

```bash
# Two flat constant lists whose only link is a naming convention
CODES=internal/plataform/bussines/codes.go
MSGS=internal/plataform/bussines/messages.go
grep -c '=' "$CODES"; grep -c '=' "$MSGS"      # unequal counts = guaranteed drift
# Comments standing in for a type the compiler could check:
grep -rn "pairs with\|va con\|corresponde a\|see also .*Code" --include='*.go' internal/
# Hand-pairing at call sites: both a code constant and a message constant on one line
grep -rn "Code[,)].*Message\|Message[,)].*Code" --include='*.go' internal/ | wc -l
# Reinvented envelope factories — the same struct literal built by private helpers per module
grep -rn "ResponseBase{\|NovoResult{\|Envelope{" --include='*.go' internal/ | grep -v _test.go | wc -l
grep -rn "func.*[Rr]esp(\|func new.*Response(" --include='*.go' internal/modules/ | grep -v _test.go
```

Flag when:

- [ ] Two lists that must stay in sync have **different lengths** and nothing validates it
- [ ] A **comment** documents the pairing (the comment is standing in for a type)
- [ ] ≥10 call sites pair the two tokens by hand
- [ ] ≥2 modules define their **own private factory** for the same envelope/struct

Proposal shape for flavor B — three parts, all required:

1. **One lookup keyed by the stable identifier** (the rc) that yields the paired value.
   Constants stay flat and immutable; only the pairing moves
2. **One constructor** in the platform package that builds the envelope
3. **One table test** asserting every key has exactly one value — this is what converts a
   review catch into a build failure

State the parity guarantee explicitly: **message text does not change**. A DRY fix that
alters a customer-visible string is not a DRY fix, it is a contract change.

#### 20c. Flavor B — copy-pasted bootstrap (the invariant half of every `Init`)

```bash
# The same literal error string in several modules = copy-pasted wiring
grep -rhon 'errors\.New("[^"]*"\|fmt\.Errorf("[^"]*"' --include='module.go' internal/modules/ \
  | sed 's/^[0-9]*://' | sort | uniq -c | sort -rn | awk '$1 > 1'
# Init size per module — an outlier that is much SHORTER is the interesting one
for f in internal/modules/*/module.go; do
  printf '%s %s\n' "$(awk '/func .*Init\(/,/^}/' "$f" | wc -l)" "$f"
done | sort -rn
```

Flag when:

- [ ] ≥3 modules repeat the same wiring block (logger tag, DB handle, key material, HTTP
      client, required-module lookups), including **identical error strings**
- [ ] One module's `Init` is conspicuously **shorter** because it skipped the block — then
      check what that omission silently cost it (usually observability; ties to 19d). *An
      omission with no failure mode is the strongest argument for a bootstrap*
- [ ] Startup ordering between modules is enforced only by **registration order** in a
      slice, with nothing asserting it. Propose a startup assertion regardless of whether
      the bootstrap lands — it is cheap and it fails loudly

The duplicated thing here is not code, it is the **decision of what every module must
initialize**. The fix is one call that returns what every module needs and **refuses to
construct a module without it**.

#### 20d. Cost evidence — prove it with git, not with taste (MANDATORY)

Before emitting any check 20 finding, produce at least one of these. This is what makes
the finding survive an author's pushback:

```bash
# Did the same fix have to land in both copies? (the killer evidence)
git log --oneline -20 -- path/to/fileA.go path/to/fileB.go
git log --oneline --all -S'<the rule that changed>' -- internal/ | head
# Are these files hot? (churn = the duplication is being paid for continuously)
git log --format=%H --since='12 months ago' -- path/to/file.go | wc -l
```

| Evidence | Strength |
|---|---|
| A fix landed twice, once per copy (ticket or commit pair) | **Strong** — quote the commits/tickets. Not style, measurable double work |
| Two counters that must match and don't (55 vs 44) | **Strong** — drift is already present |
| A module that skipped the block and lost a guarantee silently | **Strong** — the failure mode is "nothing happens" |
| High churn on both copies | Worth exploring |
| "It looks duplicated" | **Not a finding** |

#### 20e. The over-application guard — run this BEFORE reporting (MANDATORY)

> "Duplication is far cheaper than the wrong abstraction." — Sandi Metz

DRY is not a mandate. Forcing a shared abstraction onto *accidental* duplication couples
modules that should evolve apart, and the coupling is worse than the copy.

For each candidate, answer in one line each — in the report, not just in your head:

- [ ] **Same reason to change?** If the business rule changes, must **both** copies change
      together? Yes → real duplication. "Maybe" → accidental; leave it
- [ ] **Could they legitimately diverge?** Two flows that look alike today but answer to
      different owners/regulations/products will diverge. Leave them
- [ ] **Is the abstraction obvious, or invented?** If the descriptor/table/type already
      exists in the codebase (see 20a, 20b), the abstraction is discovered — low risk. If
      you had to invent a concept to make it fit, that is the wrong-abstraction zone
- [ ] **Is it small and local?** Two adjacent 5-line blocks in one file are cheaper left
      alone than parameterized

Cannot answer these affirmatively → **do not report**, or report it as
"Para el próximo commit" with the tension named. Tolerating small local duplication is a
legitimate review outcome, and saying so out loud is part of this check.

#### 20f. Keeping the vocabulary honest (SOLID cross-reference)

When the same code is visible through several lenses, report it **once**, under the lens
that names the cause, and mention the others in one clause at most. Mapping:

| Symptom | Primary check | SOLID name |
|---|---|---|
| Same decision re-decided at N sites | 19a | SRP |
| A sequence replayed by every entry point | 19c | SRP + temporal decomposition |
| Interface carrying a param almost nobody uses (`nil` in tests) | 19b | ISP |
| Business service depending on a concrete transport/infra type | 19b | DIP |
| Identical logic in two functions | 20a | *not SOLID* — DRY |
| Two lists hand-synced; copy-pasted `Init` | 20b/20c | *not SOLID* — DRY |

**Do not force the SOLID frame where it does not apply.** OCP and LSP violations are rare
in idiomatic Go review — Go has no class inheritance, and extension points are interfaces
already covered by 19b. If you did not find one, say nothing; an invented OCP finding to
round out the acronym is noise, and it costs the report its credibility.

---

### 21. Go idiom safety net (Uber Go Style Guide)

Checks 19-20 operate on modules. Check 21 operates one level down — **function, struct,
error, receiver** — on the idioms that survive a `golangci-lint` green run. Only report
what the toolchain in Phase 0 did **not** already flag; a duplicate of a linter finding is
noise.

#### 21a. Correctness & safety idioms (BLOCKER)

Real production failure modes, so they carry BLOCKER severity — each one needs the
concrete failure scenario, per check 18.

```bash
# 1. Mutex/WaitGroup/atomic copied by value — the copy protects nothing
grep -rn "func (\w* [A-Z]\w*)" --include='*.go' internal/ | grep -v '\*'   # value receivers
grep -rln "sync\.Mutex\|sync\.RWMutex\|sync\.WaitGroup" --include='*.go' internal/
# Cross-check: a type holding a mutex MUST use pointer receivers everywhere.

# 2. panic in library code — steals the caller's decision
grep -rn "panic(\|must\w*(" --include='*.go' internal/ | grep -v _test.go

# 3. os.Exit / log.Fatal outside main() — skips every defer
grep -rn "os\.Exit\|log\.Fatal" --include='*.go' internal/ cmd/ | grep -v "cmd/.*/main.go"

# 4. Mutable package-level state
grep -rn "^var [a-z]\w* *=\|^var [A-Z]\w* *=" --include='*.go' internal/ | grep -v "_test.go\|errors.New\|= \[\]\|Err"

# 5. init() with side effects — runs before any config, untestable, order-dependent
grep -rn "^func init()" --include='*.go' internal/ cmd/

# 6. Single-value type assertion — panics instead of returning an error
grep -rn "\.(\**[A-Za-z_][A-Za-z0-9_.]*)$\|:= *\w*\.(\w" --include='*.go' internal/ | grep -v ", ok\|, err\|_test.go"
```

- [ ] **Zero-value mutex is already valid** — `var mu sync.Mutex` needs no constructor; a
      `*sync.Mutex` field is a nil-deref waiting to happen
- [ ] **Slices and maps crossing a package boundary are copied** — storing a caller's
      slice, or returning an internal map, hands out a mutable reference into your state.
      Copy on the way in *and* on the way out
- [ ] **Pointers to interfaces are (almost) always wrong** — `*io.Writer`. An interface
      value is already a reference
- [ ] **Embedding a type in a public struct leaks its API** — every future method on the
      embedded type silently joins your contract. Prefer a named field
- [ ] **No `panic` for expected failures** in library/service code — return an error. A
      `Must*` constructor is acceptable only at package init of a program, never in a
      request path

#### 21b. Contract idioms (SHOULD-FIX)

```bash
# Compile-time interface satisfaction — cheap, and turns a runtime surprise into a build error
grep -rn "var _ [A-Za-z_.]* = " --include='*.go' internal/ | wc -l   # how many exist today?

# Raw ints/strings where time types belong
grep -rn "Timeout\|TTL\|Interval\|ExpiresIn\|Delay" --include='*.go' internal/ \
  | grep -E "(int|int64|string)\b" | grep -v "time\."

# Buffered channels with an arbitrary capacity
grep -rn "make(chan [^)]*, *[2-9][0-9]*)" --include='*.go' internal/

# Identifiers shadowing builtins
grep -rnE "\b(len|cap|new|copy|min|max|close|delete|append|error|string|int|any)\b *(:=|=[^=])" \
  --include='*.go' internal/ | grep -v _test.go
```

- [ ] **Error taxonomy is deliberate** — pick per how much the caller must know:
      **sentinel** (`var ErrNotFound = errors.New(...)`) when the caller branches on
      identity; **error type** (`type ValidationError struct{...}`) when the caller needs
      the *data*; **opaque** (`fmt.Errorf`) when the caller only needs "it failed".
      Exporting a type nobody type-asserts is surface for nothing; making opaque an error
      the caller must branch on forces string matching
- [ ] **Wrap with `%w`, never `%v`**, when the chain must survive `errors.Is`/`As`
      (overlaps check 11 — report once, there)
- [ ] **Naming**: sentinels `ErrFoo`/`errFoo`; error types `FooError`; error strings
      lowercase, no trailing punctuation, no "failed to" prefix (the chain already reads
      as a sentence)
- [ ] **Two-value type assertion always** — `v, ok := x.(T)`
- [ ] **`time.Time` / `time.Duration`, not raw ints** — a `timeoutSeconds int` crossing a
      boundary is a unit bug waiting for the next reader. Serialized durations use a
      string (`"30s"`) or a documented unit in the field name
- [ ] **Channel size is 0 or 1** — anything larger is a queue depth that needs a written
      justification (what backpressure does it absorb? what happens when it fills?)
- [ ] **Assert interface satisfaction at compile time** — `var _ Repository = (*repo)(nil)`
- [ ] **Receiver consistency** — a type mixing value and pointer receivers has an
      ambiguous method set; pick one, and pointer if any method mutates or the type holds a
      lock
- [ ] **Struct tags on every serialized field** — an untagged field silently changes the
      wire contract when the Go field is renamed
- [ ] **`defer` for cleanup, not manual calls at the end** — the point is not elegance:
      a manual `mu.Unlock()` / `rows.Close()` at the bottom of a function is silently
      skipped the day someone adds an early `return` above it. `defer` survives that edit
      (overlaps check 13 for the leak itself — report the leak there, the habit here)
- [ ] **`init()` — flag it, but know the accepted exception**: registering into a
      well-understood global registry (a `sql.Register` driver, an encoding codec) is
      legitimate. **Business logic, config loading or I/O in `init()` is not.** Do not
      report a driver registration as a finding
- [ ] **Intentional embedding is declared as such** — when embedding is deliberate (to
      satisfy an interface), it goes **first in the field list, separated by a blank
      line**, and is documented. Embedding buried among regular fields reads as an
      accident (pairs with the 21a rule against embedding in public structs)
- [ ] **`Printf`-style wrappers end in `f`** — `Logf(format string, args ...any)`, never
      `Log`. This is not cosmetic: `go vet`'s printf analyzer only checks verb/argument
      agreement on functions it can recognize, so the missing `f` silently disables a
      real check on every call site
- [ ] **Do not shadow builtins or the package name**

#### 21c. Style & performance idioms (NIT — batch them, never a phase of their own)

- [ ] `strconv.Itoa` over `fmt.Sprint` for simple conversions (measurably cheaper, and
      states intent)
- [ ] No repeated `string`↔`[]byte` conversion in a loop or hot path
- [ ] Preallocate capacity when the size is known: `make([]T, 0, len(src))`
- [ ] **Early return over nested blocks**; no `else` after a returning `if`
- [ ] `nil` is a valid empty slice — do not return `[]T{}` to "be safe", and check
      emptiness with `len(s) == 0`, never `s != nil`
- [ ] **Keyed struct literals** across package boundaries (positional literals break
      silently when a field is added) — overlaps 9b, report once
- [ ] Reduce variable scope; declare at first use. `:=` when the initial value makes the
      type obvious; `var` with an explicit type when it is the zero value or the type is
      not evident
- [ ] Raw string literals (backticks) instead of repeated `\"` — regexes, SQL, Windows
      paths
- [ ] `&T{Field: v}` over `new(T)` followed by field-by-field assignment
- [ ] **`nil` slice vs `[]T{}` matters in exactly one place: serialization.** JSON renders
      `nil` as `null` and `[]T{}` as `[]`. Everywhere else they behave identically — so
      never "defensively" convert, but **do** check which one the API contract promises
      when the slice is serialized. A response that flips `[]` → `null` is a contract
      break, not a style nit
- [ ] Unexported package-level vars carry the `_` prefix (`_defaultTimeout`) so the wider
      scope is visible at the use site; package-level vars declare an explicit type when
      the initial value does not make it obvious
- [ ] Methods ordered logically — constructor first, then exported methods roughly in call
      order, unexported helpers near their caller. **Not alphabetical**, which scatters
      related methods
- [ ] A format string reused at several call sites is extracted to a named constant
- [ ] Group similar declarations; import groups ordered (stdlib / external / internal);
      import aliases consistent with the rest of the repo (**one alias per package
      repo-wide** — the same type imported under several aliases makes every future grep
      unreliable; see 9.5)
- [ ] Table-driven tests for multi-case logic; **functional options** for constructors
      with several optional parameters instead of a growing positional list

Anything in 21c that `gofmt`, `golangci-lint` or `go fix` already reports belongs to
Phase 0, not here. Emit only the residue.

---

### Phase 3b gate — applies to BOTH `review` and `scan` (MANDATORY)

Phase 3b is **not optional and not "if there is time"**. It runs on every `review` and
every `scan`, and each of its rows appears in the summary table with a ternary verdict.
The asymmetry to respect: **finding nothing is a valid, expected outcome — not running the
check is not.**

The three ways this phase fails, and what each looks like:

| Failure | What it looks like | Correct behavior |
|---|---|---|
| **Skipped** | The Phase 3b rows are missing from the summary table, or filled with ✅ without a count | Every row is ✅ / ❌ / ⚠️. ✅ means *checked and clean*, and for 19 it carries the counts you measured |
| **Faked** | "Consider consolidating", "this looks duplicated", "the interface is odd" | No count, no owner → **not emitted**. Silence beats a vague finding |
| **Over-fired** | Every similarity reported as a DRY violation; every long file as a shallow module | 20e guard answered in writing; 19e exclusions honored |

**Strictness, stated as rules — these are not suggestions:**

1. **No count, no finding.** 19 needs sites **and** authorities. 20 needs cost evidence
   from git or two counters that disagree. 21 needs `file:line` plus the runtime
   consequence. A Phase 3b bullet without its number is malformed output.
2. **No proposed owner, no finding.** "Where should this live?" must be answered with a
   package/file that exists or that you name explicitly. Same standard already enforced
   for naming (check 9) and placement (checks 8b/8c).
3. **Both labels or it does not ship.** Every check-19 finding carries **confidence**
   (strong / worth exploring / speculative) **and** **seam type** (in-process / ports &
   adapters / local-substitutable). Confidence gates severity; seam type gates the
   estimate.
4. **`speculative` never becomes a Should-fix.** It goes to "Para el próximo commit" with
   the unresolved tension written out, or it is dropped.
5. **19 and 20 never block a PR.** Only 21a can be a blocker, and only with a concrete
   failure scenario. A pre-existing leak the author merely touched is framed as
   *"this PR adds site N+1"* — never as a reason to reject.
6. **The 20e guard is answered in writing.** The report states what duplication was
   deliberately tolerated and why. A Phase 3b section that proposes consolidating
   everything it saw is a failed review, not a thorough one.
7. **Report once.** The same defect seen through three lenses is one finding, under the
   lens that names its cause (see 20f). Do not pad the report by restating it as SRP, then
   DRY, then shallow-module.
8. **Money-path findings carry the parity instruction** or they are deferred. Never
   propose consolidating a flow that decides whether funds moved as if it were mechanical.

**Rule provenance — keep this honest.** Check 19 comes from Ousterhout's *A Philosophy of
Software Design*; check 20 from Hunt & Thomas plus the Metz guard; check 21 from the Uber
Go Style Guide (§2 guidelines → 21a/21b, §3 performance and §4 style → 21c, §5 patterns →
table-driven tests and functional options). When one of those sources is revised and a
rule here stops matching it, **update the rule** — do not let this phase drift into
folklore, same standard as the References section.

---

## go-bricks discovery (Phase 4 — SHOULD-FIX)

Phase 2 (checks 1-10) catches anti-patterns. Phase 4 actively explores what
go-bricks offers that the PR could leverage. The goal is to maximize the
framework's value — not to block, but to suggest better implementations.

### How to discover

**Step 1 — Identify what the PR is doing** (from the diff):
- Adding HTTP calls? → explore `httpclient` package
- Adding DB queries? → explore `database` package
- Adding error responses? → explore `server` error types
- Adding config? → explore `config` injection
- Adding tests? → explore `mocks`, `fixtures`, `testutil`
- Adding middleware? → explore `server` middleware
- Adding crypto/JWE? → explore `cryptoutil`

**Step 2 — Read go-bricks source for that area**:
```bash
# Find go-bricks module cache path
BRICKS=$(go env GOMODCACHE)/github.com/gaborage/go-bricks@$(grep go-bricks go.mod | awk '{print $2}')

# List all exported types/functions in a package
grep -rn "^func \|^type " $BRICKS/<package>/*.go | grep -v _test.go

# Example: what does httpclient offer?
grep -rn "^func \|^type " $BRICKS/httpclient/*.go | grep -v _test.go

# Example: what error types does server provide?
grep -rn "^func New.*Error\|^type .*Error" $BRICKS/server/*.go | grep -v _test.go

# Example: what test helpers exist?
grep -rn "^func \|^type " $BRICKS/mocks/*.go
grep -rn "^func \|^type " $BRICKS/fixtures/*.go
```

**Step 3 — Compare with what the PR implements**:

For each piece of custom code in the PR, ask:
- Does go-bricks already have a function/type that does this?
- Does go-bricks have a pattern for this that's different from what the PR does?
- Is the PR using a go-bricks type but missing features it offers? (e.g. using
  `httpclient.Client` but not its retry config, or using `database.Interface`
  but not its transaction helpers)

### What to look for (common missed go-bricks features)

| Code is doing... | go-bricks offers... | Where to check |
|-------------------|---------------------|----------------|
| Custom HTTP error wrapping | `httpclient.IsErrorType`, `httpclient.HTTPError`, `httpclient.NetworkError` | `$BRICKS/httpclient/errors.go` |
| Manual retry loops | `httpclient` built-in retry with `MaxRetries` config | `$BRICKS/httpclient/config.go` |
| Custom request building | `httpclient.Request` with Headers, Body, URL | `$BRICKS/httpclient/types.go` |
| Manual JSON response | `server.NewResult`, `server.NewErrorResult` | `$BRICKS/server/result.go` |
| Custom error codes | `server.NewBadRequestError`, `server.NewNotFoundError`, etc. | `$BRICKS/server/errors.go` |
| Manual DB transaction | `database.Interface.Begin()`, `tx.Commit()`, `tx.Rollback()` | `$BRICKS/database/` |
| Custom test DB setup | `mocks.MockDatabase`, `mocks.MockTx`, `fixtures.NewMockRows` | `$BRICKS/mocks/`, `$BRICKS/fixtures/` |
| Manual config reading | `config.InjectInto` with struct tags | `$BRICKS/config/` |
| Custom logging setup | `logger.New`, `logger.Logger` interface | `$BRICKS/logger/` |
| Manual context propagation | go-bricks `httpclient.Do` auto-propagates context | `$BRICKS/httpclient/client.go` |
| Custom health check | `server.HealthCheck` handler | `$BRICKS/server/health.go` |
| Custom middleware | `server.Middleware` interface | `$BRICKS/server/middleware.go` |
| Raw SQL JOIN as const | `InnerJoinOn()`, `LeftJoinOn()` + `JoinFilter` (`jf.EqColumn()`, `jf.Eq()`) | `$BRICKS/database/types/interfaces.go` |
| Raw SQL WHERE with complex conditions | `f.Raw(condition, args...)` with parameterized values | `$BRICKS/database/internal/builder/filter.go` |
| Raw SQL expressions (COUNT, TO_CHAR, CASE) | `qb.Expr(sql, alias)`, `qb.MustExpr(sql, alias)` | `$BRICKS/database/types/expression.go` |
| Raw SQL subquery in WHERE | `f.Exists(subquery)`, `f.InSubquery(col, subquery)` | `$BRICKS/database/types/interfaces.go` |
| Raw SQL table alias | `dbtypes.MustTable(name).MustAs("alias")` | `$BRICKS/database/types/` |

### Reporting go-bricks discovery findings

Use tag `[go-bricks-oportunidad]` (ES) / `[go-bricks-opportunity]` (EN):

> `[go-bricks-oportunidad]` El PR implementa retry manual con `for` loop en
> `client.go:45` — go-bricks `httpclient` ya tiene retry built-in configurable
> vía `MaxRetries`. Usar la configuración nativa simplifica el código y garantiza
> backoff exponencial.

These are **SHOULD-FIX**, not blockers — the code works, but it's not using
the framework's full potential. Exception: if the custom implementation has a
bug that go-bricks' version doesn't (e.g. missing backoff, no jitter), elevate
to **BLOCKER** because the fix is "use go-bricks".

### go-bricks version check (MANDATORY at start)

Before any review, verify go-bricks is on the latest version:
```bash
# Current version in the project
grep 'go-bricks' go.mod

# Latest available (check go proxy)
GOPROXY=https://proxy.golang.org go list -m -versions github.com/gaborage/go-bricks 2>/dev/null | awk '{print $NF}'
```

If the project is behind, note it as a **improvement comment** (not a blocker,
not a should-fix). Include it in the "Comentarios de mejora" section of the report
as context for a future upgrade — never block the PR for a version bump alone.

---

## Scope & evidence verification (Phase 5 — checks 17-18)

### 17. Scope containment (SHOULD-FIX)

Verify the PR touches only one logical scope. A PR that mixes concerns is
harder to review, test, and revert.

```bash
# List all modules touched by the PR
git diff origin/main...pr-<N> --stat | grep "internal/modules/" | sed 's|internal/modules/\([^/]*\)/.*|\1|' | sort -u

# List all layers touched per module
git diff origin/main...pr-<N> --stat | grep "internal/modules/" | sed 's|internal/modules/[^/]*/\([^/]*\)/.*|\1|' | sort -u
```

Flag:
- **Multi-module PR**: touches `accounts/` AND `cards/` without shared-infra justification
- **Multi-layer PR**: touches `domain/` AND `handlers/` in the same module (should be separate phases)
- **Unrelated changes**: config bump + new feature + test fix in one PR

Exception: changes in `internal/plataform/` (shared infra) that are consumed by the module
changes are acceptable.

### 18. Evidence-based findings (MANDATORY)

Every finding in the report MUST include:
- **Archivo/File**: exact `path/to/file.go:line`
- **Evidencia/Evidence**: the command or code snippet that proves the finding
- **Escenario de fallo/Failure scenario**: concrete inputs → wrong output/crash

A finding without evidence is speculation, not a review finding. If a check
cannot be verified (e.g. tests can't be run, file not accessible), use the
ternary verdict ⚠️ `NO VERIFICADO` instead of guessing.

### 18b. Honor the author's prior justifications (MANDATORY)

A re-review must not re-litigate a point the author already answered. Before emitting
any finding, read the PR conversation and the author's inline replies — if the author
already explained why a flagged item does not apply, and the explanation is **valid**,
do not flag it again.

**Pull the PR conversation** (do this alongside fetching the diff):

```bash
gh pr view <N> --comments 2>/dev/null                          # general comments
gh api "repos/<owner>/<repo>/pulls/<N>/comments" 2>/dev/null   # inline review threads
```

> ⚠️ On NovoPayment repos `gh` frequently lacks scope (`Could not resolve to a
> Repository`). If the conversation cannot be read, mark this check
> ⚠️ `NO VERIFICADO — no pude leer los comentarios del PR`; if the user pastes the
> author's replies, honor them. **Never assume there are no justifications.**

**Rule for each finding**:
1. Check whether the author already addressed it in a comment.
2. **Justification technically valid** (verified against Java parity / go-bricks /
   source — same discipline as every other finding) → **do NOT re-flag.** Record it as
   resolved so the author sees it was considered:
   > ✅ **Ya justificado por el autor** — `adapter.go:29`: el pool sin cota es intencional
   > para el sweep de status (explicado en el hilo). Verificado, no se re-marca.
3. **Justification wrong or incomplete** → flag again, but **engage with the author's
   argument**, never repeat the finding verbatim:
   > 🔁 **Respuesta al autor** — el dev dice que el `%s` no rompe nada, pero
   > `errors.Is(ErrNotFound)` en `service/x.go:112` sí depende del wrap. Sigue aplicando.
4. **Never rubber-stamp**: a justification is not accepted just because it exists — it is
   verified. And once a point is validly closed, never re-open it in later re-reviews.

This check never blocks a PR; it changes what gets reported. Add a row
`Justificaciones del autor honradas` to the validation table (✅ honored / ⚠️ could not
read the conversation).

### Verdict system (ternary)

Each check in the gate summary table uses three states:

| Estado | Significado |
|--------|-------------|
| ✅ | Verificado y correcto |
| ❌ | Verificado y con problemas — citar evidencia |
| ⚠️ | No se pudo verificar — explicar por qué (ej: sin acceso a tests, archivo no accesible) |

A ⚠️ is NOT a pass — it means the reviewer acknowledges a gap. The PR author
should provide evidence or the reviewer should re-check in a follow-up.

**Phase 3b severity, explicitly** — design findings must not inflate the verdict:

| Check | Max severity | Rationale |
|---|---|---|
| 19 (depth/leakage), 20 (DRY) | **SHOULD-FIX** — never a blocker | Nothing is broken at runtime; blocking a PR over a pre-existing leak the author merely touched is not this skill's job |
| 19/20 rated `speculative` | "Para el próximo commit" only | The tension is unresolved; it is a conversation, not a task |
| 21a (correctness idioms) | **BLOCKER** | A mutex copied by value or `os.Exit` in a request path is a live defect, with a concrete failure scenario |
| 21b | SHOULD-FIX | Contract risk, not a live defect |
| 21c | NIT — batched | Readability |

**Pre-existing vs. introduced.** If the diff did not create the leak or the clone but
merely adds the Nth site to it, say so and keep it SHOULD-FIX: *"this PR adds site N+1 to
an existing leak"*. That framing is what gets it fixed instead of argued about. If the diff
**created** the second site of a brand-new clone, that is the cheapest moment in its life
to fix — say that too.

---

## Reporting — Markdown output file (in a MACHINE temp dir, never the repo)

The final report MUST be written to a `.md` file so the user can open it and
copy-paste the contents into a GitHub PR comment. **The file goes in a temporary
directory ON THE MACHINE — NEVER inside the reviewed repository** (not `docs/reviews/`,
not anywhere under the repo working tree), so it can never be accidentally committed
and never pollutes the repo's git status.

Target path (in order of preference):
1. The session **scratchpad** directory if one is provided in the environment
   (e.g. `.../scratchpad/pr-{PR_NUMBER}-review.md`) — preferred.
2. Otherwise the OS temp dir: `${TMPDIR:-/tmp}/pr-{PR_NUMBER}-review.md`.

**Steps**:
1. Resolve the temp dir (scratchpad if available, else `$TMPDIR`/`/tmp`).
2. Write the full GFM report to `<tempdir>/pr-{PR_NUMBER}-review.md`.
3. **Try to open the file** for the user by running `code "<abs-path>"` (VS Code).
   Whether or not that succeeds, the agent's chat response **MUST ALWAYS include the
   open command verbatim** — `code "<abs-path>"` — plus a clickable `file://<abs-path>`
   markdown link, so the user can open it in one click even when `code` is not on PATH.
   Never leave only the bare path: the copy-paste command is mandatory in every review
   response. (If `code` isn't available, offer `open "<abs-path>"` on macOS as the
   fallback, but the `code` command stays in the message.)

**Never** write review files inside the reviewed repo, and never `git add`/commit
them. (This is distinct from PR *description* text, which is delivered inline in
chat — see the user's PR-format preference.)

The report language depends on the `LANG` parameter:

- **No `LANG` or `ES`** → Spanish (default)
- **`EN`** → English
- Other codes → use that language

All prose (headings, descriptions, issue explanations, fix suggestions, verdict)
MUST be in the target language. Code snippets, Go identifiers, file paths, and
go-bricks type names stay in English (they are code).

### The report template lives in `references/`

The full GFM template — header, the four finding sections, the rawQuery audit table, the
42-row validation table, and the naming / design tables — is in
**[`references/report-template.md`](references/report-template.md)**. Read it **when you are
ready to write the report**, not before: nothing in Phases 0-5 depends on it, and loading it
early only costs context.

There is **one** template, written in Spanish. For `LANG=EN` or any other language,
translate its labels with **[`references/report-glossary.md`](references/report-glossary.md)**
(45 label pairs) and write the prose in the target language.

Why one and not one per language: two hand-synced templates are exactly the check 20b
violation this skill reports in other people's code — parallel structures with nothing
validating that they stay in sync. It had already drifted: three edits in a single session
each had to be applied twice.

GFM rules the template obeys (they matter — the output is pasted into a PR comment):
`##` for top sections, `###` for sub-findings, `<details><summary>` to collapse the verbose
tables, task lists for actionable items, fenced blocks with a language hint, a header
separator row on every table, no raw HTML beyond `<details>`/`<summary>`/`<br>`, and a
literal `\|` for any pipe appearing inside a table cell.


## Scan workflow → `references/scan-workflow.md`

When the subcommand is **scan**, read
**[`references/scan-workflow.md`](references/scan-workflow.md)** — it carries the scan-only
steps: check out `main` first, the deep rawQuery audit, the unused go-bricks feature sweep,
the three Phase 3b tables as scan artifacts, and the phased remediation roadmap (≤400 lines
/ ≤10 files per phase, one branch per phase from `main`, P0-P4 with its sequencing rules).

A **review** never reads that file. Everything before this line applies to both subcommands.


## References

The rules in this skill are grounded in these sources — cite them when an author
pushes back on a naming or concurrency finding:

- [Google Go Style Guide — Decisions](https://google.github.io/styleguide/go/decisions) — naming, receivers, scope-proportional length, getters, initialisms (check 9)
- [Go Concurrency review checklist](https://github.com/code-review-checklists/go-concurrency) — goroutine lifecycle, `time.Ticker`, `sync.Map`, `RWMutex` (check 12b)
- [Testing concurrent code with testing/synctest](https://go.dev/blog/synctest) — deterministic concurrency tests, stdlib since Go 1.25 (check 12c)
- [Go 1.26 release notes](https://go.dev/doc/go1.26) — `go fix` modernizers, Green Tea GC, `goroutineleak` pprof profile (check 16)
- [golangci-lint v2 docs](https://golangci-lint.run/docs/linters/) — `linters.default` replaced `enable-all`/`disable-all` (Phase 0)
- [Clean Code, cap. 2 — Meaningful Names](https://www.cs.hmc.edu/cs70/homework/homework-03/pdfs/stylemartin.pdf) — intention-revealing names, noise words, consistent lexicon (check 9.0b)
- John Ousterhout, *A Philosophy of Software Design* — deep vs. shallow modules, information leakage, temporal decomposition, pass-through methods/parameters, cognitive load (check 19). The canonical deep module is the Unix file API: 4 calls over a kernel
- Andy Hunt & Dave Thomas, *The Pragmatic Programmer* (1999) — "every piece of knowledge must have a single, unambiguous, authoritative representation within a system" (check 20)
- Sandi Metz, ["The Wrong Abstraction"](https://sandimetz.com/blog/2016/1/20/the-wrong-abstraction) — "duplication is far cheaper than the wrong abstraction" (check 20e, the guard that keeps check 20 from over-firing)
- [Uber Go Style Guide](https://github.com/uber-go/guide/blob/master/style.md) — guidelines (correctness/safety), performance, style, patterns (check 21)
- Robert C. Martin — SOLID. Used in this skill only as **vocabulary mapping** (check 20f), never as a checklist of its own: SRP ≈ 19a/19c, ISP ≈ 19b, DIP ≈ 19b. OCP and LSP rarely produce real findings in idiomatic Go — do not invent them
- go-bricks `messaging` / `outbox` / `inbox` packages — `Declarations.Validate()`, `ConsumerDeclaration`, `EventIDFromHeaders`, `Inbox.ProcessOnce` (check 6b). Read them in `$(go env GOMODCACHE)/github.com/gaborage/go-bricks@<ver>/`
- NKH1 `common:pr-review` — sizing, title, coverage floor, promotion gates (Phase 1)
- `novo-legacy-migration-endpoint` (`/migrate`) — phase caps (≤400 líneas / ≤10 files), branch-per-phase from `main`, version bump per phase (scan Step 6)

**Keep this list honest**: when a rule here stops matching the linked source
(a Go release changes a default, the style guide is revised), update the rule —
do not let the skill drift into folklore.
