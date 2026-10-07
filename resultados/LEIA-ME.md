# Resultados brutos das medições

Arquivos gerados pelo fluxo `medicao.yml` e `validar.yml` no GitHub Actions (execuções de 7 out. 2026).

- `res-<cenario>-<com_cache|sem_cache>/`: `*_tempos.csv` (tempo por fase e repetição), `*_idempotencia.csv`,
  `*_consistencia.csv` e `ambiente_*.txt` (hardware e versões do runner). 10 repetições por cenário.
- `drift.csv`: teste de deriva (10 alterações x 10 repetições, escola de porte pequeno, perfil completo).
- `seguranca.csv` e `seguranca_diffs/`: teste das 6 deficiências plantadas (métrica M4) e as diferenças aplicadas ao código.
- `versoes.txt`: versões exatas das ferramentas.

Os logs completos (cerca de 50 MB por lote) ficam nos artefatos das execuções do GitHub Actions e não são versionados.
Cenários não executados por exceder a memória estimada do runner: `completo_medio_n05` e `completo_grande_n05`.
O cenário manual (A) não está aqui: depende de execução por uma pessoa (ver `medicao/PROTOCOLO_BASELINE_MANUAL.md`).
