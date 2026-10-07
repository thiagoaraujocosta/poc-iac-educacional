# Dataset público: Censo Escolar 2024 (INEP)

Este documento descreve o dataset real usado para construir os cenários de validação da PoC, como
reproduzi-los e, principalmente, o que o dataset **não** permite afirmar.

## 1. Fonte

| Item | Descrição |
|---|---|
| Nome | Microdados do Censo da Educação Básica (Censo Escolar) 2024 |
| Órgão | Instituto Nacional de Estudos e Pesquisas Educacionais Anísio Teixeira (INEP), Ministério da Educação |
| Página de origem | https://www.gov.br/inep/pt-br/acesso-a-informacao/dados-abertos/microdados/censo-escolar |
| Data de acesso | 29 set. 2026 |
| Arquivo usado | `microdados_ed_basica_2024.csv` (dentro de `microdados_censo_escolar_2024.zip`) |
| Formato | CSV, separador `;`, codificação `latin1` |
| Tamanho | 215.545 linhas (uma por escola) e 426 colunas |
| SHA-256 do CSV | `3fb4d93c714b7d9303e34430f0287ca102bf984a4769d5abaca21eb4d1453bc9` (gravado em `dados/resumo_dataset.json`) |

**Termos de uso.** Os microdados do INEP são publicados como dados abertos, sem informação que identifique
pessoas naturais (a unidade de análise é a escola). O uso exige citar a fonte (INEP, Censo Escolar 2024) e
seguir os termos vigentes na página do INEP, que devem ser conferidos na data de consulta: esta PoC não
transcreve nem interpreta a licença, apenas registra a fonte e a data de acesso. O CSV bruto e o zip **não são
versionados** (`.gitignore`); o repositório guarda apenas o script, o resumo estatístico e os cenários derivados.
O código da escola (`CO_ENTIDADE`) é público e aparece nos cenários apenas como identificador.

## 2. Filtros aplicados

Aplicados nesta ordem por `dados/gerar_cenarios.py`:

| Etapa | Filtro | Escolas restantes |
|---|---|---|
| Arquivo completo | (nenhum) | 215.545 |
| Em atividade | `TP_SITUACAO_FUNCIONAMENTO == 1` | 181.065 |
| Rede estadual ou municipal | `TP_DEPENDENCIA in {2, 3}` | 137.139 |
| Com matrícula na educação básica | `QT_MAT_BAS > 0` | **136.136** |

A base final tem 136.136 escolas. Os percentuais abaixo são calculados sobre essa base.

## 3. Colunas usadas

| Coluna | Uso |
|---|---|
| `CO_ENTIDADE` | Identificador da escola (código INEP) |
| `SG_UF` | Unidade da federação |
| `TP_DEPENDENCIA`, `TP_SITUACAO_FUNCIONAMENTO` | Filtros |
| `TP_LOCALIZACAO`, `QT_TUR_BAS` | Lidas, mas sem uso nas regras (reservadas para análises futuras) |
| `IN_ENERGIA_REDE_PUBLICA` | Apenas no resumo estatístico |
| `QT_MAT_BAS` | Matrículas: define o porte |
| `IN_LABORATORIO_INFORMATICA` | Laboratório de informática (registrado no manifesto) |
| `QT_DESKTOP_ALUNO`, `QT_COMP_PORTATIL_ALUNO` | Equipamentos para alunos (soma): definem os alvos de monitoramento |
| `IN_INTERNET`, `IN_INTERNET_APRENDIZAGEM` | Acesso à Internet (registrados) |
| `IN_BANDA_LARGA` | Define o modo local-first |

Valores ausentes em indicadores e quantidades são tratados como 0. Na prática, escolas sem Internet costumam
ter `IN_BANDA_LARGA` ausente e portanto caem no modo local-first.

## 4. Resultados do resumo (execução de 29 set. 2026)

Fonte: `dados/resumo_dataset.json`, gerado pelo script.

**Escolas por porte** (porte pelo número de matrículas: pequeno até 200, médio de 201 a 800, grande acima de 800):

| Porte | Escolas | % da base | Mediana de matrículas | Mediana de equipamentos | Com laboratório | Sem banda larga (local-first) |
|---|---|---|---|---|---|---|
| Pequeno | 74.007 | 54,36% | 79 | 0 | 12,69% | 24.470 |
| Médio | 53.790 | 39,51% | 360 | 7 | 44,34% | 6.605 |
| Grande | 8.339 | 6,13% | 1.010 | 25 | 70,55% | 709 |

**Quantis de `QT_MAT_BAS`:** mínimo 1, p10 26, p25 71, mediana 176, p75 371, p90 646, p99 1.366, máximo 16.500.

**Percentuais na base:** laboratório de informática 28,74%; Internet 89,90%; Internet para aprendizagem 66,20%;
banda larga 76,65% da base (85,26% entre as escolas com Internet); energia da rede pública 96,31%;
sem banda larga (local-first) 23,35%.

Observação: `QT_DESKTOP_ALUNO + QT_COMP_PORTATIL_ALUNO` tem valores extremos (máximo de 177.776 em uma escola),
o que sugere erro de preenchimento no Censo. Os dados não foram corrigidos; o limite de 50 alvos de
monitoramento neutraliza o efeito nos cenários.

## 5. Regras de derivação dos parâmetros

Os parâmetros de infraestrutura são **derivados por regra simples** do porte e de indicadores do Censo. Não são
valores medidos em escolas reais.

| Parâmetro (campo de `escolas`) | Regra |
|---|---|
| `porte` | Matrículas: até 200 pequeno; 201 a 800 médio; acima de 800 grande |
| `memoria_mb` (Moodle) | Pequeno 512; médio 1024; grande 2048 (só no perfil completo) |
| `cpus` (Moodle) | Pequeno 0,5; médio 1; grande 2 (só no perfil completo; aplicado como peso relativo, `cpu_shares`) |
| `alvos_monitoramento` | `min(equipamentos, 50)`, mínimo 1, com `equipamentos = QT_DESKTOP_ALUNO + QT_COMP_PORTATIL_ALUNO` |
| `modo_local_first` | `true` se `IN_BANDA_LARGA == 0` (ou ausente): rede de servidores interna, sem saída externa |
| `backup_frequencia` | Pequeno semanal; médio diária; grande a cada 12 h (registrada como rótulo e no manifesto; a PoC não agenda backups) |
| `perfil` | `completo` (todos os serviços, inclusive Moodle) ou `leve` (redes, volumes, Nginx e MariaDB de 256 MB; sem Moodle, Prometheus, Blackbox e Grafana) |

Os alvos de monitoramento são **sintéticos**: cada um é uma entrada de coleta apontando para o Blackbox Exporter
da própria escola, com o rótulo `equipamento`. Representam o volume de alvos, não equipamentos reais.

## 6. Cenários gerados

Com a semente 20260929, em `cenarios/` (14 arquivos `.tfvars.json` mais `manifesto.csv`):

| Perfil | Cenários | Amostragem |
|---|---|---|
| Completo | `completo_{pequeno,medio,grande}_n{01,03,05}` (9 arquivos) | Escolas reais do porte correspondente; N=1 está contido em N=3, que está contido em N=5 |
| Leve | `leve_n{01,05,10,25,50}` (5 arquivos) | Escolas sorteadas da população inteira (porte misto, conforme a distribuição real); amostras aninhadas |

Todos os cenários usam `rede_base_escolas = "10.64.0.0/12"`, pois o /16 padrão do módulo comporta só 16 escolas.
Os nomes dos recursos usam `escolaNN` (a ordem no cenário) e o campo `nome` traz o código INEP.

**Estimativa de memória (16 GB).** Para o perfil completo, o script estima a memória como a soma dos limites do
Moodle mais 1024 MB por escola para os demais contêineres. Esse valor de 1024 MB é uma **suposição de
planejamento, não uma medição**. Com ela, todos os cenários completos cabem em 16 GB, mas `completo_grande_n05`
usa cerca de 15.360 MB e deixa cerca de 1 GB de folga, o que na prática é insuficiente para o sistema operacional
e o Docker. Recomenda-se medir o consumo real na primeira execução e, se necessário, reduzir N ou os limites.

## 7. Como reproduzir

```bash
# 1. Baixar o zip do INEP (link acima), extrair e conferir o caminho:
#    dados/microdados_censo_escolar_2024_defeso/dados/microdados_ed_basica_2024.csv
# 2. Executar (Python 3.10+ com pandas e numpy):
python dados/gerar_cenarios.py                  # semente padrão 20260929
python dados/gerar_cenarios.py --csv OUTRO.csv --semente 20260929
```

O script ordena as escolas por `CO_ENTIDADE` antes de sortear, de modo que o resultado não depende da ordem das
linhas do arquivo. Duas execuções seguidas produziram arquivos idênticos (conferido por hash MD5 dos cenários
e do resumo). Cada cenário é executado com `medicao/executar_cenario.sh` (ou `.ps1`); veja o README.

## 8. Limitações

- **Dados agregados por escola.** O Censo informa existência de laboratório, quantidade de equipamentos e tipo de
  acesso, mas **não traz topologia de rede real**: nada sobre sub-redes, VLANs, largura de banda medida, servidores
  locais ou uso de plataformas. Por isso, memória, CPUs, alvos de monitoramento, modo local-first e frequência de
  backup são **derivados por regra** e refletem uma hipótese de dimensionamento, não a realidade das escolas.
- **Validade externa.** Os cenários mostram como a arquitetura se comporta com perfis de tamanho realistas
  (distribuição de porte e conectividade reais), mas não validam que a arquitetura atende às necessidades de
  cada escola.
- **Escala reduzida.** Os cenários rodam em um único host Docker; N=50 do perfil leve não representa uma rede
  estadual (mais de 130 mil escolas na base).
- **Qualidade do dado.** Há valores extremos e ausentes (seção 4). Ausente foi tratado como 0, o que pode
  superestimar o número de escolas sem banda larga.
- **Ano único.** Somente o Censo 2024; sem análise temporal.
