# Ordenamiento — cómo explicar las fases

Documento completo (fases 0→4 + ejemplos smoke):

- En este repo `_dt`: `docs/FASES_ORDENAMIENTO_EXPLICADAS.md`
- Mapa interactivo: `docs/MAPA_ORDENAMIENTO_EDF_VIEWS_NEGOCIO.html`
- Guía + ejemplos: `docs/GUIA_ORDENAMIENTO_EJEMPLOS_BASICOS.md`

## Pipeline en una línea

```
Unificación → preparar insumos → DIR → TEL → CEL → EMA → consolidar → drop
```

## Ejemplos rápidos

| Persona | Canal | Qué muestra |
|---------|-------|-------------|
| 20001 | DIR | Casa vs oficina → lugar 1/2 |
| 20002 | DIR | Una calle → lugar 1 |
| 20003 | DIR | Tres calles → 1/2/3 |
| 20004 | TEL | VALIDA vs NO VALIDA |
| 20006 | CEL | Prefijos 310 vs 320 |
| 20008 | EMA | gmail vs corporativo |

Rama: `feature/ordenamiento` · orden merge: `_strct` → `_pgm` → `_dt`
