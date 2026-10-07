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


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    print(contar(sys.argv[1], carregar(sys.argv[2])))
