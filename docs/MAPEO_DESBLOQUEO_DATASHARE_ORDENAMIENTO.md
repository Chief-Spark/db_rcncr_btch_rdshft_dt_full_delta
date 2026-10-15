# Mapeo de las 8 bloqueadas contra el catalogo real del datashare

SLCOPRBA-1355. UTF-8 sin BOM, ASCII sin acentos a proposito.

Fecha del catalogo: 2026-10-15, volcado de `svv_all_columns` sobre
`ds_dba_rncr_batch.edf_views` aportado en sesion.

---

## ACTUALIZACION 2026-10-15: dos de las ocho ya no estaban bloqueadas, estaban MAL

Llego el volcado de `REC_VISTA.V_Tipo_Cuenta_Ord` (44 filas) y al abrir el
codigo para enchufarlo aparecio algo peor que un bloqueo: **`CEL019` y
`EMA021` no calculaban otra cosa por falta de dato, calculaban otra cosa a
secas**, y su numero entraba en la suma del score con beta completa.

| | Hacia | Dice el legado |
|---|---|---|
| `CEL019` | `% de filas con tipo_cuenta = 'POSPAGO'` | `MAX(V_Tipo_Cuenta_Ord.Valor)` (`Caracteristicas.txt:112`) |
| `EMA021` | `COUNT(*)` | banderas 50/25/12/8/5 por tipo de cuenta (`:235`) |

Las dos estan portadas y certificadas con los arquetipos ARQ 85 y ARQ 86.
Son 299,79 puntos de beta que estaban midiendo ruido.

**Y corrige dos filas de la tabla de "lo que hay que pedir" de mas abajo:**

- `Insumo_Caracteristica` **no es un insumo y no hay a quien pedirselo**: se
  genera dentro del proceso y depende de migrar la Fase 2. `DIR034FI` y
  `DIR050TO` no esperan a una mesa, esperan a F2.
- `V_Ind_Efectiv_Orden_Peso_Email` sigue sin volcado, y ademas **su llave
  depende del hueco de `Gestion_Contactabilidad`**, que no tiene origen ni en
  el legado (0 ocurrencias en `src/teradata/`). Son dos problemas encadenados,
  no uno. Es el unico bloqueo de verdad que queda.

---

## El titular

**De las 8 bloqueadas, 5 no estan bloqueadas por el datashare: estan
bloqueadas por una vista que no hemos escrito. 1 depende de un catalogo que
hay que pedir, y 2 necesitan una definicion que el legado tampoco tiene.**

Y las 3 "aproximadas" (`DIR010FI`, `DIR013OT`, `EMA016`) se vuelven exactas
con el mismo trabajo.

**Correccion de una afirmacion anterior.**
`docs/PETICION_DATASHARE_F1_F3_ORDENAMIENTO.md:28` decia que el datashare
expone cuatro objetos, "verificado sobre los 25 archivos de DDL del repo de
estructura". Eso verifica lo que LEEMOS, no lo que el datashare CONTIENE. El
catalogo lo desmiente: ademas de `xpm`, `xpm_location`,
`xpm_location_val_contactinformations` y `xpm_counterparties` existen al
menos `xpm_bestaccounts` (~80 columnas), `xpm_bestaccounts_val_frequentbehaviour`,
`xpm_globalindebtedness`, `xpm_counterparties_val_businesslines`,
`xpm_identifications`, `xpm_legal`, `xpm_names` y `xpm_personalinformation`.

---

## El hallazgo que lo cambia todo: el contacto y la cuenta van en la misma fila

El legado trae los atributos de cuenta a la fila de direccion con un join por
`Cod_DW_Cta`:

```
V_DIRECCIONES_TEMP_DF.Cod_DW_Cta = CTA_TOTALES_PERSONAS_TMP3.Cod_DW_Cta
```

y de ahi cuelgan `Sector`, `Portafolio_Nuevo`, `Cod_Tipo_Cta_Fte` y
`cod_suscriptor` (`Caracteristicas.txt:219`, `:259`; `PRO_ORD_CTA_TOTALES_PERSONAS_2.sql:303-400`).

**En el datashare ese join no hace falta: `xpm_location` ya trae la cuenta en
la propia fila.** Cada fila de `xpm_location` es "este suscriptor reporto este
contacto para esta cuenta", que es exactamente el grano de
`V_DIRECCIONES_TEMP_DF` despues del join.

| Lo que el legado busca por `Cod_DW_Cta` | Columna de `xpm_location` | Ya la leemos? |
|---|---|---|
| `cod_suscriptor` | `location.val.counterpartyidnumber` | **si**, pero la colapsamos contra un hash |
| `Cod_Tipo_Cta_Fte` | `location.val.accounttype` | no |
| subtipo de cuenta | `location.val.subaccounttype` | no |
| identidad de la cuenta (`Cod_DW_Cta`) | `location.val.accountnumber` | no |
| linea de negocio | `location.val.businesslinecode` | no |
| razon de bloqueo (criterio F3-01) | `location.val.blockreason`, `location.val.subscriberblockstatus` | no |
| estrato | `location.val.stratum` | no |

De las 19 columnas que el catalogo muestra en `xpm_location` leemos **cuatro**.

---

## Mapeo caracteristica a caracteristica

| Caracteristica | Dato del legado que falta | Columna del datashare | Veredicto |
|---|---|---|---|
| `CEL020` | `Cod_Suscriptor`, en las dos ramas del cociente (`:1589-1590`, `:1154-1155`) | `location.val.counterpartyidnumber` | **DESBLOQUEADA HOY.** Ya leemos la columna |
| `DIR001IN` | `Portafolio_Nuevo = 'IN'` (`:2123`) | derivable: prefijo `05` de `counterpartyidnumber` | **DESBLOQUEADA HOY** |
| `DIR004RO` | `Portafolio_Nuevo = 'RO'` (`:2917-2918`) | derivable: prefijo `02`/`03` | **DESBLOQUEADA HOY** |
| `EMA021` | `Cod_Tipo_Cta_Fte` (`:2768-2769`) | `location.val.accounttype` | **PORTADA Y CERTIFICADA** (ARQ 86) |
| `DIR034FI` | `Sector = 'FI'` mas el importe `CO00END005` | `Sector` si; importe: candidato en `xpm_globalindebtedness` | **MITAD.** El predicado si, la magnitud no |
| `CEL019` | `Cod_Tipo_Cta_Fte` mas los pesos de `V_Tipo_Cuenta_Ord` (`:1292-1295`) | `location.val.accounttype` mas `bdm_datos.catalogo_tipo_cuenta_ord`, cargado del volcado de 44 filas | **PORTADA Y CERTIFICADA** (ARQ 85) |
| `DIR050TO` | `CO00MOR037` / `CO00MOR038` de `Insumo_Caracteristica` (`:3117-3121`) | candidatos en `xpm_bestaccounts.maximumdelinquency`, `...numberofdelinquenciesof30days`, `xpm_bestaccounts_val_frequentbehaviour.installmentsoverdue` | **SIN DEFINICION.** Ver abajo |
| `EMA020` | pesos de `V_Ind_Efectiv_Orden_Peso_Email` cruzando `Gestion_Contactabilidad` (`:2713-2714`) | ninguna | **SIGUE BLOQUEADA.** Es lo unico que hay que pedir de verdad |

Y las tres que hoy llevan la forma portada con el dato aproximado:

| Caracteristica | Hoy | Con `Sector` real |
|---|---|---|
| `DIR010FI` | `sector_financiero` 0/1 | predicado `Sector = 'FI'` exacto |
| `DIR013OT` | idem | predicado `Sector = 'OT'` exacto |
| `EMA016` | idem | idem |

---

## Por que `Sector` es trabajo nuestro y no una peticion

`Sector` no lee ninguna columna de origen. Es un colapso de cinco vias sobre
`Portafolio_Nuevo` (`PRO_ORD_CTA_TOTALES_PERSONAS_2.sql:391-396`, verificado):

```
CO -> CO ; CC -> CC ; RC,RS -> RE ; IN,RO,HP,VE,CP,FR -> FI ; resto -> OT
```

Y `Portafolio_Nuevo` tiene **once ramas, de las cuales diez dependen solo del
prefijo de dos digitos de `cod_suscriptor`** (`:378-389`). La unica que
necesita mas es `'CO'`, que exige `Flag_Comp_Cta_Activo = 'Y'`,
`Flag_Comp_Cta_Pasivo <> 'Y'`, `Cod_Tipo_Rel_Con_Cta_Fte = 'C'` y
`CAST(Cod_Tipo_Cta_Fte AS INTEGER) <> 2` (`:316-318`).

La rama `'VE'` lleva una lista de **66 codigos de seis digitos** escritos a
mano (35 con prefijo `04`, 1 con `05`, 7 con `18`, 1 con `20`, 22 con `45`).
Son dato, no logica: van a un catalogo en `strct`, no a un `CASE` en un SP.

**Trampa de portabilidad.** Todos los literales del `CASE` legado son
numericos sin comillas (`IN (02,03)`, `IN (040003, ...)`) mientras
`cod_suscriptor` es caracter. Teradata coacciona a numero, asi que los ceros
a la izquierda son irrelevantes. Un port a Redshift tiene que **comparar
numericamente**, o normalizar los ceros en ambos lados; comparar como texto
da un resultado distinto. No hay `LPAD` ni `TRIM` en el legado: cero
ocurrencias de `LPAD` en todo `src/teradata/`.

---

## Lo que de verdad hay que pedir, y a quien

Tres cosas, y ninguna es "la rama accounts del payload".

| Que | Por que no se puede derivar | Afecta a |
|---|---|---|
| `REC_VISTA.V_Ind_Efectiv_Orden_Peso_Email` (`Descripcion_Ind_Efectividad`, `Peso_Ind_Efectividad`) | es un **catalogo de pesos de contactabilidad**, no dato de buro. Referenciado una vez en todo el legado y **nunca cargado** | `EMA020` entera |
| ~~`REC_VISTA.V_Tipo_Cuenta_Ord`~~ **ENTREGADO 2026-10-15** | 44 filas, cargadas en `strct/.../22_ddl_catalogo_tipo_cuenta_ord.sql`. Faltan los tipos 17, 25, 26, 34, 37, 50 y 51, y el datashare entrega justo `'17'`, `'34'` y `'51'`: el legado los deja caer a categoria 0 sin dar error, y asi se porta | nada: `CEL019` esta cerrada |
| ~~la definicion de `REC_STAGE.Insumo_Caracteristica`~~ **NO ES UNA PETICION** | no es un insumo: se genera dentro del proceso y depende de migrar la Fase 2. Que no aparezca en el arbol del Ordenamiento es coherente con eso | `DIR034FI`, `DIR050TO`, que esperan a F2 |

**De las tres solo queda una**, y sale del **Teradata de origen**, no del
productor del datashare.

Lo que se puede decir de esas columnas desde el consumidor, y nada mas:

- `CO00END005`: grano por cuenta, almacenada como **texto** con los seis
  centinelas `-1,-2,-3,-4,-88,-99`, convertida con
  `CAST(... AS DECIMAL(18,2))`. Familia `END` = endeudamiento
  (`Caracteristicas.txt:219`).
- `CO00MOR037` / `CO00MOR038`: grano por cuenta, probadas con `> 0` **sin
  filtro de centinelas** (`Caracteristicas.txt:259`). Familia `MOR` = mora.
  Si se portan, hay que reproducir el `> 0` literal: un `-99` falla la
  comparacion y eso es precisamente el comportamiento legado.

---

## Orden de trabajo recomendado

1. **Dejar de colapsar el suscriptor real contra el hash.** Separar
   `id_buro_suscriptor` en dos columnas: el codigo real y el relleno. Hoy
   `02_vistas_insumo_edf_views.sql:319-333` los funde en un `COALESCE`, y
   `EMA015` cuenta cubetas de hash como si fueran suscriptores.
2. **Medir la cobertura** de `counterpartyidnumber` y su forma (longitud y
   prefijo). `deploy/redshift/SQL/diagnostico_datashare_edf_views.sql`,
   consultas 3 y 4. Decide si el paso 3 es viable hoy o parcial.
3. **Construir el clasificador** `Portafolio_Nuevo` / `Sector` en `strct`:
   un catalogo de prefijos, un catalogo de los 66 codigos `VE`, y la columna
   derivada en la vista de insumo. Desbloquea `DIR001IN`, `DIR004RO`, y
   vuelve exactas `DIR010FI`, `DIR013OT`, `EMA016`.
4. **Subir `accounttype` al insumo** desde `xpm_location`. Desbloquea
   `EMA021` y deja `CEL019` a la espera solo del catalogo de pesos.
5. **Sembrar y certificar**, arquetipo por arquetipo, como las 34 corregidas.

**Lo que no se hace:** escribir nada sobre `xpm_bestaccounts` todavia. Su
relacion con `xpm_location` por `accountnumber` esta sin verificar, y el
legado advierte que la llave natural de una cuenta no es
`(accountnumber, accounttype)` sino al menos
`(Num_Cta, Cod_Tipo_Cta_Fte, Id_Buro_Suscriptor)`: el mismo numero de cuenta
lo reportan suscriptores distintos. Verificar antes de unir.
