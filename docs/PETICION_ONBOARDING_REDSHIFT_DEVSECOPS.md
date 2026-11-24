# Petición a DevSecOps — onboarding Redshift de los tres repos `DB_DS_*`

*Redactada para enviarse tal cual. Fecha: 2026-10-22.*

## Qué pedimos

Dar de alta el **onboarding Redshift** de estos tres repositorios del proyecto
`COAWSPPR`, que hoy no lo tienen:

| Repositorio | `type` | `order` |
|---|---|---|
| `COAWSPPR/DB_DS_RCNCR_BTCH_RDSHFT_STRCT` | `struct` | 1 |
| `COAWSPPR/DB_DS_RCNCR_BTCH_RDSHFT_PGM` | `program` | 2 |
| `COAWSPPR/DB_DS_RCNCR_BTCH_RDSHFT_DT` | `data` | 3 |

Los tres despliegan contra el consumidor **`dba_rncr_batch`** (datashare
`ds_dba_rncr_batch`), que es el mismo `application` que ya usan los
repositorios anteriores del proyecto Reconocer, **ya onboardeados y
desplegando en DEV desde hace meses**. Lo más rápido para ustedes es
probablemente clonar esa configuración.

## Evidencia: el error exacto

Job **DEV/DATABASE #451**, rama
`feature/SLCOPRBA-1444-strct-full-delta-real`:

```
[REDSHIFT:151] Validando onboarding Redshift para 'COAWSPPR/DB_DS_RCNCR_BTCH_RDSHFT_STRCT'
ERROR: [REDSHIFT:156] El repositorio COAWSPPR/DB_DS_RCNCR_BTCH_RDSHFT_STRCT
       no tiene onboarding Redshift en DevSecOps
```

El fallo ocurre en `redshiftValidateRuntime()`, **después** de que el paquete
se haya detectado y validado entero:

```
[BITBUCKET:414] Paquete temporal Redshift generado en
                'REDSHIFT_451/deploy/redshift/SLCOPRBA-1353' con 49 script(s)
[REDSHIFT:208]  Changeset preparado para 'develop'
[REDSHIFT:210]  Scripts deploy: 49
[REDSHIFT:211]  Rollback disponible: 'true'
[REDSHIFT:215]  Scripts rollback: 49
```

O sea: **el paquete está bien y el pipeline es el correcto**; sólo falta el
registro. Ninguna sentencia SQL llegó a ejecutarse y el clúster de DEV no se
tocó.

## Por qué son repos nuevos

Los tres se crearon para esta fase del proyecto y nacieron de la **plantilla
de Terraform** de EITS-SLA-CO. Ya corregimos de nuestro lado lo que dependía
del repositorio:

- `.jenkins.yml` con `tech: database`, `language: redshift`,
  `application: dba_rncr_batch` y el `type`/`order` de cada uno — sin esto el
  build se iba al pipeline TERRAFORM y moría en `SONARQUBE:101` (job
  DEV/TERRAFORM #74615);
- fuera las cinco carpetas de entorno de Terraform (`trunk`, `develop`, `qa`,
  `demo`, `production`) y su README.

Lo único que queda del lado de DevSecOps es el onboarding.

## Dos cosas menores del mismo log, por si van en el mismo alta

1. **`JENKINS:207`** — *"The following environments do not have rollback
   configuration: `drs_rllbck`"*. Aparece también en el job de TERRAFORM, de
   modo que parece configuración del entorno y no del paquete. Nuestro
   `rollback.par` sí existe y el pipeline lo reconoce
   (`[REDSHIFT:211] Rollback disponible: 'true'`).
2. **`JIRA:401`** — la cuenta `devsecops-sa-jenkins` no tiene permiso para
   comentar en las subtareas `SLCOPRBA-1444/1445/1446`, de modo que el
   pipeline no puede dejar su traza de despliegue en Jira.

## Contacto

Subtareas: `SLCOPRBA-1444` (strct), `SLCOPRBA-1445` (pgm), `SLCOPRBA-1446`
(dt), bajo `SLCOPRBA-1353 [RECONOCER] Despliegue Cálculo Reconocer`.

---

# Segunda petición, y es otro código: falta el ambiente **DEMO**

*Añadida el 2026-11-24, tras el job **DEMO/DATABASE #202**.*

## Qué pedimos ahora

Añadir la configuración del ambiente **`demo`** al onboarding Redshift —
que **ya existe** — de estos repositorios del proyecto `COAWSPPR`:

| Repositorio | `type` | `order` | Ambientes que hoy funcionan | Falta |
|---|---|---|---|---|
| `COAWSPPR/DB_RCNCR_BTCH_RDSHFT_STRCT` | `struct` | 1 | develop, qa | **demo**, production |
| `COAWSPPR/DB_RCNCR_BTCH_RDSHFT_PGM` | `program` | 2 | develop, qa | **demo**, production |
| `COAWSPPR/DB_RCNCR_BTCH_RDSHFT_DT` | `data` | 3 | develop, qa | **demo**, production |

> Confirmar con DevSecOps cuáles de los tres están ya en esa situación: el
> job #202 sólo probó `DT`. Y aprovechar el mismo alta para **production**,
> porque el CHG de paso a producción va detrás.

**Ojo con el nombre: estos repos NO llevan `DS_`.** Son distintos de los
`DB_DS_RCNCR_BTCH_RDSHFT_*` de la petición de arriba.

## Evidencia: el error exacto

Job **DEMO/DATABASE #202**, rama `demo/SLCOPRBA-1353`, repositorio
`COAWSPPR/DB_RCNCR_BTCH_RDSHFT_DT`:

```
[REDSHIFT:151] Validando onboarding Redshift para 'COAWSPPR/DB_RCNCR_BTCH_RDSHFT_DT'
ERROR: [REDSHIFT:158] AWS Reconocer Redshift Reconocer no tiene configuracion
       para el ambiente demo
Finished: FAILURE
```

## No es el mismo fallo que el `[REDSHIFT:156]`

Los dos salen de `redshiftValidateRuntime()` y se parecen, pero piden cosas
distintas:

| Código | Qué dice | Qué falta |
|---|---|---|
| `[REDSHIFT:156]` | *"El repositorio ... no tiene onboarding Redshift en DevSecOps"* | el repositorio entero no está dado de alta |
| `[REDSHIFT:158]` | *"... no tiene configuracion para el ambiente demo"* | el repositorio **sí** está de alta, y le falta **ese ambiente** |

Este repositorio lleva meses desplegando en **DEV** y **QA** por el mismo
pipeline, de modo que el onboarding existe. Lo que no existe es la entrada
de `demo`.

## El paquete está bien, y el ambiente quedó intacto

El fallo ocurre en el stage **`Before deploy`**, después de que el pipeline
haya validado el paquete entero y **antes** de abrir una sola conexión:

```
[REDSHIFT:419] Paquete detectado en 'deploy/redshift/SLCOPRBA-1353'
[BITBUCKET:414] Paquete temporal Redshift generado con 1 script(s) deploy
[REDSHIFT:208]  Changeset preparado para 'demo'
[REDSHIFT:210]  Scripts deploy: 1
[REDSHIFT:211]  Rollback disponible: 'true'
[REDSHIFT:215]  Scripts rollback: 1
```

Y el `jobConfig` del log muestra el `.jenkins.yml` correcto y completo —
`application: dba_rncr_batch`, `type: data`, `tech: database`,
`language: redshift`, `order: 3` — sin ninguna clave en `null`.

**Cero sentencias SQL se ejecutaron. El clúster de DEMO no se tocó.**

## Por qué corre prisa

DEMO es el **ambiente inmediatamente anterior** a producción, y la política de
Gestión del Cambio de SP LATAM exige *certificación en el ambiente
inmediatamente anterior con evidencia adjunta*. Sin un despliegue verde en
DEMO no hay evidencia que adjuntar al CHG de paso a producción, de modo que
este alta no retrasa un build: **retrasa la radicación del cambio**.

Y el calendario está apretado: el BPP arrancó el 23 de noviembre, del 26 al
30 hay congelamiento total, y la ventana útil para ejecutar en producción es
del **1 al 10 de diciembre**.
