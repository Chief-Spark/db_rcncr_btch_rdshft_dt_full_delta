# Ticket a EDF — las nueve relaciones del datashare están enmascaradas

*Redactado para pegarse tal cual. Fecha: 2026-10-22.*

## Resumen en una línea

**Las nueve relaciones que Reconocer lee del datashare `ds_dba_rncr_batch`
tienen máscara**, y Redshift no permite consultar por datashare una relación
enmascarada. Mientras sigan así, **el proceso no entrega una sola fila** con
datos reales.

## Qué pedimos

Levantar la máscara **para el consumidor `dba_rncr_batch`** sobre estas nueve:

| # | Relación | Qué bloquea de Reconocer |
|---|---|---|
| 1 | `edf_views.xpm` | **la raíz del modelo**: `id_buro_persona = FNV_HASH(xpm.pin)`. 19 referencias en el paquete |
| 2 | `edf_views.xpm_location_val_contactinformations` | **Unificación completa**, los cuatro canales del Ordenamiento y dos tablas dominio |
| 3 | `edf_views.xpm_bestaccounts` | Fase 2 del Ordenamiento (cuentas, comportamiento, bloqueo de cuenta) |
| 4 | `edf_views.xpm_personalinformation` | Actividad económica (`MAT_INFO_ACTIVIDAD_ECONOMICA`) |
| 5 | `edf_views.xpm_chamberofcommerce` | la misma |
| 6 | `edf_views.xpm_bestidentifications` | Información básica (`MAT_INFO_BASICA`) |
| 7 | `edf_views.xpm_location` | atributos de la ubicación (tipo de cuenta, estrato, barrio) |
| 8 | `edf_views.xpm_counterparties` | identidad del suscriptor que reporta |
| 9 | `edf_views.xpm_bestaccounts_val_frequentbehaviour` | comportamiento de cuenta, Fase 2 |

**Nos sirve que se levanten por fases**, y si hay que priorizar el orden es el
de la tabla: sin la 1 y la 2 no arranca nada.

## El error, literal

```
SQL Error [XX000]: ERROR: cross-cluster query of the masked relation
  "xpm_personalinformation" is not supported.
```

Idéntico para todas, cambiando el nombre. Lo devuelve un simple
`SELECT COUNT(*)`.

## Por qué no se resuelve con un GRANT

Redshift **no permite consultar a través de un datashare una relación que
tenga una política de enmascaramiento aplicada**. No es falta de permisos: el
consumidor está en otro clúster y sus roles no son los del productor, así que
el motor rechaza la consulta entera en lugar de arriesgarse a servir el dato
sin aplicar la política.

Las tres salidas que conocemos, para que elijan la que encaje con su política
de privacidad:

1. **Excluir al consumidor `dba_rncr_batch`** de las políticas sobre esas nueve.
2. **Publicar vistas sin máscara** en `edf_views` y compartir ésas.
3. **Materializar** las relaciones del lado productor y compartir las copias.

Nos sirve cualquiera de las tres.

## Cómo lo medimos, por si quieren reproducirlo

Nueve `SELECT COUNT(*)`, uno por relación, corridos en una sesión contra DEV
sin parar en el primer error. Están en
`dt/deploy/redshift/SLCOPRBA-1353/SQL/diagnostico_datashare_edf_views.sql`
(líneas 156-164). El que devuelve número se puede consultar; el que devuelve
`XX000` está enmascarado.

## Antecedente

`xpm` tumbó el despliegue de DEV (job DEV/DATABASE #453, `[REDSHIFT:112]`) con
este mismo error, y se nos indicó que ya se le había retirado la máscara.
**Conviene confirmar si esa retirada se aplicó y sigue vigente**, porque es la
prueba de que el cambio es viable y marca el camino para las ocho restantes.

## Detalle técnico, si hace falta trazarlo

| Relación | Vistas nuestras que la leen |
|---|---|
| `xpm` | prácticamente todas: es la raíz de la identidad |
| `xpm_location_val_contactinformations` | `v_xpm_contacto_direccion`, `v_xpm_reporte_relacion_persona_ubica`, `v_xpm_contacto_canal` |
| `xpm_bestaccounts` | `v_xpm_cuenta`, `v_xpm_comportamiento_cta`, `v_xpm_cuenta_bloqueada` |
| `xpm_personalinformation` | `v_xpm_actividad_economica_persona` |
| `xpm_chamberofcommerce` | `v_xpm_actividad_economica_persona` |
| `xpm_bestidentifications` | `v_xpm_persona_basica` |
| `xpm_location` | `v_xpm_ubicacion_estandarizada`, `v_xpm_direccion_fisica` |
| `xpm_counterparties` | `v_xpm_reporte_relacion_persona_ubica` |
| `xpm_bestaccounts_val_frequentbehaviour` | `v_xpm_comportamiento_cta` |

**Las vistas se crean sin problema** — `CREATE VIEW` no ejecuta la consulta —,
de modo que el despliegue de la estructura pasa y el fallo aparece sólo al
leerlas. Por eso no se detectó antes.
