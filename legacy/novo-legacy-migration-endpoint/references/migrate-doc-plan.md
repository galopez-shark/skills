# Subcommand: `/migrate migrate-doc-plan <endpoint>` (alias `mdp`; legacy: `plandoc`, `plan-doc`, `docx`)

> Moved out of `SKILL.md` to save context. Everything here is binding exactly as if it were inline.

> Ask every question following the **Question protocol** in `SKILL.md` (rounds, read before asking, `pendiente` for unknowns).

Generates the **formal Plan de Desarrollo document (`.docx` + `.pdf`)** for a migration endpoint —
the QA / certificación artifact. It does **not** touch Jira; the Jira description is a different
deliverable (`/migrate migrate-ticket-plan`). Same endpoint, different format and audience.

Accept the endpoint by name, number, or Java method name.

### Workflow

1. **Load `.migration-context.yaml`** — if missing, tell the user to run `/migration-context` first.
2. **Resolve the endpoint** in `endpoint_inventory`. Get the ticket number. If no ticket, ask the user.
3. **Read the Java source** (resource/controller + service + dao/repository) + properties files — Java is the spec.
4. **Read the Go source** if migrated (`done` / `in_progress`); if `not_started`, derive from the Java
   analysis and the existing Go patterns.
5. **Ask ONE question before generating anything (MANDATORY)**:
   > ¿Este Plan de Desarrollo es un **comparativo** (migración Java→Go, la tabla de Pruebas
   > Unitarias muestra la respuesta Golang y la respuesta Java lado a lado) o es **solo
   > certificación** (endpoint nuevo sin legacy detrás, la tabla de Pruebas Unitarias muestra
   > únicamente la respuesta Go)?
   This decides the shape of the Pruebas Unitarias table — never guess it from
   `.migration-context.yaml` alone, since a `done` endpoint can still be a non-migration addition.
5b. **Reuse the shared plan data** (`docs/modules/<go_module>/<endpoint>.plan-data.yaml`, see the
   `migrate-ticket-plan` section) for flows, dependencies and the approved `EST-NN` cases — ask only
   what changed. Update it if you add or drop cases, so Jira and the Word file never diverge.
6. **Draft the content in sub-steps 6.1 → 6.8 — one at a time, each shown in chat and approved
   by the user before the next** (see "Sub-steps of step 6" below). Nothing is built until 6.8 passes.
7. **Build the `.docx` and `.pdf`** following "Process" below, and run its final residue grep.
8. **Report** the output paths, the case count, and print the completion checklist with evidence
   (one row per sub-step 6.1-6.8 + response images generated (count, marked "no capturadas") + build + residue grep; a row without evidence is `❌ NO EJECUTADO`).

**Output folder (fixed):** `.../proyectos/zinli/{TICKET}({Descripción})/documentacion/` — the `.docx`,
`.pdf`, the three diagram images and their `.plantuml` sources all live together there, as in
CEB-5361 / CEB-5614. Create the folder if it is missing; never write outside it.

### Sub-steps of step 6

Every text sub-step has a **hard character cap**. Count it (`len()` on the final string, spaces
included) and print `N/300` next to the draft; over the cap → shorten and recount, never ship it.
Text comes from the real Java/Go code, never invented, in Spanish, developer language.

| Sub-step | Section | Content | Rule |
|---|---|---|---|
| **6.1** | Alcance | Text ≤ **300 chars** (what is migrated/added, endpoint + method + path, read/write, why) **plus** a separate last line `Ticket: https://jira4novo.atlassian.net/browse/{TICKET}` | The ticket line is NOT counted in the 300 |
| **6.2** | Definiciones, Acrónimos y Abreviaturas | ≤ **300 chars**, only terms that actually appear in the document (PAN, cardToken, rc, …) | If nothing needs defining write `N/A` |
| **6.3** | Estructura | ≤ **300 chars**: layers/modules (handlers, service, repository, domain) and what each does, from the real Go tree | No file listings |
| **6.4** | Construcción | ≤ **300 chars**: Go/go-bricks version, QueryBuilder/Entity, tables touched, notable decisions (e.g. ambiguous row → "no registrada") | Real tables and versions only |
| **6.5** | Diagramas | Generate **3 images** in the output folder: `{endpoint} - Diagrama de Clases.png`, `{endpoint} - Diagrama de Flujo.png`, `{endpoint} - Estructura de Datos.png`, each with its `.plantuml` source | Flow: reuse the validated `.plantuml` from `docs/modules/<module>/` + Novopayment skin; classes/data from the real Go types and tables — never generic. All three are mandatory (CEB-5614 shipped without the flow image) |
| **6.6** | Ajustes realizados | Table `Aplicaciones involucradas \| Cambios aplicados`, filled from the phases' PRs/commits (`git log`/`gh pr list`) and the `go.mod` diff (e.g. endpoint enabled, go-bricks vX → vY, new config) | **Never empty or missing** — an empty section breaks the TOC with `¡Error! Marcador no definido`. Show the rows for approval |
| **6.7** | Pruebas Unitarias | Run **`/migrate usecases <endpoint>`** to get the accurate scenario list, then **ask the user which cases to include**, proposing a verdict per case (include / exclude) | See "Case selection" below. Shape follows the comparativo vs solo-certificación answer of step 5 |
| **6.8** | Revisión previa al build | Print: `N/300` per text sub-step, the three image paths (exist ✅/❌), Ajustes rows count, case count after selection | Any ❌ blocks the build |

**Case selection (6.7).** `usecases` returns the full set (happy, negative, edge, external, auth).
Present them as a table with a proposed decision and the reason, and ask the user — one
`AskUserQuestion` per group if there are many:

- **Reproducible by QA with Postman** → propose *include*.
- **Needs an external stub/mock** (KYC, SGC, third-party connector), **fault injection** (forcing a DB
  failure) or **real concurrency** → propose *exclude* and mark the reason "no replicable / no
  simulable". The user decides; never include them silently and never drop them silently.
- After the selection, renumber every `EST-NN` / "N°" sequentially and update every place that states
  the total (Control de Revisión row, summaries).

**Sections that come from the base template and are filled in step 7** (not drafted above):
Historial de cambios, Control de Revisión, "Nombre del esquema de la base de datos",
Datos para Configurar e Instalar (the `curl` for Java and Go use `Authorization: Bearer <token>` —
**never a real token**, PCI policy), and Requisitos para la Certificación (`Ruta de Repositorio` =
latest git tag on `main`, not a raw commit SHA; `Usuario`/`Clave` empty).

### Process (Word/PDF)


This produces the corporate `.docx`/`.pdf` artifact, independent of the Jira description above.
**Read `PROMPT_PLAN_DESARROLLO.md` in full before starting** — it owns the project-agnostic
process (8 phases: discovery, question round, build, Word generation, PlantUML diagrams, Python
helpers, PDF export, final checklist). What follows here is only the migration-specific layer on
top of that generic process — gotchas learned building CEB-5633 (createDebitCard), don't
rediscover them by trial and error.

**Files (bundled with this skill — portable, works on any machine without the OneDrive mount):**
- Guide: `assets/PROMPT_PLAN_DESARROLLO.md` (relative to this skill's own directory)
- Base template (always clone, never create from scratch, never edit a sibling ticket's filled
  docx in place): `assets/Plan_de_Desarrollo_BASE.docx` (relative to this skill's own directory).
  If the user's OneDrive has a newer version of either file, prefer theirs and update this skill's
  bundled copy in the same step — don't silently drift from the canonical source.
- Destination: `.../proyectos/zinli/{TICKET}({Descripción})/documentacion/Plan_de_Desarrollo_{TICKET}({Descripción}).docx`
  (+ matching `.pdf`). If that folder already has a `.docx` under this ticket's name, **open and
  read it first** — it may contain another ticket's content pasted in by mistake (this happened on
  CEB-5633: the file was named for CEB-5633 but internally was 100% CEB-5614 content). Never trust
  the filename; grep the actual paragraphs/tables for the ticket number and endpoint name before
  treating it as a starting point. If it's wrong, clone fresh from BASE — never patch over
  contaminated content.

**Before writing anything, inspect the REAL base template structure** (don't assume it matches a
previously-filled sibling doc — they can diverge): dump every `doc.paragraphs` (index + style) and
every `doc.tables` (all rows/cells, including `gridSpan`/`vMerge` via the XML) with a throwaway
python-docx script. As of the version used for CEB-5633, the base template has **6 real headings
you'll touch** (Historial de cambios, Control de Revisión, Alcance, Definiciones, Estructura →
Descripción de Clases / Estructura de datos → Nombre del esquema, Construcción, Ajustes
realizados, Pruebas Unitarias, Datos para Configurar e Instalar, Requisitos para la Certificación)
and **6 tables** in that order. It does **not** ship a "Descripción de Flujo" heading, and its
Pruebas Unitarias table is a **flat 3-column table with no example row** (N° | Alcance |
Descripción, span 1 everywhere) — confirm this hasn't changed before assuming either shape.

**The comparativo/sin-comparativa branch (from step 5 of the Workflow above) changes the Pruebas
Unitarias table shape:**

- **Sin comparativa** (no legacy): fill the base's native flat table as-is — one row per `EST-NN`,
  clone rows with `copy_row_and_fill`, no merge needed. Simple, low risk.
- **Comparativo** (migración): you need a **3-row-per-case pattern** (case header row with
  `gridSpan` on the Alcance columns → label row "RESPONSE GOLANG" / "RESPONSE JAVA" with `vMerge` →
  content row with the two responses side by side) that **the clean base template does not ship as
  an example**. Don't hand-build that `gridSpan`/`vMerge` XML — it's exactly the kind of thing that
  silently corrupts a `.docx`. Instead, **source that 3-row block from an already-finished sibling
  ticket's doc that used the comparativo format** (e.g. the CEB-5614 or CEB-5633 filled docs),
  deep-copy its header + one case's 3 rows into the destination's Pruebas Unitarias table, clear
  every cell with `cell_clear_and_set`, then clone that cleaned block once per `EST-NN` with
  `copy_row_and_fill`. This is the only way to get real merges instead of built-by-hand ones.
- **Always add a "Descripción de Flujo" H2** (clone the "Descripción de Clases" paragraph for the
  heading style) between Clases and Estructura de datos — the base template doesn't have it by
  default, but the process always needs a flow diagram there.

**Response cells are Postman-style IMAGES (as in the reference docs CEB-5361 / CEB-5614).** In the real
Plan de Desarrollo, each `RESPONSE GOLANG` / `RESPONSE JAVA` cell holds a **screenshot of the Postman
request and response** (method + URL, headers table, status, body with `rc`/`msg`), not JSON text. The
user chose to have these **generated** as images:

- **Render one PNG per response** (Pillow, or an HTML → PNG render) with a Postman-like layout: method
  and URL line, a headers table (`country`, `language`, `channel`, `Content-Type`, `accept`, `switch`,
  `Authorization: Bearer <token>`), the status badge and the pretty-printed JSON body. Dark theme, ~600 px
  wide, legible when scaled to the cell. Save them next to the docx (e.g. `casos/EST-NN-go.png`,
  `EST-NN-java.png`) and insert with `run.add_picture` into the cell — Go in column 1, Java in column 2.
- **Content comes from the real code, never invented:** Go from the handler/service/`RESPONSE_CODES`,
  Java from the Java source and properties. The request mirrors the case (headers present or omitted as
  the case says). No real token, PAN, account number, expiry or CVV: use `Bearer <token>` and the
  masked/test values only.
- **Transparency is mandatory:** these images are **derived from the code, not captured from a run**.
  Each image carries a small, legible footer line `Respuesta esperada — derivada del código (no capturada)`,
  and the final report states `N imágenes generadas (no capturadas)`. Never present a generated image as
  evidence of an execution. If QA needs real evidence for a case, the user replaces that image with a real
  Postman capture — keep the same file name so the swap is trivial.
- **Solo-certificación** docs have only the Go image; **comparativo** docs have both.

**Non-reproducible cases: ask the user, default to removing them, never silently list them as
normal cases.** Any `EST-NN` that requires an external stub/mock (KYC, SGC, any third-party
connector), fault-injection (forcing a DB failure), or real concurrency (two parallel requests) is
**not something QA can trigger manually with Postman in the standard flow**. First pass: prefix
its Alcance with **"🔒 NO REPRODUCIBLE MANUALMENTE — "** and note what it needs. Then **ask the
user whether to keep it flagged or remove it from the table entirely** — on CEB-5633 the user's
call was to remove all 6 such cases outright ("no se puede así que sobra"), since a flagged-but-
unexecutable row in a QA certification doc is still noise. Removing a 3-row comparativo block:
delete its 3 `w:tr` elements from the table XML, then **renumber every remaining `EST-NN` /
"N°" sequentially** (don't leave gaps) and update every place that states the total case count
(Control de Revisión row, any summary note) — a stale "22 casos" after deleting 6 is an immediate
tell that the doc wasn't finished.

**Headers validation needs one case PER field PER failure mode, never two generic buckets.** A
"Header requerido ausente" / "Header con formato inválido" pair collapsing country+language+channel
into 2 rows is under-specified — the team's own reference docs (e.g. CEB-5614) split each header
into its own case: *Sin header country*, *Sin header language*, *Sin header channel*, *Country
formato inválido*, *Language formato inválido*, *Channel formato inválido* (6 cases minimum,
matching whatever fields `auth.HeadersValidator`/equivalent actually validates — don't invent
fields it doesn't check, like Content-Type/Accept, unless the code validates those too). Apply the
same "one case per field per failure mode" principle to any other multi-field validator.

**Never leave a literal `"..."` placeholder in a response example.** It reads as unfinished. Fill
every field with a realistic, internally-consistent example value (an ISO datetime, a plausible
token/UUID shaped like the real one — e.g. the exact 37-char UUID-hex+salt format `generateCardToken`
produces, if that's the field) instead of an ellipsis. This is NOT a PCI concern — these are
non-sensitive example dates, tokens and IDs, not PAN/CVV/passwords — so there's no reason to leave
them as placeholders. **When a label field is blank because it genuinely doesn't apply (not
because you forgot it), write `"N/A — <one-line reason>"`** instead of leaving the cell visually
empty — an empty-looking cell in a finished certification doc reads as an oversight, not as "this
doesn't apply". PCI passwords (`Clave`) are the one exception: those stay truly empty, never even
`"N/A"` with invented text that could be mistaken for a real value — a short reason belongs in the
adjacent `Usuario` cell instead (e.g. "N/A — autenticación Bearer, sin login usuario/contraseña").

**The comparativo table's column 0 is a hidden trap — never write content into it.** In the 3-row
block, column 0 of the label row ("RESPONSE GOLANG"/"RESPONSE JAVA") and column 0 of the content
row are **vertically merged into ONE cell** (`vMerge`) that must stay blank as a gutter. Go's
response goes in column 1, Java's in column 2 (column 3 mirrors column 2 via horizontal `gridSpan`
— writing to one writes to both, since python-docx returns the same Cell object for merged
columns). **The single most common mistake building this table is an off-by-one**: treating
column 0 as "the Go column" and columns 1/2 as "the two Java columns" — this silently (a) pollutes
the blank gutter with Go's text, visible bleeding into the label row, and (b) leaves BOTH visible
response columns showing Java's text, making it look like Go behaves identically to Java even when
it was supposed to differ (a real divergence disappears from the document). **After filling the
table, run a verification pass, case by case, comparing each Go cell's text against what you
actually know Go does (not what you wrote in bulk) — a bulk find/replace across many rows is
exactly how this corruption happened on CEB-5633 (6 of 20 cases had Go silently showing Java's
behavior, caught only when the user spotted one by eye).** Fix one case, re-read it back, THEN
move to the next — don't trust a large batch edit across the whole table without rereading it.

**Certificación table has no labels in the clean base** — write them yourself (copied verbatim
from a finished sibling doc's layout: Código de Prioridad, Fecha, N° de Ticket, Usuario
Solicitante, Incidente/Requerimiento/Proyecto de Cambio, Aplicación, Tipo, País, Subsidiarias, URL,
Usuario, Clave, Ruta de Repositorio, Otros) using `cell_clear_and_set` for both label and value in
the same pass, to avoid leftover text from whatever doc you copied the layout from.

**PCI — never put real or placeholder credentials in "Usuario"/"Clave".** Leave both empty even
when a value is technically known; this is the global PCI policy (`~/.claude/CLAUDE.md`), not
optional per-ticket judgment.

**"Ruta de Repositorio" is the deployed-to-TEST reference, not an arbitrary commit.** Prefer the
latest git tag on `main` (`git tag --sort=-creatordate | head -1`) over a raw commit SHA. If you
cannot confirm via `gh` (auth can expire mid-session) that this specific tag already deployed to
TEST, say so explicitly to the user as a pending verification — don't silently assume it did.

**Diagrams**: reuse an existing, already-validated `.plantuml` from `docs/modules/<module>/` for
the flow diagram (never invent a new flow when the team already maintains one) — just prepend the
Novopayment skin block (FASE 5 of the guide) and re-render. Class and data-structure diagrams are
usually new; build them from the real Go types/tables (never generic placeholders — a prior
session had its first diagram attempt rejected for being generic), apply the same skin, render
with the local `plantuml` binary.

**If the reused flow diagram is too tall to fit one page** (a sequence diagram with many `alt`
error blocks grows vertically fast — CEB-5633's came out at a 1:2.2 aspect ratio), don't just
shrink the image until the text is unreadable. Condense each error `alt` block from its full
2-arrow-plus-`alt`/`end` form into a single `note right of <participant>` summarizing that step's
rc(s) — this keeps every error path documented while cutting the diagram's height roughly in half,
often enough to reach a near-square aspect ratio that fits one page at a readable size. Keep the
happy-path arrows exactly as they are; only the error branches get collapsed into notes.

**Final residue check is a real grep, not a visual skim.** After saving, search every XML part of
the `.docx` (it's a zip) for keywords unique to whatever content you copied structure/layout from
(ticket number, endpoint name, sample PAN/IDs) and confirm zero matches — except expected false
positives like a numeric `w:id` in `webSettings.xml` that happens to contain the ticket number as
a substring (verify it's inside a larger number, not the standalone ticket reference).

**If this is intricate enough to risk breaking table merges, delegate it** (per this repo's
Fable-delegation policy) to a `general-purpose` agent with: the exact base template + guide paths,
the content already fully drafted (text for all 6 sections + the EST table content, resolved
BEFORE delegating — never ask the agent to invent business content), and explicit instructions to
**stop and report back** if the real template structure doesn't match what's described here, rather
than improvising a merge by hand.

---



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
