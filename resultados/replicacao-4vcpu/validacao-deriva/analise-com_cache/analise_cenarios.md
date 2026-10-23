# Resultados da análise

Estatísticas calculadas a partir dos CSV informados. Desvio-padrão amostral (n-1); "n/a" quando há uma única observação.

_Cenários: 1; execuções: 10; execuções com falha: 0 (excluídas dos tempos)._

### Tempo por cenário e fase (segundos): mediana, média, desvio-padrão, mín, máx, IQR e CV

| cenario | porte | n | fase | n_obs | mediana_s | media_s | desvio_padrao_s | minimo_s | maximo_s | q1_s | q3_s | iqr_s | cv_pct |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| completo_pequeno_n01 | pequeno | 1 | terraform_apply | 10 | 12.789 | 12.730 | 2.706 | 10.037 | 15.370 | 10.139 | 15.297 | 5.157 | 21.261 |
| completo_pequeno_n01 | pequeno | 1 | ansible_playbook | 10 | 53.532 | 55.368 | 2.703 | 52.834 | 58.767 | 53.310 | 58.383 | 5.072 | 4.882 |
| completo_pequeno_n01 | pequeno | 1 | smoke_tests | 10 | 0.175 | 0.460 | 0.423 | 0.151 | 1.185 | 0.163 | 0.744 | 0.581 | 92.080 |
| completo_pequeno_n01 | pequeno | 1 | terraform_plan_idempotencia | 10 | 2.999 | 3.005 | 0.043 | 2.949 | 3.105 | 2.985 | 3.020 | 0.036 | 1.419 |
| completo_pequeno_n01 | pequeno | 1 | terraform_apply_idempotencia | 10 | 3.054 | 3.055 | 0.062 | 2.978 | 3.200 | 3.033 | 3.071 | 0.039 | 2.028 |
| completo_pequeno_n01 | pequeno | 1 | teardown_ansible | 10 | 3.440 | 3.416 | 0.069 | 3.297 | 3.506 | 3.356 | 3.458 | 0.102 | 2.024 |
| completo_pequeno_n01 | pequeno | 1 | terraform_destroy | 10 | 7.383 | 7.376 | 0.138 | 7.191 | 7.609 | 7.268 | 7.477 | 0.210 | 1.870 |
| completo_pequeno_n01 | pequeno | 1 | total_provisionamento | 10 | 68.876 | 68.558 | 3.473 | 64.056 | 73.958 | 65.830 | 69.594 | 3.764 | 5.065 |

### Tempo total de provisionamento por porte (segundos)

| porte | cenarios | n_obs | mediana_s | media_s | desvio_padrao_s | minimo_s | maximo_s | q1_s | q3_s | iqr_s | cv_pct |
|---|---|---|---|---|---|---|---|---|---|---|---|
| pequeno | 1 | 10 | 68.876 | 68.558 | 3.473 | 64.056 | 73.958 | 65.830 | 69.594 | 3.764 | 5.065 |
| pequeno (N=1) | 1 | 10 | 68.876 | 68.558 | 3.473 | 64.056 | 73.958 | 65.830 | 69.594 | 3.764 | 5.065 |

### Escalabilidade: tempo x N (mediana), tempo por escola e incremental

| familia | n | mediana_total_s | tempo_por_escola_s | incremental_por_escola_s |
|---|---|---|---|---|
| completo_pequeno | 1 | 68.876 | 68.876 | n/a |

### Escalabilidade: ajuste linear tempo = a + b x N (R2 só com 3 ou mais valores de N)

| familia | pontos_n | inclinacao_s_por_escola | intercepto_s | r2 |
|---|---|---|---|---|
| completo_pequeno | 1 | n/a | n/a | n/a |

### Falhas por cenário

| cenario | porte | n | execucoes | execucoes_com_falha | taxa_falha_pct | testes_de_fumaca_falhos | fases_com_falha |
|---|---|---|---|---|---|---|---|
| completo_pequeno_n01 | pequeno | 1 | 10 | 0 | 0.000 | 0 | - |

### Idempotência (plan -detailed-exitcode = 0 e 0 recursos a alterar)

| cenario | porte | n | execucoes_medidas | idempotentes | taxa_idempotencia_pct | recursos_a_alterar_max | plan_exit_code_2 |
|---|---|---|---|---|---|---|---|
| completo_pequeno_n01 | pequeno | 1 | 10 | 10 | 100.000 | 0 | 0 |

### Consistência entre execuções (proporção com hash igual ao mais frequente)

| cenario | porte | n | execucoes | hashes_distintos_estado_tf | consistencia_estado_tf_pct | hashes_distintos_docker | consistencia_docker_pct | hashes_distintos_combinado | consistencia_combinado_pct |
|---|---|---|---|---|---|---|---|---|---|
| completo_pequeno_n01 | pequeno | 1 | 10 | 1 | 100.000 | 1 | 100.000 | 1 | 100.000 |
