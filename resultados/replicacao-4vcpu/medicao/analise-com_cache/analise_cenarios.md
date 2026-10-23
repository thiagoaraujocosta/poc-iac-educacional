# Resultados da análise

Estatísticas calculadas a partir dos CSV informados. Desvio-padrão amostral (n-1); "n/a" quando há uma única observação.

_Cenários: 8; execuções: 80; execuções com falha: 80 (excluídas dos tempos)._

### Tempo por cenário e fase (segundos): mediana, média, desvio-padrão, mín, máx, IQR e CV

| cenario | porte | n | fase | n_obs | mediana_s | media_s | desvio_padrao_s | minimo_s | maximo_s | q1_s | q3_s | iqr_s | cv_pct |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| completo_grande_n01 | grande | 1 | total_provisionamento | 0 | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| completo_grande_n05 | grande | 5 | total_provisionamento | 0 | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| completo_medio_n01 | medio | 1 | total_provisionamento | 0 | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| completo_medio_n05 | medio | 5 | total_provisionamento | 0 | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| completo_pequeno_n01 | pequeno | 1 | total_provisionamento | 0 | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| completo_pequeno_n03 | pequeno | 3 | total_provisionamento | 0 | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| leve_n01 | medio | 1 | total_provisionamento | 0 | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| leve_n10 | misto | 10 | total_provisionamento | 0 | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a |

### Tempo total de provisionamento por porte (segundos)

|  |
||

### Falhas por cenário

| cenario | porte | n | execucoes | execucoes_com_falha | taxa_falha_pct | testes_de_fumaca_falhos | fases_com_falha |
|---|---|---|---|---|---|---|---|
| completo_grande_n01 | grande | 1 | 10 | 10 | 100.000 | 0 | terraform_apply_idempotencia=10 |
| completo_grande_n05 | grande | 5 | 10 | 10 | 100.000 | 0 | terraform_apply_idempotencia=10 |
| completo_medio_n01 | medio | 1 | 10 | 10 | 100.000 | 0 | terraform_apply_idempotencia=10 |
| completo_medio_n05 | medio | 5 | 10 | 10 | 100.000 | 0 | terraform_apply_idempotencia=10 |
| completo_pequeno_n01 | pequeno | 1 | 10 | 10 | 100.000 | 0 | terraform_apply_idempotencia=10 |
| completo_pequeno_n03 | pequeno | 3 | 10 | 10 | 100.000 | 0 | terraform_apply_idempotencia=10 |
| leve_n01 | medio | 1 | 10 | 10 | 100.000 | 0 | terraform_apply_idempotencia=10 |
| leve_n10 | misto | 10 | 10 | 10 | 100.000 | 0 | terraform_apply_idempotencia=10 |

### Idempotência (plan -detailed-exitcode = 0 e 0 recursos a alterar)

| cenario | porte | n | execucoes_medidas | idempotentes | taxa_idempotencia_pct | recursos_a_alterar_max | plan_exit_code_2 |
|---|---|---|---|---|---|---|---|
| completo_grande_n01 | grande | 1 | 10 | 0 | 0.000 | 3 | 10 |
| completo_grande_n05 | grande | 5 | 10 | 0 | 0.000 | 15 | 10 |
| completo_medio_n01 | medio | 1 | 10 | 0 | 0.000 | 3 | 10 |
| completo_medio_n05 | medio | 5 | 10 | 0 | 0.000 | 15 | 10 |
| completo_pequeno_n01 | pequeno | 1 | 10 | 0 | 0.000 | 3 | 10 |
| completo_pequeno_n03 | pequeno | 3 | 10 | 0 | 0.000 | 9 | 10 |
| leve_n01 | medio | 1 | 10 | 0 | 0.000 | 3 | 10 |
| leve_n10 | misto | 10 | 10 | 0 | 0.000 | 30 | 10 |

### Consistência entre execuções (proporção com hash igual ao mais frequente)

| cenario | porte | n | execucoes | hashes_distintos_estado_tf | consistencia_estado_tf_pct | hashes_distintos_docker | consistencia_docker_pct | hashes_distintos_combinado | consistencia_combinado_pct |
|---|---|---|---|---|---|---|---|---|---|
| completo_grande_n01 | grande | 1 | 10 | 1 | 100.000 | 1 | 100.000 | 1 | 100.000 |
| completo_grande_n05 | grande | 5 | 10 | 1 | 100.000 | 1 | 100.000 | 1 | 100.000 |
| completo_medio_n01 | medio | 1 | 10 | 1 | 100.000 | 1 | 100.000 | 1 | 100.000 |
| completo_medio_n05 | medio | 5 | 10 | 1 | 100.000 | 1 | 100.000 | 1 | 100.000 |
| completo_pequeno_n01 | pequeno | 1 | 10 | 1 | 100.000 | 1 | 100.000 | 1 | 100.000 |
| completo_pequeno_n03 | pequeno | 3 | 10 | 1 | 100.000 | 1 | 100.000 | 1 | 100.000 |
| leve_n01 | medio | 1 | 10 | 1 | 100.000 | 1 | 100.000 | 1 | 100.000 |
| leve_n10 | misto | 10 | 10 | 1 | 100.000 | 1 | 100.000 | 1 | 100.000 |
