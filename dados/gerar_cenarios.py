#!/usr/bin/env python3
"""Gera cenários de teste da PoC a partir do Censo Escolar 2024 (INEP).

Lê os microdados, filtra escolas em atividade, da rede estadual ou municipal e com
matrícula na educação básica, classifica cada escola por porte e sorteia escolas
reais para montar cenários no formato da variável "escolas" do módulo Terraform.

Saídas (relativas à raiz do repositório):
    dados/resumo_dataset.json   contagens, quantis, percentuais e regras
    cenarios/*.tfvars.json      um arquivo por cenário
    cenarios/manifesto.csv      uma linha por escola de cada cenário

Os parâmetros de infraestrutura (memória, CPUs, alvos de monitoramento, modo
local-first, frequência de backup) NÃO são medidos: são DERIVADOS por regra simples
a partir do porte e de indicadores do Censo. Veja docs/DATASET.md.

Uso:
    python dados/gerar_cenarios.py [--csv CAMINHO] [--semente 20260929]
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
import pandas as pd

RAIZ = Path(__file__).resolve().parent.parent
CSV_PADRAO = (RAIZ / "dados" / "microdados_censo_escolar_2024_defeso" / "dados"
              / "microdados_ed_basica_2024.csv")
SEMENTE_PADRAO = 20260929

COLUNAS = [
    "CO_ENTIDADE", "SG_UF", "TP_DEPENDENCIA", "TP_LOCALIZACAO", "TP_SITUACAO_FUNCIONAMENTO",
    "QT_MAT_BAS", "QT_TUR_BAS", "IN_LABORATORIO_INFORMATICA", "QT_DESKTOP_ALUNO",
    "QT_COMP_PORTATIL_ALUNO", "IN_INTERNET", "IN_INTERNET_APRENDIZAGEM", "IN_BANDA_LARGA",
    "IN_ENERGIA_REDE_PUBLICA",
]

# ------------------------------------------------------------------ regras
PORTES = ["pequeno", "medio", "grande"]
LIMITE_PEQUENO = 200          # até 200 matrículas
LIMITE_MEDIO = 800            # de 201 a 800; acima disso, grande
MEMORIA_MOODLE_MB = {"pequeno": 512, "medio": 1024, "grande": 2048}
CPUS = {"pequeno": 0.5, "medio": 1.0, "grande": 2.0}
BACKUP = {"pequeno": "semanal", "medio": "diaria", "grande": "12h"}
ALVOS_MAX = 50
N_COMPLETO = [1, 3, 5]
N_LEVE = [1, 5, 10, 25, 50]
# Bloco /12 dividido em /20 por escola (256 escolas possíveis). O padrão do módulo (/16)
# comporta apenas 16 escolas, insuficiente para o cenário de 50.
REDE_BASE = "10.64.0.0/12"
# Estimativa de planejamento (NÃO medida) para as demais contêineres de uma escola
# completa (MariaDB, Nginx, Prometheus, Blackbox, Grafana).
SOBRECARGA_COMPLETO_MB = 1024
ORCAMENTO_MB = 16 * 1024


def porte_de(matriculas: float) -> str:
    if matriculas <= LIMITE_PEQUENO:
        return "pequeno"
    if matriculas <= LIMITE_MEDIO:
        return "medio"
    return "grande"


def carregar(csv: Path) -> tuple[pd.DataFrame, dict[str, int]]:
    """Lê o CSV, aplica os filtros e devolve a base e as contagens de cada etapa."""
    df = pd.read_csv(csv, sep=";", encoding="latin1", usecols=COLUNAS, low_memory=False)
    contagens = {"linhas_arquivo": int(len(df))}
    df = df[df["TP_SITUACAO_FUNCIONAMENTO"] == 1]
    contagens["em_atividade"] = int(len(df))
    df = df[df["TP_DEPENDENCIA"].isin([2, 3])]
    contagens["estaduais_municipais_em_atividade"] = int(len(df))
    df = df[df["QT_MAT_BAS"].fillna(0) > 0].copy()
    contagens["com_matricula_maior_que_zero"] = int(len(df))
    df = df.sort_values("CO_ENTIDADE").reset_index(drop=True)  # ordem independente do arquivo
    return df, contagens


def derivar(df: pd.DataFrame) -> pd.DataFrame:
    """Acrescenta porte e os parâmetros derivados por regra."""
    for c in ["IN_LABORATORIO_INFORMATICA", "IN_INTERNET", "IN_INTERNET_APRENDIZAGEM",
              "IN_BANDA_LARGA", "IN_ENERGIA_REDE_PUBLICA", "QT_DESKTOP_ALUNO",
              "QT_COMP_PORTATIL_ALUNO"]:
        df[c] = df[c].fillna(0)   # ausente = sem informação de existência; tratado como 0
    df["matriculas"] = df["QT_MAT_BAS"].astype(int)
    df["porte"] = df["matriculas"].map(porte_de)
    df["laboratorio"] = df["IN_LABORATORIO_INFORMATICA"].astype(int)
    df["equipamentos"] = (df["QT_DESKTOP_ALUNO"] + df["QT_COMP_PORTATIL_ALUNO"]).astype(int)
    df["internet_aprendizagem"] = df["IN_INTERNET_APRENDIZAGEM"].astype(int)
    df["banda_larga"] = df["IN_BANDA_LARGA"].astype(int)
    df["memoria_moodle_mb"] = df["porte"].map(MEMORIA_MOODLE_MB)
    df["cpus"] = df["porte"].map(CPUS)
    df["alvos_monitoramento"] = df["equipamentos"].clip(lower=1, upper=ALVOS_MAX)
    df["modo_local_first"] = df["banda_larga"] == 0
    df["backup_frequencia"] = df["porte"].map(BACKUP)
    return df


def pct(serie: pd.Series) -> float:
    return round(float(serie.mean() * 100), 2)


def quantis(serie: pd.Series) -> dict[str, float]:
    qs = {"min": serie.min(), "p10": serie.quantile(.10), "p25": serie.quantile(.25),
          "mediana": serie.median(), "p75": serie.quantile(.75), "p90": serie.quantile(.90),
          "p99": serie.quantile(.99), "max": serie.max()}
    return {k: float(v) for k, v in qs.items()}


def resumo(df: pd.DataFrame, contagens: dict[str, int], csv: Path, semente: int) -> dict:
    por_porte = {}
    for p in PORTES:
        g = df[df["porte"] == p]
        por_porte[p] = {
            "escolas": int(len(g)),
            "percentual_da_base": round(len(g) / len(df) * 100, 2),
            "matriculas_mediana": float(g["matriculas"].median()),
            "equipamentos_mediana": float(g["equipamentos"].median()),
            "com_laboratorio_pct": pct(g["laboratorio"]),
            "com_banda_larga_pct": pct(g["banda_larga"]),
            "sem_banda_larga_local_first": int(g["modo_local_first"].sum()),
        }
    return {
        "fonte": "Censo Escolar da Educação Básica 2024 - microdados (INEP)",
        "arquivo": csv.name,
        "sha256_arquivo": hashlib.sha256(csv.read_bytes()).hexdigest(),
        "semente": semente,
        "contagens": contagens,
        "quantis_QT_MAT_BAS": quantis(df["matriculas"]),
        "quantis_equipamentos": quantis(df["equipamentos"]),
        "percentuais_base_filtrada": {
            "laboratorio_informatica": pct(df["laboratorio"]),
            "internet": pct(df["IN_INTERNET"]),
            "internet_aprendizagem": pct(df["internet_aprendizagem"]),
            "banda_larga": pct(df["banda_larga"]),
            "banda_larga_entre_escolas_com_internet": pct(df.loc[df["IN_INTERNET"] == 1, "banda_larga"]),
            "energia_rede_publica": pct(df["IN_ENERGIA_REDE_PUBLICA"]),
            "sem_banda_larga_local_first": pct(df["modo_local_first"]),
        },
        "regras": {
            "filtros": ["TP_SITUACAO_FUNCIONAMENTO == 1", "TP_DEPENDENCIA in {2, 3}",
                        "QT_MAT_BAS > 0"],
            "porte": {"pequeno": f"matriculas <= {LIMITE_PEQUENO}",
                      "medio": f"{LIMITE_PEQUENO + 1} a {LIMITE_MEDIO} matriculas",
                      "grande": f"matriculas > {LIMITE_MEDIO}"},
            "memoria_moodle_mb": MEMORIA_MOODLE_MB,
            "cpus": CPUS,
            "alvos_monitoramento": f"min(equipamentos, {ALVOS_MAX}), minimo 1; "
                                   "equipamentos = QT_DESKTOP_ALUNO + QT_COMP_PORTATIL_ALUNO",
            "modo_local_first": "IN_BANDA_LARGA == 0 (ausente conta como 0): rede servidores interna",
            "backup_frequencia": BACKUP,
            "valores_ausentes": "indicadores e quantidades ausentes tratados como 0 (escola sem "
                                "internet costuma ter IN_BANDA_LARGA ausente e cai em local-first)",
        },
        "escolas_por_porte": por_porte,
    }


# --------------------------------------------------------------- cenários
def bloco_escola(linha: pd.Series, indice: int, perfil: str) -> tuple[str, dict]:
    chave = f"escola{indice + 1:02d}"
    co = str(int(linha["CO_ENTIDADE"]))
    obj: dict = {
        "nome": f"Escola INEP {co}",
        "indice": indice,
        "habilitar_moodle": perfil == "completo",
        "perfil": perfil,
        "porte": linha["porte"],
        "co_entidade": co,
        "alvos_monitoramento": int(linha["alvos_monitoramento"]),
        "modo_local_first": bool(linha["modo_local_first"]),
        "backup_frequencia": linha["backup_frequencia"],
    }
    if perfil == "completo":
        obj["memoria_mb"] = int(linha["memoria_moodle_mb"])
        obj["cpus"] = float(linha["cpus"])
    return chave, obj


def montar_cenario(nome: str, perfil: str, escolas: pd.DataFrame, descricao: str):
    """Devolve (tfvars, linhas_do_manifesto, resumo_do_cenario)."""
    mapa, linhas = {}, []
    mem_moodle = 0
    for i, (_, e) in enumerate(escolas.iterrows()):
        chave, obj = bloco_escola(e, i, perfil)
        mapa[chave] = obj
        mem_moodle += obj.get("memoria_mb", 0)
        linhas.append({
            "cenario": nome, "perfil": perfil, "prefixo": chave, "indice": i,
            "CO_ENTIDADE": obj["co_entidade"], "UF": e["SG_UF"], "porte": e["porte"],
            "matriculas": int(e["matriculas"]), "laboratorio": int(e["laboratorio"]),
            "equipamentos": int(e["equipamentos"]),
            "internet_aprendizagem": int(e["internet_aprendizagem"]),
            "banda_larga": int(e["banda_larga"]),
            "memoria_moodle_mb": obj.get("memoria_mb", ""), "cpus": obj.get("cpus", ""),
            "alvos_monitoramento": obj["alvos_monitoramento"],
            "modo_local_first": str(obj["modo_local_first"]).lower(),
            "backup_frequencia": obj["backup_frequencia"],
        })
    n = len(mapa)
    if perfil == "completo":
        estimada = mem_moodle + n * SOBRECARGA_COMPLETO_MB
        est = {"memoria_moodle_mb_total": mem_moodle,
               "memoria_estimada_mb": estimada,
               "cabe_em_16gb": estimada <= ORCAMENTO_MB,
               "folga_estimada_mb": ORCAMENTO_MB - estimada}
    else:
        est = {}
    tfvars = {"rede_base_escolas": REDE_BASE, "escolas": mapa}
    meta = {"cenario": nome, "perfil": perfil, "n_escolas": n, "descricao": descricao,
            "portes": {p: int((escolas["porte"] == p).sum()) for p in PORTES}, **est}
    return tfvars, linhas, meta


def gerar(df: pd.DataFrame, semente: int, destino: Path) -> tuple[list[dict], list[dict]]:
    destino.mkdir(parents=True, exist_ok=True)
    for antigo in destino.glob("*.tfvars.json"):   # evita sobras de execuções anteriores
        antigo.unlink()
    todas, metas = [], []

    def gravar(nome, perfil, escolas, descricao):
        tfvars, linhas, meta = montar_cenario(nome, perfil, escolas, descricao)
        (destino / f"{nome}.tfvars.json").write_text(
            json.dumps(tfvars, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        todas.extend(linhas)
        metas.append(meta)

    # Perfil completo: amostragem aninhada dentro de cada porte (N=1 está em N=3, e este em N=5).
    for k, p in enumerate(PORTES):
        pop = df[df["porte"] == p]
        rng = np.random.default_rng([semente, k])
        ordem = pop.iloc[rng.permutation(len(pop))]
        for n in N_COMPLETO:
            gravar(f"completo_{p}_n{n:02d}", "completo", ordem.iloc[:n],
                   f"Perfil completo, {n} escola(s) de porte {p} sorteadas da população real")

    # Perfil leve: amostragem aninhada da população inteira (porte misto conforme a distribuição real).
    rng = np.random.default_rng([semente, 99])
    ordem = df.iloc[rng.permutation(len(df))]
    for n in N_LEVE:
        gravar(f"leve_n{n:02d}", "leve", ordem.iloc[:n],
               f"Perfil leve, {n} escola(s) sorteadas da população inteira (escalabilidade)")
    return todas, metas


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--csv", type=Path, default=CSV_PADRAO)
    ap.add_argument("--semente", type=int, default=SEMENTE_PADRAO)
    ap.add_argument("--saida-cenarios", type=Path, default=RAIZ / "cenarios")
    ap.add_argument("--saida-resumo", type=Path, default=RAIZ / "dados" / "resumo_dataset.json")
    args = ap.parse_args()
    if not args.csv.is_file():
        sys.exit(f"CSV não encontrado: {args.csv}")

    df, contagens = carregar(args.csv)
    df = derivar(df)
    res = resumo(df, contagens, args.csv, args.semente)

    linhas, metas = gerar(df, args.semente, args.saida_cenarios)
    res["cenarios"] = metas
    args.saida_resumo.write_text(json.dumps(res, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    pd.DataFrame(linhas).to_csv(args.saida_cenarios / "manifesto.csv", index=False, encoding="utf-8")

    print(f"Base filtrada: {len(df)} escolas")
    for p in PORTES:
        print(f"  {p}: {res['escolas_por_porte'][p]['escolas']}")
    print(f"Cenários gerados: {len(metas)} em {args.saida_cenarios}")
    print(f"Resumo: {args.saida_resumo}")


if __name__ == "__main__":
    main()
