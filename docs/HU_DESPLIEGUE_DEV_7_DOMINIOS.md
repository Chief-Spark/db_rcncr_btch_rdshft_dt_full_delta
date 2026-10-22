# HU — Desplegar en DEV y correr la cadena real: las 7 tablas dominio

*Redactada para pegarse campo a campo en el formulario de Jira (Story (SLA)).
Fecha: 2026-10-22.*

---

## Campos del formulario

| Campo | Valor |
|---|---|
| **Project** | EITS SLA CO PR PROCESOS B… *(el que ya trae el formulario)* |
| **Issue Type** | Story (SLA) |
| **App ID** | ⚠️ **no lo sé** — el del aplicativo Reconocer / Batch Dinámico |
| **Summary** | `Reconocer Redshift: desplegar strct/pgm/dt y correr la cadena real en DEV para entregar las 7 tablas dominio` |
| **Tipo de Historia** | ⚠️ **no sé las opciones**. Es **técnica / desarrollo**, no de negocio |
| **Requiere Transicion** | `None` — no cambia la firma de ningún SP ni el contrato del Framework Batch |
| **Priority** | High |
| **Epic Link** | ⚠️ el épico de la migración Reconocer a Redshift |
| **Component/s** | Reconocer / Novedades / Redshift |
| **Labels** | `reconocer` `redshift` `novedades` `tablas-dominio` |
| **Linked Issues** | *relates to* SLCOPRBA-1353 y SLCOPRBA-1355 |
| **Fix Version/s** | la del próximo despliegue a DEV |

---

## Description (pegar tal cual)

**Como** equipo de migración de Reconocer a Amazon Redshift,
**quiero** desplegar los tres paquetes en DEV y ejecutar la cadena real completa
contra el datashare,
**para** que Reconocer entregue las **siete tablas dominio** pobladas con datos
reales y el Batch pueda explotarlas.

### Contexto

El AS-IS de Teradata carga siete tablas `MAT_*` en cada corrida
(`P0035_Extractor_Novedades_111.BTQ:817-836`). Hasta el 2026-10-20 teníamos
tres portadas; entre el 21 y el 22 entraron las cuatro que faltaban:

| # | Tabla | Columnas pobladas |
|---|---|---|
| d1 | `mat_info_ubicacion` | contrato completo |
| d2 | `mat_info_actividad_economica` | contrato completo |
| d3 | `mat_ubicacion_agregada` | contrato completo |
| d4 | `mat_info_basica` | 20 de 22 |
| d5 | `mat_info_contactabilidad` | 2 de 12 — la fuente de gestión no existe en EDF |
| d6 | `mat_info_movilidad` | **8 de 8** |
| d7 | `mat_info_punto_interes` | 8 de 10 |

**Las siete están certificadas sólo contra datos mock.** Lo que esta historia
abre es la otra mitad: que corran contra el datashare y devuelvan filas. El
runner que lo hace, `run_reconocer_e2e_real_full.sql`, **nunca se ha ejecutado
en el clúster**: antes del 2026-10-21 no existía un solo `run_*` que invocara
`sp_novedades_ciclo_edf`.

### Alcance

1. Desplegar los tres paquetes **en este orden**: `strct` → `pgm` → `dt`.
2. Correr la batería mock, que es el gate del pipeline.
3. Correr la cadena real con el lote dedicado **1356301**:
   `sp_unificacion_ciclo` → `sp_ordenamiento_ciclo` → `sp_novedades_ciclo_edf`,
   los tres en modo `FULL`.
4. Publicar el conteo de filas de las siete tablas, que es la medida contra la
   meta.

### Criterios de aceptación

1. **Los tres paquetes despliegan sin un `[REDSHIFT:112]`.**
2. **Los catálogos quedan con filas.** Tres entraron el 2026-10-22
   (`catalogo_indicador_movilidad`, `catalogo_hom_ind_mov`,
   `catalogo_hom_tipo_pto_int`). Un literal con comilla sin escapar deja la
   tabla **vacía** sin que nada lo detecte: hay que contarlas después de
   desplegar.
3. **La batería mock pasa las DOS veces** que el ciclo controlado de Jenkins la
   corre: Unificación `174` PASSED, Novedades `76`, Ordenamiento `217`, **cero
   FAILED**, y `CERTIFICACION OK` en las dos aserciones finales.
4. **La cadena real termina sin excepción** con el lote 1356301.
5. **Las siete tablas devuelven filas > 0**, salvo las ausencias ya
   documentadas y esperadas.
6. **Evidencia:** la salida del bloque de medición que cierra
   `run_reconocer_e2e_real_full.sql`, con una línea por tabla.

### Fuera de alcance

- **Que el `UNLOAD` escriba en S3 y el `COPY` lo lea.** Es un permiso: el rol
  IAM `rcncr-batch-redshift-geo` no está asociado al clúster DEV. GEO no es
  bloqueante y la corrida sigue sin él.
- **El Ordenamiento no entra al gate** todavía: `sp_cert_asercion_final` se
  llama sólo con `UNIFICACION` y `NOVEDADES`. Encenderlo es otra decisión.
- Los catálogos que siguen sin entregarse (ver riesgos).

### Riesgos y dependencias

| Riesgo | Efecto | Estado |
|---|---|---|
| **Primera corrida real de Novedades** | una tabla puede salir en cero por un mapeo del datashare que el mock no ejercita | es justo lo que esta historia mide |
| **Nueve catálogos sin entregar** | `TIPO`, `ZONA`, `TIPO_IDENTIFICACION`, `INDICATIVO` y `TIPO_CUENTA` salen NULL | petición abierta, no código |
| **`V_TIPO_PUNTO_INTERES` sin entregar** | la llave de `mat_info_punto_interes.tipo` es una **hipótesis** (código SIC de `col07`). Va por `LEFT JOIN`: si falla deja NULL, nunca un valor errado | D-NOV-19, abierta |
| **`[REDSHIFT:419]`** | el detector no encuentra el paquete y el job muere antes de desplegar | causa raíz **no establecida**, escalada a DevSecOps |
| **`id` no es único en `xpm_location_val_contactinformations`** | 568.657 filas para 142.067 ids (~4:1); la llave debería salir de `(id, index)` | riesgo heredado, afecta a lo ya desplegado |

### Definición de terminado

La cadena real corrió de principio a fin y existe una tabla publicada con el
conteo de filas de los siete dominios, con el lote 1356301.
