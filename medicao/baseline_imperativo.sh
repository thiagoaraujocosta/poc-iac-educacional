#!/usr/bin/env bash
# Baseline imperativo: provisiona o MESMO ambiente de uma escola (perfil completo) que o OpenTofu + Ansible,
# mas apenas com comandos da CLI do Docker e do OpenSSL, em sequência, sem estado, sem plano e sem IaC.
# Representa o "procedimento por scripts" que uma equipe escreveria sem IaC. NÃO mede o tempo nem os
# erros de uma pessoa digitando comandos: para isso há o roteiro manual (PROTOCOLO_BASELINE_MANUAL.md).
# Reproduz as mesmas imagens, redes (/24), volumes, variáveis, limites de memória/CPU, TLS, cabeçalhos de
# segurança, LDAP, monitoramento e cópia de segurança do módulo terraform/modules/escola e dos papéis Ansible.
# Uso: ./baseline_imperativo.sh -c ../cenarios/completo_pequeno_n01.tfvars.json [-r 10] [-d resultados]
# Grava <cenario>_tempos.csv no mesmo formato de executar_cenario.sh (cenário renomeado com prefixo imperativo_).
# Fases: imperativo_rede, imperativo_volumes, imperativo_ldap, imperativo_banco_moodle, imperativo_proxy,
#        imperativo_monitoramento, imperativo_backup, smoke_tests, imperativo_destroy.
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
        *) sed -n '2,13p' "$0"; exit 2 ;;
    esac
done
[[ -f "$CENARIO" ]] || { echo "Informe o cenário com -c (arquivo .tfvars.json)."; exit 2; }
[[ -n "$PY" ]] || { echo "Python não encontrado."; exit 2; }

# Parâmetros da escola 01 do cenário (memória, CPUs, alvos de monitoramento, modo local-first, porte).
eval "$("$PY" - "$CENARIO" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1], encoding='utf8'))
e = d['escolas']
k = sorted(e)[0]
v = e[k]
def sh(x): return '' if x is None else str(x)
print('NOME_ESCOLA_JSON=%r' % sh(v.get('nome')))
print('PORTE=%r' % sh(v.get('porte') or 'pequeno'))
print('MEM_MB=%r' % sh(v.get('memoria_mb')))
print('CPUS=%r' % sh(v.get('cpus')))
print('ALVOS=%r' % sh(v.get('alvos_monitoramento') if v.get('alvos_monitoramento') is not None else 0))
print('LOCAL_FIRST=%r' % ('1' if v.get('modo_local_first') else '0'))
PYEOF
)"
NOME="imperativo_$(basename "$CENARIO" .tfvars.json)"
P="escola01"
DOMINIO="escola.local"
PORTA_HTTPS=8443; PORTA_GRAFANA=3000; PORTA_PROM=9090; PORTA_LDAP=1389; PORTA_LDAPS=1636
IMG_NGINX="nginx:1.27.3-alpine"; IMG_MARIADB="mariadb:11.4.4"; IMG_MOODLE="bitnamilegacy/moodle:4.5.2"
IMG_PROM="prom/prometheus:v2.55.1"; IMG_GRAFANA="grafana/grafana:11.3.1"; IMG_BLACKBOX="prom/blackbox-exporter:v0.25.0"
IMG_LDAP="bitnamilegacy/openldap:2.6.9"; IMG_RESTIC="restic/restic:0.17.3"
LDAP_BASE="dc=escola,dc=exemplo,dc=org"
TMP="$TMP_DIR/imperativo"; mkdir -p "$TMP" "$SAIDA_DIR"
TEMPOS="$SAIDA_DIR/${NOME}_tempos.csv"
cabecalho_csv "$TEMPOS" run_id cenario porte n fase segundos exit_code falhas_teste timestamp

cron_imp() { # RUN_ID FASE COMANDO...
    local run_id="$1" fase="$2"; shift 2
    local log="$LOG_DIR/${NOME}_${run_id}_${fase}.log" ts t0 t1 rc dur falhas=""
    ts="$(agora_utc)"; t0="$(date +%s.%N)"
    ( "$@" ) > "$log" 2>&1
    rc=$?
    t1="$(date +%s.%N)"
    dur="$(awk -v a="$t0" -v b="$t1" 'BEGIN { printf "%.3f", b - a }')"
    if [[ "$fase" == "smoke_tests" ]]; then falhas="$(grep -c '^FALHA' "$log" || true)"; fi
    printf '%s,%s,%s,1,%s,%s,%d,%s,%s\n' "$run_id" "$NOME" "$PORTE" "$fase" "$dur" "$rc" "$falhas" "$ts" >> "$TEMPOS"
    echo "  [$run_id] $fase: ${dur}s (exit $rc${falhas:+, falhas de teste: $falhas})"
    return "$rc"
}

senha() { openssl rand -hex 12; }

# ------------------------------------------------------------------ passos
passo_rede() {
    set -e
    local interna=()
    [[ "$LOCAL_FIRST" == "1" ]] && interna=(--internal)
    docker network create --driver bridge --subnet 10.64.1.0/24 "${P}-admin"
    docker network create --driver bridge --subnet 10.64.2.0/24 "${P}-pedagogica"
    docker network create --driver bridge --subnet 10.64.3.0/24 "${interna[@]}" "${P}-servidores"
}

passo_volumes() {
    set -e
    for v in mariadb-dados dumps moodle-app moodle-dados prometheus-dados grafana-dados ldap-dados ldap-certs backup-repo; do
        docker volume create "${P}-$v"
    done
}

passo_ldap() {
    set -e
    # Certificado autoassinado para o LDAPS (mesmo papel do tls_cert do Ansible)
    openssl req -x509 -newkey rsa:2048 -nodes -days 365 -keyout "$TMP/ldap.key" -out "$TMP/ldap.crt" \
        -subj "/CN=${P}-ldap" -addext "subjectAltName=DNS:${P}-ldap,DNS:localhost,IP:127.0.0.1"
    cp "$TMP/ldap.crt" "$TMP/ldap-ca.crt"
    docker create --name "${P}-ldap" --restart unless-stopped --network "${P}-servidores" \
        -e LDAP_ROOT="$LDAP_BASE" -e LDAP_ADMIN_USERNAME=admin -e LDAP_ADMIN_PASSWORD="$LDAP_ADMIN_PW" \
        -e LDAP_PORT_NUMBER=1389 -e LDAP_LDAPS_PORT_NUMBER=1636 -e LDAP_ENABLE_TLS=yes \
        -e LDAP_TLS_CERT_FILE=/opt/bitnami/openldap/certs/tls.crt -e LDAP_TLS_KEY_FILE=/opt/bitnami/openldap/certs/tls.key \
        -e LDAP_TLS_CA_FILE=/opt/bitnami/openldap/certs/ca.crt -e LDAP_TLS_VERIFY_CLIENT=never \
        -v "${P}-ldap-dados:/bitnami/openldap" -v "${P}-ldap-certs:/opt/bitnami/openldap/certs" \
        -p "127.0.0.1:${PORTA_LDAP}:1389" -p "127.0.0.1:${PORTA_LDAPS}:1636" "$IMG_LDAP"
    docker cp "$TMP/ldap.crt" "${P}-ldap:/opt/bitnami/openldap/certs/tls.crt"
    docker cp "$TMP/ldap.key" "${P}-ldap:/opt/bitnami/openldap/certs/tls.key"
    docker cp "$TMP/ldap-ca.crt" "${P}-ldap:/opt/bitnami/openldap/certs/ca.crt"
    docker start "${P}-ldap"
    for i in $(seq 1 60); do
        docker exec "${P}-ldap" /opt/bitnami/openldap/bin/ldapsearch -x -H ldap://localhost:1389 -b "$LDAP_BASE" -s base dn > /dev/null 2>&1 && break
        sleep 2
    done
    {
        for u in professores alunos administrativo; do printf 'dn: ou=%s,%s\nobjectClass: organizationalUnit\nou: %s\n\n' "$u" "$LDAP_BASE" "$u"; done
        printf 'dn: ou=grupos,%s\nobjectClass: organizationalUnit\nou: grupos\n\n' "$LDAP_BASE"
        g=10001
        for c in professores alunos administrativo; do
            case "$c" in professores) m=prof.exemplo ;; alunos) m=aluno.exemplo ;; *) m=adm.exemplo ;; esac
            printf 'dn: cn=%s,ou=grupos,%s\nobjectClass: posixGroup\ncn: %s\ngidNumber: %s\nmemberUid: %s\n\n' "$c" "$LDAP_BASE" "$c" "$g" "$m"; g=$((g + 1))
        done
        printf 'dn: uid=prof.exemplo,ou=professores,%s\nobjectClass: inetOrgPerson\nuid: prof.exemplo\ncn: Professora Exemplo\nsn: Exemplo\ngivenName: Professora\nmail: prof.exemplo@exemplo.invalid\nuserPassword: %s\n\n' "$LDAP_BASE" "$LDAP_USER_PW"
        printf 'dn: uid=aluno.exemplo,ou=alunos,%s\nobjectClass: inetOrgPerson\nuid: aluno.exemplo\ncn: Aluno Exemplo\nsn: Exemplo\ngivenName: Aluno\nmail: aluno.exemplo@exemplo.invalid\nuserPassword: %s\n\n' "$LDAP_BASE" "$LDAP_USER_PW"
        printf 'dn: uid=adm.exemplo,ou=administrativo,%s\nobjectClass: inetOrgPerson\nuid: adm.exemplo\ncn: Auxiliar Exemplo\nsn: Exemplo\ngivenName: Auxiliar\nmail: adm.exemplo@exemplo.invalid\nuserPassword: %s\n\n' "$LDAP_BASE" "$LDAP_USER_PW"
    } > "$TMP/estrutura.ldif"
    chmod 644 "$TMP/estrutura.ldif"
    docker cp "$TMP/estrutura.ldif" "${P}-ldap:/tmp/estrutura.ldif"
    docker exec -u 0 "${P}-ldap" chmod 644 /tmp/estrutura.ldif
    docker exec "${P}-ldap" sh -c "/opt/bitnami/openldap/bin/ldapadd -c -x -H ldap://localhost:1389 -D 'cn=admin,${LDAP_BASE}' -w \"\$LDAP_ADMIN_PASSWORD\" -f /tmp/estrutura.ldif" || [[ $? -eq 68 ]]
}

passo_banco_moodle() {
    set -e
    docker run -d --name "${P}-mariadb" --restart unless-stopped --network "${P}-servidores" \
        -e MARIADB_ROOT_PASSWORD="$DB_ROOT_PW" -e MARIADB_DATABASE=moodle -e MARIADB_USER=moodle -e MARIADB_PASSWORD="$DB_MOODLE_PW" \
        -v "${P}-mariadb-dados:/var/lib/mysql" -v "${P}-dumps:/dumps" \
        --health-cmd "healthcheck.sh --connect --innodb_initialized" --health-interval 10s --health-timeout 5s --health-retries 12 --health-start-period 20s \
        "$IMG_MARIADB" --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci --innodb-file-per-table=1
    for i in $(seq 1 60); do
        [[ "$(docker inspect -f '{{.State.Health.Status}}' "${P}-mariadb")" == "healthy" ]] && break
        sleep 3
    done
    local limites=()
    [[ -n "$MEM_MB" ]] && limites+=(--memory "${MEM_MB}m" --memory-swap "${MEM_MB}m")
    [[ -n "$CPUS" ]] && limites+=(--cpu-shares "$("$PY" -c "import math,sys; print(math.floor(float(sys.argv[1])*1024))" "$CPUS")")
    docker run -d --name "${P}-moodle" --restart unless-stopped --network "${P}-servidores" "${limites[@]}" \
        -e MOODLE_DATABASE_TYPE=mariadb -e MOODLE_DATABASE_HOST="${P}-mariadb" -e MOODLE_DATABASE_PORT_NUMBER=3306 \
        -e MOODLE_DATABASE_NAME=moodle -e MOODLE_DATABASE_USER=moodle -e MOODLE_DATABASE_PASSWORD="$DB_MOODLE_PW" \
        -e MOODLE_USERNAME=admin -e MOODLE_PASSWORD="$MOODLE_ADMIN_PW" -e MOODLE_EMAIL="admin@${DOMINIO}.invalid" \
        -e MOODLE_SITE_NAME="$NOME_ESCOLA" -e MOODLE_HOST="${DOMINIO}:${PORTA_HTTPS}" -e MOODLE_REVERSEPROXY=yes -e MOODLE_SSLPROXY=yes \
        -v "${P}-moodle-app:/bitnami/moodle" -v "${P}-moodle-dados:/bitnami/moodledata" "$IMG_MOODLE"
}

passo_proxy() {
    set -e
    # Certificado ECDSA P-256 autoassinado do proxy
    openssl ecparam -name prime256v1 -genkey -noout -out "$TMP/tls.key"
    openssl req -new -x509 -key "$TMP/tls.key" -out "$TMP/tls.crt" -days 365 -subj "/CN=${DOMINIO}/O=PoC IaC Educacional - ${P}" \
        -addext "subjectAltName=DNS:${DOMINIO},DNS:localhost,DNS:${P}-nginx,IP:127.0.0.1"
    # Configuração do proxy: ramo "com Moodle" do mesmo modelo usado pelo Terraform
    awk 'BEGIN{p=1} /^%\{ if/ {p=1; next} /^%\{ else/ {p=0; next} /^%\{ endif/ {p=1; next} p' "$RAIZ_DIR/terraform/modules/escola/templates/nginx.conf.tftpl" \
        | sed "s/\${dominio}/${DOMINIO}/g; s/\${prefixo}/${P}/g" > "$TMP/default.conf"
    cat > "$TMP/10-seguranca.conf" <<'EOF'
server_tokens off;
ssl_session_tickets off;
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Permissions-Policy "geolocation=()" always;
add_header Content-Security-Policy "frame-ancestors 'self'" always;
EOF
    mkdir -p "$TMP/certs" "$TMP/snippets"
    cp "$TMP/tls.crt" "$TMP/certs/tls.crt"; cp "$TMP/tls.key" "$TMP/certs/tls.key"; chmod 644 "$TMP/certs/tls.key"
    cp "$TMP/10-seguranca.conf" "$TMP/snippets/10-seguranca.conf"
    docker create --name "${P}-nginx" --restart unless-stopped --network "${P}-pedagogica" -p "127.0.0.1:${PORTA_HTTPS}:443"         -v "$TMP/default.conf:/etc/nginx/conf.d/default.conf:ro" -v "$TMP/certs:/etc/nginx/certs:ro" -v "$TMP/snippets:/etc/nginx/snippets:ro" "$IMG_NGINX"
    docker network connect "${P}-servidores" "${P}-nginx"
    docker start "${P}-nginx"
    docker exec "${P}-nginx" nginx -t
    docker exec "${P}-nginx" nginx -s reload
}

passo_monitoramento() {
    set -e
    cp "$RAIZ_DIR/terraform/modules/escola/templates/blackbox.yml" "$TMP/blackbox.yml"
    {
        printf 'global:\n  scrape_interval: 15s\n  evaluation_interval: 15s\n\nscrape_configs:\n'
        printf '  - job_name: prometheus\n    static_configs:\n      - targets: ["localhost:9090"]\n\n'
        printf '  - job_name: grafana\n    static_configs:\n      - targets: ["%s-grafana:3000"]\n\n' "$P"
        printf '  - job_name: disponibilidade_http\n    metrics_path: /probe\n    params:\n      module: [http_2xx_insecure]\n    static_configs:\n      - targets:\n          - https://%s-nginx/healthz\n          - https://%s-nginx/\n' "$P" "$P"
        printf '    relabel_configs:\n      - source_labels: [__address__]\n        target_label: __param_target\n      - source_labels: [__param_target]\n        target_label: instance\n      - target_label: __address__\n        replacement: %s-blackbox:9115\n' "$P"
        if (( ALVOS > 0 )); then
            printf '\n  - job_name: equipamentos_sinteticos\n    static_configs:\n'
            for ((i = 1; i <= ALVOS; i++)); do printf '      - targets: ["%s-blackbox:9115"]\n        labels:\n          equipamento: "eq-%03d"\n' "$P" "$i"; done
        fi
    } > "$TMP/prometheus.yml"
    printf 'apiVersion: 1\ndatasources:\n  - name: Prometheus\n    type: prometheus\n    access: proxy\n    url: http://%s-prometheus:9090\n    isDefault: true\n' "$P" > "$TMP/datasource.yml"
    docker create --name "${P}-blackbox" --restart unless-stopped --network "${P}-servidores" "$IMG_BLACKBOX"
    docker cp "$TMP/blackbox.yml" "${P}-blackbox:/etc/blackbox_exporter/config.yml"
    docker start "${P}-blackbox"
    docker create --name "${P}-prometheus" --restart unless-stopped --network "${P}-admin" -p "127.0.0.1:${PORTA_PROM}:9090" \
        -v "${P}-prometheus-dados:/prometheus" "$IMG_PROM" --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/prometheus --storage.tsdb.retention.time=15d
    docker network connect "${P}-servidores" "${P}-prometheus"
    docker cp "$TMP/prometheus.yml" "${P}-prometheus:/etc/prometheus/prometheus.yml"
    docker start "${P}-prometheus"
    docker create --name "${P}-grafana" --restart unless-stopped --network "${P}-admin" -p "127.0.0.1:${PORTA_GRAFANA}:3000" \
        -e GF_SECURITY_ADMIN_USER=admin -e GF_SECURITY_ADMIN_PASSWORD="$GRAFANA_PW" -e GF_USERS_ALLOW_SIGN_UP=false \
        -e GF_ANALYTICS_REPORTING_ENABLED=false -e GF_ANALYTICS_CHECK_FOR_UPDATES=false -v "${P}-grafana-dados:/var/lib/grafana" "$IMG_GRAFANA"
    docker cp "$TMP/datasource.yml" "${P}-grafana:/etc/grafana/provisioning/datasources/prometheus.yml"
    docker start "${P}-grafana"
}

passo_backup() {
    set -e
    for i in $(seq 1 120); do
        docker logs "${P}-moodle" 2>&1 | grep -q 'Moodle setup finished' && break
        sleep 5
    done
    docker exec "${P}-mariadb" sh -c 'mariadb-dump -uroot -p"$MARIADB_ROOT_PASSWORD" --single-transaction --all-databases > /dumps/mariadb.sql'
    docker run --rm --name "${P}-restic-run" --entrypoint /bin/sh -e RESTIC_REPOSITORY=/repo -e RESTIC_PASSWORD="$RESTIC_PW" \
        -v "${P}-backup-repo:/repo" -v "${P}-dumps:/data/dumps:ro" -v "${P}-moodle-dados:/data/moodle-dados:ro" -v "${P}-ldap-dados:/data/ldap:ro" \
        "$IMG_RESTIC" -c 'set -eu; restic cat config >/dev/null 2>&1 || restic init; restic backup --tag escola01 /data; restic forget --tag escola01 --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune; restic check'
}

smoke() {
    SMOKE_PERFIL=completo ESCOLA_PREFIXO="$P" PORTA_HTTPS="$PORTA_HTTPS" PORTA_GRAFANA="$PORTA_GRAFANA" PORTA_PROMETHEUS="$PORTA_PROM" SMOKE_MOODLE=1 \
        bash "$MEDICAO_DIR/smoke_tests.sh"
}

destruir() {
    docker rm -f $(docker ps -aq --filter "name=^${P}-") 2> /dev/null
    for v in mariadb-dados dumps moodle-app moodle-dados prometheus-dados grafana-dados ldap-dados ldap-certs backup-repo; do docker volume rm -f "${P}-$v" > /dev/null 2>&1; done
    for n in admin pedagogica servidores; do docker network rm "${P}-$n" > /dev/null 2>&1; done
    rm -rf "$TMP"; mkdir -p "$TMP"
    return 0
}

echo "Baseline imperativo $NOME (porte $PORTE), $REPETICOES repetições"
destruir
for ((i = 1; i <= REPETICOES; i++)); do
    run_id="$(printf 'run_%02d' "$i")"
    if [[ -n "${PRE_REP_CMD:-}" ]]; then eval "$PRE_REP_CMD" > "$LOG_DIR/${NOME}_${run_id}_pre_rep.log" 2>&1 || true; fi
    echo "== Repetição $i de $REPETICOES ($run_id)"
    NOME_ESCOLA="${NOME_ESCOLA_JSON:-Escola Modelo}"
    DB_ROOT_PW="$(senha)"; DB_MOODLE_PW="$(senha)"; MOODLE_ADMIN_PW="$(senha)"; GRAFANA_PW="$(senha)"
    LDAP_ADMIN_PW="$(senha)"; LDAP_USER_PW="$(senha)"; RESTIC_PW="$(senha)"
    ok=1
    for par in imperativo_rede:passo_rede imperativo_volumes:passo_volumes imperativo_ldap:passo_ldap imperativo_banco_moodle:passo_banco_moodle                imperativo_proxy:passo_proxy imperativo_monitoramento:passo_monitoramento imperativo_backup:passo_backup smoke_tests:smoke; do
        if (( ok )); then
            cron_imp "$run_id" "${par%%:*}" "${par##*:}"
            rc=$?
            if (( rc != 0 )); then ok=0; fi
        fi
    done
    cron_imp "$run_id" imperativo_destroy destruir
done
echo "Concluído. CSV: $TEMPOS"
