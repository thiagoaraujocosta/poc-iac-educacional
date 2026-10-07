# Módulo "escola": uma instalação completa e isolada, com as quatro camadas.
#   Rede:          três redes Docker segmentadas (admin, pedagogica, servidores)
#   Computação:    Nginx, MariaDB, Moodle, Prometheus, Blackbox e Grafana
#   Armazenamento: volumes nomeados (dados, dumps para backup)
#   Segurança:     TLS no proxy, segredos aleatórios, portas só em 127.0.0.1
# O OpenLDAP, o hardening de cabeçalhos e o backup são aplicados pelo Ansible.
#
# Perfis:
#   completo (padrão): tudo acima (Moodle opcional via habilitar_moodle).
#   leve: redes, volumes, Nginx e MariaDB de pequeno porte; sem Moodle, Prometheus,
#         Blackbox e Grafana. Usado nos cenários de escalabilidade.
# Todos os parâmetros por escola têm padrão que reproduz o comportamento anterior.

locals {
  # Três sub-redes /24 dentro do bloco /20 da escola.
  redes = {
    admin      = cidrsubnet(var.bloco_cidr, 4, 1)
    pedagogica = cidrsubnet(var.bloco_cidr, 4, 2)
    servidores = cidrsubnet(var.bloco_cidr, 4, 3)
  }

  rotulos = merge(
    {
      "iac.projeto" = "poc-iac-educacional"
      "iac.escola"  = var.prefixo
    },
    var.rotulos
  )

  completo = var.perfil == "completo"

  # Quais componentes existem em cada perfil.
  moodle_ativo        = local.completo && var.habilitar_moodle
  mariadb_ativo       = local.moodle_ativo || var.perfil == "leve"
  monitoramento_ativo = local.completo

  imagens_ativas = concat(
    ["nginx"],
    local.mariadb_ativo ? ["mariadb"] : [],
    local.moodle_ativo ? ["moodle"] : [],
    local.monitoramento_ativo ? ["prometheus", "blackbox", "grafana"] : [],
  )

  imagens_usadas = {
    for k, v in var.imagens : k => v
    if contains(local.imagens_ativas, k)
  }

  # No perfil completo, os seis volumes de sempre (inclusive com habilitar_moodle = false).
  volumes = toset(concat(
    ["mariadb-dados", "dumps"],
    local.completo ? ["moodle-app", "moodle-dados", "prometheus-dados", "grafana-dados"] : [],
  ))

  # Limites de recursos. Null = sem limite (comportamento anterior).
  # A memória do MariaDB só é limitada no perfil leve (padrão 256 MB).
  memoria_mariadb_mb = var.memoria_banco_mb != null ? var.memoria_banco_mb : (var.perfil == "leve" ? 256 : null)
  cpu_shares_moodle  = var.cpus != null ? floor(var.cpus * 1024) : null

  # Alvos sintéticos de coleta que representam os equipamentos da escola.
  alvos_equipamentos = [for i in range(var.alvos_monitoramento) : format("eq-%03d", i + 1)]

  # Rede de servidores sem saída externa: opção explícita ou modo local-first.
  rede_servidores_sem_saida = var.rede_servidores_interna || var.modo_local_first

  nginx_conf = templatefile("${path.module}/templates/nginx.conf.tftpl", {
    dominio          = var.dominio
    prefixo          = var.prefixo
    habilitar_moodle = local.moodle_ativo
  })

  prometheus_conf = templatefile("${path.module}/templates/prometheus.yml.tftpl", {
    prefixo          = var.prefixo
    habilitar_moodle = local.moodle_ativo
    alvos            = local.alvos_equipamentos
  })

  grafana_datasource = templatefile("${path.module}/templates/grafana_datasource.yml.tftpl", {
    prefixo = var.prefixo
  })
}

# ------------------------------------------------------------------ Segredos
resource "random_password" "segredos" {
  for_each = toset(["mariadb_root", "mariadb_moodle", "moodle_admin", "grafana_admin"])
  length   = 24
  special  = false
}

# ------------------------------------------------------- TLS (provedor tls)
# Escolha de projeto: o certificado autoassinado do proxy é gerado pelo provedor
# tls do Terraform, pois assim o "apply" é autossuficiente (sem etapa prévia e
# sem depender de openssl no host). O Ansible gera um certificado separado apenas
# para o LDAPS (papel tls_cert). Em produção, use uma CA (ex.: ACME/Let's Encrypt).
resource "tls_private_key" "proxy" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "proxy" {
  private_key_pem = tls_private_key.proxy.private_key_pem

  subject {
    common_name  = var.dominio
    organization = "PoC IaC Educacional - ${var.prefixo}"
  }

  dns_names             = distinct([var.dominio, "localhost", "${var.prefixo}-nginx"])
  ip_addresses          = ["127.0.0.1"]
  validity_period_hours = var.validade_certificado_horas

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# --------------------------------------------------------------------- Rede
resource "docker_network" "redes" {
  for_each = local.redes

  name     = "${var.prefixo}-${each.key}"
  driver   = "bridge"
  internal = each.key == "servidores" ? local.rede_servidores_sem_saida : false

  ipam_config {
    subnet = each.value
  }

  dynamic "labels" {
    for_each = local.rotulos
    content {
      label = labels.key
      value = labels.value
    }
  }
}

# ------------------------------------------------------------- Armazenamento
resource "docker_volume" "volumes" {
  for_each = local.volumes
  name     = "${var.prefixo}-${each.key}"

  dynamic "labels" {
    for_each = local.rotulos
    content {
      label = labels.key
      value = labels.value
    }
  }
}

# ------------------------------------------------------------------- Imagens
resource "docker_image" "imagens" {
  for_each     = local.imagens_usadas
  name         = each.value
  keep_locally = true
}

# ---------------------------------------------------------------- Computação
resource "docker_container" "mariadb" {
  count = local.mariadb_ativo ? 1 : 0

  name    = "${var.prefixo}-mariadb"
  image   = docker_image.imagens["mariadb"].image_id
  restart = "unless-stopped"

  # Memória em MB (null = sem limite). memory_swap igual a memory desliga o swap; sem isso o Docker
  # define memory_swap por conta própria e o plano passa a mostrar uma mudança a cada execução.
  memory      = local.memoria_mariadb_mb
  memory_swap = local.memoria_mariadb_mb

  command = concat(
    [
      "--character-set-server=utf8mb4",
      "--collation-server=utf8mb4_unicode_ci",
      "--innodb-file-per-table=1",
    ],
    var.perfil == "leve" ? ["--innodb-buffer-pool-size=64M", "--performance-schema=OFF"] : [],
  )

  env = [
    "MARIADB_ROOT_PASSWORD=${random_password.segredos["mariadb_root"].result}",
    "MARIADB_DATABASE=moodle",
    "MARIADB_USER=moodle",
    "MARIADB_PASSWORD=${random_password.segredos["mariadb_moodle"].result}",
  ]

  networks_advanced {
    name = docker_network.redes["servidores"].name
  }

  volumes {
    volume_name    = docker_volume.volumes["mariadb-dados"].name
    container_path = "/var/lib/mysql"
  }

  # Dumps lógicos gravados aqui pelo Ansible antes do backup com restic.
  volumes {
    volume_name    = docker_volume.volumes["dumps"].name
    container_path = "/dumps"
  }

  healthcheck {
    test         = ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
    interval     = "10s"
    timeout      = "5s"
    retries      = 12
    start_period = "20s"
  }

  wait         = true
  wait_timeout = 180

  dynamic "labels" {
    for_each = local.rotulos
    content {
      label = labels.key
      value = labels.value
    }
  }
}

resource "docker_container" "moodle" {
  count = local.moodle_ativo ? 1 : 0

  name       = "${var.prefixo}-moodle"
  image      = docker_image.imagens["moodle"].image_id
  restart    = "unless-stopped"
  depends_on = [docker_container.mariadb]

  # Memória em MB e peso relativo de CPU (1 CPU = 1024 shares). Null = sem limite.
  # cpu_shares é uma prioridade relativa sob disputa, não um teto rígido de CPU.
  memory      = var.memoria_mb
  memory_swap = var.memoria_mb
  cpu_shares  = local.cpu_shares_moodle

  env = [
    "MOODLE_DATABASE_TYPE=mariadb",
    "MOODLE_DATABASE_HOST=${var.prefixo}-mariadb",
    "MOODLE_DATABASE_PORT_NUMBER=3306",
    "MOODLE_DATABASE_NAME=moodle",
    "MOODLE_DATABASE_USER=moodle",
    "MOODLE_DATABASE_PASSWORD=${random_password.segredos["mariadb_moodle"].result}",
    "MOODLE_USERNAME=admin",
    "MOODLE_PASSWORD=${random_password.segredos["moodle_admin"].result}",
    "MOODLE_EMAIL=admin@${var.dominio}.invalid",
    "MOODLE_SITE_NAME=${var.nome_escola}",
    # Sem porta: com MOODLE_REVERSEPROXY=yes o Moodle compara o host e a porta da requisição com o wwwroot, e
    # atrás do proxy a porta vista pelo Moodle (8080) nunca bate com a porta publicada no host.
    "MOODLE_HOST=${var.dominio}",
    "MOODLE_REVERSEPROXY=yes",
    "MOODLE_SSLPROXY=yes",
  ]

  networks_advanced {
    name = docker_network.redes["servidores"].name
  }

  volumes {
    volume_name    = docker_volume.volumes["moodle-app"].name
    container_path = "/bitnami/moodle"
  }

  volumes {
    volume_name    = docker_volume.volumes["moodle-dados"].name
    container_path = "/bitnami/moodledata"
  }

  dynamic "labels" {
    for_each = local.rotulos
    content {
      label = labels.key
      value = labels.value
    }
  }
}

resource "docker_container" "nginx" {
  name    = "${var.prefixo}-nginx"
  image   = docker_image.imagens["nginx"].image_id
  restart = "unless-stopped"

  # Entrada pedagógica e acesso aos servidores. As duas redes são anexadas.
  networks_advanced {
    name = docker_network.redes["pedagogica"].name
  }

  networks_advanced {
    name = docker_network.redes["servidores"].name
  }

  ports {
    internal = 443
    external = var.porta_https
    ip       = var.ip_publicacao
  }

  upload {
    file    = "/etc/nginx/conf.d/default.conf"
    content = local.nginx_conf
  }

  upload {
    file    = "/etc/nginx/certs/tls.crt"
    content = tls_self_signed_cert.proxy.cert_pem
  }

  # A chave privada também fica no state. Veja a seção de limitações do README.
  upload {
    file    = "/etc/nginx/certs/tls.key"
    content = tls_private_key.proxy.private_key_pem
  }

  # Diretório de trechos incluídos pelo server. O Ansible (papel nginx_hardening)
  # grava aqui os cabeçalhos de segurança.
  upload {
    file    = "/etc/nginx/snippets/00-terraform.conf"
    content = "# Reservado. Trechos adicionais são aplicados pelo Ansible.\n"
  }

  dynamic "labels" {
    for_each = local.rotulos
    content {
      label = labels.key
      value = labels.value
    }
  }
}

resource "docker_container" "blackbox" {
  count = local.monitoramento_ativo ? 1 : 0

  name    = "${var.prefixo}-blackbox"
  image   = docker_image.imagens["blackbox"].image_id
  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.redes["servidores"].name
  }

  upload {
    file    = "/etc/blackbox_exporter/config.yml"
    content = file("${path.module}/templates/blackbox.yml")
  }

  dynamic "labels" {
    for_each = local.rotulos
    content {
      label = labels.key
      value = labels.value
    }
  }
}

resource "docker_container" "prometheus" {
  count = local.monitoramento_ativo ? 1 : 0

  name    = "${var.prefixo}-prometheus"
  image   = docker_image.imagens["prometheus"].image_id
  restart = "unless-stopped"

  command = [
    "--config.file=/etc/prometheus/prometheus.yml",
    "--storage.tsdb.path=/prometheus",
    "--storage.tsdb.retention.time=15d",
  ]

  networks_advanced {
    name = docker_network.redes["admin"].name
  }

  networks_advanced {
    name = docker_network.redes["servidores"].name
  }

  ports {
    internal = 9090
    external = var.porta_prometheus
    ip       = var.ip_publicacao
  }

  volumes {
    volume_name    = docker_volume.volumes["prometheus-dados"].name
    container_path = "/prometheus"
  }

  upload {
    file    = "/etc/prometheus/prometheus.yml"
    content = local.prometheus_conf
  }

  dynamic "labels" {
    for_each = local.rotulos
    content {
      label = labels.key
      value = labels.value
    }
  }
}

resource "docker_container" "grafana" {
  count = local.monitoramento_ativo ? 1 : 0

  name    = "${var.prefixo}-grafana"
  image   = docker_image.imagens["grafana"].image_id
  restart = "unless-stopped"

  env = [
    "GF_SECURITY_ADMIN_USER=admin",
    "GF_SECURITY_ADMIN_PASSWORD=${random_password.segredos["grafana_admin"].result}",
    "GF_USERS_ALLOW_SIGN_UP=false",
    "GF_ANALYTICS_REPORTING_ENABLED=false",
    "GF_ANALYTICS_CHECK_FOR_UPDATES=false",
  ]

  # Somente na rede administrativa. Alcança o Prometheus por ela.
  networks_advanced {
    name = docker_network.redes["admin"].name
  }

  ports {
    internal = 3000
    external = var.porta_grafana
    ip       = var.ip_publicacao
  }

  volumes {
    volume_name    = docker_volume.volumes["grafana-dados"].name
    container_path = "/var/lib/grafana"
  }

  upload {
    file    = "/etc/grafana/provisioning/datasources/prometheus.yml"
    content = local.grafana_datasource
  }

  dynamic "labels" {
    for_each = local.rotulos
    content {
      label = labels.key
      value = labels.value
    }
  }
}

# Endereços antigos dos recursos que ganharam "count" (retrocompatibilidade com state existente).
moved {
  from = docker_container.blackbox
  to   = docker_container.blackbox[0]
}

moved {
  from = docker_container.prometheus
  to   = docker_container.prometheus[0]
}

moved {
  from = docker_container.grafana
  to   = docker_container.grafana[0]
}
