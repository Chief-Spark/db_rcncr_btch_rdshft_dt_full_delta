# Guía de prueba del producto "Esencial" en Redshift (paso a paso, para quien empieza de cero)

> **Última actualización:** 2026-10-15. Reescritura completa de la guía anterior.
> **Qué cambió:** ahora la guía explica cada término, cada sigla y cada comando desde cero. El nivel técnico se mantiene: no se quitó ningún detalle, se agregó la explicación que faltaba.
> **Orden de la guía (el que pidió el usuario):** 1) cómo se despliega en Redshift, 2) qué tablas deben existir y dónde están sus DDL, 3) los pasos de la prueba.
> **Fuentes:** el código real de `Redshift/ddl/`, `Redshift/procedures/`, `Redshift/datos/`, `Redshift/lambda/`, `Redshift/README.md`, `Redshift/VERIFICACION.md`, los `DDL.sql`, `.BTQ` y `.TPT` originales de Teradata, la carpeta `Salidas/` y la documentación oficial de AWS (enlaces en el texto).
> ⚠ **Aviso principal:** nada de lo migrado se ha ejecutado jamás en un cluster Redshift real (lo dice `VERIFICACION.md`). Todo lo que esta guía afirma sobre el comportamiento en el cluster sale de **leer el código** o de **leer la documentación de AWS**. Lo que no se pudo comprobar está marcado como **[SUPUESTO SIN CONFIRMAR]**.

---

## 0. Antes de empezar

### 0.1 Para quién es esta guía

Para una persona que **nunca ha desplegado nada en Redshift** y que debe comprobar que la migración del proceso BATCH2 (de Teradata a Redshift) está quedando bien. Se asume que sabes abrir una terminal de Windows (PowerShell) y copiar y pegar. **No** se asume que sepas qué es un esquema, un procedure, un bucket, un rol de IAM o un UNLOAD: todo se explica la primera vez que aparece, y el glosario de 0.5 los junta.

Idea central, con una analogía: Redshift es un **archivador gigante** (la base de datos). Dentro hay **carpetas** (esquemas), dentro de cada carpeta hay **hojas de Excel** (tablas) y **recetas** (procedures). Una receta se ejecuta con la orden `CALL` y, al terminar, deja **archivos de texto** (CSV) en un **almacén en la nube** (S3). Probar el producto "Esencial" es dar a la receta unos datos de ejemplo y revisar que los archivos que salen traen lo que deben.

### 0.2 El mapa de la ruta completa (en 9 líneas)

```text
 PREPARAR AWS          1) Bucket S3, rol IAM, Lambda (una sola vez)
 CREAR LA BASE         2) CREATE DATABASE ... COLLATE CASE_INSENSITIVE y reconectarse
 DESPLEGAR             3) Esquemas y tablas (ddl) -> funciones -> procedures -> catalogos (datos)
 PREPARAR LA PRUEBA    4) Vistas puente + configuracion de la solicitud 90001 + personas de ejemplo
 AJUSTES DE DESARROLLO 5) (si siguen pendientes) _003 de direccion y layout de exportplano
 EJECUTAR              6) Por pasos (recomendado hoy) o con el CALL del orquestador
 MIRAR                 7) Bitacora en Redshift, archivos en S3, contenido contra la regla 3/3/2/2
 LIMPIAR Y REPETIR     8) Borrar los datos de prueba y volver a cargar (el proceso modifica los datos)
 DECIDIR               9) Checklist de exito
```

Y el recorrido de los datos dentro del proceso BATCH2:

```text
tablas "cubo" (datos de entrada)
   -> PROCESACUBOS : 13 filtros A..J que marcan y borran filas
   -> CUBOEXPORT   : "pivote": N filas por persona pasan a N grupos de columnas (_001, _002, ...)
   -> EXPORTPLANO  : arma el SELECT y lo descarga con UNLOAD
   -> S3           : CON_DATOS, SIN_DATOS e INCONSISTENCIA (archivos CSV)
```

### 0.3 Qué es el producto "Esencial" y qué significa para la prueba

**Definición funcional (dada por negocio):** Esencial permite actualizar los datos de contacto para campañas de mantenimiento de cartera y cobranza. Entrega, **según disponibilidad de información**, hasta:

| Canal | Cantidad máxima entregada por persona |
|---|---|
| Direcciones físicas | 3 |
| Teléfonos fijos | 3 |
| Celulares | 2 |
| Correos electrónicos | 2 |

"Hasta" significa que, si una persona tiene menos datos que el máximo, se entregan menos. Si tiene más, se entregan solo los primeros (por prioridad). A eso se le llama **truncar** a 3/3/2/2.

**Qué significa para la prueba:** hay que conservar y comprobar esa tabla de canales 3/3/2/2. En el pipeline, estos límites **no son un parámetro suelto del `CALL`**. Son filas de configuración en `rec_stage.batch_salidas_campos`, columna `cantidad_max_campo` (equivale a `BATCH_SALIDAS_CAMPOS.CANTIDAD_MAX_CAMPO` en Teradata), una fila por campo, asociada a un `id_solicitud` y un `id_plantilla`. No existe en el workspace un catálogo real de plantillas con nombres comerciales ("Esencial", "Plus"...), así que la prueba define su propia plantilla de ejemplo (`id_plantilla = 9001`, `id_solicitud = 90001`).

**Hallazgo clave, verificado leyendo el código el 2026-10-15** (el truncamiento y el "gap" del layout):

1. **Quién trunca:** el recorte a 3/3/2/2 lo hace el procedure `sp_batch2_filtro_g` (parte de PROCESACUBOS), **no** `exportplano`. Solo funciona si `batch_salidas_campos.codigo_campo` usa los códigos reales `DT_NUM` (teléfono), `DD_DIR` (dirección), `DC_NUMERO` (celular) y `CE_CORREO` (correo), **y** si `rec_stage.batch2_homologacion` tiene filas que los relacionen con su cubo. Esa tabla **no tiene script de carga en el workspace**, por eso la guía trae filas de ejemplo (sección 2.6). La guía anterior usaba los códigos `TEL`, `DIR`, `CEL`, `MAI`, que el código no reconoce.
2. **Gap del layout (sigue vigente):** `rec_stage.sp_batch2_exportplano`, el procedure que escribe los CSV, **no lee `batch_salidas_campos`**. Usa un layout fijo de 34 columnas ("CON DATOS") o 14 columnas ("SIN DATOS"): **1** teléfono, **1** dirección, **1** correo y **ningún celular**. Su propia cabecera de código dice lo contrario (que arma el SELECT desde `batch_salidas_campos`); es un comentario desactualizado (hallazgo H4, sección 4.C).
3. **Segundo gap, del pivote:** `w_cubo_direccion` solo tiene los grupos `_001` y `_002` y `sp_batch2_cubo_export` solo toma `rn <= 2` direcciones. Esencial pide 3.

**Consecuencia:** con el código de hoy **no se puede ver el 3/3/2/2 completo dentro del CSV**. Se puede comprobar el recorte en las tablas intermedias y se puede generar el CSV con el layout actual. El detalle de qué cambiar para llegar al 3/3/2/2 completo está en el paso 1 de la sección 3. Esta guía **no modifica código**: solo lo documenta.

### 0.4 Qué se puede probar hoy y qué no (resumen honesto)

| Qué | Estado hoy | Por qué |
|---|---|---|
| Generar `CON_DATOS`, `SIN_DATOS` e `INCONSISTENCIA` en S3 | Se espera que sí | Pasos 1 a 7 del orquestador, ejecutables a mano. Nunca corrieron en Redshift. |
| Recorte a 3/3/2/2 en las tablas cubo (después de PROCESACUBOS) | Se espera que sí | Lo hace `sp_batch2_filtro_g` si se cargan los códigos reales y `batch2_homologacion` (sección 2.6). |
| Ver 3/3/2/2 **dentro del CSV** | No | Layout fijo de `exportplano` y falta `_003` de dirección (paso 1 de la sección 3). |
| Que el `CALL` del orquestador termine sin error | No | Falla en el paso 9 (`sp_batch2_completitud_canal`) porque faltan vistas que la migración aún no construye (sección 2.4). Los 3 CSV ya quedaron en S3 antes de esa falla. |
| Archivo `ALERTAS` y archivo de log | No | Dependen de los pasos 10 a 12, que también fallan por objetos faltantes. |

Por eso la guía ofrece **dos caminos** (paso 3 de la sección 3): **Camino A, por pasos** (recomendado hoy: cada `CALL` es su propia transacción y un error no deshace lo anterior) y **Camino B, el `CALL` del orquestador** (se espera error en el paso 9).

### 0.5 Glosario (con analogías, sin perder rigor)

| Término | En palabras simples | Con precisión |
|---|---|---|
| **Amazon Redshift** | Un archivador gigante para tablas, pensado para consultar muchos datos rápido. | Almacén de datos (data warehouse) de AWS basado en PostgreSQL, que habla SQL. |
| **Cluster** | El "edificio" donde vive el archivador: una o más computadoras trabajando juntas. | Conjunto de nodos de Redshift. Tiene un **endpoint** (dirección de red) y escucha en el puerto **5439**. |
| **Endpoint** | La dirección del edificio. | Nombre DNS tipo `<cluster>.<id>.<region>.redshift.amazonaws.com`. |
| **Base de datos** | Un archivador completo dentro del cluster. | En un cluster puede haber varias. Una conexión trabaja con **una sola** a la vez (no existe `USE`). |
| **Esquema** | Una **carpeta** dentro del archivador. | Espacio de nombres: `rec_stage.batch_cubo_persona` es la tabla `batch_cubo_persona` en el esquema `rec_stage`. Reemplaza a las "bases de datos" de Teradata. |
| **Tabla** | Una **hoja de Excel**: columnas con nombre y filas con datos. | Estructura que guarda filas con columnas tipadas. |
| **Vista** | Una hoja que no guarda datos propios: muestra el resultado de otra consulta. | `CREATE VIEW` guarda una consulta con nombre. |
| **SQL** | El idioma para hablar con la base de datos. | Lenguaje de consulta. `SELECT` lee, `INSERT` agrega filas, `DELETE` borra. |
| **DDL** | Las instrucciones que **construyen** las hojas y carpetas. | *Data Definition Language*: `CREATE`, `ALTER`, `DROP`. Los archivos de `Redshift/ddl/` son DDL. |
| **Procedure / SP** | Una **receta** guardada en la base de datos que se ejecuta con una orden. | *Stored procedure* (procedimiento almacenado). Aquí está escrito en PL/pgSQL (`LANGUAGE plpgsql`). |
| **CALL** | La orden "ejecuta esta receta". | `CALL esquema.procedimiento(argumentos);`. No se puede usar dentro de un `SELECT`. |
| **IN / INOUT** | Entrada, o entrada y salida de una receta. | Un parámetro `INOUT` devuelve un valor. En llamadas anidadas Redshift exige `INOUT` (no `OUT`). |
| **Transacción, COMMIT, ROLLBACK** | Un grupo de cambios que se guardan **todos o ninguno**. | Cada `CALL` de nivel superior es una transacción. Si falla, se deshace (`ROLLBACK`). `TRUNCATE` hace `COMMIT` implícito dentro de un procedure. |
| **UDF** | Una función que tú defines, como una calculadora propia. | *User-defined function*. Aquí hay **SQL UDF** (escritas en SQL) y **Lambda UDF** (Redshift llama a una función Lambda). |
| **AWS Lambda** | Un programa pequeño que AWS ejecuta cuando alguien lo llama, sin que mantengas un servidor. | Servicio *serverless*. Tiene **runtime** (lenguaje y versión, aquí Python 3.12) y **handler** (la función de entrada, aquí `lambda_function.lambda_handler`). |
| **Amazon S3** | Un almacén de archivos en la nube. | Servicio de almacenamiento de objetos. |
| **Bucket** | Una **caja grande con nombre único** dentro de S3. | Contenedor de objetos. Debe estar en la **misma región** que el cluster para `UNLOAD` y `COPY` sin cláusula `REGION`. |
| **Prefijo / objeto** | S3 no tiene carpetas de verdad: el "camino" es parte del nombre del archivo. | `s3://mi-bucket/batch2/esencial/CON_DATOS_...` es un objeto cuyo nombre empieza por el prefijo `batch2/esencial/`. |
| **IAM** | El sistema de permisos de AWS. | *Identity and Access Management*. |
| **IAM Role (rol)** | Un **carné con permisos** que un servicio puede ponerse temporalmente. | Identidad sin contraseña, con políticas de permisos. Redshift "asume" el rol para escribir en S3. Se asocia al cluster. |
| **ARN** | La dirección única de cualquier cosa en AWS. | *Amazon Resource Name*, p. ej. `arn:aws:iam::<cuenta>:role/<rol>`. |
| **UNLOAD** | "Saca el resultado de este SELECT y guárdalo como archivos en S3". | Comando de Redshift. Agrega su propio **sufijo** al nombre (con `PARALLEL OFF` termina en `000`). |
| **COPY** | Lo contrario: "carga a una tabla los datos de estos archivos de S3". | Comando de Redshift para cargar desde S3. |
| **Collation (colación)** | La regla que decide si `a` y `A` son "iguales". | Con `CASE_INSENSITIVE` no se distingue mayúscula de minúscula (equivale a `NOT CASESPECIFIC` de Teradata). Se fija **al crear la base** y no se cambia después. |
| **Teradata** | El sistema de bases de datos **de origen** (el que se está reemplazando). | Motor donde corría BATCH2 antes de la migración. |
| **BTEQ** (`.BTQ`) | Guiones de SQL para Teradata. | *Basic Teradata Query*: scripts con SQL y control de flujo. |
| **TPT** (`.TPT`) | La herramienta de Teradata para exportar archivos. | *Teradata Parallel Transporter*. En Redshift lo reemplaza `UNLOAD`. |
| **Cubo** | Una tabla de datos de **entrada** de un tipo (personas, direcciones, teléfonos...). | Aquí `batch_cubo_persona`, `batch_cubo_direccion`, etc. |
| **Pivote** | Girar la tabla: varias **filas** por persona pasan a varios **grupos de columnas** en una sola fila. | `w_cubo_telefono` tiene `numero_001`, `numero_002`... Cada grupo `_00N` es la fila número N de esa persona. |
| **Lote** | Un número correlativo que etiqueta una ejecución, como el número de un recibo. | Se saca de `rec_mtdat.lote_id` con `sp_batch2_genera_lote`. |
| **Plantilla** | El "molde" que dice qué columnas lleva el archivo de salida. | `id_plantilla`. Define campos y cantidades máximas. |
| **Solicitud** | Un pedido concreto de un cliente. | `id_solicitud`. Una solicitud usa una plantilla. |
| **CSV** | Un archivo de texto donde cada línea es una fila y las columnas se separan con un carácter. | *Comma-separated values*; aquí el separador es `;`. |
| **Delimitado / ancho fijo** | Delimitado: un separador entre columnas. Ancho fijo: cada columna ocupa un número fijo de posiciones. | `FE_CSV` (delimitado) y `FE_TXT` (ancho fijo) en `batch_datos_generales.formato_salida`. En Redshift, el código siempre escribe delimitado con `;`. |
| **Cabecera (header)** | La primera línea del archivo, con los nombres de las columnas. | Opción `HEADER` de `UNLOAD`; `IGNOREHEADER` de `COPY` la salta al cargar. |
| **PN / PJ** | Persona Natural (un individuo) / Persona Jurídica (una empresa). | En `rec_vista.persona`: tipos de identificación 1 y 4 = natural, 2 y 3 = jurídica. |
| **CIIU** | Código de la actividad económica de una empresa o persona. | Clasificación Industrial Internacional Uniforme. |
| **DANE** | Los códigos oficiales de ciudades y departamentos de Colombia. | Columnas `codigo_dane_ciudad` y `codigo_dane_departamento`. |
| **Idempotente** | Puedes repetirlo y queda igual que la primera vez. | Un script `CREATE TABLE IF NOT EXISTS` es idempotente. |
| **Bitácora (log)** | El cuaderno donde el proceso anota qué hizo y si falló. | Tablas `rec_mtdat.log_td` y `rec_mtdat.log_td_detalle`. |
| **Marcador (placeholder)** | Un texto entre `<...>` que **tú** debes reemplazar por tu valor real. | Ej.: `<ENDPOINT_DEL_CLUSTER>`. |
| **psql / RSQL** | Programas de terminal para hablar con la base. | `psql` es el cliente de PostgreSQL; **RSQL** es el de Amazon Redshift. |
| **Query Editor v2** | Un editor de SQL dentro de la consola web de AWS. | Cliente web; **no** entiende los metacomandos de `psql`. |
| **Metacomando** | Una orden **del programa cliente**, no de la base. | `\i archivo.sql`, `\c base`, `\q`. Empiezan con `\`. |
| **Región** | La zona geográfica de AWS donde viven tus recursos. | Ej.: `us-east-1`. |

### 0.6 Convenciones de la guía

- **⚠** marca un punto de riesgo. **✔ Resultado esperado** marca lo que debes ver tras cada paso.
- **[VERIFICADO]**: leído en el archivo real o contrastado con la documentación de AWS. **[SUPUESTO SIN CONFIRMAR]**: no se pudo comprobar sin un cluster real.
- Los textos `<ASÍ>` son marcadores: **reemplázalos** por tus valores. **Nunca** escribas contraseñas reales en la guía, en archivos del repositorio ni en el historial: usa el prompt de `psql` o la variable `PGPASSWORD` (se explica en 1.4).
- `RS` = `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift`. **Todas las rutas relativas de la guía (`ddl\...`, `procedures\...`, `datos\...`) parten de `RS`.** Ubícate ahí antes de ejecutar nada.
- Los comandos son para **Windows PowerShell 5.1** (lo que trae Windows). Las barras `\` y `/` funcionan ambas dentro de `psql`.
- Los bloques SQL dicen en su primera línea (comentario) **dónde** se ejecutan.

---

## 1. Cómo se hace el despliegue en Redshift

"Desplegar" es dejar en Redshift todo lo que el proceso necesita para correr: las carpetas (esquemas), las hojas vacías (tablas), las calculadoras (funciones), las recetas (procedures) y unos pocos datos fijos (catálogos).

### 1.1 Inventario de artefactos (qué es cada archivo)

Todos los archivos existen (comprobado el 2026-10-15 con `Test-Path`). Rutas absolutas:

| Ruta absoluta | Qué es (lenguaje simple) |
|---|---|
| `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift\README.md` | Explica qué se migró, el orden de despliegue y cómo llamar al proceso. |
| `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift\VERIFICACION.md` | Lo que se revisó "a mano" (no hay cluster) y lo que no se pudo verificar. |
| `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift\GUIA_PRUEBA_PRODUCTO_ESENCIAL.md` | Esta guía. |
| `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift\ddl\00_README.md` | Orden de los scripts DDL y diferencias de diseño frente a Teradata. |
| `...\Redshift\ddl\01_schemas.sql` | Crea las 4 carpetas: `rec_stage`, `rec_mtdat`, `rec_datos`, `rec_vista`. |
| `...\Redshift\ddl\02_tablas_configuracion.sql` | Tablas que describen la solicitud y la plantilla (qué se pide y cómo se entrega). |
| `...\Redshift\ddl\03_tablas_cubos.sql` | Las 7 tablas "cubo" con los datos de contacto de entrada. |
| `...\Redshift\ddl\04_tablas_pivote.sql` | Las 5 tablas `w_cubo_*` donde las filas se vuelven columnas. |
| `...\Redshift\ddl\05_tablas_control.sql` | Contador de lote, bitácora, catálogo de homologación, inconsistencias, historia, estadísticas. |
| `...\Redshift\ddl\06_vistas_dimension.sql` | `rec_vista.persona` y `rec_vista.tipo_persona` (natural o jurídica) y `vstg_buropers_tmp`. |
| `...\Redshift\ddl\07_tablas_dependencias_sps.sql` | Motores de "SQL guardado como datos", plan de ejecución, insumo de validación, secuencia 1..100, catálogos. |
| `...\Redshift\ddl\08_funciones_udf.sql` | 8 funciones: 1 de conversión, 4 de similitud (Lambda), 3 de enmascaramiento. **Trae dos marcadores que hay que reemplazar.** |
| `...\Redshift\ddl\09_vistas_dependencias_sps.sql` | La vista `vstgbatchcargaubicestandarizada` y un bloque opcional **comentado** (`/* ... */`) con 7 tablas vacías del proceso P0034. |
| `...\Redshift\ddl\10_tablas_trabajo_f2_4.sql` | `w_borrar_002`, `w_ejecutor` y una lista (en comentarios) de objetos que la migración aún no construye. |
| `...\Redshift\procedures\01_sp_batch2_genera_lote.sql` | La receta que entrega el número de lote. |
| `...\Redshift\procedures\02_sp_batch2_log_helpers.sql` | Auxiliares: anotar inicio y fin en la bitácora, ejecutar SQL con bitácora (`sp_execstring_des`), borrar tablas. |
| `...\Redshift\procedures\03_sp_batch2_cubo_export.sql` | Hace el pivote de los cubos hacia `w_cubo_*`. |
| `...\Redshift\procedures\04_sp_batch2_exportplano.sql` | Arma el SELECT y descarga los CSV con `UNLOAD`. |
| `...\Redshift\procedures\05_sp_batch2_exportlog.sql` | Arma y descarga el archivo de log de la solicitud. |
| `...\Redshift\procedures\06_sp_batch2_actualiza_historia.sql` | Cierra la solicitud (`estado = 'GENERADO'`) y llena la historia si aplica. |
| `...\Redshift\procedures\07_sp_batch2_valida_archivos.sql` | Cuenta los campos configurados de la plantilla (solo informa). |
| `...\Redshift\procedures\08_sp_batch2_procesacubos.sql` | Los 13 filtros (A..J), homologaciones, porcentajes e inconsistencias. Es casi toda la lógica de negocio. |
| `...\Redshift\procedures\09b_sp_batch2_motores_sql.sql` | Dos "motores": `sp_batch2_estadisticas_cfg` y `sp_batch2_plan_ejecucion_shell`. |
| `...\Redshift\procedures\09_sp_batch2_otros.sql` | `transpuesta`, `completitud_canal`, `cantrepcanal_con`, `estadisticas`, `estadisticas_export`. |
| `...\Redshift\procedures\10_sp_batch2_proceso_batch2.sql` | **El orquestador**: llama a todo lo anterior en orden. |
| `...\Redshift\datos\01_catalogos_motor.sql` | Filas fijas: 18 de `batch_archivo_log`, 18 `LOG` de `batch_motor_log`, 12 `ITERADOR` de `pro_plan_ejecucion`. Tiene tildes (UTF-8). |
| `...\Redshift\lambda\udf_similitud\lambda_function.py` | El código de la Lambda que atiende las 4 funciones de similitud. |
| `...\Redshift\lambda\udf_similitud\test_lambda_function.py` | 36 pruebas unitarias de esa Lambda. |
| `...\Redshift\lambda\udf_similitud\casos_validacion_redshift.sql` | Casos para comprobar las funciones ya desplegadas en Redshift (toda fila debe dar `ok = 'S'`). |
| `...\Redshift\lambda\udf_similitud\casos_validacion_teradata.sql` | Los mismos casos para correr en Teradata y comparar. |

Cuando la columna dice `...\Redshift\`, léela como `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift\`. La tabla completa de referencias, con todas las rutas, está en la sección 4.D.

Notas:
- No existe `lambda\udf_similitud\README.md`: los datos de despliegue de la Lambda están en la cabecera de `ddl\08_funciones_udf.sql` (líneas 50 a 70) y en las secciones 1.2.4 a 1.2.8 de esta guía.
- No existe ningún script `COPY` ni de carga del archivo de insumo en `RS`. La carga de datos de entrada es parte de otros procesos del pipeline mayor (lo dice `README.md`).
- Datos de referencia de Teradata, **fuera** de `RS`: `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Salidas\` (muestras `CON_DATOS_4421_...`, `SIN_DATOS_4421_...`, `INCONSISTENCIA_4421_...`, `ALERTAS-4421_...`, `BATCH_SOLICITUD_BATCH.ARCHIVO_LOG`).

### 1.2 Prerrequisitos (qué debe estar listo antes de desplegar)

| # | Qué necesitas | Para qué sirve | Cómo comprobarlo |
|---|---|---|---|
| 1 | Un **cluster** Redshift en estado `available` y su **endpoint** | Es donde se despliega todo | Consola AWS > Amazon Redshift > Clusters. Con la CLI: `aws redshift describe-clusters --cluster-identifier <CLUSTER> --query "Clusters[0].[ClusterStatus,Endpoint.Address,Endpoint.Port]"` |
| 2 | **Red**: tu computador debe llegar al puerto **5439** del cluster | Sin esto `psql` se queda esperando | `Test-NetConnection <ENDPOINT_DEL_CLUSTER> -Port 5439` debe decir `TcpTestSucceeded : True` |
| 3 | Un **usuario de base de datos** con permisos suficientes | Crear y llenar objetos | Ver 1.2.1 |
| 4 | Un **cliente SQL** | Escribir y ejecutar SQL | Ver 1.3 |
| 5 | La **AWS CLI** configurada | Crear el bucket, el rol y la Lambda; mirar y bajar archivos de S3 | `aws sts get-caller-identity` debe devolver tu cuenta |
| 6 | Una **base de datos** con collation **CASE_INSENSITIVE** | Que las comparaciones de texto se comporten como en Teradata | Ver 1.4, paso D1 |
| 7 | Un **bucket S3** en la misma región que el cluster | Destino de los CSV (y origen del `COPY`, opción B) | Ver 1.2.2 |
| 8 | Un **rol IAM** con permiso sobre ese bucket, **asociado al cluster** | `UNLOAD` y `COPY` lo "asumen" | Ver 1.2.3 |
| 9 | La **Lambda** de similitud desplegada y un rol que permita invocarla | Las 4 funciones de similitud (las usa `FILTRO_F`) | Ver 1.2.4 a 1.2.8 |
| 10 | Una carpeta de trabajo local | Archivos temporales de la prueba (fuera del repositorio) | Ej.: `C:\prueba_esencial\` |

#### 1.2.1 Usuario y permisos

Lo más simple para esta prueba es usar el **superusuario** que se crea con el cluster (el usuario administrador). Un superusuario puede todo lo de la tabla. Si usas un usuario normal, necesita:

| Acción | Permiso necesario | Cómo se concede (lo hace un superusuario) |
|---|---|---|
| `CREATE SCHEMA`, `CREATE DATABASE` | `CREATE` sobre la base / `CREATEDB` (o ser superusuario) | `GRANT CREATE ON DATABASE recon_batch2 TO <USUARIO>;` / `ALTER USER <USUARIO> CREATEDB;` |
| `CREATE TABLE`, `CREATE VIEW` | Ser dueño del esquema (lo es quien lo creó) o tener `CREATE` en él | `GRANT CREATE ON SCHEMA rec_stage TO <USUARIO>;` |
| `CREATE PROCEDURE` y funciones SQL | `USAGE` sobre el lenguaje `plpgsql` (procedures) y `sql` (funciones SQL) ([AWS](https://docs.aws.amazon.com/redshift/latest/dg/r_GRANT.html)). **[SUPUESTO SIN CONFIRMAR]:** que ya esté concedido a todos por omisión | Si sale `permission denied for language plpgsql`: `GRANT USAGE ON LANGUAGE plpgsql TO <USUARIO>;` |
| `CREATE EXTERNAL FUNCTION` (las 4 de similitud) | `USAGE` sobre el lenguaje `exfunc` o ser superusuario. `CREATE OR REPLACE` de una función externa pide superusuario ([AWS](https://docs.aws.amazon.com/redshift/latest/dg/udf-creating-a-lambda-sql-udf.html)) | `GRANT USAGE ON LANGUAGE exfunc TO <USUARIO>;` |
| `UNLOAD` / `COPY` | `SELECT` sobre los datos y permiso para usar el rol IAM: el rol `default` del cluster o, si no, el privilegio `ASSUMEROLE` | `GRANT ASSUMEROLE ON 'arn:aws:iam::<CUENTA>:role/<ROL>' TO <USUARIO> FOR UNLOAD;` (la cláusula `FOR` acepta `ALL`, `COPY`, `UNLOAD`, `EXTERNAL FUNCTION` o `CREATE MODEL`; ver la [documentación de GRANT](https://docs.aws.amazon.com/redshift/latest/dg/r_GRANT.html)). Para las funciones Lambda: `... FOR EXTERNAL FUNCTION;` |

Los procedures de este proyecto no usan `SECURITY DEFINER` (verificado con búsqueda en `procedures/*.sql`): se ejecutan con los permisos de **quien hace el `CALL`**. Por eso ese usuario necesita `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `CREATE` y `DROP` sobre las tablas del proceso, además de poder hacer `UNLOAD`.

⚠ Si no sabes cuál usar: pide al administrador del cluster que haga el despliegue con el superusuario y que te deje el usuario de prueba con `GRANT ALL ON ALL TABLES IN SCHEMA ...` sobre los cuatro esquemas.

#### 1.2.2 Bucket S3

Un bucket es una caja con **nombre único en todo AWS**. Debe estar en la **misma región** del cluster: `UNLOAD` y `COPY` suponen la misma región salvo que agregues la cláusula `REGION` ([UNLOAD](https://docs.aws.amazon.com/redshift/latest/dg/r_UNLOAD.html), [COPY](https://docs.aws.amazon.com/redshift/latest/dg/copy-parameters-data-source-s3.html)). El código de `exportplano` **no** usa `REGION`.

```powershell
# PowerShell, en cualquier carpeta. Reemplaza <BUCKET> y <REGION_DEL_CLUSTER>.
aws s3 mb s3://<BUCKET> --region <REGION_DEL_CLUSTER>
```

✔ Resultado esperado: `make_bucket: <BUCKET>`. Si dice `BucketAlreadyExists`, el nombre ya lo usa alguien más: prueba otro (p. ej. agrega tu cuenta y la fecha).

#### 1.2.3 Rol IAM para `UNLOAD` y `COPY`, asociado al cluster

Un rol necesita dos cosas: una **política de confianza** (quién puede ponérselo: aquí el servicio Redshift) y una **política de permisos** (qué puede hacer: aquí leer y escribir en el bucket). `UNLOAD` necesita permisos de lectura (GET), listado (LIST) y escritura (PUT) sobre el bucket ([AWS](https://docs.aws.amazon.com/redshift/latest/dg/copy-usage_notes-access-permissions.html)).

Crea los dos archivos JSON **fuera del repositorio** (carpeta de trabajo local) y luego el rol:

```powershell
# PowerShell. Carpeta de trabajo local (fuera del repositorio):
New-Item -ItemType Directory -Force -Path C:\prueba_esencial | Out-Null
Set-Location C:\prueba_esencial

# 1) Politica de confianza: deja que el servicio Redshift use el rol
@'
{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"redshift.amazonaws.com"},"Action":"sts:AssumeRole"}]}
'@ | Set-Content -Path trust-redshift.json -Encoding ascii

# 2) Politica de permisos: S3 (UNLOAD/COPY) y, para la Lambda, invocar solo esa funcion
@'
{"Version":"2012-10-17","Statement":[
 {"Effect":"Allow","Action":["s3:PutObject","s3:GetObject","s3:ListBucket","s3:GetBucketLocation"],
  "Resource":["arn:aws:s3:::<BUCKET>","arn:aws:s3:::<BUCKET>/*"]},
 {"Effect":"Allow","Action":"lambda:InvokeFunction",
  "Resource":"arn:aws:lambda:<REGION_DEL_CLUSTER>:<CUENTA>:function:udf_similitud"}
]}
'@ | Set-Content -Path permisos-redshift.json -Encoding ascii
```

Reemplaza en el segundo archivo `<BUCKET>`, `<REGION_DEL_CLUSTER>` y `<CUENTA>` (ábrelo con el Bloc de notas). Luego:

```powershell
# PowerShell, en C:\prueba_esencial
aws iam create-role --role-name RolUnloadRedshift --assume-role-policy-document file://trust-redshift.json
aws iam put-role-policy --role-name RolUnloadRedshift --policy-name s3-y-lambda-batch2 --policy-document file://permisos-redshift.json
aws redshift modify-cluster-iam-roles --cluster-identifier <CLUSTER> --add-iam-roles arn:aws:iam::<CUENTA>:role/RolUnloadRedshift
```

✔ Resultado esperado: el primer comando imprime un JSON con el `Arn` del rol (anótalo: es tu `<ROL_ARN>`); el segundo no imprime nada; el tercero devuelve el cluster con el rol en estado `adding` y luego `in-sync`. Comprueba con `aws redshift describe-clusters --cluster-identifier <CLUSTER> --query "Clusters[0].IamRoles"` hasta ver `in-sync`.

⚠ **Un solo rol con S3 y Lambda es para simplificar la prueba.** En producción conviene separarlos (mínimo privilegio). ⚠ Si el comando de la Lambda dice que el rol "no puede ser asumido", espera unos 10 segundos: IAM tarda en propagar los roles nuevos.

**Qué hacer si falla:**

| Mensaje o síntoma | Causa probable | Solución |
|---|---|---|
| `EntityAlreadyExists` en `create-role` | El rol ya existe | Usa otro nombre o reutiliza el existente con sus políticas |
| `AccessDenied` / `not authorized to perform iam:CreateRole` | Tu usuario AWS no puede crear roles | Pide al administrador de AWS que lo cree con estas dos políticas |
| Luego, en `UNLOAD`: `S3ServiceException: Access Denied` | El rol no está asociado al cluster, o no tiene permisos sobre ese bucket | Revisa `IamRoles` del cluster y el `Resource` del bucket |

#### 1.2.4 Qué es la Lambda y por qué hace falta

Cuatro funciones de similitud (`f_bach_similitud_dir_mz`, `f_porc_similitud`, `f_bach_similitud_tel`, `f_bach_similitud_email`) comparan textos (direcciones, teléfonos, correos) y devuelven qué tan parecidos son. Redshift no puede calcular la "distancia de edición" en SQL puro, así que **llama a una función Lambda** escrita en Python. **Una sola** Lambda atiende las cuatro: elige cuál función ejecutar leyendo el nombre de la función externa que la llamó.

Las usa `sp_batch2_filtro_f`. Aunque en la prueba la tabla de insumo esté vacía y la Lambda no llegue a ejecutarse **[SUPUESTO SIN CONFIRMAR]**, las 4 funciones **deben existir**, porque `FILTRO_F` las nombra dentro de un `CREATE TABLE ... AS SELECT` y Redshift revisa que existan al analizar la consulta (si faltan, `FILTRO_F` aborta).

#### 1.2.5 Datos de la Lambda (verificados leyendo el código)

| Dato | Valor | Dónde se comprobó |
|---|---|---|
| Runtime | Python 3.12 (sugerido por la cabecera de `ddl\08_funciones_udf.sql`) | `ddl\08_funciones_udf.sql`, líneas 59 y 60 |
| Handler | `lambda_function.lambda_handler` | `lambda_function.py`, función `lambda_handler` |
| Dependencias | Ninguna externa: solo `json`, `math`, `os`, `re` | `lambda_function.py`, importaciones |
| Paquete | Un zip con **solo** `lambda_function.py` | no hace falta incluir pruebas ni `.sql` |
| Timeout | 5 minutos (300 s) | cabecera de `ddl\08_funciones_udf.sql` |
| Memoria | No especificada en el repo. La distancia de edición es O(n x m) en Python: sube la memoria si el volumen crece | `lambda_function.py`, cabecera |
| Variable opcional | `UDF_NOMBRE`: fuerza una sola función si despliegas 4 Lambdas separadas | `lambda_function.py` |

#### 1.2.6 Probar la Lambda en tu computador antes de subirla

```powershell
# PowerShell
Set-Location "d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift\lambda\udf_similitud"
python -B -m unittest test_lambda_function
```

✔ Resultado esperado: `Ran 36 tests` y al final `OK`. (`-B` evita crear la carpeta `__pycache__` dentro del repositorio.)

#### 1.2.7 Empaquetar y crear la Lambda

```powershell
# PowerShell. Crea el zip en tu carpeta de trabajo, no en el repositorio.
Compress-Archive -Path "d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift\lambda\udf_similitud\lambda_function.py" -DestinationPath C:\prueba_esencial\udf_similitud.zip -Force

# Rol de ejecucion de la Lambda (el que usa la propia Lambda para escribir sus logs)
@'
{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}
'@ | Set-Content -Path C:\prueba_esencial\trust-lambda.json -Encoding ascii
aws iam create-role --role-name RolEjecucionUdfSimilitud --assume-role-policy-document file://C:/prueba_esencial/trust-lambda.json
aws iam attach-role-policy --role-name RolEjecucionUdfSimilitud --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# Crear la funcion (espera ~10 s despues de crear el rol)
aws lambda create-function --function-name udf_similitud --runtime python3.12 --handler lambda_function.lambda_handler --timeout 300 --zip-file fileb://C:/prueba_esencial/udf_similitud.zip --role arn:aws:iam::<CUENTA>:role/RolEjecucionUdfSimilitud --region <REGION_DEL_CLUSTER>
```

✔ Resultado esperado: un JSON con `"FunctionName": "udf_similitud"`, `"Runtime": "python3.12"` y `"State": "Active"` (o `Pending` unos segundos). Prueba la función directamente:

```powershell
# PowerShell. Pide a la Lambda comparar dos telefonos (como lo haria Redshift)
'{"external_function":"rec_vista.f_bach_similitud_tel","num_records":1,"arguments":[["2826373","2826373"]]}' | Set-Content -Path C:\prueba_esencial\evento.json -Encoding ascii
aws lambda invoke --function-name udf_similitud --cli-binary-format raw-in-base64-out --payload file://C:/prueba_esencial/evento.json --region <REGION_DEL_CLUSTER> C:\prueba_esencial\salida.json
Get-Content C:\prueba_esencial\salida.json
```

✔ Resultado esperado: el archivo `salida.json` contiene un **texto JSON entre comillas** (la Lambda devuelve un string, por eso las comillas internas salen con `\`). Debes ver `success\": true` y `results\": [100]` (el caso `TEL-1 iguales` de `casos_validacion_redshift.sql` espera 100).

| Síntoma | Causa probable | Solución |
|---|---|---|
| `The role defined for the function cannot be assumed by Lambda` | El rol es nuevo y IAM aún no propaga | Espera 10 s y repite `create-function` |
| `ResourceConflictException: Function already exist` | Ya la creaste | Actualiza el código: `aws lambda update-function-code --function-name udf_similitud --zip-file fileb://C:/prueba_esencial/udf_similitud.zip --region <REGION_DEL_CLUSTER>` |
| La respuesta trae `"success": false` y `error_msg` | El evento está mal formado | Revisa que `arguments` sea una lista de listas |

#### 1.2.8 Reemplazar `<LAMBDA_UDF_SIMILITUD>` e `<IAM_ROLE_LAMBDA_ARN>` en `ddl\08_funciones_udf.sql`

El archivo trae dos **marcadores** que Redshift no entiende: `<LAMBDA_UDF_SIMILITUD>` (el nombre o ARN de la Lambda) e `<IAM_ROLE_LAMBDA_ARN>` (el rol que Redshift usa para invocarla, o la palabra `default`). Aparecen **4 veces cada uno** en sentencias (líneas 102-103, 114-115, 123-124 y 137-138) y además en comentarios (líneas 61-62). **No edites el original del repositorio.** Genera una copia fuera del repo:

```powershell
# PowerShell 5.1. Escribe UTF-8 SIN BOM (un BOM al inicio puede romper psql).
$RS   = "d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$txt  = [System.IO.File]::ReadAllText("$RS\ddl\08_funciones_udf.sql", $utf8)
$txt  = $txt.Replace('<LAMBDA_UDF_SIMILITUD>','udf_similitud').Replace('<IAM_ROLE_LAMBDA_ARN>','arn:aws:iam::<CUENTA>:role/RolUnloadRedshift')
[System.IO.File]::WriteAllText("C:\prueba_esencial\08_funciones_udf_desplegar.sql", $txt, $utf8)

# Comprobacion: no deben quedar marcadores y deben verse 4 pares LAMBDA / IAM_ROLE
([regex]::Matches($txt,'<LAMBDA_UDF_SIMILITUD>|<IAM_ROLE_LAMBDA_ARN>')).Count
Select-String -Path C:\prueba_esencial\08_funciones_udf_desplegar.sql -Pattern "^LAMBDA '|^IAM_ROLE '"
```

✔ Resultado esperado: el contador imprime `0` y `Select-String` muestra 8 líneas (4 `LAMBDA 'udf_similitud'` y 4 `IAM_ROLE 'arn:aws:iam::...'`). Este comando se probó en este equipo con valores de ejemplo (sin BOM, sin marcadores restantes).

Sintaxis válida para `IAM_ROLE`: un ARN entre comillas, o la palabra `default` si el rol está marcado como predeterminado del cluster ([AWS](https://docs.aws.amazon.com/redshift/latest/dg/r_CREATE_EXTERNAL_FUNCTION.html)). **[SUPUESTO SIN CONFIRMAR]:** que `CREATE EXTERNAL FUNCTION` **no** compruebe que la Lambda exista en el momento de crearla. La guía recomienda desplegar la Lambda real **antes** para no depender de ese supuesto.

#### 1.2.9 Variantes si no puedes usar la Lambda real

Solo para una prueba de humo y **bajo tu responsabilidad**: reemplaza `udf_similitud` por cualquier nombre y el rol por la palabra `default`. Si `CREATE EXTERNAL FUNCTION` falla, es que Redshift sí valida la Lambda: despliega la real. **No** comentes llamadas dentro de `08_sp_batch2_procesacubos.sql`: eso cambia código y esta guía no lo permite.

### 1.3 Cómo ejecutar un archivo `.sql` (las alternativas reales)

⚠ **Los archivos del repositorio y el `README.md` usan `\i archivo.sql`. Eso es un metacomando de `psql`** (una orden del programa cliente, no de la base de datos). **No funciona en Query Editor v2 ni en DBeaver.** Estas son las alternativas reales:

| Herramienta | ¿Entiende `\i`? | Cómo ejecutas un archivo | Úsala cuando |
|---|---|---|---|
| **`psql`, sesión interactiva** | Sí | Entras una vez con `psql -h ... -d ...` y escribes `\i ddl/01_schemas.sql`. La ruta es **relativa a la carpeta desde donde lanzaste `psql`** | Quieres ir paso a paso y ver cada respuesta |
| **`psql -f`** | No hace falta | `psql -h ... -d ... -v ON_ERROR_STOP=1 -f ddl\01_schemas.sql` (un archivo por llamada) | **Recomendada**: se puede automatizar y se detiene en el primer error |
| **RSQL** (cliente de línea de comandos de Amazon Redshift) | Sí (`\i`, y también `\run file=...`) ([AWS](https://docs.aws.amazon.com/redshift/latest/mgmt/rsql-query-tool-commands.html)) | `\i ddl/01_schemas.sql` dentro de RSQL | Ya tienes RSQL instalado |
| **Query Editor v2** (consola web): pegar | **No** | Abres el `.sql` en un editor de texto, **copias todo**, lo **pegas** en una pestaña, eliges el cluster y la base (arriba de la pestaña) y pulsas **Run** | No puedes instalar nada. Ojo: por omisión muestra solo 100 filas (casilla *Limit 100*) |
| **Query Editor v2**: importar el archivo | **No** (no hace falta) | Desde agosto de 2024 el editor permite **importar uno o varios archivos `.sql`** (o carpetas) desde tu computador ([AWS](https://aws.amazon.com/about-aws/whats-new/2024/08/amazon-redshift-query-editor-v2-query-import); la documentación de notebooks indica extensiones `.sql` y `.txt`). El archivo queda cargado en el editor y lo ejecutas con **Run** | Evita copiar y pegar. El nombre exacto del botón puede variar según la versión de la consola |
| **DBeaver** u otro cliente JDBC | **No** | Abres el archivo en el editor y lo ejecutas "como script" (en DBeaver, *Execute SQL Script*, `Alt+X`) | Ya lo usas. **[SUPUESTO SIN CONFIRMAR]** con estos archivos: los cuerpos de procedure van entre `$$ ... $$` y algunos clientes los parten mal |

**Recomendación:** ubícate siempre en `RS` y usa `psql -f` con `-v ON_ERROR_STOP=1`.

⚠ Consejos de `psql` moderno contra Redshift: los comandos de listado propios de `psql` (`\d`, `\dt`...) pueden fallar o salir incompletos con versiones nuevas de `psql` porque Redshift deriva de un PostgreSQL antiguo. Esta guía **no** los usa: lista objetos con consultas SQL normales. **[SUPUESTO SIN CONFIRMAR]** (no se probó con una versión concreta de `psql`).

### 1.4 Paso a paso del despliegue (en el orden verificado)

El orden sale de `README.md` y de las dependencias reales entre archivos (sección 1.4.9). Cada paso dice **qué hace**, **por qué va ahí**, el **comando exacto**, el **resultado esperado** y **qué hacer si falla**.

#### D0. Preparar la sesión de PowerShell y la conexión

**Qué hace:** te ubica en `RS`, define quién eres y a dónde te conectas, y crea una función que ejecuta un `.sql` y se detiene si hay error. **Por qué:** así cada paso siguiente es una sola línea, y la contraseña nunca queda escrita en ningún archivo.

```powershell
# PowerShell
Set-Location "d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift"   # esta carpeta es RS
$env:PGCLIENTENCODING = "UTF8"        # las tildes de datos\01_catalogos_motor.sql llegan bien
$H  = "<ENDPOINT_DEL_CLUSTER>"        # solo el nombre, sin :5439 ni /base
$U  = "<USUARIO>"
$DB = "dev"                           # una base que ya exista; en el paso D1 se cambia por recon_batch2

# La contrasena se pide sin mostrarla y vive solo en esta ventana
$seg = Read-Host "Contrasena de Redshift" -AsSecureString
$env:PGPASSWORD = [System.Net.NetworkCredential]::new("", $seg).Password

function Invoke-Sql([string]$Archivo) {
    Write-Host ">>> $Archivo" -ForegroundColor Cyan
    psql -h $H -p 5439 -U $U -d $DB -v ON_ERROR_STOP=1 -f $Archivo
    if ($LASTEXITCODE -ne 0) { throw "FALLO en $Archivo (codigo $LASTEXITCODE)" }
}
```

Qué significa cada parte de `psql`: `-h` es el servidor (endpoint), `-p 5439` el puerto de Redshift, `-U` el usuario, `-d` la base, `-f` el archivo a ejecutar, y `-v ON_ERROR_STOP=1` hace que `psql` **pare en el primer error** y devuelva un código distinto de cero (que la función revisa con `$LASTEXITCODE`). `$env:PGPASSWORD` es la variable donde `psql` busca la contraseña; si no existe, `psql` la pide por pantalla. Al terminar la prueba, bórrala con `Remove-Item Env:PGPASSWORD`.

Probar la conexión:

```powershell
# PowerShell
psql -h $H -p 5439 -U $U -d $DB -c "SELECT current_database(), current_user, version();"
```

✔ Resultado esperado: una fila con tu base, tu usuario y un texto de versión que menciona `Redshift`.

| Síntoma | Causa probable | Solución |
|---|---|---|
| Se queda esperando y luego `timeout expired` | El puerto 5439 no es alcanzable (grupo de seguridad, VPN, cluster no público) | `Test-NetConnection $H -Port 5439`; pide abrir el puerto 5439 para tu IP o conéctate por VPN |
| `password authentication failed` | Usuario o contraseña mal escritos | Repite el bloque de la contraseña |
| `database "..." does not exist` | Nombre de base incorrecto | Usa una base que exista (`dev` suele existir) |
| Error de SSL / `no encryption` | El cluster exige conexión cifrada | `$env:PGSSLMODE = "require"` y repite |
| `psql` no se reconoce como comando | `psql` no está instalado o no está en el `PATH` | Instala el cliente de PostgreSQL, o usa RSQL o Query Editor v2 (sección 1.3) |

#### D1. Crear la base de datos con collation case-insensitive y reconectarse

**Qué hace:** crea una base nueva `recon_batch2` cuyas comparaciones de texto ignoran mayúsculas y minúsculas. **Por qué:** Teradata comparaba así (`NOT CASESPECIFIC`) y el código migrado depende de ello: por ejemplo `sp_batch2_filtro_j` compara `'Correo'` con un valor que él mismo guardó como `'correo'`; sin esta collation **nunca borra duplicados** (cabecera de `procedures\08_sp_batch2_procesacubos.sql`). La collation se fija **al crear la base**. No se cambia después: habría que recrearla.

```powershell
# PowerShell (conectado a la base $DB existente, p. ej. dev)
psql -h $H -p 5439 -U $U -d $DB -c "CREATE DATABASE recon_batch2 COLLATE CASE_INSENSITIVE;"
$DB = "recon_batch2"      # <- desde aqui TODO se hace en la base nueva
psql -h $H -p 5439 -U $U -d $DB -c "SELECT current_database(), db_collation();"
```

La sintaxis `COLLATE { CASE_SENSITIVE | CS | CASE_INSENSITIVE | CI }` es la vigente en la [documentación de AWS de CREATE DATABASE](https://docs.aws.amazon.com/redshift/latest/dg/r_CREATE_DATABASE.html) (por omisión es *case sensitive*). `CREATE DATABASE` **no puede ejecutarse dentro de un bloque de transacción** y exige ser superusuario o tener el privilegio `CREATEDB`.

✔ Resultado esperado: `CREATE DATABASE` y luego `recon_batch2 | case_insensitive` ([`DB_COLLATION`](https://docs.aws.amazon.com/redshift/latest/dg/r_DB_COLLATION.html) devuelve `case_sensitive` o `case_insensitive`).

**¿Cómo "me paso" a la base nueva?** En Redshift **no existe `USE`**: una conexión trabaja con **una sola base**. Para cambiar hay que **abrir una conexión nueva** a la otra base:

| Herramienta | Cómo se reconecta |
|---|---|
| Scripts de esta guía (`psql -d`) | Cambias `$DB` y ya: cada comando abre su conexión |
| `psql` interactivo | `\c recon_batch2` (equivale a `\connect`) |
| RSQL | `\connect recon_batch2;` (así lo muestra la documentación de AWS) |
| Query Editor v2 | Elige la base `recon_batch2` en el árbol o en la lista desplegable de la pestaña (si no aparece, refresca el árbol) |
| DBeaver | Crea una conexión nueva con `recon_batch2` como base |

⚠ **Mayúsculas en el catálogo:** AWS documenta que las tablas y vistas del sistema (`pg_*`, `svv_*`, `stv_*`) **siguen distinguiendo mayúsculas** aunque la base sea case-insensitive. Escribe siempre en minúsculas los nombres de esquema y tabla cuando los compares con el catálogo (como hace esta guía).

| Síntoma | Causa probable | Solución |
|---|---|---|
| `database "recon_batch2" already exists` | Ya la creaste | Reutilízala (verifica la collation con `db_collation()`) o elige otro nombre |
| `permission denied to create database` | Tu usuario no tiene `CREATEDB` | Usa el superusuario o `ALTER USER <USUARIO> CREATEDB;` |
| `CREATE DATABASE cannot run inside a transaction block` | Tu cliente tiene auto-commit apagado | Activa auto-commit o ejecuta con `psql -c` |
| `db_collation()` devuelve `case_sensitive` | La base ya existía sin la opción | Crea otra base. Si **no** puedes: la prueba corre, pero `FILTRO_J` y las comparaciones de texto no se comportarán como en Teradata. No sirve para validar la migración |

#### D2. Esquemas y tablas base (`ddl\01` a `ddl\07`)

**Qué hace:** crea las 4 carpetas y todas las tablas vacías. **Por qué primero:** todo lo demás cuelga de los esquemas; los archivos `02` a `07` no dependen entre sí, solo del `01`.

```powershell
# PowerShell, en RS, con $DB = "recon_batch2"
Invoke-Sql "ddl\01_schemas.sql"
Invoke-Sql "ddl\02_tablas_configuracion.sql"
Invoke-Sql "ddl\03_tablas_cubos.sql"
Invoke-Sql "ddl\04_tablas_pivote.sql"        # si el equipo de desarrollo ya agrego el bloque _003 de direccion, usa esa version
Invoke-Sql "ddl\05_tablas_control.sql"
Invoke-Sql "ddl\06_vistas_dimension.sql"
Invoke-Sql "ddl\07_tablas_dependencias_sps.sql"
```

✔ Resultado esperado: por cada archivo, líneas `CREATE SCHEMA` / `CREATE TABLE` / `INSERT 0 1`. Los scripts usan `CREATE ... IF NOT EXISTS`: si el objeto ya existía, Redshift lo **omite** (puede mostrar un aviso, no un error). `05` inserta la fila semilla `lote = 0` en `rec_mtdat.lote_id`, `06` inserta 2 filas en `rec_vista.tipo_persona` y `07` inserta 100 filas en `rec_stage.secuencia`.

| Síntoma | Causa probable | Solución |
|---|---|---|
| `permission denied for database` al crear esquemas | Falta `CREATE` sobre la base | `GRANT CREATE ON DATABASE recon_batch2 TO <USUARIO>;` (lo hace un superusuario) |
| `schema "rec_stage" does not exist` en el `02` | No se ejecutó el `01` | Ejecuta `ddl\01_schemas.sql` |
| `schema "rec_stage" already exists` | Con los scripts del repo **no debería verse**: `CREATE SCHEMA IF NOT EXISTS` omite el esquema que ya existe. Solo aparece si alguien ejecutó un `CREATE SCHEMA` sin `IF NOT EXISTS` | No es grave: el esquema ya está. Sigue con el siguiente archivo |
| `relation "..." already exists` | El objeto existía **con otra definición** | Compara con el DDL; para recrear una tabla de trabajo, ver 1.6 |
| `must be owner of relation` | La tabla es de otro usuario | Usa el usuario dueño o el superusuario |

#### D3. Funciones (`ddl\08`, con los marcadores ya reemplazados)

**Qué hace:** crea las 8 funciones del esquema `rec_vista`. **Por qué aquí:** necesita que exista `rec_vista` (paso D2) y que la Lambda de la sección 1.2 esté desplegada. **Usa la copia generada en 1.2.8, nunca el original.**

```powershell
# PowerShell, en RS
Invoke-Sql "C:\prueba_esencial\08_funciones_udf_desplegar.sql"
```

✔ Resultado esperado: 8 respuestas `CREATE FUNCTION`.

| Síntoma | Causa probable | Solución |
|---|---|---|
| `syntax error at or near "<"` | Usaste el original con los marcadores `<...>` | Repite 1.2.8 y usa la copia |
| `permission denied for language exfunc` | Tu usuario no puede crear funciones externas | Usa un superusuario o `GRANT USAGE ON LANGUAGE exfunc TO <USUARIO>;` |
| Error de rol IAM o de Lambda al crear | El ARN está mal, el rol no está asociado al cluster, o Redshift sí valida que la Lambda exista | Revisa `IamRoles` del cluster y que la Lambda exista en la misma región (1.2.7). **[SUPUESTO SIN CONFIRMAR]** cuál de las tres causas es |

#### D4. Vista y tablas de trabajo (`ddl\09` y `ddl\10`)

**Qué hace:** crea la vista `rec_stage.vstgbatchcargaubicestandarizada` (vista "late-binding": se crea aunque las tablas del proceso P0034 que lee no existan todavía) y las tablas `w_borrar_002` y `w_ejecutor`. **Por qué:** el README los pone después de las funciones. No tienen dependencias de creación.

```powershell
# PowerShell, en RS
Invoke-Sql "ddl\09_vistas_dependencias_sps.sql"
Invoke-Sql "ddl\10_tablas_trabajo_f2_4.sql"
```

✔ Resultado esperado: `CREATE VIEW` y 2 `CREATE TABLE`. El bloque final de `09` (7 tablas vacías de P0034) está entre `/* ... */`: **no se ejecuta** y no hace falta para esta prueba (solo se usa si la plantilla tiene una subsección cuyo nombre contenga "Validacion").

#### D5. Procedures, en orden de dependencia (`procedures\01` a `procedures\10`)

**Qué hace:** crea los 34 procedures. **Por qué este orden:** `02` primero (casi todos llaman a `sp_execstring_des`); **`09b` antes de `09`** (`sp_batch2_estadisticas` llama a `sp_batch2_estadisticas_cfg`, aunque el orden alfabético del explorador de archivos sugiera lo contrario); `10` al final (llama a todos). Los demás no dependen entre sí.

```powershell
# PowerShell, en RS
Invoke-Sql "procedures\01_sp_batch2_genera_lote.sql"
Invoke-Sql "procedures\02_sp_batch2_log_helpers.sql"
Invoke-Sql "procedures\03_sp_batch2_cubo_export.sql"      # version con rn <= 3 de direccion si desarrollo ya la hizo
Invoke-Sql "procedures\04_sp_batch2_exportplano.sql"      # version con layout 3/3/2/2 si desarrollo ya la hizo
Invoke-Sql "procedures\05_sp_batch2_exportlog.sql"
Invoke-Sql "procedures\06_sp_batch2_actualiza_historia.sql"
Invoke-Sql "procedures\07_sp_batch2_valida_archivos.sql"
Invoke-Sql "procedures\08_sp_batch2_procesacubos.sql"     # el mas grande (unos 168 KB)
Invoke-Sql "procedures\09b_sp_batch2_motores_sql.sql"
Invoke-Sql "procedures\09_sp_batch2_otros.sql"            # despues de 09b
Invoke-Sql "procedures\10_sp_batch2_proceso_batch2.sql"
```

✔ Resultado esperado: respuestas `CREATE PROCEDURE` (o `CREATE`) por cada procedure; ninguna línea que empiece con `ERROR`.

| Síntoma | Causa probable | Solución |
|---|---|---|
| `syntax error at or near ...` con número de línea | Error de sintaxis en el archivo | **No lo corrijas tú.** Anota archivo y línea y repórtalo como hallazgo nuevo (sección 4.C). `psql` se detiene ahí por `ON_ERROR_STOP` |
| `permission denied for language plpgsql` | Falta `USAGE` sobre el lenguaje | `GRANT USAGE ON LANGUAGE plpgsql TO <USUARIO>;` |
| `schema "rec_stage" does not exist` | Falta el paso D2 | Ejecútalo |
| `relation ... does not exist` al **crear** un procedure | **[SUPUESTO SIN CONFIRMAR]** que Redshift no revisa los objetos al crear el procedure; si lo hiciera, falta un DDL previo | Repite D2 a D4 y vuelve a este paso |

#### D6. Catálogos (`datos\01_catalogos_motor.sql`)

**Qué hace:** carga las filas fijas que dos "motores" necesitan. **Por qué al final:** depende de las tablas de `ddl\05` y `ddl\07`. Es **idempotente**: borra las filas que le pertenecen y las vuelve a insertar (`DELETE FROM rec_stage.batch_archivo_log;`, `DELETE ... WHERE tipo = 'LOG'`, `DELETE ... WHERE parte = 'ITERADOR'`). Tiene tildes: por eso `PGCLIENTENCODING=UTF8` en D0.

```powershell
# PowerShell, en RS
Invoke-Sql "datos\01_catalogos_motor.sql"
```

✔ Resultado esperado: `DELETE n`, `INSERT 0 18`, `INSERT 0 12`... y ningún `ERROR`.

⚠ **Efecto que debes conocer:** con las 12 filas `ITERADOR` cargadas, el paso 2 del orquestador (`sp_batch2_plan_ejecucion_shell`) deja de ser "no hace nada" y **ejecuta SQL de verdad** (crea vistas y tablas de trabajo). Nunca corrió en Redshift **[SUPUESTO SIN CONFIRMAR]**. El Camino A de la sección 3 no llama a ese paso.

#### 1.4.9 Por qué este orden (resumen de dependencias, verificado leyendo los archivos)

1. `ddl\01` antes de todo: crea los esquemas.
2. `ddl\02` a `ddl\07`: solo `CREATE TABLE IF NOT EXISTS`; entre sí independientes.
3. `ddl\08`: necesita el esquema `rec_vista` y los dos marcadores ya reemplazados.
4. `ddl\09` (late-binding: se crea aunque no existan las tablas de P0034) y `ddl\10` (sin dependencias).
5. `procedures\02` antes de cualquier procedure que llame a `sp_execstring_des` (todos los de `05`, `08`, `09`, `09b`). `09b` antes de `09`. `10` al final.
6. `datos\01` al final: depende de `ddl\05` y `ddl\07`.
7. Después: objetos puente y datos de prueba (secciones 2.4 y 2.6).

**Todo junto**, para volver a desplegar de golpe (después de D0 y D1):

```powershell
# PowerShell, en RS, con $DB = "recon_batch2"
$orden = @(
 "ddl\01_schemas.sql","ddl\02_tablas_configuracion.sql","ddl\03_tablas_cubos.sql","ddl\04_tablas_pivote.sql",
 "ddl\05_tablas_control.sql","ddl\06_vistas_dimension.sql","ddl\07_tablas_dependencias_sps.sql",
 "C:\prueba_esencial\08_funciones_udf_desplegar.sql",
 "ddl\09_vistas_dependencias_sps.sql","ddl\10_tablas_trabajo_f2_4.sql",
 "procedures\01_sp_batch2_genera_lote.sql","procedures\02_sp_batch2_log_helpers.sql",
 "procedures\03_sp_batch2_cubo_export.sql","procedures\04_sp_batch2_exportplano.sql",
 "procedures\05_sp_batch2_exportlog.sql","procedures\06_sp_batch2_actualiza_historia.sql",
 "procedures\07_sp_batch2_valida_archivos.sql","procedures\08_sp_batch2_procesacubos.sql",
 "procedures\09b_sp_batch2_motores_sql.sql","procedures\09_sp_batch2_otros.sql",
 "procedures\10_sp_batch2_proceso_batch2.sql","datos\01_catalogos_motor.sql")
foreach ($a in $orden) { Invoke-Sql $a }
```

#### Si usas Query Editor v2 en vez de `psql`

Repite el mismo orden, pero por cada archivo: ábrelo en el Bloc de notas, **copia todo**, pégalo en una pestaña de Query Editor v2 (con la base `recon_batch2` elegida) y pulsa **Run**. En vez de copiar y pegar puedes **importar** el archivo `.sql` con la opción de importar del editor (ver 1.3). Mira el panel de resultados antes de seguir con el siguiente archivo. Para `08`, pega el contenido de la copia generada en 1.2.8, no el original.

### 1.5 Cómo verificar el despliegue

Ejecuta estas consultas en tu cliente SQL, conectado a `recon_batch2`. Todas son consultas SQL normales (no metacomandos).

**V1. Esquemas** (esperado: 4 filas)

```sql
-- Se ejecuta en recon_batch2
SELECT nspname AS esquema
FROM pg_catalog.pg_namespace
WHERE nspname IN ('rec_stage','rec_mtdat','rec_datos','rec_vista')
ORDER BY 1;
```

**V2. Cuántas tablas hay por esquema** (esperado: `rec_datos` 3, `rec_mtdat` 3, `rec_stage` 34, `rec_vista` 3; en total 43)

```sql
SELECT schemaname AS esquema, COUNT(*) AS tablas
FROM pg_tables
WHERE schemaname IN ('rec_stage','rec_mtdat','rec_datos','rec_vista')
GROUP BY 1
ORDER BY 1;
```

⚠ Estos conteos valen **antes** de ejecutar el pipeline: al correr, el pipeline crea tablas de trabajo (`bacth_fg_1`, `pro_batch2_filtro_e`...) y los números suben.

**V3. Lista de tablas y vistas** (esperado: 44 filas = 43 tablas + la vista `vstgbatchcargaubicestandarizada`)

```sql
SELECT table_schema, table_name, table_type
FROM svv_tables
WHERE table_schema IN ('rec_stage','rec_mtdat','rec_datos','rec_vista')
ORDER BY 1, 2;
```

([`SVV_TABLES`](https://docs.aws.amazon.com/redshift/latest/dg/r_SVV_TABLES.html) muestra tablas y vistas; la columna `table_type` te dice cuál es cuál.)

**V4. Procedures** (esperado: 34 filas: 7 en `rec_mtdat` y 27 en `rec_stage`)

```sql
SELECT n.nspname AS esquema, p.proname AS procedimiento
FROM pg_catalog.pg_proc_info p
JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
WHERE p.prokind = 'p'
  AND n.nspname IN ('rec_stage','rec_mtdat')
ORDER BY 1, 2;
```

`PG_PROC_INFO` es la vista de Redshift sobre `pg_proc` que incluye `prokind` (`'p'` procedimiento, `'f'` función, `'a'` agregada) ([AWS](https://docs.aws.amazon.com/redshift/latest/dg/r_PG_PROC_INFO.html)). Para quedarte solo con los `sp_batch2_*` (esperado: 31) agrega `AND p.proname LIKE 'sp\_batch2\_%'`. Los otros 3 son auxiliares: `sp_execstring_des`, `sp_drop_si_existe`, `sp_drop_tabla_por_nombre`. ⚠ La consulta de la guía anterior (`pg_proc` con columnas `schemaname, procedurename`) **no era válida**: esas columnas no existen.

**V5. Funciones** (esperado: 8 en `rec_vista`: `f_td_to_number`, `f_bach_similitud_dir_mz`, `f_porc_similitud`, `f_bach_similitud_tel`, `f_bach_similitud_email`, `f_datamasking`, `f_dirdatamasking`, `f_razondatamasking`)

```sql
SELECT n.nspname AS esquema, p.proname AS funcion
FROM pg_catalog.pg_proc_info p
JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
WHERE p.prokind = 'f'
  AND n.nspname = 'rec_vista'
ORDER BY 2;
```

**[SUPUESTO SIN CONFIRMAR]:** que las funciones externas (Lambda) aparezcan en `pg_proc_info` igual que las SQL. Alternativa documentada: `SELECT schema_name, function_name, argument_type FROM svv_redshift_functions WHERE schema_name = 'rec_vista' ORDER BY 2;` ([AWS](https://docs.aws.amazon.com/redshift/latest/dg/r_SVV_REDSHIFT_FUNCTIONS.html)).

**V6. Filas de los catálogos y semillas**

```sql
SELECT 'batch_archivo_log'         AS que, COUNT(*) AS filas FROM rec_stage.batch_archivo_log                          -- esperado 18
UNION ALL SELECT 'batch_motor_log (LOG)',        COUNT(*) FROM rec_stage.batch_motor_log WHERE tipo = 'LOG'            -- esperado 18
UNION ALL SELECT 'pro_plan_ejecucion (ITERADOR)', COUNT(*) FROM rec_stage.pro_plan_ejecucion WHERE parte = 'ITERADOR' -- esperado 12
UNION ALL SELECT 'secuencia',                    COUNT(*) FROM rec_stage.secuencia                                     -- esperado 100
UNION ALL SELECT 'tipo_persona',                 COUNT(*) FROM rec_vista.tipo_persona                                  -- esperado 2
UNION ALL SELECT 'lote_id',                      COUNT(*) FROM rec_mtdat.lote_id;                                      -- esperado 1 (lote = 0)
```

También debe cumplirse que no existan filas `FILTRO-C` ni `CANT_REP_CANAL_CONTACTO` en `batch_motor_log` (`SELECT tipo, COUNT(*) FROM rec_stage.batch_motor_log GROUP BY 1;` devuelve solo `LOG | 18`). Esas filas **no llegaron** con el insumo; es un pendiente conocido, no un fallo de tu despliegue.

**V7. Collation** (esperado: `case_insensitive` y `true`)

```sql
SELECT db_collation() AS collation, ('a' = 'A') AS ignora_mayusculas;
```

`('a' = 'A')` en `true` es la prueba de comportamiento; **[SUPUESTO SIN CONFIRMAR]** que devuelva `true` (no lo ejecuté).

**V8. Funciones SQL (no necesitan Lambda)** (resultados tomados de `casos_validacion_redshift.sql`)

```sql
SELECT rec_vista.f_td_to_number('12.5')                         AS a,   -- 12.5000000000
       rec_vista.f_td_to_number('abc')                          AS b,   -- NULL
       rec_vista.f_datamasking('3001234567')                    AS dm,  -- 300123XXXX
       rec_vista.f_dirdatamasking('CL 10 # 5-20')               AS dir, -- CL XX # X-XX
       rec_vista.f_razondatamasking('  INVERSIONES  ABC   LTDA ') AS razon; -- INVERSIXXXX ABC XXXX
```

**V9. Funciones Lambda (necesitan la Lambda desplegada)**

```sql
SELECT rec_vista.f_bach_similitud_tel('2826373','2826373') AS tel_iguales;   -- esperado 100
```

Luego corre todos los casos de validación; **toda fila** debe tener `ok = 'S'`:

```powershell
# PowerShell, en RS
psql -h $H -p 5439 -U $U -d $DB -f "lambda\udf_similitud\casos_validacion_redshift.sql"
```

| Síntoma | Causa probable | Solución |
|---|---|---|
| `V9` falla con un error de Lambda o de permisos | La Lambda no existe, está en otra región, o el rol no tiene `lambda:InvokeFunction` | Revisa 1.2.3 y 1.2.7; prueba la Lambda con `aws lambda invoke` |
| Algún caso da `ok = 'N'` en los de distancia | La distancia de edición se implementó como Damerau-Levenshtein OSA, un **[SUPUESTO SIN CONFIRMAR]** | Corre `casos_validacion_teradata.sql` en Teradata: el valor de Teradata manda |

### 1.6 Re-ejecutar y limpiar

**Idempotencia por archivo** (verificado leyendo cada archivo): puedes volver a ejecutar cualquier script sin romper nada, con estos matices.

| Archivo | Mecanismo | ¿Se puede repetir? | Matiz |
|---|---|---|---|
| `ddl\01` | `CREATE SCHEMA IF NOT EXISTS` | Sí | |
| `ddl\02`, `03`, `04`, `07`, `10` | `CREATE TABLE IF NOT EXISTS` | Sí | **No modifica una tabla que ya existe.** Para añadir el bloque `_003` a `w_cubo_direccion` hay que borrar la tabla primero (ver abajo) |
| `ddl\05` | `CREATE TABLE IF NOT EXISTS` + semilla con `WHERE NOT EXISTS` | Sí | |
| `ddl\06` | `CREATE TABLE IF NOT EXISTS` + 2 filas de `tipo_persona` con `WHERE NOT EXISTS` | Sí | `rec_vista.persona` **no** se llena |
| `ddl\08` | `CREATE OR REPLACE` | Sí | Reemplazar una función externa pide superusuario |
| `ddl\09` | `CREATE OR REPLACE VIEW` | Sí | |
| `procedures\*.sql` | `CREATE OR REPLACE PROCEDURE` | Sí | Si cambia la lista de parámetros, Redshift crea una sobrecarga en vez de reemplazar **[SUPUESTO SIN CONFIRMAR]** |
| `datos\01` | `DELETE` + `INSERT` | Sí | Borra todo `batch_archivo_log` y lo recarga |

**Recrear una sola tabla** (ejemplo: `w_cubo_direccion`, que es una tabla de trabajo que el pipeline vacía y llena en cada corrida, así que borrarla es seguro):

```sql
-- Se ejecuta en recon_batch2
DROP TABLE rec_stage.w_cubo_direccion;
```

y luego `Invoke-Sql "ddl\04_tablas_pivote.sql"` (recrea solo la que falta; las otras se omiten).

⚠ **El pipeline NO se puede repetir sobre los mismos datos.** Modifica los cubos en sitio: `HOMOLOGACIONES` reescribe `numero_id`, `FILTRO_H` y `FILTRO_J` **borran filas**, `ADICIONAR_INCON` mueve y borra identificaciones, y `actualiza_historia` solo cierra la solicitud si `estado IS NULL`. Para repetir la prueba, sigue el paso 6 de la sección 3 (limpiar y recargar).

⚠ **Reinicio total** (borra TODO el trabajo; úsalo solo en tu base de pruebas). Se hace desde **otra** base, porque no puedes borrar la base a la que estás conectado:

```powershell
# PowerShell. Conectado a la base "dev" (NO a recon_batch2)
psql -h $H -p 5439 -U $U -d dev -c "DROP DATABASE recon_batch2;"
```

Es **irreversible**: se pierden tablas, procedures, funciones y datos. Después vuelves a D1.

---

## 2. Tablas que deben existir en Redshift para esta prueba y dónde están sus DDL

No hace falta que existan **todas** las tablas del sistema final, pero sí las de esta sección. Todas las que están en la lista (i) y (ii) las crea el despliegue de la sección 1: **no tienes que escribir ningún `CREATE TABLE`**. Lo único que no crea la migración está en (iii).

### 2.1 Cómo leer las tablas

- **Cargar datos antes:** *Cargar* = hay que meterle filas antes de ejecutar (secciones 2.4 y 2.6). *Vacía* = basta con que exista; el proceso la llena o no la necesita. *Semilla* = ya viene con filas desde el despliegue.
- **DDL:** el archivo y la línea aproximada (±3) donde está su `CREATE`. Las rutas son relativas a `RS` (`d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift`).
- **DDL original en Teradata:** donde existe, `DDL.sql` está en `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\DDL.sql`. Para la mayoría de tablas **el DDL de Teradata no está en el workspace**: la estructura se infirió del uso en `Sps_Batch.sql` y los `.BTQ` (lo dice el encabezado de cada `ddl\*.sql`).
- Total tras ejecutar `ddl\01` a `ddl\10`: **43 tablas** (`rec_datos` 3, `rec_mtdat` 3, `rec_stage` 34, `rec_vista` 3), **1 vista** y **8 funciones**.

### 2.2 (i) MÍNIMO INDISPENSABLE para generar los 3 CSV (29 tablas)

**Configuración de la solicitud**

| Esquema.tabla | Para qué sirve (lenguaje simple) | ¿Datos antes? | DDL (archivo, línea) | DDL original en Teradata |
|---|---|---|---|---|
| `rec_stage.batch_solicitud_batch` | El "pedido": una fila por solicitud | **Cargar** 1 fila | `ddl\02_tablas_configuracion.sql`, ~143 | `DDL.sql`, línea 101 (`REC_STAGE.BATCH_SOLICITUD_BATCH`) |
| `rec_stage.batch_datos_generales` | Cómo se entrega el archivo (orientación, formato...) | **Cargar** exactamente 1 fila por (solicitud, plantilla) | `ddl\02`, ~26 | `DDL.sql`, línea 1 |
| `rec_stage.batch_salidas_campos` | Qué columnas lleva el archivo y **cuántas veces** se repite cada una (aquí va el 3/3/2/2) | **Cargar** (5 filas en la prueba) | `ddl\02`, ~115 | `DDL.sql`, línea 76 |
| `rec_stage.batch_direccion_filtros` | Partículas de dirección a descartar (la lee `FILTRO_A`) | Vacía | `ddl\02`, ~55 | `DDL.sql`, línea 26 |
| `rec_stage.batch_homologaciones` | Cambios de valor "X se vuelve Y" por solicitud | Vacía | `ddl\02`, ~72 | `DDL.sql`, línea 40 |
| `rec_stage.batch_porcentajes_filtros` | Porcentajes mínimos de similitud (los usan `FILTRO_E` y `FILTRO_F`) | Vacía (sin filas esos filtros no hacen nada) | `ddl\02`, ~90 | `DDL.sql`, línea 54 |
| `rec_stage.batch2_homologacion` | Diccionario que une cada `codigo_campo` con su cubo y su columna física. **Sin filas no hay recorte 3/3/2/2** | **Cargar** 5 filas (sección 2.6; no existe script de carga en el workspace) | `ddl\05_tablas_control.sql`, ~101 | No está en el workspace; columnas `id_sequencia` y `homologado` confirmadas en `Sps_Batch.sql` |
| `rec_stage.batch_motor_log` | SQL guardado como datos (motor del log) | Semilla (18 filas `LOG` con `datos\01`); puede quedar vacía para los CSV | `ddl\07_tablas_dependencias_sps.sql`, ~30 | `Dlls-Batch\Dll_Btach.csv` |
| `rec_stage.pro_plan_ejecucion` | SQL guardado como datos (motor del plan) | Semilla (12 filas `ITERADOR`); vacía = el paso 2 no hace nada | `ddl\07`, ~52 | `Dlls-Batch\Dll_Btach2.csv` |
| `rec_stage.stg_insumo_batch_validacion` | Insumo del suscriptor para las similitudes (lo lee `FILTRO_F`) | Vacía | `ddl\07`, ~95 | No está en el workspace (columnas inferidas de `FILTRO_F` y `ADD_PORC_INSUMO`) |

**Cubos (datos de contacto de entrada)** (todas con `DISTKEY (id_buro_persona)`: las filas de una misma persona viven juntas)

| Esquema.tabla | Para qué sirve | ¿Datos antes? | DDL | DDL original en Teradata |
|---|---|---|---|---|
| `rec_stage.batch_cubo_persona` | Una fila por persona: identificación, nombre, expedición | **Cargar** (6 personas). `id_solicitud` e `id_plantilla` son obligatorios en la práctica: `cubo_export` y `exportplano` filtran por ellos | `ddl\03_tablas_cubos.sql`, ~30 | No está en el workspace (inferido de `FILTRO_D/E/F/G/H` y `HOMOLOGACIONES`) |
| `rec_stage.batch_cubo_direccion` | Las direcciones de cada persona | **Cargar** | `ddl\03`, ~60 | No está (inferido de `PRO_BATCH_ADD_PORC_INSUMO`, tablas `TMP_BATCH_PORPOS_*`) |
| `rec_stage.batch_cubo_telefono` | Los teléfonos fijos | **Cargar** | `ddl\03`, ~104 | ídem |
| `rec_stage.batch_cubo_celular` | Los celulares | **Cargar** | `ddl\03`, ~144 | ídem |
| `rec_stage.batch_cubo_correo` | Los correos | **Cargar** | `ddl\03`, ~184 | ídem |
| `rec_stage.batch_cubo_ciiu` | Actividad económica | **Cargar** (opcional con datos: el export hace `LEFT JOIN`, pero la tabla debe existir) | `ddl\03`, ~219 | No está |
| `rec_stage.batch_cubo_punto_interes_dir` | Puntos de interés cercanos (los toca `FILTRO_G`) | Vacía, pero debe existir | `ddl\03`, ~241 | No está (estructura mínima inferida de `FILTRO_G`) |

**Pivote (las llena `sp_batch2_cubo_export`)**

| Esquema.tabla | Para qué sirve | ¿Datos antes? | DDL | DDL original en Teradata |
|---|---|---|---|---|
| `rec_stage.w_cubo_telefono` | Teléfonos girados a columnas. Admite **5** grupos `_001.._005` | Vacía | `ddl\04_tablas_pivote.sql`, ~26 | La generaba dinámicamente `P0033_BATCH2_CUBOEXPORT_120.BTQ` / `_130.TPT` |
| `rec_stage.w_cubo_celular` | Celulares girados. Admite **2** grupos | Vacía | `ddl\04`, ~41 | ídem |
| `rec_stage.w_cubo_direccion` | Direcciones giradas. Admite **solo 2** grupos (falta `_003`) | Vacía | `ddl\04`, ~53 | ídem |
| `rec_stage.w_cubo_correo` | Correos girados. Admite **2** grupos | Vacía | `ddl\04`, ~65 | ídem |
| `rec_stage.w_cubo_ciiu` | CIIU girado. **1** grupo | Vacía | `ddl\04`, ~77 | ídem |

**Control, bitácora y resultados**

| Esquema.tabla | Para qué sirve | ¿Datos antes? | DDL | DDL original en Teradata |
|---|---|---|---|---|
| `rec_mtdat.lote_id` | Contador de lotes (una sola fila) | Semilla (`lote = 0`) | `ddl\05_tablas_control.sql`, ~14 | `funGenerateLote` en `P0033_PROCESO_BATCH2.BTQ` (sin DDL) |
| `rec_mtdat.log_td` | Bitácora general (una fila por paso del orquestador) | Vacía | `ddl\05`, ~30 | Inferida del uso en los `.BTQ` |
| `rec_mtdat.log_td_detalle` | Bitácora detallada: una fila por sentencia ejecutada, con su resultado | Vacía | `ddl\05`, ~46 | ídem |
| `rec_stage.batch_identificaciones_validas` | Identificaciones que el insumo trajo como válidas | **Cargar** (7 filas, una es la inconsistente) | `ddl\05`, ~166 | Inferida; la carga el proceso hermano P0037 |
| `rec_stage.batch_identificaciones_incons` | Identificaciones inconsistentes; **alimenta el CSV `INCONSISTENCIA`** | Vacía (la llena `ADICIONAR_INCON`) | `ddl\05`, ~177 | ídem |

**Dimensión de persona (natural o jurídica)**

| Esquema.tabla | Para qué sirve | ¿Datos antes? | DDL | DDL original en Teradata |
|---|---|---|---|---|
| `rec_vista.tipo_persona` | Los dos tipos: 1 `NATURALES`, 2 `JURIDICAS` | Semilla (2 filas) | `ddl\06_vistas_dimension.sql`, ~17 | `BTTPRUVI.v_tipo_persona` (sin DDL en el workspace) |
| `rec_vista.persona` | Une cada tipo de identificación con natural/jurídica. **`exportplano` hace `INNER JOIN` con ella** | **Cargar 4 filas** (1 por tipo: 1, 4, 2, 3). Si queda vacía, los CSV salen **sin filas de datos**; si hay más de una fila por tipo, se **duplican** filas | `ddl\06`, ~31 | `BTTPRUVI.vu_persona` (sin DDL) |

**Funciones obligatorias** (`ddl\08_funciones_udf.sql`): `rec_vista.f_td_to_number` (la usan `FILTRO_B/E/F/G`, `HOMOLOGACIONES` y `ADICIONAR_INCON`), las **4** de similitud (deben **existir** por `FILTRO_F`) y, si `prueba` no es `'SV'`, las **3** de enmascaramiento. **Vista obligatoria no construida:** `rec_vista.vu_persona` y `rec_vista.v_tipo_persona` (sección 2.4).

### 2.3 (ii) Opcionales que NO bloquean los 3 CSV (14 tablas)

Existen tras el despliegue, pero para generar los CSV pueden quedar vacías.

| Esquema.tabla | Para qué sirve | ¿Datos antes? | DDL | Quién la usa |
|---|---|---|---|---|
| `rec_stage.batch_archivo_log` | Pares dato/valor del archivo de log | Semilla (18 filas) | `ddl\05`, ~206 | `exportlog` (paso 12) |
| `rec_stage.batch2_cantidad_reporte_canal` | Conteo de reportes por canal | Vacía | `ddl\05`, ~219 | Ningún procedure actual la referencia (hallazgo H8) |
| `rec_stage.batch2_shells_config` | Catálogo de pasos (shells) | Vacía | `ddl\07`, ~74 | Las filas `ITERADOR` |
| `rec_stage.batch2_shells_planejecucion` | Plan de ejecución | Vacía; el motor la borra y recrea | `ddl\05`, ~68 | `sp_batch2_plan_ejecucion_shell` |
| `rec_stage.batch_valform_st2`, `batch_valform_st4` | Bases de entrada y validada del proceso P0037 | Vacías | `ddl\07`, ~181 y ~188 | `sp_batch2_estadisticas` |
| `rec_stage.secuencia` | Números 1..100 | Semilla (100 filas) | `ddl\07`, ~157 | `completitud_canal` |
| `rec_stage.vstg_buropers_tmp` | Resolver el id del suscriptor | Vacía | `ddl\06`, ~45 | pasos 12 y 13 |
| `rec_stage.w_borrar_002`, `rec_stage.w_ejecutor` | Tablas de trabajo | Vacías; `completitud_canal` las borra y recrea | `ddl\10_tablas_trabajo_f2_4.sql`, ~26 y ~39 | `completitud_canal` |
| `rec_datos.batch_historia_resultados` | Quién ya recibió datos (regla de reincidentes) | Vacía | `ddl\05`, ~121 | `actualiza_historia` (solo si `no_entregado_x_meses > 0`) |
| `rec_datos.batch_estadisticas_pro` | Estadísticas por solicitud | Vacía | `ddl\05`, ~139 | `estadisticas` (paso 11) |
| `rec_datos.pro_batch2_filtros_estadisticas` | Catálogo de estadísticas | Vacía (**sin sus filas `estadisticas_cfg` no hace nada**) | `ddl\07`, ~131 | `estadisticas_cfg` |
| `rec_vista.tipo_identificacion` | Nombre de cada tipo de identificación | Vacía | `ddl\07`, ~146 | paso 12 y `estadisticas` |
| Vista `rec_stage.vstgbatchcargaubicestandarizada` | Universo de personas del insumo estandarizado | No aplica | `ddl\09_vistas_dependencias_sps.sql`, ~57 | `ADD_PORC_INSUMO`, solo si hay una subsección con "Validacion" |

Con la configuración de la prueba (sección 2.6) `ADD_PORC_INSUMO` hace `RETURN` apenas empieza (no hay subsección "Validacion"), así que **no hace falta** descomentar el bloque opcional de `ddl\09` que crea las tablas vacías de P0034.

### 2.4 (iii) Objetos que la migración AÚN NO construye (bloquean parcialmente)

Revisado en `ddl\`, `datos\` y `procedures\`: no hay ningún `CREATE` de estos objetos. **No son tablas que tengas que crear tú**, salvo las vistas puente de la primera fila, que son un artificio de prueba.

| Objeto que falta | Quién lo necesita | Qué paso bloquea | Definición original |
|---|---|---|---|
| `rec_vista.vu_persona` y `rec_vista.v_tipo_persona` | `FILTRO_E` (`procedures\08`, líneas ~731-732) y `cantrepcanal_con` (`procedures\09`, ~713-714) | **Paso 4e del orquestador: bloquea los 3 CSV** | Vistas del DW (`BTTPRUVI` / `BDM_VISTA`). No hay DDL en el workspace. **Solución de prueba abajo (Script P)** |
| `rec_stage.v_ba2_campos_salida` | `transpuesta`, `completitud_canal` | Paso 9 (y 8 si la orientación es vertical) | `P0033_BATCH2_CUBOEXPORT_111.BTQ`: `vstg_BA2_CAMPOS` línea 43, `v_BA2_CamposBase` líneas 177 y 754, `v_ba2_Campos_Salida` línea 1339. **Es el mismo vacío del layout del paso 1 de la sección 3** |
| `rec_stage.vstg_batch2_pn`, `_pj`, `_pnpj` | `transpuesta`, `completitud_canal` | **Paso 9** | `P0033_BATCH2_EXPORTPLANO_111.BTQ` y `_120.BTQ` (se generan como texto dinámico) |
| `rec_stage.vstg_inconsis_pnpj` | `estadisticas` | Paso 11 | `P0033_BATCH2_EXPORTPLANO_111.BTQ`, líneas 1134 (ancho fijo) y 1225 (variable). **No** está en `CUBOEXPORT_111.BTQ` (error de atribución de la guía anterior, de `ddl\10` y de `procedures\09`; hallazgo H6) |
| `rec_stage.batch_cubo_persona11` | `cantrepcanal_con` | Paso 10 | Solo aparece en `Sps_Batch.sql` (~línea 9121). Sin DDL |
| `rec_stage.batch_cubo_temp_dir_total` y sus 3 hermanas (`_telefono_total`, `_celular_total`, `_correo_total`) | `estadisticas` | Paso 11 | Las crearía `estadisticas_cfg` desde filas de `pro_batch2_filtros_estadisticas`, que no llegaron |
| `rec_vista.v_evento_entrega_dato` y `rec_vista.v_cod_entrega_dato` | Filas `LOG` 6 y 13 de `batch_motor_log` (`datos\01`, ~112-125 y ~183-200) | Paso 12 | Vistas del DW (declaradas como dependencia externa en `ddl\07`, ~217-221) |
| Filas de catálogo: `batch_motor_log` con `tipo = 'FILTRO-C'` y `'CANT_REP_CANAL_CONTACTO'`; `pro_batch2_filtros_estadisticas`; `batch2_shells_config`; el contenido **real** de `batch2_homologacion` | Varios | Pasos 2, 4c, 10 y 11 | Pendientes del equipo Teradata (ver `Bitacora_Batch_Teradata.md`) |

**Script P: vistas puente y filas de `rec_vista.persona` (solo para la prueba).** Estas dos vistas leen las tablas `persona` y `tipo_persona` que **sí** existen, con las mismas columnas que usa el código (`vu_persona(cod_tipo_ident_fte, cod_dw_tipo_persona)` y `v_tipo_persona(cod_dw_tipo_persona, nombre_tipo_persona)`). Son una **propuesta derivada de leer el código**, no existen en el repositorio y no se ejecutaron en Redshift. En producción deben apuntar a las vistas reales del DW.

```sql
-- Script P. Se ejecuta en recon_batch2, UNA vez, despues del despliegue.

-- P.1 Verificacion previa: rec_vista.persona debe estar vacia (esperado: 0)
SELECT COUNT(*) AS filas_persona FROM rec_vista.persona;

-- P.2 Una fila por tipo de identificacion (1 y 4 = natural, 2 y 3 = juridica).
--     Ejecutar SOLO si P.1 dio 0. Mas de una fila por tipo duplicaria filas en los CSV.
INSERT INTO rec_vista.persona (cod_tipo_ident_fte, cod_dw_tipo_persona, num_ident) VALUES
 (1, 1, NULL),
 (4, 1, NULL),
 (2, 2, NULL),
 (3, 2, NULL);

-- P.3 Vistas puente
CREATE OR REPLACE VIEW rec_vista.vu_persona AS
SELECT cod_tipo_ident_fte, cod_dw_tipo_persona, num_ident FROM rec_vista.persona;

CREATE OR REPLACE VIEW rec_vista.v_tipo_persona AS
SELECT cod_dw_tipo_persona, nombre_tipo_persona FROM rec_vista.tipo_persona;
```

✔ Resultado esperado: `INSERT 0 4` y dos `CREATE VIEW`. Con esto `FILTRO_E` obtiene `N` para los tipos 1 y 4 y `J` para 2 y 3 (toma la primera letra de `UPPER(nombre_tipo_persona)`: `NATURALES` / `JURIDICAS`), y `exportplano` separa PN (`IN (1,4)`) de PJ (`IN (2,3)`).

**Pre-chequeo de un supuesto del código.** `exportplano` compara `batch_cubo_persona.tipo_id` (texto, `VARCHAR(5)`) con `rec_vista.persona.cod_tipo_ident_fte` (número, `INTEGER`) en un `JOIN`. Se espera una conversión implícita de texto a número **[SUPUESTO SIN CONFIRMAR]**. Compruébalo antes de seguir:

```sql
-- Se ejecuta en recon_batch2
SELECT CAST('1' AS VARCHAR(5)) = 1 AS conversion_implicita;   -- esperado: true
```

⚠ Si da error, **detén la prueba** y reporta un hallazgo bloqueante: el `JOIN` de `exportplano` (línea ~107) no funcionará y la guía no autoriza corregir el código.

### 2.5 Script de verificación: ¿existen las tablas requeridas? ¿cuáles faltan?

Lista los **31 objetos** de la lista (i) (29 tablas) más las 2 vistas puente. No mezcla texto con el catálogo del sistema (solo compara columnas con valores fijos), para evitar el error "Query with different collations" que AWS documenta cuando se mezclan columnas con collation distinta.

```sql
-- Se ejecuta en recon_batch2. Las filas FALTA salen primero.
SELECT objeto, CASE WHEN n > 0 THEN 'EXISTE' ELSE 'FALTA' END AS estado
FROM (
          SELECT 'rec_mtdat.lote_id' AS objeto, (SELECT COUNT(*) FROM svv_tables WHERE table_schema = 'rec_mtdat' AND table_name = 'lote_id') AS n
UNION ALL SELECT 'rec_mtdat.log_td',                         (SELECT COUNT(*) FROM svv_tables WHERE table_schema = 'rec_mtdat' AND table_name = 'log_td')
UNION ALL SELECT 'rec_mtdat.log_td_detalle',                 (SELECT COUNT(*) FROM svv_tables WHERE table_schema = 'rec_mtdat' AND table_name = 'log_td_detalle')
UNION ALL SELECT 'rec_stage.batch_solicitud_batch',          (SELECT COUNT(*) FROM svv_tables WHERE table_schema = 'rec_stage' AND table_name = 'batch_solicitud_batch')
UNION ALL SELECT 'rec_stage.batch_datos_generales',          (SELECT COUNT(*) FROM svv_tables WHERE table_schema = 'rec_stage' AND table_name = 'batch_datos_generales')
UNION ALL SELECT 'rec_stage.batch_salidas_campos',           (SELECT COUNT(*) FROM svv_tables WHERE table_schema = 'rec_stage' AND table_name = 'batch_salidas_campos')
UNION ALL SELECT 'rec_stage.batch_direccion_filtros',        (SELECT COUNT(*) FROM svv_tables WHERE table_schema = 'rec_stage' AND table_name = 'batch_direccion_filtros')
UNION ALL SELECT 'rec_stage.batch_homologaciones',           (SELECT COUNT(*) FROM svv_tables WHERE table_schema = 'rec_stage' AND table_name = 'batch_homologaciones')
UNION ALL SELECT 'rec_stage.batch_porcentajes_filtros',      (SELECT COUNT(*) FROM svv_tables WHERE table_schema = 'rec_stage' AND table_name = 'batch_porcentajes_filtros')
UNION ALL SELECT 'rec_stage.batch2_homologacion',            (SELECT COUNT(*) FROM svv_tables WHERE table_schema = 'rec_stage' AND table_name = 'batch2_homologacion')
UNION ALL SELECT 'rec_stage.batch_motor_log',                (SELECT COUNT(*) FROM svv_tables WHERE table_schema = 'rec_stage' AND table_name = 'batch_motor_log')
UNION ALL SELECT 'rec_stage.pro_plan_ejecucion',             (SELECT COUNT(*) FROM svv_tables WHERE table_schema = 'rec_stage' AND table_name = 'pro_plan_ejecucion')
UNION ALL SELECT 'rec_stage.stg_insumo_batch_validacion',    (SELECT COUNT(*) FROM svv_tables WHERE table_schema = 'rec_stage' AND table_name = 'stg_insumo_batch_validacion')
UNION ALL SELECT 'rec_stage.batch_cubo_persona',             (SELECT COUNT(*) FROM svv_tables WHERE table_schema = 'rec_stage' AND table_name = 'batch_cubo_persona')
UNION ALL SELECT 'rec_stage.batch_cubo_direccion',           (SELECT COUNT(*) FROM svv_tables WHERE table_schema = 'rec_stage' AND table_name = 'batch_cubo_direccion')
UNION ALL SELECT 'rec_stage.batch_cubo_telefono',            (SELECT COUNT(*) FROM svv_tables WHERE table_schema = 'rec_stage' AND table_name = 'batch_cubo_telefono')
UNION ALL SELECT 'rec_stage.batch_cubo_celular',             (SELECT COUNT(*) FROM svv_tables WHERE table_schema = 'rec_stage' AND table_name = 'batch_cubo_celular')
UNION ALL SELECT 'rec_stage.batch_cubo_correo',              (SELECT COUNT(*) FROM svv_tables WHERE table_schema = 'rec_stage' AND table_name = 'batch_cubo_correo')
UNION ALL SELECT 'rec_stage.batch_cubo_ciiu',                (SELECT COUNT(*) FROM svv_tables WHERE table_schema = 'rec_stage' AND table_name = 'batch_cubo_ciiu')
UNION ALL SELECT 'rec_stage.batch_cubo_punto_interes_dir',   (SELECT COUNT(*) FROM svv_tables WHERE table_schema = 'rec_stage' AND table_name = 'batch_cubo_punto_interes_dir')
UNION ALL SELECT 'rec_stage.w_cubo_telefono',                (SELECT COUNT(*) FROM svv_tables WHERE table_schema = 'rec_stage' AND table_name = 'w_cubo_telefono')
UNION ALL SELECT 'rec_stage.w_cubo_celular',                 (SELECT COUNT(*) FROM svv_tables WHERE table_schema = 'rec_stage' AND table_name = 'w_cubo_celular')
UNION ALL SELECT 'rec_stage.w_cubo_direccion',               (SELECT COUNT(*) FROM svv_tables WHERE table_schema = 'rec_stage' AND table_name = 'w_cubo_direccion')
UNION ALL SELECT 'rec_stage.w_cubo_correo',                  (SELECT COUNT(*) FROM svv_tables WHERE table_schema = 'rec_stage' AND table_name = 'w_cubo_correo')
UNION ALL SELECT 'rec_stage.w_cubo_ciiu',                    (SELECT COUNT(*) FROM svv_tables WHERE table_schema = 'rec_stage' AND table_name = 'w_cubo_ciiu')
UNION ALL SELECT 'rec_stage.batch_identificaciones_validas', (SELECT COUNT(*) FROM svv_tables WHERE table_schema = 'rec_stage' AND table_name = 'batch_identificaciones_validas')
UNION ALL SELECT 'rec_stage.batch_identificaciones_incons',  (SELECT COUNT(*) FROM svv_tables WHERE table_schema = 'rec_stage' AND table_name = 'batch_identificaciones_incons')
UNION ALL SELECT 'rec_vista.persona',                        (SELECT COUNT(*) FROM svv_tables WHERE table_schema = 'rec_vista' AND table_name = 'persona')
UNION ALL SELECT 'rec_vista.tipo_persona',                   (SELECT COUNT(*) FROM svv_tables WHERE table_schema = 'rec_vista' AND table_name = 'tipo_persona')
UNION ALL SELECT 'rec_vista.vu_persona (vista puente)',      (SELECT COUNT(*) FROM svv_tables WHERE table_schema = 'rec_vista' AND table_name = 'vu_persona')
UNION ALL SELECT 'rec_vista.v_tipo_persona (vista puente)',  (SELECT COUNT(*) FROM svv_tables WHERE table_schema = 'rec_vista' AND table_name = 'v_tipo_persona')
) t
ORDER BY estado DESC, objeto;
```

✔ Resultado esperado: **31 filas, todas `EXISTE`** (las 2 vistas puente existen solo después del Script P).

| Síntoma | Causa probable | Solución |
|---|---|---|
| Alguna fila dice `FALTA` en un `rec_stage.*`, `rec_mtdat.*` o `rec_vista.persona`/`tipo_persona` | Un `ddl\*.sql` no se ejecutó o falló | Ejecuta el archivo de la columna "DDL" de 2.2 y repite |
| `FALTA` solo en las 2 vistas puente | No has corrido el Script P | Ejecútalo (2.4) |
| Error `Query with different collations is not supported yet` | Redshift mezcló una columna del catálogo (siempre *case sensitive*) con otra de la base | Usa la consulta **V3** de 1.5 (solo lista) y compara a ojo con las tablas de 2.2 |

Además, para el **total** (incluidas las 14 opcionales) usa **V2** de 1.5: 43 tablas (3 / 3 / 34 / 3).

### 2.6 Preparación de los datos de prueba (verificados contra los DDL)

Todos los `INSERT` de esta sección se revisaron contra los `CREATE TABLE` reales: nombres de columna, orden, cantidad de valores, columnas `NOT NULL` y largos de texto. Cada `INSERT` lleva **lista explícita de columnas**, así que no dependen del orden de las columnas de la tabla.

#### 2.6.1 Reglas que cumplen los datos (por qué los valores son así)

| Regla | Por qué |
|---|---|
| `batch_solicitud_batch.prueba` = `'SV'` (o `NULL`) | Cualquier otro valor (incluido `'S'`, que usaba la guía anterior) activa el **enmascaramiento**: `HOMOLOGACIONES` reemplaza teléfonos, direcciones, correos y nombres por `X` (`COALESCE(prueba,'SV') <> 'SV'`). Verías datos falsos en los CSV |
| `codigo_campo` = `DT_NUM`, `DD_DIR`, `DC_NUMERO`, `CE_CORREO`, `DB_CIIU` | Son los únicos que `FILTRO_G` reconoce (`'DT_NUM','CE_CORREO','DD_DIR','DC_NUMERO','DB_CIIU','DECB_NOM'`). La guía anterior usaba `TEL`, `DIR`, `CEL`, `MAI`: **no hacían nada** |
| `grupo_campo` = `CUBO_TEL`, `CUBO_DIR`, `CUBO_CEL`, `CUBO_EMAIL`, `CUBO_CIIU` | `FILTRO_G` convierte ese grupo en el nombre del cubo. Si un canal no tiene `grupo_campo` en la sección `CON DATOS`, **todas** sus filas se excluyen (así "Esencial" omite canales) |
| `nombre_seccion` contiene `CON DATOS` | `FILTRO_G` filtra `nombre_seccion LIKE '%CON DATOS%'` |
| Una sola fila por `codigo_campo` | Dos filas del mismo cubo hacen que `FILTRO_G` aborte con "SELECT-INTO returned more than one row" |
| `requerido_campo` = `'NO'` y `minimo_requerido_campo` = `'0'` | Solo `'SI'` tiene efecto (activa `FILTRO_D` y el paso 4 de `FILTRO_H`). `minimo_requerido_campo` actúa como **cota inferior de la posición**: con 3 se excluirían las 2 primeras filas de cada persona. No es "mínimo de datos" |
| `id_auto` **único entre todas las tablas cubo** (persona 1-99, dirección 1000+, teléfono 2000+, celular 3000+, correo 4000+, CIIU 5000+) | Bug del original replicado: `FILTRO_G` aplica el resultado de un cubo a los 6 por `id_auto`; si coinciden, se contaminan (hallazgo H15) |
| `orden_prioridad` no nulo y distinto por persona y canal | Define cuáles filas sobreviven al recorte. Si es `NULL`, `FILTRO_I` marca la fila y `FILTRO_H` la excluye |
| `tipo_id` y `numero_id` numéricos como texto | `HOMOLOGACIONES`, `FILTRO_F` y `ADICIONAR_INCON` los convierten con `CAST(... AS BIGINT)`: un pasaporte alfanumérico aborta el paso |
| Largos máximos de las columnas que viajan al pivote: ciudad y departamento ≤ 30, `cod_dane_*` ≤ 20, tipo ≤ 15, dirección ≤ 100, zona ≤ 10, estrato ≤ 5, correo ≤ 61, número ≤ 30 | Las `w_cubo_*` son más angostas que los cubos; un dato más largo hace fallar el `INSERT ... SELECT` de `cubo_export` ("value too long") |
| Los cubos contienen **solo la corrida actual** | Los filtros `A..J` **no filtran por solicitud**: `FILTRO_J` "opera sobre todo el contenido del cubo". ⚠ **Ejecuta la prueba en una base donde los cubos estén vacíos o sean solo de prueba** |
| `batch_datos_generales`: exactamente **1 fila** por (solicitud, plantilla) | Con más de una, la subconsulta escalar de `FILTRO_B` falla |
| `no_entregado_x_meses` = `'0'` | `FILTRO_B` y `actualiza_historia` no actúan |

**Corrección de la guía anterior (hallazgos H9, H17):** de `batch_datos_generales` solo se leen `id_plantilla`, `orientacion`, `archivos_pn_pj` y `no_entregado_x_meses`. **Ningún procedure lee** `formato_salida`, `separador`, `ancho_fijo`, `incluir_cabecera`, `sector`, `no_reportado_suscriptor`, `fecha_recogida`, `archivo_condatos`, `sindatos`, `archivo_inconsistencia`, `archivo_tablas` ni `archivo_alertas`. Los nombres de archivo (`CON_DATOS_`, `SIN_DATOS_`, `INCONSISTENCIA_`, `ALERTAS-`) y el separador `;` están **escritos en el código**. La nota "ajustar `separador` al archivo de insumo" no cambia nada en la salida.

#### 2.6.2 Script C: configuración de la solicitud 90001 / plantilla 9001

Antes de cargar, confirma que el catálogo está vacío (si no, **no** cargues las filas de `batch2_homologacion`: ya hay un catálogo real y debes usarlo):

```sql
-- Script C. Se ejecuta en recon_batch2.
-- C.0 Verificacion previa (esperado: 0, 0, 0)
SELECT (SELECT COUNT(*) FROM rec_stage.batch2_homologacion)                       AS homologacion,
       (SELECT COUNT(*) FROM rec_stage.batch_solicitud_batch WHERE id_solicitud = 90001) AS solicitud_90001,
       (SELECT COUNT(*) FROM rec_stage.batch_cubo_persona)                         AS personas_en_cubo;

-- C.1 La solicitud (11 columnas). prueba = 'SV' para NO enmascarar. estado y fecha_generacion en NULL
--     para que actualiza_historia pueda cerrarla.
INSERT INTO rec_stage.batch_solicitud_batch
 (id_solicitud, tipo_id_suscriptor, num_id_suscriptor, nombre_plantilla, prueba, archivo_control,
  fecha_solicitud, archivo_log, estado, id_planilla, fecha_generacion)
VALUES
 (90001, '1', '900123456', 'ESENCIAL', 'SV', NULL, GETDATE(), NULL, NULL, NULL, NULL);

-- C.2 Datos generales (17 columnas). Solo se leen id_plantilla, orientacion, archivos_pn_pj y no_entregado_x_meses.
INSERT INTO rec_stage.batch_datos_generales
 (id_solicitud, id_plantilla, formato_salida, separador, ancho_fijo, orientacion, incluir_cabecera,
  archivos_pn_pj, sector, no_reportado_suscriptor, no_entregado_x_meses, fecha_recogida,
  archivo_condatos, sindatos, archivo_inconsistencia, archivo_tablas, archivo_alertas)
VALUES
 (90001, 9001, 'FE_CSV', ';', NULL, 'OE_HORIZON', 'SI',
  '0', NULL, NULL, '0', NULL,
  'CON_DATOS', 'SIN_DATOS', 'INCONSISTENCIA', NULL, 'ALERTAS');

-- C.3 Catalogo de columnas de salida: AQUI SE FIJA EL 3/3/2/2 (columna cantidad_max_campo)
INSERT INTO rec_stage.batch_salidas_campos
 (id_solicitud, id_plantilla, nombre_seccion, codigo_seccion, nombre_subseccion, codigo_subseccion,
  orden_subseccion, grupo_campo, nombre_campo, codigo_campo, orden_campo, cantidad_max_campo,
  af_ancho_campo, af_relleno_campo, af_orientacion_campo, requerido_campo, minimo_requerido_campo)
VALUES
 (90001, 9001, 'CON DATOS DE UBICACION', '01', 'Datos de identificacion', 'AGSB_DI',  1, 'CUBO_CIIU',  'CIIU',            'DB_CIIU',   13, 1,  20, ' ', '0', 'NO', '0'),
 (90001, 9001, 'CON DATOS DE UBICACION', '01', 'Telefonos',               'AGSB_TEL', 2, 'CUBO_TEL',   'Numero telefono', 'DT_NUM',    20, 3,  30, ' ', '0', 'NO', '0'),
 (90001, 9001, 'CON DATOS DE UBICACION', '01', 'Direcciones',             'AGSB_DIR', 3, 'CUBO_DIR',   'Direccion',       'DD_DIR',    30, 3, 100, ' ', '0', 'NO', '0'),
 (90001, 9001, 'CON DATOS DE UBICACION', '01', 'Datos adicionales',       'AGSB_DAD', 4, 'CUBO_CEL',   'Numero celular',  'DC_NUMERO', 40, 2,  30, ' ', '0', 'NO', '0'),
 (90001, 9001, 'CON DATOS DE UBICACION', '01', 'Datos adicionales',       'AGSB_DAD', 4, 'CUBO_EMAIL', 'Correo',          'CE_CORREO', 41, 2,  61, ' ', '0', 'NO', '0');

-- C.4 Diccionario codigo_campo -> cubo -> columna fisica (5 filas MINIMAS derivadas del codigo,
--     NO es el catalogo real, que no esta en el workspace). xalias son los alias del DDL (CBTEL, CBDIR...).
INSERT INTO rec_stage.batch2_homologacion
 (id_sequencia, codigo_campo, homologado, grupo_campo, cubo, xalias)
VALUES
 (1, 'DT_NUM',    'numero',    'CUBO_TEL',   'Telefono',  'CBTEL'),
 (2, 'DD_DIR',    'direccion', 'CUBO_DIR',   'Direccion', 'CBDIR'),
 (3, 'DC_NUMERO', 'numero',    'CUBO_CEL',   'Celular',   'CBCEL'),
 (4, 'CE_CORREO', 'correo',    'CUBO_EMAIL', 'Correo',    'CBCOR'),
 (5, 'DB_CIIU',   'ciiu',      'CUBO_CIIU',  'Ciiu',      'CBCII');
```

✔ Resultado esperado: C.0 devuelve `0 | 0 | 0`; luego `INSERT 0 1`, `INSERT 0 1`, `INSERT 0 5`, `INSERT 0 5`.

Sobre las filas de C.3: cada fila dice "este campo existe en la plantilla y se repite hasta `cantidad_max_campo` veces". Teléfonos **3**, direcciones **3**, celulares **2**, correos **2** y CIIU **1**: ese es el producto Esencial. Los otros campos de la muestra `Salidas\CON_DATOS_4421_...ESQUEMA` (identificación, ciudad, departamento, tipo...) **no hacen falta** para esta prueba: hoy ningún procedure los usa (los usaría el layout dinámico, que aún no existe). `codigo_seccion` (`'01'`) y las columnas `af_*` (ancho fijo) llevan valores de ejemplo: en los procedures que se ejecutan en esta prueba no encontré que se usen (`valida_archivos` solo suma `af_ancho_campo` para informar). **[SUPUESTO SIN CONFIRMAR]** que ningún otro paso los lea.

#### 2.6.3 Script D: 6 personas y sus contactos (más de 3/3/2/2 para probar el recorte)

Qué se carga y qué se espera ver después de PROCESACUBOS (recorte a 3/3/2/2):

| Persona (`id_buro_persona`) | Tipo | Direcciones / teléfonos / celulares / correos **cargados** | Después del recorte | Va a |
|---|---|---|---|---|
| 1 | 1 (natural) | 4 / 4 / 3 / 3 (pasa el tope en los cuatro canales) | 3 / 3 / 2 / 2 | `CON_DATOS` y `_PN` |
| 2 | 1 | 3 / 3 / 2 / 2 (justo en el tope) | 3 / 3 / 2 / 2 | `CON_DATOS` y `_PN` |
| 3 | 1 | 1 / **5** / 0 / 1 (5 teléfonos: tope del pivote de teléfono) | 1 / 3 / 0 / 1 | `CON_DATOS` y `_PN` |
| 4 | 4 (natural) | 2 / 2 / 1 / 1 (menos que el tope: "según disponibilidad") | 2 / 2 / 1 / 1 | `CON_DATOS` y `_PN` |
| 5 | 2 (jurídica) | 4 / 4 / 3 / 3 | 3 / 3 / 2 / 2 | `CON_DATOS` y `_PJ` |
| 6 | 1 | 0 / 0 / 0 / 0 (sin ningún contacto) | sin filas | `SIN_DATOS` y `_PN` |
| (sin persona) | 1 | identificación `55500007`, válida pero **no está** en el cubo de personas | pasa a inconsistencias | `INCONSISTENCIA` |

```sql
-- Script D. Se ejecuta en recon_batch2, DESPUES del Script C. Datos ficticios (dominio example.com).

-- D.1 Personas: 18 columnas. id_solicitud = 90001 e id_plantilla = 9001 son obligatorios.
INSERT INTO rec_stage.batch_cubo_persona
 (id_auto, id_buro_persona, cod_pin_persona, id_solicitud, id_plantilla, tipo_id, numero_id,
  primer_apellido, segundo_apellido, primer_nombre, segundo_nombre, nombre_completo,
  fecha_expedicion, ciudad_expedicion, departamento_expedicion, genero, rango_edad, orden_prioridad)
VALUES
 (1, 1, 'PIN0001', 90001, 9001, '1', '10000001',  'PRUEBA', 'UNO',    'ANA',     'MARIA', 'ANA MARIA PRUEBA UNO',        '15/03/2005', 'BOGOTA',       'CUNDINAMARCA',    'F', '26-35', 1),
 (2, 2, 'PIN0002', 90001, 9001, '1', '10000002',  'PRUEBA', 'DOS',    'BEATRIZ', NULL,    'BEATRIZ PRUEBA DOS',          '20/07/2008', 'MEDELLIN',     'ANTIOQUIA',       'F', '36-45', 1),
 (3, 3, 'PIN0003', 90001, 9001, '1', '10000003',  'PRUEBA', 'TRES',   'CARLOS',  NULL,    'CARLOS PRUEBA TRES',          '02/11/2010', 'CALI',         'VALLE DEL CAUCA', 'M', '46-55', 1),
 (4, 4, 'PIN0004', 90001, 9001, '4', '10000004',  'PRUEBA', 'CUATRO', 'DIANA',   'PAOLA', 'DIANA PAOLA PRUEBA CUATRO',   '09/09/2012', 'BARRANQUILLA', 'ATLANTICO',       'F', '18-25', 1),
 (5, 5, 'PIN0005', 90001, 9001, '2', '900000005', NULL,     NULL,     NULL,      NULL,    'EMPRESA PRUEBA CINCO SAS',    NULL,         NULL,           NULL,              NULL, NULL,   1),
 (6, 6, 'PIN0006', 90001, 9001, '1', '10000006',  'PRUEBA', 'SEIS',   'FELIPE',  NULL,    'FELIPE PRUEBA SEIS',          '30/01/2015', 'BOGOTA',       'CUNDINAMARCA',    'M', '56+',   1);

-- D.2 Direcciones: 14 filas (persona 1: 4; 2: 3; 3: 1; 4: 2; 5: 4). id_auto 1001+
INSERT INTO rec_stage.batch_cubo_direccion
 (id_auto, id_buro_persona, cod_pin_persona, direccion, ciudad, departamento, cod_dane_ciudad,
  cod_dane_departamento, tipo, zona, estrato, fecha_ultima_actualizacion, numero_de_entidades_reporta, orden_prioridad)
VALUES
 (1001, 1, 'PIN0001', 'CL 10 # 1-01',  'BOGOTA',       'CUNDINAMARCA',    '11001', '11', 'RESIDENCIA', 'URBANA', '3', '2026-09-01', 5, 1),
 (1002, 1, 'PIN0001', 'CL 10 # 2-02',  'BOGOTA',       'CUNDINAMARCA',    '11001', '11', 'RESIDENCIA', 'URBANA', '3', '2026-09-01', 4, 2),
 (1003, 1, 'PIN0001', 'CL 10 # 3-03',  'BOGOTA',       'CUNDINAMARCA',    '11001', '11', 'RESIDENCIA', 'URBANA', '3', '2026-09-01', 3, 3),
 (1004, 1, 'PIN0001', 'CL 10 # 4-04',  'BOGOTA',       'CUNDINAMARCA',    '11001', '11', 'RESIDENCIA', 'URBANA', '3', '2026-09-01', 2, 4),
 (1005, 2, 'PIN0002', 'KR 20 # 5-01',  'MEDELLIN',     'ANTIOQUIA',       '05001', '05', 'RESIDENCIA', 'URBANA', '4', '2026-09-01', 6, 1),
 (1006, 2, 'PIN0002', 'KR 20 # 6-02',  'MEDELLIN',     'ANTIOQUIA',       '05001', '05', 'RESIDENCIA', 'URBANA', '4', '2026-09-01', 5, 2),
 (1007, 2, 'PIN0002', 'KR 20 # 7-03',  'MEDELLIN',     'ANTIOQUIA',       '05001', '05', 'RESIDENCIA', 'URBANA', '4', '2026-09-01', 4, 3),
 (1008, 3, 'PIN0003', 'AV 30 # 8-01',  'CALI',         'VALLE DEL CAUCA', '76001', '76', 'RESIDENCIA', 'URBANA', '2', '2026-09-01', 3, 1),
 (1009, 4, 'PIN0004', 'TV 40 # 9-01',  'BARRANQUILLA', 'ATLANTICO',       '08001', '08', 'RESIDENCIA', 'URBANA', '3', '2026-09-01', 2, 1),
 (1010, 4, 'PIN0004', 'TV 40 # 9-02',  'BARRANQUILLA', 'ATLANTICO',       '08001', '08', 'RESIDENCIA', 'URBANA', '3', '2026-09-01', 1, 2),
 (1011, 5, 'PIN0005', 'CL 50 # 11-01', 'BOGOTA',       'CUNDINAMARCA',    '11001', '11', 'COMERCIAL',  'URBANA', '4', '2026-09-01', 7, 1),
 (1012, 5, 'PIN0005', 'CL 50 # 12-02', 'BOGOTA',       'CUNDINAMARCA',    '11001', '11', 'COMERCIAL',  'URBANA', '4', '2026-09-01', 6, 2),
 (1013, 5, 'PIN0005', 'CL 50 # 13-03', 'BOGOTA',       'CUNDINAMARCA',    '11001', '11', 'COMERCIAL',  'URBANA', '4', '2026-09-01', 5, 3),
 (1014, 5, 'PIN0005', 'CL 50 # 14-04', 'BOGOTA',       'CUNDINAMARCA',    '11001', '11', 'COMERCIAL',  'URBANA', '4', '2026-09-01', 4, 4);

-- D.3 Telefonos fijos: 18 filas (persona 1: 4; 2: 3; 3: 5; 4: 2; 5: 4). id_auto 2001+
INSERT INTO rec_stage.batch_cubo_telefono
 (id_auto, id_buro_persona, cod_pin_persona, numero, ciudad, departamento, cod_dane_ciudad,
  cod_dane_departamento, indicativo, tipo, fecha_ultima_actualizacion, numero_de_entidades_reporta, orden_prioridad)
VALUES
 (2001, 1, 'PIN0001', '6011000001', 'BOGOTA',       'CUNDINAMARCA',    '11001', '11', '601', 'FIJO', '2026-09-01', 5, 1),
 (2002, 1, 'PIN0001', '6011000002', 'BOGOTA',       'CUNDINAMARCA',    '11001', '11', '601', 'FIJO', '2026-09-01', 4, 2),
 (2003, 1, 'PIN0001', '6011000003', 'BOGOTA',       'CUNDINAMARCA',    '11001', '11', '601', 'FIJO', '2026-09-01', 3, 3),
 (2004, 1, 'PIN0001', '6011000004', 'BOGOTA',       'CUNDINAMARCA',    '11001', '11', '601', 'FIJO', '2026-09-01', 2, 4),
 (2005, 2, 'PIN0002', '6042000001', 'MEDELLIN',     'ANTIOQUIA',       '05001', '05', '604', 'FIJO', '2026-09-01', 5, 1),
 (2006, 2, 'PIN0002', '6042000002', 'MEDELLIN',     'ANTIOQUIA',       '05001', '05', '604', 'FIJO', '2026-09-01', 4, 2),
 (2007, 2, 'PIN0002', '6042000003', 'MEDELLIN',     'ANTIOQUIA',       '05001', '05', '604', 'FIJO', '2026-09-01', 3, 3),
 (2008, 3, 'PIN0003', '6023000001', 'CALI',         'VALLE DEL CAUCA', '76001', '76', '602', 'FIJO', '2026-09-01', 6, 1),
 (2009, 3, 'PIN0003', '6023000002', 'CALI',         'VALLE DEL CAUCA', '76001', '76', '602', 'FIJO', '2026-09-01', 5, 2),
 (2010, 3, 'PIN0003', '6023000003', 'CALI',         'VALLE DEL CAUCA', '76001', '76', '602', 'FIJO', '2026-09-01', 4, 3),
 (2011, 3, 'PIN0003', '6023000004', 'CALI',         'VALLE DEL CAUCA', '76001', '76', '602', 'FIJO', '2026-09-01', 3, 4),
 (2012, 3, 'PIN0003', '6023000005', 'CALI',         'VALLE DEL CAUCA', '76001', '76', '602', 'FIJO', '2026-09-01', 2, 5),
 (2013, 4, 'PIN0004', '6054000001', 'BARRANQUILLA', 'ATLANTICO',       '08001', '08', '605', 'FIJO', '2026-09-01', 2, 1),
 (2014, 4, 'PIN0004', '6054000002', 'BARRANQUILLA', 'ATLANTICO',       '08001', '08', '605', 'FIJO', '2026-09-01', 1, 2),
 (2015, 5, 'PIN0005', '6015000001', 'BOGOTA',       'CUNDINAMARCA',    '11001', '11', '601', 'FIJO', '2026-09-01', 7, 1),
 (2016, 5, 'PIN0005', '6015000002', 'BOGOTA',       'CUNDINAMARCA',    '11001', '11', '601', 'FIJO', '2026-09-01', 6, 2),
 (2017, 5, 'PIN0005', '6015000003', 'BOGOTA',       'CUNDINAMARCA',    '11001', '11', '601', 'FIJO', '2026-09-01', 5, 3),
 (2018, 5, 'PIN0005', '6015000004', 'BOGOTA',       'CUNDINAMARCA',    '11001', '11', '601', 'FIJO', '2026-09-01', 4, 4);

-- D.4 Celulares: 9 filas (persona 1: 3; 2: 2; 4: 1; 5: 3). id_auto 3001+
INSERT INTO rec_stage.batch_cubo_celular
 (id_auto, id_buro_persona, cod_pin_persona, numero, tipo, fecha_ultima_actualizacion,
  numero_de_entidades_reporta, orden_prioridad)
VALUES
 (3001, 1, 'PIN0001', '3001000001', 'MOVIL', '2026-09-01', 5, 1),
 (3002, 1, 'PIN0001', '3001000002', 'MOVIL', '2026-09-01', 4, 2),
 (3003, 1, 'PIN0001', '3001000003', 'MOVIL', '2026-09-01', 3, 3),
 (3004, 2, 'PIN0002', '3002000001', 'MOVIL', '2026-09-01', 4, 1),
 (3005, 2, 'PIN0002', '3002000002', 'MOVIL', '2026-09-01', 3, 2),
 (3006, 4, 'PIN0004', '3004000001', 'MOVIL', '2026-09-01', 2, 1),
 (3007, 5, 'PIN0005', '3005000001', 'MOVIL', '2026-09-01', 6, 1),
 (3008, 5, 'PIN0005', '3005000002', 'MOVIL', '2026-09-01', 5, 2),
 (3009, 5, 'PIN0005', '3005000003', 'MOVIL', '2026-09-01', 4, 3);

-- D.5 Correos: 10 filas (persona 1: 3; 2: 2; 3: 1; 4: 1; 5: 3). id_auto 4001+
INSERT INTO rec_stage.batch_cubo_correo
 (id_auto, id_buro_persona, cod_pin_persona, correo, fecha_ultima_actualizacion,
  numero_de_entidades_reporta, orden_prioridad)
VALUES
 (4001, 1, 'PIN0001', 'p1.a@example.com', '2026-09-01', 5, 1),
 (4002, 1, 'PIN0001', 'p1.b@example.com', '2026-09-01', 4, 2),
 (4003, 1, 'PIN0001', 'p1.c@example.com', '2026-09-01', 3, 3),
 (4004, 2, 'PIN0002', 'p2.a@example.com', '2026-09-01', 4, 1),
 (4005, 2, 'PIN0002', 'p2.b@example.com', '2026-09-01', 3, 2),
 (4006, 3, 'PIN0003', 'p3.a@example.com', '2026-09-01', 3, 1),
 (4007, 4, 'PIN0004', 'p4.a@example.com', '2026-09-01', 2, 1),
 (4008, 5, 'PIN0005', 'p5.a@example.com', '2026-09-01', 6, 1),
 (4009, 5, 'PIN0005', 'p5.b@example.com', '2026-09-01', 5, 2),
 (4010, 5, 'PIN0005', 'p5.c@example.com', '2026-09-01', 4, 3);

-- D.6 CIIU: 2 filas (personas 1 y 5). id_auto 5001+
INSERT INTO rec_stage.batch_cubo_ciiu
 (id_auto, id_buro_persona, cod_pin_persona, ciiu, actividad_economica, fecha_reporte, orden_prioridad)
VALUES
 (5001, 1, 'PIN0001', '6201', 'ACTIVIDADES DE DESARROLLO DE SISTEMAS INFORMATICOS', '2026-08-15', 1),
 (5002, 5, 'PIN0005', '4711', 'COMERCIO AL POR MENOR EN ESTABLECIMIENTOS NO ESPECIALIZADOS', '2026-08-15', 1);

-- D.7 Identificaciones validas: las 6 personas (no se mueven) + la 55500007, que NO esta en el cubo de personas
INSERT INTO rec_stage.batch_identificaciones_validas
 (id_solicitud, id_plantilla, tipo_id, numero_id)
VALUES
 (90001, 9001, '1', '10000001'),
 (90001, 9001, '1', '10000002'),
 (90001, 9001, '1', '10000003'),
 (90001, 9001, '4', '10000004'),
 (90001, 9001, '2', '900000005'),
 (90001, 9001, '1', '10000006'),
 (90001, 9001, '1', '55500007');
```

✔ Resultado esperado: `INSERT 0 6`, `INSERT 0 14`, `INSERT 0 18`, `INSERT 0 9`, `INSERT 0 10`, `INSERT 0 2`, `INSERT 0 7`.

**Verificación de la carga** (cuenta de filas por tabla):

```sql
-- Se ejecuta en recon_batch2
SELECT 'batch_solicitud_batch' AS tabla, COUNT(*) AS filas, 1 AS esperado FROM rec_stage.batch_solicitud_batch WHERE id_solicitud = 90001
UNION ALL SELECT 'batch_datos_generales',          COUNT(*),  1 FROM rec_stage.batch_datos_generales WHERE id_solicitud = 90001
UNION ALL SELECT 'batch_salidas_campos',           COUNT(*),  5 FROM rec_stage.batch_salidas_campos WHERE id_solicitud = 90001
UNION ALL SELECT 'batch2_homologacion',            COUNT(*),  5 FROM rec_stage.batch2_homologacion
UNION ALL SELECT 'batch_cubo_persona',             COUNT(*),  6 FROM rec_stage.batch_cubo_persona WHERE id_solicitud = 90001
UNION ALL SELECT 'batch_cubo_direccion',           COUNT(*), 14 FROM rec_stage.batch_cubo_direccion
UNION ALL SELECT 'batch_cubo_telefono',            COUNT(*), 18 FROM rec_stage.batch_cubo_telefono
UNION ALL SELECT 'batch_cubo_celular',             COUNT(*),  9 FROM rec_stage.batch_cubo_celular
UNION ALL SELECT 'batch_cubo_correo',              COUNT(*), 10 FROM rec_stage.batch_cubo_correo
UNION ALL SELECT 'batch_cubo_ciiu',                COUNT(*),  2 FROM rec_stage.batch_cubo_ciiu
UNION ALL SELECT 'batch_identificaciones_validas', COUNT(*),  7 FROM rec_stage.batch_identificaciones_validas WHERE id_solicitud = 90001
UNION ALL SELECT 'rec_vista.persona',              COUNT(*),  4 FROM rec_vista.persona;
```

✔ Resultado esperado: en cada fila `filas` es igual a `esperado`. Si un `INSERT` falla con "value too long" o "null value in column ... violates not-null constraint", revisa que no cambiaste los largos ni dejaste vacío `id_auto` / `id_buro_persona` / `codigo_campo` / `id_solicitud`.

#### 2.6.4 Qué cambió respecto a la guía anterior (para quien la conozca)

| Antes | Ahora | Motivo |
|---|---|---|
| `prueba = 'S'` | `'SV'` | `'S'` enmascara los datos (H13) |
| `codigo_campo` `DIR`/`TEL`/`CEL`/`MAI` | `DD_DIR`/`DT_NUM`/`DC_NUMERO`/`CE_CORREO` | Son los códigos que reconoce `FILTRO_G` |
| `requerido_campo = 'N'` | `'NO'` | Solo `'SI'` tiene efecto; `'NO'` es el valor de catálogo (H17) |
| Sin `batch2_homologacion` | 5 filas de ejemplo | Sin ellas `FILTRO_G` no hace nada |
| Sin `rec_vista.persona` ni vistas puente | Script P | Sin ellas `FILTRO_E` aborta y los CSV salen vacíos |
| Cubos sin `id_auto` únicos | rangos disjuntos | Bug H15 |
| "Cargar el CSV de insumo con `COPY`... pendiente" | Opción B con `COPY` explicado (paso 2 de la sección 3) | Se pidió explicar cada parte |

---

## 3. Pasos detallados para ejecutar la prueba

Siete pasos, en este orden: **(1)** ajustes de desarrollo previos, **(2)** carga de datos, **(3)** el `CALL`, **(4)** seguir la ejecución, **(5)** verificar resultados, **(6)** limpiar y repetir, **(7)** criterio de éxito. Cada paso dice qué se hace, por qué, el comando exacto, el resultado esperado y el plan B.

**Antes del paso 1, confirma el punto de partida** (todo debe estar en verde):

- [ ] El despliegue de la sección 1 terminó y V1 a V9 dieron lo esperado.
- [ ] Tienes una base **solo de prueba** (los filtros modifican y borran filas de **todo** el contenido de los cubos).
- [ ] Tienes `$H`, `$U`, `$DB = "recon_batch2"` y `PGPASSWORD` definidos (paso D0).
- [ ] Tienes el bucket, el rol (`<ROL_ARN>`) y la Lambda (o, como mínimo, las 4 funciones de similitud creadas): secciones 1.2.2 a 1.2.9.

### Paso 1. Ajustes de desarrollo previos (3.1 y 3.2): ¿siguen pendientes?

**Qué se hace:** comprobar si el equipo de desarrollo ya aplicó los dos ajustes que necesita el 3/3/2/2 completo. **Por qué:** sin ellos el CSV nunca mostrará más de 1 teléfono, 1 dirección, 1 correo y 0 celulares. **Esta guía no modifica código**: solo dice qué debe cambiarse, para que lo haga quien mantiene el repositorio.

**Cómo saber si ya están hechos** (ejecutar en `recon_batch2`):

```sql
-- 3.1 aplicado?  Esperado: 1 si ya existe el bloque _003 de direccion, 0 si sigue pendiente
SELECT COUNT(*) AS tiene_direccion_003
FROM svv_columns
WHERE table_schema = 'rec_stage' AND table_name = 'w_cubo_direccion' AND column_name = 'direccion_003';

-- 3.1 y 3.2 aplicados en los procedures?  Busca "rn <= 3" y "w_cubo_celular" en el texto de cada uno
SHOW PROCEDURE rec_stage.sp_batch2_cubo_export(bigint, bigint);
SHOW PROCEDURE rec_stage.sp_batch2_exportplano(bigint, bigint, varchar, varchar, varchar, varchar);
```

([`SVV_COLUMNS`](https://docs.aws.amazon.com/redshift/latest/dg/r_SVV_COLUMNS.html) lista las columnas; [`SHOW PROCEDURE`](https://docs.aws.amazon.com/redshift/latest/dg/r_SHOW_PROCEDURE.html) muestra el texto de un procedure.) Verificación hecha el 2026-10-15 leyendo los archivos: **ambos ajustes siguen pendientes** (`ddl\04_tablas_pivote.sql` solo tiene `_001` y `_002` en `w_cubo_direccion`; `procedures\03` usa `WHERE rn <= 2` en dirección; `procedures\04` no nombra `w_cubo_celular`).

#### 1.A Ajuste 3.1: tercera dirección en el pivote (DDL + procedure)

| Qué | Archivo y bloque | Cambio concreto |
|---|---|---|
| Columnas nuevas | `ddl\04_tablas_pivote.sql`, tabla `w_cubo_direccion` (líneas ~53-64) | Después del bloque `_002` (línea ~58) agregar una coma y un bloque `_003` de **11 columnas**: `ciudad_003 VARCHAR(30), departamento_003 VARCHAR(30), codigo_dane_ciudad_003 VARCHAR(20), codigo_dane_departamento_003 VARCHAR(20), direccion_003 VARCHAR(100), tipo_003 VARCHAR(15), zona_003 VARCHAR(10), estrato_003 VARCHAR(5), fecha_ultima_actualizacion_003 VARCHAR(10), numero_entidades_reporta_003 VARCHAR(10), por_sim_dir_003 VARCHAR(30)` |
| Llenado del pivote | `procedures\03_sp_batch2_cubo_export.sql`, bloque `DIRECCION` (líneas ~83-104) | Agregar, tras el último `MAX(CASE WHEN rn = 2 ...)`, **11 expresiones `MAX(CASE WHEN rn = 3 THEN ... END)`** en el mismo orden que las columnas (ciudad, departamento, cod_dane_ciudad, cod_dane_departamento, direccion, tipo, zona, estrato, `TO_CHAR(fecha_ultima_actualizacion,'DD/MM/YYYY')`, `CAST(numero_de_entidades_reporta AS VARCHAR(10))`, `CAST(por_sim_dir AS VARCHAR(30))`) y cambiar `WHERE rn <= 2` (línea ~102) por `WHERE rn <= 3` |
| Cómo reinstalar | Consola SQL | `DROP TABLE rec_stage.w_cubo_direccion;` y luego `ddl\04` y `procedures\03` (el `CREATE TABLE IF NOT EXISTS` no añade columnas a una tabla que ya existe) |

⚠ El `INSERT INTO rec_stage.w_cubo_direccion SELECT ...` es **posicional** (no lista columnas): el número y el orden de las expresiones deben coincidir **exactamente** con las columnas del DDL.

#### 1.B Ajuste 3.2: layout de `exportplano` con celular y 3/3/2/2

Versión **mínima** (layout fijo 3/3/2/2). Archivo: `procedures\04_sp_batch2_exportplano.sql`, construcción de `v_sql_pnpj` (líneas ~85-117):

1. En el bloque de `JOIN` de "CON DATOS" (líneas ~110-113), agregar `LEFT JOIN rec_stage.w_cubo_celular CBCEL ON CBPER.id_buro_persona = CBCEL.id_buro_persona AND COALESCE(CBCEL.filtro_h,0) = 0` (con el mismo patrón `... || v_filtro_h` que `CBTEL`, `CBDIR` y `CBCOR`).
2. En la lista de columnas de "CON DATOS" (líneas ~102-104), repetir cada grupo: teléfono `_001`, `_002`, `_003` (de `CBTEL`), dirección `_001`, `_002`, `_003` (de `CBDIR`), celular `_001`, `_002` (de `CBCEL`) y correo `_001`, `_002` (de `CBCOR`). **Cada alias de columna debe ser único** (el código actual usa el sufijo `b` para eso).
3. Decidir la columna final `"Numero 001b"`: hoy sale de `CBCOR.numero_001`, que es la columna "compat" del correo; en la muestra de Teradata esa posición es `DC_NUMERO`, el **número del celular** (hallazgo H5, **[SUPUESTO SIN CONFIRMAR]** el mapeo en Teradata).

Versión **ideal** (la que documenta la cabecera del procedure como pendiente): armar los bloques recorriendo `batch_salidas_campos` unida con `batch2_homologacion`, para que el mismo procedure sirva a cualquier plantilla. Eso exige construir primero `rec_stage.v_ba2_campos_salida` (trabajo F2-5; sección 2.4) y de paso resuelve el bloqueo del paso 9 del orquestador.

Reinstalación: `Invoke-Sql "procedures\04_sp_batch2_exportplano.sql"`.

#### 1.C Si los ajustes NO se hacen: prueba "mínima aceptable" y sus límites

La prueba sigue siendo válida para comprobar **la lógica del recorte y la generación de archivos**, con estos límites declarados:

| Canal | Tope Esencial | Qué se puede validar hoy | Dónde se valida | Límite |
|---|---|---|---|---|
| Teléfonos | 3 | Recorte a 3 (5 cargados para la persona 3) | cubo después de PROCESACUBOS y `w_cubo_telefono` (admite 5) | En el CSV sale **1** teléfono |
| Direcciones | 3 | Recorte a 3 (4 cargadas) | **Solo en el cubo** (paso 5.2) | `w_cubo_direccion` admite solo **2**; en el CSV sale **1** |
| Celulares | 2 | Recorte a 2 (3 cargados) | cubo y `w_cubo_celular` | El CSV **no trae celular** |
| Correos | 2 | Recorte a 2 (3 cargados) | cubo y `w_cubo_correo` | En el CSV sale **1** correo (+ la columna `Numero 001b`, ver H5) |

Con estos límites el criterio de éxito es el **Nivel 1** del paso 7. El **Nivel 2** (3/3/2/2 completo dentro del CSV) solo es posible después de 1.A y 1.B.

✔ Resultado esperado de este paso: sabes en cuál de los dos niveles vas a evaluar.

### Paso 2. Carga de datos

**Qué se hace:** dejar en las tablas lo que el proceso necesita para correr. **Por qué:** el proceso BATCH2 no carga datos de entrada; los espera ya cargados (lo dice `README.md`).

**Orden:** primero el **Script P** (sección 2.4), luego el **Script C** y el **Script D** (sección 2.6). Si ya los ejecutaste, salta a la verificación de la carga (2.6.3).

#### Opción A. `INSERT` directo (recomendada para empezar)

Guarda los bloques SQL en **dos archivos tuyos, fuera del repositorio**:

- `C:\prueba_esencial\datos_puente.sql`: el **Script P** de la sección 2.4. Se ejecuta **una sola vez** (las filas de `rec_vista.persona` y las vistas puente se quedan).
- `C:\prueba_esencial\datos_esencial.sql`: los **Scripts C y D** de la sección 2.6. Se ejecuta **en cada repetición** de la prueba.

```powershell
# PowerShell
psql -h $H -p 5439 -U $U -d $DB -v ON_ERROR_STOP=1 -f C:\prueba_esencial\datos_puente.sql     # una sola vez
psql -h $H -p 5439 -U $U -d $DB -v ON_ERROR_STOP=1 -f C:\prueba_esencial\datos_esencial.sql   # en cada repeticion
```

Por qué archivos propios: el pipeline **modifica y borra** los datos. Para repetir la prueba (paso 6) vuelves a correr `datos_esencial.sql` después de limpiar. ⚠ Si ejecutas un archivo dos veces sin limpiar, quedan **filas duplicadas** (Redshift no impide duplicados: estas tablas no declaran llave primaria). En el caso de `rec_vista.persona` los duplicados además **repiten filas en los CSV**: por eso el Script P va aparte.

✔ Resultado esperado: las respuestas `INSERT 0 n` de 2.4 y 2.6, y la verificación de 2.6.3 con `filas = esperado` en todas las líneas.

#### Opción B. `COPY` desde S3 (más fiel a una carga real de archivos)

`COPY` carga en una tabla los datos de uno o varios archivos de S3. Es lo que se usaría para cargar volúmenes grandes. Ejemplo completo para la tabla de teléfonos (las otras cinco tablas de cubos siguen el mismo patrón: cambian la tabla, la lista de columnas y el archivo).

**B.1 Crear el archivo CSV de teléfonos** (separado por comas, con cabecera) y subirlo a S3:

```powershell
# PowerShell
@'
id_auto,id_buro_persona,cod_pin_persona,numero,ciudad,departamento,cod_dane_ciudad,cod_dane_departamento,indicativo,tipo,fecha_ultima_actualizacion,numero_de_entidades_reporta,orden_prioridad
2001,1,PIN0001,6011000001,BOGOTA,CUNDINAMARCA,11001,11,601,FIJO,2026-09-01,5,1
2002,1,PIN0001,6011000002,BOGOTA,CUNDINAMARCA,11001,11,601,FIJO,2026-09-01,4,2
2003,1,PIN0001,6011000003,BOGOTA,CUNDINAMARCA,11001,11,601,FIJO,2026-09-01,3,3
2004,1,PIN0001,6011000004,BOGOTA,CUNDINAMARCA,11001,11,601,FIJO,2026-09-01,2,4
2005,2,PIN0002,6042000001,MEDELLIN,ANTIOQUIA,05001,05,604,FIJO,2026-09-01,5,1
2006,2,PIN0002,6042000002,MEDELLIN,ANTIOQUIA,05001,05,604,FIJO,2026-09-01,4,2
2007,2,PIN0002,6042000003,MEDELLIN,ANTIOQUIA,05001,05,604,FIJO,2026-09-01,3,3
2008,3,PIN0003,6023000001,CALI,VALLE DEL CAUCA,76001,76,602,FIJO,2026-09-01,6,1
2009,3,PIN0003,6023000002,CALI,VALLE DEL CAUCA,76001,76,602,FIJO,2026-09-01,5,2
2010,3,PIN0003,6023000003,CALI,VALLE DEL CAUCA,76001,76,602,FIJO,2026-09-01,4,3
2011,3,PIN0003,6023000004,CALI,VALLE DEL CAUCA,76001,76,602,FIJO,2026-09-01,3,4
2012,3,PIN0003,6023000005,CALI,VALLE DEL CAUCA,76001,76,602,FIJO,2026-09-01,2,5
2013,4,PIN0004,6054000001,BARRANQUILLA,ATLANTICO,08001,08,605,FIJO,2026-09-01,2,1
2014,4,PIN0004,6054000002,BARRANQUILLA,ATLANTICO,08001,08,605,FIJO,2026-09-01,1,2
2015,5,PIN0005,6015000001,BOGOTA,CUNDINAMARCA,11001,11,601,FIJO,2026-09-01,7,1
2016,5,PIN0005,6015000002,BOGOTA,CUNDINAMARCA,11001,11,601,FIJO,2026-09-01,6,2
2017,5,PIN0005,6015000003,BOGOTA,CUNDINAMARCA,11001,11,601,FIJO,2026-09-01,5,3
2018,5,PIN0005,6015000004,BOGOTA,CUNDINAMARCA,11001,11,601,FIJO,2026-09-01,4,4
'@ | Set-Content -Path C:\prueba_esencial\telefonos_esencial.csv -Encoding ascii

aws s3 cp C:\prueba_esencial\telefonos_esencial.csv s3://<BUCKET>/insumo/telefonos_esencial.csv
```

**B.2 Cargarlo con `COPY`** (en `recon_batch2`; antes, deja la tabla vacía: `DELETE FROM rec_stage.batch_cubo_telefono;`):

```sql
COPY rec_stage.batch_cubo_telefono
 (id_auto, id_buro_persona, cod_pin_persona, numero, ciudad, departamento, cod_dane_ciudad,
  cod_dane_departamento, indicativo, tipo, fecha_ultima_actualizacion, numero_de_entidades_reporta, orden_prioridad)
FROM 's3://<BUCKET>/insumo/telefonos_esencial.csv'
IAM_ROLE 'arn:aws:iam::<CUENTA>:role/RolUnloadRedshift'
DELIMITER ','
IGNOREHEADER 1
REGION '<REGION_DEL_CLUSTER>';
```

Qué hace cada parte ([COPY desde S3](https://docs.aws.amazon.com/redshift/latest/dg/copy-parameters-data-source-s3.html)):

| Parte | Qué significa |
|---|---|
| `COPY rec_stage.batch_cubo_telefono (columnas...)` | La tabla destino y, **en este orden**, las columnas que trae cada línea del archivo. Las que no nombras quedan en `NULL` o con su valor por omisión (p. ej. `filtro_h = 0`) |
| `FROM 's3://<BUCKET>/insumo/telefonos_esencial.csv'` | La **ruta S3**. Es un **prefijo**: `COPY` carga todos los objetos cuyo nombre empiece así. ⚠ Usa nombres que no sean prefijo de otros archivos |
| `IAM_ROLE '...'` | El rol que Redshift asume para leer ese bucket (necesita `s3:GetObject` y `s3:ListBucket`; ya los tiene el rol de 1.2.3) |
| `DELIMITER ','` | El carácter que separa columnas. Si omites `DELIMITER`, el valor por omisión es `\|` (barra vertical) |
| `IGNOREHEADER 1` | Salta la primera línea (los nombres de columna). No es la cabecera `HEADER` de `UNLOAD`: es su contraparte para cargar |
| `REGION '...'` | Obligatoria **solo** si el bucket está en otra región que el cluster. Si están en la misma, puedes quitarla |

Si tus archivos traen comillas alrededor de los textos, agrega la opción `CSV` (maneja comillas) o usa `REMOVEQUOTES`; no se mezclan con `DELIMITER` si usas `FIXEDWIDTH`.

✔ Resultado esperado: un mensaje parecido a `Load into table 'batch_cubo_telefono' completed, 18 record(s) loaded successfully.` (texto aproximado, no verificado) y `SELECT COUNT(*) FROM rec_stage.batch_cubo_telefono;` devuelve 18.

| Síntoma | Causa probable | Solución |
|---|---|---|
| `S3ServiceException: Access Denied` | El rol no tiene `s3:GetObject`/`s3:ListBucket` o no está asociado al cluster | Revisa 1.2.3 |
| `S3ServiceException ... bucket is in a different region` | Bucket y cluster en regiones distintas sin `REGION` | Agrega `REGION '<región del bucket>'` |
| `Load into table ... failed. Check 'stl_load_errors' system table for details.` | Un dato no cabe o no se puede convertir | `SELECT starttime, filename, line_number, colname, raw_field_value, err_reason FROM stl_load_errors ORDER BY starttime DESC LIMIT 5;` ([AWS](https://docs.aws.amazon.com/redshift/latest/dg/r_STL_LOAD_ERRORS.html)) |
| Se cargaron 0 filas | Prefijo equivocado | `aws s3 ls s3://<BUCKET>/insumo/` |

⚠ **Límite real de la Opción B:** el mapeo del CSV *real* de insumo hacia las tablas cubo **no está documentado en el workspace**; esa carga corresponde a procesos previos del pipeline mayor Reconocer (`README.md`). Por eso el archivo de arriba tiene **exactamente las columnas de la tabla cubo**. No mezcles A y B en la misma tabla (duplicarías filas).

### Paso 3. Ejecutar el proceso

**Qué se hace:** correr el proceso BATCH2 para la solicitud 90001. **Por qué dos caminos:** el orquestador se detiene hoy en el paso 9 (objetos que la migración aún no construye). El Camino A ejecuta los pasos 4 a 7 y 13 del orquestador **uno por uno**, cada `CALL` en su propia transacción: si uno falla, lo anterior queda guardado y reintentas solo ese.

**Variables para esta parte** (PowerShell):

```powershell
# PowerShell, en RS
$BUCKET = "s3://<BUCKET>/batch2/esencial/"                 # DEBE terminar en "/": el codigo concatena el nombre del archivo tal cual
$ROL    = "arn:aws:iam::<CUENTA>:role/RolUnloadRedshift"   # el rol de 1.2.3
$FCH    = "_" + (Get-Date -Format "yyyyMMddHHmmss")        # sufijo de fecha de los nombres de archivo, ej. _20261015120000
```

**Pre-vuelo (4 consultas, ejecutar en `recon_batch2`):**

```sql
SELECT COUNT(*) AS cubo_persona FROM rec_stage.batch_cubo_persona WHERE id_solicitud = 90001;  -- esperado 6
SELECT CAST('1' AS VARCHAR(5)) = 1 AS conversion_implicita;                                     -- esperado true
SELECT COUNT(*) AS personas_con_tipo                                                            -- esperado 6 (el JOIN de exportplano)
FROM rec_stage.batch_cubo_persona p
INNER JOIN rec_vista.persona v ON p.tipo_id = v.cod_tipo_ident_fte
WHERE p.id_solicitud = 90001;
SELECT db_collation();                                                                          -- esperado case_insensitive
```

La tercera consulta repite el `JOIN` exacto que hace `exportplano` entre una columna de texto y una numérica: si da 6 el `JOIN` funciona; si da error, aplica lo que dice 2.4 (detener y reportar).

Además, el script de 2.5 debe dar **31 filas `EXISTE`**.

#### Camino A. Por pasos (recomendado hoy)

**A.0 Obtener el número de lote.** `sp_batch2_genera_lote` tiene un parámetro `INOUT`: se le pasa un valor (cualquiera) y devuelve el lote.

```powershell
# PowerShell
psql -h $H -p 5439 -U $U -d $DB -c "CALL rec_mtdat.sp_batch2_genera_lote(0);"
psql -h $H -p 5439 -U $U -d $DB -t -A -c "SELECT lote FROM rec_mtdat.lote_id;"
```

La segunda línea imprime el lote (por ejemplo `1`). Guárdalo: `$LOTE = 1`. **[SUPUESTO SIN CONFIRMAR]** que un `CALL` de nivel superior acepte un literal en el parámetro `INOUT`; la documentación de `CALL` muestra un ejemplo que lo hace y devuelve una fila ([AWS](https://docs.aws.amazon.com/redshift/latest/dg/r_CALL_procedure.html)). Plan B: calcúlalo a mano (es lo que hace el procedure): `UPDATE rec_mtdat.lote_id SET lote = COALESCE(lote,0) + 1;` y luego `SELECT lote FROM rec_mtdat.lote_id;`.

**A.1 Ejecutar la secuencia.** Este bloque genera un archivo con las llamadas en el **orden real del orquestador** (`procedures\10_sp_batch2_proceso_batch2.sql`, líneas 98-142) y lo ejecuta deteniéndose en el primer error.

```powershell
# PowerShell. Define $LOTE (paso A.0) y las variables de arriba antes de ejecutar.
$P = "'PRUEBA_ESENCIAL'"     # nombre del proceso que quedara en la bitacora
$sql = @"
-- PROCESACUBOS (parametros: lote, proceso, PLANTILLA, SOLICITUD)
CALL rec_stage.sp_batch2_filtro_a($LOTE, $P, 9001, 90001);
CALL rec_stage.sp_batch2_filtro_b($LOTE, $P, 9001, 90001);
CALL rec_stage.sp_batch2_filtro_c($LOTE, $P, 9001, 90001);
CALL rec_stage.sp_batch2_filtro_d($LOTE, $P, 9001, 90001);
CALL rec_stage.sp_batch2_filtro_e($LOTE, $P, 9001, 90001, 'N');
CALL rec_stage.sp_batch2_filtro_e($LOTE, $P, 9001, 90001, 'J');
CALL rec_stage.sp_batch2_filtro_f($LOTE, $P, 9001, 90001);
CALL rec_stage.sp_batch2_filtro_g($LOTE, $P, 9001, 90001);
CALL rec_stage.sp_batch2_homologaciones($LOTE, $P, 9001, 90001);
CALL rec_stage.sp_batch2_filtro_i($LOTE, $P);
CALL rec_stage.sp_batch2_filtro_h($LOTE, $P, 9001, 90001);
CALL rec_stage.sp_batch2_filtro_j($LOTE, $P);
CALL rec_stage.sp_batch2_add_porc_insumo($LOTE, $P, 9001, 90001);
CALL rec_stage.sp_batch2_adicionar_incon($LOTE, $P, 9001, 90001);
-- CUBOEXPORT (parametros: SOLICITUD, PLANTILLA: ojo, al reves que los filtros)
CALL rec_stage.sp_batch2_cubo_export(90001, 9001);
-- EXPORTPLANO: mismo sufijo de fecha en las dos llamadas
CALL rec_stage.sp_batch2_exportplano(90001, 9001, 'CON DATOS DE UBICACION', '$BUCKET', '$ROL', '$FCH');
CALL rec_stage.sp_batch2_exportplano(90001, 9001, 'SIN DATOS DE UBICACION', '$BUCKET', '$ROL', '$FCH');
-- Cierre de la solicitud (estado = 'GENERADO')
CALL rec_stage.sp_batch2_actualiza_historia(90001, 9001);
"@
Set-Content -Path C:\prueba_esencial\ejecucion_por_pasos.sql -Value $sql -Encoding ascii
psql -h $H -p 5439 -U $U -d $DB -v ON_ERROR_STOP=1 -f C:\prueba_esencial\ejecucion_por_pasos.sql
```

Si usas Query Editor v2, copia las líneas `CALL` y reemplaza a mano `$LOTE`, `$P`, `$BUCKET`, `$ROL` y `$FCH` por sus valores; pulsa **Run** y observa cada resultado.

Qué hace cada llamada (en una línea):

| Llamada | Qué hace |
|---|---|
| `filtro_a` | Marca direcciones que contienen partículas a descartar (`batch_direccion_filtros`; vacía = no marca nada) |
| `filtro_b` | Marca registros más viejos que `no_entregado_x_meses` (con `'0'` no actúa) |
| `filtro_c` | Ejecuta SQL guardado de tipo `FILTRO-C`; no hay filas, no hace nada |
| `filtro_d` | Marca por campos requeridos (`requerido_campo = 'SI'`; con `'NO'` no actúa) |
| `filtro_e` ('N' y 'J') | Porcentajes por tipo de persona. **Lee `vu_persona` y `v_tipo_persona`**: sin el Script P aborta |
| `filtro_f` | Similitud contra el insumo. **Nombra las 4 funciones de similitud**: sin ellas aborta |
| **`filtro_g`** | **El recorte a `cantidad_max_campo` (3/3/2/2)**: marca con `filtro_g = 1` las filas que pasan del tope |
| `homologaciones` | Cambia valores según `batch_homologaciones` y normaliza `numero_id` a número sin ceros a la izquierda |
| `filtro_i` | Marca con `filtro_i = 1` las filas con `orden_prioridad` nulo |
| **`filtro_h`** | **Clasifica con/sin datos (`filtro_h` 0 o 1) y BORRA las filas excluidas** (las del recorte) de las personas que tienen otras filas válidas |
| `filtro_j` | Borra correos y celulares repetidos (depende de la collation case-insensitive) |
| `add_porc_insumo` | Sin subsección "Validacion" en la plantilla, termina de inmediato |
| `adicionar_incon` | Mueve a inconsistencias (`estado '06'`, `causal '04'`) las identificaciones válidas que no están en el cubo de personas |
| `cubo_export` | Pivote: de los cubos a las tablas `w_cubo_*` |
| `exportplano` (×2) | Arma el SELECT y hace 4 `UNLOAD` por llamada: PNPJ, PN, PJ e INCONSISTENCIA |
| `actualiza_historia` | Pone `estado = 'GENERADO'` en la solicitud |

✔ Resultado esperado: `psql` imprime `CALL` por cada llamada y, en las de `cubo_export` y `exportplano`, líneas `INFO: sp_batch2_cubo_export: pivote completado...` y `INFO: sp_batch2_exportplano: UNLOAD completado para id_solicitud=90001, seccion=...`. Ningún `ERROR`.

**Punto de control tras `adicionar_incon` y antes de exportar** (recomendado: aísla fallas del recorte): corre la consulta **5.2** de este documento. Si ya ves filas `EXCEDE`, no sigas: revisa `batch2_homologacion` y los códigos de `batch_salidas_campos`.

**Reglas para reintentar en el Camino A:**
- Un `CALL` que **falló** deshizo sus propios cambios: puedes corregir la causa y repetir **solo ese** `CALL`. Excepción: `TRUNCATE` dentro de `cubo_export` confirma lo anterior (transacción implícita) y no se deshace.
- Un `CALL` que **terminó bien** ya cambió los datos (`homologaciones`, `filtro_h`, `filtro_j`, `adicionar_incon` borran o reescriben filas). **No lo repitas** sin limpiar y recargar (paso 6).
- Para ejecutar solo una parte, copia las líneas que necesites del archivo `ejecucion_por_pasos.sql`.

#### Camino B. El `CALL` del orquestador (esperando error en el paso 9)

**Firma verificada** (`procedures\10_sp_batch2_proceso_batch2.sql`): `rec_stage.sp_batch2_proceso_batch2(p_id_solicitud BIGINT, p_s3_bucket_salida VARCHAR(500), p_iam_role VARCHAR(500))`. Sin parámetros de salida: **el lote no se devuelve**. Se ve en el mensaje `INFO` y en `rec_mtdat.lote_id`.

La sintaxis documentada de `CALL` es **posicional** (`CALL nombre(arg, arg, ...)`). La guía anterior usaba `p_id_solicitud => 90001`, que no aparece en la documentación de AWS; por eso aquí no se usa **[SUPUESTO SIN CONFIRMAR]** que `=>` funcione.

```powershell
# PowerShell, en RS
psql -h $H -p 5439 -U $U -d $DB -c "CALL rec_stage.sp_batch2_proceso_batch2(90001, '$BUCKET', '$ROL');"
```

Equivalente en SQL (para Query Editor v2):

```sql
CALL rec_stage.sp_batch2_proceso_batch2(
    90001,
    's3://<BUCKET>/batch2/esencial/',                      -- debe terminar en "/"
    'arn:aws:iam::<CUENTA>:role/RolUnloadRedshift');
```

El orquestador toma `id_plantilla` y `orientacion` de `batch_datos_generales` (si falta la fila, falla con "no existe configuracion en BATCH_DATOS_GENERALES"), genera el sufijo de fecha con la hora actual y ejecuta estos pasos:

| Paso | Llamada | Puede fallar hoy por |
|---|---|---|
| 1 | `sp_batch2_genera_lote` | Nada |
| 2 | `sp_batch2_plan_ejecucion_shell` | Con las 12 filas `ITERADOR` de `datos\01` ejecuta SQL que **nunca corrió en Redshift** **[SUPUESTO SIN CONFIRMAR]** (vistas con `TOP 200 ... ORDER BY` y vista sobre vista) |
| 3 | `sp_batch2_valida_archivos` | Solo avisa (`WARNING`) si no hay campos |
| 4 | Los 13 de PROCESACUBOS (a..j, homologaciones, add_porc, adicionar_incon) | **`FILTRO_E`** sin las vistas puente; **`FILTRO_F`** sin las 4 funciones |
| 5 | `sp_batch2_cubo_export` | "value too long" si un dato supera el largo de `w_cubo_*` |
| 6 y 7 | `sp_batch2_exportplano` CON y SIN datos | IAM o S3; `rec_vista.persona` vacía = CSV sin filas |
| 8 | `transpuesta` | Solo corre si `orientacion = 'OE_VERTICA'`; con `OE_HORIZON` se omite |
| **9** | **`sp_batch2_completitud_canal`** | **Falla: no existen `rec_stage.vstg_batch2_pnpj/_pj/_pn` ni `v_ba2_campos_salida`** |
| 10 | `sp_batch2_cantrepcanal_con` | `vu_persona`/`v_tipo_persona` (ya cubiertas) y `rec_stage.batch_cubo_persona11` (no existe) |
| 11 | `estadisticas` + `estadisticas_export` | `rec_stage.vstg_inconsis_pnpj` no existe |
| 12 | `exportlog` | `rec_vista.v_evento_entrega_dato` y `v_cod_entrega_dato` no existen |
| 13 | `actualiza_historia` | Solo cierra si `estado IS NULL AND fecha_generacion IS NULL` |

**Resultado esperado hoy:** error en el **paso 9**. Un error dentro de cualquier `sp_execstring_des` **aborta todo el `CALL` y deshace su transacción** (el procedure registra el error en `rec_mtdat.log_td_detalle` y lo relanza; AWS lo confirma para procedures no `NONATOMIC`: [Trapping errors](https://docs.aws.amazon.com/redshift/latest/dg/stored-procedure-trapping-errors.html)). **No** hay "el pipeline sigue y avisa": se detiene en el primer error.

**Qué queda después del error del paso 9:**
- Los CSV de los pasos 6 y 7 **ya están en S3** (`UNLOAD` escribe en S3 al instante; un `ROLLBACK` no los borra).
- La fila `ERROR: ...` queda en `rec_mtdat.log_td_detalle` (el *handler* corre en una transacción nueva y se confirma). Las filas de `rec_mtdat.log_td` posteriores al último `TRUNCATE` se deshacen. **[SUPUESTO SIN CONFIRMAR]** el detalle exacto del `COMMIT` implícito.
- Los cubos ya quedaron modificados por PROCESACUBOS (el `TRUNCATE` de `cubo_export` confirmó lo anterior).

**Plan B si el Camino B falla ANTES del paso 9:**

| Dónde falla | Causa probable | Qué hacer |
|---|---|---|
| Paso 2 | Las 12 filas `ITERADOR` ejecutan SQL no probado | Borra temporalmente las filas: `DELETE FROM rec_stage.pro_plan_ejecucion WHERE parte = 'ITERADOR';` y repite. Se recargan con `Invoke-Sql "datos\01_catalogos_motor.sql"`. Como el cubo aún no fue modificado, puedes repetir sin limpiar |
| Paso 4 | Mira la sentencia exacta en `log_td_detalle` (paso 4.4 de esta sección) | Corrige la causa. Si el error ocurre **antes** del `TRUNCATE` del paso 5, el `CALL` completo se deshace y los cubos vuelven a su estado inicial: puedes repetir sin limpiar. Ante la duda, limpia y recarga (paso 6) |
| Pasos 6 y 7 | IAM/S3 | Tabla de síntomas del paso 5.8 |

### Paso 4. Seguir la ejecución

**Qué se hace:** mirar qué va haciendo el proceso. **Por qué:** `CALL` bloquea tu terminal hasta terminar, y el procedimiento anota su avance.

**4.1 En la misma terminal:** `psql` muestra los mensajes `INFO` y `WARNING` (`RAISE INFO` en el código) apenas llegan, p. ej. `INFO: PROCESO_BATCH2: lote=7 para id_solicitud=90001`.

**4.2 Desde otra sesión: qué está corriendo ahora** ([`STV_RECENTS`](https://docs.aws.amazon.com/redshift/latest/dg/r_STV_RECENTS.html)):

```sql
SELECT status, starttime, duration, user_name, db_name, TRIM(query) AS consulta, pid
FROM stv_recents
WHERE status = 'Running';
```

`duration` está en microsegundos. ✔ Esperado: una fila `Running` con el `CALL` en curso; al terminar ya no aparece.

**4.3 Mensajes del procedure, incluso si el `CALL` fue cancelado** ([`SVL_STORED_PROC_MESSAGES`](https://docs.aws.amazon.com/redshift/latest/dg/r_SVL_STORED_PROC_MESSAGES.html)):

```sql
SELECT recordtime, loglevel_text, TRIM(message) AS mensaje, aborted
FROM svl_stored_proc_messages
WHERE querytext LIKE 'CALL rec_stage.sp_batch2%'
ORDER BY recordtime DESC
LIMIT 30;
```

`aborted = 1` significa que ese `CALL` se detuvo por error o cancelación. (AWS recomienda también la vista equivalente `SYS_PROCEDURE_MESSAGES`; esta guía no usa sus columnas porque no las verifiqué.)

**4.4 La bitácora del proceso** (`rec_mtdat.log_td_detalle`: una fila por sentencia ejecutada por `sp_execstring_des`):

```sql
-- Todo lo del lote, en orden. Reemplaza <LOTE>
SELECT fecha_hora, nombre_proceso, paso, descripcion_teradata_error
FROM rec_mtdat.log_td_detalle
WHERE lote = <LOTE>
ORDER BY fecha_hora;

-- Solo los errores, con el SQL que fallo
SELECT fecha_hora, nombre_proceso, paso, descripcion_teradata_error, LEFT(cadena, 400) AS sql_inicio
FROM rec_mtdat.log_td_detalle
WHERE lote = <LOTE>
  AND descripcion_teradata_error <> 'Finalizo Exitosamente'
ORDER BY fecha_hora;
```

Cómo leerla: `descripcion_teradata_error = 'Finalizo Exitosamente'` es una sentencia bien ejecutada; cualquier otro valor (p. ej. `ERROR: ...`) es un fallo. `paso` es la descripción del paso y `cadena` el SQL ejecutado. Solo el orquestador escribe además en `rec_mtdat.log_td` (`SELECT * FROM rec_mtdat.log_td WHERE lote = <LOTE> ORDER BY fecha_hora_inicio;`).

⚠ **Lo que no verás en tiempo real:** las filas de bitácora que un `CALL` en curso va insertando pertenecen a su transacción; desde otra sesión no se ven hasta que termine **[SUPUESTO SIN CONFIRMAR]** (aislamiento de transacciones). En el Camino A cada `CALL` termina y confirma, así que entre llamadas sí puedes consultarla. La fila de error sí persiste aunque el `CALL` aborte.

**Puntos de lectura:** el Camino A no escribe en `log_td_detalle` desde `cubo_export` ni `exportplano` (usan `EXECUTE` directo, sin pasar por `sp_execstring_des`): su evidencia es el mensaje `INFO`, la ausencia de `ERROR` y los archivos en S3.

### Paso 5. Verificación de resultados

Ejecuta 5.1 a 5.7 en orden. Si algo no coincide con "Esperado", ve a la tabla de síntomas de 5.8.

#### 5.1 La bitácora no tiene errores

```sql
-- Esperado: 0 filas (Camino A). Camino B: solo errores del paso 9 en adelante.
SELECT fecha_hora, nombre_proceso, paso, descripcion_teradata_error
FROM rec_mtdat.log_td_detalle
WHERE lote = <LOTE> AND descripcion_teradata_error <> 'Finalizo Exitosamente'
ORDER BY fecha_hora;
```

#### 5.2 Recorte a 3/3/2/2 en los cubos (el control principal del producto Esencial)

Cuenta cuántas filas **con datos** (`filtro_h = 0`) le quedan a cada persona por canal y compara con el tope. ⚠ Para direcciones esta es **la única** comprobación posible hoy: `w_cubo_direccion` admite solo 2.

```sql
SELECT canal, id_buro_persona, filas, tope,
       CASE WHEN filas <= tope THEN 'OK' ELSE 'EXCEDE' END AS resultado
FROM (
          SELECT 'direccion' AS canal, id_buro_persona, COUNT(*) AS filas, 3 AS tope
          FROM rec_stage.batch_cubo_direccion WHERE COALESCE(filtro_h,0) = 0 GROUP BY id_buro_persona
UNION ALL SELECT 'telefono', id_buro_persona, COUNT(*), 3
          FROM rec_stage.batch_cubo_telefono  WHERE COALESCE(filtro_h,0) = 0 GROUP BY id_buro_persona
UNION ALL SELECT 'celular',  id_buro_persona, COUNT(*), 2
          FROM rec_stage.batch_cubo_celular   WHERE COALESCE(filtro_h,0) = 0 GROUP BY id_buro_persona
UNION ALL SELECT 'correo',   id_buro_persona, COUNT(*), 2
          FROM rec_stage.batch_cubo_correo    WHERE COALESCE(filtro_h,0) = 0 GROUP BY id_buro_persona
) t
ORDER BY canal, id_buro_persona;
```

✔ Resultado esperado: **19 filas, todas `OK`**:

| Canal | Persona 1 | 2 | 3 | 4 | 5 | 6 |
|---|---|---|---|---|---|---|
| direccion (tope 3) | 3 | 3 | 1 | 2 | 3 | sin fila |
| telefono (tope 3) | 3 | 3 | **3** (había 5) | 2 | 3 | sin fila |
| celular (tope 2) | 2 | 2 | sin fila | 1 | 2 | sin fila |
| correo (tope 2) | 2 | 2 | 1 | 1 | 2 | sin fila |

Si ves `EXCEDE`, el recorte no ocurrió: revisa `batch2_homologacion` (5 filas), los `codigo_campo`/`grupo_campo` de `batch_salidas_campos` y que `filtro_g`/`filtro_h` se hayan ejecutado (los mensajes de 5.8).

#### 5.3 Clasificación de personas y de inconsistencias

```sql
SELECT id_buro_persona, tipo_id, numero_id, filtro_h,
       CASE WHEN COALESCE(filtro_h,0) = 0 THEN 'CON_DATOS' ELSE 'SIN_DATOS' END AS archivo
FROM rec_stage.batch_cubo_persona
WHERE id_solicitud = 90001
ORDER BY 1;
```

✔ Esperado: personas 1 a 5 → `CON_DATOS` (`filtro_h = 0`); persona 6 → `SIN_DATOS` (`filtro_h = 1`).

```sql
SELECT id_solicitud, id_plantilla, tipo_id, numero_id, estado, causal
FROM rec_stage.batch_identificaciones_incons
WHERE id_solicitud = 90001;
```

✔ Esperado: **1 fila**: `90001 | 9001 | 1 | 55500007 | 06 | 04`. Y `SELECT COUNT(*) FROM rec_stage.batch_identificaciones_validas WHERE id_solicitud = 90001;` devuelve **6** (la 7.ª se movió a inconsistencias).

#### 5.4 Las tablas pivote: columnas pobladas por canal, sin pasar el máximo

Cuenta los grupos `_00N` con valor por persona y comprueba que no exceden el máximo de Esencial.

```sql
SELECT canal, id_buro_persona, poblados, tope,
       CASE WHEN poblados <= tope THEN 'OK' ELSE 'EXCEDE' END AS resultado
FROM (
          SELECT 'telefono' AS canal, id_buro_persona, 3 AS tope,
                 (CASE WHEN numero_001 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN numero_002 IS NOT NULL THEN 1 ELSE 0 END
                + CASE WHEN numero_003 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN numero_004 IS NOT NULL THEN 1 ELSE 0 END
                + CASE WHEN numero_005 IS NOT NULL THEN 1 ELSE 0 END) AS poblados
          FROM rec_stage.w_cubo_telefono
UNION ALL SELECT 'direccion', id_buro_persona, 3,   -- tras el ajuste 3.1 agrega: + CASE WHEN direccion_003 IS NOT NULL THEN 1 ELSE 0 END
                 (CASE WHEN direccion_001 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN direccion_002 IS NOT NULL THEN 1 ELSE 0 END)
          FROM rec_stage.w_cubo_direccion
UNION ALL SELECT 'celular', id_buro_persona, 2,
                 (CASE WHEN numero_001 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN numero_002 IS NOT NULL THEN 1 ELSE 0 END)
          FROM rec_stage.w_cubo_celular
UNION ALL SELECT 'correo', id_buro_persona, 2,
                 (CASE WHEN correo_001 IS NOT NULL THEN 1 ELSE 0 END + CASE WHEN correo_002 IS NOT NULL THEN 1 ELSE 0 END)
          FROM rec_stage.w_cubo_correo
) t
ORDER BY canal, id_buro_persona;
```

✔ Resultado esperado (código de hoy, **19 filas, todas `OK`**): teléfono `3,3,3,2,3` (personas 1 a 5); **dirección `2,2,1,2,2`** (las personas 1, 2 y 5 tienen 3 en el cubo pero el pivote solo guarda 2: ese es el gap 3.1); celular `2,2,1,2` (personas 1, 2, 4 y 5); correo `2,2,1,1,2`. Tras el ajuste 3.1 la dirección debe dar `3,3,1,2,3`.

Cuántas personas hay en cada pivote: `SELECT COUNT(*) FROM rec_stage.w_cubo_telefono;` (5), `w_cubo_direccion` (5), `w_cubo_celular` (4), `w_cubo_correo` (5), `w_cubo_ciiu` (2).

#### 5.5 Archivos en S3

```powershell
# PowerShell
aws s3 ls $BUCKET
```

**Nombres reales.** El código pide a `UNLOAD` el prefijo `<bucket><SECCION>_<solicitud><sufijo-fecha>.CSV` y, como usa `PARALLEL OFF`, `UNLOAD` agrega **`000`** al final (`001`, `002`... solo si un archivo pasa de 6,2 GB) ([AWS](https://docs.aws.amazon.com/redshift/latest/dg/r_UNLOAD.html)). La guía anterior y `VERIFICACION.md` hablan de `0000_part_00`: eso corresponde a `PARALLEL ON`, no a lo que usa este código (hallazgo H16).

Con `$FCH = _20261015120000` esperas **7 prefijos de datos**, no 3 (cada `exportplano` hace 4 `UNLOAD`: PNPJ, PN, PJ e INCONSISTENCIA, y `INCONSISTENCIA` se repite con el mismo nombre en la llamada de "SIN DATOS"; `ALLOWOVERWRITE` la sobrescribe):

| Archivo en S3 | Filas de datos esperadas (código de hoy) | Quiénes |
|---|---|---|
| `CON_DATOS_90001_20261015120000.CSV000` | 5 | personas 1 a 5 |
| `CON_DATOS_90001_PN_20261015120000.CSV000` | 4 | personas 1, 2, 3 y 4 (tipos 1 y 4) |
| `CON_DATOS_90001_PJ_20261015120000.CSV000` | 1 | persona 5 (tipo 2) |
| `SIN_DATOS_90001_20261015120000.CSV000` | 1 | persona 6 |
| `SIN_DATOS_90001_PN_20261015120000.CSV000` | 1 | persona 6 |
| `SIN_DATOS_90001_PJ_20261015120000.CSV000` | 0 | no hay jurídicas sin datos |
| `INCONSISTENCIA_90001_20261015120000.CSV000` | 1 | identificación `55500007` |

(+ 1 línea de cabecera en cada archivo, porque `UNLOAD` usa `HEADER`.) **[SUPUESTO SIN CONFIRMAR]:** cuando la consulta no devuelve filas (`SIN_DATOS_..._PJ_`), `UNLOAD` puede no crear el archivo o crear uno solo con la cabecera; no lo comprobé.

Los archivos `ALERTAS-90001_..._estadisticas_000` y `BATCH_SOLICITUD_BATCH.ARCHIVO_LOG_W000` **no aparecen** hoy: dependen de los pasos 11 y 12, que fallan por objetos faltantes.

**Bajarlos y abrirlos:**

```powershell
# PowerShell
New-Item -ItemType Directory -Force -Path C:\prueba_esencial\salida | Out-Null
aws s3 cp $BUCKET C:\prueba_esencial\salida\ --recursive
# Quita el sufijo 000 para poder abrirlos como CSV
Get-ChildItem C:\prueba_esencial\salida | Rename-Item -NewName { $_.Name -replace '000$','' }
# Cuantas lineas tiene cada uno (restale 1 de cabecera para saber las filas de datos)
Get-ChildItem C:\prueba_esencial\salida | ForEach-Object { "{0}: {1} lineas" -f $_.Name, @(Get-Content $_.FullName).Count }
# Ver el contenido de forma legible (separador ;)
Import-Csv -Delimiter ';' -Path "C:\prueba_esencial\salida\CON_DATOS_90001$($FCH).CSV" | Format-List
```

Para abrirlo en Excel, no hagas doble clic: usa **Datos > Obtener datos > Desde texto/CSV** y elige el delimitador `;` y la codificación UTF-8 (`UNLOAD` escribe UTF-8).

#### 5.6 Contenido de cada archivo contra lo esperado

**Cabeceras** (nombres de columna; salen del `SELECT` fijo de `exportplano`): `CON_DATOS` trae **34** columnas (`Tipo id 001`, `Numero id 001`, `Primer apellido 001`, ..., `Actividad economica 001`, y luego `Ciudad 001`, ... `Numero de entidades reporta 001` de teléfono, `Ciudad 001b`, ... `Numero de entidades reporta 001b` de dirección, `Correo 001` y `Numero 001b`); `SIN_DATOS` trae **14** columnas (hasta `Actividad economica 001`); `INCONSISTENCIA` trae **11** (`ID_SOLICITUD`, `ID_PLANTILLA`, `TIPO_ID`, `NUMERO_ID`, `NOMBRE_COMPLETO`, `NOMBRE_ENTIDAD`, `FECHA_EXPEDICION`, `CIUDAD_EXPEDICION`, `DEPARTAMENTO_EXPEDICION`, `ESTADO`, `CAUSAL`).

**Línea esperada de la persona 1 en `CON_DATOS`** (calculada a mano leyendo el código, no ejecutada). Fíjate en que cada canal muestra **solo su primer elemento**, el de menor `orden_prioridad`:

```text
1;10000001;PRUEBA;UNO;ANA;MARIA;ANA MARIA PRUEBA UNO;15/03/2005;BOGOTA;CUNDINAMARCA;F;26-35;6201;ACTIVIDADES DE DESARROLLO DE SISTEMAS INFORMATICOS;BOGOTA;CUNDINAMARCA;11001;11;6011000001;FIJO;01/09/2026;5;BOGOTA;CUNDINAMARCA;11001;11;CL 10 # 1-01;RESIDENCIA;URBANA;3;01/09/2026;5;p1.a@example.com;
```

La última columna (`Numero 001b`) sale **vacía** porque `exportplano` la toma de `w_cubo_correo.numero_001`, que en estos datos es `NULL` (hallazgo H5). `NULL` se escribe como campo vacío. Para la persona 3 (sin CIIU ni celular) salen vacías las dos columnas de CIIU. Las fechas salen `DD/MM/YYYY` porque el pivote las convierte con `TO_CHAR`.

**Reglas de contenido que debes comprobar:**

- No hay valores enmascarados (`XXXX`): si los hay, `prueba` no era `'SV'`.
- Cada persona aparece **una sola vez** por archivo (filas repetidas = `rec_vista.persona` con más de una fila por tipo).
- Las columnas de teléfono, dirección y correo traen el **primer** elemento de la persona (menor `orden_prioridad`).
- **Nivel 2 (después de 1.A y 1.B):** persona 1 con 3 direcciones, 3 teléfonos, 2 celulares y 2 correos poblados; persona 2 igual; persona 3 con 1 dirección, 3 teléfonos, 0 celulares y 1 correo; persona 4 con 2/2/1/1; persona 5 con 3/3/2/2; ninguna con un 4.º bloque. Es decir, "según disponibilidad" y nunca por encima del máximo. Una vez fijados los alias de columna nuevos, cuenta con `Import-Csv` las columnas de cada canal con valor por persona.

#### 5.7 Comparación con una muestra real de Teradata

Se buscó en el workspace: `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Salidas\` tiene `CON_DATOS_4421_20240902100353.CSV` (y `.ESQUEMA`), `SIN_DATOS_4421_...`, `INCONSISTENCIA_4421_...` y `ALERTAS-4421_...`. **Los `.CSV` de muestra contienen solo la cabecera** (sin filas de datos) y corresponden a una plantilla 1/1/1/1 (34 columnas). **No existe en el workspace ninguna muestra con la configuración 3/3/2/2.** Por eso la comparación posible hoy es de **estructura**, no de datos:

```powershell
# PowerShell. Compara posicion por posicion los nombres de columna (ignora espacios y el sufijo b)
$ref = ((Get-Content "d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Salidas\CON_DATOS_4421_20240902100353.CSV" -TotalCount 1) -split ';') | ForEach-Object { $_.Trim() }
$red = ((Get-Content "C:\prueba_esencial\salida\CON_DATOS_90001$($FCH).CSV" -TotalCount 1) -split ';') | ForEach-Object { ($_.Trim()) -replace '(\d{3})b$','$1' }
"Columnas Teradata: $($ref.Count)   Redshift: $($red.Count)"
for ($i = 0; $i -lt [Math]::Max($ref.Count, $red.Count); $i++) {
    if ($ref[$i] -ne $red[$i]) { "Posicion $($i+1): Teradata='$($ref[$i])'  Redshift='$($red[$i])'" }
}
```

✔ Esperado (código de hoy): `34` y `34` columnas y **ninguna diferencia** de nombre tras normalizar. Aun así hay diferencias que el script no ve: el separador del encabezado de Teradata es `; ` (punto y coma **con espacio**, se ve en el `.CSV` de muestra) mientras `UNLOAD DELIMITER ';'` no agrega espacio; y la última columna `Numero 001` del layout de Teradata es el celular mientras Redshift escribe `correo.numero_001` (H5).

Para una regresión real de **datos** hace falta que alguien entregue una salida de Teradata de una plantilla 3/3/2/2 con las mismas personas: queda como pendiente.

#### 5.8 Síntoma, causa probable y solución

| Síntoma | Causa probable | Solución |
|---|---|---|
| `S3ServiceException: Access Denied` o `Unable to assume role` en `exportplano` | El rol no está asociado al cluster, o no tiene permisos de `PutObject`/`ListBucket` sobre ese bucket, o el usuario no puede usarlo | Revisa `IamRoles` del cluster (1.2.3), el `Resource` de la política y `GRANT ASSUMEROLE ... FOR UNLOAD` |
| `bucket ... is in a different region` | Bucket y cluster en regiones distintas (el código no usa `REGION`) | Crea el bucket en la región del cluster |
| `NoSuchBucket` | El nombre del bucket está mal | Corrige `$BUCKET` (debe terminar en `/`) |
| Error en `filtro_f`: la función `rec_vista.f_porc_similitud` (u otra) **no existe**, o un error de Lambda en `log_td_detalle` | Falta ejecutar `ddl\08` con los marcadores reemplazados, o la Lambda/rol no existe (el texto exacto del error no se verificó) | 1.2.4 a 1.2.8 y V5/V9 |
| `relation "rec_vista.vu_persona" does not exist` en `filtro_e` | Falta el Script P | Ejecútalo (2.4) |
| `relation "rec_stage.vstg_batch2_pnpj" does not exist` (Camino B, paso 9) | **Esperado hoy**: objeto que la migración aún no construye | No es falla tuya; documenta y sigue con 5.2 a 5.7 |
| `FILTRO_J` nunca borra duplicados o `Query with different collations is not supported yet` | Base sin `CASE_INSENSITIVE`, o mezcla de columnas con collation distinta | Verifica `db_collation()` (V7); recrea la base (D1) |
| `value too long for type character varying(N)` en `cubo_export` | Un dato supera el largo de las columnas `w_cubo_*` | Respeta los largos de 2.6.1 |
| `SELECT-INTO returned more than one row` | Dos filas en `batch_salidas_campos` para el mismo `codigo_campo` o duplicados en `batch_datos_generales` | Deja una sola fila por `codigo_campo` y por (solicitud, plantilla) |
| `no existe configuracion en BATCH_DATOS_GENERALES para id_solicitud=...` | Falta el Script C.2 (o la solicitud no es 90001) | Carga C.2 |
| Los CSV traen solo cabecera | `rec_vista.persona` vacía, o el `JOIN` por tipo no encaja (`'1'` contra `1`), o no hay personas con `id_solicitud = 90001` e `id_plantilla = 9001` | Revisa 2.4 y 2.6; `SELECT COUNT(*) FROM rec_vista.persona;` |
| Filas repetidas en los CSV | Más de una fila por tipo en `rec_vista.persona` | Deja exactamente una por tipo |
| Datos reemplazados por `X` | `prueba` distinto de `'SV'` | `UPDATE rec_stage.batch_solicitud_batch SET prueba = 'SV' WHERE id_solicitud = 90001;` y recarga los cubos |
| Persona 1 con 4 teléfonos en `w_cubo_telefono` (5.4 da `EXCEDE`) | No hubo recorte: `batch2_homologacion` vacía, o `codigo_campo` distinto de `DT_NUM` | Revisa 2.6.1 y repite desde el paso 6 |
| `permission denied for relation ...` | El usuario no tiene permisos sobre esa tabla | `GRANT` o usa el dueño |
| `CALL` falla con `=>` | Notación nombrada no documentada | Usa argumentos posicionales |
| `procedure ... does not exist` | Argumentos de tipo o cantidad distintos a la firma | Compara con la firma (3 argumentos para el orquestador, 6 para `exportplano`) |

#### 5.9 Firmas verificadas de los procedures que se llaman a mano

Obtenidas de `procedures\*.sql`. **El orden de parámetros cambia entre familias**:

| Procedure | Parámetros (en orden) |
|---|---|
| `sp_batch2_filtro_a/_b/_c/_d/_f/_g/_h`, `sp_batch2_homologaciones`, `sp_batch2_add_porc_insumo`, `sp_batch2_adicionar_incon` | `(p_lote BIGINT, p_nombre_proceso VARCHAR(100), p_id_plantilla BIGINT, p_id_solicitud BIGINT)`: **plantilla antes que solicitud** |
| `sp_batch2_filtro_e` | los 4 anteriores + `p_tipo_persona VARCHAR(1)` (`'N'` o `'J'`) |
| `sp_batch2_filtro_i`, `sp_batch2_filtro_j` | `(p_lote BIGINT, p_nombre_proceso VARCHAR(100))` |
| `sp_batch2_cubo_export` | `(p_id_solicitud BIGINT, p_id_plantilla BIGINT)`: **solicitud antes que plantilla** |
| `sp_batch2_exportplano` | `(p_id_solicitud BIGINT, p_id_plantilla BIGINT, p_nombre_seccion VARCHAR(100), p_s3_bucket_salida VARCHAR(500), p_iam_role VARCHAR(500), p_fch_archivo VARCHAR(20))` |
| `sp_batch2_actualiza_historia` | `(p_id_solicitud BIGINT, p_id_plantilla BIGINT)` |
| `sp_batch2_valida_archivos` (informativo, opcional) | `(p_id_solicitud BIGINT, p_id_plantilla BIGINT, INOUT p_numero_separadores INTEGER, INOUT p_ancho_fijo INTEGER)`. Ejemplo: `CALL rec_stage.sp_batch2_valida_archivos(90001, 9001, 0, 0);` |
| `sp_batch2_genera_lote` | `(INOUT p_lote BIGINT)` |
| `sp_batch2_proceso_batch2` | `(p_id_solicitud BIGINT, p_s3_bucket_salida VARCHAR(500), p_iam_role VARCHAR(500))` |

### Paso 6. Limpiar los datos de prueba y repetir

**Qué se hace:** borrar todo lo de la solicitud 90001 y las filas de los cubos. **Por qué:** el pipeline modifica y borra filas (`HOMOLOGACIONES` reescribe `numero_id`, `FILTRO_H` y `FILTRO_J` borran, `ADICIONAR_INCON` mueve y borra) y `actualiza_historia` solo cierra si `estado IS NULL`. No se puede repetir sobre los mismos datos.

```sql
-- Se ejecuta en recon_batch2. Los hijos primero (cubos) y luego lo demas.
DELETE FROM rec_stage.batch_cubo_direccion   WHERE id_auto BETWEEN 1000 AND 1999;
DELETE FROM rec_stage.batch_cubo_telefono    WHERE id_auto BETWEEN 2000 AND 2999;
DELETE FROM rec_stage.batch_cubo_celular     WHERE id_auto BETWEEN 3000 AND 3999;
DELETE FROM rec_stage.batch_cubo_correo      WHERE id_auto BETWEEN 4000 AND 4999;
DELETE FROM rec_stage.batch_cubo_ciiu        WHERE id_auto BETWEEN 5000 AND 5999;
DELETE FROM rec_stage.batch_cubo_persona     WHERE id_solicitud = 90001;
DELETE FROM rec_stage.batch_identificaciones_validas WHERE id_solicitud = 90001;
DELETE FROM rec_stage.batch_identificaciones_incons  WHERE id_solicitud = 90001;
DELETE FROM rec_stage.batch_salidas_campos   WHERE id_solicitud = 90001;
DELETE FROM rec_stage.batch_datos_generales  WHERE id_solicitud = 90001;
DELETE FROM rec_stage.batch_solicitud_batch  WHERE id_solicitud = 90001;
-- Solo si TU cargaste las 5 filas de ejemplo (no borres un catalogo real):
DELETE FROM rec_stage.batch2_homologacion
 WHERE id_sequencia BETWEEN 1 AND 5
   AND codigo_campo IN ('DT_NUM','DD_DIR','DC_NUMERO','CE_CORREO','DB_CIIU');
```

Las tablas `w_cubo_*` y las de trabajo (`bacth_fg_1`, `pro_batch2_filtro_e`...) no hace falta limpiarlas: `cubo_export` las vacía y los filtros las borran y recrean. **Deja la bitácora** (`log_td_detalle`): es la evidencia de cada corrida (cada una tiene su `lote`). Las filas de `rec_vista.persona` y las dos vistas puente pueden quedarse.

**Archivos de S3 de la corrida anterior** (opcional): `aws s3 rm $BUCKET --recursive` ⚠ borra **todo** lo que cuelgue de ese prefijo y no se puede deshacer (salvo que el bucket tenga versionado). Revisa antes con `aws s3 ls $BUCKET`.

**Para repetir:** vuelve al paso 2 (carga con `datos_esencial.sql`; el Script P no se repite), define un `$FCH` nuevo y repite el paso 3. Si solo quieres re-ejecutar sin borrar la configuración, basta con: `UPDATE rec_stage.batch_solicitud_batch SET estado = NULL, fecha_generacion = NULL WHERE id_solicitud = 90001;`, **borrar y recargar los cubos y las identificaciones válidas** (Script D).

✔ Resultado esperado: la verificación de 2.6.3 sobre las tablas de la solicitud devuelve 0 filas antes de recargar.

### Paso 7. Criterio de éxito (checklist con casillas)

**Nivel 0. Despliegue**
- [ ] V1 a V9 de la sección 1.5 dan lo esperado (4 esquemas, 43 tablas, 34 procedures, 8 funciones, catálogos 18/18/12, collation `case_insensitive`).
- [ ] El script de 2.5 da 31 filas `EXISTE`.

**Nivel 1. Mínimo aceptable hoy (sin los ajustes 3.1 y 3.2)**
- [ ] El Camino A terminó sin ningún `ERROR` y `log_td_detalle` no tiene filas distintas de `Finalizo Exitosamente` (5.1).
- [ ] 5.2: las 19 filas dicen `OK` (recorte a 3/3/2/2 en los cubos).
- [ ] 5.3: personas 1 a 5 con datos, persona 6 sin datos, 1 inconsistencia `06 | 04`.
- [ ] 5.4: las 19 filas dicen `OK` (en dirección con el límite de 2 del pivote, declarado).
- [ ] 5.5: están los 7 archivos de datos con los nombres `...CSV000` y las filas de la tabla (5/4/1/1/1/0/1).
- [ ] 5.6: cabeceras de 34, 14 y 11 columnas; la línea de la persona 1 coincide; sin valores `XXXX`; sin personas repetidas.
- [ ] 5.7: 34 columnas contra 34 de la muestra de Teradata, sin diferencias de nombre tras normalizar.
- [ ] Camino B (si lo corriste): el único error es el del paso 9, y los CSV ya estaban en S3.

**Nivel 2. Esencial completo (después de 1.A y 1.B)**
- [ ] `w_cubo_direccion` tiene `direccion_003` y 5.4 da dirección `3,3,1,2,3`.
- [ ] El CSV `CON_DATOS` trae, por persona, los bloques poblados: persona 1 `3/3/2/2`, persona 2 `3/3/2/2`, persona 3 `1/3/0/1`, persona 4 `2/2/1/1`, persona 5 `3/3/2/2` (direcciones/teléfonos/celulares/correos); ninguna con un bloque por encima del máximo.
- [ ] El celular sale en el CSV y la columna final ya no depende de `correo.numero_001` (H5).

**Nivel 3. Regresión contra Teradata**
- [ ] Existe una salida real de Teradata de una plantilla 3/3/2/2 para las mismas personas y se compara columna por columna. **Pendiente: no existe en el workspace.**

**Registro de la prueba (anota al terminar):** fecha, quién la ejecutó, base, lote, prefijo de S3 y el resultado de cada casilla.

---

## 4. Anexos

### 4.A Checklist resumido final (coherente con el paso 7)

**Antes de ejecutar**
- [ ] Cluster `available`, puerto 5439 alcanzable, usuario con permisos (1.2).
- [ ] Bucket en la misma región del cluster; rol IAM con S3 (y Lambda) **asociado al cluster** (1.2.2 y 1.2.3).
- [ ] Lambda `udf_similitud` desplegada y `ddl\08` generado sin marcadores `<...>` (1.2.4 a 1.2.8).
- [ ] Base `recon_batch2` creada con `COLLATE CASE_INSENSITIVE` y conexión hecha **a esa base** (D1).
- [ ] Despliegue D2 a D6 sin errores; V1 a V9 correctos (1.5).
- [ ] Decidido el nivel de la prueba: **Nivel 1** (mínima aceptable) o **Nivel 2** (con los ajustes 3.1 y 3.2 hechos por desarrollo) (paso 1).
- [ ] Script P, Script C y Script D cargados; verificación 2.6.3 correcta; script de 2.5 con 31 `EXISTE`.
- [ ] Pre-chequeo `CAST('1' AS VARCHAR(5)) = 1` en `true`.

**Durante**
- [ ] `$BUCKET` termina en `/`; el mismo `$FCH` en las dos llamadas a `exportplano`.
- [ ] Camino A: si un `CALL` falla, se corrige la causa y se repite solo ese; los que terminaron bien no se repiten.
- [ ] Camino B: se espera el error del paso 9 y se confirma que los CSV ya estaban en S3.

**Después**
- [ ] Verificaciones 5.1 a 5.7 y casillas del paso 7 marcadas.
- [ ] Limpieza del paso 6 antes de repetir; no repetir sobre datos ya procesados.
- [ ] Hallazgos nuevos anotados (no corregidos) en 4.C.
- [ ] `Remove-Item Env:PGPASSWORD` al terminar.

### 4.B Fuera de alcance de esta guía

- Cambiar código (SQL, procedures, DDL): esta guía solo documenta; los ajustes 3.1 y 3.2 los hace quien mantiene el repositorio.
- Layout 100 % dinámico de `exportplano` desde `batch_salidas_campos` y construir `v_ba2_campos_salida` y `vstg_batch2_*` (trabajo F2-5).
- Pasos 9 a 12 del orquestador: `completitud_canal`, `cantrepcanal_con`, `estadisticas` (archivo `ALERTAS`) y `exportlog` (archivo de log); faltan **objetos y datos**, no código.
- Carga masiva del CSV de insumo *real* hacia las tablas cubo (procesos previos del pipeline mayor Reconocer; el mapeo no está en el workspace).
- Las filas **reales** de catálogos pendientes: `batch2_homologacion`, `batch_motor_log` (`FILTRO-C`, `CANT_REP_CANAL_CONTACTO`), `pro_batch2_filtros_estadisticas`, `batch2_shells_config` (ver `Bitacora_Batch_Teradata.md`).
- El paso de renombrado de archivos en S3 (Lambda o Glue) si el consumidor final exige el nombre exacto sin el sufijo `000` de `UNLOAD`.
- Confirmar contra Teradata que `editdistance_u` equivale a Damerau-Levenshtein OSA (`casos_validacion_teradata.sql`).
- Pruebas de carga y volumen (esta guía es una prueba funcional con 6 personas).
- Endurecer permisos para producción (roles separados, mínimo privilegio).

### 4.C Hallazgos de código y documentación (documentados, NO corregidos)

| # | Hallazgo | Dónde |
|---|---|---|
| H1 | El orquestador cae en el paso 9 (y luego en 10, 11 y 12). Su cabecera dice que esos pasos "fallan o no hacen nada"; en realidad **fallan y abortan todo el `CALL`** | `procedures\10_sp_batch2_proceso_batch2.sql`, cabecera (~líneas 34-45) |
| H2 | `FILTRO_E` exige `rec_vista.vu_persona` y `v_tipo_persona`, que no existen: aborta **antes** del export. La guía anterior decía que "no bloquea" | `procedures\08`, ~731-732; `ddl\07`, ~203-209 |
| H3 | `exportplano` hace `INNER JOIN rec_vista.persona` (tabla sin filas, y el `JOIN` es solo por tipo). Ni el README ni la guía anterior lo mencionaban | `procedures\04`, ~107; `ddl\06`, ~31 |
| H4 | El comentario de cabecera de `exportplano` afirma que arma el `SELECT` desde `batch_salidas_campos` y `batch2_homologacion`; el código **no lo hace** (ni nombra `w_cubo_celular`) | `procedures\04`, líneas ~16-26 |
| H5 | La columna final `"Numero 001b"` sale de `w_cubo_correo.numero_001` (columna "compat"), mientras `DC_NUMERO` es el celular en el resto del código y en la muestra de Teradata | `procedures\04`, ~104; `ddl\03`, ~206 |
| H6 | `vstg_inconsis_pnpj` se atribuye a `CUBOEXPORT_111.BTQ`; está en `EXPORTPLANO_111.BTQ` (líneas 1134 y 1225) | `ddl\10`, ~72-77; `procedures\09`, ~129 |
| H7 | Comentario obsoleto: `estadisticas` "sigue como placeholder" | `procedures\09b`, ~52-54 |
| H8 | `rec_stage.batch2_cantidad_reporte_canal` no la referencia ningún procedure | `ddl\05`, ~219 |
| H9 | Los nombres de archivo y el separador `;` están fijos en el código; 12 columnas de `batch_datos_generales` son decorativas (2.6.1) | `procedures\04`, `10`; `ddl\02`, ~26-45 |
| H10 | `exportplano` genera PN y PJ siempre (aunque `archivos_pn_pj = '0'`) y `INCONSISTENCIA` dos veces | `procedures\04`, ~135-168; `10`, ~141-142 |
| H11 | Las `w_cubo_*` son más angostas que los cubos origen: un dato largo hace fallar `cubo_export` | `ddl\04` frente a `ddl\03` |
| H12 | `CREATE TABLE IF NOT EXISTS` no actualiza una tabla ya creada (relevante para `_003`) | `ddl\04` |
| H13 | El bloque de enmascaramiento (L2) se dispara con cualquier `prueba` distinto de `'SV'` (incluye `'S'`) y no es idempotente: intercambia apellidos en cada corrida | `procedures\08`, ~2154-2270 |
| H14 | El pipeline modifica y borra los cubos en sitio: no se puede relanzar sin recargar | `procedures\08` (`FILTRO_H`, `FILTRO_J`, `HOMOLOGACIONES`) |
| H15 | `filtro_g` contamina `filtro_g` entre cubos si `id_auto` coincide (bug del original replicado) | `procedures\08`, ~1744-1790 |
| H16 | `VERIFICACION.md` (punto 3) y la cabecera de `exportplano` mencionan el sufijo `0000_part_00` (de `PARALLEL ON`); con `PARALLEL OFF`, que usa el código, es `000` | `VERIFICACION.md`, 3; `procedures\04`, cabecera |
| H17 | La guía anterior usaba `requerido_campo = 'N'`; solo `'SI'` tiene efecto | guía anterior 4.3 |
| H18 | La cabecera de la muestra de Teradata separa con `; ` (punto y coma con espacio) y repite nombres de columna; `exportplano` escribe `;` sin espacio y usa el sufijo `b` para no repetir | `Salidas\CON_DATOS_4421_20240902100353.CSV` frente a `procedures\04` |
| H19 | El ejemplo de `CALL` del `README.md` usa notación nombrada `=>`, que la sintaxis documentada de AWS no incluye | `README.md`, sección "Cómo ejecutar el pipeline completo" |
| H20 | Los scripts y el `README.md` usan `\i`, un metacomando de `psql` que no funciona en Query Editor v2 ni DBeaver | `README.md`; ver 1.3 |

**Correcciones que esta versión hace a la guía anterior:** consulta de procedures inválida (V4 la reemplaza); "10 `sp_batch2_*`" (son 34 procedures: 31 `sp_batch2_*` y 3 auxiliares); `CALL` con `=>`; `prueba = 'S'`; códigos de campo `TEL/DIR/CEL/MAI`; textos que hablaban de "placeholders" y de `ddl\01..08` (hoy son `ddl\01..10` y no hay placeholders); sufijo `0000_part_00`; afirmación de que FILTRO_E "no bloquea"; falta de `rec_vista.persona`; atribución de `vstg_inconsis_pnpj`.

### 4.D Tabla de referencias (ruta de cada archivo mencionado)

| Archivo | Ruta absoluta |
|---|---|
| Guía (este archivo) | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift\GUIA_PRUEBA_PRODUCTO_ESENCIAL.md` |
| README de la migración | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift\README.md` |
| Verificación de sintaxis | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift\VERIFICACION.md` |
| Notas de trabajo (inventario verificado) | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift\.agents\tasks\inventario_dependencias.md` |
| README del DDL | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift\ddl\00_README.md` |
| DDL 01 esquemas | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift\ddl\01_schemas.sql` |
| DDL 02 configuración | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift\ddl\02_tablas_configuracion.sql` |
| DDL 03 cubos | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift\ddl\03_tablas_cubos.sql` |
| DDL 04 pivote | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift\ddl\04_tablas_pivote.sql` |
| DDL 05 control | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift\ddl\05_tablas_control.sql` |
| DDL 06 dimensión | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift\ddl\06_vistas_dimension.sql` |
| DDL 07 dependencias | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift\ddl\07_tablas_dependencias_sps.sql` |
| DDL 08 funciones | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift\ddl\08_funciones_udf.sql` |
| DDL 09 vista | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift\ddl\09_vistas_dependencias_sps.sql` |
| DDL 10 trabajo | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift\ddl\10_tablas_trabajo_f2_4.sql` |
| Procedure 01 lote | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift\procedures\01_sp_batch2_genera_lote.sql` |
| Procedure 02 bitácora | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift\procedures\02_sp_batch2_log_helpers.sql` |
| Procedure 03 pivote | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift\procedures\03_sp_batch2_cubo_export.sql` |
| Procedure 04 exportplano | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift\procedures\04_sp_batch2_exportplano.sql` |
| Procedure 05 exportlog | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift\procedures\05_sp_batch2_exportlog.sql` |
| Procedure 06 historia | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift\procedures\06_sp_batch2_actualiza_historia.sql` |
| Procedure 07 valida | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift\procedures\07_sp_batch2_valida_archivos.sql` |
| Procedure 08 filtros | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift\procedures\08_sp_batch2_procesacubos.sql` |
| Procedure 09b motores | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift\procedures\09b_sp_batch2_motores_sql.sql` |
| Procedure 09 otros | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift\procedures\09_sp_batch2_otros.sql` |
| Procedure 10 orquestador | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift\procedures\10_sp_batch2_proceso_batch2.sql` |
| Catálogos | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift\datos\01_catalogos_motor.sql` |
| Lambda: código | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift\lambda\udf_similitud\lambda_function.py` |
| Lambda: pruebas | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift\lambda\udf_similitud\test_lambda_function.py` |
| Lambda: casos en Redshift | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift\lambda\udf_similitud\casos_validacion_redshift.sql` |
| Lambda: casos en Teradata | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Redshift\lambda\udf_similitud\casos_validacion_teradata.sql` |
| DDL original de Teradata | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\DDL.sql` |
| Stored procedures originales | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Sps_Batch.sql` |
| Orquestador original | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\P0033_PROCESO_BATCH2.BTQ` |
| CUBOEXPORT original | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\P0033_BATCH2_CUBOEXPORT_111.BTQ` (también `_120.BTQ` y `_130.TPT`) |
| EXPORTPLANO original | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\P0033_BATCH2_EXPORTPLANO_111.BTQ` (también `_120.BTQ`) |
| CANALCONTACTO original | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\P0033_BATCH2_CANALCONTACTO_111.BTQ` |
| Motores en datos (CSV) | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Dlls-Batch\Dll_Btach.csv` y `...\Dlls-Batch\Dll_Btach2.csv` |
| Bitácora del proyecto | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Bitacora_Batch_Teradata.md` |
| Bugs del original | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Bugs_Encontrados.md` |
| Muestra de salida CON_DATOS | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Salidas\CON_DATOS_4421_20240902100353.CSV` (y `.ESQUEMA`) |
| Muestra de salida SIN_DATOS | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Salidas\SIN_DATOS_4421_20240902100353.CSV` (y `.ESQUEMA`) |
| Muestra de salida INCONSISTENCIA | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Salidas\INCONSISTENCIA_4421_20240902100353.CSV` (y `.ESQUEMA`) |
| Muestra ALERTAS y log | `d:\--KIDAR--\EXPERIAN\PRY-RECON-WS5\Batch-Teradata\Salidas\ALERTAS-4421_20240902112522` y `...\Salidas\BATCH_SOLICITUD_BATCH.ARCHIVO_LOG` |

### 4.E Supuestos sin confirmar (lista consolidada)

Ninguno de estos puntos se pudo comprobar sin un cluster Redshift real. Cuando uno se confirme o se refute en la primera ejecución, anótalo aquí y en `VERIFICACION.md`.

1. `CREATE EXTERNAL FUNCTION` no valida que la Lambda exista al crearla (1.2.8).
2. Redshift no invoca la Lambda si la consulta no tiene filas (`FILTRO_F` con el insumo vacío) (1.2.4).
3. Un `CALL` de nivel superior acepta un literal en un parámetro `INOUT` (A.0).
4. `CALL` acepta notación nombrada `=>` (no aparece en la sintaxis de AWS; por eso la guía usa posicional).
5. En llamadas anidadas se aceptan expresiones como argumento (`'ALERTAS-' || p_id_solicitud || v_fch_archivo`, `GETDATE()`) y `||` convierte `BIGINT` a texto de forma implícita.
6. Comparación implícita `VARCHAR(5) = INTEGER` en el `JOIN` de `exportplano` (2.4).
7. `CREATE PROCEDURE` no exige que existan los objetos que referencia (D5).
8. Las vistas `late-binding` con `TOP 200 ... ORDER BY` y vista sobre vista de las filas `ITERADOR` (IDs 7 y 8) son aceptadas por Redshift (paso 2 del orquestador).
9. `ANALYZE` y `QUALIFY` funcionan dentro de un stored procedure (`VERIFICACION.md` lo señala como no verificado).
10. `DC_NUMERO` es el número del celular también en Teradata (H5).
11. El contenido real de `rec_stage.batch2_homologacion` (las 5 filas de la guía son derivadas del código).
12. `editdistance_u` equivale a Damerau-Levenshtein OSA.
13. Efectos exactos de `COMMIT` implícito del `TRUNCATE` y del *handler* en llamadas anidadas (Camino B).
14. `SELECT 'a' = 'A'` devuelve `true` en una base `CASE_INSENSITIVE` (V7).
15. Que las funciones externas (Lambda) aparezcan en `pg_proc_info` (V5).
16. Que `UNLOAD` con 0 filas cree un archivo solo con cabecera o no cree ninguno (5.5).
17. Que `USAGE ON LANGUAGE plpgsql` ya esté concedido por omisión (1.2.1).
18. Que un cliente como DBeaver ejecute bien los cuerpos `$$ ... $$` de estos archivos (1.3).
19. Que las filas de bitácora de un `CALL` en curso no sean visibles desde otra sesión (paso 4).
20. Que los comandos de listado de `psql` moderno (`\d`) fallen contra Redshift (1.3).
21. El texto exacto de los mensajes de error de Redshift citados en las tablas de síntomas.
22. Los valores por omisión de columnas no listadas en un `INSERT` o `COPY` (`filtro_h = 0`) se comportan como en el DDL.

### 4.F Verificaciones hechas al escribir esta guía (2026-10-15)

Se hicieron en el computador donde se redactó, **sin cluster Redshift y sin ejecutar nada contra AWS**. Sirven para que quien revise no tenga que repetirlas.

| Qué se verificó | Cómo | Resultado |
|---|---|---|
| Que existen las rutas citadas | `Test-Path` / comparación en script sobre las 48 rutas absolutas y 37 relativas del texto | Todas existen |
| Que existen los nombres citados | Búsqueda de cada `esquema.objeto`, `sp_*` y `f_*` en `ddl\` y `procedures\` | 79 nombres con respaldo (repo, vistas puente de prueba, tablas de trabajo del pipeline u objetos declarados como "no construidos"); 29 `sp_*` y 6 `f_*` existen |
| Conteos del repo | Lectura de los `CREATE` no comentados | 43 tablas (3 / 3 / 34 / 3), 1 vista, 8 funciones, 34 procedures (7 + 27; 31 `sp_batch2_*`) |
| Citas de línea de los DDL | Comparación con la línea real del `CREATE TABLE` (margen de 4) | 45 citas correctas |
| Orden de despliegue | Comparación con los `\i` de `README.md` | Idéntico (22 archivos) |
| Los `INSERT` de datos de prueba | Script que lee los `CREATE TABLE` reales: columnas existentes, número de valores por tupla, columnas `NOT NULL`, largo de textos, tipos | 12 `INSERT` sin errores; filas por `INSERT` iguales a las anunciadas |
| Coherencia de los datos | Simulación del recorte 3/3/2/2 con los datos cargados | Resultado igual al de las tablas de 2.6.3, 5.2 y 5.4 (19 filas cada una); `id_auto` único entre los 6 cubos |
| CSV de la opción B | Comparación con las tuplas de D.3 y con las columnas del `COPY` | Idénticos (18 filas, 13 columnas) |
| Firmas de los `CALL` | Comparación con los parámetros de cada `CREATE PROCEDURE` | 20 `CALL` con la cantidad correcta de argumentos; la secuencia del Camino A es la del orquestador (18 llamadas) |
| Sintaxis SQL | `sqlglot` 30.23.0, dialecto Redshift | 59 sentencias parsean (`SHOW` y `COPY` se omiten porque el analizador no los cubre) |
| Columnas en las consultas | Cada `SELECT` de una sola tabla contra los DDL y las columnas documentadas de las vistas del sistema | 73 `SELECT` sin columnas inexistentes |
| Documentación de AWS | Lectura de `CREATE DATABASE ... COLLATE`, `CALL`, `UNLOAD`, `GRANT`, `SVV_TABLES`, `SVV_COLUMNS`, `PG_PROC_INFO`, `STV_RECENTS`, `SVL_STORED_PROC_MESSAGES`, `STL_LOAD_ERRORS`, `DB_COLLATION`, RSQL y manejo de errores en procedures | Sintaxis y columnas citadas coinciden; 20 enlaces responden HTTP 200 |
| Lambda | `python -B -m unittest test_lambda_function` | `Ran 36 tests ... OK` |
| Generación de `ddl\08` sin marcadores | Comando de 1.2.8 probado con valores de ejemplo | Sin BOM, 0 marcadores restantes, 4 pares `LAMBDA` / `IAM_ROLE` |
| Markdown | Cercas de código y celdas de tablas | 59 bloques de código cerrados; 43 tablas con número de celdas consistente |

**No verificado (requiere cluster y cuenta AWS reales):** todo comportamiento en Redshift, los comandos de `psql` y de la AWS CLI, el contenido real de los CSV (la línea de ejemplo de 5.6 está calculada a mano) y los 22 supuestos de 4.E.

### 4.G Notas de actualización

- **2026-10-15:** reescritura completa para lectores sin conocimiento previo; se agregaron el glosario, el despliegue paso a paso, el Lambda, la lista de tablas con sus DDL, los datos de prueba verificados contra los DDL, el Camino A por pasos, el seguimiento, la verificación y el criterio de éxito en tres niveles.
- Esta guía complementa a `README.md` (orden de despliegue y llamada al proceso) y a `VERIFICACION.md` (qué se revisó a mano y qué no). Si algo cambia en el código, actualiza primero esos dos archivos y luego esta guía.

