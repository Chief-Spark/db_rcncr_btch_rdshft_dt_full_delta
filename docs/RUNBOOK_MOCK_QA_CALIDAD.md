# Runbook QA mock — pasar calidad (TC-R2-14 + R3)

**Para:** arreglar lo que Julian vio en QA con suite mock.  
**Carpeta:** `sql/qa_redshift/`

---

## Qué vas a lograr

| Caso | Antes | Después |
|------|-------|---------|
| TC-R2-14 (`R2_EMPATE`) | 1.200 violaciones | **0** |
| R3 sin geo | Fallaba / vacío | Mocks **930001 / 930008 / 930010** con lat/long |

---

## Orden en DBeaver (conexión QA → `dba_batch`)

1. **`mock_tc_r3_01_08_10.sql`** — carga R3 con coordenadas  
   (el `01_cargar_mock_r3_geo.sql` solo documenta; en DBeaver ejecuta directo el mock)

2. **`02_patch_r2_empate_limpiar_absorciones.sql`** — limpia absorciones del empate

3. **Correr Regla 3** (SP que usen en QA), por ejemplo:
   ```sql
   CALL bdm_stage.sp_unificacion_regla3();
   ```
   o el nombre equivalente del deploy QA.

4. **`03_validar_gates_mock_qa.sql`** — debe salir PASSED

---

## Si vuelven a correr R2 y TC-R2-14 falla otra vez

El SP viejo **rompe empates por fecha** aunque la frecuencia sea igual.  
Hay que desplegar en QA el SP con:

```text
stg_regla2_e04_ganador ... HAVING COUNT(*) = 1
```

Archivo: `sql/qa_ifr_data/06_sp_regla2.sql`  
Luego: re-ejecutar R2 + `04_revalidar_r2_empate_tras_sp.sql`

---

## Mensaje para Julian

> Ya dejamos scripts mock en el paquete para QA:
> 1) Cargar R3 con geo (`mock_tc_r3_01_08_10.sql`)
> 2) Patch TC-R2-14 (limpiar absorciones `R2_EMPATE`)
> 3) Correr R3 + validar gates (`03_validar_gates_mock_qa.sql`)
> Pedimos permiso sandbox en QA para ejecutarlos. Si re-corren R2, deben tener el SP con `e04_ganador` o el empate vuelve a absorberse.
