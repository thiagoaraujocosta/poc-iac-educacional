# Resultados brutos das medições

Arquivos gerados pelo fluxo `medicao.yml` e `validar.yml` no GitHub Actions (execuções de 7 out. 2026).

- `res-<cenario>-<com_cache|sem_cache>/`: `*_tempos.csv` (tempo por fase e repetição), `*_idempotencia.csv`,
  `*_consistencia.csv` e `ambiente_*.txt` (hardware e versões do runner). 10 repetições por cenário.
- `drift.csv`: teste de deriva (10 alterações x 10 repetições, escola de porte pequeno, perfil completo).
- `seguranca.csv` e `seguranca_diffs/`: teste das 6 deficiências plantadas (métrica M4) e as diferenças aplicadas ao código.
- `versoes.txt`: versões exatas das ferramentas.

Os logs completos (cerca de 50 MB por lote) ficam nos artefatos das execuções do GitHub Actions e não são versionados.
Cenários não executados por exceder a memória estimada do runner de 2 vCPU: `completo_medio_n05` e `completo_grande_n05` (executados na replicação, abaixo).
O tempo de uma pessoa não foi medido: é uma estimativa pelo modelo KLM (`medicao/klm_estimativa.py`), apresentada no TCC como estimativa.

## Baseline imperativo

Pastas `bas-<cenario>-<com_cache|sem_cache>/`: o mesmo ambiente de uma escola criado só com comandos do Docker e do OpenSSL
(`medicao/baseline_imperativo.sh`, fluxo `baseline.yml`), 10 repetições por porte e condição, medido no mesmo tipo de runner do IaC.
`*_reaplicacao.csv` registra o código de saída de cada passo ao executar o script uma segunda vez sobre o ambiente existente.

## Replicação em runner de 4 vCPU (`replicacao-4vcpu/`)

Repetição das medições em 23/10/2026 no runner público (4 vCPU, 16 GB, Ubuntu 26, Docker 29.4.2, OpenTofu 1.13.2), em pasta separada
para não misturar com as medições principais (2 vCPU, Docker 28.0.4). `medicao/` tem 8 cenários do IaC e `baseline/` os 3 portes do script.
Nessa replicação a idempotência falhou em 80 de 80 execuções: o Docker 29 devolve o gateway da rede e o módulo declarava só a sub-rede
(evidência em `evidencia_plano_docker29.log`). O módulo passou a declarar o gateway (commit `a7e0329`); `validacao-fix/` tem a rodada de
validação com o código corrigido (2 cenários x 3 execuções, 6 de 6 idempotentes) e `validacao-deriva/` (porte pequeno, 10 execuções: 10 de 10 idempotentes; deriva 70 de 100, igual às medições principais). Os tempos da replicação não são afetados, porque a
idempotência é medida depois do tempo de provisionamento. As medições principais usaram o código anterior à correção.
