# CERRADO — las nueve relaciones del datashare responden

*Actualizado el 2026-10-22. **Este ticket NO debe enviarse a EDF.***

## Conclusión

**Ninguna de las nueve relaciones que Reconocer lee de `ds_dba_rncr_batch`
está hoy enmascarada.** Lo que bloqueaba el proceso ya no es el datashare.

Este documento se conserva porque explica el síntoma y cómo se midió, pero
**la petición está retirada**: no hay nada que pedir.

## La evidencia, relación por relación

| Relación | Cómo se confirmó | Dato |
|---|---|---|
| `xpm` | job DEV/DATABASE #454 | carga de `catalogo_sector_financiero` |
| `xpm_location` | el mismo INNER JOIN | **1.188 filas** |
| `xpm_location_val_contactinformations` | el mismo INNER JOIN | un join de cuatro no devuelve filas si una tiene máscara |
| `xpm_counterparties` | el mismo INNER JOIN | |
| `xpm_personalinformation` | job DEV/DATABASE #458 | **124.263 filas** en `mat_info_actividad_economica` |
| `xpm_chamberofcommerce` | el mismo | 58.512 personas |
| `xpm_bestidentifications` | #458, error `42703` y no `XX000` | el error es de columna, no de máscara |
| `xpm_bestaccounts` | `SELECT COUNT(*)` en DBeaver contra DEV | **1.231.183 filas** |
| `xpm_bestaccounts_val_frequentbehaviour` | el mismo | **1.726.424 filas** |

## Qué pasó, y la lección de método

El síntoma era real: Redshift no permite consultar por datashare una relación
con máscara, y devuelve

```
XX000: ERROR: cross-cluster query of the masked relation "<rel>" is not supported
```

Eso tumbó el job #453 y es lo que originó este ticket.

**Pero el alcance se estimó tres veces y las tres salieron mal**, en las dos
direcciones:

1. **Cinco**, leyendo las flechas de un pantallazo. Falso por defecto: la sonda
   para en el primer error, de modo que lo que no falló no estaba limpio, sólo
   no se había probado.
2. **Nueve**, tomando el inventario de EDF. Falso por exceso: el inventario dice
   qué política existe, no cuál bloquea hoy.
3. **Cinco otra vez**, tras medir cuatro. También falso: seguía siendo una
   estimación, no una medición completa.

**La medición completa dio cero.** La lección, que vale para cualquier
dependencia externa: **un inventario no es una medición, y una sonda que para
en el primer error no mide el universo.** Lo único que cierra una pregunta así
es consultar las N relaciones, una por una, hasta el final.

## Lo que sí bloquea hoy, y es nuestro

Los dos defectos que el #458 dejó al descubierto en la vía real:

| Error | Dónde |
|---|---|
| `XX000: correlated subquery pattern is not supported` | el `NOT EXISTS` del filtro de bloqueo en `sp_ordenamiento_preparar_insumos_edf.sql` |
| `42846: cannot cast type boolean to character varying` | el `INSERT` a `mat_info_basica`, vía `v_xpm_persona_basica` |

Ninguno de los dos se arregla desde EDF.
