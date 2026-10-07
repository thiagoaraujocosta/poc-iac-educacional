#!/usr/bin/env python3
"""Auxiliar dos scripts de medição por cenário (sem dependências além da biblioteca padrão).

Subcomandos:
    resumo ARQ.tfvars.json          imprime "nome porte n" do cenário (porte = "misto" se houver mais de um)
    escolas ARQ.tfvars.json         imprime "prefixo indice perfil moodle(0/1)" por escola
    contar-mudancas PLANO.json      número de recursos com ação diferente de no-op/read (saída de "show -json plano")
    hash-tf ESTADO.json [--mostrar] hash do estado normalizado ("terraform show -json")
    hash-docker CONT.json REDES.json VOLS.json [--mostrar]
                                    hash da saída normalizada de "docker inspect"

A normalização usa lista de atributos ESTÁVEIS (lista branca). Ficam de fora identificadores efêmeros
(ids, IPs atribuídos, timestamps), chaves e certificados gerados, e senhas (valores mascarados).
"""
from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path

SEGREDO = re.compile(r"(PASS|SECRET|TOKEN|KEY)", re.IGNORECASE)


def carregar(caminho: str):
    return json.loads(Path(caminho).read_text(encoding="utf-8-sig"))


# --------------------------------------------------------------- cenário
def cmd_resumo(arq: str) -> None:
    escolas = carregar(arq)["escolas"]
    portes = {e.get("porte") or "n/d" for e in escolas.values()}
    porte = portes.pop() if len(portes) == 1 else "misto"
    print(Path(arq).name.removesuffix(".tfvars.json").removesuffix(".json"), porte, len(escolas))


def cmd_escolas(arq: str) -> None:
    for chave, e in sorted(carregar(arq)["escolas"].items(), key=lambda kv: kv[1]["indice"]):
        perfil = e.get("perfil", "completo")
        moodle = 1 if perfil == "completo" and e.get("habilitar_moodle", True) else 0
        print(chave, e["indice"], perfil, moodle)


# ------------------------------------------------------------ idempotência
def cmd_contar_mudancas(arq: str) -> None:
    mudancas = carregar(arq).get("resource_changes", [])
    ignorar = ([ "no-op" ], [ "read" ])
    print(sum(1 for r in mudancas if r.get("change", {}).get("actions") not in ignorar))


# ------------------------------------------------------------ normalização
def mascarar_env(env: list[str] | None) -> list[str]:
    saida = []
    for item in env or []:
        chave, _, valor = item.partition("=")
        saida.append(f"{chave}=<oculto>" if SEGREDO.search(chave) else item)
    return sorted(saida)


def ordenar(lista: list | None) -> list:
    return sorted((lista or []), key=lambda x: json.dumps(x, sort_keys=True))


def pegar(d: dict, *chaves: str) -> dict:
    return {k: d.get(k) for k in chaves}


def normalizar_recurso(r: dict) -> dict:
    v = r.get("values") or {}
    tipo = r["type"]
    base = {"address": r["address"], "type": tipo}
    if tipo == "docker_network":
        base |= pegar(v, "name", "driver", "internal")
        base["subnets"] = sorted(c.get("subnet") for c in v.get("ipam_config") or [])
        base["labels"] = ordenar(v.get("labels"))
    elif tipo == "docker_volume":
        base |= pegar(v, "name", "driver")
        base["labels"] = ordenar(v.get("labels"))
    elif tipo == "docker_image":
        base |= pegar(v, "name", "keep_locally")
    elif tipo == "docker_container":
        base |= pegar(v, "name", "restart", "memory", "cpu_shares", "command", "wait")
        base["env"] = mascarar_env(v.get("env"))
        base["ports"] = ordenar([pegar(p, "internal", "external", "ip", "protocol") for p in v.get("ports") or []])
        base["redes"] = sorted(n.get("name") for n in v.get("networks_advanced") or [])
        base["volumes"] = ordenar([pegar(x, "volume_name", "container_path") for x in v.get("volumes") or []])
        base["labels"] = ordenar(v.get("labels"))
        base["healthcheck"] = v.get("healthcheck")
        ups = []
        for u in v.get("upload") or []:
            # certificados e chaves são gerados a cada execução: só o caminho entra no hash
            conteudo = "" if "/certs/" in (u.get("file") or "") else hashlib.sha256(
                (u.get("content") or "").encode()).hexdigest()
            ups.append({"file": u.get("file"), "conteudo_sha256": conteudo})
        base["upload"] = ordenar(ups)
    elif tipo == "random_password":
        base |= pegar(v, "length", "special")
    elif tipo == "tls_private_key":
        base |= pegar(v, "algorithm", "ecdsa_curve")
    elif tipo == "tls_self_signed_cert":
        base |= pegar(v, "allowed_uses", "dns_names", "ip_addresses", "validity_period_hours")
    return base


def recursos_do_modulo(mod: dict):
    yield from mod.get("resources", [])
    for filho in mod.get("child_modules", []):
        yield from recursos_do_modulo(filho)


def normalizar_tf(estado: dict) -> list[dict]:
    raiz = (estado.get("values") or {}).get("root_module") or {}
    recursos = [normalizar_recurso(r) for r in recursos_do_modulo(raiz)]
    return sorted(recursos, key=lambda r: r["address"])


def nome_estavel(nome: str | None) -> str | None:
    """Volumes anônimos têm nome aleatório de 64 hexadecimais: não entram no hash."""
    return "<anonimo>" if nome and re.fullmatch(r"[0-9a-f]{64}", nome) else nome


def normalizar_docker(conteineres: list, redes: list, volumes: list) -> dict:
    c_norm = []
    for c in conteineres:
        cfg, host = c.get("Config") or {}, c.get("HostConfig") or {}
        c_norm.append({
            "nome": (c.get("Name") or "").lstrip("/"),
            "imagem": cfg.get("Image"),
            "cmd": cfg.get("Cmd"),
            "env": mascarar_env(cfg.get("Env")),
            "labels": dict(sorted((cfg.get("Labels") or {}).items())),
            "memoria": host.get("Memory"),
            "cpu_shares": host.get("CpuShares"),
            "restart": (host.get("RestartPolicy") or {}).get("Name"),
            "portas": {k: sorted(b.get("HostPort", "") for b in (v or []))
                       for k, v in sorted((host.get("PortBindings") or {}).items())},
            "redes": sorted(((c.get("NetworkSettings") or {}).get("Networks") or {}).keys()),
            "montagens": ordenar([{"tipo": m.get("Type"), "nome": nome_estavel(m.get("Name")),
                                   "destino": m.get("Destination")}
                                  for m in c.get("Mounts") or []]),
        })
    r_norm = [{
        "nome": r.get("Name"), "driver": r.get("Driver"), "interna": r.get("Internal"),
        "sub_redes": sorted(x.get("Subnet") for x in (r.get("IPAM") or {}).get("Config") or []),
        "labels": dict(sorted((r.get("Labels") or {}).items())),
    } for r in redes]
    v_norm = [{"nome": v.get("Name"), "driver": v.get("Driver"),
               "labels": dict(sorted((v.get("Labels") or {}).items()))} for v in volumes]
    return {"conteineres": sorted(c_norm, key=lambda x: x["nome"]),
            "redes": sorted(r_norm, key=lambda x: x["nome"]),
            "volumes": sorted(v_norm, key=lambda x: x["nome"])}


def hash_json(obj) -> str:
    return hashlib.sha256(json.dumps(obj, sort_keys=True, ensure_ascii=False).encode("utf-8")).hexdigest()


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 2
    cmd, args = argv[1], [a for a in argv[2:] if a != "--mostrar"]
    mostrar = "--mostrar" in argv
    if cmd == "resumo":
        cmd_resumo(args[0])
    elif cmd == "escolas":
        cmd_escolas(args[0])
    elif cmd == "contar-mudancas":
        cmd_contar_mudancas(args[0])
    elif cmd == "hash-tf":
        norm = normalizar_tf(carregar(args[0]))
        print(json.dumps(norm, indent=1, sort_keys=True, ensure_ascii=False) if mostrar else hash_json(norm))
    elif cmd == "hash-docker":
        norm = normalizar_docker(*(carregar(a) for a in args[:3]))
        print(json.dumps(norm, indent=1, sort_keys=True, ensure_ascii=False) if mostrar else hash_json(norm))
    else:
        print(f"Subcomando desconhecido: {cmd}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
