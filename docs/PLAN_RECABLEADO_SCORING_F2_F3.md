# Plan de recableado: que el scoring lea de F2 y F3, como el legado

**SLCOPRBA-1355.** Sobre datos mock, que es donde estamos.

---

## 0. Dos cosas que dije antes y son FALSAS. Se corrigen aquí primero

| Dije | Dice el código |
|---|---|
| *"`Sector` es portable hoy en seis líneas"* | **Ya está portado.** `sp_ordenamiento_preparar_insumos_edf.sql:377-383` lo calcula con sus valores reales derivándolo de `portafolio_nuevo`, igual que el legado (`PRO_ORD_CTA_TOTALES_PERSONAS_2.sql:391-396`) |
| *"`DIR010FI` y `EMA016` quedan clavadas por `sector_financiero`"* | **El scoring ya usa `sector`, no la bandera.** `sp_ordenamiento_scoring_dir_edf.sql:98-101` compara `sector = 'FI'` y `sector = 'OT'`; EMA, TEL y CEL llevan escrito en sus cabeceras que *"antes miraba `sector_financiero`"*. La bandera 0/1 de cubeta de hash hoy **no la lee nadie**: es peso muerto del insumo |

La fila de `CLAUDE.md` que dice que `sector_financiero` deja a `DIR010FI` y `EMA016`
en la categoría mínima **está envejecida** y entra en este plan como corrección.
Lo que sí sigue bloqueando a `DIR010FI` es otra cosa, y ya estaba escrito: el
divisor del legado excluye `'NO VALIDA'`, que no es portable hoy.

---

## 1. Qué difiere del legado, exactamente

El scoring del legado no lee el datashare: lee las salidas de F2 y F3. La prueba
es la tabla semilla del canal DIR (`Caracteristicas.txt:226`):

```sql
CREATE TABLE REC_STAGE.PASO_INICIAL_DIRC AS (
  SELECT A.Cod_Pin_Persona, A.Id_Buro_Persona, A.Cod_DW_Persona_Ubic,
         A.Cod_DW_Reporte_Persona_Ubic, A.Cod_dw_cta, a.texto_ubicacion, ...
        ,CTP3.Portafolio_Nuevo
    FROM REC_STAGE.V_DIRECCIONES_TEMP_DF  A              -- <- Fase 3
    LEFT JOIN REC_STAGE.CTA_TOTALES_PERSONAS_TMP3 CTP3   -- <- Fase 2
      ON A.Cod_DW_Cta = CTP3.Cod_DW_Cta                  -- <- por CUENTA
    LEFT JOIN REC_STAGE.TM_AGR_DIR_TMP_DEF B
      ON A.Cod_Pin_Persona = B.Cod_Pin_Persona AND A.Id_Buro_Persona = B.Id_Buro_Persona)
```

Los cuatro canales arrancan de la misma base `DIRECCIONES_TEMP`, partida en
cuatro vistas: `_DF` dirección física, `_TF` teléfono fijo, `_TM` móvil, `_ML`
correo. De ahí que `Direccion_Fisica` lleve el teléfono en el canal TEL.

### La tabla de diferencias, separando lo estructural de lo funcional

| Legado | Nuestro | Tipo |
|---|---|---|
| F3 produce `DIRECCIONES_TEMP` + 4 vistas de canal | `preparar_insumos` produce `stg_insumo_{direccion,telefono,celular,email}` | **estructural** |
| F2 produce `CTA_TOTALES_PERSONAS_TMP3` (vector de cuenta con `Portafolio`, `Portafolio_Nuevo`, `Sector`) | nuestro F2 produce **solo** `cuenta_atributo_hash` | **estructural** |
| DIR une dirección ↔ cuenta por `Cod_DW_Cta` | `preparar_insumos` deriva `portafolio_nuevo` del `cod_suscriptor` **del reporte** | **FUNCIONAL** |
| `Portafolio_Nuevo` abre con `WHEN Portafolio = 'CO' THEN 'CO'` (`:377`) | la rama `'CO'` **no se construye** (`preparar_insumos_edf.sql:369`) | **FUNCIONAL** |
| `Sector` abre con `WHEN Portafolio_nuevo = 'CO' THEN 'CO'` | la nuestra no tiene esa rama | **FUNCIONAL**, consecuencia de la anterior |
| `DIRECCIONES_TEMP` lleva `Urbanizacion_Barrio, Latitud, Longitud` del paso geo de F3 | `coincidencia_geo` clavado al literal 0 | **FUNCIONAL**, ya documentado |

### El bloqueante de la parte funcional, y es uno solo

**`cod_dw_cta` no existe en el lado de la dirección.** Ni en real
(`v_xpm_reporte_relacion_persona_ubica`, `02_vistas_insumo_edf_views.sql:316`, no
tiene esa columna) ni en mock (`bdm_stage.reporte_relacion_persona_ubica` tiene
cuatro: `cod_dw_persona_ubic`, `id_buro_suscriptor`, `cod_suscriptor`,
`fecha_reporte`). Hoy sólo aparece en las dos vistas mock que F2 estrenó
(`02b_vistas_insumo_mock.sql:323` y `:342`).

En **mock lo sembramos** y la cadena queda igual que el legado de punta a punta.
En **real es petición de datashare**, y por eso la fase B se diseña para que la
vía real degrade al comportamiento de hoy en vez de romperse.

### Lo que NO desbloquea este recableado

| Qué | Por qué |
|---|---|
| `DIR034FI` (`CO00END005`) y `DIR050TO` (`CO00MOR037/038`) | salen de `REC_STAGE.Insumo_Caracteristica` (`Caracteristicas.txt:219` y `:259`), que **no la crea F1, ni F2, ni F3, ni el orquestador, ni `Caracteristicas.txt`**. F2 sólo aporta el filtro `Sector='FI'`. Es petición, y la fila de `CLAUDE.md` que las atribuye a la Fase 2 se corrige |
| La sobrescritura a `999999` por CONTACTABILIDAD en CEL | necesita `VstgUbiContactabilidad`, que tampoco está |
| El filtro `WHERE CO01TEL022_cat > 0` del ranking de TEL | espera coincidencia geográfica |
| El divisor de `DIR010FI` / `DIR013OT` | excluye `'NO VALIDA'`, no portable hoy |

---

## 2. El orden del recableado

El ciclo **ya corre en el orden correcto** —
`preparar → cuentas → ubicaciones → scoring_* → consolidacion → cleanup`
(`sp_ordenamiento_ejecucion_mock.sql:135-204`) — de modo que no hay que reordenar
nada. Lo que cambia es **quién produce qué**.

### FASE A — estructural. El score NO se mueve, y eso es la prueba

Se hace primero y se mide sola, porque es la única forma de separar "moví el
cableado" de "moví el número".

**A1. F3 pasa a producir el vector de ubicación.**
`sp_ordenamiento_ubicaciones_{edf,mock}` construye `bdm_tempo.stg_ord_ubic_vector`
—el equivalente de `DIRECCIONES_TEMP`— y de ahí las cuatro proyecciones de canal
que hoy son `stg_insumo_{direccion,telefono,celular,email}`. Mismas columnas,
mismo grano, mismo contenido: se **mueve** el `CREATE TABLE`, no se reescribe.
La tabla de hash que F3 ya escribe sigue igual, colgando del vector.

**A2. F2 pasa a publicar el vector de cuenta.**
`sp_ordenamiento_cuentas_{edf,mock}` publica `bdm_tempo.stg_ord_cta_vector`
—el equivalente de `CTA_TOTALES_PERSONAS_TMP3`— con `cod_dw_cta`, `portafolio`,
`portafolio_nuevo`, `sector` y las dos banderas de comportamiento. Hoy esas
columnas ya se calculan dentro de `stg_ord_cta_hash`: se **exponen**, no se
recalculan.

**A3. `preparar_insumos` se queda con lo que es de F1.**
El alcance por lote/watermark, `stg_ord_alcance_origen`, el censo y las tablas
crudas de staging (`stg_rpu_post_unificacion` y las demás). Deja de producir los
cuatro `stg_insumo_*`.

**A4. Los cuatro `sp_ordenamiento_scoring_*_edf` cambian su `FROM`** a las
proyecciones de F3. **Ni una fórmula, ni un umbral, ni un divisor se toca.**
Nota a favor: esos cuatro SP **no tienen espejo mock** —el mock reutiliza los
reales—, así que el cambio se hace una vez y vale para las dos vías.
`preparar_insumos` sí tiene espejo y ahí hay que tocar los dos, con el `diff`
saliendo vacío salvo las fuentes.

**A5. `sector_financiero` sale del insumo.** No lo lee nadie desde que el scoring
pasó a `sector`. Con él se va `bdm_datos.catalogo_sector_financiero`, que es una
cubeta de hash sobre `id_buro_suscriptor >= 901`
(`02_catalogos_ordenamiento.sql:12-17`), y la petición de "catálogo oficial de
sector financiero" deja de tener sentido: el `Sector` real ya está.

### FASE B — funcional. Aquí el score SÍ se mueve, a propósito

**B1. `cod_dw_cta` en el lado de la dirección.** Columna nueva en
`bdm_stage.reporte_relacion_persona_ubica` y en `v_mock_reporte_relacion_persona_ubica`;
en la vista real entra como `NULL` explícito con su comentario de petición, para
que la vía real degrade a lo de hoy en vez de romperse.

**B2. La semilla del canal DIR une por cuenta.** El vector de ubicación pasa a
unirse a `stg_ord_cta_vector` por `cod_dw_cta`, como el legado, en vez de derivar
el portafolio del `cod_suscriptor` del reporte. Con `cod_dw_cta` nulo el `LEFT
JOIN` no trae nada y la rama cae a `'OT'`: por eso B1 va antes y por eso en real
no rompe.

**B3. La rama `'CO'`.** `Portafolio_Nuevo` abre leyendo el `Portafolio` de nueve
valores, que F2 **ya calcula** con sus banderas de comportamiento. Se construye,
y con ella la rama `'CO'` de `Sector`.

**B4. Arquetipo nuevo.** Una persona cuya cuenta clasifica `'CO'` y cuyo prefijo
de `cod_suscriptor` daría otra cosa. Es el único arquetipo que distingue "la rama
`'CO'` existe" de "la rama `'CO'` nunca se toma", y sin él B3 no se puede afirmar
— la lección del `ARQ 96` y la de `NOV-UB-12`.

### FASE C — lo que queda fuera

Las cuatro filas de la tabla "lo que NO desbloquea". Se escriben en
`PETICION_DATASHARE_F1_F3_ORDENAMIENTO.md` y no se abren como trabajo.

---

## 3. La medición

Es la mitad del plan, no un apéndice. Sin la foto previa no se puede afirmar
que la fase A no movió nada.

### El instrumento: foto y diff de `score_ordenamiento`

`score_ordenamiento` **no se trunca nunca** — su única limpieza es
`DELETE ... WHERE id_buro_persona IN (stg_ord_personas_alcance)` —, de modo que
una copia simple basta:

```sql
-- ANTES de tocar nada, con la batería recién corrida
DROP TABLE IF EXISTS bdm_tempo.foto_score_pre;
CREATE TABLE bdm_tempo.foto_score_pre AS SELECT * FROM bdm_datos.score_ordenamiento;

-- DESPUES de la fase A, tras re-correr la batería
SELECT COUNT(*) AS filas_que_cambiaron
  FROM (SELECT * FROM bdm_datos.score_ordenamiento
        EXCEPT SELECT * FROM bdm_tempo.foto_score_pre) d;
```

En el banco se corre a mano; en Redshift real la foto se toma en la primera
pasada de DPLY y el diff en la segunda, que es gratis porque el pipeline ya
corre la batería dos veces.

### Las puertas, fase por fase

| Puerta | Fase A — exigido | Fase B — exigido |
|---|---|---|
| `filas_que_cambiaron` de la foto | **0** | distinto de 0, y **explicado persona a persona** |
| `CA-F03`: 15 arquetipos con su delta | 15/15 en las tres fases | 15/15, con los deltas **re-baseados a propósito** y el nuevo valor escrito en la semilla |
| `grupos_con_empate` por canal | idénticos (CEL 100 / DIR 200 / EMA 0 / TEL 0 con `BANCO_N=100`) | idénticos: `'CO'` no crea ni rompe empates |
| Tablero ORD | 217 PASSED / 0 FAILED / 0 NO_IMPLEMENTADO | igual, y `F2-05` pasa de 10 a **11** valores distintos al aparecer `'CO'` |
| Unificación / Novedades | 174 y 63 | 174 y 63 |
| `cert_criterio_ord` | 90 filas, `MAX(LENGTH(evidencia)) < 700` | igual |
| Paridad real ↔ mock | `diff` de cada `_edf` contra su `_mock`: sólo las fuentes | igual |
| `./validar.sh` en los tres | rc=0 | rc=0 |
| `./banco.sh fase dt` **dos veces** | las dos pasadas idénticas | idénticas |

**La puerta que manda en la fase A es la primera.** Si `filas_que_cambiaron` no
es 0, el recableado cambió algo que no debía y hay que encontrar qué antes de
seguir; ningún otro verde lo sustituye.

### Por qué la fase B necesita su propia linea base

Los arquetipos del Ordenamiento se certifican por la **diferencia de score entre
las dos filas de cada persona**, no por el valor absoluto, y el delta es
`(diferencia de categoría / divisor) * beta`. La rama `'CO'` cambia la categoría
de `DIR010FI` y `DIR013OT` en las personas cuya cuenta clasifica `'CO'`, de modo
que el delta de esos arquetipos se mueve **por diseño**. Hay que recalcularlo a
mano desde la fórmula, escribirlo en `seed_mock_matriz_ord.sql` y que el criterio
lo exija — no al revés, que sería ajustar el criterio al resultado.

---

## 4. Riesgos, y el orden en que se cobran

| Riesgo | Mitigación |
|---|---|
| Mover cuatro `CREATE TABLE` de sitio y cambiar una columna sin darse cuenta | la foto de `score_ordenamiento` con diff en 0; es exactamente para esto |
| Añadir una columna al insumo real y no al espejo | ya se pagó (`column "..." does not exist` en el primer ciclo): el `diff` de los dos `preparar_insumos` tiene que salir vacío |
| `stg_ord_ubic_vector` multiplica filas al unir la cuenta | el mismo fan-out de `v_xpm_contacto_canal` (219.000 filas para 73.000 ids): `cod_dw_cta` tiene que ser único por `cod_dw_persona_ubic` en la semilla, y se verifica con un `COUNT(*)` contra `COUNT(DISTINCT)` antes de unir |
| La vía real se rompe por `cod_dw_cta` ausente | entra como `NULL` explícito y el `LEFT JOIN` degrada a `'OT'`, que es el comportamiento de hoy |
| Un literal nuevo más largo que su columna | `[REDSHIFT:112]` que `CREATE TABLE IF NOT EXISTS` esconde: contar filas del catálogo después de desplegar |

---

## 5. Secuencia de commits

1. **Correcciones de bitácora** (este documento + las tres filas envejecidas de
   `CLAUDE.md`: `sector_financiero`, `DIR034FI`/`DIR050TO`, y la atribución de
   `Insumo_Caracteristica`). Sin código.
2. **Fase A**, en un commit, con el diff en 0 reportado en el mensaje.
3. **Fase B**, en un commit, con los deltas re-baseados y el arquetipo nuevo.
4. **Despliegue** y, al verde, el gate de Ordenamiento.

**Nada de esto se cierra en el banco.** Un verde local degrada un
`[REDSHIFT:112]` de desconocido a específico de Redshift; la prueba que manda es
el job DEV/DATABASE con sus dos pasadas de DPLY.
