# Se docker_host for null, o provedor usa a variável de ambiente DOCKER_HOST
# ou o soquete padrão do sistema.
# Windows com Docker Desktop: npipe:////./pipe/docker_engine
# Linux/WSL: unix:///var/run/docker.sock
provider "docker" {
  host = var.docker_host
}
