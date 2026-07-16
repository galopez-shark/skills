---
name: novo-legacy-migration-endpoint
description: "Migrates a single legacy endpoint to Go using the context from novo-legacy-migration-context. Supports subcommands: /migrate list (all endpoints + status), /migrate status <name> (phase detail), /migrate roadmap (full migration roadmap with priorities). Uses go-bricks as the mandatory architectural foundation. Encodes 50+ battle-tested rules from real production migrations."
license: MIT
metadata:
  author: galopez-shark
  version: "4.2.0"
  domain: migration
  triggers: migration-endpoint, migrate, novo-migrate, migrar endpoint, migrate endpoint, migrate list, migrate status, migrate roadmap
  role: specialist
  scope: implementation
  output-format: code
  related-skills: novo-legacy-migration-context, golang-pro, golang-testing, openapi-spec-generation
---

# Migrate Endpoint

Migrates a single legacy endpoint to an idiomatic Go microservice. Requires `.migration-context.yaml` from `novo-legacy-migration-context`.

**Supports subcommands:**
- `/migrate` or `/migrate <endpoint>` — migrate a specific endpoint (default behavior)
- `/migrate list` — list all endpoints with migration status
- `/migrate status <endpoint>` — show phase-level detail for one endpoint
- `/migrate roadmap` — show the full migration roadmap with priorities and estimates
- `/migrate verify-parity <endpoint>` (alias `simetria`) — validate Java↔Go business-logic symmetry for one endpoint (read-only report)
- `/migrate parity-solve <endpoint> cases (<ids>)` (alias `solve-parity`) — plan fixes for the selected verify-parity divergences (≤300 new lines / ≤10 files per phase)
- `/migrate usecases <endpoint>` (alias `casos`) — extract the Java use-case / test-scenario list (testRigor-style, con IDs `EST-NN`) — QA testing del Go + base de la tabla de escenarios del Plan de Desarrollo
- `/migrate techdoc <endpoint>` (alias `doc-tecnico`) — generate the technical doc (scope, glossary, structure, construction) + class/flow/data diagrams as images (asks for the output folder)
- `/migrate help` (alias `?`) — show available subcommands, usage, and key rules

---

## Subcommand: `/migrate help` (alias `?`)

Print the help card below. Trigger when the user types `/migrate help`, `/migrate ?`, or asks
"what can this do / what commands does it have / how do I use it".

```text
migrate — migrate ONE legacy endpoint to Go (go-bricks), phase by phase.

SUBCOMMANDS
  /migrate <endpoint>          Migrate an endpoint (default). Reads Java, plans phases, executes
                               domain → repository → service → handler → docs, one branch per phase.
  /migrate list                Table of every endpoint + migration status.
  /migrate roadmap             Recommended wave order + effort estimates.
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
  /migrate help                This help (alias: ?).

REQUIRES  .migration-context.yaml — run /migration-context first to create it.

KEY RULES
  • Every phase branches from main; ≤400 new lines / ≤10 files per phase; bump version each phase.
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

Load `.migration-context.yaml` and display the endpoint inventory as a table:

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                           ENDPOINT MIGRATION STATUS                                    │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│ MODULE: accounts                                                          4/4 done ✅  │
│  #  │ Endpoint              │ HTTP │ Status     │ Phase    │ Ticket   │ Complexity     │
│  1  │ getBalance             │ GET  │ ✅ done     │ —        │ CEB-5479 │ ★★★☆☆ medium  │
│  2  │ getCardHolder          │ GET  │ ✅ done     │ —        │ CEB-5479 │ ★★★☆☆ medium  │
│  3  │ getCVV2                │ GET  │ ✅ done     │ —        │ CEB-5479 │ ★★☆☆☆ simple  │
│  4  │ preventiveBlock        │ PUT  │ ✅ done     │ —        │ CEB-5602 │ ★★★★☆ medium  │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│ MODULE: funds_transfer                                                    3/3 done ✅  │
│  5  │ cashIn                 │ POST │ ✅ done     │ —        │ CEB-5479 │ ★★★★☆ medium  │
│  6  │ cashOut                │ POST │ ✅ done     │ —        │ CEB-5479 │ ★★★★☆ medium  │
│  7  │ p2p                    │ POST │ ✅ done     │ —        │ CEB-5480 │ ★★★★★ complex │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│ MODULE: cards (new)                                                    0/6 not started │
│  8  │ cancelCard             │ PUT  │ ❌ pending  │ —        │ —        │ ★★★★☆ medium  │
│  9  │ physicalCardAssign     │ POST │ ❌ pending  │ —        │ —        │ ★★★★★ complex │
│ 10  │ setCardPin             │ POST │ ❌ pending  │ —        │ —        │ ★★★☆☆ medium  │
│ 11  │ changePin              │ PUT  │ ❌ pending  │ —        │ —        │ ★★★☆☆ medium  │
│ 12  │ cardReissue            │ POST │ ❌ pending  │ —        │ —        │ ★★★★★ complex │
│ 13  │ getCardInfo            │ GET  │ ❌ pending  │ —        │ —        │ ★★☆☆☆ simple  │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│ MODULE: enrolls (new)                                                  0/5 not started │
│ 14  │ enrollment             │ POST │ ❌ pending  │ —        │ —        │ ★★★★★ complex │
│ 15  │ enrollmentUpdate       │ PUT  │ ❌ pending  │ —        │ —        │ ★★★☆☆ medium  │
│ 16  │ enrollmentDelete       │ PUT  │ ❌ pending  │ —        │ —        │ ★★★☆☆ medium  │
│ 17  │ enrollAndIssue         │ POST │ ❌ pending  │ —        │ —        │ ★★★★★ complex │
│ 18  │ getLastCardToken       │ GET  │ ❌ pending  │ —        │ —        │ ★★☆☆☆ simple  │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│ SUMMARY                                                                                │
│ ✅ Done: 13  │ 🔄 In Progress: 0  │ ❌ Not Started: 11  │ 🚫 Blocked: 0              │
│ Est. remaining phases: ~47-62                                                          │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

**Data source**: Read `endpoint_inventory` from `.migration-context.yaml`. If the file doesn't exist, tell the user to run `/migration-context` first.

**After displaying**: Ask if the user wants to:
1. Start migrating a specific endpoint
2. Update the status of any endpoint
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

## Subcommand: `/migrate verify-parity <endpoint>` (alias `simetria`)

Validates the **business-logic symmetry** between the Java legacy source and the Go
implementation for ONE endpoint. **READ-ONLY** — it never edits code. It produces a
per-endpoint parity report and flags every divergence for the user to decide on; any fix
afterwards goes through the normal phase/branch flow (parity rule: flag, then wait for approval).

Accept the endpoint by name, number, or Java method name.

### Workflow

> **ALWAYS checkout main first:** `git checkout main && git pull`. Parity is validated against the
> canonical Go code merged in `main`, NEVER the current feature branch's WIP. If the working tree is
> dirty, stash or commit before switching, and restore afterwards.

1. **Load `.migration-context.yaml`** — if missing, tell the user to run `/migration-context` first.
2. **Resolve the endpoint** in `endpoint_inventory`. If `status: not_started` → there is no Go
   side to compare; tell the user and suggest `/migrate <endpoint>` instead. Stop.
3. **Locate both sides:**
   - Java: the `java_file` handler/resource + its service + dao (from `source_repos[].paths`).
   - Go: `internal/modules/<go_module>/{handlers,service,repository}`.
   - Properties files for error codes/messages (IMMUTABLE source of truth).
4. **Read Java FIRST, then Go** — never assume Go behavior; extract from the actual code.
5. **Extract the business cases from BOTH sides:**
   - Validation order (each guard + the condition that triggers it)
   - Error codes + EXACT messages, and the condition that fires each
   - Flow branches (happy path + every early return)
   - External-call handling (success / 4xx / 5xx / timeout / compensation-reversal)
   - **Response serialization parity (null/empty handling) — ALWAYS check this:** Java serializes with
     `@JsonInclude(NON_NULL/NON_EMPTY)` (omite campos null y vacíos), Go solo omite con `omitempty`.
     Revisa **cada DTO de respuesta Y sus campos heredados** (clases base Java que la respuesta
     `extends`, p.ej. `SumTotalsResult extends Transactions` — el base aporta decenas de campos).
     Marca ⚠️ cuando:
       · un campo string vacío que Go **pinta** (`"x":""`) pero Java **omite** → falta `omitempty` en Go;
       · un campo que Go omite por `omitempty` pero Java sí renderiza (p.ej. número no-null) → quitar omitempty / usar puntero;
       · un campo presente en Go que Java no envía, o viceversa.
   - Defaults and date formats

5b. **Trampas de FALSA PARIDAD (OBLIGATORIO — nunca declares `✅ match` sin descartar estas).**
   Un check que "existe" en Go NO garantiza paridad. Para CADA validación/campo, verifica en el
   código REAL (no por el nombre ni por presencia del check) y marca `⚠️` si difiere:

   1. **Formato de dato** — el mismo campo puede tener formato distinto (ej. fecha de expiración
      `yyMM` vs `MMYY`, `YYYY-MM-DD` vs epoch). Un parseo con el formato equivocado suele
      **retornar "no aplica" en silencio** y **desactivar la validación** (la tarjeta vencida pasa).
      Confirma el formato REAL de la DB/propiedad y cómo lo parsea Java vs Go.
   2. **Comparación config-driven** — Java a menudo lee un valor de properties Y **la semántica de la
      comparación importa** (ej. `isMaxAmount` compara `amount.length() > MAX_AMOUNT.length()` —
      ¡por LONGITUD de string, no por valor numérico!). Lee CÓMO compara, no solo el umbral. Si Go
      usa comparación numérica donde Java usa longitud (o viceversa) → `⚠️`. El valor debe venir por
      config/env igual que en Java, no hardcodeado.
   3. **Colapso a nivel query/SQL** — un `WHERE`/JOIN puede volver **inalcanzable** un código de error
      (ej. filtrar por `cardToken` en el WHERE elimina la fila del cliente → Go devuelve `-2023`
      "usuario no existe" en vez de `-2029` "tarjeta no registrada"). Rastrea si CADA código de error
      es realmente alcanzable con la query actual.
   4. **Obligatorio vs opcional** — un campo vacío/ausente puede dar error en Java pero un default
      silencioso en Go (ej. `cardToken` vacío → `-2029` en Java; Go tomaba la primera tarjeta activa).
      Verifica qué hace cada lado con vacío/ausente.
   5. **Alcanzabilidad / código muerto** — que Go tenga el código `-2029` en una función NO significa
      que se ejecute. **Traza el camino de principio a fin**; si una rama es inalcanzable, no es paridad.
   6. **Precedencia/orden** — reordenar/consolidar validaciones en Go es **intencional (rendimiento)** y
      NO es divergencia por sí mismo → 🟢. Lo ÚNICO que importa es el **resultado**: si para un input con
      varias violaciones el **código/mensaje que gana** sigue siendo el mismo que en Java, es paridad.
      Marca `⚠️` **solo** si el reorden cambia cuál error recibe el cliente (ej. Go devuelve `-2047`
      donde Java devolvía `-2050`); si el ganador es el mismo, no lo marques aunque el orden difiera.
   7. **Semántica del valor** — verifica la comparación real (`>`, `>=`, `<`, longitud, canónico),
      no solo que el check exista.

   Regla de oro: **ante la duda, es divergencia** — no declares paridad por inspección superficial.

6. **Build the symmetry matrix** (one row per business case). The **`#` column is the stable case
   ID** — the user references these ids later in `parity-solve`, so number every row sequentially:

   | # | Caso de negocio | Java (`Clase.metodo:línea`) | Go (`archivo.func:línea`) | Estado |
   |---|-----------------|------------------------------|----------------------------|--------|

   Estados: `✅ match` · `⚠️ divergencia` · `❌ falta en Go` · `➕ extra en Go`

7. **Build the error-code parity table** (messages are immutable → any text diff is `⚠️`):

   | Código | Mensaje | Condición Java | Condición Go | Estado |
   |--------|---------|----------------|--------------|--------|

8. **Build the response comparison (Java vs Go)** — for the happy path AND for each divergent
   case, show the LITERAL response body each side returns, as paired fenced JSON blocks, so the
   difference in shape, field names, nesting, values, and `rc`/`msg` is visible at a glance:

   **Caso `<nombre>` — Java (`Clase`)**
   ```json
   { "rc": "...", "msg": "...", ... }
   ```
   **Caso `<nombre>` — Go (`archivo`)**
   ```json
   { "rc": "...", "msg": "...", ... }
   ```

   Reconstruct each body from the ACTUAL code (resource/handler response builder + DTO + JSON
   tags), never from memory. Mark field-level diffs inline with a `← ...` note (e.g.
   `← Java interpola $monto$`, `← Go omite responseCard`, `← campo extra en Go`). Cover at minimum:
   the success response and one example per divergent business case.
9. **Classify each divergence:**
   - 🟢 **Mejora intencional** — Go corrige un bug de Java o mejora la estructura (anótalo, no es error)
   - 🔴 **Discrepancia de paridad** — Go diverge incorrectamente → marcar `⚠️ Discrepancia de paridad:`
     citando archivo:línea en ambos lados
   - ⚪ **Caso faltante** — un caso/código de Java no migrado a Go
10. **Veredicto final:** resumen `N match / M divergencias` por categoría. **Lista explícitamente
    los IDs (`#`) de los casos divergentes** (`⚠️`/`🔴`/`⚪`) agrupados por categoría, y cierra
    invitando a corregirlos:

    > Para preparar los fixes de paridad: `/migrate parity-solve {endpoint} cases (<ids>)`
    > (ej. `cases (9,10,11)`). Roadmap con cap ≤300 líneas / ≤10 files por fase.

    **No modificar código.** El usuario decide qué IDs corregir; cada corrección entra por el flujo
    normal de fases vía `parity-solve`.

11. **Sección "Bugs Java detectados":** además de las divergencias de paridad, reporta TODOS los
    bugs encontrados al leer el fuente Java, clasificados por severidad:

    **11a. Bugs críticos** (corrupción de datos, seguridad, resultado/monto incorrecto, pérdida de dinero):

    > `⚠️ Bug Java crítico:` {qué} · severidad · impacto · ubicación (`Clase.metodo:línea`) ·
    > mitigación propuesta en Go

    Se **DECIDE con el usuario** (mitigar en Go o replicar tal cual) — no se corrige ni se replica
    en silencio.

    **11b. Bugs de respuesta** (código/mensaje incorrecto para la condición — el error llega al usuario
    con un código genérico o un mensaje que no describe el problema real). Estos son muy comunes en
    el legacy: excepciones no tipadas que caen en un `catch(Exception)` genérico produciendo `-2000`
    cuando deberían usar un código específico (ej. `-1002` para parámetro requerido, `-1003` para
    formato inválido). Por cada uno:

    > `🔶 Bug Java respuesta:` {condición que lo dispara} · código Java actual (`rc`/`msg`) ·
    > código correcto según RESPONSE_CODES · ubicación (`Clase.metodo:línea`) ·
    > estado en Go: `✅ corregido` / `❌ replica el bug` / `⚪ no migrado aún`

    Construir la tabla de bugs de respuesta:

    | # | Condición | Java (`rc` · `msg`) | Correcto (`rc` · `msg` según RESPONSE_CODES) | Go estado | Ubicación Java |
    |---|-----------|---------------------|-----------------------------------------------|-----------|----------------|

    Estos bugs NO requieren aprobación del usuario para corregir en Go — son mejoras claras de
    calidad de respuesta. Se corrigen usando los códigos de RESPONSE_CODES.properties que ya existen
    para ese tipo de error. Si Go ya los corrigió, marcar `✅ corregido`; si no, marcar `❌ replica
    el bug` y sugerir el fix como caso adicional para `parity-solve`.

    Si no hay bugs de ningún tipo, indicar "sin bugs detectados".

### Reglas

- **Falsa paridad = el peor error del análisis.** Antes de declarar `✅ match` en cualquier caso,
  corre el checklist **5b (trampas de falsa paridad)** contra el código REAL de ambos lados. Declarar
  "match" donde hay divergencia hace fugar un bug a producción; ante la mínima duda, marca `⚠️`.
- Mensajes y códigos de error son **inmutables** — se exige match exacto de texto.
- **Solo reporta** — nunca aplica cambios. Recomienda; el usuario aprueba.
- Si el endpoint no está migrado → no hay nada que comparar; sugiere `/migrate <endpoint>`.
- Una discrepancia que el reporte declare "incorrecta" debe verificarse contra el Java real antes
  de proponer fix (el hallazgo puede contradecir la paridad — leer el do-while/for de Java primero).

---

## Subcommand: `/migrate parity-solve <endpoint> cases (<ids>)` (alias `solve-parity`)

After a `verify-parity` run, plan the fixes for the **cases the user chooses** to bring to parity.
The `<ids>` are the row numbers from the verify-parity matrix (e.g. `cases (9,10,11)`). Produces a
**phased roadmap** (one branch per phase, always from `main`) under a **STRICTER limit than the
default**: **max 300 new lines and max 10 files per phase** (parity fixes must be small and surgical;
split into more phases when needed).

Usage: `/migrate parity-solve cashin cases (9,10,11)`

### Workflow

1. **Require a verify-parity matrix** for the endpoint. If none exists in this session, run
   `verify-parity` first (which checks out `main` and builds the matrix), then continue.
2. **Resolve the selected ids** against the matrix. Reject ids that are `✅ match` or `🟢 mejora
   intencional` (nothing to fix) and confirm the remaining set with the user.
3. **RE-VERIFY each selected case against the Java source FIRST** — read the real Java code /
   `RESPONSE_CODES` before planning any fix. If a case turns out to be intentional or unverifiable,
   flag it (`⚠️`) and drop it from the plan. Never fix from the report summary alone.
4. **Map each confirmed case → the Go change** needed: layer + file(s) + approx new lines
   (error code/message, validation order, missing branch like KYC, response field, etc.). Reuse
   go-bricks / existing helpers; defer to `target.reference_repo` for patterns.
5. **Group changes into phases under the cap** — **≤300 new lines AND ≤10 files per phase** (impl +
   tests). If the selected cases exceed it, split into `parity-1`, `parity-2`, … Each phase includes
   tests, `make check` (0 issues, coverage ≥85%), and a version bump.
6. **Present the roadmap and WAIT for approval.** Before creating any branch, **ASK the user for the
   Jira epic/ticket** for these parity fixes. If they give an epic, **search its children for the
   ticket matching this endpoint, show the candidate, and confirm it** before branching (same as
   Phase START step 2). Then execute phase by phase: **always `git checkout main && git pull` first,
   then create** `feature/{ticket}-parity-{n}` **from `main`** — one phase merged before the next.

### Output (roadmap)

```
parity-solve: {endpoint} — cases {ids}

Confirmed for fix (verified vs Java):
  #9  {caso}   → {Go file} ({layer})   ~{X} líneas
  #11 {caso}   → {Go file(s)}          ~{Y} líneas
Dropped:
  #10 {caso}   → 🟢 intencional / no procede ({razón})

Phases (≤300 líneas · ≤10 files c/u):
  Phase parity-1  feature/{ticket}-parity-1   cases #9       ~{X} líneas, {n} files
  Phase parity-2  feature/{ticket}-parity-2   cases #11      ~{Y} líneas, {n} files
```

### Rules

- **Cap is 300 lines / 10 files per phase** — HARD, stricter than the standard 400. Split otherwise.
- **Verify each case against Java before fixing** — messages/codes are immutable, match exactly.
- **Only fix the selected cases** — never touch cases the user didn't choose.
- One branch per phase from `main`; tests + `make check` + version bump per phase; no commit without approval.

---

## Subcommand: `/migrate usecases <endpoint>` (alias `casos`)

Extracts, from the **Java source** (the spec), the full list of **use cases / test scenarios** for
the endpoint — redactados con disciplina de test-case writing — para que QA pruebe la versión Go
**y** para que sea la **BASE directa de la tabla de Pruebas Unitarias (EST-XX) del Plan de Desarrollo**
(techdoc). **READ-ONLY** — produces a test-case catalog, touches no code. Feeds the QA ticket de la
fase docs/cert y el Plan de Desarrollo.

### Principios de redacción (test-case writing)

Consolidado de las guías estándar (testRigor, Katalon, Guru99, BrowserStack, TestRail, Testmo).
Cada caso se redacta así:

- **Consistencia** — mismo formato/estructura para todos los casos.
- **Claridad + atomicidad** — pasos accionables y **un solo objetivo por caso** (nunca validar varios
  `rc` en un mismo caso; un branch → un caso). Mantener los pasos mínimos.
- **Naming accionable** — el título describe la acción y el resultado ("Recarga OK…", "amount ≤ 0 →
  rechazo"), no algo vago como "probar cashin".
- **Cobertura** — positivos **y** negativos, más edge / externo / auth / estado DB.
- **Técnicas de diseño (para enumerar edge/negativos con método, no a ojo):**
  · **Partición de equivalencia** — agrupa clases válidas/ inválidas por campo (un caso por clase).
  · **Análisis de valor límite (BVA)** — prueba los bordes: monto `0` / mínimo / **máximo y máximo±1**,
    longitud `dataMfetch` **250/251**, fechas límite, longitudes de campo.
  · **Tabla de decisión** — cuando el resultado depende de una combinación (ej. estado tarjeta ×
    estado cuenta × v1/v2): una fila por combinación relevante.
- **Datos definidos** — input y precondición explícitos y accionables (valor exacto, no "un monto malo").
- **Independiente y repetible** — cada caso corre solo (no depende del anterior) y da el **mismo
  resultado sin importar quién lo ejecute**. Documentar la **limpieza/reversión** del ambiente
  (ej. la transacción insertada, el `X-Identifier-Key` consumido) para no contaminar corridas.
- **Trazabilidad (clave para migración)** — cada caso lleva un **ID estable `EST-NN`** y su **Origen
  Java** (clase/método/branch de donde sale). Ese `EST-NN` se **reusa tal cual** en la tabla de
  Pruebas Unitarias del Plan de Desarrollo → un solo lenguaje entre QA, dev y el plan. Referencia por
  ID (no repitas un caso: apúntalo por su `EST-NN`).
- **Sin suposiciones** — derivar SOLO del código Java + `RESPONSE_CODES`; jamás inventar un caso.
- **Campos por caso** (adaptados al API): ID · título · tipo · prioridad · precondición · datos de
  entrada · pasos/reproducción · resultado esperado (`rc`·msg·HTTP·objeto) · verificación (log/BD/HTTP)
  · postcondición/limpieza (estado DB) · origen Java · **[ejecución] Resultado real · Estado (Pass/Fail)**.
  Las dos columnas de ejecución van **vacías al diseñar** y las llena QA al correr (hoja tipo Excel/Word).

### Workflow

1. **Load `.migration-context.yaml`** and resolve the endpoint.
2. **Read the Java source** (resource + service + dao) + `RESPONSE_CODES.properties` (runtime) — same
   source-of-truth as `verify-parity`. Read Java FIRST; derive scenarios ONLY from the real code, never invent.
3. **Enumerate EVERY scenario** the endpoint can produce — aplica **partición de equivalencia, BVA y
   tabla de decisión** (ver principios) para cubrir bordes y combinaciones sin dejar casos fuera:
   - **Happy path(s)** — including variants (e.g. card ACTIVE vs PB, with/without optional fields).
   - **Negative** — one per validation/error branch, with the INPUT that triggers it and the exact
     `rc`/`msg`/HTTP expected (codes from RESPONSE_CODES).
   - **Edge** — empty/missing fields, boundaries (montos min/max, rango de fechas 90d, longitudes
     dataMfetch 250), fechas invertidas, tarjeta vencida/bloqueada/cancelada, cliente inactivo,
     body no descifrable / JWE inválido.
   - **External** — fallo del servicio externo (4xx/5xx/timeout) y compensación/reverso si aplica.
   - **Estado DB** — qué queda en Oracle tras éxito vs rechazo (transacción PROCESSED/REJECTED, etc.).
   - **Auth** — token ausente/inválido/vencido (`-122`/`-102`); `switch:1` (respuesta plana) si aplica.

3b. **Precisión de mensaje y OBJETO de response (OBLIGATORIO).** Para cada caso, no basta el `rc`:
   captura **el `msg` EXACTO** (texto literal de RESPONSE_CODES, con interpolaciones resueltas —
   `$monto$`, `[param]`, espacios finales) **y la forma del objeto de response** que debe devolverse:
   qué campos aparecen, cuáles se omiten y con qué valores. Reconstrúyelo del **response builder real**
   (resource/handler + DTO + tags/`@JsonInclude`), nunca de memoria. Ten en cuenta:
   - campos que solo aparecen en éxito (ej. `transactionIdentifier`, `transactionDate`, `card`);
   - campos que Java omite (NON_NULL/NON_EMPTY) vs los que Go pinta (`omitempty` o no);
   - el objeto/estructura de éxito puede diferir del de error (rc≠0 suele traer solo `rc`/`msg`).
   Este objeto esperado es lo que QA valida byte-a-byte, así que debe ser **exacto**.

4. **Present the test-case catalog** (QA + **base del Plan de Desarrollo**):

   | EST | Caso (título) | Tipo | Prio | Precondición | Entrada (delta) | Resultado esperado (`rc` · msg · HTTP) | Verificación (log/BD/HTTP) | Origen Java | Bug legacy |
   |-----|---------------|------|------|--------------|-----------------|----------------------------------------|----------------------------|-------------|------------|

   - **EST** — ID estable correlativo `EST-01`, `EST-02`, … Es la **columna puente**: estos mismos
     IDs se copian a la tabla de Pruebas Unitarias del Plan de Desarrollo (techdoc). No renumerar.
   - **Tipos**: ✅ positivo · ❌ negativo · 🔶 edge · 🌐 externo · 🔐 auth.
   - **Prio**: 🔴 alta (flujo de dinero / seguridad) · 🟠 media · 🟡 baja.
   - **Entrada (delta)**: qué cambiar sobre el *request base* (ver 4c) para disparar el caso — valor exacto.
   - **Verificación**: cómo confirma QA — línea de log esperada, estado en Oracle (`TP`/`TR`/`TRR`),
     y/o shape del body HTTP. Es el "cómo verificar" que exige el escenario del Plan de Desarrollo.
   - **Origen Java**: clase/método/branch del que sale el caso (trazabilidad al spec).

   Esta tabla **ES** la base de la tabla `[3] Pruebas Unitarias (EST-XX)` del Plan de Desarrollo:
   el `techdoc`/plan la consume tal cual (mismo `EST-NN`, mismo alcance, misma verificación).

   **Columna "Bug legacy"** — para cada caso, verificar si Java produce una respuesta incorrecta
   (código genérico, mensaje equivocado, excepción no tipada que cae en catch genérico). Valores:
   - `—` → Java responde correctamente para este caso
   - `🔶 Java: rc X / msg "Y"` → Java produce un código/mensaje incorrecto; el "Resultado esperado"
     de la tabla ya muestra el valor CORRECTO (el que Go debe usar según RESPONSE_CODES). Agregar
     entre paréntesis si Go ya lo corrigió: `(Go ✅ corregido)` o `(Go ❌ pendiente)`.

   Ejemplo:
   ```
   | EST-05 | transactionCode vacío | ❌ | 🔴 | Token válido; sin query param `transactionCode` | Quitar `transactionCode` del path | rc: -1002 · "Error parametros requeridos: [transactionCode]" · HTTP 200 | Body `{rc,msg}` sin `data`; no inserta en ADMCONS_TRANSACTIONS | ValidationsServiceImpl.validateParams | 🔶 Java: rc -2000 / "Error General" (Go ✅ corregido) |
   ```

4b. **Objeto de response literal (OBLIGATORIO).** Además de la tabla, incluye el **body de respuesta
   exacto** (JSON) para: el/los happy path(s) y **al menos un caso de error representativo**.
   Reconstruido del código real, mostrando `rc`, `msg` literal y los campos presentes/omitidos:

   **Éxito**
   ```json
   { "rc": "0", "msg": "PROCESS OK", "transactionIdentifier": "…", "transactionDate": "…" }
   ```
   **Error (ej. -2029)**
   ```json
   { "rc": "-2029", "msg": "Error la tarjeta no esta registrada" }
   ```
   Esto le da a QA el objeto exacto a validar (shape + msg), no solo el código.

4c. **Ejemplo de REPRODUCCIÓN por caso (OBLIGATORIO).** Cada caso debe indicar **cómo dispararlo**
   con un request concreto, para que QA lo replique sin adivinar. Estructura recomendada:
   - **Request base** (una vez): método + ruta, headers requeridos con **valores válidos** (ej.
     `Authorization: Bearer <token>`, `country: Pa`, `language: es`, `channel: mobile`,
     `Content-Type/Accept: application/json`, y en v2 `X-Identifier-Key: <uuid>`), y el **payload
     descifrado** del happy path (los campos y valores que producen `rc:0`). Si el body va cifrado
     (JWE), indícalo: se envía `{"data":"<jwe>"}` cifrando ese payload.
   - **Delta por caso**: para cada caso de la tabla, di **qué cambiar** sobre el request base para
     dispararlo (ej. "`amount:"0"` → -2027", "`cardToken:""` → -2029", "reenviar el mismo
     `X-Identifier-Key` ya procesado → -2073", "usar tarjeta con `expiry` en el pasado → -2050",
     "header `language:ES` → -1003"). Debe ser accionable: valor exacto + resultado esperado.
   - Para casos que dependen de estado (tarjeta bloqueada/vencida, usuario dado de baja, cuenta
     inactiva, fondos insuficientes) indica el **dato/precondición** a preparar en la DB/ambiente.
   Regla: alguien de QA debe poder **copiar el request base + aplicar el delta** y obtener el `rc`/`msg`
   y objeto de response documentados, sin interpretar.

5. **"Consideraciones para QA"** — qué preparar/tener en cuenta: datos (cliente/tarjeta y su estado,
   montos), headers (`Authorization`, `switch`), body JWE, límites, cómo simular fallos de externos,
   idempotencia, y los datos del ambiente TEST.
6. **"Bugs legacy detectados"** — sección de resumen al final del documento con TODOS los casos donde
   Java produce una respuesta incorrecta. Tabla consolidada:

   | # caso | Condición | Java (`rc` · `msg`) | Correcto (`rc` · `msg` según RESPONSE_CODES) | Go estado |
   |--------|-----------|---------------------|-----------------------------------------------|-----------|

   Incluir una nota explicativa: "Estos bugs son condiciones donde Java produce un código/mensaje
   genérico (típicamente `-2000` por `catch(Exception)` no tipado) en lugar del código específico
   definido en RESPONSE_CODES.properties. El 'Resultado esperado' en la tabla principal ya refleja
   el valor correcto."

   Si todos los casos de la tabla tienen `—` en "Bug legacy" (Java responde correctamente en todos),
   indicar "sin bugs legacy detectados" y omitir la tabla.

### Rules

- Derive scenarios ONLY from the Java source + `RESPONSE_CODES` — do not invent cases.
- One row per distinct outcome/branch + the edge cases above. Codes/messages exact (runtime-verified).
- **Follow the test-case writing principles** (bloque de arriba): consistencia, atomicidad (un
  objetivo por caso), naming accionable, cobertura positiva+negativa, datos definidos, trazabilidad.
- **Usa técnicas de diseño para enumerar, no a ojo** — partición de equivalencia (una clase por caso),
  BVA (bordes: monto 0/mín/máx±1, dataMfetch 250/251, fechas límite) y tabla de decisión para
  combinaciones (estado tarjeta × cuenta × v1/v2). Deben quedar reflejadas en los casos edge/negativos.
- **Casos independientes, repetibles y con limpieza** — cada caso corre solo y da el mismo resultado
  sin importar quién lo ejecute; documenta la reversión de estado (transacción, `X-Identifier-Key`).
- **La tabla es exportable a hoja QA (Excel/Word)** — al entregarse a QA lleva además las columnas de
  ejecución **Resultado real** y **Estado (Pass/Fail)**, vacías en diseño y llenadas al correr.
- **`EST-NN` IDs are MANDATORY and stable** — correlativos, no se renumeran; son la columna puente
  que el Plan de Desarrollo (techdoc) reusa tal cual en su tabla `[3] Pruebas Unitarias`.
- **Origen Java + Verificación son obligatorios** por caso (trazabilidad al spec y cómo valida QA).
- **READ-ONLY** — output is for QA/test planning; no code changes, no branch.
- This is the input for the QA ticket (Definition of Done: "Ticket de QA con flujo completo + tabla de errores")
  **y la base de la tabla de escenarios del Plan de Desarrollo** — misma numeración `EST-NN`.
- **Bug legacy column is MANDATORY** — every row must have either `—` or the bug annotation. Never skip this analysis.
- **Message + response object are MANDATORY and exact** — cada caso lleva el `msg` literal (interpolaciones
  resueltas) y el objeto de response esperado (campos presentes/omitidos), reconstruido del response
  builder real. Es lo que QA valida byte-a-byte; un `msg` u objeto aproximado invalida la prueba.
- **Reproduction example is MANDATORY** — incluye un request base (headers válidos + payload descifrado
  del happy path) y, por caso, el **delta exacto** para dispararlo (valor del campo/header o
  precondición de estado). QA debe poder copiar-pegar y reproducir sin interpretar.

---

## Subcommand: `/migrate techdoc <endpoint>` (alias `doc-tecnico`)

Generates the endpoint's **technical document** (in text) + **three diagrams as images** (class, flow,
data). Reads Java + Go; READ-ONLY on the project code — it only writes the diagram/image files into
the folder the user specifies.

### Step 0 — ASK for the output folder (MANDATORY, first)

Before generating anything, **ask the user for the destination folder** where the diagram images will
be generated. Do NOT assume the path. Create the folder if it doesn't exist (`mkdir -p`).

### Text content (derived from Java spec + Go real code — never invent)

1. **Alcance** — qué hace el endpoint, ruta/método, entradas y salidas, qué cubre y qué NO (fuera de scope).
2. **Definiciones, acrónimos y abreviaturas** — glosario SOLO de lo que aplica al endpoint
   (p.ej. JWE, RC, PAN, tagPay, cardToken, SGC, KYC, PB, AppError, go-bricks, JWE/RSA, Oracle…).
3. **Estructura** — módulo y capas (`domain`/`repository`/`service`/`handlers`), archivos, dependencias,
   y qué se reutiliza (helpers/clients compartidos).
4. **Construcción** — cómo se arma con go-bricks (wiring en `module.go`, registro de rutas, config,
   cifrado), fases de migración y pruebas.

### Diagrams (generate as IMAGES in the folder)

- **Diagrama de clases** — structs/interfaces Go (Service, Handler, DTOs, repos, clients) y relaciones.
- **Diagrama de flujo** — flujo de la petición por capa (middleware → handler → service → repo/externos),
  happy path + ramas de error.
- **Diagrama de datos** — tablas Oracle involucradas + relaciones (ER) / modelo de datos.

For each, write a PlantUML source into the folder (`<endpoint>-clases.plantuml`, `-flujo.plantuml`,
`-datos.plantuml`) and **render it to an image** (PNG): use the `plantuml` CLI if available
(`plantuml -tpng <file>`), else Docker (`plantuml/plantuml`), else save the `.plantuml` and give the
user the exact render command. Confirm the generated image paths at the end.

### Rules

- **ASK for the folder FIRST, always** — create it if missing; never assume.
- Content derived from the Java source (spec) + the real Go code — do not invent.
- READ-ONLY on the project repo; the ONLY writes are the diagram/image files in the chosen folder.

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

## STEP 1 — Present Phase Roadmap (MANDATORY — show BEFORE any code)

### Phase limits (HARD RULES — ENFORCED AT ALL TIMES)

- Max **400 new lines** and **10 files** per phase (implementation + tests combined)
- **Every phase branches from `main`** — NEVER from another feature branch
- Each phase bumps version in the versioning file
- If a phase exceeds limits → **split it into more phases**

**These limits are enforced DURING implementation, not just during planning.** If while writing code you realize the current phase will exceed 400 lines or 10 files:

1. **STOP immediately** — do not keep writing hoping it will fit
2. **Count current lines**: `git diff --stat` or `wc -l` on new/modified files
3. **Announce the split** to the user:
   > ⚠️ Esta fase va a superar las 400 líneas (~{N} estimadas). Propongo dividirla:
   > - Fase {N}a: {what stays in this branch} (~{X} líneas)
   > - Fase {N}b: {what moves to a new branch} (~{Y} líneas)
4. **Finish only what fits** in the current branch (≤ 400 lines)
5. **Run `make check`** and present the PR for what you have
6. **The rest goes in the next branch** — after this one merges to main

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

### Present numbered checklist

Adjust the number of phases based on the estimate:

```
Migration roadmap for: {endpoint_name}

Phase 1 — Domain
  Branch: {branch_prefix}{ticket}-domain
  Delivers: DTOs, entities
  Est: ~X files, ~Y lines
  Status: [ ] pending

Phase 2 — Repository
  Branch: {branch_prefix}{ticket}-repository
  Delivers: SQL queries, repository impl + tests
  Est: ~X files, ~Y lines
  Status: [ ] pending (blocked by Phase 1 merge)

Phase 3 — Service
  Branch: {branch_prefix}{ticket}-service
  Delivers: Business logic, error mapping + tests
  Est: ~X files, ~Y lines
  Status: [ ] pending (blocked by Phase 2 merge)

Phase 4 — Handler
  Branch: {branch_prefix}{ticket}-handler
  Delivers: HTTP binding, route registration + tests
  Est: ~X files, ~Y lines
  Status: [ ] pending (blocked by Phase 3 merge)

Phase 5 — Docs (after TEST certification)
  Branch: {branch_prefix}{ticket}-docs
  Delivers: Flow docs, PlantUML, OpenAPI updates
  Status: [ ] pending (blocked by Phase 4 merge + TEST cert)
```

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

---

## STEP 2 — Execute Phase by Phase (SEQUENTIAL)

### CRITICAL: One phase at a time, always from main

```
Phase 1 → PR → merge to main → user confirms ✓
                                     ↓
Phase 2 → PR → merge to main → user confirms ✓
                                     ↓
  ...repeat for each phase...
                                     ↓
Phase N (docs) → PR → merge to main → done ✓
```

The number of phases varies per endpoint (3 to 7+). The rule is the same regardless:

**NEVER start the next phase until the user explicitly confirms the previous one is merged to main.**

### Phase START sequence (EVERY phase)

1. **Confirm merge**: "Is Phase N merged to main?"
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
3. `git checkout main && git pull` — **every branch ALWAYS starts from `main`** (stash/commit dirty tree first)
4. Verify go-bricks version — if outdated, update branch FIRST
5. **Create the branch:** `git checkout -b {branch_prefix}{ticket}-{phase}` — **from main** (do create it, don't skip)
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
│ Named placeholders (:param)    │ ✅/N/A │ Oracle = :name        │
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

1. **LINE COUNT CHECK** — verify the phase stays within limits:
   ```bash
   # Count new/modified lines (implementation + tests)
   git diff --stat main...HEAD
   # If total new lines > 400 or files > 10 → STOP
   # Split remaining work into a new phase BEFORE continuing
   ```
   If over 400 lines: **do NOT proceed** with make check or PR. Remove excess code, move it to a TODO for the next phase, and re-check.
2. Run test command from context (`make check`, etc.) — 0 issues. Must satisfy the NovoPayment Go
   quality gates: **staticcheck · go vet · gosec · gocyclo · ineffassign · `go test -cover`**.
3. Verify coverage — NKH1 **floor 70%** on changed code, **goal 85%**; keep per-package ~85%.
4. Bump version in versioning file
5. `grep -rn` for source-language references — 0 matches
6. `grep -rn "log.Printf\|fmt.Println"` — 0 debug logs
7. **go-bricks POST-CHECK** — verify no go-bricks type was reinvented during implementation:
   ```bash
   # Check for raw DB usage (should use database.Interface)
   grep -rn "sql.DB" internal/modules/{module}/ --include="*.go" | grep -v _test.go
   # Check for raw HTTP client (should use httpclient.Client)
   grep -rn "http.Client" internal/modules/{module}/ --include="*.go" | grep -v _test.go
   # Check for raw echo context (should use server.HandlerContext)
   grep -rn "echo.Context" internal/modules/{module}/handlers/ --include="*.go" | grep -v _test.go
   ```
   All must return **0 matches** (except legitimate uses like type assertions in tests).
8. **POSTMAN COLLECTION (handler/route phase only)** — if this phase registers the route
   (i.e. the endpoint becomes reachable), the endpoint MUST be added to the Postman
   collection in the same phase. Add a request with: method, full `/core/<module>/v1/...`
   path (path params as `{{var}}`), required headers (`Authorization`, `switch`), and a
   sample JWE/plain body where applicable. Ask the user where the collection lives if
   unknown (repo file vs Postman cloud via the Postman MCP). Skip for domain/repository/
   service/docs phases — only the phase that enables the route touches the collection.
9. Present PR text with ticket link
10. **Update roadmap** — mark phase done, show next status
11. **Update `.migration-context.yaml`** — update `current_phase` and `current_branch`
12. **WAIT for approval** before committing

### Between phases — show progress (adapt to actual phase count)

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

---

## Implementation Rules

### go-bricks First (NON-NEGOTIABLE)

Before writing ANY code in any phase:
1. Check `gobricks_mapping` in `.migration-context.yaml`
2. Cross-reference [`novopayment/mdw-welcome-project-go`](https://github.com/novopayment/mdw-welcome-project-go)
   — the canonical reference for go-bricks usage and Go architecture; follow its module/layer/wiring patterns
3. Grep go-bricks source for the types you need
4. If go-bricks has it → use it directly
5. If go-bricks doesn't have it → implement it, but follow go-bricks + welcome-project patterns

**go-bricks provides:**
- HTTP server, routing, handler context → `server.*`
- DB access, transactions → `database.Interface`, `db.Begin`
- HTTP client for external calls → `httpclient.Client`
- JWE encryption/decryption → `cryptoutil.*`
- Logging → `logger.Logger` (zerolog-based)
- Config injection → `deps.Config.InjectInto`
- Module system → `app.Module` interface
- Test helpers → `fixtures.NewMockRows`, `mocks.MockDatabase`, `mocks.MockTx`

### Parity (NON-NEGOTIABLE)

- **Java business rules ARE the spec — always respected.** Migrate the decision exactly: codes,
  messages, validation precedence, response shape. Default = replicate the Java behavior.
- Error codes and messages are **IMMUTABLE** — match source exactly
- Validation order / precedence must match source
- Response structure (field names, nesting, null behavior) must match
- **Critical bug** (data corruption, security, wrong outcome/amount, money loss) → the ONLY exception:
  **REPORT it** with `⚠️ Bug Java detectado:` (severity · impact · Java location · proposed Go
  mitigation) and **DECIDE WITH THE USER** whether to mitigate in Go or replicate as-is. Never
  silently fix, never silently replicate a critical bug. This is *parity, but for bugs*: report → decide → act.
- **Non-critical bug** → fix in Go, mention the deviation explicitly.

### Rule consolidation & performance parity (efficiency without breaking the decision)

Legacy code often **scatters and REPEATS** the same business rules across layers (resource + service
+ dao) and **re-fetches the same data multiple times** (e.g. cashin: `getUserData`, then
`isCardStatusValidation` and `isCardExpiryDateValidation` each re-query `getCardDetails` — 3 DB reads
of the same card). When migrating to Go:

- **Consolidate** repeated reads/validations into ONE efficient pass (single DB fetch, checks
  evaluated in order). Do NOT replicate the source's redundant re-queries / re-validations.
- **Preserve the business OUTCOME exactly**: the same code/message must win, in the same **order of
  precedence** (the check that fires first in the source must still fire first in Go). Parity is
  about the *decision*, not the number of round-trips.
- **Always flag the consolidation** in the STEP 0 analysis and the PR: list which source steps were
  merged and why it's outcome-equivalent (this is the "flow improvement — mention the deviation" rule).
- Net effect = **performance parity**: identical rules, fewer DB hits, no reprocessing.

In `verify-parity`, a Go consolidation of repeated source checks is **🟢 mejora intencional** (NOT a
divergence) — *as long as* the firing order and resulting code/message match. If the consolidation
changes WHICH error wins or its precedence, that IS a 🔴 divergence.

### Code Quality

| Rule | Details |
|------|---------|
| **No source-language refs in comments** | Never mention Java, Jackson, Spring, etc. Check: `grep -rn "Java\|Jackson\|parity\|Spring"` |
| **Max 7 params** | Group into struct |
| **Complexity ≤ 15** | Extract helpers |
| **Comments: WHY not WHAT** | Short + explicit; ≤100 chars/line default, exceed only when necessary, hard cap 150 |
| **Extend before add** | Same table → extend existing method |
| **Constants stay local** | Unexported if single-package use |

### Architecture

| Rule | Details |
|------|---------|
| **getDB func pattern** | Never inject raw DB |
| **SQL in queries.go** | Never inline SQL |
| **Named placeholders** | `:param` Oracle, `$N` PostgreSQL |
| **External clients in shared pkg** | Not in service/ |
| **Filtering in SQL** | Never in-memory |
| **Config in both files** | Env placeholders + local values |

### Date Handling

| Pattern | Go |
|---------|-----|
| `MM/YYYY` | Normalize, `time.Parse("01/2006", s)` |
| `YYYY-MM-DD` | `time.Parse("2006-01-02", s[:10])` |
| `dd/MM/yyyy` | `time.Parse("02/01/2006", s)` |
| Last day | `firstOfNext.AddDate(0, 0, -1)` |
| Query upper bound | `dateTo.AddDate(0, 0, 1)` |
| Echo trailing slash | Trim before parsing |
| Test assertions | `time.Date()` + `.Truncate(24h)` |

### JSON Parity

| Issue | Fix |
|-------|-----|
| `float64(0)` → `0` | Custom type with `MarshalJSON` |
| Null fields | `omitempty` tag |
| String or number field | Custom `UnmarshalJSON` |

### Compensation Pattern

When external call succeeds but DB write fails:
1. Best-effort compensation call to reverse
2. Log attempt
3. Return original error
4. Test both: compensation succeeds + fails

---

## Testing Patterns

### File structure

```
domain/        dto.go                (no tests)
repository/    sql_repository.go     → sql_repository_test.go
service/       service.go            → service_test.go + service_xxx_test.go
handlers/      handler.go            → handler_test.go
```

### Mock pattern

```go
type mockRepo struct {
    mock.Mock
    repo.Interface
}
func (m *mockRepo) Method(ctx context.Context, ...) (Result, error) {
    args := m.Called(ctx, ...)
    if v := args.Get(0); v != nil { return v.(Result), args.Error(1) }
    return nil, args.Error(1)
}
```

**Always `mock.AssertExpectations(t)` at end.**

### Repository coverage

| # | Case |
|---|------|
| 1 | getDB error |
| 2 | Query error |
| 3 | Empty rows → ErrNotFound |
| 4 | Scan error (fewer cols) |
| 5 | rows.Err() via sqlmock |
| 6 | Success 1 row |
| 7 | Success 2+ rows |

Transactional methods ADD: Begin error, Exec error, Zero rows, Commit error, Rollback mocking.

### Service coverage (table-driven)

Cover: parse errors, customer 404, customer DB error, card not found, repo 404, repo DB error, success variants.

### Handler coverage (table-driven)

Cover: success, each business error code → HTTP status, service 500, service 502.

### Lint gotchas

- `unused-parameter`: `_ *testing.T` in setup funcs
- `rowserrcheck`: `assert.NoError(t, rows.Err())` after `fixtures.NewMockRows`
- `sqlmock.Rows` has no `.Err()` — only `*sql.Rows` from `rowsFromSqlmock`

---

## Handler Patterns

### Plain body

```go
func (m *Handler) Foo(req *service.FooRequest, ctx server.HandlerContext) (interface{}, server.IAPIError) {
    resp, appErr := m.Service.Foo(ctx.Echo.Request().Context(), req)
    if apiErr := m.ValidateError(appErr); apiErr != nil { return nil, apiErr }
    return server.NewResult(HTTPStatusFromRC(resp.Rc), resp), nil
}
```

### Encrypted body (pure module)

```go
type fooReq struct {
    TagPay string `param:"tagPay" validate:"required"`
    Data   string `json:"data"    validate:"required"`
}
```
- `httpClient` in Handler — service gets it as param
- `authHeader` inline — no intermediate variable

### Encrypted body (mixed module)

- Service already has `s.httpClient` → all methods use it
- Do NOT add `client` param to service method

---

## Docs Phase (LAST — after TEST cert)

1. `{endpoint}-flow.md` — layer-by-layer, error tables, examples
2. `{endpoint}-flow.plantuml` — activity diagram, no internal bypass details
3. Update `overview.md` — endpoint table, params, model, errors
4. Update `openapi.yaml` (root) + `{module}.yaml` (module spec)
5. Bump version

---

## SDLC — NovoPayment standard (org-wide alignment)

This skill's phase flow implements NovoPayment's **SDLC Developer Quick Reference**. Keep these
org-wide rules in sync with the per-phase steps above.

### Branching
`[tipo]/[JIRA-ID]-[desc-kebab]`, **always from `main`**. Types: `feature/` (nueva funcionalidad),
`fix/` (bug), `hotfix/` (urgente en prod). Lowercase + kebab-case, description 3–5 words, JIRA-ID
mandatory. This repo's migration phases append the phase to the desc (`feature/CEB-XXXX-service`).
- ❌ `feature/login` · `gabriel/fix-bug` (no name prefix) · `Feature/PAY-456-Login` (caps) ·
  `feature/PAY-456` (no desc) · overly long descriptions
- ✅ `feature/CEB-5634-service`

### Commits & PR title
Conventional Commits: `tipo: descripción en minúsculas`. **Valid types (ONLY):**
`feat` · `fix` · `hotfix` · `docs` · `test` · `refactor` (never `chore`/`perf`).
- **Ticket goes in the BODY as `Refs: CEB-XXXX`, NEVER in the subject** (org SDLC + NKH1). The
  title is `tipo: descripción` only. Keep the subject **≤72** chars.

### PR size (reviewable in < 30 min)
- `<200` líneas = ✅ ideal · `200–400` = ⚠️ aceptable (justificar) · `>400` = ❌ dividir antes de review.
- Split by: one endpoint/feature per PR; business logic apart from infra/config; refactors in their
  own PR; tests can land in a prior PR; DB migrations independent. (Matches the ≤400/10-file phase cap.)

### Quality gates (Go) — enforced by `make check`
staticcheck · go vet · gosec · gocyclo · ineffassign · `go test -cover`. Plus **CodeRabbit** on the
PR — review & resolve every comment before requesting merge.

### Testing mix & coverage
**60% unit · 30% integration (APIs/endpoints) · 10% E2E (critical flows).** Coverage **floor 70%**,
**goal 85%**. Exceptions (no tests required): config files, simple constants/enums, generated code,
critical hotfixes (with a documented remediation plan in the PR).

### Deployment (immutable build)
`main → DEV (auto on merge) → UAT (PO approval) → PRD (Prod approval)`. Same artifact promoted across
environments; config is external and per-environment. Migration endpoints follow this after the
handler phase merges.

### Hotfix (expedited)
`hotfix/JIRA-ID-desc` from main → fix mínimo → testing acelerado en DEV → review (puede ser post-merge
en emergencia) → aprobación de Producción → deploy a PRD → post-mortem. Coverage bypass permitido con
plan de remediación documentado en el PR.

### DORA targets
Lead time `<2d` features / `<4h` hotfix · `≥2` deploys/week · change-failure `<5%` · MTTR `<1h`.

---

## PR Template

```markdown
**Title:** `feat: {description, lowercase}`
(no scope in parentheses after the type; description in lowercase — no capitals except proper
nouns/acronyms; **NO Jira ticket in the title** — it goes in the body as `Refs:` — e.g.
`feat: add getLastCardToken domain + service`)
**Keep the title ≤ 72 chars (NKH1 standard).** Put extra detail (and the ticket) in the body.
A title over 72 chars (e.g. ~120) is a nit, not a blocker — but trim scope words to fit.

**Body:**

## Jira
[{TICKET}](https://{ticket_host}/browse/{TICKET})

## Summary
- Bullet 1
- Bump version X → Y

## Test plan
- [x] N test cases
- [x] Test command passes — 0 issues, coverage X% (floor 70%, goal 85%)

Refs: {TICKET}

Generated with [Claude Code](https://claude.com/claude-code)
```

---

## Anti-Patterns

| Don't | Do |
|-------|-----|
| Invent error codes | Read properties files |
| Filter in service | Filter in SQL |
| Inline SQL | Use queries.go |
| New method for same table | Extend existing |
| `NewMockDatabase(t)` | `&mocks.MockDatabase{}` |
| `.Day()+1` in tests | `time.Date()` + `.Truncate()` |
| `param:` on service structs | Only handler binding |
| Commit without test check | Always run full check |
| PR without version bump | Bump EVERY phase |
| Debug logs in code | Remove before done |
| Skip AssertExpectations | Always at end |
| Reinvent go-bricks types | Use existing go-bricks components |
| Skip go-bricks check | ALWAYS check go-bricks FIRST |
