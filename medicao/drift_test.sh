#!/usr/bin/env bash
# Teste de deriva (drift): altera manualmente o ambiente e verifica se
# "plan -detailed-exitcode" detecta a diferença (código de saída 2).
# São 10 alterações-padrão, repetidas R vezes (padrão 10), o que dá 100 verificações.
# Pré-requisito: nenhum (o script aplica a escola01, mede e destrói ao final de cada repetição).
# Os resultados NÃO são presumidos: o script apenas registra o observado. Alterações feitas
# DENTRO de um contêiner (conteúdo de arquivos) não são vistas pelo plan; isso é registrado como observado.
# Uso: ./drift_test.sh [-r 10] [-o resultados/drift.csv]
set -u
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SAIDA="$MEDICAO_DIR/resultados/drift.csv"
REPETICOES=10
while getopts "r:o:h" opt; do
    case "$opt" in
        r) REPETICOES="$OPTARG" ;;
        o) SAIDA="$OPTARG" ;;
        *) sed -n '2,9p' "$0"; exit 2 ;;
    esac
done

P="escola01"
TFVARS="$TMP_DIR/drift.tfvars.json"
gerar_tfvars 1 true "$TFVARS"
cabecalho_csv "$SAIDA" repeticao cenario descricao plan_exit_code detectado seg_deteccao seg_remediacao apply_exit_code plan_pos_exit_code timestamp

plan() { "$TF_BIN" -chdir="$TF_DIR" plan -detailed-exitcode -input=false -var-file="$TFVARS" > "$LOG_DIR/drift_plan.log" 2>&1; }

tf_init > "$LOG_DIR/setup_init.log" 2>&1 || { echo "Falha no init."; exit 1; }

cenario() { # repeticao id descricao comando...
    local rep="$1" id="$2" desc="$3"; shift 3
    local ts t0 t1 t2 plan_rc=0 apply_rc=0 pos_rc=0 det
    ts="$(agora_utc)"
    echo "== [$rep] Cenário $id: $desc"
    "$@" > "$LOG_DIR/drift_${rep}_${id}_alteracao.log" 2>&1 || echo "  (a alteração manual retornou erro; veja o log)"
    t0="$(date +%s.%N)"; plan || plan_rc=$?; t1="$(date +%s.%N)"
    det="nao"; [[ "$plan_rc" -eq 2 ]] && det="sim"
    tf_apply "$TFVARS" > "$LOG_DIR/drift_${rep}_${id}_apply.log" 2>&1 || apply_rc=$?; t2="$(date +%s.%N)"
    plan || pos_rc=$?
    printf '%s,%s,"%s",%s,%s,%s,%s,%s,%s,%s\n' "$rep" "$id" "$desc" "$plan_rc" "$det" \
        "$(awk -v a="$t0" -v b="$t1" 'BEGIN { printf "%.3f", b - a }')" \
        "$(awk -v a="$t1" -v b="$t2" 'BEGIN { printf "%.3f", b - a }')" \
        "$apply_rc" "$pos_rc" "$ts" >> "$SAIDA"
    echo "  plan=$plan_rc detectado=$det apply=$apply_rc plan_pos=$pos_rc"
}

alterar_memoria_mariadb() { docker update --memory 512m --memory-swap 512m "${P}-mariadb"; }
remover_mariadb_e_volume() {
    docker rm -f "${P}-mariadb" && docker volume ls --format '{{.Name}}' | grep "^${P}-" | grep -i "banco\|mariadb\|db" | xargs -r docker volume rm
}
conectar_grafana_rede_extra() { docker network create "${P}-extra" && docker network connect "${P}-extra" "${P}-grafana"; }
limpar_extras() { docker network disconnect "${P}-extra" "${P}-grafana" 2> /dev/null; docker network rm "${P}-extra" 2> /dev/null; docker unpause "${P}-prometheus" 2> /dev/null; return 0; }

for ((rep = 1; rep <= REPETICOES; rep++)); do
    echo "##### Repetição $rep de $REPETICOES: aplicando o ambiente"
    if ! tf_apply "$TFVARS" > "$LOG_DIR/drift_${rep}_apply_inicial.log" 2>&1; then
        echo "apply inicial falhou (veja o log); repetição ignorada."
        tf_destroy "$TFVARS" > /dev/null 2>&1
        continue
    fi
    base_rc=0; plan || base_rc=$?
    if [[ "$base_rc" -ne 0 ]]; then
        echo "O plan inicial retornou $base_rc (esperado 0); repetição ignorada."
        tf_destroy "$TFVARS" > /dev/null 2>&1
        continue
    fi
    cenario "$rep" parar_proxy "Parar o contêiner do proxy" docker stop "${P}-nginx"
    cenario "$rep" remover_proxy "Remover o contêiner do proxy" docker rm -f "${P}-nginx"
    cenario "$rep" reinicio_grafana "Alterar a política de reinício do Grafana" docker update --restart=no "${P}-grafana"
    cenario "$rep" memoria_mariadb "Alterar o limite de memória do MariaDB" alterar_memoria_mariadb
    cenario "$rep" desconectar_rede "Desconectar o proxy da rede pedagógica" docker network disconnect "${P}-pedagogica" "${P}-nginx"
    cenario "$rep" remover_mariadb_volume "Remover o contêiner do MariaDB e o volume de dados" remover_mariadb_e_volume
    cenario "$rep" renomear_prometheus "Renomear o contêiner do Prometheus" docker rename "${P}-prometheus" "${P}-prometheus-renomeado"
    cenario "$rep" config_interna_nginx "Editar a configuração do Nginx dentro do contêiner" \
        docker exec "${P}-nginx" sh -c 'echo "# alteracao manual" >> /etc/nginx/conf.d/default.conf'
    cenario "$rep" rede_extra_grafana "Conectar o Grafana a uma rede extra" conectar_grafana_rede_extra
    limpar_extras
    cenario "$rep" pausar_prometheus "Pausar o contêiner do Prometheus" docker pause "${P}-prometheus"
    limpar_extras
    tf_destroy "$TFVARS" > "$LOG_DIR/drift_${rep}_destroy.log" 2>&1 || echo "  (destroy retornou erro; veja o log)"
done
echo "Concluído. CSV: $SAIDA"
