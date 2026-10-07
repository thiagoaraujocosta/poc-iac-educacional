#!/usr/bin/env python3
"""Análise estatística dos CSV de medição (IaC x manual).

Lê os arquivos produzidos por executar_medicao.sh/.ps1, replicacao.sh,
drift_test.sh e pelo registro manual (modelo_baseline_manual.csv), calcula
média, desvio-padrão amostral, mínimo e máximo e grava tabelas em Markdown e CSV.
Nenhum valor é inventado: sem dados de entrada, nada é gerado.

Cenários do dataset real (executar_cenario.sh/.ps1): por cenário e por porte, calcula mediana, média,
desvio-padrão, mín, máx, IQR e coeficiente de variação do tempo; curva de escalabilidade (tempo x N,
tempo incremental por escola, ajuste linear com R2); falhas; taxa de idempotência; taxa de consistência;
e teste de Mann-Whitney com delta de Cliff entre grupos (scipy se disponível, senão Python puro).

    python analise.py --tempos resultados/*_tempos.csv --idempotencia resultados/*_idempotencia.csv \
        --consistencia resultados/*_consistencia.csv --saida resultados/analise_cenarios
    # comparação explícita: --comparar completo_pequeno_n05 completo_grande_n05  (ou porte:pequeno porte:grande)

Exemplo:
    python analise.py --iac resultados/medicao_iac.csv \
        --manual resultados/baseline_manual.csv \
        --replicacao resultados/replicacao.csv \
        --drift resultados/drift.csv --saida resultados/analise
"""
from __future__ import annotations

import argparse
import math
import re
import statistics
import sys
from pathlib import Path

import pandas as pd

FASES_PROVISIONAMENTO = ["terraform_apply", "ansible_playbook", "smoke_tests"]
COLUNAS_ESTAT = ["n", "media_s", "desvio_padrao_s", "minimo_s", "maximo_s"]


def estatisticas(valores: list[float]) -> dict[str, float]:
    """Média, desvio-padrão amostral (n-1), mínimo e máximo."""
    n = len(valores)
    if n == 0:
        return {"n": 0, "media_s": float("nan"), "desvio_padrao_s": float("nan"),
                "minimo_s": float("nan"), "maximo_s": float("nan")}
    return {
        "n": n,
        "media_s": statistics.fmean(valores),
        "desvio_padrao_s": statistics.stdev(valores) if n > 1 else float("nan"),
        "minimo_s": min(valores),
        "maximo_s": max(valores),
    }


def tabela_markdown(df: pd.DataFrame, casas: int = 3) -> str:
    """Converte um DataFrame em tabela Markdown (sem depender de tabulate)."""
    def fmt(v: object) -> str:
        if isinstance(v, float):
            if pd.isna(v):
                return "n/a"
            return f"{v:.2e}" if (v != 0 and abs(v) < 10 ** -casas) else f"{v:.{casas}f}"
        return str(v)

    cab = "| " + " | ".join(str(c) for c in df.columns) + " |"
    sep = "|" + "|".join("---" for _ in df.columns) + "|"
    linhas = ["| " + " | ".join(fmt(v) for v in linha) + " |" for linha in df.itertuples(index=False)]
    return "\n".join([cab, sep, *linhas])


def exigir_colunas(df: pd.DataFrame, colunas: list[str], nome: str) -> None:
    faltando = [c for c in colunas if c not in df.columns]
    if faltando:
        sys.exit(f"{nome}: colunas ausentes: {', '.join(faltando)}")


def agrupar(df: pd.DataFrame, chaves: list[str], coluna: str = "segundos") -> pd.DataFrame:
    linhas = []
    for chave, grupo in df.groupby(chaves, sort=False):
        chave = chave if isinstance(chave, tuple) else (chave,)
        linhas.append({**dict(zip(chaves, chave)), **estatisticas(grupo[coluna].astype(float).tolist())})
    return pd.DataFrame(linhas, columns=[*chaves, *COLUNAS_ESTAT])


def analisar_iac(df: pd.DataFrame, incluir_falhas: bool) -> tuple[pd.DataFrame, pd.DataFrame, str]:
    exigir_colunas(df, ["run_id", "fase", "segundos", "exit_code", "timestamp"], "CSV IaC")
    falhas = df[df["exit_code"] != 0]
    base = df if incluir_falhas else df[df["exit_code"] == 0]
    por_fase = agrupar(base, ["fase"])
    por_fase["execucoes_com_falha"] = por_fase["fase"].map(falhas.groupby("fase").size()).fillna(0).astype(int)

    # Total de provisionamento: apenas repetições em que as três fases existem (e passaram, salvo -f).
    pivo = base[base["fase"].isin(FASES_PROVISIONAMENTO)].pivot_table(
        index="run_id", columns="fase", values="segundos", aggfunc="sum")
    completas = pivo.dropna(subset=[c for c in FASES_PROVISIONAMENTO if c in pivo.columns])
    if len(completas.columns) == len(FASES_PROVISIONAMENTO) and len(completas) > 0:
        totais = completas[FASES_PROVISIONAMENTO].sum(axis=1)
        total = pd.DataFrame([{"fase": "total_provisionamento", **estatisticas(totais.tolist()),
                               "execucoes_com_falha": int(len(pivo) - len(completas))}])
        por_fase = pd.concat([por_fase, total], ignore_index=True)
        totais_df = totais.rename("segundos_total_iac").reset_index()
    else:
        totais_df = pd.DataFrame(columns=["run_id", "segundos_total_iac"])
    nota = (f"Repetições no arquivo: {df['run_id'].nunique()}; "
            f"linhas com exit_code diferente de 0: {len(falhas)}"
            f"{' (incluídas)' if incluir_falhas else ' (excluídas das estatísticas)'}.")
    return por_fase, totais_df, nota


def segundos_manual(df: pd.DataFrame) -> pd.Series:
    """Usa a coluna 'segundos'; se vazia, calcula por inicio_hhmmss e fim_hhmmss."""
    seg = pd.to_numeric(df.get("segundos"), errors="coerce")
    if {"inicio_hhmmss", "fim_hhmmss"}.issubset(df.columns):
        ini = pd.to_timedelta(df["inicio_hhmmss"].astype(str), errors="coerce")
        fim = pd.to_timedelta(df["fim_hhmmss"].astype(str), errors="coerce")
        calc = (fim - ini).dt.total_seconds()
        calc = calc.where(calc >= 0, calc + 86400)  # cronometragem que virou o dia
        seg = seg.fillna(calc)
    return seg


def analisar_manual(df: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    exigir_colunas(df, ["repeticao", "etapa_id", "fase_iac"], "CSV manual")
    df = df.copy()
    df["segundos"] = segundos_manual(df)
    df["erros_qtd"] = pd.to_numeric(df.get("erros_qtd"), errors="coerce").fillna(0)
    df = df.dropna(subset=["segundos"])
    if df.empty:
        sys.exit("CSV manual: nenhuma etapa com tempo preenchido.")
    por_etapa = agrupar(df, ["etapa_id"])
    por_fase_rep = df.groupby(["repeticao", "fase_iac"], as_index=False)["segundos"].sum()
    por_fase = agrupar(por_fase_rep, ["fase_iac"])
    total_rep = df.groupby("repeticao", as_index=False).agg(
        segundos_total_manual=("segundos", "sum"), erros_total=("erros_qtd", "sum"))
    return por_etapa, por_fase, total_rep


def analisar_replicacao(df: pd.DataFrame) -> pd.DataFrame:
    exigir_colunas(df, ["n_escolas", "repeticao", "fase", "segundos", "exit_code"], "CSV replicação")
    base = df[df["exit_code"] == 0]
    res = agrupar(base, ["n_escolas", "fase"])
    extra = df.groupby(["n_escolas", "fase"], sort=False).agg(
        n_recursos_state=("n_recursos_state", "max"), linhas_tfvars=("linhas_tfvars", "max")).reset_index()
    return res.merge(extra, on=["n_escolas", "fase"], how="left")


# ---------------------------------------------------------------------------
# Análise por cenário (dataset real do Censo Escolar): tempo, escalabilidade,
# falhas, idempotência, consistência e comparação entre grupos.
# ---------------------------------------------------------------------------
try:  # scipy é opcional: sem ele, os testes usam implementação em Python puro
    from scipy import stats as _scipy_stats
except ImportError:  # pragma: no cover
    _scipy_stats = None

USAR_SCIPY = _scipy_stats is not None
COLUNAS_DESCR = ["n_obs", "mediana_s", "media_s", "desvio_padrao_s", "minimo_s", "maximo_s",
                 "q1_s", "q3_s", "iqr_s", "cv_pct"]
COLUNAS_TEMPOS = ["run_id", "cenario", "porte", "n", "fase", "segundos", "exit_code", "falhas_teste"]


def quantil(ordenados: list[float], q: float) -> float:
    """Quantil por interpolação linear (mesmo método padrão de pandas/numpy)."""
    if not ordenados:
        return float("nan")
    pos = (len(ordenados) - 1) * q
    i = int(math.floor(pos))
    j = min(i + 1, len(ordenados) - 1)
    return ordenados[i] + (ordenados[j] - ordenados[i]) * (pos - i)


def descrever(valores: list[float]) -> dict[str, float]:
    """Mediana, média, desvio-padrão amostral, mín, máx, quartis, IQR e coeficiente de variação (%)."""
    v = sorted(float(x) for x in valores if not pd.isna(x))
    n = len(v)
    nan = float("nan")
    if n == 0:
        return {"n_obs": 0, **{c: nan for c in COLUNAS_DESCR[1:]}}
    media = statistics.fmean(v)
    dp = statistics.stdev(v) if n > 1 else nan
    q1, q3 = quantil(v, .25), quantil(v, .75)
    return {"n_obs": n, "mediana_s": statistics.median(v), "media_s": media, "desvio_padrao_s": dp,
            "minimo_s": v[0], "maximo_s": v[-1], "q1_s": q1, "q3_s": q3, "iqr_s": q3 - q1,
            "cv_pct": (dp / media * 100) if (n > 1 and media) else nan}


def familia_de(cenario: str) -> str:
    """'completo_medio_n03' -> 'completo_medio'; 'leve_n10' -> 'leve'."""
    return re.sub(r"_n\d+$", "", str(cenario))


# ---- testes de comparação entre grupos ---------------------------------
def cliff_delta(x: list[float], y: list[float]) -> tuple[float, str]:
    """Delta de Cliff: (#(x>y) - #(x<y)) / (n*m), e a magnitude (limiares de Romano et al., 2006)."""
    if not x or not y:
        return float("nan"), "n/a"
    maior = sum(1 for a in x for b in y if a > b)
    menor = sum(1 for a in x for b in y if a < b)
    d = (maior - menor) / (len(x) * len(y))
    a = abs(d)
    mag = "desprezível" if a < 0.147 else "pequena" if a < 0.33 else "média" if a < 0.474 else "grande"
    return d, mag


def _postos_com_empates(valores: list[float]) -> tuple[list[float], list[int]]:
    ordem = sorted(range(len(valores)), key=lambda i: valores[i])
    postos = [0.0] * len(valores)
    tamanhos = []
    i = 0
    while i < len(ordem):
        j = i
        while j + 1 < len(ordem) and valores[ordem[j + 1]] == valores[ordem[i]]:
            j += 1
        media = (i + j) / 2 + 1
        for k in range(i, j + 1):
            postos[ordem[k]] = media
        tamanhos.append(j - i + 1)
        i = j + 1
    return postos, tamanhos


def mann_whitney_puro(x: list[float], y: list[float]) -> tuple[float, float]:
    """U de Mann-Whitney bilateral com aproximação normal, correção de empates e de continuidade.
    Devolve (U de x, p-valor). Para amostras muito pequenas a aproximação é imprecisa (use scipy)."""
    n1, n2 = len(x), len(y)
    postos, empates = _postos_com_empates(list(x) + list(y))
    u1 = sum(postos[:n1]) - n1 * (n1 + 1) / 2
    n = n1 + n2
    mu = n1 * n2 / 2
    var = n1 * n2 / 12 * ((n + 1) - sum(t ** 3 - t for t in empates) / (n * (n - 1)))
    if var <= 0:
        return u1, 1.0
    z = (abs(u1 - mu) - 0.5) / math.sqrt(var)
    p = math.erfc(max(z, 0.0) / math.sqrt(2))   # 2 * (1 - Phi(z))
    return u1, min(1.0, p)


def mann_whitney(x: list[float], y: list[float], usar_scipy: bool | None = None) -> tuple[float, float, str]:
    """(U, p-valor bilateral, método). Usa scipy quando disponível."""
    if len(x) < 2 or len(y) < 2:
        return float("nan"), float("nan"), "n/a"
    if (USAR_SCIPY if usar_scipy is None else usar_scipy) and _scipy_stats is not None:
        r = _scipy_stats.mannwhitneyu(x, y, alternative="two-sided")
        return float(r.statistic), float(r.pvalue), "scipy"
    u, p = mann_whitney_puro(x, y)
    return u, p, "python puro (aprox. normal)"


def comparar_grupos(nome_a: str, x: list[float], nome_b: str, y: list[float]) -> dict:
    u, p, metodo = mann_whitney(x, y)
    d, mag = cliff_delta(x, y)
    return {"grupo_a": nome_a, "grupo_b": nome_b, "n_a": len(x), "n_b": len(y),
            "mediana_a_s": statistics.median(x) if x else float("nan"),
            "mediana_b_s": statistics.median(y) if y else float("nan"),
            "U": u, "p_valor": p, "metodo": metodo, "delta_cliff": d, "magnitude": mag}


# ---- ajuste linear -------------------------------------------------------
def ajuste_linear(xs: list[float], ys: list[float]) -> tuple[float, float, float]:
    """Mínimos quadrados: (inclinação, intercepto, R2). R2 é nan com menos de 3 pontos ou y constante."""
    n = len(xs)
    if n < 2:
        return float("nan"), float("nan"), float("nan")
    mx, my = statistics.fmean(xs), statistics.fmean(ys)
    sxx = sum((a - mx) ** 2 for a in xs)
    if sxx == 0:
        return float("nan"), float("nan"), float("nan")
    b = sum((a - mx) * (c - my) for a, c in zip(xs, ys)) / sxx
    a0 = my - b * mx
    sst = sum((c - my) ** 2 for c in ys)
    sse = sum((c - (a0 + b * a)) ** 2 for a, c in zip(xs, ys))
    r2 = (1 - sse / sst) if (n >= 3 and sst > 0) else float("nan")
    return b, a0, r2


# ---- carga e agregação ---------------------------------------------------
def ler_varios(caminhos: list[Path]) -> pd.DataFrame:
    return pd.concat([pd.read_csv(c, encoding="utf-8-sig") for c in caminhos], ignore_index=True)


def preparar_tempos(df: pd.DataFrame) -> pd.DataFrame:
    exigir_colunas(df, COLUNAS_TEMPOS, "CSV de tempos por cenário")
    df = df.copy()
    df["segundos"] = pd.to_numeric(df["segundos"], errors="coerce")
    df["exit_code"] = pd.to_numeric(df["exit_code"], errors="coerce").fillna(1).astype(int)
    df["falhas_teste"] = pd.to_numeric(df["falhas_teste"], errors="coerce").fillna(0).astype(int)
    df["n"] = pd.to_numeric(df["n"], errors="coerce").astype(int)
    df["familia"] = df["cenario"].map(familia_de)
    return df


def totais_por_execucao(df: pd.DataFrame, incluir_falhas: bool) -> pd.DataFrame:
    """Uma linha por (cenario, run_id): soma de apply + ansible + smoke, e se a execução falhou.

    Uma execução falha se qualquer fase tem exit_code diferente de 0 ou se algum teste de fumaça falhou.
    Execuções incompletas (faltando uma das três fases) não têm total e são contadas como falha.
    """
    linhas = []
    for (cen, run), g in df.groupby(["cenario", "run_id"], sort=False):
        fases = g.set_index("fase")
        completa = all(f in fases.index for f in FASES_PROVISIONAMENTO)
        falhou = bool((g["exit_code"] != 0).any() or (g["falhas_teste"] > 0).any() or not completa)
        total = float(fases.loc[FASES_PROVISIONAMENTO, "segundos"].sum()) if completa else float("nan")
        linhas.append({"cenario": cen, "run_id": run, "porte": g["porte"].iloc[0], "n": int(g["n"].iloc[0]),
                       "familia": g["familia"].iloc[0], "total_s": total, "falhou": falhou})
    res = pd.DataFrame(linhas)
    if res.empty:
        return res
    res["usar"] = res["total_s"].notna() & (True if incluir_falhas else ~res["falhou"])
    return res


def tabela_descritiva(df: pd.DataFrame, totais: pd.DataFrame) -> pd.DataFrame:
    """Estatísticas por cenário: cada fase e o total de provisionamento."""
    linhas = []
    ok_runs = set(zip(totais.loc[totais["usar"], "cenario"], totais.loc[totais["usar"], "run_id"]))
    for (cen, porte, n), g in df.groupby(["cenario", "porte", "n"], sort=False):
        g_ok = g[[(cen, r) in ok_runs for r in g["run_id"]]]
        for fase in FASES_PROVISIONAMENTO + ["terraform_plan_idempotencia", "terraform_apply_idempotencia",
                                            "teardown_ansible", "terraform_destroy"]:
            v = g_ok.loc[g_ok["fase"] == fase, "segundos"].tolist()
            if v:
                linhas.append({"cenario": cen, "porte": porte, "n": n, "fase": fase, **descrever(v)})
        t = totais[(totais["cenario"] == cen) & totais["usar"]]["total_s"].tolist()
        linhas.append({"cenario": cen, "porte": porte, "n": n, "fase": "total_provisionamento", **descrever(t)})
    return pd.DataFrame(linhas)


def tabela_por_porte(totais: pd.DataFrame) -> pd.DataFrame:
    """Total de provisionamento agrupado por porte (reúne as repetições de todos os cenários do porte)."""
    linhas = []
    usados = totais[totais["usar"]]
    for porte, g in usados.groupby("porte", sort=False):
        linhas.append({"porte": porte, "cenarios": g["cenario"].nunique(), **descrever(g["total_s"].tolist())})
    # também por porte e N (equivale ao cenário do perfil completo)
    for (porte, n), g in usados.groupby(["porte", "n"], sort=True):
        linhas.append({"porte": f"{porte} (N={n})", "cenarios": g["cenario"].nunique(),
                       **descrever(g["total_s"].tolist())})
    return pd.DataFrame(linhas)


def tabela_escalabilidade(totais: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Curva tempo x N por família de cenários (mediana por N), tempo por escola e ajuste linear."""
    pontos, ajustes = [], []
    usados = totais[totais["usar"]]
    for fam, g in usados.groupby("familia", sort=False):
        med = g.groupby("n")["total_s"].median().sort_index()
        if med.empty:
            continue
        anterior = None
        for n, t in med.items():
            inc = float("nan")
            if anterior is not None and n != anterior[0]:
                inc = (t - anterior[1]) / (n - anterior[0])
            pontos.append({"familia": fam, "n": int(n), "mediana_total_s": float(t),
                           "tempo_por_escola_s": float(t) / n, "incremental_por_escola_s": inc})
            anterior = (n, float(t))
        b, a0, r2 = ajuste_linear([float(n) for n in med.index], [float(t) for t in med.values])
        ajustes.append({"familia": fam, "pontos_n": len(med), "inclinacao_s_por_escola": b,
                        "intercepto_s": a0, "r2": r2})
    return pd.DataFrame(pontos), pd.DataFrame(ajustes)


def tabela_falhas(df: pd.DataFrame, totais: pd.DataFrame) -> pd.DataFrame:
    linhas = []
    for cen, g in totais.groupby("cenario", sort=False):
        d = df[df["cenario"] == cen]
        exec_total = len(g)
        com_falha = int(g["falhou"].sum())
        fases_falhas = d[(d["exit_code"] != 0)].groupby("fase").size().to_dict()
        linhas.append({"cenario": cen, "porte": g["porte"].iloc[0], "n": int(g["n"].iloc[0]),
                       "execucoes": exec_total, "execucoes_com_falha": com_falha,
                       "taxa_falha_pct": com_falha / exec_total * 100 if exec_total else float("nan"),
                       "testes_de_fumaca_falhos": int(d["falhas_teste"].sum()),
                       "fases_com_falha": "; ".join(f"{k}={v}" for k, v in sorted(fases_falhas.items())) or "-"})
    return pd.DataFrame(linhas)


def tabela_idempotencia(df: pd.DataFrame) -> pd.DataFrame:
    """Idempotente = plan -detailed-exitcode retornou 0 e 0 recursos a alterar (e o segundo apply nada mudou)."""
    exigir_colunas(df, ["run_id", "cenario", "porte", "n", "plan_exit_code", "recursos_a_alterar"], "CSV idempotência")
    df = df.copy()
    for c in ["plan_exit_code", "recursos_a_alterar", "apply2_adicionados", "apply2_alterados", "apply2_destruidos"]:
        df[c] = pd.to_numeric(df.get(c), errors="coerce")
    apply_limpo = (df[["apply2_adicionados", "apply2_alterados", "apply2_destruidos"]].fillna(0) == 0).all(axis=1)
    df["idempotente"] = (df["plan_exit_code"] == 0) & (df["recursos_a_alterar"] == 0) & apply_limpo
    df["medido"] = df["plan_exit_code"].notna() & df["recursos_a_alterar"].notna()
    linhas = []
    for (cen, porte, n), g in df.groupby(["cenario", "porte", "n"], sort=False):
        m = g[g["medido"]]
        linhas.append({"cenario": cen, "porte": porte, "n": int(n), "execucoes_medidas": len(m),
                       "idempotentes": int(m["idempotente"].sum()),
                       "taxa_idempotencia_pct": m["idempotente"].mean() * 100 if len(m) else float("nan"),
                       "recursos_a_alterar_max": m["recursos_a_alterar"].max() if len(m) else float("nan"),
                       "plan_exit_code_2": int((m["plan_exit_code"] == 2).sum())})
    return pd.DataFrame(linhas)


def tabela_consistencia(df: pd.DataFrame) -> pd.DataFrame:
    """Proporção de execuções cujo hash é igual ao hash mais frequente (moda) do cenário."""
    exigir_colunas(df, ["run_id", "cenario", "porte", "n", "hash_estado_tf", "hash_docker"], "CSV consistência")
    linhas = []
    for (cen, porte, n), g in df.groupby(["cenario", "porte", "n"], sort=False):
        linha = {"cenario": cen, "porte": porte, "n": int(n), "execucoes": len(g)}
        combinado = g["hash_estado_tf"].astype(str) + "|" + g["hash_docker"].astype(str)
        for nome, serie in [("estado_tf", g["hash_estado_tf"]), ("docker", g["hash_docker"]),
                            ("combinado", combinado)]:
            vc = serie.value_counts()
            linha[f"hashes_distintos_{nome}"] = int(len(vc))
            linha[f"consistencia_{nome}_pct"] = float(vc.iloc[0] / len(serie) * 100) if len(serie) else float("nan")
        linhas.append(linha)
    return pd.DataFrame(linhas)


def tabela_comparacoes(totais: pd.DataFrame, pares: list[tuple[str, str]]) -> pd.DataFrame:
    """Compara o total de provisionamento entre grupos. Um grupo é um cenário ('leve_n05') ou 'porte:medio'.
    Sem pares explícitos, compara automaticamente os portes do perfil completo com o mesmo N."""
    usados = totais[totais["usar"]]

    def valores(grupo: str) -> list[float]:
        if grupo.startswith("porte:"):
            return usados.loc[usados["porte"] == grupo.split(":", 1)[1], "total_s"].tolist()
        return usados.loc[usados["cenario"] == grupo, "total_s"].tolist()

    if not pares:
        comp = usados[usados["familia"].str.startswith("completo_")]
        for n, g in comp.groupby("n"):
            cenarios = list(dict.fromkeys(g["cenario"]))
            pares += [(a, b) for i, a in enumerate(cenarios) for b in cenarios[i + 1:]]
    return pd.DataFrame([comparar_grupos(a, valores(a), b, valores(b)) for a, b in pares])


def salvar(df: pd.DataFrame, base: Path, titulo: str, md: list[str]) -> None:
    base.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(base.with_suffix(".csv"), index=False)
    md.append(f"### {titulo}\n\n{tabela_markdown(df)}\n")


def analisar_cenarios(bruto: pd.DataFrame, args: argparse.Namespace, md: list[str]) -> None:
    df = preparar_tempos(bruto)
    totais = totais_por_execucao(df, args.incluir_falhas)
    md.append(f"_Cenários: {df['cenario'].nunique()}; execuções: {len(totais)}; "
              f"execuções com falha: {int(totais['falhou'].sum())} "
              f"({'incluídas' if args.incluir_falhas else 'excluídas dos tempos'})._\n")
    salvar(tabela_descritiva(df, totais), Path(f"{args.saida}_cenarios_tempo"),
           "Tempo por cenário e fase (segundos): mediana, média, desvio-padrão, mín, máx, IQR e CV", md)
    salvar(tabela_por_porte(totais), Path(f"{args.saida}_porte_tempo"),
           "Tempo total de provisionamento por porte (segundos)", md)
    pontos, ajustes = tabela_escalabilidade(totais)
    if not pontos.empty:
        salvar(pontos, Path(f"{args.saida}_escalabilidade_curva"),
               "Escalabilidade: tempo x N (mediana), tempo por escola e incremental", md)
        salvar(ajustes, Path(f"{args.saida}_escalabilidade_ajuste"),
               "Escalabilidade: ajuste linear tempo = a + b x N (R2 só com 3 ou mais valores de N)", md)
    salvar(tabela_falhas(df, totais), Path(f"{args.saida}_falhas"), "Falhas por cenário", md)
    comp = tabela_comparacoes(totais, [tuple(p) for p in args.comparar])
    if not comp.empty:
        salvar(comp, Path(f"{args.saida}_comparacoes"),
               "Comparação entre grupos (Mann-Whitney bilateral e delta de Cliff)", md)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--iac", type=Path, help="CSV de executar_medicao (run_id,fase,segundos,exit_code,timestamp)")
    ap.add_argument("--manual", type=Path, help="CSV do baseline manual")
    ap.add_argument("--replicacao", type=Path, help="CSV de replicacao.sh")
    ap.add_argument("--drift", type=Path, help="CSV de drift_test.sh")
    ap.add_argument("--tempos", type=Path, nargs="+", help="CSV(s) *_tempos.csv de executar_cenario")
    ap.add_argument("--idempotencia", type=Path, nargs="+", help="CSV(s) *_idempotencia.csv")
    ap.add_argument("--consistencia", type=Path, nargs="+", help="CSV(s) *_consistencia.csv")
    ap.add_argument("--comparar", nargs=2, action="append", metavar=("A", "B"), default=[],
                    help="compara dois grupos (cenário ou porte:NOME); repetível. Padrão: portes do perfil "
                         "completo com o mesmo N")
    ap.add_argument("--sem-scipy", action="store_true", help="força a implementação em Python puro dos testes")
    ap.add_argument("--saida", type=Path, default=Path("resultados/analise"), help="prefixo dos arquivos de saída")
    ap.add_argument("--incluir-falhas", action="store_true", help="inclui linhas com exit_code diferente de 0")
    args = ap.parse_args()
    if not any([args.iac, args.manual, args.replicacao, args.drift, args.tempos,
                args.idempotencia, args.consistencia]):
        ap.error("informe pelo menos um CSV de entrada")

    md: list[str] = ["# Resultados da análise\n",
                     "Estatísticas calculadas a partir dos CSV informados. Desvio-padrão amostral (n-1); "
                     "\"n/a\" quando há uma única observação.\n"]
    totais_iac = None
    if args.iac:
        por_fase, totais_iac, nota = analisar_iac(pd.read_csv(args.iac, encoding="utf-8-sig"), args.incluir_falhas)
        md.append(f"_{nota}_\n")
        salvar(por_fase, Path(f"{args.saida}_iac_por_fase"), "Fluxo IaC por fase (segundos)", md)
    if args.manual:
        por_etapa, por_fase_m, total_rep = analisar_manual(pd.read_csv(args.manual, encoding="utf-8-sig"))
        salvar(por_fase_m, Path(f"{args.saida}_manual_por_fase"), "Baseline manual por fase equivalente (segundos)", md)
        salvar(por_etapa, Path(f"{args.saida}_manual_por_etapa"), "Baseline manual por etapa (segundos)", md)
        salvar(total_rep, Path(f"{args.saida}_manual_totais"), "Baseline manual: total e erros por repetição", md)
        if totais_iac is not None and len(totais_iac) > 0:
            e_m = estatisticas(total_rep["segundos_total_manual"].tolist())
            e_i = estatisticas(totais_iac["segundos_total_iac"].tolist())
            comp = pd.DataFrame([
                {"abordagem": "manual", **e_m},
                {"abordagem": "iac (apply+ansible+smoke)", **e_i},
            ])
            razao = e_m["media_s"] / e_i["media_s"] if e_i["media_s"] else float("nan")
            salvar(comp, Path(f"{args.saida}_comparativo"), "Comparativo do total (manual x IaC)", md)
            md.append(f"Razão entre as médias (manual / IaC): {razao:.2f}. Interprete com o cuidado descrito no "
                      "protocolo: o tempo de autoria do código IaC não está incluído.\n")
    if args.replicacao:
        salvar(analisar_replicacao(pd.read_csv(args.replicacao, encoding="utf-8-sig")),
               Path(f"{args.saida}_replicacao"), "Replicação por número de escolas (segundos)", md)
    if args.drift:
        drift = pd.read_csv(args.drift, encoding="utf-8-sig")
        salvar(drift, Path(f"{args.saida}_drift"), "Teste de deriva (valores observados)", md)

    if args.sem_scipy:
        global USAR_SCIPY
        USAR_SCIPY = False
    if args.tempos:
        analisar_cenarios(ler_varios(args.tempos), args, md)
    if args.idempotencia:
        salvar(tabela_idempotencia(ler_varios(args.idempotencia)), Path(f"{args.saida}_idempotencia"),
               "Idempotência (plan -detailed-exitcode = 0 e 0 recursos a alterar)", md)
    if args.consistencia:
        salvar(tabela_consistencia(ler_varios(args.consistencia)), Path(f"{args.saida}_consistencia"),
               "Consistência entre execuções (proporção com hash igual ao mais frequente)", md)

    destino = Path(f"{args.saida}.md")
    destino.parent.mkdir(parents=True, exist_ok=True)
    destino.write_text("\n".join(md), encoding="utf-8")
    print(f"Tabelas gravadas em {destino} e arquivos {args.saida}_*.csv")


if __name__ == "__main__":
    main()
