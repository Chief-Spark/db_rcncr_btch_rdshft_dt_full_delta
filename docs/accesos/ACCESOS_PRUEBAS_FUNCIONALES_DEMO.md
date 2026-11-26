# Accesos para las pruebas funcionales en DEMO (Julian Mendez)

**Peticion de Fernando Garrido, 2026-11-25.** Cuenta de DEMO:
**`453645298399`**, region `us-east-1`, token de la IaC **`stg`** (medido en el
apply, no deducido: la cuenta se llama DEMO en Jenkins, `uat` en el alias de
AWS y `prd`/`stg` en los tags).

## Lo primero, porque cambia toda la lista

**El perfil de quien valida NO es el perfil de quien despliega.** El usuario de
despliegue es DUENO de los tres esquemas y puede `CREATE`, `TRUNCATE` y `DROP`;
con ese perfil, una consulta mal pegada borra la evidencia de la prueba. Lo que
necesita una validacion funcional es **solo lectura**, y con eso alcanza para
todo lo que se quiere comprobar.

**Y una pregunta que hay que contestar antes de pedir nada:** Julian va a
**LANZAR** corridas o solo a **LEER** el resultado de las que lancemos nosotros?
No es lo mismo y no se resuelve con el mismo permiso:

| | Que necesita |
|---|---|
| **Leer resultados** (lo normal) | los tres accesos de abajo, todos de lectura |
| **Lanzar una corrida** | ademas, poner un archivo `.val` en el bucket de origen del Framework, que vive en **otra cuenta** y es otro permiso. No se consigue con un GRANT en Redshift |

## 1. Redshift -- es el acceso que de verdad usa

Base **`dba_rncr_batch`** del cluster de Reconocer en DEMO.

```sql
-- Usuario o rol de lectura para la validacion funcional
GRANT USAGE ON SCHEMA bdm_datos, bdm_tempo, bdm_stage TO <usuario>;
GRANT SELECT ON ALL TABLES IN SCHEMA bdm_datos TO <usuario>;
```

Lo minimo, si prefieren no dar el esquema entero -- las siete tablas de dominio,
que son el entregable, mas la traza que dice si la corrida hizo algo:

```
bdm_datos.mat_info_ubicacion            bdm_datos.nov_control
bdm_datos.mat_info_contactabilidad      bdm_datos.nov_control_etapa
bdm_datos.mat_ubicacion_agregada        bdm_datos.nov_export_control
bdm_datos.mat_info_basica               bdm_datos.unif_control
bdm_datos.mat_info_actividad_economica  bdm_datos.ord_control
bdm_datos.mat_info_movilidad            bdm_datos.unif_alcance_censo
bdm_datos.mat_info_punto_interes        bdm_datos.ord_alcance_censo
```

**NO se le da `TRUNCATE`, `DELETE`, `UPDATE` ni propiedad de esquema.** No los
necesita y con ellos puede dejar el ambiente sin la evidencia de su propia
prueba.

**DOS TRAMPAS DE CONEXION QUE CUESTAN UNA MANANA SI NO SE AVISAN:**

1. **DBeaver abre en la base `dba`, donde NO existen `bdm_datos`,
   `bdm_tempo` ni `bdm_stage`.** Hay que cambiar a `dba_rncr_batch` antes de
   consultar. Las relaciones del datashare si responden desde cualquiera,
   porque llevan las tres partes del nombre.
2. **Los scripts de validacion traen sentencias con `;` dentro de literales**:
   un cliente que parta por `;` las rompe. Se ejecutan enteras.

## 2. S3 -- lectura sobre DOS buckets, no uno

**Son dos buckets distintos y hacen cosas distintas.** Pedir solo "el bucket"
deja la mitad de la prueba sin poder verse:

| Bucket | Que contiene | Prefijo |
|---|---|---|
| `stg-453645298399-rcncr-ws5-geo` | lo que sale y entra de ArcGIS | `reconocer_input/`, `reconocer_output/` |
| `stg-453645298399-rcncr-ws5-triggers-reconocer-s3` | **la salida del calculo**: las siete tablas en CSV GZIP y el CTL | `nov/<run_id>/data/<tabla>/` y `nov/<run_id>/7_tablas_finish000.json` |

Permisos: **`s3:GetObject` y `s3:ListBucket`**, nada mas. Sin `PutObject`.

**Y hay un motivo concreto para no dar escritura en el de GEO:** el cargador
hace `COPY` de **todos** los archivos del prefijo de salida, sin filtrar por
nombre. Un archivo dejado ahi por una prueba se lo come la siguiente corrida
real como si fuera respuesta de ArcGIS.

**El bucket de triggers va cifrado con KMS**, no con AES256. Para descargar un
objeto hace falta ademas **`kms:Decrypt`** sobre la llave de ese bucket. Si el
sintoma es `AccessDenied` al bajar un CSV y el `ListBucket` si funciona, es
esto y no el permiso de S3.

## 3. Step Functions -- solo lectura, y son de DOS sitios

1. **La maquina de estados del Framework Batch** (la que hace los `CALL` a los
   procedimientos). Vive en la **cuenta del Framework**, que no es la de
   Reconocer: el ARN hay que pedirselo al equipo del Framework.
2. **La cadena del consumidor**, que la crea `tf_rcncr_linea_ws5_infra` en la
   cuenta de Reconocer: lambdas, Step Functions, Glue y la carga a DynamoDB.
   El ARN sale de la salida del apply de ese repositorio.

Permiso: `states:ListStateMachines`, `states:DescribeExecution`,
`states:GetExecutionHistory` y `states:ListExecutions`. **Lectura.**
`states:StartExecution` solo si la respuesta a la pregunta de arriba es que si
va a lanzar corridas.

## 4. Lo que conviene decirle a Julian antes de la prueba, no durante

- **Un verde no dice que el proceso hizo algo.** `estado = 'completado'` solo
  dice que no hubo excepcion. La pregunta util es el conteo, y el mejor
  detector de cambio que hay es `nov_control_etapa` (`filas_altas`, `cambios`).
- **`unif_control_etapa` y `ord_control_etapa` traen los conteos en 0 literal**:
  son marcadores. Valen por estado y por tiempos, nunca por volumen.
- **`mat_info_movilidad` se trunca en cada corrida**: su `COUNT(*)` es el de la
  ULTIMA, no el acumulado. Se mide en la traza, no en la tabla.
- **`mat_info_punto_interes` sale en 0** mientras ArcGIS no procese: depende de
  `geo_distancias`, que solo llena el `COPY` de la respuesta externa.
