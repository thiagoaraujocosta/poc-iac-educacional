output "nome_escola" {
  description = "Nome legível da escola."
  value       = var.nome_escola
}

output "url_moodle" {
  description = "URL do Moodle atrás do proxy reverso com TLS."
  value       = local.moodle_ativo ? "https://${var.dominio}:${var.porta_https}/" : null
}

output "url_grafana" {
  description = "URL do Grafana (null no perfil leve)."
  value       = local.monitoramento_ativo ? "http://${var.ip_publicacao}:${var.porta_grafana}/" : null
}

output "url_prometheus" {
  description = "URL do Prometheus (null no perfil leve)."
  value       = local.monitoramento_ativo ? "http://${var.ip_publicacao}:${var.porta_prometheus}/" : null
}

output "redes" {
  description = "Nome e sub-rede de cada rede da escola."
  value = {
    for k, r in docker_network.redes : k => {
      nome     = r.name
      sub_rede = local.redes[k]
    }
  }
}

output "volumes" {
  description = "Volumes nomeados da escola."
  value       = [for v in docker_volume.volumes : v.name]
}

output "conteineres" {
  description = "Nomes dos contêineres criados pelo Terraform."
  value = compact([
    docker_container.nginx.name,
    one(docker_container.prometheus[*].name),
    one(docker_container.grafana[*].name),
    one(docker_container.blackbox[*].name),
    one(docker_container.mariadb[*].name),
    one(docker_container.moodle[*].name),
  ])
}

output "parametros" {
  description = "Parâmetros efetivos aplicados à escola (úteis para conferir a derivação a partir do cenário)."
  value = {
    perfil                    = var.perfil
    moodle_ativo              = local.moodle_ativo
    memoria_moodle_mb         = var.memoria_mb
    memoria_mariadb_mb        = local.memoria_mariadb_mb
    cpu_shares_moodle         = local.cpu_shares_moodle
    alvos_monitoramento       = var.alvos_monitoramento
    rede_servidores_sem_saida = local.rede_servidores_sem_saida
  }
}

output "certificado_validade_fim" {
  description = "Fim da validade do certificado autoassinado."
  value       = tls_self_signed_cert.proxy.validity_end_time
}

output "moodle_admin_senha" {
  description = "Senha do administrador do Moodle (gerada)."
  value       = random_password.segredos["moodle_admin"].result
  sensitive   = true
}

output "grafana_admin_senha" {
  description = "Senha do administrador do Grafana (gerada)."
  value       = random_password.segredos["grafana_admin"].result
  sensitive   = true
}
