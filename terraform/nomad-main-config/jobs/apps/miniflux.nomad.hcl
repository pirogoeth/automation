variable "admin_username" {
  type = string
}

variable "admin_password" {
  type = string
}

variable "domain" {
  type = string
}

variable "version" {
  type    = string
  default = "2.0.51"
}

job "miniflux" {
  namespace   = "apps"
  type        = "service"
  datacenters = ["dc1"]

  update {
    max_parallel      = 1
    min_healthy_time  = "10s"
    healthy_deadline  = "3m"
    progress_deadline = "10m"
    auto_revert       = false
    canary            = 0
  }

  group "app" {
    count = 1

    network {
      mode = "bridge"

      port "http" {
        to = 3000
      }
    }

    task "miniflux" {
      driver = "docker"

      config {
        image      = "miniflux/miniflux:${var.version}"
        force_pull = true

        ports = ["http"]

        labels {
          appname                  = "miniflux"
          vector_stderr_parse_mode = "logfmt"
        }
      }

      env {
        DATABASE_URL             = "postgres://miniflux:miniflux@localhost/miniflux?sslmode=disable"
        BASE_URL                 = "https://news.${var.domain}"
        RUN_MIGRATIONS           = "1"
        CREATE_ADMIN             = "1"
        ADMIN_USERNAME           = var.admin_username
        ADMIN_PASSWORD           = var.admin_password
        LISTEN_ADDR              = ":3000"
        METRICS_COLLECTOR        = "1"
        METRICS_ALLOWED_NETWORKS = "127.0.0.0/8,172.17.0.0/12,10.100.10.0/23"
        FETCH_NEBULA_WATCH_TIME  = "1"
      }

      resources {
        cpu        = 256
        memory     = 256
        memory_max = 1024
      }

      service {
        port     = "http"
        provider = "nomad"
        tags = [
          "prometheus.io/scrape=true",
          "prometheus.io/path=/metrics",
          "traefik.enable=true",
          "traefik.http.routers.miniflux.rule=Host(`news.${var.domain}`)",
          "traefik.http.routers.miniflux.entrypoints=web-secure",
          "traefik.http.routers.miniflux.tls=true",
          # Temporarily(?) using the defaultGeneratedCert
          # "traefik.http.routers.miniflux-secure.tls.certresolver=letsencrypt",
        ]
      }
    }

    task "postgres" {
      driver = "docker"

      config {
        image      = "postgres:15-alpine"
        force_pull = true

        volumes = [
          "/data/miniflux-db-postgres:/var/lib/postgresql/data"
        ]
      }

      env {
        POSTGRES_USER     = "miniflux"
        POSTGRES_PASSWORD = "miniflux"
        POSTGRES_DB       = "miniflux"
      }

      resources {
        cpu    = 256
        memory = 256
      }
    }
  }
}
