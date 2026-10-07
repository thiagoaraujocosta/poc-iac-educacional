#!/usr/bin/env bash
# Mede N repetições do fluxo IaC completo, com destroy entre elas.
# Fases cronometradas: terraform_apply, ansible_playbook, smoke_tests,
# teardown_ansible, terraform_destroy.
# Uso: ./executar_medicao.sh [-n 10] [-o resultados/medicao_iac.csv] [-m]
#   -n  número de repetições (padrão 10)
#   -o  CSV de saída
#   -m  sem Moodle/MariaDB (usa menos memória; altera o que está sendo medido)
# Variáveis úteis: TF_BIN=tofu, VAULT_PASSWORD_FILE, SMOKE_TIMEOUT.
set -u
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

REPETICOES=10
SAIDA="$MEDICAO_DIR/resultados/medicao_iac.csv"
MOODLE=true
while getopts "n:o:mh" opt; do
    case "$opt" in
        n) REPETICOES="$OPTARG" ;;
        o) SAIDA="$OPTARG" ;;
        m) MOODLE=false ;;
        *) sed -n '2,10p' "$0"; exit 2 ;;
    esac
done
[[ "$REPETICOES" =~ ^[0-9]+$ && "$REPETICOES" -ge 1 ]] || { echo "Repetições inválidas."; exit 2; }

TFVARS="$TMP_DIR/medicao.tfvars.json"
gerar_tfvars 1 "$MOODLE" "$TFVARS"
SMOKE_MOODLE=1; [[ "$MOODLE" == "false" ]] && SMOKE_MOODLE=0

cabecalho_csv "$SAIDA" run_id fase segundos exit_code timestamp
echo "Inicializando o provedor (fora da medição)..."
tf_init > "$LOG_DIR/setup_init.log" 2>&1 || { echo "Falha no init. Veja $LOG_DIR/setup_init.log"; exit 1; }

for ((i = 1; i <= REPETICOES; i++)); do
    run_id="$(printf 'run_%02d' "$i")"
    echo "== Repetição $i de $REPETICOES ($run_id)"
    cronometrar "$SAIDA" "$run_id" terraform_apply tf_apply "$TFVARS"
    cronometrar "$SAIDA" "$run_id" ansible_playbook ansible_escola site.yml escola01 0 "$MOODLE"
    cronometrar "$SAIDA" "$run_id" smoke_tests smoke_escola escola01 0 "$SMOKE_MOODLE"
    # Limpeza obrigatória mesmo se uma fase falhou, para não contaminar a próxima repetição.
    cronometrar "$SAIDA" "$run_id" teardown_ansible ansible_escola teardown.yml escola01 0 "$MOODLE"
    cronometrar "$SAIDA" "$run_id" terraform_destroy tf_destroy "$TFVARS"
done
echo "Concluído. CSV: $SAIDA (logs em $LOG_DIR)"
