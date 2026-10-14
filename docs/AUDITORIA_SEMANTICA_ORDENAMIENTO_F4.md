# Auditoría semántica de la Fase 4 (Scoring) — legado Teradata contra Redshift

**Para la mesa funcional. No es un informe de defectos: es la constatación de
que lo construido no reproduce el modelo del legado.**

Fecha: 2026-10-14 · Alcance: las 47 características de los cuatro canales ·
Método: comparación una por una del SQL del legado (`Caracteristicas.txt`)
contra el SQL de los `sp_ordenamiento_scoring_*_edf.sql`, preguntando a cada
una **qué magnitud calcula**, no si los umbrales coinciden.

---

## ESTADO A 2026-10-14 (noche): 34 de las 47 ya estan corregidas

**Lo que sigue a esta seccion es el diagnostico original, y se conserva
entero porque es la justificacion de por que habia que tocar nada. Pero ya no
describe el estado del codigo.** Tras auditar las 47 una a una contra el
legado y reescribir lo que no coincidia, el reparto es este:

| Canal | Ya correctas | Corregidas | Bloqueadas | Total |
|---|---|---|---|---|
| EMA | 2 | 9 | 2 | 13 |
| CEL | 1 | 8 | 2 | 11 |
| DIR | 0 | 8 | 4 | 12 |
| TEL | 2 | 9 | 0 | 11 |
| **Total** | **5** | **34** | **8** | **47** |

El diagnostico original contaba 32 con magnitud distinta; la cuenta fina, al
reescribirlas, dio 34. La diferencia son dos que el primer pase clasifico
como "parcial" y resultaron ser otra magnitud.

### Lo que ademas aparecio al reescribir, y no estaba en el diagnostico

| Hallazgo | Donde |
|---|---|
| **El grano de TEL estaba mal.** El legado agrupa por NUMERO DE TELEFONO; la columna se llama `Direccion_Fisica` pero contiene el numero, y su divisor se llama `Total_Reportes_Telefono` (`Caracteristicas.txt:2252-2262`). Nosotros agrupabamos por direccion | `sp_ordenamiento_scoring_tel_edf.sql` |
| **El canal CEL tiene una compuerta de elegibilidad.** `Orden_Celular` filtra `WHERE CEl018.CO01CEL018 <> 0` (`:899`): un prefijo no catalogado deja al celular FUERA del ranking, no solo penalizado. Aplicada | `sp_ordenamiento_scoring_cel_edf.sql` |
| **`EMA024` no puntuaba nada.** Su categoria era `CASE WHEN ema024 <= 0 THEN 1 ELSE 1`, las dos ramas a 1: entraba en la suma con su beta y aportaba la misma constante a todas las filas | corregido |
| **`DIR002TO` era un conteo y el legado es una recencia** (`:2916`). No estaba en la lista; entro porque alimenta `DIR059` | corregido |
| **Cuatro caracteristicas se daban por bloqueadas y no lo estaban:** `CEL014`, `CEL017`, `TEL017` y `TEL010` no dependen de `tipo_cuenta` ni de `sector_financiero` en el legado | portadas |
| **El mock no tiene recencia.** Solo dos valores, 0 y 8 meses: las ventanas `(3,6]` y `>24` estan vacias, asi que varias caracteristicas correctas salen constantes | `docs/HALLAZGOS_RECENCIA_MOCK_ORDENAMIENTO.md` |

### Lo que la mesa todavia tiene que resolver

Las 8 bloqueadas, todas por datos que no estan en el datashare actual:

| Caracteristica | Que falta | Cita |
|---|---|---|
| `EMA020` | `REC_VISTA.V_Ind_Efectiv_Orden_Peso_Email` cruzando `Gestion_Contactabilidad` | `:2713-2714` |
| `EMA021` | `Cod_Tipo_Cta_Fte` de `CTA_TOTALES_PERSONAS_TMP3` | `:2768-2769` |
| `CEL019` | `Cod_Tipo_Cta_Fte` mas `REC_VISTA.V_Tipo_Cuenta_Ord` | `:1292-1295` |
| `CEL020` | `Cod_Suscriptor`, en las DOS ramas del cociente | `:1589-1590`, `:1154-1155` |
| `DIR001IN` | `Portafolio_Nuevo = 'IN'` | `:2123` |
| `DIR004RO` | `Portafolio_Nuevo = 'RO'` | `:2917-2918` |
| `DIR034FI` | el importe `CO00END005` de `Insumo_Caracteristica`, mas `Sector` | `:2589-2595` |
| `DIR050TO` | `CO00MOR037` / `CO00MOR038` de `Insumo_Caracteristica` | `:3117-3121` |

Y dos quedan con la FORMA portada y el dato aproximado: `DIR010FI` y
`DIR013OT` llevan ya sus ventanas (`<= 6` y `> 24`) y el divisor por persona,
pero nuestra bandera `sector_financiero` 0/1 no distingue `'FI'` de `'OT'` ni
de `'CO'`, `'CC'`, `'RE'`. Cuando llegue el `Sector` solo cambia el predicado.

Peticion itemizada en `docs/PETICION_DATASHARE_F1_F3_ORDENAMIENTO.md`.

### Una rareza del legado que conviene que la mesa vea

`CO01CEL019_Peso` divide por 4 (`:1517`) pero su `_Cat` solo llega a 3
(`:1837-1842`), de modo que su aporte queda topado en el 75% de su beta.
Todas las demas del canal tienen cuatro cubetas. Parece un defecto del
legado; se porto literal, porque manda el codigo, y se levanta aqui para que
alguien decida si se corrige en el modelo.

### Sobre los betas

El apartado de abajo advierte que aplicar los betas del `RITM5226589` a
magnitudes distintas es aritmetica sin fundamento. **Esa advertencia ya no
aplica a las 34 corregidas**, que vuelven a medir la magnitud sobre la que se
calibraron los coeficientes. Sigue aplicando, y conviene no perderlo de
vista, a las 8 bloqueadas y a las 2 aproximadas: ahi los betas se estan
aplicando sobre otra cosa.

---

## El resultado

| Canal | Misma magnitud | Parcial | **Magnitud distinta** | Total |
|---|---|---|---|---|
| DIR | 0 | 5 | **7** | 12 |
| TEL | 3 | 1 | **7** | 11 |
| CEL | 2 | 2 | **7** | 11 |
| EMA | 1 | 1 | **11** | 13 |
| **Total** | **6** | **9** | **32** | **47** |

**32 de 47 características miden algo distinto de lo que mide el legado.**

En EMA el dato es más duro todavía: **las nueve características que componen la
suma del score miden otra cosa.** Las dos únicas que coinciden — `EMA003` y
`EMA007` — son precisamente las que el legado deja **fuera** de la suma.

---

## Por qué importa: los betas dejan de significar nada

Los 47 coeficientes del `RITM5226589` se calibraron estadísticamente **sobre
las características del legado**. Aplicarlos a magnitudes distintas no es una
aproximación con error acotado: es aritmética sin fundamento.

El ejemplo más claro:

| | `EMA014` |
|---|---|
| **Legado** | % de los reportes de más de 24 meses de la persona que son de este correo |
| **Nuestro** | ¿el dominio es gmail, hotmail, yahoo u outlook? |
| **Beta** | **−130.80** |

El beta negativo tenía sentido sobre la primera magnitud: más peso en la cola
larga del histórico, peor contactabilidad. Sobre la segunda significa
**penalizar 98 puntos por tener gmail**, sin ninguna base.

Y no está solo: `EMA017` deriva de la **misma** lista de dominios, también con
beta negativa. Entre las dos restan **121.02 puntos** a todo correo de dominio
conocido. En el legado el dominio **no afecta al score en absoluto** — está en
`EMA018`, con beta positiva y fuera de la suma.

Sumando los peores casos, dos scores EMA del mismo correo pueden diferir en
**más de 600 puntos** entre el legado y el nuestro.

### El patrón, en una frase

**El legado construye los canales sobre ventanas de recencia y participación
relativa dentro de la persona. El código actual las sustituyó por atributos
estáticos del contacto.**

Donde el legado pregunta *"¿qué proporción de los reportes recientes de esta
persona corresponden a este contacto?"*, nuestro código pregunta *"¿de qué
operador es?"*, *"¿es gmail?"*, *"¿el suscriptor es financiero?"*.

La causa raíz es identificable: **se tomó el nombre de la característica, o el
de la vista de catálogo, como especificación, en vez del SQL.** El caso que lo
demuestra es `POSPAGO`: esa cadena **no aparece ni una vez en todo el legado**.
`V_Tipo_Cuenta_Ord` está indexada por `Cod_Tipo_Cta_Fte`, el tipo de
**obligación crediticia** (1 = ahorros, 23/24 = tarjeta). Alguien leyó "tipo de
cuenta" y entendió prepago/pospago de línea móvil.

---

## El hallazgo que afecta a producción hoy

**El canal TEL no rankea nada, y no solo en el mock.**

El legado agrupa las características de TEL por
`(Cod_Pin_Persona, Id_Buro_Persona, Direccion_Fisica)`, donde `Direccion_Fisica`
es **la dirección física de cada fila de reporte**. Una persona con N
direcciones produce **N grupos**, y el ranking elige entre ellos. Ese es el
propósito del canal.

Nuestro código agrupa por `direccion_fisica`, pero esa columna se construye
como `COALESCE(ref.dir_ref, ...)` y **`ref.dir_ref` es `MIN(texto_ubicacion)`
agregado POR PERSONA** (`sp_ordenamiento_preparar_insumos_edf.sql:127`). Si la
persona tiene una sola ubicación estandarizada —el caso normal— **todos sus
teléfonos reciben el mismo valor y colapsan en un grupo**. Resultado: una fila
de score, `lugar = 1` siempre, nada que ordenar.

**Está en el SP real, no solo en el mock.** Y arrastra cinco características
más: `TEL001`, `TEL006`, `TEL010`, `TEL023` y `TEL025` son, en el legado,
*cuotas del grupo contra el total de la persona*. Si grupo = persona, esas
cuotas valen trivialmente 100 o 0. No es que den otro número: **la magnitud
pierde el sentido sin el segundo nivel**, y por eso el código tuvo que inventar
fórmulas de un solo nivel.

Es el arreglo de mayor retorno de toda la auditoría y no toca el scoring:
`direccion_fisica` debe ser la de **la fila de contacto**, no un `MIN` por
persona.

---

## Qué se puede arreglar y qué no

| Grupo | Nº aprox. | Qué hace falta |
|---|---|---|
| **Reescribir la fórmula, el dato ya está** | ~22 | Añadir los contadores de ventana por persona (`Total_Reportes_3/6/12/24/24m`), derivables del `meses_reporte` que ya tenemos. Cubre `EMA010/014/015/016/017`, `CEL006/013/014/015/017`, `DIR007TO/017/019/057/059/009` |
| **Falta el filtro de validez** | ~13 | `Descripcion_Gestion_Registro` no existe en `v_xpm_contacto_canal`. Para TEL se sustituyó por una regex sobre el propio número — dos predicados sin relación |
| **No portables con lo entregado** | ~12 | Dependen de la **Fase 2** (`Cod_DW_Cta`, portafolio, sector por cuenta, mora, endeudamiento) o de catálogos que no vinieron |

### Lo que falta del entregable

| Artefacto | Para qué | Afecta a |
|---|---|---|
| `V_DIRECCIONES_TEMP_{TF,TM,DF,ML}` | **la frontera F3/F4**; ninguna está definida en el material | los 4 canales |
| `V_Ind_Efectiv_Orden_Peso_Email` + `Gestion_Contactabilidad` | peso de efectividad de contacto | `EMA020` |
| `V_Tipo_Cuenta_Ord` + `Cod_Tipo_Cta_Fte` | tipo de obligación crediticia | `CEL019`, `EMA021` |
| `V_Operador_Ord_Cel` | pesos de operador (los 16 nuestros son inventados) | `CEL018` |
| `CTA_TOTALES_PERSONAS_TMP3`, `Insumo_Caracteristica` | portafolio, sector, mora, endeudamiento **por cuenta** | 6 de DIR |
| `COINCIDENCIA` | coincidencia geográfica | `TEL010`, `TEL020`, `TEL022` |

**Casi todo lo no portable es salida de la Fase 2**, que no está migrada. Eso
corrige un supuesto con el que se definió el alcance: se asumió que F1-F3 solo
cambiaban *quién llena* las tablas de insumo de F4. No es así — **F2 aporta
columnas que las fórmulas de F4 necesitan**, y en su ausencia se sustituyeron
por aproximaciones a nivel de reporte.

---

## Dos divergencias estructurales más, al margen de las fórmulas

1. **Partición del ranking.** El legado parte por
   `(Id_Buro_Persona, Cod_Pin_Persona)`; nuestro código solo por
   `id_buro_persona`. Equivalentes solo si la relación pin↔buró es 1:1, lo que
   no está verificado.
2. **Centinela de contactabilidad.** El legado asigna `SCORE = 999999` a los
   celulares verificados por la fuente `CONTACTABILIDAD` con
   `Severidad_ = 1 AND Severidad2_ = 1`: **el celular verificado gana siempre**.
   No existe en nuestro código, y no está en el documento de requerimientos.

---

## Qué decide la mesa

1. **¿Se reescribe la Fase 4 para reproducir el legado, o se acepta el modelo
   actual como evolución funcional con betas recalibrados?** Son los dos
   caminos; no hay un tercero que conserve los betas actuales y tenga sentido
   estadístico.
2. **¿Se prioriza portar la Fase 2?** Sin ella, ~12 características no son
   reproducibles y `CA-M01` (paridad numérica con Teradata) no es alcanzable.
3. **¿Se piden los artefactos que faltan** al equipo que entregó el legado?
   Las cuatro vistas `V_DIRECCIONES_TEMP_*` son la frontera del proceso: sin
   ellas no se puede certificar nada del canal por lectura.
4. **El arreglo de TEL**, ¿entra ya? Es acotado, no depende de ninguna decisión
   anterior y hoy el canal no cumple su función en producción.

---

## Nota sobre el método

Esta auditoría la hizo posible la maquinaria de certificación construida en las
tandas anteriores: el catálogo de 90 criterios, los arquetipos con scores
predichos y la comparación por deltas. **El tablero hizo exactamente su
trabajo — demostrar que lo que se iba a certificar no reproduce el legado.**
Nada de lo construido se pierde: sigue siendo el instrumento con el que se
verificará lo que se decida.
