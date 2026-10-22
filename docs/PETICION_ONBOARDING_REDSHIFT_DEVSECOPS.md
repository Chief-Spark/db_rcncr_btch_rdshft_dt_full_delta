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
