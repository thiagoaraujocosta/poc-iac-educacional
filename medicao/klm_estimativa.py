#!/usr/bin/env python3
"""Estimativa do tempo de um operador humano pelo Keystroke-Level Model (KLM).

Referência: CARD, S. K.; MORAN, T. P.; NEWELL, A. The keystroke-level model for user performance time with
interactive systems. Communications of the ACM, v. 23, n. 7, p. 396-410, 1980. DOI 10.1145/358886.358895.

ISTO É UMA ESTIMATIVA POR MODELO, NÃO UMA MEDIÇÃO. Ela vale para um operador especialista que conhece o roteiro e
não comete erros; não estima erros, aprendizado nem variação entre pessoas.

Entradas: o próprio script imperativo (medicao/baseline_imperativo.sh), de onde saem os comandos que uma pessoa
digitaria, e os CSV medidos do baseline (tempo de máquina por fase). Nada é inventado: os operadores K e M vêm do
modelo, e o tempo de máquina vem das medições.

Premissas (todas explícitas na saída):
  K  = tempo por tecla: 0,12 s (bom digitador), 0,20 s (digitador habilidoso médio) e 0,28 s (médio, sem prática).
  M  = 1,35 s de preparação mental por comando (valor padrão do KLM).
  Arquivos de configuração e LDIF são colados de modelos prontos: custo fixo de 1 M + 5 K + 1 H (H = 0,40 s).
  Senhas e nomes são digitados com o comprimento real das variáveis expandidas (senhas de 12 caracteres).
  Limite inferior: a inicialização do Moodle (cerca de 67 s, medida no log) se sobrepõe ao trabalho do operador.
  Limite superior: o operador espera a máquina terminar cada passo (sem sobreposição).
Uso: python klm_estimativa.py [--tempos DIR_CSV_DO_BASELINE] [--saida PREFIXO]
"""
import argparse
import csv
import glob
import json
import os
import re
import statistics

QUALIDADE_K = {'bom digitador (0,12 s)': 0.12, 'digitador habilidoso (0,20 s)': 0.20, 'digitador médio (0,28 s)': 0.28}
M = 1.35
H = 0.40
ARQUIVO_COLADO = lambda k: M + 5 * k + H
INIT_MOODLE_S = 67.0

EXPANSOES = {
    'P': 'escola01', 'DOMINIO': 'escola.local', 'LDAP_BASE': 'dc=escola,dc=exemplo,dc=org',
    'IMG_NGINX': 'nginx:1.27.3-alpine', 'IMG_MARIADB': 'mariadb:11.4.4', 'IMG_MOODLE': 'bitnamilegacy/moodle:4.5.2',
    'IMG_PROM': 'prom/prometheus:v2.55.1', 'IMG_GRAFANA': 'grafana/grafana:11.3.1', 'IMG_BLACKBOX': 'prom/blackbox-exporter:v0.25.0',
    'IMG_LDAP': 'bitnamilegacy/openldap:2.6.9', 'IMG_RESTIC': 'restic/restic:0.17.3',
    'PORTA_HTTPS': '8443', 'PORTA_GRAFANA': '3000', 'PORTA_PROM': '9090', 'PORTA_LDAP': '1389', 'PORTA_LDAPS': '1636',
    'DB_ROOT_PW': 'x' * 12, 'DB_MOODLE_PW': 'x' * 12, 'MOODLE_ADMIN_PW': 'x' * 12, 'GRAFANA_PW': 'x' * 12,
    'LDAP_ADMIN_PW': 'x' * 12, 'LDAP_USER_PW': 'x' * 12, 'RESTIC_PW': 'x' * 12, 'NOME_ESCOLA': 'Escola Modelo',
}
PASSOS = [('imperativo_rede', 'passo_rede', 'Redes (3)'), ('imperativo_volumes', 'passo_volumes', 'Volumes (9)'),
          ('imperativo_ldap', 'passo_ldap', 'OpenLDAP, TLS e carga do diretório'), ('imperativo_banco_moodle', 'passo_banco_moodle', 'MariaDB e Moodle'),
          ('imperativo_proxy', 'passo_proxy', 'Proxy Nginx com TLS e cabeçalhos'), ('imperativo_monitoramento', 'passo_monitoramento', 'Prometheus, Blackbox e Grafana'),
          ('imperativo_backup', 'passo_backup', 'Cópia de segurança (restic)')]
# Laços do script que uma pessoa executaria repetindo o comando: volumes (9 criações) e carga LDAP (3 unidades).
MULTIPLICADOR = {'passo_volumes': 9}
CMD = re.compile(r'^(docker|openssl|chmod|mkdir|cp)\b')


def blocos(texto):
    linhas = texto.splitlines()
    out = {}
    nome = None
    for l in linhas:
        m = re.match(r'^(passo_\w+)\(\) \{', l)
        if m:
            nome = m.group(1); out[nome] = []; continue
        if nome and l.startswith('}'):
            nome = None; continue
        if nome:
            out[nome].append(l)
    return out


def expandir(cmd):
    def sub(m):
        nome = m.group(1) or m.group(2)
        return EXPANSOES.get(nome, 'x' * 8)
    cmd = re.sub(r'\$\{(\w+)(?:\[[@*]\])?\}|\$(\w+)', sub, cmd)
    return cmd.replace('"', '')


def analisar_passo(linhas):
    """Retorna (comandos, caracteres, arquivos_colados)."""
    corpo = []
    heredoc = None
    for l in linhas:
        s = l.strip()
        if heredoc:
            if s == heredoc:
                heredoc = None
            continue
        m = re.search(r"<<'?(\w+)'?$", s)
        if m:
            heredoc = m.group(1)
        corpo.append(l)
    unidas = []
    atual = ''
    for l in corpo:
        s = l.strip()
        if not s or s.startswith('#'):
            continue
        if s.endswith('\\'):
            atual += s[:-1] + ' '; continue
        unidas.append(atual + s); atual = ''
    comandos = chars = arquivos = 0
    for c in unidas:
        c = re.sub(r'^\(\s*|\s*\)$', '', c)
        c = re.sub(r'^(local|set -e)\b.*', '', c)
        if re.search(r'printf .*>\s*"?\$TMP', c) or re.search(r"awk .*>\s*\"?\$TMP", c) or re.search(r'cat > ', c) or re.search(r'^\{|^\}', c):
            continue
        if re.search(r'> "\$TMP/(estrutura\.ldif|prometheus\.yml|datasource\.yml)"', c):
            continue
        if CMD.match(c):
            comandos += 1
            chars += len(expandir(c))
    texto = '\n'.join(linhas)
    arquivos = len(re.findall(r'> "\$TMP/(?:estrutura\.ldif|prometheus\.yml|datasource\.yml|default\.conf|10-seguranca\.conf)"', texto)) + len(re.findall(r'cat > "\$TMP/10-seguranca\.conf"', texto))
    arquivos += len(re.findall(r'cp "\$RAIZ_DIR/terraform/modules/escola/templates/blackbox\.yml"', texto))
    return comandos, chars, arquivos


def tempos_maquina(dir_csv):
    if not dir_csv:
        return None
    vals = {}
    for f in glob.glob(os.path.join(dir_csv, '*_tempos.csv')):
        for r in csv.DictReader(open(f, encoding='utf8')):
            try:
                vals.setdefault(r['fase'], []).append(float(r['segundos']))
            except (KeyError, ValueError):
                pass
    return {k: statistics.median(v) for k, v in vals.items()} if vals else None


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--script', default=os.path.join(os.path.dirname(os.path.abspath(__file__)), 'baseline_imperativo.sh'))
    ap.add_argument('--tempos', help='pasta com *_tempos.csv do baseline imperativo (com cache)')
    ap.add_argument('--saida', default='klm_estimativa')
    a = ap.parse_args()
    bl = blocos(open(a.script, encoding='utf8').read())
    maq = tempos_maquina(a.tempos)
    linhas = []
    for fase, fn, rotulo in PASSOS:
        cmds, chars, arqs = analisar_passo(bl.get(fn, []))
        cmds *= MULTIPLICADOR.get(fn, 1); chars *= MULTIPLICADOR.get(fn, 1)
        t_maq = (maq or {}).get(fase)
        linhas.append(dict(fase=fase, rotulo=rotulo, comandos=cmds, caracteres=chars, arquivos_colados=arqs, maquina_s=t_maq))
    tot_cmd = sum(l['comandos'] for l in linhas); tot_chr = sum(l['caracteres'] for l in linhas); tot_arq = sum(l['arquivos_colados'] for l in linhas)
    smoke = (maq or {}).get('smoke_tests')
    # +1 passo de verificação (testes de fumaça digitados: 8 comandos curtos, ~60 caracteres cada, estimativa declarada)
    teste_cmds, teste_chars = 8, 8 * 60
    res = {}
    for nome, k in QUALIDADE_K.items():
        h = tot_cmd * M + tot_chr * k + tot_arq * ARQUIVO_COLADO(k) + teste_cmds * M + teste_chars * k
        m_total = sum(l['maquina_s'] or 0 for l in linhas) + (smoke or 0)
        m_sem_moodle = max(m_total - INIT_MOODLE_S, 0)
        res[nome] = dict(k=k, humano_s=h, inferior_s=h + m_sem_moodle, superior_s=h + m_total)
    out = dict(modelo='KLM (Card, Moran e Newell, 1980)', M=M, H=H, init_moodle_s=INIT_MOODLE_S, passos=linhas,
               total=dict(comandos=tot_cmd, caracteres=tot_chr, arquivos_colados=tot_arq, testes_cmds=teste_cmds, testes_chars=teste_chars,
                          maquina_total_s=sum(l['maquina_s'] or 0 for l in linhas) + (smoke or 0)),
               estimativas=res)
    json.dump(out, open(a.saida + '.json', 'w', encoding='utf8'), ensure_ascii=False, indent=1)
    md = ['# Estimativa KLM do tempo de um operador humano (não é medição)', '', '| Passo | Comandos | Caracteres | Arquivos colados | Máquina (mediana medida, s) |', '|---|---|---|---|---|']
    for l in linhas:
        md.append('| %s | %d | %d | %d | %s |' % (l['rotulo'], l['comandos'], l['caracteres'], l['arquivos_colados'], '%.1f' % l['maquina_s'] if l['maquina_s'] is not None else '-'))
    md += ['', '| Digitador | Humano (s) | Total, limite inferior (s) | Total, limite superior (s) |', '|---|---|---|---|']
    for nome, r in res.items():
        md.append('| %s | %.0f | %.0f | %.0f |' % (nome, r['humano_s'], r['inferior_s'], r['superior_s']))
    open(a.saida + '.md', 'w', encoding='utf8').write('\n'.join(md) + '\n')
    print('\n'.join(md))


if __name__ == '__main__':
    main()
