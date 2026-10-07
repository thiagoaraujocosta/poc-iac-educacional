#!/usr/bin/env bash
# Executa R repetições de um cenário (arquivo .tfvars.json de cenarios/):
#   apply -> configuração (Ansible) -> testes de fumaça -> idempotência -> consistência -> teardown -> destroy
# Grava três CSV em resultados/ (ou -d):
#   <cenario>_tempos.csv        run_id,cenario,porte,n,fase,segundos,exit_code,falhas_teste,timestamp
#   <cenario>_idempotencia.csv  run_id,cenario,porte,n,plan_exit_code,recursos_a_alterar,
#                               apply2_adicionados,apply2_alterados,apply2_destruidos
#   <cenario>_consistencia.csv  run_id,cenario,porte,n,hash_estado_tf,hash_docker
# Fases: terraform_apply, ansible_playbook, smoke_tests, terraform_plan_idempotencia,
#        terraform_apply_idempotencia, teardown_ansible, terraform_destroy.
# A fase terraform_plan_idempotencia registra exit_code 0 quando o plan executou (0 ou 2); o código real
# do "plan -detailed-exitcode" (0 = sem mudanças, 2 = há mudanças) fica no CSV de idempotência.
# Uso: ./executar_cenario.sh -c ../cenarios/leve_n05.tfvars.json [-r 10] [-d resultados]
# Variáveis: TF_BIN=tofu, VAULT_PASSWORD_FILE, SMOKE_TIMEOUT, PY, PRE_REP_CMD (comando antes de cada repetição).
# No perfil leve o Ansible roda apenas o papel do proxy (tag "proxy").
set -u
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

REPETICOES=10
SAIDA_DIR="$MEDICAO_DIR/resultados"
CENARIO=""
while getopts "c:r:d:h" opt; do
    case "$opt" in
        c) CENARIO="$OPTARG" ;;
        r) REPETICOES="$OPTARG" ;;
        d) SAIDA_DIR="$OPTARG" ;;
        *) sed -n '2,17p' "$0"; exit 2 ;;
    esac
done
[[ -f "$CENARIO" ]] || { echo "Informe o cenário com -c (arquivo .tfvars.json)."; exit 2; }
[[ "$REPETICOES" =~ ^[0-9]+$ && "$REPETICOES" -ge 1 ]] || { echo "Repetições inválidas."; exit 2; }
[[ -n "$PY" ]] || { echo "Python não encontrado (defina PY)."; exit 2; }

TFVARS="$(cd "$(dirname "$CENARIO")" && pwd)/$(basename "$CENARIO")"
UTIL="$MEDICAO_DIR/utils_cenario.py"
read -r NOME PORTE N < <("$PY" "$UTIL" resumo "$TFVARS")
mapfile -t ESCOLAS < <("$PY" "$UTIL" escolas "$TFVARS")
read -r _ _ PERFIL _ <<< "${ESCOLAS[0]}"
if [[ "$PERFIL" == "leve" ]]; then export ANSIBLE_TAGS="proxy"; fi

TEMPOS="$SAIDA_DIR/${NOME}_tempos.csv"
IDEM="$SAIDA_DIR/${NOME}_idempotencia.csv"
CONS="$SAIDA_DIR/${NOME}_consistencia.csv"
cabecalho_csv "$TEMPOS" run_id cenario porte n fase segundos exit_code falhas_teste timestamp
cabecalho_csv "$IDEM" run_id cenario porte n plan_exit_code recursos_a_alterar apply2_adicionados apply2_alterados apply2_destruidos
cabecalho_csv "$CONS" run_id cenario porte n hash_estado_tf hash_docker

# cron_cen RUN_ID FASE COMANDO... : cronometra, grava em TEMPOS e devolve o código de saída do comando.
cron_cen() {
    local run_id="$1" fase="$2"; shift 2
    local log="$LOG_DIR/${NOME}_${run_id}_${fase}.log" ts t0 t1 rc dur falhas=""
    ts="$(agora_utc)"; t0="$(date +%s.%N)"
    "$@" > "$log" 2>&1
    rc=$?
    t1="$(date +%s.%N)"
    dur="$(awk -v a="$t0" -v b="$t1" 'BEGIN { printf "%.3f", b - a }')"
    if [[ "$fase" == "smoke_tests" ]]; then falhas="$(grep -c '^FALHA' "$log" || true)"; fi
    printf '%s,%s,%s,%s,%s,%s,%d,%s,%s\n' "$run_id" "$NOME" "$PORTE" "$N" "$fase" "$dur" "$rc" "$falhas" "$ts" >> "$TEMPOS"
    echo "  [$run_id] $fase: ${dur}s (exit $rc${falhas:+, falhas de teste: $falhas})"
    return "$rc"
}

por_escola() { # COMANDO... : executa "COMANDO prefixo indice perfil moodle" para cada escola; falha se alguma falhar
    local rc=0 linha p i pf m
    for linha in "${ESCOLAS[@]}"; do
        read -r p i pf m <<< "$linha"
        "$@" "$p" "$i" "$pf" "$m" || rc=1
    done
    return "$rc"
}
cfg_uma()      { ansible_escola site.yml "$1" "$2" "$([[ "$4" == 1 ]] && echo true || echo false)"; }
teardown_uma() { ansible_escola teardown.yml "$1" "$2" "$([[ "$4" == 1 ]] && echo true || echo false)"; }
smoke_uma()    { smoke_escola "$1" "$2" "$4" "$3"; }
cfg_todas()      { por_escola cfg_uma; }
teardown_todas() { por_escola teardown_uma; }
smoke_todas()    { por_escola smoke_uma; }

PLANO_BIN="$TMP_DIR/${NOME}.plan"
PLANO_JSON="$TMP_DIR/${NOME}_plano.json"
plan_idem() {
    local rc=0
    "$TF_BIN" -chdir="$TF_DIR" plan -detailed-exitcode -input=false -var-file="$TFVARS" -out="$PLANO_BIN" || rc=$?
    echo "$rc" > "$TMP_DIR/${NOME}_plan_rc"
    [[ "$rc" -eq 0 || "$rc" -eq 2 ]] || return "$rc"
    "$TF_BIN" -chdir="$TF_DIR" show -json "$PLANO_BIN" > "$PLANO_JSON"
}

nomes_docker() { # TIPO(container|network|volume)
    case "$1" in
        container) docker ps -a --format '{{.Names}}' ;;
        network) docker network ls --format '{{.Name}}' ;;
        volume) docker volume ls --format '{{.Name}}' ;;
    esac | grep -E '^escola[0-9]+-' || true
}
inspecionar() { # TIPO ARQUIVO
    local nomes
    nomes="$(nomes_docker "$1")"
    if [[ -z "$nomes" ]]; then echo '[]' > "$2"; return; fi
    # shellcheck disable=SC2086
    docker "$1" inspect $nomes > "$2" 2> /dev/null || echo '[]' > "$2"
}
coletar_hashes() { # RUN_ID
    local est="$TMP_DIR/${NOME}_estado.json" c r v h_tf h_dk
    "$TF_BIN" -chdir="$TF_DIR" show -json > "$est" 2> /dev/null
    h_tf="$("$PY" "$UTIL" hash-tf "$est")"
    c="$TMP_DIR/${NOME}_cont.json"; r="$TMP_DIR/${NOME}_redes.json"; v="$TMP_DIR/${NOME}_vols.json"
    inspecionar container "$c"; inspecionar network "$r"; inspecionar volume "$v"
    h_dk="$("$PY" "$UTIL" hash-docker "$c" "$r" "$v")"
    printf '%s,%s,%s,%s,%s,%s\n' "$1" "$NOME" "$PORTE" "$N" "$h_tf" "$h_dk" >> "$CONS"
    echo "  [$1] hash estado TF: ${h_tf:0:12}  hash docker: ${h_dk:0:12}"
}

registrar_idempotencia() { # RUN_ID
    local plan_rc alterar="" add="" alt="" des="" resumo
    plan_rc="$(cat "$TMP_DIR/${NOME}_plan_rc" 2> /dev/null || echo "")"
    [[ -s "$PLANO_JSON" && ( "$plan_rc" == 0 || "$plan_rc" == 2 ) ]] && alterar="$("$PY" "$UTIL" contar-mudancas "$PLANO_JSON")"
    resumo="$(grep -o 'Resources: [0-9]* added, [0-9]* changed, [0-9]* destroyed' \
        "$LOG_DIR/${NOME}_$1_terraform_apply_idempotencia.log" 2> /dev/null | tail -n 1)"
    if [[ -n "$resumo" ]]; then
        read -r _ add _ alt _ des _ <<< "$resumo"
    fi
    printf '%s,%s,%s,%s,%s,%s,%s,%s,%s\n' "$1" "$NOME" "$PORTE" "$N" "$plan_rc" "$alterar" "$add" "$alt" "$des" >> "$IDEM"
    echo "  [$1] plan -detailed-exitcode: ${plan_rc:-?}; recursos a alterar: ${alterar:-?}; segundo apply: +${add:-?} ~${alt:-?} -${des:-?}"
}

echo "Cenário $NOME (porte $PORTE, N=$N, perfil $PERFIL), $REPETICOES repetições"
echo "Inicializando o provedor (fora da medição)..."
tf_init > "$LOG_DIR/setup_init.log" 2>&1 || { echo "Falha no init. Veja $LOG_DIR/setup_init.log"; exit 1; }

for ((i = 1; i <= REPETICOES; i++)); do
    run_id="$(printf 'run_%02d' "$i")"
    echo "== Repetição $i de $REPETICOES ($run_id)"
    rm -f "$PLANO_JSON" "$PLANO_BIN" "$TMP_DIR/${NOME}_plan_rc"
    # Gancho opcional (ex.: PRE_REP_CMD="docker system prune -af" para medir sem cache de imagens).
    if [[ -n "${PRE_REP_CMD:-}" ]]; then eval "$PRE_REP_CMD" > "$LOG_DIR/${NOME}_${run_id}_pre_rep.log" 2>&1 || true; fi
    cron_cen "$run_id" terraform_apply tf_apply "$TFVARS"
    apply_rc=$?
    if [[ "$apply_rc" -eq 0 ]]; then
        cron_cen "$run_id" ansible_playbook cfg_todas
        cron_cen "$run_id" smoke_tests smoke_todas
        cron_cen "$run_id" terraform_plan_idempotencia plan_idem
        cron_cen "$run_id" terraform_apply_idempotencia tf_apply "$TFVARS"
        registrar_idempotencia "$run_id"
        coletar_hashes "$run_id"
    else
        echo "  apply falhou: configuração, testes, idempotência e consistência não executados nesta repetição."
    fi
    # Limpeza obrigatória mesmo após falha, para não contaminar a próxima repetição.
    cron_cen "$run_id" teardown_ansible teardown_todas
    cron_cen "$run_id" terraform_destroy tf_destroy "$TFVARS"
done
echo "Concluído. CSV: $TEMPOS, $IDEM, $CONS (logs em $LOG_DIR)"
