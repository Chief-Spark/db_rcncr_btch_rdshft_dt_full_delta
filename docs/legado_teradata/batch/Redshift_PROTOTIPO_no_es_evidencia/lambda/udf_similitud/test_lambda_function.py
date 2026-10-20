"""
Pruebas de la Lambda UDF de similitud y de las SQL UDF de enmascaramiento.

Ejecutar (Python 3.9+, solo libreria estandar):
    python -m unittest -v test_lambda_function.py

Los casos marcados "BTQ" son los SELECT de prueba que vienen comentados en
los .BTQ de FuncionesUDF/. Sus valores esperados salen de aplicar a mano las
formulas del codigo C; deben confirmarse en Teradata con
casos_validacion_teradata.sql.
"""

import json
import random
import re
import unittest
from functools import lru_cache

import lambda_function as lf


# ---------------------------------------------------------------------------
# Referencias independientes
# ---------------------------------------------------------------------------
def osa_referencia(a, b):
    """OSA recursiva con memo (implementacion distinta a la de la Lambda)."""
    @lru_cache(maxsize=None)
    def d(i, j):
        if i == 0:
            return j
        if j == 0:
            return i
        best = min(d(i - 1, j) + 1, d(i, j - 1) + 1, d(i - 1, j - 1) + (a[i - 1] != b[j - 1]))
        if i > 1 and j > 1 and a[i - 1] == b[j - 2] and a[i - 2] == b[j - 1]:
            best = min(best, d(i - 2, j - 2) + 1)
        return best
    return d(len(a), len(b))


# Port literal del C de enmascaramiento (DataMasking.c, DirDataMasking.c,
# RazonDataMasking.c), con el VARCHAR(200) de entrada de Teradata.
def c_datamasking(dato):
    if dato is None:
        return None
    dato = dato[:200]
    n = len(dato)
    if n > 3:
        return dato[:n - 4] + "XXXX"
    return dato  # en C el buffer queda sin inicializar; decision: devolver el dato


def c_dirdatamasking(d):
    if d is None:
        return None
    return "".join("X" if ch in "0123456789" else ch for ch in d[:200])


def c_razondatamasking(razon):
    if razon is None:
        return None
    tokens = [t for t in razon[:200].split(" ") if t]  # strtok(str, " ")
    salida = []
    for t in tokens:
        if len(t) > 3:
            t = t[:-4] + "XXXX"
        salida.append(t)
    return " ".join(salida)


# Emulacion en Python de las formulas SQL de ddl/08_funciones_udf.sql
def sql_datamasking(v):
    if v is None:
        return None
    x = v[:200]                                   # LEFT($1, 200)
    return x[:len(x) - 4] + "XXXX" if len(x) > 3 else x


def sql_dirdatamasking(v):
    if v is None:
        return None
    return v[:200].translate(str.maketrans("0123456789", "XXXXXXXXXX"))  # TRANSLATE


def sql_razondatamasking(v):
    if v is None:
        return None
    x = re.sub(" +", " ", v[:200].strip(" "))     # REGEXP_REPLACE(BTRIM(LEFT($1,200)), ' +', ' ')
    x = re.sub("[^ ]{4} ", "XXXX ", x + " ")      # REGEXP_REPLACE(x || ' ', '[^ ]{4} ', 'XXXX ')
    return x.rstrip(" ")                          # RTRIM(x, ' ')


PESOS_MZ = (0, 100, 20, 80, 50, 50, 70, 30)       # los de FILTRO_F y del BTQ
PESOS_MAIL = (70, 50, 50, 30, 50, 50)


# ---------------------------------------------------------------------------
class TestSemanticaC(unittest.TestCase):
    def test_c_int_trunca_hacia_cero(self):
        self.assertEqual(lf._c_int(86.9), 86)
        self.assertEqual(lf._c_int(-66.2), -66)

    def test_c_int_no_finito(self):
        self.assertEqual(lf._c_int(float("nan")), lf.INT32_MIN)
        self.assertEqual(lf._c_int(float("-inf")), lf.INT32_MIN)
        self.assertEqual(lf._c_int(3e10), lf.INT32_MIN)

    def test_wrap32(self):
        self.assertEqual(lf._wrap32(lf.INT32_MIN * 50), 0)
        self.assertEqual(lf._wrap32(lf.INT32_MIN * 51), lf.INT32_MIN)
        self.assertEqual(lf._wrap32(5000), 5000)


class TestDistancia(unittest.TestCase):
    def test_valores_conocidos(self):
        self.assertEqual(lf.edit_distance("kitten", "sitting"), 3)
        self.assertEqual(lf.edit_distance("", "abc"), 3)
        self.assertEqual(lf.edit_distance("abc", ""), 3)
        self.assertEqual(lf.edit_distance("abc", "abc"), 0)

    def test_transposicion_adyacente_cuesta_1(self):
        # Levenshtein puro daria 2
        self.assertEqual(lf.edit_distance("ab", "ba"), 1)
        self.assertEqual(lf.edit_distance("3434620", "3436420"), 1)

    def test_osa_no_es_damerau_completo(self):
        # OSA = 3; Damerau-Levenshtein sin restriccion = 2. Discrimina el
        # supuesto sobre editdistance_u (ver casos_validacion_teradata.sql).
        self.assertEqual(lf.edit_distance("CA", "ABC"), 3)

    def test_sensible_a_mayusculas(self):
        self.assertEqual(lf.edit_distance("abc", "ABC"), 3)

    def test_contra_referencia_aleatoria(self):
        rnd = random.Random(20261014)
        for _ in range(3000):
            a = "".join(rnd.choice("ab1 ") for _ in range(rnd.randint(0, 8)))
            b = "".join(rnd.choice("ab1 ") for _ in range(rnd.randint(0, 8)))
            self.assertEqual(lf.edit_distance(a, b), osa_referencia(a, b), (a, b))


class TestSimilitudTel(unittest.TestCase):
    # BTQ: REC_VISTA.Bach_Similitud_Tel(B, A) -> insumo = B, bodega = A
    def test_btq(self):
        self.assertEqual(lf.similitud_tel("2826373", "2826373"), 100)
        self.assertEqual(lf.similitud_tel("2822994", "2822992"), 86)
        self.assertEqual(lf.similitud_tel("3434620", "3436420"), 86)   # transposicion
        self.assertEqual(lf.similitud_tel("3432064", "3436420"), 43)   # dist 4
        self.assertEqual(lf.similitud_tel("7654321", "1234567"), 14)

    def test_bodega_vacia(self):
        self.assertEqual(lf.similitud_tel("123", ""), 0)   # (1-3/3+0.00499)*100 = 0.499

    def test_negativo(self):
        # distancia 5 > largo 3: (1-5/3+0.00499)*100 = -66.17 -> -66
        self.assertEqual(lf.similitud_tel("123", "12345678"), -66)

    def test_insumo_vacio_x86(self):
        self.assertEqual(lf.similitud_tel("", "123"), lf.INT32_MIN)
        self.assertEqual(lf.similitud_tel("", ""), lf.INT32_MIN)


class TestPorcSimilitud(unittest.TestCase):
    def test_iguales(self):
        self.assertEqual(lf.porc_similitud("CL 10 20 30", "CL 10 20 30"), 100.0)

    def test_valor(self):
        self.assertAlmostEqual(lf.porc_similitud("2822994", "2822992"), 600.0 / 7, places=10)

    def test_vacio(self):
        self.assertIsNone(lf.porc_similitud("", "ABC"))

    def test_truncamiento_varchar20_en_handler(self):
        a = "CALLE 123 NUMERO 45 67 SUR BARRIO"
        b = "CALLE 123 NUMERO 45 67 NORTE"
        self.assertEqual(lf.evaluar("f_porc_similitud", [a, b]),
                         lf.porc_similitud(a[:20], b[:20]))
        self.assertEqual(lf.evaluar("f_porc_similitud", [a, b]), 100.0)


class TestSimilitudEmail(unittest.TestCase):
    def test_btq(self):
        # luedu01 vs luedu: dist 2, largo 7 -> 71; ((100*50+71*50)*70)/10000 = 59.85 -> 59
        # gmail.com igual -> 30. Total 89 (con SOUNDEX iguales en ambos)
        r = lf.similitud_email("luedu01", "gmail.com", "L300", "G540",
                               "luedu", "gmail.com", "L300", "G540", *PESOS_MAIL)
        self.assertEqual(r, 89)

    def test_iguales(self):
        r = lf.similitud_email("ana", "x.com", "A500", "X250",
                               "ana", "x.com", "A500", "X250", *PESOS_MAIL)
        self.assertEqual(r, 100)

    def test_soundex_distinto(self):
        # buzon: (0*50 + 100*50)*70/10000 = 35; dominio igual = 30
        r = lf.similitud_email("ana", "x.com", "A500", "X250",
                               "ana", "x.com", "B000", "X250", *PESOS_MAIL)
        self.assertEqual(r, 65)

    def test_buzon_vacio_x86(self):
        # largo 0 -> division por cero -> INT_MIN; INT_MIN*50 desborda a 0
        r = lf.similitud_email("", "x.com", "", "X250",
                               "luedu", "x.com", "", "X250", *PESOS_MAIL)
        self.assertEqual(r, 35 + 30)


class TestSimilitudDirMZ(unittest.TestCase):
    def test_btq(self):
        self.assertEqual(lf.similitud_dir_mz("KR 9 161B 23", "KR 9 161B 23", *PESOS_MZ), 100)

    def test_sin_numeros_usa_pesos_0(self):
        # cant_num 0 -> solo distancia (100 %): MZ A vs MZ B -> dist 1, largo 4
        # (0.75*1.0 + 0.00499)*100 = 75.499 -> 75
        self.assertEqual(lf.similitud_dir_mz("MZ A", "MZ B", *PESOS_MZ), 75)

    def test_aciertos_duplicados_superan_100(self):
        # insumo: '9','9' (cant 2, pesos 50/50); cada uno coincide 3 veces -> 6/2 = 3
        r = lf.similitud_dir_mz("CL 9 9", "CL 9 9 9", *PESOS_MZ)
        # (3*0.5 + (1-2/6)*0.5 + 0.00499)*100 = 183.83 -> 183
        self.assertEqual(r, 183)

    def test_numero_de_10_digitos_no_cuenta(self):
        r1 = lf.similitud_dir_mz("CL 1234567890", "CL 1234567890", *PESOS_MZ)
        self.assertEqual(r1, 100)   # cant 0: (1*1.0+0.00499)*100

    def test_vacio(self):
        self.assertEqual(lf.similitud_dir_mz("", "CL 1", *PESOS_MZ), 0)

    def test_espacios_multiples(self):
        self.assertEqual(lf._palabras("  KR  9 "), ["KR", "9"])


class TestHandler(unittest.TestCase):
    def _call(self, nombre, argumentos):
        evento = {"external_function": nombre, "num_records": len(argumentos),
                  "arguments": argumentos}
        return json.loads(lf.lambda_handler(evento, None))

    def test_contrato_y_nulos(self):
        r = self._call("rec_vista.f_bach_similitud_tel",
                       [["2826373", "2826373"], None, ["1", None]])
        self.assertTrue(r["success"])
        self.assertEqual(r["num_records"], 3)
        self.assertEqual(r["results"], [100, None, None])

    def test_enteros_y_texto(self):
        r = self._call('"rec_vista"."f_bach_similitud_dir_mz"',
                       [["KR 9 161B 23", "KR 9 161B 23"] + list(PESOS_MZ)])
        self.assertEqual(r["results"], [100])

    def test_email_14_args(self):
        r = self._call("rec_vista.f_bach_similitud_email",
                       [["luedu01", "gmail.com", "L300", "G540",
                         "luedu", "gmail.com", "L300", "G540"] + list(PESOS_MAIL)])
        self.assertEqual(r["results"], [89])

    def test_porc_float(self):
        r = self._call("rec_vista.f_porc_similitud", [["ABCD", "ABCD"], ["", "A"]])
        self.assertEqual(r["results"], [100.0, None])

    def test_udf_desconocida(self):
        r = self._call("rec_vista.f_otra", [["a", "b"]])
        self.assertFalse(r["success"])
        self.assertIn("no soportada", r["error_msg"])

    def test_numero_de_argumentos(self):
        r = self._call("rec_vista.f_bach_similitud_tel", [["a"]])
        self.assertFalse(r["success"])


class TestEnmascaramientoSQL(unittest.TestCase):
    """Las SQL UDF de ddl/08 deben dar lo mismo que el C original."""

    def test_ejemplos(self):
        self.assertEqual(c_datamasking("3001234567"), "300123XXXX")
        self.assertEqual(c_datamasking("ABCD"), "XXXX")
        self.assertEqual(c_dirdatamasking("CL 10 # 5-20"), "CL XX # X-XX")
        self.assertEqual(c_razondatamasking("  INVERSIONES  ABC   LTDA "), "INVERSIXXXX ABC XXXX")
        self.assertEqual(c_razondatamasking(""), "")

    def test_equivalencia_aleatoria(self):
        rnd = random.Random(14102026)
        for _ in range(5000):
            v = "".join(rnd.choice("AB1 %\t") for _ in range(rnd.randint(0, 14)))
            self.assertEqual(sql_datamasking(v), c_datamasking(v), repr(v))
            self.assertEqual(sql_dirdatamasking(v), c_dirdatamasking(v), repr(v))
            self.assertEqual(sql_razondatamasking(v), c_razondatamasking(v), repr(v))

    def test_truncamiento_200(self):
        v = "A" * 250
        self.assertEqual(sql_datamasking(v), c_datamasking(v))
        self.assertEqual(len(sql_datamasking(v)), 200)
        self.assertEqual(sql_razondatamasking("AB " * 90), c_razondatamasking("AB " * 90))

    def test_nulos(self):
        self.assertIsNone(sql_datamasking(None))
        self.assertIsNone(sql_dirdatamasking(None))
        self.assertIsNone(sql_razondatamasking(None))


if __name__ == "__main__":
    unittest.main()
