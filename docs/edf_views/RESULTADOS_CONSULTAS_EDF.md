# Resultados de las consultas a `edf_views`

Las consultas se corren en el consumidor DEV (`dba_batch_DEV`), solo en modo lectura. Aquí se registran los metadatos y los conteos agregados; ningún dato personal.

| Consulta | Fecha | Archivo con la salida |
|---|---|---|
| C1 · tablas (`svv_all_tables`) | 2026-10-20 | `svv_all_tables_2026-10-20.csv` (104 objetos: 35 tablas y 69 vistas `vw_biz_*`) |
| C2 · columnas (`svv_all_columns`) | 2026-10-20 | `svv_all_columns_2026-10-20.csv` (1.071 columnas) |
| C3 · búsqueda de contactabilidad | 2026-10-20 | se resolvió sobre C2 (ver §1) |
| C5 · dominio de `personidtype` | 2026-10-20 | §2 |
| C7 · bloqueo | 2026-10-20 | §3 |
| C4, C6, C8 a C14 | pendientes | `consultas_perfilado_edf_2026-10-20.sql` |

## 1. Lo que dice el catálogo

**Contactabilidad: no está en `edf_views`. Ya está verificado, ya no es supuesto.**
- En las 70 tablas y vistas con columnas visibles no hay ninguna de gestión, contacto efectivo, resultado, intento ni mejor día u hora. La búsqueda por `contact|gestion|effect|result|call|attempt|manage` solo encuentra el prefijo `contactinformations`.
- 34 vistas `vw_biz_*` no muestran columnas. Puede ser por permisos o por enlace tardío. Ninguna tiene nombre de contactabilidad: alerts, bureaumodels, inquiryfootprints, judicialinformation, dian, sisben, names_val_aka y otras.

**Consecuencia:** el dominio d5 de Novedades (Contactabilidad) y las columnas de gestión de los cubos (`Contactabilidad`, `Medio_Acceso`, `Mejor_dia/hora`, `Mejor_Resultado_3/6Meses`, `Reportado_por`) **hay que pedirlas al productor**, o salen NULL explícito.

**El catálogo sí trae muchos datos que el AS-IS saca de catálogos, de GEO o de `VU_PERSONA`.** Cambia lo que hay que pedir:

| Necesidad AS-IS | Teradata | Columna EDF encontrada | Grado | Nota |
|---|---|---|---|---|
| Barrio | `RELACION_UBICAC_ESTANDAR_GEO.URBANIZACION_BARRIO` | `xpm_location_val_contactinformations."…contactneighborhood"` | PROBABLE | llenado por medir (C11) |
| Localidad / comuna | `…LOCALIDAD_COMUNA` | `"…contactburroughs"` | PROBABLE | idem |
| Código postal | `…COD_POSTAL` | `"…contactzipcode"` | PROBABLE | idem |
| Estrato | `V_ESTRATO_DIRECCION` | `xpm_location."location.val.stratum"` | PROBABLE | es del reporte, no del contacto (C11) |
| Página web (Info Básica) | `PAGINA_WEB` | `"…contactinformations.val.website"` | PROBABLE | |
| Coordenadas | `RELACION_UBICAC_ESTANDAR_GEO` | **no existe** | — | GEO (ArcGIS) sigue siendo necesario, pero solo para latitud y longitud |
| Tipo y número de documento | `VU_PERSONA` | `xpm_bestidentifications."…personidtype"` / `"…personidnumber"` | PROBABLE | `best*` equivale al "registro más confiable" del AS-IS (`Vstg_BUROPERS_TMP`) |
| Fecha, ciudad y departamento de expedición | `VU_PERSONA`, `V_JERARQUIA_GEOGRAFICA` | `xpm_bestidentifications."…issuedate"`, `"…issuingcityname"`/`code`, `"…issuingstatename"`/`code` | PROBABLE | |
| Estado del documento | `VU_PERSONA.ESTADO_DOCUMENTO` | `"…idstatus"` / `"…businessidstatus"` | PROBABLE | dominio por medir (C10) |
| Nombres y nombre completo | `VU_PERSONA` | `xpm."bestname.firstname"`, `secondname`, `firstlastname`, `secondlastname`, `fullname` | PROBABLE | `xpm_names` trae todos los reportados |
| Género | `V_GENERO` | `xpm."bestpersonalinformation.gender"` (bigint) | PROBABLE | falta el catálogo de códigos (C9) |
| Rango de edad | `V_RANGO_EDAD` | `xpm."bestpersonalinformation.agerange"` | PROBABLE | comparar el formato con `36-45` (C9) |
| CIIU principal y descripción | `V_ACTIVIDAD_ECONO_CIIU` | `xpm."bestpersonalinformation.mainisiccodeforproduct"` + `"…productmainisicdescription"` | PROBABLE | **la descripción solo existe para el principal** |
| Todas las actividades (d2) | `VU_PERSONA_ACTIVIDAD_ECONOMICA` | `xpm_personalinformation."…mainisiccode"` + `"…secondaryisiccode1..4"`; `xpm_chamberofcommerce` igual | PROBABLE | los secundarios no traen descripción, así que `V_ACTIVIDAD_ECONO_CIIU` sigue haciendo falta |
| Fecha de matrícula (d2) | `V_PERSONA_JURIDICA_CAMARA.Fecha_Matricula` | `xpm_chamberofcommerce."…dateofmercantileregistration"` | PROBABLE | |
| RUT (Info Básica) | fuente DIAN | `xpm."bestpersonalinformation.citizentaxregistrationindicator"` | HIPÓTESIS | |
| Número de entidades | `COUNT(DISTINCT Id_Buro_Suscriptor)` | `xpm_location."location.val.counterpartyidnumber"` | PROBABLE | **está en la fila del reporte**: sobra el hash de respaldo y el join a nivel persona |
| Bloqueo | `V_BLOQUEO` | `xpm_location."location.val.blockreason"` + `"…subscriberblockstatus"` | CONFIRMADO que existe; falta la regla | §3 |
| Sector (contactabilidad, sector financiero) | clase buró / sector | `xpm_counterparties_val_businesslines."…economicsector"` | HIPÓTESIS | dominio por medir (C14) |
| Cuentas y comportamiento (F2) | `VU_CUENTA` | `xpm_bestaccounts` (92 columnas, con `index`) y `xpm_bestaccounts_val_frequentbehaviour` | PROBABLE | **las vistas stub `v_xpm_cuenta` y `v_xpm_comportamiento_cta` se pueden conectar**, tras medir la llave (C13) |
| Marca de delta del productor | `METADATACARGALOG` / `LOG_TD` | `xpm.delta_operation`, `source_type`, `generation`, `xpmversion` | HIPÓTESIS | podría sustituir o complementar el watermark (C8) |

**Vistas `vw_biz_*` frente a tablas base:**
- Las vistas ocultan las columnas no "business". `xpm_bestaccounts` tiene 9 columnas que su vista no muestra (`maximumdelinquency`, `numberofdelinquenciesof30days`, `legalcollectiondate`…) y `frequentbehaviour` tiene 4 (`accountstatus`, `bureauevent`…).
- El repo lee las tablas base y conviene seguir así. Si gobierno exige leer las `vw_biz_*`, se pierden esas columnas.

## 2. C5 · Tipo de identificación en `xpm_location` (146.724 filas)

| `personidtype` | Filas | ID Type NH | Nota |
|---|---|---|---|
| 1 | 55.762 | CC | |
| NULL | 45.592 | — | **31 %** sin tipo en el reporte |
| 2 | 43.735 | **NIT** | |
| 4 | 687 | CE | |
| 8 | 672 | DNI | |
| 5 | 244 | PAS | |
| 7 | 16 | TI | |
| 6 | 6 | PPT | |
| 9 | 5 | PEP | |
| 3 | 5 | PJE (persona jurídica del extranjero) | |

**CONFIRMADO: en EDF el NIT es el código 2, no el 3.**
- El repo cablea `'3'` como NIT (`pgm/sp_unificacion_r2_esc3_sin_nit_misma_nomenclatura.sql:27`, `pgm/sp_unificacion_r2_motor_nit_empates_nuevas_direcciones.sql:194`).
- Con datos reales, la rama NIT de la R2 ve **5 filas en vez de 43.735**.

El dominio observado (1 a 9) cabe en ID Type NH (0 a 10). El Batch trunca el tipo a 1 carácter (`SPS:1272`): el código 10 (RC) no aparece aquí, pero si llega colisionaría con el 1.

## 3. C7 · Bloqueo en `xpm_location` (146.724 filas)

| `blockreason` | `subscriberblockstatus` | Filas | Significado NH de `blockreason` |
|---|---|---|---|
| (vacío) | (vacío) | 139.786 | — |
| 0 | 1 | 6.502 | 0 = Activo |
| 2 | 0 | 386 | Por fuerza mayor |
| 3 | 0 | 25 | Insoluta o prescrita |
| 4 | 0 | 19 | Inconsistencia en el sistema |
| 5 | 0 | 5 | Validación de la entidad |
| 1 | 0 | 1 | Por solicitud SIC |

**La regla de bloqueo no se puede deducir y hay que decidirla:**
- `subscriberblockstatus = 1` aparece **solo** con razón 0 ("Activo"). Son 6.502 filas (4,4 %). ¿Es un bloqueo del suscriptor o un estado activo?
- Las razones 1 a 5 vienen siempre con estado 0.
- El AS-IS excluía el `cod_dw_persona_ubic` entero si existía en `V_BLOQUEO`, cualquiera fuera la razón. Además, los códigos 1-9 de Teradata **no significan lo mismo** que en NH.
- En EDF el bloqueo es **por reporte** (fila de `xpm_location`), así que aplicaría a todos los contactos de ese reporte.

**DECISIÓN PROVISIONAL (usuario, 2026-10-20):**
- **Bloqueado** = `TRIM("location.val.blockreason")` distinto de vacío y de `'0'`. Hoy excluye 436 filas.
- `subscriberblockstatus = 1` con razón 0 **se trata como activo** hasta que el productor explique qué significa.
- Al implementarla se marca como provisional en el código y en el criterio que la mida.

## 4. Lo que sigue

1. Correr `consultas_perfilado_edf_2026-10-20.sql` (C4, C6, C8 a C14) y pegar las salidas aquí.
2. Decidir la regla de bloqueo (§3).
3. Pedir al productor: contactabilidad/gestión, movilidad, puntos de interés, el catálogo de `contacttype` y el de género, y `V_ACTIVIDAD_ECONO_CIIU` (para los CIIU secundarios).
