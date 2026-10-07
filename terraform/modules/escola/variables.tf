variable "prefixo" {
  description = "Prefixo de todos os recursos da escola (ex.: escola01)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.prefixo))
    error_message = "Use 2 a 21 caracteres: minúsculas, números e hífen, iniciando por letra."
  }
}

variable "nome_escola" {
  description = "Nome legível da escola (usado no título do Moodle)."
  type        = string
}

variable "bloco_cidr" {
  description = "Bloco /20 da escola. Dele saem três sub-redes /24."
  type        = string

  validation {
    condition     = can(cidrsubnet(var.bloco_cidr, 4, 3))
    error_message = "bloco_cidr deve permitir a divisão em quatro bits adicionais (ex.: um /20)."
  }
}

variable "dominio" {
  description = "Nome DNS do certificado e do Moodle (não use localhost)."
  type        = string
  default     = "escola.local"
}

variable "ip_publicacao" {
  description = "Endereço do host em que as portas são publicadas."
  type        = string
  default     = "127.0.0.1"
}

variable "porta_https" {
  description = "Porta HTTPS publicada no host (Nginx)."
  type        = number
}

variable "porta_grafana" {
  description = "Porta do Grafana publicada no host."
  type        = number
}

variable "porta_prometheus" {
  description = "Porta do Prometheus publicada no host."
  type        = number
}

variable "habilitar_moodle" {
  description = "Se false, não cria MariaDB nem Moodle (útil para testes de replicação com pouca memória)."
  type        = bool
  default     = true
}

variable "perfil" {
  description = "Perfil de implantação: completo (todos os serviços) ou leve (redes, proxy e banco pequeno; sem Moodle, Prometheus, Blackbox e Grafana)."
  type        = string
  default     = "completo"

  validation {
    condition     = contains(["completo", "leve"], var.perfil)
    error_message = "perfil deve ser \"completo\" ou \"leve\"."
  }
}

variable "memoria_mb" {
  description = "Limite de memória do contêiner do Moodle, em MB. Null = sem limite."
  type        = number
  default     = null

  validation {
    condition     = var.memoria_mb == null ? true : var.memoria_mb >= 128
    error_message = "memoria_mb deve ser pelo menos 128 quando informada."
  }
}

variable "memoria_banco_mb" {
  description = "Limite de memória do MariaDB, em MB. Null = sem limite no perfil completo e 256 MB no perfil leve."
  type        = number
  default     = null

  validation {
    condition     = var.memoria_banco_mb == null ? true : var.memoria_banco_mb >= 128
    error_message = "memoria_banco_mb deve ser pelo menos 128 quando informada."
  }
}

variable "cpus" {
  description = "Peso relativo de CPU do Moodle em unidades de CPU (1 = 1024 cpu_shares). Não é um teto rígido. Null = padrão do Docker."
  type        = number
  default     = null

  validation {
    condition     = var.cpus == null ? true : var.cpus > 0
    error_message = "cpus deve ser maior que zero quando informado."
  }
}

variable "alvos_monitoramento" {
  description = "Quantidade de alvos sintéticos de coleta no Prometheus, representando os equipamentos da escola. 0 = nenhum (padrão)."
  type        = number
  default     = 0

  validation {
    condition     = var.alvos_monitoramento >= 0 && var.alvos_monitoramento <= 200 && floor(var.alvos_monitoramento) == var.alvos_monitoramento
    error_message = "alvos_monitoramento deve ser um inteiro entre 0 e 200."
  }
}

variable "modo_local_first" {
  description = "Escola sem banda larga: a rede de servidores fica sem saída externa (equivale a rede_servidores_interna = true)."
  type        = bool
  default     = false
}

variable "rede_servidores_interna" {
  description = "Se true, a rede servidores não tem saída para a Internet (isolamento maior; o Moodle não baixa plugins)."
  type        = bool
  default     = false
}

variable "validade_certificado_horas" {
  description = "Validade do certificado autoassinado, em horas."
  type        = number
  default     = 8760
}

variable "rotulos" {
  description = "Rótulos adicionais aplicados a todos os recursos que aceitam labels."
  type        = map(string)
  default     = {}
}

# Tags fixadas. VERIFIQUE a existência de cada tag no registro antes de executar:
# a PoC ainda não foi executada nesta máquina. O Bitnami migrou imagens versionadas
# para o repositório "bitnamilegacy"; troque por outra imagem mantida se preferir.
variable "imagens" {
  description = "Imagens de contêiner com tag fixa."
  type = object({
    nginx      = string
    mariadb    = string
    moodle     = string
    prometheus = string
    grafana    = string
    blackbox   = string
  })
  default = {
    nginx      = "nginx:1.27.3-alpine"
    mariadb    = "mariadb:11.4.4"
    moodle     = "bitnamilegacy/moodle:4.5.2"
    prometheus = "prom/prometheus:v2.55.1"
    grafana    = "grafana/grafana:11.3.1"
    blackbox   = "prom/blackbox-exporter:v0.25.0"
  }
}
