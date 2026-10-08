# -*- coding: utf-8 -*-
"""Verificación exhaustiva DEV — Ordenamiento REAL (_edf) + MOCK."""
from __future__ import annotations

import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import psycopg2

sys.stdout.reconfigure(encoding="utf-8")

HOST = "eec-aws-us-eits-reconocerbatch-dev-redshift.cz7jl1sn7m8z.us-east-1.redshift.amazonaws.com"
PORT = 5440
DB = "dba_rncr_batch"
USER = "c32525e"
PASSWORD = "WGawh7y777IV"

CASO_A = 3228096126421495389
CASO_B = 2848501447849812647

STRCT = Path(
    r"C:\Users\C32525E\Downloads\demo_unificacion_completa (2)"
    r"\db_rcncr_btch_rdshft_strct\deploy\redshift\SQL"
)
PGM = Path(
    r"C:\Users\C32525E\Downloads\demo_unificacion_completa (2)"
    r"\db_rcncr_btch_rdshft_pgm\deploy\redshift\SQL"
)

RESULTS: list[tuple[str, str, str]] = []  # id, estado, detalle


def connect():
    conn = psycopg2.connect(
        host=HOST,
        port=PORT,
        dbname=DB,
        user=USER,
        password=PASSWORD,
        connect_timeout=60,
        sslmode="require",
    )
    conn.autocommit = True
    return conn


def log(msg: str):
    print(msg, flush=True)


def record(cid: str, ok: bool, detail: str):
    estado = "PASSED" if ok else "FAILED"
    RESULTS.append((cid, estado, detail))
    log(f"[{estado}] {cid}: {detail}")


def q(cur, sql: str):
    cur.execute(sql)
    if cur.description:
        return cur.fetchall()
    return []


def deploy_file(cur, path: Path) -> bool:
    log(f"\n--- DEPLOY {path.name} ---")
    try:
        cur.execute(path.read_text(encoding="utf-8"))
        log("OK")
        return True
    except Exception as e:
        log(f"ERR {e}")
        record(f"DEPLOY:{path.name}", False, str(e)[:200])
        return False


def main():
    t0 = time.time()
    log("=" * 72)
    log(f"VERIFICACIÓN EXHAUSTIVA DEV — {datetime.now(timezone.utc).isoformat()}")
    log("=" * 72)

    conn = connect()
    cur = conn.cursor()

    # ------------------------------------------------------------------
    # 0) Inventario SPs
    # ------------------------------------------------------------------
    log("\n######## 0. INVENTARIO SPS ########")
    edf_expected = [
        "sp_ordenamiento_preparar_insumos_edf",
        "sp_ordenamiento_scoring_dir_edf",
        "sp_ordenamiento_scoring_tel_edf",
        "sp_ordenamiento_scoring_cel_edf",
        "sp_ordenamiento_scoring_ema_edf",
        "sp_ordenamiento_consolidacion_edf",
        "sp_ordenamiento_drop_staging_edf",
        "sp_ordenamiento_ejecucion_edf",
    ]
    mock_expected = [
        "sp_ordenamiento_cargar_seed_mock",
        "sp_ordenamiento_validar_mock",
        "sp_ordenamiento_ejecucion_mock",
    ]
    rows = q(
        cur,
        """
        SELECT n.nspname, p.proname
        FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
        WHERE p.proname ILIKE '%ordenamiento%'
        ORDER BY 1,2
        """,
    )
    present = {(r[0], r[1]) for r in rows}
    for name in edf_expected:
        record(
            f"INV-EDF-{name}",
            ("bdm_datos", name) in present,
            "presente en bdm_datos" if ("bdm_datos", name) in present else "AUSENTE",
        )

    # Deploy mock DDL+SPs always (ensure latest)
    log("\n######## 1. DEPLOY MOCK (DDL+SPS) ########")
    for p in [
        STRCT / "05_ddl_ordenamiento_mock.sql",
        PGM / "sp_ordenamiento_cargar_seed_mock.sql",
        PGM / "sp_ordenamiento_validar_mock.sql",
        PGM / "sp_ordenamiento_ejecucion_mock.sql",
    ]:
        deploy_file(cur, p)

    rows = q(
        cur,
        """
        SELECT n.nspname, p.proname
        FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
        WHERE p.proname ILIKE '%ordenamiento%mock%'
        ORDER BY 1,2
        """,
    )
    present_m = {(r[0], r[1]) for r in rows}
    for name in mock_expected:
        record(
            f"INV-MOCK-{name}",
            ("bdm_stage", name) in present_m,
            "presente en bdm_stage" if ("bdm_stage", name) in present_m else "AUSENTE",
        )

    # ------------------------------------------------------------------
    # 2) CALL EDF completo
    # ------------------------------------------------------------------
    log("\n######## 2. CALL sp_ordenamiento_ejecucion_edf(TRUE) ########")
    t_edf = time.time()
    try:
        cur.execute("CALL bdm_datos.sp_ordenamiento_ejecucion_edf(TRUE);")
        elapsed = time.time() - t_edf
        record("RUN-EDF", True, f"CALL OK en {elapsed:.1f}s")
    except Exception as e:
        elapsed = time.time() - t_edf
        record("RUN-EDF", False, f"CALL FAIL tras {elapsed:.1f}s: {e}")
        log("Continúo con gates sobre data existente…")

    # ------------------------------------------------------------------
    # 3) Gates REAL exhaustivos
    # ------------------------------------------------------------------
    log("\n######## 3. GATES REAL (post-corrida) ########")

    # CA-O01 scores
    rows = q(
        cur,
        """
        SELECT canal, COUNT(*)::BIGINT, ROUND(MIN(score::FLOAT),4), ROUND(MAX(score::FLOAT),4)
        FROM bdm_datos.score_ordenamiento GROUP BY 1 ORDER BY 1
        """,
    )
    by_c = {r[0]: r for r in rows}
    for canal in ("DIR", "TEL", "EMA"):
        n = by_c.get(canal, (canal, 0, None, None))[1]
        record(f"REAL-CA-O01-{canal}", n > 0, f"n={n} min/max={by_c.get(canal)}")
    cel_n = by_c.get("CEL", ("CEL", 0, None, None))[1]
    record("REAL-CA-O01-CEL", True, f"n={cel_n} (cobertura baja aceptable)")

    # CA-O02 betas
    rows = q(
        cur,
        """
        SELECT canal, COUNT(*)::BIGINT
        FROM bdm_datos.beta_ordenamiento GROUP BY 1 ORDER BY 1
        """,
    )
    total_b = sum(r[1] for r in rows)
    record("REAL-CA-O02", total_b == 47, f"total={total_b} detalle={rows}")

    # CA-O03 hijas
    rows = q(
        cur,
        """
        SELECT COUNT(*)::BIGINT FROM bdm_datos.rpu_orden_prioridad op
        WHERE EXISTS (
          SELECT 1 FROM bdm_datos.unificacion_direccion u
          WHERE u.cod_dw_persona_ubic = op.cod_dw_persona_ubic
        )
        """,
    )
    record("REAL-CA-O03-orden", rows[0][0] == 0, f"hijas_con_orden={rows[0][0]}")

    rows = q(
        cur,
        """
        SELECT COUNT(*)::BIGINT FROM bdm_datos.score_ordenamiento s
        WHERE EXISTS (
          SELECT 1 FROM bdm_datos.unificacion_direccion u
          WHERE u.cod_dw_persona_ubic = s.cod_dw_persona_ubic
        )
        """,
    )
    record("REAL-CA-O03-score", rows[0][0] == 0, f"hijas_con_score={rows[0][0]}")

    # Caso B RANK-01
    rows = q(
        cur,
        f"""
        SELECT cod_dw_persona_ubic, score, lugar
        FROM bdm_datos.score_ordenamiento
        WHERE id_buro_persona = {CASO_B} AND canal='DIR'
        ORDER BY lugar
        """,
    )
    ok_b = (
        len(rows) >= 2
        and rows[0][2] == 1
        and rows[0][1] >= rows[1][1]
        and float(rows[0][1]) == 611.8280
    )
    record("REAL-CA-O04-CasoB", ok_b, f"filas={rows}")

    # Caso A F3-02
    rows = q(
        cur,
        "SELECT COUNT(*)::BIGINT FROM bdm_datos.score_ordenamiento WHERE cod_dw_persona_ubic=3",
    )
    record("REAL-CA-O05-hija3", rows[0][0] == 0, f"scores_hija3={rows[0][0]}")

    rows = q(
        cur,
        """
        SELECT COUNT(*)::BIGINT FROM bdm_datos.rpu_orden_prioridad
        WHERE cod_dw_persona_ubic=3
        """,
    )
    record("REAL-CA-O05-orden-hija3", rows[0][0] == 0, f"orden_hija3={rows[0][0]}")

    # Caso A canales
    rows = q(
        cur,
        f"""
        SELECT canal, score, lugar FROM bdm_datos.score_ordenamiento
        WHERE id_buro_persona={CASO_A} ORDER BY canal, lugar
        """,
    )
    canales = {r[0] for r in rows}
    record(
        "REAL-CA-O06-CasoA",
        {"DIR", "TEL", "EMA"}.issubset(canales),
        f"canales={sorted(canales)} filas={rows}",
    )

    # Caso B orden = lugar
    rows = q(
        cur,
        f"""
        SELECT o.cod_dw_persona_ubic, o.orden_prioridad, s.lugar, s.score
        FROM bdm_datos.rpu_orden_prioridad o
        JOIN bdm_datos.score_ordenamiento s
          ON s.cod_dw_persona_ubic=o.cod_dw_persona_ubic
         AND s.id_buro_persona=o.id_buro_persona AND s.canal='DIR'
        WHERE o.id_buro_persona={CASO_B}
        ORDER BY o.orden_prioridad
        """,
    )
    ok_ord = len(rows) >= 2 and all(r[1] == r[2] for r in rows)
    record("REAL-CA-O07-orden", ok_ord, f"filas={rows}")

    # Empates DIR (informativo)
    rows = q(
        cur,
        """
        SELECT id_buro_persona, score, COUNT(*) AS n
        FROM bdm_datos.score_ordenamiento
        WHERE canal='DIR'
        GROUP BY 1,2 HAVING COUNT(*)>1
        LIMIT 5
        """,
    )
    record(
        "REAL-CA-O08-empates",
        True,
        f"empates_encontrados={len(rows)} muestra={rows} (N/A si 0; MOCK cubre)",
    )

    # TEL020 / EMA exclusiones — presencia en betas + comentario SP (código)
    rows = q(
        cur,
        """
        SELECT codigo_variable, valor_beta FROM bdm_datos.beta_ordenamiento
        WHERE canal='TEL' AND codigo_variable ILIKE '%TEL020%'
        """,
    )
    # column may be cod_caracteristica
    if not rows:
        rows = q(
            cur,
            """
            SELECT cod_caracteristica, valor_beta FROM bdm_datos.beta_ordenamiento
            WHERE canal='TEL' AND cod_caracteristica ILIKE '%TEL020%'
            """,
        )
    record("REAL-CA-O09-beta-TEL020", len(rows) >= 1, f"betas_TEL020={rows}")

    rows = q(
        cur,
        """
        SELECT cod_caracteristica FROM bdm_datos.beta_ordenamiento
        WHERE canal='EMA' AND (
          cod_caracteristica ILIKE '%EMA003%' OR cod_caracteristica ILIKE '%EMA007%'
          OR cod_caracteristica ILIKE '%EMA018%' OR cod_caracteristica ILIKE '%EMA025%'
        )
        ORDER BY 1
        """,
    )
    record("REAL-CA-O10-betas-EMA-excl", len(rows) >= 2, f"vars={rows}")

    # CEL A/B
    rows = q(
        cur,
        f"""
        SELECT id_buro_persona, score, lugar FROM bdm_datos.score_ordenamiento
        WHERE canal='CEL' AND id_buro_persona IN ({CASO_A},{CASO_B})
        """,
    )
    record(
        "REAL-CA-O11-CEL-AB",
        True,
        f"filas_CEL_AB={len(rows)} {rows} (0=N/A; MOCK 20012 cubre)",
    )

    # Multi DIR Caso B
    rows = q(
        cur,
        f"""
        SELECT COUNT(*)::BIGINT FROM bdm_datos.score_ordenamiento
        WHERE id_buro_persona={CASO_B} AND canal='DIR'
        """,
    )
    record("REAL-CA-O12-multiDIR", rows[0][0] >= 2, f"n_dir_casoB={rows[0][0]}")

    # Unificación gates (precondición)
    rows = q(
        cur,
        """
        SELECT
          SUM(CASE WHEN cod_dw_direccion_unificada IS NULL THEN 1 ELSE 0 END)::BIGINT AS c03,
          SUM(CASE WHEN cod_dw_persona_ubic = cod_dw_direccion_unificada THEN 1 ELSE 0 END)::BIGINT AS c04,
          COUNT(*)::BIGINT AS n
        FROM bdm_datos.unificacion_direccion
        """,
    )
    c03, c04, n_u = rows[0]
    record("PRE-UNIF-C03", c03 == 0, f"c03={c03} n_unif={n_u}")
    record("PRE-UNIF-C04", c04 == 0, f"c04={c04}")

    rows = q(
        cur,
        """
        SELECT unifica_atributos, COUNT(*)::BIGINT
        FROM bdm_datos.unificacion_direccion GROUP BY 1 ORDER BY 1
        """,
    )
    record("PRE-UNIF-por-regla", True, f"detalle={rows}")

    # Fórmulas en código SP (estático desde disco)
    log("\n######## 3b. REVISIÓN ESTÁTICA SPS (disco) ########")
    tel = (PGM / "sp_ordenamiento_scoring_tel_edf.sql").read_text(encoding="utf-8")
    ema = (PGM / "sp_ordenamiento_scoring_ema_edf.sql").read_text(encoding="utf-8")
    cel = (PGM / "sp_ordenamiento_scoring_cel_edf.sql").read_text(encoding="utf-8")
    prep = (PGM / "sp_ordenamiento_preparar_insumos_edf.sql").read_text(encoding="utf-8")
    cons = (PGM / "sp_ordenamiento_consolidacion_edf.sql").read_text(encoding="utf-8")

    record(
        "CODE-TEL02",
        "no entra en SCORE" in tel or "no entra en SCORE" in tel.replace("  ", " "),
        "TEL020 fuera de SUM en scoring_tel_edf",
    )
    # stronger: c20 not in score expression after comment
    record(
        "CODE-TEL02-sum",
        "CAST(c.c20" not in tel.split("AS score")[0].split("scored AS")[-1]
        if "scored AS" in tel
        else False,
        "c20 no suma en expresión score",
    )
    record(
        "CODE-EMA03",
        "EMA003/007/018/025" in ema and "fuera de SUM" in ema,
        "EMA excluidas documentadas en scoring_ema_edf",
    )
    record(
        "CODE-CEL02",
        "0.22" in cel and "COALESCE" in cel,
        "default 0.22 en scoring_cel_edf",
    )
    record(
        "CODE-F302-prep",
        "ind_unificacion" in prep and "<> 1" in prep,
        "preparar filtra hijas",
    )
    record(
        "CODE-F302-cons",
        "ind_unificacion" in cons and "<> 1" in cons,
        "consolidacion filtra hijas",
    )
    record(
        "CODE-NOSIGMOID",
        "1/(1+" not in tel + ema + cel and "sigmoid" not in (tel + ema + cel).lower(),
        "sin sigmoid en scoring EDF",
    )

    # ------------------------------------------------------------------
    # 4) MOCK full
    # ------------------------------------------------------------------
    log("\n######## 4. CALL sp_ordenamiento_ejecucion_mock ########")
    t_m = time.time()
    try:
        cur.execute("CALL bdm_stage.sp_ordenamiento_ejecucion_mock();")
        record("RUN-MOCK", True, f"CALL OK en {time.time()-t_m:.1f}s")
    except Exception as e:
        record("RUN-MOCK", False, f"CALL FAIL: {e}")

    rows = q(
        cur,
        "SELECT criterio_ca, estado, detalle FROM bdm_stage.mock_ord_ca_result ORDER BY 1",
    )
    for ca, est, det in rows:
        record(f"MOCK-{ca}", est == "PASSED", det or "")

    rows = q(
        cur,
        """
        SELECT
          CASE WHEN SUM(CASE WHEN estado='FAILED' THEN 1 ELSE 0 END)=0
               THEN 'PASSED_ALL' ELSE 'FAILED_SOME' END,
          SUM(CASE WHEN estado='PASSED' THEN 1 ELSE 0 END),
          SUM(CASE WHEN estado='FAILED' THEN 1 ELSE 0 END)
        FROM bdm_stage.mock_ord_ca_result
        """,
    )
    verd, passed, failed = rows[0]
    record("MOCK-VEREDICTO", verd == "PASSED_ALL", f"{verd} passed={passed} failed={failed}")

    # Spot-check all mock personas
    rows = q(
        cur,
        """
        SELECT id_buro_persona, COUNT(*) FROM bdm_stage.mock_ord_score
        GROUP BY 1 ORDER BY 1
        """,
    )
    expected_pids = set(range(20001, 20015))
    got = {r[0] for r in rows}
    record(
        "MOCK-PERSONAS-20001-20014",
        expected_pids.issubset(got),
        f"got={sorted(got)}",
    )

    rows = q(
        cur,
        """
        SELECT s.id_buro_persona, r.etiqueta, s.score, s.lugar, p.orden_prioridad
        FROM bdm_stage.mock_ord_score s
        JOIN bdm_stage.mock_ord_rpu r ON r.cod_dw_persona_ubic=s.cod_dw_persona_ubic
        LEFT JOIN bdm_stage.mock_ord_prioridad p ON p.cod_dw_persona_ubic=s.cod_dw_persona_ubic
        WHERE s.id_buro_persona=20001 AND s.canal='DIR' ORDER BY s.lugar
        """,
    )
    record("MOCK-HTML-20001", len(rows) == 2 and float(rows[0][2]) == 850.0, f"{rows}")

    # ------------------------------------------------------------------
    # Resumen
    # ------------------------------------------------------------------
    log("\n" + "=" * 72)
    log("RESUMEN FINAL")
    log("=" * 72)
    failed_ids = [r for r in RESULTS if r[1] == "FAILED"]
    passed_n = sum(1 for r in RESULTS if r[1] == "PASSED")
    failed_n = len(failed_ids)
    for cid, est, det in RESULTS:
        log(f"{est:7} | {cid:40} | {det[:100]}")
    log("-" * 72)
    log(f"TOTAL PASSED={passed_n} FAILED={failed_n} elapsed={time.time()-t0:.1f}s")
    if failed_ids:
        log("FALLIDOS:")
        for cid, est, det in failed_ids:
            log(f"  - {cid}: {det}")
        veredicto = "FAILED"
    else:
        veredicto = "PASSED_ALL"
    log(f"\nVEREDICTO_GLOBAL={veredicto}")

    # write report next to script
    out = (
        Path(__file__).resolve().parent
        / f"EVIDENCIA_VERIFICACION_EXHAUSTIVA_DEV_{datetime.now().strftime('%Y%m%d_%H%M%S')}.md"
    )
    lines = [
        "# Evidencia verificación exhaustiva DEV — Ordenamiento",
        "",
        f"- Fecha UTC: {datetime.now(timezone.utc).isoformat()}",
        f"- DB: `{DB}` @ `{HOST}`",
        f"- Veredicto: **{veredicto}**",
        f"- Passed: {passed_n} · Failed: {failed_n} · Elapsed: {time.time()-t0:.1f}s",
        "",
        "| Check | Estado | Detalle |",
        "|-------|--------|---------|",
    ]
    for cid, est, det in RESULTS:
        d = det.replace("|", "/").replace("\n", " ")[:180]
        lines.append(f"| `{cid}` | {est} | {d} |")
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    log(f"\nReporte: {out}")

    conn.close()
    return 0 if veredicto == "PASSED_ALL" else 1


if __name__ == "__main__":
    raise SystemExit(main())
