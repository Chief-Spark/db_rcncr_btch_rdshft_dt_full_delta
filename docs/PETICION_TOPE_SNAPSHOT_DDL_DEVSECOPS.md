# Petición a DevSecOps — el snapshot DDL aborta en 1.200 celdas y tumba builds verdes

*Redactada para enviarse tal cual. Fecha: 2026-11-16. Ticket: SLCOPRBA-1449.*

## Qué pedimos

Tres cosas, en este orden de prioridad:

1. **Subir o eliminar el tope de 1.200 celdas** de la sección `COLUMN` del
   snapshot DDL, o paginar la tabla en lugar de abortar.
2. **Que un fallo al generar el snapshot no tumbe el build.** Es un paso de
   *evidencia*, no de despliegue: hoy marca `FAILURE` un DPLY que salió entero
   en verde, y eso enmascara el resultado real del despliegue.
3. Si (1) no es posible a corto plazo, decirnos **qué objetos cuenta la
   sección `COLUMN`** (el catálogo completo de los esquemas, o sólo los objetos
   que toca el paquete). De eso depende si podemos hacer algo desde el
   repositorio o no.

## Evidencia: el error exacto

Despliegue de `struct` en DEV, pipeline DATABASE, 2026-11-16. **Los 51 scripts
del paquete se ejecutaron correctamente**, incluidos los dos nuevos de ese
commit:

```
[REDSHIFT:315] Script 'SQL/11e_ddl_unif_alcance_censo.sql' ejecutado correctamente
[REDSHIFT:315] Script 'SQL/11f_ddl_unif_alcance_censo_mock.sql' ejecutado correctamente
```

Y el build murió **después**, en la verificación controlada:

```
[REDSHIFT:340] Error en snapshot DDL_2 sección COLUMN: Cannot add cell to
               table content: total cell count of 1200 exceeded.
[REDSHIFT:340] La verificación controlada falló. Los snapshots generados se
               archivarán para revisión.
ERROR: [REDSHIFT:330] Error generando snapshot 'DDL_2' en la sección 'COLUMN'
Finished: FAILURE
```

El mensaje *"Cannot add cell to table content"* no es de Amazon Redshift: es de
la librería de tablas con la que el pipeline renderiza el snapshot, y `1200` es
un tope duro de esa librería.

## Dónde cae, y por qué importa

El ciclo controlado es:

```
RLLBCK_PRECHECK → DDL_1 → DPLY → DDL_2 → RLLBCK_FINAL → DDL_3 → compare → DPLY
```

El fallo es en **`DDL_2`**, inmediatamente después del primer `DPLY`. Las
consecuencias, que es lo que nos obliga a escalarlo:

| Hecho | Consecuencia |
|---|---|
| El primer `DPLY` completó los 51 scripts | **los objetos quedaron en DEV** |
| `RLLBCK_FINAL` no llegó a correr | **nada se revirtió**: el ambiente quedó con el paquete aplicado |
| El segundo `DPLY` no corrió | este build **no tiene prueba de rollback** |
| El build figura como `FAILURE` | el expediente de QA no refleja que el despliegue sí funcionó |

O sea: **un despliegue correcto queda registrado como fallido, y el ambiente
queda en un estado intermedio que el propio pipeline no verificó.**

## El dato que acota el tope, y es medición y no estimación

`DDL_1` se generó **sin error** y `DDL_2` falló: mismo renderizador, misma
sección, mismo esquema. Lo único que ocurrió entre los dos fue el `DPLY`, que
añadió **dos tablas de 13 columnas cada una — 26 columnas en total**.

De modo que el total que la herramienta cuenta estaba:

| | Celdas en la sección `COLUMN` |
|---|---|
| Antes del `DPLY` (DDL_1, correcto) | **≤ 1.200** |
| Después del `DPLY` (DDL_2, aborta) | **> 1.200** |
| Delta introducido por el paquete | **+26 columnas** |

Es decir, el esquema ya estaba **entre 1.175 y 1.200**, pegado al tope, antes
de nuestro commit. No es que nuestras dos tablas sean grandes: es que **el
margen restante era de menos de 26 columnas**.

## Por qué no se puede resolver desde el repositorio

Tres razones, y la tercera es la que más debería pesar:

1. **Recortar nuestras 26 columnas devuelve el catálogo exactamente al borde**
   (1.200), que es el peor sitio donde dejarlo: el siguiente `CREATE TABLE` o
   `ALTER TABLE` de cualquiera vuelve a romper el build.
2. El esquema `struct` de este proyecto declara hoy **108 tablas y ~1.264
   columnas** en sus `CREATE TABLE`. Cualquier evolución normal del modelo
   cruza el tope.
3. **`bdm_datos` es un esquema compartido.** Si la sección `COLUMN` cuenta el
   catálogo de los esquemas y no sólo los objetos del paquete, entonces **un
   equipo ajeno puede tumbar nuestros builds creando una tabla suya**, y
   nosotros los de ellos. El log culparía al paquete que pasara por ahí
   después, no al que cruzó el límite.

## Cómo se verifica que está resuelto

Relanzar el despliegue de `struct` sobre el mismo commit. Esperado:

```
[REDSHIFT:330]  (ausente)
DDL_1 vs DDL_2  sin diferencias
Rollback de prueba exitoso para 'struct'
Finished: SUCCESS
```

Y, para el punto (2) de la petición, que un fallo del snapshot imprima el aviso
pero deje el build en `SUCCESS` o `UNSTABLE`, no en `FAILURE`.

## Contexto para quien reciba esto

Es el **tercer** bloqueo de este proyecto que no está en el código SQL sino en
un paso del pipeline o en un alta de DevSecOps:

| Código | Qué era | Estado |
|---|---|---|
| `[REDSHIFT:419]` | el detector caía en silencio a la ruta legacy | escalado |
| `[REDSHIFT:156]` | los repos `DB_DS_*` sin onboarding Redshift | `PETICION_ONBOARDING_REDSHIFT_DEVSECOPS.md` |
| `[REDSHIFT:330/340]` | este | **esta petición** |

Los tres comparten la misma forma: el paquete valida y despliega bien, y el
build muere en un paso que no es el despliegue.
