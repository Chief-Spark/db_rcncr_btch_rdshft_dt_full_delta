# Petición a DevSecOps — el snapshot DDL aborta en 1.200 celdas y marca FAILURE un despliegue correcto

*Redactada para enviarse tal cual. Fecha: 2026-11-16. Ticket: SLCOPRBA-1449.*

## Qué pedimos

**Que un fallo al generar el snapshot DDL no marque el build como `FAILURE`.**
Es un paso de *evidencia*, no de despliegue. Hoy, cuando falla, deja el
ambiente **desplegado y sin verificar** y el expediente de QA dice que el
despliegue falló cuando en realidad funcionó entero.

Y en segundo lugar, **subir o paginar el tope de 1.200 celdas** de la sección
`COLUMN`, en lugar de abortar.

**Lo que NO pedimos: no es un bloqueo para nosotros.** Ya lo resolvimos desde
el repositorio recortando columnas (abajo está cómo). Lo levantamos porque el
modo de fallo es malo para cualquier equipo que lo cruce, no porque nos tenga
parados.

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
un tope duro de esa librería. No es un límite de la base de datos — Redshift
topa en 1.600 columnas **por tabla** y no tiene tope por esquema.

## Por qué el modo de fallo es el problema, y no el tope

El ciclo controlado es:

```
RLLBCK_PRECHECK → DDL_1 → DPLY → DDL_2 → RLLBCK_FINAL → DDL_3 → compare → DPLY
```

El fallo es en **`DDL_2`**, inmediatamente después del primer `DPLY`:

| Hecho | Consecuencia |
|---|---|
| El primer `DPLY` completó los 51 scripts | **los objetos quedaron en DEV** |
| `RLLBCK_FINAL` no llegó a correr | **nada se revirtió** |
| El segundo `DPLY` no corrió | este build **no tiene prueba de rollback** |
| El build figura `FAILURE` | QA no refleja que el despliegue sí funcionó |

O sea: **un despliegue correcto queda registrado como fallido, y el ambiente
queda en un estado intermedio que el propio pipeline no verificó.** Eso es más
caro que el tope en sí: un `FAILURE` que no distingue "no se desplegó" de "se
desplegó y no se pudo documentar" obliga a reconstruir a mano qué quedó aplicado.

## El tope está medido: son celdas = columnas del paquete, y nosotros sobrábamos por 19

Dos mediciones nuestras, por si les sirven para dimensionarlo:

**1. El tope es por paquete, no del esquema compartido.** El paquete `program`
del mismo proyecto desplegó **en verde contra el mismo catálogo**, mismo
cluster y mismos esquemas, con las tablas nuevas ya dentro. Si la sección
`COLUMN` inventariara el esquema, habría fallado igual.

**2. `1 columna = 1 celda`**, y el modelo predice los dos resultados sin
ajustar nada:

| | Columnas declaradas por el paquete | Snapshot |
|---|---|---|
| Antes del `DPLY` (`DDL_1`) | **1.193** | verde (≤ 1.200) |
| Después del `DPLY` (`DDL_2`) | **1.219** | rojo (> 1.200) |

## Cómo lo resolvimos de nuestro lado

Auditamos las 108 tablas del paquete contra los tres repositorios del proyecto
y encontramos **siete sin un solo escritor ni un solo lector**: cuatro tablas
residuo de un diseño anterior y tres mock que nadie llenaba. Borradas, el
paquete pasa de **1.219 a 1.157 columnas**, con 43 de margen.

**Y al hacerlo encontramos un defecto latente que el tope nos obligó a mirar:**
esas cuatro tablas estaban declaradas con el **mismo nombre** que cuatro vistas
del mismo paquete. En un ambiente donde el nombre ya existía, el
`CREATE TABLE IF NOT EXISTS` no hacía nada y el `CREATE OR REPLACE VIEW`
funcionaba; **en un ambiente limpio el despliegue habría fallado**. Lo
menciono porque es el argumento a favor de (1): el snapshot es evidencia útil,
y vale la pena que no se pierda por un tope de renderizado.

## Cómo se verifica que está resuelto

Relanzar el despliegue de `struct`. Esperado:

```
[REDSHIFT:330]  (ausente)
DDL_1 vs DDL_2  sin diferencias
Rollback de prueba exitoso para 'struct'
Finished: SUCCESS
```

Y para el punto (1): que un fallo del snapshot imprima el aviso pero deje el
build en `SUCCESS` o `UNSTABLE`, nunca en `FAILURE`.

## Contexto para quien reciba esto

Es el **tercer** asunto de este proyecto que no está en el código SQL sino en
un paso del pipeline o en un alta de DevSecOps:

| Código | Qué era | Estado |
|---|---|---|
| `[REDSHIFT:419]` | el detector caía en silencio a la ruta legacy | escalado |
| `[REDSHIFT:156]` | los repos `DB_DS_*` sin onboarding Redshift | `PETICION_ONBOARDING_REDSHIFT_DEVSECOPS.md` |
| `[REDSHIFT:330/340]` | este | **esta petición**, no bloqueante |
