# Resultados esperados — certificación mock FULL/DELTA

> SLCOPRBA-1356. Acompaña a `deploy/redshift/SQL/seed_mock_matriz.sql`.
> Entrega parcial: **Regla 1 completa (ARQ 1..20)**. Regla 2 (ARQ 21..55) pendiente.

## Método

Las semillas se generan por **arquetipos**, no al azar. Un arquetipo es una celda
de la matriz *escenario de regla × posición respecto al Watermark*, replicada
`N` veces (N = 1000) con identificadores distintos y estructura idéntica. El
resultado esperado es por tanto exacto:

```
filas_esperadas(arquetipo) = N × filas_por_caso
```

Todo se deriva de `bdm_stage.mock_numeros.i`. **No hay `RANDOM()`**: dos
ejecuciones producen exactamente los mismos datos.

### Identificadores

| Campo | Fórmula |
|---|---|
| `id_buro_persona` | `9000000 + ARQ*10000 + i` |
| `cod_dw_persona_ubic` | `id_buro_persona*10 + k` (k = 1 padre, 2 hija) |
| `cod_dw_ubic` | `id_buro_persona*10 + 1` (compartido: mismo texto) |
| `cod_dw_direccion_fisica` | `= cod_dw_persona_ubic` |

El arquetipo se recupera con `ARQ = (id_buro_persona - 9000000) / 10000`, así que
los gates agrupan por caso sin tabla auxiliar. Estos ids no colisionan con los
reales, que son `FNV_HASH(pin)` (64 bits, típicamente negativos).

### Posiciones respecto al Watermark

El FULL siembra el Watermark con `MAX(fecha_relacion_persona_ubicaci)` = `2026-03-01`.
La ventana DELTA es entonces `fecha >= 2026-03-01 OR fecha IS NULL`.

| Posición | Semilla | Qué certifica |
|---|---|---|
| `DENTRO` | ambas fechas `2026-03-01` | caso base |
| `FUERA` | ambas `2024-01-15` | la persona queda fuera del driver |
| `NULL` | ambas NULL | el nulo es inclusivo |
| `CABALLO` | una `2026-03-01`, otra `2024-01-15` | **la ventana por persona** |
| `YA_UNIF` | fechas dentro, hija con `ind_unificacion = 1` | el incremental **por estado** del legado |

## Matriz de resultados — Regla 1

Filas en `unificacion_direccion_mock` **por réplica** (multiplicar por N):

| ARQ | Escenario | CIIU | Posición | FULL | DELTA |
|----:|---|---|---|----:|----:|
| 1 | E1 — padre LAB/CRR | `10` | DENTRO | 1 | 1 |
| 2 | E1 | `10` | FUERA | 1 | **0** |
| 3 | E1 | `10` | NULL | 1 | 1 |
| 4 | E1 | `10` | CABALLO | 1 | **1** |
| 5 | E1 | `10` | YA_UNIF | 0 | 0 |
| 6 | E2 — padre RES/CRR | `81` | DENTRO | 1 | 1 |
| 7 | E2 | `81` | FUERA | 1 | **0** |
| 8 | E2 | `81` | NULL | 1 | 1 |
| 9 | E2 | `81` | CABALLO | 1 | **1** |
| 10 | E2 | `81` | YA_UNIF | 0 | 0 |
| 11 | E3 — más entidades | `47` | DENTRO | 1 | 1 |
| 12 | E3 | `47` | FUERA | 1 | **0** |
| 13 | E3 | `47` | NULL | 1 | 1 |
| 14 | E3 | `47` | CABALLO | 1 | **1** |
| 15 | E3 | `47` | YA_UNIF | 0 | 0 |
| 16–20 | EMPATE | `10` | las 5 | 0 | 0 |

**Totales R1 con N = 1000:** FULL → **12 000** filas · DELTA → **9 000** nuevas
o re-tocadas (las 3 000 de `FUERA` sobreviven del FULL sin re-tocarse, con
`lote_actualizacion` en NULL).

### Por qué cada 0

- **`FUERA` en DELTA:** la persona no tiene ninguna relación en la ventana, así
  que no entra al driver. La fila creada por el FULL permanece intacta.
- **`YA_UNIF`:** la hija lleva `ind_unificacion = 1` y el filtro de estado del
  legado la excluye del insumo. La persona queda con una sola dirección: no hay
  pareja padre/hija.
- **`EMPATE`:** las dos direcciones empatan en score máximo y el ganador exige
  `HAVING COUNT(*) = 1`.

## Verificación previa a la ejecución

La matriz **no es una predicción**: se simuló la generación de semillas junto
con la lógica de `preparar_insumo` + los tres escenarios de R1 (score,
`ROW_NUMBER`, ganador único, emparejamiento con tipo distinto). Los 20
arquetipos arrojaron exactamente los valores de la tabla.

Además se corrió el **contrafactual** con la ventana anterior (por fila en vez
de por persona):

| ARQ | Posición | Ventana por persona | Ventana por fila |
|----:|---|---:|---:|
| 4 | CABALLO | 1 | **0** |
| 9 | CABALLO | 1 | **0** |
| 14 | CABALLO | 1 | **0** |

Es decir: los arquetipos `CABALLO` **fallarían** con el diseño anterior. La
prueba discrimina; no es una tautología.

## Canales de Ordenamiento

Cada persona recibe tres contactos colgados de su dirección **padre**:

| `contact_type` | Canal | Valor sembrado |
|---|---|---|
| `4` | TEL fijo | `601` + 7 dígitos → clasifica `VALIDA` |
| `9` | CEL | `310` + 7 dígitos → resuelve operador |
| `10` | EMA | `mock<id>@gmail.com` → dominio `PERSONAL` |

Como el Ordenamiento solo toma canales de personas con al menos una RPU no-hija
(`stg_persona_dir_ganadora`), estos contactos entran al scoring de TEL/CEL/EMA.

## GEO

Todas las ubicaciones se siembran con `latitud`/`longitud` en NULL, de modo que
son `Ubicacion_Candidata` para el Exportador_GEO. El arquetipo con coordenadas
(ARQ 56, que **no** debe generar candidato) se sembrará junto con R2.

Comportamiento esperado del ciclo GEO mock:

| Corrida | Candidatos | Lote |
|---|---|---|
| FULL | 20 000 ubicaciones | lote 1, queda `fallido` (UNLOAD sin rol IAM) |
| DELTA | **0** | no se crea lote: el 1 no está `cargado` (Req 1.5) |

El fallo del UNLOAD es **resultado esperado**, no defecto: no es bloqueante y el
flujo continúa con R1+R2 hacia Ordenamiento.

## Pendiente

- **ARQ 21..55 — Regla 2.** Los seis escenarios de R2 forman una **cascada con
  estado compartido**: esc3 a esc6 leen `stg_mock_regla2_e2 WHERE ind_unificacion = 'N'`
  —lo que los anteriores no consumieron— y cada uno marca `'S'` lo que toma. Los
  arquetipos no son independientes: cada uno debe diseñarse para ser inmune a
  todos los escenarios anteriores de la cadena.
- **ARQ 56 — GEO con coordenadas.**
