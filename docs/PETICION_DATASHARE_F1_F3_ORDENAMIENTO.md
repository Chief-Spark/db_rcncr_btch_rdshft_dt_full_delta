# Petición de objetos al datashare — Fases 1, 2 y 3 del Ordenamiento

**Conclusión primero: portar F1, F2 y F3 no está bloqueado por código. Está
bloqueado por el datashare.** De los ~25 objetos externos que esas tres fases
leen en el legado Teradata, **5 tienen equivalente hoy en Redshift y unos 18
no**. Lo que falta es, en bloque, **el modelo de crédito BTT**: cuentas,
comportamiento de cuenta, buró de persona, tipo de persona y tipo de cuenta.

**F2 no se puede empezar en absoluto. F3 solo a medias.** Y el SQL, cuando
llegue el turno, es menos de lo que parece: de las 6 912 líneas de F1–F3,
alrededor del 60 % es *boilerplate* de Teradata (`dbc.tables`,
`COLLECT STATISTICS`, `DROP`, comprobaciones de `ACTIVITY_COUNT`) que
desaparece. Queda del orden de **2 000–2 500 líneas reales**, sin CTE
recursivos, sin `MERGE`, sin tablas volátiles, con un solo `QUALIFY` y con el
UDF `hash_md5` que mapea al `MD5()` nativo.

Por eso esta petición va primero: **es el camino crítico, y es el que tiene el
plazo externo más largo.**

Fecha: 2026-10-14 · Consumidor: `reconocerbatch` (cuenta 647096294147) ·
Datashare: `ds_dba_rncr_batch`, esquema `edf_views`

---

## Lo que el datashare expone hoy

> **RESUELTO (2026-10-15). La version anterior de esta seccion era falsa y
> esta es la correccion.** Decia "cuatro objetos, verificado sobre los 25
> archivos de DDL del repo de estructura". Eso verifica lo que NOSOTROS
> LEEMOS, no lo que el datashare CONTIENE. Las tres comprobaciones que
> existian eran la misma contada tres veces -- esa frase, el `grep` de
> `ds_dba_rncr_batch.edf_views.*` sobre `strct`, y `banco/stub_datashare.py`,
> que DERIVA sus tablas stub de nuestras propias vistas. Ninguna miraba el
> catalogo.
>
> **El catalogo real desmiente la afirmacion.** El volcado de
> `svv_all_columns` sobre `ds_dba_rncr_batch.edf_views` muestra, ademas de las
> cuatro de abajo, al menos: `xpm_bestaccounts` (~80 columnas),
> `xpm_bestaccounts_val_frequentbehaviour`, `xpm_globalindebtedness`,
> `xpm_counterparties_val_businesslines` (con `economicsector`),
> `xpm_identifications`, `xpm_legal`, `xpm_names` y `xpm_personalinformation`.
> Y `xpm_location` tiene **19 columnas**, de las que leemos cuatro: trae
> `accountnumber`, `accounttype`, `subaccounttype`, `businesslinecode`,
> `blockreason`, `subscriberblockstatus` y `stratum` sin usar.
>
> **Consecuencia: el Bloque A no es una peticion, es trabajo nuestro.** Este
> documento se queda sin su mitad mas cara. El mapeo caracteristica a
> caracteristica, con lo que si hay que pedir y a que mesa, esta en
> `docs/MAPEO_DESBLOQUEO_DATASHARE_ORDENAMIENTO.md`.

Las cuatro que nuestras vistas leen hoy, que **no** son las cuatro que el
datashare expone:

| Objeto | Lo usamos para |
|---|---|
| `edf_views.xpm` | persona (`pin`), CIIU, enlace a ubicacion |
| `edf_views.xpm_location` | ubicacion, fecha de corte, contraparte |
| `edf_views.xpm_location_val_contactinformations` | el contacto: direccion, telefono, celular, correo |
| `edf_views.xpm_counterparties` | identificador de la contraparte |

Sobre esos cuatro están construidas las ocho vistas `bdm_tempo.v_xpm_*` que
alimentan Unificación y la Fase 4 del Ordenamiento. **Para F1–F3 no alcanzan.**

---

## Bloque A — BTT / crédito. Bloquea la Fase 2 por completo

Sin estos objetos, la Fase 2 (Atributos de Cuenta) **no tiene insumo**: su
primer paso extrae las cuentas de las personas del universo.

| Objeto del legado | Quién lo lee en el legado | Para qué |
|---|---|---|
| `VU_CUENTA` / `V_CUENTA` | `PRO_ORD_CTA_ATRIBUTOS.sql:163`, `PRO_ORD_CALC_UBICACIONES.sql:126,328`, `_1.sql:104` | la cuenta: `Cod_DW_Cta`, tipo de cuenta, tipo de obligación, suscriptor. **Es el grano de toda la Fase 2** |
| `vu_comportamiento_cta_Activo` | `PRO_ORD_CTA_TOTALES_PERSONAS_1.sql:106` | comportamiento activo en la ventana de 12 meses |
| `vu_comportamiento_cta_pasivo` | `PRO_ORD_CTA_TOTALES_PERSONAS_2.sql:106` | comportamiento pasivo: mora, saldo, cuotas |
| `V_COMPORTAMIENTO_CUENTA` | `PRO_ORD_MATERIALIZA_BTT.sql` | detección de delta sobre el modelo de crédito |
| `V_BURO_PERSONA` | `PRO_ORD_MATERIALIZA_BTT.sql` (5 veces) | persona del buró, llave del universo de F1 |
| `VU_Persona` | `PRO_ORD_CALC_UBICACIONES_2.sql` | atributos de persona para el vector de ubicaciones |
| `V_Tipo_persona` | `PRO_ORD_CALC_UBICACIONES_2.sql` | natural / jurídica — **criterio F3-03** |
| `v_tipo_cuenta` | `PRO_ORD_CALC_UBICACIONES_2.sql` | tipo de cuenta real, hoy sustituido por un catálogo interino |
| `V_Razon_Bloqueo` | `PRO_ORD_CTA_ATRIBUTOS.sql:298` | razón de bloqueo de la cuenta |
| `V_FUENTE_DATO` | `PRO_ORD_CTA_ATRIBUTOS.sql:301` | fuente del dato |
| `V_COD_ENTREGA_DATO` | `PRO_ORD_CTA_ATRIBUTOS.sql:304` | código de entrega |

**Desbloquea:** los 10 criterios de F2 y, de rebote, las seis características de
la Fase 4 que hoy se alimentan de catálogos interinos (ver el apartado final).

---

## Bloque B — REC / ubicaciones. Deja la Fase 3 a medias

| Objeto del legado | Quién lo lee en el legado | Para qué |
|---|---|---|
| `bloqueo` / `V_BLOQUEO` | `PRO_ORD_CALC_UBICACIONES_2.sql:263`, `PRO_ORD_MATERIALIZA_REC.sql` | **criterio F3-01.** Hoy el Ordenamiento de Redshift no tiene filtro de bloqueo, y está anotado como tal en el catálogo de criterios |
| `relacion_ubicac_estandar_Geo` / `v_RELACION_UBICAC_ESTANDAR_GEO` | `PRO_ORD_CALC_UBICACIONES_2.sql:1180` | la coincidencia geográfica. Hoy `coincidencia_geo` está **fijada al literal 0** en el insumo. **Corrección (2026-10-15):** afecta solo a `TEL020`, y `TEL020` **no entra en la suma del score** ni en el legado (`Caracteristicas.txt:2830-2834`) ni en nuestro port, así que no toca el ranking. `TEL010` no depende de la geo: es la cuota de la ventana `<= 12` sobre `Total_Reportes_12` (`:2972-2977`), y ya está portada. **Este objeto baja de prioridad** |
| `v_gestion_registro` | `PRO_ORD_CALC_UBICACIONES_2.sql` | gestión del registro. Hoy se sintetiza con una expresión regular sobre el valor de contacto |
| `v_Fuente` | `PRO_ORD_CALC_UBICACIONES_2.sql` | fuente de la ubicación |
| `V_UBICACION_ORIGINAL` | `PRO_ORD_MATERIALIZA_REC.sql` | ubicación sin estandarizar |
| `V_Log_Ubicacion_Estandariza` | `PRO_ORD_MATERIALIZA_REC.sql` | traza de la estandarización |
| `V_Geografia` | `PRO_ORD_CALC_UBICACIONES_2.sql` | geografía. **Parcial**: tenemos `bdm_datos.geo_atributos`, no una vista equivalente |
| `V_Tipo_Ubicacion_Direccion` | `PRO_ORD_CALC_UBICACIONES_2.sql` | **Parcial**: lo cubre el catálogo local `bdm_datos.tipo_ubicacion_dir` |
| `CUENTA_ATRIBUTO_HASH` + `V_CUENTA_ATRIBUTO_HASH` | `PRO_ORD_FINAL_CTA_ATRIBUTOS.sql` | persistencia por hash MD5. **Ojo: desactivado en producción** desde 2018-10-05 |
| `UBICACION_ATRIBUTO_HASH` + `V_UBICACION_ATRIBUTO_HASH` | `PRO_ORD_FINAL_UBIC_DIRECCIONES.sql:122,222` | ídem. **También desactivado** |

**Desbloquea:** los 11 criterios de F3, y con ellos `F4-TEL-02` y `F4-TEL-03`,
que hoy quedan en `SIN_DATO` por la `coincidencia_geo` constante.

---

## Lo que NO hace falta pedir

- **La Fase 1 no se porta: se re-especifica.** Sus 46 pasos existen para
  detectar el delta por lote con `bdm_mtdat.MetadataCargaLog` y `dbc.tables`,
  que no tienen contraparte. En Redshift el equivalente ya existe con otra
  forma: el alcance por `p_lote` / `p_watermark` de
  `sp_ordenamiento_preparar_insumos_edf.sql:36-67`. Pedir `MetadataCargaLog`
  sería pedir la plomería de Teradata, no el dato.
- `METADATA_ORDENAMIENTO`, `Control_Ordenamiento`, `log_td`: sustituidos por
  `bdm_datos.ord_control` y `ord_control_etapa`.
- El UDF `rec_vista.hash_md5()`: Redshift trae `MD5()` nativo. Conviene
  comparar una salida byte a byte una sola vez, porque los criterios `F2-07` y
  `F3-04` exigen exactamente 32 caracteres.

---

## Dos hallazgos que la mesa debe conocer antes de decidir

Los dos salieron al revisar esta dependencia, y los dos cambian el valor de lo
que se pide.

### 1. `sector_financiero` no es un catálogo provisional: hoy es ruido

`02_catalogos_ordenamiento.sql:12-17` lo carga así:

```sql
CASE WHEN rep.id_buro_suscriptor >= 901 THEN 1 ELSE 0 END
```

Y `02_vistas_insumo_edf_views.sql:326-333` define `id_buro_suscriptor` como un
`COALESCE` cuyo **último recurso** es

```sql
MOD(ABS(FNV_HASH(xpm.pin || ':' || ci.id::VARCHAR)), 9998) + 1
```

Es decir: para todo reporte que llegue **sin** `counterpartyidnumber`, el
"sector" sale de una cubeta de hash — una moneda al aire. Y la misma columna
alimenta `EMA015`, que hace `COUNT(DISTINCT id_buro_suscriptor)`: cuenta
cubetas de hash como si fueran suscriptores distintos.

**Qué pedir, concretamente:** el porcentaje de reportes sin
`counterpartyidnumber`. Si es alto, estas cuatro características miden ruido
hoy mismo, con independencia de F2.

### 2. El `Sector` del legado tiene grano por CUENTA, y una bandera 0/1 no lo reproduce

`PRO_ORD_CTA_TOTALES_PERSONAS_2.sql:378-396`, literal: `Sector` toma valores en
`{CO, CC, RE, FI, OT}` y se deriva de `Portafolio_Nuevo`, que a su vez sale del
prefijo de dos dígitos de `cod_suscriptor` más una lista explícita de unos 60
códigos. La tabla resultante lleva `PRIMARY INDEX (Cod_DW_Cta)`: **es por
cuenta, no por suscriptor.**

Nuestra bandera 0/1 no puede distinguir `'FI'` de `'OT'`. Por eso
`DIR010FI`, `DIR013OT`, `DIR034FI` y `EMA016` **no son portables con el insumo
de hoy**, y por eso el Bloque A no es solo cuestión de F2: también cierra
cuatro características de la Fase 4 que ya están escritas.

> **Corrección (2026-10-15): eran seis y son cuatro.** Esta lista incluía
> `TEL017` y `CEL017`. Las dos **ya están portadas**: el legado no las define
> sobre `Sector`. `CO01TEL017` es la cuota de reportes de tipo `'RES'` sobre
> `Total_Reportes_Telefono` (`Caracteristicas.txt:2296-2299`) y `CO01CEL017`
> la cuota de la ventana `(12, 24]` sobre
> `Total_Reportes_24 - Total_Reportes_12` (`:2459-2463`). Pedir el Bloque A
> por ellas sería pedir de más.
>
> `DIR010FI` y `DIR013OT` además ya llevan la **forma** correcta — sus
> ventanas (`<= 6` y `> 24`) y el divisor `Total_Reportes_Dirc` por persona.
> Lo único que les falta es el predicado: cuando llegue el `Sector`, cambia
> una línea en cada una.

Matiz honesto, y es favorable: **diez de las once ramas de `Portafolio_Nuevo`
dependen solo del `cod_suscriptor`**, no de la cuenta. Únicamente la rama
`portafolio = 'CO'` necesita el tipo de cuenta. Si el productor puede entregar
el `cod_suscriptor` de seis dígitos —no su hash— se podría reproducir casi todo
el clasificador **sin esperar a F2**. Esa es la pregunta más rentable de todo
este documento.

---

## Bloque C — lo que faltaba pedir: `EMA020`

Apareció al auditar las 47 características una a una, y no estaba en ninguno
de los dos bloques anteriores.

| Objeto del legado | Quién lo lee | Para qué |
|---|---|---|
| `REC_VISTA.V_Ind_Efectiv_Orden_Peso_Email` | `Caracteristicas.txt:2713-2714` | `Peso_Ind_Efectividad` y `Descripcion_Ind_Efectividad`. **Es toda la característica `CO01EMA020`**: el legado la resuelve cruzando esa vista contra `Gestion_Contactabilidad` |
| `Gestion_Contactabilidad` | `NUM_TOTAL_REPORTE`, `:2711-2712` | la columna de hechos. **Su catálogo sí llegó** (`21_ddl_catalogos_dominio.sql:49-62`, `VALIDA`=61197 / `NO VALIDA`=61196); lo que falta es el dato por reporte, que hoy se sintetiza con una expresión regular sobre el valor de contacto |

Matiz que conviene decir al productor: la categorización de `EMA020` en el
legado usa una cubeta **negativa** (`-1`) y deja un hueco sin asignar entre 0 y
9 (`:686-696`). No la hemos portado a propósito — aplicarla sobre nuestro valor
sustituto daría un score peor, no mejor.

---

## Qué pedimos, en una línea

1. El **Bloque A** completo: es la condición necesaria para la Fase 2.
2. Del **Bloque B**, por orden de rendimiento: `bloqueo`,
   `relacion_ubicac_estandar_Geo`, `v_gestion_registro`.
3. El **`cod_suscriptor` de seis dígitos** expuesto tal cual. Desbloquea
   cuatro características de la Fase 4 que hoy están escritas y alimentadas
   con sustitutos.
4. El **Bloque C**, que es pequeño y cierra `EMA020` por sí solo.

**Y antes de enviar nada, el paso 0, que es nuestro y cuesta una sesión:**
correr `deploy/redshift/SQL/diagnostico_datashare_edf_views.sql` contra DEV.
Enumera el catálogo real de `edf_views` y mide qué fracción de los reportes
cae al hash de `id_buro_suscriptor`. Lo segundo ya no hace falta pedírselo al
productor —la pregunta estaba en este documento como petición y resulta que es
una consulta nuestra—, y lo primero puede dejar sin objeto la mitad del
Bloque A.
