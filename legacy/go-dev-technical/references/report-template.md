# Report template — `go-dev-technical review`

Loaded on demand by the skill at report-writing time. **Read this file before writing the
report**, not earlier — nothing in the review depends on it until the findings exist.

## One template, any language

There is exactly one canonical template, written in Spanish (the skill's default). For any
other `LANG`, translate the **labels** with the glossary in
[`report-glossary.md`](report-glossary.md) and write all prose in the target language.

**Never keep a second copy of this template per language.** Two hand-synced templates are
this skill's own check 20b — and it already cost real drift: three separate edits in one
session had to be applied twice, once per copy.

What is translated: headings, row labels, descriptions, fix explanations, the verdict line.
What is **not**: code snippets, Go identifiers, file paths, go-bricks type names, and the
emoji/status glyphs (✅ ❌ ⚠️ 🔧 💡 🔒 📌 📁 📋 🧱 📊 📝) — those are stable across languages.


The entire output is ONE markdown block the user can copy-paste into a GitHub
PR comment. It MUST render correctly in GitHub-Flavored Markdown (GFM):
- Use `##` for top sections, `###` for sub-findings
- Use `<details><summary>` to collapse verbose sections (validation table, nits)
- Use task lists (`- [ ]` / `- [x]`) for actionable items
- Use fenced code blocks with language hint (\`\`\`go, \`\`\`bash)
- Tables must have a header separator row (`|---|---|`)
- No raw HTML except `<details>`, `<summary>`, `<br>`
- Emoji are OK for status: ✅ ❌ ⚠️ 🔧 💡

```markdown
## Revisión PR #{number} — {title}

📋 **{count} archivos** | **+{prodLOC} prod / +{testLOC} test líneas** (gate ≤400 sobre prod) | **Riesgo**: {ALTO/MEDIO/BAJO} | **go-bricks**: v{version}

### ❌ Bloqueadores

> Ninguno / o lista:

**1. `[tag]` {título corto}**
📁 `path/to/file.go:42`
```go
// código problemático (copiado del diff)
```
**Problema**: {explicación en lenguaje developer — qué pasa en runtime}
**Fix**:
```go
// código corregido
```

---

### 🔧 Debe corregirse

> **Regla dura de esta sección: todo ítem lleva su PROPUESTA CONCRETA, nunca solo el
> problema.** Según el tipo de hallazgo:
> - **Nombre de variable/función/tipo/constante** → dar el **nombre propuesto** + bloque
>   ```suggestion``` con la línea ya corregida (renombre de un solo sitio) o `gofmt -r`
>   (multi-sitio). Ver check 9.
> - **Código en el archivo/capa equivocada** → dar el **`git mv` al `.go` que le
>   corresponde** según la estructura de arquitectura (mappers → `mapper.go`, DTOs →
>   `dto.go`, errores → `errors.go`, queries → `queries.go`, interfaz de repo →
>   `repository.go`, config/wiring → `module.go`, handlers HTTP → `http.go`, etc. —
>   ver checks 8b/8c). Si es contenido mal ubicado *dentro* de un archivo, usar
>   ```suggestion```; si es el archivo entero, `git mv`.
> - **Bug/error de runtime** → dar el diff before→after concreto (ver Phase 3).
> - **Diseño (fuga de decisión / interfaz shallow / duplicación)** → dar el **conteo**
>   (N sitios · M autoridades, o la evidencia de costo en git) + el **dueño propuesto**
>   (paquete/archivo que debe poseer la decisión, o la fuente de verdad del hecho) +
>   la etiqueta de confianza. Ver checks 19/20. Los `speculative` NO van aquí, van a
>   "Para el próximo commit".
>
> Un ítem que dice "mejorar el nombre", "reubicar esto" o "revisar la estructura" **sin la
> propuesta concreta (nombre exacto / ruta destino / diff) NO está listo** — no se emite así.
> Lo mismo aplica a diseño: "considerar consolidar", "está muy duplicado" o "esta interfaz
> es rara" **sin conteo y sin dueño propuesto NO se emite**.

- [ ] **`path/to/file.go:42`** — `[tag]` {descripción developer-friendly: qué está mal, qué pasa en runtime, cómo corregir}
- [ ] **`path/to/file.go:80`** — `[tag]` {descripción}
- [ ] **`path/to/file.go:24`** — `[naming]` sugerencia: renombrar `{actual}` → `{propuesto}` ({regla}). Seguir una nomenclatura más clara y diciente. *(sugerencia, no bloquea)*
  ```suggestion
  {la línea file.go:24 completa, ya con el nombre corregido}
  ```
  _(un bullet por cada fila real de la tabla de nombres; `suggestion` sólo para renombres de un solo sitio — multi-sitio va a la tabla con `gofmt -r`)_
- [ ] **`path/to/file.go`** — `[layout]` mover `{Tipo/func}` a `{archivo destino}.go` para cumplir la estructura de la arquitectura ({razón: mappers en mapper.go / config en module.go / etc.}). Seguir una organización más cohesiva. *(sugerencia, no bloquea)*
  ```bash
  git mv internal/modules/<mod>/<capa>/<origen>.go internal/modules/<mod>/<capa>/<destino>.go
  ```
- [ ] **`path/to/file.go:73`** — `[design]` la decisión "{pregunta}" se resuelve en **{N} sitios** con **{M} autoridades distintas** (`{autoridad A}`, `{autoridad B}`); cambiar la regla obliga a tocar los {N}. Proponer que la posea `{paquete/archivo destino}` y que el llamador quede en 1 línea. *(confianza: strong — no cambia ninguna regla de negocio)*
- [ ] **`path/to/file.go:29`** — `[design]` `{param}` es un seam hipotético: {X} menciones no-test, **{Y} implementación real**, `nil` en {Z} tests. Que el adaptador lo reciba en el constructor y la interfaz quede `(ctx, req)` — desaparecen {Z} argumentos `nil`. *(confianza: strong)*
- [ ] **`fileA.go:160` ↔ `fileB.go:915`** — `[dry]` mismo comportamiento, ~{N} líneas copiadas; el fix de `{regla}` ya tuvo que aterrizar 2 veces ({commits/tickets}). Un solo path parametrizado por `{descriptor existente}`; la interfaz no cambia. *(confianza: strong)*

---

### 💡 Oportunidades go-bricks

- [ ] **`path/to/file.go:45`** — `[go-bricks]` {lo que el PR hace manualmente} → usar `{go-bricks type/function}` ({beneficio concreto})

---

### 🔒 Auditoría rawQuery / SQL

| # | Archivo | Tipo | Riesgo | Detalle |
|---|---------|------|--------|---------|
| 1 | `repo/queries.go:15` | `f.Raw()` | ✅ Safe | Args parametrizados |
| 2 | `repo/legacy.go:30` | `fmt.Sprintf+SQL` | ❌ BLOCKER | Inyección SQL |
| 3 | `repo/queries.go:45` | raw const | ⚠️ Migrable | Builder puede expresarlo |

---

### 📌 Para el próximo commit

- {item 1 — forward-looking, no bloquea este PR}
- {item 2}
- go-bricks v{current} → v{latest} disponible

<details>
<summary>📊 Resumen de validación (click para expandir)</summary>

| Verificación | Estado | Notas |
|:--|:--:|:--|
| **Base de evidencia (Phase 0)** | | |
| `go build ./...` | ✅/❌/⚠️ | |
| `go vet ./...` | ✅/❌/⚠️ | |
| `go test ./...` | ✅/❌/⚠️ | cobertura por paquete tocado |
| `golangci-lint run ./...` | ✅/❌/⚠️ | comparado contra `origin/main` |
| `go test -race` | ✅/N/A | sólo si el diff toca concurrencia |
| Modernización (`go fix -diff`) | ✅/❌/N/A | |
| **go-bricks** | | |
| Sin tipos reinventados | ✅/❌/⚠️ | |
| rawQuery / SQL safety | ✅/❌/⚠️ | |
| Sin llamados a stored procedures | ✅/❌ | BLOCKER si hay SP |
| Límites de capa correctos | ✅/❌/⚠️ | |
| Cableado de módulo | ✅/N/A | |
| Patrones de BD | ✅/N/A | |
| Entity/Row mapping | ✅/N/A | |
| Construcción queries (builder+Entity vs const) | ✅/❌/N/A | |
| Sin andamiaje muerto (Entity[T] usado) | ✅/❌/N/A | |
| Ubicación archivos/structs | ✅/N/A | |
| Cohesión y minimalismo de archivos | ✅/❌/N/A | |
| Contenido de cada archivo = su responsabilidad | ✅/❌/N/A | |
| Patrones handler | ✅/N/A | |
| Llamadas externas httpclient | ✅/N/A | |
| Integración bus (nombres, AutoAck, DLQ, idempotencia) | ✅/❌/⚠️/N/A | |
| Patrones de test | ✅/N/A | |
| Sin código duplicado | ✅/❌ | |
| Nombres y convenciones | ✅/❌ | |
| Diseño de firmas (ctx/error/params) | ✅/❌ | |
| Config completa | ✅/N/A | |
| Version bump en config.yml (+1 patch) | ✅/❌ | |
| **Bugs & code smells** | | |
| Manejo de errores | ✅/❌/⚠️ | |
| Sin bugs de concurrencia | ✅/N/A | |
| Sin resource leaks | ✅/❌/⚠️ | |
| Fail-closed en fallos | ✅/N/A | |
| Calidad de tests | ✅/❌/⚠️ | |
| **Diseño y duplicación (Fase 3b)** | | |
| Sin fugas de decisión (una autoridad por decisión) | ✅/❌/N/A | {N} sitios / {M} autoridades |
| Sin interfaces shallow ni params pass-through | ✅/❌/N/A | |
| Sin concerns fusionados (telemetría independiente) | ✅/❌/N/A | |
| DRY — cada hecho con una sola fuente de verdad | ✅/❌/N/A | |
| Guard de sobre-aplicación DRY evaluado | ✅/N/A | duplicación accidental tolerada a propósito |
| Idioms de Go (Uber) | ✅/❌/⚠️ | |
| **go-bricks discovery** | | |
| Versión go-bricks | ⚠️/✅ | |
| Oportunidades go-bricks | ✅/❌ | {N} encontradas |
| **Scope** | | |
| Scope contenido | ✅/❌ | |
| Justificaciones del autor honradas | ✅/⚠️ | ⚠️ si no pude leer los comentarios del PR |

</details>

<details>
<summary>📝 Nombres — propuestas de renombrado</summary>

| # | Archivo | Actual | **Propuesto** | Razón |
|---|---------|--------|---------------|-------|
| 1 | `path/file.go:24` | `{nombre actual}` | `{nombre propuesto}` | {regla en una línea} |
| — | — | Todas las convenciones seguidas ✅ | — | — |

Verificado: receptores, `ctx` primero, `error` último, acrónimos (`ID`/`URL`/`HTTP`),
stuttering, alias de import, palabras ruido (`Data`/`Info`/`Manager`), verbos vacíos,
constantes autodescriptivas.

</details>

<details>
<summary>🧱 Diseño — profundidad de módulos y duplicación (checks 19-20)</summary>

| # | Decisión / interfaz | Sitios | Autoridades | Confianza | Tipo de seam | **Dueño propuesto** |
|---|---|---:|---:|---|---|---|
| 1 | `path/file.go:73` — "{la decisión, como pregunta}" | {N} | {M} | strong | in-process / ports & adapters / local-substitutable | `{paquete/archivo que debe poseerla}` |
| — | — | — | — | — | — | Sin fugas detectadas ✅ |

| # | Hecho duplicado | Sabor | Evidencia de costo | **Fuente de verdad propuesta** |
|---|---|---|---|---|
| 1 | `fileA.go:160` ↔ `fileB.go:915` | A · código | {commit/ticket donde el fix aterrizó 2 veces} | un solo path + descriptor de operación |
| 2 | `codes.go` ↔ `messages.go` | B · datos | {55 vs 44, nada lo valida} | tabla indexada por rc + 1 test de tabla |
| — | — | — | — | Sin duplicación de conocimiento ✅ |

Tolerado a propósito (duplicación accidental, no misma razón de cambio): {lista o "ninguno"}.

</details>

**Veredicto**: ✅ Aprobado / ⚠️ No verificado ({razón}) / ❌ {N} bloqueadores pendientes
```