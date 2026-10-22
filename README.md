# Reconocer Redshift — paquete DT (datos y ejecución)

Unificación de direcciones, Ordenamiento, GEO y Novedades de Experian
Reconocer, migrados de Teradata a Amazon Redshift.

**`type: data` · `order: 3` · se despliega el ÚLTIMO de los tres.**

Semillas, corridas y validaciones. **Es el que produce la evidencia de QA**, y
el único cuyo despliegue ejecuta lógica de negocio.

## Qué hay en el paquete

| Ruta | Contenido |
|---|---|
| `deploy/redshift/SLCOPRBA-1353/deploy.par` | 17 líneas, y el orden importa |
| `deploy/redshift/SLCOPRBA-1353/SQL/` | migraciones, semillas, corridas y tableros |
| `deploy/redshift/SLCOPRBA-1353/rollback.par` | el reverso exacto, en orden inverso |

## Qué hace el despliegue, en orden

| Líneas | Qué |
|---|---|
| 1–3 | migraciones de esquema sobre lo ya desplegado |
| 4–8 | reset y siembra del mock |
| 9–15 | la batería: FULL, DELTA1, mutación, DELTA2, convergencia, ciclo GEO y los tres tableros |
| 16 | **el gate** — `run_cert_asercion_final.sql`. Un FAILED aquí tumba el build |
| 17 | **la cadena real** — `run_reconocer_e2e_real_full.sql`, sobre el datashare |

**El mock y la vía real no comparten datos, sólo el turno.** El mock vive en
tablas `*_mock` sembradas por el propio paquete; la real lee el datashare de
EDF y escribe `bdm_datos.mat_*`. La real va la última, entera y detrás del
gate: así el gate sigue decidiendo sobre mock y la última escritura sobre las
tablas compartidas es la de la corrida real.

**La medida del proyecto está al final del log**: el conteo de filas de las
siete tablas dominio, que es lo que explota el Batch.

## Lo que hay que saber antes de leer un verde

- **La batería corre DOS VECES**: el ciclo controlado de Jenkins ejecuta el
  stage de despliegue dos veces sobre el mismo clúster. Todo lo que una corrida
  escribe y el reset no borra sobrevive de una pasada a la otra.
- **Un DELTA en cero no prueba que no haya cambios.** Antes de dar por buena
  una rama vacía hay que comparar el rango del dato con el watermark.
- **La certificación es con datos mock.** Lo que la línea 17 añade es que la
  vía real corra y entregue filas, no que su contenido esté conciliado contra
  Teradata.

## Convenciones que el pipeline exige

| Código | Causa |
|---|---|
| `REDSHIFT:112` | error SQL durante el deploy — es lo único que tumba el build |
| `REDSHIFT:207` | BOM en un `.par` — van en UTF-8 **sin** BOM |
| `REDSHIFT:219` | un archivo de `RevSQL/` con basename distinto al de `rollback.par` |
| `REDSHIFT:232` | `UPDATE`/`DELETE` de nivel superior sin `WHERE` |
| `JENKINS:104/105` | rama sin el ID de la subtarea |

## De dónde sale esto

Este repositorio es **sólo de despliegue**. El trabajo, la bitácora de
divergencias contra el legado, el banco de pruebas local y los validadores
viven en el repositorio de GitHub del equipo; aquí llega únicamente
`deploy/redshift/` y este `.jenkins.yml`.
