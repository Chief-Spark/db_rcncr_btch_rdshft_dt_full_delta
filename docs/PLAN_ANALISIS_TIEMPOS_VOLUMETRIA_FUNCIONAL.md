# Plan de análisis: tiempos, volumetría y funcional de las 7 tablas dominio

Versión 1.0 · 2026-10-26 · base de medida: job **DEV/DATABASE #491**, vía real,
lote `1356301`, las dos pasadas de DPLY.

## Lo primero: dos de los tres análisis ya tienen la mitad hecha, y uno no hace falta

| Análisis | Estado real | Qué falta |
|---|---|---|
| **Tiempos** | **CERRADO con el #491** y está abajo, en §1. Las tablas de control traen marca de inicio y fin por etapa | nada en DEV. Falta la proyección a volumen de producción, que depende de §2 |
| **Volumetría** | hay conteos de filas y nada más | bytes, grano real, sesgo por nodo y factor de crecimiento. §2 trae las consultas |
| **Funcional** | **ya existe y es bueno**: `DICCIONARIO_DATOS_7_TABLAS_DOMINIO.md` (392 líneas, las siete con su grano y columna por columna), `ESTRUCTURA_TABLAS_MAT_NOVEDADES.md` y `CONTRATO_DATOS_ENTREGA_BATCH.md` | NO hay que reescribirlo. Falta lo que ningún documento puede afirmar sin datos: que las llaves **unan de verdad** y con qué cardinalidad. §3 |

**Y una corrección de premisa, antes de planificar nada.** La frase "las 7 tablas
pobladas son lo que explota el Batch" es falsa tal cual:
**el Batch P0033 no lee ninguna de las siete.** Lee siete cubos
`rec_stage.batch_cubo_*` que en Teradata arma `P0032_BATCH_GENERACUBO`, y ese
script **no está en el material entregado**. Medido: cero coincidencias de
`mat_info_*` ni `mat_ubicacion_*` en los 36 archivos de
`docs/legado_teradata/batch/`; sus fuentes son `rec_stage.batch_cubo_persona`,
`_direccion`, `_telefono`, `_correo` y `_celular`.
`CONTRATO_DATOS_ENTREGA_BATCH.md:9` ya lo decía.

Consecuencia para este análisis: **el eslabón que falta es de las 7 MAT al cubo**,
y es lo único cuyo cierre vale una decisión de negocio. Va en §4.

---

## §1 · TIEMPOS: medido en el #491, no estimado

### La cadena real completa

| Proceso | Pasada 1 | Pasada 2 | Entrada | Rendimiento (pasada 1) |
|---|---|---|---|---|
| Unificación | **130 s** | 153 s | 78.173 relaciones | 601 rel/s |
| Ordenamiento | **61 s** | 61 s | 78.173 contactos | 3.037 scores/s |
| Novedades | **70 s** | 76 s | 363.327 filas MAT | 5.190 filas/s |
| **Cadena** | **263 s** (4 m 23 s) | **291 s** (4 m 51 s) | 58.878 personas | 224 personas/s |

### Dónde se va el tiempo, por etapa

| Proceso | Etapa | s | % del proceso |
|---|---|---|---|
| Unificación | **regla2** | **73** | **56%** |
| | regla1 | 21 | 16% |
| | regla3 | 19 | 15% |
| | geo | 8 | 6% |
| Ordenamiento | **preparar** | **24** | **39%** |
| | ubicaciones (F3) | 9 | 15% |
| | cleanup | 8 | 13% |
| | los cuatro scoring | 9 | 15% |
| | cuentas (F2) + consolidación | 6 | 10% |
| Novedades | **ubicacion** | **23** | **33%** |
| | **ubi_agregada** | **21** | **30%** |
| | actividad_economica | 8 | 11% |
| | info_basica | 5 | 7% |
| | contactabilidad | 3 | 4% |
| | movilidad + punto_interes | 5 | 7% |

**Las tres conclusiones de tiempos:**

1. **La cascada de la Regla 2 es el 28% de la cadena entera** y la única pieza con
   riesgo de no escalar: es un encadenamiento de nueve etapas que se leen entre
   sí. Las demás son barridos de una pasada.
2. **La segunda pasada es un 11% más lenta y TODO el delta está en la R2**
   (95 s contra 73 s; los otros ocho tiempos no se mueven ni un segundo).
   Observado, no explicado: puede ser caché del clúster o el estado que la
   primera pasada dejó. Es la primera cosa a aislar si los tiempos importan.
3. **Novedades es barata: 70 s para 363.327 filas.** Los dos tercios se los
   llevan `ubicacion` y `ubi_agregada`, que son las que tienen `LISTAGG` y
   ventanas.

**Lo que NO se puede medir con las tablas de control, y hay que decirlo cada vez
que alguien lea esta tabla:** `unif_control_etapa` y `ord_control_etapa` traen
los conteos en **0 literal** (`16_sp_unificacion_ciclo.sql:282`, `:302-308`),
y las seis `regla2_esc*` se abren todas antes y se cierran todas después, de modo
que sus 71-72 s son el mismo intervalo repetido seis veces, **no el tiempo de
cada escenario**. Para repartir los 73 s de la R2 entre sus nueve etapas hace
falta la consulta de §1.1.

### §1.1 · Reparto real de la Regla 2 (la consulta que falta)

```sql
-- Los pasos de verdad de la cascada, desde el log del motor.
-- Ventana: la de la etapa regla2 de la corrida que interese.
SELECT q.starttime, q.endtime,
       DATEDIFF(milliseconds, q.starttime, q.endtime) AS ms,
       LEFT(REGEXP_REPLACE(q.querytxt, '[[:space:]]+', ' '), 180) AS sentencia
  FROM stl_query q
 WHERE q.userid <> 1
   AND q.starttime BETWEEN
        (SELECT fecha_hora_inicio FROM bdm_datos.unif_control_etapa
          WHERE lote = 1356301 AND etapa = 'regla2' AND corrida_id = 1)
    AND (SELECT fecha_hora_fin    FROM bdm_datos.unif_control_etapa
          WHERE lote = 1356301 AND etapa = 'regla2' AND corrida_id = 1)
 ORDER BY ms DESC
 LIMIT 40;
```

**Y el paso que de verdad decide, con su plan:**

```sql
-- Sobre el query_id mas caro que devuelva la anterior.
SELECT * FROM svl_query_summary WHERE query = <query_id> ORDER BY stm, seg, step;
-- is_diskbased = 't' en cualquier paso dice que ese paso derramo a disco:
-- es lo que hace que un join no escale cuando sube el volumen.
```

---

## §2 · VOLUMETRÍA: cuatro preguntas, cuatro consultas

El conteo de filas no sirve para dimensionar. Lo que decide son bytes, grano,
sesgo y factor de crecimiento.

### §2.1 · Peso, sesgo y salud física

```sql
SELECT "table"           AS tabla,
       tbl_rows          AS filas,
       size              AS bloques_1mb,
       pct_used          AS pct_espacio,
       unsorted          AS pct_sin_ordenar,
       stats_off         AS pct_stats_viejas,
       skew_rows         AS sesgo_filas,
       diststyle, sortkey1, max_varchar
  FROM svv_table_info
 WHERE schema = 'bdm_datos'
   AND "table" IN ('mat_info_ubicacion','mat_info_actividad_economica',
                   'mat_ubicacion_agregada','mat_info_contactabilidad',
                   'mat_info_basica','mat_info_punto_interes','mat_info_movilidad')
 ORDER BY size DESC;
```

**Qué se busca:** `skew_rows` muy por encima de 1 dice que el `DISTKEY` reparte
mal y el join se hará por red; `stats_off` alto, que el plan se está eligiendo a
ciegas; `unsorted` alto, que el `SORTKEY` no está sirviendo.

### §2.2 · El grano REAL de cada tabla, que es lo que nadie ha medido

```sql
-- Cada tabla contra su llave declarada. filas = llaves significa grano 1:1;
-- filas > llaves, que la tabla es 1:N por esa llave, y hay que saber por que.
SELECT 'mat_info_basica' AS tabla, COUNT(*) AS filas,
       COUNT(DISTINCT id) AS llaves, 'id (persona)' AS llave
  FROM bdm_datos.mat_info_basica
UNION ALL SELECT 'mat_info_ubicacion', COUNT(*), COUNT(DISTINCT id), 'id (ubicacion)'
  FROM bdm_datos.mat_info_ubicacion
UNION ALL SELECT 'mat_info_ubicacion x persona', COUNT(*), COUNT(DISTINCT info_basica), 'info_basica'
  FROM bdm_datos.mat_info_ubicacion
UNION ALL SELECT 'mat_info_actividad_economica', COUNT(*), COUNT(DISTINCT id), 'id'
  FROM bdm_datos.mat_info_actividad_economica
UNION ALL SELECT 'mat_info_acteco x (persona,ciiu)', COUNT(*),
       COUNT(DISTINCT info_basica_id || ':' || COALESCE(ciiu,'')), 'persona+ciiu'
  FROM bdm_datos.mat_info_actividad_economica
UNION ALL SELECT 'mat_ubicacion_agregada', COUNT(*), COUNT(DISTINCT info_basica), 'info_basica'
  FROM bdm_datos.mat_ubicacion_agregada
UNION ALL SELECT 'mat_info_contactabilidad', COUNT(*), COUNT(DISTINCT ubicacion_id), 'ubicacion_id'
  FROM bdm_datos.mat_info_contactabilidad
 ORDER BY 2 DESC;
```

**Expectativa escrita, del #491:** `mat_info_basica` 58.878 = 58.878 (1:1 por
persona). `mat_info_ubicacion` 60.452 filas / 60.452 ids / **55.259 personas**
(1:N por persona, 1,09 ubicaciones por persona). `mat_info_acteco` 124.263 para
58.512 personas (2,12 CIIU por persona) — y ahí hay que comprobar si el par
(persona, ciiu) es único, porque `NOV-AE-02` dice que el legado cierra con un
`QUALIFY ROW_NUMBER` sobre ese par.

### §2.3 · Ancho real contra ancho declarado

```sql
-- Donde se está pagando espacio por nada, y donde se está al borde del limite.
SELECT 'nombre_completo' AS columna, 200 AS declarado,
       MAX(OCTET_LENGTH(nombre_completo)) AS max_bytes_real,
       COUNT(*) - COUNT(nombre_completo)  AS nulos
  FROM bdm_datos.mat_info_basica
UNION ALL SELECT 'razon_social', 500, MAX(OCTET_LENGTH(razon_social)),
       COUNT(*) - COUNT(razon_social) FROM bdm_datos.mat_info_basica
UNION ALL SELECT 'actividad_economica', 500, MAX(OCTET_LENGTH(actividad_economica)),
       COUNT(*) - COUNT(actividad_economica) FROM bdm_datos.mat_info_actividad_economica
UNION ALL SELECT 'dato (direccion)', 201, MAX(OCTET_LENGTH(dato)),
       COUNT(*) - COUNT(dato) FROM bdm_datos.mat_info_ubicacion;
```

**Por qué importa y no es cosmético:** `OCTET_LENGTH` y no `LEN`, porque
`VARCHAR(n)` en Redshift son **n BYTES**. Es la misma distinción que tumbó el
#477, y una columna al 99% de su ancho es el siguiente `XX000` esperando dato
real.

### §2.4 · El factor de crecimiento a producción

```sql
-- El universo de DEV contra el del buró entero. Este cociente es el
-- multiplicador con el que se proyecta TODO lo de §1.
SELECT (SELECT COUNT(DISTINCT id_buro_persona)
          FROM bdm_tempo.v_xpm_relacion_persona_ubicacion)        AS personas_dev_rpu,
       (SELECT COUNT(*) FROM ds_dba_rncr_batch.edf_views.xpm)      AS personas_buro,
       (SELECT COUNT(*) FROM ds_dba_rncr_batch.edf_views.xpm_location_val_contactinformations)
                                                                   AS ubicaciones_buro;
```

**Lo que ya se sabe y acota la respuesta:** `xpm` entero dio **1.194.682**
personas en el #484, contra 58.878 en la RPU de DEV. **El factor es ~20x.**
Aplicado lineal a los 263 s de §1 da ~88 min de cadena. **La proyección lineal
es el suelo, no la estimación:** la R2 es una cascada con joins entre etapas y
puede ser superlineal. Por eso §1.1 pregunta por `is_diskbased`: un paso que ya
derrama a disco en DEV se multiplica, no se escala.

---

## §3 · FUNCIONAL: el mapa de llaves, MEDIDO

El diccionario ya dice qué significa cada columna. Lo que ningún documento puede
afirmar es que las llaves **unan**. Esto es lo que hay que medir.

### §3.1 · El mapa que hay que verificar

```
                 mat_info_basica                 (1 fila por PERSONA, id)
                        |
     +------------------+------------------+--------------------+
     | info_basica_id                      | info_basica        | info_basica
     v                                     v                    v
mat_info_actividad_economica      mat_ubicacion_agregada    mat_info_ubicacion
   (N CIIU por persona)            (N por persona+clase)    (N ubicaciones, id)
                                                                   |
                                        +--------------------------+
                                        | ubicacion_id (= id de ubicacion)
                                        v
                               mat_info_contactabilidad   mat_info_punto_interes
                                 (1 por ubicacion)         (N por ubicacion)

mat_info_movilidad  --info_basica_id-->  mat_info_basica   (N eventos por persona)
```

**Las dos trampas de este mapa, y son las que hacen falta la medición:**

- **`mat_info_ubicacion` tiene DOS llaves y se confunden:** `id` es la
  **ubicación** y `info_basica` la **persona**
  (`30_ddl_novedades.sql:189-212` declara las dos). Ya costó una consulta mal
  hecha en esta misma sesión.
- **`mat_info_contactabilidad.id` sale NULL siempre**
  (`36_ddl_nov_contactabilidad.sql:93`) y **no tiene columna de persona**: solo
  se puede unir por `ubicacion_id`, y la persona se alcanza pasando por
  `mat_info_ubicacion`. Lo mismo `mat_info_punto_interes`.

### §3.2 · La consulta de integridad referencial

```sql
-- Huerfanos: filas de cada tabla cuya llave NO existe en su padre.
-- TIENE que dar 0 en las cinco. Un numero distinto de 0 es un defecto de carga.
SELECT 'acteco sin persona' AS relacion, COUNT(*) AS huerfanos
  FROM bdm_datos.mat_info_actividad_economica h
  LEFT JOIN bdm_datos.mat_info_basica p ON p.id = h.info_basica_id
 WHERE p.id IS NULL
UNION ALL
SELECT 'ubicacion sin persona', COUNT(*)
  FROM bdm_datos.mat_info_ubicacion h
  LEFT JOIN bdm_datos.mat_info_basica p ON p.id = h.info_basica
 WHERE p.id IS NULL
UNION ALL
SELECT 'ubi_agregada sin persona', COUNT(*)
  FROM bdm_datos.mat_ubicacion_agregada h
  LEFT JOIN bdm_datos.mat_info_basica p ON p.id = h.info_basica
 WHERE p.id IS NULL
UNION ALL
SELECT 'contactabilidad sin ubicacion', COUNT(*)
  FROM bdm_datos.mat_info_contactabilidad h
  LEFT JOIN bdm_datos.mat_info_ubicacion u ON u.id = h.ubicacion_id
 WHERE u.id IS NULL
UNION ALL
SELECT 'movilidad sin persona', COUNT(*)
  FROM bdm_datos.mat_info_movilidad h
  LEFT JOIN bdm_datos.mat_info_basica p ON p.id = h.info_basica_id
 WHERE p.id IS NULL;
```

### §3.3 · La cardinalidad de cada arista

```sql
-- Cuantos hijos por padre, y si hay padres sin hijos. Es la forma de la
-- estrella, y lo que dice si un JOIN de negocio multiplica.
SELECT 'persona -> ubicaciones' AS arista,
       COUNT(*) AS padres,
       SUM(CASE WHEN n = 0 THEN 1 ELSE 0 END) AS sin_hijos,
       MAX(n) AS max_hijos, AVG(n::DECIMAL(12,4)) AS media_hijos
  FROM ( SELECT p.id, COUNT(h.info_basica) AS n
           FROM bdm_datos.mat_info_basica p
           LEFT JOIN bdm_datos.mat_info_ubicacion h ON h.info_basica = p.id
          GROUP BY p.id ) t
UNION ALL
SELECT 'persona -> CIIU', COUNT(*), SUM(CASE WHEN n = 0 THEN 1 ELSE 0 END),
       MAX(n), AVG(n::DECIMAL(12,4))
  FROM ( SELECT p.id, COUNT(h.info_basica_id) AS n
           FROM bdm_datos.mat_info_basica p
           LEFT JOIN bdm_datos.mat_info_actividad_economica h ON h.info_basica_id = p.id
          GROUP BY p.id ) t
UNION ALL
SELECT 'ubicacion -> contactabilidad', COUNT(*), SUM(CASE WHEN n = 0 THEN 1 ELSE 0 END),
       MAX(n), AVG(n::DECIMAL(12,4))
  FROM ( SELECT u.id, COUNT(c.ubicacion_id) AS n
           FROM bdm_datos.mat_info_ubicacion u
           LEFT JOIN bdm_datos.mat_info_contactabilidad c ON c.ubicacion_id = u.id
          GROUP BY u.id ) t;
```

**`sin_hijos` es la columna que importa**, y hay que leerla contra lo ya medido:
Info básica tiene **58.878** personas y Ubicación **55.259**, de modo que
`persona -> ubicaciones` debe dar ~3.619 padres sin hijos. Si da otro número,
una de las dos medidas está mal.

### §3.4 · Qué pregunta de negocio responde cada tabla

La pregunta sale del **grano**, que es dato del DDL. La columna "cubo destino"
es **inferencia**, y hay que leerla como tal: se deriva del nombre del cubo y del
grano que encaja, porque `P0032_BATCH_GENERACUBO` -- el unico sitio donde el
mapeo esta escrito -- no esta en el material. Confirmarla es parte de §4, no de
este cuadro.

| Tabla | Grano | Pregunta que responde | Cubo destino |
|---|---|---|---|
| `mat_info_basica` | persona | ¿quién es esta persona: nombre, documento, género, actividad? | `BATCH_CUBO_PERSONA` |
| `mat_info_ubicacion` | ubicación | ¿dónde se le puede ubicar, y por qué canal (DIR/TEL/CEL/EMAIL)? | `BATCH_CUBO_DIRECCION`, `_TELEFONO`, `_CELULAR`, `_CORREO` |
| `mat_ubicacion_agregada` | persona × clase | ¿cuál es su MEJOR ubicación por canal, y con cuántos reportes la respaldan? | `BATCH_CUBO_DIRECCION` (orden) |
| `mat_info_actividad_economica` | persona × CIIU | ¿a qué se dedica? | `BATCH_CUBO_CIIU` |
| `mat_info_contactabilidad` | ubicación | ¿se le ha contactado por ahí y con qué resultado? | `BATCH_CUBO_*` (columnas de gestión) |
| `mat_info_punto_interes` | ubicación × punto | ¿qué hay cerca de su dirección? | `BATCH_CUBO_PUNTO_INTERES_DIR` |
| `mat_info_movilidad` | persona × evento | ¿se ha mudado, y de qué tipo fue el cambio? | `BATCH_CUBO_PERSONA` (indicadores) |

**La que decide el valor del conjunto es `mat_ubicacion_agregada`**, y conviene
entender por qué: las otras seis describen, y ella **ordena**. Es la que dice
cuál de las N direcciones de una persona es la buena, y ese orden sale del
Ordenamiento (`rpu_orden_prioridad`). Un cubo con ubicaciones y sin orden no
sirve para llamar a nadie.

---

## §4 · EL ESLABÓN QUE FALTA, Y ES LO ÚNICO QUE DECIDE SI ESTO ESTÁ COMPLETO

Entre las 7 MAT y el Batch hay un paso que **no está en el material**:
`P0032_BATCH_GENERACUBO`. Sin él no se puede afirmar que las siete tablas
alimenten los siete cubos, por mucho que estén pobladas.

**La medición que cierra la pregunta** es de cobertura, no de volumen: por cada
columna de cada `BATCH_CUBO_*` del contrato, decir si tiene origen en una de las
siete MAT, si lo tiene en EDF sin conectar, o si no existe. El contrato ya trae
la columna `Estado` con ese vocabulario (`OK`, `CORREGIR`, `CONECTAR`, `DERIVAR`,
`PEDIR`, `NULL`) y **ya está rellena**: el trabajo es contarla y publicar el
porcentaje, no volver a analizarla.

```
Entregable: una tabla de 7 filas (una por cubo) con
  columnas_totales | OK | CORREGIR | CONECTAR | DERIVAR | PEDIR | NULL
```

Eso convierte "cinco de siete tablas pobladas" en un número que un comité
entiende: **qué porcentaje de lo que el Batch necesita está servido.**

---

## Orden de ejecución propuesto

| Paso | Qué | Dónde | Coste |
|---|---|---|---|
| 1 | §2.1, §2.2, §2.3 y §3.2, §3.3 | DBeaver contra DEV, una sesión | ~10 min |
| 2 | §2.4 y la proyección de §1 | la misma sesión | ~5 min |
| 3 | §1.1 sobre la corrida 1 del #491 | `stl_query` conserva días, no meses | ~10 min |
| 4 | §4, contando el contrato | no necesita base de datos | ~30 min |

**Los pasos 1 y 2 no necesitan un build nuevo**: las siete tablas y las de
control siguen en DEV con los datos del #491, porque `reset_mock.sql` no las
toca. El paso 3 sí caduca — `stl_query` rota.
