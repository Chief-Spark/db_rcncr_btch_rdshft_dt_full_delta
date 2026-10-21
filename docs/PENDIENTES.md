# Reconocer: la meta y todo lo que falta

Actualizado: 2026-10-21. **Este archivo sustituye al tablero anterior y es la única lista de pendientes.** Se tacha lo que se cierra; lo que no está aquí, no está pendiente.

---

## La meta

**No estaba escrita en ninguna parte, y esa es la razón de que el trabajo se sintiera por pedazos.** Queda escrita aquí, y lo demás se ordena contra ella:

> **Que Reconocer corra en Redshift en producción, que el Batch entregue sus cubos, y que exista evidencia de que produce lo mismo que Teradata.**

Se da por terminado cuando se cumplen las cuatro, y no antes:

| | Criterio de salida | Hoy |
|---|---|---|
| **M1** | Las cuatro cadenas —Unificación, GEO, Ordenamiento y Novedades— corren de punta a punta invocadas por el Framework Batch | parcial |
| **M2** | El tablero de certificación en verde **y el Ordenamiento dentro del gate** | parcial: verde, pero el Ordenamiento no tumba el build |
| **M3** | **Paridad medida contra una muestra real de Teradata** (RF G-05) | **no empezado, y no depende de nosotros** |
| **M4** | Entrega al Batch cerrada (`BATCH2_HOMOLOGACION`) y desplegado en QA y producción | no empezado |

**M3 es el que de verdad decide.** Todo lo que certificamos hoy dice *"reproduce lo que leímos del legado"*, nunca *"da lo mismo que producción"*. Sin esa muestra, el proyecto no se puede cerrar formalmente por mucho código que se escriba.

---

## 1. Decisiones tuyas (bloquean trabajo)

- [ ] **D1 · Los SP viejos del renombrado.** Quedan huérfanos en DEV y QA y no hay forma limpia de borrarlos: Redshift no admite `DROP PROCEDURE IF EXISTS` (lecciones #10 y #12) y un `DROP` condicional exige SQL dinámico, prohibido por el RF (RG-07). Si se quedan, el comparador de esquema del pipeline da `[REDSHIFT:335]`, el mismo del job QA/DATABASE #122. **O se asume un script manual de limpieza antes del despliegue, o el renombrado se queda a medias.** Bloquea 34 de los 45 renombres
- [ ] **D2 · Entrega al Batch.** Decidir el contrato de `BATCH2_HOMOLOGACION`. Bloquea M4

## 2. Lo que corres tú (no tengo conexión a Redshift)

- [ ] **C37** — leer por `code` completo los 8 catálogos de Collibra que encontró C35. Desbloquea la fuente de Novedades, Info Básica y 7 criterios `NOV-AG`
- [ ] **C36 / C38.3** — ya corrida: el contenedor `bestaccounts` es 1:1 con la persona
- [ ] **Mensaje único a Experian** (sección 6)
- [ ] **Traslado a Bitbucket y job de Jenkins** de todo lo de hoy

## 3. Novedades: 3 de las 7 tablas de salida

Las siete salen del `DELETE ... ALL` de `P0035_Extractor_Novedades_111.BTQ:817-836`.

- [x] ~~`mat_info_ubicacion` (d1)~~
- [x] ~~`mat_info_actividad_economica` (d2)~~
- [x] ~~`mat_ubicacion_agregada` (d3)~~
- [ ] **`mat_info_basica` (d4)** — la única de las cuatro que podemos hacer ya. Género, estado del documento y tipo de identificación están decididos (D-EDF-13, D-EDF-14); espera **C37**
- [ ] `mat_info_punto_interes` (d7) — falta el nombre del punto de interés, que el contrato de distancias no persiste
- [ ] `mat_info_contactabilidad` (d5) — **no existe en `edf_views`**, verificado. Petición a Experian
- [ ] `mat_info_movilidad` (d6) — depende íntegro del proceso **P0029**, sin migrar. No es nuestro

**Techo realista sin terceros: 4 de 7.**

## 4. Criterios que no están en verde

**Ordenamiento — 5 bloqueados:**

- [ ] `F1-08` y `CA-M01` — **desbloqueables ya**: `Estandarizacion.sql:6718` y `P0001_..._111.BTQ:177` prueban que **`Lote` existe** en la salida de estandarización. Era el motivo por el que estaban bloqueados
- [ ] `F3-09` (cuentas ICBDIR) y `F3-10` (ubicaciones NO VALIDA) — `F3-10` puede no estar bloqueado sino **mal buscado**: se buscó en el legado de F1-F3 y la regla vive en P0001
- [ ] `RG-04` — el contrato de cuenta no trae razón ni fecha de bloqueo (`V_Razon_Bloqueo`)

**Novedades — 16 bloqueados y 5 sin implementar:**

- [ ] `NOV-AG-02..08` (7) y `NOV-AE-07` — **`V_Hom_Tip_Ident_Linea`**. Candidato encontrado por C35: `177_EXPERIAN_NOVEDAT_ID_TYPE_HO`. Espera **C37**
- [ ] `NOV-AE-06` — `V_ACTIVIDAD_ECONO_CIIU`. Candidatos: catálogos `116` y `117`. Espera **C37**
- [ ] `NOV-UB-16..22` (7) — catálogos de homologación a Línea
- [ ] `NOV-CAT-01`, `NOV-CON-01`, `NOV-INB-01`, `NOV-MOV-01`, `NOV-PIN-01` — los 5 dominios sin portar (sección 3)

**Y el gate:**

- [ ] **El Ordenamiento no está en `sp_cert_asercion_final`.** Un FAILED suyo no tumba el build. Encenderlo pide primero verde en Redshift real, que es la condición que ya cumplió Novedades en el job #409

## 5. Vía real: lo que queda de código

- [x] ~~T5 · fuente de Novedades desde `typeOfData`~~
- [x] ~~F2 real con la llave completa~~
- [x] ~~Ranking por canal (D-ORD-10)~~
- [x] ~~Compuerta DIR053 (T4)~~
- [x] ~~Universo de Actividad Económica (D-NOV-06)~~
- [x] ~~Llave de Severidad de ACTECO (3 columnas)~~
- [x] ~~Observabilidad: DDL, `version_betas`, `corrida_id`, `etapa` a 64 (T3)~~
- [ ] **Arquetipos que faltan**: uno con dirección **sin DANE** (certifica DIR053) y uno con **varias actividades** (certifica D-NOV-06). Las dos ramas están portadas y **el mock no las ejercita**
- [ ] **Observabilidad de verdad**: filas reales por etapa (hoy 0), tiempo real por escenario, rechazo de corridas concurrentes. **T3 fue solo el DDL**
- [ ] **Renombrado `sp_rcn_*`**: 11 de 45. Bloqueado por **D1**. Además, 3 nombres existen por duplicado en `bdm_datos` y `bdm_stage` (los GEO) y esa parte es a mano
- [ ] **Verificar contra el legado**, sin tocar código: el desempate del `QUALIFY` de ACTECO (`Novedad.sql:1380`), el tipo de `fecha_reporte`, y si `xpm_chamberofcommerce` es el `V_Persona_Juridica_Camara` del legado

## 6. Mensaje único a Experian

- [ ] **`bestAccounts` está vacío**: 146 de 98.586 personas (0,15 %) tienen cuenta. Sin eso no se conecta la Fase 2 (D-EDF-15)
- [ ] **`P0001_..._130.TPT` y los SPs de estandarización** — *recibidos el 2026-10-21*
- [ ] **Tres columnas de la Fase 2** sin fuente confirmada: `cod_tipo_obligacion_fte`, `numero_dias_mora` y el tipo `'A'`/`'P'` del comportamiento
- [ ] Severidad 2 de cuenta · `businessIdStatus` = `00` · score de suscriptor · `contactType` 12 · contactabilidad · movilidad y puntos de interés · los catálogos que C37 no cierre

## 7. Otros equipos

- [ ] **DBA / DevSecOps** — asociar el rol IAM `rcncr-batch-redshift-geo` al clúster DEV. Sin él, el `UNLOAD` y el `COPY` de GEO no se certifican nunca
- [ ] **DevSecOps** — el `[REDSHIFT:419]` del pipeline, ya escalado
- [ ] **Equipo de Teradata** — **la muestra del mismo corte para medir paridad. Es M3, y es lo único que cierra el proyecto**
- [ ] **Framework** — el `PP9999999.yml` llama a un SP que no existe y con `()`. Hay que reescribirlo con las tres entradas en cadena

---

## Cómo trabajamos

1. **Una tanda a la vez**, en este orden: qué mueve · tu OK si hay DDL · código · banco (dos pasadas) · commit · tachar aquí.
2. **Lo que una corrida escribe, el reset lo borra** (job #412).
3. **Un fallo del banco es una hipótesis** hasta trazarlo al legado o a la documentación de Redshift.
4. **Cada respuesta termina igual**: hecho, en curso, y qué necesito de ti.
