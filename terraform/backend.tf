# Backend local de state (padrão da PoC).
#
# O arquivo de state fica em estado/terraform.tfstate. Ele contém dados
# sensíveis (senhas geradas e chave privada do certificado), portanto NUNCA
# deve ser versionado (veja o .gitignore da raiz do projeto).
#
# No CI o caminho pode ser sobrescrito sem editar este arquivo:
#   terraform init -backend-config="path=/srv/iac-estado/terraform.tfstate"
#
# NOTA SOBRE BACKEND REMOTO: em um ambiente real com mais de uma pessoa, use um
# backend remoto com bloqueio (lock) e criptografia em repouso, por exemplo:
#   - GitLab managed state (backend "http", endpoint da API do projeto);
#   - S3 compatível com DynamoDB ou lockfile;
#   - Consul, PostgreSQL ("pg") ou outro suportado pelo Terraform/OpenTofu.
# Exemplo (GitLab), mantido comentado porque exige um projeto GitLab real:
#
# terraform {
#   backend "http" {}
# }
# terraform init \
#   -backend-config="address=https://gitlab.exemplo.org/api/v4/projects/ID/terraform/state/producao" \
#   -backend-config="lock_address=https://gitlab.exemplo.org/api/v4/projects/ID/terraform/state/producao/lock" \
#   -backend-config="unlock_address=https://gitlab.exemplo.org/api/v4/projects/ID/terraform/state/producao/lock" \
#   -backend-config="username=SEU_USUARIO" -backend-config="password=$TOKEN"
terraform {
  backend "local" {
    path = "estado/terraform.tfstate"
  }
}
