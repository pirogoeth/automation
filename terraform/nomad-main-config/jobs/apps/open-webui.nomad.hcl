variable "domain" {
  type = string
}

variable "open_webui_version" {
  type    = string
  default = "main"
}

variable "pipelines_version" {
  type    = string
  default = "main"
}

job "open-webui" {
  type        = "service"
  namespace   = "apps"
  datacenters = ["dc1"]

  node_pool = "all"

  group "app" {
    count = 1

    network {
      mode = "bridge"

      port "http-ui" {
        to = 8080
      }

      port "http-pipelines" {
        to = 9099
      }
    }

    task "open-webui" {
      driver = "docker"

      config {
        image      = "ghcr.io/open-webui/open-webui:${var.open_webui_version}"
        force_pull = true

        ports = ["http-ui"]

        labels {
          appname                  = "open-webui"
          component                = "open-webui"
          vector_stdout_parse_mode = "plain"
          vector_stderr_parse_mode = "plain"
        }

        volumes = [
          "/data/open-webui-data:/app/backend/data",
        ]
      }

      env {
        WEBUI_URL       = "https://llms.${var.domain}/"
        OLLAMA_BASE_URL = "https://ollama.${var.domain}"
      }

      resources {
        cpu        = 512
        memory     = 512
        memory_max = 10240
      }

      service {
        name     = "open-webui"
        provider = "nomad"
        port     = "http-ui"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.llm-open-webui.rule=Host(`llms.${var.domain}`)",
          "traefik.http.routers.llm-open-webui.entrypoints=web-secure",
          "traefik.http.routers.llm-open-webui.tls=true",
        ]

        check {
          type     = "http"
          port     = "http-ui"
          path     = "/health"
          interval = "120s"
          timeout  = "2s"
        }
      }
    }

    task "pipelines" {
      driver = "docker"

      config {
        image      = "ghcr.io/open-webui/pipelines:${var.pipelines_version}"
        force_pull = true

        ports = ["http-pipelines"]

        labels {
          appname                  = "open-webui"
          component                = "pipelines"
          vector_stdout_parse_mode = "plain"
          vector_stderr_parse_mode = "plain"
        }

        volumes = [
          "/data/open-webui-pipelines:/pipelines",
        ]
      }

      env {
        WEBUI_URL       = "https://llms.${var.domain}/"
        OLLAMA_BASE_URL = "https://ollama.${var.domain}"
      }

      resources {
        cpu    = 512
        memory = 512
        # memory_max = 10240
        memory_max = 4096
      }

      service {
        name     = "pipelines"
        provider = "nomad"
        port     = "http-pipelines"

        check {
          type     = "http"
          port     = "http-pipelines"
          path     = "/health"
          interval = "120s"
          timeout  = "2s"
        }
      }
    }
  }
}

