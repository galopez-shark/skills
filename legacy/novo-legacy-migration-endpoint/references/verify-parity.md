# Subcommand: `/migrate verify-parity <endpoint>` (alias `simetria`)

> Moved out of `SKILL.md` to save context. Everything here is binding exactly as if it were inline.

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
