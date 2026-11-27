# Catalogo de campos del datashare EDF que consume el calculo Reconocer

**Alcance: SOLO lo que leemos del datashare `ds_dba_rncr_batch.edf_views`.**
No estan aqui las columnas de nuestras propias tablas (`bdm_datos`,
`bdm_tempo`, `bdm_stage`), ni las del mock, ni los catalogos.

**Como se saco, para que se pueda rehacer:** el datashare se consume en
EXACTAMENTE tres archivos de `strct`, y en ningun otro sitio de los cuatro
paquetes. Todo lo demas -- Unificacion, GEO, Ordenamiento y Novedades -- lee
las vistas `bdm_tempo.v_xpm_*`, nunca la relacion cruda:

| Archivo | Entrada de `deploy.par` |
|---|---|
| `02_vistas_insumo_edf_views.sql` | 21 |
| `03_vistas_contacto_canal_edf_views.sql` | 22 |
| `04_vistas_insumo_ordenamiento_edf_views.sql` | 23 |

De ahi salen **94 columnas distintas sobre nueve relaciones**: 71 de dato y
23 de navegacion (las llaves `id` / `index` y los arreglos que solo se
recorren para desanidar).

## Que etapa lee que vista

Es el mapa que conviene mirar primero: una columna le importa a una etapa
solo si la etapa lee la vista que la expone.

| Etapa | Vistas del datashare que consume |
|---|---|
| Unificacion R1 | `v_xpm_relacion_persona_ubicacion`, `v_xpm_ubicacion_estandarizada`, `v_xpm_direccion_fisica`, `v_xpm_reporte_relacion_persona_ubica`, `v_xpm_ciiu_persona` |
| Unificacion R2 | `v_xpm_relacion_persona_ubicacion`, `v_xpm_ubicacion_estandarizada`, `v_xpm_direccion_fisica`, `v_xpm_reporte_relacion_persona_ubica` |
| Unificacion R3 | las mismas cuatro de la R2 |
| GEO | `v_xpm_ubicacion_estandarizada` (exportar insumo y cargar resultados) |
| Ordenamiento F1 y F3 | `v_xpm_contacto_direccion`, `v_xpm_contacto_canal`, `v_xpm_relacion_persona_ubicacion`, `v_xpm_ubicacion_estandarizada`, `v_xpm_reporte_relacion_persona_ubica` |
| Ordenamiento F2 | `v_xpm_cuenta`, `v_xpm_comportamiento_cta` |
| Ordenamiento F4 (scoring) | **ninguna directamente**: lee las `bdm_tempo.stg_insumo_*` que arma `preparar_insumos` |
| Novedades Ubicacion | `v_xpm_contacto_canal`, `v_xpm_relacion_persona_ubicacion`, `v_xpm_ubicacion_estandarizada`, `v_xpm_direccion_fisica`, `v_xpm_reporte_relacion_persona_ubica` |
| Novedades Actividad economica | `v_xpm_actividad_economica_persona`, `v_xpm_ciiu_persona`, `v_xpm_relacion_persona_ubicacion`, `v_xpm_reporte_relacion_persona_ubica` |
| Novedades Info basica | `v_xpm_persona_basica` |
| Novedades Contactabilidad | `v_xpm_relacion_persona_ubicacion`, `v_xpm_reporte_relacion_persona_ubica` |
| Novedades Ubicacion agregada | `v_xpm_contacto_canal` |
| Novedades Movilidad y Punto de interes | **ninguna**: trabajan sobre tablas nuestras ya materializadas |
| Exportador UNLOAD (SLCOPRBA-1820) | **ninguna**: lee las siete `bdm_datos.mat_*` |

**Dos vistas se declaran y hoy no las lee nadie fuera de las propias vistas:**
`v_xpm_cuenta_bloqueada` y `v_relacion_persona_ubicacion_ord`. Se dejan
anotadas; declarar una vista no prueba que alguien la consuma.

## Campos del datashare EDF que lee el calculo Reconocer

Extraido de las tres vistas de `strct` que tocan `ds_dba_rncr_batch.edf_views`.
`N` marca las columnas de NAVEGACION (llaves de join y arreglos que solo se
recorren); el resto son columnas de DATO.


### `xpm` -- 17 columnas (11 de dato, 6 de navegacion)

| | Columna | Vistas que la leen |
|---|---|---|
| N | `bestaccounts` | v_xpm_contacto_canal, v_xpm_contacto_direccion, v_xpm_cuenta |
| N | `bestidentifications` | v_xpm_persona_basica |
|  | `bestname.firstlastname` | v_xpm_persona_basica |
|  | `bestname.firstname` | v_xpm_persona_basica |
|  | `bestname.fullname` | v_xpm_persona_basica |
|  | `bestname.secondlastname` | v_xpm_persona_basica |
|  | `bestname.secondname` | v_xpm_persona_basica |
|  | `bestpersonalinformation.agerange` | v_xpm_persona_basica |
|  | `bestpersonalinformation.citizentaxregistrationindicator` | v_xpm_persona_basica |
|  | `bestpersonalinformation.gender` | v_xpm_persona_basica |
|  | `bestpersonalinformation.mainisiccodeforproduct` | v_xpm_actividad_economica_persona, v_xpm_ciiu_persona, v_xpm_persona_basica |
|  | `bestpersonalinformation.productmainisicdescription` | v_xpm_persona_basica |
| N | `chamberofcommerce` | v_xpm_actividad_economica_persona |
| N | `counterparties` | v_xpm_contacto_canal, v_xpm_reporte_relacion_persona_ubica |
| N | `location` | v_xpm_contacto_canal, v_xpm_contacto_direccion, v_xpm_reporte_relacion_persona_ubica |
| N | `personalinformation` | v_xpm_actividad_economica_persona |
|  | `pin` | v_xpm_actividad_economica_persona, v_xpm_ciiu_persona, v_xpm_contacto_canal, v_xpm_contacto_direccion, v_xpm_cuenta, v_xpm_persona_basica |

### `xpm_bestaccounts` -- 13 columnas (10 de dato, 3 de navegacion)

| | Columna | Vistas que la leen |
|---|---|---|
|  | `bestaccounts.val.accountnumber` | v_xpm_cuenta_bloqueada |
|  | `bestaccounts.val.accounttype` | v_xpm_cuenta, v_xpm_cuenta_bloqueada |
|  | `bestaccounts.val.blockseverity` | v_xpm_cuenta_bloqueada |
|  | `bestaccounts.val.businesslinecode` | v_xpm_cuenta, v_xpm_cuenta_bloqueada |
|  | `bestaccounts.val.cutoffdate` | v_xpm_cuenta |
| N | `bestaccounts.val.frequentbehaviour` | v_xpm_comportamiento_cta, v_xpm_cuenta |
|  | `bestaccounts.val.guaranteetype` | v_xpm_cuenta |
|  | `bestaccounts.val.personidnumber` | v_xpm_cuenta_bloqueada |
|  | `bestaccounts.val.personidtype` | v_xpm_cuenta_bloqueada |
|  | `bestaccounts.val.totalnumberofinstallments` | v_xpm_cuenta |
|  | `bestaccounts.val.typeofdebtor` | v_xpm_cuenta |
| N | `id` | v_xpm_comportamiento_cta, v_xpm_cuenta, v_xpm_cuenta_bloqueada |
| N | `index` | v_xpm_comportamiento_cta, v_xpm_cuenta, v_xpm_cuenta_bloqueada |

### `xpm_bestaccounts_val_frequentbehaviour` -- 6 columnas (4 de dato, 2 de navegacion)

| | Columna | Vistas que la leen |
|---|---|---|
|  | `bestaccounts.val.frequentbehaviour.val.behaviourdate` | v_xpm_comportamiento_cta, v_xpm_cuenta |
|  | `bestaccounts.val.frequentbehaviour.val.debtbalance` | v_xpm_cuenta |
|  | `bestaccounts.val.frequentbehaviour.val.paidinstallments` | v_xpm_cuenta |
|  | `bestaccounts.val.frequentbehaviour.val.valuemonthlypayment` | v_xpm_cuenta |
| N | `id` | v_xpm_comportamiento_cta, v_xpm_cuenta |
| N | `index` | v_xpm_comportamiento_cta, v_xpm_cuenta |

### `xpm_bestidentifications` -- 9 columnas (7 de dato, 2 de navegacion)

| | Columna | Vistas que la leen |
|---|---|---|
|  | `bestidentifications.val.businessidstatus` | v_xpm_persona_basica |
|  | `bestidentifications.val.issuedate` | v_xpm_persona_basica |
|  | `bestidentifications.val.issuingcityname` | v_xpm_persona_basica |
|  | `bestidentifications.val.issuingstatename` | v_xpm_persona_basica |
|  | `bestidentifications.val.officialsourcevalidationstatus` | v_xpm_persona_basica |
|  | `bestidentifications.val.personidnumber` | v_xpm_persona_basica |
|  | `bestidentifications.val.personidtype` | v_xpm_persona_basica |
| N | `id` | v_xpm_persona_basica |
| N | `index` | v_xpm_persona_basica |

### `xpm_chamberofcommerce` -- 7 columnas (5 de dato, 2 de navegacion)

| | Columna | Vistas que la leen |
|---|---|---|
|  | `chamberofcommerce.val.detailofmercantileregistrations.mainisiccodeforproduct` | v_xpm_actividad_economica_persona |
|  | `chamberofcommerce.val.detailofmercantileregistrations.secondaryisiccode1` | v_xpm_actividad_economica_persona |
|  | `chamberofcommerce.val.detailofmercantileregistrations.secondaryisiccode2` | v_xpm_actividad_economica_persona |
|  | `chamberofcommerce.val.detailofmercantileregistrations.secondaryisiccode3` | v_xpm_actividad_economica_persona |
|  | `chamberofcommerce.val.detailofmercantileregistrations.secondaryisiccode4` | v_xpm_actividad_economica_persona |
| N | `id` | v_xpm_actividad_economica_persona |
| N | `index` | v_xpm_actividad_economica_persona |

### `xpm_counterparties` -- 3 columnas (1 de dato, 2 de navegacion)

| | Columna | Vistas que la leen |
|---|---|---|
|  | `counterparties.val.counterpartyidnumber` | v_xpm_contacto_canal, v_xpm_reporte_relacion_persona_ubica |
| N | `id` | v_xpm_contacto_canal, v_xpm_reporte_relacion_persona_ubica |
| N | `index` | v_xpm_contacto_canal, v_xpm_reporte_relacion_persona_ubica |

### `xpm_location` -- 11 columnas (9 de dato, 2 de navegacion)

| | Columna | Vistas que la leen |
|---|---|---|
| N | `id` | v_xpm_contacto_canal, v_xpm_contacto_direccion, v_xpm_reporte_relacion_persona_ubica |
|  | `location.val.accountnumber` | v_xpm_contacto_canal, v_xpm_contacto_direccion |
|  | `location.val.accounttype` | v_xpm_contacto_canal, v_xpm_contacto_direccion |
|  | `location.val.blockreason` | v_xpm_contacto_canal, v_xpm_contacto_direccion |
|  | `location.val.businesslinecode` | v_xpm_contacto_canal, v_xpm_contacto_direccion |
| N | `location.val.contactinformations` | v_xpm_contacto_canal, v_xpm_contacto_direccion, v_xpm_reporte_relacion_persona_ubica |
|  | `location.val.counterpartyidnumber` | v_xpm_contacto_canal, v_xpm_reporte_relacion_persona_ubica |
|  | `location.val.cutoffdate` | v_xpm_reporte_relacion_persona_ubica |
|  | `location.val.personidnumber` | v_xpm_contacto_canal, v_xpm_contacto_direccion |
|  | `location.val.personidtype` | v_xpm_contacto_canal, v_xpm_contacto_direccion |
|  | `location.val.typeofdata` | v_xpm_reporte_relacion_persona_ubica |

### `xpm_location_val_contactinformations` -- 21 columnas (19 de dato, 2 de navegacion)

| | Columna | Vistas que la leen |
|---|---|---|
| N | `id` | v_xpm_contacto_canal, v_xpm_contacto_direccion, v_xpm_reporte_relacion_persona_ubica |
| N | `index` | v_xpm_contacto_canal, v_xpm_contacto_direccion, v_xpm_reporte_relacion_persona_ubica |
|  | `location.val.contactinformations.val.citycode` | v_xpm_contacto_direccion |
|  | `location.val.contactinformations.val.cityname` | v_xpm_contacto_direccion |
|  | `location.val.contactinformations.val.contactasreported` | v_xpm_contacto_canal, v_xpm_contacto_direccion |
|  | `location.val.contactinformations.val.contactasreportedstandardized` | v_xpm_contacto_canal, v_xpm_contacto_direccion |
|  | `location.val.contactinformations.val.contactasstandardizedscore` | v_xpm_contacto_direccion |
|  | `location.val.contactinformations.val.contacteventlastupdated` | v_xpm_contacto_canal, v_xpm_contacto_direccion |
|  | `location.val.contactinformations.val.contactfirsteventdate` | v_xpm_contacto_direccion |
|  | `location.val.contactinformations.val.contacttype` | v_xpm_contacto_canal, v_xpm_contacto_direccion, v_xpm_reporte_relacion_persona_ubica |
|  | `location.val.contactinformations.val.standardizedcomplemento` | v_xpm_contacto_direccion |
|  | `location.val.contactinformations.val.standardizeddanecode` | v_xpm_contacto_canal, v_xpm_contacto_direccion |
|  | `location.val.contactinformations.val.standardizeddepartment` | v_xpm_contacto_direccion |
|  | `location.val.contactinformations.val.standardizedmunicipality` | v_xpm_contacto_direccion |
|  | `location.val.contactinformations.val.standardizednumeropuerta` | v_xpm_contacto_direccion |
|  | `location.val.contactinformations.val.standardizedtextoubicacion` | v_xpm_contacto_canal, v_xpm_contacto_direccion |
|  | `location.val.contactinformations.val.standardizedtipo` | v_xpm_contacto_direccion |
|  | `location.val.contactinformations.val.standardizedtipoviaprincipal` | v_xpm_contacto_direccion |
|  | `location.val.contactinformations.val.standardizedviageneradora` | v_xpm_contacto_direccion |
|  | `location.val.contactinformations.val.standardizedviaprincipal` | v_xpm_contacto_direccion |
|  | `location.val.contactinformations.val.statename` | v_xpm_contacto_direccion |

### `xpm_personalinformation` -- 7 columnas (5 de dato, 2 de navegacion)

| | Columna | Vistas que la leen |
|---|---|---|
| N | `id` | v_xpm_actividad_economica_persona |
| N | `index` | v_xpm_actividad_economica_persona |
|  | `personalinformation.val.mainisiccode` | v_xpm_actividad_economica_persona |
|  | `personalinformation.val.secondaryisiccode.secondaryisiccode1` | v_xpm_actividad_economica_persona |
|  | `personalinformation.val.secondaryisiccode.secondaryisiccode2` | v_xpm_actividad_economica_persona |
|  | `personalinformation.val.secondaryisiccode.secondaryisiccode3` | v_xpm_actividad_economica_persona |
|  | `personalinformation.val.secondaryisiccode.secondaryisiccode4` | v_xpm_actividad_economica_persona |

**TOTAL: 94 columnas distintas -- 71 de dato y 23 de navegacion.**

## Tres cosas que conviene saber antes de usar esta lista

**Una columna se nombra con su ruta completa y entre comillas dobles.** El
datashare entrega estructuras anidadas, de modo que la columna no es
`contacttype` sino
`"location.val.contactinformations.val.contacttype"`. Buscar el nombre corto
en el codigo no encuentra nada.

**`v_xpm_cuenta` y `v_xpm_comportamiento_cta` YA leen el datashare.** Hasta el
2026-10-21 eran stubs de cero filas contra `bdm_stage.mock_numeros WHERE 1=0`,
y asi lo sigue diciendo la bitacora de los tres repos. Es falso desde esa
fecha: hoy arrancan de `xpm_bestaccounts` y de
`xpm_bestaccounts_val_frequentbehaviour`, y por eso 19 de las 94 columnas de
esta lista son de cuentas.

**Las columnas de navegacion no son relleno.** `id` e `index` son lo que
distingue un contacto de otro: `cod_dw_persona_ubic` se deriva de
`FNV_HASH(id || ':' || index)` porque `id` solo NO es unico en
`xpm_location_val_contactinformations` -- 568.657 filas para 142.067 `id`
distintos, ~4:1. Pedir la relacion sin `index` rompe la llave.
