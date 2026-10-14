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

Cuatro objetos. Verificado sobre los 25 archivos de DDL del repo de estructura:

| Objeto | Lo usamos para |
|---|---|
| `edf_views.xpm` | persona (`pin`), CIIU, enlace a ubicación |
| `edf_views.xpm_location` | ubicación, fecha de corte, contraparte |
| `edf_views.xpm_location_val_contactinformations` | el contacto: dirección, teléfono, celular, correo |
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
| `relacion_ubicac_estandar_Geo` / `v_RELACION_UBICAC_ESTANDAR_GEO` | `PRO_ORD_CALC_UBICACIONES_2.sql:1180` | la coincidencia geográfica. Hoy `coincidencia_geo` está **fijada al literal 0** en el insumo, de modo que `TEL010` aporta una constante y `TEL020` no discrimina |
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
`DIR010FI`, `DIR013OT`, `DIR034FI`, `TEL017`, `CEL017` y `EMA016` **no son
portables con el insumo de hoy**, y por eso el Bloque A no es solo cuestión de
F2: también cierra seis características de la Fase 4 que ya están escritas.

Matiz honesto, y es favorable: **diez de las once ramas de `Portafolio_Nuevo`
dependen solo del `cod_suscriptor`**, no de la cuenta. Únicamente la rama
`portafolio = 'CO'` necesita el tipo de cuenta. Si el productor puede entregar
el `cod_suscriptor` de seis dígitos —no su hash— se podría reproducir casi todo
el clasificador **sin esperar a F2**. Esa es la pregunta más rentable de todo
este documento.

---

## Qué pedimos, en una línea

1. El **Bloque A** completo: es la condición necesaria para la Fase 2.
2. Del **Bloque B**, por orden de rendimiento: `bloqueo`,
   `relacion_ubicac_estandar_Geo`, `v_gestion_registro`.
3. El **`cod_suscriptor` de seis dígitos** expuesto tal cual, y el **porcentaje
   de reportes sin `counterpartyidnumber`**. Las dos cosas son baratas y
   desbloquean seis características de la Fase 4 que hoy están escritas y
   alimentadas con sustitutos.
