# Índice del paquete

## Empezar aquí (proceso claro)

| Documento | Uso |
|-----------|-----|
| **`RECONOCER_TODO_EN_UNO.html`** | **Un solo HTML:** E2E + mapa Unificación + mapa Ordenamiento (pestañas) |
| `PROCESO_RECONOCER_END_TO_END.md` (+ `.html`) | Cadena punta a punta (también embebida en el TODO_EN_UNO) |
| **`COMO_SE_HA_HECHO_DATOS_REALES.md`** | Cómo se hizo + números DEV reales |
| **`PLAN_QA_DATOS_REALES_VS_MOCK.md`** | Sign-off real; mock anexo |
| **`contexto_reconocer/`** | Docs del paquete RECONOCER-Consolidado (00–06 + guía repos + PDFs índice) |
| Mapas HTML (también dentro del TODO_EN_UNO) | `MAPA_UNIFICACION_…` · `MAPA_ORDENAMIENTO_…` |

**Cierre y pendientes (2026-09-04):**  
→ **`Documentacion/PENDIENTES_Y_CIERRE_2026-09-04.md`**

**Documento único (hecho, pendiente, mapping, pipeline):**  
→ **`Documentacion/ESTADO_COMPLETO_UNIFICACION_BDM.md`**

**Informe de avance (2026-08-11):**  
→ **`Documentacion/INFORME_AVANCE_2026-08-11.md`**

---

## Scripts SQL

| Carpeta | Uso |
|---------|-----|
| `sql/` | Mock / develop (`bdm_stage`) |
| `sql/benchmark_20k/` | Cierre sintético 20K |
| `sql/qa_ifr_data/` | **QA datos reales XPM** (`ifr_data`, campos tokenizados) |
| `sql/qa_xpm/` | Alias histórico — usar `qa_ifr_data/` |
| `rev-sql/` | Rollbacks |

## Otros documentos de referencia

| Archivo | Contenido |
|---------|-----------|
| `Documentacion/GUIA_INSTALACION.md` | Instalación paquete base |
| `Documentacion/SPEC_IA_DATOS_SINTETICOS_20K.md` | SPEC datos sintéticos |
| `Documentacion/MAPEO_QA_IFR_TABLAS_COLUMNAS.md` | **Tablas/columnas IFR QA** (mapping validado) |
| `Documentacion/configuracion_ifr_data_qa.md` | Config campos tokenizados IFR |
| `Documentacion/PLAN_ADAPTACION_DIVIDER_BDM_STAGE.md` | Plan adaptación inicial |
| `deploy_order.par` | Orden deploy/rollback mock |
