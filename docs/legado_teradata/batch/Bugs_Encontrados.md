# Bugs encontrados en el código Teradata original (BATCH2 / P0033)

> **Propósito y alcance.**
> La **fase 1** del proyecto es migrar BATCH2 de Teradata a Redshift obteniendo **exactamente los mismos resultados**, incluso cuando el original produce un resultado incorrecto. Por eso **ninguno de los defectos de este documento está corregido en el código migrado**: todos se replican de forma deliberada y quedan señalados con un comentario en el archivo `.sql` correspondiente.
>
> Este documento es el inventario para una **fase posterior** en la que se evaluará, con el negocio, cuáles corregir y con qué impacto.
>
> No se documentan aquí las *diferencias de sintaxis* Teradata → Redshift (esas están en `Redshift/VERIFICACION.md` y en las cabeceras de cada archivo de procedures). Solo defectos de lógica del original.

**Última actualización:** 2026-10-15
**Fuentes revisadas:** `Sps_Batch.sql` (19 SPs, ~9 540 líneas), los 28 archivos `.BTQ`/`.TPT` de la raíz, `DDL.sql`, `Dlls-Batch/*.csv`, `FuncionesUDF/`, y las muestras reales de `Salidas/`.

---

## Cómo leer este documento

| Campo | Significado |
|---|---|
| **ID** | Identificador estable para referenciarlo en la bitácora y en los comentarios del código |
| **Severidad** | `Alta` = altera cifras o contenido entregado al cliente · `Media` = altera resultados en casos específicos · `Baja` = no altera el resultado (trabajo desperdiciado, log engañoso) |
| **Estado en Redshift** | Siempre *Replicado*, salvo las excepciones marcadas explícitamente |

### Resumen

| ID | Objeto | Síntesis | Severidad |
|---|---|---|---|
| [B-01](#b-01) | `PRO_BATCH2_FILTRO_E` | `CUBO_DIRECCIONES`/`CUBO_CELULARES` no coinciden con el `UPDATE` → esos cubos nunca marcan `FILTRO_E` | Alta |
| [B-02](#b-02) | `PRO_BATCH2_FILTRO_E` | La segunda llamada (`'J'`) borra las marcas que dejó la primera (`'N'`) | Alta |
| [B-03](#b-03) | `PRO_BATCH2_FILTRO_G` | El `UPDATE` de `BACTH_FG_2` se aplica a los 6 cubos en cada iteración | Alta |
| [B-04](#b-04) | `PRO_Batch2_Completitud_Canal` | El bloque de DIRECCIÓN nunca se ejecuta (`WHILE V_ITERA=2` con `V_ITERA=1`) | Alta |
| [B-05](#b-05) | `PRO_BATCH2_ESTADISTICAS` | Producto cartesiano en el conteo `ID_NE` | Alta |
| [B-06](#b-06) | `BATCH_MOTOR_LOG` fila 13 | Sobrescribe el campo `CODIGO SUSCRIPTOR` (ID=6) en vez de escribir el ID=13 | Alta |
| [B-07](#b-07) | `BATCH_MOTOR_LOG` fila 8 | `REGISTROS GRABADOS` siempre vale 0 (compara dos literales distintos) | Alta |
| [B-08](#b-08) | `P0033_BATCH2_CANTREPCANAL_111.BTQ` | Pasa `(PLANTILLA, SOLICITUD)` a una firma `(SOLICITUD, PLANTILLA)` | Alta |
| [B-09](#b-09) | `PRO_BATCH_ADD_PORC_INSUMO` | El BTQ invierte solicitud/plantilla igual que B-08 | Alta |
| [B-10](#b-10) | `PRO_BATCH2_ESTADISTICAS` | `PARTE_12` del archivo de alertas repite `CIUDAD_DIR_TOTAL` en vez de `CIUDAD_TEL_TOTAL` | Alta |
| [B-11](#b-11) | `PRO_BATCH2_FILTRO_F` | No resetea `FILTRO_F`; arrastra marcas de corridas anteriores | Media |
| [B-12](#b-12) | `PRO_BATCH2_FILTRO_F` | Sin fila en `PMD` el registro queda marcado (`FLAG = 1`) | Media |
| [B-13](#b-13) | `PRO_BATCH2_FILTRO_D` | Cubo no mapeado → SQL `NULL`; y truncamiento silencioso a 1 000 caracteres | Media |
| [B-14](#b-14) | `PRO_BATCH2_HOMOLOGACIONES` | `MIN_ID`/`QUALIFY` puede generar SQL inválido con una sola fila | Media |
| [B-15](#b-15) | `PRO_BATCH2_FILTRO_H` | `CASE` sin `ELSE`; el cubo punto de interés no se recalcula | Media |
| [B-16](#b-16) | `PRO_BATCH2_FILTRO_J` | El resultado depende de la *collation* (`'Correo'` vs `'correo'`) | Media |
| [B-17](#b-17) | `PRO_BATCH2_ADICIONAR_INCON` | `CAST` a `BIGINT` sin protección | Media |
| [B-18](#b-18) | `PRO_BATCH_ADD_PORC_INSUMO` | Duplica filas si `BATCH_SALIDAS_CAMPOS` tiene varias por campo | Media |
| [B-19](#b-19) | `PRO_BATCH2_ESTADISTICAS` | Mezcla `P_BDSTAGE` con `REC_STAGE` hardcodeado en el mismo `UNION ALL` | Media |
| [B-20](#b-20) | `DataMasking` (UDF C) | Con 3 caracteres o menos devuelve un buffer sin inicializar | Media |
| [B-21](#b-21) | `DataMasking`/`DirDataMasking`/`RazonDataMasking` | `sprintf(salida, cadena)`: un `%` en el dato corrompe la salida | Media |
| [B-22](#b-22) | `Bach_Similitud_Dir_MZ` | Puede devolver más de 100 o menos de 0 | Media |
| [B-23](#b-23) | `PorcSimilitud` | Declara `VARCHAR(20)`: solo compara los primeros 20 caracteres | Media |
| [B-24](#b-24) | UDF de similitud (C) | Con insumo vacío divide por cero y devuelve `-2147483648` | Media |
| [B-25](#b-25) | `PRO_BATCH2_TRANSPUESTA` | Si una partición tiene una sola fila, el SQL generado queda sin cerrar | Media |
| [B-26](#b-26) | `PRO_BATCH2_ESTADISTICAS` | `BATCH2_ESTADISTICAS_TMP` se borra pero nunca se crea | Baja |
| [B-27](#b-27) | `PRO_BATCH2_TRANSPUESTA` | `BACTH_CAMPOS_2` se crea dos veces con el mismo DDL | Baja |
| [B-28](#b-28) | `PRO_BATCH2_ESTADISTICAS` | Descripciones de paso copiadas/pegadas: el log miente | Baja |
| [B-29](#b-29) | `PRO_BATCH2_FILTRO_A` | Texto de log copiado de otro filtro | Baja |
| [B-30](#b-30) | `PRO_Batch2_Completitud_Canal`, `PRO_BATCH2_TRANSPUESTA` | Referencias a `rec_stage` hardcodeadas, ignorando `P_BDSTAGE` | Baja |
| [B-31](#b-31) | Varios SPs | `PRO_PLAN_EJECUCION`: `DROP TABLE` sin `IF EXISTS` falla en la primera corrida | Baja |

---

## Detalle

### B-01
**Objeto:** `PRO_BATCH2_FILTRO_E` · **Severidad:** Alta · **Estado en Redshift:** Replicado

El SP llena una tabla temporal con los literales `'CUBO_DIRECCIONES'` y `'CUBO_CELULARES'` (en plural), pero el `UPDATE` que marca la columna `FILTRO_E` compara contra `'CUBO_DIRECCION'` y `'CUBO_CELULAR'` (en singular). Como nunca coinciden, **el cubo de direcciones y el de celulares quedan siempre con `FILTRO_E = 0`**, es decir, el filtro E no descarta nada en esos dos canales. Los otros cuatro cubos sí se filtran.

*Impacto:* direcciones y celulares que el filtro E debía descartar llegan al archivo de salida.
*Dónde está replicado:* `Redshift/procedures/08_sp_batch2_procesacubos.sql`, `sp_batch2_filtro_e`.

### B-02
**Objeto:** `PRO_BATCH2_FILTRO_E` · **Severidad:** Alta · **Estado en Redshift:** Replicado

El orquestador llama a `FILTRO_E` dos veces, primero con `p_tipo_persona = 'N'` y luego con `'J'`. El SP **no acota el `UPDATE` al tipo de persona de la llamada**, así que la segunda invocación recalcula sobre todo el universo y **borra las marcas que dejó la primera**. En la práctica solo sobrevive el resultado de la pasada `'J'`.

*Impacto:* el filtro E de personas naturales se pierde.
*Dónde está replicado:* `08_sp_batch2_procesacubos.sql`, `sp_batch2_filtro_e`.

### B-03
**Objeto:** `PRO_BATCH2_FILTRO_G` · **Severidad:** Alta · **Estado en Redshift:** Replicado

Dentro del bucle que recorre los registros, el `UPDATE` que usa la tabla `BACTH_FG_2` se aplica a **los 6 cubos de contacto en cada iteración**, no solo al cubo del registro en curso. Como la llave `ID_AUTO` es un correlativo que **puede repetirse entre cubos distintos**, una fila de un cubo puede marcar el `FILTRO_G` de una fila ajena en otro cubo.

*Impacto:* contaminación cruzada entre canales; se descartan datos válidos y se conservan datos que debían descartarse. El efecto concreto depende de los datos.
*Dónde está replicado:* `08_sp_batch2_procesacubos.sql`, `sp_batch2_filtro_g`.

### B-04
**Objeto:** `PRO_Batch2_Completitud_Canal` · **Severidad:** Alta · **Estado en Redshift:** Replicado

El SP tiene dos bloques simétricos, TELÉFONO y DIRECCIÓN. Ambos están controlados por un `WHILE` cuya condición original (comentada en el fuente) era `WHILE ( V_ITERA <= V_INDICE )`. Quedó reemplazada por una condición fija:

- bloque TELÉFONO (`Sps_Batch.sql` línea 8545): `SET V_ITERA = 1` … `WHILE ( V_ITERA = 1 )` → **entra una sola vez** (al final hace `V_ITERA = V_ITERA + 1`).
- bloque DIRECCIÓN (línea 8792): `SET V_ITERA = 1` … `WHILE ( V_ITERA = 2 )` → **la condición es falsa al entrar; el bloque completo (líneas 8799–8945) nunca se ejecuta**.

Además `V_INDICE`, que se calcula justo antes en ambos bloques (`SELECT count(*) ... WHERE codigo_campo = 'DD_DIR'`), queda sin usar.

*Impacto:* la tabla `tabla_w2` se crea vacía y **la completitud de canal solo se evalúa para teléfono, nunca para dirección**. El archivo de ALERTAS sale incompleto. Además, como el bloque de teléfono también corre una sola vez en lugar de iterar `V_INDICE` veces, solo se evalúa la **serie 1** (el primer teléfono), no las repeticiones.
*Dónde está replicado:* `Redshift/procedures/09_sp_batch2_otros.sql`, `sp_batch2_completitud_canal`.

### B-05
**Objeto:** `PRO_BATCH2_ESTADISTICAS` · **Severidad:** Alta · **Estado en Redshift:** Replicado

En el bloque que cuenta el causal `ID_NE` (`Sps_Batch.sql` ~líneas 6820–6850), el `INNER JOIN` contra el catálogo no tiene predicado de unión contra la tabla unida:

```sql
FROM  <stage>.vstg_INCONSIS_PNPJ_TABLA tw
INNER JOIN REC_DATOS.PRO_BATCH2_FILTROS_ESTADISTICAS CR
ON TRIM(TW.CAUSAL) = '05'          -- condición sobre TW únicamente
WHERE CR.CAMPO = 'CAUSAL' AND CR.IDENTIFICADOR = 'GENERALES' AND CR.VALOR1 = 'ID_NE'
```

Es un producto cartesiano: `COUNT(*)` devuelve *(filas con causal 05)* × *(filas del catálogo que cumplen el `WHERE`)*. Solo da el número correcto si existe **exactamente una** fila con `CAMPO='CAUSAL'` y `VALOR1='ID_NE'`.

Agrava el efecto que este bloque, a diferencia de los demás, **acumula** en vez de asignar: `SET CONTEO = COALESCE(CONTEO,0) + TMP.CUANTOS`.

*Impacto:* el conteo de identificaciones no encontradas (`ID_NE`) del archivo de alertas queda multiplicado.
*Dónde está replicado:* `09_sp_batch2_otros.sql`, `sp_batch2_estadisticas`.
*Nota:* no se puede confirmar la magnitud hasta recibir las filas de `PRO_BATCH2_FILTROS_ESTADISTICAS`.

### B-06
**Objeto:** fila `ID = 13` de `BATCH_MOTOR_LOG` (`TIPO='LOG'`) · **Severidad:** Alta · **Estado en Redshift:** Replicado

La fila 13 debería escribir `NUMERO DE DATOS MÍNIMOS POR TELÉFONO FIJO`. Su `SQL_STRING` es, en cambio, una **copia de la sentencia de la fila 6** (`CODIGO SUSCRIPTOR`) y termina en `WHERE ID=6`. Dos consecuencias:

1. El campo `NUMERO DE DATOS MÍNIMOS POR TELÉFONO FIJO` (ID 13) **nunca se puebla**.
2. El campo `CODIGO SUSCRIPTOR` (ID 6) **se sobrescribe**, y con una variante distinta: la fila 6 filtra `WHERE ID_SOLICITUD = P_ID_SOLICITUD` y la fila 13 filtra `WHERE ID_SOLICITUD = P_ID_PLANTILLA`.

*Confirmación:* en las 4 corridas de `Salidas/BATCH_SOLICITUD_BATCH.ARCHIVO_LOG` el campo sale vacío, consistente con el filtro por plantilla no encontrando filas.
*Dónde está replicado:* `Redshift/datos/01_catalogos_motor.sql`, fila 13.

### B-07
**Objeto:** fila `ID = 8` de `BATCH_MOTOR_LOG` (`REGISTROS GRABADOS`) · **Severidad:** Alta · **Estado en Redshift:** Replicado

La sentencia compara dos literales constantes y distintos:

```sql
CASE WHEN TRIM('SIN DATOS DE UBICACION') = 'CON DATOS DE UBICACION' THEN COUNT(NUMERO_ID) ELSE 0 END
```

La condición es siempre falsa, así que los tres brazos del `UNION ALL` devuelven 0 y **`REGISTROS GRABADOS` siempre vale 0**. Lo que debió ser un parámetro (`P_NOMBRE_SECCION`) quedó escrito como literal.

*Confirmación:* las 4 muestras de `Salidas/` traen `REGISTROS GRABADOS;0`.
*Dónde está replicado:* `Redshift/datos/01_catalogos_motor.sql`, fila 8, simplificada a `SET valor = '0'` con el original citado en el comentario.

### B-08
**Objeto:** `P0033_BATCH2_CANTREPCANAL_111.BTQ` → `PRO_BATCH2_CANTREPCANAL_CON` · **Severidad:** Alta · **Estado en Redshift:** Replicado

La firma del SP es `(..., P_ID_SOLICITUD INTEGER, P_ID_PLANTILLA INTEGER, ...)` pero el BTQ pasa, en ese orden, `${varPLANTILLA}` y `${varSOLICITUD}`:

```
CALL PRO_BATCH2_CANTREPCANAL_CON ( ${lote}, ..., ${varPLANTILLA}, ${varSOLICITUD}, '${P_CDATOS_SDATOS}', P_ERROR );
```

Los dos identificadores llegan **cruzados**, y el motor los sustituye así en los marcadores `P_ID_SOLICITUD` / `P_ID_PLANTILLA` de cada `SQL_STRING`.

*Impacto:* las sentencias de conteo por canal filtran por los valores invertidos. Si la solicitud y la plantilla tienen el mismo valor el error es invisible.
*Dónde está replicado:* el orquestador `10_sp_batch2_proceso_batch2.sql` invierte los argumentos al llamar a `sp_batch2_cantrepcanal_con`, con el comentario correspondiente.

### B-09
**Objeto:** llamada a `PRO_BATCH_ADD_PORC_INSUMO` · **Severidad:** Alta · **Estado en Redshift:** Replicado (neutralizado por nombre)

Mismo patrón que B-08: el BTQ pasa plantilla y solicitud en el orden contrario al de la firma.

*Mitigación en la migración:* en Redshift los parámetros se pasan **por nombre** desde el orquestador, con el mismo cruce que hacía el BTQ, de modo que el comportamiento observable es idéntico.
*Dónde está replicado:* `08_sp_batch2_procesacubos.sql`, `sp_batch2_add_porc_insumo`.

### B-10
**Objeto:** `PRO_BATCH2_ESTADISTICAS`, vista `VSTG_BATCH_ESTADISTICAS_EXP` · **Severidad:** Alta · **Estado en Redshift:** Replicado

En la vista que arma el archivo de alertas, los bloques `PARTE_11` (ID 22) y `PARTE_12` (ID 24) leen **el mismo** `IDENTIFICADOR = 'CIUDAD_DIR_TOTAL'`. Por simetría con el resto de la vista (`CIUDAD_DIR1` / `CIUDAD_TEL1`, `DIR_POR_IDENT` / `TEL_POR_IDENT`, `TIPO_DIR` / `TIPO_TEL`), `PARTE_12` debería leer `CIUDAD_TEL_TOTAL`.

*Impacto:* el archivo de alertas repite la distribución por ciudad de **direcciones** donde debería mostrar la de **teléfonos**. La sección de teléfonos nunca se entrega.
*Dónde está replicado:* `09_sp_batch2_otros.sql`, `sp_batch2_estadisticas`, bloque de creación de `vstg_batch_estadisticas_exp`.

### B-11
**Objeto:** `PRO_BATCH2_FILTRO_F` · **Severidad:** Media · **Estado en Redshift:** Replicado

A diferencia de los otros filtros, `FILTRO_F` **no pone `FILTRO_F = 0` antes de recalcular**. Si la tabla cubo conserva valores de una corrida anterior para la misma solicitud, esas marcas se arrastran.

*Impacto:* solo afecta reprocesos sobre cubos no recreados.
*Dónde está replicado:* `08_sp_batch2_procesacubos.sql`, `sp_batch2_filtro_f`.

### B-12
**Objeto:** `PRO_BATCH2_FILTRO_F` · **Severidad:** Media · **Estado en Redshift:** Replicado

Cuando no existe fila de porcentajes mínimos en `PMD` para el canal evaluado, el `CASE` que decide la marca cae en una rama que deja `FLAG = 1`, es decir, **descarta el registro por defecto** en vez de conservarlo.

*Impacto:* una parametrización incompleta de `BATCH_PORCENTAJES_FILTROS` descarta datos en silencio.
*Dónde está replicado:* `08_sp_batch2_procesacubos.sql`, `sp_batch2_filtro_f`.

### B-13
**Objeto:** `PRO_BATCH2_FILTRO_D` · **Severidad:** Media · **Estado en Redshift:** Replicado

Dos defectos en el armado de SQL dinámico:

1. Si el nombre de cubo que llega no está en el mapeo del `CASE`, la variable de SQL queda en `NULL` y la sentencia que se ejecuta es `NULL` (no hace nada, sin error visible).
2. La cadena ensamblada se **trunca a 1 000 caracteres** por el tamaño de la variable. Con suficientes campos configurados, el SQL se corta por la mitad.

*Dónde está replicado:* `08_sp_batch2_procesacubos.sql`, `sp_batch2_filtro_d`.

### B-14
**Objeto:** `PRO_BATCH2_HOMOLOGACIONES` · **Severidad:** Media · **Estado en Redshift:** Replicado

El SP arma SQL por tramos usando `MIN_ID`/`MAX_ID` sobre una partición, igual que `TRANSPUESTA` (ver B-25). Cuando una partición tiene **una sola fila**, el primer `WHEN` del `CASE` (el que agrega el prefijo) gana y el sufijo de cierre nunca se añade, produciendo una sentencia sin cerrar.

*Dónde está replicado:* `08_sp_batch2_procesacubos.sql`, `sp_batch2_homologaciones`.

### B-15
**Objeto:** `PRO_BATCH2_FILTRO_H` · **Severidad:** Media · **Estado en Redshift:** Replicado

El `CASE` que calcula la marca `FILTRO_H` **no tiene rama `ELSE`**, así que los casos no previstos quedan en `NULL` en lugar de 0 o 1. Además, el cubo de punto de interés (`batch_cubo_punto_interes_dir`) **no se recalcula** en este filtro, aunque los otros seis sí.

*Dónde está replicado:* `08_sp_batch2_procesacubos.sql`, `sp_batch2_filtro_h`.

### B-16
**Objeto:** `PRO_BATCH2_FILTRO_J` · **Severidad:** Media · **Estado en Redshift:** Replicado (depende de la configuración del clúster)

El SP compara nombres de cubo contra literales con distinta capitalización (`'Correo'` frente a `'correo'`). En Teradata las columnas son `NOT CASESPECIFIC` y la comparación ignora mayúsculas, así que coincide.

**Requisito de despliegue derivado:** la base Redshift debe crearse con `COLLATE CASE_INSENSITIVE`. Sin esa *collation* el filtro J deja de coincidir y el comportamiento **no** es el del original.

*Dónde está replicado:* `08_sp_batch2_procesacubos.sql`, `sp_batch2_filtro_j`; requisito anotado en `Redshift/README.md`.

### B-17
**Objeto:** `PRO_BATCH2_ADICIONAR_INCON` · **Severidad:** Media · **Estado en Redshift:** Replicado

Hace `CAST(numero_id AS BIGINT)` sin validar que el texto sea numérico. Un número de identificación con caracteres no numéricos **aborta el paso**. Teradata y Redshift fallan igual aquí, así que el comportamiento coincide.

*Dónde está replicado:* `08_sp_batch2_procesacubos.sql`, `sp_batch2_adicionar_incon`.

### B-18
**Objeto:** `PRO_BATCH_ADD_PORC_INSUMO` · **Severidad:** Media · **Estado en Redshift:** Replicado

El join contra `BATCH_SALIDAS_CAMPOS` no agrupa ni desduplica. Si el catálogo tiene **más de una fila para el mismo campo** (por ejemplo, el mismo `codigo_campo` en dos subsecciones), el SP **duplica filas** en la tabla resultado.

*Dónde está replicado:* `08_sp_batch2_procesacubos.sql`, `sp_batch2_add_porc_insumo`.

### B-19
**Objeto:** `PRO_BATCH2_ESTADISTICAS` · **Severidad:** Media · **Estado en Redshift:** No aplica (esquemas fijos)

En el `UNION ALL` del conteo `ID_NV` (líneas 6782 y 6793), el primer brazo referencia `'||P_BDSTAGE||'.vstg_INCONSIS_PNPJ_TABLA` (parametrizado) y el segundo `REC_STAGE.VSTG_INCONSIS_PNPJ_TABLA` (**hardcodeado**). Si `P_BDSTAGE` no es `REC_STAGE` —por ejemplo en un ambiente de pruebas— los dos brazos leen tablas distintas.

*Estado:* en Redshift los esquemas son fijos (`rec_stage`), así que el defecto no se puede manifestar. Se documenta porque **oculta una dependencia de ambiente** del original.

### B-20
**Objeto:** UDF `DataMasking` (C) · **Severidad:** Media · **Estado en Redshift:** **No replicado** (ver nota)

El código C enmascara dejando visibles los primeros caracteres y reemplazando el resto. Cuando la cadena de entrada tiene **3 caracteres o menos**, el bucle de relleno no se ejecuta y la función **devuelve el buffer de salida sin inicializar**: el resultado es basura de memoria, no determinista.

*Estado en la migración:* **única desviación deliberada de este documento.** La Lambda/SQL UDF devuelve el dato **sin cambios** en ese caso, porque replicar memoria sin inicializar no es posible ni deseable.
*Impacto:* afecta buzones de correo de 3 caracteres o menos en solicitudes de prueba (las de producción no se enmascaran).
*Pendiente:* confirmar con negocio que devolver el dato sin cambios es aceptable (insumo #18 de la lista del 14-oct).
*Dónde:* `Redshift/ddl/08_funciones_udf.sql`, `f_datamasking`.

### B-21
**Objeto:** UDF `DataMasking`, `DirDataMasking`, `RazonDataMasking` (C) · **Severidad:** Media · **Estado en Redshift:** **No replicado**

Las tres funciones escriben el resultado con `sprintf(salida, cadena)`, pasando el **dato como cadena de formato**. Si el dato contiene un `%`, `sprintf` lo interpreta como especificador de formato y la salida se corrompe (o se lee memoria arbitraria).

*Estado en la migración:* no se replica. Es un defecto de seguridad de memoria, sin resultado definido que imitar.
*Dónde:* `Redshift/ddl/08_funciones_udf.sql`.

### B-22
**Objeto:** UDF `Bach_Similitud_Dir_MZ` (C) · **Severidad:** Media · **Estado en Redshift:** Replicado

El cálculo de similitud cuenta un número repetido en la bodega **varias veces**, por lo que el porcentaje devuelto puede ser **mayor que 100**; por el lado opuesto, ciertas combinaciones devuelven valores **negativos**. El `CASE` de `FILTRO_F` acota el rango después, así que el efecto queda contenido, pero la función no respeta su propio contrato de 0–100.

*Dónde está replicado:* `Redshift/lambda/udf_similitud/lambda_function.py`.

### B-23
**Objeto:** UDF `PorcSimilitud` (C) · **Severidad:** Media · **Estado en Redshift:** Replicado

La UDF declara sus parámetros como `VARCHAR(20)`, pero `FILTRO_F` le pasa **direcciones completas**. Teradata trunca los argumentos en silencio, así que en producción **solo se comparan los primeros 20 caracteres** de cada dirección.

*Impacto:* dos direcciones que difieren solo después del carácter 20 se consideran idénticas.
*Dónde está replicado:* `Redshift/lambda/udf_similitud/lambda_function.py` (`TRUNCAR_A`).
*Pendiente:* confirmar que Teradata trunca y no lanza error (insumo #5 de la lista del 14-oct).

### B-24
**Objeto:** UDF de similitud (C) · **Severidad:** Media · **Estado en Redshift:** Replicado

Con insumo vacío el código divide por cero. En x86-64 el resultado observado es `-2147483648` (`INT_MIN`), no una excepción.

*Dónde está replicado:* `Redshift/lambda/udf_similitud/lambda_function.py`, con prueba unitaria que fija el valor.

### B-25
**Objeto:** `PRO_BATCH2_TRANSPUESTA` · **Severidad:** Media · **Estado en Redshift:** Replicado

El SQL de transposición se arma por tramos con un `CASE` de tres ramas sobre `ID_C` (posición dentro de la partición):

```sql
CASE WHEN ID_C = MIN_ID THEN '<prefijo CREATE TABLE ...>' || SQL_1
     WHEN ID_C = MAX_ID THEN SQL_1 || '<sufijo END ) AS C... >'
     ELSE SQL_1 END
```

Si una partición tiene **una sola fila** (`MIN_ID = MAX_ID = 1`), el primer `WHEN` gana y el segundo nunca se evalúa: la sentencia generada lleva el prefijo pero **no el sufijo de cierre**, y falla al ejecutarse. Ocurre cuando `BACTH_CAMPOS` tiene una sola columna configurada.

*Dónde está replicado:* `09_sp_batch2_otros.sql`, `sp_batch2_transpuesta`.

### B-26
**Objeto:** `PRO_BATCH2_ESTADISTICAS` · **Severidad:** Baja · **Estado en Redshift:** Replicado

El SP arranca borrando `BATCH2_ESTADISTICAS_TMP`, pero **esa tabla no se crea en ninguna parte del SP**. El bloque de borrado es código muerto, probablemente residuo de una versión anterior.

*Dónde está replicado:* `09_sp_batch2_otros.sql`, `sp_batch2_estadisticas` (se conserva el `DROP ... IF EXISTS` para mantener el mismo rastro en el log).

### B-27
**Objeto:** `PRO_BATCH2_TRANSPUESTA` · **Severidad:** Baja · **Estado en Redshift:** Replicado

`BACTH_CAMPOS_2` se crea **dos veces con el mismo DDL** (líneas 8083 y 8139). El bloque intermedio lleva el comentario `-- Borrado de tabla temporal BACTH_HOMG_3` pero verifica y borra `BACTH_CAMPOS_2`; debería referirse a `BACTH_CAMPOS_3`. La primera creación es trabajo desperdiciado (la tabla se borra y se recrea idéntica).

*Impacto:* solo tiempo de ejecución.
*Dónde está replicado:* `09_sp_batch2_otros.sql`, `sp_batch2_transpuesta`.

### B-28
**Objeto:** `PRO_BATCH2_ESTADISTICAS` · **Severidad:** Baja · **Estado en Redshift:** Replicado

Varias descripciones de paso que se escriben en `LOG_TD_DETALLE` están copiadas de otro bloque. En particular, `'Crea Tabla BATCH2_ESTADISTICAS_TMP'` se usa para registrar la creación de `vstg_INCONSIS_PNPJ_TABLA` (línea 6305) y la de `BATCH_CUBO_PERSONA_UNICO` (línea 6352).

*Impacto:* el log de ejecución es engañoso al diagnosticar un fallo. Se replica literalmente porque el log es parte de la salida comparable.
*Dónde está replicado:* `09_sp_batch2_otros.sql`, `sp_batch2_estadisticas`.

### B-29
**Objeto:** `PRO_BATCH2_FILTRO_A` · **Severidad:** Baja · **Estado en Redshift:** Replicado

La cabecera del SP y algunos textos de log mencionan otro filtro (herencia de copiar/pegar la plantilla del SP). No afecta el resultado de datos, sí el log.

*Dónde está replicado:* `08_sp_batch2_procesacubos.sql`, `sp_batch2_filtro_a`.

### B-30
**Objeto:** `PRO_Batch2_Completitud_Canal`, `PRO_BATCH2_TRANSPUESTA` · **Severidad:** Baja · **Estado en Redshift:** No aplica (esquemas fijos)

Ambos SPs reciben `P_BDSTAGE` como parámetro pero en varios puntos escriben `rec_stage` / `REC_STAGE` **hardcodeado**:

- `TRANSPUESTA` línea 7904: `FROM rec_stage.v_ba2_Campos_Salida`.
- `Completitud_Canal` líneas 8402–8407: la vista `v_Datos_tmp1` se crea en `P_BDSTAGE` pero une `rec_stage.Vstg_Batch2_PNPJ/_PJ/_PN`.
- `Completitud_Canal`: casi todos los `INSERT INTO REC_STAGE.w_borrar_002` del interior de los bucles.

*Estado:* igual que B-19, en Redshift no se puede manifestar. Se documenta porque invalida la parametrización de esquema del original.

### B-31
**Objeto:** filas `ID = 5` y `ID = 10` de `PRO_PLAN_EJECUCION` · **Severidad:** Baja · **Estado en Redshift:** **No replicado**

Las filas del motor del plan de ejecución hacen `DROP TABLE REC_STAGE.INTEGRADOR_TMP` y `DROP TABLE REC_STAGE.BATCH2_SHELLS_PLANEJECUCION` **sin `IF EXISTS`**. En un ambiente nuevo, la primera corrida **falla** en ese paso; solo funciona a partir de la segunda, o si alguien creó las tablas a mano.

*Estado en la migración:* se usa `DROP TABLE IF EXISTS` para que la primera corrida en un clúster limpio no falle. Es una desviación consciente: replicar el fallo impediría cualquier prueba inicial.
*Dónde:* `Redshift/datos/01_catalogos_motor.sql`, filas 5 y 10.

---

## Desviaciones deliberadas (resumen)

La fase 1 replica todo salvo estos cuatro casos, donde replicar es imposible o impediría ejecutar:

| ID | Por qué no se replica |
|---|---|
| B-20 | Memoria sin inicializar: no hay resultado determinista que imitar |
| B-21 | `sprintf` con el dato como formato: comportamiento indefinido |
| B-31 | `DROP` sin `IF EXISTS` haría fallar la primera corrida en un clúster limpio |
| B-19 / B-30 | Dependen de que el nombre de esquema sea parametrizable; en Redshift es fijo |

---

## Defectos pendientes de confirmar

No se clasifican como bug todavía porque faltan insumos del equipo Teradata:

| Tema | Qué falta | Insumo |
|---|---|---|
| Magnitud real de B-05 | Filas de `PRO_BATCH2_FILTROS_ESTADISTICAS`: cuántas cumplen `CAMPO='CAUSAL'` y `VALOR1='ID_NE'` | #2 de la lista del 14-oct |
| Comportamiento de `editdistance_u` | Confirmar que es Damerau-Levenshtein OSA con costos 1 | #5 |
| Truncamiento de argumentos (B-23) | Confirmar que Teradata trunca en silencio y no lanza error | #5 |
| Contenido de `FILTRO-C` y `CANT_REP_CANAL_CONTACTO` | Las filas de `BATCH_MOTOR_LOG` pueden traer más defectos del mismo tipo que B-06 y B-07 | #1 |
| `SP_EXECSTRING_DES` | Confirmar qué escribe exactamente en `LOG_TD_DETALLE` | #6 |
