# Los catálogos de dominio llevan llaves inventadas

**Conclusión primero: tres de nuestros catálogos no coinciden con los reales, y
los tres gobiernan decisiones de procesos ya certificados. Ninguno lo puede
detectar el mock, porque el mock siembra exactamente lo que nuestros catálogos
declaran.**

Fecha: 2026-10-14 · Origen: `novedades_mapeo_y_catalogos.zip` entregado por el
cliente · Decisión tomada: **documentar, no corregir**

No son defectos de código: son datos. Y por eso no los encuentra ni `validar.sh`
ni el banco local ni la batería de 45 criterios. Se encuentran comparando
nuestros catálogos contra los del cliente, que es lo que hace este documento.

---

## 1. El diccionario de nomenclaturas — el más grave

`bdm_datos.nomenclatura` (`strct/.../01_ddl_unificacion_direccion.sql:137`)
tiene **12 entradas**. El catálogo real (`NOMENCLATURA_SINTETICO.csv`) tiene
**58**.

De nuestras 12: **4 correctas, 7 con el nivel equivocado, 1 que no existe.**

| Nuestra | Nivel nuestro | Nivel real | |
|---|---|---|---|
| `AP` | 7 | 7 | ok |
| `BR` | 1 | 1 | ok |
| `ED` | 2 | 2 | ok |
| `MZ` | 3 | 3 | ok |
| `BL` | 2 | **5** | distinto |
| `CS` | 5 | **7** | distinto |
| `IN` | 8 | **5** | distinto |
| `LC` | 3 | **7** | distinto |
| `LT` | 5 | **8** | distinto |
| `OF` | 6 | **7** | distinto |
| `TO` | 4 | **5** | distinto |
| `CA` | 4 | — | **no existe en el catálogo real** |

Y faltan 47:

```
AD/10 AG/4  AL/7  ALC/11 BA/11 BG/7  CC/1  CD/1  CDM/1 CEN/99 CN/7  CONJ/1
CPO/11 CU/4 DP/7  EN/10  ESQ/10 ET/4 EX/5  GJ/7  GR/12 GS/7   IF/13 MD/5
MLT/2  MN/7 NCO/5 NI/5   PA/9  PD/9  PH/7  PI/6  PL/6  POR/2  PQ/2  PQD/6
PU/9   SA/7 SEC/2 SM/2   SS/7  ST/7  SU/7  TZ/7  UN/1  URB/1  ZN/2
```

### Por qué importa

`nivel_complemento` es lo que comparan, literalmente, el escenario 5
(«la nomenclatura de menor nivel pierde»), el escenario 6, y los motores NIVEL
y DIF. En producción:

- las **47 que faltan** resuelven a NULL y la comparación de nivel degrada;
- las **7 con nivel equivocado** hacen que la Regla 2 **elija otro ganador**.

### Por qué el mock no lo ve, y por qué `45 | 45 | 0` no lo contradice

Porque el mock siembra exactamente esas 12 nomenclaturas —incluida `CA`, que en
el catálogo real no existe— y el catálogo que consulta es el nuestro. El
sistema es coherente consigo mismo y ciego al mundo. El titular está bien
calculado sobre un diccionario equivocado.

### Quién manda

El legado hace `JOIN REC_DATOS.NOMENCLATURA` (66 veces vía SQL dinámico, 12
directas). Es una tabla de **datos**, no de código, así que su contenido nunca
estuvo en el dump de Teradata: nuestras 12 entradas son una transcripción a
mano. El CSV entregado es el contenido de esa tabla.

**Lo único a confirmar:** el archivo se llama `NOMENCLATURA_SINTETICO` y la
tabla del legado, `NOMENCLATURA`. Plausiblemente el mismo objeto exportado, pero
conviene que quien lo exportó lo diga.

---

## 2. `tipo_ubicacion_dir` — las llaves son de otro espacio

| | Nuestro | Real |
|---|---|---|
| `RES` | 1 | **21478** |
| `LAB` | 2 | **21461** |
| `CRR` | 3 | **21426** |
| `JUD` | 4 | **40164** |
| `CCL` | 5 | **21417** |
| `DIR` | 7 | **no existe** |

Nuestras llaves son enteros secuenciales inventados; las reales son surrogates
de cinco dígitos. **Un join por `cod_dw_tipo_ubicacion_dir` contra el dato real
no casa ni una fila.** Y el `LEFT JOIN` no da error: da NULL, y las
características de DIR que dependen de `tipo_direccion` degradan en silencio.

Dos detalles que confirman el diagnóstico: el catálogo real trae además una
columna **`Token`** con valores 1..5 —que es, casi seguro, lo que nuestra
numeración intentaba aproximar, salvo que **`JUD` y `CCL` están intercambiados**
respecto a ella— y `REC_VISTA.V_Fuente` usa el mismo espacio de llaves de cinco
dígitos (`77387`, `21409`), lo que descarta que lo de cinco dígitos sea una
rareza de un solo catálogo.

---

## 3. `cod_dw_persona_ubic = ci.id` — la llave no es de la fila

`strct/.../02_vistas_insumo_edf_views.sql:19-21`:

```sql
loc.id   AS cod_dw_ubic,
ci.id    AS cod_dw_persona_ubic,
ci.id    AS cod_dw_direccion_fisica,
```

El documento del cliente mide `xpm_location_val_contactinformations`:
**568 657 filas / 142 067 `id` distintos, unos 4:1.** Y dice, literal, que «la
llave debe derivarse de `(id, index)`». Nosotros **no usamos `"index"` en
ningún archivo**.

Si la medición es correcta, en producción `cod_dw_persona_ubic` **colapsa unos
cuatro contactos en uno**, y toda la Unificación y todo el Ordenamiento operan
sobre un grano fundido.

**No está verificado por nosotros:** no tenemos acceso al datashare. Es la única
afirmación de este documento que descansa en una medición ajena, y es la más
cara de las tres si resulta cierta. Se verifica con una consulta en QA/UAT:

```sql
SELECT COUNT(*) AS filas, COUNT(DISTINCT id) AS ids
  FROM ds_dba_rncr_batch.edf_views.xpm_location_val_contactinformations;
```

Cualquier cociente lejos de 1,0 confirma el problema. Es, además, exactamente el
riesgo `R8` del análisis de performance, que ya decía que la cardinalidad de
estas llaves «está en los datos, no en el código» y que el mock no puede verla.

---

## 4. Lo que sí se cargó, y por qué fue seguro

`strct/.../21_ddl_catalogos_dominio.sql` carga los **cuatro catálogos que no
tenían contraparte en el repo**, con todas sus columnas:

| Tabla | Filas | Para qué sirve ya |
|---|---|---|
| `catalogo_razon_bloqueo` | 18 | es el filtro de bloqueo que el criterio `F3-01` del Ordenamiento echa de menos |
| `catalogo_gestion_registro` | 2 | es el catálogo real que hoy sustituye una expresión regular (`04_vistas_insumo_ordenamiento_edf_views.sql:104-107`) |
| `catalogo_fuente` | 6 | gap del Bloque B de la petición de datashare |
| `catalogo_fuente_dato` | 33 | gap del Bloque A |

Son **aditivos**: ninguna consulta los lee todavía, así que no mueven un dígito
de lo certificado. Quedan listos para cuando la mesa decida cablearlos.

### Los dos que llegaron truncados

`V_Cod_Entrega_Dato` y `V_Geografia` vienen con **exactamente 1000 filas** cada
uno —`V_Geografia` se corta en Santander, departamento 68, de 99— así que son
exportes con tope. **No se cargan a medias**: un catálogo geográfico parcial no
da error, da joins que no casan, en silencio, que es justo el modo de fallo de
los tres hallazgos de arriba. Hay que pedir el export completo.

---

## Lo que esto deja sobre la mesa

1. **¿Se adopta el diccionario de 58 nomenclaturas?** Cambia resultados de
   Unificación, así que obliga a re-certificar y a ampliar el mock, que hoy
   siembra solo 12.
2. **¿Se adoptan las llaves reales de `tipo_ubicacion_dir`?** Mismo efecto sobre
   Ordenamiento.
3. **¿Alguien puede correr la consulta de cardinalidad de `ci.id` en QA/UAT?**
   Es una consulta, no un despliegue, y decide si hay un problema de grano en
   dos procesos ya entregados.
4. **El export completo** de `V_Cod_Entrega_Dato` y `V_Geografia`.

Y una lección que ya va por la cuarta vez en este proyecto, contando
`sector_financiero`: **un catálogo que nos inventamos no falla, degrada.** No
hay error, no hay excepción, no hay criterio en rojo. Sale un NULL, el `LEFT
JOIN` lo acepta, y el resultado es plausible y equivocado.
