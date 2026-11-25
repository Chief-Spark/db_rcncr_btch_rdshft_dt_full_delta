# Despliegue manual en **PRODUCCION (PDN)** — calculo Reconocer + exportador UNLOAD

Paquete para ejecutar con cliente SQL contra el cluster de **PDN**, en la base
del proyecto. Va documentado sobre el **CHG3122759**.

**Incluye los cuatro ajustes que salieron del despliegue manual a DEMO**
(reportados por Neil Tellez el 2026-11-24). Ese es el motivo de esta nueva
version del paquete, y estan listados al final de este documento.

**Son 178 archivos de estructura y programas, mas 2 de ejecucion**, y van
**en el orden de su carpeta y, dentro de ella, en el orden de su numero**.

| Carpeta | Archivos | Que es |
|---|---|---|
| `01_STRCT_1353` | 51 | Tablas, vistas y catalogos del calculo. Solo DDL |
| `02_PGM_1353` | 122 | Los procedimientos del calculo. Solo DDL |
| `03_STRCT_1820` | 2 | Configuracion y control del exportador. Solo DDL |
| `04_PGM_1820` | 3 | Los procedimientos del exportador. Solo DDL |
| `05_EJECUCION` | 2 | **Aqui si se ejecuta el proceso.** Primero la cadena, luego el UNLOAD |
| `06_VALIDACION` | 1 | Tres consultas de comprobacion. Al final |
| `90_ROLLBACK` | — | Solo si hay que revertir. No se ejecuta en un despliegue normal |

---

## 0. ESTE PAQUETE ES LA ULTIMA TAREA DEL CHG, NO LA PRIMERA

El orden de implementacion del **CHG3122759** es este, y **cada paso es
prerrequisito del siguiente**:

| # | Tarea | Quien |
|---|---|---|
| 1 | Datashare `ds_dba_rncr_batch`, esquemas, rol propietario y permisos | DBA |
| 2 | Infraestructura: buckets y roles IAM de **GEO** y de **UNLOAD** (Terraform) | Infraestructura / DevSecOps |
| 3 | **Asociar los dos roles IAM al cluster de Redshift de PDN** | DBA / Infraestructura |
| 4 | **Este paquete**: los 178 archivos, la ejecucion y la validacion | DBA |

Saltarse el 1 deja el calculo sin fuente. Saltarse el 2 o el 3 deja el
`UNLOAD` sin donde escribir, que es exactamente lo que paso en DEMO.

## 0.1 TRES COSAS ANTES DE EMPEZAR, Y LAS TRES IMPORTAN

**1 — El usuario tiene que ser DUENO de los tres esquemas**
(`bdm_datos`, `bdm_tempo`, `bdm_stage`).

No basta con `GRANT`. Ningun procedimiento se declara `SECURITY DEFINER`, de
modo que corren con los privilegios de quien los invoca, y **27 procedimientos
hacen `TRUNCATE`**, que en Redshift exige ser dueno del objeto.

**La prueba que cierra esto no es un `SELECT` al datashare**, que es lo que
todo el mundo verifica, sino un `CREATE TABLE` + `TRUNCATE` + `DROP` como el
usuario de ejecucion en `bdm_tempo`. Es la unica que distingue "los permisos
estan puestos" de "los permisos sirven".

**2 — Cada archivo se ejecuta ENTERO, de una sola vez.**

No por sentencias. Los 125 archivos de `02_PGM_1353` y `04_PGM_1820` llevan el
cuerpo del procedimiento entre `$$ ... $$`, y **dentro de ese cuerpo hay puntos
y coma**. Un cliente que parta por `;` los rompe todos. En DBeaver:
**Execute script** (`Alt+X`), nunca *Execute statement* (`Ctrl+Enter`).

**3 — Autocommit encendido**, archivo a archivo, comprobando que cada uno
termina sin error antes de pasar al siguiente.

---

## 0.2 EL RIESGO NUMERO UNO DE PDN: EL TOKEN DEL AMBIENTE

**EL TOKEN DE LA CUENTA DE PRODUCCION ES `pro`, Y ESTA MEDIDO (2026-11-25).**
La salida del apply de `COAWSPPR/TF_RCNCR_WS5_INFRA` en PROD/TERRAFORM
(`10 added`) lo dice sin lugar a interpretacion:

```
geo_bucket_name       = "pro-696708350333-rcncr-ws5-geo"
geo_redshift_role_arn = "arn:aws:iam::696708350333:role/BURoleFor-pro-696708350333-rcncr-ws5-redshift-geo"
```

**La cuenta lleva CUATRO etiquetas distintas y manda la cuarta:** Jenkins la
llama **PROD**, su alias de AWS es `eec-aws-us-eits-reconocermaster-prod`, su
tag `Environment` es **`prd`** y lo que la IaC **crea** lleva **`pro`**.

Esta version del paquete ya trae los cuatro literales corregidos a `pro`:

```
geo_config  PROD  bucket           pro-696708350333-rcncr-ws5-geo                 <- MEDIDO
geo_config  PROD  iam_role         ...:role/BURoleFor-pro-...-rcncr-ws5-redshift-geo    <- MEDIDO
nov_config  PROD  triggers_bucket  pro-696708350333-rcncr-ws5-triggers-reconocer-s3     <- MEDIDO
nov_config  PROD  unload_iam_role  ...:role/BURoleFor-pro-...-rcncr-ws5-redshift-unload <- MEDIDO
```

**LOS CUATRO ESTAN MEDIDOS: EL SEGUNDO APPLY YA CORRIO (2026-11-25).** El par
del UNLOAD lo crea el OTRO repositorio, `tf_rcncr_linea_ws5_infra`, y su salida
en PROD/TERRAFORM (`135 added, 0 changed, 0 destroyed`) devuelve exactamente
estos dos nombres:

```
"redshift_unload"  = "arn:aws:iam::696708350333:role/BURoleFor-pro-696708350333-rcncr-ws5-redshift-unload"
s3_triggers_bucket = "pro-696708350333-rcncr-ws5-triggers-reconocer-s3"
```

Se habian puesto por inferencia -- en DEMO los dos repositorios usaron el mismo
token -- y el apply los confirma letra por letra. **La tarea 2 del CHG esta
COMPLETA y el paquete no necesita ningun ajuste previo.**

**Y DOS COSAS DEL SEGUNDO APPLY QUE NO ESTABAN EN DEMO.** El bucket de triggers
va cifrado con **KMS** (`aws:kms`), no con AES256 como el de GEO: si el UNLOAD
del exportador diera `AccessDenied`, el sitio a mirar es el permiso
`kms:GenerateDataKey` del rol, no el nombre del bucket. Y ese bucket quedo con
la notificacion cableada, de modo que **la cadena del consumidor esta ARMADA en
produccion**: lo que el UNLOAD escriba dispara lambdas, Step Functions, Glue y
la carga a DynamoDB.

**En DEMO esta misma suposicion salio MAL.** La cuenta `453645298399` se llama
DEMO en Jenkins, `uat` en el alias de AWS y **`stg`** en todo lo que crea la
infraestructura. El paquete pedia `demo-...` y `uat-...`, y **ninguno de esos
cuatro objetos existia**.

**Por eso la tarea 2 del CHG tiene que devolver la salida del `terraform apply`
con los nombres reales**, y si no coinciden con los de arriba, se corrigen esos
cuatro literales ANTES de ejecutar la carpeta `01` y la `03`. Son cuatro
cadenas, no hay cambio de logica.

**Como se corrige cada uno, que NO es igual en los dos:**

| Tabla | Forma del seed | Que basta |
|---|---|---|
| `nov_config` | `DELETE` + `INSERT` | cambiar el literal y volver a correr el archivo |
| `geo_config` | `INSERT ... WHERE NOT EXISTS` | cambiar el literal **y** los dos `UPDATE` de reconciliacion del final del archivo; el `INSERT` no hace nada donde ya hay filas |

---

## 1 a 4 — La estructura y los programas (178 archivos)

Ejecutar las cuatro carpetas en orden, y dentro de cada una por numero.

Todo es DDL idempotente (`CREATE TABLE IF NOT EXISTS`,
`CREATE OR REPLACE VIEW`, `CREATE OR REPLACE PROCEDURE`), asi que volver a
correr un archivo no rompe nada. **En ningun punto se ejecuta `DROP SCHEMA`**:
los tres esquemas son compartidos con otros equipos.

Si alguno falla, **parar ahi** y reportar el archivo y el mensaje.

## 5 — La ejecucion (2 archivos, y este es el paso largo)

**`001_run_reconocer_e2e_real_full.sql`** ejecuta la cadena completa sobre los
datos reales de PDN, en modo FULL: Unificacion de direcciones -> Ordenamiento
de contactabilidad -> Novedades. Al terminar deja pobladas las siete tablas de
dominio.

**Referencias de tiempo medidas, para dimensionar la ventana:** en DEV, con
~300.000 relaciones, **263 segundos**. En DEMO, con un volumen ~6x mayor,
produjo **2,5 millones de filas** en las siete tablas. PDN es mayor que los
dos: **hay que contar con que este paso es el que marca la duracion de la
ventana**, y conviene lanzarlo con el tiempo medido en DEMO como suelo, no
como techo.

**`002_run_novedades_exportar_7_tablas.sql`** hace el `UNLOAD` de esas siete
tablas a S3, en CSV con cabecera comprimido en GZIP, y escribe un archivo de
control que avisa al consumidor de que la entrega esta completa.

**Dos avisos para este paso:**

- **La georreferenciacion puede fallar sin que eso invalide la corrida.** Corre
  en su propio bloque de excepcion por decision de negocio: si el bucket o el
  rol de GEO no responden, el paso queda anotado como `fallido` y **la cadena
  continua**. No es motivo para parar ni para revertir.
- **El `UNLOAD` si es el entregable, y ahi un fallo si importa.** Lee el bucket
  y el rol de `bdm_datos.nov_config`, fila `PROD`. Si falla, los objetos quedan
  desplegados y las siete tablas pobladas: se corrige la causa (tarea 2 o 3 del
  CHG) y **se vuelve a ejecutar solo este archivo**, que es idempotente.

## 6 — La comprobacion (1 archivo, tres consultas)

**Consulta 1 — el inventario.** Comprueba que esten los **279 objetos** que el
calculo y el exportador necesitan (109 tablas, 34 vistas y 136 procedimientos
y funciones). Lo que se espera:

```
TITULAR   COMPLETO - el calculo Reconocer y el exportador tienen todos sus objetos   279   0
```

Si dice `INCOMPLETO`, las filas `FALTANTE` dicen que objeto falta y en que
esquema. **Esta consulta ya se verifico contra un ambiente real**: en DEMO dio
279 esperados y **0 faltantes**.

**Consulta 2 — los catalogos.** Conteo de filas de los 23 catalogos de
parametrizacion. **Ninguno debe dar 0**: un catalogo existe y esta vacio cuando
un literal del `INSERT` trae una comilla sin escapar, y lo unico que lo detecta
es contar las filas. Los tres de certificacion tienen que dar **51, 90 y 48**.

**Consulta 3 — el resultado.** Las siete tablas de dominio con su conteo, y la
traza del exportador en `nov_export_control`. Punto de interes y Movilidad
salen en **0** y es correcto: la primera espera la respuesta del
geocodificador, la segunda compara contra una foto anterior que en la primera
corrida no existe.

**Y el total del exportador sale algo por debajo de la suma de las siete, por
diseno:** las siete se exportan con `WHERE tipo_identificacion IS NOT NULL AND
numero_identificacion IS NOT NULL`, porque la llave del consumidor es
`tipo || '#' || numero` y una fila sin documento daria una llave nula. En DEMO
la diferencia fue de **1.758 filas sobre 2,5 millones: el 0,07%**.

## 7 — Que hay que devolver como evidencia del CHG

1. Confirmacion de que los **178 archivos de las carpetas 01 a 04** terminaron
   sin error, o el nombre y el mensaje del primero que fallo.
2. Cuanto tardo cada uno de los **2 archivos de `05_EJECUCION`**, y si alguno
   fallo, con el mensaje.
3. **El resultado completo de las tres consultas** de `06_VALIDACION`.
4. **Las cuatro filas de configuracion**, que es lo que prueba que el paquete
   quedo apuntando a la infraestructura real y no a un nombre supuesto:

```sql
SELECT 'nov' AS cual, parametro, valor FROM bdm_datos.nov_config
 WHERE ambiente = 'PROD' AND parametro IN ('triggers_bucket','unload_iam_role')
UNION ALL
SELECT 'geo', parametro, valor FROM bdm_datos.geo_config
 WHERE ambiente = 'PROD' AND parametro IN ('bucket','iam_role');
```

---

## Si hay que revertir

`90_ROLLBACK` trae el reverso de cada paquete y **se ejecuta en el orden
contrario**: `04_PGM_1820`, `03_STRCT_1820`, `02_PGM_1353`, `01_STRCT_1353`.
Dentro de cada carpeta, el orden de los numeros.

Los procedimientos se borran con su firma exacta y **sin `IF EXISTS`**
(Redshift no lo admite ahi), de modo que si un objeto ya no existe ese `DROP`
falla y se continua: es el comportamiento previsto.

**El despliegue es aditivo**: crea objetos y puebla tablas propias de los tres
esquemas. No altera ni borra objetos de otros equipos.

## Lo que este paquete NO hace

- **No crea el bucket ni el rol de S3**, ni el de GEO ni el del UNLOAD, ni los
  asocia al cluster. Eso es la tarea 2 y la 3 del CHG.
- **No crea el datashare.** Es la tarea 1.
- **No ejecuta nada en modo DELTA**, ni nada del juego de pruebas mock: esta
  entrega es unicamente la cadena real en FULL y su exportacion.

---

## Los cuatro ajustes que trae esta version, y por que

Los cuatro salieron del despliegue manual a DEMO del 2026-11-24.

| # | Archivo | Que pasaba | Que se corrigio |
|---|---|---|---|
| 1 | `01_STRCT_1353/023_04_vistas_insumo_ordenamiento_edf_views.sql` | `ERROR: "insumo_direccion" is not a table / HINT: Use DROP VIEW`. **`IF EXISTS` no protege del tipo equivocado**: solo calla el "no existe", nunca el "no es de ese tipo", y es simetrico en las dos direcciones | se quitaron los cuatro `DROP TABLE` y se dejaron solo los `DROP VIEW`. Hoy ningun paquete crea esos cuatro nombres como TABLA |
| 2 | `06_VALIDACION/99_validacion_inventario.sql` | `syntax error at or near "VALUES"`. **`VALUES` como constructor de tabla no existe en Redshift**, es sintaxis de PostgreSQL | se reescribio como `SELECT ... UNION ALL SELECT ...`, con el `CAST` en la primera rama |
| 3 | el mismo archivo | `column "filas_totales" does not exist`. La columna se llama **`registros_total`** | corregido, y el inventario paso de 273 a **279** objetos: se derivo de los `CREATE`/`DROP` simulando el orden del despliegue, en vez de escribirlo a mano |
| 4 | `01_STRCT_1353/009_03_ddl_geo.sql` y `03_STRCT_1820/001_40_ddl_nov_config.sql` | pedian `uat-...` y `demo-...` para la cuenta de DEMO, y **ninguno de esos objetos existia** | corregidos al token real `stg`, medido en la salida del Terraform. **Es la leccion que la seccion 0.2 aplica a PDN** |
