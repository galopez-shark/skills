# Subcommand: `/migrate migrate-ticket-plan <endpoint>` (alias `mtp`; legacy: `devplan`, `plan-dev`)

> Moved out of `SKILL.md` to save context. Everything here is binding exactly as if it were inline.

> Ask every question following the **Question protocol** in `SKILL.md` (rounds, read before asking, `pendiente` for unknowns).

Generates the **Plan de Desarrollo** (development plan) for a migration endpoint and updates the
Jira ticket description directly. (The Word/PDF document for QA is `/migrate migrate-doc-plan`.) This is the developer-facing technical document that lives in
Jira — written in developer language (Spanish), with the exact structure used by the team
(modeled after CEB-5602 blockUnblock).

Accept the endpoint by name, number, or Java method name.

### Shared plan data (single source of truth for `mtp` and `mdp`)

`migrate-ticket-plan` and `migrate-doc-plan` describe the same endpoint, so they read and write
**one** file instead of each re-deriving (and possibly contradicting) the other:
`docs/modules/<go_module>/<endpoint>.plan-data.yaml` in the Go repo — **local only, never committed
or pushed**.

**Ignore it before writing (MANDATORY):** the file must be git-ignored so it cannot reach the repo.
```bash
git check-ignore -q docs/modules/<go_module>/<endpoint>.plan-data.yaml \
  || echo 'docs/modules/**/*.plan-data.yaml' >> "$(git rev-parse --git-path info/exclude)"
git check-ignore -q docs/modules/<go_module>/<endpoint>.plan-data.yaml && echo IGNORED
```
`.git/info/exclude` is local to the checkout, so the Go repo gets no `.gitignore` diff. If the check
still fails, **do not write the file** — tell the user. If the repo's own `.gitignore` already covers
it, nothing to add. Because it is not versioned, a teammate or a fresh clone will not have it: then
`mtp`/`mdp` simply rebuild it (step 5) and ask the case questions again.

```yaml
ticket: CEB-XXXX
state: estimado            # estimado (not_started / in progress) | implementado (real, after last phase)
updated: 2026-11-05
flows:                     # parity flows from the Java origin, stable ids
  - {id: F1, step: "Sin Authorization", result: "401 / rc -102"}
dependencies:
  tables: []
  external: []
  modules: []
  config: []
cases:                     # approved by the user after /migrate usecases
  - {id: EST-01, flow: F1, decision: include}
  - {id: EST-07, flow: F4, decision: exclude, reason: "requiere stub externo"}
```

Rules: if the file exists, **reuse it** and ask only about what changed (new flows, new cases,
state); if it does not, create it after step 5 of whichever subcommand runs first. The `EST-NN`
ids are identical in the Jira DoD and the Word table. Never put PANs, tokens or credentials in it — it stays local, but it is still treated as sensitive.

### Workflow

1. **Load `.migration-context.yaml`** — if missing, tell the user to run `/migration-context` first.
2. **Resolve the endpoint** in `endpoint_inventory`. Get the ticket number. If no ticket, ask the user.
3. **ALWAYS read the migration origin (Java source) — mandatory, even if the endpoint is already
   migrated:** resource/controller + service + dao/repository + properties files. Java is the spec.
   From it extract and keep, for sections 2 and 5 (and save them in the shared plan data above): **(a) the parity flows** (every branch: auth,
   validation, business, external, DB, success — with its rc/HTTP), **(b) the dependencies**: tables
   and columns, external services/connectors, other modules or shared components reused, properties
   and config keys. Never write the plan from memory of the Go code alone.
4. **Read the Go source** if the endpoint is already migrated (`status: done` or `in_progress`) —
   `internal/modules/<go_module>/` (handlers, service, repository, domain). If `not_started`, derive
   the plan from the Java analysis + existing Go patterns in the project.
5. **Run `/migrate usecases <endpoint>` and ask the user which cases to include** (skip the questions
   already answered in the shared plan data; ask only what is new) (some cannot be
   replicated or simulated by QA — propose include/exclude with the reason, the user decides). The
   approved set feeds the DoD of section 5.
5b. **Generate the Plan de Desarrollo** following the template below (6 numbered sections) for the
   Jira description, and **write/update the shared plan data file**. The plan opens with a state
   line: `Plan de Desarrollo vN — {fecha} — Estado: ESTIMADO` (endpoint not migrated yet) or
   `Estado: IMPLEMENTADO` (real Go code, after the last phase). Re-run `mtp` and flip it to
   IMPLEMENTADO when the last phase merges, so QA never certifies against a stale plan.
6. **Present to the user** for review. Show the full document in chat.
7. **Protected Jira update** (see "Jira update" below): read the current description, show the diff of
   what will change, back it up, and only then write — after the user approves **that diff**.
   This subcommand produces **only** the Jira description.
   The Word/PDF document for QA/certificación is a different deliverable with its own subcommand:
   **`/migrate migrate-doc-plan <endpoint>`**.
8. **Print the completion checklist with evidence** — one row each: Java origin read (files), flows and
   dependencies extracted (counts), `usecases` run, cases approved by the user (included/excluded),
   shared plan data written **and confirmed ignored (`git check-ignore`)**, Jira description read + backup path, diff approved, Jira updated
   (issue key + timestamp). A row without evidence is `❌ NO EJECUTADO`, never `✅`.

### Template (6 sections — MANDATORY, in this exact order)

The generated plan MUST follow this structure. All content in **Spanish**. Derive everything from
the actual Java source + Go code — never invent.

```
## 1. Contexto / Motivación

{Qué endpoint es, en qué servicio Java vive (clase + método), qué hace funcionalmente.
Si el módulo Go ya existe, mencionarlo. Si reutiliza componentes de otros módulos, listarlos.
Mencionar si es simétrico a un endpoint ya migrado (ej. cashOut es simétrico a cashIn).
Lenguaje directo de developer — sin marketing ni user stories.}

## 2. Descripción técnica

### Ruta y método

{HTTP_METHOD} /core/{module}/v1/{path}
Authorization: Bearer <token>
Content-Type: application/json
{Si JWE: Body: {"data": "<JWE compact>"}}

### Flujo (Java parity — {JavaClass}.{javaMethod})

{Lista numerada o con bullets de CADA paso del flujo, en orden de ejecución:
- Validaciones (con el código de error que dispara cada una)
- Consultas a DB (qué tabla, qué campos)
- Llamadas a servicios externos (método HTTP, path, qué envía)
- Interpretación de respuesta externa
- Persistencia en DB (INSERT/UPDATE, dentro de transacción si aplica)
- Construcción de respuesta

Para cada paso que puede fallar, indicar: condición → rc/msg/HTTP.
Si hay mejoras de Go sobre Java (bugs corregidos), mencionarlas con "Mejora respecto a Java:".
Si hay diferencias con endpoints similares, incluir tabla comparativa.}

### Request body {(JWE-descifrado) si aplica}

| Campo | Tipo | Requerido | Valores válidos / Default |
|-------|------|-----------|--------------------------|
| {field} | {type} | {Sí/No} | {valores o default} |

### Response {(JWE-cifrado) si aplica}

```json
{response body literal — rc, msg, y campos de datos}
```

### Dependencias (del origen Java)

| Tipo | Detalle |
|------|---------|
| Tablas | {tabla.columnas leídas/escritas} |
| Servicios externos | {conector, método, path} |
| Módulos / componentes reutilizados | {CustomerReader, handler base, ...} |
| Configuración | {properties / keys de config} |

### Errores de negocio

| Condición | HTTP | rc | Mensaje |
|-----------|------|----|---------|
| {condición que dispara el error} | {HTTP status} | {rc code} | {mensaje EXACTO de RESPONSE_CODES} |

{Incluir TODOS los errores: auth (-102, -122), validación (400), negocio (4xx), externos, Oracle (500).
Ordenar por el flujo: auth → validación → negocio → externo → DB → éxito.}

## 3. Archivos creados / modificados

{Árbol de archivos del módulo Go con una descripción corta por archivo:}

internal/modules/{module}/
  domain/dto.go                    <- {qué contiene}
  domain/entity.go                 <- {qué contiene}
  handlers/handler.go              <- {qué contiene}
  handlers/handler_test.go         <- {N casos: listar los nombres}
  service/service.go               <- {qué contiene}
  service/in_out.go                <- {qué contiene}
  service/service_test.go          <- {table-driven, qué cubre}
  repository/repository.go         <- {interfaces}
  repository/sql_repository.go     <- {qué operaciones}
  repository/sql_repository_test.go <- {N casos: listar categorías}
  module.go                        <- {wiring y registro de ruta}

{Si modifica archivos fuera del módulo (main.go, config, shared), listarlos.}

Reutilizado sin duplicar: {lista de componentes compartidos que se reusan}

## 4. Criterios de aceptación

{Lista de criterios verificables — sin checkboxes, texto plano:}
- {Criterio 1: qué debe hacer el endpoint ante un request válido}
- {Criterio 2: qué tablas se actualizan y cómo}
- {Criterio 3: qué servicios externos se llaman y en qué orden}
- {Criterio 4: paridad de errores con Java}
- {Criterio 5: make check pasa con 0 issues}
- {Criterio 6: cobertura >= 70% (piso), meta 85%}

## 5. Definition of Done

{Lista de condiciones para considerar el ticket DONE. QA también usa este ticket: el DoD es la
lista de lo que se certifica. Cada flujo de paridad de la sección 2 es un ítem verificable aquí,
referenciando su paso (no se copia el flujo; se apunta a él). Incluir SOLO los casos aprobados
por el usuario tras `/migrate usecases`; los no replicables/no simulables se listan aparte.}

**Flujos de paridad con Java a certificar (QA):**
- [ ] EST-01 · Flujo 2.1 — Sin Authorization → rc/HTTP {x}
- [ ] EST-02 · Flujo 2.3 — {condición de negocio} → rc/HTTP {x}, mensaje exacto de RESPONSE_CODES
- [ ] EST-NN · Flujo 2.N — Éxito → respuesta {campos}, paridad Go vs Java
**No certificables manualmente (excluidos, con motivo):** EST-NN {stub externo / falla inyectada / concurrencia}

**Técnicos:**
- PR revisado y aprobado ({branch names de las fases})
- make check limpio (0 lint issues, 0 race conditions)
- Mensajes de error verificados contra Java {servicio Java fuente}
- Sin duplicación de lógica ya existente ({componentes reutilizados})
- Documentación en docs/modules/{module}/ actualizada
- Tests completados — {paquetes}: {cobertura%} por paquete

## 6. Notas técnicas

{Lista de bullets con notas relevantes para el developer:}
- {Nota sobre transacciones Oracle si aplica}
- {Nota sobre componentes reutilizados y dónde viven}
- {Nota sobre httpClient: en Handler o en Service según patrón del módulo}
- {Nota sobre auth: middleware, parámetro explícito, etc.}
- {Nota sobre ramas de desarrollo y fases}
- {Nota sobre cobertura final por paquete}
```

### Content rules

- **Java source is the spec** — derive the flow, errors, and fields from the actual code, not from
  memory or Jira descriptions. Read the Java handler + service + dao FIRST.
- **Error messages are IMMUTABLE** — copy exactly from `RESPONSE_CODES.properties` or the Java code.
- **Developer language** — escrito para devs, no para PO. Directo, técnico, sin user stories.
- **Go-specific details** — if the endpoint is already migrated, include actual Go file names, test
  case names, coverage numbers, branch names. If not migrated, use the estimated plan.
- **Reutilización explícita** — always list what existing Go components are reused (CustomerReader,
  Handler base, external clients, cryptoutil, etc.).
- **Mejoras sobre Java** — if Go fixes a Java bug or improves behavior, call it out explicitly with
  "Mejora respecto a Java:" and explain what changed.
- **Diferencias con endpoints similares** — if the endpoint is symmetric to another (cashIn/cashOut,
  block/unblock, associate/disassociate), include a comparison table showing the differences.

### Jira update (protected — the description may hold text from the PO or QA)

The write **replaces** the whole description, and it is visible to other people, so it never runs
blind. Use the **Atlassian connector** (`getJiraIssue` / `editJiraIssue`), not raw REST calls with
credentials — if it needs authorization, tell the user to authorize it; never ask for or handle a
password or token.

1. **Read** the current description (`getJiraIssue`). Save it as a backup in the scratchpad
   (`<TICKET>-description-backup.md`) and print the path.
2. **Split** it: the plan block is delimited by the heading `Plan de Desarrollo vN — …`. Everything
   outside that block (PO text, QA notes, links) is **preserved untouched**. No marker found → treat
   the whole current text as "other content" and append the plan below it.
3. **Show the diff** (what is removed/replaced, what is kept) in chat and ask the user to approve
   **that diff**, not just the plan.
4. Convert only the plan block to **Atlassian Document Format (ADF)** — headings, paragraphs, bullet
   lists, tables, code blocks, inline code — and write the merged description (`editJiraIssue`).
5. **Idempotent re-run:** a second run replaces the existing plan block (bumping `vN` and the date),
   it never stacks a second copy.
6. Read the ticket back to verify the write, then confirm:
   ```
   ✅ Plan de Desarrollo actualizado en {TICKET_KEY} (backup: <path>)
   ```

### When to use this vs other subcommands

| Need | Subcommand |
|------|-----------|
| Jira ticket description (Plan de Desarrollo for devs) | **`migrate-ticket-plan`** (`mtp`) ← this one |
| Word/PDF Plan de Desarrollo for QA / certificación | `/migrate migrate-doc-plan` |
| Jira ticket for PO (Historia de Usuario + subtasks) | `/migration-context ticket` |
| Technical doc + diagrams (offline/docs folder) | `/migrate techdoc` |
| QA test scenarios | `/migrate usecases` |
| Java↔Go parity check | `/migrate verify-parity` |
