# Reconocer - repo de DATOS (dt)

Unificacion de direcciones y Ordenamiento (scoring de contactabilidad) de
Experian Reconocer, migrados de Teradata a Amazon Redshift.

Este repo tiene `global.type = data`: **semillas, runners y validaciones**.
Se despliega **el ultimo** de los tres, y es el que produce la evidencia de QA.

## Donde esta que

| Pieza | Archivo |
|---|---|
| Semillas del mock | `seed_mock_matriz.sql`, `_r2.sql`, `_r3.sql` |
| Bateria e2e (FULL / DELTA1 / mutacion / DELTA2) | `run_reconocer_e2e_mock_full_delta.sql` |
| Convergencia (4 ciclos + FULL2) | `run_unif_convergencia_mock.sql` |
| Tablero y titular de certificacion | `validacion_certificacion_51.sql` |
| Documentacion funcional | `docs/` |

## El esquema de arquetipos del mock

```
id_buro_persona     = 9000000 + ARQ * 10000 + i      (i = 0..N-1, N = 1000)
cod_dw_persona_ubic = id_buro_persona * 10 + k
=> ARQ = (cod_dw_persona_ubic / 10 - 9000000) / 10000
```

| Banda | ARQ | Contenido |
|---|---|---|
| 9010000..9200999 | 1..20 | Regla 1 |
| 9210000..9550999 | 21..55 | Regla 2 |
| 9560000..9560999 | 56 | GEO con coordenadas |
| 9570000..9590999 | 57..59 | Grupo A (CIIU 82, CIIU 90, hija bloqueada) |
| 9600000..9600999 | 60 | cascada R1 -> R2 |
| 9610000..9700999 | 61..70 | Regla 3 |
| 9710000..9730999 | 71..73 | sitios 2, 3 y 4 de creacion (`A6`, `A8`, `D9`) |

Cada arquetipo debe ser **inmune a toda la cascada previa**, y esa inmunidad se
justifica por escrito en la cabecera de la semilla. Un arquetipo que una etapa
anterior se lleva no prueba nada.

Las cinco posiciones respecto al Watermark son `DENTRO`, `FUERA`, `NULL`,
`CABALLO` (una direccion dentro y otra fuera: certifica la ventana **por
persona**) y `YA_UNIFICADA`.

## Fuentes de verdad del negocio

- Unificacion: `PRO_UnificacionR2.sql` (legado Teradata).
- Ordenamiento F4: **`Caracteristicas.txt`** (ese archivo *es* el modelo).
  F1-F3: `Prc_Ordenamiento2.sql`.

## Reglas que no se negocian

1. **Nunca cambiar la firma de un SP.** El Framework Batch exige 6 parametros
   VARCHAR en los orquestadores, en este orden: `in_solicitud`,
   `in_nit_suscriptor`, `in_path_archivo`, `in_nemotecnico` (= MODO),
   `in_id_facturacion` (= LOTE), `in_fecha_ejecucion` (= FECHA). Los tres
   primeros no se usan y aun asi forman parte de la firma. Los gates NO usan
   esta firma: van `(VARCHAR, INTEGER)`.
2. **Rama `claude/elegant-carson-tqhcku`.** Nunca empujar a otra sin permiso
   explicito.
3. **No crear pull requests** salvo peticion expresa.
4. **Revisar el codigo de Teradata antes de decidir.** El documento funcional
   se equivoca; el codigo manda. Verificado tres veces en Unificacion y tres
   veces mas en Ordenamiento (EMA014, EMA025, DIR017).
5. **Certificar solo con datos mock.**
6. **Orden de despliegue: strct -> pgm -> dt.**

## Politicas del pipeline

| Codigo | Causa | Como se evita |
|---|---|---|
| `REDSHIFT:112` | error SQL durante el deploy | **es lo unico que tumba el build hoy** |
| `REDSHIFT:207` | BOM en un `.par` | UTF-8 **sin** BOM |
| `REDSHIFT:219` | basename de `RevSQL/` distinto a la linea de `rollback.par` | mismo nombre, sin sufijo `_rev` |
| `REDSHIFT:232` | `UPDATE`/`DELETE` de nivel superior sin `WHERE` | `WHERE` explicito, o `TRUNCATE` |
| `JENKINS:104/105` | rama sin ID de subtarea | nombrar la rama con la subtarea |

`rollback.par` es el reverso exacto de `deploy.par`, modulo el prefijo
`NN_rollback_` en los archivos numerados. Todo archivo sin prefijo numerico
conserva su nombre en `RevSQL/`.

## Convenciones de codigo

- **UTF-8 sin BOM. ASCII sin acentos**, a proposito, en todo el repo.
- `NONATOMIC` en toda la cadena de `CALL`. Mezclar modos rompe con
  *"P0001: created in one transaction mode cannot be invoked from another"*.
- Rollback de procedimientos: `DROP PROCEDURE nombre(<firma exacta>);`
  **sin `IF EXISTS`** (Redshift da `syntax error at or near "EXISTS"`).
  Tablas y vistas si usan `IF EXISTS`.
- **Nunca `GRANT ... TO PUBLIC`.** Nunca `DROP SCHEMA ... CASCADE` desde
  `strct` (incidente DEV #256): `bdm_datos` es compartido.
- DDL idempotente: `CREATE TABLE IF NOT EXISTS`, `CREATE OR REPLACE VIEW`.
- Vistas con `WITH NO SCHEMA BINDING`, para que el orden de despliegue no las
  rompa.
- Tablas pequenas en `DISTSTYLE ALL`, con la justificacion escrita.
- **Paridad real <-> mock** en todo SP que se toque. El mock se genera por
  sustitucion de fuentes y debe regenerarse identico.

## Trampas de Redshift ya pagadas

- `generate_series` es **leader-node only** -> usar `bdm_stage.mock_numeros`.
- `REGEXP_*` exige patrones **literales**, no derivados de columna.
- `EXISTS` no vale en la lista del `SELECT` (en el `WHERE` si).
- `UPDATE ... FROM`: el destino **no admite alias**.
- `CAST(fecha AS INTEGER)` no existe -> `(anio-1900)*10000 + mes*100 + dia`
  con `DATE_PART`.
- `CASE`/`COALESCE` no mezclan INTEGER y VARCHAR.
- **Todos los `LISTAGG` del MISMO `SELECT` comparten `WITHIN GROUP`** (por
  `SELECT`, no por sentencia). Es lo que tumbo el job #341.
- `LISTAGG(DISTINCT ...)` no convive con `COUNT(DISTINCT ...)` en el mismo
  `SELECT`.
- `COUNT(DISTINCT)` no vale como funcion de ventana -> `MIN()/MAX() OVER`.
- `REPLACE(x, NULL, '')` devuelve **NULL**.
- `SUM()` sobre cero filas devuelve **NULL**, no 0 -> guarda `COUNT(*) = 0`
  primero, y `COALESCE` despues. Sin eso, un criterio vacio sale PASSED.
- Subconsulta escalar en la proyeccion dentro de una agregacion: Redshift no la
  resuelve de forma fiable -> `CROSS JOIN`.
- El `DISTKEY` tiene que ser una columna de la **lista del SELECT**, no un
  alias (job #315).
- El `CAST` de la primera rama de un `UNION ALL` fija el tipo del nodo.
- **`ORDER BY ... DESC` pone `NULLS FIRST` por defecto** (Teradata hace lo
  contrario). Escribir `NULLS LAST` explicito.
- `CREATE OR REPLACE PROCEDURE` **no compila el cuerpo**: los errores salen en
  la primera invocacion.

## Lecciones numeradas (estaban dispersas en cabeceras)

| # | Leccion |
|---|---|
| #5 | `deploy.par` y `rollback.par` con paridad de lineas |
| #7 | Framework Batch: 6 params VARCHAR obligatorios |
| #9 | `.par` en UTF-8 sin BOM y en orden inverso |
| #10 | Redshift no soporta `DROP FUNCTION IF EXISTS`; usar firma exacta y asumir el fallo si no existe |
| #11 | Firma exacta del Framework Batch, en ese orden |
| #12 | Redshift no soporta `DROP PROCEDURE IF EXISTS` |
| #13 | `NONATOMIC` en toda la cadena de `CALL` |
| #14 | El `DROP` debe repetir la firma **exacta** del `CREATE`, incluido el `INOUT` |

*(#1-#4, #6 y #8 no estan citadas en ningun archivo del repo: se perdieron.)*

## Antes de empujar

```
./validar.sh
```
Chequea ASCII, BOM, `$$` y parentesis balanceados, simetria de los `.par`, que
toda entrada tenga su archivo, `WHERE` en `UPDATE`/`DELETE`, y `LISTAGG` con el
mismo `WITHIN GROUP` por `SELECT`. Sale distinto de cero si algo falla.
