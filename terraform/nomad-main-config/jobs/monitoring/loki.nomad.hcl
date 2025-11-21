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
  description = "Loki config"
}

job "loki" {
  namespace   = "monitoring"
  type        = "service"
  datacenters = ["dc1"]

  group "loki" {
    count = 1

    ephemeral_disk {
      # Used to store index, cache, WAL
      # Nomad will try to preserve the disk between job updates
      size   = 1000
      sticky = true
    }

    network {
      port "http" {
        to     = 3100
        static = 3100
      }
      port "grpc" {}
    }

    task "loki" {
      driver = "docker"
      user   = "nobody"

      config {
        image = "grafana/loki:${var.version}"

        ports = [
          "http",
          "grpc",
        ]

        args = [
          "-target=all",
          "-config.file=/local/config.yml",
          "-config.expand-env=true",
        ]
      }

      template {
        destination   = "local/config.yml"
        change_mode   = "signal"
        change_signal = "SIGHUP"

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
        name     = "loki"
        port     = "http"
        provider = "nomad"

        tags = [
          "prometheus.io/scrape=true",
          "prometheus.io/path=/metrics",
          "prometheus.io/scrape_interval=15s",

          "traefik.enable=true",
          "traefik.http.routers.loki.rule=Host(`loki.${var.domain}`)",
          "traefik.http.routers.loki.entrypoints=web-secure",
          "traefik.http.routers.loki.tls=true",
        ]

        check {
          name     = "Loki"
          port     = "http"
          type     = "http"
          path     = "/ready"
          interval = "20s"
          timeout  = "1s"

          initial_status = "passing"
        }
      }

      resources {
        cpu        = 500
        memory     = 256
        memory_max = 1024
      }
    }
  }
}
