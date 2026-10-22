# Ticket a EDF — cinco relaciones enmascaradas bloquean Reconocer en Redshift

*Redactado para pegarse tal cual. Fecha: 2026-10-22. Medido contra el Redshift
de DEV, consumidor `dba_rncr_batch`.*

## Resumen en una línea

De las nueve relaciones que Reconocer lee del datashare `ds_dba_rncr_batch`,
**cinco tienen máscara y no se pueden consultar desde el clúster consumidor**.
Mientras sigan así, **el proceso no entrega una sola fila** con datos reales.

## Qué pedimos

Levantar la máscara **para el consumidor `dba_rncr_batch`** sobre estas cinco:

| # | Relación | Qué bloquea de Reconocer |
|---|---|---|
| 1 | `edf_views.xpm_location_val_contactinformations` | **Unificación completa**, los cuatro canales del Ordenamiento y dos de las siete tablas dominio. **Es la más crítica** |
| 2 | `edf_views.xpm_bestaccounts` | Fase 2 del Ordenamiento (cuentas, comportamiento y bloqueo de cuenta) |
| 3 | `edf_views.xpm_personalinformation` | Actividad económica (tabla dominio `MAT_INFO_ACTIVIDAD_ECONOMICA`) |
| 4 | `edf_views.xpm_chamberofcommerce` | la misma |
| 5 | `edf_views.xpm_bestidentifications` | Información básica (tabla dominio `MAT_INFO_BASICA`) |

**No hace falta tocar el resto.** Estas cuatro ya responden:
`xpm`, `xpm_location`, `xpm_counterparties` y
`xpm_bestaccounts_val_frequentbehaviour`.

## El error, literal

```
SQL Error [XX000]: ERROR: cross-cluster query of the masked relation
  "xpm_personalinformation" is not supported.
```

Idéntico para las cinco, cambiando el nombre. Lo devuelve un simple
`SELECT COUNT(*)`.

## Por qué no se resuelve con un GRANT

Redshift **no permite consultar a través de un datashare una relación que
tenga una política de enmascaramiento aplicada**. No es falta de permisos: el
consumidor está en otro clúster y sus roles no son los del productor, así que
el motor rechaza la consulta entera en lugar de arriesgarse a servir el dato
sin aplicar la política.

Las tres salidas que conocemos, para que elijan la que encaje con su política
de privacidad:

1. **Excluir al consumidor `dba_rncr_batch`** de la política sobre esas cinco.
2. **Publicar una vista sin máscara** en `edf_views` y compartir esa.
3. **Materializar** la relación del lado productor y compartir la copia.

Nos sirve cualquiera de las tres.

## Cómo lo medimos, por si quieren reproducirlo

Nueve `SELECT COUNT(*)`, uno por relación, corridos en una sesión contra DEV
sin parar en el primer error. Están en
`dt/deploy/redshift/SLCOPRBA-1353/SQL/diagnostico_datashare_edf_views.sql`
(líneas 156-164). El que devuelve número se puede consultar; el que devuelve
`XX000` está enmascarado.

## Antecedente que conviene conocer

`xpm` **estaba** enmascarada y tumbó el despliegue de DEV (job DEV/DATABASE
#453, `[REDSHIFT:112]`). **Ya la levantaron y hoy responde**, lo que confirma
que el cambio es viable y que esta petición es la continuación de aquella, no
una nueva.

## Detalle técnico, si hace falta trazarlo

| Relación enmascarada | Vistas nuestras que la leen |
|---|---|
| `xpm_location_val_contactinformations` | `v_xpm_contacto_direccion`, `v_xpm_reporte_relacion_persona_ubica`, `v_xpm_contacto_canal` |
| `xpm_bestaccounts` | `v_xpm_cuenta`, `v_xpm_comportamiento_cta`, `v_xpm_cuenta_bloqueada` |
| `xpm_personalinformation` | `v_xpm_actividad_economica_persona` |
| `xpm_chamberofcommerce` | `v_xpm_actividad_economica_persona` |
| `xpm_bestidentifications` | `v_xpm_persona_basica` |

**Las vistas se crean sin problema** — `CREATE VIEW` no ejecuta la consulta —,
de modo que el despliegue de la estructura pasa y el fallo aparece sólo al
leerlas. Por eso no se detectó antes.
