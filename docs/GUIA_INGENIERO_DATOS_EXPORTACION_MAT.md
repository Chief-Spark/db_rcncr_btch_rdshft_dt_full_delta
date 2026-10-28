# Guía para construir SPs de exportación sobre las 7 tablas dominio

**Para quién es:** un ingeniero de datos que va a escribir procedimientos
almacenados en Redshift que lean las siete tablas dominio de Reconocer y
produzcan salidas (planos, vistas, extractos, cubos).

**Qué asume:** que no conoces el repo. No asume que conozcas Teradata ni el
legado — para exportar no hace falta.

---

## 1. Los tres repositorios y cómo interactúan

El despliegue a Redshift **no es un repositorio, son tres**, y el orden entre
ellos no es una convención: es una dependencia real.

| Orden | Repositorio | `global.type` | Qué contiene |
|---|---|---|---|
| **1** | `db_rcncr_btch_rdshft_strct` | `structure` | **Solo DDL**: tablas, vistas, catálogos, funciones. Ningún procedimiento, ningún dato |
| **2** | `db_rcncr_btch_rdshft_pgm` | `program` | **Solo procedimientos almacenados** |
| **3** | `db_rcncr_btch_rdshft_dt` | `data` | **Semillas, runners y validaciones.** Es el que produce la evidencia de QA |

**Tu SP de exportación va en `pgm`. Si necesita una tabla o una vista nueva,
ese DDL va en `strct` y se despliega ANTES.** Si lo pones al revés, el `CREATE
PROCEDURE` pasa igual (Redshift difiere la semántica) y revienta en la primera
invocación con `relation ... does not exist`.

### Cómo se ejecuta un despliegue

Cada repo lleva un paquete bajo `deploy/redshift/<ID-JIRA>/` con esta forma:

```
deploy/redshift/SLCOPRBA-1353/
├── deploy.par          <- lista ORDENADA de los scripts a ejecutar
├── rollback.par        <- la MISMA lista en orden INVERSO
├── SQL/                <- los scripts de despliegue
└── RevSQL/             <- el reverso de cada uno, mismo basename
```

Reglas del paquete, cada una con el código de error que te cae si la rompes:

| Regla | Si la rompes |
|---|---|
| `rollback.par` es el reverso exacto de `deploy.par`, línea por línea | el build no cuadra la paridad |
| El basename en `RevSQL/` es **idéntico** al de la línea de `rollback.par`, sin sufijo `_rev` | `REDSHIFT:219` |
| Los `.par` van en **UTF-8 sin BOM** | `REDSHIFT:207` |
| Todo `UPDATE`/`DELETE` de nivel superior lleva `WHERE` explícito (o usa `TRUNCATE`) | `REDSHIFT:232` |
| Cualquier error SQL durante el despliegue | `REDSHIFT:112` — **es lo único que tumba el build hoy** |

### El ciclo de Jenkins, y el detalle que más sorprende

```
RLLBCK_PRECHECK → DDL_1 → DPLY → DDL_2 → RLLBCK_FINAL → DDL_3 → compare → DPLY
```

**El `DPLY` aparece DOS veces.** Tu script se ejecuta dos veces sobre el mismo
clúster en un solo build, y entre las dos pasadas hay un rollback completo que
también se ejecuta. Consecuencias directas para tu SP:

1. **Tiene que ser idempotente.** Si inserta, la segunda pasada no puede
   duplicar. Un `INSERT` suelto duplica; usa `DELETE` + `INSERT` acotado por
   lote, o un patrón de UPSERT.
2. **Lo que una corrida escribe, el reverso lo tiene que borrar.** Si creas una
   tabla de control nueva, su `TRUNCATE` entra en el mismo commit que su DDL.
3. **La primera pasada puede salir verde y la segunda fallar.** Ya pasó: un
   watermark heredado de la primera pasada dejó la ventana vacía en la segunda.

### El traslado a Bitbucket

GitHub es el repo de trabajo; **Bitbucket es el repo de despliegue y es el que
Jenkins construye**. Al trasladar va **solo** `deploy/redshift/` y el
`.jenkins.yml`. No van `docs/`, ni `banco/`, ni `validar.sh`, ni este archivo.

El `.jenkins.yml` es lo que **elige el pipeline**, y Jenkins lo lee de la rama
de Bitbucket:

```yaml
tech: database          # si dice 'terraform' el build se va al pipeline
language: redshift      # equivocado y muere en sonarQubeScan sin mirar SQL
application: dba_rncr_batch
type: struct | program | data
order: 1 | 2 | 3
```

**Después de empujar a Bitbucket, verifica el remoto, no el índice local:**

```bash
git ls-tree -r --name-only origin/<rama> -- deploy/redshift | wc -l
```

`git ls-files` lee tu índice local y **no sirve** para esto: Jenkins construye
lo que hay en el remoto.

---

## 2. Integración con Jira

Hay tres puntos de contacto, y los tres se rompen por motivos distintos.

### 2.1 La rama debe llevar el ID de la subtarea

Jenkins extrae el issue key del nombre de la rama. Una rama sin él falla con
`JENKINS:104` / `JENKINS:105`.

```
feature/SLCOPRBA-1450-pgm-reales      ✅
feature/export-plano                  ❌  sin ID, el build no arranca
```

### 2.2 El commit debe llevar el issue key en el MENSAJE

Esto es lo que más se olvida. **El panel de desarrollo de Jira enlaza los
commits por el issue key que aparece en el MENSAJE del commit, no por el nombre
de la rama.** Si el mensaje no lo trae, el trabajo existe en Bitbucket pero en
Jira la incidencia aparece vacía y parece que nadie hizo nada.

```
SLCOPRBA-1450: SP de exportación de contactabilidad top-N      ✅
Ajuste del export                                              ❌
```

### 2.3 El `SNOW ID`, que es aviso y no error

En el log vas a ver:

```
JIRA:110 The issue 'SLCOPRBA-1353' in the 'SNOW ID' field is empty or invalid
```

**No bloquea.** No lleva código de error y el build continúa hasta
`Finished: SUCCESS`. Es el campo de ServiceNow sin diligenciar en la
incidencia; se llena en Jira, no en el repo.

### 2.4 Lo que el pipeline hace solo

En el stage `After deploy`, Jenkins consulta la incidencia (`jiraGetIssue`) y
crea la rama de promoción en Bitbucket (`bitbucketCreateBranch`). Si ya existe
imprime `BITBUCKET:319 'La rama demo/<ID> ya existe'` y sigue. No hay que
hacer nada.

---

## 3. Buenas prácticas: los errores ya pagados

Esta sección es la que te ahorra días. Cada línea costó un build roto.

### 3.1 Firma y estructura del procedimiento

- **Si el Framework Batch va a invocar tu SP, la firma es obligatoria y son
  SEIS parámetros `VARCHAR`, en este orden:** `in_solicitud`,
  `in_nit_suscriptor`, `in_path_archivo`, `in_nemotecnico` (= MODO),
  `in_id_facturacion` (= LOTE), `in_fecha_ejecucion` (= FECHA). Los tres
  primeros no se usan y aun así forman parte de la firma. **Nunca la cambies.**
- **`NONATOMIC` en toda la cadena de `CALL`.** Mezclar modos rompe con
  `P0001: created in one transaction mode cannot be invoked from another`.
- **El rollback de un procedimiento es `DROP PROCEDURE nombre(<firma exacta>);`
  SIN `IF EXISTS`** — Redshift da `syntax error at or near "EXISTS"`. La firma
  del `DROP` repite la del `CREATE` carácter por carácter, incluido el `INOUT`.
  Tablas y vistas **sí** usan `IF EXISTS`.

### 3.2 Convenciones del repo

- **UTF-8 sin BOM y ASCII sin acentos** dentro de `deploy/`. `docs/` y
  `README.md` quedan fuera a propósito (son prosa en castellano).
- DDL idempotente: `CREATE TABLE IF NOT EXISTS`, `CREATE OR REPLACE VIEW`.
- Vistas con `WITH NO SCHEMA BINDING`, para que el orden de despliegue no las
  rompa.
- **Nunca `GRANT ... TO PUBLIC`. Nunca `DROP SCHEMA ... CASCADE`**: `bdm_datos`
  es compartido con otros equipos.
- Tablas pequeñas en `DISTSTYLE ALL`, con la justificación escrita al lado.

### 3.3 Trampas de Redshift que el motor no te avisa a tiempo

| Trampa | Qué pasa |
|---|---|
| **`DELTA` es palabra reservada** (viene de los codificados `DELTA`/`DELTA32K`) | un `AS delta` compila en PostgreSQL y Redshift lo rechaza al desplegar. Lo mismo con `RAW`, `ENCODE`, `TOP`, `TAG`, `PERCENT`, `SYSDATE`, `DISTKEY`, `SORTKEY` |
| **`RAISE` admite VARIABLES, no expresiones** | `RAISE INFO 'x %', NULLIF(a,b)` es error de **sintaxis en el propio `CREATE`**. Mueve la expresión al `SELECT` que alimenta la variable |
| **Subconsulta escalar en la lista del `SELECT` con `EXISTS` correlacionado** | Redshift la **rechaza** en ejecución: `XX000: This type of correlated subquery pattern is not supported`. Materializa los conteos en una tabla de apoyo y únela con `CROSS JOIN` |
| **`SUM()` sobre cero filas devuelve `NULL`, no 0** | guarda con `COUNT(*) = 0` primero y `COALESCE` después |
| **`ORDER BY ... DESC` pone `NULLS FIRST` por defecto** | escribe `NULLS LAST` explícito. Teradata hace lo contrario |
| **`COUNT(DISTINCT)` no vale como función de ventana** | usa `MIN()/MAX() OVER` |
| **Todos los `LISTAGG` del mismo `SELECT` comparten `WITHIN GROUP`** | y `LISTAGG(DISTINCT ...)` no convive con `COUNT(DISTINCT ...)` en el mismo `SELECT` |
| **`UPDATE ... FROM`: el destino no admite alias** | |
| **`REPLACE(x, NULL, '')` devuelve `NULL`** | |
| **`generate_series` es leader-node only** | usa `bdm_stage.mock_numeros` |
| **`EXISTS` no vale en la lista del `SELECT`** | en el `WHERE` sí |
| **El `DISTKEY` tiene que ser una columna de la lista del `SELECT`**, no un alias | |
| **El `CAST` de la primera rama de un `UNION ALL` fija el tipo del nodo** | |

### 3.4 Anchos de columna: el defecto que solo el dato real revela

`VARCHAR(n)` en Redshift son **n BYTES**, y `LEFT()` corta **CARACTERES**. 200
caracteres acentuados son hasta 400 bytes. **Acota siempre con `CAST` explícito
al ancho de la columna destino**, nunca con `LEFT()`. Redshift **no** trunca
solo al insertar: lanza `XX000: Value too long for type character varying(n)`.

Y **cuando una vista declara un ancho, tiene que ser el de su tabla.** Una
vista que castea a `VARCHAR(100)` contra una columna `VARCHAR(30)` da el mismo
error sin que la fuente tenga nada que ver.

> **El error se repite en clase, no en incidente.** Cuando encuentres uno de
> estos, barre **todo** el paquete buscando el patrón el mismo día. La primera
> vez solo falla la primera columna porque el motor para en el primer error.

### 3.5 Antes de empujar

```bash
./validar.sh
```

Chequea ASCII, BOM, `$$` y paréntesis balanceados, simetría de los `.par`, que
toda entrada tenga su archivo, `WHERE` en `UPDATE`/`DELETE`, `LISTAGG`, las
reservadas, los `RAISE` con expresiones y las subconsultas en la proyección.
Sale distinto de cero si algo falla.

**Y una que `validar.sh` no caza:** una comilla simple sin escapar dentro de un
literal deja la tabla **vacía** sin error. Si tu SP carga un catálogo, cuenta
las filas después de desplegar.

---

## 4. Las siete tablas dominio, tal como quedaron

Todas viven en **`bdm_datos`**. El DDL completo está en el repo `strct`, bajo
`deploy/redshift/<ID>/SQL/`.

> **El discriminador entre dato real y mock es el LOTE.** Real = `1356301`.
> Mock = `13566xx`. En `score_ordenamiento` el mock además cae en la banda
> `id_buro_persona BETWEEN 9000000 AND 9999999`, que hay que excluir.

### 4.1 `mat_info_basica` — una fila por persona

`DISTKEY(id)` · `SORTKEY(id)` · QA: **57.813 filas / 57.813 personas**

| Columna | Tipo | Nota |
|---|---|---|
| `id` | BIGINT | **= `id_buro_persona`.** Es la llave con la que se une todo |
| `primer_nombre` · `segundo_nombre` | VARCHAR(100) | |
| `primer_apellido` · `segundo_apellido` | VARCHAR(100) | |
| `nombre_completo` | VARCHAR(200) | poblada al 98,7% en QA |
| `cod_tipo_ident_fte` | VARCHAR(20) | |
| `tipo_identificacion` | VARCHAR(30) | |
| `numero_identificacion` | BIGINT | el documento. Poblada al 100% |
| `estado_documento` | VARCHAR(20) | |
| `rango_edad` | VARCHAR(25) | |
| `lugar_expedicion` · `departamento_expedicion` | VARCHAR(100) | |
| `fecha_expedicion` | DATE | **solo 1,5% poblada** — el dato no existe en origen |
| `genero` | VARCHAR(508) | `M` / `F` / `O` / vacío. 34% vacío en QA |
| `ciiu` | VARCHAR(20) | |
| `actividad_economica` | VARCHAR(500) | |
| `razon_social` | VARCHAR(500) | derivada: el nombre completo cuando el tipo es NIT |
| `pagina_web` | VARCHAR(100) | **siempre NULL**: no existe en el origen |
| `mosaic_id` | INTEGER | **siempre NULL**: fuera por decisión legal |
| `cod_pin_persona` | BIGINT | |
| `rut` | VARCHAR(1) | |
| `lote` · `fecha_actualizacion` · `usuario_bd` | | control |

### 4.2 `mat_info_ubicacion` — una fila por ubicación

`DISTKEY(id)` · `SORTKEY(id)` · QA: **74.237 filas / 51.682 personas**

Las 45 columnas; las que te interesan para exportar:

| Columna | Tipo | Nota |
|---|---|---|
| `id` | BIGINT | llave de la fila |
| `info_basica` | BIGINT | **= `mat_info_basica.id`.** Por aquí se une a la persona |
| `dato` | VARCHAR(201) | **el valor**: la dirección compuesta |
| `clase` | VARCHAR(5) | `DIR` / `TEL` / `CEL` / `EMAIL` — **ver el aviso de §5** |
| `orden` | INTEGER | el orden de prioridad que produce el Ordenamiento |
| `tipo` · `zona` | VARCHAR(30) | **NULL**: faltan sus catálogos |
| `ciudad` · `departamento` | VARCHAR(30) | |
| `codigo_dane` | VARCHAR(20) | |
| `latitud` · `longitud` | DECIMAL(10,6) | |
| `estrato` | VARCHAR(10) | **NULL**: contrato GEO sin pinar |
| `barrio` · `localidad` · `codigo_postal` | | **NULL**: contrato GEO sin pinar |
| `indicativo` | VARCHAR(20) | **NULL**: falta `V_TELEFONO_FIJO` |
| `reportado_desde` · `ultimo_reporte` · `fuente` · `numero_reportes` · `numero_entidades` | | **NULL / 0 literales por esta ruta.** No es un defecto: el legado los emite así. Sus valores reales viven en `mat_ubicacion_agregada` |
| `es_tipo_crr` · `es_tipo_res` · `es_tipo_lab` | VARCHAR(1) | `1`/`0` |
| `es_tipo_ppl` · `_agn` · `_suc` · `_est` · `_cdi` | VARCHAR(1) | **NULL literal** en el legado |
| `cod_dw_ubic` · `cod_dw_direccion_fisica` · `cod_dw_telefono` · `cod_dw_direccion_electronica` | BIGINT | llaves de origen |
| `ind_unificacion` | INTEGER | |
| `cod_pin_persona` | BIGINT | |
| `flag_op` | SMALLINT | `1`=alta, `2`=cambio, `3`=baja |

### 4.3 `mat_ubicacion_agregada` — una fila por persona + ubicación

`DISTKEY(info_basica)` · `SORTKEY(info_basica, ubicacion_dato)` · QA: **69.231 filas**

**Es la que SÍ trae las cinco columnas de reporte** que `mat_info_ubicacion`
deja en blanco. Si tu export necesita «desde cuándo» y «cuántas entidades»,
**la fuente es esta, no la anterior.**

| Columna | Tipo | Nota |
|---|---|---|
| `info_basica` | BIGINT | = `mat_info_basica.id` |
| `tipo_identificacion` · `numero_identificacion` | | |
| `ubicacion_dato` | VARCHAR(201) | el valor |
| `ubicacion_clase` | VARCHAR(5) | |
| `ubicacion_orden` | INTEGER | |
| `ubicacion_reportdesde` · `ubicacion_ultreporte` | DATE | **pobladas** |
| `ubicacion_numentidades` · `ubicacion_numreportes` | INTEGER | **pobladas** |
| `ubicacion_ciudad` · `_departamento` · `_codigodane` | | |
| `ubicacion_latitud` · `_longitud` | DECIMAL(10,6) | |
| `ciudad` · `departamento` · `codigo_dane` | | de la persona |
| `tipo` | VARCHAR(30) | **cadena agregada**: `'R - L - C'` |
| `fuente` | VARCHAR(30) | **cadena agregada**: `'SUS - CAM'` |
| `id` | VARCHAR(1000) | **lista de `cod_dw_ubic` separada por comas**, no un número |
| `ubicacion_tipocuenta` · `_indicativo` · `_estrato` · `_zona` · `_barrio` · `_localidad` · `_codigopostal` · `cod_pais` | | **NULL**: catálogos no entregados |

> **`tipo`, `fuente` e `id` son cadenas agregadas.** Si las tratas como escalares
> el export sale mal. `id` puede traer varias llaves separadas por comas.

### 4.4 `mat_info_actividad_economica` — N filas por persona

`DISTKEY(info_basica_id)` · `SORTKEY(info_basica_id)` · QA: **121.216 filas / 57.581 personas**

| Columna | Tipo | Nota |
|---|---|---|
| `id` | INTEGER | correlativo, único |
| `info_basica_id` | BIGINT | = `mat_info_basica.id` |
| `ciiu` | VARCHAR(20) | nunca NULL (el proceso filtra por CIIU informado) |
| `actividad_economica` | VARCHAR(500) | **NULL**: falta el catálogo CIIU |
| `version` | INTEGER | **NULL**: idem |
| `fecha_reporte` | DATE | |
| `tipo_identificacion` · `numero_identificacion` | | |

El grano es **una fila por (CIIU, persona)**, sin duplicados.

### 4.5 `mat_info_contactabilidad` — una fila por ubicación

`DISTKEY(ubicacion_id)` · `SORTKEY(ubicacion_id)` · QA: **74.237 filas**

> **Solo 2 de 12 columnas se pueblan, y las dos con OTRA semántica.** No existe
> la fuente de eventos de gestión. **No construyas un export de contactabilidad
> sobre esta tabla sin leer antes esta nota.**

| Columna | Estado |
|---|---|
| `ubicacion_id` | **poblada** (= `cod_dw_persona_ubic`) |
| `fecha_ultimo_contacto` | **poblada, pero es `ContactEventLastUpdated`** — no es la fecha de una gestión |
| `reportado_por` | **poblada, pero es quién REPORTÓ**, no quién gestionó |
| `id` · `contactabilidad` · `fecha_gestion` · `mejor_dia_gestion` · `mejor_hora_gestion` · `sector` · `peso` · `mejor_resultado_3meses` · `mejor_resultado_6meses` | **NULL** — el hecho no se midió |

### 4.6 `mat_info_movilidad` — N eventos por persona

`DISTKEY(info_basica_id)` · `SORTKEY(info_basica_id, novedad)` · QA real: **0 filas**

| Columna | Tipo | Nota |
|---|---|---|
| `id` | BIGINT | derivada |
| `info_basica_id` | BIGINT | = `mat_info_basica.id` |
| `fecha` | DATE | cuándo se detectó el cambio |
| `novedad` | VARCHAR(1000) | `Cambio de Direccion` / `de Ciudad` / `de Estrato` |
| `novedad_2` | VARCHAR(30) | código: `CAM_LOC` / `CAM_CIU` / `CAM_EST` |
| `descripcion` | VARCHAR(100) | la frase larga del catálogo |

**Cero filas es correcto, no es un defecto.** Es un delta contra una foto
anterior: una persona vista por primera vez no se mudó. Se llenará cuando haya
un cambio real en origen (dirección, ciudad, DANE o estrato).

### 4.7 `mat_info_punto_interes` — N puntos por ubicación

`DISTKEY(ubicacion_id)` · `SORTKEY(ubicacion_id, id)` · QA real: **0 filas**

| Columna | Tipo | Nota |
|---|---|---|
| `id` | BIGINT | derivada |
| `ubicacion_id` | BIGINT | **= `cod_dw_ubic`**, no la relación persona-ubicación |
| `nombre` | VARCHAR(200) | |
| `distancia` | INTEGER | metros |
| `tipo` | VARCHAR(30) | código homologado |
| `descripcion_tipo_punto_interes` | VARCHAR(1000) | valor crudo |
| `latitud` · `longitud` | VARCHAR(40) | **del punto de interés**, y son VARCHAR por contrato |
| `nombre_entidad` · `nit_entidad` | | **NULL**: falta la fuente |

**Cero filas es por una dependencia de infraestructura, no por código**: lee de
`geo_distancias`, que solo llena la respuesta de ArcGIS, y el `UNLOAD` a S3
está bloqueado por el rol IAM.

---

## 5. Top 3, Top 5, Top X: de qué tabla sale el ranking

Esta es la pregunta que más se contesta mal, así que va directa.

### La respuesta corta

```
bdm_datos.score_ordenamiento    ← la tabla del ranking
  lugar = 1  es el MEJOR de ese canal para esa persona
  lugar = 2, 3, 4 ...           van descendiendo por score
```

El `lugar` es un `ROW_NUMBER() OVER (PARTITION BY persona, canal ORDER BY score
DESC)`. Está certificado con dato: en QA, los **289.800** grupos
`(persona, canal)` tienen el lugar 1 en el score máximo, **sin huecos y sin
repetidos**.

| Columna de `score_ordenamiento` | Tipo |
|---|---|
| `cod_dw_persona_ubic` | BIGINT |
| `cod_pin_persona` | BIGINT |
| `id_buro_persona` | BIGINT |
| `canal` | VARCHAR(10) — `DIR` / `TEL` / `CEL` / `EMA` |
| `score` | DECIMAL(18,4) |
| `lugar` | INTEGER |

`DISTKEY(id_buro_persona)` · `SORTKEY(id_buro_persona, canal, lugar)` — el
sortkey ya está pensado para esta consulta: filtrar por persona y canal y cortar
por lugar es un barrido secuencial.

### ⚠️ Las dos trampas

**1. `score_ordenamiento` NO guarda el número de teléfono ni el correo.**
Guarda la **llave** (`cod_dw_persona_ubic`), no el valor. Para el dato hay que
unir con `bdm_tempo.v_xpm_contacto_canal`, **y la llave de unión son DOS
columnas**: `(cod_dw_persona_ubic, canal)`. Con solo la primera se mezclan
canales que comparten reporte.

**2. `mat_info_ubicacion` parece el atajo y NO sirve para los cuatro canales.**
Trae `dato`, `clase` y `orden` en la misma fila, pero **en la vía real `clase`
es `DIR` en el 100%**: teléfonos, celulares y correos viven en otra tabla y otro
grano, y traerlos exige un `UNION ALL` que todavía no está portado. La prueba
es el conteo: `mat_info_ubicacion` = 74.237 = exactamente las filas de la RPU.

Compruébalo antes de diseñar tu export:

```sql
SELECT clase, COUNT(*) FROM bdm_datos.mat_info_ubicacion GROUP BY clase;
```

**Y ojo al literal del canal, que NO es el mismo en las dos tablas:**

| Tabla | Columna | Valor del correo |
|---|---|---|
| `score_ordenamiento` · `rpu_orden_prioridad` · `v_xpm_contacto_canal` | `canal` | **`EMA`** |
| `mat_info_ubicacion` · `mat_ubicacion_agregada` | `clase` | **`EMAIL`** |

Un `JOIN ... ON clase = canal` devuelve cero filas para correo y nadie se entera.

### El patrón de consulta: Top X por canal

```sql
-- Top N de cada canal para una persona, con el valor del contacto.
-- Cambia el 3 por el N que necesites. Un solo barrido.
SELECT s.id_buro_persona,
       s.cod_pin_persona AS documento,
       s.canal,
       s.lugar,
       s.score,
       c.valor_contacto
  FROM bdm_datos.score_ordenamiento s
  JOIN bdm_tempo.v_xpm_contacto_canal c
    ON  c.cod_dw_persona_ubic = s.cod_dw_persona_ubic
    AND c.canal               = s.canal          -- LAS DOS columnas
 WHERE s.lugar <= 3                               -- <- el Top X
   AND s.id_buro_persona NOT BETWEEN 9000000 AND 9999999   -- fuera el mock
 ORDER BY s.id_buro_persona, s.canal, s.lugar;
```

**No necesitas un `ROW_NUMBER` propio.** El `lugar` ya viene calculado y
certificado; recalcularlo sobre `score` te expone a un criterio de desempate
distinto del oficial.

### Qué esperar por canal

Volumetría de QA (`#196`) y DEV (`#491`), para que dimensiones el export:

| Canal | Filas (DEV) | Personas (DEV) | `lugar_max` |
|---|---|---|---|
| `DIR` | 64.393 | 58.642 | 47 |
| `EMA` | 59.756 | 58.485 | 57 |
| `CEL` | 48.493 | 47.978 | 5 |
| `TEL` | 12.600 | 10.746 | 40 |
| **Suma** | **185.242** | | |

**El árbol se abre, no se estrecha:** los cuatro canales suman más que las
relaciones de entrada porque `DIR` sale de la RPU pero `TEL`, `CEL` y `EMA`
salen de `contacto_canal`, que tiene una fila por canal y no por ubicación.

**Y `lugar_max` te dice cuánto pedir de verdad:** con `CEL` topando en 5, un
«Top 10 de celulares» no existe para nadie. Un **Top 3** cubre la práctica
totalidad de los casos en los cuatro canales.

### Si solo quieres el mejor de cada canal

```sql
SELECT s.id_buro_persona, s.canal, c.valor_contacto, s.score
  FROM bdm_datos.score_ordenamiento s
  JOIN bdm_tempo.v_xpm_contacto_canal c
    ON c.cod_dw_persona_ubic = s.cod_dw_persona_ubic AND c.canal = s.canal
 WHERE s.lugar = 1
   AND s.id_buro_persona NOT BETWEEN 9000000 AND 9999999;
```

### La tabla puente, por si la necesitas

`bdm_datos.rpu_orden_prioridad` lleva el orden ya escrito de vuelta contra la
relación persona-ubicación: `cod_dw_persona_ubic`, `id_buro_persona`, `canal`
(**VARCHAR(3)**), `orden_prioridad`, `fecha_actualizacion`. Es la misma
información que `lugar`, publicada para quien consuma la RPU y no el score.

---

## 6. Resumen operativo

1. **Tu SP va en `pgm`.** El DDL que necesite, en `strct`, desplegado antes.
2. **Hazlo idempotente**: el pipeline ejecuta `DPLY` dos veces por build.
3. **Rama y commit con el issue key**, o Jira no enlaza nada.
4. **El ranking sale de `score_ordenamiento`**, no de las MAT. `lugar = 1` es
   el mejor; `lugar <= X` es tu Top X.
5. **Une por `(cod_dw_persona_ubic, canal)`**, con las dos columnas.
6. **`EMA` ≠ `EMAIL`.**
7. **Corre `./validar.sh` antes de empujar.**
