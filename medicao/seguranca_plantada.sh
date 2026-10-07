#!/usr/bin/env bash
# Teste de detecção de deficiências de segurança (métrica M4).
# Para cada uma das 6 deficiências, cria uma cópia do código com a deficiência plantada e roda as cinco
# ferramentas (tflint, trivy, checkov, ansible-lint, gitleaks) na cópia e no código-base. Uma ferramenta
# "detecta" quando o número de achados na cópia é MAIOR que no código-base. Nada é presumido: o script
# só registra a contagem observada. Requer as ferramentas instaladas e no PATH (as ausentes são anotadas
# como "ausente" no CSV).
# Uso: ./seguranca_plantada.sh [-o resultados/seguranca.csv]
set -u
MEDICAO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAIZ_DIR="$(cd "$MEDICAO_DIR/.." && pwd)"
SAIDA="$MEDICAO_DIR/resultados/seguranca.csv"
while getopts "o:h" opt; do
    case "$opt" in
        o) SAIDA="$OPTARG" ;;
        *) sed -n '2,9p' "$0"; exit 2 ;;
    esac
done
PY="${PY:-$(command -v python3 || command -v python)}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$(dirname "$SAIDA")"
[[ -s "$SAIDA" ]] || echo "deficiencia,ferramenta,achados_base,achados_plantada,detectada" > "$SAIDA"

FERRAMENTAS=(tflint trivy checkov ansible-lint gitleaks)

# preparar DIR: copia terraform/ e ansible/ e arquivos de configuração para DIR
preparar() {
    local d="$1"
    mkdir -p "$d"
    cp -r "$RAIZ_DIR/terraform" "$RAIZ_DIR/ansible" "$d/"
    cp "$RAIZ_DIR/.gitleaks.toml" "$d/" 2> /dev/null || true
    rm -rf "$d"/terraform/.terraform "$d"/ansible/group_vars/all/vault.yml
}

# rodar FERRAMENTA DIR SAIDA_JSON
rodar() {
    local f="$1" d="$2" out="$3"
    : > "$out"
    case "$f" in
        tflint) (cd "$d/terraform" && tflint --init > /dev/null 2>&1; tflint --recursive --format json > "$out" 2> /dev/null) ;;
        trivy) trivy config --format json --quiet "$d/terraform" > "$out" 2> /dev/null ;;
        checkov) checkov -d "$d/terraform" --framework terraform --output json --quiet > "$out" 2> /dev/null ;;
        ansible-lint) (cd "$d/ansible" && ansible-lint -f json site.yml teardown.yml > "$out" 2> /dev/null) ;;
        gitleaks) gitleaks detect --no-git --source "$d" --report-format json --report-path "$out" --exit-code 0 > /dev/null 2>&1 ;;
    esac
    return 0
}

contar() { "$PY" "$MEDICAO_DIR/contar_achados.py" "$1" "$2"; }

# plantar ID DIR : aplica a deficiência
plantar() {
    local id="$1" d="$2"
    case "$id" in
        senha_texto_puro)
            printf '\nvariable "senha_exemplo_plantada" {\n  default = "SenhaPlantada#2026!AbCdEfGhIj"\n}\n' >> "$d/terraform/variables.tf"
            printf '\nsenha_plantada_api: "ghp_FICTICIO_PARA_TESTE_DE_DETECCAO"\n' >> "$d/ansible/group_vars/all/vars.yml"
            ;;
        porta_todas_interfaces)
            find "$d/terraform" -name '*.tf' -print0 | xargs -0 sed -i 's/ip *= *"127\.0\.0\.1"/ip = "0.0.0.0"/g'
            ;;
        tls_desabilitado)
            find "$d/terraform" -name '*.tftpl' -print0 | xargs -0 sed -i 's/listen 443 ssl/listen 443/g; s/^ *ssl_certificate.*$//; s/^ *ssl_certificate_key.*$//'
            ;;
        imagem_sem_versao)
            find "$d/terraform" -name 'variables.tf' -print0 | xargs -0 sed -i -E '0,/default *= *"[^"]+:[^"]+"/s//default = "nginx:latest"/'
            ;;
        conteiner_superusuario)
            find "$d/terraform" -name 'main.tf' -path '*modules*' -print0 | xargs -0 sed -i '0,/resource "docker_container" "nginx" {/s//resource "docker_container" "nginx" {\n  privileged = true\n  user       = "root"/'
            ;;
        volume_sem_restricao)
            find "$d/terraform" -name 'main.tf' -path '*modules*' -print0 | xargs -0 sed -i '0,/resource "docker_container" "nginx" {/s//resource "docker_container" "nginx" {\n  volumes {\n    host_path      = "\/var\/run\/docker.sock"\n    container_path = "\/var\/run\/docker.sock"\n  }/'
            ;;
    esac
}

DEFICIENCIAS=(senha_texto_puro porta_todas_interfaces tls_desabilitado imagem_sem_versao conteiner_superusuario volume_sem_restricao)

preparar "$TMP/base"
declare -A BASE
for f in "${FERRAMENTAS[@]}"; do
    if ! command -v "$f" > /dev/null 2>&1; then BASE[$f]="ausente"; continue; fi
    rodar "$f" "$TMP/base" "$TMP/base_$f.json"
    BASE[$f]="$(contar "$f" "$TMP/base_$f.json")"
    echo "base $f: ${BASE[$f]} achados"
done

for id in "${DEFICIENCIAS[@]}"; do
    preparar "$TMP/$id"
    plantar "$id" "$TMP/$id"
    for f in "${FERRAMENTAS[@]}"; do
        if [[ "${BASE[$f]}" == "ausente" ]]; then
            echo "$id,$f,ausente,ausente,ausente" >> "$SAIDA"
            continue
        fi
        rodar "$f" "$TMP/$id" "$TMP/${id}_$f.json"
        n="$(contar "$f" "$TMP/${id}_$f.json")"
        det="nao"; [[ "$n" -gt "${BASE[$f]}" ]] && det="sim"
        echo "$id,$f,${BASE[$f]},$n,$det" >> "$SAIDA"
        echo "  $id / $f: base=${BASE[$f]} plantada=$n detectada=$det"
    done
done
echo "Concluído. CSV: $SAIDA"
