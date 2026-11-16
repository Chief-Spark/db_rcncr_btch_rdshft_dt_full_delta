# Prueba del Framework Batch contra dato real en DEV

Los archivos de la cadena real lanzada **desde el Framework** (no desde
`deploy.par`). Detalle en la seccion "El Framework Batch contra dato real" de
`CLAUDE.md`.

| Archivo | Donde va | Para que |
|---|---|---|
| `PE1353.yml` | **raiz** de `<stage>-<cuenta>-fwdynbtch-dynamic-batch-definition-repository` | los CINCO niveles, con los cuatro canales de scoring en paralelo en el nivel 3 |
| `reconocerfullval1-20261116-2611.val` | carpeta `PE1353/` de `...-dynamic-batch-source-repository` | **dispara FULL**. Su NOMBRE lleva los parametros; el cuerpo no lo lee nadie |
| `reconocerdeltaval1-20261117-2611.val` | la misma carpeta | **dispara DELTA**. Lo unico que cambia es el nombre |
| `mnemotecnicos_filas_reconocer.csv` | **dos filas que se AGREGAN** a `mnemotecnicos.csv` en la raiz del bucket de definiciones | sin ellas el Builder muere con `NITNotFoundError`. **Leer `MNEMOTECNICOS_LEEME.md` antes de subirlo** |
| `drilldown_qa.sql` | no se sube: se corre en DBeaver | nueve consultas de Niveles 0/1/2 con la cifra de DEV al lado para comparar |
| `ddl_7_mat_real.sql` | no se sube: es referencia | el DDL de las siete MAT tal como quedaron en Redshift real |

**El YAML primero y el `.val` de ultimo**, porque el `.val` es lo que arranca la
Step Function.

**`PE1353` es una propuesta, no el codigo asignado.** El `product_id` sale de la
carpeta y tiene que casar con el nombre del YAML: si el codigo oficial es otro,
se renombran los dos a la vez.

## Como se leen los dos nombres

```
reconocerfullval 1 - 20261116 - 2611 .val
|______________| |   |______|   |__|
 mnemotecnico    |    LOTE      YYMM
                 solicitud (no se usa)
```

| Trozo | Slot del CALL | Resuelve a |
|---|---|---|
| `reconocerfullval` / `reconocerdeltaval` | 4, `in_nemotecnico` | **MODO = FULL / DELTA** |
| `1` | 1, `in_solicitud` | no se usa |
| `20261116` / `20261117` | 5, `in_id_facturacion` | **LOTE** |
| `2611` | 6, `in_fecha_ejecucion` | **FECHA = 2026-11-01** |

Medido con la funcion real: `fw_resolver_param` devuelve `FULL`/`DELTA`, el lote
tal cual y `2026-11-01`. **El FULL y el DELTA llevan lote distinto a proposito**,
para que `ord_control` quede con una corrida inequivoca por cada uno.

**La fecha es YYMM y no MMYY** -- `0826` da cadena vacia porque el mes 26 no
existe --, y `[\D]+` no admite digitos antes de `val`: `reconocer1val` no casa.

**Para mandar un DELTA solo cambia el nombre del `.val`**: `fw_resolver_param`
decide el MODO por lo que el mnemotecnico CONTIENE, mirando `DELTA` antes que
`FULL`. **El YAML no se toca, y los SP tampoco.**

## Los cinco niveles, y por que el 3 va en paralelo

```
nivel 1  unificacion_ciclo                                    (secuencial)
nivel 2  ordenamiento_preparar                                (secuencial)
nivel 3  scoring_dir | scoring_tel | scoring_cel | scoring_ema  <-- EN PARALELO
nivel 4  ordenamiento_cerrar                                  (secuencial)
nivel 5  novedades_ciclo                                      (secuencial)
```

El Framework corre en PARALELO los `procedimientos` del MISMO nivel y en SERIE
los niveles. Los cuatro canales pueden ir a la vez porque **cada uno escribe una
particion disjunta de `score_ordenamiento`**: antes de insertar borra solo la
suya, con `DELETE ... WHERE canal = 'XXX'`. El insumo comun lo deja el nivel 2 en
las `bdm_tempo.stg_*`, que son tablas **permanentes** y por eso sobreviven de un
nivel al siguiente aunque cada rama sea otra sesion del Data API.

## Los seis wrappers, y por que hacen falta

**El Builder renderiza SIEMPRE un `CALL` de seis argumentos posicionales**
(`step_function_definition_builder.py:93`), de modo que al YAML solo entra un SP
con la firma del Framework. Los cuatro de scoring estan declarados **sin
parametros** (`sp_ordenamiento_scoring_dir_edf.sql:4`), asi que ponerlos tal cual
da `procedure does not exist`.

Por eso `pgm` lleva seis objetos nuevos en `bdm_stage`, con la firma de 6 VARCHAR
-- mismo patron que los wrappers de GEO:

| Objeto | Nivel | Etapas que se lleva |
|---|---|---|
| `sp_ordenamiento_preparar` | 2 | abre `ord_control`; `preparar`, `cuentas`, `ubicaciones` |
| `sp_ordenamiento_scoring_{dir,tel,cel,ema}` | 3 | una etapa cada uno |
| `sp_ordenamiento_cerrar` | 4 | `consolidacion`, `cleanup`, censo y cierre |

**`bdm_datos.sp_ordenamiento_ciclo` NO se toco** y sigue siendo el que usan
`deploy.par`, la bateria mock y la via manual. Los wrappers reparten sus etapas,
no las reescriben.

## La traza de control no cambia, y es lo que hay que verificar

| Tabla | Que tiene que verse tras la corrida |
|---|---|
| `ord_control` | **una** fila para el lote, `estado = 'completado'`, con watermark y los tres conteos |
| `ord_control_etapa` | las **nueve** etapas en `completado`, con sus literales de siempre, y los cuatro `scoring_*` **solapados en el tiempo** -- ese solape es la prueba del paralelismo |
| `ord_alcance_censo` | **una** fila por corrida, escrita en `cleanup` ANTES del drop del staging. Los criterios `F1-01..08` dependen de ella |

Los niveles 3 y 4 recuperan la corrida **por lote**
(`SELECT MAX(corrida_id) ... WHERE estado = 'enproceso' AND lote = ?`), porque
`corrida_id` es variable local y cada nivel es otra sesion.

**RIESGO ABIERTO, y es hipotesis, no medida:** cuatro transacciones concurrentes
escribiendo la MISMA tabla `score_ordenamiento` pueden dar
`1023 Serializable isolation violation`. Las particiones son disjuntas, pero
Redshift detecta conflicto a nivel de TABLA. Si aparece, el repliegue no toca
codigo: emparejar los canales en dos niveles de a dos en este YAML.
