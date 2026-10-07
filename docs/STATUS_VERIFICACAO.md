# Status de verificação

Data da verificação: 29/09/2026. Máquina: Windows 11 Pro.
Este documento registra, sem otimismo, o que foi validado, o que foi executado e o que ficou pendente.

## 1. Ferramentas encontradas na máquina

| Ferramenta | Situação |
|---|---|
| Python 3.13 com pandas 3.0.5, numpy 2.5.2 e scipy 1.18.1 | Presente |
| Bash (Git Bash/Cygwin 5.3) via ferramenta do assistente | Presente (fora do PATH do PowerShell) |
| PowerShell 5.1 | Presente |
| docker | **Ausente** |
| terraform | **Ausente** |
| tofu (OpenTofu) | **Ausente** |
| ansible, ansible-playbook | **Ausente** |
| ansible-lint | **Ausente** |
| yamllint | **Ausente** |
| tflint | **Ausente** |
| trivy, checkov, gitleaks, shellcheck | **Ausentes** |
| pyyaml (módulo Python) | Ausente |

Nenhuma ferramenta foi baixada ou instalada durante a verificação.

## 2. Validado estaticamente (o que de fato rodou)

| Verificação | Resultado |
|---|---|
| `bash -n` em `lib.sh`, `smoke_tests.sh`, `executar_medicao.sh`, `replicacao.sh`, `drift_test.sh` | Sem erros de sintaxe |
| Analisador de sintaxe do PowerShell em `executar_medicao.ps1` | 0 erros |
| `python -m py_compile medicao/analise.py` | Compilou |
| Execução de `analise.py` com CSV **sintéticos** criados fora do projeto (pasta temporária) | Rodou e gerou as tabelas; serviu somente para testar o código. Os números desse teste não têm relação com a PoC e não foram guardados |
| Balanceamento de chaves, colchetes e parênteses nos arquivos `.tf` | Balanceado |
| Busca por travessões (em e en dash) e tabulações em todos os arquivos | Nenhum encontrado |

## 3. Executado de fato

**Nenhuma medição de infraestrutura foi executada.** Não há Docker nem Terraform/OpenTofu/Ansible nesta máquina,
portanto nenhuma repetição real de `apply`, configuração, testes de fumaça, idempotência ou consistência foi feita
e **não existe nenhum tempo medido da PoC**. A pasta `medicao/resultados/` está vazia de propósito.

O que foi executado de verdade (Python 3.13, pandas, numpy, scipy 1.18.1), em 29/09/2026:

| Item | Resultado |
|---|---|
| `python dados/gerar_cenarios.py` sobre o CSV do Censo Escolar 2024 | Executou sem erro. Base filtrada: 136.136 escolas (pequeno 74.007; médio 53.790; grande 8.339). Gerou `dados/resumo_dataset.json`, 14 arquivos `cenarios/*.tfvars.json` e `cenarios/manifesto.csv` (118 linhas de escola mais o cabeçalho) |
| Reprodutibilidade | Duas execuções seguidas produziram arquivos idênticos (MD5 dos 14 cenários, do manifesto e do resumo) |
| Tamanho dos cenários | Completo: 422 a 425 bytes com 1 escola, 1.135 a 1.144 com 3 e 1.849 a 1.863 com 5. Leve: 375 bytes (N=1), 1.618 (N=5), 3.162 (N=10), 7.818 (N=25) e 15.582 (N=50) |
| Composição dos cenários leves | N=5: 4 pequenas e 1 média; N=10: 6, 3 e 1 grande; N=25: 14, 9 e 2; N=50: 28, 20 e 2 (sorteio da população real, sem estratificação) |
| Memória estimada (perfil completo, 16 GB) | Todos os 9 cenários completos cabem no orçamento pela estimativa (Moodle + 1024 MB por escola, suposição não medida); `completo_grande_n05` usa 15.360 MB estimados e deixa 1.024 MB de folga |
| Todos os `.tfvars.json` gerados | JSON válido (carregados com `json.load`) |
| `medicao/analise.py` com CSV **sintéticos** gerados fora do projeto (pasta temporária) | Rodou: estatísticas por cenário e por porte, curva de escalabilidade com R2, falhas, idempotência, consistência e Mann-Whitney com delta de Cliff. A implementação em Python puro do Mann-Whitney deu U e p-valor iguais aos do scipy em 4 casos testados (inclusive com empates); o ajuste linear e o delta de Cliff foram conferidos em exemplos pequenos com resultado conhecido. Os modos antigos (`--iac`) continuam funcionando. Os números dos dados sintéticos servem só para testar o código e não foram guardados |
| Lógica de `medicao/executar_cenario.sh` com **stubs** de `terraform`, `docker`, `ansible-playbook`, `curl` e `sleep` em pasta temporária | Rodou em 2 cenários (leve N=5 e completo médio N=1): as fases foram cronometradas, os três CSV foram gravados com as colunas esperadas, o código 2 do `plan` e a contagem de recursos a alterar foram registrados, e os hashes normalizados ignoraram senhas e ids variáveis dos stubs. Isso testa apenas a lógica do script, **não** o comportamento de Terraform, Docker ou Ansible. Os tempos dos stubs foram descartados |
| `medicao/utils_cenario.py` | Compila; `resumo` e `escolas` conferidos nos cenários reais; `contar-mudancas` e os hashes conferidos com os stubs |
| Analisador de sintaxe do PowerShell em `executar_cenario.ps1` | 0 erros (o script não foi executado) |
| Balanceamento de chaves, colchetes e parênteses em todos os `.tf` após as alterações | Balanceado |

## 4. Não validado (pendente)

| Item | Motivo | Como fazer |
|---|---|---|
| `terraform fmt -check`, `init`, `validate` (ou `tofu`) | Ferramenta ausente. O alinhamento do `fmt` foi feito à mão e pode exigir ajuste (`terraform fmt -recursive`) | Instalar Terraform ou OpenTofu e rodar em `terraform/` |
| Compatibilidade real dos atributos do provedor `kreuzwerker/docker` 3.0.x (blocos `upload`, `networks_advanced`, `healthcheck`, `wait`, `labels`) | Sem `init` não houve verificação do esquema | `terraform validate` |
| `tflint`, `trivy config`/`checkov`, `gitleaks` | Ferramentas ausentes | Rodar o pipeline ou localmente |
| `ansible-playbook --syntax-check`, `ansible-lint`, `yamllint` | Ferramentas ausentes; não houve sequer parse de YAML com biblioteca | Instalar ansible-core (Linux/WSL) e as coleções de `requirements.yml` |
| Nomes de parâmetros dos módulos `community.docker` (`docker_container_copy_into`, `docker_container_exec`) e o uso de `args:` com dicionário | Escritos a partir de conhecimento do módulo, sem checagem | `ansible-doc` e `--syntax-check` |
| Existência das tags de imagem (nginx 1.27.3-alpine, mariadb 11.4.4, bitnamilegacy/moodle 4.5.2, prom/prometheus v2.55.1, grafana 11.3.1, blackbox v0.25.0, bitnamilegacy/openldap 2.6.9, restic 0.17.3) e das imagens dos jobs de CI | Sem acesso ao registro | Conferir no Docker Hub/GHCR e ajustar |
| Variáveis de ambiente do Moodle Bitnami atrás de proxy (`MOODLE_HOST` com porta, `MOODLE_REVERSEPROXY`, `MOODLE_SSLPROXY`) | Sem execução | Primeira subida real |
| Caminhos e permissões dentro do contêiner LDAP (UID 1001, `/opt/bitnami/openldap/certs`) | Sem execução | Primeira subida real |
| Scripts bash de medição em ambiente real (GNU `date +%N`, `docker exec`) | Sem Docker | `./executar_medicao.sh -n 1` como teste |
| Pipeline GitLab CI (sintaxe, runner, ambiente protegido, agendamento) | Sem GitLab | `glab ci lint` ou o editor de CI do projeto |
| Testes de deriva: o que o `plan` detecta em cada cenário | Sem execução; o script não presume resultado | `./drift_test.sh` |
| Baseline manual | Depende de o operador executar e cronometrar | `medicao/PROTOCOLO_BASELINE_MANUAL.md` |
| **Alterações do Terraform para os parâmetros por escola** (`perfil`, `memoria_mb`, `cpus`, `alvos_monitoramento`, `modo_local_first`, rótulos, `rede_base_escolas` de /12 a /16, `count` em Prometheus/Blackbox/Grafana com blocos `moved`) | Revisadas **somente à mão**; `terraform validate`/`plan` não foram executados. Pontos a conferir: (1) o atributo `cpu_shares` e o `memory` (em MB) do `docker_container` na versão 3.0.x do provedor; (2) que `cpu_shares` é peso relativo, não teto de CPU (não há `cpus` rígido garantido nessa versão); (3) os blocos `moved` no módulo; (4) expressões condicionais com `null` em `variable` (`x == null ? true : ...`); (5) `optional(number)` sem padrão nos objetos de `escolas`; (6) a renderização de `%{ for }` em `prometheus.yml.tftpl`; (7) o `cidrsubnet` com o bloco /12 (limite de índices não é validado em tempo de variável, apenas no `plan`) | `terraform fmt -check`, `validate`, `plan` com `-var-file=../cenarios/*.tfvars.json` |
| Retrocompatibilidade com `state` existente | Os padrões reproduzem o comportamento anterior e os blocos `moved` evitam recriar Prometheus, Blackbox e Grafana, mas isso não foi testado com um state real | `plan` sobre um state antigo deve mostrar 0 recursos a destruir |
| Perfil leve no Ansible e nos testes de fumaça | O leve roda só o papel `proxy` (`--tags proxy`) e testa proxy, TLS, HSTS e saúde do MariaDB; a compatibilidade dos papéis com esse subconjunto não foi verificada | Uma repetição real do cenário `leve_n01` |
| Carga sintética de monitoramento (`equipamentos_sinteticos`) | Cada alvo aponta ao Blackbox Exporter (`:9115`); que ele responda `/metrics` e que os alvos fiquem `up` não foi verificado | Consultar `/api/v1/targets` no Prometheus |
| Consistência e idempotência reais | Espera-se que o `plan` reporte 0 mudanças, mas o provedor `docker` pode gerar diferenças espúrias (blocos `upload`, `labels`, `healthcheck`); o script apenas mede, sem presumir resultado. A lista de atributos estáveis usada no hash foi escrita sem ver a saída real de `terraform show -json` e `docker inspect` e pode precisar de ajuste | Primeira execução real de `executar_cenario.sh -r 1` e inspeção com `python medicao/utils_cenario.py hash-tf ARQ --mostrar` |
| Memória real dos cenários | A estimativa de 1024 MB por escola para os demais contêineres é suposição | Medir com `docker stats` no `completo_grande_n05` |
| Arquivo `.terraform.lock.hcl` | Gerado só após `init` | Rodar `init` e versionar |

## 5. Ordem sugerida para a primeira validação real

1. Instalar Docker, Terraform (ou OpenTofu), ansible-core (WSL), tflint, yamllint, ansible-lint.
2. `terraform fmt -recursive && terraform init && terraform validate`.
3. `ansible-galaxy collection install -r requirements.yml` e `ansible-playbook site.yml --syntax-check`.
4. Conferir as tags de imagem e ajustar.
5. Uma repetição real (`./executar_medicao.sh -n 1 -m` para começar sem Moodle) e atualizar este documento com o observado.
6. Rodar `terraform plan -var-file=../cenarios/leve_n01.tfvars.json`, depois `./executar_cenario.sh -c ../cenarios/leve_n01.tfvars.json -r 1`, e só então os cenários maiores (`leve_n50` e `completo_grande_n05` exigem memória; monitore com `docker stats`).

## Atualização: preparação para o GitHub Actions

- Criados `.github/workflows/validar.yml` e `medicao.yml` (sintaxe YAML verificada com PyYAML; **não executados**).
- `medicao/drift_test.sh` reescrito para 10 alterações-padrão com R repetições (antes havia 4); `bash -n` sem erros; não executado.
- Criados `medicao/seguranca_plantada.sh` e `medicao/contar_achados.py` para a métrica M4 (6 deficiências plantadas; uma ferramenta "detecta" quando o número de achados aumenta em relação ao código-base); `bash -n` e `py_compile` sem erros; **não executados**. Os padrões de substituição (`sed`) dependem do formato exato dos arquivos `.tf` e podem exigir ajuste na primeira execução.
- `executar_cenario.sh` ganhou o gancho `PRE_REP_CMD` (medição sem cache de imagens).
- Pendências conhecidas: as versões das ações e das ferramentas no CI não foram confirmadas (as ações usam versões principais `@v4`/`@v5`; OpenTofu usa a última versão). Fixe as versões após a primeira execução bem-sucedida, usando `resultados/versoes.txt`.

