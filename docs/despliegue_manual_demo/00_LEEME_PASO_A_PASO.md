# Despliegue manual en **DEMO** — cálculo Reconocer + exportador UNLOAD

Para ejecutar con cliente SQL contra el clúster de **DEMO**, en la base del
proyecto. Sustituye al pipeline de Jenkins, que hoy no puede desplegar en DEMO
porque al repositorio le falta el alta de ese ambiente en DevSecOps
(`[REDSHIFT:158]`, job DEMO/DATABASE #202).

**Son 178 archivos de estructura y programas, más 2 de ejecución**, y van
**en el orden de su carpeta y, dentro de ella, en el orden de su número**.

| Carpeta | Archivos | Qué es |
|---|---|---|
| `01_STRCT_1353` | 51 | Tablas, vistas y catálogos del cálculo. Sólo DDL |
| `02_PGM_1353` | 122 | Los procedimientos del cálculo. Sólo DDL |
| `03_STRCT_1820` | 2 | Configuración y control del exportador. Sólo DDL |
| `04_PGM_1820` | 3 | Los procedimientos del exportador. Sólo DDL |
| `05_EJECUCION` | 2 | **Aquí sí se ejecuta el proceso.** Primero la cadena, luego el UNLOAD |
| `06_VALIDACION` | 1 | Tres consultas de comprobación. Al final |
| `90_ROLLBACK` | — | Sólo si hay que revertir. No se ejecuta en un despliegue normal |

---

## 0. Tres cosas antes de empezar, y las tres importan

**1 — El usuario tiene que ser DUEÑO de los tres esquemas**
(`bdm_datos`, `bdm_tempo`, `bdm_stage`).

No basta con `GRANT`. Ningún procedimiento se declara `SECURITY DEFINER`, de
modo que corren con los privilegios de quien los invoca, y **27 procedimientos
hacen `TRUNCATE`**, que en Redshift exige ser dueño del objeto.

**2 — Cada archivo se ejecuta ENTERO, de una sola vez.**

No por sentencias. Los 125 archivos de `02_PGM_1353` y `04_PGM_1820` llevan el
cuerpo del procedimiento entre `$$ ... $$`, y **dentro de ese cuerpo hay puntos
y coma**. Un cliente que parta por `;` los rompe todos. En DBeaver:
**Execute script** (`Alt+X`), nunca *Execute statement* (`Ctrl+Enter`).

**3 — Autocommit encendido**, archivo a archivo, comprobando que cada uno
termina sin error antes de pasar al siguiente.

---

## 1 a 4 — La estructura y los programas (178 archivos)

Ejecutar las cuatro carpetas en orden, y dentro de cada una por número.

Todo es DDL idempotente (`CREATE TABLE IF NOT EXISTS`,
`CREATE OR REPLACE VIEW`, `CREATE OR REPLACE PROCEDURE`), así que volver a
correr un archivo no rompe nada. **En ningún punto se ejecuta `DROP SCHEMA`**:
los tres esquemas son compartidos con otros equipos.

Si alguno falla, **parar ahí** y reportar el archivo y el mensaje.

## 5 — La ejecución (2 archivos, y este es el paso largo)

**`001_run_reconocer_e2e_real_full.sql`** ejecuta la cadena completa sobre los
datos reales de DEMO, en modo FULL: Unificación de direcciones → Ordenamiento
de contactabilidad → Novedades. Al terminar deja pobladas las siete tablas de
dominio. Como referencia, en DEV con ~300.000 relaciones tardó **263 segundos**.

**`002_run_novedades_exportar_7_tablas.sql`** hace el `UNLOAD` de esas siete
tablas a S3, en CSV con cabecera comprimido en GZIP, y escribe un archivo de
control que avisa al consumidor de que la entrega está completa.

**Dos avisos para este paso, y los dos son esperados, no motivo para parar:**

- **La georreferenciación va a fallar en DEMO.** La tabla `geo_config` etiqueta
  la cuenta de DEMO como `UAT` y apunta al bucket `uat-...-rcncr-ws5-geo`, que
  muy probablemente no existe. El paso levanta excepción, queda anotado como
  `fallido` y **la cadena continúa**: corre en su propio bloque de excepción
  por decisión de negocio.
- **El `UNLOAD` necesita que existan su bucket y su rol.** El exportador los lee
  de `bdm_datos.nov_config`, fila `DEMO`, y son el bucket
  `demo-453645298399-rcncr-ws5-triggers-reconocer-s3` y el rol
  `BURoleFor-demo-453645298399-rcncr-ws5-redshift-unload`. Si no están creados
  o el rol no está asociado al clúster, el paso falla. **No invalida el resto**:
  los objetos quedaron desplegados y las siete tablas pobladas.

## 6 — La comprobación (1 archivo, tres consultas)

**Consulta 1 — el inventario.** Comprueba que estén los **273 objetos** que el
cálculo y el exportador necesitan (103 tablas, 34 vistas y 136 procedimientos
y funciones). Lo que se espera:

```
TITULAR   COMPLETO - el calculo Reconocer y el exportador tienen todos sus objetos   273   0
```

Si dice `INCOMPLETO`, las filas `FALTANTE` dicen qué objeto falta y en qué
esquema.

**Consulta 2 — los catálogos.** Conteo de filas de los 23 catálogos de
parametrización. **Ninguno debe dar 0**: un catálogo existe y está vacío cuando
un literal del `INSERT` trae una comilla sin escapar, y lo único que lo detecta
es contar las filas.

**Consulta 3 — el resultado.** Las siete tablas de dominio con su conteo, y la
traza del exportador en `nov_export_control`. Punto de interés y Movilidad
salen en **0** y es correcto: la primera espera la respuesta del
geocodificador, la segunda compara contra una foto anterior que en la primera
corrida no existe.

## 7 — Qué hay que devolver como evidencia

1. Confirmación de que los **178 archivos de las carpetas 01 a 04** terminaron
   sin error, o el nombre y el mensaje del primero que falló.
2. Cuánto tardó cada uno de los **2 archivos de `05_EJECUCION`**, y si alguno
   falló, con el mensaje.
3. **El resultado completo de las tres consultas** de `06_VALIDACION`.

---

## Si hay que revertir

`90_ROLLBACK` trae el reverso de cada paquete y **se ejecuta en el orden
contrario**: `04_PGM_1820`, `03_STRCT_1820`, `02_PGM_1353`, `01_STRCT_1353`.
Dentro de cada carpeta, el orden de los números.

Los procedimientos se borran con su firma exacta y **sin `IF EXISTS`**
(Redshift no lo admite ahí), de modo que si un objeto ya no existe ese `DROP`
falla y se continúa: es el comportamiento previsto.

## Lo que este paquete NO hace

- **No crea el bucket ni el rol de S3**, ni el de GEO ni el del UNLOAD. Eso es
  infraestructura y va por Terraform.
- **No ejecuta nada en modo DELTA**, ni nada del juego de pruebas mock: esta
  entrega es únicamente la cadena real en FULL y su exportación.
