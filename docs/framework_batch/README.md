# Prueba del Framework Batch contra dato real en DEV

Los cuatro archivos de la primera prueba de la cadena real lanzada **desde el
Framework** (no desde `deploy.par`). Detalle y el bloqueo abierto, en la seccion
"El Framework Batch contra dato real" de `CLAUDE.md`.

| Archivo | Donde va | Para que |
|---|---|---|
| `PE1353.yml` | **raiz** de `<stage>-<cuenta>-fwdynbtch-dynamic-batch-definition-repository` | los tres niveles secuenciales: Unificacion, Ordenamiento, Novedades |
| `reconocerfullval1-20261028-2610.val` | carpeta `PE1353/` de `...-dynamic-batch-source-repository` | es el disparador, y su NOMBRE lleva los parametros |
| `drilldown_qa.sql` | no se sube: se corre en DBeaver | nueve consultas de Niveles 0/1/2 con la cifra de DEV al lado para comparar |
| `ddl_7_mat_real.sql` | no se sube: es referencia | el DDL de las siete MAT tal como quedaron en Redshift real |

**El YAML primero y el `.val` de ultimo**, porque el `.val` es lo que arranca la
Step Function.

**`PE1353` es una propuesta, no el codigo asignado.** El `product_id` sale de la
carpeta y tiene que casar con el nombre del YAML: si el codigo oficial es otro,
se renombran los dos a la vez.

**Para mandar un DELTA solo cambia el nombre del `.val`**
(`reconocerdeltaval2-20261029-2610.val`): `fw_resolver_param` decide el MODO por
lo que el mnemotecnico CONTIENE. El YAML no se toca.
