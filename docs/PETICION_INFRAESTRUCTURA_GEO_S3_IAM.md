# Petición de infraestructura: S3 y rol IAM del ciclo GEO (ArcGIS)

**Estado:** abierta · **Fecha:** 2026-10-27 · **Ticket:** SLCOPRBA-1355
**Destinatario:** DevSecOps / equipo de IaC (Terraform)
**Bloquea:** el enriquecimiento GEO de la Regla 3 en la vía real, en los cuatro ambientes.

---

## 1. Qué se pide, en una línea

Crear por IaC, en cada ambiente: **un bucket S3**, **un rol IAM** con permisos sobre
él, y **la asociación de ese rol al clúster Redshift**. Nada de esto se puede hacer
desde el repositorio de base de datos.

## 2. Por qué: son DOS bloqueos, no uno

Hasta hoy el incidente figuraba como un problema de permisos. Es sólo la mitad.

| # | Bloqueo | Evidencia |
|---|---|---|
| 1 | El rol **no está asociado al clúster** | el `UNLOAD` muere con `UnauthorizedException: role rcncr-batch-redshift-geo is not associated to cluster` (job DEV/DATABASE #484) |
| 2 | **El bucket de destino no existe** | consola S3 de la cuenta `647096294147`, filtro `rcncr`, todas las regiones: 4 buckets y ninguno es el de GEO (2026-10-27) |

El segundo estaba tapado por el primero: Redshift valida el rol antes de resolver el
destino, **y el motor para en el primer error**. Aunque se asociara el rol mañana, el
`UNLOAD` seguiría fallando.

> Nota de alcance: la comprobación se hizo en DEV. **Los otros tres ambientes no
> están verificados**; lo más probable es que estén igual, pero es hipótesis.

## 3. Inventario exacto por ambiente

Los valores salen de `bdm_datos.geo_config`, sembrado en
`strct/.../SQL/03_ddl_geo.sql:187-197` (DEV) y equivalentes.

| Ambiente | Cuenta AWS | Bucket | Rol IAM |
|---|---|---|---|
| DEV  | `647096294147` | `rcncr-batch-geo-dev-647096294147`  | `arn:aws:iam::647096294147:role/rcncr-batch-redshift-geo` |
| TEST (QA) | `667397050561` | `rcncr-batch-geo-test-667397050561` | `arn:aws:iam::667397050561:role/rcncr-batch-redshift-geo` |
| UAT  | `453645298399` | `rcncr-batch-geo-uat-453645298399`  | `arn:aws:iam::453645298399:role/rcncr-batch-redshift-geo` |
| PROD | `696708350333` | `rcncr-batch-geo-prod-696708350333` | `arn:aws:iam::696708350333:role/rcncr-batch-redshift-geo` |

Región: `us-east-1`, la misma que el resto de buckets de la cuenta.

### 3.1 Prefijos dentro del bucket

| Prefijo | Quién escribe | Quién lee | Config |
|---|---|---|---|
| `reconocer_input/`  | Redshift (`UNLOAD`) | ArcGIS | `s3_prefix` |
| `reconocer_output/` | ArcGIS | Redshift (`COPY`) | `s3_output_prefix` |

Nombres de objeto:

```
reconocer_input/delta_geo_<ambiente>_<lote>_<AAAAMMDD>.csv.gz
reconocer_output/geo_result_*
reconocer_output/distancias_result_*
```

## 4. Permisos que necesita el rol

El rol lo asume **el clúster Redshift**, no una persona.

| Acción | Recurso | Para qué |
|---|---|---|
| `s3:PutObject`, `s3:AbortMultipartUpload` | `arn:aws:s3:::<bucket>/reconocer_input/*` | el `UNLOAD` de candidatos |
| `s3:GetObject` | `arn:aws:s3:::<bucket>/reconocer_output/*` | los dos `COPY` de respuesta |
| `s3:ListBucket` | `arn:aws:s3:::<bucket>` | el `COPY` resuelve un prefijo, no un objeto |
| `kms:Encrypt`, `kms:Decrypt`, `kms:GenerateDataKey` | la clave del bucket | sólo si se cifra con KMS gestionada |

**Y el paso que hoy falta y es el que da el error:** asociar el rol al clúster
(`aws redshift modify-cluster-iam-roles`, o el equivalente en el módulo de Terraform
del clúster). Crear el rol sin asociarlo **no desbloquea nada**.

## 5. Acceso de ArcGIS

`geo_config.arcgis_account_id` trae, en los cuatro ambientes, **la misma cuenta que el
ambiente**. Es decir: ArcGIS se espera en la propia cuenta y **no hace falta acceso
cross-account**. Si en realidad corriera en otra cuenta, habría que añadir una bucket
policy — **confírmenlo, porque es una suposición tomada de la configuración, no una
medición.**

ArcGIS necesita: leer `reconocer_input/` y escribir `reconocer_output/`.

## 6. Una decisión que les corresponde: el nombre

El nombre configurado no sigue la convención que usa hoy la cuenta de DEV, donde los
cuatro buckets existentes son `dev-647096294147-rcncr-ws5-<proposito>`:

```
dev-647096294147-rcncr-ws5-emrserverless
dev-647096294147-rcncr-ws5-filesbatchprocess
dev-647096294147-rcncr-ws5-triggers-reconocer-s3
dev-647096294147-rcncr-ws5-upload-staging-s3
```

Dos salidas, **y hay que elegir una**:

| Opción | Qué implica |
|---|---|
| **A** — crear con el nombre ya configurado | ningún cambio en el repositorio de base de datos |
| **B** — adoptar la convención, p. ej. `dev-647096294147-rcncr-ws5-geo` | un `UPDATE` sobre `bdm_datos.geo_config` por ambiente, sin tocar código |

Recomendamos **B**: la convención de la cuenta pesa más que un literal nuestro, y el
cambio de nuestro lado es un `UPDATE`, no un despliegue.

## 7. Cómo se verifica que quedó bien

Tres comprobaciones, en este orden:

```
1. aws s3 ls s3://<bucket>/            -> responde, no AccessDenied
2. En Redshift:  UNLOAD de una fila a reconocer_input/  -> sin UnauthorizedException
3. El ciclo completo: el Lote queda en 'exportado' y no en 'fallido'
```

Y desde el tablero:

```sql
SELECT lote, estado, fase_fallo, ultimo_error, conteo_esperado
FROM   bdm_datos.geo_lote_control
ORDER  BY fecha_hora_inicio DESC LIMIT 5;
```

Un Lote en **`exportado`** con `fase_fallo` y `ultimo_error` en NULL es el verde que
buscamos.

## 8. Qué NO bloquea esto

Conviene acotarlo para que no frene otras entregas:

- **GEO no es bloqueante** (decisión de negocio, 2026-10-20: ArcGIS todavía no
  procesa). El ciclo de Unificación captura la excepción y continúa con la Regla 3.
- Los **cinco criterios CA-01..CA-05 están certificados sobre mock** (job #402, 50/50),
  sustituyendo el viaje a S3. Lo único sin certificar es que el `UNLOAD` escriba de
  verdad y que el `COPY` lea.
- `mat_info_punto_interes` sale en **0 filas** por esta causa: lee
  `bdm_datos.geo_distancias`, que sólo llena el `COPY` de la respuesta de ArcGIS
  (`sp_novedades_punto_interes_edf.sql:117`). **Es el único de los siete dominios que
  este requerimiento desbloquea.**

## 9. Referencias de código

| Qué | Dónde |
|---|---|
| Composición de la ruta y el `UNLOAD` | `pgm/.../sp_geo_exportar_insumo.sql:195-207`, `:475-500` |
| Los dos `COPY` de respuesta | `pgm/.../sp_rcn_geo_02_buscar_resultados.sql:102-147` |
| Semilla de `geo_config` | `strct/.../03_ddl_geo.sql:150-226` |
