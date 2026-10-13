# Prompt — Agente: Generación Automática de Plan de Desarrollo

> Lee este archivo cuando el usuario pida generar un Plan de Desarrollo para cualquier proyecto.
> Eres un agente autónomo. Tu objetivo es producir un plan tan completo que el equipo QA pueda
> ejecutar cada caso de prueba sin ambigüedad, sin tener que preguntar al desarrollador.

---

## Filosofía

1. **Explora primero, pregunta después.** El código, git y configs ya tienen la mayoría de la info.
2. **Haz UNA sola ronda de preguntas** al usuario — agrúpalas todas en un solo mensaje, nunca hagas preguntas de una en una.
3. **Entre más detalle tenga el plan, mejor trabaja QA.** Cada escenario de prueba debe tener: condición de entrada, pasos, resultado esperado y cómo verificarlo (log, BD, respuesta HTTP, colección Postman).

---

## FASE 1 — Auto-descubrimiento del proyecto (ejecutar ANTES de preguntar nada)

### 1.1 Identidad y stack
```bash
# Java/Maven
grep -m3 "<artifactId>\|<version>\|<name>" pom.xml 2>/dev/null

# Node.js
node -e "const d=require('./package.json'); console.log(d.name, d.version)" 2>/dev/null

# Go
grep "^module\|^version" go.mod 2>/dev/null

# Rama y repositorio
git branch --show-current
git remote get-url origin
git config user.name && git config user.email
```

### 1.2 Qué cambió en esta rama
```bash
git log main..HEAD --oneline 2>/dev/null || git log master..HEAD --oneline
git diff main..HEAD --stat 2>/dev/null
git diff main..HEAD --name-only --diff-filter=A   # archivos nuevos
git diff main..HEAD --name-only --diff-filter=M   # archivos modificados
git log main..HEAD --format="- %s"               # mensajes de commits
```

### 1.3 Detectar el TIPO de cambio (esto define qué secciones del plan aplican)

```bash
# ¿Tiene endpoints REST?
grep -r "@GetMapping\|@PostMapping\|@PutMapping\|@DeleteMapping\|@RestController\|router\.\|app\.get\|app\.post" \
     src/ --include="*.java" --include="*.go" --include="*.ts" --include="*.js" -rl 2>/dev/null

# ¿Tiene scheduler / tareas programadas?
grep -r "@Scheduled\|@EnableScheduling\|cron\s*=\|time\.Tick\|setInterval\|node-cron\|quartz" \
     src/ --include="*.java" --include="*.go" --include="*.ts" -rl 2>/dev/null

# ¿Tiene cambios de BD? (migraciones, entidades, queries)
git diff main..HEAD --name-only | grep -iE "migration|flyway|liquibase|\.sql|V[0-9].*\.sql"
grep -r "@Entity\|@Table\|CREATE TABLE\|ALTER TABLE\|DROP TABLE" \
     src/ --include="*.java" --include="*.sql" -rl 2>/dev/null

# ¿Tiene mensajería / eventos / colas?
grep -r "@KafkaListener\|@RabbitListener\|@SqsListener\|pubsub\|EventBridge\|sns\|sqs\|kafka\|rabbitmq\|amqp" \
     src/ --include="*.java" --include="*.go" --include="*.ts" -rl 2>/dev/null

# ¿Tiene webhooks o integraciones externas?
grep -r "RestClient\|WebClient\|HttpClient\|fetch(\|axios\|RestTemplate\|Unirest\|http\.Post\|http\.Get" \
     src/ --include="*.java" --include="*.go" --include="*.ts" -rl 2>/dev/null

# ¿Tiene colección Postman?
find . -name "*.postman_collection.json" -o -name "*.postman_environment.json" 2>/dev/null

# ¿Tiene Swagger / OpenAPI?
find . -name "openapi*.yml" -o -name "swagger*.yml" -o -name "openapi*.json" 2>/dev/null
grep -r "@OpenAPIDefinition\|@Operation\|springdoc\|swagger" src/ --include="*.java" -rl 2>/dev/null

# ¿Tiene Docker / despliegue?
ls Dockerfile docker-compose*.yml .github/workflows/*.yml k8s/ 2>/dev/null

# Dependencias actualizadas
git diff main..HEAD -- pom.xml package.json go.mod requirements.txt 2>/dev/null \
  | grep "^[+-]" | grep -i "version\|\":\s*\""
```

### 1.4 Leer archivos clave según el tipo detectado
```bash
# Configuración principal
cat src/main/resources/application.yml 2>/dev/null || cat .env.example 2>/dev/null

# Scripts de despliegue
ls shell/*.sh scripts/*.sh deploy/*.sh 2>/dev/null

# Migraciones de BD
ls src/main/resources/db/migration/*.sql 2>/dev/null | sort

# Colección Postman
find . -name "*.postman_collection.json" -exec cat {} \; 2>/dev/null | python3 -c "
import json,sys
d=json.load(sys.stdin)
def items(col):
    for i in col.get('item', []):
        if 'item' in i: items(i)
        else: print(i.get('request',{}).get('method','?'), i.get('name',''))
items(d)" 2>/dev/null
```

---

## FASE 2 — Ronda única de preguntas al usuario

Con lo que encontraste en la Fase 1, formula UN SOLO mensaje con todas las preguntas pendientes.
Organízalas por categoría según el tipo de proyecto detectado:

### Preguntas SIEMPRE obligatorias
```
1. ¿Cuál es el número/URL del ticket Jira? (si no está en commits ni README)
2. ¿En qué carpeta quieres que guarde el Word y el PDF?
3. ¿Cuál es el país/subsidiaria del cliente? (PANAMA, COLOMBIA, etc.)
4. ¿Cuál es la prioridad del cambio? (ALTA / MEDIA / BAJA)
5. ¿Tienes un archivo .md con el alcance, cambios o escenarios ya redactados?
```

### Si detectaste endpoints REST
```
6. ¿Hay una colección de Postman actualizada para esta versión? ¿Cuál es la ruta?
7. ¿Cuál es la URL base del ambiente de pruebas (QA/TEST)?
8. ¿Qué método de autenticación usan los endpoints? (JWT, OAuth2, API Key, Basic Auth, ninguno)
9. ¿Hay headers obligatorios que QA debe enviar en cada request? (Authorization, Content-Type, country, channel, etc.)
10. ¿Hay ejemplos de request/response que debas incluir?
```

### Si detectaste scheduler / tareas programadas
```
11. ¿Cuál es el cron expression y cada cuánto se ejecuta?
12. ¿Cómo puede QA disparar la tarea manualmente para no esperar el cron?
13. ¿Qué tabla/recurso consulta y qué tabla/recurso actualiza?
14. ¿Cuál es el comportamiento esperado cuando NO hay datos pendientes?
15. ¿Cuál es el comportamiento esperado cuando SÍ hay datos pendientes?
16. ¿Tiene algún límite de registros por ejecución (batch size)?
```

### Si detectaste cambios de base de datos
```
17. ¿Cuáles son los scripts DDL/DML que deben ejecutarse antes del despliegue?
18. ¿Hay datos de prueba (INSERT) necesarios para que QA pueda probar?
19. ¿El cambio afecta datos existentes en producción? ¿Hay migración de datos?
20. ¿Cuál es el plan de rollback si falla?
21. ¿Hay índices, triggers o constraints nuevos?
```

### Si detectaste mensajería / eventos / colas
```
22. ¿Cuál es el nombre del topic/queue/exchange?
23. ¿Cuál es la estructura del mensaje/evento (payload de ejemplo)?
24. ¿Cómo puede QA publicar un mensaje de prueba manualmente?
25. ¿Qué pasa si el mensaje tiene formato inválido?
26. ¿Hay dead-letter queue o manejo de errores de mensajería?
```

### Si detectaste integraciones externas / webhooks
```
27. ¿Cuáles son las URLs de los servicios externos que se invocan?
28. ¿Hay mocks o stubs disponibles para las dependencias externas?
29. ¿Cómo simula QA un fallo del servicio externo?
30. ¿Qué pasa si el servicio externo no responde (timeout)?
```

### Si detectaste Swagger / OpenAPI
```
31. ¿Cuál es la URL del Swagger UI en el ambiente de pruebas?
32. ¿Se puede usar Swagger para ejecutar las pruebas o se requiere Postman?
```

### Si detectaste Docker / despliegue
```
33. ¿Hay variables de entorno que QA debe configurar antes de iniciar?
34. ¿Cuál es el comando exacto para desplegar?
35. ¿Cómo verifica QA que el servicio arrancó correctamente?
```

---

## FASE 3 — Construir el plan (con toda la información recolectada)

### 3.1 Leer el .md del usuario (si lo proporcionó)
Extraer: resumen ejecutivo, cambios, tipos de entidades/transacciones/endpoints, escenarios, ambiente, parámetros.

### 3.2 Sección de Pruebas — objetivo y nivel de detalle

El plan de desarrollo es un documento **informativo**. La sección de pruebas no reemplaza el trabajo de QA —
su objetivo es darle a QA todo el contexto necesario para que **ellos creen sus propios casos de prueba**
sin tener que ir a preguntarle nada al desarrollador.

**Lo que el plan debe dejarle claro a QA:**

- Qué flujos existen y cómo funcionan (diagramas)
- Qué tipos de transacciones/entidades/endpoints fueron modificados
- Cuáles son los comportamientos esperados para cada tipo (incluyendo casos especiales)
- Qué tablas de BD se ven afectadas y con qué estados
- Qué parámetros de configuración influyen en el comportamiento
- Cómo acceder al ambiente, ver logs e interpretar respuestas
- Qué colecciones Postman / Swagger están disponibles

**Estructura de cada escenario en la tabla de Pruebas Unitarias:**

| Campo | Qué escribir |
|-------|-------------|
| N° | EST-XX numerado |
| Alcance | Una línea: qué funcionalidad cubre este escenario |
| Descripción del caso | Condición de entrada + comportamiento esperado + qué debe verificar QA (log, BD, respuesta HTTP) |

> El nivel de detalle correcto es: QA lee el escenario, entiende qué debe probar y sabe cómo
> verificar que funciona. No es un script paso a paso — es contexto suficiente para que QA
> diseñe su propio caso.

**Cobertura mínima por tipo de cambio (qué escenarios no pueden faltar):**

- **REST API:** flujo normal por endpoint, autenticación inválida, parámetros requeridos ausentes, recurso no encontrado, respuesta de error del servidor
- **Scheduler:** ejecución con registros pendientes, ejecución sin registros, comportamiento al alcanzar el máximo de reintentos
- **BD:** inserción/actualización correcta, registro duplicado, violación de constraint
- **Mensajería:** mensaje con formato válido, mensaje con formato inválido, servicio destino no disponible
- **Integración externa:** respuesta exitosa del servicio externo, respuesta de error 4xx/5xx, timeout

---

## FASE 4 — Template base del Word

**SIEMPRE clonar (nunca crear desde cero):**
```
/Users/galopez/Library/CloudStorage/OneDrive-NovopaymentInc/MaquinaD/Novopayment/UtilidadesNovopayment/plantillas/Plan_de_Desarrollo_BASE.docx
```

**Entorno Python:**
```bash
python3 -m venv /tmp/docx_env && /tmp/docx_env/bin/pip install python-docx -q
/tmp/docx_env/bin/python3 mi_script.py
```

### Mapeo de secciones del Word

| Heading del Word | Contenido |
|---|---|
| Historial de cambios → Tabla [0] | V.1, fecha hoy, descripción breve, autor (git config) |
| Control de Revisión → Tabla [1] | Descripción completa del cambio |
| Alcance | Qué hace el proyecto, qué resuelve esta versión, URL ticket |
| Definiciones | Términos separados por \| (siglas, tecnologías, estados BD) |
| Estructura | Arquitectura general, capas, tipo de servicio |
| Construcción | Stack tecnológico, enfoque de implementación |
| Descripción de Clases | **IMAGEN** PlantUML — diagrama de componentes |
| Diagramas de flujo | **IMÁGENES** PlantUML — uno por flujo principal + scheduler si aplica |
| Estructura de datos | **IMAGEN** PlantUML — ER con tablas y relaciones |
| Nombre del esquema | Motor de BD + nombre del esquema |
| Ajustes realizados → Tabla [2] | Por componente: qué cambió (de git diff --stat + commits) |
| Pruebas Unitarias → Tabla [3] | Todos los escenarios EST-XX (expandir filas con copy_row_and_fill) |
| Datos para Config e Instalar → Tabla [4] | Izq: servidor, rutas, comandos log, params. Der: pasos instalación |
| Requisitos Certificación → Tabla [5] | Ticket, repo, país, prioridad, tipo |

**Localizar headings por texto (los índices cambian al insertar imágenes):**
```python
def find_heading(doc, text):
    for i, p in enumerate(doc.paragraphs):
        if text.lower() in ''.join(r.text for r in p.runs).lower():
            return i, p
    return None, None
```

---

## FASE 5 — Diagramas PlantUML

PlantUML: `/opt/homebrew/bin/plantuml` | Output: `/tmp/plantuml_diagrams/`

### Skin base Novopayment (usar en todos los diagramas)
```plantuml
skinparam backgroundColor #FFFFFF
skinparam defaultFontSize 12
skinparam arrowThickness 2
skinparam roundcorner 10
skinparam componentBackgroundColor #D6E4F0
skinparam componentBorderColor #1F3864
skinparam entityBackgroundColor #D6E4F0
skinparam entityBorderColor #1F3864
skinparam sequenceParticipantBackgroundColor #D6E4F0
skinparam sequenceParticipantBorderColor #1F3864
skinparam arrowColor #2E74B5
skinparam noteBackgroundColor #FFF3CD
skinparam noteBorderColor #F0A500
skinparam sequenceGroupBackgroundColor #EBF5FF
skinparam packageBackgroundColor #EBF5FF
```

### Qué diagrama usar según el tipo
| Tipo | Diagrama | Cuándo |
|------|---------|--------|
| Flujo entre servicios/BD | Secuencia (`participant`) | Siempre — flujo principal |
| Scheduler/batch | Secuencia con `loop` y `alt` | Si hay scheduler |
| Clases/módulos | Componentes (`[Clase]`, `package`) | Descripción de Clases |
| Tablas de BD | Entidad-Relación (`entity`) | Estructura de datos |
| Lógica de negocio compleja | Actividad (`start / if / stop`) | Flujos de decisión |

```bash
mkdir -p /tmp/plantuml_diagrams
plantuml /tmp/plantuml_diagrams/nombre.puml -png -DPLANTUML_LIMIT_SIZE=8192
```

---

## FASE 6 — Helpers Python

```python
import shutil, copy
from docx import Document
from docx.shared import Inches
from docx.oxml.ns import qn
from docx.oxml import OxmlElement
from lxml import etree

def replace_para(p, text):
    runs = p.runs
    if runs:
        runs[0].text = text
        for r in runs[1:]: r.text = ''
    else:
        p.add_run(text)

def clear_para_content(p):
    for child in list(p._element):
        if child.tag != qn('w:pPr'):
            p._element.remove(child)

def cell_replace(cell, text):
    for i, p in enumerate(cell.paragraphs):
        if i == 0:
            runs = p.runs
            if runs:
                runs[0].text = text; [setattr(r, 'text', '') for r in runs[1:]]
            else:
                p.add_run(text)
            text = ''
        else:
            [setattr(r, 'text', '') for r in p.runs]

def cell_clear_and_set(cell, text):
    """Usar en Tabla [5] — evita duplicar contenido del template anterior."""
    tc = cell._tc
    for p in tc.findall(qn('w:p')): tc.remove(p)
    new_p = etree.SubElement(tc, qn('w:p'))
    new_r = etree.SubElement(new_p, qn('w:r'))
    new_t = etree.SubElement(new_r, qn('w:t'))
    new_t.text = text

def copy_row_and_fill(table, src_idx, values):
    new_tr = copy.deepcopy(table.rows[src_idx]._tr)
    table._tbl.append(new_tr)
    row = table.rows[-1]
    for i, v in enumerate(values):
        if i < len(row.cells): cell_replace(row.cells[i], v)
    return row

def insert_image_after(doc, p, img_path, width_inches=6.2):
    new_p = OxmlElement('w:p')
    pPr = OxmlElement('w:pPr')
    jc = OxmlElement('w:jc')
    jc.set(qn('w:val'), 'center')
    pPr.append(jc); new_p.append(pPr)
    p._element.addnext(new_p)
    tmp = doc.add_paragraph()
    tmp.add_run().add_picture(img_path, width=Inches(width_inches))
    for child in list(tmp._element):
        if child.tag != qn('w:pPr'): new_p.append(child)
    tmp._element.getparent().remove(tmp._element)

def remove_extra_empty_paras(doc):
    prev_empty = False
    to_remove = []
    for p in doc.paragraphs:
        txt = ''.join(r.text for r in p.runs).strip()
        has_img = p._element.find('.//{http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing}inline') is not None
        is_empty = not txt and not has_img and 'Heading' not in p.style.name
        if is_empty and prev_empty: to_remove.append(p)
        prev_empty = is_empty
    for p in to_remove: p._element.getparent().remove(p._element)
```

---

## FASE 7 — Exportar a PDF

```bash
DOCX="/ruta/Plan_de_Desarrollo_TICKET.docx"
PDF="/ruta/Plan_de_Desarrollo_TICKET.pdf"
osascript <<EOF
tell application "Microsoft Word"
    activate
    open POSIX file "${DOCX}"
    delay 4
    set theDoc to active document
    save as theDoc file name "${PDF}" file format format PDF
    close theDoc saving no
end tell
EOF
```

---

## FASE 8 — Checklist final

### General
- [ ] Sin contenido residual del template anterior (buscar keywords del proyecto anterior)
- [ ] Tabla [5] fila 2: URL ticket correcto | fila 10: URL repositorio correcto
- [ ] Historial y Control de Revisión: fecha y autor actualizados
- [ ] Diagramas PlantUML como imágenes (no como texto/código)
- [ ] Sin páginas en blanco (remove_extra_empty_paras ejecutado)
- [ ] PDF generado desde el Word final

### Escenarios de prueba (QA)
- [ ] Los escenarios son informativos — describen el comportamiento esperado, no pasos de script
- [ ] Cada escenario tiene alcance claro y describe qué debe verificar QA (log, BD, HTTP, etc.)
- [ ] Hay cobertura de: flujo normal + casos especiales + comportamientos de error documentados en el código
- [ ] Si hay Postman: la sección Config/Instalar incluye ruta de la colección y cómo importarla
- [ ] Si hay scheduler: está documentado el cron, qué procesa y cómo verificar su ejecución
- [ ] Si hay BD: están documentadas las tablas afectadas, los estados posibles y constraints relevantes
- [ ] Si hay integración externa: está documentado qué pasa cuando falla
- [ ] Si hay mensajería: está documentada la estructura del mensaje y el nombre del topic/queue
- [ ] La sección "Datos para Configurar e Instalar" tiene comandos reales ejecutables por QA
- [ ] Con solo leer el plan, QA sabe qué probar sin tener que consultar al desarrollador
