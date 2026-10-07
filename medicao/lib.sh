#!/usr/bin/env bash
# Funções comuns dos scripts de medição. Faça "source" deste arquivo.
# Requer bash 4+, awk, date com suporte a %N (GNU coreutils; Linux ou WSL).

export LC_ALL=C   # garante ponto decimal nos CSV

MEDICAO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAIZ_DIR="$(cd "$MEDICAO_DIR/.." && pwd)"
TF_DIR="$RAIZ_DIR/terraform"
ANSIBLE_DIR="$RAIZ_DIR/ansible"
LOG_DIR="$MEDICAO_DIR/logs"
TMP_DIR="$MEDICAO_DIR/.tmp"
# Use TF_BIN=tofu para OpenTofu.
TF_BIN="${TF_BIN:-terraform}"
# Python (no Windows/WSL pode ser "python3" ou "python").
PY="${PY:-$(command -v python3 || command -v python)}"
# Arquivo com a senha do Ansible Vault (opcional; senão o Ansible pedirá a senha).
VAULT_PASSWORD_FILE="${VAULT_PASSWORD_FILE:-}"

mkdir -p "$LOG_DIR" "$TMP_DIR"

cabecalho_csv() { # arquivo colunas...
    local arq="$1"; shift
    if [[ ! -s "$arq" ]]; then
        mkdir -p "$(dirname "$arq")"
        (IFS=,; echo "$*") > "$arq"
    fi
}

agora_utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# cronometrar CSV RUN_ID FASE COMANDO... -> acrescenta "run_id,fase,segundos,exit_code,timestamp"
cronometrar() {
    local csv="$1" run_id="$2" fase="$3"; shift 3
    local ts t0 t1 rc dur
    ts="$(agora_utc)"
    t0="$(date +%s.%N)"
    "$@" > "$LOG_DIR/${run_id}_${fase}.log" 2>&1
    rc=$?
    t1="$(date +%s.%N)"
    dur="$(awk -v a="$t0" -v b="$t1" 'BEGIN { printf "%.3f", b - a }')"
    printf '%s,%s,%s,%d,%s\n' "$run_id" "$fase" "$dur" "$rc" "$ts" >> "$csv"
    echo "  [$run_id] $fase: ${dur}s (exit $rc)"
    return "$rc"
}

# gerar_tfvars N HABILITAR_MOODLE(true|false) ARQUIVO -> JSON com N escolas
gerar_tfvars() {
    local n="$1" moodle="$2" arq="$3" i
    {
        echo '{'
        echo '  "escolas": {'
        for ((i = 0; i < n; i++)); do
            local sep=","
            (( i == n - 1 )) && sep=""
            printf '    "escola%02d": { "nome": "Escola Modelo %02d", "indice": %d, "habilitar_moodle": %s }%s\n' \
                "$((i + 1))" "$((i + 1))" "$i" "$moodle" "$sep"
        done
        echo '  }'
        echo '}'
    } > "$arq"
}

tf_init() {
    "$TF_BIN" -chdir="$TF_DIR" init -input=false
}

tf_apply() { # tfvars
    "$TF_BIN" -chdir="$TF_DIR" apply -auto-approve -input=false -var-file="$1"
}

tf_destroy() { # tfvars
    "$TF_BIN" -chdir="$TF_DIR" destroy -auto-approve -input=false -var-file="$1"
}

# ansible_escola PLAYBOOK PREFIXO INDICE MOODLE(true|false)
ansible_escola() {
    local playbook="$1" prefixo="$2" indice="$3" moodle="$4"
    local args=()
    [[ -n "$VAULT_PASSWORD_FILE" ]] && args+=(--vault-password-file "$VAULT_PASSWORD_FILE")
    # ANSIBLE_TAGS limita os papéis executados (ex.: "proxy" no perfil leve).
    [[ -n "${ANSIBLE_TAGS:-}" ]] && args+=(--tags "$ANSIBLE_TAGS")
    (cd "$ANSIBLE_DIR" && ansible-playbook "$playbook" "${args[@]}" \
        -e "escola_prefixo=$prefixo" -e "escola_indice=$indice" -e "escola_habilitar_moodle=$moodle")
}

# smoke_escola PREFIXO INDICE MOODLE(1|0) [PERFIL]
smoke_escola() {
    SMOKE_PERFIL="${4:-completo}" ESCOLA_PREFIXO="$1" PORTA_HTTPS="$((${PORTA_BASE_HTTPS:-8443} + $2))" \
        PORTA_GRAFANA="$((${PORTA_BASE_GRAFANA:-3000} + $2))" \
        PORTA_PROMETHEUS="$((${PORTA_BASE_PROMETHEUS:-9090} + $2))" \
        SMOKE_MOODLE="$3" "$MEDICAO_DIR/smoke_tests.sh"
}
