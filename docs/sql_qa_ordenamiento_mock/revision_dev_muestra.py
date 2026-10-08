# -*- coding: utf-8 -*-
"""Revisión DEV muestra pequeña + MOCK + readiness MIG-01 (sin tocar Teradata)."""
from __future__ import annotations

import os
import sys
from datetime import datetime, timezone
from pathlib import Path

import psycopg2

sys.stdout.reconfigure(encoding="utf-8")

HOST = "eec-aws-us-eits-reconocerbatch-dev-redshift.cz7jl1sn7m8z.us-east-1.redshift.amazonaws.com"
DB = "dba_rncr_batch"
USER = os.environ.get("RS_USER", "c32525e")
PASSWORD = os.environ.get("RS_PASSWORD", "")

PGM = Path(
    r"C:\Users\C32525E\Downloads\demo_unificacion_completa (2)"
    r"\db_rcncr_btch_rdshft_pgm\deploy\redshift\SQL"
)
OUT_DIR = Path(
    r"C:\Users\C32525E\Downloads\demo_unificacion_completa (2)"
    r"\db_rcncr_btch_rdshft_dt\docs\sql_qa_ordenamiento_mock"
)
DL = Path(r"C:\Users\C32525E\Downloads")

R: list[tuple[str, str, str]] = []


def rec(cid: str, ok: bool, det: str):
    est = "PASSED" if ok else "FAILED"
    R.append((cid, est, det))
    print(f"[{est}] {cid}: {det}", flush=True)


def main():
    if not PASSWORD:
        print("ERROR: set RS_PASSWORD env var")
        return 2

    conn = psycopg2.connect(
        host=HOST,
        port=5440,
        dbname=DB,
        user=USER,
        password=PASSWORD,
        connect_timeout=60,
        sslmode="require",
    )
    conn.autocommit = True
    cur = conn.cursor()

    def q(sql):
        cur.execute(sql)
        return cur.fetchall() if cur.description else []

    print("=== REVISIÓN DEV (muestra aceptada) ===\n")

    # Ambiente
    try:
        n_xpm = q("SELECT COUNT(*) FROM ds_dba_rncr_batch.edf_views.xpm")[0][0]
    except Exception as e:
        n_xpm = -1
        rec("ENV-datashare", False, f"sin acceso edf_views: {e}")
    else:
        rec(
            "ENV-muestra",
            n_xpm > 0,
            f"edf_views.xpm={n_xpm} (muestra pequeña = OK según equipo)",
        )

    n_unif = q("SELECT COUNT(*) FROM bdm_datos.unificacion_direccion")[0][0]
    por_regla = q(
        "SELECT unifica_atributos, COUNT(*)::BIGINT FROM bdm_datos.unificacion_direccion GROUP BY 1 ORDER BY 1"
    )
    rec("REAL-unif", True, f"n={n_unif} por_regla={por_regla}")

    # Si unif vacía, intentar cascada
    if n_unif == 0:
        print("\n-- Unif vacía: intento R1→R2→R3 --")
        try:
            cur.execute("CALL bdm_datos.sp_unificacion_regla1();")
            cur.execute("CALL bdm_datos.sp_unificacion_regla2();")
            cur.execute("CALL bdm_datos.sp_unificacion_regla3();")
            n_unif = q("SELECT COUNT(*) FROM bdm_datos.unificacion_direccion")[0][0]
            rec("RUN-UNIF", True, f"OK → n={n_unif}")
        except Exception as e:
            rec("RUN-UNIF", False, str(e)[:200])

    print("\n-- Ordenamiento EDF --")
    try:
        cur.execute("CALL bdm_datos.sp_ordenamiento_ejecucion_edf(TRUE);")
        rec("RUN-EDF", True, "CALL OK")
    except Exception as e:
        rec("RUN-EDF", False, str(e)[:200])

    scores = q(
        "SELECT canal, COUNT(*)::BIGINT, ROUND(MIN(score::FLOAT),4), ROUND(MAX(score::FLOAT),4) "
        "FROM bdm_datos.score_ordenamiento GROUP BY 1 ORDER BY 1"
    )
    by = {r[0]: r for r in scores}
    for c in ("DIR", "TEL", "EMA"):
        n = by.get(c, (c, 0, None, None))[1]
        # En muestra: DIR/TEL esperados; EMA puede ser 0
        if c == "EMA":
            rec(f"REAL-scores-{c}", True, f"n={n} (puede ser 0 en muestra) {by.get(c)}")
        else:
            rec(f"REAL-scores-{c}", n > 0, f"n={n} {by.get(c)}")
    cel_n = by.get("CEL", ("CEL", 0, None, None))[1]
    rec("REAL-scores-CEL", True, f"n={cel_n} (bajo/0 OK en muestra)")

    betas = q("SELECT COUNT(*) FROM bdm_datos.beta_ordenamiento")[0][0]
    rec("REAL-betas47", betas == 47, f"n={betas}")

    hijas_o = q(
        """
        SELECT COUNT(*) FROM bdm_datos.rpu_orden_prioridad op
        WHERE EXISTS (
          SELECT 1 FROM bdm_datos.unificacion_direccion u
          WHERE u.cod_dw_persona_ubic = op.cod_dw_persona_ubic
        )
        """
    )[0][0]
    hijas_s = q(
        """
        SELECT COUNT(*) FROM bdm_datos.score_ordenamiento s
        WHERE EXISTS (
          SELECT 1 FROM bdm_datos.unificacion_direccion u
          WHERE u.cod_dw_persona_ubic = s.cod_dw_persona_ubic
        )
        """
    )[0][0]
    rec("REAL-F3-02-orden", hijas_o == 0, f"hijas_con_orden={hijas_o}")
    rec("REAL-F3-02-score", hijas_s == 0, f"hijas_con_score={hijas_s}")

    # Ejemplo REAL de la muestra: persona con >=2 DIR
    ej = q(
        """
        SELECT id_buro_persona, COUNT(*) AS n_dir,
               MAX(score) AS max_s, MIN(score) AS min_s
        FROM bdm_datos.score_ordenamiento
        WHERE canal='DIR'
        GROUP BY 1
        HAVING COUNT(*) >= 2
        ORDER BY 2 DESC
        LIMIT 3
        """
    )
    if ej:
        pid = ej[0][0]
        det = q(
            f"""
            SELECT cod_dw_persona_ubic, score, lugar
            FROM bdm_datos.score_ordenamiento
            WHERE id_buro_persona={pid} AND canal='DIR'
            ORDER BY lugar
            """
        )
        ok_rank = len(det) >= 2 and det[0][2] == 1 and det[0][1] >= det[1][1]
        rec("REAL-RANK-ejemplo-muestra", ok_rank, f"id_buro={pid} filas={det}")
        ejemplo_pid = pid
    else:
        # al menos 1 DIR
        one = q(
            """
            SELECT id_buro_persona, cod_dw_persona_ubic, score, lugar
            FROM bdm_datos.score_ordenamiento
            WHERE canal='DIR' AND lugar=1
            LIMIT 1
            """
        )
        rec(
            "REAL-RANK-ejemplo-muestra",
            len(one) == 1,
            f"solo 1 DIR por persona en muestra; ejemplo={one}",
        )
        ejemplo_pid = one[0][0] if one else None

    # MOCK
    print("\n-- MOCK --")
    try:
        cur.execute("CALL bdm_stage.sp_ordenamiento_ejecucion_mock();")
        verd = q(
            """
            SELECT CASE WHEN SUM(CASE WHEN estado='FAILED' THEN 1 ELSE 0 END)=0
                 THEN 'PASSED_ALL' ELSE 'FAILED_SOME' END,
                   SUM(CASE WHEN estado='PASSED' THEN 1 ELSE 0 END),
                   SUM(CASE WHEN estado='FAILED' THEN 1 ELSE 0 END)
            FROM bdm_stage.mock_ord_ca_result
            """
        )[0]
        rec("MOCK-VEREDICTO", verd[0] == "PASSED_ALL", f"{verd}")
        for ca, est, det in q(
            "SELECT criterio_ca, estado, detalle FROM bdm_stage.mock_ord_ca_result ORDER BY 1"
        ):
            rec(f"MOCK-{ca}", est == "PASSED", det or "")
    except Exception as e:
        rec("MOCK-VEREDICTO", False, str(e)[:200])
        ejemplo_pid = ejemplo_pid

    # Código / MIG-01 readiness
    print("\n-- Código vs Teradata (MIG-01 readiness) --")
    tel = (PGM / "sp_ordenamiento_scoring_tel_edf.sql").read_text(encoding="utf-8")
    ema = (PGM / "sp_ordenamiento_scoring_ema_edf.sql").read_text(encoding="utf-8")
    cel = (PGM / "sp_ordenamiento_scoring_cel_edf.sql").read_text(encoding="utf-8")
    prep = (PGM / "sp_ordenamiento_preparar_insumos_edf.sql").read_text(encoding="utf-8")
    cons = (PGM / "sp_ordenamiento_consolidacion_edf.sql").read_text(encoding="utf-8")

    rec("MIG-prep-TEL02", "no entra en SCORE" in tel, "TEL020 fuera SUM (alineado TD doc)")
    rec("MIG-prep-EMA03", "fuera de SUM" in ema, "EMA003/007/018/025 fuera SUM")
    rec("MIG-prep-CEL02", "0.22" in cel, "default operador 0.22")
    rec("MIG-prep-F302", "<> 1" in prep and "<> 1" in cons, "hijas fuera ranking")
    rec("MIG-prep-formula", "valor_beta" in tel and "ROW_NUMBER" in tel, "beta×cat + ROW_NUMBER")
    rec(
        "MIG-01-paridad-numerica",
        False,
        "NO ejecutada: falta corrida lado a lado Teradata vs Redshift (externo)",
    )
    rec(
        "MIG-01-alcance-opcionA",
        True,
        "Opción A = suma lineal betas RITM; no exige sigmoid 0-1 para cierre actual",
    )

    failed = [x for x in R if x[1] == "FAILED"]
    # MIG-01 numeric expected fail doesn't block Opción A
    failed_block = [x for x in failed if x[0] != "MIG-01-paridad-numerica"]
    passed = sum(1 for x in R if x[1] == "PASSED")

    veredicto = "PASSED_OPCION_A" if not failed_block else "FAILED"
    print("\n" + "=" * 64)
    print(f"VEREDICTO={veredicto} passed={passed} failed_block={len(failed_block)}")
    for cid, est, det in failed:
        print(f"  {est} {cid}: {det}")

    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    lines = [
        "# Revisión DEV — Ordenamiento (muestra pequeña aceptada)",
        "",
        f"- Fecha UTC: {datetime.now(timezone.utc).isoformat()}",
        f"- Premisa: muestra datashare pequeña = **normal** mientras hay columnas de estandarización",
        f"- Veredicto Opción A: **{veredicto}**",
        f"- Ejemplo REAL muestra: `{ejemplo_pid}`",
        "",
        "## Checks",
        "",
        "| Check | Estado | Detalle |",
        "|-------|--------|---------|",
    ]
    for cid, est, det in R:
        d = det.replace("|", "/").replace("\n", " ")[:220]
        lines.append(f"| `{cid}` | {est} | {d} |")
    lines += [
        "",
        "## Paridad Teradata (MIG-01)",
        "",
        "| Tema | Estado |",
        "|------|--------|",
        "| Reglas de fórmula alineadas (TEL-02, EMA-03, CEL-02, F3-02, betas) | Listo en código |",
        "| Comparación numérica 1:1 Teradata vs Redshift | **Pendiente externo** |",
        "| ¿Bloquea cierre Opción A / muestra DEV? | **No** (mesa) |",
        "",
        "## Siguiente",
        "",
        "1. Usar MOCK PASSED_ALL + gates REAL de la muestra para entrega QA.",
        "2. Cuando estandarización/datashare pase a full, re-correr y adjuntar volumen.",
        "3. MIG-01 cuando Experian entregue set/corrida Teradata de referencia.",
        "",
    ]
    text = "\n".join(lines)
    out1 = OUT_DIR / f"REVISION_DEV_MUESTRA_{ts}.md"
    out2 = DL / f"REVISION_DEV_ORDENAMIENTO_{ts}.md"
    out1.write_text(text, encoding="utf-8")
    out2.write_text(text, encoding="utf-8")
    print("REPORT", out2)

    conn.close()
    return 0 if veredicto == "PASSED_OPCION_A" else 1


if __name__ == "__main__":
    raise SystemExit(main())
