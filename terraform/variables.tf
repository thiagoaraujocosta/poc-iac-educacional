variable "docker_host" {
  description = "Endereço do daemon Docker. Null usa DOCKER_HOST ou o padrão do sistema."
  type        = string
  default     = null
}

variable "escolas" {
  description = <<-EOT
    Mapa de escolas a provisionar. A chave do mapa é o prefixo dos recursos
    (minúsculas, números e hífen). O campo "indice" define a sub-rede e as portas
    de cada escola e deve ser único; o máximo é 2^(20 - prefixo de rede_base_escolas) - 1
    (15 com o /16 padrão). Campos opcionais (todos retrocompatíveis):
      perfil              "completo" (padrão) ou "leve" (sem Moodle, Prometheus, Blackbox e Grafana)
      memoria_mb, cpus    limites do Moodle (null = sem limite)
      alvos_monitoramento alvos sintéticos de coleta no Prometheus (padrão 0)
      modo_local_first    true = rede de servidores sem saída externa
      porte, co_entidade, backup_frequencia   apenas rótulos de rastreabilidade
  EOT
  type = map(object({
    nome                = string
    indice              = number
    habilitar_moodle    = optional(bool, true)
    perfil              = optional(string, "completo")
    porte               = optional(string)
    co_entidade         = optional(string)
    memoria_mb          = optional(number)
    cpus                = optional(number)
    alvos_monitoramento = optional(number, 0)
    modo_local_first    = optional(bool, false)
    backup_frequencia   = optional(string)
  }))
  default = {
    escola01 = {
      nome   = "Escola Modelo 01"
      indice = 0
    }
  }

  validation {
    condition     = alltrue([for k in keys(var.escolas) : can(regex("^[a-z][a-z0-9-]{1,20}$", k))])
    error_message = "As chaves de escolas devem ter 2 a 21 caracteres: minúsculas, números e hífen, iniciando por letra."
  }

  validation {
    condition     = length(distinct([for e in values(var.escolas) : e.indice])) == length(var.escolas)
    error_message = "O campo indice deve ser único entre as escolas."
  }

  # O limite superior exato depende de rede_base_escolas; validações entre variáveis exigem
  # Terraform 1.9, então aqui só há o teto absoluto. Fora do intervalo, o cidrsubnet falha no plan.
  validation {
    condition     = alltrue([for e in values(var.escolas) : e.indice >= 0 && e.indice <= 255])
    error_message = "O campo indice deve estar entre 0 e 255 (o limite real depende de rede_base_escolas)."
  }

  validation {
    condition     = alltrue([for e in values(var.escolas) : contains(["completo", "leve"], e.perfil)])
    error_message = "O campo perfil deve ser \"completo\" ou \"leve\"."
  }

  validation {
    condition = alltrue([
      for e in values(var.escolas) :
      (e.memoria_mb == null ? true : e.memoria_mb >= 128) &&
      (e.cpus == null ? true : e.cpus > 0) &&
      e.alvos_monitoramento >= 0 && e.alvos_monitoramento <= 200
    ])
    error_message = "Limites inválidos: memoria_mb >= 128, cpus > 0 e alvos_monitoramento entre 0 e 200."
  }
}

variable "rede_base_escolas" {
  description = "Bloco dividido em blocos /20 (um por escola) e depois em três sub-redes /24 (admin, pedagogica, servidores). O /16 padrão comporta 16 escolas; um /12 comporta 256."
  type        = string
  default     = "10.40.0.0/16"

  validation {
    condition     = can(cidrhost(var.rede_base_escolas, 0)) && tonumber(split("/", var.rede_base_escolas)[1]) >= 8 && tonumber(split("/", var.rede_base_escolas)[1]) <= 16
    error_message = "Informe um bloco CIDR com máscara entre /8 e /16."
  }
}

variable "dominio" {
  description = "Nome DNS usado no certificado autoassinado e no Moodle. Não use localhost: o Moodle atrás de proxy reverso rejeita esse nome (veja docs/STATUS_VERIFICACAO.md). Para acessar pelo navegador, aponte o nome para 127.0.0.1 no arquivo hosts."
  type        = string
  default     = "escola.local"
}

variable "ip_publicacao" {
  description = "Endereço do host em que as portas são publicadas. Mantenha 127.0.0.1 para não expor os serviços."
  type        = string
  default     = "127.0.0.1"
}

variable "porta_base_https" {
  description = "Porta HTTPS do host da escola de índice 0. As demais somam o índice."
  type        = number
  default     = 8443
}

variable "porta_base_grafana" {
  description = "Porta do Grafana no host da escola de índice 0."
  type        = number
  default     = 3000
}

variable "porta_base_prometheus" {
  description = "Porta do Prometheus no host da escola de índice 0."
  type        = number
  default     = 9090
}
