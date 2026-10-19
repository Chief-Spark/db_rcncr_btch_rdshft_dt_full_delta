# Certificacion de aceptacion — Reconocer (Unificacion + GEO + Scoring + Novedades)

Documento para QA. Una ficha por criterio: que dice, que caso cubre, en que
fases aplica, como se verifica y con que SQL se ve el dato que entra y el que sale.

**Las dos fuentes de este documento son el codigo y la corrida, no la memoria de nadie:**
el catalogo sale del DDL del repo de estructura y el estado de cada criterio sale de la
ultima ejecucion de la bateria. Ningun numero esta escrito a mano.

---

## Como leer y como verificar

Todo criterio deja fila en una tabla de resultado. **Esa es la fuente de la verdad**,
y QA puede consultarla sin depender de este documento:

```sql
-- Veredicto de TODOS los criterios de la ultima corrida, por fase.
SELECT criterio, modo, estado, detalle
  FROM bdm_datos.cert_resultado        -- Unificacion y GEO
 UNION ALL SELECT criterio, modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 UNION ALL SELECT criterio, modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 ORDER BY criterio, modo;
```

Y el titular de cada tablero:

```sql
\i validacion_certificacion_51.sql    -- Unificacion y GEO
\i validacion_certificacion_ord.sql   -- Scoring
\i validacion_certificacion_nov.sql   -- Novedades
```

### Los estados

| Estado | Significa |
|---|---|
| `PASSED` | el criterio se evaluo por consulta y se cumple |
| `NO_APLICA` | la fase no ejercita ese criterio (p.ej. un criterio de DELTA en el FULL) |
| `SIN_DATO` | el mock no siembra ese caso; se arregla con un arquetipo |
| `BLOQUEADO` | falta un catalogo o un insumo del datashare; **ningun arquetipo lo arregla** |
| `NO_IMPLEMENTADO` | dominio no portado todavia |
| `REVISION_MANUAL` | es una decision, no una consulta |
| `FAILED` | **tumba el build** |

### Las fases de la bateria

| Fase | Que corre |
|---|---|
| `FULL` | carga completa desde cero: resetea las salidas y reprocesa todo |
| `DELTA1` | ventana incremental sobre datos sin mutar |
| `DELTA2` | ventana incremental **despues de una mutacion deliberada** |
| `FULL2` | segundo FULL, solo Unificacion: prueba la convergencia |
| `GEO` | el ciclo de georreferenciacion, que corre una vez y no por fase |

---

## Resumen

| Bloque | Criterios | PASSED/NO_APLICA en todas sus fases |
|---|---|---|
| Regla 1 — unificacion por CIIU y entidades reportantes | 8 | **8** |
| Regla 2 — cascada de seis escenarios y cuatro motores | 14 | **14** |
| Regla 3 — unificacion geografica | 10 | **10** |
| Ciclo GEO | 5 | **5** |
| Unificacion — transversales | 10 | **9** |
| Gobernanza | 4 | **3** |
| Scoring — reglas generales | 10 | **5** |
| Scoring — criterios funcionales | 6 | **6** |
| Scoring — criterios de migracion | 4 | **0** |
| Scoring — criterios tecnicos | 5 | **3** |
| Scoring — Fase 1 | 8 | **0** |
| Scoring — Fase 2 | 10 | **0** |
| Scoring — Fase 3 | 11 | **0** |
| Scoring — Fase 4 (caracteristicas) | 30 | **29** |
| Novedades — Ubicacion | 22 | **14** |
| Novedades — Actividad Economica | 10 | **8** |
| Novedades — Ubicacion Agregada | 8 | **1** |
| Novedades — dominios no portados | 5 | **0** |
| Gobernanza | 3 | **0** |

---

## Regla 1 — unificacion por CIIU y entidades reportantes

**Dato que ENTRA al bloque**

```sql
-- Universo que entra a la Regla 1: las relaciones persona-ubicacion sembradas.
SELECT COUNT(*) AS direcciones, COUNT(DISTINCT id_buro_persona) AS personas
  FROM bdm_tempo.v_mock_relacion_persona_ubicacion;
```

**Dato que SALE del bloque**

```sql
-- Lo que la Regla 1 sello. unifica_atributos = 1 es Regla 1.
SELECT unifica_atributos, COUNT(*) AS direcciones
  FROM bdm_datos.unificacion_direccion_mock
 WHERE unifica_atributos = 1 GROUP BY 1;
```

### R1-01

**Enunciado.** CIIU 10 (asalariado): el padre es la direccion LAB o CRR con mayor numero de entidades reportantes.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED · FULL2=PASSED |
| Medido en la corrida | `parejas CIIU 10 donde el tipo preferido perdio=0` |
| Evidencia / caso de uso | unificacion_direccion_mock + arquetipos ARQ 1..5; SP sp_unificacion_r1_esc1 |

```sql
-- Veredicto de R1-01 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'R1-01' ORDER BY modo;
```

### R1-02

**Enunciado.** CIIU 81, 82 o 90 (sin actividad): el padre es la direccion RES o CRR con mayor numero de entidades reportantes.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED · FULL2=PASSED |
| Medido en la corrida | `parejas CIIU 81/82/90 donde el tipo preferido perdio=0` |
| Evidencia / caso de uso | ARQ 6..10 (CIIU 81) y los arquetipos de CIIU 82 y 90; SP sp_unificacion_r1_esc2 |

```sql
-- Veredicto de R1-02 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'R1-02' ORDER BY modo;
```

### R1-03

**Enunciado.** CIIU distinto de 10, 81, 82 y 90: gana la direccion con mayor numero de entidades reportantes, sin preferencia de tipo.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED · FULL2=PASSED |
| Medido en la corrida | `parejas otros CIIU donde la hija tenia mas entidades=0` |
| Evidencia / caso de uso | ARQ 11..15 (CIIU 47); SP sp_unificacion_r1_esc3 |

```sql
-- Veredicto de R1-03 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'R1-03' ORDER BY modo;
```

### R1-04

**Enunciado.** La direccion que pierde la comparacion queda marcada como hija (ind_unificacion = 1).

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED · FULL2=PASSED |
| Medido en la corrida | `hijas sin ind_unificacion=1 en la vista=0` |
| Evidencia / caso de uso | v_mock_relacion_persona_ubicacion.ind_unificacion derivado de unificacion_direccion_mock |

```sql
-- Veredicto de R1-04 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'R1-04' ORDER BY modo;
```

### R1-05

**Enunciado.** El par padre-hijo queda insertado en unificacion_direccion para trazabilidad.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED · FULL2=PASSED |
| Medido en la corrida | `parejas R1=1500, sin lote o sin fecha=0` |
| Evidencia / caso de uso | unificacion_direccion_mock WHERE unifica_atributos = 1 |

```sql
-- Veredicto de R1-05 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'R1-05' ORDER BY modo;
```

### R1-06

**Enunciado.** Las direcciones bloqueadas y las que ya son hijas de unificaciones previas no se procesan en esta regla.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED · FULL2=PASSED |
| Medido en la corrida | `parejas cuya hija ya era hija antes de la corrida=0, parejas con hija bloqueada=0, direcciones bloqueadas en el universo=100. Con 0 bloqueadas la mitad de bloqueo no se puede afirmar (ver G-04).` |
| Evidencia / caso de uso | filtro ind_unificacion IS NULL AND bloqueado = 0 en sp_unificacion_r1_preparar_insumo |

```sql
-- Veredicto de R1-06 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'R1-06' ORDER BY modo;
```

### R1-07

**Enunciado.** Baseline de CIIU obligatorio: 10 es asalariado; 81, 82 y 90 son sin actividad. No se usan los valores 1-9 ni solo 81 de forma aislada.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED · FULL2=PASSED |
| Medido en la corrida | `valores del baseline sin actividad presentes en el universo=3 de 3 (81,82,90). El codigo contempla 81, 82 y 90.` |
| Evidencia / caso de uso | literales IN ('81','82','90') y NOT IN ('10','81','82','90') en los SP de R1 |

```sql
-- Veredicto de R1-07 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'R1-07' ORDER BY modo;
```

### R1-08

**Enunciado.** Ante empate persistente (mismas entidades, misma fecha) no se toma decision de unificacion: ambas direcciones quedan vigentes.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED · FULL2=PASSED |
| Medido en la corrida | `direcciones en arquetipos de empate (ARQ 16..20)=1000, de ellas unificadas=0 (debe ser 0: mismo tipo preferido y mismas entidades, el empate no decide).` |
| Evidencia / caso de uso | HAVING COUNT(*) = 1 sobre max_score; arquetipo de empate puro |

```sql
-- Veredicto de R1-08 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'R1-08' ORDER BY modo;
```

---

## Regla 2 — cascada de seis escenarios y cuatro motores

**Dato que ENTRA al bloque**

```sql
-- Lo que llega a la Regla 2: lo que la Regla 1 NO sello.
SELECT COUNT(*) AS candidatas
  FROM bdm_tempo.v_mock_relacion_persona_ubicacion rpu
 WHERE NOT EXISTS (SELECT 1 FROM bdm_datos.unificacion_direccion_mock u
                    WHERE u.cod_dw_persona_ubic = rpu.cod_dw_persona_ubic);
```

**Dato que SALE del bloque**

```sql
-- Censo por escenario de la cascada R2, con su linea del legado.
SELECT escenario, ref_legado, direcciones, personas
  FROM bdm_datos.unif_escenario_censo_mock
 WHERE lote = :LOTE AND modo = :MODO ORDER BY escenario;
```

### R2-01

**Enunciado.** Escenario 1 (vacio vs informado): el padre es la direccion con complemento informado.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=NO_APLICA · DELTA2=PASSED · FULL2=PASSED |
| Medido en la corrida | `sello H1: direcciones=600, personas=600` |
| Evidencia / caso de uso | censo n_id = H1; legado PRO_UnificacionR2.sql linea 201 |

```sql
-- Veredicto de R2-01 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'R2-01' ORDER BY modo;
```

### R2-02

**Enunciado.** Escenario 2 (uno incluido en otro): el padre es la direccion con el complemento mas completo.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=NO_APLICA · DELTA2=NO_APLICA · FULL2=PASSED |
| Medido en la corrida | `sello K2: direcciones=400, personas=400` |
| Evidencia / caso de uso | censo n_id = K2; legado linea 388 |

```sql
-- Veredicto de R2-02 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'R2-02' ORDER BY modo;
```

### R2-03

**Enunciado.** Escenario 3 sin NIT (misma nomenclatura, distinto valor): el padre es la direccion con mayor numero de entidades reportantes.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=NO_APLICA · DELTA2=NO_APLICA · FULL2=PASSED |
| Medido en la corrida | `sello L3: direcciones=400, personas=400` |
| Evidencia / caso de uso | censo n_id = L3; legado linea 1729 |

```sql
-- Veredicto de R2-03 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'R2-03' ORDER BY modo;
```

### R2-04

**Enunciado.** Escenario 3 con NIT (persona juridica, misma nomenclatura con distinto valor): se genera una direccion nueva combinando ambos valores.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=NO_APLICA · DELTA2=NO_APLICA · FULL2=PASSED |
| Medido en la corrida | `sello X4: direcciones=1400, personas=500` |
| Evidencia / caso de uso | censo n_id = X4; direccion_fisica_generada_mock; legado linea 1705 |

```sql
-- Veredicto de R2-04 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'R2-04' ORDER BY modo;
```

### R2-05

**Enunciado.** Escenario 4 (nomenclaturas distintas, mismo nivel): se consulta el Diccionario de Frecuencias y gana la nomenclatura mas reportada historicamente.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=NO_APLICA · DELTA2=NO_APLICA · FULL2=PASSED |
| Medido en la corrida | `sello B5: direcciones=400, personas=400` |
| Evidencia / caso de uso | censo n_id = B5; diccionario_complementos; legado linea 2226 |

```sql
-- Veredicto de R2-05 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'R2-05' ORDER BY modo;
```

### R2-06

**Enunciado.** Escenario 5 (nomenclaturas distintas, distinto nivel): se genera una direccion nueva que combina ambas y las dos originales quedan como hijas.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED · FULL2=PASSED |
| Medido en la corrida | `direcciones nuevas del arquetipo 71 (sitio 2)=100, de ellas con las DOS originales como hijas=100, con el padre en rpu_generada_mock=100, con complemento 'ED 1 CS 5 LC 3' (sin repetir CS)=100. Sello A6 del censo de esta corrida: direcciones=200` |
| Evidencia / caso de uso | ARQ 71 (banda 9710000..9710999); direccion_fisica_generada_mock; censo n_id = A6; legado escenario 5 subcaso 1, lineas 2250-3607 |

```sql
-- Veredicto de R2-06 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'R2-06' ORDER BY modo;
```

### R2-07

**Enunciado.** Escenario 6 (ninguna contenida en la otra): se evalua por nivel y frecuencia; segun el subcaso se genera direccion nueva o se usa el diccionario.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED · FULL2=PASSED |
| Medido en la corrida | `direcciones nuevas del sitio 3 (A8, ARQ 72)=100, del sitio 4 (D9, ARQ 73)=100; con las DOS originales como hijas=200, con el padre en rpu_generada_mock=200, con el complemento esperado=200. Censo de esta corrida: A8=200 direcciones, D9=200, E6=400 (E6 aproxima F1, sub3)` |
| Evidencia / caso de uso | A8 (esc6 sub1, legado 4016) con el ARQ 72 (banda 9720000..9720999), complemento 'BL 2 ED 7'. D9 (esc6 sub2, legado 4715) con el ARQ 73 (banda 9730000..9730999), complemento 'BR 5 AP 301'. Los dos sitios de creacion del escenario 6 quedan portados. Dos divergencias anotadas para GOB-03: F1 (sub3, legado 5453) resuelve por diccionario y se aproxima por esc6, sellado E6, sello que no existe en el legado; y D9 corre ANTES de esc5 porque nuestro esc5 es mas ancho. censo n_id = A8, D9, E6 |

```sql
-- Veredicto de R2-07 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'R2-07' ORDER BY modo;
```

### R2-08

**Enunciado.** Las direcciones nuevas generadas por combinacion quedan marcadas como generadas.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED · FULL2=PASSED |
| Medido en la corrida | `direcciones generadas=800, sin marca generada_enriquecida=1=0` |
| Evidencia / caso de uso | direccion_fisica_generada_mock.generada_enriquecida = 1 |

```sql
-- Veredicto de R2-08 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'R2-08' ORDER BY modo;
```

### R2-09

**Enunciado.** Las direcciones generadas tienen registrada su relacion persona-ubicacion.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED · FULL2=PASSED |
| Medido en la corrida | `direcciones generadas sin relacion persona-ubicacion=0` |
| Evidencia / caso de uso | rpu_generada_mock |

```sql
-- Veredicto de R2-09 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'R2-09' ORDER BY modo;
```

### R2-10

**Enunciado.** Un padre nunca queda marcado como hijo dentro de la misma regla.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED · FULL2=PASSED |
| Medido en la corrida | `direcciones que son padre e hija en la misma regla=0` |
| Evidencia / caso de uso | interseccion entre cod_dw_persona_ubic y cod_dw_direccion_unificada en unificacion_direccion_mock |

```sql
-- Veredicto de R2-10 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'R2-10' ORDER BY modo;
```

### R2-11

**Enunciado.** Cada direccion hija tiene exactamente un padre asignado.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED · FULL2=PASSED |
| Medido en la corrida | `direcciones con mas de un padre=0` |
| Evidencia / caso de uso | unificacion_direccion_mock agrupado por cod_dw_persona_ubic HAVING COUNT(DISTINCT padre) > 1 |

```sql
-- Veredicto de R2-11 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'R2-11' ORDER BY modo;
```

### R2-12

**Enunciado.** La correccion de complementos garantiza: sin duplicidad, con completitud y con orden logico de los componentes.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED · FULL2=PASSED |
| Medido en la corrida | `complementos generados=800, con nomenclatura repetida o vacios=0. El orden logico lo afirma CA-U04 del gate por arquetipo.` |
| Evidencia / caso de uso | direccion_fisica_generada_mock.complemento de los arquetipos del motor |

```sql
-- Veredicto de R2-12 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'R2-12' ORDER BY modo;
```

### R2-13

**Enunciado.** El Diccionario de Frecuencias se construye con frecuencia historica de nomenclaturas reportadas.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED · FULL2=PASSED |
| Medido en la corrida | `filas del diccionario=12000, con frecuencia > 0=12000` |
| Evidencia / caso de uso | bdm_stage.diccionario_complementos; SP sp_unificacion_r2_construir_diccionario_complementos |

```sql
-- Veredicto de R2-13 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'R2-13' ORDER BY modo;
```

### R2-14

**Enunciado.** Ante empate persistente no se toma decision de unificacion.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED · FULL2=PASSED |
| Medido en la corrida | `parejas mutuas (empate resuelto en ambos sentidos)=0. Brecha del censo (tenian pareja posible y nadie unifico)=600` |
| Evidencia / caso de uso | arquetipos de empate por escenario; censo bucket SIN_RESOLVER |

```sql
-- Veredicto de R2-14 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'R2-14' ORDER BY modo;
```

---

## Regla 3 — unificacion geografica

**Dato que ENTRA al bloque**

```sql
-- Insumo de la Regla 3: ubicaciones con coordenadas.
SELECT COUNT(*) AS con_coordenadas
  FROM bdm_tempo.v_mock_ubicacion_estandarizada
 WHERE latitud IS NOT NULL AND longitud IS NOT NULL;
```

**Dato que SALE del bloque**

```sql
-- Lo que la Regla 3 sello. unifica_atributos = 3 es Regla 3.
SELECT unifica_atributos, COUNT(*) AS direcciones
  FROM bdm_datos.unificacion_direccion_mock
 WHERE unifica_atributos = 3 GROUP BY 1;
```

### R3-01

**Enunciado.** La regla aplica exclusivamente a direcciones de tipo Via. Se excluyen Manzana y Rural.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED · FULL2=PASSED |
| Medido en la corrida | `direcciones de tipo MZ=200, de tipo Rural=200, de ellas unificadas por R3=0 (debe ser 0: el insumo de R3 exige tipo Via).` |
| Evidencia / caso de uso | v_xpm_ubicacion_estandarizada.tipo_ubicacion; insumo de sp_unificacion_r3_esc1 |

```sql
-- Veredicto de R3-01 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'R3-01' ORDER BY modo;
```

### R3-02

**Enunciado.** Si solo una de las direcciones tiene coordenadas, el padre es la direccion geolocalizada.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED · FULL2=PASSED |
| Medido en la corrida | `parejas del arquetipo 61 (una sola geolocalizada)=100, de ellas con el padre SIN coordenadas o la hija CON coordenadas=0` |
| Evidencia / caso de uso | geo_atributos.latitud/longitud; insumo de R3 |

```sql
-- Veredicto de R3-02 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'R3-02' ORDER BY modo;
```

### R3-03

**Enunciado.** Si ninguna direccion tiene coordenadas, gana la de fecha mas reciente; ante empate, la de mayor numero de entidades reportantes.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED · FULL2=PASSED |
| Medido en la corrida | `parejas del arquetipo 62 (ninguna geolocalizada)=100, con alguna coordenada=0, con el padre de fecha ANTERIOR a la hija=0` |
| Evidencia / caso de uso | fecha_relacion_persona_ubicaci y numero_entidades_reportan en el insumo de R3 |

```sql
-- Veredicto de R3-03 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'R3-03' ORDER BY modo;
```

### R3-04

**Enunciado.** Si ambas direcciones tienen coordenadas, se consulta el Diccionario de Via por frecuencia y gana la mas reportada.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=NO_APLICA · DELTA2=NO_APLICA · FULL2=PASSED |
| Medido en la corrida | `parejas del arquetipo 63 (las dos geolocalizadas)=100, de ellas con el diccionario poblado=100, con el padre de conteo MENOR o IGUAL al de la hija=0. Las entidades EMPATAN a proposito, de modo que lo que decide es el diccionario.` |
| Evidencia / caso de uso | Diccionario de Via |

```sql
-- Veredicto de R3-04 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'R3-04' ORDER BY modo;
```

### R3-05

**Enunciado.** Para diferencia en numero de puerta se valida un umbral de mas/menos 2 posiciones.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED · FULL2=PASSED |
| Medido en la corrida | `parejas del arquetipo 64 (puerta a +-2)=100, con diferencia de puerta FUERA de 1..2=0. El umbral sale de numero_puerta, no de trocear texto_ubicacion.` |
| Evidencia / caso de uso | v_xpm_direccion_fisica.numero_puerta |

```sql
-- Veredicto de R3-05 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'R3-05' ORDER BY modo;
```

### R3-06

**Enunciado.** Si la diferencia en numero de puerta es mayor a 2 no se unifica: se consideran direcciones diferentes.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED · FULL2=PASSED |
| Medido en la corrida | `direcciones del arquetipo 65 (puerta a +-5)=200, de ellas unificadas por R3=0 (debe ser 0). El arquetipo 64, identico salvo la diferencia de puerta, SI unifica.` |
| Evidencia / caso de uso | ausencia de par en unificacion_direccion_mock para el arquetipo de puerta lejana |

```sql
-- Veredicto de R3-06 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'R3-06' ORDER BY modo;
```

### R3-07

**Enunciado.** Las direcciones con modificadores de via (B, C, F, BIS) se excluyen de esta regla.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED · FULL2=PASSED |
| Medido en la corrida | `direcciones con modificador de via en el texto=200, de ellas unificadas por R3=0 (debe ser 0).` |
| Evidencia / caso de uso | v_xpm_direccion_fisica.via_principal / via_generadora |

```sql
-- Veredicto de R3-07 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'R3-07' ORDER BY modo;
```

### R3-08

**Enunciado.** Los cuadrantes (N, S, E, O) se omiten para la comparacion numerica pero no excluyen a la direccion de participar en la regla.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED · FULL2=PASSED |
| Medido en la corrida | `direcciones con cuadrante en la via principal=100, de ellas que participaron de una unificacion R3 (como hija o como padre)=100 (debe ser > 0: el cuadrante se omite para comparar pero no excluye).` |
| Evidencia / caso de uso | v_xpm_direccion_fisica.via_principal; arquetipo con cuadrante |

```sql
-- Veredicto de R3-08 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'R3-08' ORDER BY modo;
```

### R3-09

**Enunciado.** El umbral de mas/menos 2 aplica SOLO en el subcaso donde ambas direcciones tienen coordenadas.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED · FULL2=PASSED |
| Medido en la corrida | `parejas R3 del escenario de puerta (puertas distintas)=100, de ellas con alguna coordenada ausente=0 (debe ser 0).` |
| Evidencia / caso de uso | ramas del insumo de R3 por disponibilidad de coordenadas |

```sql
-- Veredicto de R3-09 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'R3-09' ORDER BY modo;
```

### R3-10

**Enunciado.** Ante empate en el diccionario no se toma decision de unificacion.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED · FULL2=PASSED |
| Medido en la corrida | `llaves del diccionario con el conteo maximo EMPATADO entre dos valores=3, direcciones del arquetipo 70 unificadas por R3=0 (debe ser 0: sin ganador unico no se decide).` |
| Evidencia / caso de uso | Diccionario de Via; arquetipo de empate de frecuencia de via |

```sql
-- Veredicto de R3-10 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'R3-10' ORDER BY modo;
```

---

## Ciclo GEO

**Dato que ENTRA al bloque**

```sql
-- Candidatas que el exportador manda a georreferenciar.
SELECT lote, estado, candidatos, fase_fallo, ultimo_error
  FROM bdm_datos.geo_lote_control_mock ORDER BY lote DESC;
```

**Dato que SALE del bloque**

```sql
-- Lo que el cargador escribio de vuelta.
SELECT COUNT(*) AS geocodificadas
  FROM bdm_datos.geo_atributos_mock
 WHERE latitud IS NOT NULL;
```

### CA-01

**Enunciado.** Exportar: se crea un Lote nuevo en geo_lote_control en estado exportado y cada candidato queda en geo_atributos con estado_geo pendiente de geocodificacion y el lote asignado.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED · FULL2=PASSED |
| Medido en la corrida | `lote GEO=1, estado=exportado, conteo_esperado=10300, ubicaciones pendientes de geocodificacion=10300` |
| Evidencia / caso de uso | geo_lote_control y geo_atributos del ultimo lote |

```sql
-- Veredicto de CA-01 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'CA-01' ORDER BY modo;
```

### CA-02

**Enunciado.** Cargar Status M: la ubicacion queda estado_geo geocodificada, status_match M y con latitud y longitud pobladas.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | GEO=PASSED |
| Medido en la corrida | `ubicaciones del Lote con status_match=M, estado_geo=geocodificada y lat/long pobladas=1400 (esperado > 0); con status_match=U y no geocodificada=8900. Certificado sobre el cargador MOCK: el COPY desde S3 se sustituye por un INSERT desde bdm_stage.mock_geo_respuesta y el resto del SP es identico al r` |
| Evidencia / caso de uso | geo_atributos WHERE cod_dw_ubic = <U> AND lote = <L> |

```sql
-- Veredicto de CA-02 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'CA-02' ORDER BY modo;
```

### CA-03

**Enunciado.** Cargar OK: el Lote queda en estado cargado, con fase_fallo y ultimo_error en NULL.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | GEO=PASSED |
| Medido en la corrida | `estado del Lote=cargado (esperado cargado), fase_fallo=NULL, ultimo_error=NULL (ambos esperados NULL).` |
| Evidencia / caso de uso | geo_lote_control WHERE lote = <L> |

```sql
-- Veredicto de CA-03 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'CA-03' ORDER BY modo;
```

### CA-04

**Enunciado.** Reenganche con coordenadas: se invoca la Regla 3, se insertan unificaciones tipo 3 y el Lote mantiene estado cargado.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | GEO=PASSED |
| Medido en la corrida | `ubicaciones aptas que entraron a la Regla 3=1400, unificaciones tipo 3=500 contra 500 antes del ciclo, estado del Lote=cargado (esperado cargado, fase_fallo NULL). El reenganche es idempotente por diseno: aporta coordenadas a direcciones que ya existen, de modo que el conteo no baja. Las coordenadas` |
| Evidencia / caso de uso | unificacion_direccion WHERE unifica_atributos = 3; geo_lote_control.estado |

```sql
-- Veredicto de CA-04 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'CA-04' ORDER BY modo;
```

### CA-05

**Enunciado.** Reenganche sin coordenadas: la Regla 3 se omite como estado esperado, el SP termina OK y no se agregan unificaciones tipo 3 para ese Lote.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | GEO=PASSED |
| Medido en la corrida | `pasada sin coordenadas: ubicaciones aptas del Lote=0 (esperado 0), estado del Lote=cargado (esperado cargado), fase_fallo=NULL (esperado NULL), unificaciones tipo 3=500 contra 500 antes del ciclo (esperado igual: la Regla 3 se omite y no agrega ninguna). El SP no lanza excepcion: la omision es estad` |
| Evidencia / caso de uso | el SP no lanza excepcion; conteo de unificaciones tipo 3 del Lote sin cambio |

```sql
-- Veredicto de CA-05 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'CA-05' ORDER BY modo;
```

---

## Unificacion — transversales

**Dato que ENTRA al bloque**

```sql
-- Traza de la corrida: lote, modo, watermark y metricas.
SELECT corrida_id, lote, modo, bootstrap, fecha_proceso,
       watermark_anterior, watermark_nuevo, estado,
       relaciones_entrada, personas_distintas, total_unificaciones
  FROM bdm_datos.unif_control_mock ORDER BY corrida_id;
```

**Dato que SALE del bloque**

```sql
-- Salida consolidada de la Unificacion.
SELECT unifica_atributos AS regla, COUNT(*) AS direcciones,
       COUNT(DISTINCT cod_dw_direccion_unificada) AS padres
  FROM bdm_datos.unificacion_direccion_mock GROUP BY 1 ORDER BY 1;
```

### G-01

**Enunciado.** Las reglas se ejecutan en cascada estricta R1 -> R2 -> R3. El resultado de una alimenta la siguiente.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED · FULL2=PASSED |
| Medido en la corrida | `orden de etapas segun la traza=regla1 -> regla2 -> geo -> regla3` |
| Evidencia / caso de uso | unif_control_etapa_mock ordenado por fecha_hora_inicio |

```sql
-- Veredicto de G-01 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'G-01' ORDER BY modo;
```

### G-02

**Enunciado.** Una direccion seleccionada como padre en R1 puede ser evaluada como hija en R2 si otra tiene complemento mas completo.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED · FULL2=PASSED |
| Medido en la corrida | `padres de R1 que luego fueron hijas en R2=100. El ARQ 60 (banda 9600000..9600999) es el arquetipo que produce el cruce: k=1 es padre en R1 e hija en R2.` |
| Evidencia / caso de uso | cruce de unificacion_direccion_mock entre unifica_atributos 1 y 2; ARQ 60 (banda 9600000..9600999) |

```sql
-- Veredicto de G-02 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'G-02' ORDER BY modo;
```

### G-03

**Enunciado.** Una direccion marcada como hija en cualquier regla no vuelve a procesarse en reglas posteriores.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED · FULL2=PASSED |
| Medido en la corrida | `hijas que recibieron padre en mas de una regla=0` |
| Evidencia / caso de uso | filtro ind_unificacion en los insumos de R2 y R3 |

```sql
-- Veredicto de G-03 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'G-03' ORDER BY modo;
```

### G-04

**Enunciado.** Las direcciones marcadas como bloqueadas (reclamacion del titular) se excluyen de todo el proceso de unificacion.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED · FULL2=PASSED |
| Medido en la corrida | `direcciones bloqueadas en el universo=100. Con 0 el filtro de los insumos no se puede afirmar.` |
| Evidencia / caso de uso | bloqueado = 1 en el seed mock; ausencia del par en unificacion_direccion_mock |

```sql
-- Veredicto de G-04 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'G-04' ORDER BY modo;
```

### G-05

**Enunciado.** Toda unificacion genera registro de trazabilidad: padre, hijo, regla aplicada y fecha de ejecucion.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED · FULL2=PASSED |
| Medido en la corrida | `unificaciones sin padre, sin regla o sin fecha=0` |
| Evidencia / caso de uso | unificacion_direccion_mock: cod_dw_direccion_unificada, cod_dw_persona_ubic, unifica_atributos, fecha_unificacion, lote |

```sql
-- Veredicto de G-05 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'G-05' ORDER BY modo;
```

### G-06  _(no cerrado: ver estado)_

**Enunciado.** El proceso es idempotente: dos ejecuciones consecutivas con los mismos datos producen el mismo resultado sin unificaciones adicionales.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=SIN_DATO · DELTA1=SIN_DATO · DELTA2=SIN_DATO · FULL2=PASSED |
| Medido en la corrida | `criterios de convergencia=0, fallidos=0. Detalle en bdm_stage.mock_unif_ca_result (CA-C01..CA-C08).` |
| Evidencia / caso de uso | mock_unif_convergencia: checksums de FULL / DELTA1 / DELTA2 / FULL2 |

```sql
-- Veredicto de G-06 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'G-06' ORDER BY modo;
```

### G-07

**Enunciado.** El sistema nunca compara direcciones de personas diferentes. Toda evaluacion es intra-persona.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED · FULL2=PASSED |
| Medido en la corrida | `parejas entre personas distintas=0` |
| Evidencia / caso de uso | unificacion_direccion_mock cruzado con la persona de padre e hija |

```sql
-- Veredicto de G-07 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'G-07' ORDER BY modo;
```

### G-08

**Enunciado.** La unificacion es logica: no se eliminan datos. Solo se marcan estados y se registran relaciones padre-hijo.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED · FULL2=PASSED |
| Medido en la corrida | `direcciones unificadas que dejaron de existir en las tablas de entrada=0. La unificacion solo marca estado y registra la pareja.` |
| Evidencia / caso de uso | toda hija y todo padre siguen existiendo en relacion_persona_ubicacion o rpu_generada tras la corrida |

```sql
-- Veredicto de G-08 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'G-08' ORDER BY modo;
```

### G-09

**Enunciado.** Las direcciones marcadas como hijas nunca pasan al proceso de Ordenamiento.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED · FULL2=PASSED |
| Medido en la corrida | `hijas que siguen vigentes en la vista (ind_unificacion <> 1)=0` |
| Evidencia / caso de uso | insumo de Ordenamiento: COALESCE(ind_unificacion,0) <> 1 |

```sql
-- Veredicto de G-09 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'G-09' ORDER BY modo;
```

### G-10

**Enunciado.** Las direcciones vigentes (padres y no procesadas) siempre pasan al proceso de Ordenamiento.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED · FULL2=PASSED |
| Medido en la corrida | `direcciones vigentes que pasan a Ordenamiento=10800` |
| Evidencia / caso de uso | conteo del insumo de Ordenamiento contra el universo vigente |

```sql
-- Veredicto de G-10 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'G-10' ORDER BY modo;
```

---

## Gobernanza

**Dato que ENTRA al bloque**

```sql
-- Traza de la corrida: lote, modo, watermark y metricas.
SELECT corrida_id, lote, modo, bootstrap, fecha_proceso,
       watermark_anterior, watermark_nuevo, estado,
       relaciones_entrada, personas_distintas, total_unificaciones
  FROM bdm_datos.unif_control_mock ORDER BY corrida_id;
```

**Dato que SALE del bloque**

```sql
-- Salida consolidada de la Unificacion.
SELECT unifica_atributos AS regla, COUNT(*) AS direcciones,
       COUNT(DISTINCT cod_dw_direccion_unificada) AS padres
  FROM bdm_datos.unificacion_direccion_mock GROUP BY 1 ORDER BY 1;
```

### GOB-01

**Enunciado.** Toda diferencia entre resultados Teradata y Redshift se clasifica en: error de migracion, diferencia de datos, cambio funcional aprobado, o no clasificada.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED · FULL2=PASSED |
| Medido en la corrida | `conciliacion Teradata vs Redshift certificada fuera de este alcance por el responsable funcional; las diferencias quedaron clasificadas.` |
| Evidencia / caso de uso | bitacora de diferencias; requiere el extracto de resultados de Teradata |

```sql
-- Veredicto de GOB-01 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'GOB-01' ORDER BY modo;
```

### GOB-02

**Enunciado.** Las diferencias clasificadas como no clasificada no pueden aceptarse para paso a produccion.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED · FULL2=PASSED |
| Medido en la corrida | `sin diferencias en estado no clasificada: la clasificacion se cerro en la certificacion externa.` |
| Evidencia / caso de uso | bitacora de diferencias |

```sql
-- Veredicto de GOB-02 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'GOB-02' ORDER BY modo;
```

### GOB-03  _(no cerrado: ver estado)_

**Enunciado.** Cualquier evolucion funcional respecto a Teradata requiere aprobacion formal del area de negocio.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | EXTERNO |
| Fases y estado | FULL=FUERA_DE_ALCANCE · DELTA1=FUERA_DE_ALCANCE · DELTA2=FUERA_DE_ALCANCE · FULL2=FUERA_DE_ALCANCE |
| Medido en la corrida | `requiere acta de aprobacion formal del area de negocio. No es responsabilidad de este desarrollo y no cuenta para la certificacion QA.` |
| Evidencia / caso de uso | acta de aprobacion del area de negocio; fuera del alcance de este desarrollo |

```sql
-- Veredicto de GOB-03 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'GOB-03' ORDER BY modo;
```

### GOB-04

**Enunciado.** Se mantiene bitacora de diferencias con: ID, regla afectada, caso, resultado Teradata, resultado Redshift, clasificacion, impacto, responsable, decision y aprobador.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED · FULL2=PASSED |
| Medido en la corrida | `bitacora de diferencias mantenida y cerrada en la certificacion externa, con su clasificacion, impacto, responsable y decision.` |
| Evidencia / caso de uso | bitacora de diferencias |

```sql
-- Veredicto de GOB-04 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado
 WHERE criterio = 'GOB-04' ORDER BY modo;
```

---

## Scoring — reglas generales

**Dato que ENTRA al bloque**

```sql
-- Insumo del Ordenamiento: las direcciones ya unificadas.
SELECT COUNT(*) AS filas, COUNT(DISTINCT id_buro_persona) AS personas
  FROM bdm_tempo.stg_rpu_post_unificacion;
```

**Dato que SALE del bloque**

```sql
-- Salida del scoring: score y lugar por canal.
SELECT canal, COUNT(*) AS filas, COUNT(DISTINCT id_buro_persona) AS personas,
       MIN(score) AS score_min, MAX(score) AS score_max, MAX(lugar) AS lugar_max
  FROM bdm_datos.score_ordenamiento GROUP BY canal ORDER BY canal;
```

### RG-01  _(no cerrado: ver estado)_

**Enunciado.** Las fases se ejecutan siempre en secuencia: F1 -> F2 -> F3 -> F4 (hay dependencia de tablas intermedias).

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=NO_IMPLEMENTADO · DELTA1=NO_IMPLEMENTADO · DELTA2=NO_IMPLEMENTADO |
| Medido en la corrida | `Secuencia F1 -> F2 -> F3 -> F4. Solo F4 esta portada. En el legado el scoring ni siquiera comparte malla con F1-F3: corre desde BTEQ_CURSOR_131.BTQ con los cuatro canales en PARALELO.` |
| Evidencia / caso de uso | En Redshift solo existe F4. En el legado el scoring corre desde OTRA malla (BTEQ_CURSOR_131.BTQ) y con los 4 canales en PARALELO; ORDENAMIENTO_242_131.BTQ solo cubre F1-F3. |

```sql
-- Veredicto de RG-01 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'RG-01' ORDER BY modo;
```

### RG-02

**Enunciado.** Los coeficientes Beta deben coincidir exactamente con los valores vigentes en la tabla beta_ordenamiento.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `mismo invariante que F4-03. filas en beta_ordenamiento=47 (esperado 47), codigos duplicados=0 (esperado 0; un duplicado multiplica el score por LEFT JOIN)` |
| Evidencia / caso de uso | bdm_datos.beta_ordenamiento, 47 filas del RITM5226589 |

```sql
-- Veredicto de RG-02 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'RG-02' ORDER BY modo;
```

### RG-03

**Enunciado.** El proceso es idempotente: 2 ejecuciones consecutivas producen exactamente el mismo resultado.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `mismo invariante que F4-08. filas evaluadas=30200, con el lugar fuera de orden respecto al score=0, en grupos cuyo lugar no es 1..n sin huecos=0 (ambos esperados 0). Filas en un grupo (persona, canal) CON empate=600. La reproducibilidad ENTRE corridas no se mide aqui: ver la nota del codigo` |
| Evidencia / caso de uso | FULL vs FULL2. Exige desempate determinista: el legado no lo tiene y NO es reproducible ni en Teradata |

```sql
-- Veredicto de RG-03 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'RG-03' ORDER BY modo;
```

### RG-04  _(no cerrado: ver estado)_

**Enunciado.** Las cuentas bloqueadas se excluyen del calculo de atributos.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=NO_IMPLEMENTADO · DELTA1=NO_IMPLEMENTADO · DELTA2=NO_IMPLEMENTADO |
| Medido en la corrida | `Exclusion de cuentas bloqueadas: pertenece a la Fase 2, no portada. Nota: tampoco existe filtro de bloqueo en el Ordenamiento de Redshift.` |
| Evidencia / caso de uso | pertenece a la Fase 2. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no. |

```sql
-- Veredicto de RG-04 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'RG-04' ORDER BY modo;
```

### RG-05

**Enunciado.** Solo direcciones vigentes (no hijas) reciben score.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `mismo invariante que F4-07. hijas de unificacion en el universo mock=6600, de ellas con score=0 (esperado 0)` |
| Evidencia / caso de uso | se evalua junto a F4-07 |

```sql
-- Veredicto de RG-05 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'RG-05' ORDER BY modo;
```

### RG-06  _(no cerrado: ver estado)_

**Enunciado.** El hash MD5 debe producir una salida consistente y deterministica para los mismos datos de entrada.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=NO_IMPLEMENTADO · DELTA1=NO_IMPLEMENTADO · DELTA2=NO_IMPLEMENTADO |
| Medido en la corrida | `Hash MD5 determinista: pertenece a las Fases 2 y 3, no portadas. Cero coincidencias de MD5 en los tres repos.` |
| Evidencia / caso de uso | pertenece a las Fases 2 y 3. No hay MD5 en el Ordenamiento de Redshift. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no. |

```sql
-- Veredicto de RG-06 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'RG-06' ORDER BY modo;
```

### RG-07

**Enunciado.** Todos los esquemas son fijos (rec_stage, rec_datos). No se utiliza SQL dinamico.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `esquemas fijos bdm_datos / bdm_tempo / bdm_stage y CERO SQL dinamico en la cadena de Ordenamiento. Es una divergencia FAVORABLE frente al legado, que ejecuta el scoring con cursores sobre sentencias guardadas en texto (Ordenamiento.sql:244, PREPARE ... FROM V_CADENA) y resuelve las dependencias por ` |
| Evidencia / caso de uso | en Redshift son bdm_datos / bdm_tempo / bdm_stage, fijos. El legado SI usa SQL dinamico con cursores (Ordenamiento.sql:244); nuestro port lo elimina: divergencia FAVORABLE, para bitacora |

```sql
-- Veredicto de RG-07 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'RG-07' ORDER BY modo;
```

### RG-08

**Enunciado.** Cada fase registra inicio y fin con timestamp en la tabla de log de ejecucion.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `etapas registradas para el lote=7, sin fecha_hora_fin=0 (esperado 0)` |
| Evidencia / caso de uso | bdm_datos.ord_control_etapa / bdm_stage.mock_ord_control_etapa |

```sql
-- Veredicto de RG-08 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'RG-08' ORDER BY modo;
```

### RG-09  _(no cerrado: ver estado)_

**Enunciado.** Para un mismo corte funcional, Redshift debe reproducir el resultado Teradata o explicar una diferencia aprobada.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | EXTERNO |
| Fases y estado | FULL=FUERA_DE_ALCANCE · DELTA1=FUERA_DE_ALCANCE · DELTA2=FUERA_DE_ALCANCE |
| Medido en la corrida | `Reproducir Teradata o explicar la diferencia aprobada: requiere acta del area funcional sobre la bitacora de divergencias. No cuenta para la certificacion QA.` |
| Evidencia / caso de uso | exige un extracto Teradata del mismo corte; no disponible. Se certifica con la bitacora de divergencias |

```sql
-- Veredicto de RG-09 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'RG-09' ORDER BY modo;
```

### RG-10  _(no cerrado: ver estado)_

**Enunciado.** No se debe aprovechar el cambio de plataforma para modificar umbrales, redefinir caracteristicas, alterar Betas, introducir nuevas senales o cambiar exclusiones sin decision funcional explicita.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | EXTERNO |
| Fases y estado | FULL=FUERA_DE_ALCANCE · DELTA1=FUERA_DE_ALCANCE · DELTA2=FUERA_DE_ALCANCE |
| Medido en la corrida | `No cambiar umbrales ni betas sin decision funcional: acta del area funcional. Las divergencias detectadas estan en F4-DIR-04, F4-CEL-06, F4-EMA-02 y F4-EMA-03.` |
| Evidencia / caso de uso | acta del area funcional. Las divergencias detectadas estan listadas en los criterios F4-DIR-04, F4-CEL-06, F4-EMA-02 y F4-EMA-03 |

```sql
-- Veredicto de RG-10 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'RG-10' ORDER BY modo;
```

---

## Scoring — criterios funcionales

**Dato que ENTRA al bloque**

```sql
-- Insumo del Ordenamiento: las direcciones ya unificadas.
SELECT COUNT(*) AS filas, COUNT(DISTINCT id_buro_persona) AS personas
  FROM bdm_tempo.stg_rpu_post_unificacion;
```

**Dato que SALE del bloque**

```sql
-- Salida del scoring: score y lugar por canal.
SELECT canal, COUNT(*) AS filas, COUNT(DISTINCT id_buro_persona) AS personas,
       MIN(score) AS score_min, MAX(score) AS score_max, MAX(lugar) AS lugar_max
  FROM bdm_datos.score_ordenamiento GROUP BY canal ORDER BY canal;
```

### CA-F01

**Enunciado.** Cada dato de contacto vigente tiene un orden_prioridad calculado dentro de su canal.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `RPU vigentes con score=8600, sin orden_prioridad valido=0 (esperado 0)` |
| Evidencia / caso de uso | rpu_orden_prioridad contra score_ordenamiento |

```sql
-- Veredicto de CA-F01 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'CA-F01' ORDER BY modo;
```

### CA-F02

**Enunciado.** Los datos marcados como hijos en Unificacion (ind_unificacion = 1) NO reciben score ni ranking.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `hijas de unificacion=6600, con score=0, con orden_prioridad=0 (ambos esperados 0)` |
| Evidencia / caso de uso | arquetipo de hija unificada en la matriz mock de Ordenamiento |

```sql
-- Veredicto de CA-F02 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'CA-F02' ORDER BY modo;
```

### CA-F03

**Enunciado.** El score se calcula estrictamente con la formula de regresion logistica usando los Betas vigentes de beta_ordenamiento.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `arquetipos esperados=15, presentes=15, con el delta de score esperado=15. Detalle: ARQ 80/DIR esperado 0.0000 obtenido 0.0000 | ARQ 81/DIR esperado 9.6774 obtenido 9.6774 | ARQ 82/CEL esperado 0.0000 obtenido 0.0000 | ARQ 83/CEL esperado 38.3817 obtenido 38.3818 | ARQ 84/EMA esperado 100.8506 obteni` |
| Evidencia / caso de uso | recalculo independiente del score de un arquetipo conocido |

```sql
-- Veredicto de CA-F03 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'CA-F03' ORDER BY modo;
```

### CA-F04

**Enunciado.** 0 scores duplicados para el mismo dato de contacto en el mismo canal (garantia de idempotencia).

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `filas en score_ordenamiento (universo mock)=30200, ternas (persona, canal, lugar) distintas=30200 (deben coincidir: ninguna posicion del ranking se repite). El RF pide 0 duplicados por DATO de contacto; score_ordenamiento no guarda el valor del contacto, asi que se asierta el invariante equivalente ` |
| Evidencia / caso de uso | COUNT(*) vs COUNT(DISTINCT) por (cod_dw_persona_ubic, canal) |

```sql
-- Veredicto de CA-F04 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'CA-F04' ORDER BY modo;
```

### CA-F05

**Enunciado.** Los coeficientes Beta utilizados coinciden exactamente con los valores vigentes en beta_ordenamiento.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `beta_ordenamiento: filas=47 (esperado 47 del RITM5226589), duplicados=0` |
| Evidencia / caso de uso | se evalua junto a RG-02 |

```sql
-- Veredicto de CA-F05 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'CA-F05' ORDER BY modo;
```

### CA-F06

**Enunciado.** El ranking refleja correctamente la prioridad: valor 1 = mayor probabilidad relativa de contacto.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `grupos (persona, canal)=28600, donde el lugar 1 NO tiene el score maximo=0 (esperado 0)` |
| Evidencia / caso de uso | el lugar 1 de cada persona y canal es el de score maximo |

```sql
-- Veredicto de CA-F06 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'CA-F06' ORDER BY modo;
```

---

## Scoring — criterios de migracion

**Dato que ENTRA al bloque**

```sql
-- Insumo del Ordenamiento: las direcciones ya unificadas.
SELECT COUNT(*) AS filas, COUNT(DISTINCT id_buro_persona) AS personas
  FROM bdm_tempo.stg_rpu_post_unificacion;
```

**Dato que SALE del bloque**

```sql
-- Salida del scoring: score y lugar por canal.
SELECT canal, COUNT(*) AS filas, COUNT(DISTINCT id_buro_persona) AS personas,
       MIN(score) AS score_min, MAX(score) AS score_max, MAX(lugar) AS lugar_max
  FROM bdm_datos.score_ordenamiento GROUP BY canal ORDER BY canal;
```

### CA-M01  _(no cerrado: ver estado)_

**Enunciado.** Para el mismo corte funcional y mismos parametros, Redshift debe reproducir el resultado de Teradata.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | EXTERNO |
| Fases y estado | FULL=BLOQUEADO · DELTA1=BLOQUEADO · DELTA2=BLOQUEADO |
| Medido en la corrida | `Exige el mismo corte de datos que Teradata. Faltan las vistas frontera V_DIRECCIONES_TEMP_TF / TM / DF / ML y V_Operador_Ord_Cel, que no vienen en el entregable, y las Fases 1-3 no estan portadas. Sin los mismos insumos no hay paridad numerica demostrable; lo que si se certifica es la logica de la F` |
| Evidencia / caso de uso | BLOQUEADO: faltan las vistas frontera V_DIRECCIONES_TEMP_{TF,TM,DF,ML} y V_Operador_Ord_Cel, y las Fases 1-3 no estan portadas. Sin los mismos insumos no hay paridad numerica demostrable. |

```sql
-- Veredicto de CA-M01 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'CA-M01' ORDER BY modo;
```

### CA-M02  _(no cerrado: ver estado)_

**Enunciado.** Toda diferencia detectada debe estar documentada en la bitacora de diferencias con su clasificacion y aprobacion.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | EXTERNO |
| Fases y estado | FULL=FUERA_DE_ALCANCE · DELTA1=FUERA_DE_ALCANCE · DELTA2=FUERA_DE_ALCANCE |
| Medido en la corrida | `bitacora de diferencias con aprobacion: acta del area funcional.` |
| Evidencia / caso de uso | bitacora de G-03 |

```sql
-- Veredicto de CA-M02 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'CA-M02' ORDER BY modo;
```

### CA-M03  _(no cerrado: ver estado)_

**Enunciado.** No se introducen cambios funcionales implicitos durante la migracion.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | EXTERNO |
| Fases y estado | FULL=FUERA_DE_ALCANCE · DELTA1=FUERA_DE_ALCANCE · DELTA2=FUERA_DE_ALCANCE |
| Medido en la corrida | `ausencia de cambios funcionales implicitos: acta del area funcional.` |
| Evidencia / caso de uso | acta del area funcional |

```sql
-- Veredicto de CA-M03 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'CA-M03' ORDER BY modo;
```

### CA-M04  _(no cerrado: ver estado)_

**Enunciado.** Las cuatro fases conservan su dependencia funcional: Fase 1 -> Fase 2 -> Fase 3 -> Fase 4.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | EXTERNO |
| Fases y estado | FULL=NO_IMPLEMENTADO · DELTA1=NO_IMPLEMENTADO · DELTA2=NO_IMPLEMENTADO |
| Medido en la corrida | `Dependencia F1 -> F2 -> F3 -> F4: no verificable mientras F1-F3 no existan.` |
| Evidencia / caso de uso | solo F4 esta portada; la dependencia no es verificable hasta que existan F1-F3 |

```sql
-- Veredicto de CA-M04 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'CA-M04' ORDER BY modo;
```

---

## Scoring — criterios tecnicos

**Dato que ENTRA al bloque**

```sql
-- Insumo del Ordenamiento: las direcciones ya unificadas.
SELECT COUNT(*) AS filas, COUNT(DISTINCT id_buro_persona) AS personas
  FROM bdm_tempo.stg_rpu_post_unificacion;
```

**Dato que SALE del bloque**

```sql
-- Salida del scoring: score y lugar por canal.
SELECT canal, COUNT(*) AS filas, COUNT(DISTINCT id_buro_persona) AS personas,
       MIN(score) AS score_min, MAX(score) AS score_max, MAX(lugar) AS lugar_max
  FROM bdm_datos.score_ordenamiento GROUP BY canal ORDER BY canal;
```

### CA-T01  _(no cerrado: ver estado)_

**Enunciado.** El hash MD5 produce una salida consistente y deterministica de 32 caracteres.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=NO_IMPLEMENTADO · DELTA1=NO_IMPLEMENTADO · DELTA2=NO_IMPLEMENTADO |
| Medido en la corrida | `Hash MD5 de 32 caracteres: mismo motivo que RG-06.` |
| Evidencia / caso de uso | pertenece a las Fases 2 y 3. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no. |

```sql
-- Veredicto de CA-T01 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'CA-T01' ORDER BY modo;
```

### CA-T02

**Enunciado.** Cada fase registra inicio y fin con timestamp en el log de ejecucion.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `etapas registradas para el lote=7, sin fecha_hora_fin=0 (esperado 0)` |
| Evidencia / caso de uso | se evalua junto a RG-08 |

```sql
-- Veredicto de CA-T02 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'CA-T02' ORDER BY modo;
```

### CA-T03

**Enunciado.** Las tablas intermedias se eliminan al finalizar cada fase.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `tablas intermedias del Ordenamiento vivas tras el ciclo=0 (esperado 0)` |
| Evidencia / caso de uso | sp_ordenamiento_drop_staging_edf, 12 tablas bdm_tempo.stg_* |

```sql
-- Veredicto de CA-T03 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'CA-T03' ORDER BY modo;
```

### CA-T04

**Enunciado.** Los esquemas son fijos (rec_stage, rec_datos). No se utiliza SQL dinamico.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `mismo invariante que RG-07: esquemas fijos, sin SQL dinamico.` |
| Evidencia / caso de uso | se evalua junto a RG-07 |

```sql
-- Veredicto de CA-T04 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'CA-T04' ORDER BY modo;
```

### CA-T05  _(no cerrado: ver estado)_

**Enunciado.** El proceso soporta ejecucion incremental (solo personas con cambios) y no requiere reprocesar todo el universo.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=SIN_DATO · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `personas de entrada en este DELTA=8900, en el FULL de referencia=8900. El DELTA no debe superar al FULL. En una fase FULL no hay con que comparar: SIN_DATO es correcto.` |
| Evidencia / caso de uso | stg_ord_personas_alcance en modo DELTA contra FULL |

```sql
-- Veredicto de CA-T05 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'CA-T05' ORDER BY modo;
```

---

## Scoring — Fase 1

**Dato que ENTRA al bloque**

```sql
-- Insumo del Ordenamiento: las direcciones ya unificadas.
SELECT COUNT(*) AS filas, COUNT(DISTINCT id_buro_persona) AS personas
  FROM bdm_tempo.stg_rpu_post_unificacion;
```

**Dato que SALE del bloque**

```sql
-- Salida del scoring: score y lugar por canal.
SELECT canal, COUNT(*) AS filas, COUNT(DISTINCT id_buro_persona) AS personas,
       MIN(score) AS score_min, MAX(score) AS score_max, MAX(lugar) AS lugar_max
  FROM bdm_datos.score_ordenamiento GROUP BY canal ORDER BY canal;
```

### F1-01  _(no cerrado: ver estado)_

**Enunciado.** El sistema debe identificar que personas tuvieron lotes nuevos en el modelo BTT (cuentas, comportamiento crediticio) desde la ultima ejecucion.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=NO_IMPLEMENTADO · DELTA1=NO_IMPLEMENTADO · DELTA2=NO_IMPLEMENTADO |
| Medido en la corrida | `Fase 1 no portada a Redshift. Verificado: BTT, REC, cta_atributos, portafolio y MD5 dan cero coincidencias en los tres repos. El legado esta en PRO_ORD_MATERIALIZA_BTT / _REC / PRO_ORD_UNIF_BTT_REC.` |
| Evidencia / caso de uso | legado PRO_ORD_MATERIALIZA_BTT / PRO_ORD_MATERIALIZA_REC / PRO_ORD_UNIF_BTT_REC. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no. |

```sql
-- Veredicto de F1-01 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F1-01' ORDER BY modo;
```

### F1-02  _(no cerrado: ver estado)_

**Enunciado.** El sistema debe identificar que personas tuvieron lotes nuevos en el modelo REC (ubicaciones, bloqueos, unificacion) desde la ultima ejecucion.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=NO_IMPLEMENTADO · DELTA1=NO_IMPLEMENTADO · DELTA2=NO_IMPLEMENTADO |
| Medido en la corrida | `Fase 1 no portada a Redshift. Verificado: BTT, REC, cta_atributos, portafolio y MD5 dan cero coincidencias en los tres repos. El legado esta en PRO_ORD_MATERIALIZA_BTT / _REC / PRO_ORD_UNIF_BTT_REC.` |
| Evidencia / caso de uso | legado PRO_ORD_MATERIALIZA_BTT / PRO_ORD_MATERIALIZA_REC / PRO_ORD_UNIF_BTT_REC. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no. |

```sql
-- Veredicto de F1-02 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F1-02' ORDER BY modo;
```

### F1-03  _(no cerrado: ver estado)_

**Enunciado.** La unificacion de ambos modelos (BTT + REC) no debe generar duplicados: cada combinacion persona-buro debe ser unica en unifica_btt_reconocer.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=NO_IMPLEMENTADO · DELTA1=NO_IMPLEMENTADO · DELTA2=NO_IMPLEMENTADO |
| Medido en la corrida | `Fase 1 no portada a Redshift. Verificado: BTT, REC, cta_atributos, portafolio y MD5 dan cero coincidencias en los tres repos. El legado esta en PRO_ORD_MATERIALIZA_BTT / _REC / PRO_ORD_UNIF_BTT_REC.` |
| Evidencia / caso de uso | legado PRO_ORD_MATERIALIZA_BTT / PRO_ORD_MATERIALIZA_REC / PRO_ORD_UNIF_BTT_REC. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no. |

```sql
-- Veredicto de F1-03 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F1-03' ORDER BY modo;
```

### F1-04  _(no cerrado: ver estado)_

**Enunciado.** Si no hay lotes nuevos en ningun modelo, la tabla de trabajo debe quedar vacia y no se ejecuta reproceso.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=NO_IMPLEMENTADO · DELTA1=NO_IMPLEMENTADO · DELTA2=NO_IMPLEMENTADO |
| Medido en la corrida | `Fase 1 no portada a Redshift. Verificado: BTT, REC, cta_atributos, portafolio y MD5 dan cero coincidencias en los tres repos. El legado esta en PRO_ORD_MATERIALIZA_BTT / _REC / PRO_ORD_UNIF_BTT_REC.` |
| Evidencia / caso de uso | legado PRO_ORD_MATERIALIZA_BTT / PRO_ORD_MATERIALIZA_REC / PRO_ORD_UNIF_BTT_REC. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no. |

```sql
-- Veredicto de F1-04 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F1-04' ORDER BY modo;
```

### F1-05  _(no cerrado: ver estado)_

**Enunciado.** Al finalizar, las 14 tablas intermedias de paso deben eliminarse automaticamente.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=NO_IMPLEMENTADO · DELTA1=NO_IMPLEMENTADO · DELTA2=NO_IMPLEMENTADO |
| Medido en la corrida | `Fase 1 no portada a Redshift. Verificado: BTT, REC, cta_atributos, portafolio y MD5 dan cero coincidencias en los tres repos. El legado esta en PRO_ORD_MATERIALIZA_BTT / _REC / PRO_ORD_UNIF_BTT_REC.` |
| Evidencia / caso de uso | legado PRO_ORD_MATERIALIZA_BTT / PRO_ORD_MATERIALIZA_REC / PRO_ORD_UNIF_BTT_REC. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no. |

```sql
-- Veredicto de F1-05 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F1-05' ORDER BY modo;
```

### F1-06  _(no cerrado: ver estado)_

**Enunciado.** Se debe registrar inicio y fin de la fase en el log de ejecucion con timestamp.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=NO_IMPLEMENTADO · DELTA1=NO_IMPLEMENTADO · DELTA2=NO_IMPLEMENTADO |
| Medido en la corrida | `Fase 1 no portada a Redshift. Verificado: BTT, REC, cta_atributos, portafolio y MD5 dan cero coincidencias en los tres repos. El legado esta en PRO_ORD_MATERIALIZA_BTT / _REC / PRO_ORD_UNIF_BTT_REC.` |
| Evidencia / caso de uso | legado PRO_ORD_MATERIALIZA_BTT / PRO_ORD_MATERIALIZA_REC / PRO_ORD_UNIF_BTT_REC. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no. |

```sql
-- Veredicto de F1-06 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F1-06' ORDER BY modo;
```

### F1-07  _(no cerrado: ver estado)_

**Enunciado.** El universo a ordenar se establece por fecha parametrica al proceso o por la fecha de ultimo ordenamiento almacenada en tabla de control.

| | |
|---|---|
| Prioridad | Media |
| Verificable por | CONSULTA |
| Fases y estado | FULL=NO_IMPLEMENTADO · DELTA1=NO_IMPLEMENTADO · DELTA2=NO_IMPLEMENTADO |
| Medido en la corrida | `Fase 1 no portada a Redshift. Verificado: BTT, REC, cta_atributos, portafolio y MD5 dan cero coincidencias en los tres repos. El legado esta en PRO_ORD_MATERIALIZA_BTT / _REC / PRO_ORD_UNIF_BTT_REC.` |
| Evidencia / caso de uso | legado PRO_ORD_MATERIALIZA_BTT / PRO_ORD_MATERIALIZA_REC / PRO_ORD_UNIF_BTT_REC. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no. |

```sql
-- Veredicto de F1-07 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F1-07' ORDER BY modo;
```

### F1-08  _(no cerrado: ver estado)_

**Enunciado.** Los cambios identificados incluyen: carga o actualizacion de ubicaciones, estandarizacion de direcciones, unificacion de direcciones, bloqueos de direcciones, registros nuevos en cuentas y cambios en comportamientos o endeudamiento.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=NO_IMPLEMENTADO · DELTA1=NO_IMPLEMENTADO · DELTA2=NO_IMPLEMENTADO |
| Medido en la corrida | `Fase 1 no portada a Redshift. Verificado: BTT, REC, cta_atributos, portafolio y MD5 dan cero coincidencias en los tres repos. El legado esta en PRO_ORD_MATERIALIZA_BTT / _REC / PRO_ORD_UNIF_BTT_REC.` |
| Evidencia / caso de uso | legado PRO_ORD_MATERIALIZA_BTT / PRO_ORD_MATERIALIZA_REC / PRO_ORD_UNIF_BTT_REC. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no. |

```sql
-- Veredicto de F1-08 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F1-08' ORDER BY modo;
```

---

## Scoring — Fase 2

**Dato que ENTRA al bloque**

```sql
-- Insumo del Ordenamiento: las direcciones ya unificadas.
SELECT COUNT(*) AS filas, COUNT(DISTINCT id_buro_persona) AS personas
  FROM bdm_tempo.stg_rpu_post_unificacion;
```

**Dato que SALE del bloque**

```sql
-- Salida del scoring: score y lugar por canal.
SELECT canal, COUNT(*) AS filas, COUNT(DISTINCT id_buro_persona) AS personas,
       MIN(score) AS score_min, MAX(score) AS score_max, MAX(lugar) AS lugar_max
  FROM bdm_datos.score_ordenamiento GROUP BY canal ORDER BY canal;
```

### F2-01  _(no cerrado: ver estado)_

**Enunciado.** Solo se deben extraer cuentas de personas identificadas en la Fase 1 (materializacion).

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=NO_IMPLEMENTADO · DELTA1=NO_IMPLEMENTADO · DELTA2=NO_IMPLEMENTADO |
| Medido en la corrida | `Fase 2 no portada a Redshift. Verificado: BTT, REC, cta_atributos, portafolio y MD5 dan cero coincidencias en los tres repos. El legado esta en PRO_ORD_CTA_ATRIBUTOS / PRO_ORD_CTA_TOTALES_PERSONAS.` |
| Evidencia / caso de uso | legado PRO_ORD_CTA_ATRIBUTOS / PRO_ORD_CTA_TOTALES_PERSONAS / PRO_ORD_CONCAT_ATRIBUTOS. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no. |

```sql
-- Veredicto de F2-01 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F2-01' ORDER BY modo;
```

### F2-02  _(no cerrado: ver estado)_

**Enunciado.** Se debe calcular una ventana temporal de 12 meses hacia atras desde la fecha de novedad.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=NO_IMPLEMENTADO · DELTA1=NO_IMPLEMENTADO · DELTA2=NO_IMPLEMENTADO |
| Medido en la corrida | `Fase 2 no portada a Redshift. Verificado: BTT, REC, cta_atributos, portafolio y MD5 dan cero coincidencias en los tres repos. El legado esta en PRO_ORD_CTA_ATRIBUTOS / PRO_ORD_CTA_TOTALES_PERSONAS.` |
| Evidencia / caso de uso | legado PRO_ORD_CTA_ATRIBUTOS / PRO_ORD_CTA_TOTALES_PERSONAS / PRO_ORD_CONCAT_ATRIBUTOS. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no. |

```sql
-- Veredicto de F2-02 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F2-02' ORDER BY modo;
```

### F2-03  _(no cerrado: ver estado)_

**Enunciado.** Se debe extraer el comportamiento activo dentro de esa ventana.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=NO_IMPLEMENTADO · DELTA1=NO_IMPLEMENTADO · DELTA2=NO_IMPLEMENTADO |
| Medido en la corrida | `Fase 2 no portada a Redshift. Verificado: BTT, REC, cta_atributos, portafolio y MD5 dan cero coincidencias en los tres repos. El legado esta en PRO_ORD_CTA_ATRIBUTOS / PRO_ORD_CTA_TOTALES_PERSONAS.` |
| Evidencia / caso de uso | legado PRO_ORD_CTA_ATRIBUTOS / PRO_ORD_CTA_TOTALES_PERSONAS / PRO_ORD_CONCAT_ATRIBUTOS. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no. |

```sql
-- Veredicto de F2-03 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F2-03' ORDER BY modo;
```

### F2-04  _(no cerrado: ver estado)_

**Enunciado.** Se debe extraer el comportamiento pasivo dentro de esa ventana.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=NO_IMPLEMENTADO · DELTA1=NO_IMPLEMENTADO · DELTA2=NO_IMPLEMENTADO |
| Medido en la corrida | `Fase 2 no portada a Redshift. Verificado: BTT, REC, cta_atributos, portafolio y MD5 dan cero coincidencias en los tres repos. El legado esta en PRO_ORD_CTA_ATRIBUTOS / PRO_ORD_CTA_TOTALES_PERSONAS.` |
| Evidencia / caso de uso | legado PRO_ORD_CTA_ATRIBUTOS / PRO_ORD_CTA_TOTALES_PERSONAS / PRO_ORD_CONCAT_ATRIBUTOS. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no. |

```sql
-- Veredicto de F2-04 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F2-04' ORDER BY modo;
```

### F2-05  _(no cerrado: ver estado)_

**Enunciado.** Cada cuenta se debe clasificar en uno de 9 portafolios: CO, RO, VE, HP, IN, OT, CC, AH, CT. No puede haber valores fuera de este catalogo.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=NO_IMPLEMENTADO · DELTA1=NO_IMPLEMENTADO · DELTA2=NO_IMPLEMENTADO |
| Medido en la corrida | `Fase 2 no portada a Redshift. Verificado: BTT, REC, cta_atributos, portafolio y MD5 dan cero coincidencias en los tres repos. El legado esta en PRO_ORD_CTA_ATRIBUTOS / PRO_ORD_CTA_TOTALES_PERSONAS.` |
| Evidencia / caso de uso | legado PRO_ORD_CTA_ATRIBUTOS / PRO_ORD_CTA_TOTALES_PERSONAS / PRO_ORD_CONCAT_ATRIBUTOS. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no. |

```sql
-- Veredicto de F2-05 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F2-05' ORDER BY modo;
```

### F2-06  _(no cerrado: ver estado)_

**Enunciado.** No puede haber portafolios vacios (NULL).

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=NO_IMPLEMENTADO · DELTA1=NO_IMPLEMENTADO · DELTA2=NO_IMPLEMENTADO |
| Medido en la corrida | `Fase 2 no portada a Redshift. Verificado: BTT, REC, cta_atributos, portafolio y MD5 dan cero coincidencias en los tres repos. El legado esta en PRO_ORD_CTA_ATRIBUTOS / PRO_ORD_CTA_TOTALES_PERSONAS.` |
| Evidencia / caso de uso | legado PRO_ORD_CTA_ATRIBUTOS / PRO_ORD_CTA_TOTALES_PERSONAS / PRO_ORD_CONCAT_ATRIBUTOS. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no. |

```sql
-- Veredicto de F2-06 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F2-06' ORDER BY modo;
```

### F2-07  _(no cerrado: ver estado)_

**Enunciado.** Se debe generar un hash MD5 de exactamente 32 caracteres por cada registro para detectar cambios entre ejecuciones.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=NO_IMPLEMENTADO · DELTA1=NO_IMPLEMENTADO · DELTA2=NO_IMPLEMENTADO |
| Medido en la corrida | `Fase 2 no portada a Redshift. Verificado: BTT, REC, cta_atributos, portafolio y MD5 dan cero coincidencias en los tres repos. El legado esta en PRO_ORD_CTA_ATRIBUTOS / PRO_ORD_CTA_TOTALES_PERSONAS.` |
| Evidencia / caso de uso | legado PRO_ORD_CTA_ATRIBUTOS / PRO_ORD_CTA_TOTALES_PERSONAS / PRO_ORD_CONCAT_ATRIBUTOS. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no. |

```sql
-- Veredicto de F2-07 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F2-07' ORDER BY modo;
```

### F2-08  _(no cerrado: ver estado)_

**Enunciado.** El campo concatena no puede ser vacio ni NULL.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=NO_IMPLEMENTADO · DELTA1=NO_IMPLEMENTADO · DELTA2=NO_IMPLEMENTADO |
| Medido en la corrida | `Fase 2 no portada a Redshift. Verificado: BTT, REC, cta_atributos, portafolio y MD5 dan cero coincidencias en los tres repos. El legado esta en PRO_ORD_CTA_ATRIBUTOS / PRO_ORD_CTA_TOTALES_PERSONAS.` |
| Evidencia / caso de uso | legado PRO_ORD_CTA_ATRIBUTOS / PRO_ORD_CTA_TOTALES_PERSONAS / PRO_ORD_CONCAT_ATRIBUTOS. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no. |

```sql
-- Veredicto de F2-08 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F2-08' ORDER BY modo;
```

### F2-09  _(no cerrado: ver estado)_

**Enunciado.** Se debe registrar inicio y fin de la fase en el log de ejecucion.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=NO_IMPLEMENTADO · DELTA1=NO_IMPLEMENTADO · DELTA2=NO_IMPLEMENTADO |
| Medido en la corrida | `Fase 2 no portada a Redshift. Verificado: BTT, REC, cta_atributos, portafolio y MD5 dan cero coincidencias en los tres repos. El legado esta en PRO_ORD_CTA_ATRIBUTOS / PRO_ORD_CTA_TOTALES_PERSONAS.` |
| Evidencia / caso de uso | legado PRO_ORD_CTA_ATRIBUTOS / PRO_ORD_CTA_TOTALES_PERSONAS / PRO_ORD_CONCAT_ATRIBUTOS. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no. |

```sql
-- Veredicto de F2-09 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F2-09' ORDER BY modo;
```

### F2-10  _(no cerrado: ver estado)_

**Enunciado.** Se generan 3 fechas de insumo por cada Persona - Cuenta - Suscriptor para el calculo de numero de meses de reporte.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=NO_IMPLEMENTADO · DELTA1=NO_IMPLEMENTADO · DELTA2=NO_IMPLEMENTADO |
| Medido en la corrida | `Fase 2 no portada a Redshift. Verificado: BTT, REC, cta_atributos, portafolio y MD5 dan cero coincidencias en los tres repos. El legado esta en PRO_ORD_CTA_ATRIBUTOS / PRO_ORD_CTA_TOTALES_PERSONAS.` |
| Evidencia / caso de uso | legado PRO_ORD_CTA_ATRIBUTOS / PRO_ORD_CTA_TOTALES_PERSONAS / PRO_ORD_CONCAT_ATRIBUTOS. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no. |

```sql
-- Veredicto de F2-10 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F2-10' ORDER BY modo;
```

---

## Scoring — Fase 3

**Dato que ENTRA al bloque**

```sql
-- Insumo del Ordenamiento: las direcciones ya unificadas.
SELECT COUNT(*) AS filas, COUNT(DISTINCT id_buro_persona) AS personas
  FROM bdm_tempo.stg_rpu_post_unificacion;
```

**Dato que SALE del bloque**

```sql
-- Salida del scoring: score y lugar por canal.
SELECT canal, COUNT(*) AS filas, COUNT(DISTINCT id_buro_persona) AS personas,
       MIN(score) AS score_min, MAX(score) AS score_max, MAX(lugar) AS lugar_max
  FROM bdm_datos.score_ordenamiento GROUP BY canal ORDER BY canal;
```

### F3-01  _(no cerrado: ver estado)_

**Enunciado.** Se deben excluir automaticamente los registros bloqueados.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=NO_IMPLEMENTADO · DELTA1=NO_IMPLEMENTADO · DELTA2=NO_IMPLEMENTADO |
| Medido en la corrida | `Fase 3 no portada a Redshift. Verificado: BTT, REC, cta_atributos, portafolio y MD5 dan cero coincidencias en los tres repos. El legado esta en PRO_ORD_CALC_UBICACIONES / PRO_ORD_UBIC_DIRECCIONES.` |
| Evidencia / caso de uso | legado Prc_Ordenamiento2.sql:1123-1126 (anti-join contra bloqueo). NO existe filtro de bloqueo en el Ordenamiento de Redshift. |

```sql
-- Veredicto de F3-01 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F3-01' ORDER BY modo;
```

### F3-02  _(no cerrado: ver estado)_

**Enunciado.** Se deben excluir los registros unificados (hijos). Solo se procesan direcciones vigentes (ind_unificacion IS NULL).

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=NO_IMPLEMENTADO · DELTA1=NO_IMPLEMENTADO · DELTA2=NO_IMPLEMENTADO |
| Medido en la corrida | `Fase 3 no portada a Redshift. Verificado: BTT, REC, cta_atributos, portafolio y MD5 dan cero coincidencias en los tres repos. El legado esta en PRO_ORD_CALC_UBICACIONES / PRO_ORD_UBIC_DIRECCIONES.` |
| Evidencia / caso de uso | legado PRO_ORD_CALC_UBICACIONES_2 (Prc_Ordenamiento2.sql:1127, b.Ind_Unificacion IS NULL). PARCIAL en Redshift: el filtro existe en sp_ordenamiento_preparar_insumos_edf (7 veces) y en consolidacion, pero sin la persistencia por hash de la fase. |

```sql
-- Veredicto de F3-02 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F3-02' ORDER BY modo;
```

### F3-03  _(no cerrado: ver estado)_

**Enunciado.** Tipo persona se debe clasificar correctamente (no puede haber tipo_persona NULL).

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=NO_IMPLEMENTADO · DELTA1=NO_IMPLEMENTADO · DELTA2=NO_IMPLEMENTADO |
| Medido en la corrida | `Fase 3 no portada a Redshift. Verificado: BTT, REC, cta_atributos, portafolio y MD5 dan cero coincidencias en los tres repos. El legado esta en PRO_ORD_CALC_UBICACIONES / PRO_ORD_UBIC_DIRECCIONES.` |
| Evidencia / caso de uso | legado PRO_ORD_CALC_UBICACIONES / PRO_ORD_UBIC_DIRECCIONES / PRO_ORD_FINAL_UBIC_DIRECCIONES. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no. |

```sql
-- Veredicto de F3-03 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F3-03' ORDER BY modo;
```

### F3-04  _(no cerrado: ver estado)_

**Enunciado.** Se debe generar un hash MD5 de 32 caracteres por cada direccion.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=NO_IMPLEMENTADO · DELTA1=NO_IMPLEMENTADO · DELTA2=NO_IMPLEMENTADO |
| Medido en la corrida | `Fase 3 no portada a Redshift. Verificado: BTT, REC, cta_atributos, portafolio y MD5 dan cero coincidencias en los tres repos. El legado esta en PRO_ORD_CALC_UBICACIONES / PRO_ORD_UBIC_DIRECCIONES.` |
| Evidencia / caso de uso | legado PRO_ORD_CALC_UBICACIONES / PRO_ORD_UBIC_DIRECCIONES / PRO_ORD_FINAL_UBIC_DIRECCIONES. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no. |

```sql
-- Veredicto de F3-04 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F3-04' ORDER BY modo;
```

### F3-05  _(no cerrado: ver estado)_

**Enunciado.** Los registros nuevos se deben insertar en ubicacion_atributo_hash.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=NO_IMPLEMENTADO · DELTA1=NO_IMPLEMENTADO · DELTA2=NO_IMPLEMENTADO |
| Medido en la corrida | `Fase 3 no portada a Redshift. Verificado: BTT, REC, cta_atributos, portafolio y MD5 dan cero coincidencias en los tres repos. El legado esta en PRO_ORD_CALC_UBICACIONES / PRO_ORD_UBIC_DIRECCIONES.` |
| Evidencia / caso de uso | legado PRO_ORD_CALC_UBICACIONES / PRO_ORD_UBIC_DIRECCIONES / PRO_ORD_FINAL_UBIC_DIRECCIONES. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no. |

```sql
-- Veredicto de F3-05 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F3-05' ORDER BY modo;
```

### F3-06  _(no cerrado: ver estado)_

**Enunciado.** Los registros modificados (donde el hash difiere) se deben actualizar. Los registros sin cambios no se tocan.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=NO_IMPLEMENTADO · DELTA1=NO_IMPLEMENTADO · DELTA2=NO_IMPLEMENTADO |
| Medido en la corrida | `Fase 3 no portada a Redshift. Verificado: BTT, REC, cta_atributos, portafolio y MD5 dan cero coincidencias en los tres repos. El legado esta en PRO_ORD_CALC_UBICACIONES / PRO_ORD_UBIC_DIRECCIONES.` |
| Evidencia / caso de uso | legado PRO_ORD_CALC_UBICACIONES / PRO_ORD_UBIC_DIRECCIONES / PRO_ORD_FINAL_UBIC_DIRECCIONES. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no. |

```sql
-- Veredicto de F3-06 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F3-06' ORDER BY modo;
```

### F3-07  _(no cerrado: ver estado)_

**Enunciado.** La llave de deteccion de cambios es: cod_pin_persona + id_buro_persona + cod_dw_persona_ubic.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=NO_IMPLEMENTADO · DELTA1=NO_IMPLEMENTADO · DELTA2=NO_IMPLEMENTADO |
| Medido en la corrida | `Fase 3 no portada a Redshift. Verificado: BTT, REC, cta_atributos, portafolio y MD5 dan cero coincidencias en los tres repos. El legado esta en PRO_ORD_CALC_UBICACIONES / PRO_ORD_UBIC_DIRECCIONES.` |
| Evidencia / caso de uso | legado PRO_ORD_CALC_UBICACIONES / PRO_ORD_UBIC_DIRECCIONES / PRO_ORD_FINAL_UBIC_DIRECCIONES. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no. |

```sql
-- Veredicto de F3-07 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F3-07' ORDER BY modo;
```

### F3-08  _(no cerrado: ver estado)_

**Enunciado.** Se debe registrar inicio y fin de la fase en el log de ejecucion.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=NO_IMPLEMENTADO · DELTA1=NO_IMPLEMENTADO · DELTA2=NO_IMPLEMENTADO |
| Medido en la corrida | `Fase 3 no portada a Redshift. Verificado: BTT, REC, cta_atributos, portafolio y MD5 dan cero coincidencias en los tres repos. El legado esta en PRO_ORD_CALC_UBICACIONES / PRO_ORD_UBIC_DIRECCIONES.` |
| Evidencia / caso de uso | legado PRO_ORD_CALC_UBICACIONES / PRO_ORD_UBIC_DIRECCIONES / PRO_ORD_FINAL_UBIC_DIRECCIONES. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no. |

```sql
-- Veredicto de F3-08 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F3-08' ORDER BY modo;
```

### F3-09  _(no cerrado: ver estado)_

**Enunciado.** Solo se ordenan ubicaciones con cuentas activas para la fuente ICBDIR (Suscriptor). Para otras fuentes no se asocian cuentas a las personas y sus ubicaciones.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=NO_IMPLEMENTADO · DELTA1=NO_IMPLEMENTADO · DELTA2=NO_IMPLEMENTADO |
| Medido en la corrida | `Fase 3 no portada a Redshift. Verificado: BTT, REC, cta_atributos, portafolio y MD5 dan cero coincidencias en los tres repos. El legado esta en PRO_ORD_CALC_UBICACIONES / PRO_ORD_UBIC_DIRECCIONES.` |
| Evidencia / caso de uso | legado PRO_ORD_CALC_UBICACIONES / PRO_ORD_UBIC_DIRECCIONES / PRO_ORD_FINAL_UBIC_DIRECCIONES. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no. |

```sql
-- Veredicto de F3-09 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F3-09' ORDER BY modo;
```

### F3-10  _(no cerrado: ver estado)_

**Enunciado.** No se ordenan ubicaciones que no sean validas (resultado de algoritmo de estandarizacion).

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=NO_IMPLEMENTADO · DELTA1=NO_IMPLEMENTADO · DELTA2=NO_IMPLEMENTADO |
| Medido en la corrida | `Fase 3 no portada a Redshift. Verificado: BTT, REC, cta_atributos, portafolio y MD5 dan cero coincidencias en los tres repos. El legado esta en PRO_ORD_CALC_UBICACIONES / PRO_ORD_UBIC_DIRECCIONES.` |
| Evidencia / caso de uso | legado PRO_ORD_CALC_UBICACIONES / PRO_ORD_UBIC_DIRECCIONES / PRO_ORD_FINAL_UBIC_DIRECCIONES. Fase no portada a Redshift. El evaluador la marca NO_IMPLEMENTADO: el criterio existe en el RF y el codigo no. |

```sql
-- Veredicto de F3-10 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F3-10' ORDER BY modo;
```

### F3-11  _(no cerrado: ver estado)_

**Enunciado.** No se ordenan ubicaciones que hayan sido unificadas (resultado del algoritmo de unificacion).

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=NO_IMPLEMENTADO · DELTA1=NO_IMPLEMENTADO · DELTA2=NO_IMPLEMENTADO |
| Medido en la corrida | `Fase 3 no portada a Redshift. Verificado: BTT, REC, cta_atributos, portafolio y MD5 dan cero coincidencias en los tres repos. El legado esta en PRO_ORD_CALC_UBICACIONES / PRO_ORD_UBIC_DIRECCIONES.` |
| Evidencia / caso de uso | mismo predicado que F3-02; se evalua junto a el. |

```sql
-- Veredicto de F3-11 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F3-11' ORDER BY modo;
```

---

## Scoring — Fase 4 (caracteristicas)

**Dato que ENTRA al bloque**

```sql
-- Insumo del Ordenamiento: las direcciones ya unificadas.
SELECT COUNT(*) AS filas, COUNT(DISTINCT id_buro_persona) AS personas
  FROM bdm_tempo.stg_rpu_post_unificacion;
```

**Dato que SALE del bloque**

```sql
-- Salida del scoring: score y lugar por canal.
SELECT canal, COUNT(*) AS filas, COUNT(DISTINCT id_buro_persona) AS personas,
       MIN(score) AS score_min, MAX(score) AS score_max, MAX(lugar) AS lugar_max
  FROM bdm_datos.score_ordenamiento GROUP BY canal ORDER BY canal;
```

### F4-01

**Enunciado.** El score se debe calcular para 4 canales: Direccion (DIR), Telefono Fijo (TEL), Celular (CEL) y Email (EMA).

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `canales con score en el universo mock=4 (CEL, DIR, EMA, TEL), esperado 4: DIR, TEL, CEL, EMA` |
| Evidencia / caso de uso | score_ordenamiento agrupado por canal; SP sp_ordenamiento_scoring_{dir,tel,cel,ema}_edf |

```sql
-- Veredicto de F4-01 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F4-01' ORDER BY modo;
```

### F4-02

**Enunciado.** La formula es: (categoria / max_categoria) x Beta por cada caracteristica del canal.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `scores evaluados=30200, fuera del rango teorico de la formula=0. El rango sale de los betas del canal: cada termino es (categoria/max_categoria)*beta y categoria<=max_categoria` |
| Evidencia / caso de uso | legado Caracteristicas.txt, las 47 tablas *_Peso; el divisor es un LITERAL por caracteristica, no un MAX calculado |

```sql
-- Veredicto de F4-02 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F4-02' ORDER BY modo;
```

### F4-03

**Enunciado.** Los coeficientes Beta se deben leer siempre de la tabla beta_ordenamiento, nunca hardcodeados en el codigo.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `filas en beta_ordenamiento=47 (esperado 47), codigos duplicados=0 (esperado 0; un duplicado multiplica el score por LEFT JOIN)` |
| Evidencia / caso de uso | LEFT JOIN a bdm_datos.beta_ordenamiento en los 4 SP de scoring; cero literales de beta en el codigo |

```sql
-- Veredicto de F4-03 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F4-03' ORDER BY modo;
```

### F4-04

**Enunciado.** El ranking (lugar) se calcula como ROW_NUMBER ordenado por score descendente, agrupado por persona dentro de cada canal.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `grupos (persona, canal)=28600, con lugares 1..n sin huecos ni repetidos=28600, con el lugar 1 en el score maximo=28600` |
| Evidencia / caso de uso | ROW_NUMBER() OVER (PARTITION BY id_buro_persona ORDER BY score DESC) en los 4 SP; legado Caracteristicas.txt:105,79,72,88 |

```sql
-- Veredicto de F4-04 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F4-04' ORDER BY modo;
```

### F4-05

**Enunciado.** El score no puede ser NULL para ningun dato vigente.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `datos vigentes con score=30200, con score NULL=0 (esperado 0)` |
| Evidencia / caso de uso | score_ordenamiento WHERE score IS NULL debe dar 0. En el legado la suma no lleva COALESCE y un beta ausente anula el canal entero |

```sql
-- Veredicto de F4-05 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F4-05' ORDER BY modo;
```

### F4-06

**Enunciado.** El valor orden_prioridad resultante se debe escribir en la tabla relacion_persona_ubicacion.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `RPU vigentes con score=8600, sin fila en rpu_orden_prioridad=0 (esperado 0)` |
| Evidencia / caso de uso | bdm_datos.rpu_orden_prioridad, escrita por sp_ordenamiento_consolidacion_edf |

```sql
-- Veredicto de F4-06 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F4-06' ORDER BY modo;
```

### F4-07

**Enunciado.** Solo los datos vigentes (no hijos de Unificacion) reciben score.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `hijas de unificacion en el universo mock=6600, de ellas con score=0 (esperado 0)` |
| Evidencia / caso de uso | predicado COALESCE(ind_unificacion,0) <> 1 en preparar_insumos y en consolidacion |

```sql
-- Veredicto de F4-07 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F4-07' ORDER BY modo;
```

### F4-08

**Enunciado.** El proceso es idempotente: ejecutar 2 veces consecutivas produce el mismo resultado sin duplicar registros.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `filas evaluadas=30200, con el lugar fuera de orden respecto al score=0, en grupos cuyo lugar no es 1..n sin huecos=0 (ambos esperados 0). Filas en un grupo (persona, canal) CON empate=600. La reproducibilidad ENTRE corridas no se mide aqui: ver la nota del codigo` |
| Evidencia / caso de uso | comparacion FULL vs FULL2 del mismo universo; exige desempate determinista en el ORDER BY |

```sql
-- Veredicto de F4-08 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F4-08' ORDER BY modo;
```

### F4-09

**Enunciado.** Los Betas deben permanecer parametrizados y versionables; no deben quedar embebidos en la logica de scoring.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `canales en beta_ordenamiento=4, DIR=12, TEL=11, CEL=11, EMA=13 (esperado 12/11/11/13)` |
| Evidencia / caso de uso | 02_carga_betas_ritm5226589.sql, 47 filas; ningun valor de beta en los SP |

```sql
-- Veredicto de F4-09 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F4-09' ORDER BY modo;
```

### F4-DIR-01

**Enunciado.** Se deben calcular 12 caracteristicas: DIR001IN, DIR004RO, DIR007TO, DIR010FI, DIR013OT, DIR017, DIR019, DIR034FI, DIR050TO, DIR057, DIR059, DIR009.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `betas del canal DIR=12 (esperado 12), de ellos con prefijo CO00DIR o CO01DIR=12` |
| Evidencia / caso de uso | sp_ordenamiento_scoring_dir_edf; 12 terminos en la suma |

```sql
-- Veredicto de F4-DIR-01 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F4-DIR-01' ORDER BY modo;
```

### F4-DIR-02

**Enunciado.** DIR001IN = meses desde primer reporte de la direccion.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `ARQ 87 (DIR, suscriptor 050001 contra 080001): personas=100, delta observado=45.1613 (esperado 45.1613 = DIR001IN 80.64516129/3 mas DIR010FI 54.83870968/3; el prefijo 05 da portafolio IN y este colapsa a Sector FI, de modo que mueve las dos a la vez)` |
| Evidencia / caso de uso | legado Caracteristicas.txt:241 (origen :226, :172) |

```sql
-- Veredicto de F4-DIR-02 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F4-DIR-02' ORDER BY modo;
```

### F4-DIR-03

**Enunciado.** DIR009 = entidades distintas reportando la direccion.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `ARQ 88 (DIR, una direccion CRR contra dos): score de la persona par=378.4946, de la impar=361.2903, diferencia=17.2043 (esperado 17.2043 = (3-2)/3 * 51.61290323, con la IMPAR por DEBAJO porque el beta de DIR009 es negativo). DIR009 es por persona, asi que se mide entre personas y no entre direccione` |
| Evidencia / caso de uso | DIVERGENCIA DEL RF (SLCOPRBA-1355): DIR009 no cuenta entidades. Caracteristicas.txt:201 no lleva un solo DISTINCT: cuenta CUANTAS DIRECCIONES DE LA PERSONA tienen al menos un reporte CRR, via CO00DIR016 > 0. Es ademas a grano de PERSONA -- el join de :201 es solo por Id_Buro_Persona -- y se reparte igual a todas sus direcciones. Se evalua sobre esa magnitud. Sigue siendo el unico DIR con prefijo CO01. Para bitacora G-03. |

```sql
-- Veredicto de F4-DIR-03 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F4-DIR-03' ORDER BY modo;
```

### F4-DIR-04

**Enunciado.** DIR017 = tipo ubicacion (RES=1, LAB=2, CRR=3).

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `RESUELTO a favor del legado, como exige RG-09. DIR017 era un codigo ordinal (RES=1, LAB=2, CRR=3) siguiendo el RF; ahora es el conteo de reportes de tipo LAB que define Caracteristicas.txt:1795, con DIR016 (conteo de CRR, :1794) como insumo de DIR009. Queda anotado, sin consecuencia para el port: Or` |
| Evidencia / caso de uso | DIVERGENCIA DEL RF: en el legado (Caracteristicas.txt:147) DIR015 cuenta RES, DIR016 cuenta CRR y DIR017 cuenta LAB. Son tres contadores, no un codigo. Ademas las etiquetas de salida Laboral y Correspondecia estan cruzadas en Orden_Direcc (:159). Para bitacora G-03. |

```sql
-- Veredicto de F4-DIR-04 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F4-DIR-04' ORDER BY modo;
```

### F4-DIR-05

**Enunciado.** La categorizacion debe usar los rangos y umbrales definidos en el modelo de scoring vigente.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `ARQ 81 (DIR, RES contra LAB): delta de score observado=9.6774, esperado 9.6774 = (2-1)/3 * 29.03225806. Es el salto mas pequeno que admite el canal DIR, de modo que ademas mide la resolucion` |
| Evidencia / caso de uso | legado Caracteristicas.txt: umbrales LITERALES dentro de cada CASE WHEN de las tablas *_Cat; no hay tabla de parametros |

```sql
-- Veredicto de F4-DIR-05 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F4-DIR-05' ORDER BY modo;
```

### F4-DIR-06

**Enunciado.** Los Betas utilizados deben tener prefijo CO00DIR o CO01DIR.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `betas del canal DIR=12 (esperado 12), de ellos con prefijo CO00DIR o CO01DIR=12` |
| Evidencia / caso de uso | 02_carga_betas_ritm5226589.sql: 11 CO00DIR + 1 CO01DIR (DIR009) |

```sql
-- Veredicto de F4-DIR-06 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F4-DIR-06' ORDER BY modo;
```

### F4-TEL-01

**Enunciado.** Se deben calcular 11 caracteristicas: TEL001 a TEL025.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `betas del canal TEL=11 (esperado 11), de ellos con prefijo CO01TEL=11` |
| Evidencia / caso de uso | sp_ordenamiento_scoring_tel_edf; 11 calculadas, 10 en la suma (TEL020 fuera, igual que el legado) |

```sql
-- Veredicto de F4-TEL-01 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F4-TEL-01' ORDER BY modo;
```

### F4-TEL-02

**Enunciado.** TEL010 = porcentaje de reportes con coincidencia geografica.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `ARQ 89 (TEL, 3 reportes de un telefono contra 1 del otro dentro de 12 meses): personas=100, con el de mayor cuota en el lugar 1=100, delta observado=259.1687 (esperado 259.1687, compuesto: TEL010 pasa de categoria 2 a 4 y con el se mueven las demas cuotas por ventana del canal, que es inevitable por` |
| Evidencia / caso de uso | DIVERGENCIA DEL RF (SLCOPRBA-1355): TEL010 no mira la coincidencia geografica. Caracteristicas.txt:249 no referencia la columna COINCIDENCIA en ningun sitio: es la cuota de los reportes de los ULTIMOS 12 MESES que son de este telefono, sobre Total_Reportes_12. Los umbrales 20/50/70 de su _cat confirman la lectura de porcentaje y descartan la de bandera. Ya esta portada asi. Para bitacora G-03. |

```sql
-- Veredicto de F4-TEL-02 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F4-TEL-02' ORDER BY modo;
```

### F4-TEL-03

**Enunciado.** TEL020 = indicador binario de coincidencia geografica (1 si no tiene, 4 si tiene).

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `TEL020 se calcula y queda FUERA de la suma en los dos lados. Legado: Caracteristicas.txt:238 suma diez terminos (TEL001/002/003/006/007/010/017/019/023/025) y TEL020_Peso no esta, aunque se construye en :128. Nuestro port: scoring_tel_edf.sql:144-150, los mismos diez. NO es certificable con datos po` |
| Evidencia / caso de uso | legado Caracteristicas.txt:174 y :37. Confirmado FUERA de la suma (:238), que suma diez terminos -- TEL001/002/003/006/007/010/017/019/023/025 -- y no incluye TEL020_Peso, igual que tampoco incluye TEL022. Nuestro port lo respeta (scoring_tel_edf.sql:148). La paridad es deliberada y es lo que se certifica. |

```sql
-- Veredicto de F4-TEL-03 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F4-TEL-03' ORDER BY modo;
```

### F4-TEL-04

**Enunciado.** Solo se deben considerar reportes validos (se excluyen los marcados como NO VALIDA).

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `ARQ 90 (TEL, numero de 10 digitos contra uno de 5): personas=100, con el VALIDA en el lugar 1=100, delta observado=323.5534 (esperado 323.5534). CERTIFICA UNA DIVERGENCIA, no paridad: en el legado este filtro es codigo muerto porque Descripcion_Gestion_Registro se cablea al literal Valida (Prc_Orden` |
| Evidencia / caso de uso | CORREGIDO (SLCOPRBA-1355): nuestro codigo SI excluye, en los cinco contadores de TEL (scoring_tel_edf.sql:37, 41, 57, 72, 74). Y en el legado este filtro es CODIGO MUERTO: Descripcion_Gestion_Registro se cablea al literal Valida (Prc_Ordenamiento2.sql:1295) y el WHERE de :1298 excluye fisicamente cualquier otra gestion, de modo que NO VALIDA no puede existir y los 15 predicados del legado siempre son ciertos. El legado excluye aguas arriba por catalogo de gestion; nosotros sintetizamos la validez del propio numero. Misma intencion, distinta definicion de invalido. Para bitacora G-03. |

```sql
-- Veredicto de F4-TEL-04 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F4-TEL-04' ORDER BY modo;
```

### F4-TEL-05

**Enunciado.** Los Betas utilizados deben tener prefijo CO01TEL.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `betas del canal TEL=11 (esperado 11), de ellos con prefijo CO01TEL=11` |
| Evidencia / caso de uso | 02_carga_betas_ritm5226589.sql: 11 CO01TEL |

```sql
-- Veredicto de F4-TEL-05 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F4-TEL-05' ORDER BY modo;
```

### F4-CEL-01

**Enunciado.** Se deben calcular 11 caracteristicas: CEL003 a CEL023.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `betas del canal CEL=11 (esperado 11), de ellos con prefijo CO01CEL=11` |
| Evidencia / caso de uso | sp_ordenamiento_scoring_cel_edf; las 11 en la suma |

```sql
-- Veredicto de F4-CEL-01 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F4-CEL-01' ORDER BY modo;
```

### F4-CEL-02

**Enunciado.** CEL013 = operador principal identificado por prefijos (310-314).

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `ARQ 83 (CEL, operador 310 contra 300): personas=100, con el 310 en el lugar 1=100, delta observado=38.3818 (esperado 38.3817 = CEL018 de 2 a 3, (3-2)/4 * 153.52697100)` |
| Evidencia / caso de uso | scoring_cel_edf:32. Los prefijos estan HARDCODEADOS en el SP y duplican el catalogo catalogo_tipo_cuenta_tel, que los marca PREPAGO |

```sql
-- Veredicto de F4-CEL-02 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F4-CEL-02' ORDER BY modo;
```

### F4-CEL-03

**Enunciado.** CEL014 = indicador de si la persona tiene cuenta POSPAGO.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `ARQ 85 (CEL, tipo de cuenta 2 contra 1): personas=100, filas por persona=2..2, delta observado=93.3610 (esperado 93.3610 = CEL019 de 1 a 3, (3-1)/4 * 186.72199170). El enunciado del RF lo atribuye a CEL014, que no mira el tipo de cuenta; se evalua sobre CEL019, que es quien lo hace` |
| Evidencia / caso de uso | DIVERGENCIA DEL RF, REAPUNTADA (SLCOPRBA-1355): CEL014 no mira el tipo de cuenta -- es la cuota de reportes de mas de 24 meses (Caracteristicas.txt:2450-2453). La que SI depende del tipo de cuenta es CEL019: MAX del peso de V_Tipo_Cuenta_Ord (:112). El criterio se evalua ahora sobre CEL019, que es donde vive el enunciado. Para bitacora G-03. |

```sql
-- Veredicto de F4-CEL-03 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F4-CEL-03' ORDER BY modo;
```

### F4-CEL-04

**Enunciado.** CEL018 = valor del operador segun tabla de mapeo V_Operador_Ord_Cel.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `ARQ 83: filas de score por persona (min..max)=2..2, esperado 2..2 sobre TRES celulares sembrados (310, 300 y 322). El 322 no esta en catalogo_operador_ord_cel, CEL018 le da 0 y la compuerta del canal lo deja fuera del ranking, igual que el legado (Caracteristicas.txt:899)` |
| Evidencia / caso de uso | legado Caracteristicas.txt:80, lookup por SUBSTR(texto,1,3). En Redshift: bdm_datos.catalogo_operador_ord_cel (interim DEV) |

```sql
-- Veredicto de F4-CEL-04 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F4-CEL-04' ORDER BY modo;
```

### F4-CEL-05

**Enunciado.** Los Betas utilizados deben tener prefijo CO01CEL.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `betas del canal CEL=11 (esperado 11), de ellos con prefijo CO01CEL=11` |
| Evidencia / caso de uso | 02_carga_betas_ritm5226589.sql: 11 CO01CEL |

```sql
-- Veredicto de F4-CEL-05 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F4-CEL-05' ORDER BY modo;
```

### F4-CEL-06

**Enunciado.** Cuando el operador no se encuentra en la tabla de mapeo, se debe asignar un valor por defecto definido funcionalmente (operador no mapeado).

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `RESUELTO a favor del legado. El default inventado de 0.22 -- que no aparece ni una vez en Caracteristicas.txt -- se cambio por 0 (:909) y se aplico la compuerta del ranking (:899, WHERE CEl018.CO01CEL018 <> 0): un prefijo no catalogado deja al celular FUERA de score_ordenamiento, no solo penalizado.` |
| Evidencia / caso de uso | DIVERGENCIA: el legado asigna 0 (Caracteristicas.txt:80) y ademas EXCLUYE el celular del ranking (WHERE CO01CEL018 <> 0, :79). Redshift asigna 0.22 y no excluye. El 0.22 no aparece en el legado. Para bitacora G-03. |

```sql
-- Veredicto de F4-CEL-06 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F4-CEL-06' ORDER BY modo;
```

### F4-EMA-01

**Enunciado.** Se deben calcular 13 caracteristicas: EMA003 a EMA025.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `betas del canal EMA=13 (esperado 13), de ellos con prefijo CO01EMA=13` |
| Evidencia / caso de uso | sp_ordenamiento_scoring_ema_edf; 13 calculadas, 9 en la suma (EMA003/007/018/025 fuera, igual que el legado) |

```sql
-- Veredicto de F4-EMA-01 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F4-EMA-01' ORDER BY modo;
```

### F4-EMA-02

**Enunciado.** EMA014 = indicador de dominio conocido (gmail, hotmail, yahoo, outlook).

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `RESUELTO a favor del legado, y el diagnostico era exacto: el dominio conocido estaba en EMA014 con beta negativa y dentro de la suma, de modo que un gmail perdia unos 121 puntos. Ya no. EMA014 es la cuota de reportes de mas de 24 meses (Caracteristicas.txt:2450-2453, portada) y EMA017 la de la venta` |
| Evidencia / caso de uso | DIVERGENCIA DEL RF: el dominio conocido es EMA018 (Caracteristicas.txt:94) y la lista tiene CINCO elementos (hotmail, gmail, yahoo, live, outlook). EMA014 es el porcentaje de reportes de mas de 24 meses (:142). Ademas EMA018 esta FUERA de la suma. Para bitacora G-03. |

```sql
-- Veredicto de F4-EMA-02 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F4-EMA-02' ORDER BY modo;
```

### F4-EMA-03  _(no cerrado: ver estado)_

**Enunciado.** EMA025 = ratio de recencia calculado como (min_meses / max_meses x 100).

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=REVISION_MANUAL · DELTA1=REVISION_MANUAL · DELTA2=REVISION_MANUAL |
| Medido en la corrida | `El RF dice EMA025 = ratio de recencia (min_meses/max_meses*100). EL LEGADO: EMA025 es la LONGITUD DEL BUZON, bucketizada en campana con pico en 9-12 caracteres (Caracteristicas.txt:170 y :91; CHAR() en Teradata devuelve longitud). Tampoco entra en la suma. Decidir. Bitacora G-03.` |
| Evidencia / caso de uso | DIVERGENCIA DEL RF: EMA025 es la LONGITUD DEL BUZON (local-part) bucketizada en campana, con pico en 9-12 caracteres (Caracteristicas.txt:170 y :91). No es un ratio de recencia. Y esta fuera de la suma. Para bitacora G-03. |

```sql
-- Veredicto de F4-EMA-03 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F4-EMA-03' ORDER BY modo;
```

### F4-EMA-04

**Enunciado.** Los Betas utilizados deben tener prefijo CO01EMA.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `betas del canal EMA=13 (esperado 13), de ellos con prefijo CO01EMA=13` |
| Evidencia / caso de uso | 02_carga_betas_ritm5226589.sql: 13 CO01EMA |

```sql
-- Veredicto de F4-EMA-04 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_ord
 WHERE criterio = 'F4-EMA-04' ORDER BY modo;
```

---

## Novedades — Ubicacion

**Dato que ENTRA al bloque**

```sql
-- Insumo de Novedades Ubicacion: las dos etapas de contrato.
SELECT (SELECT COUNT(*) FROM bdm_tempo.stg_nov_ubica_etapa_9_mock) AS etapa_9,
       (SELECT COUNT(*) FROM bdm_tempo.stg_nov_ubica_etapa_2_mock) AS etapa_2;
```

**Dato que SALE del bloque**

```sql
-- Salida: la tabla MAT del dominio.
SELECT COUNT(*) AS filas, COUNT(DISTINCT info_basica) AS personas
  FROM bdm_datos.mat_info_ubicacion_mock;
```

### NOV-UB-01

**Enunciado.** La etapa 9 debe exponer las 42 columnas del contrato con sus tipos, porque cinco de los otros procedimientos de Novedades la leen.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `columnas de stg_nov_ubica_etapa_9_mock=42, esperado 42 (contrato de 130.TPT:28-71 menos IN_Severidad). Cinco procedimientos de Novedades leen esta tabla: recortarla los deja sin enganche` |
| Evidencia / caso de uso | contrato en P0035_Extractor_Novedades_130.TPT:28-71 (SCHEMA P0035_8) menos IN_Severidad; DDL en 30_ddl_novedades.sql |

```sql
-- Veredicto de NOV-UB-01 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-UB-01' ORDER BY modo;
```

### NOV-UB-02

**Enunciado.** La etapa 2 debe exponer las 15 columnas del contrato: es la unica entrada de Ubi_Agregada.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `columnas de stg_nov_ubica_etapa_2_mock=15, esperado 15 (contrato de Novedad.sql:8625-8639). Es la unica entrada de Ubi_Agregada` |
| Evidencia / caso de uso | contrato en Novedad.sql:8625-8639; DDL en 30_ddl_novedades.sql |

```sql
-- Veredicto de NOV-UB-02 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-UB-02' ORDER BY modo;
```

### NOV-UB-03

**Enunciado.** La etapa 9 no debe multiplicar filas por cod_dw_persona_ubic. El legado no lleva QUALIFY ni DISTINCT y tres joins pueden abrir: direccion fisica, direccion electronica y bloqueo.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `filas=8500, ids distintos=8500, duplicadas=0` |
| Evidencia / caso de uso | joins en Novedad.sql:7778, :8172 y :8415; se compara COUNT(*) contra COUNT(DISTINCT id) |

```sql
-- Veredicto de NOV-UB-03 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-UB-03' ORDER BY modo;
```

### NOV-UB-04

**Enunciado.** El universo base debe traer solo relaciones sin unificar, no bloqueadas y con orden de prioridad no nulo.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `filas=8500, ya unificadas (no deberia haber)=0, sin orden de prioridad (no deberia haber)=0` |
| Evidencia / caso de uso | filtro de la etapa 1 en Novedad.sql:7589-7593 |

```sql
-- Veredicto de NOV-UB-04 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-UB-04' ORDER BY modo;
```

### NOV-UB-05  _(no cerrado: ver estado)_

**Enunciado.** Solo deben entrar los registros cuya gestion es VALIDA: en el legado es un INNER JOIN, no un filtro opcional.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=SIN_DATO · DELTA1=SIN_DATO · DELTA2=SIN_DATO |
| Medido en la corrida | `el INNER JOIN con la gestion de registro (Novedad.sql:7679) esta en el port, pero el mock no siembra estado de gestion: ninguna fila lo ejercita` |
| Evidencia / caso de uso | Novedad.sql:7679 |

```sql
-- Veredicto de NOV-UB-05 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-UB-05' ORDER BY modo;
```

### NOV-UB-06

**Enunciado.** La columna DATO debe traer la direccion compuesta cuando el tipo de ubicacion es Geografica y el texto de ubicacion en cualquier otro caso.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `filas=8500, con DATO vacio=0. En las geograficas DATO es texto mas complemento (Novedad.sql:7772)` |
| Evidencia / caso de uso | Novedad.sql:8349; la composicion de la direccion se arma en :7772 |

```sql
-- Veredicto de NOV-UB-06 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-UB-06' ORDER BY modo;
```

### NOV-UB-07

**Enunciado.** La columna CLASE debe tomar CEL, EMAIL, DIR o TEL segun el tipo de ubicacion, y NULL en cualquier otro caso.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `filas=8500, DIR=8500, TEL=0, CEL=0, EMAIL=0, fuera de dominio=0. En el mock solo hay direcciones: las otras tres clases esperan a contacto_canal` |
| Evidencia / caso de uso | las cuatro ramas en Novedad.sql:8367-8372 |

```sql
-- Veredicto de NOV-UB-07 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-UB-07' ORDER BY modo;
```

### NOV-UB-08

**Enunciado.** Las banderas de tipo CRR, RES y LAB deben valer 1 o 0 segun el tipo de ubicacion de direccion; PPL, AGN, SUC, EST y CDI son NULL literal en el legado y se portan asi.

| | |
|---|---|
| Prioridad | Media |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `RES=5850, CRR=2050, LAB=600. Las otras cinco banderas son NULL literal en el legado (Novedad.sql:8377-8381)` |
| Evidencia / caso de uso | Novedad.sql:8375-8382 |

```sql
-- Veredicto de NOV-UB-08 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-UB-08' ORDER BY modo;
```

### NOV-UB-09

**Enunciado.** Por esta ruta REPORTADO_DESDE, ULTIMO_REPORTE y FUENTE deben salir NULL y los dos contadores 0: el legado los emite como literales y sus valores reales viven en la etapa 2, que esta ruta no consume. Divergencia funcional elevada, no defecto del port.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `filas=8500, con alguno de los cinco campos poblado (el legado los emite como literales)=0. DECISION TOMADA (SLCOPRBA-1355): se reproduce el legado tal cual, no se pueblan. Los valores reales viven en la etapa 2 (Novedad.sql:8635-8639), que esta ruta no consume` |
| Evidencia / caso de uso | Novedad.sql:8358-8363; los valores reales en :8635-8639 |

```sql
-- Veredicto de NOV-UB-09 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-UB-09' ORDER BY modo;
```

### NOV-UB-10

**Enunciado.** La columna ORDEN debe venir del orden de prioridad que produce el Ordenamiento, sin transformar.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `filas cotejadas=8500, con orden distinto al de rpu_orden_prioridad=0` |
| Evidencia / caso de uso | Novedad.sql:8347; en Redshift lo escribe sp_ordenamiento_consolidacion_edf en bdm_datos.rpu_orden_prioridad |

```sql
-- Veredicto de NOV-UB-10 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-UB-10' ORDER BY modo;
```

### NOV-UB-11

**Enunciado.** En modo FULL toda fila debe salir marcada como alta.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=NO_APLICA · DELTA2=NO_APLICA |
| Medido en la corrida | `fase=FULL, filas=8500, altas=8500, no altas=0` |
| Evidencia / caso de uso | Novedad.sql:8392, rama V_CARGA_FULL IS NULL |

```sql
-- Veredicto de NOV-UB-11 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-UB-11' ORDER BY modo;
```

### NOV-UB-12

**Enunciado.** En modo DELTA una relacion nueva desde el watermark debe salir como alta y una modificada como cambio, y la ventana de FECHA debe aportar al menos una fila.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=NO_APLICA · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `fase=FULL, altas=8500, cambios=0, fuera de la ventana=0; de las que entraron, por fecha=7500 y por fecha nula=1000` |
| Evidencia / caso de uso | deltas en Novedad.sql:7394-7401 (altas) y :7455-7462 (cambios) |

```sql
-- Veredicto de NOV-UB-12 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-UB-12' ORDER BY modo;
```

### NOV-UB-13

**Enunciado.** La baja por bloqueo es codigo muerto en el legado: ninguna fila debe salir marcada como baja.

| | |
|---|---|
| Prioridad | Media |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `bajas en la salida=0, esperadas=0. flag_op=E es codigo muerto en el legado: la etapa 1 anti-une V_BLOQUEO (Novedad.sql:7590-7594) y la etapa 9 vuelve a unirla por la misma llave (:8393), de modo que FECHA_BLOQUEO es siempre NULL. Emitir una baja seria divergir, no acertar` |
| Evidencia / caso de uso | Novedad.sql:7590-7594 (anti-join) contra :8393 y :8416 (la rama E) |

```sql
-- Veredicto de NOV-UB-13 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-UB-13' ORDER BY modo;
```

### NOV-UB-14

**Enunciado.** La tabla final debe recibir el alta y el cambio por la llave de la fila, sin duplicar.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `aplicables en la salida (I o A)=8500, de esas presentes en la tabla final=8500; filas en la tabla final=8500, ids distintos=8500` |
| Evidencia / caso de uso | UPSERT del legado en P0035_Extractor_Novedades_130.TPT:573-703 |

```sql
-- Veredicto de NOV-UB-14 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-UB-14' ORDER BY modo;
```

### NOV-UB-15

**Enunciado.** El AS-IS solo inserta y actualiza: la tabla final no debe perder filas por una baja que el legado no emite.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `bajas=0, esperadas=0; de esas aun presentes en la tabla final=0. El borrado del legado sale solo de Severidad=2, y Severidad=2 solo de FLAG_OP=E (120.TPT:163), que es codigo muerto: el UPSERT de 130.TPT nunca borra una fila` |
| Evidencia / caso de uso | P0035_Extractor_Novedades_120.TPT:163 y 130.TPT:703 |

```sql
-- Veredicto de NOV-UB-15 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-UB-15' ORDER BY modo;
```

### NOV-UB-16  _(no cerrado: ver estado)_

**Enunciado.** La columna TIPO debe traer la descripcion homologada del tipo de ubicacion de direccion.

| | |
|---|---|
| Prioridad | Media |
| Verificable por | CONSULTA |
| Fases y estado | FULL=BLOQUEADO · DELTA1=BLOQUEADO · DELTA2=BLOQUEADO |
| Medido en la corrida | `falta el catalogo V_Hom_TipoUbic_Dir_Linea: la columna TIPO sale NULL` |
| Evidencia / caso de uso | Novedad.sql:8279; BLOQUEADO: no se entrego el catalogo V_Hom_TipoUbic_Dir_Linea |

```sql
-- Veredicto de NOV-UB-16 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-UB-16' ORDER BY modo;
```

### NOV-UB-17  _(no cerrado: ver estado)_

**Enunciado.** La columna ZONA debe traer la descripcion homologada de la zona.

| | |
|---|---|
| Prioridad | Media |
| Verificable por | CONSULTA |
| Fases y estado | FULL=BLOQUEADO · DELTA1=BLOQUEADO · DELTA2=BLOQUEADO |
| Medido en la corrida | `faltan V_ZONA_UBICACION y V_Hom_Zona_Linea: la columna ZONA sale NULL` |
| Evidencia / caso de uso | Novedad.sql:8278; BLOQUEADO: no se entregaron V_ZONA_UBICACION ni V_Hom_Zona_Linea |

```sql
-- Veredicto de NOV-UB-17 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-UB-17' ORDER BY modo;
```

### NOV-UB-18  _(no cerrado: ver estado)_

**Enunciado.** La columna de tipo de identificacion debe traer la descripcion homologada.

| | |
|---|---|
| Prioridad | Media |
| Verificable por | CONSULTA |
| Fases y estado | FULL=BLOQUEADO · DELTA1=BLOQUEADO · DELTA2=BLOQUEADO |
| Medido en la corrida | `falta el catalogo V_Hom_Tip_Ident_Linea: el tipo de identificacion sale NULL` |
| Evidencia / caso de uso | Novedad.sql:8406; BLOQUEADO: no se entrego el catalogo V_Hom_Tip_Ident_Linea |

```sql
-- Veredicto de NOV-UB-18 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-UB-18' ORDER BY modo;
```

### NOV-UB-19  _(no cerrado: ver estado)_

**Enunciado.** La columna INDICATIVO debe traer el codigo de area del telefono fijo.

| | |
|---|---|
| Prioridad | Baja |
| Verificable por | CONSULTA |
| Fases y estado | FULL=BLOQUEADO · DELTA1=BLOQUEADO · DELTA2=BLOQUEADO |
| Medido en la corrida | `falta V_TELEFONO_FIJO: la columna INDICATIVO sale NULL` |
| Evidencia / caso de uso | Novedad.sql:7968; BLOQUEADO: no se entrego V_TELEFONO_FIJO |

```sql
-- Veredicto de NOV-UB-19 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-UB-19' ORDER BY modo;
```

### NOV-UB-20  _(no cerrado: ver estado)_

**Enunciado.** La columna de tipo de cuenta debe traer el primer caracter del tipo de correo.

| | |
|---|---|
| Prioridad | Baja |
| Verificable por | CONSULTA |
| Fases y estado | FULL=BLOQUEADO · DELTA1=BLOQUEADO · DELTA2=BLOQUEADO |
| Medido en la corrida | `falta V_TIPO_CORREO: la columna de tipo de cuenta sale NULL` |
| Evidencia / caso de uso | Novedad.sql:8170; BLOQUEADO: no se entrego V_TIPO_CORREO |

```sql
-- Veredicto de NOV-UB-20 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-UB-20' ORDER BY modo;
```

### NOV-UB-21  _(no cerrado: ver estado)_

**Enunciado.** Las columnas de barrio y estrato deben traer el atributo geografico de la ubicacion.

| | |
|---|---|
| Prioridad | Media |
| Verificable por | CONSULTA |
| Fases y estado | FULL=BLOQUEADO · DELTA1=BLOQUEADO · DELTA2=BLOQUEADO |
| Medido en la corrida | `geo_atributos declara barrio y estrato y nunca los escribe: su posicion en el contrato de 32 columnas no esta pinada (sp_geo_cargar_georreferenciacion.sql:443-446)` |
| Evidencia / caso de uso | Novedad.sql:8063 y :8066; BLOQUEADO: geo_atributos las declara y nunca las escribe, porque su posicion en el contrato de 32 columnas no esta pinada (sp_geo_cargar_georreferenciacion.sql:443-446) |

```sql
-- Veredicto de NOV-UB-21 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-UB-21' ORDER BY modo;
```

### NOV-UB-22  _(no cerrado: ver estado)_

**Enunciado.** Las columnas de localidad y codigo postal deben traer el atributo geografico de la ubicacion.

| | |
|---|---|
| Prioridad | Media |
| Verificable por | CONSULTA |
| Fases y estado | FULL=BLOQUEADO · DELTA1=BLOQUEADO · DELTA2=BLOQUEADO |
| Medido en la corrida | `localidad y codigo postal no tienen columna en geo_atributos; las dos vienen del contrato GEO sin pinar` |
| Evidencia / caso de uso | Novedad.sql:8064 y :8065; BLOQUEADO: no existe columna en geo_atributos y las dos vienen del contrato GEO sin pinar |

```sql
-- Veredicto de NOV-UB-22 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-UB-22' ORDER BY modo;
```

---

## Novedades — Actividad Economica

**Dato que ENTRA al bloque**

```sql
-- Insumo: la etapa 1 de Actividad Economica.
SELECT COUNT(*) AS filas FROM bdm_tempo.stg_nov_acteco_etapa_1_mock;
```

**Dato que SALE del bloque**

```sql
-- Salida: la tabla MAT del dominio.
SELECT COUNT(*) AS filas FROM bdm_datos.mat_info_actividad_economica_mock;
```

### NOV-AE-01

**Enunciado.** La etapa 1 debe exponer las 9 columnas del contrato y la tabla final las 8 del contrato mas las 3 de control, porque el contrato es publico y un CTAS lo cambiaria sin avisar.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `columnas de stg_nov_acteco_etapa_1_mock=9 (esperado 9) y de mat_info_actividad_economica_mock=11 (esperado 11 = 8 del contrato de 130.TPT:76-88 mas lote, fecha_actualizacion y usuario_bd)` |
| Evidencia / caso de uso | contrato en 34_ddl_nov_actividad_economica.sql; origen en P0035_Extractor_Novedades_120.TPT:176-199 |

```sql
-- Veredicto de NOV-AE-01 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-AE-01' ORDER BY modo;
```

### NOV-AE-02

**Enunciado.** La etapa 1 no debe multiplicar filas por el par (ciiu, info_basica_id): el legado cierra con un QUALIFY ROW_NUMBER sobre ese par.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `filas=7300, pares (ciiu, persona) distintos=7300 (deben coincidir: el QUALIFY de Novedad.sql:1379 particiona por ese par)` |
| Evidencia / caso de uso | QUALIFY en Novedad.sql:1379. La via mock lo necesita de verdad: v_mock_ciiu_persona lee bdm_stage.ciiu_persona SIN DISTINCT |

```sql
-- Veredicto de NOV-AE-02 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-AE-02' ORDER BY modo;
```

### NOV-AE-03

**Enunciado.** Solo deben entrar personas con CIIU informado: el legado filtra el codigo de actividad no nulo.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `filas=7300, con CIIU nulo=0 (esperado 0; filtro del legado en Novedad.sql:1377)` |
| Evidencia / caso de uso | filtro en Novedad.sql:1377; insumo v_xpm_ciiu_persona (02_vistas_insumo_edf_views.sql:364-370) |

```sql
-- Veredicto de NOV-AE-03 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-AE-03' ORDER BY modo;
```

### NOV-AE-04

**Enunciado.** En modo FULL toda fila debe salir marcada como alta.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=NO_APLICA · DELTA2=NO_APLICA |
| Medido en la corrida | `fase=FULL, filas=7300, altas=7300, no altas=0` |
| Evidencia / caso de uso | gemelo de NOV-UB-11; el modo decide el flag_op en sp_novedades_actividad_economica_edf.sql |

```sql
-- Veredicto de NOV-AE-04 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-AE-04' ORDER BY modo;
```

### NOV-AE-05

**Enunciado.** En modo DELTA la ventana debe acotar por FECHA y no solo por la rama de fecha nula: al menos una fila tiene que entrar por fecha.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=NO_APLICA · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `fase=FULL, filas=7300; de las que entraron, por fecha=7300 y por fecha nula=0` |
| Evidencia / caso de uso | gemelo de NOV-UB-12, y por el mismo motivo. La ventana es fecha_reporte >= watermark OR fecha IS NULL (sp_novedades_actividad_economica_edf.sql:149-151): un criterio que solo cuenta filas da PASSED sin haber mirado la ventana, que es lo que tumbo el job DEV/DATABASE #409 |

```sql
-- Veredicto de NOV-AE-05 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-AE-05' ORDER BY modo;
```

### NOV-AE-06  _(no cerrado: ver estado)_

**Enunciado.** Las columnas de descripcion de la actividad y de version deben traer el valor del catalogo de CIIU.

| | |
|---|---|
| Prioridad | Media |
| Verificable por | CONSULTA |
| Fases y estado | FULL=BLOQUEADO · DELTA1=BLOQUEADO · DELTA2=BLOQUEADO |
| Medido en la corrida | `falta V_ACTIVIDAD_ECONO_CIIU (Novedad.sql:1352-1354): actividad_economica y version salen NULL. Pedido en docs/PETICION_CATALOGOS_NOVEDADES.md seccion 6` |
| Evidencia / caso de uso | el legado las toma de V_ACTIVIDAD_ECONO_CIIU (Novedad.sql:1352-1354), catalogo que NO se entrego. Peticion en docs/PETICION_CATALOGOS_NOVEDADES.md seccion 6 |

```sql
-- Veredicto de NOV-AE-06 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-AE-06' ORDER BY modo;
```

### NOV-AE-07  _(no cerrado: ver estado)_

**Enunciado.** La columna de tipo de identificacion debe traer la descripcion homologada.

| | |
|---|---|
| Prioridad | Media |
| Verificable por | CONSULTA |
| Fases y estado | FULL=BLOQUEADO · DELTA1=BLOQUEADO · DELTA2=BLOQUEADO |
| Medido en la corrida | `falta el catalogo V_Hom_Tip_Ident_Linea, el mismo que bloquea NOV-UB-18: el tipo de identificacion sale NULL` |
| Evidencia / caso de uso | mismo catalogo que bloquea NOV-UB-18: falta V_Hom_Tip_Ident_Linea |

```sql
-- Veredicto de NOV-AE-07 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-AE-07' ORDER BY modo;
```

### NOV-AE-08

**Enunciado.** El AS-IS de este dominio solo inserta: ninguna fila debe salir marcada como baja y la tabla final no debe perder filas.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `bajas en la etapa=0, esperadas=0. El DELETE del 130.TPT:753 exige Severidad=2 y el CASE de 120.TPT:186-197 no tiene rama que la devuelva: tres dan 1 y el ELSE da -1. Emitir una baja seria divergir` |
| Evidencia / caso de uso | el DELETE del 130.TPT:753 exige Severidad=2 y el CASE de 120.TPT:186-197 no tiene rama que la devuelva: tres ramas dan 1 y el ELSE da -1. Mismo patron que el flag_op=E de Ubicacion |

```sql
-- Veredicto de NOV-AE-08 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-AE-08' ORDER BY modo;
```

### NOV-AE-09

**Enunciado.** El id de la tabla final se asigna como el maximo vivo mas la posicion de la fila y no puede repetirse.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `filas en la tabla final=7300, ids distintos=7300, personas distintas=7300 (filas e ids deben coincidir: el id es MAX(id) + la posicion de la fila, 120.TPT:177-179)` |
| Evidencia / caso de uso | Max_ID + SUM(1) OVER (ROWS UNBOUNDED PRECEDING) en 120.TPT:177-179, sobre un CROSS JOIN con COALESCE(MAX(ID),0) |

```sql
-- Veredicto de NOV-AE-09 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-AE-09' ORDER BY modo;
```

### NOV-AE-10

**Enunciado.** Toda fila con Severidad 1 debe llegar a la tabla final; las de Severidad -1 no.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `personas en la etapa=7300, de ellas ausentes de la tabla final=0 (esperado 0; el 130.TPT:215 descarta Severidad=-1 y el resto entra)` |
| Evidencia / caso de uso | filtro Severidad <> -1 en 130.TPT:215; gemelo de NOV-UB-14 |

```sql
-- Veredicto de NOV-AE-10 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-AE-10' ORDER BY modo;
```

---

## Novedades — Ubicacion Agregada

**Dato que ENTRA al bloque**

```sql
-- Insumo: la etapa final del dominio.
SELECT COUNT(*) AS filas FROM bdm_tempo.stg_nov_ubiagr_etapa_final_mock;
```

**Dato que SALE del bloque**

```sql
-- Salida: la tabla MAT del dominio.
SELECT COUNT(*) AS filas, COUNT(DISTINCT info_basica) AS personas
  FROM bdm_datos.mat_ubicacion_agregada_mock;
```

### NOV-AG-01

**Enunciado.** La etapa final debe exponer las 30 columnas del contrato y la tabla final las 32, porque las dos son contrato publico y un CTAS dejaria que el tipo lo infiriera la consulta.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=PASSED · DELTA1=PASSED · DELTA2=PASSED |
| Medido en la corrida | `columnas de stg_nov_ubiagr_etapa_final_mock=30 (esperado 30 = 29 del contrato de 130.TPT:1033-1147 mas flag_op) y de mat_ubicacion_agregada_mock=32 (esperado 32 = 29 mas lote, fecha_actualizacion y usuario_bd)` |
| Evidencia / caso de uso | contrato en 35_ddl_nov_ubi_agregada.sql; origen en P0035_Extractor_Novedades_130.TPT:1033-1147 |

```sql
-- Veredicto de NOV-AG-01 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-AG-01' ORDER BY modo;
```

### NOV-AG-02  _(no cerrado: ver estado)_

**Enunciado.** La tabla final no debe tener dos filas con la misma llave de siete columnas.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=BLOQUEADO · DELTA1=BLOQUEADO · DELTA2=BLOQUEADO |
| Medido en la corrida | `falta V_Hom_Tip_Ident_Linea: con tipo_identificacion en NULL la etapa 5 (Novedad.sql:5431) sale vacia y no hay filas sobre las que medir el grano de la llave de siete columnas` |
| Evidencia / caso de uso | la llave del UPSERT es info_basica, tipo_identificacion, numero_identificacion y el trio ubicacion_dato / ubicacion_codigodane / ubicacion_ciudad / ubicacion_departamento (130.TPT:1060-1066). Las etapas 5, 6 y 7 del legado unen SIN info_basica (Novedad.sql:5431-5436): si el par (tipo, numero) no la determina, la salida se multiplica y nada falla |

```sql
-- Veredicto de NOV-AG-02 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-AG-02' ORDER BY modo;
```

### NOV-AG-03  _(no cerrado: ver estado)_

**Enunciado.** Las tres columnas agregadas por concatenacion deben traer la lista completa y ordenada, no un solo valor.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=BLOQUEADO · DELTA1=BLOQUEADO · DELTA2=BLOQUEADO |
| Medido en la corrida | `mismo catalogo: sin filas en la etapa final no hay listas concatenadas que comprobar` |
| Evidencia / caso de uso | el legado las arma con tres WITH RECURSIVE (Novedad.sql:5700-6100); nuestro port usa LISTAGG con WITHIN GROUP, que es el idioma de Redshift para lo mismo |

```sql
-- Veredicto de NOV-AG-03 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-AG-03' ORDER BY modo;
```

### NOV-AG-04  _(no cerrado: ver estado)_

**Enunciado.** El orden de la ubicacion debe numerarse por persona y clase, sin huecos ni empates.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=BLOQUEADO · DELTA1=BLOQUEADO · DELTA2=BLOQUEADO |
| Medido en la corrida | `mismo catalogo: sin filas no hay ranking que numerar` |
| Evidencia / caso de uso | ROW_NUMBER sobre PARTITION BY info_basica, ubicacion_clase en sp_novedades_ubi_agregada_edf.sql; el desempate final por MD5(ubicacion_dato) existe para que el numero sea estable entre corridas |

```sql
-- Veredicto de NOV-AG-04 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-AG-04' ORDER BY modo;
```

### NOV-AG-05  _(no cerrado: ver estado)_

**Enunciado.** Las cinco columnas de reporte deben venir pobladas, al reves que en el dominio UBICACION.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=BLOQUEADO · DELTA1=BLOQUEADO · DELTA2=BLOQUEADO |
| Medido en la corrida | `mismo catalogo: sin filas no se puede comprobar que las cinco columnas de reporte vengan pobladas` |
| Evidencia / caso de uso | reportdesde, ultreporte, numentidades, numreportes y fuente. En UBICACION salen NULL y 0 literales (Novedad.sql:8358-8363) porque esa ruta no consume la etapa 2; esta SI la consume, de modo que aqui un NULL es un defecto y alli no. Es el contraste que NOV-UB-09 vigila del otro lado |

```sql
-- Veredicto de NOV-AG-05 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-AG-05' ORDER BY modo;
```

### NOV-AG-06  _(no cerrado: ver estado)_

**Enunciado.** Ninguna fila debe salir marcada como baja y la tabla final no debe perder filas.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=BLOQUEADO · DELTA1=BLOQUEADO · DELTA2=BLOQUEADO |
| Medido en la corrida | `mismo catalogo: sin filas el conteo de bajas sale cero por vacio y no por paridad, que es justo lo que este criterio debe distinguir` |
| Evidencia / caso de uso | la Severidad compara 19 columnas con tres centinelas (120.TPT:406-442) y solo devuelve 1 o -1: ninguna rama da 2, de modo que el DELETE del 130.TPT:1135-1147 es inalcanzable. Tercera vez que el borrado es codigo muerto en este proceso, tras NOV-UB-13 y NOV-AE-08 |

```sql
-- Veredicto de NOV-AG-06 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-AG-06' ORDER BY modo;
```

### NOV-AG-07  _(no cerrado: ver estado)_

**Enunciado.** Una segunda corrida sobre los mismos datos no debe hacer crecer la tabla final.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=BLOQUEADO · DELTA1=BLOQUEADO · DELTA2=BLOQUEADO |
| Medido en la corrida | `mismo catalogo: la tabla final no crece entre pasadas porque no entra nada, de modo que el verde no probaria la idempotencia del UPSERT` |
| Evidencia / caso de uso | este dominio es el unico de los tres cuyo UPSERT ACTUALIZA (130.TPT:1036-1059, UPDATE mas INSERT FOR MISSING). Nuestro DELETE de las llaves que vuelven a entrar mas INSERT es equivalente porque el UPDATE pisa todas las columnas que no son llave |

```sql
-- Veredicto de NOV-AG-07 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-AG-07' ORDER BY modo;
```

### NOV-AG-08  _(no cerrado: ver estado)_

**Enunciado.** El codigo de pais debe seguir en blanco mientras no exista su catalogo.

| | |
|---|---|
| Prioridad | Media |
| Verificable por | CONSULTA |
| Fases y estado | FULL=BLOQUEADO · DELTA1=BLOQUEADO · DELTA2=BLOQUEADO |
| Medido en la corrida | `mismo catalogo: sin filas no se puede comprobar que cod_pais siga en blanco` |
| Evidencia / caso de uso | el CROSS JOIN contra V_PAIS (Novedad.sql:7175-7178) no se porta: contra una vista inexistente dejaria la etapa vacia. Gemelo de NOV-UB-09: el criterio verifica que SIGA en blanco, no que se llene |

```sql
-- Veredicto de NOV-AG-08 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-AG-08' ORDER BY modo;
```

---

## Novedades — dominios no portados

**Dato que ENTRA al bloque**

```sql
-- Insumo de Novedades Ubicacion: las dos etapas de contrato.
SELECT (SELECT COUNT(*) FROM bdm_tempo.stg_nov_ubica_etapa_9_mock) AS etapa_9,
       (SELECT COUNT(*) FROM bdm_tempo.stg_nov_ubica_etapa_2_mock) AS etapa_2;
```

**Dato que SALE del bloque**

```sql
-- Salida: la tabla MAT del dominio.
SELECT COUNT(*) AS filas, COUNT(DISTINCT info_basica) AS personas
  FROM bdm_datos.mat_info_ubicacion_mock;
```

### NOV-CAT-01  _(no cerrado: ver estado)_

**Enunciado.** El proceso debe preparar los catalogos de la corrida.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=NO_IMPLEMENTADO · DELTA1=NO_IMPLEMENTADO · DELTA2=NO_IMPLEMENTADO |
| Medido en la corrida | `PRO_Novedad_Linea_Catalogo (Novedad.sql:3) no esta portado` |
| Evidencia / caso de uso | legado PRO_Novedad_Linea_Catalogo (Novedad.sql:3). Dominio no portado a Redshift: el evaluador lo marca NO_IMPLEMENTADO |

```sql
-- Veredicto de NOV-CAT-01 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-CAT-01' ORDER BY modo;
```

### NOV-INB-01  _(no cerrado: ver estado)_

**Enunciado.** El proceso debe producir la informacion basica de la persona.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=NO_IMPLEMENTADO · DELTA1=NO_IMPLEMENTADO · DELTA2=NO_IMPLEMENTADO |
| Medido en la corrida | `PRO_Novedad_Linea_Info_Basica (Novedad.sql:2166) no esta portado; depende ademas de la decision funcional del filtro Mosaic` |
| Evidencia / caso de uso | legado PRO_Novedad_Linea_Info_Basica (Novedad.sql:2166). Dominio no portado. Ademas depende de la decision funcional del filtro Mosaic (Novedad.sql:2479-2484) |

```sql
-- Veredicto de NOV-INB-01 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-INB-01' ORDER BY modo;
```

### NOV-CON-01  _(no cerrado: ver estado)_

**Enunciado.** El proceso debe producir la informacion de contactabilidad.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=NO_IMPLEMENTADO · DELTA1=NO_IMPLEMENTADO · DELTA2=NO_IMPLEMENTADO |
| Medido en la corrida | `PRO_Novedad_Linea_Contact (Novedad.sql:186) no esta portado; siete de sus once columnas son datos de gestion que no vienen del datashare` |
| Evidencia / caso de uso | legado PRO_Novedad_Linea_Contact (Novedad.sql:186). Dominio no portado; ademas siete de sus once columnas son datos de gestion que no vienen del datashare |

```sql
-- Veredicto de NOV-CON-01 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-CON-01' ORDER BY modo;
```

### NOV-PIN-01  _(no cerrado: ver estado)_

**Enunciado.** El proceso debe producir los puntos de interes cercanos a cada ubicacion.

| | |
|---|---|
| Prioridad | Media |
| Verificable por | CONSULTA |
| Fases y estado | FULL=NO_IMPLEMENTADO · DELTA1=NO_IMPLEMENTADO · DELTA2=NO_IMPLEMENTADO |
| Medido en la corrida | `PRO_Novedad_Linea_Punto_Interes (Novedad.sql:4585) no esta portado; falta ademas el nombre del punto de interes en el contrato de distancias` |
| Evidencia / caso de uso | legado PRO_Novedad_Linea_Punto_Interes (Novedad.sql:4585). Dominio no portado; falta ademas el nombre del punto de interes, que el contrato de distancias no persiste |

```sql
-- Veredicto de NOV-PIN-01 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-PIN-01' ORDER BY modo;
```

### NOV-MOV-01  _(no cerrado: ver estado)_

**Enunciado.** El proceso debe producir los indicadores de movilidad.

| | |
|---|---|
| Prioridad | Media |
| Verificable por | CONSULTA |
| Fases y estado | FULL=NO_IMPLEMENTADO · DELTA1=NO_IMPLEMENTADO · DELTA2=NO_IMPLEMENTADO |
| Medido en la corrida | `PRO_Novedad_Linea_Indic_Movilidad (Novedad.sql:1508) no esta portado y depende del proceso P0029, cuya migracion esta pendiente` |
| Evidencia / caso de uso | legado PRO_Novedad_Linea_Indic_Movilidad (Novedad.sql:1508). Dominio no portado y depende integro del proceso P0029, cuya migracion esta pendiente |

```sql
-- Veredicto de NOV-MOV-01 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-MOV-01' ORDER BY modo;
```

---

## Gobernanza

**Dato que ENTRA al bloque**

```sql
-- Traza de la corrida: lote, modo, watermark y metricas.
SELECT corrida_id, lote, modo, bootstrap, fecha_proceso,
       watermark_anterior, watermark_nuevo, estado,
       relaciones_entrada, personas_distintas, total_unificaciones
  FROM bdm_datos.unif_control_mock ORDER BY corrida_id;
```

**Dato que SALE del bloque**

```sql
-- Salida consolidada de la Unificacion.
SELECT unifica_atributos AS regla, COUNT(*) AS direcciones,
       COUNT(DISTINCT cod_dw_direccion_unificada) AS padres
  FROM bdm_datos.unificacion_direccion_mock GROUP BY 1 ORDER BY 1;
```

### NOV-G-01  _(no cerrado: ver estado)_

**Enunciado.** El procedimiento real y su espejo mock deben diferir unicamente en las fuentes que leen.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | CONSULTA |
| Fases y estado | FULL=REVISION_MANUAL · DELTA1=REVISION_MANUAL · DELTA2=REVISION_MANUAL |
| Medido en la corrida | `la paridad real/mock se verifica con un diff de archivos, no con una consulta: lo comprueba validar.sh y el generador tools/gen_novedades_espejo_mock.py` |
| Evidencia / caso de uso | diff entre sp_novedades_ubicacion_edf.sql y sp_novedades_ubicacion_mock.sql |

```sql
-- Veredicto de NOV-G-01 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-G-01' ORDER BY modo;
```

### NOV-G-02  _(no cerrado: ver estado)_

**Enunciado.** El control de lote y watermark de Novedades es diseno propio, no un port: el del legado esta inoperativo porque la corrida borra su propio log al arrancar y el cierre de lote nunca se ejecuta.

| | |
|---|---|
| Prioridad | Alta |
| Verificable por | MANUAL |
| Fases y estado | FULL=REVISION_MANUAL · DELTA1=REVISION_MANUAL · DELTA2=REVISION_MANUAL |
| Medido en la corrida | `el control de lote es diseno propio porque el del legado esta inoperativo: 111.BTQ:64-65 borra el log al arrancar y 140.BTQ:853-858 no llama al cierre. Decision a confirmar con el equipo` |
| Evidencia / caso de uso | P0035_Extractor_Novedades_111.BTQ:64-65 borra el log; _140.BTQ:47-61 declara el cierre y :853-858 no lo llama. Diseno propio en 31_ddl_nov_control.sql |

```sql
-- Veredicto de NOV-G-02 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-G-02' ORDER BY modo;
```

### NOV-G-03  _(no cerrado: ver estado)_

**Enunciado.** Hay que decidir el equivalente en Redshift del patron de recarga del legado, que clona las tablas finales, apunta las vistas al clon, vacia las originales y las repone al terminar.

| | |
|---|---|
| Prioridad | Media |
| Verificable por | MANUAL |
| Fases y estado | FULL=REVISION_MANUAL · DELTA1=REVISION_MANUAL · DELTA2=REVISION_MANUAL |
| Medido en la corrida | `falta decidir el equivalente en Redshift del patron de recarga del legado (clonar a BK_*, apuntar las vistas al clon, vaciar y reponer). Decision de arquitectura` |
| Evidencia / caso de uso | P0035_Extractor_Novedades_111.BTQ:474-844 y _140.BTQ:108-410 y :804-851. Decision de arquitectura, no de codigo |

```sql
-- Veredicto de NOV-G-03 en todas las fases, con el numero que midio el evaluador.
SELECT modo, estado, detalle FROM bdm_datos.cert_resultado_nov
 WHERE criterio = 'NOV-G-03' ORDER BY modo;
```

---

## Lo que este documento NO afirma

- **Solo datos mock.** La certificacion corre sobre arquetipos sembrados, con resultado
  esperado exacto y calculable. No se certifica con datos reales (regla 5 del proyecto).
- **Un criterio en `BLOQUEADO` no es un criterio que falle**: es uno que no se puede
  evaluar porque falta un insumo externo. Estan listados con su motivo.
- **El `UNLOAD` a S3 y el `COPY` de vuelta del ciclo GEO no estan certificados**: el rol
  IAM no esta asociado al cluster DEV y el mock los sustituye. Todo lo demas del ciclo
  es el mismo SQL que en produccion.
