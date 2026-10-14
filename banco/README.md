# banco -- replica local del job de Jenkins, sobre PostgreSQL 16

**Lo primero, porque es lo que se malinterpreta: un verde del banco NO es una
certificacion.** Degrada un `[REDSHIFT:112]` de "desconocido" a "especifico de
Redshift". Nada mas, y ya es mucho.

Existe por una razon concreta, que `CLAUDE.md` nombra:
**`CREATE OR REPLACE PROCEDURE` no compila el cuerpo en Redshift; los errores
salen en la primera invocacion.** Un procedimiento de 824 lineas puede estar en
un repo verde sin que nadie haya probado que corre. Postgres si compila el
cuerpo al crearlo, y ademas lo ejecuta.

No se traslada al cliente: el traslado a Bitbucket copia solo
`deploy/redshift`. Esta carpeta y `validar.sh` viven en la raiz.

## Uso

```
./banco.sh init nueva      # cluster limpio, shims y stub del datashare
./banco.sh fase strct      # el DDL
./banco.sh foto tras_strct # guarda el estado como plantilla
./banco.sh fase pgm        # los 74 procedimientos
./banco.sh foto tras_pgm
./banco.sh fase dt         # semillas, cascada e2e y tableros
./banco.sh desde tras_pgm  # vuelve atras en ~2 s para re-correr dt
./banco.sh psql            # consola
```

**Una foto guarda los PROCEDIMIENTOS YA CREADOS, con el cuerpo que tenian al
tomarla.** Si cambia `transpila.py` o `shims.sql`, la foto queda obsoleta: hay
que volver a correr `fase pgm` y re-fotografiar. El banco guarda la huella de
las dos piezas junto a la foto y avisa al restaurar. Costo veinte minutos
aprenderlo con `DATE_PART(year, x)`.

Errores en `out/errores.tsv`: `fase | archivo | linea | sqlstate | clase |
mensaje`. La **linea es la del archivo original del repo**, no la del
transpilado: el transpilador conserva el numero de saltos de linea a proposito,
justo para que no haga falta mantener un mapa.

## Las piezas

| Archivo | Que hace |
|---|---|
| `banco.sh` | arranca el cluster y ejecuta los tres `deploy.par` en orden |
| `transpila.py` | las 8 reglas Redshift -> Postgres. Su cabecera explica cada una |
| `shims.sql` | `rs.fnv_hash`, `rs.getdate`, `rs.dateadd`, `rs.datediff`, `rs.len`, `rs.trunc` |
| `stub_datashare.py` | deriva las 4 tablas de `edf_views` de los cuerpos de las vistas |
| `verifica.py` | comprueba que al terminar una fase **existen** todos los objetos |

`fnv_hash` se comprobo contra una implementacion de referencia de FNV-1a de 64
bits: coincide bit a bit, cadena vacia incluida. Los identificadores generados
en local son los mismos que generaria Redshift.

## Donde acaba la autoridad de cada capa

| Capa | Prueba | NO prueba |
|---|---|---|
| `validar.sh` | higiene de Redshift: BOM, ASCII, `$$`, parentesis, paridad de los `.par`, `WHERE` en `UPDATE`/`DELETE`, `LISTAGG` con el mismo `WITHIN GROUP` | que algo corra |
| transpilado | que los Redshift-ismos estan **reconocidos y localizados** (cuenta por regla) | que la forma Redshift sea legal |
| fases `strct` / `pgm` | que cada sentencia DDL parsea y cada cuerpo PL/pgSQL compila | las reglas de parseo propias de Redshift |
| fase `dt` | que la cascada **ejecuta**, los gates evaluan y la aritmetica reproduce | distribucion, orden, y la lista de abajo |
| Jenkins | **lo unico que certifica** | nada esta por encima |

**Postgres es mas PERMISIVO que Redshift** en al menos cinco formas, asi que un
verde local puede caer igual en Jenkins:

- `generate_series` aqui corre en cualquier nodo; en Redshift es solo de nodo
  lider.
- aqui cada `LISTAGG` puede llevar su propio `WITHIN GROUP`; en Redshift todos
  los del MISMO `SELECT` tienen que compartirlo (tumbo el job #341).
- aqui `EXISTS` vale en la lista del `SELECT`; en Redshift no.
- aqui no hay `DISTKEY`, asi que no se detecta que en Redshift tiene que ser una
  columna de la lista del `SELECT` (job #315).
- aqui el tipo de un `UNION ALL` se negocia entre ramas; en Redshift lo fija el
  `CAST` de la primera.

**Y es mas ESTRICTO en tres**, que producen ruido que NO son hallazgos:

- no hay vistas de enlace tardio. Al desaparecer `WITH NO SCHEMA BINDING`,
  Postgres exige el orden de dependencias que Redshift tolera: por eso la fase
  `strct` da varias pasadas y por eso el veredicto de esa fase lo da
  `verifica.py` sobre el estado final, no archivo a archivo.
- `DROP TABLE IF EXISTS` sobre una **vista** aqui falla con "is not a table";
  en Redshift es un no-op. `04_vistas_insumo_ordenamiento_edf_views.sql:44-55`
  se apoya en ese no-op, y lo dice en un comentario.
- un `CALL` que falla hace rollback completo; en Redshift, `NONATOMIC`, no.
  O sea: el staging desaparece tras un fallo y no se puede hacer la autopsia
  en caliente.

Dos divergencias mas, deliberadas y anotadas:

- **`GETDATE()` es `clock_timestamp()`, no `now()`.** En Redshift la cadena de
  `CALL` es `NONATOMIC` y el reloj avanza por sentencia; con `now()` el tiempo
  se congelaria en toda la fase y `DATEDIFF(second, inicio, fin)` daria 0 en la
  traza. El precio es que dos `GETDATE()` de la misma sentencia pueden diferir,
  cosa que en Redshift no pasaria.
- **Postgres trunca los identificadores a 63 bytes**, Redshift admite 127. En
  los tres repos hay **13 identificadores que pasan de 63** (el mas largo, 80:
  `bdm_tempo.sp_unificacion_mock_r2_esc1_complemento_vacio_esc2_substring_complemento_persist`)
  y dos columnas del relationalize. **Verificado: cero colisiones al truncar**,
  asi que Postgres no esta aliasando dos objetos distintos en uno. No rompe nada
  porque trunca igual la definicion y la referencia, pero si se anade un nombre
  cuyos primeros 63 caracteres coincidan con otro, el banco los confundiria en
  silencio. Para Redshift ninguno es problema: el mas largo esta a 80 de 127.

## El ANALYZE que el banco pone y el repo no

Unificacion tiene **93 `CREATE TABLE AS` y cero `ANALYZE`**; Ordenamiento tiene
13 y 13. Redshift sobrevive a esa ausencia por fuerza bruta columnar. Postgres
en un solo nodo, sin estadisticas, se queda **minutos** en el primer self-join
de la Regla 2. El banco corre `ANALYZE` tras sembrar, del lado de la
herramienta.

Es compensacion del motor, no un parche al repo: el `ANALYZE` que falta esta
anotado como hallazgo y fuera del alcance de esta tanda. Pero el banco lo midio,
y eso vale como argumento.

## La disciplina, que es lo que hace util a la herramienta

**Un fallo local es una HIPOTESIS hasta que se traza al legado o a la
documentacion de Redshift. Nunca cambiar codigo correcto en Redshift para
contentar a Postgres.** Las tres estrictezes de arriba son exactamente la clase
de cosa que invita a "arreglar" algo que no esta roto.
