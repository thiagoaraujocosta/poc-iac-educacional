output "escolas" {
  description = "Resumo por escola: URLs, redes, volumes e nomes de contêineres."
  value = {
    for k, m in module.escola : k => {
      nome            = m.nome_escola
      parametros      = m.parametros
      url_moodle      = m.url_moodle
      url_grafana     = m.url_grafana
      url_prometheus  = m.url_prometheus
      redes           = m.redes
      volumes         = m.volumes
      conteineres     = m.conteineres
      certificado_fim = m.certificado_validade_fim
    }
  }
}

output "credenciais_geradas" {
  description = "Senhas aleatórias geradas pelo Terraform (existem também no state). Consulte com: terraform output -json credenciais_geradas"
  sensitive   = true
  value = {
    for k, m in module.escola : k => {
      moodle_admin  = m.moodle_admin_senha
      grafana_admin = m.grafana_admin_senha
    }
  }
}
