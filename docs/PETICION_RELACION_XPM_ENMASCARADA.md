# Bloqueo: la relación `xpm` del datashare está enmascarada

*Para EDF / DevSecOps. Fecha: 2026-10-22. Es el bloqueo de mayor impacto
abierto hoy: **sin esto la vía real de Reconocer no devuelve una sola fila**.*

## El error, literal

Job **DEV/DATABASE #453**, durante el despliegue de `strct`:

```
Failed [Redshift][ODBC Driver][Server]XX000:ERROR:
  cross-cluster query of the masked relation "xpm" is not supported
```

Tumbó el build con `[REDSHIFT:112] código 12` en el archivo 17 de 49.

## Qué relación es, y por qué importa tanto

`ds_dba_rncr_batch.edf_views.xpm`, el consumidor `dba_rncr_batch` del
datashare `ds_dba_rncr_batch`.

**Es la raíz de todo el modelo.** De ella sale la identidad de la persona:

```sql
FNV_HASH(xpm.pin)      AS id_buro_persona
CAST(xpm.pin AS BIGINT) AS cod_pin_persona
```

Hay **17 referencias** a esa relación en los tres archivos de vistas del
paquete (`02_vistas_insumo_edf_views.sql` 15, `03_vistas_contacto_canal` 1,
`04_vistas_insumo_ordenamiento` 1). Toda vista `v_xpm_*` que identifique a una
persona pasa por ahí.

## Lo que esto bloquea, y lo que no

| | Estado |
|---|---|
| Crear las vistas (`CREATE OR REPLACE VIEW`) | **funciona** — no ejecuta la consulta, por eso el despliegue pasaba hasta ahora |
| Consultar cualquier vista `v_xpm_*` | **bloqueado** |
| Unificación, Ordenamiento y Novedades por la vía REAL | **bloqueado** |
| La batería de certificación (mock) | **no afectada** — vive en `bdm_stage` |

Es decir: **el error aparece la primera vez que algo EJECUTA una consulta
contra el datashare**, no al desplegar la estructura. Por eso no había salido
antes: el primer sitio que la ejecutaba era la carga de un catálogo.

## Qué pedimos

Que `edf_views.xpm` deje de estar enmascarada **para el consumidor
`dba_rncr_batch`**, o que se nos indique la vía soportada para leerla desde el
cluster consumidor.

Redshift no permite consultar a través de un datashare una relación con
máscara aplicada (dynamic data masking); no es un problema de `GRANT`, y por
eso no se resuelve con permisos. Las alternativas que conocemos, para que
elijan la que encaje con su política:

1. **Excluir a `dba_rncr_batch` de la política de máscara** sobre esa relación.
2. **Publicar una vista sin máscara** en `edf_views` y compartir esa.
3. **Materializar** la relación del lado productor y compartir la copia.

Nos sirve cualquiera de las tres: lo único que necesitamos es `pin` y las
columnas que ya consumimos.

## Mientras tanto, lo que hicimos de nuestro lado

Quitamos la **única** consulta al datashare que ocurría en tiempo de DDL
(`02_catalogos_ordenamiento.sql`, la carga de `catalogo_sector_financiero`).
Era una bandera que ya salía en cero y que el propio log del #453 imprime
como `catalogo_sector_financiero | 0`, así que no se pierde ni una fila y el
despliegue de la estructura deja de depender de que el dato esté disponible.

**Eso desbloquea el DESPLIEGUE, no la vía real.** La corrida real sigue sin
poder ejecutarse hasta que la máscara se levante.
