# Solicitud ServiceNow — Datashare y permisos de Reconocer en PRODUCCIÓN

*Redactada para pegarse en ServiceNow. Fecha: 2026-11-19.*

> **Cómo leer este documento.** Lo que está en la tabla "Datos confirmados"
> sale del código y está citado. Lo que está en "Datos que faltan" **no lo
> tenemos** y debe completarlo DevSecOps / el DBA de PROD antes de ejecutar:
> no está inventado aquí a propósito.

---

## 1. Resumen de la solicitud

Habilitar en **producción** el consumo del datashare `ds_dba_rncr_batch` desde
el clúster Redshift de Reconocer, y otorgar al **usuario de despliegue
(pipeline Jenkins DATABASE)** y al **usuario del Framework Batch (`user_sp`)**
los permisos mínimos para desplegar y ejecutar la cadena.

El clúster de Reconocer en PROD **ya existe**. Esta solicitud **no pide
infraestructura nueva**: pide el datashare, su asociación cross-account y los
permisos.

| Campo ServiceNow | Valor sugerido |
|---|---|
| Tipo | Solicitud de cambio estándar — base de datos |
| Aplicación | `dba_rncr_batch` (Reconocer Batch) |
| Ambiente | Producción |
| Referencia Jira | `SLCOPRBA-1353` (historia padre) |
| Impacto | Sin el datashare la cadena no arranca: las vistas de insumo no resuelven |

---

## 2. Datos confirmados (salen del código, con cita)

| Dato | Valor | Dónde |
|---|---|---|
| Base de datos consumidora | `dba_rncr_batch` | `production/terraform.tfvars` (bloque RECONOCER) |
| Cuenta AWS de Reconocer PROD | **`696708350333`** | `03_ddl_geo.sql:193,219-222` y `production/terraform.tfvars` |
| Nombre del datashare | **`ds_dba_rncr_batch`** | 48 referencias en el paquete, p. ej. `02_vistas_insumo_edf_views.sql` |
| Esquema del productor | **`edf_views`** | todas las referencias son `ds_dba_rncr_batch.edf_views.<rel>` |
| Usuario del Framework Batch | **`user_sp`** | `production/terraform.tfvars`, `database_user_arn` |
| Esquemas propios a crear | `bdm_datos`, `bdm_tempo`, `bdm_stage` | `00_prerequisitos_schemas.sql`, `12_ddl_ord_control.sql` |
| Región | `us-east-1` | todos los ARN del `terraform.tfvars` |

**Y una aclaración que ya costó una confusión interna:** la cuenta
**`324037294240` NO es la de Reconocer**, es la del **Framework Batch en
producción** (`procesosbatch`). Las dos aparecen en el mismo archivo y se
cruzan con facilidad.

---

## 3. Datos que faltan y quién los pone

Ninguno de estos lo podemos aportar nosotros. **Ejecutar sin ellos no es
posible.**

| # | Dato | Quién lo tiene |
|---|---|---|
| 1 | **Namespace (GUID) del clúster PRODUCTOR de EDF** en PROD | EDF |
| 2 | **Cuenta AWS del productor de EDF** en PROD | EDF |
| 3 | **Namespace (GUID) del clúster CONSUMIDOR** de Reconocer en PROD | DBA de Reconocer |
| 4 | **`cluster_id` real de Reconocer en PROD** | DBA de Reconocer |
| 5 | **Nombre del usuario de despliegue** con el que el pipeline DATABASE se conecta (el mismo que ya opera en DEV/QA/DEMO, credencial `REDSHIFT_USER` de Jenkins) | DevSecOps |

**Sobre el punto 4:** el `terraform.tfvars` de producción trae el `cluster_id`
`eec-aws-us-eits-reconocerbatch-pro-redshift`, pero su propio comentario dice
*"cluster_id inferido con el patrón de nomenclatura (no fue provisto para
prd). CONFIRMAR el cluster_id real de producción antes de aplicar."* **Es
hipótesis, no dato.**

**Y hay una inconsistencia de nomenclatura que conviene resolver de una vez:**
el token de producción aparece como **`prod`** en el bucket de GEO
(`prod-696708350333-rcncr-ws5-geo`) y como **`pro`** en el rol cross-account
(`BURoleFor-pro-696708350333-...`). Uno de los dos está mal y hoy no sabemos
cuál.

---

## 4. Lo que hay que ejecutar

### 4.1 Lado PRODUCTOR (EDF)

Las **nueve** relaciones que el paquete consume hoy, ni una más:

```sql
CREATE DATASHARE ds_dba_rncr_batch;

ALTER DATASHARE ds_dba_rncr_batch ADD SCHEMA edf_views;

ALTER DATASHARE ds_dba_rncr_batch ADD TABLE
  edf_views.xpm,
  edf_views.xpm_location,
  edf_views.xpm_location_val_contactinformations,
  edf_views.xpm_counterparties,
  edf_views.xpm_personalinformation,
  edf_views.xpm_chamberofcommerce,
  edf_views.xpm_bestidentifications,
  edf_views.xpm_bestaccounts,
  edf_views.xpm_bestaccounts_val_frequentbehaviour;

-- Cross-account: el consumidor está en otra cuenta.
GRANT USAGE ON DATASHARE ds_dba_rncr_batch TO ACCOUNT '696708350333';
```

Después, el administrador de la cuenta **`696708350333`** debe **asociar** el
datashare (consola de Redshift o `aws redshift associate-data-share-consumer`).
Sin esa asociación el `CREATE DATABASE` del consumidor falla.

### 4.2 Lado CONSUMIDOR (clúster de Reconocer, cuenta `696708350333`)

```sql
CREATE DATABASE ds_dba_rncr_batch
  FROM DATASHARE ds_dba_rncr_batch
  OF ACCOUNT '<cuenta-productor-EDF>'
  NAMESPACE '<namespace-productor-EDF>';
```

### 4.3 Esquemas y propiedad

**La recomendación es crear un ROL y que el rol sea el dueño**, no repartir
permisos usuario por usuario. El motivo está en 4.5 y no es cosmético.

```sql
CREATE ROLE rol_rcncr_batch;

CREATE SCHEMA IF NOT EXISTS bdm_datos AUTHORIZATION ROLE rol_rcncr_batch;
CREATE SCHEMA IF NOT EXISTS bdm_tempo AUTHORIZATION ROLE rol_rcncr_batch;
CREATE SCHEMA IF NOT EXISTS bdm_stage AUTHORIZATION ROLE rol_rcncr_batch;

GRANT ROLE rol_rcncr_batch TO <usuario_despliegue>;
GRANT ROLE rol_rcncr_batch TO user_sp;
```

> `bdm_datos` y `bdm_stage` **son esquemas compartidos** en los ambientes
> actuales: en DEV `bdm_stage` tiene 23 objetos de otros equipos. Si en PROD ya
> existen, **no se recrean ni se cambia su dueño**: en ese caso hay que ir por
> la vía de permisos explícitos de 4.4, no por `AUTHORIZATION`.

### 4.4 Permisos de los dos usuarios

```sql
-- Acceso al datashare: lo necesitan LOS DOS.
GRANT USAGE ON DATABASE ds_dba_rncr_batch TO <usuario_despliegue>;
GRANT USAGE ON DATABASE ds_dba_rncr_batch TO user_sp;

-- Usuario de despliegue: crea tablas, vistas, funciones y procedimientos,
-- y los borra en el rollback.
GRANT CREATE ON DATABASE dba_rncr_batch TO <usuario_despliegue>;
GRANT ALL ON SCHEMA bdm_datos, bdm_tempo, bdm_stage TO <usuario_despliegue>;

-- Usuario del Framework: ejecuta la cadena.
GRANT USAGE ON SCHEMA bdm_datos, bdm_tempo, bdm_stage TO user_sp;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA bdm_datos TO user_sp;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA bdm_tempo TO user_sp;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA bdm_stage TO user_sp;
GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA bdm_datos TO user_sp;
GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA bdm_stage TO user_sp;

-- SIN ESTO SE ROMPE EN EL SIGUIENTE DESPLIEGUE, no hoy: cada deploy crea
-- objetos NUEVOS sobre los que user_sp no tendria permiso.
ALTER DEFAULT PRIVILEGES FOR USER <usuario_despliegue> IN SCHEMA bdm_datos
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO user_sp;
ALTER DEFAULT PRIVILEGES FOR USER <usuario_despliegue> IN SCHEMA bdm_tempo
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO user_sp;
ALTER DEFAULT PRIVILEGES FOR USER <usuario_despliegue> IN SCHEMA bdm_stage
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO user_sp;
```

### 4.5 El punto que decide todo: TRUNCATE y la propiedad de los objetos

**`EXECUTE` sobre los procedimientos NO basta.** Ninguno de los 116
procedimientos del paquete se declara `SECURITY DEFINER` (verificado: cero
coincidencias), de modo que **corren con los privilegios de quien los invoca**
— `user_sp` —, no con los del dueño.

Y **27 procedimientos de la vía real hacen `TRUNCATE`** (p. ej.
`16_sp_unificacion_ciclo.sql`, `sp_ordenamiento_preparar_insumos_edf.sql`, los
siete dominios de Novedades). En Redshift `TRUNCATE` **exige ser dueño del
objeto** y no se concede con un `GRANT` como en PostgreSQL — **esto hay que
confirmarlo contra la documentación vigente de Redshift**, pero la salida
propuesta funciona en los dos casos.

**Por eso la recomendación es el ROL dueño de 4.3**: con `rol_rcncr_batch`
dueño de los objetos y concedido a los dos usuarios, ambos pueden crear,
truncar y ejecutar **sin superusuario**. Si se va por permisos sueltos, el
primer `TRUNCATE` fallará con *permission denied / must be owner of relation*.

---

## 5. Riesgo conocido: el enmascaramiento dinámico

En DEV este síntoma tumbó un despliegue completo (job #453):

```
XX000: cross-cluster query of the masked relation "<rel>" is not supported
```

`CREATE OR REPLACE VIEW` **no lo detecta**, porque no ejecuta la consulta: el
error sale la primera vez que algo la **ejecuta**, mucho después y en otro
sitio. En DEV se midió relación por relación y hoy **responden las nueve**,
pero **PROD lleva dato real y sus políticas de enmascaramiento pueden no ser
las mismas**.

**Se pide a EDF confirmar explícitamente** que el usuario/rol consumidor queda
exento de *dynamic data masking* sobre las nueve relaciones, o indicar cuáles
no lo estarán.

---

## 6. Verificación (qué se corre para dar el cambio por bueno)

| # | Comprobación | Resultado esperado |
|---|---|---|
| 1 | `SELECT COUNT(*) FROM ds_dba_rncr_batch.edf_views.xpm;` como `<usuario_despliegue>` | devuelve un número, sin `XX000` |
| 2 | Lo mismo **como `user_sp`** | idéntico: los dos usuarios tienen que poder leer |
| 3 | Las **nueve** relaciones, una por una, hasta el final | cero errores. Una sonda que para en el primer error no mide el universo |
| 4 | `SELECT nspname FROM pg_namespace WHERE nspname IN ('bdm_datos','bdm_tempo','bdm_stage');` | tres filas |
| 5 | `CREATE TABLE bdm_tempo.prueba_permiso(id INT); TRUNCATE bdm_tempo.prueba_permiso; DROP TABLE bdm_tempo.prueba_permiso;` **como `user_sp`** | las tres sentencias pasan. **Es la prueba de 4.5** y la que de verdad cierra la solicitud |

El punto 5 es el que no hay que saltarse: es el único que distingue
"los permisos están puestos" de "los permisos sirven".

---

## 7. Fuera del alcance de esta solicitud

Se listan porque **PROD no funciona sin ellos** y conviene que no aparezcan de
sorpresa en el primer despliegue:

| # | Qué falta | A quién |
|---|---|---|
| 1 | **Bucket y rol IAM de GEO en PROD** (`prod-696708350333-rcncr-ws5-geo` y su `BURoleFor-...-redshift-geo`), con el rol **asociado al clúster**. En DEV faltaban las dos cosas y un fallo tapó al otro | Infraestructura / IaC |
| 2 | **Onboarding Redshift en DevSecOps** de los repos para el ambiente de producción | DevSecOps |
| 3 | **Destino `RECONOCER` del Framework Batch**: hoy está **comentado** en `production/terraform.tfvars`. Sin descomentarlo el Builder cae al destino por defecto `ALPHA` —cuenta `324037294240`, base `dba_batch`— donde nuestros procedimientos **no existen** | Equipo del Framework Batch |
| 4 | **Fila de `geo_config` para el ambiente de producción**, si el token correcto resulta ser `pro` y no `prod` | Nosotros, una vez resuelto el punto del nombre |
