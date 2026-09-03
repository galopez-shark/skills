# Label glossary — ES (canonical) → EN

Used with [`report-template.md`](report-template.md). The template exists **once**, in
Spanish; this table is how it becomes any other language without a second copy.

For a `LANG` other than EN, translate the Spanish column directly — do not translate the
English column (a relay through a third language drifts).

Anything not listed here is prose: translate it naturally. Code, identifiers, paths,
go-bricks type names and status glyphs are never translated.

| Español (canónico) | English | Dónde |
|---|---|---|
| Revisión PR #{number} — {title} | PR Review #{number} — {title} | heading |
| ❌ Bloqueadores | ❌ Blockers | heading |
| 🔧 Debe corregirse | 🔧 Should fix | heading |
| 💡 Oportunidades go-bricks | 💡 go-bricks opportunities | heading |
| 🔒 Auditoría rawQuery / SQL | 🔒 rawQuery / SQL audit | heading |
| 📌 Para el próximo commit | 📌 For the next commit | heading |
| Verificación | Check | fila |
| **Base de evidencia (Phase 0)** | **Evidence base (Phase 0)** | fila |
| Modernización (`go fix -diff`) | Modernization (`go fix -diff`) | fila |
| Sin tipos reinventados | No reinvented types | fila |
| Sin llamados a stored procedures | No stored procedure calls | fila |
| Límites de capa correctos | Layer boundaries | fila |
| Cableado de módulo | Module wiring | fila |
| Patrones de BD | DB patterns | fila |
| Construcción queries (builder+Entity vs const) | Query construction (builder+Entity vs const) | fila |
| Sin andamiaje muerto (Entity[T] usado) | No dead scaffolding (Entity[T] used) | fila |
| Ubicación archivos/structs | File/struct placement | fila |
| Cohesión y minimalismo de archivos | File cohesion & minimalism | fila |
| Contenido de cada archivo = su responsabilidad | File content matches its responsibility | fila |
| Patrones handler | Handler patterns | fila |
| Llamadas externas httpclient | External calls httpclient | fila |
| Integración bus (nombres, AutoAck, DLQ, idempotencia) | Bus integration (names, AutoAck, DLQ, idempotency) | fila |
| Patrones de test | Test patterns | fila |
| Sin código duplicado | No duplicate code | fila |
| Nombres y convenciones | Naming & conventions | fila |
| Diseño de firmas (ctx/error/params) | Signature design (ctx/error/params) | fila |
| Config completa | Config complete | fila |
| Version bump en config.yml (+1 patch) | Version bump in config.yml (+1 patch) | fila |
| Manejo de errores | Error handling | fila |
| Sin bugs de concurrencia | No concurrency bugs | fila |
| Sin resource leaks | No resource leaks | fila |
| Fail-closed en fallos | Fail-closed on errors | fila |
| Calidad de tests | Test quality | fila |
| **Diseño y duplicación (Fase 3b)** | **Design & duplication (Phase 3b)** | fila |
| Sin fugas de decisión (una autoridad por decisión) | No leaked decisions (one authority per decision) | fila |
| Sin interfaces shallow ni params pass-through | No shallow interfaces or pass-through params | fila |
| Sin concerns fusionados (telemetría independiente) | No fused concerns (telemetry independent) | fila |
| DRY — cada hecho con una sola fuente de verdad | DRY — every fact has one source of truth | fila |
| Guard de sobre-aplicación DRY evaluado | DRY over-application guard applied | fila |
| Idioms de Go (Uber) | Go idioms (Uber) | fila |
| Versión go-bricks | go-bricks version | fila |
| Oportunidades go-bricks | go-bricks opportunities | fila |
| Scope contenido | Scope contained | fila |
| Justificaciones del autor honradas | Author's prior justifications honored | fila |
