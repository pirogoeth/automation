variable "version" {
  type = string
}

variable "domain" {
  type = string
}

job "grafana" {
  namespace   = "monitoring"
  type        = "service"
  datacenters = ["dc1"]

  update {
    stagger = "30s"
  }

  group "app" {
    count = 1

    network {
      port "http" {
        to = 3000
      }
    }

    task "grafana" {
      driver = "docker"

      config {
        image      = "grafana/grafana:${var.version}"
        force_pull = true

        ports = ["http"]

        labels {
          appname                  = "grafana"
          vector_stdout_parse_mode = "logfmt"
        }

        volumes = [
          "/data/grafana-data:/var/lib/grafana",
        ]
      }

      env {
        GF_SERVER_DOMAIN   = "grafana.${var.domain}"
        GF_SERVER_ROOT_URL = "https://grafana.${var.domain}"
      }

      resources {
        cpu        = 512
        memory     = 1024
        memory_max = 2048
      }

      service {
        port     = "http"
        provider = "nomad"
        tags = [
          "prometheus.io/scrape=true",
          "prometheus.io/path=/metrics",
          "traefik.enable=true",
          "traefik.http.routers.grafana.rule=Host(`grafana.${var.domain}`) && !Path(`/metrics`)",
          "traefik.http.routers.grafana.entrypoints=web-secure,cftunnel-secure",
          "traefik.http.routers.grafana.tls=true",
          # Temporarily(?) using the defaultGeneratedCert
          # "traefik.http.routers.grafana-secure.tls.certresolver=default-le",
        ]

        check {
          type     = "http"
          path     = "/"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}
