# P0001 UBICACION ESTANDARIZADA (legado Teradata)

Entregado el 2026-10-21 dentro de `archivos_120_tpt.zip`. De los ocho TPT de
ese zip, **siete eran byte a byte idénticos** a copias que el repo ya tenía;
este era el único material nuevo.

## Qué es este archivo, y qué no es

`P0001_UBICACION_ESTANDARIZADA_120.TPT` es un **job DDL de limpieza**: define
`RECHAZADOS_UBICACION_ESTANDARIZADA` (`:24`), un `DDL_OPERATOR` (`:27-37`) y un
único paso `DROP_RELEASE_TABLES` (`:38-78`) con los `DROP` de las temporales y
los `RELEASE MLOAD`.

**No carga, no proyecta columnas, no trae `Severidad` ni filtros.** No
contradice ni confirma nada de lo que el repo afirma sobre
`bdm_stage.ubicacion_estandarizada`.

## Lo único que aporta, y por qué importa

**El P0001 real escribe SEIS tablas destino**, `@TablaDestino1..@TablaDestino6`
(`:63-74`), con seis juegos de work y error (`@Wktb`, `@Wktb2`..`@Wktb6`,
`:41-58`). Nuestra `bdm_stage.ubicacion_estandarizada` es **una sola tabla de 8
columnas** (`strct/02a_ddl_bdm_stage_insumo_mock.sql:52-71`).

**Si alguna de esas seis lleva la columna `Lote`, ahí está el desbloqueo de
`F1-01` y `F1-08`**, los dos criterios del Ordenamiento que siguen en
BLOQUEADO porque `ubicacion_estandarizada` no tiene rastro temporal con el que
medir el delta.

**Es hipótesis, no prueba.** La plantilla de staging de esta familia de cargas
lleva `Lote INTEGER, Lote_Actualizacion INTEGER, Usuario_BD, Severidad INTEGER,
Cod_Rechazo VARCHAR(50)` (`P0029_INDICADORES_MOVILIDAD_120.TPT:45-57`, el único
de los ocho que crea tablas). Si el destino real de P0001 sigue esa plantilla,
tendría `Lote`. Para saberlo hace falta leerlo.

## Lo que falta pedir

| Archivo | Para qué |
|---|---|
| `P0001_UBICACION_ESTANDARIZADA_111.TPT` | el `SCHEMA` y las vistas `Vstg_*`: ahí están las columnas de las seis tablas |
| `P0001_UBICACION_ESTANDARIZADA_130.TPT` | el `CASE` de `Severidad` y el upsert: las reglas de carga |

Son dos archivos y desbloquean dos criterios. Van en el mensaje a Experian.
