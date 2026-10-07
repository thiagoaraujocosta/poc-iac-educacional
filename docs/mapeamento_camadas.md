# Mapeamento das camadas da arquitetura

Matriz entre as quatro camadas da arquitetura proposta no TCC, o recurso implementado na PoC e o
arquivo onde ele está definido. "TF" indica Terraform/OpenTofu e "ANS" indica Ansible.

| Camada | Recurso implementado | Ferramenta | Arquivo |
|---|---|---|---|
| Rede | Três redes Docker segmentadas por escola (admin, pedagogica, servidores) | TF | `terraform/modules/escola/main.tf` (`docker_network.redes`) |
| Rede | Sub-redes distintas derivadas de um bloco base (padrão /16, um /20 por escola, três /24 dentro dele) | TF | `terraform/main.tf` (`cidrsubnet`), `terraform/modules/escola/main.tf` (`local.redes`) |
| Rede | Rede de servidores com opção de isolamento sem saída externa | TF | `terraform/modules/escola/variables.tf` (`rede_servidores_interna`) |
| Rede | Portas publicadas apenas em 127.0.0.1, uma faixa por escola | TF | `terraform/variables.tf`, `terraform/modules/escola/main.tf` (blocos `ports`) |
| Rede | Proxy reverso Nginx entre a rede pedagógica e os servidores | TF | `terraform/modules/escola/main.tf` (`docker_container.nginx`), `templates/nginx.conf.tftpl` |
| Computação | MariaDB (imagem oficial, tag fixa, healthcheck) | TF | `terraform/modules/escola/main.tf` (`docker_container.mariadb`) |
| Computação | Moodle como carga de trabalho educacional (Bitnami, tag fixa) | TF | `terraform/modules/escola/main.tf` (`docker_container.moodle`) |
| Computação | Diretório de identidade OpenLDAP com unidades e grupos | ANS | `ansible/roles/openldap/` |
| Computação | Monitoramento: Prometheus, Blackbox Exporter e Grafana com datasource provisionado | TF | `terraform/modules/escola/main.tf`, `templates/prometheus.yml.tftpl`, `templates/blackbox.yml`, `templates/grafana_datasource.yml.tftpl` |
| Computação | Replicação para N escolas com um único módulo e `for_each` | TF | `terraform/main.tf`, `terraform/modules/escola/` |
| Armazenamento | Volumes nomeados (banco, aplicação, dados do Moodle, métricas, dashboards, dumps) | TF | `terraform/modules/escola/main.tf` (`docker_volume.volumes`) |
| Armazenamento | Volumes do LDAP e dos certificados do LDAP | ANS | `ansible/roles/openldap/tasks/main.yml` |
| Armazenamento | Backup com restic (repositório local, dump lógico do MariaDB, retenção diária/semanal/mensal, verificação) | ANS | `ansible/roles/backup_restic/` |
| Armazenamento | State do Terraform em backend local (com nota sobre backend remoto) | TF | `terraform/backend.tf` |
| Segurança | TLS no proxy com certificado autoassinado gerado pelo provedor `tls` | TF | `terraform/modules/escola/main.tf` (`tls_private_key.proxy`, `tls_self_signed_cert.proxy`) |
| Segurança | LDAPS com certificado gerado por Ansible (`community.crypto`) | ANS | `ansible/roles/tls_cert/` |
| Segurança | Hardening do proxy: HSTS, nosniff, X-Frame-Options, Referrer-Policy, CSP frame-ancestors, `server_tokens off` | ANS | `ansible/roles/nginx_hardening/` |
| Segurança | Senhas de banco, Moodle e Grafana geradas aleatoriamente e marcadas como sensíveis | TF | `terraform/modules/escola/main.tf` (`random_password.segredos`), `outputs.tf` |
| Segurança | Segredos do Ansible em Ansible Vault (exemplo fictício não criptografado) | ANS | `ansible/group_vars/all/vault.yml.exemplo`, `ansible/group_vars/all/vars.yml` |
| Segurança | Varredura de segredos, análise estática e lint no pipeline | CI | `.gitlab-ci.yml`, `.gitleaks.toml`, `.yamllint`, `terraform/.tflint.hcl` |
| Governança (transversal) | Aprovação manual com ambiente protegido; alternativa OPA/Conftest | CI | `.gitlab-ci.yml` (`aprovar`) |
| Governança (transversal) | Detecção de deriva agendada (`plan -detailed-exitcode`, falha com código 2) | CI | `.gitlab-ci.yml` (`drift-check`) |
| Rede | Modo local-first: rede de servidores sem saída externa para escolas sem banda larga (`modo_local_first`); bloco base configurável (`rede_base_escolas`, /12 a /16) para mais de 16 escolas | TF | `terraform/modules/escola/main.tf` (`local.rede_servidores_sem_saida`), `terraform/main.tf` (`bits_por_escola`) |
| Computação | Limites de memória e peso de CPU do Moodle por porte (`memoria_mb`, `cpus` como `cpu_shares`) e MariaDB de 256 MB no perfil leve | TF | `terraform/modules/escola/main.tf`, `variables.tf` |
| Computação | Perfis `completo` e `leve` (o leve omite Moodle, Prometheus, Blackbox e Grafana) | TF | `terraform/modules/escola/main.tf` (`local.completo`, `count`, `moved`) |
| Computação | Alvos de monitoramento sintéticos por escola (`alvos_monitoramento`) | TF | `terraform/modules/escola/templates/prometheus.yml.tftpl` |
| Governança (transversal) | Idempotência (`plan -detailed-exitcode` e segundo `apply`) e consistência (hash do estado normalizado) por repetição | Scripts | `medicao/executar_cenario.sh`, `medicao/executar_cenario.ps1`, `medicao/utils_cenario.py` |
| Validação (transversal) | Cenários de pequeno, médio e grande porte com escolas reais do Censo Escolar 2024 | Python | `dados/gerar_cenarios.py`, `cenarios/`, `docs/DATASET.md` |
| Medição (transversal) | Cronometragem por fase, deriva, replicação, análise estatística e baseline manual | Scripts | `medicao/` |
