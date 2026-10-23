# Resultados da análise

Estatísticas calculadas a partir dos CSV informados. Desvio-padrão amostral (n-1); "n/a" quando há uma única observação.

_Cenários: 2; execuções: 6; execuções com falha: 0 (excluídas dos tempos)._

### Tempo por cenário e fase (segundos): mediana, média, desvio-padrão, mín, máx, IQR e CV

| cenario | porte | n | fase | n_obs | mediana_s | media_s | desvio_padrao_s | minimo_s | maximo_s | q1_s | q3_s | iqr_s | cv_pct |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| completo_pequeno_n01 | pequeno | 1 | terraform_apply | 3 | 15.434 | 13.824 | 2.807 | 10.582 | 15.455 | 13.008 | 15.444 | 2.437 | 20.309 |
| completo_pequeno_n01 | pequeno | 1 | ansible_playbook | 3 | 66.033 | 66.120 | 0.366 | 65.806 | 66.522 | 65.919 | 66.278 | 0.358 | 0.553 |
| completo_pequeno_n01 | pequeno | 1 | smoke_tests | 3 | 1.315 | 0.949 | 0.661 | 0.186 | 1.347 | 0.750 | 1.331 | 0.581 | 69.655 |
| completo_pequeno_n01 | pequeno | 1 | terraform_plan_idempotencia | 3 | 3.068 | 3.076 | 0.014 | 3.067 | 3.092 | 3.067 | 3.080 | 0.013 | 0.460 |
| completo_pequeno_n01 | pequeno | 1 | terraform_apply_idempotencia | 3 | 3.093 | 3.123 | 0.063 | 3.081 | 3.195 | 3.087 | 3.144 | 0.057 | 2.006 |
| completo_pequeno_n01 | pequeno | 1 | teardown_ansible | 3 | 3.807 | 3.802 | 0.037 | 3.762 | 3.836 | 3.784 | 3.821 | 0.037 | 0.981 |
| completo_pequeno_n01 | pequeno | 1 | terraform_destroy | 3 | 8.664 | 8.732 | 0.175 | 8.601 | 8.930 | 8.633 | 8.797 | 0.165 | 2.000 |
| completo_pequeno_n01 | pequeno | 1 | total_provisionamento | 3 | 82.163 | 80.893 | 2.546 | 77.962 | 82.555 | 80.062 | 82.359 | 2.297 | 3.148 |
| leve_n01 | medio | 1 | terraform_apply | 3 | 14.493 | 14.482 | 0.051 | 14.426 | 14.526 | 14.460 | 14.509 | 0.050 | 0.352 |
| leve_n01 | medio | 1 | ansible_playbook | 3 | 2.999 | 3.007 | 0.027 | 2.984 | 3.037 | 2.992 | 3.018 | 0.026 | 0.909 |
| leve_n01 | medio | 1 | smoke_tests | 3 | 0.053 | 0.054 | 0.003 | 0.052 | 0.057 | 0.052 | 0.055 | 0.003 | 4.900 |
| leve_n01 | medio | 1 | terraform_plan_idempotencia | 3 | 2.845 | 2.847 | 0.005 | 2.843 | 2.853 | 2.844 | 2.849 | 0.005 | 0.186 |
| leve_n01 | medio | 1 | terraform_apply_idempotencia | 3 | 2.909 | 2.908 | 0.002 | 2.906 | 2.910 | 2.907 | 2.909 | 0.002 | 0.072 |
| leve_n01 | medio | 1 | teardown_ansible | 3 | 0.552 | 0.553 | 0.004 | 0.550 | 0.558 | 0.551 | 0.555 | 0.004 | 0.752 |
| leve_n01 | medio | 1 | terraform_destroy | 3 | 5.419 | 5.405 | 0.033 | 5.367 | 5.429 | 5.393 | 5.424 | 0.031 | 0.616 |
| leve_n01 | medio | 1 | total_provisionamento | 3 | 17.530 | 17.542 | 0.030 | 17.520 | 17.577 | 17.525 | 17.553 | 0.029 | 0.173 |

### Tempo total de provisionamento por porte (segundos)

| porte | cenarios | n_obs | mediana_s | media_s | desvio_padrao_s | minimo_s | maximo_s | q1_s | q3_s | iqr_s | cv_pct |
|---|---|---|---|---|---|---|---|---|---|---|---|
| pequeno | 1 | 3 | 82.163 | 80.893 | 2.546 | 77.962 | 82.555 | 80.062 | 82.359 | 2.297 | 3.148 |
| medio | 1 | 3 | 17.530 | 17.542 | 0.030 | 17.520 | 17.577 | 17.525 | 17.553 | 0.029 | 0.173 |
| medio (N=1) | 1 | 3 | 17.530 | 17.542 | 0.030 | 17.520 | 17.577 | 17.525 | 17.553 | 0.029 | 0.173 |
| pequeno (N=1) | 1 | 3 | 82.163 | 80.893 | 2.546 | 77.962 | 82.555 | 80.062 | 82.359 | 2.297 | 3.148 |

### Escalabilidade: tempo x N (mediana), tempo por escola e incremental

| familia | n | mediana_total_s | tempo_por_escola_s | incremental_por_escola_s |
|---|---|---|---|---|
| completo_pequeno | 1 | 82.163 | 82.163 | n/a |
| leve | 1 | 17.530 | 17.530 | n/a |

### Escalabilidade: ajuste linear tempo = a + b x N (R2 só com 3 ou mais valores de N)

| familia | pontos_n | inclinacao_s_por_escola | intercepto_s | r2 |
|---|---|---|---|---|
| completo_pequeno | 1 | n/a | n/a | n/a |
| leve | 1 | n/a | n/a | n/a |

### Falhas por cenário

| cenario | porte | n | execucoes | execucoes_com_falha | taxa_falha_pct | testes_de_fumaca_falhos | fases_com_falha |
|---|---|---|---|---|---|---|---|
| completo_pequeno_n01 | pequeno | 1 | 3 | 0 | 0.000 | 0 | - |
| leve_n01 | medio | 1 | 3 | 0 | 0.000 | 0 | - |

### Idempotência (plan -detailed-exitcode = 0 e 0 recursos a alterar)

| cenario | porte | n | execucoes_medidas | idempotentes | taxa_idempotencia_pct | recursos_a_alterar_max | plan_exit_code_2 |
|---|---|---|---|---|---|---|---|
| completo_pequeno_n01 | pequeno | 1 | 3 | 3 | 100.000 | 0 | 0 |
| leve_n01 | medio | 1 | 3 | 3 | 100.000 | 0 | 0 |

### Consistência entre execuções (proporção com hash igual ao mais frequente)

| cenario | porte | n | execucoes | hashes_distintos_estado_tf | consistencia_estado_tf_pct | hashes_distintos_docker | consistencia_docker_pct | hashes_distintos_combinado | consistencia_combinado_pct |
|---|---|---|---|---|---|---|---|---|---|
| completo_pequeno_n01 | pequeno | 1 | 3 | 1 | 100.000 | 1 | 100.000 | 1 | 100.000 |
| leve_n01 | medio | 1 | 3 | 1 | 100.000 | 1 | 100.000 | 1 | 100.000 |
