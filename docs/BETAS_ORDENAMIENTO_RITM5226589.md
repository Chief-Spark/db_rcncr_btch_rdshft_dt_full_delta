# Betas ordenamiento — catálogo desde Teradata (RITM5226589)

**Fecha:** 2026-09-16  
**Fuente Teams:** John Bueno adjunta `LogRITM5226589.txt` (15/09/2026) · Manuel: *tomar coeficientes y crearlos en tablas auxiliares/catálogos*.

## Qué dijeron en sesión / mesa

| Punto | Acuerdo |
|-------|---------|
| ¿Qué son los betas? | **Coeficientes** que alimentan el scoring; **funcionan como catálogo** |
| ¿Cambian? | Sí (pueden recalcularse); por eso van en catálogo, no hardcode en SP |
| Origen Teradata | `REC_VISTA.V_Beta_Ordenamiento_{Tel,Cel,Email,Dir}` ← `REC_DATOS.ATRIBUTO` filtrado por `TIPO_ATRIBUTO` (`Beta_Ord_Tel` / `_Cel` / `_Mail` / `_Dir`) |
| Uso en fórmula | `(categoría / max_cat) × valor_beta` → sumar pesos → `ORDER BY score DESC` (lugar) |
| Secuencia proceso | Unificación primero; **no avanzar ordenamiento** sin unificación OK |

Copia del log en paquete: [`fuentes/LogRITM5226589.txt`](fuentes/LogRITM5226589.txt)

## Qué se aplicó en Redshift

| Artefacto | Rol |
|-----------|-----|
| `sql/dev_edf_ordenamiento/02_carga_betas_ritm5226589.sql` | **Carga oficial** → `bdm_datos.beta_ordenamiento` (47 filas) |
| `02_mock_betas.sql` | Mismo contenido (compat runners) |
| `deploy_bitbucket/.../02_carga_betas_ritm5226589.sql` | Deploy `_strct` (en `deploy.par` post-DDL) |

### Conteos

| Canal | Filas |
|-------|------:|
| DIR | 12 |
| TEL | 11 |
| CEL | 11 |
| EMA | 13 |
| **Total** | **47** |

### Nota de escala

Los valores reales son del orden **±30 a ±200** (ej. `CO01TEL001 = 114.09942950`), no ~0.10 del placeholder anterior.  
El ranking (`ROW_NUMBER` / lugar) sigue siendo por score descendente; **hay que re-correr scoring** tras esta carga — los scores absolutos DEV anteriores (≈0.2–0.8) ya no aplican como referencia de magnitud.

## Cómo cargar / validar

```sql
-- Tras DDL ordenamiento
-- Ejecutar 02_carga_betas_ritm5226589.sql

SELECT canal, COUNT(*) AS n, MIN(valor_beta) AS min_b, MAX(valor_beta) AS max_b
FROM bdm_datos.beta_ordenamiento
GROUP BY 1 ORDER BY 1;
```

Luego: `CALL bdm_datos.sp_ordenamiento_ejecucion_edf(TRUE);`

## Pendiente aún (externo)

- Publicar / datashare continuo `ifr_data.v_beta_ordenamiento_*` (si IFR lo materializa) — hoy el **snapshot RITM** cierra el gap de catálogo.
- Re-evidenciar DEV post-carga (nuevos min/max score).
