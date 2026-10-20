# Legado Teradata de Reconocer y Batch: manifiesto

**Para que existe esta carpeta.** El codigo Teradata (AS-IS) es la fuente de
verdad para homologar a Redshift, y hasta 2026-10-20 vivia solo en adjuntos
de sesion que se pierden. Aqui queda versionado, en texto, para poder
buscarlo (`grep`) y compararlo (`diff`).

**Reglas de lectura.**

- Esto es **evidencia**, no codigo desplegable: nada de aqui entra en
  `deploy/redshift/` ni en el traslado a Bitbucket.
- Los `.md` de `batch/` son **interpretaciones previas hechas con IA**: no son
  evidencia. Se conservan solo como referencia.
- `batch/Redshift_PROTOTIPO_no_es_evidencia/` es un **prototipo no desplegado**.
  Tiene errores conocidos (por ejemplo `DC_NUMERO` sale del correo). No usarlo
  como fuente.
- Los archivos se copiaron **byte a byte**, con su codificacion y sus finales
  de linea originales (CRLF en varios BTQ/TPT). Las citas `archivo:linea` del
  repo se refieren a estas copias.

## Origen

| Fuente | Recibido | SHA-256 | Archivos |
|---|---|---|---|
| `reconocer_teradata_completo.zip` | 2026-10-20 (sesion) | `0c78b878af091ffe69cc59bbe64f46a1e7f5b91f3465624b09f9ea9963d4f1d3` | 76 |
| `Batch_Teradata_Oct_16_2.zip` | 2026-10-20 (sesion) | `0160eb274ae74caa9ee9ece99e00bb5b2d3ce3344ed275b806943aeb6051b8a4` | 97 |
| `Batch_Teradata_Oct_16_2.zip` | 2026-10-20 (sesion, segundo envio) | `0160eb274ae74caa9ee9ece99e00bb5b2d3ce3344ed275b806943aeb6051b8a4` | 97 |
| `Batch-Teradata-16Oct438pm (1).zip` | repo `Chief-Spark/reconocer_downstream_batch` | `a74cc4bceeaf0aea490edf6326d05cea143570214046fa47353c0fb911d05966` | 98 |
| `Reconocer_Esencial_2950_20221216145538_1.xlsx` | 2026-10-20 (sesion) | `ee58b1e78e4db4232238b9fbb8c7e507bc75121ecdef83f7036554089e1e0f23` | 1 |

- `Batch_Teradata_Oct_16_2.zip` llego **dos veces** con el mismo SHA-256: es
  el mismo archivo.
- `Batch-Teradata-16Oct438pm (1).zip` es la copia anterior, publicada en
  `Chief-Spark/reconocer_downstream_batch`. Comparada por CRC con Oct_16_2:
  identica salvo dos cosas. Trae ademas `InfoAdicional.txt` (volcados de DDL de
  vistas, que el Batch usa) y una version distinta de un `.md` del prototipo.
  **De esa copia se toma solo `InfoAdicional.txt`.**
- La salida real `.xlsx` **no se versiona**: tiene datos personales reales.
  Queda su perfil en `salida_real_esencial/`.
- El correo del DBA sobre el cluster consumidor no se versiona (trae nombres y
  correos). Sus datos tecnicos estan en `../ANALISIS_AS_IS_HOMOLOGACION.md`.

## Que se excluyo o transformo, y por que

| Que | Accion | Motivo |
|---|---|---|
| `Batch-Teradata/Salidas/BATCH_VALFORMATO_4421_VAL.txt` | excluido | trae numeros de documento reales |
| `Batch-Teradata/Bitacora_Batch_Teradata.md` | excluido | su propio `.gitignore` dice "no debe versionarse" |
| `Batch-Teradata/.gitignore` | excluido | ya no tiene nada que ignorar |
| `Batch-Teradata/Redshift/` | renombrado a `Redshift_PROTOTIPO_no_es_evidencia/` | dejar claro que no es evidencia |
| `catalogos/*.xlsx` (6) | convertidos a `* (NH).csv` | **sin** las columnas `Roles > ...` (usuario, nombre y correo de los responsables del dato), sin HTML y sin las lineas "Data Owner". Los xlsx originales no se versionan |
| `Documento Funcional Unificacion Final V1.0.docx` | se conserva, mas una copia `.txt` | el `.txt` es para poder buscar; los diagramas solo estan en el `.docx` |
| `BATCH_VALFORM_ST1` | **se conserva** | se revisó: es la configuración de validación de formato (expresiones regulares por tipo de documento), no trae documentos |

**Credenciales.** Se revisó todo. No hay ninguna literal. Los BTQ y TPT leen
`@UserPassword`, `$tdwallet(...)` o archivos `.par` del servidor, y ninguno
de esos se incluye aquí.

## Que falta del legado (no vino en ningun zip)

| Pieza | Para que | Impacto |
|---|---|---|
| `P0032_BATCH_GENERACUBO` (+ `_PUNTO_INT`, `_EXPL_DE_PUNTOS_DE_INT`) | arma los 7 `BATCH_CUBO_*` que lee el Batch | el puente Reconocer -> Batch solo se puede **inferir** |
| Contenido de `BATCH2_HOMOLOGACION` | campo de plantilla -> columna del cubo | pedido al usuario |
| `PRO_BATCH_VALNOMBRE` (P0037), `Vstg_BUROPERS_TMP` | universo valido e inconsistencias | traza de identidad inferida |
| `PRO_CARGA_INSUMO_UNI_REG2`, `PRO_CreaDicNomenclaturaReg2` | insumo y diccionario de la R2 | |
| Carga final de `RELACION_UBICAC_ESTANDAR_GEO`, `PRO_HOMOLOGACION_GEO` | GEO | |
| Productor de `MTCalcularIndicadoresMovilidad` | Novedades d6 (Movilidad) | |
| `PRO_Cursor_Drop*`, `PRO_Novedad_BTBONE`, `EXPORT_*.TPT` de Novedades | ordenamiento y layout final de extractos | |

## Contenido

```
batch/Bugs_Encontrados.md
batch/DDL.sql
batch/Dlls-Batch/Dll_Btach.csv
batch/Dlls-Batch/Dll_Btach2.csv
batch/FuncionesUDF/Bach_Similitud_Dir_MZ/BachSimilitudDirMZ.c
batch/FuncionesUDF/Bach_Similitud_Dir_MZ/Bach_Similitud_Dir_MZ.BTQ
batch/FuncionesUDF/Bach_Similitud_Dir_VIA/BachSimilitudDirVIA.c
batch/FuncionesUDF/Bach_Similitud_Dir_VIA/Bach_Similitud_Dir_VIA.BTQ
batch/FuncionesUDF/Bach_Similitud_Tel/BachSimilitudTel.c
batch/FuncionesUDF/Bach_Similitud_Tel/Bach_Similitud_Tel.BTQ
batch/FuncionesUDF/Bach_Similitud_email/BachSimilitudEmail.c
batch/FuncionesUDF/Bach_Similitud_email/Bach_Similitud_email.BTQ
batch/FuncionesUDF/DataMasking/DataMasking.BTQ
batch/FuncionesUDF/DataMasking/DataMasking.c
batch/FuncionesUDF/DataMasking/DirDataMasking.BTQ
batch/FuncionesUDF/DataMasking/DirDataMasking.c
batch/FuncionesUDF/DataMasking/RazonDataMasking.BTQ
batch/FuncionesUDF/DataMasking/RazonDataMasking.c
batch/FuncionesUDF/PorcSimilitud/PorcSimilitud.BTQ
batch/FuncionesUDF/PorcSimilitud/PorcSimilitud.c
batch/InfoAdicional.txt
batch/P0033_BATCH2_ACTUALIZA_HISTORIA_111.BTQ
batch/P0033_BATCH2_ACTUALIZA_HISTORIA_130.TPT
batch/P0033_BATCH2_CANALCONTACTO_111.BTQ
batch/P0033_BATCH2_CANALCONTACTO_120.BTQ
batch/P0033_BATCH2_CANALCONTACTO_130.TPT
batch/P0033_BATCH2_CANALCONTACTO_140.BTQ
batch/P0033_BATCH2_CANTREPCANAL_111.BTQ
batch/P0033_BATCH2_CUBOEXPORT_111.BTQ
batch/P0033_BATCH2_CUBOEXPORT_120.BTQ
batch/P0033_BATCH2_CUBOEXPORT_130.TPT
batch/P0033_BATCH2_ESTADISTICAS_111.BTQ
batch/P0033_BATCH2_ESTADISTICAS_130.TPT
batch/P0033_BATCH2_ESTADISTIOLD_111_1.BTQ
batch/P0033_BATCH2_EXPORTLOG_111.BTQ
batch/P0033_BATCH2_EXPORTLOG_130.TPT
batch/P0033_BATCH2_EXPORTLOG_140.BTQ
batch/P0033_BATCH2_EXPORTPLANO_111.BTQ
batch/P0033_BATCH2_EXPORTPLANO_120.BTQ
batch/P0033_BATCH2_EXPORTPLANO_130.TPT
batch/P0033_BATCH2_EXPORTPLANO_135.TPT
batch/P0033_BATCH2_EXPORTPLANO_140.BTQ
batch/P0033_BATCH2_EXPORTVERTPLANO_111.BTQ
batch/P0033_BATCH2_EXPORTVERTPLANO_130.TPT
batch/P0033_BATCH2_EXPORTVERTPLANO_140.BTQ
batch/P0033_BATCH2_EXPORT_111.BTQ
batch/P0033_BATCH2_PROCESACUBOS_111.BTQ
batch/P0033_BATCH2_VALIDAR_ARCHIVOS_111.BTQ
batch/P0033_PROCESO_BATCH2.BTQ
batch/P0033_PROCESO_BATCH2_MOD.BTQ
batch/Redshift_PROTOTIPO_no_es_evidencia/.agents/tasks/inventario_dependencias.md
batch/Redshift_PROTOTIPO_no_es_evidencia/GUIA_PRUEBA_PRODUCTO_ESENCIAL.md
batch/Redshift_PROTOTIPO_no_es_evidencia/README.md
batch/Redshift_PROTOTIPO_no_es_evidencia/VERIFICACION.md
batch/Redshift_PROTOTIPO_no_es_evidencia/datos/01_catalogos_motor.sql
batch/Redshift_PROTOTIPO_no_es_evidencia/ddl/00_README.md
batch/Redshift_PROTOTIPO_no_es_evidencia/ddl/01_schemas.sql
batch/Redshift_PROTOTIPO_no_es_evidencia/ddl/02_tablas_configuracion.sql
batch/Redshift_PROTOTIPO_no_es_evidencia/ddl/03_tablas_cubos.sql
batch/Redshift_PROTOTIPO_no_es_evidencia/ddl/04_tablas_pivote.sql
batch/Redshift_PROTOTIPO_no_es_evidencia/ddl/05_tablas_control.sql
batch/Redshift_PROTOTIPO_no_es_evidencia/ddl/06_vistas_dimension.sql
batch/Redshift_PROTOTIPO_no_es_evidencia/ddl/07_tablas_dependencias_sps.sql
batch/Redshift_PROTOTIPO_no_es_evidencia/ddl/08_funciones_udf.sql
batch/Redshift_PROTOTIPO_no_es_evidencia/ddl/09_vistas_dependencias_sps.sql
batch/Redshift_PROTOTIPO_no_es_evidencia/ddl/10_tablas_trabajo_f2_4.sql
batch/Redshift_PROTOTIPO_no_es_evidencia/lambda/udf_similitud/casos_validacion_redshift.sql
batch/Redshift_PROTOTIPO_no_es_evidencia/lambda/udf_similitud/casos_validacion_teradata.sql
batch/Redshift_PROTOTIPO_no_es_evidencia/lambda/udf_similitud/lambda_function.py
batch/Redshift_PROTOTIPO_no_es_evidencia/lambda/udf_similitud/test_lambda_function.py
batch/Redshift_PROTOTIPO_no_es_evidencia/procedures/01_sp_batch2_genera_lote.sql
batch/Redshift_PROTOTIPO_no_es_evidencia/procedures/02_sp_batch2_log_helpers.sql
batch/Redshift_PROTOTIPO_no_es_evidencia/procedures/03_sp_batch2_cubo_export.sql
batch/Redshift_PROTOTIPO_no_es_evidencia/procedures/04_sp_batch2_exportplano.sql
batch/Redshift_PROTOTIPO_no_es_evidencia/procedures/05_sp_batch2_exportlog.sql
batch/Redshift_PROTOTIPO_no_es_evidencia/procedures/06_sp_batch2_actualiza_historia.sql
batch/Redshift_PROTOTIPO_no_es_evidencia/procedures/07_sp_batch2_valida_archivos.sql
batch/Redshift_PROTOTIPO_no_es_evidencia/procedures/08_sp_batch2_procesacubos.sql
batch/Redshift_PROTOTIPO_no_es_evidencia/procedures/09_sp_batch2_otros.sql
batch/Redshift_PROTOTIPO_no_es_evidencia/procedures/09b_sp_batch2_motores_sql.sql
batch/Redshift_PROTOTIPO_no_es_evidencia/procedures/10_sp_batch2_proceso_batch2.sql
batch/Salidas/ALERTAS-4421_20240902112522
batch/Salidas/BATCH_SOLICITUD_BATCH.ARCHIVO_CONTROL
batch/Salidas/BATCH_SOLICITUD_BATCH.ARCHIVO_LOG
batch/Salidas/BATCH_VALFORMATO_4421_INC.txt
batch/Salidas/BATCH_VALFORM_ST1
batch/Salidas/CON_DATOS_4421_20240902100353.CSV
batch/Salidas/CON_DATOS_4421_20240902100353.ESQUEMA
batch/Salidas/INCONSISTENCIA_4421_20240902100353.CSV
batch/Salidas/INCONSISTENCIA_4421_20240902100353.ESQUEMA
batch/Salidas/SIN_DATOS_4421_20240902100353.CSV
batch/Salidas/SIN_DATOS_4421_20240902100353.ESQUEMA
batch/Shell/sh-BATCH-VFORNOM
batch/Sps_Batch.sql
batch/_verif_f2_4_sql.py
reconocer/catalogos/BDM_VISTA - V_Cod_Entrega_Dato.csv
reconocer/catalogos/BDM_VISTA - V_Fuente_Dato.csv
reconocer/catalogos/BDM_VISTA - V_Razon_Bloqueo.csv
reconocer/catalogos/BDM_VISTA - V_Tipo_Cuenta.csv
reconocer/catalogos/DANE State Code (NH).csv
reconocer/catalogos/Dane Divipola Villages Codes (NH).csv
reconocer/catalogos/ID Type NH (NH).csv
reconocer/catalogos/Information Recognizer (NH).csv
reconocer/catalogos/NOMENCLATURA_SINTETICO.csv
reconocer/catalogos/REC_VISTA - V_Beta_Ordenamiento_Cel.csv
reconocer/catalogos/REC_VISTA - V_Beta_Ordenamiento_Dir.csv
reconocer/catalogos/REC_VISTA - V_Beta_Ordenamiento_Email.csv
reconocer/catalogos/REC_VISTA - V_Beta_Ordenamiento_Tel.csv
reconocer/catalogos/REC_VISTA - V_Fuente.csv
reconocer/catalogos/REC_VISTA - V_Geografia.csv
reconocer/catalogos/REC_VISTA - V_Gestion_Registro.csv
reconocer/catalogos/REC_VISTA - V_Operador_Ord_Cel.csv
reconocer/catalogos/REC_VISTA - V_Tipo_Cuenta_Ord.csv
reconocer/catalogos/REC_VISTA - V_Tipo_Ubicacion_Direccion.csv
reconocer/catalogos/Subscriber Account Type (NH).csv
reconocer/catalogos/Subscriber Blocking Reasons (NH).csv
reconocer/geo/SO/P0006_STAGEGEOREFERENCIA_100.TPT
reconocer/geo/SO/P0007_PUNTO_DE_INTERES_GEO_100.TPT
reconocer/geo/SO/P0007_PUNTO_DE_INTERES_GEO_110.TPT
reconocer/geo/SO/P0007_PUNTO_DE_INTERES_GEO_120.TPT
reconocer/geo/SO/P0007_PUNTO_DE_INTERES_GEO_130.TPT
reconocer/geo/SO/P0007_PUNTO_DE_INTERES_GEO_140.TPT
reconocer/geo/SO/P0007_PUNTO_DE_INTERES_GEO_141.BTQ
reconocer/geo/SO/P0013_STAGEDISTANCIASGEO_100.TPT
reconocer/geo/SO/P0014_NUEVANOMENCLATURA_100.TPT
reconocer/geo/SO/P0014_NUEVANOMENCLATURA_110.TPT
reconocer/geo/SO/P0014_NUEVANOMENCLATURA_120.TPT
reconocer/geo/SO/P0014_NUEVANOMENCLATURA_130.TPT
reconocer/geo/SO/P0014_NUEVANOMENCLATURA_140.TPT
reconocer/geo/SO/P0036_STAGE_PUNTO_INTERES_GEO_131.BTQ
reconocer/geo/SO/P0036_STAGE_PUNTO_INTERES_GEO_141.TPT
reconocer/novedades/DB/Novedad.sql
reconocer/novedades/P0035_Extractor_Novedades_111.BTQ
reconocer/novedades/P0035_Extractor_Novedades_120.TPT
reconocer/novedades/P0035_Extractor_Novedades_130.TPT
reconocer/novedades/P0035_Extractor_Novedades_140.BTQ
reconocer/ordenamiento/BTEQ_CURSOR_131.BTQ
reconocer/ordenamiento/Caracteristicas.txt
reconocer/ordenamiento/DB/Ordenamiento.sql
reconocer/ordenamiento/ORDENAMIENTO_242_131.BTQ
reconocer/ordenamiento/P0027_UBI_ORDENAMIENTO_111.TPT
reconocer/ordenamiento/P0027_UBI_ORDENAMIENTO_120.TPT
reconocer/ordenamiento/P0027_UBI_ORDENAMIENTO_130.TPT
reconocer/ordenamiento/P0027_UBI_ORDENAMIENTO_140.TPT
reconocer/ordenamiento/P0029_INDICADORES_MOVILIDAD_111.BTQ
reconocer/ordenamiento/P0029_INDICADORES_MOVILIDAD_120.TPT
reconocer/ordenamiento/P0029_INDICADORES_MOVILIDAD_130.TPT
reconocer/ordenamiento/P0029_INDICADORES_MOVILIDAD_140.TPT
reconocer/unificacion/DB/Unificacion.sql
reconocer/unificacion/Documento Funcional Unificacion Final V1.0.docx
reconocer/unificacion/Documento Funcional Unificacion Final V1.0.txt
reconocer/unificacion/P0019_UNIFICACION_111.TPT
reconocer/unificacion/P0019_UNIFICACION_120.TPT
reconocer/unificacion/P0019_UNIFICACION_130.TPT
reconocer/unificacion/P0019_UNIFICACION_130_20240730.TPT
reconocer/unificacion/P0019_UNIFICACION_140.TPT
reconocer/unificacion/P0020_CARGA_INSUMO_UNI_REG2_131.BTQ
reconocer/unificacion/P0020_CreaDicNomenclaturaReg2_131.BTQ
reconocer/unificacion/P0020_UNIFICACION_DIRECCION_111.BTQ
reconocer/unificacion/P0020_UNIFICACION_DIRECCION_120.BTQ
reconocer/unificacion/P0020_UNIFICACION_DIRECCION_130.TPT
reconocer/unificacion/P0020_UNIFICACION_DIRECCION_140.BTQ
reconocer/unificacion/P0021_UNIFICACION_111.BTQ
reconocer/unificacion/P0021_UNIFICACION_120.TPT
reconocer/unificacion/P0021_UNIFICACION_130.TPT
reconocer/unificacion/P0021_UNIFICACION_140.TPT
reconocer/unificacion/P0021_UNIFICACION_141.TPT
reconocer/unificacion/Tipo_Via.txt
reconocer/unificacion/VM_Reporte_Relacion_Pers_Ubi.txt
reconocer/unificacion/V_Insumo_Unificacion_Regla1.txt
reconocer/unificacion/V_Insumo_Unificacion_Regla2.txt
reconocer/unificacion/V_Insumo_Unificacion_Regla3.txt
salida_real_esencial/PERFIL_SALIDA_RECONOCER_ESENCIAL.md
```

## Lista original de cada zip

### `reconocer_teradata_completo.zip`

```
28208	reconocer_teradata_completo/novedades/P0035_Extractor_Novedades_140.BTQ
406015	reconocer_teradata_completo/novedades/DB/Novedad.sql
35544	reconocer_teradata_completo/novedades/P0035_Extractor_Novedades_120.TPT
41031	reconocer_teradata_completo/novedades/P0035_Extractor_Novedades_130.TPT
20257	reconocer_teradata_completo/novedades/P0035_Extractor_Novedades_111.BTQ
4711	reconocer_teradata_completo/geo/SO/P0007_PUNTO_DE_INTERES_GEO_140.TPT
8655	reconocer_teradata_completo/geo/SO/P0014_NUEVANOMENCLATURA_110.TPT
6254	reconocer_teradata_completo/geo/SO/P0014_NUEVANOMENCLATURA_100.TPT
2724	reconocer_teradata_completo/geo/SO/P0007_PUNTO_DE_INTERES_GEO_120.TPT
3294	reconocer_teradata_completo/geo/SO/P0036_STAGE_PUNTO_INTERES_GEO_131.BTQ
9650	reconocer_teradata_completo/geo/SO/P0007_PUNTO_DE_INTERES_GEO_130.TPT
6484	reconocer_teradata_completo/geo/SO/P0006_STAGEGEOREFERENCIA_100.TPT
5395	reconocer_teradata_completo/geo/SO/P0013_STAGEDISTANCIASGEO_100.TPT
6820	reconocer_teradata_completo/geo/SO/P0007_PUNTO_DE_INTERES_GEO_100.TPT
4185	reconocer_teradata_completo/geo/SO/P0007_PUNTO_DE_INTERES_GEO_110.TPT
4665	reconocer_teradata_completo/geo/SO/P0014_NUEVANOMENCLATURA_140.TPT
6317	reconocer_teradata_completo/geo/SO/P0007_PUNTO_DE_INTERES_GEO_141.BTQ
9354	reconocer_teradata_completo/geo/SO/P0014_NUEVANOMENCLATURA_130.TPT
2734	reconocer_teradata_completo/geo/SO/P0036_STAGE_PUNTO_INTERES_GEO_141.TPT
2720	reconocer_teradata_completo/geo/SO/P0014_NUEVANOMENCLATURA_120.TPT
1045336	reconocer_teradata_completo/unificacion/Documento Funcional Unificacion Final V1.0.docx
7997	reconocer_teradata_completo/unificacion/P0019_UNIFICACION_130_20240730.TPT
3486	reconocer_teradata_completo/unificacion/P0021_UNIFICACION_140.TPT
2479	reconocer_teradata_completo/unificacion/P0021_UNIFICACION_141.TPT
6812	reconocer_teradata_completo/unificacion/P0019_UNIFICACION_111.TPT
2267	reconocer_teradata_completo/unificacion/P0020_UNIFICACION_DIRECCION_140.BTQ
15494	reconocer_teradata_completo/unificacion/P0021_UNIFICACION_111.BTQ
1832	reconocer_teradata_completo/unificacion/V_Insumo_Unificacion_Regla2.txt
126	reconocer_teradata_completo/unificacion/V_Insumo_Unificacion_Regla3.txt
2827	reconocer_teradata_completo/unificacion/V_Insumo_Unificacion_Regla1.txt
7994	reconocer_teradata_completo/unificacion/P0021_UNIFICACION_130.TPT
2539	reconocer_teradata_completo/unificacion/P0021_UNIFICACION_120.TPT
2344	reconocer_teradata_completo/unificacion/P0020_UNIFICACION_DIRECCION_120.BTQ
2557	reconocer_teradata_completo/unificacion/VM_Reporte_Relacion_Pers_Ubi.txt
1559	reconocer_teradata_completo/unificacion/P0020_CARGA_INSUMO_UNI_REG2_131.BTQ
11837	reconocer_teradata_completo/unificacion/P0020_UNIFICACION_DIRECCION_130.TPT
3074	reconocer_teradata_completo/unificacion/P0020_UNIFICACION_DIRECCION_111.BTQ
3422	reconocer_teradata_completo/unificacion/P0019_UNIFICACION_140.TPT
311427	reconocer_teradata_completo/unificacion/DB/Unificacion.sql
2539	reconocer_teradata_completo/unificacion/P0019_UNIFICACION_120.TPT
1565	reconocer_teradata_completo/unificacion/P0020_CreaDicNomenclaturaReg2_131.BTQ
795	reconocer_teradata_completo/unificacion/Tipo_Via.txt
9915	reconocer_teradata_completo/unificacion/P0019_UNIFICACION_130.TPT
6916	reconocer_teradata_completo/ordenamiento/ORDENAMIENTO_242_131.BTQ
3937	reconocer_teradata_completo/ordenamiento/P0027_UBI_ORDENAMIENTO_111.TPT
6171	reconocer_teradata_completo/ordenamiento/BTEQ_CURSOR_131.BTQ
8546	reconocer_teradata_completo/ordenamiento/P0029_INDICADORES_MOVILIDAD_130.TPT
3874	reconocer_teradata_completo/ordenamiento/P0029_INDICADORES_MOVILIDAD_111.BTQ
2136	reconocer_teradata_completo/ordenamiento/P0027_UBI_ORDENAMIENTO_120.TPT
6343	reconocer_teradata_completo/ordenamiento/P0027_UBI_ORDENAMIENTO_130.TPT
4168	reconocer_teradata_completo/ordenamiento/P0029_INDICADORES_MOVILIDAD_120.TPT
17677	reconocer_teradata_completo/ordenamiento/DB/Ordenamiento.sql
5213	reconocer_teradata_completo/ordenamiento/P0027_UBI_ORDENAMIENTO_140.TPT
133297	reconocer_teradata_completo/ordenamiento/Caracteristicas.txt
4832	reconocer_teradata_completo/ordenamiento/P0029_INDICADORES_MOVILIDAD_140.TPT
1071	reconocer_teradata_completo/catalogos/REC_VISTA - V_Tipo_Cuenta_Ord.csv
119	reconocer_teradata_completo/catalogos/REC_VISTA - V_Gestion_Registro.csv
524	reconocer_teradata_completo/catalogos/REC_VISTA - V_Beta_Ordenamiento_Tel.csv
343	reconocer_teradata_completo/catalogos/NOMENCLATURA_SINTETICO.csv
744	reconocer_teradata_completo/catalogos/REC_VISTA - V_Operador_Ord_Cel.csv
5656	reconocer_teradata_completo/catalogos/Subscriber Blocking Reasons.xlsx
290	reconocer_teradata_completo/catalogos/REC_VISTA - V_Fuente.csv
574	reconocer_teradata_completo/catalogos/REC_VISTA - V_Beta_Ordenamiento_Dir.csv
5301	reconocer_teradata_completo/catalogos/BDM_VISTA - V_Tipo_Cuenta.csv
644	reconocer_teradata_completo/catalogos/REC_VISTA - V_Beta_Ordenamiento_Email.csv
9312	reconocer_teradata_completo/catalogos/DANE State Code.xlsx
105149	reconocer_teradata_completo/catalogos/REC_VISTA - V_Geografia.csv
7232	reconocer_teradata_completo/catalogos/ID Type NH.xlsx
645482	reconocer_teradata_completo/catalogos/Dane Divipola Villages Codes.xlsx
3493	reconocer_teradata_completo/catalogos/BDM_VISTA - V_Fuente_Dato.csv
4307	reconocer_teradata_completo/catalogos/Information Recognizer.xlsx
122770	reconocer_teradata_completo/catalogos/BDM_VISTA - V_Cod_Entrega_Dato.csv
3192	reconocer_teradata_completo/catalogos/BDM_VISTA - V_Razon_Bloqueo.csv
19883	reconocer_teradata_completo/catalogos/Subscriber Account Type.xlsx
524	reconocer_teradata_completo/catalogos/REC_VISTA - V_Beta_Ordenamiento_Cel.csv
199	reconocer_teradata_completo/catalogos/REC_VISTA - V_Tipo_Ubicacion_Direccion.csv
```

### `Batch_Teradata_Oct_16_2.zip`

```
80	Batch-Teradata/.gitignore
77265	Batch-Teradata/Bitacora_Batch_Teradata.md
26843	Batch-Teradata/Bugs_Encontrados.md
5686	Batch-Teradata/DDL.sql
15056	Batch-Teradata/Dlls-Batch/Dll_Btach.csv
7373	Batch-Teradata/Dlls-Batch/Dll_Btach2.csv
6489	Batch-Teradata/FuncionesUDF/Bach_Similitud_Dir_MZ/BachSimilitudDirMZ.c
2210	Batch-Teradata/FuncionesUDF/Bach_Similitud_Dir_MZ/Bach_Similitud_Dir_MZ.BTQ
7330	Batch-Teradata/FuncionesUDF/Bach_Similitud_Dir_VIA/BachSimilitudDirVIA.c
3855	Batch-Teradata/FuncionesUDF/Bach_Similitud_Dir_VIA/Bach_Similitud_Dir_VIA.BTQ
3179	Batch-Teradata/FuncionesUDF/Bach_Similitud_email/BachSimilitudEmail.c
2543	Batch-Teradata/FuncionesUDF/Bach_Similitud_email/Bach_Similitud_email.BTQ
1633	Batch-Teradata/FuncionesUDF/Bach_Similitud_Tel/BachSimilitudTel.c
1753	Batch-Teradata/FuncionesUDF/Bach_Similitud_Tel/Bach_Similitud_Tel.BTQ
1095	Batch-Teradata/FuncionesUDF/DataMasking/DataMasking.BTQ
722	Batch-Teradata/FuncionesUDF/DataMasking/DataMasking.c
1112	Batch-Teradata/FuncionesUDF/DataMasking/DirDataMasking.BTQ
596	Batch-Teradata/FuncionesUDF/DataMasking/DirDataMasking.c
1117	Batch-Teradata/FuncionesUDF/DataMasking/RazonDataMasking.BTQ
983	Batch-Teradata/FuncionesUDF/DataMasking/RazonDataMasking.c
1157	Batch-Teradata/FuncionesUDF/PorcSimilitud/PorcSimilitud.BTQ
1590	Batch-Teradata/FuncionesUDF/PorcSimilitud/PorcSimilitud.c
4247	Batch-Teradata/P0033_BATCH2_ACTUALIZA_HISTORIA_111.BTQ
3081	Batch-Teradata/P0033_BATCH2_ACTUALIZA_HISTORIA_130.TPT
4694	Batch-Teradata/P0033_BATCH2_CANALCONTACTO_111.BTQ
8747	Batch-Teradata/P0033_BATCH2_CANALCONTACTO_120.BTQ
2688	Batch-Teradata/P0033_BATCH2_CANALCONTACTO_130.TPT
2773	Batch-Teradata/P0033_BATCH2_CANALCONTACTO_140.BTQ
4664	Batch-Teradata/P0033_BATCH2_CANTREPCANAL_111.BTQ
47938	Batch-Teradata/P0033_BATCH2_CUBOEXPORT_111.BTQ
30236	Batch-Teradata/P0033_BATCH2_CUBOEXPORT_120.BTQ
1954	Batch-Teradata/P0033_BATCH2_CUBOEXPORT_130.TPT
7114	Batch-Teradata/P0033_BATCH2_ESTADISTICAS_111.BTQ
1750	Batch-Teradata/P0033_BATCH2_ESTADISTICAS_130.TPT
7115	Batch-Teradata/P0033_BATCH2_ESTADISTIOLD_111_1.BTQ
5266	Batch-Teradata/P0033_BATCH2_EXPORTLOG_111.BTQ
1998	Batch-Teradata/P0033_BATCH2_EXPORTLOG_130.TPT
1102	Batch-Teradata/P0033_BATCH2_EXPORTLOG_140.BTQ
41162	Batch-Teradata/P0033_BATCH2_EXPORTPLANO_111.BTQ
15187	Batch-Teradata/P0033_BATCH2_EXPORTPLANO_120.BTQ
6239	Batch-Teradata/P0033_BATCH2_EXPORTPLANO_130.TPT
2348	Batch-Teradata/P0033_BATCH2_EXPORTPLANO_135.TPT
6957	Batch-Teradata/P0033_BATCH2_EXPORTPLANO_140.BTQ
9525	Batch-Teradata/P0033_BATCH2_EXPORTVERTPLANO_111.BTQ
3879	Batch-Teradata/P0033_BATCH2_EXPORTVERTPLANO_130.TPT
2344	Batch-Teradata/P0033_BATCH2_EXPORTVERTPLANO_140.BTQ
28064	Batch-Teradata/P0033_BATCH2_EXPORT_111.BTQ
19927	Batch-Teradata/P0033_BATCH2_PROCESACUBOS_111.BTQ
6971	Batch-Teradata/P0033_BATCH2_VALIDAR_ARCHIVOS_111.BTQ
15154	Batch-Teradata/P0033_PROCESO_BATCH2.BTQ
16399	Batch-Teradata/P0033_PROCESO_BATCH2_MOD.BTQ
77353	Batch-Teradata/Redshift/.agents/tasks/inventario_dependencias.md
23744	Batch-Teradata/Redshift/datos/01_catalogos_motor.sql
3222	Batch-Teradata/Redshift/ddl/00_README.md
1257	Batch-Teradata/Redshift/ddl/01_schemas.sql
7472	Batch-Teradata/Redshift/ddl/02_tablas_configuracion.sql
11689	Batch-Teradata/Redshift/ddl/03_tablas_cubos.sql
5755	Batch-Teradata/Redshift/ddl/04_tablas_pivote.sql
10833	Batch-Teradata/Redshift/ddl/05_tablas_control.sql
2366	Batch-Teradata/Redshift/ddl/06_vistas_dimension.sql
10806	Batch-Teradata/Redshift/ddl/07_tablas_dependencias_sps.sql
9706	Batch-Teradata/Redshift/ddl/08_funciones_udf.sql
10471	Batch-Teradata/Redshift/ddl/09_vistas_dependencias_sps.sql
4770	Batch-Teradata/Redshift/ddl/10_tablas_trabajo_f2_4.sql
173555	Batch-Teradata/Redshift/GUIA_PRUEBA_PRODUCTO_ESENCIAL.md
3631	Batch-Teradata/Redshift/lambda/udf_similitud/casos_validacion_redshift.sql
4876	Batch-Teradata/Redshift/lambda/udf_similitud/casos_validacion_teradata.sql
12190	Batch-Teradata/Redshift/lambda/udf_similitud/lambda_function.py
11831	Batch-Teradata/Redshift/lambda/udf_similitud/test_lambda_function.py
1886	Batch-Teradata/Redshift/procedures/01_sp_batch2_genera_lote.sql
8843	Batch-Teradata/Redshift/procedures/02_sp_batch2_log_helpers.sql
10805	Batch-Teradata/Redshift/procedures/03_sp_batch2_cubo_export.sql
11532	Batch-Teradata/Redshift/procedures/04_sp_batch2_exportplano.sql
8574	Batch-Teradata/Redshift/procedures/05_sp_batch2_exportlog.sql
3946	Batch-Teradata/Redshift/procedures/06_sp_batch2_actualiza_historia.sql
2356	Batch-Teradata/Redshift/procedures/07_sp_batch2_valida_archivos.sql
168570	Batch-Teradata/Redshift/procedures/08_sp_batch2_procesacubos.sql
7691	Batch-Teradata/Redshift/procedures/09b_sp_batch2_motores_sql.sql
95068	Batch-Teradata/Redshift/procedures/09_sp_batch2_otros.sql
15515	Batch-Teradata/Redshift/procedures/10_sp_batch2_proceso_batch2.sql
7377	Batch-Teradata/Redshift/README.md
8352	Batch-Teradata/Redshift/VERIFICACION.md
2895	Batch-Teradata/Salidas/ALERTAS-4421_20240902112522
971	Batch-Teradata/Salidas/BATCH_SOLICITUD_BATCH.ARCHIVO_CONTROL
2585	Batch-Teradata/Salidas/BATCH_SOLICITUD_BATCH.ARCHIVO_LOG
0	Batch-Teradata/Salidas/BATCH_VALFORMATO_4421_INC.txt
116	Batch-Teradata/Salidas/BATCH_VALFORMATO_4421_VAL.txt
281	Batch-Teradata/Salidas/BATCH_VALFORM_ST1
659	Batch-Teradata/Salidas/CON_DATOS_4421_20240902100353.CSV
2215	Batch-Teradata/Salidas/CON_DATOS_4421_20240902100353.ESQUEMA
158	Batch-Teradata/Salidas/INCONSISTENCIA_4421_20240902100353.CSV
274	Batch-Teradata/Salidas/INCONSISTENCIA_4421_20240902100353.ESQUEMA
266	Batch-Teradata/Salidas/SIN_DATOS_4421_20240902100353.CSV
1008	Batch-Teradata/Salidas/SIN_DATOS_4421_20240902100353.ESQUEMA
18659	Batch-Teradata/Shell/sh-BATCH-VFORNOM
300860	Batch-Teradata/Sps_Batch.sql
93857	Batch-Teradata/_verif_f2_4_sql.py
```
