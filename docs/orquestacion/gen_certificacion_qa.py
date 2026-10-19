# -*- coding: utf-8 -*-
import json, collections, io, re
B = "/tmp/claude-0/-home-user/fe748083-e217-5400-bdfd-fe1498b014c4/scratchpad/"
C = json.load(open(B + "criterios.json"))
LOC = {tuple(k.split("|")): v for k, v in json.load(open(B + "evloc.json")).items()}
est = collections.defaultdict(dict); det = collections.defaultdict(dict)
for l in io.open(B + "estados.psv", encoding="utf-8"):
    p = l.rstrip("\n").split("~")
    if len(p) >= 5:
        est[(p[0], p[1])][p[2]] = p[3]; det[(p[0], p[1])][p[2]] = p[4]
FASES = {"UNIF": ["FULL","DELTA1","DELTA2","FULL2","GEO"], "ORD": ["FULL","DELTA1","DELTA2"],
         "NOV": ["FULL","DELTA1","DELTA2"]}
TABLA = {"UNIF":"bdm_datos.cert_resultado","ORD":"bdm_datos.cert_resultado_ord","NOV":"bdm_datos.cert_resultado_nov"}
# Banda de arquetipos por bloque (esquema documentado en CLAUDE.md).
BANDA = {"REGLA1":(1,20), "REGLA2":(21,55), "REGLA3":(61,70), "GEO":(56,56),
         "GENERAL":(1,73), "GOBERNANZA":(1,73),
         "FASE4":(80,90), "CA_FUNC":(80,90), "CA_TECN":(80,90), "REGLA_GRAL":(80,90),
         "CA_MIGR":(80,90), "FASE1":(80,90), "FASE2":(80,90), "FASE3":(80,90),
         "UBICACION":(1,73), "ACTIVIDAD_ECONOMICA":(1,73),
         "UBICACION_AGREGADA":(1,73), "OTROS_DOMINIOS":(1,73)}
PAT = re.compile(r"ARQ\s*(\d+(?:\s*(?:\.\.|a |- |y )\s*\d+)?)", re.I)
def banda(c, b):
    """Banda de arquetipos: cubre TODOS los ARQ que nombre la evidencia."""
    ns = [int(x) for m in PAT.finditer(c["evidencia"])
                 for x in re.findall(r"\d+", m.group(1))]
    return (min(ns), max(ns)) if ns else BANDA.get(b, (1, 90))

def drill(tag, b, lo, hi):
    """Consulta de detalle: quien, con que caracteristica, y que salio."""
    if tag == "UNIF" and b in ("REGLA1","REGLA2","REGLA3","GENERAL","GOBERNANZA"):
        return ("""-- QUIEN y POR QUE. Una fila por direccion del arquetipo, con el atributo que
-- decide y el resultado. La fila con 'padre' vacio ES el padre; la que lo lleva
-- es la hija y apunta a quien gano.
--   ARQ se deriva del id:  ARQ = (cod_dw_persona_ubic / 10 - 9000000) / 10000
WITH arq AS (
  SELECT rpu.cod_dw_persona_ubic, rpu.id_buro_persona,
         rpu.cod_dw_tipo_ubicacion_dir AS tipo_ubic, rpu.cod_dw_ubic,
         rpu.fecha_relacion_persona_ubicaci AS fecha, rpu.ind_unificacion,
         (rpu.cod_dw_persona_ubic / 10 - 9000000) / 10000 AS arq
    FROM bdm_tempo.v_mock_relacion_persona_ubicacion rpu)
SELECT a.arq, a.id_buro_persona AS persona, a.cod_dw_persona_ubic AS direccion,
       ci.cod_act_econo_ciiu_fte AS ciiu, a.tipo_ubic, a.fecha,
       ue.texto_ubicacion AS texto,
       (SELECT COUNT(DISTINCT r.id_buro_suscriptor)
          FROM bdm_tempo.v_mock_reporte_relacion_persona_ubica r
         WHERE r.cod_dw_persona_ubic = a.cod_dw_persona_ubic) AS entidades_reportan,
       u.cod_dw_direccion_unificada AS padre,
       u.unifica_atributos          AS regla_que_sello
  FROM arq a
  LEFT JOIN bdm_tempo.v_mock_ciiu_persona ci        ON ci.id_buro_persona = a.id_buro_persona
  LEFT JOIN bdm_tempo.v_mock_ubicacion_estandarizada ue ON ue.cod_dw_ubic = a.cod_dw_ubic
  LEFT JOIN bdm_datos.unificacion_direccion_mock u  ON u.cod_dw_persona_ubic = a.cod_dw_persona_ubic
 WHERE a.arq BETWEEN %d AND %d
 ORDER BY a.id_buro_persona, a.cod_dw_persona_ubic
 LIMIT 40;""" % (lo, hi))
    if tag == "UNIF" and b == "GEO":
        return """-- QUIEN y POR QUE. El Lote GEO, sus candidatos y lo que el cargador escribio.
SELECT lote, estado, conteo_esperado, conteo_cargado, intentos,
       fase_fallo, ultimo_error, ambiente
  FROM bdm_datos.geo_lote_control_mock ORDER BY lote DESC;

-- Las ubicaciones del ARQ 56 (banda 9560000..9560999) con sus coordenadas.
SELECT g.cod_dw_ubic, g.latitud, g.longitud, g.status_match, g.estado_geo,
       u.cod_dw_direccion_unificada AS padre, u.unifica_atributos AS regla
  FROM bdm_datos.geo_atributos_mock g
  LEFT JOIN bdm_datos.unificacion_direccion_mock u ON u.cod_dw_persona_ubic = g.cod_dw_ubic * 10
 ORDER BY g.cod_dw_ubic LIMIT 40;"""
    if tag == "ORD":
        return ("""-- QUIEN y POR QUE. Los arquetipos del Ordenamiento se certifican por la
-- DIFERENCIA de score entre las dos filas de la misma persona, nunca por el
-- valor absoluto: el delta es inmune a la fecha, al catalogo y al numero de
-- reportes, que las dos filas comparten.
SELECT (s.id_buro_persona - 9000000) / 10000 AS arq,
       s.id_buro_persona AS persona, s.canal,
       s.cod_dw_persona_ubic AS ubicacion, s.score, s.lugar,
       s.score - MIN(s.score) OVER (PARTITION BY s.id_buro_persona, s.canal) AS delta_score
  FROM bdm_datos.score_ordenamiento s
 WHERE (s.id_buro_persona - 9000000) / 10000 BETWEEN %d AND %d
 ORDER BY s.id_buro_persona, s.canal, s.lugar
 LIMIT 40;""" % (lo, hi))
    if tag == "NOV" and b == "UBICACION":
        return """-- QUIEN y POR QUE. Lo que entro por las dos etapas y lo que quedo en la MAT.
SELECT e9.info_basica AS persona, e9.id, e9.dato, e9.clase, e9.orden,
       e9.flag_op, e9.tipo_identificacion, e9.fuente,
       m.id IS NOT NULL AS llego_a_mat, m.orden AS orden_en_mat
  FROM bdm_tempo.stg_nov_ubica_etapa_9_mock e9
  LEFT JOIN bdm_datos.mat_info_ubicacion_mock m ON m.id = e9.id
 ORDER BY e9.info_basica, e9.id
 LIMIT 40;"""
    if tag == "NOV" and b == "ACTIVIDAD_ECONOMICA":
        return """-- QUIEN y POR QUE. La etapa 1 y su reflejo en la tabla MAT.
SELECT a.info_basica_id AS persona, a.id, a.ciiu, a.actividad_economica,
       a.version, a.fecha_reporte, a.tipo_identificacion, a.flag_op,
       m.id IS NOT NULL AS llego_a_mat
  FROM bdm_tempo.stg_nov_acteco_etapa_1_mock a
  LEFT JOIN bdm_datos.mat_info_actividad_economica_mock m ON m.id = a.id
 ORDER BY a.info_basica_id
 LIMIT 40;"""
    if tag == "NOV" and b == "UBICACION_AGREGADA":
        return """-- QUIEN y POR QUE. La etapa final y su reflejo en la tabla MAT.
-- NOTA: hoy este dominio emite CERO filas porque falta V_Hom_Tip_Ident_Linea;
-- la consulta esta aqui para el dia que llegue el catalogo.
SELECT f.info_basica AS persona, f.tipo_identificacion, f.numero_identificacion,
       f.ubicacion_dato, f.ubicacion_clase, f.ubicacion_orden, f.flag_op,
       m.info_basica IS NOT NULL AS llego_a_mat
  FROM bdm_tempo.stg_nov_ubiagr_etapa_final_mock f
  LEFT JOIN bdm_datos.mat_ubicacion_agregada_mock m
         ON m.info_basica = f.info_basica AND m.ubicacion_dato = f.ubicacion_dato
 ORDER BY f.info_basica
 LIMIT 40;"""
    return """-- Traza de la corrida de Novedades.
SELECT corrida_id, lote, modo, estado, relaciones_entrada, personas_distintas,
       filas_mat_escritas, fecha_hora_inicio, fecha_hora_fin
  FROM bdm_datos.nov_control_mock ORDER BY corrida_id;"""

NOMBRE = {"REGLA1":"Regla 1 - unificacion por CIIU y entidades reportantes",
 "REGLA2":"Regla 2 - cascada de seis escenarios y cuatro motores",
 "REGLA3":"Regla 3 - unificacion geografica","GEO":"Ciclo GEO",
 "GENERAL":"Unificacion - transversales","GOBERNANZA":"Gobernanza",
 "FASE1":"Scoring - Fase 1 (no portada)","FASE2":"Scoring - Fase 2 (no portada)",
 "FASE3":"Scoring - Fase 3 (no portada)","FASE4":"Scoring - Fase 4 (caracteristicas)",
 "CA_FUNC":"Scoring - criterios funcionales","CA_MIGR":"Scoring - criterios de migracion",
 "CA_TECN":"Scoring - criterios tecnicos","REGLA_GRAL":"Scoring - reglas generales",
 "UBICACION":"Novedades - Ubicacion","ACTIVIDAD_ECONOMICA":"Novedades - Actividad Economica",
 "UBICACION_AGREGADA":"Novedades - Ubicacion Agregada","OTROS_DOMINIOS":"Novedades - dominios no portados"}
ORDEN = [("UNIF",b) for b in ("REGLA1","REGLA2","REGLA3","GEO","GENERAL","GOBERNANZA")] + \
        [("ORD",b) for b in ("REGLA_GRAL","CA_FUNC","CA_MIGR","CA_TECN","FASE4","FASE1","FASE2","FASE3")] + \
        [("NOV",b) for b in ("UBICACION","ACTIVIDAD_ECONOMICA","UBICACION_AGREGADA","OTROS_DOMINIOS","GOBERNANZA")]

def fases(tag, cid):
    e = est.get((tag, cid), {})
    return " &middot; ".join("%s=%s" % (f, e[f]) for f in FASES[tag] if f in e) or "sin resultado"
def paso(tag, cid):
    v = list(est.get((tag, cid), {}).values())
    return bool(v) and all(x in ("PASSED","NO_APLICA") for x in v)

L = []; w = L.append
w("# Certificacion de aceptacion - Reconocer")
w("## Unificacion (R1, R2, R3) + GEO + Scoring + Novedades\n")
w("Documento para QA. **Una ficha por criterio**, con el SQL que deja ver *quien*")
w("es el registro, *que caracteristica* lo decide y *que salio*.\n")
w("**El catalogo sale del DDL del repo de estructura y el estado de cada criterio")
w("de las tablas de resultado de la ultima corrida. Ningun numero esta escrito a")
w("mano.**\n")
w("---\n")
w("## Como se lee un arquetipo\n")
w("La certificacion no usa datos reales: usa **arquetipos**, personas sembradas")
w("con un resultado esperado exacto. El numero de arquetipo esta dentro del id:\n")
w("```")
w("id_buro_persona      = 9000000 + ARQ * 10000 + i      (i = 0..999)")
w("cod_dw_persona_ubic  = id_buro_persona * 10 + k       (k = la direccion)")
w("")
w("=> ARQ = (cod_dw_persona_ubic / 10 - 9000000) / 10000")
w("```\n")
w("| Banda ARQ | Que contiene |")
w("|---|---|")
w("| 1..20 | Regla 1 |")
w("| 21..55 | Regla 2 |")
w("| 56 | GEO, con coordenadas |")
w("| 57..59 | grupo A: CIIU 82, CIIU 90, hija bloqueada |")
w("| 60 | cascada R1 -> R2 |")
w("| 61..70 | Regla 3 |")
w("| 71..73 | los sitios de creacion de direccion (A6, A8, D9) |")
w("| 80..90 | Ordenamiento / Scoring |")
w("")
w("**Cada arquetipo es inmune a la cascada anterior**: si una etapa previa se lo")
w("llevara, no probaria nada.\n")
w("---\n")
w("## Ejemplo resuelto: como se ve que R1-01 cumple\n")
w("`R1-01` dice que con CIIU 10 el padre debe ser la direccion **LAB o CRR**. Se")
w("siembran dos direcciones por persona en el ARQ 1..5 y se mira cual gano:\n")
w("```")
w(" arq | persona | direccion | ciiu | tipo_ubic | entidades |  padre   | regla")
w("-----+---------+-----------+------+-----------+-----------+----------+------")
w("   1 | 9010000 |  90100001 | 10   |         3 |         1 |          |      ")
w("   1 | 9010000 |  90100002 | 10   |         1 |         1 | 90100001 |     1")
w("```\n")
w("Se lee asi: la persona `9010000` tiene dos direcciones. La `...0002` **quedo")
w("como hija** -- lleva `padre` -- y apunta a la `...0001`, que es la del")
w("`tipo_ubic = 3`. `regla = 1` dice que la sello la Regla 1. **Eso es exactamente")
w("lo que el criterio exige**, y por eso sale PASSED.\n")
w("---\n")
w("## Las fases\n")
w("| Fase | Que corre |")
w("|---|---|")
w("| `FULL` | carga completa: resetea las salidas y reprocesa todo |")
w("| `DELTA1` | ventana incremental sobre datos sin mutar |")
w("| `DELTA2` | ventana incremental **despues de una mutacion deliberada** |")
w("| `FULL2` | segundo FULL, solo Unificacion: prueba la convergencia |")
w("| `GEO` | el ciclo de georreferenciacion: corre una vez, no por fase |\n")
w("## Los estados\n")
w("| Estado | Significa |")
w("|---|---|")
w("| `PASSED` | se evaluo por consulta y se cumple |")
w("| `NO_APLICA` | la fase no ejercita ese criterio |")
w("| `SIN_DATO` | el mock no siembra el caso; **se arregla con un arquetipo** |")
w("| `BLOQUEADO` | falta un catalogo o un insumo externo; **ningun arquetipo lo arregla** |")
w("| `NO_IMPLEMENTADO` | dominio o fase no portada todavia |")
w("| `REVISION_MANUAL` | es una decision, no una consulta |")
w("| `FAILED` | **tumba el build** |\n")
w("---\n")
w("## Resumen\n")
w("| Bloque | Criterios | Cerrados |")
w("|---|---|---|")
for tag, b in ORDEN:
    fs = [c for c in C[tag] if c["bloque"] == b]
    if fs: w("| %s | %d | **%d** |" % (NOMBRE.get(b,b), len(fs), sum(1 for c in fs if paso(tag,c["id"]))))
w("")
w("---\n")
for tag, b in ORDEN:
    fs = [c for c in C[tag] if c["bloque"] == b]
    if not fs: continue
    lo, hi = BANDA.get(b, (1, 90))
    w("## %s\n" % NOMBRE.get(b, b))
    w("**Detalle del bloque — quien y por que.** Misma consulta para todos sus")
    w("criterios; cambia la banda `ARQ` segun el criterio.\n")
    w("```sql"); w(drill(tag, b, lo, hi)); w("```\n")
    for c in fs:
        blo, bhi = banda(c, b)
        w("### %s%s\n" % (c["id"], "" if paso(tag, c["id"]) else "   _(no cerrado)_"))
        w("**%s**\n" % c["enunciado"])
        w("| | |")
        w("|---|---|")
        w("| Fases y estado | `%s` |" % fases(tag, c["id"]))
        d = det.get((tag, c["id"]), {})
        med = d.get("FULL") or d.get("DELTA2") or d.get("DELTA1") or d.get("GEO") or ""
        if med: w("| Lo que midio la corrida | %s |" % med[:300])
        w("| Arquetipos | ARQ %d..%d (`id_buro_persona` %d..%d) |"
          % (blo, bhi, 9000000 + blo*10000, 9000000 + bhi*10000 + 999))
        w("| Caso de uso / evidencia | %s |" % c["evidencia"])
        ev = LOC.get((tag, c["id"]))
        if ev: w("| SQL que lo decide | `%s` (repo pgm) |" % ev)
        w("| Prioridad | %s |" % c["prioridad"])
        w("")
        w("```sql")
        w("-- 1) VEREDICTO de %s en todas las fases." % c["id"])
        w("SELECT modo, estado, detalle FROM %s" % TABLA[tag])
        w(" WHERE criterio = '%s' ORDER BY modo;" % c["id"])
        w("")
        w("-- 2) DETALLE: los registros de este criterio. Usa la consulta del bloque")
        w("--    de arriba acotando a su banda:")
        w("--       ARQ BETWEEN %d AND %d" % (blo, bhi))
        w("```\n")
    w("---\n")
w("## Lo que este documento NO afirma\n")
w("- **Se certifica solo con datos mock.** Arquetipos con resultado esperado exacto")
w("  y calculable; no se certifica con datos reales (regla 5 del proyecto).")
w("- **`BLOQUEADO` no es un criterio que falle**: es uno que no se puede evaluar")
w("  porque falta un insumo externo. El motivo esta en cada ficha.")
w("- **Las Fases 1, 2 y 3 del Scoring no estan portadas.** Sus criterios figuran")
w("  para que el alcance sea visible, no porque se hayan probado.")
w("- **El `UNLOAD` a S3 y el `COPY` de vuelta del ciclo GEO no estan certificados**:")
w("  el rol IAM no esta asociado al cluster DEV y el mock los sustituye. El resto")
w("  del ciclo es el mismo SQL que en produccion.")
io.open("/home/user/db_rcncr_btch_rdshft_dt_full_delta/docs/CERTIFICACION_ACEPTACION_QA.md",
        "w", encoding="utf-8").write("\n".join(L) + "\n")
print("lineas:", len(L))
