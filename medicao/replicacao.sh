#!/usr/bin/env bash
# Mede o esforço de replicar N escolas (N = 1, 3, 5 por padrão).
# Registra tempo por fase, número de recursos no state e linhas do arquivo de
# variáveis (medida de esforço marginal de configuração).
# Uso: ./replicacao.sh [-l "1 3 5"] [-r 1] [-o resultados/replicacao.csv] [-m]
#   -l  lista de tamanhos    -r  repetições por tamanho
#   -m  sem Moodle/MariaDB (recomendado se a máquina tiver pouca memória)
set -u
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

LISTA="1 3 5"
REPETICOES=1
SAIDA="$MEDICAO_DIR/resultados/replicacao.csv"
MOODLE=true
while getopts "l:r:o:mh" opt; do
    case "$opt" in
        l) LISTA="$OPTARG" ;;
        r) REPETICOES="$OPTARG" ;;
        o) SAIDA="$OPTARG" ;;
        m) MOODLE=false ;;
        *) sed -n '2,8p' "$0"; exit 2 ;;
    esac
done
SMOKE_MOODLE=1; [[ "$MOODLE" == "false" ]] && SMOKE_MOODLE=0

cabecalho_csv "$SAIDA" n_escolas repeticao fase segundos exit_code timestamp n_recursos_state linhas_tfvars
tf_init > "$LOG_DIR/setup_init.log" 2>&1 || { echo "Falha no init."; exit 1; }

# registrar N REP FASE COMANDO... : usa cronometrar num CSV temporário e reformata a linha.
registrar() {
    local n="$1" rep="$2" fase="$3"; shift 3
    local tmp="$TMP_DIR/linha.csv" recursos
    : > "$tmp"
    cronometrar "$tmp" "n${n}_r${rep}" "$fase" "$@"
    local rc=$?
    IFS=, read -r _ f seg cod ts < "$tmp"
    recursos="$("$TF_BIN" -chdir="$TF_DIR" state list 2> /dev/null | wc -l | tr -d ' ')"
    printf '%s,%s,%s,%s,%s,%s,%s,%s\n' "$n" "$rep" "$f" "$seg" "$cod" "$ts" "$recursos" "$LINHAS" >> "$SAIDA"
    return "$rc"
}

# Cada função abaixo percorre as N escolas (escola01 a escolaNN, índices 0 a N-1).
config_todas() {
    local n="$1" i rc=0
    for ((i = 0; i < n; i++)); do
        ansible_escola site.yml "$(printf 'escola%02d' "$((i + 1))")" "$i" "$MOODLE" || rc=1
    done
    return "$rc"
}
smoke_todas() {
    local n="$1" i rc=0
    for ((i = 0; i < n; i++)); do
        smoke_escola "$(printf 'escola%02d' "$((i + 1))")" "$i" "$SMOKE_MOODLE" || rc=1
    done
    return "$rc"
}
teardown_todas() {
    local n="$1" i rc=0
    for ((i = 0; i < n; i++)); do
        ansible_escola teardown.yml "$(printf 'escola%02d' "$((i + 1))")" "$i" "$MOODLE" || rc=1
    done
    return "$rc"
}

for n in $LISTA; do
    for ((rep = 1; rep <= REPETICOES; rep++)); do
        echo "== N=$n escolas, repetição $rep"
        TFVARS="$TMP_DIR/replicacao_${n}.tfvars.json"
        gerar_tfvars "$n" "$MOODLE" "$TFVARS"
        LINHAS="$(wc -l < "$TFVARS" | tr -d ' ')"
        registrar "$n" "$rep" terraform_apply tf_apply "$TFVARS"
        registrar "$n" "$rep" ansible_playbook config_todas "$n"
        registrar "$n" "$rep" smoke_tests smoke_todas "$n"
        registrar "$n" "$rep" teardown_ansible teardown_todas "$n"
        registrar "$n" "$rep" terraform_destroy tf_destroy "$TFVARS"
    done
done
echo "Concluído. CSV: $SAIDA"
