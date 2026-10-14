#!/usr/bin/env python3
"""Genera las tablas stub del datashare, derivandolas de las vistas.

Postgres no tiene vistas de enlace tardio: `WITH NO SCHEMA BINDING` desaparece
en el transpilado, asi que las cuatro tablas de `edf_views` tienen que EXISTIR
antes de que se cree cualquier vista de strct.

Se derivan, no se escriben a mano, por una razon concreta: las columnas son los
nombres que escupe el relationalize del JSON
("location.val.contactinformations.val.standardizedcomplemento") y transcribir
treinta de esos a mano es garantia de una errata que luego parece un bug del
codigo. La entrada son las DOS unicas vistas que leen el datashare.

Las tablas quedan VACIAS. La via de certificacion mock lee bdm_tempo.v_mock_*,
no estas: el stub solo tiene que permitir que las vistas y los procedimientos
REALES se CREEN.

Tipado, tres reglas y una excepcion:
  - entre comillas dobles        -> VARCHAR(4000)   (en el real todo es texto)
  - identificador desnudo        -> BIGINT          (son los id de join)
  - en una igualdad con un BIGINT-> BIGINT
      sin esta tercera regla, loc."location.val.contactinformations" quedaria
      VARCHAR y el join `ON loc."..." = ci.id` daria
      `operator does not exist: character varying = bigint`, que parece un
      error del codigo y no lo es.
  - EXCEPCION xpm.pin -> VARCHAR: en produccion es texto y es el argumento de
      FNV_HASH, cuyo shim rechaza a proposito la sobrecarga numerica.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from transpila import mapa_codigo, busca_cod, CODE  # noqa: E402

REF = r'([a-z_][a-z0-9_]*)\.("(?:[^"]*)"|[a-z_][a-z0-9_]*)'


def analiza(textos):
    tablas = {}        # tabla -> {columna: tipo}
    for s in textos:
        m = mapa_codigo(s)
        # alias -> tabla, solo donde la referencia esta en codigo
        alias = {}
        pos = 0
        while True:
            mm = busca_cod(
                s, m,
                r'ds_dba_rncr_batch\.edf_views\.([a-z_][a-z0-9_]*)\s+([a-z_][a-z0-9_]*)',
                pos)
            if not mm:
                break
            alias[mm.group(2)] = mm.group(1)
            pos = mm.start() + 1
        # referencias alias.columna
        refs = []
        for mm in re.finditer(REF, s, re.IGNORECASE):
            if m[mm.start()] != CODE:
                continue
            a, c = mm.group(1), mm.group(2)
            if a in alias:
                refs.append((alias[a], c, mm.start(), mm.end()))
        for t, c, _, _ in refs:
            tablas.setdefault(t, {})
            tablas[t].setdefault(c, 'VARCHAR(4000)' if c.startswith('"') else 'BIGINT')
        # tercera regla: igualdades entre dos referencias
        for mm in re.finditer(REF + r'\s*=\s*' + REF, s, re.IGNORECASE):
            if m[mm.start()] != CODE:
                continue
            a1, c1, a2, c2 = mm.group(1), mm.group(2), mm.group(3), mm.group(4)
            if a1 not in alias or a2 not in alias:
                continue
            t1, t2 = alias[a1], alias[a2]
            lados = [(t1, c1), (t2, c2)]
            if any(tablas.get(t, {}).get(c) == 'BIGINT' for t, c in lados):
                for t, c in lados:
                    if (t, c) != ('xpm', 'pin'):      # la excepcion
                        tablas.setdefault(t, {})[c] = 'BIGINT'
    tablas.setdefault('xpm', {})['pin'] = 'VARCHAR(4000)'
    return tablas


def emite(tablas):
    out = ['-- GENERADO por banco/stub_datashare.py -- NO editar a mano.',
           '-- Cuatro tablas vacias que imitan ds_dba_rncr_batch.edf_views.',
           '-- Se regeneran; si una columna esta mal tipada, se arregla la regla.',
           '',
           'CREATE SCHEMA IF NOT EXISTS edf_views;',
           '']
    for t in sorted(tablas):
        cols = sorted(tablas[t].items(), key=lambda kv: (kv[1] != 'BIGINT', kv[0]))
        out.append('CREATE TABLE IF NOT EXISTS edf_views.%s (' % t)
        out.append(',\n'.join('  %-74s %s' % (c, ty) for c, ty in cols))
        out.append(');')
        out.append('')
    return '\n'.join(out)


if __name__ == '__main__':
    textos = []
    for p in sys.argv[1:]:
        with open(p, encoding='utf-8', errors='surrogateescape') as f:
            textos.append(f.read())
    tablas = analiza(textos)
    sys.stdout.write(emite(tablas))
    sys.stderr.write('stub: %d tablas, %d columnas\n'
                     % (len(tablas), sum(len(v) for v in tablas.values())))
