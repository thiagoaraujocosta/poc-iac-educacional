# Protocolo do baseline manual

Este protocolo descreve como executar e cronometrar, à mão, o mesmo ambiente que o
fluxo IaC cria. Os tempos manuais e os tempos do fluxo IaC só são comparáveis se as
condições abaixo forem respeitadas.

## 1. Condições de comparabilidade

1. Mesma máquina, mesma versão do Docker e mesmas imagens (tags de `terraform/modules/escola/variables.tf`).
2. **Imagens baixadas antes** de iniciar qualquer cronômetro (`docker pull` de cada imagem), tanto no
   manual quanto no IaC. Assim o tempo de rede do registro não distorce a comparação.
3. Ambiente limpo antes de cada repetição: sem contêineres, redes e volumes com o prefixo `escola01`
   (`docker ps -a`, `docker network ls`, `docker volume ls`).
4. Uma pessoa executa todas as repetições, sem consultar o código IaC durante o manual. Consultas a
   documentação oficial são permitidas, mas devem ser marcadas na coluna `consultou_documentacao`.
5. Registrar a curva de aprendizado: a repetição 1 tende a ser mais lenta que a 10. Informe isso na análise
   (não descarte repetições sem justificar).
6. O tempo de **autoria** do código IaC (escrever Terraform e Ansible) não entra nas medições. Ele é um
   custo único e deve ser discutido à parte no TCC.
7. Espera de inicialização conta nos dois lados: o cronômetro da etapa só para quando o serviço passa no
   teste de fumaça correspondente.

## 2. Como cronometrar

- Use um cronômetro que registre horário de início e fim (celular ou `Get-Date -Format HH:mm:ss`).
- Para cada etapa, anote `inicio_hhmmss` e `fim_hhmmss`. A coluna `segundos` pode ficar vazia:
  o `analise.py` calcula a diferença.
- Erro = qualquer comando que falhou, valor digitado errado, etapa esquecida ou refeita.
  Conte em `erros_qtd` e descreva em `erros_descricao`. Tempo de correção entra na etapa.
- Não pause o cronômetro para pensar ou procurar comandos. Pausas só para eventos externos
  (queda de energia, por exemplo), registrados em `observacoes`.

## 3. Checklist cronometrável (uma repetição)

Registre cada etapa em `modelo_baseline_manual.csv` (copie o bloco de linhas e altere `repeticao`
para 2, 3, ... até o número de repetições desejado; o IaC usa padrão de 10).

Legenda: **Início** ____:____:____  **Fim** ____:____:____  **Erros** ____  **Docs?** S / N

### Rede (fase equivalente: terraform_apply)

| Etapa | Ação | Início | Fim | Erros | Docs? |
|---|---|---|---|---|---|
| M01 | `docker network create --subnet 10.40.1.0/24 escola01-admin` | | | | |
| M02 | `docker network create --subnet 10.40.2.0/24 escola01-pedagogica` | | | | |
| M03 | `docker network create --subnet 10.40.3.0/24 escola01-servidores` | | | | |

### Armazenamento (terraform_apply)

| Etapa | Ação | Início | Fim | Erros | Docs? |
|---|---|---|---|---|---|
| M04 | `docker volume create` para: `escola01-mariadb-dados`, `-moodle-app`, `-moodle-dados`, `-prometheus-dados`, `-grafana-dados`, `-dumps` | | | | |

### Segurança do proxy (terraform_apply)

| Etapa | Ação | Início | Fim | Erros | Docs? |
|---|---|---|---|---|---|
| M05 | Gerar chave EC P-256 e certificado autoassinado com `openssl req -x509` (CN=localhost, SAN localhost e 127.0.0.1, 365 dias) | | | | |

### Computação (terraform_apply)

| Etapa | Ação | Início | Fim | Erros | Docs? |
|---|---|---|---|---|---|
| M06 | `docker run` do MariaDB: rede servidores, volumes `/var/lib/mysql` e `/dumps`, variáveis `MARIADB_*`, parâmetros utf8mb4; aguardar saúde (`healthcheck.sh`) | | | | |
| M07 | `docker run` do Moodle: rede servidores, variáveis `MOODLE_*` (banco, admin, proxy reverso), volumes `/bitnami/moodle` e `/bitnami/moodledata` | | | | |
| M08 | Escrever o arquivo `default.conf` do Nginx (TLS 1.2/1.3, `/healthz`, proxy para o Moodle, resolver 127.0.0.11) | | | | |
| M09 | `docker create` do Nginx (porta 127.0.0.1:8443:443, rede pedagogica), `docker cp` de conf/cert/chave e do diretório `snippets`, `docker network connect` na rede servidores, `docker start` | | | | |
| M10 | Escrever `prometheus.yml` e `config.yml` do Blackbox; subir os dois contêineres com redes e portas corretas | | | | |
| M11 | Subir o Grafana (rede admin, porta 127.0.0.1:3000) e provisionar o datasource Prometheus | | | | |

### Configuração (fase equivalente: ansible_playbook)

| Etapa | Ação | Início | Fim | Erros | Docs? |
|---|---|---|---|---|---|
| M12 | Gerar certificado do LDAPS; criar e iniciar o OpenLDAP com TLS na rede servidores; aguardar `ldapsearch` responder | | | | |
| M13 | Escrever o LDIF (unidades professores, alunos, administrativo; grupos; 3 usuários fictícios) e carregar com `ldapadd` | | | | |
| M14 | Gravar o trecho de cabeçalhos de segurança no Nginx, `nginx -t` e `nginx -s reload` | | | | |
| M15 | Dump do MariaDB para `/dumps`; `restic init` (se necessário), `restic backup`, `restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune`, `restic check` | | | | |

### Verificação (fase equivalente: smoke_tests)

| Etapa | Ação | Início | Fim | Erros | Docs? |
|---|---|---|---|---|---|
| M16 | Executar os mesmos testes de `smoke_tests.sh`: `/healthz` por HTTPS, TLS 1.2, cabeçalho HSTS, Moodle 2xx/3xx, Grafana `/api/health`, Prometheus `/-/healthy`, alvos do Prometheus ativos, `ldapsearch` na unidade professores | | | | |

### Limpeza (não entra no comparativo)

Remover tudo antes da próxima repetição (contêineres, redes e volumes com prefixo `escola01`). O tempo de
limpeza pode ser registrado à parte em `observacoes`, para comparar com `teardown_ansible` +
`terraform_destroy`.

## 4. Como comparar com o fluxo IaC

| Manual (etapas) | Fase IaC equivalente |
|---|---|
| M01 a M11 | `terraform_apply` |
| M12 a M15 | `ansible_playbook` |
| M16 | `smoke_tests` |

Total manual = soma de M01 a M16. Total IaC = `terraform_apply` + `ansible_playbook` + `smoke_tests`
(linha `total_provisionamento` da análise). Execute:

```
python medicao/analise.py --iac medicao/resultados/medicao_iac.csv \
    --manual medicao/resultados/baseline_manual.csv --saida medicao/resultados/analise
```

## 5. Ameaças à validade a registrar no TCC

- Autoria do IaC não contabilizada (custo inicial) e curva de aprendizado do operador manual.
- Amostra pequena (n = 10) e variabilidade do host (cache, carga da máquina, antivírus, OneDrive).
- Uma única pessoa executando, que conhece o ambiente; resultados com operadores menos experientes podem diferir.
- A inicialização do Moodle domina o tempo total em ambos os fluxos; considere reportar também a variante sem Moodle.
