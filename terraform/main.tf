# Uma instância do módulo por escola. Para replicar, basta acrescentar uma
# entrada em var.escolas: nenhuma linha deste arquivo muda.
locals {
  # Bits adicionais para chegar a um /20 por escola a partir do bloco base (/16 -> 4 bits; /12 -> 8 bits).
  bits_por_escola = 20 - tonumber(split("/", var.rede_base_escolas)[1])
}

module "escola" {
  source   = "./modules/escola"
  for_each = var.escolas

  prefixo          = each.key
  nome_escola      = each.value.nome
  habilitar_moodle = each.value.habilitar_moodle
  perfil           = each.value.perfil
  dominio          = var.dominio
  ip_publicacao    = var.ip_publicacao

  # Parâmetros por escola (null = sem limite / padrão do módulo).
  memoria_mb          = each.value.memoria_mb
  cpus                = each.value.cpus
  alvos_monitoramento = each.value.alvos_monitoramento
  modo_local_first    = each.value.modo_local_first

  # Rótulos opcionais; nulos são descartados para não alterar recursos existentes.
  rotulos = {
    for k, v in {
      "iac.porte"       = each.value.porte
      "iac.co_entidade" = each.value.co_entidade
      "iac.backup"      = each.value.backup_frequencia
      "iac.perfil"      = each.value.perfil == "completo" ? null : each.value.perfil
    } : k => v if v != null
  }

  bloco_cidr       = cidrsubnet(var.rede_base_escolas, local.bits_por_escola, each.value.indice)
  porta_https      = var.porta_base_https + each.value.indice
  porta_grafana    = var.porta_base_grafana + each.value.indice
  porta_prometheus = var.porta_base_prometheus + each.value.indice
}
