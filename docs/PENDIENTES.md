# Pendientes de Reconocer: tablero único

Actualizado: 2026-10-21. **Este archivo es la única lista de pendientes.** Se actualiza al cerrar cada tanda; lo que no está aquí no está pendiente. El detalle de cada punto vive en `BITACORA_DIFERENCIAS.md` (por su código D-…) y en `edf_views/RESULTADOS_CONSULTAS_EDF.md`.

## 1. Decisiones tuyas (bloquean trabajo)

| # | Decisión | Mi recomendación | Bloquea |
|---|---|---|---|
| T1 | DDL: columna `canal` en `rpu_orden_prioridad` | migración condicional (un SP que la añade una sola vez y vacía la tabla; la siguiente corrida es FULL). Probar con datos sintéticos del banco, sin tocar semillas del mock | ranking por canal (D-ORD-10) |
| T2 | Push de los tres repos a GitHub (strct 67, pgm 108 y dt 30 commits locales) | autorizarlo pronto: nada de lo hecho ha pasado por Redshift real, que es el gate. **Antes, decidir si `edf_views/catalogos_collibra_2026-10-21.csv` sube: el repo dt es público** | que Jenkins valide en DEV |
| T3 | OK al DDL de observabilidad (filas y tiempos reales, `version_betas`) | sí, después del ranking por canal | F3 del plan |
| T4 | Compuerta DIR053: el legado deja sin lugar las direcciones sin ciudad DANE (`Caracteristicas.txt` CR 1942). No está portada | portarla en una tanda propia, midiendo antes qué mueve | paridad del ranking DIR |

## 2. Consultas que corres tú en Redshift

Todas están al final de `edf_views/consultas_perfilado_edf_2026-10-20.sql`. Solo devuelven conteos, sin datos personales.

| # | Qué mide | Conexión | Qué decide |
|---|---|---|---|
| **C33 v2** | si la llave de cuenta del reporte casa con `xpm_bestaccounts` (reescrita para que corra rápido) | Reconocer | conectar la F2 real (`v_xpm_cuenta`) y saber si el bloqueo de cuenta ve todas las cuentas |
| **C35** | la lista de los 321 catálogos de Collibra (solo nombre y filas) | `dba_batch` | qué pedidos de la §3 se cierran solos, sin preguntar a Experian |

## 3. Preguntas a Experian (un solo mensaje)

Antes de enviarlo, correr la C35: los puntos 7 y 8 pueden estar ya en Collibra.

1. **Severidad 2 de cuenta.** `blockSeverity = 2` junta los indicadores 8 (reclamo sin solución, el legado no lo muestra) y 9 (cuenta sin validar ante la Registraduría, el legado sí lo muestra). `blockReason` no los distingue (C34: 25 cuentas en DEV, todas con razón 0). ¿En qué campo viene el indicador?
2. **`businessIdStatus` = `00` en NIT.** `01` es matrícula activa; `00` también es el valor por defecto cuando no viene (31 filas en DEV). ¿Qué significa?
3. **Score de estandarización de las direcciones de suscriptor** (`contactType` 1, 2 y 3). Alpha dice que se añadió en septiembre de 2026, pero no llega a DEV. ¿Cuándo llega?
4. **`contactType` 12** (RNT, dirección de notificación): ¿qué tipo es, RES, LAB, CRR, CCL o JUD? Baja prioridad: en DEV no hay filas.
5. **Contactabilidad y gestión** (`V_CONTACTABILIDAD`, `VstgUbiContactabilidad`): no están en `edf_views`. ¿Existen en EDF? Sin eso no se porta la prioridad 999999 de CEL (D-ORD-14) ni el dominio d5 de Novedades (D-NOV-08).
6. **Movilidad y puntos de interés:** el productor de indicadores de movilidad (P0029) y el catálogo de puntos de interés.
7. **Catálogos de homologación a Línea:** `V_Hom_Tip_Ident_Linea` (es el más urgente: deja vacío el dominio Ubicación Agregada), `V_Hom_TipoUbic_Dir_Linea`, `V_Hom_Zona_Linea` y `V_Hom_Fuente_Linea`.
8. **Otros catálogos:** `V_ACTIVIDAD_ECONO_CIIU`, `V_TELEFONO_FIJO`, `V_TIPO_CORREO`, `V_DIRECCION_ELECTRONICA`, `V_Tipo_Via`, y el reexport completo de `V_Geografia` y `V_Cod_Entrega_Dato` (llegaron cortados en 1.000 filas).

## 4. Otros equipos

| Con quién | Qué |
|---|---|
| DevSecOps | `[REDSHIFT:419]` del pipeline (ya escalado) |
| DBA / DevSecOps | asociar el rol IAM `rcncr-batch-redshift-geo` al clúster DEV, para que el `UNLOAD` y el `COPY` de GEO funcionen de verdad |
| Tú | `BATCH2_HOMOLOGACION`: decide el contrato de entrega al Batch |
| Equipo de Teradata | una muestra de la salida del Ordenamiento del mismo corte, para medir paridad (RF: G-05) |

## 5. Mi cola de trabajo, en orden

| # | Tanda | Estado | Necesita |
|---|---|---|---|
| 1 | Verificar el bloqueo de cuenta y el score en el banco (dos pasadas) | corriendo | — |
| 2 | Ranking por canal (D-ORD-10) | análisis listo; previsión: cero cambios de estado en el tablero | T1 |
| 3 | Novedades: fuente (D-NOV-03), ciudad y departamento en `''` (D-NOV-05), universo de Actividad Económica (D-NOV-06) | listo para empezar | — |
| 4 | F2 real: conectar `v_xpm_cuenta` a `xpm_bestaccounts` | espera | C33 v2 |
| 5 | Info Básica (d4): género, estado del documento, tipo de identificación | espera | C35 y la pregunta 2 |
| 6 | Observabilidad (F3 del plan) | espera | T3 |
| 7 | Renombrado de SP reales al patrón `sp_rcn_*` (F4 del plan) | al final | — |

## 6. Cerrado en esta ronda (no volver a abrir)

| Tema | Decisión | Dónde |
|---|---|---|
| Umbral del score | `>= 0.80` es VALIDA, menor es NO VALIDA y sin score cuenta como válida | D-EDF-12 |
| Bloqueo de suscriptor | estado 0 (bloqueado), 436 filas en DEV | D-EDF-01 |
| Bloqueo de cuenta | solo severidad 1; la 2 se muestra hasta que Experian responda | D-EDF-01, C34 |
| Sector `C` | Telecomunicaciones (catálogo 219) | D-ORD-15 |
| Género | 1 → M, 2 → F, 3 → O; el resto vacío | D-EDF-14 |
| Estado del documento (CC) | catálogo 124: `00` y `01` vigente; 12 y 14 → 00; 51 → 21; 52 → 26 | D-EDF-13 |
| `contactType` y fuente (`typeOfData`) | catálogos 320 y 170 | RESULTADOS §16 y §18 |
| GEO | no bloquea la Unificación; los lotes fallidos o vencidos se reenvían | D-GEO-07 |

## Cómo trabajamos

1. **Una tanda a la vez.** Cada una sigue el mismo orden: qué mueve, tu OK si hay DDL, código, banco, commit local y actualización de este archivo.
2. **Consultas en lotes numerados**, en un solo archivo. Cada una dice qué decisión destraba.
3. **Experian en un solo mensaje** (§3). Las respuestas se anotan aquí y en la bitácora.
4. **Cada respuesta mía termina igual:** hecho, en curso y qué necesito de ti.
