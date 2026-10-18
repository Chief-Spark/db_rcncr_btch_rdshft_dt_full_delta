# Pipeline MOCK en Framework Batch — identificadores registrados

**SLCOPRBA-1355.** Los tres nombres que hay que mantener sincronizados para
disparar Unificación → Ordenamiento → Novedades con datos mock desde el
Framework Batch, y qué está verificado y qué no.

> Este documento vive en `docs/`, que **no viaja a Bitbucket** a propósito: el
> traslado lleva solo `deploy/redshift/`. El YAML tampoco es parte del paquete
> de Redshift — va a S3, no al repo de despliegue.

---

## 1. Los tres identificadores

Los tres tienen que coincidir o el job no arranca, y falla en silencio: no hay
error visible, simplemente no se dispara.

| Pieza | Valor | Dónde va |
|---|---|---|
| **Mnemotécnico** | `reconocermockval` | fila en `mnemotecnicos.csv`, tabla de resolución NIT |
| **NIT** | `123456789` | misma fila |
| **YAML** | `PP9999reconocermock.yaml` | bucket de **definiciones**, en la raíz |
| **Carpeta del `.val`** | `PP9999reconocermock/` | bucket de **source** |
| **`directorio.ruta`** | `PP9999reconocermock` | dentro del YAML — **es** el nombre de la carpeta |

La fila del CSV, con el formato del fichero (`"mnemotécnico","nit","descripción"`):

```
"reconocermockval","123456789","RECONOCER BATCH - MOCK EXTREMO A EXTREMO"
```

**Por qué `123456789` y no `999999999`:** `reconocerval` ya usa ese NIT y una
fila duplicada deja la resolución ambigua. Se eligió uno que **empieza por 1**
porque las personas jurídicas colombianas empiezan por 8 o 9 — los 16 NIT
reales del fichero lo confirman —, de modo que no puede colisionar con una
empresa real.

**Por qué el sufijo `val`:** todos los mnemotécnicos del CSV terminan así, y es
la extensión del archivo disparador.

---

## 2. Los SP que invoca, y por qué esos y no otros

| Nivel | SP | Firma |
|---|---|---|
| 0 | `bdm_datos.sp_unificacion_mock_ciclo` | 6 VARCHAR ✔ |
| 1 | `bdm_datos.sp_ordenamiento_ejecucion_mock` | 6 VARCHAR ✔ |
| 2 | `bdm_datos.sp_novedades_mock_ciclo` | 6 VARCHAR ✔ |

**No se invocan las reglas sueltas.** `sp_unificacion_mock_regla1/2/3` llevan
`(p_modo VARCHAR, p_lote INTEGER, p_watermark DATE)` y el Framework no puede
llamarlas; `sp_unificacion_mock_ciclo` ya las encadena por dentro. No hacen
falta wrappers.

**Cuidado con los nombres parecidos:** `sp_ordenamiento_ciclo` es el **real**,
no el mock. El mock es `sp_ordenamiento_ejecucion_mock`.

**El orden no es negociable.** Novedades va después de Ordenamiento porque su
etapa 1 filtra por orden de prioridad no nulo (`Novedad.sql:7593`). Al revés
saldría vacío por un efecto de secuencia y no por un defecto — la misma
lección que el ciclo GEO.

---

## 3. Dos cosas que este pipeline NO cubre

**GEO queda fuera.** Su ciclo mock es `sp_cert_geo_mock()`, sin parámetros, y
el Framework no puede invocarlo. El único GEO con firma válida es
`bdm_stage.sp_geo_ciclo_lote`, que es el real y hace `UNLOAD` a S3 con un rol
IAM que no está asociado al clúster DEV. Entraría con un wrapper de 6 VARCHAR.

**El reset, las semillas y los tableros tampoco.** `reset_mock.sql`, los cuatro
`seed_mock_*.sql` y las validaciones **no son procedimientos**, así que no
caben en el YAML. Sin reset ni semilla, el nivel 0 corre sobre lo que hubiera;
sin tableros, no hay evidencia de QA. Hoy eso solo lo da el job `dt`.

Dicho de otro modo: **este YAML ejecuta el proceso, no lo certifica.**

---

## 4. EL RIESGO QUE HAY QUE RESOLVER ANTES DE DISPARAR

**Nuestros SP leen `in_nemotecnico` como MODO, no como mnemotécnico.**

`12_fn_unif_resolver_param.sql:33-37`:

- vacío o NULL → asume `FULL`
- **cualquier otro valor** → lo pasa en mayúsculas al orquestador, que valida
  que sea `FULL` o `DELTA`

Si el Framework mete `reconocermockval` en ese parámetro, el ciclo se cae por
MODO inválido aunque el CSV, el YAML y la carpeta estén perfectos.

**Hay que confirmar con quien tenga la guía de despliegue qué valor manda el
Framework en `in_nemotecnico`.** Si manda el mnemotécnico, hace falta un
wrapper que traduzca; si lo deja vacío, entra por el default `FULL` y funciona.

---

## 5. Qué está verificado y qué es inferencia

Conviene separarlo porque equivocarse aquí da un job que no arranca, no un
error legible.

| Afirmación | Estado |
|---|---|
| Los tres SP tienen la firma de 6 VARCHAR | **verificado** en el repo `pgm` |
| Las reglas sueltas llevan otra firma | **verificado** |
| `in_nemotecnico` se interpreta como MODO | **verificado** (`12_fn_unif_resolver_param.sql`) |
| El disparo es un `.val` en S3; hay buckets *source* y *definition* separados | **documentado** (`contexto_reconocer/03_FRAMEWORK_BATCH.md`) |
| La carpeta del `.val` es exactamente `directorio.ruta` | **inferencia** — se apoya en que el `SourceValidator` valida "YAML + archivos S3" y `ruta` es el único campo que dice dónde |
| El `.val` se llama como el mnemotécnico | **inferencia** — se apoya en el sufijo `val` de todos los mnemotécnicos |
| El YAML va en la raíz del bucket de definiciones | **inferencia** — el documento dice "YAML en S3 definition repository" sin más detalle |

**La regla exacta está en `proyecto/orquestacion/despliegue_framework_batch_reconocer.md`, que no está en estos repos.**
Si alguien del equipo lo tiene, confirmar las tres inferencias antes de subir.
Y si el bucket de definiciones ya tiene otros YAML, copiar el patrón de los
existentes vale más que cualquiera de ellas.
