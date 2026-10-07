# Versões travadas. Compatível com Terraform (>= 1.6) e OpenTofu (>= 1.6).
# Após o primeiro "init", versione também o arquivo .terraform.lock.hcl.
terraform {
  required_version = ">= 1.6.0, < 2.0.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 3.0.2, < 4.0.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
