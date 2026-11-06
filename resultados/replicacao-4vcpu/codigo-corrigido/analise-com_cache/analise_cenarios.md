# Resultados da análise

Estatísticas calculadas a partir dos CSV informados. Desvio-padrão amostral (n-1); "n/a" quando há uma única observação.

_Cenários: 8; execuções: 80; execuções com falha: 0 (excluídas dos tempos)._

### Tempo por cenário e fase (segundos): mediana, média, desvio-padrão, mín, máx, IQR e CV

| cenario | porte | n | fase | n_obs | mediana_s | media_s | desvio_padrao_s | minimo_s | maximo_s | q1_s | q3_s | iqr_s | cv_pct |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| completo_grande_n01 | grande | 1 | terraform_apply | 10 | 15.393 | 14.021 | 2.404 | 10.321 | 15.676 | 11.857 | 15.580 | 3.723 | 17.148 |
| completo_grande_n01 | grande | 1 | ansible_playbook | 10 | 65.517 | 65.682 | 0.457 | 65.274 | 66.596 | 65.353 | 65.778 | 0.424 | 0.696 |
| completo_grande_n01 | grande | 1 | smoke_tests | 10 | 0.181 | 1.016 | 1.582 | 0.171 | 5.270 | 0.175 | 1.278 | 1.103 | 155.699 |
| completo_grande_n01 | grande | 1 | terraform_plan_idempotencia | 10 | 3.053 | 3.057 | 0.034 | 3.008 | 3.102 | 3.031 | 3.084 | 0.053 | 1.106 |
| completo_grande_n01 | grande | 1 | terraform_apply_idempotencia | 10 | 3.102 | 3.098 | 0.030 | 3.050 | 3.156 | 3.085 | 3.109 | 0.024 | 0.958 |
| completo_grande_n01 | grande | 1 | teardown_ansible | 10 | 3.663 | 3.687 | 0.054 | 3.641 | 3.791 | 3.648 | 3.694 | 0.046 | 1.478 |
| completo_grande_n01 | grande | 1 | terraform_destroy | 10 | 8.633 | 8.648 | 0.122 | 8.442 | 8.880 | 8.572 | 8.725 | 0.153 | 1.416 |
| completo_grande_n01 | grande | 1 | total_provisionamento | 10 | 81.603 | 80.719 | 2.280 | 76.090 | 82.364 | 81.150 | 82.059 | 0.909 | 2.824 |
| completo_grande_n05 | grande | 5 | terraform_apply | 10 | 35.916 | 37.106 | 3.517 | 32.739 | 45.690 | 35.242 | 38.372 | 3.130 | 9.477 |
| completo_grande_n05 | grande | 5 | ansible_playbook | 10 | 227.162 | 226.271 | 5.640 | 216.577 | 232.697 | 222.878 | 230.418 | 7.540 | 2.492 |
| completo_grande_n05 | grande | 5 | smoke_tests | 10 | 0.768 | 0.773 | 0.023 | 0.741 | 0.805 | 0.757 | 0.795 | 0.038 | 2.968 |
| completo_grande_n05 | grande | 5 | terraform_plan_idempotencia | 10 | 7.022 | 7.582 | 0.877 | 6.732 | 8.750 | 6.889 | 8.540 | 1.652 | 11.565 |
| completo_grande_n05 | grande | 5 | terraform_apply_idempotencia | 10 | 8.479 | 8.254 | 0.772 | 6.854 | 9.287 | 8.397 | 8.568 | 0.171 | 9.353 |
| completo_grande_n05 | grande | 5 | teardown_ansible | 10 | 18.905 | 19.055 | 0.454 | 18.544 | 19.782 | 18.735 | 19.417 | 0.682 | 2.381 |
| completo_grande_n05 | grande | 5 | terraform_destroy | 10 | 28.570 | 28.368 | 0.960 | 26.749 | 29.558 | 28.020 | 29.064 | 1.044 | 3.383 |
| completo_grande_n05 | grande | 5 | total_provisionamento | 10 | 265.115 | 264.151 | 6.468 | 253.525 | 273.616 | 258.600 | 268.683 | 10.082 | 2.449 |
| completo_medio_n01 | medio | 1 | terraform_apply | 10 | 15.332 | 14.851 | 1.556 | 10.426 | 15.430 | 15.281 | 15.380 | 0.100 | 10.475 |
| completo_medio_n01 | medio | 1 | ansible_playbook | 10 | 54.694 | 56.148 | 2.746 | 53.637 | 60.445 | 53.806 | 58.827 | 5.021 | 4.890 |
| completo_medio_n01 | medio | 1 | smoke_tests | 10 | 0.693 | 0.703 | 0.566 | 0.158 | 1.312 | 0.169 | 1.224 | 1.056 | 80.499 |
| completo_medio_n01 | medio | 1 | terraform_plan_idempotencia | 10 | 2.939 | 2.966 | 0.058 | 2.908 | 3.062 | 2.933 | 2.999 | 0.067 | 1.946 |
| completo_medio_n01 | medio | 1 | terraform_apply_idempotencia | 10 | 2.978 | 2.997 | 0.065 | 2.937 | 3.140 | 2.951 | 3.018 | 0.067 | 2.156 |
| completo_medio_n01 | medio | 1 | teardown_ansible | 10 | 3.497 | 3.501 | 0.047 | 3.432 | 3.582 | 3.480 | 3.534 | 0.054 | 1.336 |
| completo_medio_n01 | medio | 1 | terraform_destroy | 10 | 10.262 | 10.314 | 0.200 | 10.093 | 10.785 | 10.193 | 10.347 | 0.154 | 1.944 |
| completo_medio_n01 | medio | 1 | total_provisionamento | 10 | 70.511 | 71.702 | 2.604 | 69.240 | 77.025 | 70.340 | 73.461 | 3.121 | 3.631 |
| completo_medio_n05 | medio | 5 | terraform_apply | 10 | 35.315 | 34.981 | 2.472 | 31.610 | 38.630 | 33.201 | 36.386 | 3.185 | 7.066 |
| completo_medio_n05 | medio | 5 | ansible_playbook | 10 | 220.208 | 218.145 | 4.499 | 210.753 | 222.772 | 214.780 | 221.505 | 6.725 | 2.062 |
| completo_medio_n05 | medio | 5 | smoke_tests | 10 | 0.792 | 0.800 | 0.027 | 0.777 | 0.870 | 0.784 | 0.805 | 0.021 | 3.363 |
| completo_medio_n05 | medio | 5 | terraform_plan_idempotencia | 10 | 6.681 | 7.137 | 0.844 | 6.511 | 8.794 | 6.558 | 7.612 | 1.054 | 11.832 |
| completo_medio_n05 | medio | 5 | terraform_apply_idempotencia | 10 | 8.343 | 7.865 | 0.889 | 6.471 | 8.648 | 7.109 | 8.447 | 1.338 | 11.297 |
| completo_medio_n05 | medio | 5 | teardown_ansible | 10 | 19.703 | 19.926 | 0.554 | 19.607 | 21.373 | 19.621 | 19.862 | 0.241 | 2.783 |
| completo_medio_n05 | medio | 5 | terraform_destroy | 10 | 26.437 | 26.323 | 1.725 | 23.810 | 28.616 | 25.011 | 27.600 | 2.589 | 6.552 |
| completo_medio_n05 | medio | 5 | total_provisionamento | 10 | 254.944 | 253.926 | 4.675 | 247.133 | 259.785 | 249.529 | 258.170 | 8.641 | 1.841 |
| completo_pequeno_n01 | pequeno | 1 | terraform_apply | 10 | 12.553 | 12.566 | 2.638 | 9.978 | 15.160 | 10.072 | 15.071 | 4.999 | 20.995 |
| completo_pequeno_n01 | pequeno | 1 | ansible_playbook | 10 | 56.754 | 57.207 | 3.252 | 50.990 | 62.530 | 56.229 | 57.178 | 0.949 | 5.684 |
| completo_pequeno_n01 | pequeno | 1 | smoke_tests | 10 | 0.883 | 0.654 | 0.440 | 0.146 | 1.052 | 0.154 | 1.038 | 0.884 | 67.284 |
| completo_pequeno_n01 | pequeno | 1 | terraform_plan_idempotencia | 10 | 2.904 | 2.920 | 0.054 | 2.855 | 3.011 | 2.877 | 2.961 | 0.084 | 1.833 |
| completo_pequeno_n01 | pequeno | 1 | terraform_apply_idempotencia | 10 | 2.946 | 2.953 | 0.047 | 2.900 | 3.067 | 2.935 | 2.962 | 0.027 | 1.599 |
| completo_pequeno_n01 | pequeno | 1 | teardown_ansible | 10 | 2.969 | 2.968 | 0.064 | 2.883 | 3.077 | 2.911 | 3.013 | 0.102 | 2.146 |
| completo_pequeno_n01 | pequeno | 1 | terraform_destroy | 10 | 9.648 | 9.668 | 0.114 | 9.553 | 9.958 | 9.606 | 9.685 | 0.079 | 1.175 |
| completo_pequeno_n01 | pequeno | 1 | total_provisionamento | 10 | 70.306 | 70.427 | 5.063 | 62.145 | 77.778 | 67.148 | 72.901 | 5.753 | 7.189 |
| completo_pequeno_n03 | pequeno | 3 | terraform_apply | 10 | 19.279 | 19.592 | 1.884 | 17.695 | 24.288 | 18.760 | 20.028 | 1.268 | 9.616 |
| completo_pequeno_n03 | pequeno | 3 | ansible_playbook | 10 | 133.447 | 136.244 | 10.414 | 126.195 | 154.848 | 128.041 | 141.772 | 13.731 | 7.644 |
| completo_pequeno_n03 | pequeno | 3 | smoke_tests | 10 | 0.432 | 0.468 | 0.090 | 0.397 | 0.688 | 0.414 | 0.475 | 0.061 | 19.316 |
| completo_pequeno_n03 | pequeno | 3 | terraform_plan_idempotencia | 10 | 3.929 | 3.915 | 0.517 | 3.360 | 4.471 | 3.433 | 4.390 | 0.957 | 13.213 |
| completo_pequeno_n03 | pequeno | 3 | terraform_apply_idempotencia | 10 | 4.338 | 4.165 | 0.402 | 3.396 | 4.413 | 4.285 | 4.386 | 0.102 | 9.655 |
| completo_pequeno_n03 | pequeno | 3 | teardown_ansible | 10 | 9.640 | 10.094 | 1.002 | 9.031 | 12.241 | 9.495 | 10.372 | 0.877 | 9.924 |
| completo_pequeno_n03 | pequeno | 3 | terraform_destroy | 10 | 27.127 | 27.066 | 2.493 | 23.070 | 31.622 | 26.004 | 27.985 | 1.981 | 9.211 |
| completo_pequeno_n03 | pequeno | 3 | total_provisionamento | 10 | 152.533 | 156.305 | 10.812 | 144.573 | 174.080 | 148.987 | 165.270 | 16.284 | 6.917 |
| leve_n01 | medio | 1 | terraform_apply | 10 | 14.216 | 12.281 | 2.565 | 9.178 | 14.319 | 9.336 | 14.284 | 4.948 | 20.883 |
| leve_n01 | medio | 1 | ansible_playbook | 10 | 2.399 | 2.402 | 0.024 | 2.370 | 2.450 | 2.384 | 2.417 | 0.033 | 0.993 |
| leve_n01 | medio | 1 | smoke_tests | 10 | 0.046 | 0.046 | 9.94e-04 | 0.045 | 0.048 | 0.045 | 0.046 | 0.001 | 2.167 |
| leve_n01 | medio | 1 | terraform_plan_idempotencia | 10 | 2.705 | 2.704 | 0.015 | 2.674 | 2.725 | 2.703 | 2.713 | 0.011 | 0.566 |
| leve_n01 | medio | 1 | terraform_apply_idempotencia | 10 | 2.768 | 2.808 | 0.139 | 2.734 | 3.200 | 2.762 | 2.781 | 0.019 | 4.950 |
| leve_n01 | medio | 1 | teardown_ansible | 10 | 0.440 | 0.442 | 0.009 | 0.432 | 0.459 | 0.435 | 0.446 | 0.010 | 2.034 |
| leve_n01 | medio | 1 | terraform_destroy | 10 | 5.238 | 5.255 | 0.088 | 5.143 | 5.433 | 5.196 | 5.298 | 0.103 | 1.670 |
| leve_n01 | medio | 1 | total_provisionamento | 10 | 16.657 | 14.729 | 2.570 | 11.606 | 16.797 | 11.800 | 16.727 | 4.927 | 17.449 |
| leve_n10 | misto | 10 | terraform_apply | 10 | 39.700 | 39.798 | 4.184 | 34.797 | 44.805 | 36.108 | 43.287 | 7.179 | 10.512 |
| leve_n10 | misto | 10 | ansible_playbook | 10 | 31.498 | 31.526 | 0.319 | 31.135 | 32.003 | 31.278 | 31.823 | 0.545 | 1.011 |
| leve_n10 | misto | 10 | smoke_tests | 10 | 0.537 | 0.543 | 0.021 | 0.517 | 0.582 | 0.526 | 0.554 | 0.028 | 3.870 |
| leve_n10 | misto | 10 | terraform_plan_idempotencia | 10 | 9.324 | 9.328 | 0.065 | 9.229 | 9.449 | 9.299 | 9.358 | 0.059 | 0.696 |
| leve_n10 | misto | 10 | terraform_apply_idempotencia | 10 | 9.274 | 9.258 | 0.067 | 9.088 | 9.336 | 9.243 | 9.294 | 0.051 | 0.727 |
| leve_n10 | misto | 10 | teardown_ansible | 10 | 5.855 | 5.863 | 0.126 | 5.723 | 6.144 | 5.773 | 5.915 | 0.143 | 2.144 |
| leve_n10 | misto | 10 | terraform_destroy | 10 | 21.345 | 21.387 | 0.154 | 21.218 | 21.615 | 21.261 | 21.514 | 0.253 | 0.720 |
| leve_n10 | misto | 10 | total_provisionamento | 10 | 71.604 | 71.868 | 4.164 | 67.099 | 77.390 | 68.382 | 75.221 | 6.839 | 5.794 |

### Tempo total de provisionamento por porte (segundos)

| porte | cenarios | n_obs | mediana_s | media_s | desvio_padrao_s | minimo_s | maximo_s | q1_s | q3_s | iqr_s | cv_pct |
|---|---|---|---|---|---|---|---|---|---|---|---|
| grande | 2 | 20 | 167.945 | 172.435 | 94.217 | 76.090 | 273.616 | 81.639 | 264.697 | 183.058 | 54.639 |
| medio | 3 | 30 | 70.511 | 113.452 | 103.814 | 11.606 | 259.785 | 16.755 | 249.455 | 232.700 | 91.504 |
| pequeno | 2 | 20 | 111.175 | 113.366 | 44.814 | 62.145 | 174.080 | 71.380 | 151.408 | 80.028 | 39.530 |
| misto | 1 | 10 | 71.604 | 71.868 | 4.164 | 67.099 | 77.390 | 68.382 | 75.221 | 6.839 | 5.794 |
| grande (N=1) | 1 | 10 | 81.603 | 80.719 | 2.280 | 76.090 | 82.364 | 81.150 | 82.059 | 0.909 | 2.824 |
| grande (N=5) | 1 | 10 | 265.115 | 264.151 | 6.468 | 253.525 | 273.616 | 258.600 | 268.683 | 10.082 | 2.449 |
| medio (N=1) | 2 | 20 | 43.019 | 43.215 | 29.335 | 11.606 | 77.025 | 16.660 | 70.499 | 53.839 | 67.880 |
| medio (N=5) | 1 | 10 | 254.944 | 253.926 | 4.675 | 247.133 | 259.785 | 249.529 | 258.170 | 8.641 | 1.841 |
| misto (N=10) | 1 | 10 | 71.604 | 71.868 | 4.164 | 67.099 | 77.390 | 68.382 | 75.221 | 6.839 | 5.794 |
| pequeno (N=1) | 1 | 10 | 70.306 | 70.427 | 5.063 | 62.145 | 77.778 | 67.148 | 72.901 | 5.753 | 7.189 |
| pequeno (N=3) | 1 | 10 | 152.533 | 156.305 | 10.812 | 144.573 | 174.080 | 148.987 | 165.270 | 16.284 | 6.917 |

### Escalabilidade: tempo x N (mediana), tempo por escola e incremental

| familia | n | mediana_total_s | tempo_por_escola_s | incremental_por_escola_s |
|---|---|---|---|---|
| completo_grande | 1 | 81.603 | 81.603 | n/a |
| completo_grande | 5 | 265.115 | 53.023 | 45.878 |
| completo_medio | 1 | 70.511 | 70.511 | n/a |
| completo_medio | 5 | 254.944 | 50.989 | 46.108 |
| completo_pequeno | 1 | 70.306 | 70.306 | n/a |
| completo_pequeno | 3 | 152.533 | 50.844 | 41.113 |
| leve | 1 | 16.657 | 16.657 | n/a |
| leve | 10 | 71.604 | 7.160 | 6.105 |

### Escalabilidade: ajuste linear tempo = a + b x N (R2 só com 3 ou mais valores de N)

| familia | pontos_n | inclinacao_s_por_escola | intercepto_s | r2 |
|---|---|---|---|---|
| completo_grande | 2 | 45.878 | 35.726 | n/a |
| completo_medio | 2 | 46.108 | 24.403 | n/a |
| completo_pequeno | 2 | 41.113 | 29.193 | n/a |
| leve | 2 | 6.105 | 10.552 | n/a |

### Falhas por cenário

| cenario | porte | n | execucoes | execucoes_com_falha | taxa_falha_pct | testes_de_fumaca_falhos | fases_com_falha |
|---|---|---|---|---|---|---|---|
| completo_grande_n01 | grande | 1 | 10 | 0 | 0.000 | 0 | - |
| completo_grande_n05 | grande | 5 | 10 | 0 | 0.000 | 0 | - |
| completo_medio_n01 | medio | 1 | 10 | 0 | 0.000 | 0 | - |
| completo_medio_n05 | medio | 5 | 10 | 0 | 0.000 | 0 | - |
| completo_pequeno_n01 | pequeno | 1 | 10 | 0 | 0.000 | 0 | - |
| completo_pequeno_n03 | pequeno | 3 | 10 | 0 | 0.000 | 0 | - |
| leve_n01 | medio | 1 | 10 | 0 | 0.000 | 0 | - |
| leve_n10 | misto | 10 | 10 | 0 | 0.000 | 0 | - |

### Comparação entre grupos (Mann-Whitney bilateral e delta de Cliff)

| grupo_a | grupo_b | n_a | n_b | mediana_a_s | mediana_b_s | U | p_valor | metodo | delta_cliff | magnitude |
|---|---|---|---|---|---|---|---|---|---|---|
| completo_grande_n01 | completo_medio_n01 | 10 | 10 | 81.603 | 70.511 | 98.000 | 3.30e-04 | scipy | 0.960 | grande |
| completo_grande_n01 | completo_pequeno_n01 | 10 | 10 | 81.603 | 70.306 | 96.000 | 5.83e-04 | scipy | 0.920 | grande |
| completo_medio_n01 | completo_pequeno_n01 | 10 | 10 | 70.511 | 70.306 | 59.000 | 0.521 | scipy | 0.180 | pequena |
| completo_grande_n05 | completo_medio_n05 | 10 | 10 | 265.115 | 254.944 | 88.000 | 0.005 | scipy | 0.760 | grande |

### Idempotência (plan -detailed-exitcode = 0 e 0 recursos a alterar)

| cenario | porte | n | execucoes_medidas | idempotentes | taxa_idempotencia_pct | recursos_a_alterar_max | plan_exit_code_2 |
|---|---|---|---|---|---|---|---|
| completo_grande_n01 | grande | 1 | 10 | 10 | 100.000 | 0 | 0 |
| completo_grande_n05 | grande | 5 | 10 | 10 | 100.000 | 0 | 0 |
| completo_medio_n01 | medio | 1 | 10 | 10 | 100.000 | 0 | 0 |
| completo_medio_n05 | medio | 5 | 10 | 10 | 100.000 | 0 | 0 |
| completo_pequeno_n01 | pequeno | 1 | 10 | 10 | 100.000 | 0 | 0 |
| completo_pequeno_n03 | pequeno | 3 | 10 | 10 | 100.000 | 0 | 0 |
| leve_n01 | medio | 1 | 10 | 10 | 100.000 | 0 | 0 |
| leve_n10 | misto | 10 | 10 | 10 | 100.000 | 0 | 0 |

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
