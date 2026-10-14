#!/usr/bin/env python3
"""Emite el SQL que comprueba que todo objeto del DDL existe de verdad.

Por que esto y no "cada archivo corrio limpio": en Redshift las vistas son
WITH NO SCHEMA BINDING, de enlace tardio, y el DDL de strct se apoya en eso de
dos maneras que Postgres no admite:

  - 02_vistas_insumo_edf_views.sql referencia bdm_datos.geo_atributos, que crea
    03_ddl_geo.sql tres archivos despues.
  - 04_vistas_insumo_ordenamiento_edf_views.sql:44-55 hace DROP TABLE IF EXISTS
    y DESPUES DROP VIEW IF EXISTS sobre el mismo nombre, con un comentario que
    explica por que ese orden: en Redshift el DROP TABLE sobre una vista es un
    no-op, y el DROP VIEW sobre una tabla aborta con 42809. En Postgres el
    DROP TABLE IF EXISTS sobre una vista NO es un no-op: da "is not a table".

Las dos cosas son divergencias del banco, no defectos del codigo. Perseguirlas
archivo a archivo produce ruido. La pregunta que si importa es: al terminar la
fase, existen todos los objetos? Eso es lo que mide este archivo.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from transpila import mapa_codigo, CODE  # noqa: E402

# El deploy es SECUENCIAL, asi que gana la ultima sentencia que toca un nombre.
# Importa de verdad: 01_ddl_ordenamiento.sql:61 crea la tabla
# bdm_datos.insumo_direccion y 04_vistas_insumo_ordenamiento_edf_views.sql la
# BORRA tres archivos despues para poner una vista con el mismo nombre (es el
# refactor "no copiar el universo XPM" que anuncia su cabecera). Con "gana la
# primera" el verificador pediria una tabla que el propio deploy destruye.
PATRONES = [
    ('crea_r', r'CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?([a-z_][a-z0-9_]*\.[a-z_][a-z0-9_]*)'),
    ('crea_v', r'CREATE\s+(?:OR\s+REPLACE\s+)?VIEW\s+([a-z_][a-z0-9_]*\.[a-z_][a-z0-9_]*)'),
    ('crea_p', r'CREATE\s+(?:OR\s+REPLACE\s+)?PROCEDURE\s+([a-z_][a-z0-9_]*\.[a-z_][a-z0-9_]*)'),
    ('crea_f', r'CREATE\s+(?:OR\s+REPLACE\s+)?FUNCTION\s+([a-z_][a-z0-9_]*\.[a-z_][a-z0-9_]*)'),
    ('borra',  r'DROP\s+(?:TABLE|VIEW|PROCEDURE|FUNCTION)\s+(?:IF\s+EXISTS\s+)?([a-z_][a-z0-9_]*\.[a-z_][a-z0-9_]*)'),
]
CLASE = {'crea_r': 'r', 'crea_v': 'v', 'crea_p': 'p', 'crea_f': 'f'}


NAMEDATALEN = 63


def nivel_superior(s, m):
    """bytearray: 1 donde la sentencia es de NIVEL SUPERIOR del archivo.

    Lo de dentro de un cuerpo $$...$$ no cuenta. Un procedimiento crea y borra
    sus propias bdm_tempo.stg_* EN EJECUCION, de modo que esperarlas al terminar
    la fase es un falso positivo: tras la fase pgm no existe ninguna, y es
    correcto que no exista.
    """
    t = bytearray([1]) * len(s)
    dentro, i, n = False, 0, len(s)
    while i < n:
        if m[i] == CODE and s[i] == '$':
            mm = re.match(r'\$[A-Za-z_0-9]*\$', s[i:])
            if mm:
                dentro = not dentro
                for k in range(i, i + mm.end()):
                    t[k] = 0
                i += mm.end()
                continue
        if dentro:
            t[i] = 0
        i += 1
    return t


def objetos(paths):
    """Nombre -> clase esperada al TERMINAR la fase. Un DROP retira la espera."""
    esperado = {}
    muertos = []
    for p in paths:
        with open(p, encoding='utf-8', errors='surrogateescape') as f:
            s = f.read()
        m = mapa_codigo(s)
        top = nivel_superior(s, m)
        eventos = []
        for accion, pat in PATRONES:
            for mm in re.finditer(pat, s, re.IGNORECASE):
                if m[mm.start()] == CODE and top[mm.start()]:
                    eventos.append((mm.start(), accion, mm.group(1).lower()))
        for _, accion, nombre in sorted(eventos):
            if accion == 'borra':
                if nombre in esperado:
                    muertos.append(nombre)
                esperado.pop(nombre, None)
            else:
                esperado[nombre] = CLASE[accion]
    return esperado, sorted(set(muertos))


if __name__ == '__main__':
    par, sqldir = sys.argv[1], sys.argv[2]
    paths = []
    with open(par, encoding='utf-8') as f:
        for ln in f:
            ln = ln.strip()
            if ln and os.path.exists(os.path.join(sqldir, ln)):
                paths.append(os.path.join(sqldir, ln))
    obj, muertos = objetos(paths)
    for d in muertos:
        sys.stderr.write('  DDL que el propio deploy destruye y no repone: %s\n' % d)
    # Postgres trunca los identificadores a 63 bytes y Redshift admite 127. En
    # estos repos hay 13 que pasan de 63 -- el mas largo, 80 -- y cero
    # colisiones al truncar, asi que truncar aqui es exacto, no una
    # aproximacion.
    def corta(n):
        e, _, o = n.partition('.')
        return '%s.%s' % (e, o.encode()[:NAMEDATALEN].decode('utf-8', 'ignore'))
    filas = ',\n  '.join("('%s','%s')" % (corta(k), v)
                         for k, v in sorted(obj.items()))
    print("""\\pset tuples_only on
WITH esperado(nombre, clase) AS ( VALUES
  %s
),
real AS (
  SELECT n.nspname || '.' || c.relname AS nombre,
         CASE c.relkind WHEN 'r' THEN 'r' WHEN 'v' THEN 'v' ELSE 'o' END AS clase
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  UNION ALL
  SELECT n.nspname || '.' || p.proname,
         CASE p.prokind WHEN 'p' THEN 'p' ELSE 'f' END
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
)
SELECT CASE WHEN COUNT(*) = 0
            THEN 'TODOS LOS ' || %d || ' OBJETOS EXISTEN'
            ELSE 'FALTAN ' || COUNT(*) || ' DE %d: '
                 || string_agg(e.clase || ' ' || e.nombre, ', ' ORDER BY e.nombre)
       END
FROM esperado e
WHERE NOT EXISTS (SELECT 1 FROM real r
                   WHERE r.nombre = e.nombre AND r.clase = e.clase);""" % (
        filas, len(obj), len(obj)))
