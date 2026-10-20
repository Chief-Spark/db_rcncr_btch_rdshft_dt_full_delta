# Resultados de las consultas a `edf_views`

Las consultas se corren en el consumidor DEV (`dba_batch_DEV`), solo en modo lectura. Aquí se registran los metadatos y los conteos agregados; ningún dato personal.

| Consulta | Fecha | Archivo con la salida |
|---|---|---|
| C1 · tablas (`svv_all_tables`) | 2026-10-20 | `svv_all_tables_2026-10-20.csv` (104 objetos: 35 tablas y 69 vistas `vw_biz_*`) |
| C2 · columnas (`svv_all_columns`) | 2026-10-20 | `svv_all_columns_2026-10-20.csv` (1.071 columnas) |
| C3 · búsqueda de contactabilidad | 2026-10-20 | se resolvió sobre C2 (ver §1) |
| C5 · dominio de `personidtype` | 2026-10-20 | §2 |
| C7 · bloqueo | 2026-10-20 | §3 |
| C4, C6, C8 a C16 | 2026-10-20 | §4 a §11 |
| C17 a C20 · verificación de las hipótesis de §4-§11 | 2026-10-20 | §14 |
| C21 · forma del valor estandarizado de teléfonos y celulares | 2026-10-20 | §14 |
| C22 · largo y prefijo de 2 dígitos de los teléfonos de suscriptor | 2026-10-20 | §14 |
| C18, C19, C20 y C22 repetidas en **QA** | 2026-10-20 | §15 |

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


## 4. Cómo está armado el datashare (C4a-c, C10, C13, C15)

```
xpm                         125.703 personas (1 fila por pin)
 ├─ 27.117 sin location, sin contrapartes y sin generation  -> personas vacías (21,6 %)
 └─ 98.586 con location
     xpm_location           146.724 filas = 142.067 reportes + 4.657 arreglos vacíos
         └─ contactinformations  568.657 filas = 568.544 contactos + 113 arreglos vacíos
```

**CONFIRMADO:**

| Hecho | Evidencia | Consecuencia |
|---|---|---|
| Un arreglo vacío deja **una fila con `index` NULL** | xpm_location 146.724 − 142.067 = 4.657 (= `typeofdata` NULL); contactos 568.657 − 568.544 = 113 (= `contacttype` NULL); bestidentifications 66; bestaccounts **98.440** | Toda lectura nueva filtra `"index" IS NOT NULL`. Las vistas actuales ya lo evitan por el `IN` de `contacttype` |
| **`(id, index)` es la llave del contacto**: única en las 568.544 filas reales | C4a | D-UNI-02 cerrado en el dato: la llave sale de `(ci.id, ci."index")` |
| **`ci.id` es un reporte, no un contacto**: 136.146 de 142.067 reportes traen **4 tipos de contacto distintos** | C4b | Hoy `cod_dw_persona_ubic = ci.id` (`02_vistas…:20`) junta los cuatro en una sola "RPU" |
| **`loc.id` es el arreglo de la PERSONA**: 98.586 `id` = 98.586 personas con location | C4c | Hoy `cod_dw_ubic = loc.id` (`02_vistas…:19`): **todas las direcciones de una persona comparten `cod_dw_ubic`**. Ver §12, hallazgo 2 |

## 5. Tipos de contacto (C6a-b) frente al mapeo del repo

| `contacttype` | Filas | `standardizedtipo` | Repo hoy | Lectura del dato |
|---|---|---|---|---|
| **8** | 135.084 | VIA 90.488 · UNDETERMINED 40.935 · RURAL 2.258 · DESCRIPTIVE 1.312 · MANZANA 89 | DIR (tipo 3 = CRR) **y TEL** (`04_vistas…:125`, `sp_ordenamiento_ubicaciones_edf.sql:248`) | **es dirección** (CONFIRMADO por `standardizedtipo`). En TEL es un defecto |
| **10** | 138.714 | — | EMAIL (`04_vistas…:180`) | HIPÓTESIS, verificar con C18 |
| **6** | 135.084 | — | **no se lee** | HIPÓTESIS: el registro de ciudad (`citycode` viene en 135.082 filas). C18 |
| **11** | 135.084 | — | **no se lee** | desconocido. C18 |
| 1 · 2 · 3 | 5.426 · 3.665 · 4.922 | — | DIR (RES · LAB · CRR) | coherente con un reporte de suscriptor; falta el catálogo |
| 4 · 5 | 4.349 · 3.032 | — | TEL | sin verificar |
| 9 | 3.184 | — | CEL (`04_vistas…:157`) | sin verificar |
| **7** | **0** | — | DIR (`02_vistas…:107`, catálogo `01_ddl…:126`) | no existe en el dato |

**Los tipos 8, 6, 11 y 10 vienen juntos**: 135.084 filas cada uno, igual que los reportes con `typeofdata = 6` (§9). Es un paquete por reporte: una dirección, su ciudad y dos contactos más.

**Consecuencia:** **el 72 % de los contactos (6, 10, 11) no tiene un canal verificado**, y 270.168 de ellos (6 y 11) no se leen. Si 11 es teléfono o celular, hoy se pierde el canal entero.

## 6. Código DANE (C6c)

- Solo **94.143 contactos (16,6 %)** traen DANE, y **todos con 8 dígitos** (centro poblado). No hay ninguno de 5.
- El repo usa el mismo valor para ciudad y municipio (`02_vistas…:250-251`). El municipio son los **primeros 5 dígitos**. Como hoy es `INTEGER` y pierde el cero inicial, se saca con `cod_dw_ciudad / 1000` (05001000 → 5001 = 05001).
- **Al ~37 % de las direcciones les falta el DANE** (estimado: 94k de ~149k). Para ellas el repo inventa una ciudad con el hash de `cityname`.
- `citycode` está en 135.082 filas: puede ser la fuente de ciudad que falta. C18 dice en qué tipo viene y con qué largo.

## 7. Marca de delta del productor (C8)

- **Todo el datashare es `FULL_REFRESH`**, con un único `generation` = 1792243798000 = **2026-10-17 13:29:58 UTC**. Las 27.117 personas vacías lo traen en NULL.
- **No hay delta del productor.** El DELTA por watermark sobre la fecha del dato sigue siendo el único incremental posible: lo que hace el repo es correcto.
- **Propuesta (F3):** guardar `generation` en cada `*_control`. Sirve para la trazabilidad (qué foto procesó cada corrida) y para saltar una corrida si la foto no cambió.

## 8. Persona (C9, C10)

| Dato | Resultado | Lectura | Acción |
|---|---|---|---|
| Género | 1 = 27.059 · 2 = 25.118 · NULL = 73.526 (58 %) | HIPÓTESIS 1 = M, 2 = F | **PEDIR** el catálogo |
| Rango de edad | **solo 2.462 personas (2 %)**. Formato `36 - 45`, `66 años o más` | la salida espera `36-45`, `66+` | homologar con `REPLACE(' - ', '-')` y `66 años o más` → `66+`. **Avisar al negocio: `DP_RAN_EDA` saldrá vacío el 98 % de las veces** |
| RUT | true 43.319 · false 55.267 | 43.319 ≈ 43.313 NIT en bestidentifications ≈ 43.735 NIT en location | refuerza que **NIT = 2** (D-UNI-01) |
| Identificación "mejor" | 98.664 reales para 98.586 personas | **78 personas con dos** | regla de desempate obligatoria (propuesta: la de `idstatus` vigente y, si empatan, `MIN("index")`) |
| Tipo 11 | 1 fila | **no está en ID Type NH (0 a 10)** | PEDIR |
| `idstatus` | `''`, `00`, `01`, `21`, `vo` | sin catálogo | PEDIR |

## 9. Tipo de dato del reporte (C12) y llenado (C11)

| `typeofdata` | Reportes | Lectura |
|---|---|---|
| **6** | 135.084 (95 %) | el paquete de §5. **No trae suscriptor** (§10) |
| 1 · 2 | 4.417 · 2.433 | reportes con tipos 1-5 y 9 |
| **3** | **113** | los únicos con `stratum` (113 filas): **el estrato llega como reporte propio, sin contactos** |
| 17 | 20 | — |

**HIPÓTESIS:** `typeofdata` es la **fuente** del dato y sería el insumo de `FUENTE` (SUS/CIU/CAM). `businesslines.listoftypeofdata` sugiere que existe un catálogo. **PEDIR.**

**Llenado de las direcciones (~149k):**

| Campo | Llenado | Acción |
|---|---|---|
| barrio | 90.481 (~61 %) | **CONECTAR**; ya no hace falta ArcGIS para esto |
| localidad | 93.605 (~63 %) | **CONECTAR** |
| código postal | 67.599 (~45 %) | **CONECTAR** |
| estrato | 113 en todo el datashare | en la práctica **no está**: PEDIR, o esperar a GEO |
| web | 540 | ignorar |

## 10. Suscriptor, contrapartes y fecha (C15, C16, C14)

- **El reporte casi nunca trae su suscriptor:** `location.counterpartyidnumber` está en **6.983 de 142.067 reportes (4,9 %)**.
- **La contraparte es por PERSONA:** 98.491 personas tienen una sola y 95 tienen entre 2 y 57.
  - Hoy `id_buro_suscriptor` toma primero la de la persona (`02_vistas…:319-330`) y, si falta, una cubeta de hash.
  - O sea: **el 95 % de los "suscriptores" es el mismo valor para todos los reportes de la persona**. "Número de entidades que reportan" sale 1 o un número de cubetas, no entidades.
- **Fan-out CONFIRMADO:** las 95 personas con varias contrapartes multiplican cada reporte hasta ×57 en `v_xpm_reporte_relacion_persona_ubica` y en `v_xpm_contacto_canal`. Es poco en la muestra, pero en producción (65-70 M) no se puede dejar.
- **Fecha:** `cutoffdate` está en el **100 % de los reportes reales** (142.067, todos en epoch). La caída a `CURRENT_DATE` solo toca los arreglos vacíos, que no tienen contactos. **D-EDF-04 tiene impacto cero hoy**; se corrige por higiene.
- **Sector (C14):** F 1.775 · R 852 · C 50 · vacío 93.858. HIPÓTESIS: F→FI, R→RE, C→CO, y el resto OT. PEDIR el catálogo. Ojo: el sector cuelga de la contraparte de la persona, no del reporte.

**Propuesta para el suscriptor (vista real, pide tu OK):**
1. el del propio reporte;
2. si falta y la persona tiene **una sola** contraparte, esa;
3. si no, NULL. **Nunca un hash y nunca multiplicar filas.**

Antes hay que saber qué es la contraparte de la persona (C19). Si son unos pocos valores, es la fuente y no un suscriptor.

## 11. Cuentas y bloqueo (C13, con C7)

- **Solo 7.759 cuentas reales**; las otras 98.440 filas son arreglos vacíos. La Fase 2 real tendrá poco dato.
- Los tipos vienen con cero a la izquierda (`'05'`, `'02'`): el cruce con `V_Tipo_Cuenta_Ord` necesita normalizarlos.
- `'51'` (1.407, el más frecuente), `'34'` y `'17'` **no están en el catálogo** y caen a categoría 0 (trampa ya anotada). Son 1.506 cuentas, el 19 %.
- **Bloqueo, mismo patrón en las dos tablas:** estado 1 ⇔ razón 0, y razón > 0 ⇔ estado 0. Nunca aparecen juntos.
  - **Esto refuerza la regla provisional:** bloqueado ⇔ `blockreason` ∉ (`''`, `'0'`), y `subscriberblockstatus = 1` es "sin bloqueo".
  - Pasa de HIPÓTESIS a **PROBABLE**.

## 12. Brechas, en orden de impacto en la vía real

| # | Brecha | Evidencia | Impacto | Propuesta | Necesita |
|---|---|---|---|---|---|
| 1 | **Direcciones en el canal TEL** | tipo 8 = dirección (§5); TEL = `IN ('4','5','8')` | 135.084 direcciones rankeadas como teléfonos; cubo TELEFONO contaminado | quitar el 8 de TEL (vista `04` y `sp_ordenamiento_ubicaciones_edf.sql:248`) | OK a la vista |
| 2 | **`cod_dw_ubic` es la persona** | §4 | R1/R2/R3 unen RPU y ubicación por `cod_dw_ubic` (`sp_unificacion_r3_esc1_…:151,244,251`): **producto cruzado entre las direcciones de la persona** y textos o coordenadas cruzados. GEO deduplica por persona | `cod_dw_persona_ubic` = `(ci.id, ci."index")`; `cod_dw_ubic` = la dirección (propuesta: hash del texto normalizado + DANE, que reproduce el maestro de ubicaciones del AS-IS) | OK + C17 + re-certificar en real |
| 3 | **72 % de los contactos sin canal verificado** (6, 10, 11) | §5 | posibles teléfonos o celulares perdidos; EMAIL sin verificar | C18 (forma de cada tipo) y catálogo `contacttype` | C18 + PEDIR |
| 4 | Suscriptor y número de entidades | §10 | entidades por dirección sin sentido; fan-out | regla de tres niveles | C19 + OK a la vista |
| 5 | DANE y municipio | §6 | 37 % de direcciones sin ciudad real; municipio = ciudad | municipio = `/1000`; `citycode` como respaldo; NULL en vez del hash | C18 + OK a la vista |
| 6 | Bloqueo | §11 | 436 reportes bloqueados entran hoy | implementar la regla, ahora PROBABLE | OK a la vista |
| 7 | Identificación del cubo PERSONA | §8 | 78 personas con dos documentos | desempate determinista | — (F5) |
| 8 | Edad, género, sector, fuente | §8-§10 | campos del cubo vacíos o sin catálogo | homologaciones propuestas | catálogos |
| 9 | `generation` sin registrar | §7 | sin trazabilidad de la foto procesada | columna en `*_control` | OK al DDL (F3) |

## 14. C17 a C20: lo que confirman

**Antes de leer:** DEV es una muestra (125.703 personas frente a 65-70 M en producción). Las **formas** valen; los **porcentajes** no se extrapolan.

### Tipos de contacto: el mapeo queda casi cerrado (C18, C20)

| `contacttype` | Forma del valor (C18) | Viene en | Lectura | Repo hoy |
|---|---|---|---|---|
| **10** | 138.714 con `@` (100 %) | todas las fuentes | **EMAIL** · CONFIRMADO | EMAIL ✓ |
| **6** | sin letras; **104.851 con forma de celular** (3 + 9 dígitos) y 23.044 fijos de 7-8 | solo `typeofdata 6` | **TELÉFONO de la fuente 6**: 78 % celulares | **no se lee: se pierden ~128k teléfonos** |
| **11** | vacío en casi todo (largo medio 0); 1.097 con dígitos | solo `typeofdata 6` | segundo teléfono o fax, casi vacío | no se lee (bien, mientras no haya catálogo) |
| **8** | texto con letras; DANE 94.143; **`citycode` 135.082, de 4-5 dígitos** | solo `typeofdata 6` | **DIRECCIÓN**; `citycode` = **municipio DANE** sin el cero | DIR ✓ (ya no está en TEL) |
| 1 · 3 | texto con letras; `cityname` en todas; sin DANE | suscriptores (`typeofdata` 1, 2, 17) | **DIRECCIÓN** (RES y CRR, según el repo) | DIR ✓ |
| 2 | 64 % con letras | suscriptores | dirección (LAB, según el repo) | DIR ✓ |
| 4 · 5 | sin letras, largo 12, `cityname` en todas | suscriptores | **TELÉFONO FIJO**, probablemente con indicativo (60X + 7 dígitos) | TEL ✓ |
| **9** | sin letras, largo 12, **ninguno con forma 3 + 9 dígitos** | suscriptores | **CELULAR, probablemente con prefijo 57** | CEL, **en riesgo** (ver abajo) |

**Dos fuentes con paquetes distintos (C20):**
- **Suscriptores** (`typeofdata` 1, 2, 17; 6.870 reportes): traen suscriptor, tipo de cuenta y tipo de identificación en el 100 %. Contactos 1-5, 9 y 10.
- **`typeofdata 6`** (135.084 reportes, el 95 %): **ningún** suscriptor ni tipo de cuenta. Siempre el mismo paquete: dirección 8 + teléfono 6 + correo 10 + vacío 11.
- `typeofdata 3` (113): solo el estrato.

Que la fuente 6 no traiga suscriptor ni cuenta encaja con un registro público o comercial y no con un reporte de crédito. Es HIPÓTESIS: el catálogo de `typeofdata` lo confirma.

### Teléfonos: no vienen estandarizados (C21) y el tipo 9 no se reconoce

**Corrección:** la versión anterior de esta sección suponía que el celular del tipo 9 traía el prefijo 57. **C21 lo desmiente:** `reportado_cel_57 = 0`.

| `contacttype` | Valor estandarizado vacío | Lectura |
|---|---|---|
| 4 · 5 · 6 · 9 · 11 | **100 %** | `contactasreportedstandardized` no se llena para teléfonos. El repo cae a `contactasreported`, **en crudo** (`03_vistas_contacto_canal_edf_views.sql`, `valor_contacto`) |

**Consecuencias:**
- **Hay que normalizar el teléfono nosotros**, a solo dígitos, antes de sacar el operador (`LEFT(..., 3)`) y de comparar números.
- **El tipo 9 sigue sin forma reconocible:** 12 caracteres, sin letras, ni celular de 10 dígitos ni con 57. Lo mismo pasa con los tipos 4 y 5. Si el operador no sale de esos valores, CEL018 = 0 y la compuerta (`sp_ordenamiento_scoring_cel_edf.sql:261`) saca esos celulares del ranking.
- **HIPÓTESIS a confirmar con el DBA:** en DEV los teléfonos de suscriptor podrían venir **enmascarados**. Los de la fuente 6 sí tienen forma real (104.851 celulares).
- C22 mide el largo en dígitos y el prefijo de 2 dígitos, que no identifica a nadie.

### C22: los teléfonos de suscriptor vienen rellenados con ceros hasta 12 dígitos

| Tipo | Filas | Forma (C22) |
|---|---|---|
| 9 (celular) | 3.184 | **100 % de 12 dígitos que empiezan por `00`** → `00` + celular de 10 |
| 4 (fijo) | 4.349 | 12 dígitos; 4.226 con `00` y el resto con otros prefijos |
| 5 (fijo) | 3.032 | 12 dígitos; 3.001 con `00` |

**Repetida en QA (2026-10-20), con más volumen y la misma forma:**

| Tipo | Filas en QA | Con `00` | Otros prefijos |
|---|---|---|---|
| 9 (celular) | 39.453 | **100 %** | — |
| 4 (fijo) | 69.817 | 66.801 (95,7 %) | 3.016 en 68 prefijos distintos (`31` 794, `01` 468, `57` 32…) |
| 5 (fijo) | 53.000 | 52.538 (99,1 %) | 462 |

Todos tienen exactamente 12 dígitos y ninguno trae caracteres que no sean dígitos.

**El relleno es el formato del productor, no un enmascarado de DEV:** sale idéntico en dos ambientes. Los ~3.500 fijos que no empiezan por `00` son formatos sucios del origen (prefijo `57`, `01` de larga distancia…). La normalización les quita solo los ceros y no los pierde: siguen siendo 12 dígitos válidos.

**Eso cierra el "tipo 9 sin forma":** no está enmascarado, está **rellenado**. Sin los ceros es un celular de 10 dígitos.

**Y CONFIRMA QUE EL CANAL CEL REAL HOY QUEDA VACÍO:**
1. `sp_ordenamiento_ubicaciones_edf.sql:275,290` toma el celular y su operador del valor **crudo** (`LEFT(c.valor_contacto, 3)` → `'003'`).
2. `sp_ordenamiento_scoring_cel_edf.sql:121` busca `'003'` en `V_Operador_Ord_Cel`, que no lo tiene: CEL018 = 0.
3. La compuerta `WHERE cel018 <> 0` (`:261`) saca **todos** los celulares de suscriptor del ranking.
4. Los de la fuente 6 (tipo 6) ni siquiera se leen.

**Por qué no contradice la regla 4 del legado.** El código anterior quitó a propósito un `LTRIM` de ceros, porque el legado saca el operador con `SUBSTR(Texto_Ubicacion, 1, 3)` sin normalizar (`Caracteristicas.txt:912`). Eso sigue siendo cierto sobre el legado. Pero el `Texto_Ubicacion` del AS-IS **no viene rellenado**: el catálogo de operadores del propio legado tiene llaves 300-350, que solo cuadran con un celular sin ceros. **El relleno es un formato de transporte de EDF** y se homologa en la vista, no en el scoring. Así el SP sigue haciendo lo mismo que el legado sobre un valor equivalente.

### Ciudad: hay con qué llenarla (C18)

- Dirección de la fuente 6 (8): `citycode` en el 100 %, con 4-5 dígitos = municipio DANE. Donde falta el DANE de 8 dígitos (41k), `citycode` da el municipio y `citycode * 1000` la cabecera municipal.
- Direcciones de suscriptor (1, 2, 3): solo `cityname`. Se homologa contra **Divipola** (`legado_teradata/reconocer/catalogos/Dane Divipola Villages Codes (NH).csv`) por nombre normalizado y departamento.

### Personas con muchas direcciones (C17)

- 52.553 personas con 1 dirección y 41.267 con 2. La cola llega hasta **1.245 direcciones en una sola persona**: hay 90 personas con más de 10.
- **Con la llave vieja eso era un producto cruzado de 1.245² = 1,5 M filas para esa persona.** La corrección de llaves ya aplicada lo elimina.
- **Riesgo de rendimiento que queda:** la R2 se auto-une por persona. Una empresa con miles de direcciones sigue siendo cara. En producción hay que medir el máximo y decidir si se acota. Es AS-IS: el legado tiene el mismo patrón.

### Suscriptor (C19)

- La contraparte de la persona es siempre de tipo 2 (NIT), pero **solo 1.889 de 95.701 traen número** (347 distintos).
- Los reportes traen 296 suscriptores distintos, todos de las fuentes de suscriptor.
- El nivel 2 de la regla (la contraparte única de la persona) aporta poco y no daña: se deja.
- **"Número de entidades = 0" para la fuente 6 es lo correcto**: no la reporta una entidad.

### Lo que se propone ahora (pide OK)

| # | Cambio | Ganancia en DEV | Dónde |
|---|---|---|---|
| A | **Leer el tipo 6** y repartirlo por forma: 3 + 9 dígitos → CEL; si no → TEL | +104.851 celulares y +23.044 fijos | `v_xpm_contacto_canal` y los filtros de canal |
| B | **Normalizar los teléfonos** (tipos 4, 5, 6, 9 y 11): solo dígitos y **sin los ceros de relleno** (C21, C22). *Reemplaza la propuesta del prefijo 57, que C21 desmintió* | **el canal CEL deja de quedar vacío**: 3.184 celulares de suscriptor recuperan su operador | `v_xpm_contacto_canal` (el SP no se toca) |
| C | **Ciudad de respaldo**: `citycode` para el tipo 8; Divipola por nombre para 1, 2 y 3 | ciudad en ~55k direcciones que hoy quedan en NULL | `v_xpm_contacto_direccion` + catálogo Divipola en strct |

## 15. QA: las mismas consultas sobre otro ambiente (C18, C19, C20, C22)

**QA confirma las formas de DEV y desmiente sus proporciones.** DEV no es representativo del volumen ni de la mezcla de fuentes.

| | DEV | QA |
|---|---|---|
| Reportes de suscriptor (`typeofdata` 1, 2, 3, 17) | 6.983 (5 %) | 118.120 (87,5 %) |
| Reportes de la fuente 6 | 135.084 (95 %) | 16.927 (12,5 %) |
| Contraparte de la persona con número | 1.889 de 95.701 (2 %) | 21.581 de 33.881 (64 %), 1.489 distintas |
| Suscriptores distintos en los reportes | 296 | 1.251 |

**Por tipo de contacto, en QA (C18):**

| Tipo | Filas | Forma | Ciudad |
|---|---|---|---|
| 1 | 92.350 | dirección (93 % con letras) | **DANE en el 74 %**; `cityname` en todas |
| 3 | 88.829 | dirección | DANE en el 76 % |
| 2 | 61.312 | dirección con algo de basura numérica (68 % con letras) | DANE en el 54 % |
| 4 · 5 | 69.019 · 52.865 | fijos de 12 dígitos rellenados (C22) | `cityname` |
| 9 | 39.453 | celulares de 12 dígitos rellenados: el **100 %** empieza por `00` (C22) | — |
| 10 | 68.809 | correo (68.769 con `@`) | — |
| 6 | 16.927 | **teléfono**: 13.684 celulares y 2.075 fijos | — |
| 8 | 16.927 | dirección | DANE 15.940; **`citycode` de 5 dígitos** en 16.915 |
| 11 | 16.924 | vacío | — |
| **7** | **9** | dirección (fuente 6) | `cityname` |

**Qué cambia respecto de §14:**
- Las direcciones de suscriptor **sí traen DANE** en QA (54-76 %). Aun así faltan ~74k, y para ellas está la ciudad de respaldo por Divipola.
- **El tipo 7 existe** (9 filas): se mantiene en la lista de direcciones.
- **La contraparte de la persona sí parece un suscriptor** (NIT, 64 % con número, cifra del orden de los suscriptores de los reportes). El nivel 2 de la regla de suscriptor se queda.
- La fuente 6 sigue sin suscriptor ni tipo de cuenta (C20 en QA: 0 de 16.927).

## 13. Lo que sigue

1. Correr **C17 a C20** (al final de `consultas_perfilado_edf_2026-10-20.sql`); con ellas se cierran las hipótesis de las brechas 2 a 5.
2. **Pedir al productor:**
   - el catálogo de `contacttype` (urgente: brechas 1 y 3);
   - el de `typeofdata` (fuente);
   - género;
   - `idstatus`;
   - `economicsector`;
   - el tipo de identificación 11;
   - contactabilidad y gestión, movilidad y puntos de interés;
   - `V_ACTIVIDAD_ECONO_CIIU`.
3. **OK a las vistas reales** para las brechas 1, 2, 4, 5 y 6. Ninguna toca el mock.
