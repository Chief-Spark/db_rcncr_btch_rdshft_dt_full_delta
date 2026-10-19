# Legado Teradata de las Fases 1, 2 y 3 del Ordenamiento

**Por qué está aquí.** La regla 4 del proyecto dice que *el documento funcional
se equivoca; el código manda*. Para portar F1-F3 hay que leer estos 18
archivos, y hasta ahora no existía copia de ellos en ningún repositorio: vivían
en un directorio temporal que se pierde al cerrar la sesión. Quedan fijados
aquí.

**No se despliega.** `docs/` está fuera de `deploy/redshift/`, que es lo único
que viaja a Bitbucket, y fuera también del barrido de `validar.sh`
(`validar.sh:18`, `ROOT="deploy/redshift/SLCOPRBA-1353"`). Son fuente de
consulta, no entregable.

**Origen:** `ws-ordenamiento/src/teradata/`. 18 archivos, 13.826 líneas.

---

## Qué archivo pertenece a qué fase

El reparto sale de la evidencia de cada criterio en
`bdm_datos.cert_criterio_ord` y de `docs/PETICION_DATASHARE_F1_F3_ORDENAMIENTO.md`,
no de los encabezados: **los encabezados no dicen la fase**, solo repiten la
misma firma de seis parámetros.

### Fase 1 — Materialización (4 archivos, 2.294 líneas)

*¿Qué personas cambiaron desde la última ejecución?*

| Archivo | Líneas | Qué hace |
|---|---|---|
| `PRO_ORD_MATERIALIZA_BTT.sql` | 730 | delta del modelo de crédito. Lee `V_COMPORTAMIENTO_CUENTA` y `V_BURO_PERSONA` (5 veces) |
| `PRO_ORD_MATERIALIZA_REC.sql` | 949 | delta del modelo de ubicaciones. Lee `V_UBICACION_ORIGINAL`, `V_Log_Ubicacion_Estandariza`, `bloqueo` |
| `PRO_ORD_UNIF_BTT_REC.sql` | 206 | une los dos universos |
| `PRO_ORD_UNIF_BTT_REC_2.sql` | 409 | ídem, segunda pasada |

> **Esta fase NO se porta: se re-especifica.** Sus pasos existen para detectar
> el delta con `bdm_mtdat.MetadataCargaLog` y `dbc.tables`, que son plomería de
> Teradata sin contraparte en Redshift. El equivalente ya existe: el alcance
> por `p_lote` / `p_watermark` de
> `sp_ordenamiento_preparar_insumos_edf.sql:36-67`.

### Fase 2 — Atributos de Cuenta (6 archivos, 1.576 líneas)

*¿Qué crédito tiene cada persona?*

| Archivo | Líneas | Qué hace |
|---|---|---|
| `PRO_ORD_CTA_ATRIBUTOS.sql` | 368 | extrae las cuentas del universo. Lee `VU_CUENTA` (`:163`), `V_Razon_Bloqueo` (`:298`), `V_FUENTE_DATO` (`:301`), `V_COD_ENTREGA_DATO` (`:304`) |
| `PRO_ORD_CTA_TOTALES_PERSONAS.sql` | 138 | arranque de los totales |
| `PRO_ORD_CTA_TOTALES_PERSONAS_1.sql` | 224 | comportamiento **activo** en la ventana de 12 meses (`:106`) |
| `PRO_ORD_CTA_TOTALES_PERSONAS_2.sql` | 453 | comportamiento **pasivo** (`:106`) y, sobre todo, **el portafolio y el Sector** (`:376-396`) |
| `PRO_ORD_CONCAT_ATRIBUTOS.sql` | 161 | arma el campo `concatena` del hash |
| `PRO_ORD_FINAL_CTA_ATRIBUTOS.sql` | 232 | persistencia por hash MD5 contra `CUENTA_ATRIBUTO_HASH` |

**CUIDADO: HAY DOS COLUMNAS DE PORTAFOLIO EN ESTE ARCHIVO, Y CONFUNDIRLAS
CUESTA EL PLAN ENTERO.** *(Este párrafo decía antes que «el corazón de F2 son
20 líneas» y que `F2-05` no coincidía con el código. Las dos afirmaciones eran
falsas y salían de haber leído la columna equivocada.)*

| Columna | Dónde | Qué es | Valores |
|---|---|---|---|
| `Portafolio_Nuevo` | `:376-389` | prefijo de dos dígitos del `cod_suscriptor`; decide el `Sector` (`:391-396`). **Ya está portada**, con catálogo en `23_ddl_catalogo_portafolio_ord.sql` | **once**: `RO, IN, VE, HP, FR, CC, CP, RC, RS, CT, OT` |
| `Portafolio` | `:304-375` | **la de `F2-05`**: un `CASE` anidado de **179 líneas** | **nueve**: `AH, CC, CO, CT, HP, IN, OT, RO, VE` |

**`F2-05` y el código SÍ coinciden**: los nueve del `CASE` son exactamente los
nueve que el criterio nombra. No hay divergencia que documentar.

**Y F2 es la fase MÁS cara de las tres, no la más barata.** El `Portafolio`
consume **nueve** columnas y de ellas hoy solo tenemos `cod_suscriptor`:

```
Cod_Tipo_Cta_Fte     Cod_Tipo_Obligacion_Fte   Cod_Tipo_Rel_Con_Cta_Fte
Cod_Clase_Garantia_Buro_Fte                    NUM_CUOTAS_PACTADAS
Cod_suscriptor       Cod_DW_Cta
Flag_Comp_Cta_Activo  Flag_Comp_Cta_Pasivo   <- son F2-03 y F2-04
```

Las dos banderas son justo lo que `F2-03` y `F2-04` piden, y lo que destraba la
rama `'CO'` que `23_ddl_catalogo_portafolio_ord.sql` dejó sin construir.

Dos detalles más antes de escribir una línea:

1. La ventana de 12 meses es **por cuenta**, no global:
   `add_months(fecha_nov, -12)` sobre la `fecha_nov` de cada cuenta
   (`PRO_ORD_CTA_TOTALES_PERSONAS.sql:93`). Es `F2-02`.
2. La rama de `VE` de `Portafolio_Nuevo` lleva **35 `cod_suscriptor` literales**
   enumerados. Se copian uno a uno.

### Fase 3 — Ubicaciones (7 archivos, 3.042 líneas)

*¿Qué direcciones entran al scoring, y cuáles cambiaron?*

| Archivo | Líneas | Qué hace |
|---|---|---|
| `PRO_ORD_CALC_UBICACIONES.sql` | 574 | vector de ubicaciones. Lee `VU_CUENTA` (`:126,328`) |
| `PRO_ORD_CALC_UBICACIONES_1.sql` | 284 | ídem (`:104`) |
| `PRO_ORD_CALC_UBICACIONES_2.sql` | 1.316 | **el más grande de los 17.** Anti-join contra `bloqueo` (`:263`), `V_Tipo_persona`, `v_tipo_cuenta`, `v_gestion_registro`, `V_Geografia`, y la coincidencia geográfica (`:1180`) |
| `PRO_ORD_UBIC_DIRECCIONES.sql` | 244 | direcciones del vector |
| `PRO_ORD_FINAL_UBIC_DIRECCIONES.sql` | 247 | persistencia por hash (`:122,222`) |
| `PRO_ORD_FINAL_UBIC_DIRECCIONES1.sql` | 236 | ídem |
| `PRO_ORD_CONCAT_DIRECCIONES.sql` | 141 | arma el `concatena` del hash de dirección |

Los dos predicados de exclusión están en el orquestador, no en los SP, y van
juntos en el mismo `WHERE`:

```sql
   LEFT JOIN  <bddatos>.bloqueo d
          ON  b.cod_dw_persona_ubic = d.cod_dw_persona_ubic
        WHERE d.cod_dw_persona_ubic IS NULL   -- F3-01: anti-join de bloqueo
          AND b.Ind_Unificacion     IS NULL   -- F3-02 y F3-11: solo vigentes
```

`Prc_Ordenamiento2.sql:1122-1126`. Es un **anti-join**, no un filtro de fila:
excluye el `cod_dw_persona_ubic` entero. La misma distinción que costó una
divergencia en Novedades, donde nuestro `COALESCE(bloqueado, 0) = 0` excluía la
fila y el legado excluye el id.

### El orquestador

`Prc_Ordenamiento2.sql`, 6.914 líneas. **No se lee en línea recta**: arma
cadenas de SQL y las ejecuta con `REC_DATOS.SP_EXECSTRING_DES` y
`DBC.SysExecSQL`. Para seguir la secuencia hay que buscar esas dos llamadas;
para entender *qué* se ejecuta, los 17 SP de arriba.

---

## Lo que ya no hace falta buscar aquí

| Objeto del legado | Por qué no se porta |
|---|---|
| `METADATA_ORDENAMIENTO`, `Control_Ordenamiento`, `log_td` | sustituidos por `bdm_datos.ord_control` y `ord_control_etapa` |
| `bdm_mtdat.MetadataCargaLog`, `dbc.tables` | plomería de Teradata; el alcance en Redshift es por lote y watermark |
| UDF `rec_vista.hash_md5()` | Redshift trae `MD5()` nativo. Conviene comparar una salida byte a byte una sola vez: `F2-07` y `F3-04` exigen exactamente 32 caracteres |
| `CUENTA_ATRIBUTO_HASH` y `UBICACION_ATRIBUTO_HASH` del legado | **desactivados en producción desde 2018-10-05.** Se reconstruyen en Redshift, no se migran |
| `TMP_UBICA_ETAPA_0` y demás temporales de paso | `F1-05` solo exige que se borren |
