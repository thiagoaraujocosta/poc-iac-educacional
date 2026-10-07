#!/usr/bin/env bash
# Testes de fumaça de uma escola. Retorna 0 se todos passarem.
# Variáveis: ESCOLA_PREFIXO, PORTA_HTTPS, PORTA_GRAFANA, PORTA_PROMETHEUS,
#            SMOKE_MOODLE (1/0), SMOKE_PERFIL (completo|leve, padrão completo),
#            SMOKE_TIMEOUT (segundos por teste, padrão 900).
set -u
export LC_ALL=C

PREFIXO="${ESCOLA_PREFIXO:-escola01}"
HTTPS="${PORTA_HTTPS:-8443}"
GRAFANA="${PORTA_GRAFANA:-3000}"
PROM="${PORTA_PROMETHEUS:-9090}"
MOODLE="${SMOKE_MOODLE:-1}"
TIMEOUT="${SMOKE_TIMEOUT:-900}"
PERFIL="${SMOKE_PERFIL:-completo}"
falhas=0

# esperar "descrição" comando... : repete a cada 5 s até passar ou estourar o tempo.
esperar() {
    local nome="$1"; shift
    local limite=$((SECONDS + TIMEOUT))
    until "$@" > /dev/null 2>&1; do
        if (( SECONDS >= limite )); then
            echo "FALHA  $nome"
            falhas=$((falhas + 1))
            return 1
        fi
        sleep 5
    done
    echo "OK     $nome"
}

http_ok() { # URL: código 2xx ou 3xx
    local codigo
    codigo="$(curl -ks -o /dev/null -w '%{http_code}' --max-time 10 "$1")" || return 1
    [[ "$codigo" =~ ^(2|3)[0-9][0-9]$ ]]
}

tem_hsts() { curl -ksI --max-time 10 "https://localhost:${HTTPS}/healthz" | grep -qi '^strict-transport-security'; }
tls_moderno() { curl -ks --tlsv1.2 --max-time 10 -o /dev/null "https://localhost:${HTTPS}/healthz"; }
ldap_unidade() {
    docker exec "${PREFIXO}-ldap" sh -c \
        '/opt/bitnami/openldap/bin/ldapsearch -x -H ldap://localhost:1389 -D "cn=admin,$LDAP_ROOT" -w "$LDAP_ADMIN_PASSWORD" -b "ou=professores,$LDAP_ROOT" -s base dn' \
        | grep -q '^dn: ou=professores'
}
prom_alvos_ativos() { curl -ks --max-time 10 "http://localhost:${PROM}/api/v1/targets" | grep -q '"health":"up"'; }

mariadb_saudavel() {
    [[ "$(docker inspect -f '{{.State.Health.Status}}' "${PREFIXO}-mariadb")" == "healthy" ]]
}

echo "Smoke tests da escola ${PREFIXO} (perfil ${PERFIL})"
esperar "proxy responde em /healthz (HTTPS)"          curl -ksf --max-time 10 "https://localhost:${HTTPS}/healthz"
esperar "TLS 1.2 ou superior aceito"                  tls_moderno
esperar "cabeçalho HSTS presente (hardening)"         tem_hsts
if [[ "$PERFIL" == "leve" ]]; then
    # Perfil leve: sem Moodle, Prometheus, Grafana e LDAP.
    esperar "MariaDB saudável (healthcheck)"          mariadb_saudavel
else
    if [[ "$MOODLE" == "1" ]]; then
        esperar "Moodle acessível pelo proxy (2xx/3xx)"   http_ok "https://localhost:${HTTPS}/"
    fi
    esperar "Grafana saudável"                        curl -sf --max-time 10 "http://localhost:${GRAFANA}/api/health"
    esperar "Prometheus saudável"                     curl -sf --max-time 10 "http://localhost:${PROM}/-/healthy"
    esperar "Prometheus com alvos ativos"             prom_alvos_ativos
    esperar "LDAP: unidade professores existe (ldapsearch)" ldap_unidade
fi

if (( falhas > 0 )); then
    # Diagnóstico: últimas linhas dos contêineres e respostas do proxy (ajuda a achar a causa da falha).
    for c in moodle nginx mariadb; do
        echo "--- docker logs ${PREFIXO}-${c} (últimas 60 linhas)"
        docker logs --tail 60 "${PREFIXO}-${c}" 2>&1 || true
    done
    echo "--- resposta do proxy em /"
    curl -ksi --max-time 10 "https://localhost:${HTTPS}/" 2>&1 | head -n 40 | cut -c1-300 || true
    echo "--- corpo da resposta (texto sem marcação)"
    curl -ks --max-time 10 "https://localhost:${HTTPS}/" 2>&1 | tr '
' ' ' | sed 's/<style.*<\/style>//; s/<[^>]*>/ /g' | tr -s ' ' | head -c 1500 || true
    echo
    echo "--- Moodle direto (rede de servidores), com o mesmo Host"
    docker exec "${PREFIXO}-moodle" sh -c 'curl -s -H "Host: localhost:'"${HTTPS}"'" -H "X-Forwarded-Proto: https" -o /dev/null -w "%{http_code}
" http://localhost:8080/' 2>&1 || true
    docker exec "${PREFIXO}-moodle" sh -c 'tail -n 20 /opt/bitnami/apache/logs/error_log 2>/dev/null; ls /bitnami/moodledata 2>/dev/null | head' 2>&1 || true
    docker ps -a --format '{{.Names}}	{{.Status}}' | grep "^${PREFIXO}-" || true
    echo "Resultado: ${falhas} teste(s) falharam."
    exit 1
fi
echo "Resultado: todos os testes passaram."
