# El mock no tiene recencia: por que once caracteristicas correctas salen constantes

Fecha: 2026-10-14. Rama `claude/elegant-carson-tqhcku`. Medido en el banco local.

---

## La conclusion

**Once caracteristicas de CEL y DIR estaban mal portadas. Ya estan corregidas
contra el legado. Pero el mock no puede ejercitarlas, porque solo tiene dos
valores de recencia: 0 y 8 meses.**

Las caracteristicas del Ordenamiento se reparten en cuatro ventanas de
`Meses_Reporte` (`<= 3`, `(3, 6]`, `(6, 12]`, `(12, 24]`, `> 24`). El mock
puebla **dos**. Las demas quedan vacias y su caracteristica devuelve la misma
constante para las 271 000 filas.

Esto NO es un defecto del codigo y NO se arregla en los SP. Es la siembra.

---

## La medida

Recencia en los insumos, tal como los deja `sp_ordenamiento_preparar_insumos_mock`:

| Canal | `meses_reporte` | filas |
|---|---|---|
| CEL | 0 | 4 000 |
| CEL | 8 | 64 000 |
| EMA | 0 | 2 000 |
| EMA | 8 | 64 000 |
| DIR | 8 | 150 000 |
| DIR | 15 | 7 000 |
| TEL | 8 | **64 000, y nada mas** |

Y el efecto en la salida, tras un FULL con los SP ya corregidos:

| Canal | filas | scores **distintos** |
|---|---|---|
| CEL | 68 000 | 4 |
| DIR | 73 000 | 9 |
| EMA | 66 000 | 2 |
| TEL | 64 000 | **1** |

Un canal con un solo score no ordena nada: `lugar = 1` para todo el mundo.

---

## Que caracteristica cae en que ventana

Con recencias de solo 0, 8 y 15 meses:

| Ventana | Quien la mira | Filas del mock que caen dentro |
|---|---|---|
| `<= 3` | `CEL006` | solo las 4 000 de CEL a 0 meses |
| `(3, 6]` | `CEL015`, `EMA015` | **ninguna** |
| `(6, 12]` | `EMA016` | las de 8 meses |
| `(12, 24]` | `CEL017`, `EMA017` | solo las 7 000 de DIR a 15 meses |
| `> 24` | `CEL013`, `CEL014`, `EMA014` | **ninguna** |
| `<= 12` | `EMA010` | todas menos ninguna -> constante 100 |
| `<= 24` | `DIR007TO` | todas -> constante |

`DIR059` merece su propia linea: es una normalizacion min-max de la recencia de
la direccion contra el rango de recencias **de la persona**
(`Caracteristicas.txt:439-444`). Sale constante a `100.00` porque **ninguna
persona del mock tiene dos recencias distintas**: las 7 000 filas de 15 meses
pertenecen a personas que solo tienen filas de 15 meses. `valor1 = valor2`
siempre, y el legado devuelve 1 en ese caso.

---

## La causa, con cita

`seed_mock_matriz.sql:321` siembra **un literal**:

```sql
  CAST('2026-02-15' AS DATE)       AS fecha_contacto,
```

y `seed_mock_matriz.sql:245` hace lo mismo con `fecha_reporte`
(`CAST('2026-02-01' AS DATE)`).

Son exactamente la trampa que `CLAUDE.md` ya advierte y que aqui se materializa
dos veces:

> **Las fechas tienen que ser relativas, no literales.** El insumo calcula
> `meses_reporte` con `DATEDIFF(month, fecha, CURRENT_DATE)`, asi que un literal
> significa una cosa hoy y otra el mes que viene.

Hoy, 2026-10-14, ese literal vale 8 meses. En enero valdra 11 y `EMA016` dejara
de discriminar sola. Las unicas filas con otra recencia son las que
`seed_mock_matriz_ord.sql:233` siembra a `CURRENT_DATE` a proposito, que es la
forma correcta y la que hay que generalizar.

---

## Lo que se propone (no hecho: excede el alcance aprobado)

Derivar la recencia de un atributo estable de la fila, en meses **relativos**:

```sql
  DATEADD(month, -1 * CASE rpu.cod_dw_persona_ubic % 5
                        WHEN 0 THEN  1    -- ventana <= 3
                        WHEN 1 THEN  5    -- ventana (3, 6]
                        WHEN 2 THEN  9    -- ventana (6, 12]
                        WHEN 3 THEN 18    -- ventana (12, 24]
                        ELSE        30    -- ventana > 24
                      END, CURRENT_DATE)  AS fecha_contacto
```

Con `DATEADD` relativo el `DATEDIFF(month, ...)` devuelve **exactamente** esa N
cualquier dia del mes, asi que el score deja de derivar con el calendario. La
advertencia de `CLAUDE.md` sobre elegir N lejos de los umbrales aplica a los
literales, cuya N se mueve; con `DATEADD` no hace falta margen.

Falta ademas que **una misma persona** tenga filas en ventanas distintas, o
`DIR059` y todos los divisores por diferencia de ventanas seguiran degenerados.
Lo barato es variar tambien por `contact_type`, de modo que el correo, el fijo y
el celular de una persona caigan en ventanas distintas.

**Esto cambia la linea base de todo el tablero**, no solo de las once
caracteristicas: es decision de la mesa, no de esta tanda.

---

## Lo que si quedo hecho en esta tanda

Las once reescrituras contra el legado, verificadas una a una sobre el insumo
real del banco. Los valores crudos ya varian donde el mock se lo permite:

| | valores distintos | min | max |
|---|---|---|---|
| `DIR002TO` | 2 | 8 | 15 |
| `DIR007TO` | 5 | 1 | 10 |
| `DIR017` | 2 | 1 | 5 |
| `DIR019` | 2 | 0 | 1 |
| `DIR057` | 5 | 1 | 10 |
| `DIR009` | 2 | 0 | 1 |
| `DIR059` | **1** | 100,00 | 100,00 |
| `CEL006` | 2 | 0,00 | 50,00 |
| `CEL013`, `CEL014`, `CEL015`, `CEL017` | **1** | 0 | 0 |

Las cinco que salen con un solo valor son las de las ventanas vacias. Son
correctas; lo que falta es dato.
