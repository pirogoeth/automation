variable "version" {
  type = string
}

variable "domain" {
  type = string
}

job "phoenix" {
  type        = "service"
  namespace   = "apps"
  datacenters = ["dc1"]

  node_pool = "default"

  update {
    max_parallel      = 1
    min_healthy_time  = "10s"
    healthy_deadline  = "3m"
    progress_deadline = "10m"
    auto_revert       = true
    canary            = 0
  }

  group "app" {
    count = 1

    network {
      mode = "bridge"

      port "http" {
        to = 6006
      }

      port "grpc" {
        to = 4317
      }

      port "metrics" {
        to = 9090
      }
    }

    task "phoenix" {
      driver = "docker"

      config {
        image      = "arizephoenix/phoenix:${var.version}"
        force_pull = true

        ports = ["http", "grpc", "metrics"]

        labels {
          appname                  = "phoenix"
          vector_stdout_parse_mode = "plain"
          vector_stderr_parse_mode = "plain"
        }

        volumes = [
          "/data/phoenix-data:/data:cached",
        ]
      }

      env {
        PHOENIX_WORKING_DIR = "/data"
      }

      service {
        name     = "phoenix-http"
        port     = "http"
        provider = "nomad"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.phoenix.rule=Host(`phoenix.${var.domain}`)",
          "traefik.http.routers.phoenix.entrypoints=web-secure",
          "traefik.http.routers.phoenix.tls=true",
          "traefik.http.services.phoenix.loadbalancer.passhostheader=true",
        ]

        check {
          type     = "http"
          path     = "/healthz"
          interval = "10s"
          timeout  = "2s"
        }
      }

      service {
        name     = "phoenix-grpc"
        port     = "grpc"
        provider = "nomad"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.phoenix-grpc-secure.rule=Host(`phoenix-ingest.${var.domain}`)",
          "traefik.http.routers.phoenix-grpc-secure.entrypoints=web-secure",
          "traefik.http.routers.phoenix-grpc-secure.tls=true",
          "traefik.http.routers.phoenix-grpc-secure.service=phoenix-grpc-secure",
          "traefik.http.services.phoenix-grpc-secure.loadbalancer.server.scheme=h2c",
        ]

        check {
          port     = "http"
          type     = "http"
          path     = "/healthz"
          interval = "20s"
          timeout  = "1s"
        }
      }

      service {
        name     = "phoenix-metrics"
        port     = "metrics"
        provider = "nomad"

        tags = [
          "prometheus.io/scrape=true",
          "prometheus.io/path=/metrics",
        ]
      }

      resources {
        cpu        = 256
        memory     = 512
        memory_max = 2048
      }
    }
  }
}
