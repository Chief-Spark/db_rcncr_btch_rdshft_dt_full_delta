# El desglose por dentro: regla, escenario y canal, en mock, DEV y QA

Medido el 2026-10-30 con `docs/framework_batch/distribucion_detalle.sql`.
Es el material de las tres tablas de la pagina de la sesion con Negocio.

**DE DONDE SALE CADA COLUMNA, Y NO ES DE DONDE YO CREIA.** `unificacion_direccion`
de DEV trae `lote = 7001` en sus 19 filas, no el `1356301` que usa
`run_reconocer_e2e_real_full.sql:60`. Lo mismo el gemelo mock (7001 en vez de
13566xx) y `mock_ord_control`. **El estado actual de DEV lo produjo una corrida
MANUAL con lote 7001, posterior al ultimo despliegue**, no el job #491.

Y eso, que parecia un problema, resulta ser el mejor dato de reproducibilidad
que tenemos: **la corrida manual reproduce al #491 dentro del 0,1%** --
19 unificaciones exactas, 185.317 scores contra 185.242, 363.437 filas contra
363.327--. Dos corridas independientes, mismo resultado.

## A. Que resolvio cada regla

| Regla | Mock | DEV | QA |
|---|---|---|---|
| Regla 1 | 15.000 | **0** | **0** |
| Regla 2 | 46.200 | 2 | 3.739 |
| Regla 3 | 5.000 | 17 | 4.051 |
| **Total** | **66.200** | **19** | **7.790** |

**La Regla 1 da CERO en los dos ambientes reales**, y no es un defecto: pide dos
escrituras de la misma direccion con tipo distinto, y eso en el buro casi no
ocurre. Solo el mock lo siembra.

**Y el total del mock son 66.200, no 66.000**, que es lo que la pagina decia a
ojo desde el principio. Corregido.

## B. Los diez escenarios de la Regla 2

| Escenario | Sello | Mock | DEV | QA |
|---|---|---|---|---|
| esc1 complemento vacio | `H1` | 6.000 | 2 | **3.739** |
| esc2 substring | `K2` | 4.000 | 0 | 0 |
| esc3 sin NIT, misma nomenclatura | `L3` | 4.000 | 0 | 0 |
| esc4 mayor frecuencia | `B5` | 4.000 | 0 | 0 |
| esc5 menor nivel | `C7` | 4.000 | 0 | 0 |
| esc6 complemento mas frecuente | `E6` | 4.000 | 0 | 0 |
| sitio 1 direccion fusionada | `X4` | 14.000 | 0 | 0 |
| sitio 2 nivel distinto | `A6` | 2.000 | 0 | 0 |
| sitio 3 nomenclatura cruzada | `A8` | 2.000 | 0 | 0 |
| sitio 4 ninguna coincide | `D9` | 2.000 | 0 | 0 |
| sin pareja posible | -- | 75.800 | 78.188 | 265.983 |
| **BRECHA sin resolver** | -- | **6.000** | **0** | **35** |

**ESTA ES LA TABLA QUE JUSTIFICA EL MOCK ENTERO: el dato real solo ejercita UN
escenario de los diez.** Los otros nueve estan portados y nunca se habrian
probado sin el laboratorio. Un proceso validado solo contra produccion deja
nueve de cada diez caminos sin recorrer.

**Y LA BRECHA DEL MOCK EN 6.000 NO ESTA EN LA PAGINA, A PROPOSITO.** Las tres
cifras de brecha salen del censo **ANTES** de la correccion del 2026-10-30 --la
del hermano sin sellar, commiteada y **no desplegada**--, de modo que las tres
estan infladas por la misma medida defectuosa. El 35 de QA es justo el caso ya
diagnosticado. **Hipotesis, no dato:** el 6.000 del mock es el mismo artefacto,
amplificado porque el mock siembra grupos de dos y tres con el mismo
complemento por construccion. Se vuelve a medir despues de desplegar, y hasta
entonces no se publica ni se abre trabajo por ella.

## C. El Ordenamiento, canal por canal

| Canal | Mock | DEV | QA |
|---|---|---|---|
| DIR | 89.800 | 64.436 | **83.180** |
| EMA | 74.000 | 59.759 | 62.147 |
| CEL | 74.000 | 48.499 | 52.944 |
| TEL | 68.000 | 12.623 | 18.074 |
| **Total** | **305.800** | **185.317** | **216.345** |
| `lugar_max` | **2** | **57** | **291** |

`lugar_max` es lo que prueba que el ranking discrimina: en QA hay una persona
con 291 datos de contacto ordenados. En mock se queda en 2 por construccion --dos
filas por persona para medir el DELTA de score--, y eso no es un limite del port.

**Y AQUI HAY UNA CONTRADICCION ABIERTA QUE NO SE PUEDE CERRAR DESDE EL REPO.**
La pagina trae **522.145** para QA y los cuatro canales suman hoy **216.345**.
No es el filtro de banda --en QA no corre el mock--: la tabla tiene hoy menos
filas de las que se midieron antes. La explicacion plausible es que
`score_ordenamiento` **no se trunca nunca** y su unica limpieza es
`DELETE ... WHERE id_buro_persona IN (stg_ord_personas_alcance)`: una corrida
posterior borro y reinserto su alcance. **Se cierra leyendo
`ord_control.scores_generados` por corrida en QA**, y hasta entonces la celda de
la pagina queda con el numero que el desglose reproduce.

## D. Las siete tablas de entrega

| Tabla | DEV filas | DEV personas | QA filas | QA personas |
|---|---|---|---|---|
| actividad economica | 124.267 | 58.512 | 121.220 | 57.581 |
| ubicacion | 60.493 | 55.264 | 74.237 | 51.703 |
| contactabilidad | 60.485 | -- | 74.237 | -- |
| ubicacion agregada | 59.314 | 55.264 | 69.231 | 51.703 |
| info basica | 58.878 | 58.809 | 57.813 | 57.813 |
| punto de interes | **0** | -- | **0** | -- |
| movilidad | **0** | 0 | **0** | 0 |
| **Total** | **363.437** | | **396.738** | |

El total de QA cuadra **exacto** con el que ya estaba en la pagina. Falta la
columna del mock: es el bloque `D2`, que no se ha corrido.

**Dos ceros que no son codigo que falte**, y valen para los dos ambientes:
punto de interes arranca `FROM bdm_datos.geo_distancias`, que solo escribe el
COPY de la respuesta de ArcGIS; movilidad es un delta contra una foto anterior
y en la primera corrida no hay foto.

**Y un detalle de DEV que no aparece en QA:** `info basica` trae 58.878 filas
para 58.809 personas distintas. Sesenta y nueve filas comparten par
`(tipo_identificacion, numero_identificacion)`. En QA el par es unico. No se
abre trabajo por esto hasta saber si son documentos repetidos en origen.
