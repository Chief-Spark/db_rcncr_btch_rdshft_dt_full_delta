# Las 7 tablas `MAT_*` de Novedades — estructura

> **CORRECCIÓN 2026-10-20 (lectura del legado completo, `docs/legado_teradata/`).**
> Este documento se escribió sin `Novedad.sql` ni los scripts P0035. Dos cosas
> de abajo son falsas:
> - **El AS-IS no "sólo inserta y actualiza".** `111.BTQ:817-836` hace
>   `DELETE … ALL` de las siete `MAT_*` antes de cargar: cada corrida
>   reconstruye la foto completa. Las novedades reales salen de las vistas
>   `*_Delta` contra las copias `BK_*` (`120.TPT:455-602`).
> - **Latitud y longitud no son `VARCHAR(40)` en la tabla final.** Ese es el
>   tipo de transporte del TPT; la tabla guarda `DECIMAL(38,8)` (`130.TPT:603`).
>
> Detalle: `docs/ANALISIS_AS_IS_HOMOLOGACION.md` §6 y §10.

**Son el entregable del proceso P0035 Extractor Novedades.** 131 columnas en
total. Todo lo de abajo está tomado del legado, no inferido:

- **Tipos y orden:** `P0035_Extractor_Novedades_130.TPT:26-192`, bloques
  `DEFINE SCHEMA P0035_8` .. `P0035_14`.
- **Nombres expuestos:** las vistas `VU_*` de
  `P0035_Extractor_Novedades_111.BTQ:474-844`.
- **Grano del borrado:** los `DELETE` de `130.TPT` (línea citada en cada tabla).

**Dos cosas que hay que saber antes de leer las tablas:**

1. **`Severidad` NO es una columna de las `MAT_*`.** La calcula la vista de
   staging comparando contra la tabla viva (`120.TPT:174-175`) y vale 1 para
   alta o cambio, 2 para baja y −1 para «sin cambio»; el TPT descarta los −1
   (`130.TPT:215`). Por eso cada esquema del TPT tiene **una columna más** que
   su tabla destino.
2. **Equivalencia de tipos Teradata → Redshift:** `BYTEINT` → `SMALLINT`
   (Redshift no tiene entero de un byte). Lo demás es 1:1.

3. **En `MAT_INFO_UBICACION` el borrado NUNCA OCURRE, aunque la columna
   «Grano del `DELETE`» diga `ID`.** `Severidad = 2` sale únicamente de
   `WHEN STG.FLAG_OP = 'E' THEN 2` (`120.TPT:163`), y `FLAG_OP = 'E'` es código
   muerto: la etapa 1 anti-une `V_BLOQUEO` (`Novedad.sql:7590-7594`) y la
   etapa 9 vuelve a unir esa misma tabla por esa misma llave para preguntar
   por `FECHA_BLOQUEO` (`:8393`), que por tanto es siempre NULL. ~~El AS-IS de
   Ubicación sólo inserta y actualiza.~~ **[Corregido: el `DELETE` por `ID`
   no se ejecuta, pero `111.BTQ:817-836` vacía la tabla entera antes de cada
   carga.]** La columna del resumen describe la
   llave que el `DELETE` usaría, no que llegue a ejecutarse; para los otros
   seis dominios está sin verificar.

---

## Resumen

| # | Tabla | Cols | SP que la produce | Tabla `TMP_*` de origen | Grano del `DELETE` |
|---|---|---|---|---|---|
| 1 | `MAT_INFO_UBICACION` | **42** | `PRO_Novedad_Linea_Ubicacion` | `TMP_UBICA_ETAPA_9` | `ID` (`130.TPT:703`) |
| 2 | `MAT_INFO_ACTIVIDAD_ECONOMICA` | **8** | `PRO_Novedad_Linea_Historial` | `TMP_PERS_ACTIVIDAD_ECONOMIC` | `ID` (`:755`) |
| 3 | `MAT_INFO_BASICA` | **22** | `PRO_Novedad_Linea_Info_Basica` | `TMP_INBAS_ETAPA_10` | `ID` (`:847`) |
| 4 | `MAT_INFO_CONTACTABILIDAD` | **12** | `PRO_Novedad_Linea_Contact` | `TMP_HIST_ETAPA_7` | `ID` + `SECTOR` + `UBICACION_ID` (`:912-915`) |
| 5 | `MAT_INFO_MOVILIDAD` | **8** | `PRO_Novedad_Linea_Indic_Movilidad` | `TMP_MOVIL_ETAPA_2` | `ID` (`:965-966`) |
| 6 | `MAT_INFO_PUNTO_INTERES` | **10** | `PRO_Novedad_Linea_Punto_Interes` | `TMP_PINTER_ETAPA_2` | `ID` + `UBICACION_ID` (`:1022`) |
| 7 | `MAT_UBICACION_AGREGADA` | **29** | `PRO_Novedad_Linea_Ubi_Agregada` | `TMP_AGR_ETAPA_FINAL` | compuesto de 7 columnas (`:1138-1145`) |

> **Ojo con la nomenclatura del legado, que está cruzada.**
> `MAT_INFO_ACTIVIDAD_ECONOMICA` la produce el SP **`_Historial`**, y
> `MAT_INFO_CONTACTABILIDAD` se alimenta de `TMP_HIST_ETAPA_7`, que produce
> **`_Contact`**. Los nombres `TMP_HIST_*` no corresponden al SP que se
> adivina. Para portar hay que seguir el `120.TPT`, no los nombres.

---

## 1. `MAT_INFO_UBICACION` — 42 columnas

`130.TPT:28-71`. Es la única portada: `bdm_datos.mat_info_ubicacion`
(`strct/.../30_ddl_novedades.sql`).

| # | Columna | Tipo | Nota |
|---|---|---|---|
| 1 | `Cod_Tipo_Ident_Fte` | VARCHAR(20) | |
| 2 | `TIPO_IDENTIFICACION` | VARCHAR(30) | homologada; **bloqueada**, falta `V_Hom_Tip_Ident_Linea` |
| 3 | `NUMERO_IDENTIFICACION` | BIGINT | |
| 4 | `ID` | BIGINT | `Cod_DW_Persona_Ubic`. Es la llave del *upsert* y del borrado |
| 5 | `ORDEN` | INTEGER | `Orden_Prioridad`, lo escribe el Ordenamiento |
| 6 | `INDICATIVO` | VARCHAR(20) | **bloqueada**, falta `V_TELEFONO_FIJO` |
| 7 | `DATO` | VARCHAR(201) | texto de ubicación; en las geográficas, texto + complemento |
| 8 | `ESTRATO` | VARCHAR(10) | **bloqueada**, contrato GEO sin pinar |
| 9 | `TIPO` | VARCHAR(30) | **bloqueada**, falta `V_Hom_TipoUbic_Dir_Linea` |
| 10 | `ZONA` | VARCHAR(30) | **bloqueada**, faltan `V_ZONA_UBICACION` y `V_Hom_Zona_Linea` |
| 11 | `CIUDAD` | VARCHAR(30) | |
| 12 | `DEPARTAMENTO` | VARCHAR(30) | |
| 13 | `LONGITUD` | VARCHAR(40) | tipo de transporte del TPT; la tabla final es `DECIMAL(38,8)` (`130.TPT:603`) |
| 14 | `LATITUD` | VARCHAR(40) | ídem |
| 15 | `REPORTADO_DESDE` | INTEGER | **NULL literal** por esta ruta |
| 16 | `ULTIMO_REPORTE` | INTEGER | **NULL literal** por esta ruta |
| 17 | `FUENTE` | INTEGER | **NULL literal** por esta ruta |
| 18 | `NUMERO_REPORTES` | BYTEINT | **0 literal** por esta ruta |
| 19 | `NUMERO_ENTIDADES` | BYTEINT | **0 literal** por esta ruta |
| 20 | `BARRIO` | VARCHAR(100) | **bloqueada**, contrato GEO sin pinar |
| 21 | `LOCALIDAD` | VARCHAR(100) | **bloqueada**, sin columna de origen |
| 22 | `CODIGO_POSTAL` | VARCHAR(20) | **bloqueada**, sin columna de origen |
| 23 | `CLASE` | VARCHAR(5) | `DIR` / `TEL` / `CEL` / `EMAIL` |
| 24 | `INFO_BASICA` | INTEGER | `Id_Buro_Persona`; FK lógica a `MAT_INFO_BASICA` |
| 25 | `CODIGO_DANE` | VARCHAR(20) | `COALESCE(..., '-1')` |
| 26-33 | `ES_TIPO_CRR` `_RES` `_PPL` `_AGN` `_SUC` `_EST` `_CDI` `_LAB` | VARCHAR(1) | sólo CRR, RES y LAB se calculan; las otras cinco son **NULL literal** |
| 34 | `TIPO_CUENTA` | VARCHAR(1) | **bloqueada**, falta `V_TIPO_CORREO` |
| 35 | `Cod_DW_Ubic` | BIGINT | |
| 36 | `Cod_DW_Direccion_Fisica` | BIGINT | |
| 37 | `Cod_DW_Telefono` | BIGINT | sin origen en `edf_views` |
| 38 | `Cod_DW_Direccion_Electronica` | BIGINT | sin origen en `edf_views` |
| 39 | `Ind_Unificacion` | INTEGER | |
| 40 | `Cod_DW_Tipo_Ubicacion_Dir` | INTEGER | |
| 41 | `Cod_Pin_Persona` | INTEGER | |
| 42 | `FLAG_OP` | BYTEINT | **1 = alta, 2 = cambio, 3 = baja** (`120.TPT:169-173`) |

**Las cinco columnas en blanco (15-19) no son un defecto del port.** El legado
las emite como literales (`Novedad.sql:8358-8363`); sus valores reales se
calculan en `TMP_UBICA_ETAPA_2`, que esta ruta no consume — esa etapa existe
sólo para alimentar a `Ubi_Agregada`. Es divergencia funcional, elevada.

---

## 2. `MAT_INFO_ACTIVIDAD_ECONOMICA` — 8 columnas

`130.TPT:76-88`. Vista expuesta: `VU_Historial` (`111.BTQ:603-640`).

| # | Columna | Tipo |
|---|---|---|
| 1 | `ID` | INTEGER |
| 2 | `CIIU` | VARCHAR(20) |
| 3 | `ACTIVIDAD_ECONOMICA` | VARCHAR(500) |
| 4 | `VERSION` | INTEGER |
| 5 | `FECHA_REPORTE` | VARCHAR(8) |
| 6 | `INFO_BASICA_ID` | INTEGER |
| 7 | `TIPO_IDENTIFICACION` | VARCHAR(30) |
| 8 | `NUMERO_IDENTIFICACION` | BIGINT |

---

## 3. `MAT_INFO_BASICA` — 22 columnas

`130.TPT:90-114`. Vista expuesta: `VU_InBas` (`111.BTQ:489-545`).

| # | Columna | Tipo | Nota |
|---|---|---|---|
| 1 | `COD_PIN_PERSONA` | INTEGER | |
| 2 | `ID` | INTEGER | |
| 3 | `PRIMER_NOMBRE` | VARCHAR(100) | |
| 4 | `SEGUNDO_NOMBRE` | VARCHAR(100) | |
| 5 | `PRIMER_APELLIDO` | VARCHAR(100) | |
| 6 | `SEGUNDO_APELLIDO` | VARCHAR(100) | |
| 7 | `NOMBRE_COMPLETO` | VARCHAR(200) | |
| 8 | `COD_TIPO_IDENT_FTE` | VARCHAR(20) | |
| 9 | `TIPO_IDENTIFICACION` | VARCHAR(30) | |
| 10 | `NUMERO_IDENTIFICACION` | BIGINT | |
| 11 | `ESTADO_DOCUMENTO` | VARCHAR(20) | |
| 12 | `RANGO_EDAD` | VARCHAR(25) | |
| 13 | `LUGAR_EXPEDICION` | VARCHAR(100) | |
| 14 | `FECHA_EXPEDICION` | VARCHAR(8) | |
| 15 | `GENERO` | VARCHAR(508) | el ancho es del legado |
| 16 | `CIIU` | VARCHAR(20) | |
| 17 | `ACTIVIDAD_ECONOMICA` | VARCHAR(500) | |
| 18 | `RAZON_SOCIAL` | VARCHAR(500) | |
| 19 | `PAGINA_WEB` | VARCHAR(100) | |
| 20 | `MOSAIC_ID` | INTEGER | **fuera de alcance** por decisión legal |
| 21 | `DEPARTAMENTO_EXPEDICION` | VARCHAR(100) | |
| 22 | `RUT` | VARCHAR(1) | |

> Es la única tabla a la que afecta la decisión pendiente de Mosaic: el
> predicado `COD_DW_GRUPO_MOSAIC>0 OR COD_DW_TIPO_GRUPO_MOSAIC>0` aparece
> **una sola vez en todo `Novedad.sql`**, en `:2482`, dentro de
> `PRO_Novedad_Linea_Info_Basica`. No toca Ubicación.

---

## 4. `MAT_INFO_CONTACTABILIDAD` — 12 columnas

`130.TPT:116-130`. Vista expuesta: `VU_Contact` (`111.BTQ:552-596`).

| # | Columna | Tipo |
|---|---|---|
| 1 | `ID` | BIGINT |
| 2 | `CONTACTABILIDAD` | VARCHAR(2) |
| 3 | `FECHA_ULTIMO_CONTACTO` | VARCHAR(32) |
| 4 | `Fecha_Gestion` | VARCHAR(32) |
| 5 | `MEJOR_DIA_GESTION` | VARCHAR(9) |
| 6 | `MEJOR_HORA_GESTION` | VARCHAR(13) |
| 7 | `REPORTADO_POR` | INTEGER |
| 8 | `SECTOR` | VARCHAR(100) |
| 9 | `UBICACION_ID` | BIGINT |
| 10 | `PESO` | FLOAT |
| 11 | `MEJOR_RESULTADO_3MESES` | VARCHAR(100) |
| 12 | `MEJOR_RESULTADO_6MESES` | VARCHAR(100) |

> **Siete de las doce son datos de gestión que no vienen del datashare.** Es
> la tabla con mayor dependencia externa de las siete.

---

## 5. `MAT_INFO_MOVILIDAD` — 8 columnas

`130.TPT:132-144`. Vista expuesta: `VU_Ind_Movil` (`111.BTQ:649-680`).

| # | Columna | Tipo |
|---|---|---|
| 1 | `ID` | INTEGER |
| 2 | `FECHA` | VARCHAR(8) |
| 3 | `DESCRIPCION` | VARCHAR(100) |
| 4 | `NOVEDAD` | VARCHAR(1000) |
| 5 | `INFO_BASICA_ID` | INTEGER |
| 6 | `NOVEDAD_2` | VARCHAR(30) |
| 7 | `TIPO_IDENTIFICACION` | VARCHAR(30) |
| 8 | `NUMERO_IDENTIFICACION` | BIGINT |

> Depende íntegra del proceso **P0029 Indicadores de Movilidad**, cuya
> migración está pendiente.

---

## 6. `MAT_INFO_PUNTO_INTERES` — 10 columnas

`130.TPT:146-159`. Vista expuesta: `VU_Punto_Inter` (`111.BTQ:690-725`).

| # | Columna | Tipo | Nota |
|---|---|---|---|
| 1 | `ID` | BIGINT | |
| 2 | `NOMBRE` | VARCHAR(200) | **falta origen**: el contrato de distancias no persiste `nombre_punto_interes` |
| 3 | `DISTANCIA` | INTEGER | metros |
| 4 | `Descripcion_Tipo_Punto_Interes` | VARCHAR(1000) | |
| 5 | `UBICACION_ID` | BIGINT | |
| 6 | `NOMBRE_ENTIDAD` | VARCHAR(1000) | |
| 7 | `NIT_ENTIDAD` | VARCHAR(20) | |
| 8 | `LATITUD` | VARCHAR(40) | |
| 9 | `LONGITUD` | VARCHAR(40) | |
| 10 | `TIPO` | VARCHAR(30) | |

> El origen en Redshift es `bdm_datos.geo_distancias`, que persiste 11 de las
> 12 columnas del contrato. La que falta es justo `nombre_punto_interes`.

---

## 7. `MAT_UBICACION_AGREGADA` — 29 columnas

`130.TPT:161-192`. Vista expuesta: `Vu_Agrupa_Ubica` (`111.BTQ:760-812`), que
expone 26 de las 29.

| # | Columna | Tipo |
|---|---|---|
| 1 | `TIPO_IDENTIFICACION` | VARCHAR(30) |
| 2 | `NUMERO_IDENTIFICACION` | BIGINT |
| 3 | `INFO_BASICA` | INTEGER |
| 4 | `CODIGO_DANE` | VARCHAR(20) |
| 5 | `CIUDAD` | VARCHAR(30) |
| 6 | `DEPARTAMENTO` | VARCHAR(30) |
| 7 | `UBICACION_DATO` | VARCHAR(201) |
| 8 | `UBICACION_REPORTDESDE` | VARCHAR(8) |
| 9 | `UBICACION_ULTREPORTE` | VARCHAR(8) |
| 10 | `UBICACION_NUMENTIDADES` | INTEGER |
| 11 | `UBICACION_NUMREPORTES` | INTEGER |
| 12 | `UBICACION_CLASE` | VARCHAR(5) |
| 13 | `UBICACION_TIPOCUENTA` | VARCHAR(1) |
| 14 | `UBICACION_ORDEN` | INTEGER |
| 15 | `UBICACCION_INDICATIVO` | VARCHAR(20) |
| 16 | `UBICACION_ESTRATO` | VARCHAR(10) |
| 17 | `UBICACION_ZONA` | VARCHAR(30) |
| 18 | `UBICACION_CIUDAD` | VARCHAR(30) |
| 19 | `UBICACION_DEPARTAMENTO` | VARCHAR(30) |
| 20 | `UBICACION_CODIGODANE` | VARCHAR(20) |
| 21 | `UBICACION_BARRIO` | VARCHAR(100) |
| 22 | `UBICACION_LOCALIDAD` | VARCHAR(100) |
| 23 | `UBICACION_CODIGOPOSTAL` | VARCHAR(20) |
| 24 | `UBICACION_LONGITUD` | VARCHAR(40) |
| 25 | `UBICACION_LATITUD` | VARCHAR(40) |
| 26 | `TIPO` | VARCHAR(30) |
| 27 | `FUENTE` | VARCHAR(30) |
| 28 | `ID` | VARCHAR(1000) |
| 29 | `COD_PAIS` | VARCHAR(3) |

> **`UBICACCION_INDICATIVO` lleva la errata en el legado.** Se porta tal cual:
> es el nombre del contrato.
>
> **Y su `ID` no es una llave.** Es `IDS_UBICACIONES_ORIGEN`, un VARCHAR(1000)
> con la lista de ubicaciones que se agregaron. Por eso el borrado es
> compuesto de siete columnas (`130.TPT:1138-1145`): `INFO_BASICA`,
> `TIPO_IDENTIFICACION`, `NUMERO_IDENTIFICACION`, `UBICACION_DATO`,
> `UBICACION_CODIGODANE`, `UBICACION_CIUDAD` y `UBICACION_DEPARTAMENTO`.
> Portarlo como `DELETE ... WHERE ID` corrompe la tabla en silencio.

---

## El patrón de recarga, que no es obvio y hay que decidir

El AS-IS no actualiza las `MAT_*` en caliente: hace un **blue/green de
lectura**.

1. `111.BTQ:474-844` clona las 7 tablas en `BK_*`, reapunta las 7 vistas
   `VU_*` a los clones y **vacía las originales** (`DELETE ... ALL`).
2. El `130.TPT` recarga las originales desde las vistas de staging.
3. `140.BTQ:108-410` devuelve las vistas `VU_*` a las tablas vivas y
   `:804-851` vacía las `BK_*`.

Durante la ventana de recarga, quien consulta las `VU_*` lee el clon. **El
TO-BE necesita un equivalente** — `ALTER TABLE ... RENAME`, vistas tardías, u
otra cosa — y esa decisión está abierta (`NOV-G-03` del tablero).

---

## Qué está portado hoy

| Tabla | Estado |
|---|---|
| `MAT_INFO_UBICACION` | **portada**: `bdm_datos.mat_info_ubicacion` y su espejo `_mock`. 11 criterios en PASSED, 0 en FAILED |
| Las otras seis | `NO_IMPLEMENTADO` en el tablero — visibles, no ausentes |

El orden de portado no es libre: **`Ubi_Agregada` va la última**, porque
consume las dos salidas de `Ubicacion` en once puntos.
