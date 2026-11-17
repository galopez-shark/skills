# STEP 1 — Present Phase Roadmap (MANDATORY — show BEFORE any code)

> Shared construction rules, loaded on demand by `novo-legacy-migration-endpoint` and `novo-go-build`.
> Binding exactly as if they were inline. Where the text says Java, parity or `EST-NN`, see "Reading these rules" in `SKILL.md`.

### Phase limits (HARD RULES — ENFORCED AT ALL TIMES)

- Max **400 new lines** and **10 files** per phase (implementation + tests combined) —
  **measured against the branch's base**, not against `main` (see the Phase END line count)
- **One branch per phase, one phase per PR.** The base is `main` in serial mode and the
  previous phase's branch when stacked — what is forbidden is *two concerns in one branch*,
  not branching off a phase
- Each phase bumps version in the versioning file
- If a phase exceeds limits → **split it into more phases**

**Stacking does not raise the cap — it makes it cheaper to respect.** The whole point is that
a 1200-line change becomes three 400-line PRs reviewed in parallel instead of one unreviewable
PR or three serialized waits. A stack of oversized PRs is three review problems, not one
solved.

**These limits are enforced DURING implementation, not just during planning.** If while writing code you realize the current phase will exceed 400 lines or 10 files:

1. **STOP immediately** — do not keep writing hoping it will fit
2. **Count current lines**: `git diff --stat` or `wc -l` on new/modified files
3. **Announce the split** to the user:
   > ⚠️ Esta fase va a superar las 400 líneas (~{N} estimadas). Propongo dividirla:
   > - Fase {N}a: {what stays in this branch} (~{X} líneas)
   > - Fase {N}b: {what moves to a new branch} (~{Y} líneas)
4. **Finish only what fits** in the current branch (≤ 400 lines)
5. **Run `make check`** and present the PR for what you have
6. **The rest goes in the next branch** — after this one merges (serial), or stacked directly
   on top of it with `gh stack add` (stacked, no wait)

**Monitor during implementation:**
- After writing each file, do a quick line count check
- At the halfway point of a phase, run `git diff --stat` to see where you stand
- If you're at 300+ lines and still have significant work left → split NOW, don't wait until 400

### Estimate BEFORE planning

After the source analysis, estimate the total lines and files for each layer:

```
Layer estimates:
  Domain:     ~X files, ~Y lines (DTOs, entities)
  Repository: ~X files, ~Y lines (queries, impl, tests)
  Service:    ~X files, ~Y lines (logic, tests)
  Handler:    ~X files, ~Y lines (binding, route, tests)
  Docs:       ~X files, ~Y lines (flow md, plantuml, openapi)
```

If ANY layer exceeds 400 lines or 10 files → split it. Common splits:
- `domain-repository` → `domain` + `repository` (if complex DTOs + big SQL)
- `repository` → `repository-queries` + `repository-impl` (if many SQL queries)
- `service` → `service-validation` + `service-logic` (if complex business rules)
- `handler` → separate phase if module registration is complex

**The number of phases is NOT fixed at 4.** It can be 3 (simple endpoint) or 7+ (complex endpoint with external calls, transactions, multiple tables). The phases depend entirely on the size estimate.

### Propose the sequencing mode with the roadmap (MANDATORY)

The roadmap is where the mode is decided, because it is the only point where the whole phase
list is visible. Present it as a recommendation with its reason, per phase, and get a yes:

> Son 5 fases. Propongo **stack** para 1-3 (domain → repository → service): se revisan en
> paralelo y no esperamos merges. La fase 4 (ruta) va **serial** porque necesita certificación
> en TEST antes de que exista la fase 5. ¿Lo hago así?

Rules for that proposal:

- **Default to stacked** when the prerequisites are met and no phase hits the "When NOT to
  stack" list. Say the expected saving in plain terms — N merge waits removed — not a
  percentage you cannot back
- **Name the serial phases and why**, one clause each. A mode chosen without a stated reason
  is a mode nobody can challenge
- **Never switch a running migration** from serial to stacked mid-flight. Finish the open
  phase, then propose the mode for what remains
- If the prerequisites fail (`gh` < 2.90.0, extension unavailable), **say so and run serial**
  rather than proposing something the user cannot execute

### Present numbered checklist

Adjust the number of phases based on the estimate:

**The roadmap MUST show the PR chain**, not just the phase list — in stacked mode the base of
each PR is the plan's most important fact, and it is what the user is approving. Mark every
phase with its mode and what it actually waits for:

```
Migration roadmap for: {endpoint_name}
Modo: STACK fases 1-3 · SERIAL fase 4 (cert TEST) y 5     ← propuesta, requiere tu OK

  main
   └─ Fase 1 — Domain                    PR → main
      Branch:  {branch_prefix}{ticket}-domain
      Delivers: DTOs, entities
      Est:     ~X archivos, ~Y líneas
      Espera:  nada — arranca ya

      └─ Fase 2 — Repository             PR → PR de fase 1
         Branch:  {branch_prefix}{ticket}-repository
         Delivers: SQL queries, repository impl + tests
         Est:     ~X archivos, ~Y líneas
         Espera:  que la fase 1 esté submitteada (NO su merge)

         └─ Fase 3 — Service             PR → PR de fase 2
            Branch:  {branch_prefix}{ticket}-service
            Delivers: Business logic, error mapping + tests
            Est:     ~X archivos, ~Y líneas
            Espera:  que la fase 2 esté submitteada (NO su merge)

  ── corte del stack ──  fase 4 arranca desde main, ya mergeado el stack

  Fase 4 — Handler / ruta                PR → main          [SERIAL]
      Branch:  {branch_prefix}{ticket}-handler
      Delivers: HTTP binding, route registration, Postman + tests
      Espera:  merge del stack 1-3.  Serial porque habilita la ruta y
               necesita certificación en TEST antes de la fase 5

  Fase 5 — Docs                          PR → main          [SERIAL]
      Branch:  {branch_prefix}{ticket}-docs
      Delivers: Flow docs, PlantUML, OpenAPI
      Espera:  certificación en TEST de la fase 4

Se ahorran 2 esperas de merge (fases 2 y 3 no bloquean).
Comandos del stack: gh stack init -b main → add ×2 → push → submit --open
```

Three things that template gets right and a plain phase list does not:

- **Every phase says what it waits for**, and in stacked mode that is *submitted*, not
  *merged*. "Blocked by Phase N merge" is the serial assumption — never print it for a
  stacked phase
- **The cut between stacked and serial is drawn explicitly**, with the reason on the first
  serial phase. A mode without a stated reason is one nobody can challenge
- **The saving is stated in merge waits removed**, a number you can back — not a percentage

PR numbers do not exist until `gh stack submit` runs, so the roadmap shows the **chain**
(`PR → PR de fase N`). Replace those with real numbers (`PR #124 → #123`) in the progress
display once submitted, and keep `gh stack view` as the source of truth.

If the user accepts an all-serial plan, drop the tree and print the flat list with
`Espera: merge de la fase N` on each.

For a simple endpoint (few DTOs, one query, no external calls), phases can be combined:

```
Phase 1 — Domain + Repository  (combined — fits in 400 lines)
Phase 2 — Service
Phase 3 — Handler
Phase 4 — Docs
```

### Determine endpoint type

- **Plain body**: Handler first param = service request struct with `param:`/`query:` tags
- **Encrypted (JWE)**: Flat binding struct with `param:` + `json:"data"`, httpClient in Handler or service depending on module type

### go-bricks components for this endpoint

List which go-bricks components will be used in each phase:

```
go-bricks usage plan:
  Phase 1 (domain):     — (no go-bricks deps in domain)
  Phase 2 (repository): database.Interface, fixtures.NewMockRows, mocks.MockDatabase
  Phase 3 (service):    httpclient.Client, logger.Logger, cryptoutil (if JWE)
  Phase 4 (handler):    server.HandlerContext, server.IAPIError, app.Module
```

**WAIT for user approval of the roadmap.**

### Update endpoint status in .migration-context.yaml

After approval, update the endpoint entry:
```yaml
status: "in_progress"
current_phase: "domain"
current_branch: "feature/CEB-XXXX-domain"
ticket: "CEB-XXXX"
```
