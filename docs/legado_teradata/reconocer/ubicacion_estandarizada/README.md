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

La nomenclatura del proceso, confirmada por el usuario el 2026-10-21:
`_111` = setup (DDL y estructuras de staging), `_120` = carga del insumo,
`_130` = transformación, `_140` = exportación. El `_131.BTQ` invoca los SPs
de estandarización.

| Archivo | Para qué | Prioridad |
|---|---|---|
| `PRO_Consolida_Estandarizacion` y `PRO_CARGA_INSUMO_STANDARD_2` | **la regla de validez.** El `_131.BTQ` solo los invoca, y la regla 4 dice que manda el código | **1** |
| `P0001_UBICACION_ESTANDARIZADA_111.BTQ` | el DDL de las seis tablas destino: ¿alguna lleva `Lote` o `Lote_Actualizacion`? | **2** |
| `P0001_UBICACION_ESTANDARIZADA_130.TPT` | el `CASE` de `Severidad` y el upsert | 3 |
| `_120.TPT` y `_140.TPT` | cierran la familia | 4 |

## Por qué la regla de validez importa más que el resto

**Este proceso corre hoy en EDF, no en Redshift** (usuario, 2026-10-21):
produce las columnas `standardized*` del XPM y es donde se calcula la
validez o gestión de la dirección — el `NO VALIDA` que no llega en el
datashare.

Eso toca dos cosas que hoy resolvemos por aproximación:

- **D-EDF-12.** Derivamos `VALIDA` / `NO VALIDA` del score de
  estandarización con el umbral `>= 0.80` decidido por el usuario, porque
  Confluence documenta la escala 0-1 pero no el umbral. Si el legado lo trae
  escrito, dejamos de aproximar.
- **`F3-10`** está BLOQUEADO con el argumento de que `'NO VALIDA'` no aparece
  en el legado de F1-F3, y es cierto: buscado en sus 13.826 líneas. **Pero
  nunca se buscó en P0001**, que es donde se calcula. El criterio puede no
  estar bloqueado, sino mal buscado.
