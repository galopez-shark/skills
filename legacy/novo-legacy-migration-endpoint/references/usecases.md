# Subcommand: `/migrate usecases <endpoint>` (alias `casos`)

> Moved out of `SKILL.md` to save context. Everything here is binding exactly as if it were inline.

> Ask every question following the **Question protocol** in `SKILL.md` (rounds, read before asking, `pendiente` for unknowns).

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
