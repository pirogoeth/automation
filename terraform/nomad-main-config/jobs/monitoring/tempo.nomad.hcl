variable "s3_endpoint_url" {
  type = string
}

variable "s3_region" {
  type = string
}

variable "s3_bucket_name" {
  type = string
}

variable "s3_access_key_id" {
  type = string
}

variable "s3_secret_access_key" {
  type = string
}

variable "s3_insecure" {
  type = string
}

variable "version" {
  type = string
}

variable "domain" {
  type = string
}

variable "config" {
  type        = string
  description = "Tempo config"
}

job "tempo" {
  namespace   = "monitoring"
  type        = "service"
  datacenters = ["dc1"]

  group "app" {
    count = 1

    ephemeral_disk {
      # Used to store index, cache, WAL
      # Nomad will try to preserve the disk between job updates
      size   = 1000
      sticky = true
    }

    network {
      port "http" {}
      port "grpc" {}
      port "gossip" {}

      port "ingest-http" {}
      port "ingest-grpc" {}
    }

    task "monolith" {
      driver = "docker"
      user   = "nobody"

      config {
        image = "docker.io/bitnami/grafana-tempo:${var.version}"

        ports = [
          "http",
          "gossip",
          "ingest-http",
          "ingest-grpc",
        ]

        args = [
          "-target=all",
          "-config.file=/local/config.yml",
          "-config.expand-env=true",
        ]
      }

      resources {
        cpu        = 500
        memory     = 512
        memory_max = 3096
      }

      template {
        destination   = "local/config.yml"
        change_mode   = "signal"
        change_signal = "SIGHUP"
        splay         = "30s"

        data = var.config
      }

      template {
        destination = "secrets/env"
        env         = true

        data = <<-EOH
DOMAIN=${var.domain}
S3_ENDPOINT_URL=${var.s3_endpoint_url}
S3_REGION=${var.s3_region}
S3_BUCKET_NAME=${var.s3_bucket_name}
S3_ACCESS_KEY_ID=${var.s3_access_key_id}
S3_SECRET_ACCESS_KEY=${var.s3_secret_access_key}
S3_INSECURE=${var.s3_insecure}
        EOH
      }

      # dynamic "template" {
      #   for_each = fileset(".", "loki/rules/**")

      #   content {
      #     data            = file(template.value)
      #     destination     = "local/${template.value}"
      #     left_delimiter  = "[["
      #     right_delimiter = "]]"
      #   }
      # }

      service {
        name     = "tempo-monolith-gossip"
        port     = "gossip"
        provider = "nomad"

        check {
          name     = "Tempo"
          port     = "http"
          type     = "http"
          path     = "/ready"
          interval = "20s"
          timeout  = "1s"

          initial_status = "passing"
        }
      }

      service {
        name     = "tempo-monolith-http"
        port     = "http"
        provider = "nomad"

        tags = [
          "prometheus.io/scrape=true",
          "prometheus.io/path=/metrics",
          "prometheus.io/scrape_interval=15s",

          "traefik.enable=true",
          "traefik.http.routers.tempo-http.rule=Host(`tempo.${var.domain}`)",
          "traefik.http.routers.tempo-http.entrypoints=web",
          "traefik.http.routers.tempo-http.middlewares=tempo-https-redirect",
          "traefik.http.routers.tempo-http-secure.rule=Host(`tempo.${var.domain}`)",
          "traefik.http.routers.tempo-http-secure.entrypoints=web-secure",
          "traefik.http.routers.tempo-http-secure.tls=true",
          "traefik.http.middlewares.tempo-https-redirect.redirectscheme.scheme=https",
        ]

        check {
          name     = "Tempo"
          port     = "http"
          type     = "http"
          path     = "/ready"
          interval = "20s"
          timeout  = "1s"

          initial_status = "passing"
        }
      }

      service {
        name     = "tempo-monolith-ingest-http"
        port     = "ingest-http"
        provider = "nomad"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.tempo-ingest-http-secure.rule=Host(`tempo-ingest-http.${var.domain}`)",
          "traefik.http.routers.tempo-ingest-http-secure.entrypoints=web-secure",
          "traefik.http.routers.tempo-ingest-http-secure.tls=true",
        ]

        check {
          name     = "Tempo"
          port     = "http"
          type     = "http"
          path     = "/ready"
          interval = "20s"
          timeout  = "1s"

          initial_status = "passing"
        }
      }

      service {
        name     = "tempo-monolith-ingest-grpc"
        port     = "ingest-grpc"
        provider = "nomad"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.tempo-grpc-secure.rule=Host(`tempo-ingest.${var.domain}`) || Host(`tempo-ingest-grpc.${var.domain}`)",
          "traefik.http.routers.tempo-grpc-secure.entrypoints=web-secure",
          "traefik.http.routers.tempo-grpc-secure.tls=true",
          "traefik.http.routers.tempo-grpc-secure.service=tempo-grpc-secure",
          "traefik.http.services.tempo-grpc-secure.loadbalancer.server.scheme=h2c",
        ]

        check {
          name     = "Tempo"
          port     = "http"
          type     = "http"
          path     = "/ready"
          interval = "20s"
          timeout  = "1s"

          initial_status = "passing"
        }
      }
    }
  }
}
