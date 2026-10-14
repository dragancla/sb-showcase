terraform {
  required_version = ">= 1.5.0"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13.0"
    }
    nomad = {
      source  = "hashicorp/nomad"
      version = "~> 2.1.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.0"
    }
  }
}

resource "random_password" "db_password" {
  length  = 16
  special = false
}

provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_path
  }
}

resource "helm_release" "sb" {
  name             = "sb"
  chart            = "${path.module}/../charts/sb"
  namespace        = "sb"
  create_namespace = true
  timeout          = 300

  set {
    name  = "global.imageTag"
    value = var.app_version
  }

  set_sensitive {
    name  = "db.password"
    value = random_password.db_password.result
  }
}

provider "nomad" {
  address = var.nomad_address
}

resource "nomad_job" "sb" {
  jobspec = file("${path.module}/../nomad-jobs/sb.nomad.hcl")
  detach  = false

  hcl2 {
    vars = {
      datacenter  = var.nomad_datacenter
      app_version = var.app_version
      db_password = random_password.db_password.result
    }
  }
}
