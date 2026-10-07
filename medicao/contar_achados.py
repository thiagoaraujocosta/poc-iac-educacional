#!/usr/bin/env python3
"""Conta os achados de uma ferramenta de análise a partir da saída JSON.

Uso: contar_achados.py FERRAMENTA ARQUIVO_JSON
FERRAMENTA: tflint | trivy | checkov | ansible-lint | gitleaks
Imprime um inteiro (número de achados). Se o arquivo não existir ou estiver vazio, imprime 0.
Nenhum valor é presumido: a contagem vem somente do que a ferramenta reportou.
"""
import json
import sys
from pathlib import Path


def carregar(caminho):
    p = Path(caminho)
    if not p.exists() or p.stat().st_size == 0:
        return None
    txt = p.read_text(encoding="utf-8", errors="replace").strip()
    if not txt:
        return None
    try:
        return json.loads(txt)
    except json.JSONDecodeError:
        return None


def contar(ferramenta, dados):
    if dados is None:
        return 0
    if ferramenta == "tflint":
        return len(dados.get("issues", [])) + len(dados.get("errors", []))
    if ferramenta == "trivy":
        total = 0
        for r in dados.get("Results", []) or []:
            total += len(r.get("Misconfigurations") or [])
            total += len(r.get("Secrets") or [])
        return total
    if ferramenta == "checkov":
        itens = dados if isinstance(dados, list) else [dados]
        total = 0
        for it in itens:
            total += len(((it.get("results") or {}).get("failed_checks")) or [])
        return total
    if ferramenta == "ansible-lint":
        return len(dados) if isinstance(dados, list) else 0
    if ferramenta == "gitleaks":
        return len(dados) if isinstance(dados, list) else 0
    raise SystemExit("Ferramenta desconhecida: " + ferramenta)


def ids(ferramenta, dados):
    """Identificadores únicos das regras que dispararam (para auditar o que foi detectado)."""
    if dados is None:
        return set()
    r = set()
    if ferramenta == "tflint":
        r = {i.get("rule", {}).get("name", "?") for i in dados.get("issues", [])}
    elif ferramenta == "trivy":
        for x in dados.get("Results", []) or []:
            r |= {m.get("ID", "?") for m in (x.get("Misconfigurations") or [])}
            r |= {m.get("RuleID", "?") for m in (x.get("Secrets") or [])}
    elif ferramenta == "checkov":
        for it in (dados if isinstance(dados, list) else [dados]):
            r |= {c.get("check_id", "?") for c in (((it.get("results") or {}).get("failed_checks")) or [])}
    elif ferramenta == "ansible-lint":
        r = {i.get("check_name", "?") for i in dados} if isinstance(dados, list) else set()
    elif ferramenta == "gitleaks":
        r = {i.get("RuleID", "?") for i in dados} if isinstance(dados, list) else set()
    return r


if __name__ == "__main__":
    if len(sys.argv) == 5 and sys.argv[1] == "novos":
        # novos FERRAMENTA BASE.json PLANTADA.json -> regras que aparecem só na versão com a deficiência
        f_ = sys.argv[2]
        novos = sorted(ids(f_, carregar(sys.argv[4])) - ids(f_, carregar(sys.argv[3])))
        print(";".join(novos))
        raise SystemExit(0)
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    print(contar(sys.argv[1], carregar(sys.argv[2])))
