variable "datacenter" {
  type        = string
  default     = "dc1"
  description = "Target Nomad Datacenter"
}

variable "app_version" {
  type        = string
  default     = "1.0.0"
  description = "Application image tag"
}

variable "db_password" {
  type        = string
  default     = "dev_password_only"
  description = "Database superuser secret"
}

job "sb" {
  datacenters = [var.datacenter]
  type        = "service"

  # =============================================================
  # 1. DATABASE
  # =============================================================
  group "db" {
    count          = 1
    shutdown_delay = "5s"

    network {
      port "db" {
        to = 5432
      }
    }

    service {
      name     = "db"
      port     = "db"
      provider = "nomad"

      check {
        type     = "tcp"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "postgres" {
      driver = "docker"

      config {
        image        = "postgres:16-alpine"
        ports        = ["db"]
        network_mode = "sb" # Joins shared Docker network
        hostname     = "db" # Resolvable by backend API
      }

      env {
        POSTGRES_DB       = "sb"
        POSTGRES_USER     = "sb_user"
        POSTGRES_PASSWORD = var.db_password
      }

      resources {
        cpu    = 50
        memory = 256
      }
    }
  }

  # =============================================================
  # 2. BACKEND API
  # =============================================================
  group "backend" {
    count          = 2
    shutdown_delay = "5s"

    network {
      port "http" {
        to = 8080
      }
    }

    service {
      name     = "backend"
      port     = "http"
      provider = "nomad"

      check {
        type     = "http"
        path     = "/healthz"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "api" {
      driver = "docker"

      config {
        image        = "ghcr.io/anton-dragan/sb-backend:${var.app_version}"
        ports        = ["http"]
        network_mode = "sb"       # Joins shared Docker network
        hostname     = "backend"  # Resolvable by frontend Nginx
      }

      env {
        PORT    = "8080"
        DB_HOST = "db"
      }

      resources {
        cpu    = 50
        memory = 128
      }
    }
  }

  # =============================================================
  # 3. FRONTEND (Ingress)
  # =============================================================
  group "frontend" {
    count          = 1
    shutdown_delay = "5s"

    network {
      port "http" {
        static = 8080
        to     = 8080
      }
    }

    service {
      name     = "frontend"
      port     = "http"
      provider = "nomad"

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "web" {
      driver = "docker"

      config {
        image        = "ghcr.io/anton-dragan/sb-frontend:${var.app_version}"
        ports        = ["http"]
        network_mode = "sb" # Joins shared Docker network
      }

      resources {
        cpu    = 50
        memory = 64
      }
    }
  }
}
