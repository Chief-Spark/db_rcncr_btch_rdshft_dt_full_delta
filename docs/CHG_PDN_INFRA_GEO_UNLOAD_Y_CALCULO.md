# CHG - Despliegue a PRODUCCION: infraestructura GEO, infraestructura UNLOAD y calculo Reconocer

| | |
|---|---|
| Redactado | 2026-11-23 |
| Ambiente destino | **PRODUCCION** -- cuenta de Reconocer `696708350333` |
| Ambiente inmediatamente anterior | **DEMO**, desplegado el 2026-11-23 (ventana de medio dia) |
| Medio de despliegue | **Pipeline de Jenkins**. Ningun paso es manual |
| Subtasks | **3, y el orden es obligatorio** |

---

## 1. Que se despliega, y en que orden

| # | Subtask | HU | Repositorio | Pipeline | Que crea |
|---|---|---|---|---|---|
| 1 | Infraestructura GEO | **SLCOPRBA-1368** | `tf_rcncr_ws5_infra` (PR #4) | TERRAFORM | Bucket de GEO y rol IAM que Redshift asume para el `UNLOAD`/`COPY` |
| 2 | Infraestructura UNLOAD (En Linea) | **SLCOPRBA-1525** | `tf_rcncr_linea_ws5_infra` (PR #3) | TERRAFORM | Bucket de entrega y rol IAM del `UNLOAD` de las siete tablas |
| 3 | Calculo Reconocer | **SLCOPRBA-1353** | `DB_DS_RCNCR_BTCH_RDSHFT_{STRCT,PGM,DT}` (PR #19) | DATABASE | Tablas, vistas, catalogos y los 122 procedimientos del calculo |

**El orden no es una preferencia, es una dependencia.** El correo de
SLCOPRBA-1353 ya lo dice: *"Antes de ejecutar este deploy es necesario haber
ejecutado los deploy de los correos adjuntos."*

El motivo tecnico es que el paquete de base de datos **siembra en
`bdm_datos.geo_config` el nombre del bucket y el ARN del rol**, y el ciclo de
Unificacion ejecuta un `UNLOAD` contra ellos. Si la infraestructura no existe
cuando el calculo corre, el `UNLOAD` falla con
`UnauthorizedException` o con un bucket inexistente. **No tumba el build**
-- GEO corre en su propio bloque de excepcion por decision de negocio -- de
modo que el sintoma seria peor que un error: ningun Lote saldria y nadie se
enteraria.

**Dentro de la subtask 3 hay un orden propio que tampoco se negocia:**
`struct` -> `program` -> `data`. Lo impone el `.jenkins.yml` de cada repo con
su `type`/`order`, y romperlo deja procedimientos apuntando a tablas que
todavia no existen.

---

## 2. Campos del CHG (para pegar en ServiceNow)

### Short description

```
Despliegue a Produccion del calculo Reconocer: infraestructura GEO, infraestructura de entrega UNLOAD y paquete de base de datos (SLCOPRBA-1368, 1525, 1353)
```

### Description

```
Puesta en produccion del proceso de calculo Reconocer migrado de Teradata a
Amazon Redshift, en tres despliegues encadenados y ejecutados por pipeline.

1) SLCOPRBA-1368 (IaC, pipeline TERRAFORM): crea el bucket de S3 de
   georreferenciacion y el rol IAM que el cluster de Redshift asume para
   escribir el archivo de candidatos y leer la respuesta del geocodificador.
   Cambio aditivo: no modifica ni elimina recursos existentes.

2) SLCOPRBA-1525 (IaC, pipeline TERRAFORM): crea el bucket de S3 de entrega y
   el rol IAM del proceso de UNLOAD, por donde salen las siete tablas de
   dominio hacia el consumidor. Cambio aditivo.

3) SLCOPRBA-1353 (base de datos, pipeline DATABASE): despliega el paquete del
   calculo en los esquemas bdm_datos, bdm_tempo y bdm_stage, en el orden
   struct -> program -> data. Comprende las tablas y vistas de insumo, los
   catalogos de parametrizacion, y los procedimientos de Unificacion de
   direcciones, Ordenamiento de contactabilidad y Novedades.

Los tres despliegues se ejecutan unicamente por el pipeline de Jenkins. No hay
ejecucion manual de scripts ni acceso directo al cluster.

El despliegue 3 depende de los despliegues 1 y 2: el paquete de base de datos
parametriza el nombre del bucket y el ARN del rol, y el ciclo de Unificacion
los usa en tiempo de ejecucion.

Este cambio NO ejecuta la cadena de calculo sobre datos de produccion. Solo
deja la infraestructura y los objetos creados. La primera ejecucion se
programa aparte, por el Framework Batch.
```

### Justificacion

```
Habilitar en produccion el calculo Reconocer, que hoy solo existe en
ambientes menores. Sin estos tres despliegues el proceso no puede ejecutarse
en produccion: faltan los objetos de base de datos y los destinos de S3 por
donde entra y sale la informacion de georreferenciacion y la entrega de las
siete tablas de dominio al consumidor.
```

### Impacto si no se realiza

```
El calculo Reconocer sigue sin estar disponible en produccion y la entrega de
las siete tablas de dominio al consumidor no puede iniciarse.
```

### Riesgo e impacto declarados

```
Aditivo. No modifica ni elimina objetos existentes, no altera tablas en uso,
no requiere ventana de indisponibilidad y no afecta la disponibilidad de
ningun servicio en linea. Los esquemas destino son compartidos, por lo que el
paquete usa exclusivamente DDL idempotente (CREATE TABLE IF NOT EXISTS,
CREATE OR REPLACE VIEW) y en ningun punto ejecuta DROP SCHEMA.
```

### Plan de rollback

```
Cada despliegue tiene reverso propio y el pipeline lo ejecuta.

1 y 2 (IaC): revertir el merge en Bitbucket y relanzar el pipeline con el
job de rollback del ambiente (production_rllbck). Los buckets se crean
vacios, de modo que la reversion no destruye informacion. Si el bucket ya
tuviera objetos, se vacia antes.

3 (base de datos): el paquete incluye rollback.par y la carpeta RevSQL/, que
son el reverso exacto de deploy.par archivo por archivo. El propio pipeline
valida la disponibilidad del rollback antes de desplegar
([REDSHIFT:211] Rollback disponible: 'true') y ejecuta una prueba de
rollback dentro del ciclo controlado.

El rollback de 3 es independiente de 1 y 2: revertir la base de datos no
obliga a revertir la infraestructura, y al reves tampoco.
```

### Plan de verificacion (pruebas post implementacion)

```
Subtask 1: el bucket y el rol existen y responden, y Redshift puede escribir.
Subtask 2: el bucket y el rol existen y responden.
Subtask 3: estan los 273 objetos que el calculo necesita, y los catalogos
           tienen filas.

El detalle de cada verificacion va en la propia subtask.
```

---

## 3. Las tres Implementation Tasks

### IMPTASK 1 - Infraestructura GEO (SLCOPRBA-1368)

**Short description**

```
SLCOPRBA-1368 - Despliegue IaC por pipeline: bucket S3 y rol IAM de georreferenciacion (GEO)
```

**Description**

```
Despliegue por pipeline de Jenkins (TERRAFORM) del repositorio
tf_rcncr_ws5_infra, Pull Request #4.

Crea dos recursos, ambos nuevos:

- Bucket de S3 de georreferenciacion, con acceso publico bloqueado,
  cifrado en reposo, versionado y una regla de ciclo de vida que expira
  versiones no vigentes.
- Rol IAM que el cluster de Redshift asume para operar contra ese bucket,
  con permiso de escritura sobre el prefijo de entrada y de lectura sobre
  el prefijo de salida, y ninguno fuera de esos dos prefijos.

Es un cambio aditivo: no toca recursos existentes ni servicios en linea.

Pasos:
1. Aprobar el merge del Pull Request #4 en Bitbucket.
2. Lanzar el job del pipeline sobre el ambiente production.
3. Verificar en el log que el plan de Terraform solo CREA recursos
   (0 to change, 0 to destroy).

Nota operativa: si el pipeline presenta un error de conexion, se recomienda
redesplegar.

Verificacion:
- El bucket existe y responde.
- El rol IAM existe y esta asociado al cluster de Redshift.
- Prueba funcional desde Redshift: UNLOAD ('SELECT 1') contra el prefijo de
  entrada, que debe terminar en verde y dejar el objeto en S3.

Rollback: revertir el merge y relanzar el pipeline con el job de rollback
del ambiente. El bucket se crea vacio.
```

### IMPTASK 2 - Infraestructura de entrega UNLOAD (SLCOPRBA-1525)

**Short description**

```
SLCOPRBA-1525 - Despliegue IaC por pipeline: bucket S3 y rol IAM del UNLOAD de entrega
```

**Description**

```
Despliegue por pipeline de Jenkins (TERRAFORM) del repositorio
tf_rcncr_linea_ws5_infra, Pull Request #3.

Crea el bucket de S3 de entrega y el rol IAM que el cluster de Redshift
asume para escribir en el. Por ahi salen las siete tablas de dominio hacia
el consumidor, en archivos CSV con cabecera comprimidos en GZIP, mas un
archivo de control que avisa que la entrega esta completa.

Es un cambio aditivo: no toca recursos existentes ni servicios en linea.

Pasos:
1. Aprobar el merge del Pull Request #3 en Bitbucket.
2. Lanzar el job del pipeline sobre el ambiente production.
3. Verificar en el log que el plan de Terraform solo CREA recursos.

Nota operativa: si el pipeline presenta un error de conexion, se recomienda
redesplegar.

Verificacion:
- El bucket existe y responde.
- El rol IAM existe y esta asociado al cluster de Redshift.
- Prueba funcional desde Redshift: UNLOAD ('SELECT 1') contra el prefijo de
  entrega.

Rollback: revertir el merge y relanzar el pipeline con el job de rollback
del ambiente. El bucket se crea vacio.
```

### IMPTASK 3 - Paquete de base de datos del calculo (SLCOPRBA-1353)

**Short description**

```
SLCOPRBA-1353 - Despliegue por pipeline del paquete de base de datos del calculo Reconocer (struct, program, data)
```

**Description**

```
Despliegue por pipeline de Jenkins (DATABASE) del paquete del calculo
Reconocer, Pull Request #19.

DEPENDE de IMPTASK 1 e IMPTASK 2: no iniciar hasta que las dos esten
cerradas en verde.

Son tres repositorios que se despliegan en este orden, y el orden es
obligatorio:

1. DB_DS_RCNCR_BTCH_RDSHFT_STRCT  (type struct,  order 1) - 51 scripts
   Tablas, vistas de insumo, catalogos de parametrizacion y funciones base.
2. DB_DS_RCNCR_BTCH_RDSHFT_PGM    (type program, order 2) - 122 scripts
   Los procedimientos de Unificacion de direcciones, Ordenamiento de
   contactabilidad y Novedades.
3. DB_DS_RCNCR_BTCH_RDSHFT_DT     (type data,    order 3) - 1 script
   Script de arranque de la cadena.

Todo el DDL es idempotente y los esquemas destino son compartidos, de modo
que el despliegue no elimina ni altera objetos de otros equipos. En ningun
punto se ejecuta DROP SCHEMA.

Pasos:
1. Aprobar el merge del Pull Request #19 en Bitbucket.
2. Lanzar el pipeline sobre production para struct, esperar su cierre en
   verde, y solo entonces lanzar program, y por ultimo data.
3. Verificar en el log de cada uno que el paquete fue detectado, que el
   numero de scripts de deploy y de rollback coinciden, y que el rollback
   figura disponible.

Nota operativa: si el pipeline presenta un error de conexion, se recomienda
redesplegar.

Verificacion: ejecutar la consulta de inventario entregada con este cambio,
que comprueba la existencia de los 268 objetos que el calculo necesita
(101 tablas, 34 vistas y 133 procedimientos y funciones) y que los 22
catalogos de parametrizacion tienen filas. El resultado esperado es
268 esperados / 0 faltantes / COMPLETO.

Rollback: rollback.par y la carpeta RevSQL/ del propio paquete, ejecutados
por el pipeline en orden inverso: data, program, struct.
```

---

## 4. Evidencia que exige la politica de Gestion del Cambio

La politica de SP LATAM pide **certificacion en el ambiente inmediatamente
anterior con evidencia adjunta**. Para este CHG, ese ambiente es **DEMO**, y
hace falta una evidencia por subtask:

| Subtask | Evidencia a adjuntar |
|---|---|
| 1 | Log del job de DEMO de `tf_rcncr_ws5_infra` terminado en SUCCESS, con el resumen del `terraform apply`, y captura del bucket y del rol ya creados en la consola de la cuenta de DEMO |
| 2 | Lo mismo para `tf_rcncr_linea_ws5_infra` |
| 3 | Log del job de DEMO de los tres repositorios terminados en SUCCESS, con `Rollback disponible: 'true'`, y el resultado de la consulta de inventario en DEMO dando `0 faltantes` |

Y ademas, para el CHG completo:

- Aprobacion de **PEER**, **Manager** y **Product Owner**.
- **Placa de inicio** por correo. Sin ella el cambio **no se ejecuta y se
  considera cancelado**.
- Placa de cierre con la evidencia de las pruebas post implementacion.
- **PIR** si el cambio falla o genera efectos no esperados.

---

## 5. Lo que hay que resolver antes de presentar este CHG

| # | Asunto | Estado |
|---|---|---|
| 1 | **Clasificacion.** El BPP arranco el 23 de noviembre y su Fase 1 **no autoriza Normales de impacto o riesgo ALTO**. Este cambio es aditivo y no afecta disponibilidad, de modo que la clasificacion que corresponde es **bajo o medio con CAB** | Hay que confirmarlo con Change Management |
| 2 | **Dia de recepcion.** El CAB recibe **lunes y jueves** hasta las 10:00 Colombia, y en Fase 1 es la **unica** via: AID y ScoreCard estan inhabilitados. Del **26 al 30 de noviembre** hay congelamiento total | La ventana util de ejecucion es del **1 al 10 de diciembre** |
| 3 | **Hora de la ventana.** La tabla de horarios por tipo de servicio nombra a Teradata y **no nombra a Redshift** | Hay que preguntar a Change Management en que categoria cae |
| 4 | **El datashare de produccion no existe todavia.** Pedido en `PETICION_DATASHARE_PROD_SERVICENOW.md` | El despliegue de los objetos no lo necesita; la primera **ejecucion** si |
| 5 | **El paquete del UNLOAD (SLCOPRBA-1820) no esta en este CHG.** Es el procedimiento que escribe las siete tablas a S3 | Sin el, el bucket de la subtask 2 queda creado y nadie escribe en el |

