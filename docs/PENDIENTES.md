# Pendientes de Reconocer: tablero único

Actualizado: 2026-10-21. **Este archivo es la única lista de pendientes.** Se actualiza al cerrar cada tanda; lo que no está aquí no está pendiente. El detalle de cada punto vive en `BITACORA_DIFERENCIAS.md` (por su código D-…) y en `edf_views/RESULTADOS_CONSULTAS_EDF.md`.

## 1. Decisiones tuyas

**Pendiente ahora (bloquea trabajo):**

| # | Decisión | Mi recomendación | Bloquea |
|---|---|---|---|
| T5 | Columna `fuente` en `v_xpm_reporte_relacion_persona_ubica`, calculada del `typeOfData` (1, 2, 3 y 17 → SUS; el resto → CAM). La vista mock lleva `'CAM'` fijo | sí: la etapa 2 pasa al grano del legado (una fila por RPU y fuente, `Novedad.sql:8670`) y el tablero mock no se mueve | fuente de Novedades (D-NOV-03) |

**Aprobadas (2026-10-21):**

| # | Decisión | Qué se aprobó | Estado |
|---|---|---|---|
| T1 | DDL: columna `canal` en `rpu_orden_prioridad` | migración condicional (un SP que la añade una sola vez y vacía la tabla; la siguiente corrida es FULL), probada con datos sintéticos del banco y sin tocar semillas del mock | **en curso** (cola §5, punto 2) |
| T2 | Push de los tres repos a GitHub | push con el CSV de catálogos incluido | **hecho**: strct `04b4fb2`, pgm `6ecf93b` y dt `581d701` en `codex/ajustes-sp-reales-batch-en-linea`, verificados contra el remoto. Falta tu traslado a Bitbucket y el job de Jenkins |
| T3 | DDL de observabilidad (filas y tiempos reales, `version_betas`) | sí, después del ranking por canal | en cola (§5, punto 6) |
| T4 | Compuerta DIR053: el legado deja sin lugar las direcciones sin ciudad DANE (`Caracteristicas.txt` CR 1942) | portarla en una tanda propia, midiendo antes qué mueve | en cola (§5, punto 3b) |
| — | Homologación de la fuente de Novedades (D-NOV-03) | 1, 2, 3 y 17 → SUS; el resto → CAM | aprobada; falta T5 para implementarla |

## 2. Consultas que corres tú en Redshift

Todas están al final de `edf_views/consultas_perfilado_edf_2026-10-20.sql`. Solo devuelven conteos, sin datos personales.

| # | Qué mide | Conexión | Qué decide |
|---|---|---|---|
| ~~C33 v2~~ | **hecha:** la llave completa casa en el 4 % y el número de cuenta en el 81 %. Es formato | — | — |
| **C33b** | cuál de los cinco campos de la llave viene con otro formato | Reconocer | corregir la llave del bloqueo de cuenta y conectar la F2 real |
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
| 2 | Ranking por canal (D-ORD-10) | **en curso** (T1 aprobado); previsión: cero cambios de estado en el tablero | — |
| 3 | Novedades: ~~ciudad y departamento en `''` (D-NOV-05)~~ **hecho**; fuente (D-NOV-03) y universo de Actividad Económica (D-NOV-06) | en curso | la fuente espera T5 |
| 3b | Compuerta DIR053 | en cola (T4 aprobado) | medir antes qué mueve |
| 4 | Llave de cuenta: normalizar el campo que falle en el bloqueo de cuenta; luego conectar la F2 real (`v_xpm_cuenta`) | espera | C33b |
| 5 | Info Básica (d4): género, estado del documento, tipo de identificación | espera | C35 y la pregunta 2 |
| 6 | Observabilidad (F3 del plan) | en cola (T3 aprobado) | — |
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
| Ciudad y departamento en Novedades | centinela `''`, como el legado | D-NOV-05 |
| Severidad 2 de cuenta | `blockReason` no la separa (C34); se queda como está hasta que Experian responda | D-EDF-01 |

## Cómo trabajamos

1. **Una tanda a la vez.** Cada una sigue el mismo orden: qué mueve, tu OK si hay DDL, código, banco, commit local y actualización de este archivo.
2. **Consultas en lotes numerados**, en un solo archivo. Cada una dice qué decisión destraba.
3. **Experian en un solo mensaje** (§3). Las respuestas se anotan aquí y en la bitácora.
4. **Cada respuesta mía termina igual:** hecho, en curso y qué necesito de ti.
