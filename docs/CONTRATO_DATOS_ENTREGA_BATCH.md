# Contrato de datos: lo que Reconocer entrega al Batch

Versión 0.1 · 2026-10-20 · estado **BORRADOR**. Se cierra cuando llegue el contenido de `BATCH2_HOMOLOGACION`.

## Qué es esto

El Batch (P0033 BATCH2) no lee las tablas de Reconocer. Lee **siete cubos** (`BATCH_CUBO_*`) que en Teradata arma `P0032_BATCH_GENERACUBO`, y ese script **no está en el material**. Este contrato dice qué columna de cada cubo entregamos desde Redshift: qué significa, de dónde sale y cuánta evidencia tenemos.

**Nuestro límite es el cubo.** Los filtros, las plantillas y los archivos CON_DATOS, SIN_DATOS e INCONSISTENCIA son del Batch y quedan fuera de alcance.

## Cómo leer las tablas

**Grado de la traza al AS-IS:**

| Grado | Significado |
|---|---|
| **CONFIRMADO** | el código lo muestra |
| **PROBABLE** | mismo nombre, semántica o formato |
| **HIPÓTESIS** | sin rastro directo |

Ninguna columna está CONFIRMADA de punta a punta, porque falta `GENERACUBO`.

**Estado en Redshift:**

| Estado | Significado |
|---|---|
| **OK** | ya fluye bien |
| **CORREGIR** | se lee, pero mal |
| **CONECTAR** | está en EDF y no lo leemos |
| **DERIVAR** | se calcula a partir de un dato existente |
| **PEDIR** | no está en EDF; hay que pedirlo al productor |
| **NULL** | se entrega vacío de forma explícita y documentada |

**Prefijos:**
- `ci.` = `edf_views.xpm_location_val_contactinformations."location.val.contactinformations.val.…"`
- `loc.` = `edf_views.xpm_location."location.val.…"`
- `bid.` = `edf_views.xpm_bestidentifications."bestidentifications.val.…"`
- `xpm.` = `edf_views.xpm`

Evidencia AS-IS en `docs/legado_teradata/`: `SPS` = `batch/Sps_Batch.sql`, `CE120` = `batch/P0033_BATCH2_CUBOEXPORT_120.BTQ`, `NOV` = `reconocer/novedades/DB/Novedad.sql`.

## Reglas comunes a los cubos de ubicación

| Regla | Evidencia | Qué entregamos |
|---|---|---|
| **Un cubo por canal:** DIRECCION, TELEFONO, CELULAR, CORREO | `SPS:5416-5796` | una vista por canal |
| **Grano:** persona × ubicación (`Cod_DW_Persona_Ubic`) | `SPS:5416` | RPU = contacto. **Llave por confirmar**: `(id, index)` de `ci` (D-UNI-02) |
| **`Orden_Prioridad` = lugar dentro del canal**, un valor por RPU; si es NULL, el Batch descarta la fila | `CE120:134,391,637,894`; `SPS:4124`; RF CA-F01 | **CORREGIR** (D-ORD-10): hoy es `MIN(lugar)` entre canales |
| Posición `00n` = `ROW_NUMBER` por persona ordenado por `Orden_Prioridad`, fecha descendente, … | `CE120` | lo calcula el Batch; nosotros entregamos `Orden_Prioridad` y la fecha |
| Solo contactos **vigentes**: no bloqueados (D-EDF-01) y no hijos de Unificación | `NOV:7590-7595` | filtro en la vista |
| Formatos de la salida real: fecha `dd/mm/aaaa`, DANE de 8 dígitos, tipo multivalor `RES - LAB - CRR` | `legado_teradata/salida_real_esencial/` | el formato final lo aplica el Batch; entregamos `DATE` y códigos en texto |


### Qué `contacttype` alimenta cada cubo (medido en DEV y QA, 2026-10-20)

Lo decide la columna `canal` de `v_xpm_contacto_canal`. Evidencia en `edf_views/RESULTADOS_CONSULTAS_EDF.md` §14-§15.

| Cubo | `contacttype` | Forma del dato | Grado |
|---|---|---|---|
| DIRECCION | 1, 2, 3, 7, 8 | texto de dirección; el 8 con `standardizedtipo` VIA, RURAL, MANZANA… | PROBABLE (falta el catálogo; el 8 es CONFIRMADO por su `standardizedtipo`) |
| TELEFONO | 4, 5 y el 6 sin forma de celular | 12 dígitos rellenados con ceros (4, 5) o limpio (6). **Se entrega sin el relleno** | PROBABLE |
| CELULAR | 9 y el 6 con forma de celular (10 dígitos que empiezan por 3) | igual: **sin el relleno** | PROBABLE |
| CORREO | 10 | el 100 % con `@` | CONFIRMADO por la forma |
| — | 11 | vacío | no se lee |

---

## BATCH_CUBO_PERSONA · una fila por persona

| Columna del cubo | Campo en la salida | Qué significa | Origen AS-IS | Grado | EDF | Estado |
|---|---|---|---|---|---|---|
| `Id_Buro_Persona` | — | llave interna de la persona | `VU_PERSONA` | CONFIRMADO (dominio) | `FNV_HASH(xpm.pin)` | OK (sintética) |
| `Cod_Pin_Persona` | — | PIN de la persona | `RPU.Cod_Pin_Persona` | PROBABLE | `xpm.pin` | OK |
| `Tipo_Id` | `DB_TIP_ID` | tipo de documento (1 CC, 2 NIT, 3 PJE, 4 CE, …) | `VU_PERSONA.COD_TIPO_IDENT_FTE` | CONFIRMADO (dominio) | `bid.personidtype` (ID Type NH) | CONECTAR · ojo: el Batch lo trunca a 1 carácter (`SPS:1272`), así que el 10 (RC) colisiona con el 1 |
| `Numero_Id` | `DB_NUM_ID` | número de documento | `VU_PERSONA.NUM_IDENT` | PROBABLE | `bid.personidnumber` | CONECTAR · **no es el PIN** |
| `Primer_Apellido` / `Segundo_Apellido` | `DP_PRI_APE` / `DP_SEG_APE` | apellidos | `VU_PERSONA` (registro más confiable) | PROBABLE | `xpm."bestname.firstlastname"` / `secondlastname` | CONECTAR |
| `Primer_Nombre` / `Segundo_Nombre` | `DP_PRI_NOM` / `DP_SEG_NOM` | nombres | ídem | PROBABLE | `xpm."bestname.firstname"` / `secondname` | CONECTAR |
| `Nombre_Completo` | `DB_NOM_COM` | nombre completo o razón social | `MAT_INFO_BASICA.NOMBRE_COMPLETO` / `RAZON_SOCIAL` | PROBABLE | `xpm."bestname.fullname"` | CONECTAR |
| fecha de expedición | `DP_FEC_EXP` | fecha de expedición del documento | `VU_PERSONA.FECHA_EXPEDICION` | PROBABLE | `bid.issuedate` (epoch) | CONECTAR |
| ciudad de expedición | `DP_CIU_EXP` | ciudad de expedición | `V_JERARQUIA_GEOGRAFICA.NOMBRE_CIUDAD` | PROBABLE | `bid.issuingcityname` | CONECTAR |
| departamento de expedición | `DP_DEP_EXP` | departamento de expedición | `V_JERARQUIA_GEOGRAFICA.NOMBRE_DEPARTAMENTO` | PROBABLE | `bid.issuingstatename` | CONECTAR |
| `GENERO` | `DP_GENERO` | `M` / `F` | `V_GENERO.COD_GENERO_FTE`, primera letra | PROBABLE | `xpm."bestpersonalinformation.gender"` (bigint) | CONECTAR + **PEDIR el catálogo de códigos** |
| `RANGO_EDAD` | `DP_RAN_EDA` | `'36-45'`, `'66+'` | `V_RANGO_EDAD` | PROBABLE | `xpm."bestpersonalinformation.agerange"` | CONECTAR · comparar el formato (C9) |
| `CIIU` | `DB_CIIU` | ver cubo CIIU | — | — | — | — |
| `CATEGORIA_DE_INGRESOS` / `EGRESOS` | según plantilla | categoría de ingresos o egresos | no existe en Reconocer | HIPÓTESIS | `xpm_personalinformation."…income"` / `"…liabilities"` | PEDIR los catálogos `V_CATEGORIA_INGRESO` / `EGRESO` |

## BATCH_CUBO_CIIU · persona × CIIU

**Un CIIU válido basta para que la persona sea CON_DATOS** (`SPS:3812-3849`).

| Columna | Campo | Qué significa | Origen AS-IS | Grado | EDF | Estado |
|---|---|---|---|---|---|---|
| `CIIU` | `DB_CIIU` | código de actividad económica | `MAT_INFO_ACTIVIDAD_ECONOMICA.CIIU` (todas las actividades, `NOV:1288-1291`) | PROBABLE | principal: `xpm."bestpersonalinformation.mainisiccodeforproduct"`; secundarios: `xpm_personalinformation."…secondaryisiccode1..4"`, `xpm_chamberofcommerce` | CORREGIR (D-NOV-06) |
| `Actividad_Economica` | `DB_ACT_ECO` | descripción del CIIU | `V_ACTIVIDAD_ECONO_CIIU.DESC_ACT_ECONO_CIIU` | PROBABLE | principal: `xpm."bestpersonalinformation.productmainisicdescription"` | CONECTAR · **PEDIR `V_ACTIVIDAD_ECONO_CIIU`** para los secundarios |
| `Version` | — | versión de la codificación CIIU | `VERSION_CODIFICACION_CIIU` | PROBABLE | — | PEDIR (mismo catálogo) |
| `FECHA_REPORTE` | — | inicio de la relación o fecha de matrícula | `COALESCE(FECHA_INICIO_RELACION, Fecha_Matricula)` (`NOV:1282`) | PROBABLE | `xpm_personalinformation."…firsteventdate"`; `xpm_chamberofcommerce."…dateofmercantileregistration"` | CONECTAR |
| `FECHA_ACTUALIZACION` | — | la usa la posición (`RANK` por fecha descendente, `CE120:1134`) | no está en `MAT` | HIPÓTESIS | `xpm_personalinformation."…eventdatelastupdated"` | HIPÓTESIS |

## BATCH_CUBO_DIRECCION · persona × dirección

| Columna | Campo | Qué significa | Origen AS-IS | Grado | EDF | Estado |
|---|---|---|---|---|---|---|
| `Cod_DW_Persona_Ubic` | — | llave del contacto (RPU) | `RPU.Cod_DW_Persona_Ubic` | PROBABLE | `ci.id` + `ci.index` | CORREGIR (D-UNI-02) |
| `Direccion` | `DD_DIR` | dirección estandarizada + complemento | `TEXTO_UBICACION ‖ ' ' ‖ COMPLEMENTO` (`NOV:7772`) | PROBABLE | `ci.standardizedtextoubicacion` + `ci.standardizedcomplemento` | OK · solo direcciones **padre** (Unificación) |
| `Ciudad` | `DD_CIUDAD` | nombre del centro poblado | `V_GEOGRAFIA.DESCRIPCION_CIUDAD` | PROBABLE | DANE → Divipola; sin DANE: `citycode` (cabecera) o el nombre contra Divipola | DERIVAR: el código ya sale en `cod_dw_ciudad` (D-EDF-02, corregido en local); el nombre se toma de Divipola en la vista de entrega (F7) |
| `Departamento` | `DD_DEPARTA` | departamento | `V_GEOGRAFIA.DESCRIPCION_DEPARTAMENTO` | PROBABLE | `ci.standardizeddepartment` / DANE State Code | OK |
| `Cod_Dane_Ciudad` | `DD_DAN_CIU` | DANE de 8 dígitos, en texto | `V_GEOGRAFIA.COD_DANE_CIUDAD` | PROBABLE | `ci.standardizeddanecode` con relleno a 8 | CORREGIR (D-EDF-02) |
| `Cod_Dane_Departamento` | `DD_DAN_DEP` | DANE de 2 dígitos | `V_GEOGRAFIA` | PROBABLE | primeros 2 dígitos del de 8 | DERIVAR |
| `Tipo` | `DD_TIPO` | tipos del contacto, multivalor `RES - LAB - CRR` | `V_Hom_TipoUbic_Dir_Linea` + la cadena de Agregada (`NOV:5972-5977`) | PROBABLE | `ci.contacttype` | PEDIR el catálogo `contacttype` (D-EDF-06) |
| `Zona` | `DD_ZONA` | `URB` / `RUR` | `V_ZONA_UBICACION` + `V_Hom_Zona_Linea` | PROBABLE | — | PEDIR |
| `Estrato` | `DD_ESTRATO` | `0`-`6` | `V_ESTRATO_DIRECCION` | PROBABLE | `loc.stratum` (del reporte) | CONECTAR |
| `Barrio` | según plantilla | barrio | `RELACION_UBICAC_ESTANDAR_GEO.URBANIZACION_BARRIO` | PROBABLE | `ci.contactneighborhood` | CONECTAR |
| `Localidad` | según plantilla | localidad o comuna | `…LOCALIDAD_COMUNA` | PROBABLE | `ci.contactburroughs` | CONECTAR |
| `Fecha_ultima_actualizacion` | `DD_ULT_ACT` | último reporte del dato | `MAX(FECHA_REPORTE)` (`NOV:8637`) | PROBABLE | `ci.contacteventlastupdated` / `loc.cutoffdate` | OK · sin caer a la fecha de hoy (D-EDF-04) |
| `Numero_de_entidades_reporta` | `DD_ND_ENT_` | suscriptores distintos que reportan el dato | `COUNT(DISTINCT Id_Buro_Suscriptor)` (`NOV:8505`) | PROBABLE | `COUNT(DISTINCT loc.counterpartyidnumber)` | CORREGIR (D-EDF-03) |
| `Fuente` | según plantilla | `SUS` / `CIU` / `CAM` | `V_FUENTE` o `'CAM'` | PROBABLE | — | PEDIR (D-NOV-03) |
| `Orden_Prioridad` | (posición) | lugar en el canal DIR | Ordenamiento | PROBABLE | Ordenamiento DIR | CORREGIR (D-ORD-10) |
| `Contactabilidad`, `Medio_Acceso`, `Mejor_dia/hora`, `Mejor_Resultado_3/6Meses`, `Reportado_por` | según plantilla | gestión de contacto | `MAT_INFO_CONTACTABILIDAD` | PROBABLE | **no existe** en `edf_views` (verificado) | PEDIR · NULL mientras tanto |
| `Reportado_por_el_Suscriptor`, `Meses_desde_el_ultimo_Reporte` | filtros del Batch | si lo reportó el solicitante; meses desde el último reporte | sin rastro en Reconocer | HIPÓTESIS | `loc.counterpartyidnumber`, `loc.cutoffdate` | DERIVAR cuando se confirme la regla |

## BATCH_CUBO_TELEFONO · persona × teléfono fijo

Mismas reglas que DIRECCION, con estas diferencias:

| Columna | Campo | Origen AS-IS | Grado | EDF | Estado |
|---|---|---|---|---|---|
| `Numero` | `DT_NUM` | `TEXTO_UBICACION` de tipo Teléfono | PROBABLE | `ci.contactasreported` (el estandarizado viene vacío), tipos 4, 5 y 6 fijo, sin el relleno de ceros | OK en local (D-EDF-08, -10 y -11); el catálogo `contacttype` lo confirmaría |
| `Indicativo` | según plantilla | `V_TELEFONO_FIJO.COD_AREA` (`NOV:7966`) | PROBABLE | — | PEDIR |
| `Tipo` | `DT_TIPO` | `RES` / `LAB` (`RES - LAB`) | PROBABLE | `ci.contacttype` | PEDIR |
| `Ciudad`, `Departamento`, `Cod_Dane_*`, `Fecha_ultima_actualizacion`, `Numero_de_entidades_reporta` | `DT_*` | igual que DIRECCION | PROBABLE | igual | igual |

## BATCH_CUBO_CELULAR y BATCH_CUBO_CORREO

| Cubo.Columna | Campo | Origen AS-IS | Grado | EDF | Estado |
|---|---|---|---|---|---|
| CELULAR.`Numero` | `DC_NUMERO` | `TEXTO_UBICACION` de tipo Celular | PROBABLE | `ci.contactasreported`, tipos 9 y 6 con forma de celular, sin el relleno de ceros | OK en local (D-EDF-10 y -11) · **sale del celular, nunca del correo** (error del prototipo) |
| CORREO.`Correo` | `CE_CORREO` | `TEXTO_UBICACION` de tipo Mail | PROBABLE | `contacttype` 10 (100 % con `@`) | OK |
| `Orden_Prioridad` | (posición) | Ordenamiento CEL / EMA, **por RPU** | PROBABLE | Ordenamiento | CORREGIR (D-ORD-10) |
| `Fecha_ultima_actualizacion`, `Numero_de_entidades_reporta` | — | igual que DIRECCION | PROBABLE | igual | igual |

## BATCH_CUBO_PUNTO_INTERES_DIR · persona × dirección × punto de interés

| Columna | Origen AS-IS | Grado | EDF / Redshift | Estado |
|---|---|---|---|---|
| `COD_DW_UBIC` | `V_RELACION_UBICACION_PUNTO_INT` (`NOV:4793-4809`) | PROBABLE | `geo_distancias.cod_dw_ubic` | OK cuando GEO funcione |
| `Cod_DW_Ubic_Punto_Interes` | ídem | PROBABLE | `geo_distancias` (código host) | CORREGIR: falta el nombre del punto de interés (D-EDF-05) |
| `DISTANCIA` | `Distancia_Punto_Interes` (`P0013_STAGEDISTANCIASGEO_100.TPT:119`) | PROBABLE | `geo_distancias` | OK cuando GEO funcione |

## INCONSISTENCIA · fuera de Reconocer

Las 11 columnas (`ID_SOLICITUD` … `CAUSAL`) salen de la validación de identidad del propio Batch (`PRO_BATCH_VALNOMBRE`, P0037, que no está en el material) y de `ADICIONAR_INCON` (`SPS:6066-6140`). **Reconocer no las produce.** Solo aportamos el universo de personas encontradas, el cubo PERSONA, para que el Batch marque como inconsistentes las que no aparecen.

## Lo que cierra este contrato

1. **`BATCH2_HOMOLOGACION`** (pendiente de tu lado): confirma qué columna del cubo alimenta cada campo y sube los grados.
2. **Catálogos:** `contacttype`, género, `V_ACTIVIDAD_ECONO_CIIU`, zona, indicativo, fuente, categorías de ingreso y egreso.
3. **Consultas C4, C6, C9 a C11** (`edf_views/consultas_perfilado_edf_2026-10-20.sql`): llave, DANE, formatos y llenado.
4. **Contactabilidad:** pedir al productor.
