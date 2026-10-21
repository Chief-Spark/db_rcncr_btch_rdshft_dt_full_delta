# Reconocer: la meta y todo lo que falta

Actualizado: 2026-10-21. **Este archivo es la única lista de pendientes.** Se tacha lo que se cierra; lo que no está aquí, no está pendiente.

---

## La meta (usuario, 2026-10-21)

> **Que Reconocer corra en Redshift en cualquier ambiente con datos reales, y que entregue las 7 tablas dominio, que son las que explota el producto Batch.**

Dos consecuencias que reordenan todo el trabajo:

1. **No hace falta producción.** DEV o QA con datos reales cuentan.
2. **La medida de avance son las 7 tablas dominio pobladas con datos reales.** No el tablero mock, no la paridad contra Teradata, no los nombres de los SP.
3. **La bitácora es parte de la entrega.** El resultado no será idéntico al de Teradata y no se pretende que lo sea: cada diferencia que aparezca con datos reales se decide y se escribe en `BITACORA_DIFERENCIAS.md` con su cita. **Hoy van 29 diferencias: 15 ABIERTA, 13 DECIDIDA, 1 CERRADA.** Las 15 abiertas son el verdadero backlog de decisiones, y cerrarlas es tan entregable como poblar una tabla.

### Lo que esto saca del camino crítico

| | Por qué se baja de prioridad |
|---|---|
| **Paridad contra Teradata** (muestra del mismo corte, RF G-05) | **no va a ser idéntico, va a ser similar** (usuario, 2026-10-21). Las diferencias se deciden y se documentan según aparezcan; la muestra sigue pedida pero **no es condición de entrega ni bloquea** |
| **Renombrado `sp_rcn_*`** | cosmético: no acerca ni una tabla dominio. Queda en 11 de 45 y **se para ahí** |
| **El Ordenamiento dentro del gate** | no entrega ninguna tabla |
| **El tablero mock en verde** | es la red de seguridad, no la meta. Ya está en 174 / 63 / 217 |

---

## 0. El camino crítico: las 7 tablas dominio

- [x] ~~`mat_info_ubicacion` (d1)~~ — portada **en mock**
- [x] ~~`mat_info_actividad_economica` (d2)~~ — portada **en mock**
- [x] ~~`mat_ubicacion_agregada` (d3)~~ — portada **en mock**
- [ ] **`mat_info_basica` (d4)** — la única de las cuatro que falta y podemos hacer. Género, estado del documento y tipo de identificación decididos (D-EDF-13, D-EDF-14); espera **C37**
- [ ] `mat_info_punto_interes` (d7) — falta el nombre del punto de interés, que el contrato de distancias no persiste
- [ ] `mat_info_contactabilidad` (d5) — **no existe en `edf_views`**, verificado. Petición a Experian
- [ ] `mat_info_movilidad` (d6) — depende íntegro del proceso **P0029**, sin migrar. No es nuestro

**Techo sin terceros: 4 de 7.**

### Y el agujero que esto destapa

- [ ] **NADIE HA CORRIDO NUNCA LA VÍA REAL DE NOVEDADES.** El runner de la cadena real (`run_reconocer_e2e_unificacion_ordenamiento.sql:17-20`) llama a Unificación y Ordenamiento **y para ahí**. No hay ningún `run_*` que invoque `sp_novedades_ciclo_edf`. Las tres tablas dominio que damos por portadas **solo se han visto en mock**: no sabemos si contra el datashare producen una sola fila
- [x] ~~**Runner de la cadena real completa**~~ — `run_reconocer_e2e_real_full.sql`, en el orden del Framework: `unificación → ordenamiento → novedades`, lote 1356301, con la medición de las 7 tablas y la traza por dominio
- [ ] **Y la medida que de verdad importa**: `COUNT(*)` de las tres MAT después de correrla en DEV. Hoy no existe ese número

**Esto es lo primero. Todo lo demás de esta lista es secundario frente a saber si la cadena real produce filas.**

---

## 1. Decisiones tuyas

- [x] ~~**D1 · Los SP viejos del renombrado**~~ — **al final** (usuario, 2026-10-21). El renombrado se queda en 11 de 45 y se retoma cuando las tablas dominio estén
- [x] ~~**D2 · Entrega al Batch**~~ — **el contrato es el que define el legado** (usuario, 2026-10-21). No hay que negociarlo: son los `SCHEMA` de los `130.TPT` por tabla, que ya tenemos. Lo que queda es verificar columna por columna que nuestras MAT los cumplen

## 2. Lo que corres tú

- [ ] **C37** — los 8 catálogos de Collibra por `code` completo. Desbloquea `mat_info_basica` y 9 criterios
- [ ] **Correr la cadena real en DEV** cuando esté el runner, y pasarme los conteos
- [ ] Mensaje a Experian (sección 4) · traslado a Bitbucket y job de Jenkins

## 3. Vía real: código que sí acerca la meta

- [x] ~~T5 · fuente de Novedades desde `typeOfData`~~
- [x] ~~F2 real con la llave completa~~
- [x] ~~Ranking por canal (D-ORD-10)~~
- [x] ~~Compuerta DIR053 (T4)~~
- [x] ~~Universo de Actividad Económica (D-NOV-06)~~
- [x] ~~Llave de Severidad de ACTECO (3 columnas)~~
- [x] ~~Observabilidad: DDL, `version_betas`, `corrida_id`, `etapa` a 64 (T3)~~
- [ ] **Runner de la cadena real completa** (sección 0)
- [ ] **`mat_info_basica` (d4)**, tras C37
- [ ] Arquetipos que faltan: dirección **sin DANE** (certifica DIR053) y **varias actividades** (certifica D-NOV-06)
- [ ] Observabilidad de verdad: filas reales por etapa (hoy 0), tiempo real, concurrencia. **T3 fue solo el DDL**
- [ ] Verificar contra el legado, sin código: desempate del `QUALIFY` de ACTECO (`Novedad.sql:1380`), tipo de `fecha_reporte`, y si `xpm_chamberofcommerce` es el `V_Persona_Juridica_Camara` del legado

## 4. Mensaje único a Experian

- [ ] **`bestAccounts` está vacío**: 146 de 98.586 personas (0,15 %) tienen cuenta (D-EDF-15)
- [ ] **Contactabilidad** (`V_CONTACTABILIDAD`, `VstgUbiContactabilidad`): bloquea la tabla dominio d5
- [ ] **Movilidad y puntos de interés**: el proceso P0029 y el nombre del punto de interés. Bloquean d6 y d7
- [ ] Tres columnas de la Fase 2 sin fuente confirmada: `cod_tipo_obligacion_fte`, `numero_dias_mora` y el tipo `'A'`/`'P'`
- [ ] Severidad 2 de cuenta · `businessIdStatus` = `00` · score de suscriptor · `contactType` 12 · lo que C37 no cierre

## 5. Criterios sin verde (red de seguridad, no camino crítico)

- [ ] Ordenamiento, 5 bloqueados: `F1-08` y `CA-M01` **desbloqueables ya** (el `Lote` de `Estandarizacion.sql:6718`); `F3-09`; `F3-10` puede estar **mal buscado**, no bloqueado; `RG-04`
- [ ] Novedades, 16 bloqueados: `NOV-AG-02..08` y `NOV-AE-07` esperan C37; `NOV-AE-06` idem; `NOV-UB-16..22` catálogos de Línea
- [ ] Novedades, 5 sin implementar: son los 5 dominios de la sección 0
- [ ] El Ordenamiento fuera del gate

## 6. Otros equipos

- [ ] **DBA / DevSecOps** — rol IAM `rcncr-batch-redshift-geo` en DEV. Sin él, `UNLOAD` y `COPY` de GEO no se certifican
- [ ] **DevSecOps** — `[REDSHIFT:419]`, escalado
- [ ] **Framework** — `PP9999999.yml` llama a un SP que no existe y con `()`. Hay que reescribirlo con las tres entradas en cadena
- [ ] **Equipo de Teradata** — muestra del mismo corte. **Ya no es condición de entrega**, pero sigue siendo lo único que probaría paridad

---

## Cómo trabajamos

1. **Una tanda a la vez**: qué mueve · tu OK si hay DDL · código · banco (dos pasadas) · commit · tachar aquí.
2. **Lo que una corrida escribe, el reset lo borra** (job #412).
3. **Un fallo del banco es una hipótesis** hasta trazarlo al legado o a la documentación de Redshift.
4. **Cada respuesta termina igual**: hecho, en curso, y qué necesito de ti.
