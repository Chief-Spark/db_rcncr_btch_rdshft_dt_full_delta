"""
Lambda UDF de Amazon Redshift: port de las UDF C de similitud de Teradata
(base REC_VISTA) que usa PRO_BATCH2_FILTRO_F (sp_batch2_filtro_f en Redshift).

Fuentes portadas (FuncionesUDF/ del workspace):
  Bach_Similitud_Dir_MZ/BachSimilitudDirMZ.c  -> rec_vista.f_bach_similitud_dir_mz
  PorcSimilitud/PorcSimilitud.c               -> rec_vista.f_porc_similitud
  Bach_Similitud_Tel/BachSimilitudTel.c       -> rec_vista.f_bach_similitud_tel
  Bach_Similitud_email/BachSimilitudEmail.c   -> rec_vista.f_bach_similitud_email

Una sola funcion Lambda atiende las 4 UDF. El handler elige la UDF por el
campo "external_function" que Redshift envia en cada invocacion (nombre
calificado, p. ej. "rec_vista.f_bach_similitud_tel"). La variable de entorno
UDF_NOMBRE, si existe, fuerza una UDF fija (para desplegar 4 Lambdas
separadas con el mismo codigo).

Contrato Redshift (https://docs.aws.amazon.com/redshift/latest/dg/udf-creating-a-lambda-sql-udf.html):
  entrada : {"external_function": "...", "num_records": n,
             "arguments": [[a1, a2, ...], ...]}   (un registro puede ser null)
  salida  : JSON string {"success": true, "num_records": n, "results": [...]}
            en el mismo orden de "arguments".

Semantica Teradata/C que se replica a proposito:
  1. PARAMETER STYLE TD_GENERAL: la UDF no recibe NULL. Si algun argumento
     es NULL, Teradata no la invoca y el resultado es NULL. Aqui: cualquier
     argumento None -> resultado None.
  2. Largo de los parametros VARCHAR declarados en Teradata (VARCHAR(20) en
     PorcSimilitud y Bach_Similitud_Tel, VARCHAR(30)/VARCHAR(5) en
     Bach_Similitud_email, VARCHAR(500) en Bach_Similitud_Dir_MZ). En modo de
     sesion Teradata (BTET), un argumento mas largo se trunca en silencio al
     largo del parametro. FILTRO_F llama a PorcSimilitud con direcciones
     completas, asi que en Teradata solo se comparan sus primeros 20
     caracteres. Aqui se trunca igual (TRUNCAR_A).
  3. Conversion double -> int de C (asignacion a INTEGER): trunca hacia cero.
     En x86-64 (cvttsd2si) NaN, +/-inf o fuera de rango -> INT_MIN
     (-2147483648). Pasa cuando el texto del insumo esta vacio (division por
     cero). Se replica con _c_int.
  4. Aritmetica int de 32 bits con desborde (solo relevante en el caso
     INT_MIN de Bach_Similitud_email): _wrap32.
  5. Comparaciones con strcmp: sensibles a mayusculas, sin importar la
     collation CASE_INSENSITIVE de la base Redshift.

Distancia de edicion: las 4 UDF llaman a editdistance_u(s1, s2, &ci, &cd,
&cs, &ct, ...) de loadParamsAcepAut.h, que NO esta en el workspace. Su firma
(costos de insercion, borrado, sustitucion y transposicion) es la de
EDITDISTANCE de Teradata (Damerau-Levenshtein). Se implementa la version
OSA (Optimal String Alignment, transposicion de adyacentes) con los 4
costos. Supuesto a validar en Teradata con los casos del test
(test_lambda_function.py, clase TestDistancia).

No portada: Bach_Similitud_Dir_VIA (FuncionesUDF/Bach_Similitud_Dir_VIA).
Ningun SP de BATCH2 la llama y depende de Address_Normalization
(AddressNormalization.h), cuyo codigo no esta en el workspace.

Rendimiento: la distancia es O(n*m) en Python puro. Con direcciones de ~100
caracteres son ~10^4 celdas por par. Para volumenes grandes, ajustar memoria
de la Lambda y MAX_BATCH_ROWS en CREATE EXTERNAL FUNCTION.
"""

import json
import math
import os
import re

INT32_MIN = -2147483648
INT32_MAX = 2147483647

# Largo de cada parametro VARCHAR declarado en la UDF Teradata (.BTQ)
TRUNCAR_A = {
    "f_bach_similitud_dir_mz": {0: 500, 1: 500},
    "f_porc_similitud": {0: 20, 1: 20},
    "f_bach_similitud_tel": {0: 20, 1: 20},
    "f_bach_similitud_email": {0: 30, 1: 30, 2: 5, 3: 5, 4: 30, 5: 30, 6: 5, 7: 5},
}

_RE_NUMERO_MZ = re.compile(r"[0-9]{1,9}")  # valExpRegStr(word, "^[0-9]{1,9}$")


# ---------------------------------------------------------------------------
# Emulacion de semantica C
# ---------------------------------------------------------------------------
def _c_int(x):
    """double -> int de C en x86-64: trunca hacia cero; NaN/inf/fuera de rango -> INT_MIN."""
    if math.isnan(x) or math.isinf(x):
        return INT32_MIN
    t = int(x)  # int() de Python trunca hacia cero, igual que C
    if t < INT32_MIN or t > INT32_MAX:
        return INT32_MIN
    return t


def _wrap32(n):
    """Resultado de una operacion int de 32 bits con desborde (complemento a 2)."""
    n &= 0xFFFFFFFF
    return n - 0x100000000 if n >= 0x80000000 else n


def _div(a, b):
    """Division double de C (IEEE 754): x/0.0 -> +/-inf, 0.0/0.0 -> NaN."""
    if b == 0:
        if a == 0 or math.isnan(a):
            return math.nan
        return math.copysign(math.inf, a) * math.copysign(1.0, b)
    return a / b


# ---------------------------------------------------------------------------
# editdistance_u (Damerau-Levenshtein OSA con costos)
# ---------------------------------------------------------------------------
def edit_distance(s, t, ci=1, cd=1, cs=1, ct=1):
    """Distancia de edicion de s a t: insercion ci, borrado cd, sustitucion cs,
    transposicion de caracteres adyacentes ct (variante OSA)."""
    n, m = len(s), len(t)
    if n == 0:
        return m * ci
    if m == 0:
        return n * cd
    prev2 = None
    prev = [j * ci for j in range(m + 1)]
    for i in range(1, n + 1):
        cur = [i * cd] + [0] * m
        si = s[i - 1]
        for j in range(1, m + 1):
            tj = t[j - 1]
            v = prev[j - 1] + (0 if si == tj else cs)
            d = prev[j] + cd
            if d < v:
                v = d
            ins = cur[j - 1] + ci
            if ins < v:
                v = ins
            if i > 1 and j > 1 and si == t[j - 2] and s[i - 2] == tj:
                tr = prev2[j - 2] + ct
                if tr < v:
                    v = tr
            cur[j] = v
        prev2, prev = prev, cur
    return prev[m]


# ---------------------------------------------------------------------------
# UDF
# ---------------------------------------------------------------------------
def similitud_tel(tel_insumo, tel_bodega):
    """BachSimilitudTel.c -> INTEGER."""
    len_tel = len(tel_insumo)
    dist = edit_distance(tel_insumo, tel_bodega)
    # *outSimilitud = (1.0-((*outDist1*1.0)/(lenTel*1.0))+0.00499)*100;
    return _c_int((1.0 - _div(dist * 1.0, len_tel * 1.0) + 0.00499) * 100)


def porc_similitud(cad_insumo, cad_bodega):
    """PorcSimilitud.c -> FLOAT. Devuelve None si el resultado no es finito
    (insumo vacio): ni JSON ni Redshift representan inf/NaN en este contrato."""
    len_tel = len(cad_insumo)
    dist = edit_distance(cad_insumo, cad_bodega)
    # *outSimilitud = ((lenTel - *outDist1)*1.0/lenTel*1.0 )*100 ;
    r = (_div((len_tel - dist) * 1.0, len_tel) * 1.0) * 100
    if math.isnan(r) or math.isinf(r):
        return None
    return r


def similitud_email(buzon_ins, dominio_ins, soun_buz_ins, soun_dom_ins,
                    buzon_bod, dominio_bod, soun_buz_bod, soun_dom_bod,
                    por_bz, por_bz_soun, por_bz_dist,
                    por_dom, por_dom_soun, por_dom_dist):
    """BachSimilitudEmail.c -> INTEGER."""
    por_soun_bz = 100 if soun_buz_ins == soun_buz_bod else 0
    por_soun_dom = 100 if soun_dom_ins == soun_dom_bod else 0

    dist_bz = edit_distance(buzon_ins, buzon_bod)
    dist_dom = edit_distance(dominio_ins, dominio_bod)

    largo_bz = len(buzon_ins)
    largo_dom = len(dominio_ins)

    # outPorcDistanciaBz = (((outLargoBz-(*outDistBz))*1.0/outLargoBz*1.0))*100.0;  (int)
    porc_dist_bz = _c_int(_div((largo_bz - dist_bz) * 1.0, largo_bz) * 1.0 * 100.0)
    porc_dist_dom = _c_int(_div((largo_dom - dist_dom) * 1.0, largo_dom) * 1.0 * 100.0)

    # outPorBzIn = (((porSounBz*(*PorBzSounIn))*1.0+(outPorcDistanciaBz*(*PorBzDistIn))*1.0)*(*PorBzIn))/10000.0;  (int)
    p_bz = _c_int(((_wrap32(por_soun_bz * por_bz_soun) * 1.0
                    + _wrap32(porc_dist_bz * por_bz_dist) * 1.0) * por_bz) / 10000.0)
    p_dom = _c_int(((_wrap32(por_soun_dom * por_dom_soun) * 1.0
                     + _wrap32(porc_dist_dom * por_dom_dist) * 1.0) * por_dom) / 10000.0)

    # *outSimilitud = round(outPorBzIn + outPorDomIn);  suma int -> round() no cambia el valor
    return _wrap32(p_bz + p_dom)


def _palabras(cadena):
    """Recorrido caracter a caracter del C: palabras separadas por ' ' (solo
    espacio), sin palabras vacias."""
    return [w for w in cadena.split(" ") if w]


def similitud_dir_mz(dir_insumo, dir_bodega,
                     por_hit_mz0, por_dis_mz0, por_hit_mz1, por_dis_mz1,
                     por_hit_mz2, por_dis_mz2, por_hit_mz3, por_dis_mz3):
    """BachSimilitudDirMZ.c (funcion similitudDirMZ) -> INTEGER.
    Puede devolver valores > 100 (aciertos numericos duplicados en la
    bodega) o < 0 (distancia mayor que el largo del insumo); FILTRO_F lo
    acota con su CASE."""
    pal_ins = _palabras(dir_insumo)
    pal_bod = _palabras(dir_bodega)

    cant_num = 0
    count_hits = 0
    num_bod = [w for w in pal_bod if _RE_NUMERO_MZ.fullmatch(w)]
    for w in pal_ins:
        if _RE_NUMERO_MZ.fullmatch(w):
            cant_num += 1
            # Cuenta cada coincidencia en la bodega (si se repite, suma varias veces)
            count_hits += sum(1 for b in num_bod if b == w)

    if cant_num == 0:
        por_hit, por_dis = por_hit_mz0, por_dis_mz0
    elif cant_num == 1:
        por_hit, por_dis = por_hit_mz1, por_dis_mz1
    elif cant_num == 2:
        por_hit, por_dis = por_hit_mz2, por_dis_mz2
    else:
        por_hit, por_dis = por_hit_mz3, por_dis_mz3

    dist = edit_distance(dir_insumo, dir_bodega)
    len_ins = len(dir_insumo)

    if cant_num != 0 and len_ins != 0:
        r = ((((count_hits * 1.0) / (cant_num * 1.0)) * ((por_hit * 1.0) / 100.0))
             + ((1 - ((dist * 1.0) / (len_ins * 1.0))) * ((por_dis * 1.0) / 100.0))
             + 0.00499) * 100
        return _c_int(r)
    if cant_num == 0 and len_ins != 0:
        r = 0 + (((1 - ((dist * 1.0) / (len_ins * 1.0))) * ((por_dis * 1.0) / 100.0))
                 + 0.00499) * 100
        return _c_int(r)
    if cant_num != 0 and len_ins == 0:  # inalcanzable: sin texto no hay palabras
        r = ((((count_hits * 1.0) / (cant_num * 1.0)) * ((por_hit * 1.0) / 100.0))
             + 0 + 0.00499) * 100
        return _c_int(r)
    return 0


# nombre -> (funcion, numero de argumentos, indices de argumentos INTEGER)
UDFS = {
    "f_bach_similitud_dir_mz": (similitud_dir_mz, 10, range(2, 10)),
    "f_porc_similitud": (porc_similitud, 2, ()),
    "f_bach_similitud_tel": (similitud_tel, 2, ()),
    "f_bach_similitud_email": (similitud_email, 14, range(8, 14)),
}


def _nombre_udf(event):
    forzado = os.environ.get("UDF_NOMBRE")
    nombre = forzado if forzado else (event.get("external_function") or "")
    return nombre.replace('"', "").strip().split(".")[-1].lower()


def evaluar(nombre, registro):
    """Evalua una fila. registro: lista de argumentos (o None)."""
    func, n_args, idx_int = UDFS[nombre]
    if registro is None:
        return None
    if not isinstance(registro, list):
        registro = [registro]
    if len(registro) != n_args:
        raise ValueError("%s espera %d argumentos y recibio %d" % (nombre, n_args, len(registro)))
    if any(a is None for a in registro):
        return None  # TD_GENERAL: NULL de entrada -> NULL
    args = list(registro)
    for i, largo in TRUNCAR_A[nombre].items():
        args[i] = str(args[i])[:largo]
    for i in idx_int:
        args[i] = int(args[i])
    return func(*args)


def lambda_handler(event, context):
    try:
        nombre = _nombre_udf(event)
        if nombre not in UDFS:
            raise ValueError("UDF no soportada por esta Lambda: '%s'" % nombre)
        registros = event.get("arguments") or []
        resultados = [evaluar(nombre, r) for r in registros]
        return json.dumps({"success": True,
                           "num_records": len(resultados),
                           "results": resultados})
    except Exception as exc:  # Redshift aborta la consulta y muestra error_msg
        return json.dumps({"success": False, "error_msg": "%s: %s" % (type(exc).__name__, exc)})
