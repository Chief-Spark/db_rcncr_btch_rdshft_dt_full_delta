# Hallazgos de la primera corrida del banco local

Fecha: 2026-10-14 · Herramienta: `dt/banco/` sobre PostgreSQL 16 ·
Alcance: los 112 archivos que despliega un job, 24 568 líneas

**Contexto en una línea: `[REDSHIFT:418]` tiene el despliegue bloqueado, Jenkins
era el único modo de ejecutar SQL de este proyecto, y 1 805 de esas líneas nunca
habían corrido ni una vez.**

Los hallazgos van separados en tres clases, y la separación es lo que hace útil
el documento. **Postgres no es Redshift**: es más permisivo en cinco formas y
más estricto en tres (`banco/README.md` las lista), así que una parte del ruido
que produce no es un defecto del código.

---

## Clase REAL — defectos del código, encontrados por ejecución

### 1. La evidencia de `R2-07` no cabía en su columna · CORREGIDO

`strct/.../13_ddl_cert_criterios.sql:151` · literal de **688 caracteres** contra
`evidencia VARCHAR(500)`.

Se escribió en la tanda de `D9` y **nunca llegó a desplegarse**: el job #353
murió en `[REDSHIFT:418]` antes de ejecutar una sentencia. Habría tumbado el
siguiente build con `[REDSHIFT:112]`, que es lo único que hoy tumba el pipeline.
Reescrito en 487 caracteres sin perder las dos divergencias de `GOB-03`.

**La trampa general, que vale para todo el repo:** `CREATE TABLE IF NOT EXISTS`
esconde este error. Si la tabla ya existe en DEV con la columna ancha de una
versión anterior, el `INSERT` pasa — y falla en el primer despliegue sobre
ambiente limpio, que es QA, UAT o producción. Anotado en los tres `CLAUDE.md`.

### 2. El `detalle` de `CA-F03` desbordaba justo cuando el criterio falla · CORREGIDO

`pgm/.../sp_cert_evaluar_criterios_ord_mock.sql:616` · el `detalle` concatena el
encabezado, un `LISTAGG` sobre los arquetipos que no cuadran y una nota de ~250
caracteres, contra `detalle VARCHAR(1024)`. Con los cinco arquetipos de hoy
aterriza en ~780.

**Lo que importa es cuándo desbordaría:** el `LISTAGG` solo crece cuando los
deltas NO cuadran. O sea que el evaluador se caería con `[REDSHIFT:112]`
exactamente en la corrida en que hace falta leer el detalle, en vez de reportar
`FAILED`. Envuelto en `SUBSTRING(..., 1, 1024)`, el mismo patrón que ya usaba la
línea 521. Con los valores de hoy no cambia un carácter.

---

## Clase REAL — vista, no corregida (fuera del alcance acordado)

### 3. El mismo desborde, en el gate por arquetipo de Unificación

`pgm/.../sp_unificacion_mock_gate_arq.sql:180-196` · el `detalle` de `CA-U01`
hace `LISTAGG` sobre **todos** los arquetipos que no cuadran, sin guarda, contra
`detalle VARCHAR(1024)`.

**Observado, no supuesto.** En la corrida en que el motor NIT se cayó por otra
causa, muchos arquetipos quedaron descuadrados, el `LISTAGG` creció y el gate
murió con `value too long for type character varying(1024)` en vez de reportar
`FAILED`. Mismo patrón que el 2: el diagnóstico se pierde cuando más se
necesita.

Es una línea (`SUBSTRING(..., 1, 1024)`) y no cambia nada mientras el gate pase.
**No se aplica porque Unificación quedó fuera del alcance de esta tanda.** Queda
aquí para que sea una decisión y no un olvido.

### 4. DDL que el propio deploy destruye y no repone

`strct/.../01_ddl_ordenamiento.sql` crea cinco tablas que
`04_vistas_insumo_ordenamiento_edf_views.sql:44-55` **borra tres archivos
después**, en el refactor "no copiar el universo XPM" que su cabecera anuncia.
Cuatro vuelven como vista con el mismo nombre; la quinta no:

| Objeto | Qué queda tras el deploy |
|---|---|
| `bdm_datos.insumo_{direccion,telefono,celular,email}` | vista (`04:59` y siguientes) |
| `bdm_datos.relacion_persona_ubicacion` | **no existe** |

Nadie la lee —`16_sp_unificacion_ciclo.sql:317` anota justamente que no existe en
el consumidor DEV— así que es inocuo. Pero son cinco `CREATE TABLE` de DDL
muerto que se ejecutan en cada despliegue, y el verificador del banco los señala
cada vez. Limpiar exige cuidado: los `DROP` de `04` tienen que quedarse para los
ambientes que todavía tengan las tablas viejas.

---

## Clase HUECO_DEL_BANCO — el código era correcto

Se listan porque la tentación de "arreglar" el repo para contentar a Postgres es
real, y es la peor cosa que puede pasarle a esta herramienta.

| Síntoma | Por qué el código está bien |
|---|---|
| `column "year" does not exist` en `DATE_PART(year, f)` | Redshift admite la unidad como **palabra desnuda**, igual que en `DATEADD`. Es la forma que usa la traducción de `CAST(fecha AS INTEGER)`, la trampa ya pagada. Faltaba la regla T9 del transpilador. 24 sitios |
| `function getdate() does not exist` | `CREATE DATABASE ... TEMPLATE` no copia los ajustes por base, así que al restaurar una foto el `search_path` perdía el esquema de los shims |
| `relation "bdm_datos.geo_atributos" does not exist` al crear una vista | Redshift tiene **enlace tardío** (`WITH NO SCHEMA BINDING`): `02` puede referenciar lo que crea `03`. Por eso la fase `strct` da varias pasadas y su veredicto lo da el estado final, no archivo a archivo |
| `"insumo_direccion" is not a table` | En Redshift `DROP TABLE IF EXISTS` sobre una vista es un **no-op**; en Postgres es un error. `04:44-55` se apoya en ese no-op y lo explica en un comentario |
| La Regla 1 tardaba **más de cuatro minutos** en su primer CTAS | Unificación tiene **93 CTAS y cero `ANALYZE`**; Redshift sobrevive por fuerza bruta columnar y Postgres en un nodo no. El banco pone `ANALYZE` e índices de su lado: el mismo tramo baja a minuto y medio |

Y una comprobación que valía la pena hacer: Postgres trunca los identificadores a
**63 bytes** y Redshift admite 127. En los tres repos hay **13 identificadores
que pasan de 63** —el más largo, 80— y **cero colisiones al truncar**. El banco
no está confundiendo dos objetos en uno.

---

## Lo que el banco ya dejó verificado

| | |
|---|---|
| DDL de `strct` | los **80 objetos** existen al terminar la fase |
| Procedimientos de `pgm` | **74/74 se crean**, y Postgres compila el cuerpo PL/pgSQL — justo lo que Redshift no hace hasta la primera invocación |
| `reset_mock` + las cuatro semillas | corren limpias, 164 000 RPU sembradas |
| `rs.fnv_hash` | coincide **bit a bit** con FNV-1a de 64 bits de referencia, cadena vacía incluida: los identificadores generados en local son los de Redshift |

**Y lo que no deja verificado, que hay que repetir cada vez: un verde del banco
no certifica.** Degrada un `[REDSHIFT:112]` de "desconocido" a "específico de
Redshift". Jenkins sigue siendo el único que certifica.
