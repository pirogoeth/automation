variable "version" {
  type = string
}

variable "domain" {
  type = string
}

job "localai" {
  type        = "service"
  namespace   = "apps"
  datacenters = ["dc1"]

  node_pool = "gpu"

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
        to = 8080
      }
    }

    task "localai" {
      driver = "docker"

      config {
        image      = "localai/localai:${var.version}-aio-gpu-nvidia-cuda-12"
        force_pull = true

        runtime = "nvidia"

        ports = ["http"]

        labels {
          appname                  = "localai"
          vector_stdout_parse_mode = "plain"
          vector_stderr_parse_mode = "plain"
        }

        volumes = [
          "/data/localai-models:/build/models:cached"
        ]
      }

      service {
        port     = "http"
        provider = "nomad"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.localai.rule=Host(`ai.${var.domain}`)",
          "traefik.http.routers.localai.entrypoints=web-secure",
          "traefik.http.routers.localai.tls=true",
          "traefik.http.services.localai.loadbalancer.passhostheader=true",
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
