# PoC de Infraestrutura como Código para ambientes educacionais

Prova de conceito do TCC "Proposta de arquitetura automatizada via Infraestrutura como Código para
modernização de infraestruturas tecnológicas em ambientes educacionais" (Engenharia da Computação,
Impacta, 2026). Ela cobre as quatro camadas da arquitetura (rede, computação, armazenamento e
segurança) e traz o instrumental para medir, de forma comparativa, o processo manual e o automatizado.

> **Aviso:** todos os valores, nomes, domínios e senhas deste repositório são **fictícios** e servem apenas
> para demonstração. Não use nenhum deles em produção. Os arquivos de segredos reais (`vault.yml`,
> `terraform.tfvars`, state) estão no `.gitignore`.

> **Estado de validação:** consulte `docs/STATUS_VERIFICACAO.md`. Este repositório não contém resultados
> de medição: qualquer número apresentado no TCC deve vir de execuções reais registradas em `medicao/resultados/`.

## Arquitetura

Cada escola é uma instância do módulo `terraform/modules/escola`:

```
                       host (127.0.0.1)
                 :8443 (HTTPS)   :3000   :9090   :1389/:1636
                      |            |       |          |
   rede pedagogica -- Nginx ------+       |          |
                      |  (TLS, proxy)     |          |
   rede servidores -- Nginx -- Moodle -- MariaDB     OpenLDAP (Ansible)
                      Blackbox   Prometheus <-------- (Prometheus está em admin e servidores)
   rede admin -------------------Prometheus -- Grafana
```

- **Rede:** `escolaNN-admin`, `escolaNN-pedagogica`, `escolaNN-servidores`, cada uma com sub-rede /24 própria.
- **Computação:** Nginx, MariaDB, Moodle, Prometheus, Blackbox Exporter, Grafana (Terraform) e OpenLDAP (Ansible).
- **Armazenamento:** volumes nomeados e backup com restic (repositório local, retenção 7 diários, 4 semanais, 6 mensais).
- **Segurança:** TLS no proxy, LDAPS, cabeçalhos de segurança, segredos aleatórios e Ansible Vault.

A matriz completa está em `docs/mapeamento_camadas.md`.

### Decisões de projeto

- **Certificado TLS do proxy:** gerado pelo provedor `tls` do Terraform. É a opção mais simples: o
  `apply` fica autossuficiente e não depende de `openssl` no host. O Ansible gera outro certificado, só para
  o LDAPS (papel `tls_cert`). Consequência: a chave privada do proxy fica no state (veja Limitações).
- **Divisão de responsabilidades:** o Terraform cria a infraestrutura declarativa; o Ansible configura o que
  é imperativo ou pós-provisionamento (carga de LDIF, hardening, backup). Por isso o `terraform destroy`
  exige antes o `teardown.yml` (o contêiner LDAP usa a rede criada pelo Terraform).
- **Replicação:** acrescentar uma escola é acrescentar uma entrada no mapa `escolas` (poucas linhas) e
  rodar o playbook com `-e escola_prefixo=... -e escola_indice=...`.
- **Compatibilidade:** os arquivos `.tf` funcionam com Terraform e OpenTofu (use `TF_BIN=tofu` nos scripts).

## Pré-requisitos

| Ferramenta | Versão alvo |
|---|---|
| Docker Engine ou Docker Desktop | 24 ou superior |
| Terraform | 1.6 a 1.x (o pipeline usa 1.9.8; ainda não executado localmente) |
| OpenTofu (alternativa) | 1.6 ou superior |
| Ansible (ansible-core) | 2.15 ou superior, em Linux ou WSL |
| Coleções Ansible | `community.docker` >= 3.10, `community.general` >= 9, `community.crypto` >= 2.20 |
| Python | 3.10 ou superior; SDK `docker` (`pip install docker`); `pandas` para a análise |
| Ferramentas de qualidade | tflint, trivy (ou checkov), ansible-lint, yamllint, gitleaks |
| Sistema | Bash com `date +%N` (Linux/WSL) para os scripts `.sh`; PowerShell 5.1+ para o `.ps1` |

No Windows, execute o Docker Desktop com integração WSL e rode Ansible e os scripts bash dentro do WSL.
Defina `docker_host = "npipe:////./pipe/docker_engine"` no `terraform.tfvars` se usar o Terraform nativo do Windows.

## Como executar

```bash
# 1. Terraform (ou OpenTofu: troque terraform por tofu)
cd terraform
terraform init
terraform validate
terraform apply            # cria redes, volumes, Nginx, MariaDB, Moodle, monitoramento
terraform output escolas
terraform output -json credenciais_geradas   # senhas geradas (sensíveis)

# 2. Ansible (em outro terminal, no WSL/Linux)
cd ../ansible
pip install docker
ansible-galaxy collection install -r requirements.yml
cp group_vars/all/vault.yml.exemplo group_vars/all/vault.yml
#   edite os valores FICTICIO-... e criptografe:
ansible-vault encrypt group_vars/all/vault.yml
ansible-playbook site.yml --ask-vault-pass

# 3. Encerrar
ansible-playbook teardown.yml --ask-vault-pass
cd ../terraform && terraform destroy
```

Para mais escolas, edite `terraform.tfvars` (modelo em `terraform.tfvars.example`) e rode o playbook uma vez por
escola. Para menos memória, use `habilitar_moodle = false` (não cria MariaDB nem Moodle) ou o perfil `leve`.

**Antes da primeira execução**, confirme no registro cada tag de imagem (`terraform/modules/escola/variables.tf`
e `ansible/group_vars/all/vars.yml`). As tags não foram verificadas nesta máquina.

### Política de segredos

| Segredo | Onde vive | Observação |
|---|---|---|
| Senhas de MariaDB, Moodle e Grafana | Geradas pelo Terraform (`random_password`) | Ficam no state; proteja o state |
| Senha admin do LDAP, usuário de exemplo, senha do restic | Ansible Vault (`vault.yml`) | Somente o arquivo criptografado pode ser versionado |
| Senha do Vault | Arquivo fora do repositório ou variável de CI do tipo File | Nunca no Git |
| Exemplo | `vault.yml.exemplo` | Valores fictícios, autorizado no `.gitleaks.toml` |

## Pipeline (GitLab CI)

`.gitlab-ci.yml` define: `validate` (fmt, validate, tflint, trivy config, ansible-lint, yamllint, gitleaks),
`plan` (`-detailed-exitcode`, artefato do plano), `aprovacao` (job manual em ambiente protegido; há comentário
sobre a alternativa OPA/Conftest para equipes de uma pessoa), `apply` e o job agendado `drift-check`, que falha
quando o `plan` retorna código 2. Requer runner com acesso ao soquete do Docker e diretório persistente para o state.

## Validação com dataset público real

Para atender à validação com dados reais, os cenários de teste são construídos a partir do Censo Escolar 2024 do
INEP (136.136 escolas estaduais e municipais em atividade e com matrícula). O script `dados/gerar_cenarios.py`
classifica as escolas em pequeno, médio e grande porte por matrículas, sorteia escolas reais (semente 20260929) e
gera 14 cenários em `cenarios/` (perfil completo com N = 1, 3 e 5 por porte; perfil leve com N = 1, 5, 10, 25 e 50),
além de `cenarios/manifesto.csv` e `dados/resumo_dataset.json`. Fonte, filtros, regras de derivação e limitações
estão em `docs/DATASET.md`. **Atenção:** o Censo é agregado por escola e não traz topologia de rede; memória, CPUs,
alvos de monitoramento, modo local-first e frequência de backup são **derivados por regra**, não medidos.

```bash
python dados/gerar_cenarios.py                       # requer o CSV do INEP (não versionado)
cd terraform && terraform apply -var-file=../cenarios/completo_medio_n03.tfvars.json
cd ../medicao
./executar_cenario.sh -c ../cenarios/leve_n10.tfvars.json -r 10     # PowerShell: .\executar_cenario.ps1
python analise.py --tempos resultados/*_tempos.csv --idempotencia resultados/*_idempotencia.csv \
    --consistencia resultados/*_consistencia.csv --saida resultados/analise_cenarios
```

Por repetição, `executar_cenario.sh` registra apply, configuração, testes de fumaça, **idempotência**
(`plan -detailed-exitcode` e segundo `apply`; esperado: código 0 e nenhum recurso a alterar) e **consistência**
(hash do estado do Terraform e do `docker inspect`, normalizados sem ids, IPs, chaves e senhas), além de
`teardown` e `destroy`. Saídas: `<cenario>_tempos.csv`, `<cenario>_idempotencia.csv` e `<cenario>_consistencia.csv`.
`analise.py` calcula mediana, média, desvio-padrão, mín, máx, IQR e CV por cenário e por porte, a curva de
escalabilidade (tempo x N com ajuste linear e R2), falhas, taxa de idempotência, taxa de consistência e o
teste de Mann-Whitney com delta de Cliff entre grupos. Novos campos opcionais por escola no Terraform: `perfil`,
`memoria_mb`, `cpus`, `alvos_monitoramento`, `modo_local_first` e rótulos (`porte`, `co_entidade`,
`backup_frequencia`); todos têm padrão que preserva o comportamento anterior. Para mais de 16 escolas, use um
`rede_base_escolas` maior (os cenários usam `10.64.0.0/12`).

**Estado:** os cenários e a análise estatística foram executados/testados; nenhuma medição de infraestrutura foi
executada (sem Docker, Terraform nem Ansible nesta máquina). Veja `docs/STATUS_VERIFICACAO.md`.

## Como reproduzir as medições

Pré-requisitos: ambiente funcional, imagens já baixadas, vault criado (`VAULT_PASSWORD_FILE` opcional).

```bash
cd medicao
./executar_medicao.sh -n 10                 # fluxo IaC, 10 repetições -> resultados/medicao_iac.csv
./drift_test.sh                             # requer ambiente aplicado -> resultados/drift.csv
./replicacao.sh -l "1 3 5" -r 3 -m          # -m: sem Moodle -> resultados/replicacao.csv
cp modelo_baseline_manual.csv resultados/baseline_manual.csv   # preencha conforme PROTOCOLO_BASELINE_MANUAL.md
python analise.py --iac resultados/medicao_iac.csv --manual resultados/baseline_manual.csv \
    --replicacao resultados/replicacao.csv --drift resultados/drift.csv --saida resultados/analise
```

Em PowerShell: `.\executar_medicao.ps1 -Repeticoes 10` (Ansible via WSL). Os scripts de deriva e replicação são
somente bash. O CSV tem as colunas `run_id,fase,segundos,exit_code,timestamp`; as fases são `terraform_apply`,
`ansible_playbook`, `smoke_tests`, `teardown_ansible` e `terraform_destroy`. O `terraform init` não é cronometrado.

O cenário "editar a configuração dentro do contêiner" do teste de deriva existe para verificar, com dados reais, o
que o `plan` enxerga e o que não enxerga; o script não pressupõe o resultado.

## Limitações

- **Não executada:** até o momento desta entrega, a PoC foi apenas escrita e validada estaticamente onde
  possível. Veja `docs/STATUS_VERIFICACAO.md`.
- **Imagens de terceiros:** o Bitnami moveu suas imagens versionadas para `bitnamilegacy` (sem atualizações), e as
  imagens `osixia/openldap` estão sem manutenção. Adequado a laboratório; para produção, avalie alternativas mantidas.
- **State e segredos:** o state local contém a chave privada do certificado e as senhas geradas. Em uso real, use
  backend remoto criptografado com bloqueio (`terraform/backend.tf`).
- **Certificado autoassinado:** navegadores exibirão alerta. Em produção, use uma CA (ACME).
- **Deriva interna:** o Terraform não observa o conteúdo de arquivos dentro dos contêineres nem os trechos aplicados
  pelo Ansible; reexecutar o playbook cobre esse caso.
- **Docker local, não uma nuvem:** tempos e escala refletem um único host. A rede `pedagogica` contém apenas o ponto
  de entrada (Nginx); não há estações de aula simuladas.
- **Moodle atrás do proxy:** a combinação `MOODLE_HOST` com porta e `MOODLE_REVERSEPROXY` deve ser confirmada na
  primeira execução (URL de instalação e redirecionamentos).
- **Medições:** o tempo de autoria do código IaC e a curva de aprendizado do operador manual não entram nos tempos.

## Estrutura

```
terraform/            infraestrutura (módulo escola, versions.tf, backend.tf)
dados/                gerar_cenarios.py, resumo_dataset.json (CSV bruto do INEP não versionado)
cenarios/             cenários .tfvars.json e manifesto.csv gerados a partir do Censo Escolar 2024
ansible/              roles: openldap, tls_cert, nginx_hardening, backup_restic; vault de exemplo
.gitlab-ci.yml        pipeline
medicao/              scripts de medição (inclui executar_cenario.sh/.ps1), análise e protocolo manual
docs/                 mapeamento das camadas, dataset (DATASET.md) e status de verificação
```

## Licença

MIT. Veja o arquivo `LICENSE`.

## Execução no GitHub Actions

Dois fluxos em `.github/workflows/`:

| Fluxo | Quando roda | O que faz |
|---|---|---|
| `validar.yml` | a cada push, pull request ou manualmente | `tofu fmt`, `validate`, TFLint, Trivy, ansible-lint, yamllint, gitleaks; grava `resultados/versoes.txt` (versões exatas das ferramentas e hardware do runner); roda `medicao/seguranca_plantada.sh` (métrica M4). Não provisiona nada. |
| `medicao.yml` | manualmente (Actions > medicao > Run workflow) | Uma máquina virtual por cenário (matriz): instala OpenTofu e Ansible, cria segredos fictícios no Vault, faz um aquecimento (modo `com_cache`) e roda `medicao/executar_cenario.sh` com R repetições; opcionalmente roda o teste de deriva; o job `analisar` reúne os CSV e roda `analise.py`. |

Entradas do `medicao.yml`: `cenarios` (lista JSON, por exemplo `["completo_pequeno_n01","leve_n10"]`), `repeticoes` (padrão 10), `cache` (`com_cache` ou `sem_cache`, que executa `docker system prune -af` antes de cada repetição) e `rodar_deriva`.

**Limites do runner.** Em repositório privado, `ubuntu-latest` tem 2 vCPU e 7 GB de RAM; em repositório público, 4 vCPU e 16 GB. Cenários grandes (`completo_grande_n05`) e o perfil leve com 25 e 50 escolas exigem o runner maior. Cada execução grava o hardware efetivo em `ambiente_<cenario>.txt`; os tempos do TCC são os do runner e devem ser descritos assim. Cenários diferentes rodam em máquinas diferentes, o que adiciona variabilidade entre cenários (não dentro de um mesmo cenário).

**Baseline imperativo (`baseline.yml`).** Cria o mesmo ambiente de uma escola só com comandos do Docker e do OpenSSL (`medicao/baseline_imperativo.sh`), sem estado e sem plano, e registra também o que acontece ao executar o script uma segunda vez sobre o ambiente existente. Deve rodar no mesmo tipo de runner das medições do IaC para a comparação valer. Observação: em repositório público o runner `ubuntu-latest` tem 4 vCPU e 16 GB; as medições do TCC foram feitas em 2 vCPU e 7,9 GB (repositório então privado), e os tempos não são comparáveis entre os dois tipos de máquina.

**O que o CI não faz.** O contraste humano é executado por uma pessoa, seguindo `medicao/PROTOCOLO_BASELINE_MANUAL.md`, em máquina com Docker (por exemplo, GitHub Codespaces ou Docker Desktop), registrando os tempos em `medicao/modelo_baseline_manual.csv`.

Todos os valores de segredos no CI são fictícios e gerados na hora; nada sensível é versionado.

